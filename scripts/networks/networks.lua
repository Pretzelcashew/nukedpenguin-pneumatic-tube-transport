-- scripts/networks/networks.lua
local store = require("scripts.networks.networks-store")
local graph = require("scripts.networks.networks-graph")

local networks = {}

-- Proxy store functions
networks.init = store.init
networks.create = store.create
networks.delete = store.delete
networks.merge = store.merge
networks.purge_port = store.purge_port

-- Proxy metadata functions
networks.set_metadata = store.set_metadata
networks.get_metadata = store.get_metadata
networks.extract_metadata = store.extract_metadata

-- Proxy graph functions
networks.record_connection = graph.record_connection
networks.remove_connection = graph.remove_connection
networks.bind_group_to_network = graph.bind_group_to_network

return networks