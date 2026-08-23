-- scripts/networks/network-invalidate.lua
local port_defs = require("scripts.ports.port-definitions")
local connection_defs = require("scripts.ports.port-connection-definitions")
local networks = require("scripts.networks.networks")
local networks_flow = require("scripts.networks.networks-flow")

local network_invalidate = {}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

--- Completely severs an entity from the network and purges its internal port data.
function network_invalidate.execute(entity)
    if not (entity and entity.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local unit_number = entity.unit_number
    local neighbor_keys = {}

    -- Cache external neighbor port keys before unlinking connections
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        local neighbors = storage.port_connections and storage.port_connections[port_key]

        if neighbors then
            for neighbor_key, _ in pairs(neighbors) do
                local neighbor_unit = tonumber(neighbor_key:match("^(%d+):"))
                if neighbor_unit ~= unit_number then
                    table.insert(neighbor_keys, neighbor_key)
                end
            end
        end
    end

    -- 1. Process EXTERNAL connections only
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        local neighbors = storage.port_connections and storage.port_connections[port_key]

        if neighbors then
            local external_edges = {}
            for neighbor_key, conn_type in pairs(neighbors) do
                local neighbor_unit = tonumber(neighbor_key:match("^(%d+):"))
                if neighbor_unit ~= unit_number then
                    table.insert(external_edges, { key = neighbor_key, type = conn_type })
                end
            end

            for _, edge in ipairs(external_edges) do
                local unoutcome = connection_defs.inverses[edge.type]
                local def = connection_defs.types[unoutcome]

                if def and def.handler then
                    def.handler(port_key, edge.key)
                end
            end
        end
    end

    -- 2. Fully purge all internal graph nodes & network mappings via API
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        networks.purge_port(port_key)
    end

    -- 3. Rebuild flow maps for all surviving neighbor networks
    local affected_networks = {}
    for _, n_key in ipairs(neighbor_keys) do
        local n_net_id = storage.networks.port_to_network[n_key]
        if n_net_id then
            affected_networks[n_net_id] = true
        end
    end

    for net_id in pairs(affected_networks) do
        networks_flow.build(net_id)
    end
end

return network_invalidate