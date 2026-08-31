local networks = require("scripts.networks.networks")
local network_rebuild_engine = require("scripts.networks.network-rebuild-engine")

local network_unmerge = {}

function network_unmerge.execute(severed_port_key, neighbor_key)
    networks.init()

    local old_net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[neighbor_key]

    -- 1. Sever the physical edge instantly (O(1))
    networks.remove_connection(severed_port_key, neighbor_key)

    if not old_net_id then return end

    -- 2. Delegate graph split validation to the time-sliced rebuild engine
    network_rebuild_engine.queue_split(severed_port_key, neighbor_key, old_net_id)
end

return network_unmerge