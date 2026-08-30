local networks = require("scripts.networks.networks")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_unpacking = require("scripts.hubs.hub-unpacking")
local capsule_queries = require("scripts.capsules.capsule-queries")
local diverter_settings = require("scripts.diverter-settings")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local port_defs = require("scripts.ports.port-definitions")

local MAX_CAPSULES_PER_ENTITY_NETWORK = 1
local BASE_SPEED_TILES_PER_SEC = 15
local MIN_SPEED_TILES_PER_SEC = 4
local MAX_SPEED_TILES_PER_SEC = 60

local capsule_motion = {}

--- Efficiently retrieves the unit_number from a port_key ("unit_number:port_index")
--- Uses node metadata if available, falling back to fast plain string sub without regex.
--- @param port_key string|nil
--- @return number|nil unit_number
local function get_unit_number(port_key)
    if not port_key then return nil end
    local node = capsule_motion.get_node(port_key)
    if node and node.unit_number then
        return node.unit_number
    end
    local colon = string.find(port_key, ":", 1, true)
    return colon and tonumber(string.sub(port_key, 1, colon - 1))
end

local function evaluate_filter_slot(slot, payload_item)
    if not slot then return nil end
    local filter_item = slot.item or slot.signal
    if not filter_item then return nil end

    local item_match = (payload_item == filter_item)
    local comp = slot.comparator or "="

    if comp == "=" then
        return item_match
    elseif comp == "≠" or comp == "!=" then
        return not item_match
    elseif comp == ">" or comp == "≥" or comp == ">=" then
        return item_match
    elseif comp == "<" then
        return not item_match
    elseif comp == "≤" or comp == "<=" then
        return true
    end

    return item_match
end

local function evaluates_port_filter(port_setting, payload_item)
    if not (port_setting and port_setting.use_filters) then
        return true
    end

    if not payload_item then
        return port_setting.filter_mode == "blacklist"
    end

    local filter_mode = port_setting.filter_mode or "whitelist"
    local filters = port_setting.filters
    if not filters then return true end

    local has_configured_slots = false
    local any_slot_matched = false

    for i = 1, 5 do
        local slot = filters[i]
        local match_res = evaluate_filter_slot(slot, payload_item)
        if match_res ~= nil then
            has_configured_slots = true
            if match_res == true then
                any_slot_matched = true
            end
        end
    end

    if not has_configured_slots then
        return filter_mode == "blacklist"
    end

    if filter_mode == "whitelist" then
        return any_slot_matched
    else
        return not any_slot_matched
    end
end

local function check_diverter_port_filter(port_key, payload_item)
    if not (port_key and storage.diverter_settings) then return true end

    local node = capsule_motion.get_node(port_key)
    local unit_number, port_index
    if node then
        unit_number = node.unit_number
        port_index = node.port_index
    else
        local colon = string.find(port_key, ":", 1, true)
        if not colon then return true end
        unit_number = tonumber(string.sub(port_key, 1, colon - 1))
        port_index = tonumber(string.sub(port_key, colon + 1))
    end
    if not (unit_number and port_index) then return true end

    local d_settings = storage.diverter_settings[unit_number]
    if not (d_settings and d_settings.ports) then return true end

    local port_setting = d_settings.ports[port_index]
    if not port_setting then return true end

    return evaluates_port_filter(port_setting, payload_item)
end

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
--- @param payload_item table|nil
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
--- @param hub_entity LuaEntity
--- @param capsule_id number|nil
--- @param current_port_key string|nil
--- @return string|nil best_port_key
--- @return string|nil fallback_port_key
function capsule_motion.find_best_hub_outbound_port(hub_entity, capsule_id, current_port_key)
    if not (hub_entity and hub_entity.valid) then return nil, nil end

    local ports = port_defs.get_ports(hub_entity)
    if not ports then return nil, nil end

    local payload_item = capsule_renderer.get_dominant_item(capsule_id)
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
            current_node = capsule_motion.get_node(best_hub_port)
        end
    end

    if not (current_node and current_node.outbound_hops and #current_node.outbound_hops > 0) then
        return nil
    end

    local payload_item = capsule_renderer.get_dominant_item(capsule.capsule_id or capsule.id)

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
                capsule_queries.clear_capsule_render(capsule)
                storage.capsules[id] = nil
                return true
            else
                capsule.to_port_key = nil
            end
        end
    end
    return false
end

return capsule_motion