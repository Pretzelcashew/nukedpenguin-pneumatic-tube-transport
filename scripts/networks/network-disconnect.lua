local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")
local connection_defs = require("scripts.ports.port-connection-definitions")

local removal_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

local function handle_entity_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local unit_number = entity.unit_number

    -- 1. Process EXTERNAL connections only
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        local neighbors = storage.port_connections and storage.port_connections[port_key]

        if neighbors then
            -- Snapshot neighbor entries to safely iterate
            local external_edges = {}
            for neighbor_key, conn_type in pairs(neighbors) do
                local neighbor_unit = tonumber(neighbor_key:match("^(%d+):"))
                -- CRITICAL FILTER: Ignore internal edges connecting ports on the same entity
                if neighbor_unit ~= unit_number then
                    table.insert(external_edges, { key = neighbor_key, type = conn_type })
                end
            end

            for _, edge in ipairs(external_edges) do
                local unoutcome = "un" .. edge.type  -- "merge" -> "unmerge", "join" -> "unjoin"
                local def = connection_defs.types[unoutcome]

                if def and def.handler then
                    -- Execute unoutcome handler across the external boundary
                    def.handler(port_key, edge.key)
                end
            end
        end
    end

    -- 2. Fully purge all internal graph nodes & network mappings for the removed entity
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        
        -- Clean up internal/external connections table for this port
        if storage.port_connections then
            storage.port_connections[port_key] = nil
        end

        -- Clean up network lookup
        if storage.networks and storage.networks.port_to_network then
            storage.networks.port_to_network[port_key] = nil
        end
    end
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end