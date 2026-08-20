-- scripts/networks/networks.lua
local port_defs = require("scripts.ports.port-definitions")
local networks = {}

function networks.init()
    storage.networks = storage.networks or {}
    storage.networks.list = storage.networks.list or {}
    storage.networks.next_id = storage.networks.next_id or 1
    storage.networks.recycled_ids = storage.networks.recycled_ids or {} -- NEW: Stack of free IDs
    storage.networks.port_to_network = storage.networks.port_to_network or {}
    storage.port_connections = storage.port_connections or {}
end

--- Retrieves an ID from the recycle pool, or generates a new one if empty
function networks.create()
    networks.init()
    local id
    local recycle_count = #storage.networks.recycled_ids
    
    if recycle_count > 0 then
        -- Pop the last ID off the recycled stack
        id = storage.networks.recycled_ids[recycle_count]
        table.remove(storage.networks.recycled_ids, recycle_count)
    else
        -- Fallback: generate a new ID
        id = storage.networks.next_id
        storage.networks.next_id = id + 1
    end

    storage.networks.list[id] = { id = id, members = {} }
    return id
end

--- Safely destroys a network and adds its ID to the recycle pool
function networks.delete(network_id)
    networks.init()
    if storage.networks.list[network_id] then
        storage.networks.list[network_id] = nil
        table.insert(storage.networks.recycled_ids, network_id)
    end
end

--- Records a physical or internal edge connection between two ports along with its type
function networks.record_connection(unit_a, port_a_index, unit_b, port_b_index, conn_type)
    networks.init()
    local key_a = unit_a .. ":" .. port_a_index
    local key_b = unit_b .. ":" .. port_b_index

    storage.port_connections[key_a] = storage.port_connections[key_a] or {}
    storage.port_connections[key_b] = storage.port_connections[key_b] or {}

    storage.port_connections[key_a][key_b] = conn_type
    storage.port_connections[key_b][key_a] = conn_type
end

--- Removes an edge connection between two port keys
function networks.remove_connection(key_a, key_b)
    networks.init()
    if storage.port_connections[key_a] then
        storage.port_connections[key_a][key_b] = nil
        if next(storage.port_connections[key_a]) == nil then
            storage.port_connections[key_a] = nil
        end
    end

    if storage.port_connections[key_b] then
        storage.port_connections[key_b][key_a] = nil
        if next(storage.port_connections[key_b]) == nil then
            storage.port_connections[key_b] = nil
        end
    end
end

--- Binds ALL ports sharing a specific group on an entity to a network
function networks.bind_group_to_network(entity, group_id, network_id)
    networks.init()
    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local group_ports = {}

    for p_idx, p_data in ipairs(ports) do
        if p_data.group == group_id then
            table.insert(group_ports, p_idx)
            local key = entity.unit_number .. ":" .. p_idx
            storage.networks.port_to_network[key] = network_id

            local net = storage.networks.list[network_id]
            if net then
                local exists = false
                for _, m in ipairs(net.members) do
                    if m.unit_number == entity.unit_number and m.port_index == p_idx then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(net.members, { unit_number = entity.unit_number, port_index = p_idx })
                end
            end
        end
    end

    for i = 1, #group_ports do
        for j = i + 1, #group_ports do
            networks.record_connection(entity.unit_number, group_ports[i], entity.unit_number, group_ports[j], "merge")
        end
    end
end

function networks.merge(net_a_id, net_b_id)
    networks.init()
    local net_a = storage.networks.list[net_a_id]
    local net_b = storage.networks.list[net_b_id]
    if not (net_a and net_b) then return end

    for _, member in ipairs(net_b.members) do
        table.insert(net_a.members, member)
        local key = member.unit_number .. ":" .. member.port_index
        storage.networks.port_to_network[key] = net_a_id
    end

    -- Recycle the absorbed network's ID instead of just setting it to nil
    networks.delete(net_b_id)
end

--- Purges network mappings and connections for a specific port key
function networks.purge_port(port_key)
    networks.init()
    
    if storage.port_connections then
        storage.port_connections[port_key] = nil
    end
    
    if storage.networks and storage.networks.port_to_network then
        local net_id = storage.networks.port_to_network[port_key]
        storage.networks.port_to_network[port_key] = nil
        
        -- Clean up the member list and check for an empty network
        if net_id and storage.networks.list[net_id] then
            local net = storage.networks.list[net_id]
            
            -- Remove this specific port from the network members array
            for i = #net.members, 1, -1 do
                local m = net.members[i]
                if (m.unit_number .. ":" .. m.port_index) == port_key then
                    table.remove(net.members, i)
                    break
                end
            end
            
            -- If the network is now completely empty, recycle its ID
            if #net.members == 0 then
                networks.delete(net_id)
                game.print(string.format("[NETWORK RECYCLED] Network #%d is empty and was recycled.", net_id))
            end
        end
    end
end

return networks