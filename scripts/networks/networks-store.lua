-- scripts/networks/networks-store.lua
local networks_store = {}

function networks_store.init()
    storage.networks = storage.networks or {}
    storage.networks.list = storage.networks.list or {}
    storage.networks.next_id = storage.networks.next_id or 1
    storage.networks.recycled_ids = storage.networks.recycled_ids or {}
    storage.networks.port_to_network = storage.networks.port_to_network or {}
    storage.port_connections = storage.port_connections or {}
end

function networks_store.create()
    networks_store.init()
    local id
    local recycle_count = #storage.networks.recycled_ids
    
    if recycle_count > 0 then
        id = storage.networks.recycled_ids[recycle_count]
        table.remove(storage.networks.recycled_ids, recycle_count)
    else
        id = storage.networks.next_id
        storage.networks.next_id = id + 1
    end

    -- A clean dictionary for modular data storage
    storage.networks.list[id] = { 
        id = id, 
        members = {}, 
        metadata = {} 
    }
    return id
end

--- Allows external modules to write data to a specific namespace within the network
function networks_store.set_metadata(network_id, module_key, data)
    networks_store.init()
    local net = storage.networks.list[network_id]
    if net then
        net.metadata[module_key] = data
    end
end

--- Allows external modules to read data from their specific namespace
function networks_store.get_metadata(network_id, module_key)
    networks_store.init()
    local net = storage.networks.list[network_id]
    if net then
        return net.metadata[module_key]
    end
    return nil
end

--- Detaches the entire metadata block cleanly without deleting the network
function networks_store.extract_metadata(network_id)
    networks_store.init()
    local net = storage.networks.list[network_id]
    if net and net.metadata then
        local detached_metadata = net.metadata
        net.metadata = {} -- Wipe it from the object so it isn't duplicated
        return detached_metadata
    end
    return {}
end

--- Deletes the network and returns all metadata for handoff
function networks_store.delete(network_id)
    networks_store.init()
    local all_metadata = {}
    
    if storage.networks.list[network_id] then
        all_metadata = storage.networks.list[network_id].metadata
        storage.networks.list[network_id] = nil
        table.insert(storage.networks.recycled_ids, network_id)
    end
    
    return all_metadata
end

function networks_store.merge(net_a_id, net_b_id)
    networks_store.init()
    local net_a = storage.networks.list[net_a_id]
    local net_b = storage.networks.list[net_b_id]
    if not (net_a and net_b) then return nil end

    for _, member in ipairs(net_b.members) do
        table.insert(net_a.members, member)
        local key = member.unit_number .. ":" .. member.port_index
        storage.networks.port_to_network[key] = net_a_id
    end

    -- Network B is destroyed, return its metadata so the caller 
    -- can handle combining it into Network A's metadata.
    return networks_store.delete(net_b_id)
end

function networks_store.purge_port(port_key)
    networks_store.init()
    
    if storage.port_connections then
        storage.port_connections[port_key] = nil
    end
    
    if storage.networks and storage.networks.port_to_network then
        local net_id = storage.networks.port_to_network[port_key]
        storage.networks.port_to_network[port_key] = nil
        
        if net_id and storage.networks.list[net_id] then
            local net = storage.networks.list[net_id]
            
            for i = #net.members, 1, -1 do
                local m = net.members[i]
                if (m.unit_number .. ":" .. m.port_index) == port_key then
                    table.remove(net.members, i)
                    break
                end
            end
            
            -- Emptied networks are recycled, handing off the metadata packet
            if #net.members == 0 then
                local all_metadata = networks_store.delete(net_id)
                game.print(string.format("[NETWORK RECYCLED] Network #%d is empty and was recycled.", net_id))
                return all_metadata
            end
        end
    end
    return nil
end

return networks_store