local port_walk = {}

--- Traverses connected ports through edges matching the specified connection type
-- @param start_port_key string Format "unit_number:port_index"
-- @param match_conn_type string Connection type to traverse (e.g. "merge", "join")
-- @return table<string, boolean> Set of all visited port keys {[port_key] = true}
function port_walk.traverse(start_port_key, match_conn_type)
    local visited = {}
    if not (start_port_key and match_conn_type and storage.port_connections) then 
        return visited 
    end

    visited[start_port_key] = true
    local queue = { start_port_key }
    local head = 1

    while head <= #queue do
        local current_key = queue[head]
        head = head + 1

        local neighbors = storage.port_connections[current_key]
        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                if conn_type == match_conn_type and not visited[neighbor_key] then
                    visited[neighbor_key] = true
                    table.insert(queue, neighbor_key)
                end
            end
        end
    end

    return visited
end

return port_walk