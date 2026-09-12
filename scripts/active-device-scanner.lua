local events = require("scripts.events")
local flow_engine = require("scripts.flow.flow-engine")
local counter_range = require("scripts.counters.counter-range")
local capsule_runner = require("scripts.capsules.capsule-runner")
local pump_manager = require("scripts.pumps.pump-manager")
local diverter_manager = require("scripts.diverters.diverter-manager")
local counter_manager = require("scripts.counters.counter-manager")
local projector_manager = require("scripts.projectors.projector-manager")
local profiler = require("scripts.utils.profiler")
local util = require("util")

local active_device_scanner = {}

local SCAN_INTERVAL = 15

local device_specs_by_name = {}
local device_specs_list = {}
local settings_changed_callbacks = {}

local PROXY_NAMES = {
    ["pneumatic-diverter-circuit-proxy"] = true,
    ["pneumatic-pump-circuit-proxy"] = true,
    ["pneumatic-capsule-counter-circuit-proxy"] = true,
    ["pneumatic-capsule-counter-red-proxy"] = true,
    ["pneumatic-capsule-counter-green-proxy"] = true,
    ["pneumatic-projector-circuit-proxy"] = true
}

local function get_spec_device_id(spec_name, entity)
    if not (spec_name and entity) then return nil end
    local spec = (type(spec_name) == "table") and spec_name or device_specs_by_name[spec_name]
    if spec and spec.get_device_id then
        return spec.get_device_id(entity)
    end
    return nil
end

local function get_pos_key(surface, position, real_name)
    if not (surface and position) then return nil end
    local sname = type(surface) == "string" and surface or surface.name
    local px = position.x or position[1] or 0
    local py = position.y or position[2] or 0
    local prefix = real_name or "device"
    return prefix .. "@" .. sname .. "@" .. px .. "," .. py
end

local function find_existing_real_at_pos(surface, position, real_name, exclude_entity)
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
            if r.valid and r.name == real_name and r ~= exclude_entity then
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

local function find_ghost_id_at_pos(surface, position, real_name, spec_name)
    if not (surface and position) then return nil, nil, nil end
    local sname = type(surface) == "string" and surface or surface.name
    local px = position.x or position[1] or 0
    local py = position.y or position[2] or 0

    local exact_key = get_pos_key(sname, position, real_name)
    if exact_key and storage.ghost_by_pos and storage.ghost_by_pos[exact_key] then
        local g_id = storage.ghost_by_pos[exact_key]
        local g_dir = storage.ghost_directions and storage.ghost_directions[g_id]
        return g_id, g_dir, exact_key
    end

    if storage.ghost_by_pos then
        for pos_k, g_id in pairs(storage.ghost_by_pos) do
            local prefix, k_sname, coords = pos_k:match("^([^@]+)@([^@]+)@(.+)$")
            if (not k_sname) then
                k_sname, coords = pos_k:match("^([^@]+)@(.+)$")
            end
            if k_sname == sname and coords then
                if not prefix or prefix == real_name or prefix == "device" then
                    local kx, ky = coords:match("^([^,]+),(.+)$")
                    if kx and ky then
                        local nx = tonumber(kx)
                        local ny = tonumber(ky)
                        if nx and ny and math.abs(nx - px) < 0.1 and math.abs(ny - py) < 0.1 then
                            local g_dir = storage.ghost_directions and storage.ghost_directions[g_id]
                            return g_id, g_dir, pos_k
                        end
                    end
                end
            end
        end
    end

    return nil, nil, nil
end


function active_device_scanner.on_settings_changed(callback)
    if type(callback) == "function" then
        table.insert(settings_changed_callbacks, callback)
    end
end

function active_device_scanner.register_device_type(spec)
    if not (spec and spec.name and spec.storage_key) then return end

    table.insert(device_specs_list, spec)

    local names = spec.entity_names
    if type(names) == "string" then
        names = { names }
    end

    if names then
        for _, ename in ipairs(names) do
            device_specs_by_name[ename] = spec
        end
    end
end

function active_device_scanner.notify_settings_changed(entity)
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local name = is_ghost and entity.ghost_name or entity.name
    if PROXY_NAMES[name] or PROXY_NAMES[entity.name] then return end

    local spec = device_specs_by_name[name]
    if not spec then return end

    local unit_number = entity.unit_number
    if not is_ghost then
        if spec.check_and_update_state then
            spec.check_and_update_state(entity, true)
        end
    end

    if spec.on_settings_changed then
        spec.on_settings_changed(entity, is_ghost)
    end

    for i = 1, #settings_changed_callbacks do
        settings_changed_callbacks[i](entity)
    end

    if not is_ghost then
        flow_engine.enqueue_unit_ports(unit_number)
        capsule_runner.wake_parked_capsules(unit_number)
    end
end

local function scan_active_devices(tick)
    local p_cache = profiler.start_sub_timer("Scanner: Cache")
    if storage.fast_replace_cache then
        local cur_tick = tick or game.tick
        for k, v in pairs(storage.fast_replace_cache) do
            if (cur_tick - (v.tick or 0)) > 60 then
                storage.fast_replace_cache[k] = nil
            end
        end
    end
    profiler.stop_sub_timer("Scanner: Cache", p_cache)

    for _, spec in ipairs(device_specs_list) do
        local sub_name = "Scanner: " .. (spec.name == "pneumatic-capsule-counter" and "Counters" or
                                         spec.name == "pneumatic-diverter" and "Diverters" or
                                         spec.name == "pneumatic-pump" and "Pumps" or
                                         spec.name == "pneumatic-projector" and "Projectors" or spec.name)
        local p_spec = profiler.start_sub_timer(sub_name)
        local storage_table = storage[spec.storage_key]
        if storage_table then
            for unit_number, entity in pairs(storage_table) do
                if entity.valid then
                    if spec.check_and_update_state then
                        local changed = spec.check_and_update_state(entity, false)
                        if changed then
                            flow_engine.enqueue_unit_ports(unit_number)
                            capsule_runner.wake_parked_capsules(unit_number)
                        end
                    end
                    if spec.on_scan then
                        spec.on_scan(entity)
                    end
                else
                    storage_table[unit_number] = nil
                    if spec.on_unregister then
                        spec.on_unregister(entity, unit_number)
                    end
                end
            end
        end
        profiler.stop_sub_timer(sub_name, p_spec)
    end
end

active_device_scanner.register_device_type(pump_manager.spec)

active_device_scanner.register_device_type(diverter_manager.spec)

active_device_scanner.register_device_type(counter_manager.spec)

active_device_scanner.register_device_type(projector_manager.spec)

function active_device_scanner.register_events()
    events.on_event(defines.events.on_tick, function(event)
        if (event.tick % SCAN_INTERVAL) == 0 then
            scan_active_devices(event.tick)
        end
    end)

    local build_events = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.script_raised_revive,
        defines.events.on_space_platform_built_entity,
        defines.events.on_entity_cloned
    }
    for _, id in ipairs(build_events) do
        events.on_event(id, function(event)
            local entity = event.entity or event.destination
            if entity and entity.valid then
                local is_ghost = (entity.name == "entity-ghost")
                local real_name = is_ghost and entity.ghost_name or entity.name

                if PROXY_NAMES[real_name] or PROXY_NAMES[entity.name] then return end

                local spec = device_specs_by_name[real_name]

                if spec then
                    local existing_real = nil
                    if is_ghost then
                        existing_real = find_existing_real_at_pos(entity.surface, entity.position, real_name)
                    end

                    local target_entity = existing_real or entity
                    local target_is_ghost = (target_entity.name == "entity-ghost")
                    local target_dev_id = get_spec_device_id(spec.name, target_entity)
                    local pos_key = get_pos_key(target_entity.surface, target_entity.position, real_name)

                    local ghost_id = nil
                    local ghost_dir = nil
                    local matched_pos_key = nil
                    local ghost_entity = nil

                    ghost_id, ghost_dir, matched_pos_key = find_ghost_id_at_pos(target_entity.surface, target_entity.position, real_name, spec.name)
                    if ghost_id and storage.ghost_devices then
                        ghost_entity = storage.ghost_devices[ghost_id]
                    end

                    if not ghost_id and event.consumed_ghost and event.consumed_ghost.valid then
                        local cg = event.consumed_ghost
                        ghost_id = get_spec_device_id(spec.name, cg)
                        ghost_dir = cg.direction
                        ghost_entity = cg
                    end
                    if not ghost_id and event.source and event.source.valid then
                        local src = event.source
                        ghost_id = get_spec_device_id(spec.name, src)
                        ghost_dir = src.direction
                        ghost_entity = src
                    end

                    if target_is_ghost then
                        storage.ghost_devices = storage.ghost_devices or {}
                        storage.ghost_devices[target_dev_id] = target_entity
                        storage.ghost_directions = storage.ghost_directions or {}
                        storage.ghost_directions[target_dev_id] = target_entity.direction
                    else
                        storage[spec.storage_key] = storage[spec.storage_key] or {}
                        storage[spec.storage_key][target_entity.unit_number] = target_entity
                    end

                    local copied = false
                    local bp_tags = event.tags or (is_ghost and entity.tags)
                    if bp_tags and bp_tags.pneumatic_settings then
                        if spec.apply_blueprint_settings then
                            if existing_real and existing_real.valid and existing_real.direction ~= entity.direction then
                                local prev_dir = existing_real.direction
                                existing_real.direction = entity.direction
                                if spec.on_rotate then
                                    spec.on_rotate(existing_real, { previous_direction = prev_dir })
                                end
                            end
                            spec.apply_blueprint_settings(target_entity, bp_tags.pneumatic_settings)
                            copied = true
                        end
                    elseif ghost_id and ghost_id ~= target_dev_id then
                        local src_dir = ghost_dir
                            or (storage.ghost_directions and storage.ghost_directions[ghost_id])
                            or target_entity.direction

                        local is_compatible = true
                        if ghost_entity and ghost_entity.valid then
                            local g_pos = ghost_entity.position
                            local e_pos = target_entity.position
                            local dx = math.abs((g_pos.x or g_pos[1]) - (e_pos.x or e_pos[1]))
                            local dy = math.abs((g_pos.y or g_pos[2]) - (e_pos.y or e_pos[2]))
                            if dx >= 0.1 or dy >= 0.1 then
                                is_compatible = false
                            end
                            local g_real_name = (ghost_entity.name == "entity-ghost") and ghost_entity.ghost_name or ghost_entity.name
                            if g_real_name ~= real_name then
                                is_compatible = false
                            end
                        end

                        if is_compatible and spec.is_direction_compatible then
                            if not spec.is_direction_compatible(src_dir, target_entity.direction) then
                                is_compatible = false
                            end
                        end

                        if is_compatible and spec.copy_settings then
                            copied = (spec.copy_settings(ghost_id, target_dev_id, src_dir, target_entity.direction) ~= nil)
                        end

                        if matched_pos_key and storage.ghost_by_pos then
                            storage.ghost_by_pos[matched_pos_key] = nil
                        end
                        if storage.ghost_directions then
                            storage.ghost_directions[ghost_id] = nil
                        end
                        if storage.ghost_devices then
                            storage.ghost_devices[ghost_id] = nil
                        end
                        if spec.clear_settings then
                            spec.clear_settings(ghost_id)
                        end
                    elseif not target_is_ghost then
                        local existing_settings = spec.get_settings and spec.get_settings(target_dev_id)

                        if existing_settings then
                            copied = true
                        else
                            local replaced_real = find_existing_real_at_pos(target_entity.surface, target_entity.position, real_name, target_entity)
                            if replaced_real and replaced_real.valid and replaced_real.unit_number ~= target_entity.unit_number then
                                local src_id = get_spec_device_id(spec, replaced_real)
                                if spec.copy_settings then
                                    copied = (spec.copy_settings(src_id, target_dev_id, replaced_real.direction, target_entity.direction) ~= nil)
                                end
                            end

                            if not copied and pos_key and storage.fast_replace_cache and storage.fast_replace_cache[pos_key] then
                                local cached = storage.fast_replace_cache[pos_key]
                                local cur_tick = event.tick or game.tick
                                if cached and cached.tick == cur_tick and cached.name == real_name then
                                    if spec.apply_blueprint_settings then
                                        spec.apply_blueprint_settings(target_dev_id, cached.settings)
                                        if cached.direction and cached.direction ~= target_entity.direction and spec.on_rotate_delta then
                                            spec.on_rotate_delta(target_dev_id, cached.direction, target_entity.direction)
                                        end
                                        copied = true
                                    end
                                end
                                storage.fast_replace_cache[pos_key] = nil
                            end
                        end
                    end

                    if target_is_ghost and pos_key then
                        storage.ghost_by_pos = storage.ghost_by_pos or {}
                        storage.ghost_by_pos[pos_key] = target_dev_id
                    end

                    if not copied and spec.init_settings then
                        spec.init_settings(target_entity)
                    end

                    if spec.on_settings_changed then
                        spec.on_settings_changed(target_entity, target_is_ghost)
                    end

                    if not target_is_ghost then
                        if spec.check_and_update_state then
                            spec.check_and_update_state(target_entity, true)
                        end

                        flow_engine.enqueue_unit_ports(target_entity.unit_number)
                        capsule_runner.wake_parked_capsules(target_entity.unit_number)
                        active_device_scanner.notify_settings_changed(target_entity)
                    end

                    if existing_real and is_ghost and entity.valid then
                        entity.destroy()
                    end
                end
            end
        end)
    end

    if defines.events.on_blueprint_settings_pasted then
        events.on_event(defines.events.on_blueprint_settings_pasted, function(event)
            local entity = event.entity or event.destination
            if not (entity and entity.valid) then return end

            local is_ghost = (entity.name == "entity-ghost")
            local real_name = is_ghost and entity.ghost_name or entity.name

            if PROXY_NAMES[real_name] or PROXY_NAMES[entity.name] then return end

            local spec = device_specs_by_name[real_name]
            if not spec then return end

            local tags = event.tags or (is_ghost and entity.tags)
            if tags and tags.pneumatic_settings then
                if event.previous_direction and entity.direction ~= event.previous_direction then
                    if spec.on_rotate then
                        spec.on_rotate(entity, { previous_direction = event.previous_direction })
                    end
                end
                if spec.apply_blueprint_settings then
                    spec.apply_blueprint_settings(entity, tags.pneumatic_settings)
                end
                if is_ghost then
                    local etags = entity.tags or {}
                    etags.pneumatic_settings = tags.pneumatic_settings
                    entity.tags = etags
                end
                if spec.on_settings_changed then
                    spec.on_settings_changed(entity, is_ghost)
                end
                if not is_ghost then
                    if spec.check_and_update_state then
                        spec.check_and_update_state(entity, true)
                    end
                    flow_engine.enqueue_unit_ports(entity.unit_number)
                    capsule_runner.wake_parked_capsules(entity.unit_number)
                end
                active_device_scanner.notify_settings_changed(entity)
            end
        end)
    end

    local destroy_events = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.script_raised_destroy,
        defines.events.on_space_platform_mined_entity
    }
    for _, id in ipairs(destroy_events) do
        events.on_event(id, function(event)
            local entity = event.entity
            if entity and entity.valid then
                local is_ghost = (entity.name == "entity-ghost")
                local real_name = is_ghost and entity.ghost_name or entity.name

                if PROXY_NAMES[real_name] or PROXY_NAMES[entity.name] then return end

                local spec = device_specs_by_name[real_name]
                if spec then
                    local dev_id = get_spec_device_id(spec.name, entity)
                    if is_ghost then
                        if storage.ghost_devices then
                            storage.ghost_devices[dev_id] = nil
                        end
                    else
                        local pos_key = get_pos_key(entity.surface, entity.position, real_name)
                        if pos_key and storage.ghost_by_pos then
                            storage.ghost_by_pos[pos_key] = nil
                        end

                        local replacement = find_existing_real_at_pos(entity.surface, entity.position, real_name, entity)
                        if replacement and replacement.valid and replacement.unit_number ~= entity.unit_number then
                            local dest_id = get_spec_device_id(spec, replacement)
                            if spec.copy_settings then
                                spec.copy_settings(dev_id, dest_id, entity.direction, replacement.direction)
                            end
                        end

                        local cur_settings = spec.get_settings and spec.get_settings(dev_id)

                        if cur_settings and pos_key then
                            storage.fast_replace_cache = storage.fast_replace_cache or {}
                            storage.fast_replace_cache[pos_key] = {
                                settings = util.table.deepcopy(cur_settings),
                                direction = entity.direction,
                                tick = event.tick or game.tick,
                                name = real_name
                            }
                        end

                        if storage[spec.storage_key] and entity.unit_number then
                            storage[spec.storage_key][entity.unit_number] = nil
                        end
                        if spec.clear_settings then
                            spec.clear_settings(dev_id)
                        end
                    end
                    if spec.on_unregister then
                        spec.on_unregister(entity, entity.unit_number)
                    end
                end
            end
        end)
    end

    local rotate_events = {
        defines.events.on_player_rotated_entity,
        defines.events.on_player_flipped_entity
    }
    for _, id in ipairs(rotate_events) do
        events.on_event(id, function(event)
            local entity = event.entity
            if entity and entity.valid then
                local is_ghost = (entity.name == "entity-ghost")
                local real_name = is_ghost and entity.ghost_name or entity.name

                if PROXY_NAMES[real_name] or PROXY_NAMES[entity.name] then return end

                local spec = device_specs_by_name[real_name]
                if spec then
                    local dev_id = get_spec_device_id(spec.name, entity)
                    if spec.on_rotate then
                        spec.on_rotate(entity, event)
                    end
                    if is_ghost then
                        storage.ghost_directions = storage.ghost_directions or {}
                        storage.ghost_directions[dev_id] = entity.direction
                        local pos_key = get_pos_key(entity.surface, entity.position, real_name)
                        if pos_key then
                            storage.ghost_by_pos = storage.ghost_by_pos or {}
                            storage.ghost_by_pos[pos_key] = dev_id
                        end
                    end
                    active_device_scanner.notify_settings_changed(entity)
                end
            end
        end)
    end
end

return active_device_scanner