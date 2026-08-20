-- scripts/ports/port-connection-definitions.lua
local network_join = require("scripts.networks.network-join")

local connection_defs = {}

connection_defs.types = {
    ["join"] = {
        handler = network_join.execute
    },
    ["merge"] = {}
}

return connection_defs