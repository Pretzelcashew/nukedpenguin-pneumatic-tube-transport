-- scripts/networks/network-validate.lua
local port_finder = require("scripts.ports.port-finder")
local port_evaluator = require("scripts.ports.port-evaluator")
local connection_defs = require("scripts.ports.port-connection-definitions")
local network_form_internals = require("scripts.networks.network-form-internals")

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
end

return network_validate