local events = require("scripts.events")
local liminal_surface = require("scripts.surfaces.liminal-surface")
local debug_manager = require("scripts.debug-manager")
local proxy_manager = require("scripts.proxy-manager")
local active_device_scanner = require("scripts.active-device-scanner")
local device_settings_copier = require("scripts.device-settings-copier")
local diverter_renderer = require("scripts.diverters.diverter-renderer")

require("scripts.hubs.hub-manager")
require("scripts.hubs.hub-gui")
require("scripts.diverters.diverter-settings")
require("scripts.diverters.diverter-gui")
require("scripts.pumps.pump-settings")
require("scripts.pumps.pump-gui")
require("scripts.counters.counter-settings")
require("scripts.counters.counter-gui")
require("scripts.counters.counter-logic")
require("scripts.projectors.projector-settings")
require("scripts.capsules.capsule-runner")
require("scripts.capsules.capsule-inputs")

local port_defs = require("scripts.flow.port-defs")
local flow_engine = require("scripts.flow.flow-engine")
local counter_range = require("scripts.counters.counter-range")
local capsule_runner = require("scripts.capsules.capsule-runner")

proxy_manager.register_events()
active_device_scanner.register_events()
device_settings_copier.register_events()
flow_engine.register_events()
counter_range.register_events()
capsule_runner.register_events()

local function setup_storage()
    -- Clear legacy storage tables
    storage.networks = nil
    storage.port_connections = nil
    storage.port_pressures = nil
    storage.network_rebuild_queue = nil
    storage.port_to_network = nil
    storage.bio_integrity_levels = nil

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
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.counter_settings = storage.counter_settings or {}
    storage.active_projectors = storage.active_projectors or {}
    storage.projector_settings = storage.projector_settings or {}
    storage.projector_power_states = storage.projector_power_states or {}
    storage.projector_enabled_states = storage.projector_enabled_states or {}
    storage.projector_muzzle_states = storage.projector_muzzle_states or {}

    liminal_surface.init_storage()

    flow_engine.init_storage()
    counter_range.init_storage()
    storage.parked_by_port = storage.parked_by_port or {}
    storage.object_destruction_map = storage.object_destruction_map or {}

    proxy_manager.purge_orphans()

    if storage.active_diverters then
        for _, entity in pairs(storage.active_diverters) do
            if entity and entity.valid then
                diverter_renderer.update_render(entity)
            end
        end
    end

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
                if entity.name == "pneumatic-capsule-counter" then
                    storage.active_counters[entity.unit_number] = entity
                    counter_range.register_counter(entity)
                elseif entity.name == "pneumatic-projector" then
                    storage.active_projectors[entity.unit_number] = entity
                end
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
    storage.bio_integrity_levels = nil
    setup_storage(data)
end)