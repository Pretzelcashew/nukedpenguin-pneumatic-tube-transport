-- scripts/ports/port-logger.lua
local events = require("scripts.events")
local port_finder = require("scripts.ports.port-finder")

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

local function handle_entity_placed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local connections = port_finder.find_connections(entity)

    for _, conn in ipairs(connections) do
        game.print(string.format("[Port] %s (Port %d) <-> %s (Port %d)", 
            entity.name, conn.port_index, conn.neighbor.name, conn.neighbor_port_index))
    end
end

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_placed)
end