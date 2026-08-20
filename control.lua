local events = require("scripts.events")
local networks = require("scripts.networks.networks")
require("scripts.ports.port-renderer")
require("scripts.ports.port-finder")
require("scripts.ports.port-connection")
require("scripts.networks.member-removed")


local function setup_storage()
    storage.port_connections = storage.port_connections or {}
    networks.init()
end

script.on_init(setup_storage)
script.on_configuration_changed(setup_storage)