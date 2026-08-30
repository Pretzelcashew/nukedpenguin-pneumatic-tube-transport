local events = require("scripts.events")
local networks_flow = require("scripts.networks.networks-flow")
local port_defs = require("scripts.ports.port-definitions")
local pump_settings = require("scripts.pump-settings")

local pump_manager = {}
local SCAN_INTERVAL = 15 -- Poll power & circuit states every 15 ticks (~4 times per sec)

local function rebuild_pump_networks(entity)
    if not (entity and entity.valid) then return end
    local unit_number = entity.unit_number
    local ports = port_defs.get_ports(entity)
    if not ports then return end

    for p_idx, _ in ipairs(ports) do
        local port_key = unit_number .. ":" .. p_idx
        local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[port_key]
        if net_id then
            networks_flow.build(net_id)
        end
    end
end

function pump_manager.notify_settings_changed(entity)
    if not (entity and entity.valid) then return end
    local unit_number = entity.unit_number
    if storage.pump_enabled_states then
        storage.pump_enabled_states[unit_number] = pump_settings.is_pump_enabled(entity)
    end
    if storage.pump_power_states then
        storage.pump_power_states[unit_number] = (entity.energy > 0)
    end
    rebuild_pump_networks(entity)
end

local function register_pump(entity)
    if not (entity and entity.valid and entity.name == "pneumatic-pump") then return end
    storage.active_pumps = storage.active_pumps or {}
    storage.pump_power_states = storage.pump_power_states or {}
    storage.pump_enabled_states = storage.pump_enabled_states or {}

    local unit_number = entity.unit_number
    storage.active_pumps[unit_number] = entity
    storage.pump_power_states[unit_number] = (entity.energy > 0)
    storage.pump_enabled_states[unit_number] = pump_settings.is_pump_enabled(entity)

    pump_settings.get(unit_number)
end

local function unregister_pump(entity)
    if not (entity and entity.valid and entity.name == "pneumatic-pump") then return end
    local unit_number = entity.unit_number
    if storage.active_pumps then storage.active_pumps[unit_number] = nil end
    if storage.pump_power_states then storage.pump_power_states[unit_number] = nil end
    if storage.pump_enabled_states then storage.pump_enabled_states[unit_number] = nil end
end

local function check_pump_states()
    if not storage.active_pumps then return end
    storage.pump_power_states = storage.pump_power_states or {}
    storage.pump_enabled_states = storage.pump_enabled_states or {}

    for unit_number, entity in pairs(storage.active_pumps) do
        if entity.valid then
            local is_powered = (entity.energy > 0)
            local is_enabled = pump_settings.is_pump_enabled(entity)

            local last_power = storage.pump_power_states[unit_number]
            local last_enabled = storage.pump_enabled_states[unit_number]

            if is_powered ~= last_power or is_enabled ~= last_enabled then
                storage.pump_power_states[unit_number] = is_powered
                storage.pump_enabled_states[unit_number] = is_enabled
                rebuild_pump_networks(entity)
            end
        else
            storage.active_pumps[unit_number] = nil
            storage.pump_power_states[unit_number] = nil
            storage.pump_enabled_states[unit_number] = nil
        end
    end
end

-- Interleaved power & circuit state polling loop
events.on_event(defines.events.on_tick, function(event)
    if (event.tick % SCAN_INTERVAL) == 0 then
        check_pump_states()
    end
end)

-- Entity lifecycle hooks
local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built
}
for _, id in ipairs(build_events) do
    events.on_event(id, function(event)
        register_pump(event.entity)
    end)
end

local destroy_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}
for _, id in ipairs(destroy_events) do
    events.on_event(id, function(event)
        unregister_pump(event.entity)
    end)
end

return pump_manager