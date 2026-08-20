local port_walk = {}

--- Traverses all connected ports starting from a given port key
-- @param start_port_key string Format "unit_number:port_index"
-- @return table<string, boolean> Set of all visited port keys {[port_key] = true}
function port_walk.traverse(start_port_key)
    local visited = {}
    if not start_port_key then return visited end

    visited[start_port_key] = true

    -- If the port has no recorded connections, return just itself
    if not (storage.port_connections and storage.port_connections[start_port_key]) then
        return visited
    end

    local queue = { start_port_key }
    local head = 1

    while head <= #queue do
        local current_key = queue[head]
        head = head + 1

        local neighbors = storage.port_connections[current_key]
        if neighbors then
            for neighbor_key in pairs(neighbors) do
                if not visited[neighbor_key] then
                    visited[neighbor_key] = true
                    table.insert(queue, neighbor_key)
                end
            end
        end
    end

    return visited
end

return port_walk