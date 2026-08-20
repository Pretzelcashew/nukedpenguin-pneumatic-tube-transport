local port_defs = require("scripts.ports.port-definitions")
local networks = {}

function networks.init()
    storage.networks = storage.networks or {}
    storage.networks.list = storage.networks.list or {}
    storage.networks.next_id = storage.networks.next_id or 1
    storage.networks.port_to_network = storage.networks.port_to_network or {}
    storage.port_connections = storage.port_connections or {}
end

function networks.create()
    networks.init()
    local id = storage.networks.next_id
    storage.networks.next_id = id + 1
    storage.networks.list[id] = { id = id, members = {} }
    return id
end

--- Records a physical edge connection between two ports
function networks.record_connection(unit_a, port_a_index, unit_b, port_b_index)
    networks.init()
    local key_a = unit_a .. ":" .. port_a_index
    local key_b = unit_b .. ":" .. port_b_index

    storage.port_connections[key_a] = storage.port_connections[key_a] or {}
    storage.port_connections[key_b] = storage.port_connections[key_b] or {}

    storage.port_connections[key_a][key_b] = true
    storage.port_connections[key_b][key_a] = true
end

--- Binds ALL ports sharing a specific group on an entity to a network
function networks.bind_group_to_network(entity, group_id, network_id)
    networks.init()
    local ports = port_defs.get_ports(entity)
    if not ports then return end

    for p_idx, p_data in ipairs(ports) do
        if p_data.group == group_id then
            local key = entity.unit_number .. ":" .. p_idx
            storage.networks.port_to_network[key] = network_id

            -- Ensure member isn't duplicated in list
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

    storage.networks.list[net_b_id] = nil
end

return networks