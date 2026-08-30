local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")

local MAX_CAPSULES_PER_ENTITY_NETWORK = 1

local capsule_queries = {}

--- Returns the port group ID (e.g. 1 or 2) for a given port key string ("unit_number:port_index")
--- @param port_key string
--- @return number|nil
function capsule_queries.get_port_group(port_key)
    if not (port_key and storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local flow_map = networks.get_metadata(net_id, "flow_map")
    local node = flow_map and flow_map[port_key]
    if not (node and node.entity and node.entity.valid and node.port_index) then return nil end

    local ports = port_defs.get_ports(node.entity)
    local port_def = ports and ports[node.port_index]
    return port_def and port_def.group
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

--- Removes a capsule from motion tracking and clears its visual debug render
--- @param id number
function capsule_queries.remove_capsule(id)
    if not storage.capsules then return end
    local capsule = storage.capsules[id]
    if capsule then
        capsule_queries.clear_capsule_render(capsule)
        storage.capsules[id] = nil
    end
end

--- Finds all active capsule runner IDs currently located at or heading to/from an entity
--- @param unit_number number
--- @return table<number>
function capsule_queries.find_capsules_at_entity(unit_number)
    if not storage.capsules then return {} end
    local prefix = tostring(unit_number) .. ":"
    local prefix_len = #prefix
    local matches = {}

    for id, cap in pairs(storage.capsules) do
        local at_from = cap.from_port_key and string.sub(cap.from_port_key, 1, prefix_len) == prefix
        local at_to = cap.to_port_key and string.sub(cap.to_port_key, 1, prefix_len) == prefix
        if at_from or at_to then
            table.insert(matches, id)
        end
    end

    return matches
end

--- Checks how many capsules are currently occupying the entity's ports
--- @param unit_number number
--- @return number
function capsule_queries.get_capsule_count_at_entity(unit_number)
    if not storage.capsules then return 0 end
    local count = 0
    local prefix = tostring(unit_number) .. ":"
    local prefix_len = #prefix

    for _, cap in pairs(storage.capsules) do
        if cap.from_port_key and string.sub(cap.from_port_key, 1, prefix_len) == prefix then
            count = count + 1
        end
    end
    return count
end

--- Checks how many capsules occupy a specific entity's internal/external network segment and port group
--- @param unit_number number
--- @param net_id number
--- @param target_port_key_or_group string|number|nil
--- @return number
function capsule_queries.get_capsule_count_at_entity_network(unit_number, net_id, target_port_key_or_group)
    if not (unit_number and net_id and storage.capsules and storage.networks and storage.networks.port_to_network) then
        return 0
    end

    local target_group = nil
    if type(target_port_key_or_group) == "number" then
        target_group = target_port_key_or_group
    elseif type(target_port_key_or_group) == "string" then
        target_group = capsule_queries.get_port_group(target_port_key_or_group)
    end

    local count = 0
    local port_to_net = storage.networks.port_to_network
    local prefix = tostring(unit_number) .. ":"
    local prefix_len = #prefix

    for _, cap in pairs(storage.capsules) do
        local is_at_from = cap.from_port_key 
            and string.sub(cap.from_port_key, 1, prefix_len) == prefix 
            and port_to_net[cap.from_port_key] == net_id
            and (not target_group or capsule_queries.get_port_group(cap.from_port_key) == target_group)

        local is_at_to = cap.to_port_key 
            and string.sub(cap.to_port_key, 1, prefix_len) == prefix 
            and port_to_net[cap.to_port_key] == net_id
            and (not target_group or capsule_queries.get_port_group(cap.to_port_key) == target_group)

        if is_at_from or is_at_to then
            count = count + 1
        end
    end
    return count
end

return capsule_queries