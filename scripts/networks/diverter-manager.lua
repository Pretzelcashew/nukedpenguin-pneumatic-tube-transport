local events = require("scripts.events")
local diverter_settings = require("scripts.diverter-settings")
local flow_engine = require("scripts.flow.flow-engine")
local capsule_runner = require("scripts.capsules.capsule-runner")

local diverter_manager = {}
local SCAN_INTERVAL = 15

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

local function rebuild_diverter_networks(entity)
    if not (entity and entity.valid) then return end
    flow_engine.enqueue_unit_ports(entity.unit_number)
    capsule_runner.wake_parked_capsules(entity.unit_number)
end

function diverter_manager.notify_settings_changed(entity)
    if not (entity and entity.valid) then return end
    storage.diverter_power_states = storage.diverter_power_states or {}
    storage.diverter_port_states = storage.diverter_port_states or {}

    local unit_number = entity.unit_number
    storage.diverter_power_states[unit_number] = (entity.energy > 0)

    local current_ports = {}
    for i = 1, 4 do
        current_ports[i] = diverter_settings.is_port_enabled(entity, i)
    end
    storage.diverter_port_states[unit_number] = current_ports

    clear_diverter_compiled_filters(unit_number)
    rebuild_diverter_networks(entity)
end

local function register_diverter(entity)
    if not (entity and entity.valid and entity.name == "pneumatic-diverter") then return end
    storage.active_diverters = storage.active_diverters or {}
    storage.diverter_power_states = storage.diverter_power_states or {}
    storage.diverter_port_states = storage.diverter_port_states or {}

    local unit_number = entity.unit_number
    storage.active_diverters[unit_number] = entity
    storage.diverter_power_states[unit_number] = (entity.energy > 0)

    local initial_ports = {}
    for i = 1, 4 do
        initial_ports[i] = diverter_settings.is_port_enabled(entity, i)
    end
    storage.diverter_port_states[unit_number] = initial_ports

    diverter_settings.get(unit_number)
end

local function unregister_diverter(entity)
    if not (entity and entity.valid and entity.name == "pneumatic-diverter") then return end
    local unit_number = entity.unit_number
    if storage.active_diverters then storage.active_diverters[unit_number] = nil end
    if storage.diverter_power_states then storage.diverter_power_states[unit_number] = nil end
    if storage.diverter_port_states then storage.diverter_port_states[unit_number] = nil end
end

local function check_diverter_states()
    if not storage.active_diverters then return end
    storage.diverter_power_states = storage.diverter_power_states or {}
    storage.diverter_port_states = storage.diverter_port_states or {}

    for unit_number, entity in pairs(storage.active_diverters) do
        if entity.valid then
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

            if is_powered ~= last_power or port_changed then
                storage.diverter_power_states[unit_number] = is_powered
                storage.diverter_port_states[unit_number] = current_ports
                clear_diverter_compiled_filters(unit_number)
                rebuild_diverter_networks(entity)
            end
        else
            storage.active_diverters[unit_number] = nil
            storage.diverter_power_states[unit_number] = nil
            storage.diverter_port_states[unit_number] = nil
        end
    end
end

events.on_event(defines.events.on_tick, function(event)
    if (event.tick % SCAN_INTERVAL) == 0 then
        check_diverter_states()
    end
end)

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built
}
for _, id in ipairs(build_events) do
    events.on_event(id, function(event)
        register_diverter(event.entity)
    end)
end

local destroy_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.script_raised_destroy
}
for _, id in ipairs(destroy_events) do
    events.on_event(id, function(event)
        unregister_diverter(event.entity)
    end)
end

local rotate_events = {
    defines.events.on_player_rotated_entity,
    defines.events.on_player_flipped_entity
}
for _, id in ipairs(rotate_events) do
    events.on_event(id, function(event)
        local entity = event.entity
        if entity and entity.valid and entity.name == "pneumatic-diverter" then
            diverter_manager.notify_settings_changed(entity)
        end
    end)
end

return diverter_manager