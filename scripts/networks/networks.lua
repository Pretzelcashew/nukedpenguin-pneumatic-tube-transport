-- scripts/networks/networks.lua
local networks = {}

-- Storage for active network IDs and their registered members
networks.list = {}
local next_network_id = 1

--- Creates a new network ID container
-- @return number
function networks.create()
    local id = next_network_id
    next_network_id = next_network_id + 1
    networks.list[id] = {
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
    local net = networks.list[network_id]
    if not net then return end

    table.insert(net.members, {
        unit_number = unit_number,
        port_index = port_index
    })
end

return networks