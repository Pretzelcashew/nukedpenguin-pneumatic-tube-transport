local events = require("scripts.events")
local flow_engine = require("scripts.flow.flow-engine")
local capsule_runner = require("scripts.capsules.capsule-runner")
local pump_settings = require("scripts.pump-settings")
local diverter_settings = require("scripts.diverter-settings")
local diverter_renderer = require("scripts.diverter-renderer")

local active_device_scanner = {}

local SCAN_INTERVAL = 15

local device_specs_by_name = {}
local device_specs_list = {}
local settings_changed_callbacks = {}

local PROXY_NAMES = {
    ["pneumatic-diverter-circuit-proxy"] = true,
    ["pneumatic-pump-circuit-proxy"] = true
}

local function get_pos_key(surface, position, real_name)
    if not (surface and position) then return nil end
    local sname = type(surface) == "string" and surface or surface.name
    local px = position.x or position[1] or 0
    local py = position.y or position[2] or 0
    local prefix = real_name or "device"
    return prefix .. "@" .. sname .. "@" .. px .. "," .. py
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
    end

    for i = 1, #settings_changed_callbacks do
        settings_changed_callbacks[i](entity)
    end

    if not is_ghost then
        flow_engine.enqueue_unit_ports(unit_number)
        capsule_runner.wake_parked_capsules(unit_number)
    end
end

local function scan_active_devices()
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

function active_device_scanner.register_events()
    events.on_event(defines.events.on_tick, function(event)
        if (event.tick % SCAN_INTERVAL) == 0 then
            scan_active_devices()
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
                    local dev_id = spec.name == "pneumatic-diverter" and diverter_settings.get_device_id(entity) or pump_settings.get_device_id(entity)
                    local pos_key = get_pos_key(entity.surface, entity.position, real_name)

                    if is_ghost then
                        storage.ghost_devices = storage.ghost_devices or {}
                        storage.ghost_devices[dev_id] = entity
                        if pos_key then
                            storage.ghost_by_pos = storage.ghost_by_pos or {}
                            storage.ghost_by_pos[pos_key] = dev_id
                        end
                        storage.ghost_directions = storage.ghost_directions or {}
                        storage.ghost_directions[dev_id] = entity.direction
                    else
                        storage[spec.storage_key] = storage[spec.storage_key] or {}
                        storage[spec.storage_key][entity.unit_number] = entity
                    end

                    local ghost_id = nil
                    if not is_ghost then
                        if pos_key and storage.ghost_by_pos then
                            ghost_id = storage.ghost_by_pos[pos_key]
                        end
                        if not ghost_id and event.consumed_ghost and event.consumed_ghost.valid then
                            ghost_id = spec.name == "pneumatic-diverter" and diverter_settings.get_device_id(event.consumed_ghost) or pump_settings.get_device_id(event.consumed_ghost)
                        end
                        if not ghost_id and event.source and event.source.valid then
                            ghost_id = spec.name == "pneumatic-diverter" and diverter_settings.get_device_id(event.source) or pump_settings.get_device_id(event.source)
                        end
                        if not ghost_id then
                            local ghosts = entity.surface.find_entities_filtered{
                                ghost_name = real_name,
                                position = entity.position
                            }
                            if ghosts and ghosts[1] and ghosts[1].valid then
                                ghost_id = spec.name == "pneumatic-diverter" and diverter_settings.get_device_id(ghosts[1]) or pump_settings.get_device_id(ghosts[1])
                            end
                        end
                    end

                    local copied = false
                    if event.tags and event.tags.pneumatic_settings then
                        if spec.apply_blueprint_settings then
                            spec.apply_blueprint_settings(entity, event.tags.pneumatic_settings)
                            copied = true
                        end
                    elseif ghost_id and ghost_id ~= dev_id and not is_ghost then
                        local src_dir = (storage.ghost_directions and storage.ghost_directions[ghost_id])
                            or (event.consumed_ghost and event.consumed_ghost.valid and event.consumed_ghost.direction)
                            or (event.source and event.source.valid and event.source.direction)
                            or entity.direction

                        if spec.name == "pneumatic-pump" then
                            copied = (pump_settings.copy(ghost_id, dev_id) ~= nil)
                        elseif spec.name == "pneumatic-diverter" then
                            copied = (diverter_settings.copy(ghost_id, dev_id, src_dir, entity.direction) ~= nil)
                        end

                        if pos_key and storage.ghost_by_pos then
                            storage.ghost_by_pos[pos_key] = nil
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
                        end
                    end

                    if not copied and spec.init_settings then
                        spec.init_settings(entity)
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
                end
            end
        end)
    end

    local destroy_events = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.events.script_raised_destroy,
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
                    local dev_id = spec.name == "pneumatic-diverter" and diverter_settings.get_device_id(entity) or pump_settings.get_device_id(entity)
                    if is_ghost then
                        local pos_key = get_pos_key(entity.surface, entity.position, real_name)
                        if pos_key and storage.ghost_by_pos then
                            storage.ghost_by_pos[pos_key] = nil
                        end
                        if storage.ghost_directions then
                            storage.ghost_directions[dev_id] = nil
                        end
                        if storage.ghost_devices then
                            storage.ghost_devices[dev_id] = nil
                        end
                        if spec.name == "pneumatic-pump" and storage.pump_settings then
                            storage.pump_settings[dev_id] = nil
                        elseif spec.name == "pneumatic-diverter" and storage.diverter_settings then
                            storage.diverter_settings[dev_id] = nil
                        end
                    else
                        if storage[spec.storage_key] and entity.unit_number then
                            storage[spec.storage_key][entity.unit_number] = nil
                        end
                        if spec.name == "pneumatic-pump" and storage.pump_settings then
                            storage.pump_settings[dev_id] = nil
                        elseif spec.name == "pneumatic-diverter" and storage.diverter_settings then
                            storage.diverter_settings[dev_id] = nil
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
                    local dev_id = spec.name == "pneumatic-diverter" and diverter_settings.get_device_id(entity) or pump_settings.get_device_id(entity)
                    if spec.on_rotate then
                        spec.on_rotate(entity, event)
                    end
                    if is_ghost then
                        storage.ghost_directions = storage.ghost_directions or {}
                        storage.ghost_directions[dev_id] = entity.direction
                    end
                    active_device_scanner.notify_settings_changed(entity)
                end
            end
        end)
    end
end

return active_device_scanner