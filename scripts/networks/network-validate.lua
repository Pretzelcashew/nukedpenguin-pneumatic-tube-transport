-- scripts/networks/network-validate.lua
local port_defs = require("scripts.ports.port-definitions")
local port_finder = require("scripts.ports.port-finder")
local port_evaluator = require("scripts.ports.port-evaluator")
local connection_defs = require("scripts.ports.port-connection-definitions")
local network_form_internals = require("scripts.networks.network-form-internals")
local networks_flow = require("scripts.networks.networks-flow")

local network_validate = {}

function network_validate.execute(entity)
    if not (entity and entity.valid) then return end

    network_form_internals.execute(entity)

    local spatial_connections = port_finder.find_connections(entity)

    for _, conn in ipairs(spatial_connections) do
        local is_compatible, outcome = port_evaluator.are_compatible(
            entity, 
            conn.port_index, 
            conn.neighbor, 
            conn.neighbor_port_index
        )

        if is_compatible and outcome then
            local def = connection_defs.types[outcome]
            
            if def and def.handler then
                def.handler(entity, conn.port_index, conn.neighbor, conn.neighbor_port_index)
            end

            debug_print(string.format("[CONNECTED] %s (Port %d) <-> %s (Port %d) | Outcome: %s", 
                entity.name, conn.port_index, conn.neighbor.name, conn.neighbor_port_index, outcome))
        else
            debug_print(string.format("[INCOMPATIBLE] %s (Port %d) <-> %s (Port %d)", 
                entity.name, conn.port_index, conn.neighbor.name, conn.neighbor_port_index))
        end
    end

    -- Track networks for both the placed entity and any joined neighbors
    local rebuilt = {}

    local ports = port_defs.get_ports(entity)
    if ports then
        for p_idx, _ in ipairs(ports) do
            local key = entity.unit_number .. ":" .. p_idx
            local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[key]
            if net_id then
                rebuilt[net_id] = true
            end
        end
    end

    for _, conn in ipairs(spatial_connections) do
        if conn.neighbor and conn.neighbor.valid then
            local n_key = conn.neighbor.unit_number .. ":" .. conn.neighbor_port_index
            local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[n_key]
            if net_id then
                rebuilt[net_id] = true
            end
        end
    end

    for net_id in pairs(rebuilt) do
        networks_flow.build(net_id)
    end
end

return network_validate