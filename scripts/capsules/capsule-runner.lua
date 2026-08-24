-- scripts/capsules/capsule-runner.lua
local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")

local capsule_runner = {}

-- Configurable movement speed (3 tiles / second -> divided by 60 ticks)
local SPEED_TILES_PER_SEC = 3.0
local TILES_PER_TICK = SPEED_TILES_PER_SEC / 60.0

local function init_storage()
    storage.capsules = storage.capsules or {}
    storage.next_capsule_id = storage.next_capsule_id or 1
    if storage.show_capsules == nil then
        storage.show_capsules = true
    end
end

--- Retrieves node metadata across network boundaries safely
local function get_node(port_key)
    if not (storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local flow_map = networks.get_metadata(net_id, "flow_map")
    return flow_map and flow_map[port_key]
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

--- Leverages flow_map outbound_hops and applies anti-backtracking
local function select_next_target(capsule)
    local current_node = get_node(capsule.from_port_key)
    if not (current_node and current_node.outbound_hops and #current_node.outbound_hops > 0) then
        return nil
    end

    local hops = current_node.outbound_hops

    -- 1. Anti-backtracking filter (avoid returning to last_port_key)
    local candidates = {}
    for _, hop_key in ipairs(hops) do
        if hop_key ~= capsule.last_port_key then
            table.insert(candidates, hop_key)
        end
    end

    -- Fix 1: Conditional turnaround. Prevents dead-end ping-pong, 
    -- but allows flow reversal if a new path opens upstream.
    if #candidates == 0 then
        local last_node = get_node(capsule.last_port_key)
        local path_opened = false
        
        -- Check if the node we came from has any valid exits besides the dead end we are sitting at
        if last_node and last_node.outbound_hops then
            for _, next_hop in ipairs(last_node.outbound_hops) do
                if next_hop ~= capsule.from_port_key then
                    path_opened = true
                    break
                end
            end
        end
        
        if path_opened then
            candidates = hops -- Re-allow turnaround because a valid path exists
        else
            return nil -- Sit and wait. The only option is a useless ping-pong loop.
        end
    end

    -- 2. Select hop with highest effective pressure differential
    local best_target = candidates[1]
    local max_drop = -math.huge

    for _, hop_key in ipairs(candidates) do
        local target_node = get_node(hop_key)
        if target_node then
            local drop = -math.huge
            local is_internal = (target_node.unit_number == current_node.unit_number)

            if is_internal then
                -- For pumps: heavily prioritize internal hops that increase pressure (Inlet -> Outlet)
                if target_node.pressure > current_node.pressure then
                    drop = math.huge
                else
                    -- Fix 2: For junctions, look ahead one hop to find the lowest pressure exit path
                    local best_downstream = -math.huge
                    for _, next_hop in ipairs(target_node.outbound_hops) do
                        local next_node = get_node(next_hop)
                        -- Check external neighbors of the target internal port
                        if next_node and next_node.unit_number ~= target_node.unit_number then
                            local d = current_node.pressure - next_node.pressure
                            if d > best_downstream then 
                                best_downstream = d 
                            end
                        end
                    end
                    -- Use the best downstream drop, fallback to 0 if no external exits exist
                    drop = (best_downstream ~= -math.huge) and best_downstream or 0
                end
            else
                -- Standard external hop drop
                drop = current_node.pressure - target_node.pressure
            end

            if drop > max_drop then
                max_drop = drop
                best_target = hop_key
            end
        end
    end

    return best_target
end

local function clear_capsule_render(capsule)
    if capsule.render_id and capsule.render_id.valid then
        capsule.render_id.destroy()
    end
    capsule.render_id = nil
end

--- Main movement loop executed every game tick
local function update_capsules()
    if not storage.capsules then return end

    for id, capsule in pairs(storage.capsules) do
        -- 1. Acquire target if stationary
        if not capsule.to_port_key then
            capsule.to_port_key = select_next_target(capsule)
            capsule.progress = 0.0
        end

        local from_pos, surface = get_port_world_pos(capsule.from_port_key)

        -- Remove capsule if its origin entity was destroyed
        if not from_pos then
            clear_capsule_render(capsule)
            storage.capsules[id] = nil
        else
            local curr_pos = { x = from_pos.x, y = from_pos.y }

            -- 2. Process movement toward active target
            if capsule.to_port_key then
                local to_pos = get_port_world_pos(capsule.to_port_key)
                if not to_pos then
                    -- Target port removed, clear target and retry search next tick
                    capsule.to_port_key = nil
                    capsule.progress = 0.0
                else
                    local dx = to_pos.x - from_pos.x
                    local dy = to_pos.y - from_pos.y
                    local distance = math.sqrt(dx * dx + dy * dy)

                    if distance <= 0.001 then
                        -- Co-located internal machine hop; step immediately
                        capsule.last_port_key = capsule.from_port_key
                        capsule.from_port_key = capsule.to_port_key
                        capsule.to_port_key = nil
                        capsule.progress = 0.0
                    else
                        local step = TILES_PER_TICK / distance
                        capsule.progress = capsule.progress + step

                        if capsule.progress >= 1.0 then
                            -- Arrival at destination port
                            capsule.last_port_key = capsule.from_port_key
                            capsule.from_port_key = capsule.to_port_key
                            capsule.to_port_key = nil
                            capsule.progress = 0.0
                            curr_pos = { x = to_pos.x, y = to_pos.y }
                        else
                            -- Interpolate position between ports
                            curr_pos.x = from_pos.x + dx * capsule.progress
                            curr_pos.y = from_pos.y + dy * capsule.progress
                        end
                    end
                end
            end

            -- 3. Redraw visual render position
            clear_capsule_render(capsule)
            if storage.show_capsules then
                capsule.render_id = rendering.draw_circle{
                    color = { r = 1, g = 0.84, b = 0, a = 0.9 }, -- Bright Yellow
                    radius = 0.25,
                    filled = true,
                    target = curr_pos,
                    surface = surface
                }
            end
        end
    end
end

function capsule_runner.spawn(player, entity)
    init_storage()

    if not (entity and entity.valid) then
        if player then player.print("[Capsule] No valid entity selected/hovered.") end
        return
    end

    local ports = port_defs.get_ports(entity)
    if not ports then
        if player then player.print(string.format("[Capsule] %s does not have network ports.", entity.name)) end
        return
    end

    -- Find first port on an active network
    local target_port_key = nil
    for p_idx, _ in ipairs(ports) do
        local key = entity.unit_number .. ":" .. p_idx
        local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[key]
        if net_id then
            target_port_key = key
            break
        end
    end

    if not target_port_key then
        if player then player.print("[Capsule] Hovered entity is not bound to an active flow network.") end
        return
    end

    local id = storage.next_capsule_id
    storage.next_capsule_id = id + 1

    storage.capsules[id] = {
        id = id,
        from_port_key = target_port_key,
        to_port_key = nil,
        last_port_key = nil,
        progress = 0.0,
        render_id = nil
    }

    if player then
        player.print(string.format("[Capsule] Spawned Capsule #%d at Port %s", id, target_port_key))
    end
end

function capsule_runner.clear_all(player)
    init_storage()
    local count = 0

    for _, capsule in pairs(storage.capsules) do
        clear_capsule_render(capsule)
        count = count + 1
    end

    storage.capsules = {}

    if player then
        player.print(string.format("[Capsule] Cleared %d capsule(s).", count))
    end
end

function capsule_runner.toggle_rendering(player)
    init_storage()
    storage.show_capsules = not storage.show_capsules

    if not storage.show_capsules then
        for _, capsule in pairs(storage.capsules) do
            clear_capsule_render(capsule)
        end
    end

    if player then
        player.print(string.format("[Capsule] Visualization: %s", storage.show_capsules and "ENABLED" or "DISABLED"))
    end
end

-- Hook game tick event for smooth travel
events.on_event(defines.events.on_tick, function(event)
    update_capsules()
end)

-- Command Registrations
commands.add_command("spawn-capsule", "Spawn an abstract capsule at the hovered network entity", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    local selected = player and player.selected
    capsule_runner.spawn(player, selected)
end)

commands.add_command("clear-capsules", "Clear all active capsules from the map", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    capsule_runner.clear_all(player)
end)

commands.add_command("toggle-capsule", "Toggle capsule rendering overlay", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    capsule_runner.toggle_rendering(player)
end)

return capsule_runner