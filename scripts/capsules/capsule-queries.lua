local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")

local MAX_CAPSULES_PER_ENTITY_NETWORK = 1

local capsule_queries = {}

-- Fast memoization cache for port key string parsing ("101:1" -> unit_number=101, port_index=1)
local port_info_cache = {}

--- Efficiently gets unit_number and port_index from a port_key string without repeated string allocations
--- @param port_key string|nil
--- @return number|nil unit_number
--- @return number|nil port_index
function capsule_queries.get_port_info(port_key)
    if not port_key then return nil, nil end
    local info = port_info_cache[port_key]
    if info then
        return info.unit_number, info.port_index
    end

    local colon = string.find(port_key, ":", 1, true)
    if colon then
        local u_num = tonumber(string.sub(port_key, 1, colon - 1))
        local p_idx = tonumber(string.sub(port_key, colon + 1))
        if u_num and p_idx then
            info = { unit_number = u_num, port_index = p_idx }
            port_info_cache[port_key] = info
            return u_num, p_idx
        end
    end
    return nil, nil
end

--- Ensures storage.occupancy structure is initialized
local function ensure_occupancy_storage()
    if not storage.occupancy then
        storage.occupancy = {
            by_entity_net_group = {}, -- [unit_number][net_id][group] = { caps = { [id] = true }, count = N }
            by_entity_from = {},      -- [unit_number] = { caps = { [id] = true }, count = N }
            by_entity_all = {}        -- [unit_number] = { [id] = true }
        }
    end
end

--- Returns the port group ID (e.g. 1 or 2) for a given port key string ("unit_number:port_index")
--- @param port_key string
--- @return number|nil
function capsule_queries.get_port_group(port_key)
    if not (port_key and storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local flow_map = networks.get_metadata(net_id, "flow_map")
    local node = flow_map and flow_map[port_key]
    if not node then return nil end

    if node.group ~= nil then
        return node.group ~= false and node.group or nil
    end

    if not (node.entity and node.entity.valid and node.port_index) then return nil end

    local ports = port_defs.get_ports(node.entity)
    local port_def = ports and ports[node.port_index]
    local group = port_def and port_def.group
    node.group = (group ~= nil) and group or false
    return group
end

--- Helper to resolve (unit_number, net_id, group) tuple for a given port_key
--- @param port_key string|nil
--- @return number|nil unit_number
--- @return number|nil net_id
--- @return number|nil group
local function get_port_descriptor(port_key)
    if not port_key then return nil, nil, nil end
    local unit_number = capsule_queries.get_port_info(port_key)
    if not unit_number then return nil, nil, nil end

    local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[port_key]
    local group = capsule_queries.get_port_group(port_key) or 0
    return unit_number, net_id, group
end

--- Internal helper to add a capsule to a specific (unit_number, net_id, group) occupancy bucket
local function add_occupancy_entry(id, unit_num, net_id, group)
    ensure_occupancy_storage()

    if net_id then
        local net_map = storage.occupancy.by_entity_net_group[unit_num]
        if not net_map then
            net_map = {}
            storage.occupancy.by_entity_net_group[unit_num] = net_map
        end
        local group_map = net_map[net_id]
        if not group_map then
            group_map = {}
            net_map[net_id] = group_map
        end
        local slot = group_map[group]
        if not slot then
            slot = { caps = {}, count = 0 }
            group_map[group] = slot
        end
        if not slot.caps[id] then
            slot.caps[id] = true
            slot.count = slot.count + 1
        end
    end

    local all_map = storage.occupancy.by_entity_all[unit_num]
    if not all_map then
        all_map = {}
        storage.occupancy.by_entity_all[unit_num] = all_map
    end
    all_map[id] = true
end

--- Internal helper to remove a capsule from a specific (unit_number, net_id, group) occupancy bucket
local function remove_occupancy_entry(id, unit_num, net_id, group)
    if not storage.occupancy then return end

    if net_id then
        local net_map = storage.occupancy.by_entity_net_group[unit_num]
        local group_map = net_map and net_map[net_id]
        local slot = group_map and group_map[group]
        if slot and slot.caps[id] then
            slot.caps[id] = nil
            slot.count = slot.count - 1
            if slot.count <= 0 then
                group_map[group] = nil
                if next(group_map) == nil then
                    net_map[net_id] = nil
                    if next(net_map) == nil then
                        storage.occupancy.by_entity_net_group[unit_num] = nil
                    end
                end
            end
        end
    end
end

--- Unregisters a capsule from all O(1) occupancy tracking buckets
--- @param id number
function capsule_queries.unregister_capsule_occupancy(id)
    if not (id and storage.capsules and storage.occupancy) then return end
    local capsule = storage.capsules[id]
    
    local old_from_key = capsule and capsule._occ_from_key
    local old_to_key = capsule and capsule._occ_to_key

    if old_from_key then
        local f_unit, f_net, f_group = get_port_descriptor(old_from_key)
        if f_unit then
            remove_occupancy_entry(id, f_unit, f_net, f_group)

            local from_slot = storage.occupancy.by_entity_from[f_unit]
            if from_slot and from_slot.caps[id] then
                from_slot.caps[id] = nil
                from_slot.count = from_slot.count - 1
                if from_slot.count <= 0 then
                    storage.occupancy.by_entity_from[f_unit] = nil
                end
            end

            local all_map = storage.occupancy.by_entity_all[f_unit]
            if all_map then
                all_map[id] = nil
                if next(all_map) == nil then
                    storage.occupancy.by_entity_all[f_unit] = nil
                end
            end
        end
    end

    if old_to_key then
        local t_unit, t_net, t_group = get_port_descriptor(old_to_key)
        if t_unit then
            remove_occupancy_entry(id, t_unit, t_net, t_group)

            local all_map = storage.occupancy.by_entity_all[t_unit]
            if all_map then
                all_map[id] = nil
                if next(all_map) == nil then
                    storage.occupancy.by_entity_all[t_unit] = nil
                end
            end
        end
    end

    if capsule then
        capsule._occ_from_key = nil
        capsule._occ_to_key = nil
    end
end

--- Updates the O(1) occupancy tracking index for a capsule
--- @param capsule table
function capsule_queries.update_capsule_occupancy(capsule)
    if not capsule then return end
    local id = capsule.id or capsule.capsule_id
    if not id then return end

    ensure_occupancy_storage()

    local new_from_key = capsule.from_port_key
    local new_to_key = capsule.to_port_key

    -- Fast-path return if port keys haven't changed
    if capsule._occ_from_key == new_from_key and capsule._occ_to_key == new_to_key then
        return
    end

    capsule_queries.unregister_capsule_occupancy(id)

    capsule._occ_from_key = new_from_key
    capsule._occ_to_key = new_to_key

    local f_unit, f_net, f_group = get_port_descriptor(new_from_key)
    local t_unit, t_net, t_group = get_port_descriptor(new_to_key)

    if f_unit then
        add_occupancy_entry(id, f_unit, f_net, f_group)

        local from_slot = storage.occupancy.by_entity_from[f_unit]
        if not from_slot then
            from_slot = { caps = {}, count = 0 }
            storage.occupancy.by_entity_from[f_unit] = from_slot
        end
        if not from_slot.caps[id] then
            from_slot.caps[id] = true
            from_slot.count = from_slot.count + 1
        end
    end

    if t_unit then
        if not (t_unit == f_unit and t_net == f_net and t_group == f_group) then
            add_occupancy_entry(id, t_unit, t_net, t_group)
        else
            local all_map = storage.occupancy.by_entity_all[t_unit]
            if not all_map then
                all_map = {}
                storage.occupancy.by_entity_all[t_unit] = all_map
            end
            all_map[id] = true
        end
    end
end

--- Rebuilds the complete O(1) capsule occupancy index from storage.capsules
function capsule_queries.rebuild_occupancy_index()
    storage.occupancy = {
        by_entity_net_group = {},
        by_entity_from = {},
        by_entity_all = {}
    }
    if not storage.capsules then return end
    for id, capsule in pairs(storage.capsules) do
        capsule._occ_from_key = nil
        capsule._occ_to_key = nil
        capsule_queries.update_capsule_occupancy(capsule)
    end
end

--- Destroys the visual rendering object(s) associated with a capsule and clears cache metadata
--- @param capsule table
function capsule_queries.clear_capsule_render(capsule)
    if capsule then
        if capsule.render_id then
            if type(capsule.render_id) == "table" then
                for _, render_obj in ipairs(capsule.render_id) do
                    if render_obj and render_obj.valid then
                        render_obj.destroy()
                    end
                end
            elseif capsule.render_id.valid then
                capsule.render_id.destroy()
            end
            capsule.render_id = nil
        end
        capsule.render_cache = nil
    end
end

--- Removes a capsule from motion tracking and clears its visual debug render and occupancy tracking
--- @param id number
function capsule_queries.remove_capsule(id)
    if not storage.capsules then return end
    local capsule = storage.capsules[id]
    if capsule then
        capsule_queries.unregister_capsule_occupancy(id)
        capsule_queries.clear_capsule_render(capsule)
        storage.capsules[id] = nil
    end
end

--- Finds all active capsule runner IDs currently located at or heading to/from an entity
--- @param unit_number number
--- @return table<number>
function capsule_queries.find_capsules_at_entity(unit_number)
    if not (unit_number and storage.capsules) then return {} end
    if not storage.occupancy then
        capsule_queries.rebuild_occupancy_index()
    end
    local caps = storage.occupancy.by_entity_all[unit_number]
    if not caps then return {} end

    local matches = {}
    for id in pairs(caps) do
        table.insert(matches, id)
    end
    return matches
end

--- Checks how many capsules are currently occupying the entity's ports
--- @param unit_number number
--- @return number
function capsule_queries.get_capsule_count_at_entity(unit_number)
    if not (unit_number and storage.capsules) then return 0 end
    if not storage.occupancy then
        capsule_queries.rebuild_occupancy_index()
    end
    local slot = storage.occupancy.by_entity_from[unit_number]
    return slot and slot.count or 0
end

--- Checks how many capsules occupy a specific entity's internal/external network segment and port group
--- @param unit_number number
--- @param net_id number
--- @param target_port_key_or_group string|number|nil
--- @param max_threshold number|nil Optional threshold limit for early exit once count reaches max_threshold
--- @return number
function capsule_queries.get_capsule_count_at_entity_network(unit_number, net_id, target_port_key_or_group, max_threshold)
    if not (unit_number and net_id and storage.capsules) then
        return 0
    end

    if not storage.occupancy then
        capsule_queries.rebuild_occupancy_index()
    end

    local net_map = storage.occupancy.by_entity_net_group[unit_number]
    local group_map = net_map and net_map[net_id]
    if not group_map then return 0 end

    local target_group = nil
    if type(target_port_key_or_group) == "number" then
        target_group = target_port_key_or_group
    elseif type(target_port_key_or_group) == "string" then
        target_group = capsule_queries.get_port_group(target_port_key_or_group)
    end

    if target_group then
        local slot = group_map[target_group]
        local count = slot and slot.count or 0
        if max_threshold and count >= max_threshold then
            return max_threshold
        end
        return count
    else
        local count = 0
        local unique_caps = nil
        for _, slot in pairs(group_map) do
            if slot and slot.count > 0 then
                if not unique_caps then
                    unique_caps = {}
                end
                for id in pairs(slot.caps) do
                    if not unique_caps[id] then
                        unique_caps[id] = true
                        count = count + 1
                        if max_threshold and count >= max_threshold then
                            return max_threshold
                        end
                    end
                end
            end
        end
        return count
    end
end

return capsule_queries