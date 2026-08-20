-- scripts/ports/port-connection.lua
local events = require("scripts.events")
local port_finder = require("scripts.ports.port-finder")
local port_evaluator = require("scripts.ports.port-evaluator")
local connection_defs = require("scripts.ports.port-connection-definitions")

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

local function handle_entity_placed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    -- 1. Find physical connections in space
    local spatial_connections = port_finder.find_connections(entity)

    -- 2. Evaluate compatibility and outcome
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

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_placed)
end