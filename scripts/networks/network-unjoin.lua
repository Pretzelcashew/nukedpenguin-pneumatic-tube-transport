local networks = require("scripts.networks.networks")
local network_unjoin = {}

function network_unjoin.execute(severed_port_key, neighbor_key)
    networks.init()

    -- Sever the boundary edge
    networks.remove_connection(severed_port_key, neighbor_key)

    -- Join edges do not merge networks, so severing one does not require rebuilding subgraphs.
    -- We simply unbind if the neighbor entity no longer has any active connections.
    debug_print(string.format("[UNJOIN] Severed boundary edge %s <-> %s", severed_port_key, neighbor_key))
end

return network_unjoin