local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")
local port_walk = require("scripts.ports.port-walk")
local networks = require("scripts.networks.networks")

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

    networks.init()

    local unit_number = entity.unit_number
    local external_neighbors_to_check = {}
    local affected_old_net_ids = {}

    -- 1. Gather neighbors and clear entity port entries
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)

        local old_net_id = storage.networks.port_to_network[port_key]
        if old_net_id then
            affected_old_net_ids[old_net_id] = true
        end

        local neighbors = storage.port_connections[port_key]
        if neighbors then
            for neighbor_key in pairs(neighbors) do
                -- Only keep neighbors belonging to external entities
                local neighbor_unit = tonumber(neighbor_key:match("^(%d+):"))
                if neighbor_unit ~= unit_number then
                    table.insert(external_neighbors_to_check, neighbor_key)
                end

                -- Disconnect neighbor's connection back to this port
                if storage.port_connections[neighbor_key] then
                    storage.port_connections[neighbor_key][port_key] = nil
                    if next(storage.port_connections[neighbor_key]) == nil then
                        storage.port_connections[neighbor_key] = nil
                    end
                end
            end
        end

        storage.port_connections[port_key] = nil
        storage.networks.port_to_network[port_key] = nil
    end

    -- Clear stale old network IDs
    for old_id in pairs(affected_old_net_ids) do
        storage.networks.list[old_id] = nil
    end

    -- 2. Traverse severed subgraphs to build new isolated networks
    local visited_all = {}

    for _, start_key in ipairs(external_neighbors_to_check) do
        if not visited_all[start_key] then
            local visited_subgraph = port_walk.traverse(start_key)

            local new_net_id = networks.create()
            for node_key in pairs(visited_subgraph) do
                visited_all[node_key] = true
                storage.networks.port_to_network[node_key] = new_net_id

                local u_num, p_idx = node_key:match("^(%d+):(%d+)$")
                if u_num and p_idx then
                    table.insert(storage.networks.list[new_net_id].members, {
                        unit_number = tonumber(u_num),
                        port_index = tonumber(p_idx)
                    })
                end
            end

            game.print(string.format("[REMOVAL SPLIT] Formed Network #%d starting from %s", new_net_id, start_key))
        end
    end
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end