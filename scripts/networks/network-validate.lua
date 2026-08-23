-- scripts/networks/network-validate.lua
local port_finder = require("scripts.ports.port-finder")
local port_evaluator = require("scripts.ports.port-evaluator")
local connection_defs = require("scripts.ports.port-connection-definitions")
local network_form_internals = require("scripts.networks.network-form-internals")
local networks_flow = require("scripts.networks.networks-flow")
local port_defs = require("scripts.ports.port-definitions")

local network_validate = {}

--- Evaluates spatial connections and integrates an entity into the network
function network_validate.execute(entity)
    if not (entity and entity.valid) then return end

    -- 1. Initialize internal groups and standalone networks 
    network_form_internals.execute(entity)

    -- 2. Find physical connections in space
    local spatial_connections = port_finder.find_connections(entity)

    -- 3. Evaluate compatibility and outcome
    for _, conn in ipairs(spatial_connections) do
        local is_compatible, outcome = port_evaluator.are_compatible(
            entity, 
            conn.port_index, 
            conn.neighbor, 
            conn.neighbor_port_index
        )

        if is_compatible and outcome then
            local def = connection_defs.types[outcome]
            
            -- Execute the handler function defined for this outcome
            if def and def.handler then
                def.handler(entity, conn.port_index, conn.neighbor, conn.neighbor_port_index)
            end

            game.print(string.format("[CONNECTED] %s (Port %d) <-> %s (Port %d) | Outcome: %s", 
                entity.name, conn.port_index, conn.neighbor.name, conn.neighbor_port_index, outcome))
        else
            game.print(string.format("[INCOMPATIBLE] %s (Port %d) <-> %s (Port %d)", 
                entity.name, conn.port_index, conn.neighbor.name, conn.neighbor_port_index))
        end
    end

    -- 4. Rebuild flow maps for all affected networks (this entity & its direct neighbors)
    local affected_networks = {}
    local ports = port_defs.get_ports(entity)
    if ports then
        for p_idx, _ in ipairs(ports) do
            local port_key = entity.unit_number .. ":" .. p_idx
            local net_id = storage.networks.port_to_network[port_key]
            if net_id then affected_networks[net_id] = true end

            -- Collect joined/merged neighbor network IDs as well
            local neighbors = storage.port_connections and storage.port_connections[port_key]
            if neighbors then
                for neighbor_key, _ in pairs(neighbors) do
                    local n_net_id = storage.networks.port_to_network[neighbor_key]
                    if n_net_id then affected_networks[n_net_id] = true end
                end
            end
        end
    end

    for net_id in pairs(affected_networks) do
        networks_flow.build(net_id)
    end
end

return network_validate