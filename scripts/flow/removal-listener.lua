local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local debug_manager = require("scripts.debug-manager")

local removal_listener = {}

local pneumatic_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    pneumatic_entities[name] = true
end

local listeners = {}

function removal_listener.register_entity_name(name)
    pneumatic_entities[name] = true
end

function removal_listener.is_pneumatic_entity(entity)
    return entity and entity.valid and pneumatic_entities[entity.name] == true
end

function removal_listener.on_entity_removed(callback)
    table.insert(listeners, callback)
end

local removal_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}

if defines.events.on_space_platform_mined_entity then
    table.insert(removal_events, defines.events.on_space_platform_mined_entity)
end

local function handle_entity_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if not pneumatic_entities[entity.name] then return end

    for i = 1, #listeners do
        listeners[i](entity, event)
    end
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end

-- Integrated debug print listener
removal_listener.on_entity_removed(function(entity, event)
    local unit_str = entity.unit_number and (" #" .. tostring(entity.unit_number)) or ""
    local player_idx = event and event.player_index

    debug_print(string.format("[Flow Engine] Entity removed: %s%s at (%.1f, %.1f) on '%s'",
        entity.name,
        unit_str,
        entity.position.x,
        entity.position.y,
        entity.surface.name
    ), player_idx)
end)

return removal_listener