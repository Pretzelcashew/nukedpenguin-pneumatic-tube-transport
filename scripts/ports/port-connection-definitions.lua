local network_join = require("scripts.networks.network-join")
local network_merge = require("scripts.networks.network-merge")
local network_unjoin = require("scripts.networks.network-unjoin")
local network_unmerge = require("scripts.networks.network-unmerge")

local connection_defs = {}

connection_defs.types = {
    ["join"]    = { handler = network_join.execute },
    ["merge"]   = { handler = network_merge.execute },
    ["unjoin"]  = { handler = network_unjoin.execute },
    ["unmerge"] = { handler = network_unmerge.execute }
}

connection_defs.inverses = {
    ["merge"] = "unmerge",
    ["join"]  = "unjoin"
}

return connection_defs