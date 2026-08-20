local networks = require("scripts.networks.networks")
local port_walk = require("scripts.ports.port-walk")
local network_unmerge = {}

function network_unmerge.execute(severed_port_key, neighbor_key)
    networks.init()

    -- Disconnect the edge from the graph
    networks.remove_connection(severed_port_key, neighbor_key)

    -- Perform graph walk only along "merge" connections
    local visited_subgraph = port_walk.traverse(neighbor_key, "merge")

    -- Assign a new network ID to the separated subgraph component
    local new_net_id = networks.create()
    for node_key in pairs(visited_subgraph) do
        storage.networks.port_to_network[node_key] = new_net_id

        local u_num, p_idx = node_key:match("^(%d+):(%d+)$")
        if u_num and p_idx then
            table.insert(storage.networks.list[new_net_id].members, {
                unit_number = tonumber(u_num),
                port_index = tonumber(p_idx)
            })
        end
    end

    game.print(string.format("[UNMERGE] Severed %s <-> %s. Created Network #%d", severed_port_key, neighbor_key, new_net_id))
end

return network_unmerge