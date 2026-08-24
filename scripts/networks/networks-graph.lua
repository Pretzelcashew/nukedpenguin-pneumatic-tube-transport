-- scripts/networks/networks-graph.lua
local port_defs = require("scripts.ports.port-definitions")
local networks_store = require("scripts.networks.networks-store")

local networks_graph = {}

function networks_graph.record_connection(unit_a, port_a_index, unit_b, port_b_index, conn_type)
    networks_store.init()
    local key_a = unit_a .. ":" .. port_a_index
    local key_b = unit_b .. ":" .. port_b_index

    storage.port_connections[key_a] = storage.port_connections[key_a] or {}
    storage.port_connections[key_b] = storage.port_connections[key_b] or {}

    storage.port_connections[key_a][key_b] = conn_type
    storage.port_connections[key_b][key_a] = conn_type
end

function networks_graph.remove_connection(key_a, key_b)
    networks_store.init()
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

function networks_graph.bind_group_to_network(entity, group_id, network_id)
    networks_store.init()
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
                    table.insert(net.members, { 
                        unit_number = entity.unit_number, 
                        port_index = p_idx,
                        entity = entity
                    })
                end
            end
        end
    end

    for i = 1, #group_ports do
        for j = i + 1, #group_ports do
            networks_graph.record_connection(entity.unit_number, group_ports[i], entity.unit_number, group_ports[j], "merge")
        end
    end
end

return networks_graph