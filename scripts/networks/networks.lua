local networks = {}

--- Initializes network state inside Factorio's persistent storage table
function networks.init()
    storage.networks = storage.networks or {}
    storage.networks.list = storage.networks.list or {}
    storage.networks.next_id = storage.networks.next_id or 1
    storage.networks.port_to_network = storage.networks.port_to_network or {}
end

--- Creates a new network ID container inside storage
-- @return number
function networks.create()
    networks.init()
    local id = storage.networks.next_id
    storage.networks.next_id = id + 1
    storage.networks.list[id] = {
        id = id,
        members = {}
    }
    return id
end

--- Adds a port member to a network using entity unit_number
-- @param network_id number
-- @param unit_number number
-- @param port_index number
function networks.add_member(network_id, unit_number, port_index)
    networks.init()
    local net = storage.networks.list[network_id]
    if not net then return end

    table.insert(net.members, {
        unit_number = unit_number,
        port_index = port_index
    })
end

--- Merges network_b into network_a and updates all port mappings
-- @param net_a_id number Target network ID
-- @param net_b_id number Source network ID to absorb
function networks.merge(net_a_id, net_b_id)
    networks.init()
    local net_a = storage.networks.list[net_a_id]
    local net_b = storage.networks.list[net_b_id]
    if not (net_a and net_b) then return end

    -- Transfer members from network B to network A and update port keys
    for _, member in ipairs(net_b.members) do
        table.insert(net_a.members, member)
        local key = member.unit_number .. ":" .. member.port_index
        storage.networks.port_to_network[key] = net_a_id
    end

    -- Delete old network container
    storage.networks.list[net_b_id] = nil
end

return networks