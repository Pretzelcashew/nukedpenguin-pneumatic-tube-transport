local events = require("scripts.events")
local liminal_surface = require("scripts.surfaces.liminal-surface")
local debug_manager = require("scripts.debug-manager")
local proxy_manager = require("scripts.proxy-manager")
local active_device_scanner = require("scripts.active-device-scanner")
local device_settings_copier = require("scripts.device-settings-copier")

require("scripts.hubs.hub-manager")
require("scripts.hubs.hub-gui")
require("scripts.diverter-settings")
require("scripts.diverter-gui")
require("scripts.pump-settings")
require("scripts.pump-gui")
require("scripts.capsules.capsule-runner")
require("scripts.capsules.capsule-inputs")

local port_defs = require("scripts.flow.port-defs")
local flow_engine = require("scripts.flow.flow-engine")
local capsule_runner = require("scripts.capsules.capsule-runner")

proxy_manager.register_events()
active_device_scanner.register_events()
device_settings_copier.register_events()
flow_engine.register_events()
capsule_runner.register_events()

local function setup_storage()
    -- Clear legacy v1 storage tables
    storage.networks = nil
    storage.port_connections = nil
    storage.port_pressures = nil
    storage.network_rebuild_queue = nil
    storage.port_to_network = nil

    storage.active_hubs = storage.active_hubs or {}
    storage.hub_settings = storage.hub_settings or {}
    storage.diverter_settings = storage.diverter_settings or {}
    storage.pump_settings = storage.pump_settings or {}
    storage.active_pumps = storage.active_pumps or {}
    storage.pump_power_states = storage.pump_power_states or {}
    storage.pump_enabled_states = storage.pump_enabled_states or {}
    storage.active_diverters = storage.active_diverters or {}
    storage.diverter_power_states = storage.diverter_power_states or {}
    storage.diverter_port_states = storage.diverter_port_states or {}
    storage.bio_integrity_levels = storage.bio_integrity_levels or {}

    liminal_surface.init_storage()

    flow_engine.init_storage()
    storage.parked_by_port = storage.parked_by_port or {}
    storage.object_destruction_map = storage.object_destruction_map or {}

    proxy_manager.purge_orphans()

    if storage.active_capsules and script.register_on_object_destroyed then
        for cap_id, cap_data in pairs(storage.active_capsules) do
            if cap_data.holder and cap_data.holder.valid then
                local reg_id = script.register_on_object_destroyed(cap_data.holder)
                storage.object_destruction_map[reg_id] = { type = "capsule", id = cap_id }
            end
        end
    end

    if storage.capsules then
        for cap_id, capsule in pairs(storage.capsules) do
            if capsule.from_port_key and capsule.to_port_key == nil and capsule.next_retry_tick then
                storage.parked_by_port[capsule.from_port_key] = storage.parked_by_port[capsule.from_port_key] or {}
                storage.parked_by_port[capsule.from_port_key][cap_id] = true
                capsule.parked_at_port = capsule.from_port_key
            end
        end
    end

    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered{name = port_defs.registered_names}
        for _, entity in ipairs(entities) do
            if entity.valid and entity.unit_number then
                flow_engine.connect_entity(entity)
            end
        end
    end

    for _, player in pairs(game.players) do
        debug_manager.sync_shortcuts(player.index)
    end
end

script.on_init(setup_storage)
script.on_configuration_changed(function(data)
    storage.networks = nil
    storage.port_connections = nil
    storage.port_pressures = nil
    storage.network_rebuild_queue = nil
    storage.port_to_network = nil
    setup_storage(data)
end)