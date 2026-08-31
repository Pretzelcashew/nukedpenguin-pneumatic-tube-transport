local networks = require("scripts.networks.networks")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_unpacking = require("scripts.hubs.hub-unpacking")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local diverter_settings = require("scripts.diverter-settings")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local port_defs = require("scripts.ports.port-definitions")

local MAX_CAPSULES_PER_ENTITY_NETWORK = 1
local BASE_SPEED_TILES_PER_SEC = 15
local MIN_SPEED_TILES_PER_SEC = 4
local MAX_SPEED_TILES_PER_SEC = 60

local capsule_motion = {}

--- Efficiently retrieves the unit_number from a port_key ("unit_number:port_index")
--- Uses memoized port key parsing to avoid flow map lookups and string allocations.
--- @param port_key string|nil
--- @return number|nil unit_number
local function get_unit_number(port_key)
    if not port_key then return nil end
    return capsule_queries.get_port_info(port_key)
end

--- Lazily compiles and memoizes diverter port filter structures on port_setting._compiled
--- @param port_setting table
--- @return table|false compiled_filter
local function get_compiled_filter(port_setting)
    local compiled = port_setting._compiled
    if compiled ~= nil then
        return compiled
    end

    if not port_setting.use_filters then
        compiled = false
        port_setting._compiled = compiled
        return compiled
    end

    local filter_mode = port_setting.filter_mode or "whitelist"
    local is_blacklist = (filter_mode == "blacklist")
    local filters = port_setting.filters

    local active_slots = {}
    if filters then
        for i = 1, 5 do
            local slot = filters[i]
            if slot then
                local item = slot.item or slot.signal
                if item then
                    local comp = slot.comparator or "="
                    table.insert(active_slots, { item = item, comp = comp })
                end
            end
        end
    end

    compiled = {
        is_blacklist = is_blacklist,
        active_slots = active_slots
    }
    port_setting._compiled = compiled
    return compiled
end

--- Evaluates payload item against memoized compiled port filter configuration
--- @param port_setting table|nil
--- @param payload_item string|nil
--- @return boolean
local function evaluates_port_filter(port_setting, payload_item)
    if not port_setting then return true end

    local compiled = get_compiled_filter(port_setting)
    if compiled == false then
        return true
    end

    if not payload_item then
        return compiled.is_blacklist
    end

    local active_slots = compiled.active_slots
    local num_active = #active_slots

    if num_active == 0 then
        return compiled.is_blacklist
    end

    local any_slot_matched = false
    for i = 1, num_active do
        local slot = active_slots[i]
        local item_match = (payload_item == slot.item)
        local comp = slot.comp

        local match_res = false
        if comp == "=" then
            match_res = item_match
        elseif comp == "≠" or comp == "!=" then
            match_res = not item_match
        elseif comp == ">" or comp == "≥" or comp == ">=" then
            match_res = item_match
        elseif comp == "<" then
            match_res = not item_match
        elseif comp == "≤" or comp == "<=" then
            match_res = true
        else
            match_res = item_match
        end

        if match_res then
            any_slot_matched = true
            if not compiled.is_blacklist then
                return true
            end
        end
    end

    if compiled.is_blacklist then
        return not any_slot_matched
    else
        return any_slot_matched
    end
end

--- Fast-path diverter port filter validator
--- Short-circuits non-diverter entities in O(1) time before settings traversal
--- @param port_key string|nil
--- @param payload_item string|nil
--- @return boolean
local function check_diverter_port_filter(port_key, payload_item)
    if not port_key then return true end
    local diverter_settings_store = storage.diverter_settings
    if not diverter_settings_store then return true end

    local unit_number, port_index = capsule_queries.get_port_info(port_key)
    if not unit_number then return true end

    local d_settings = diverter_settings_store[unit_number]
    if not d_settings then return true end

    local port_setting = d_settings.ports and d_settings.ports[port_index]
    if not port_setting then return true end

    return evaluates_port_filter(port_setting, payload_item)
end

--- Checks whether hop movement is allowed by diverter filters at origin and target ports
--- @param from_port_key string
--- @param hop_key string
--- @param payload_item string|nil
--- @return boolean
local function is_hop_allowed_by_diverter_filters(from_port_key, hop_key, payload_item)
    if not check_diverter_port_filter(hop_key, payload_item) then
        return false
    end
    if not check_diverter_port_filter(from_port_key, payload_item) then
        return false
    end
    return true
end

function capsule_motion.get_node(port_key)
    if not (storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local flow_map = networks.get_metadata(net_id, "flow_map")
    return flow_map and flow_map[port_key]
end

function capsule_motion.get_port_world_pos(port_key)
    local node = capsule_motion.get_node(port_key)
    if node and node.entity and node.entity.valid then
        return {
            x = node.entity.position.x + node.offset.x,
            y = node.entity.position.y + node.offset.y
        }, node.entity.surface
    end
    return nil, nil
end

function capsule_motion.calculate_segment_speed(from_port_key, to_port_key)
    if not (from_port_key and to_port_key) then
        return MIN_SPEED_TILES_PER_SEC / 60.0
    end

    local node_from = capsule_motion.get_node(from_port_key)
    local node_to = capsule_motion.get_node(to_port_key)
    if not (node_from and node_to) then
        return BASE_SPEED_TILES_PER_SEC / 60.0
    end

    local p_from = (storage.port_pressures and storage.port_pressures[from_port_key]) or node_from.pressure or 0
    local p_to = (storage.port_pressures and storage.port_pressures[to_port_key]) or node_to.pressure or 0
    local is_internal = (node_from.unit_number == node_to.unit_number)

    local delta_p = 0
    if is_internal then
        delta_p = math.max(1.0, math.abs(p_from) * 0.10)
    else
        delta_p = math.max(0.1, math.abs(p_from - p_to))
    end

    local speed_multiplier = math.sqrt(delta_p)
    local tiles_per_sec = BASE_SPEED_TILES_PER_SEC * speed_multiplier
    tiles_per_sec = math.max(MIN_SPEED_TILES_PER_SEC, math.min(MAX_SPEED_TILES_PER_SEC, tiles_per_sec))

    return tiles_per_sec / 60.0
end

--- Pre-computes and caches segment parameters (positions, distance, speed, entities) on capsule
--- to eliminate tick-by-tick node lookups, physical entity coordinate queries, and math calculations mid-segment.
--- @param capsule table
--- @return boolean success
function capsule_motion.setup_segment(capsule)
    if not capsule then return false end

    local from_key = capsule.from_port_key
    if not from_key then
        capsule.seg_from_key = nil
        capsule.seg_to_key = nil
        capsule.entity_from = nil
        capsule.entity_to = nil
        return false
    end

    local node_from = capsule_motion.get_node(from_key)
    if not (node_from and node_from.entity and node_from.entity.valid) then
        capsule.seg_from_key = nil
        capsule.seg_to_key = nil
        capsule.entity_from = nil
        capsule.entity_to = nil
        return false
    end

    local ent_from = node_from.entity
    local from_x = ent_from.position.x + node_from.offset.x
    local from_y = ent_from.position.y + node_from.offset.y
    local surf = ent_from.surface

    local to_key = capsule.to_port_key
    if not to_key then
        -- Parked state setup
        capsule.seg_from_key = from_key
        capsule.seg_to_key = nil
        capsule.entity_from = ent_from
        capsule.entity_to = nil
        capsule.seg_from_x = from_x
        capsule.seg_from_y = from_y
        capsule.seg_to_x = from_x
        capsule.seg_to_y = from_y
        capsule.seg_dx = 0.0
        capsule.seg_dy = 0.0
        capsule.seg_dist = 0.0
        capsule.seg_speed = MIN_SPEED_TILES_PER_SEC / 60.0
        capsule.surface = surf
        return true
    end

    local node_to = capsule_motion.get_node(to_key)
    if not (node_to and node_to.entity and node_to.entity.valid) then
        capsule.seg_from_key = from_key
        capsule.seg_to_key = nil
        capsule.entity_from = ent_from
        capsule.entity_to = nil
        return false
    end

    local ent_to = node_to.entity
    local to_x = ent_to.position.x + node_to.offset.x
    local to_y = ent_to.position.y + node_to.offset.y

    local dx = to_x - from_x
    local dy = to_y - from_y
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Speed calculation using already retrieved nodes
    local p_from = (storage.port_pressures and storage.port_pressures[from_key]) or node_from.pressure or 0
    local p_to = (storage.port_pressures and storage.port_pressures[to_key]) or node_to.pressure or 0
    local is_internal = (node_from.unit_number == node_to.unit_number)

    local delta_p = 0
    if is_internal then
        delta_p = math.max(1.0, math.abs(p_from) * 0.10)
    else
        delta_p = math.max(0.1, math.abs(p_from - p_to))
    end

    local speed_multiplier = math.sqrt(delta_p)
    local tiles_per_sec = BASE_SPEED_TILES_PER_SEC * speed_multiplier
    tiles_per_sec = math.max(MIN_SPEED_TILES_PER_SEC, math.min(MAX_SPEED_TILES_PER_SEC, tiles_per_sec))
    local speed = tiles_per_sec / 60.0

    capsule.seg_from_key = from_key
    capsule.seg_to_key = to_key
    capsule.entity_from = ent_from
    capsule.entity_to = ent_to
    capsule.seg_from_x = from_x
    capsule.seg_from_y = from_y
    capsule.seg_to_x = to_x
    capsule.seg_to_y = to_y
    capsule.seg_dx = dx
    capsule.seg_dy = dy
    capsule.seg_dist = dist
    capsule.seg_speed = speed
    capsule.surface = surf

    return true
end

function capsule_motion.has_entity_network_capacity(from_port_key, target_port_key)
    if not (storage.networks and storage.networks.port_to_network) then return false end

    local target_unit = get_unit_number(target_port_key)
    local target_net_id = storage.networks.port_to_network[target_port_key]
    if not (target_unit and target_net_id) then return false end

    local current_unit = get_unit_number(from_port_key)
    local current_net_id = storage.networks.port_to_network[from_port_key]

    local same_segment = false
    local target_group = nil
    if current_unit == target_unit and current_net_id == target_net_id then
        target_group = capsule_queries.get_port_group(target_port_key)
        local current_group = capsule_queries.get_port_group(from_port_key)
        same_segment = (target_group == current_group)
    else
        target_group = capsule_queries.get_port_group(target_port_key)
    end

    local max_allowed = same_segment and MAX_CAPSULES_PER_ENTITY_NETWORK or (MAX_CAPSULES_PER_ENTITY_NETWORK - 1)
    local max_threshold = max_allowed + 1

    local count = capsule_queries.get_capsule_count_at_entity_network(target_unit, target_net_id, target_group, max_threshold)

    return count <= max_allowed
end

--- Recursively validates whether a candidate hop has entity capacity, filter permission,
--- and (for internal hops on multi-port entities) at least one open downstream path.
--- @param from_port_key string
--- @param target_port_key string
--- @param payload_item string|nil
--- @param depth number|nil
--- @return boolean
local function is_hop_valid(from_port_key, target_port_key, payload_item, depth)
    depth = depth or 1
    if depth > 3 then return false end

    if not capsule_motion.has_entity_network_capacity(from_port_key, target_port_key) then
        return false
    end

    if not is_hop_allowed_by_diverter_filters(from_port_key, target_port_key, payload_item) then
        return false
    end

    local current_node = capsule_motion.get_node(from_port_key)
    local target_node = capsule_motion.get_node(target_port_key)
    if not (current_node and target_node) then return false end

    local is_internal = (current_node.unit_number == target_node.unit_number)
    if is_internal then
        if not (target_node.outbound_hops and #target_node.outbound_hops > 0) then
            return false
        end

        local has_valid_downstream = false
        for _, next_hop in ipairs(target_node.outbound_hops) do
            if is_hop_valid(target_port_key, next_hop, payload_item, depth + 1) then
                has_valid_downstream = true
                break
            end
        end

        if not has_valid_downstream then
            return false
        end
    end

    return true
end

--- Evaluates all ports of a hub entity to find the optimal exit port with active outbound flow, valid capacity, and filter matching.
--- Evaluates payload characteristics from memory metadata without querying physical C++ inventories.
--- @param hub_entity LuaEntity
--- @param capsule_id number|nil
--- @param current_port_key string|nil
--- @return string|nil best_port_key
--- @return string|nil fallback_port_key
function capsule_motion.find_best_hub_outbound_port(hub_entity, capsule_id, current_port_key)
    if not (hub_entity and hub_entity.valid) then return nil, nil end

    local ports = port_defs.get_ports(hub_entity)
    if not ports then return nil, nil end

    local cap_data = capsule_id and capsule_manager.get(capsule_id)
    local payload_item = cap_data and cap_data.dominant_item
    if not payload_item and capsule_id then
        local cap = storage.capsules and storage.capsules[capsule_id]
        payload_item = cap and cap.dominant_item
    end
    if not payload_item and capsule_id then
        payload_item = capsule_renderer.get_dominant_item(capsule_id)
    end

    local best_port_key = nil
    local max_drop = -math.huge
    local fallback_port_key = nil

    for p_idx, _ in ipairs(ports) do
        local key = hub_entity.unit_number .. ":" .. p_idx
        local node = capsule_motion.get_node(key)

        if node then
            if not fallback_port_key then fallback_port_key = key end

            if node.outbound_hops then
                for _, hop_key in ipairs(node.outbound_hops) do
                    local target_node = capsule_motion.get_node(hop_key)
                    if target_node and target_node.unit_number ~= hub_entity.unit_number then
                        if is_hop_valid(key, hop_key, payload_item) then
                            local drop = node.pressure - target_node.pressure
                            if drop > max_drop or (drop == max_drop and key == current_port_key) then
                                max_drop = drop
                                best_port_key = key
                            end
                        end
                    end
                end
            end
        end
    end

    return best_port_key, fallback_port_key
end

function capsule_motion.select_next_target(capsule)
    local current_node = capsule_motion.get_node(capsule.from_port_key)
    if not (current_node and current_node.entity and current_node.entity.valid) then
        return nil
    end

    local entity = current_node.entity
    local hub_def = hub_defs.types[entity.name]
    local is_hub = (hub_def and hub_def.type == "hub")

    -- Re-evaluate hub ports if parked/stationary at a hub entity when flow updates
    if is_hub then
        local best_hub_port = capsule_motion.find_best_hub_outbound_port(entity, capsule.capsule_id or capsule.id, capsule.from_port_key)
        if best_hub_port and best_hub_port ~= capsule.from_port_key then
            capsule.from_port_key = best_hub_port
            capsule_queries.update_capsule_occupancy(capsule)
            current_node = capsule_motion.get_node(best_hub_port)
        end
    end

    if not (current_node and current_node.outbound_hops and #current_node.outbound_hops > 0) then
        return nil
    end

    -- Fast-path payload evaluation directly from cached primitive property on capsule object
    local payload_item = capsule.dominant_item
    if not payload_item then
        local cap_id = capsule.capsule_id or capsule.id
        local cap_data = cap_id and capsule_manager.get(cap_id)
        payload_item = cap_data and cap_data.dominant_item
        if not payload_item and cap_id then
            payload_item = capsule_renderer.get_dominant_item(cap_id)
            if payload_item then
                capsule.dominant_item = payload_item
            end
        end
    end

    local hops = current_node.outbound_hops
    local candidates = {}
    for _, hop_key in ipairs(hops) do
        local is_internal_hub_hop = false
        if is_hub then
            local target_unit = get_unit_number(hop_key)
            if target_unit == entity.unit_number then
                is_internal_hub_hop = true
            end
        end

        if not is_internal_hub_hop
           and hop_key ~= capsule.last_port_key 
           and is_hop_valid(capsule.from_port_key, hop_key, payload_item) then
            table.insert(candidates, hop_key)
        end
    end

    if #candidates == 0 then
        local backtrack_candidate = nil
        for _, hop_key in ipairs(hops) do
            local is_internal_hub_hop = false
            if is_hub then
                local target_unit = get_unit_number(hop_key)
                if target_unit == entity.unit_number then
                    is_internal_hub_hop = true
                end
            end

            if not is_internal_hub_hop
               and hop_key == capsule.last_port_key 
               and is_hop_valid(capsule.from_port_key, hop_key, payload_item) then
                backtrack_candidate = hop_key
                break
            end
        end

        if backtrack_candidate then
            local last_node = capsule_motion.get_node(capsule.last_port_key)
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

    local best_candidates = {}
    local max_drop = -math.huge

    for _, hop_key in ipairs(candidates) do
        local target_node = capsule_motion.get_node(hop_key)
        if target_node then
            local drop = -math.huge
            local is_internal = (target_node.unit_number == current_node.unit_number)

            if is_internal then
                if current_node.entity and current_node.entity.name == "pneumatic-pump" and target_node.pressure > current_node.pressure then
                    drop = math.huge
                else
                    local best_downstream = -math.huge
                    for _, next_hop in ipairs(target_node.outbound_hops) do
                        local next_node = capsule_motion.get_node(next_hop)
                        if next_node and next_node.unit_number ~= target_node.unit_number then
                            if is_hop_valid(hop_key, next_hop, payload_item) then
                                local d = current_node.pressure - next_node.pressure
                                if d > best_downstream then 
                                    best_downstream = d 
                                end
                            end
                        end
                    end
                    drop = (best_downstream ~= -math.huge) and best_downstream or 0
                end
            else
                drop = current_node.pressure - target_node.pressure
            end

            local is_ext = not is_internal

            if drop > max_drop then
                max_drop = drop
                best_candidates = { { key = hop_key, is_external = is_ext } }
            elseif drop == max_drop then
                local current_best_is_ext = best_candidates[1] and best_candidates[1].is_external
                if is_ext and not current_best_is_ext then
                    best_candidates = { { key = hop_key, is_external = true } }
                elseif not is_ext and current_best_is_ext then
                else
                    table.insert(best_candidates, { key = hop_key, is_external = is_ext })
                end
            end
        end
    end

    if #best_candidates == 0 then return nil end
    local chosen = best_candidates[math.random(#best_candidates)]
    return chosen.key
end

function capsule_motion.handle_arrival(capsule, id)
    local new_unit_num = get_unit_number(capsule.from_port_key)
    
    if capsule.source_hub and new_unit_num ~= capsule.source_hub then
        capsule.source_hub = nil
    end

    local node = capsule_motion.get_node(capsule.from_port_key)
    if node and node.entity and node.entity.valid then
        local hub_def = hub_defs.types[node.entity.name]
        if hub_def and capsule.source_hub ~= node.entity.unit_number then
            local unpacked = hub_unpacking.capture(capsule, node.entity)
            if unpacked then
                capsule_queries.remove_capsule(id)
                return true
            else
                capsule.to_port_key = nil
                capsule_queries.update_capsule_occupancy(capsule)
            end
        end
    end
    return false
end

return capsule_motion