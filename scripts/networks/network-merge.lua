local networks = require("scripts.networks.networks")
local network_merge = {}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

function network_merge.execute(entity_a, port_a_index, entity_b, port_b_index)
    networks.init()
    local port_to_net = storage.networks.port_to_network

    local unit_a, unit_b = entity_a.unit_number, entity_b.unit_number
    if not (unit_a and unit_b) then return end

    local key_a, key_b = get_port_key(unit_a, port_a_index), get_port_key(unit_b, port_b_index)
    local net_a, net_b = port_to_net[key_a], port_to_net[key_b]

    if not net_a and not net_b then
        local new_net_id = networks.create()
        networks.add_member(new_net_id, unit_a, port_a_index)
        networks.add_member(new_net_id, unit_b, port_b_index)
    elseif net_a and not net_b then
        networks.add_member(net_a, unit_b, port_b_index)
    elseif not net_a and net_b then
        networks.add_member(net_b, unit_a, port_a_index)
    elseif net_a ~= net_b then
        -- Tube-to-tube MERGE boundary: Collapse Network B into Network A
        networks.merge(net_a, net_b)
        game.print(string.format("[NETWORK MERGED] Absorbed Network #%d into Network #%d", net_b, net_a))
    end
end

return network_merge