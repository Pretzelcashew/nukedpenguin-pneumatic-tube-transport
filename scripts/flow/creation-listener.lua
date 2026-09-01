local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")

local creation_listener = {}

local pneumatic_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    pneumatic_entities[name] = true
end

local listeners = {}

function creation_listener.register_entity_name(name)
    pneumatic_entities[name] = true
end

function creation_listener.is_pneumatic_entity(entity)
    return entity and entity.valid and pneumatic_entities[entity.name] == true
end

function creation_listener.on_entity_created(callback)
    table.insert(listeners, callback)
end

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    defines.events.on_entity_cloned
}

if defines.events.on_space_platform_built_entity then
    table.insert(build_events, defines.events.on_space_platform_built_entity)
end

local function handle_entity_entry(event)
    local entity = event.destination or event.entity or event.created_entity
    if not (entity and entity.valid) then return end
    if not pneumatic_entities[entity.name] then return end

    for i = 1, #listeners do
        listeners[i](entity, event)
    end
end

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_entry)
end

creation_listener.on_entity_created(function(entity, event)
    local unit_str = entity.unit_number and (" #" .. tostring(entity.unit_number)) or ""
    local player_idx = event and event.player_index

    debug_print(string.format("[Flow Engine] Entity created: %s%s at (%.1f, %.1f) on '%s'",
        entity.name,
        unit_str,
        entity.position.x,
        entity.position.y,
        entity.surface.name
    ), player_idx)
end)

return creation_listener