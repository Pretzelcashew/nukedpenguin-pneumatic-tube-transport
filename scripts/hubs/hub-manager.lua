local events = require("scripts.events")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_spill = require("scripts.hubs.hub-spill")
local hub_packing = require("scripts.hubs.hub-packing")
local hub_settings = require("scripts.hubs.hub-settings")
local capsule_runner = require("scripts.capsules.capsule-runner")

local hub_manager = {}

function hub_manager.notify_settings_changed(entity)
    if not (entity and entity.valid) then return end
    capsule_runner.wake_parked_capsules()
    if hub_settings.can_send(entity) then
        hub_packing.evaluate_inventory(entity)
    end
end

local function on_hub_built(event)
    local entity = event.entity or event.destination
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local real_name = is_ghost and entity.ghost_name or entity.name

    local def = hub_defs.types[real_name]
    if def and def.type == "hub" then
        local unit_number = entity.unit_number

        if not is_ghost then
            storage.active_hubs = storage.active_hubs or {}
            storage.active_hubs[unit_number] = entity
        end

        if event.tags and event.tags.pneumatic_settings then
            hub_settings.apply_blueprint_settings(unit_number, event.tags.pneumatic_settings)
        elseif event.source and event.source.valid then
            hub_settings.copy(event.source.unit_number, unit_number)
        else
            hub_settings.get(unit_number)
        end

        if not is_ghost then
            hub_manager.notify_settings_changed(entity)
        end
    end
end

local function on_hub_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local real_name = is_ghost and entity.ghost_name or entity.name

    local def = hub_defs.types[real_name]
    if def then
        local unit_number = entity.unit_number
        if storage.active_hubs then
            storage.active_hubs[unit_number] = nil
        end
        if storage.hub_settings then
            storage.hub_settings[unit_number] = nil
        end
    end
end

local function on_tick(event)
    if not storage.active_hubs then return end

    local current_tick = event.tick
    for unit_number, entity in pairs(storage.active_hubs) do
        if (unit_number + current_tick) % 10 == 0 then
            if entity.valid then
                hub_packing.evaluate_inventory(entity)
            else
                storage.active_hubs[unit_number] = nil
            end
        end
    end
end

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}
if defines.events.on_space_platform_built_entity then
    table.insert(build_events, defines.events.on_space_platform_built_entity)
end
if defines.events.on_entity_cloned then
    table.insert(build_events, defines.events.on_entity_cloned)
end

for _, id in ipairs(build_events) do
    events.on_event(id, on_hub_built)
end

events.on_event(defines.events.on_player_mined_entity, on_hub_removed)
events.on_event(defines.events.on_robot_mined_entity, on_hub_removed)
events.on_event(defines.events.on_entity_died, on_hub_removed)
events.on_event(defines.events.script_raised_destroy, on_hub_removed)

events.on_event(defines.events.on_tick, on_tick)

return hub_manager