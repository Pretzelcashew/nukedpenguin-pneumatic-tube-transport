local events = require("scripts.events")
local flow_engine = require("scripts.flow.flow-engine")
local counter_range = require("scripts.counters.counter-range")
local capsule_runner = require("scripts.capsules.capsule-runner")
local pump_settings = require("scripts.pumps.pump-settings")
local diverter_settings = require("scripts.diverters.diverter-settings")
local counter_settings = require("scripts.counters.counter-settings")
local counter_logic = require("scripts.counters.counter-logic")
local diverter_renderer = require("scripts.diverters.diverter-renderer")
local projector_settings = require("scripts.projectors.projector-settings")
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
    if spec_name == "pneumatic-diverter" then
        return diverter_settings.get_device_id(entity)
    elseif spec_name == "pneumatic-pump" then
        return pump_settings.get_device_id(entity)
    elseif spec_name == "pneumatic-capsule-counter" then
        return counter_settings.get_device_id(entity)
    elseif spec_name == "pneumatic-projector" then
        return projector_settings.get_device_id(entity)
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

local function clear_diverter_compiled_filters(unit_number)
    local dev_id = diverter_settings.get_device_id(unit_number)
    local d_settings = dev_id and storage.diverter_settings and storage.diverter_settings[dev_id]
    if d_settings and d_settings.ports then
        for i = 1, 4 do
            if d_settings.ports[i] then
                d_settings.ports[i]._compiled = nil
            end
        end
    end
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

    if spec.name == "pneumatic-diverter" then
        diverter_renderer.update_render(entity)
    elseif spec.name == "pneumatic-capsule-counter" and not is_ghost then
        counter_logic.update_signals(entity)
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
    if storage.fast_replace_cache then
        local cur_tick = tick or game.tick
        for k, v in pairs(storage.fast_replace_cache) do
            if (cur_tick - (v.tick or 0)) > 60 then
                storage.fast_replace_cache[k] = nil
            end
        end
    end

    for _, spec in ipairs(device_specs_list) do
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
    end
end

active_device_scanner.register_device_type({
    name = "pneumatic-pump",
    entity_names = { "pneumatic-pump" },
    storage_key = "active_pumps",

    init_settings = function(entity)
        local dev_id = pump_settings.get_device_id(entity)
        pump_settings.get(dev_id)
    end,

    apply_blueprint_settings = function(entity, settings)
        local dev_id = pump_settings.get_device_id(entity)
        pump_settings.apply_blueprint_settings(dev_id, settings)
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.pump_power_states = storage.pump_power_states or {}
        storage.pump_enabled_states = storage.pump_enabled_states or {}

        local is_powered = (entity.energy > 0)
        local is_enabled = pump_settings.is_pump_enabled(entity)

        local last_power = storage.pump_power_states[unit_number]
        local last_enabled = storage.pump_enabled_states[unit_number]

        if forced or is_powered ~= last_power or is_enabled ~= last_enabled then
            storage.pump_power_states[unit_number] = is_powered
            storage.pump_enabled_states[unit_number] = is_enabled
            return true
        end
        return false
    end,

    on_unregister = function(entity, unit_number)
        if storage.pump_power_states then storage.pump_power_states[unit_number] = nil end
        if storage.pump_enabled_states then storage.pump_enabled_states[unit_number] = nil end
    end
})

active_device_scanner.register_device_type({
    name = "pneumatic-diverter",
    entity_names = { "pneumatic-diverter" },
    storage_key = "active_diverters",

    init_settings = function(entity)
        local dev_id = diverter_settings.get_device_id(entity)
        diverter_settings.get(dev_id)
    end,

    apply_blueprint_settings = function(entity, settings)
        local dev_id = diverter_settings.get_device_id(entity)
        diverter_settings.apply_blueprint_settings(dev_id, settings)
    end,

    on_rotate = function(entity, event)
        local dev_id = diverter_settings.get_device_id(entity)
        if event.previous_direction ~= nil then
            diverter_settings.rotate_ports(dev_id, event.previous_direction, entity.direction)
        elseif event.horizontal ~= nil or event.vertical ~= nil then
            diverter_settings.flip_ports(dev_id, event.horizontal, event.vertical)
        end
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.diverter_power_states = storage.diverter_power_states or {}
        storage.diverter_port_states = storage.diverter_port_states or {}

        local is_powered = (entity.energy > 0)
        local last_power = storage.diverter_power_states[unit_number]
        local last_ports = storage.diverter_port_states[unit_number] or {}

        local port_changed = false
        local current_ports = {}
        for i = 1, 4 do
            local state = diverter_settings.is_port_enabled(entity, i)
            current_ports[i] = state
            if state ~= last_ports[i] then
                port_changed = true
            end
        end

        if forced or is_powered ~= last_power or port_changed then
            storage.diverter_power_states[unit_number] = is_powered
            storage.diverter_port_states[unit_number] = current_ports
            clear_diverter_compiled_filters(unit_number)
            return true
        end
        return false
    end,

    on_unregister = function(entity, unit_number)
        if storage.diverter_power_states then storage.diverter_power_states[unit_number] = nil end
        if storage.diverter_port_states then storage.diverter_port_states[unit_number] = nil end
        diverter_renderer.clear_render(unit_number)
    end
})

active_device_scanner.register_device_type({
    name = "pneumatic-capsule-counter",
    entity_names = { "pneumatic-capsule-counter" },
    storage_key = "active_counters",

    init_settings = function(entity)
        local dev_id = counter_settings.get_device_id(entity)
        counter_settings.get(dev_id)
    end,

    apply_blueprint_settings = function(entity, settings)
        local dev_id = counter_settings.get_device_id(entity)
        counter_settings.apply_blueprint_settings(dev_id, settings)
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.counter_power_states = storage.counter_power_states or {}

        local is_powered = (entity.energy > 0)
        local last_power = storage.counter_power_states[unit_number]

        if forced or is_powered ~= last_power then
            storage.counter_power_states[unit_number] = is_powered
            counter_logic.update_signals(entity)
            return true
        end
        return false
    end,

    on_scan = function(entity)
        counter_logic.update_signals(entity)
    end,

    on_unregister = function(entity, unit_number)
        if storage.counter_power_states then storage.counter_power_states[unit_number] = nil end
        counter_range.unregister_counter(unit_number)
    end
})

active_device_scanner.register_device_type({
    name = "pneumatic-projector",
    entity_names = { "pneumatic-projector" },
    storage_key = "active_projectors",

    init_settings = function(entity)
        local dev_id = projector_settings.get_device_id(entity)
        projector_settings.get(dev_id, entity)
    end,

    apply_blueprint_settings = function(entity, settings)
        local dev_id = projector_settings.get_device_id(entity)
        projector_settings.apply_blueprint_settings(dev_id, settings)
    end,

    on_rotate = function(entity, event)
        local dev_id = projector_settings.get_device_id(entity)
        if event.previous_direction ~= nil then
            projector_settings.rotate_muzzle(dev_id, event.previous_direction, entity.direction)
        end
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.projector_power_states = storage.projector_power_states or {}
        storage.projector_enabled_states = storage.projector_enabled_states or {}
        storage.projector_muzzle_states = storage.projector_muzzle_states or {}
        storage.projector_ready_states = storage.projector_ready_states or {}

        local is_powered = projector_settings.is_powered(entity)
        local is_enabled = projector_settings.is_projector_enabled(entity)
        local is_ready = projector_settings.can_fire(entity)

        local dev_id = projector_settings.get_device_id(entity)
        local p_set = projector_settings.get(dev_id, entity)
        local current_muzzle = p_set and p_set.muzzle_dir or entity.direction

        local last_power = storage.projector_power_states[unit_number]
        local last_enabled = storage.projector_enabled_states[unit_number]
        local last_muzzle = storage.projector_muzzle_states[unit_number]
        local last_ready = storage.projector_ready_states[unit_number]

        local muzzle_changed = (current_muzzle ~= last_muzzle)
        local ready_changed = (is_ready ~= last_ready)

        if forced or is_powered ~= last_power or is_enabled ~= last_enabled or muzzle_changed or ready_changed then
            storage.projector_power_states[unit_number] = is_powered
            storage.projector_enabled_states[unit_number] = is_enabled
            storage.projector_muzzle_states[unit_number] = current_muzzle
            storage.projector_ready_states[unit_number] = is_ready

            if muzzle_changed and entity.valid and not (entity.name == "entity-ghost") then
                flow_engine.notify_beam_obstruction_changed(entity, true)

                -- Free and wake any incoming beam endpoints that were targeting this machine's old orientation
                for pkey, fn in pairs(storage.flow_nodes or {}) do
                    if fn and fn.hit_receiver == unit_number then
                        fn.is_endpoint = false
                        fn.hit_receiver = nil
                        flow_engine.enqueue_port(pkey)
                        capsule_runner.wake_parked_capsules(pkey)
                    end
                end

                flow_engine.disconnect_entity(entity)
                flow_engine.connect_entity(entity)
                flow_engine.notify_beam_obstruction_changed(entity, false)
            end

            return true
        end
        return false
    end,

    on_unregister = function(entity, unit_number)
        if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end
        if storage.projector_enabled_states then storage.projector_enabled_states[unit_number] = nil end
        if storage.projector_muzzle_states then storage.projector_muzzle_states[unit_number] = nil end
        if storage.projector_ready_states then storage.projector_ready_states[unit_number] = nil end
        if storage.projector_last_fired then storage.projector_last_fired[unit_number] = nil end
    end
})

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
                    if event.tags and event.tags.pneumatic_settings then
                        if spec.apply_blueprint_settings then
                            if existing_real and existing_real.valid and existing_real.direction ~= entity.direction then
                                local prev_dir = existing_real.direction
                                existing_real.direction = entity.direction
                                if spec.on_rotate then
                                    spec.on_rotate(existing_real, { previous_direction = prev_dir })
                                end
                            end
                            spec.apply_blueprint_settings(target_entity, event.tags.pneumatic_settings)
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

                        if is_compatible and spec.name == "pneumatic-pump" then
                            local g_idx = diverter_settings.get_cardinal_index(src_dir)
                            local e_idx = diverter_settings.get_cardinal_index(target_entity.direction)
                            if (g_idx % 2) ~= (e_idx % 2) then
                                is_compatible = false
                            end
                        end

                        if is_compatible then
                            if spec.name == "pneumatic-pump" then
                                copied = (pump_settings.copy(ghost_id, target_dev_id) ~= nil)
                            elseif spec.name == "pneumatic-diverter" then
                                copied = (diverter_settings.copy(ghost_id, target_dev_id, src_dir, target_entity.direction) ~= nil)
                            elseif spec.name == "pneumatic-capsule-counter" then
                                copied = (counter_settings.copy(ghost_id, target_dev_id) ~= nil)
                            elseif spec.name == "pneumatic-projector" then
                                copied = (projector_settings.copy(ghost_id, target_dev_id, src_dir, target_entity.direction) ~= nil)
                            end
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
                        if storage.diverter_settings and spec.name == "pneumatic-diverter" then
                            storage.diverter_settings[ghost_id] = nil
                        elseif storage.pump_settings and spec.name == "pneumatic-pump" then
                            storage.pump_settings[ghost_id] = nil
                        elseif storage.counter_settings and spec.name == "pneumatic-capsule-counter" then
                            storage.counter_settings[ghost_id] = nil
                        elseif storage.projector_settings and spec.name == "pneumatic-projector" then
                            storage.projector_settings[ghost_id] = nil
                        end
                    elseif not target_is_ghost then
                        local existing_settings = nil
                        if spec.name == "pneumatic-pump" and storage.pump_settings then
                            existing_settings = storage.pump_settings[target_dev_id]
                        elseif spec.name == "pneumatic-diverter" and storage.diverter_settings then
                            existing_settings = storage.diverter_settings[target_dev_id]
                        elseif spec.name == "pneumatic-capsule-counter" and storage.counter_settings then
                            existing_settings = storage.counter_settings[target_dev_id]
                        elseif spec.name == "pneumatic-projector" and storage.projector_settings then
                            existing_settings = storage.projector_settings[target_dev_id]
                        end

                        if existing_settings then
                            copied = true
                        else
                            local replaced_real = find_existing_real_at_pos(target_entity.surface, target_entity.position, real_name, target_entity)
                            if replaced_real and replaced_real.valid and replaced_real.unit_number ~= target_entity.unit_number then
                                local src_id = get_spec_device_id(spec.name, replaced_real)
                                if spec.name == "pneumatic-pump" then
                                    copied = (pump_settings.copy(src_id, target_dev_id) ~= nil)
                                elseif spec.name == "pneumatic-diverter" then
                                    copied = (diverter_settings.copy(src_id, target_dev_id, replaced_real.direction, target_entity.direction) ~= nil)
                                elseif spec.name == "pneumatic-capsule-counter" then
                                    copied = (counter_settings.copy(src_id, target_dev_id) ~= nil)
                                elseif spec.name == "pneumatic-projector" then
                                    copied = (projector_settings.copy(src_id, target_dev_id, replaced_real.direction, target_entity.direction) ~= nil)
                                end
                            end

                            if not copied and pos_key and storage.fast_replace_cache and storage.fast_replace_cache[pos_key] then
                                local cached = storage.fast_replace_cache[pos_key]
                                local cur_tick = event.tick or game.tick
                                if cached and cached.tick == cur_tick and cached.name == real_name then
                                    if spec.name == "pneumatic-pump" then
                                        pump_settings.apply_blueprint_settings(target_dev_id, cached.settings)
                                        copied = true
                                    elseif spec.name == "pneumatic-diverter" then
                                        diverter_settings.apply_blueprint_settings(target_dev_id, cached.settings)
                                        if cached.direction and cached.direction ~= target_entity.direction then
                                            diverter_settings.rotate_ports(target_dev_id, cached.direction, target_entity.direction)
                                        end
                                        copied = true
                                    elseif spec.name == "pneumatic-capsule-counter" then
                                        counter_settings.apply_blueprint_settings(target_dev_id, cached.settings)
                                        copied = true
                                    elseif spec.name == "pneumatic-projector" then
                                        projector_settings.apply_blueprint_settings(target_dev_id, cached.settings)
                                        if cached.direction and cached.direction ~= target_entity.direction then
                                            projector_settings.rotate_muzzle(target_dev_id, cached.direction, target_entity.direction)
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

                    if spec.name == "pneumatic-diverter" then
                        diverter_renderer.update_render(target_entity)
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
                if spec.name == "pneumatic-diverter" then
                    diverter_renderer.update_render(entity)
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
                            local dest_id = get_spec_device_id(spec.name, replacement)
                            if spec.name == "pneumatic-pump" then
                                pump_settings.copy(dev_id, dest_id)
                            elseif spec.name == "pneumatic-diverter" then
                                diverter_settings.copy(dev_id, dest_id, entity.direction, replacement.direction)
                            elseif spec.name == "pneumatic-capsule-counter" then
                                counter_settings.copy(dev_id, dest_id)
                            elseif spec.name == "pneumatic-projector" then
                                projector_settings.copy(dev_id, dest_id, entity.direction, replacement.direction)
                            end
                        end

                        local cur_settings = nil
                        if spec.name == "pneumatic-pump" and storage.pump_settings then
                            cur_settings = storage.pump_settings[dev_id]
                        elseif spec.name == "pneumatic-diverter" and storage.diverter_settings then
                            cur_settings = storage.diverter_settings[dev_id]
                        elseif spec.name == "pneumatic-capsule-counter" and storage.counter_settings then
                            cur_settings = storage.counter_settings[dev_id]
                        elseif spec.name == "pneumatic-projector" and storage.projector_settings then
                            cur_settings = storage.projector_settings[dev_id]
                        end

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
                        if spec.name == "pneumatic-pump" and storage.pump_settings then
                            storage.pump_settings[dev_id] = nil
                        elseif spec.name == "pneumatic-diverter" and storage.diverter_settings then
                            storage.diverter_settings[dev_id] = nil
                        elseif spec.name == "pneumatic-capsule-counter" and storage.counter_settings then
                            storage.counter_settings[dev_id] = nil
                        elseif spec.name == "pneumatic-projector" and storage.projector_settings then
                            storage.projector_settings[dev_id] = nil
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