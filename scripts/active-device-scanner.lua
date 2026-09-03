local events = require("scripts.events")
local flow_engine = require("scripts.flow.flow-engine")
local capsule_runner = require("scripts.capsules.capsule-runner")
local pump_settings = require("scripts.pump-settings")
local diverter_settings = require("scripts.diverter-settings")

local active_device_scanner = {}

local SCAN_INTERVAL = 15

local device_specs_by_name = {}
local device_specs_list = {}

local function clear_diverter_compiled_filters(unit_number)
    local d_settings = storage.diverter_settings and storage.diverter_settings[unit_number]
    if d_settings and d_settings.ports then
        for i = 1, 4 do
            if d_settings.ports[i] then
                d_settings.ports[i]._compiled = nil
            end
        end
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

    local spec = device_specs_by_name[entity.name]
    if not spec then return end

    local unit_number = entity.unit_number
    if spec.check_and_update_state then
        spec.check_and_update_state(entity, true)
    end

    flow_engine.enqueue_unit_ports(unit_number)
    capsule_runner.wake_parked_capsules(unit_number)
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
        pump_settings.get(entity.unit_number)
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
        diverter_settings.get(entity.unit_number)
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
        defines.events.on_space_platform_built_entity,
        defines.events.on_entity_cloned
    }
    for _, id in ipairs(build_events) do
        events.on_event(id, function(event)
            local entity = event.entity or event.destination
            if entity and entity.valid then
                local spec = device_specs_by_name[entity.name]
                if spec then
                    local unit_number = entity.unit_number
                    storage[spec.storage_key] = storage[spec.storage_key] or {}
                    storage[spec.storage_key][unit_number] = entity

                    if spec.init_settings then
                        spec.init_settings(entity)
                    end
                    if spec.check_and_update_state then
                        spec.check_and_update_state(entity, true)
                    end

                    flow_engine.enqueue_unit_ports(unit_number)
                    capsule_runner.wake_parked_capsules(unit_number)
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
                local spec = device_specs_by_name[entity.name]
                if spec then
                    local unit_number = entity.unit_number
                    if storage[spec.storage_key] then
                        storage[spec.storage_key][unit_number] = nil
                    end
                    if spec.on_unregister then
                        spec.on_unregister(entity, unit_number)
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
            if entity and entity.valid and device_specs_by_name[entity.name] then
                active_device_scanner.notify_settings_changed(entity)
            end
        end)
    end
end

return active_device_scanner