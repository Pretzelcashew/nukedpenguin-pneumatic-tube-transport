local network_join = require("scripts.networks.network-join")
local network_merge = require("scripts.networks.network-merge")

local connection_defs = {}

connection_defs.types = {
    ["join"] = { handler = network_join.execute },
    ["merge"] = { handler = network_merge.execute }
}

return connection_defs