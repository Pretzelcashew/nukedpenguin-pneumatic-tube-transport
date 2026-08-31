local port_defs = require("scripts.ports.port-definitions")
local connection_defs = require("scripts.ports.port-connection-definitions")
local networks = require("scripts.networks.networks")
local network_rebuild_engine = require("scripts.networks.network-rebuild-engine")

local network_invalidate = {}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

function network_invalidate.execute(entity)
    if not (entity and entity.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local unit_number = entity.unit_number

    -- 1. Record connected neighbor keys before severing connections
    local external_edges = {}
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        local neighbors = storage.port_connections and storage.port_connections[port_key]

        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                local neighbor_unit = tonumber(neighbor_key:match("^(%d+):"))
                if neighbor_unit ~= unit_number then
                    table.insert(external_edges, { port_key = port_key, neighbor_key = neighbor_key, type = conn_type })
                end
            end
        end
    end

    -- 2. Execute unoutcome handlers (severs edges instantly and queues split jobs)
    for _, edge in ipairs(external_edges) do
        local unoutcome = connection_defs.inverses[edge.type]
        local def = connection_defs.types[unoutcome]

        if def and def.handler then
            def.handler(edge.port_key, edge.neighbor_key)
        end
    end

    -- 3. Purge port definitions for the mined entity
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        networks.purge_port(port_key)
    end

    -- 4. Mark surviving neighbor networks as dirty for batched flow/pressure updates
    for _, edge in ipairs(external_edges) do
        local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[edge.neighbor_key]
        if net_id then
            network_rebuild_engine.mark_dirty(net_id)
        end
    end
end

return network_invalidate