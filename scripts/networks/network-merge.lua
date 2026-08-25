local networks = require("scripts.networks.networks")
local port_defs = require("scripts.ports.port-definitions")
local network_merge = {}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

function network_merge.execute(entity_a, port_a_index, entity_b, port_b_index)
    networks.init()
    
    -- Explicitly record connection type as "merge"
    networks.record_connection(entity_a.unit_number, port_a_index, entity_b.unit_number, port_b_index, "merge")

    local ports_a = port_defs.get_ports(entity_a)
    local ports_b = port_defs.get_ports(entity_b)
    local group_a = ports_a[port_a_index].group
    local group_b = ports_b[port_b_index].group

    local key_a = get_port_key(entity_a.unit_number, port_a_index)
    local key_b = get_port_key(entity_b.unit_number, port_b_index)

    local net_a = storage.networks.port_to_network[key_a]
    local net_b = storage.networks.port_to_network[key_b]

    if not net_a and not net_b then
        local new_net_id = networks.create()
        networks.bind_group_to_network(entity_a, group_a, new_net_id)
        networks.bind_group_to_network(entity_b, group_b, new_net_id)
        debug_print(string.format("[MERGE CREATED #%d] Expanded internal groups for Unit %d <-> Unit %d", new_net_id, entity_a.unit_number, entity_b.unit_number))

    elseif net_a and not net_b then
        networks.bind_group_to_network(entity_b, group_b, net_a)
        debug_print(string.format("[MERGE ADD] Added Unit %d (Group %d) to Network #%d", entity_b.unit_number, group_b, net_a))

    elseif not net_a and net_b then
        networks.bind_group_to_network(entity_a, group_a, net_b)
        debug_print(string.format("[MERGE ADD] Added Unit %d (Group %d) to Network #%d", entity_a.unit_number, group_a, net_b))

    elseif net_a ~= net_b then
        networks.merge(net_a, net_b)
        debug_print(string.format("[MERGE ACTION] Combined Network #%d into Network #%d", net_b, net_a))
    end
end

return network_merge