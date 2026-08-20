local networks = require("scripts.networks.networks")
local port_defs = require("scripts.ports.port-definitions")
local network_join = {}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

function network_join.execute(entity_a, port_a_index, entity_b, port_b_index)
    networks.init()

    -- 1. Always record the physical connection edge
    networks.record_connection(entity_a.unit_number, port_a_index, entity_b.unit_number, port_b_index)

    local ports_a = port_defs.get_ports(entity_a)
    local ports_b = port_defs.get_ports(entity_b)
    local group_a = ports_a[port_a_index].group
    local group_b = ports_b[port_b_index].group

    local key_a = get_port_key(entity_a.unit_number, port_a_index)
    local key_b = get_port_key(entity_b.unit_number, port_b_index)

    local net_a = storage.networks.port_to_network[key_a]
    local net_b = storage.networks.port_to_network[key_b]

    -- Bind internal groups to ensure internal continuity on both sides
    if not net_a then
        net_a = networks.create()
        networks.bind_group_to_network(entity_a, group_a, net_a)
    end

    if not net_b then
        net_b = networks.create()
        networks.bind_group_to_network(entity_b, group_b, net_b)
    end

    game.print(string.format("[JOIN BOUNDARY] Edge created between Network #%d and Network #%d (Keeping IDs separate)", net_a, net_b))
end

return network_join