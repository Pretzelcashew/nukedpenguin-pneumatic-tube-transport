local events = require("scripts.events")
local networks = require("scripts.networks.networks")
require("scripts/debug-manager")
require("scripts.ports.port-renderer")
require("scripts.ports.port-finder")
require("scripts.networks.network-connect")
require("scripts.networks.network-disconnect")
require("scripts.networks.network-rotate")
require("scripts.hubs.hub-manager")
require("scripts.capsules.capsule-runner")
require("scripts.networks.pump-manager")

local function setup_storage()
    storage.port_connections = storage.port_connections or {}
    storage.active_hubs = storage.active_hubs or {}
    storage.hub_settings = storage.hub_settings or {}
    networks.init()
end

script.on_init(setup_storage)
script.on_configuration_changed(setup_storage)