local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_unpacking = require("scripts.hubs.hub-unpacking")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local debug_manager = require("scripts.debug-manager")

local MAX_CAPSULES_PER_ENTITY_NETWORK = 1

local capsule_runner = {}

-- Alias extracted queries and cleanup routines for API compatibility
capsule_runner.get_capsule_count_at_entity = capsule_queries.get_capsule_count_at_entity
capsule_runner.get_capsule_count_at_entity_network = capsule_queries.get_capsule_count_at_entity_network
capsule_runner.remove_capsule = capsule_queries.remove_capsule
capsule_runner.find_capsules_at_entity = capsule_queries.find_capsules_at_entity

local clear_capsule_render = capsule_queries.clear_capsule_render

-- Velocity bounds & baseline configuration (tiles per second)
local BASE_SPEED_TILES_PER_SEC = 15
local MIN_SPEED_TILES_PER_SEC = 4
local MAX_SPEED_TILES_PER_SEC = 60

local function init_storage()
    storage.capsules = storage.capsules or {}
    storage.next_capsule_id = storage.next_capsule_id or 1
end

--- Retrieves node metadata across network boundaries safely
local function get_node(port_key)
    if not (storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local flow_map = networks.get_metadata(net_id, "flow_map")
    return flow_map and flow_map[port_key]
end

--- Dynamic velocity calculation scaling strictly with the intensity of local pressure drop (ΔP)
--- @param from_port_key string|nil
--- @param to_port_key string|nil
--- @return number tiles_per_tick
local function calculate_segment_speed(from_port_key, to_port_key)
    if not (from_port_key and to_port_key) then
        return MIN_SPEED_TILES_PER_SEC / 60.0
    end

    local node_from = get_node(from_port_key)
    local node_to = get_node(to_port_key)
    if not (node_from and node_to) then
        return BASE_SPEED_TILES_PER_SEC / 60.0
    end

    local p_from = (storage.port_pressures and storage.port_pressures[from_port_key]) or node_from.pressure or 0
    local p_to = (storage.port_pressures and storage.port_pressures[to_port_key]) or node_to.pressure or 0
    local is_internal = (node_from.unit_number == node_to.unit_number)

    local delta_p = 0
    if is_internal then
        -- Internal machine pass-through: fallback drop based on local node pressure (minimum 1.0)
        delta_p = math.max(1.0, math.abs(p_from) * 0.10)
    else
        -- External pipe segment edge drop: ΔP = |P_from - P_to|
        delta_p = math.max(0.1, math.abs(p_from - p_to))
    end

    -- Velocity scales non-linearly with the square root of local pressure drop intensity
    local speed_multiplier = math.sqrt(delta_p)
    local tiles_per_sec = BASE_SPEED_TILES_PER_SEC * speed_multiplier

    tiles_per_sec = math.max(MIN_SPEED_TILES_PER_SEC, math.min(MAX_SPEED_TILES_PER_SEC, tiles_per_sec))

    return tiles_per_sec / 60.0
end

--- Inspects the capsule's liminal holder container to determine the dominant cargo item stack
--- @param capsule_id number
--- @return string|nil item_name
local function get_dominant_item(capsule_id)
    local cap_data = capsule_manager.get(capsule_id)
    if not (cap_data and cap_data.holder and cap_data.holder.valid) then
        return nil
    end

    local inventory = cap_data.holder.get_inventory(defines.inventory.chest)
    if not (inventory and inventory.valid and not inventory.is_empty()) then
        return nil
    end

    local max_cargo_count = 0
    local dominant_cargo_item = nil

    local max_vessel_count = 0
    local dominant_vessel_item = nil

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read and stack.count > 0 then
            local is_vessel = capsule_defs.types[stack.name] ~= nil
            if is_vessel then
                if stack.count > max_vessel_count then
                    max_vessel_count = stack.count
                    dominant_vessel_item = stack.name
                end
            else
                if stack.count > max_cargo_count then
                    max_cargo_count = stack.count
                    dominant_cargo_item = stack.name
                end
            end
        end
    end

    -- Prioritize internal cargo items over vessel capsule shell
    return dominant_cargo_item or dominant_vessel_item
end

--- Retrieves world coordinates and surface for a specific port key
local function get_port_world_pos(port_key)
    local node = get_node(port_key)
    if node and node.entity and node.entity.valid then
        return {
            x = node.entity.position.x + node.offset.x,
            y = node.entity.position.y + node.offset.y
        }, node.entity.surface
    end
    return nil, nil
end

--- Evaluates if target entity's network segment has available capsule capacity
local function has_entity_network_capacity(from_port_key, target_port_key)
    if not (storage.networks and storage.networks.port_to_network) then return false end

    local target_unit = tonumber(target_port_key:match("^(%d+)"))
    local target_net_id = storage.networks.port_to_network[target_port_key]

    if not (target_unit and target_net_id) then return false end

    local current_unit = tonumber(from_port_key:match("^(%d+)"))
    local current_net_id = storage.networks.port_to_network[from_port_key]

    local count = capsule_queries.get_capsule_count_at_entity_network(target_unit, target_net_id)

    -- If moving within the exact same entity and network, capsule is already accounted for
    if current_unit == target_unit and current_net_id == target_net_id then
        return count <= MAX_CAPSULES_PER_ENTITY_NETWORK
    else
        return count < MAX_CAPSULES_PER_ENTITY_NETWORK
    end
end

--- Leverages flow_map outbound_hops and applies anti-backtracking with randomized tie-breaking
local function select_next_target(capsule)
    local current_node = get_node(capsule.from_port_key)
    if not (current_node and current_node.outbound_hops and #current_node.outbound_hops > 0) then
        return nil
    end

    local hops = current_node.outbound_hops

    -- 1. Anti-backtracking & local entity-network capacity filter
    local candidates = {}
    for _, hop_key in ipairs(hops) do
        if hop_key ~= capsule.last_port_key and has_entity_network_capacity(capsule.from_port_key, hop_key) then
            table.insert(candidates, hop_key)
        end
    end

    -- Conditional turnaround check
    if #candidates == 0 then
        local backtrack_candidate = nil
        for _, hop_key in ipairs(hops) do
            if hop_key == capsule.last_port_key and has_entity_network_capacity(capsule.from_port_key, hop_key) then
                backtrack_candidate = hop_key
                break
            end
        end

        if backtrack_candidate then
            local last_node = get_node(capsule.last_port_key)
            local path_opened = false
            
            if last_node and last_node.outbound_hops then
                for _, next_hop in ipairs(last_node.outbound_hops) do
                    if next_hop ~= capsule.from_port_key then
                        path_opened = true
                        break
                    end
                end
            end
            
            if path_opened then
                candidates = { backtrack_candidate }
            else
                return nil
            end
        else
            return nil
        end
    end

    -- 2. Evaluate scores and collect top candidates for randomized tie-breaking
    local best_candidates = {}
    local max_drop = -math.huge

    for _, hop_key in ipairs(candidates) do
        local target_node = get_node(hop_key)
        if target_node then
            local drop = -math.huge
            local is_internal = (target_node.unit_number == current_node.unit_number)

            if is_internal then
                if target_node.pressure > current_node.pressure then
                    drop = math.huge
                else
                    local best_downstream = -math.huge
                    for _, next_hop in ipairs(target_node.outbound_hops) do
                        local next_node = get_node(next_hop)
                        if next_node and next_node.unit_number ~= target_node.unit_number then
                            local d = current_node.pressure - next_node.pressure
                            if d > best_downstream then 
                                best_downstream = d 
                            end
                        end
                    end
                    drop = (best_downstream ~= -math.huge) and best_downstream or 0
                end
            else
                drop = current_node.pressure - target_node.pressure
            end

            local is_ext = not is_internal

            -- Handle scores and tie-breaking pools
            if drop > max_drop then
                max_drop = drop
                best_candidates = { { key = hop_key, is_external = is_ext } }
            elseif drop == max_drop then
                local current_best_is_ext = best_candidates[1] and best_candidates[1].is_external
                
                if is_ext and not current_best_is_ext then
                    -- External exits take priority over internal routing on a tie
                    best_candidates = { { key = hop_key, is_external = true } }
                elseif not is_ext and current_best_is_ext then
                    -- Keep the external choice, ignore the internal one
                else
                    -- Truly equal options, add to pool
                    table.insert(best_candidates, { key = hop_key, is_external = is_ext })
                end
            end
        end
    end

    if #best_candidates == 0 then
        return nil
    end

    -- 3. Pick randomly among all top-tier tied candidates
    local chosen = best_candidates[math.random(#best_candidates)]
    return chosen.key
end

--- Checks memory and evaluates capture conditions upon reaching or standing at a port
local function handle_arrival(capsule, id)
    local new_unit_num = tonumber(capsule.from_port_key:match("^(%d+)"))
    
    -- 1. Memory Wipe: If stepped onto a different entity, forget the source hub
    if capsule.source_hub and new_unit_num ~= capsule.source_hub then
        capsule.source_hub = nil
    end

    -- 2. Capture Check
    local node = get_node(capsule.from_port_key)
    if node and node.entity and node.entity.valid then
        local hub_def = hub_defs.types[node.entity.name]
        
        -- If it's a hub, and NOT our source hub
        if hub_def and capsule.source_hub ~= node.entity.unit_number then
            local unpacked = hub_unpacking.capture(capsule, node.entity)
            
            if unpacked then
                clear_capsule_render(capsule)
                storage.capsules[id] = nil
                return true -- Unpacked and destroyed successfully
            else
                -- Hub chest is full. Halt target movement so we remain parked here.
                capsule.to_port_key = nil
            end
        end
    end
    return false
end

--- Main movement loop executed every game tick
local function update_capsules()
    if not storage.capsules then return end

    for id, capsule in pairs(storage.capsules) do
        local current_speed = calculate_segment_speed(capsule.from_port_key, capsule.to_port_key)
        local tiles_this_tick = current_speed
        local surface = nil
        local curr_pos = nil
        local safety_counter = 0

        while tiles_this_tick > 0 and safety_counter < 50 do
            safety_counter = safety_counter + 1

            -- 1. If stationary at a port, poll unpacking FIRST before target searching
            if not capsule.to_port_key then
                if handle_arrival(capsule, id) then 
                    break -- Capsule unpacked and destroyed successfully!
                end

                capsule.to_port_key = select_next_target(capsule)
                capsule.progress = 0.0

                if capsule.to_port_key then
                    local new_speed = calculate_segment_speed(capsule.from_port_key, capsule.to_port_key)
                    if current_speed > 0 then
                        tiles_this_tick = tiles_this_tick * (new_speed / current_speed)
                    else
                        tiles_this_tick = new_speed
                    end
                    current_speed = new_speed
                end
            end

            local from_pos, surf = get_port_world_pos(capsule.from_port_key)
            
            if not from_pos then
                clear_capsule_render(capsule)
                storage.capsules[id] = nil
                break
            end
            
            surface = surf
            curr_pos = { x = from_pos.x, y = from_pos.y }

            -- Parked waiting at a full hub or dead end
            if not capsule.to_port_key then
                break
            end

            local to_pos = get_port_world_pos(capsule.to_port_key)
            if not to_pos then
                capsule.to_port_key = nil
                capsule.progress = 0.0
                break
            end

            local dx = to_pos.x - from_pos.x
            local dy = to_pos.y - from_pos.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= 0.001 then
                capsule.last_port_key = capsule.from_port_key
                capsule.from_port_key = capsule.to_port_key
                capsule.to_port_key = nil
                capsule.progress = 0.0
                
                if handle_arrival(capsule, id) then break end
            else
                local remaining_distance = distance * (1.0 - capsule.progress)

                if tiles_this_tick >= remaining_distance then
                    tiles_this_tick = tiles_this_tick - remaining_distance
                    capsule.last_port_key = capsule.from_port_key
                    capsule.from_port_key = capsule.to_port_key
                    capsule.to_port_key = nil
                    capsule.progress = 0.0
                    curr_pos = { x = to_pos.x, y = to_pos.y }
                    
                    if handle_arrival(capsule, id) then break end
                else
                    capsule.progress = capsule.progress + (tiles_this_tick / distance)
                    curr_pos.x = from_pos.x + dx * capsule.progress
                    curr_pos.y = from_pos.y + dy * capsule.progress
                    tiles_this_tick = 0
                end
            end
        end

        if storage.capsules[id] then
            clear_capsule_render(capsule)
            if is_debug_active("capsules") and surface and curr_pos then
                local render_objects = {}

                local dominant_item = get_dominant_item(capsule.id or id)
                if dominant_item then
                    -- Clean gold border outline framing the item sprite
                    local ring = rendering.draw_circle{
                        color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                        radius = 0.35,
                        filled = false,
                        width = 2,
                        target = curr_pos,
                        surface = surface
                    }
                    table.insert(render_objects, ring)

                    -- Scaled item sprite rendered clearly on top
                    local sprite = rendering.draw_sprite{
                        sprite = "item/" .. dominant_item,
                        target = curr_pos,
                        surface = surface,
                        x_scale = 0.55,
                        y_scale = 0.55
                    }
                    table.insert(render_objects, sprite)
                else
                    -- Fallback simple gold indicator dot if capsule is completely empty
                    local dot = rendering.draw_circle{
                        color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                        radius = 0.25,
                        filled = true,
                        target = curr_pos,
                        surface = surface
                    }
                    table.insert(render_objects, dot)
                end

                capsule.render_id = render_objects
            end
        end
    end
end

--- Injects a physically packed capsule ID into the motion runner on the optimal port
function capsule_runner.inject_from_hub(capsule_id, entity)
    init_storage()
    local ports = port_defs.get_ports(entity)
    if not ports then return false end

    local best_port_key = nil
    local max_drop = -math.huge
    local fallback_port_key = nil

    for p_idx, _ in ipairs(ports) do
        local key = entity.unit_number .. ":" .. p_idx
        
        if storage.networks and storage.networks.port_to_network then
            local net_id = storage.networks.port_to_network[key]
            if net_id then
                if not fallback_port_key then fallback_port_key = key end
                
                local flow_map = networks.get_metadata(net_id, "flow_map")
                local node = flow_map and flow_map[key]
                
                if node and node.outbound_hops then
                    for _, hop_key in ipairs(node.outbound_hops) do
                        local target_node = flow_map[hop_key]
                        
                        if target_node and target_node.unit_number ~= entity.unit_number then
                            local drop = node.pressure - target_node.pressure
                            if drop > max_drop then
                                max_drop = drop
                                best_port_key = key
                            end
                        end
                    end
                end
            end
        end
    end

    local target_port_key = best_port_key or fallback_port_key
    if not target_port_key then return false end

    storage.capsules[capsule_id] = {
        id = capsule_id,
        from_port_key = target_port_key,
        to_port_key = nil,
        last_port_key = nil,
        progress = 0.0,
        render_id = nil,
        source_hub = entity.unit_number
    }
    return true
end

-- Hook game tick event for smooth travel
events.on_event(defines.events.on_tick, function(event)
    update_capsules()
end)

return capsule_runner