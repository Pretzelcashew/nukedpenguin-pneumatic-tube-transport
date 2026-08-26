local port_defs = require("scripts.ports.port-definitions")

local networks_pressure = {}
local PRESSURE_DROPOFF = 1

--- Traverses graph edges port-by-port to collect network IDs, stopping at internal join boundaries
local function get_connected_network_ids(start_net_id)
    local connected_nets = {}
    local start_net = storage.networks.list and storage.networks.list[start_net_id]
    if not (start_net and start_net.members) then return connected_nets end

    local visited_ports = {}
    local queue = {}

    -- Seed the queue with all ports belonging to the starting network
    for _, member in ipairs(start_net.members) do
        local key = member.unit_number .. ":" .. member.port_index
        visited_ports[key] = true
        table.insert(queue, { key = key, unit_number = member.unit_number })
    end

    local head = 1
    while head <= #queue do
        local curr = queue[head]
        head = head + 1

        local net_id = storage.networks.port_to_network and storage.networks.port_to_network[curr.key]
        if net_id then
            connected_nets[net_id] = true
        end

        local neighbors = storage.port_connections and storage.port_connections[curr.key]
        if neighbors then
            for n_key, conn_type in pairs(neighbors) do
                local n_unit = tonumber(n_key:match("^(%d+):"))

                -- BLOCK INTERNAL JOIN EDGES (Hub & Pump internal boundaries)
                local is_internal_join = (curr.unit_number == n_unit) and (conn_type == "join")

                if not is_internal_join and not visited_ports[n_key] then
                    visited_ports[n_key] = true
                    table.insert(queue, { key = n_key, unit_number = n_unit })
                end
            end
        end
    end

    return connected_nets
end

local function can_propagate(curr, n_unit, n_flow, conn_type, next_p)
    -- Internal hop (same entity): block if edge is "join" (Hubs, Pumps)
    if curr.unit_number == n_unit then
        return conn_type ~= "join" and (curr.flow == "any" or n_flow == "any")
    end

    -- External hop: evaluate directional pressure flow
    if next_p > 0 then
        return (curr.flow ~= "in" and n_flow ~= "out")
    elseif next_p < 0 then
        return (curr.flow ~= "out" and n_flow ~= "in")
    end

    return false
end

function networks_pressure.process(net_id)
    if not net_id then return {} end

    storage.port_pressures = storage.port_pressures or {}
    local affected_nets = get_connected_network_ids(net_id)

    -- 1. Build a local cache of port definitions & reset pressure for affected ports
    local port_cache = {}
    local queue = {}
    local calculated = {}
    local fixed_sources = {}

    for affected_id in pairs(affected_nets) do
        local net = storage.networks.list[affected_id]
        if net and net.members then
            for _, member in ipairs(net.members) do
                local key = member.unit_number .. ":" .. member.port_index
                storage.port_pressures[key] = 0

                if member.entity and member.entity.valid then
                    local ports = port_defs.get_ports(member.entity)
                    local port = ports and ports[member.port_index]

                    if port then
                        port_cache[key] = port

                        if port.pressure and port.pressure ~= 0 then
                            -- Power Check: Unpowered entities (entity.energy == 0) halt pressure generation
                            local is_powered = not (member.entity.energy and member.entity.energy == 0)

                            if is_powered then
                                fixed_sources[key] = true
                                calculated[key] = port.pressure
                                table.insert(queue, {
                                    key = key,
                                    unit_number = member.unit_number,
                                    pressure = port.pressure,
                                    flow = port.flow
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Multi-source BFS traversal driven purely by graph connections
    local head = 1
    while head <= #queue do
        local curr = queue[head]
        head = head + 1

        local curr_p = curr.pressure
        if curr_p ~= 0 then
            local neighbors = storage.port_connections and storage.port_connections[curr.key]
            if neighbors then
                for neighbor_key, conn_type in pairs(neighbors) do
                    if not fixed_sources[neighbor_key] then
                        local n_port = port_cache[neighbor_key]

                        if n_port then
                            local n_unit = tonumber(neighbor_key:match("^(%d+):"))
                            local dropoff = (curr.unit_number == n_unit) and 0 or PRESSURE_DROPOFF

                            local next_p = 0
                            if curr_p > 0 then
                                next_p = math.max(0, curr_p - dropoff)
                            elseif curr_p < 0 then
                                next_p = math.min(0, curr_p + dropoff)
                            end

                            if next_p ~= 0 and can_propagate(curr, n_unit, n_port.flow, conn_type, next_p) then
                                local existing_p = calculated[neighbor_key] or 0

                                if existing_p == 0 or math.abs(next_p) > math.abs(existing_p) then
                                    calculated[neighbor_key] = next_p
                                    table.insert(queue, {
                                        key = neighbor_key,
                                        unit_number = n_unit,
                                        pressure = next_p,
                                        flow = n_port.flow
                                    })
                                elseif math.abs(next_p) == math.abs(existing_p) and ((next_p > 0 and existing_p < 0) or (next_p < 0 and existing_p > 0)) then
                                    calculated[neighbor_key] = 0
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3. Commit calculated pressure values back to persistent storage
    for key, val in pairs(calculated) do
        storage.port_pressures[key] = val
    end

    return affected_nets
end

return networks_pressure