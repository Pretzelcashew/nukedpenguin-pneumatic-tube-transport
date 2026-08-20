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

    -- Iterate through entity's ports and process existing graph edges
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        local neighbors = storage.port_connections and storage.port_connections[port_key]

        if neighbors then
            -- Copy neighbors map to safely iterate during mutation
            local neighbor_edges = {}
            for neighbor_key, conn_type in pairs(neighbors) do
                table.insert(neighbor_edges, { key = neighbor_key, type = conn_type })
            end

            for _, edge in ipairs(neighbor_edges) do
                -- Map the stored edge connection type directly to its unoutcome counterpart
                local unoutcome = "un" .. edge.type  -- "merge" -> "unmerge", "join" -> "unjoin"
                local def = connection_defs.types[unoutcome]

                if def and def.handler then
                    -- Unoutcome handler does all graph cleanup and component splits
                    def.handler(port_key, edge.key)
                end
            end
        end

        -- Clean up orphaned network mapping for this port
        if storage.networks and storage.networks.port_to_network then
            storage.networks.port_to_network[port_key] = nil
        end
    end
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end