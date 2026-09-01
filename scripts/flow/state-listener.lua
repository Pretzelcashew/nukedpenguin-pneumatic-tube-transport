local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local debug_manager = require("scripts.debug-manager")

local state_listener = {}

local pneumatic_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    pneumatic_entities[name] = true
end

local listeners = {}

function state_listener.register_entity_name(name)
    pneumatic_entities[name] = true
end

function state_listener.is_pneumatic_entity(entity)
    return entity and entity.valid and pneumatic_entities[entity.name] == true
end

function state_listener.on_entity_state_changed(callback)
    table.insert(listeners, callback)
end

local state_events = {
    defines.events.on_player_rotated_entity,
    defines.events.on_player_flipped_entity
}

local function handle_state_changed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if not pneumatic_entities[entity.name] then return end

    for i = 1, #listeners do
        listeners[i](entity, event)
    end
end

for _, event_id in ipairs(state_events) do
    events.on_event(event_id, handle_state_changed)
end

-- Integrated debug print listener
state_listener.on_entity_state_changed(function(entity, event)
    local unit_str = entity.unit_number and (" #" .. tostring(entity.unit_number)) or ""
    local player_idx = event and event.player_index

    debug_print(string.format("[Flow Engine] Entity state changed: %s%s at (%.1f, %.1f) on '%s'",
        entity.name,
        unit_str,
        entity.position.x,
        entity.position.y,
        entity.surface.name
    ), player_idx)
end)

return state_listener