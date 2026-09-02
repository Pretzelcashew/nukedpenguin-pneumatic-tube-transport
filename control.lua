local events = require("scripts.events")
local networks = require("scripts.networks.networks")
local networks_flow = require("scripts.networks.networks-flow")
local liminal_surface = require("scripts.surfaces.liminal-surface")
local debug_manager = require("scripts.debug-manager")

require("scripts.ports.port-renderer")
require("scripts.ports.port-finder")
require("scripts.networks.network-connect")
require("scripts.networks.network-disconnect")
require("scripts.networks.network-rotate")
require("scripts.hubs.hub-manager")
require("scripts.hubs.hub-gui")
require("scripts.diverter-settings")
require("scripts.diverter-gui")
require("scripts.pump-settings")
require("scripts.pump-gui")
require("scripts.capsules.capsule-runner")
require("scripts.networks.pump-manager")
require("scripts.networks.diverter-manager")
require("scripts.capsules.capsule-inputs")

require("prototypes.pneumatic-diverter-proxy-linkage")
require("prototypes.pneumatic-pump-proxy-linkage")

local port_defs = require("scripts.flow.port-defs")
local flow_engine = require("scripts.flow.flow-engine")
local v2_capsule_runner = require("scripts.flow.capsule-runner")

local FLOW_VERSION = settings.startup["pneumatic-flow-version"] and settings.startup["pneumatic-flow-version"].value or "v1"

if FLOW_VERSION == "v2" then
    flow_engine.register_events()
    v2_capsule_runner.register_events()
end

local function setup_storage()
    storage.port_connections = storage.port_connections or {}
    storage.active_hubs = storage.active_hubs or {}
    storage.hub_settings = storage.hub_settings or {}
    storage.diverter_settings = storage.diverter_settings or {}
    storage.pump_settings = storage.pump_settings or {}
    storage.active_diverters = storage.active_diverters or {}
    storage.diverter_power_states = storage.diverter_power_states or {}
    storage.bio_integrity_levels = storage.bio_integrity_levels or {}

    networks.init()
    liminal_surface.init_storage()

    if FLOW_VERSION == "v2" then
        flow_engine.init_storage()

        for _, surface in pairs(game.surfaces) do
            local entities = surface.find_entities_filtered{name = port_defs.registered_names}
            for _, entity in ipairs(entities) do
                if entity.valid and entity.unit_number then
                    flow_engine.connect_entity(entity)
                end
            end
        end
    end

    for _, player in pairs(game.players) do
        debug_manager.sync_shortcuts(player.index)
    end

    if FLOW_VERSION == "v1" and is_debug_active("flow") then
        networks_flow.draw_all()
    end
end

script.on_init(setup_storage)
script.on_configuration_changed(setup_storage)