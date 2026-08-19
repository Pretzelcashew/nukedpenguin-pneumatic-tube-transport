local events = require("scripts.events")
local port_defs = require("scripts.port-definitions")

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

    -- Fetch the custom port data for this entity
    local def = port_defs[entity.name]
    if not def or not def.ports then return end

    -- Render a small circle at each port offset attached directly to the entity
    for _, port in ipairs(def.ports) do
        rendering.draw_circle{
            color = {r = 0, g = 1, b = 0.2, a = 0.8}, -- Bright cyan/green dot
            radius = 0.12,
            filled = true,
            target = entity,
            target_offset = port.offset,
            surface = entity.surface
        }
    end
end

-- Register the handler across all placement events
for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_created)
end