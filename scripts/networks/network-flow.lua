-- scripts/networks/networks-flow.lua
local networks = require("scripts.networks.networks")
local port_defs = require("scripts.ports.port-definitions")

local networks_flow = {}

--- Helper to get port pressure. 
--- IMPORTANT: You must implement a way to fetch the entity by unit_number!
local function get_port_pressure(net, target_unit_number, target_port_index)
    -- Find the member in the network to grab the entity reference
    for _, member in ipairs(net.members) do
        if member.unit_number == target_unit_number and member.port_index == target_port_index then
            if member.entity and member.entity.valid then
                local ports = port_defs.get_ports(member.entity)
                if ports and ports[target_port_index] then
                    return ports[target_port_index].pressure or 0
                end
            end
            break
        end
    end
    return 0
end

--- Generates a directional flow map for a specific network ID
function networks_flow.build(network_id)
    networks.init()
    local net = storage.networks.list[network_id]
    if not net then return end

    local terminators = {}
    local sinks = {}
    local distances = {}

    -- 1. Identify terminators and sinks (ports connected to external networks)
    for _, member in ipairs(net.members) do
        local port_key = member.unit_number .. ":" .. member.port_index
        local neighbors = storage.port_connections[port_key]

        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                -- "join" edges represent the boundaries between different networks
                if conn_type == "join" then
                    local neighbor_pressure = get_port_pressure(neighbor_key)
                    
                    terminators[port_key] = terminators[port_key] or {}
                    table.insert(terminators[port_key], { 
                        handoff_to = neighbor_key, 
                        pressure = neighbor_pressure 
                    })

                    -- If the external neighbor is pulling (negative pressure), this port is an exit (Sink)
                    if neighbor_pressure < 0 then
                        sinks[port_key] = true
                        distances[port_key] = 0 -- Distance to exit is 0
                    end
                end
            end
        end
    end

    -- 2. Propagate the gradient field (BFS)
    local queue = {}
    for sink_key, _ in pairs(sinks) do
        table.insert(queue, sink_key)
    end

    local head = 1
    while head <= #queue do
        local current_key = queue[head]
        head = head + 1
        local current_dist = distances[current_key]

        local neighbors = storage.port_connections[current_key]
        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                -- Only propagate through internal network routing ("merge" connections)
                if conn_type == "merge" then
                    if not distances[neighbor_key] or distances[neighbor_key] > current_dist + 1 then
                        distances[neighbor_key] = current_dist + 1
                        table.insert(queue, neighbor_key)
                    end
                end
            end
        end
    end

    -- 3. Construct the finalized directional flow map
    local flow_map = {}
    for _, member in ipairs(net.members) do
        local port_key = member.unit_number .. ":" .. member.port_index
        local node_flow = {
            next_hops = {}, -- Internal ports to move to
            handoffs = {},  -- External ports to pass data/items to
            distance = distances[port_key] -- The gradient potential
        }

        -- Route internally by strictly moving DOWN the gradient
        local current_dist = distances[port_key]
        if current_dist then
            local neighbors = storage.port_connections[port_key]
            if neighbors then
                for neighbor_key, conn_type in pairs(neighbors) do
                    if conn_type == "merge" and distances[neighbor_key] and distances[neighbor_key] < current_dist then
                        table.insert(node_flow.next_hops, neighbor_key)
                    end
                end
            end
        end

        -- Map the hand-off points for terminators
        if terminators[port_key] then
            for _, handoff in ipairs(terminators[port_key]) do
                -- Hand off to the next network if it is pulling flow
                if handoff.pressure < 0 then
                    table.insert(node_flow.handoffs, handoff.handoff_to)
                end
            end
        end

        flow_map[port_key] = node_flow
    end

    -- 4. Store the compiled map in the network's metadata space
    networks.set_metadata(network_id, "flow_map", flow_map)
    game.print(string.format("[FLOW MAP] Generated gradient map for Network #%d", network_id))

    return flow_map
end

return networks_flow