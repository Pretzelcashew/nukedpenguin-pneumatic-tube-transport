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

local function find_existing_real_hub_at_pos(surface, position, real_name)
    if not (surface and position and real_name) then return nil end
    local px = position.x or position[1] or 0
    local py = position.y or position[2] or 0
    local reals = surface.find_entities_filtered{
        name = real_name,
        position = position,
        radius = 0.1
    }
    if reals then
        for _, r in ipairs(reals) do
            if r.valid and r.name == real_name then
                local rx = r.position.x or r.position[1] or 0
                local ry = r.position.y or r.position[2] or 0
                if math.abs(rx - px) < 0.1 and math.abs(ry - py) < 0.1 then
                    return r
                end
            end
        end
    end
    return nil
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
        local existing_real = nil
        if is_ghost then
            existing_real = find_existing_real_hub_at_pos(entity.surface, entity.position, real_name)
        end

        local target_entity = existing_real or entity
        local target_is_ghost = (target_entity.name == "entity-ghost")
        local unit_number = target_entity.unit_number
        local pos_key = get_pos_key(target_entity.surface, target_entity.position)

        local ghost_unit_number = nil
        local ghost_entity = nil
        if pos_key and storage.ghost_by_pos then
            ghost_unit_number = storage.ghost_by_pos[pos_key]
        end
        if not ghost_unit_number and storage.ghost_by_pos then
            local sname = target_entity.surface.name
            local px = target_entity.position.x or target_entity.position[1] or 0
            local py = target_entity.position.y or target_entity.position[2] or 0
            for pos_k, g_id in pairs(storage.ghost_by_pos) do
                local k_sname, coords = pos_k:match("^([^@]+)@(.+)$")
                if k_sname == sname and coords then
                    local kx, ky = coords:match("^([^,]+),(.+)$")
                    if kx and ky then
                        local nx, ny = tonumber(kx), tonumber(ky)
                        if nx and ny and math.abs(nx - px) < 0.1 and math.abs(ny - py) < 0.1 then
                            ghost_unit_number = g_id
                            break
                        end
                    end
                end
            end
        end
        if not ghost_unit_number and event.source and event.source.valid then
            ghost_unit_number = event.source.unit_number
            ghost_entity = event.source
        end

        if target_is_ghost then
            storage.ghost_hubs = storage.ghost_hubs or {}
            storage.ghost_hubs[unit_number] = target_entity
        else
            storage.active_hubs = storage.active_hubs or {}
            storage.active_hubs[unit_number] = target_entity
        end

        local copied = false
        if event.tags and event.tags.pneumatic_settings then
            hub_settings.apply_blueprint_settings(unit_number, event.tags.pneumatic_settings)
            copied = true
        elseif ghost_unit_number and ghost_unit_number ~= unit_number then
            local is_compatible = true
            if not ghost_entity and storage.ghost_hubs then
                ghost_entity = storage.ghost_hubs[ghost_unit_number]
            end
            if ghost_entity and ghost_entity.valid then
                local g_real_name = (ghost_entity.name == "entity-ghost") and ghost_entity.ghost_name or ghost_entity.name
                if g_real_name ~= real_name then
                    is_compatible = false
                end
                local g_pos = ghost_entity.position
                local e_pos = target_entity.position
                local dx = math.abs((g_pos.x or g_pos[1]) - (e_pos.x or e_pos[1]))
                local dy = math.abs((g_pos.y or g_pos[2]) - (e_pos.y or e_pos[2]))
                if dx >= 0.1 or dy >= 0.1 then
                    is_compatible = false
                end
            end

            if is_compatible then
                copied = (hub_settings.copy(ghost_unit_number, unit_number) ~= nil)
            end

            if pos_key and storage.ghost_by_pos then
                storage.ghost_by_pos[pos_key] = nil
            end
            if storage.ghost_hubs then
                storage.ghost_hubs[ghost_unit_number] = nil
            end
            if storage.hub_settings then
                storage.hub_settings[ghost_unit_number] = nil
            end
        end

        if target_is_ghost and pos_key then
            storage.ghost_by_pos = storage.ghost_by_pos or {}
            storage.ghost_by_pos[pos_key] = unit_number
        end

        if not copied then
            hub_settings.get(unit_number)
        end

        if not target_is_ghost then
            hub_manager.notify_settings_changed(target_entity)
        end

        if existing_real and is_ghost and entity.valid then
            entity.destroy()
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
            if storage.ghost_hubs then
                storage.ghost_hubs[unit_number] = nil
            end
        else
            local pos_key = get_pos_key(entity.surface, entity.position)
            if pos_key and storage.ghost_by_pos then
                storage.ghost_by_pos[pos_key] = nil
            end
            if storage.active_hubs then
                storage.active_hubs[unit_number] = nil
            end
            if storage.hub_settings then
                storage.hub_settings[unit_number] = nil
            end
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

if defines.events.on_blueprint_settings_pasted then
    events.on_event(defines.events.on_blueprint_settings_pasted, function(event)
        local entity = event.entity or event.destination
        if not (entity and entity.valid) then return end

        local is_ghost = (entity.name == "entity-ghost")
        local real_name = is_ghost and entity.ghost_name or entity.name

        local def = hub_defs.types[real_name]
        if def and def.type == "hub" then
            local dev_id = hub_settings.get_device_id(entity)
            local tags = event.tags or (is_ghost and entity.tags)
            if tags and tags.pneumatic_settings then
                hub_settings.apply_blueprint_settings(dev_id, tags.pneumatic_settings)
                hub_manager.notify_settings_changed(entity)
            end
        end
    end)
end

events.on_event(defines.events.on_player_mined_entity, on_hub_removed)
events.on_event(defines.events.on_robot_mined_entity, on_hub_removed)
events.on_event(defines.events.on_entity_died, on_hub_removed)
events.on_event(defines.events.script_raised_destroy, on_hub_removed)

events.on_event(defines.events.on_tick, on_tick)

return hub_manager