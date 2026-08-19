-- control.lua
local events = require("scripts.events")
--require("scripts.event-logger")
require("scripts.ports.port-renderer")
require("scripts.ports.port-finder")
require("scripts.ports.port-logger")

script.on_init(function()
    storage.port_connections = storage.port_connections or {}
end)

script.on_configuration_changed(function()
    storage.port_connections = storage.port_connections or {}
end)