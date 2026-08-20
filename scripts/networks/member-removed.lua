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
    local neighbor_keys_to_check = {}

    -- 1. Sever physical edges and unbind entity ports from storage
    for p_idx, _ in ipairs(ports) do
        local port_key = get_port_key(unit_number, p_idx)
        local neighbors = storage.port_connections[port_key]

        if neighbors then
            for neighbor_key in pairs(neighbors) do
                table.insert(neighbor_keys_to_check, neighbor_key)

                -- Disconnect neighbor's link back to this port
                if storage.port_connections[neighbor_key] then
                    storage.port_connections[neighbor_key][port_key] = nil
                    if next(storage.port_connections[neighbor_key]) == nil then
                        storage.port_connections[neighbor_key] = nil
                    end
                end
            end
        end

        -- Clear entity port data from storage
        storage.port_connections[port_key] = nil
        local old_net_id = storage.networks.port_to_network[port_key]
        storage.networks.port_to_network[port_key] = nil

        -- Remove member entry from old network
        if old_net_id and storage.networks.list[old_net_id] then
            local members = storage.networks.list[old_net_id].members
            for i = #members, 1, -1 do
                if members[i].unit_number == unit_number and members[i].port_index == p_idx then
                    table.remove(members, i)
                end
            end
        end
    end

    -- 2. Traverse severed neighbors using port_walk to rebuild network components
    local visited_all = {}

    for _, neighbor_key in ipairs(neighbor_keys_to_check) do
        if not visited_all[neighbor_key] then
            local visited_subgraph = port_walk.traverse(neighbor_key)

            -- Mark visited nodes so we don't re-process the same connected component
            for node_key in pairs(visited_subgraph) do
                visited_all[node_key] = true
            end

            -- Assign new Network ID to the remaining valid subgraph
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

            game.print(string.format("[REMOVAL SPLIT] Formed Network #%d from severed edge starting at %s", new_net_id, neighbor_key))
        end
    end
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end