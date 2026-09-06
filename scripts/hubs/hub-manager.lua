local events = require("scripts.events")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_spill = require("scripts.hubs.hub-spill")
local hub_packing = require("scripts.hubs.hub-packing")
local hub_settings = require("scripts.hubs.hub-settings")
local capsule_runner = require("scripts.capsules.capsule-runner")

local hub_manager = {}

local function get_pos_key(surface, position)
    if not (surface and position) then return nil end
    local sname = type(surface) == "string" and surface or surface.name
    local px = position.x or position[1] or 0
    local py = position.y or position[2] or 0
    return sname .. "@" .. px .. "," .. py
end

function hub_manager.notify_settings_changed(entity)
    if not (entity and entity.valid) then return end
    capsule_runner.wake_parked_capsules()
    local is_ghost = (entity.name == "entity-ghost")
    if not is_ghost and hub_settings.can_send(entity) then
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
        local pos_key = get_pos_key(entity.surface, entity.position)

        if is_ghost then
            storage.ghost_hubs = storage.ghost_hubs or {}
            storage.ghost_hubs[unit_number] = entity
            if pos_key then
                storage.ghost_by_pos = storage.ghost_by_pos or {}
                storage.ghost_by_pos[pos_key] = unit_number
            end
        else
            storage.active_hubs = storage.active_hubs or {}
            storage.active_hubs[unit_number] = entity
        end

        local ghost_unit_number = nil
        if not is_ghost then
            if pos_key and storage.ghost_by_pos then
                ghost_unit_number = storage.ghost_by_pos[pos_key]
            end
            if not ghost_unit_number and event.source and event.source.valid then
                ghost_unit_number = event.source.unit_number
            end
        end

        local copied = false
        if event.tags and event.tags.pneumatic_settings then
            hub_settings.apply_blueprint_settings(unit_number, event.tags.pneumatic_settings)
            copied = true
        elseif ghost_unit_number then
            copied = (hub_settings.copy(ghost_unit_number, unit_number) ~= nil)

            if pos_key and storage.ghost_by_pos then
                storage.ghost_by_pos[pos_key] = nil
            end
            if storage.hub_settings then
                storage.hub_settings[ghost_unit_number] = nil
            end
        end

        if not copied then
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
        if is_ghost then
            local pos_key = get_pos_key(entity.surface, entity.position)
            if pos_key and storage.ghost_by_pos then
                storage.ghost_by_pos[pos_key] = nil
            end
        end
        if storage.ghost_hubs then
            storage.ghost_hubs[unit_number] = nil
        end
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