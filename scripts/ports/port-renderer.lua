local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")

-- All entity build events in Factorio
local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

local function handle_entity_created(event)
    local entity = event.entity or event.created_entity
    if not (entity and entity.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    for _, port in ipairs(ports) do
        rendering.draw_circle{
            color = {r = 0, g = 1, b = 0.2, a = 0.8},
            radius = 0.12,
            filled = true,
            target = { entity = entity, offset = port.offset },
            surface = entity.surface
        }
    end
end

-- Register the handler across all placement events
for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_created)
end