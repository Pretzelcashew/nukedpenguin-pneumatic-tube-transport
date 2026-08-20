-- scripts/ports/port-logger.lua
local events = require("scripts.events")
local port_finder = require("scripts.ports.port-finder")
local port_evaluator = require("scripts.ports.port-evaluator")

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

    -- 2. Pass findings directly to evaluator
    for _, conn in ipairs(spatial_connections) do
        local is_compatible = port_evaluator.are_compatible(
            entity, 
            conn.port_index, 
            conn.neighbor, 
            conn.neighbor_port_index
        )
        local status = is_compatible and "COMPATIBLE" or "INCOMPATIBLE"

        game.print(string.format("[Port %s] %s (Port %d) <-> %s (Port %d)", 
            status, entity.name, conn.port_index, conn.neighbor.name, conn.neighbor_port_index))
    end
end

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_placed)
end