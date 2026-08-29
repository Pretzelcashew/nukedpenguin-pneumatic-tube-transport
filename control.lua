local events = require("scripts.events")
local networks = require("scripts.networks.networks")
local networks_flow = require("scripts.networks.networks-flow")
local liminal_surface = require("scripts.surfaces.liminal-surface")

require("scripts.debug-manager")
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

local function setup_storage()
    storage.port_connections = storage.port_connections or {}
    storage.active_hubs = storage.active_hubs or {}
    storage.hub_settings = storage.hub_settings or {}
    storage.diverter_settings = storage.diverter_settings or {}
    storage.pump_settings = storage.pump_settings or {}
    storage.active_diverters = storage.active_diverters or {}
    storage.diverter_power_states = storage.diverter_power_states or {}
    networks.init()
    liminal_surface.init_storage()

    if is_debug_active("flow") then
        networks_flow.draw_all()
    end
end

script.on_init(setup_storage)
script.on_configuration_changed(setup_storage)