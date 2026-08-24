-- scripts/networks/networks-pressure.lua
local port_defs = require("scripts.ports.port-definitions")

local networks_pressure = {}

-- Configurable pressure dropoff per external hop
local PRESSURE_DROPOFF = 1

local function get_entity_and_port(port_key)
    local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[port_key]
    if not net_id then return nil, nil end

    local net = storage.networks.list and storage.networks.list[net_id]
    if not (net and net.members) then return nil, nil end

    local unit_num, p_idx = port_key:match("^(%d+):(%d+)$")
    unit_num = tonumber(unit_num)
    p_idx = tonumber(p_idx)

    for _, member in ipairs(net.members) do
        if member.unit_number == unit_num and member.port_index == p_idx then
            if member.entity and member.entity.valid then
                local ports = port_defs.get_ports(member.entity)
                return member.entity, ports and ports[p_idx]
            end
        end
    end
    return nil, nil
end

--- Traverses graph edges to collect all network IDs physically connected to the target network
local function get_connected_network_ids(start_net_id)
    local connected_nets = { [start_net_id] = true }
    local queue = { start_net_id }
    local head = 1

    while head <= #queue do
        local curr_net_id = queue[head]
        head = head + 1

        local net = storage.networks.list and storage.networks.list[curr_net_id]
        if net and net.members then
            for _, member in ipairs(net.members) do
                local key = member.unit_number .. ":" .. member.port_index
                local neighbors = storage.port_connections and storage.port_connections[key]
                if neighbors then
                    for n_key, _ in pairs(neighbors) do
                        local n_net_id = storage.networks.port_to_network and storage.networks.port_to_network[n_key]
                        if n_net_id and not connected_nets[n_net_id] then
                            connected_nets[n_net_id] = true
                            table.insert(queue, n_net_id)
                        end
                    end
                end
            end
        end
    end

    return connected_nets
end

local function can_propagate(curr, n_unit, n_flow, conn_type, next_p)
    if curr.unit_number == n_unit then
        if curr.flow ~= "any" and n_flow ~= "any" then
            return false
        end
        return true
    end

    local flow_ok = false
    if next_p > 0 then
        flow_ok = (curr.flow ~= "in" and n_flow ~= "out")
    elseif next_p < 0 then
        flow_ok = (curr.flow ~= "out" and n_flow ~= "in")
    end

    if not flow_ok then return false end

    if conn_type == "join" and curr.entered_via_join then
        return false
    end

    return true
end

--- Propagates pressure only across the connected subgraph containing net_id
-- @return table Map of affected net_ids { [net_id] = true }
function networks_pressure.process(net_id)
    if not net_id then return {} end

    storage.port_pressures = storage.port_pressures or {}

    -- 1. Identify all network IDs physically reachable from net_id
    local affected_nets = get_connected_network_ids(net_id)

    -- 2. Clear stored pressures ONLY for ports belonging to affected networks
    for affected_id in pairs(affected_nets) do
        local net = storage.networks.list[affected_id]
        if net and net.members then
            for _, member in ipairs(net.members) do
                local key = member.unit_number .. ":" .. member.port_index
                storage.port_pressures[key] = 0
            end
        end
    end

    local fixed_sources = {}
    local queue = {}
    local calculated = {}

    -- 3. Register fixed pressure sources within the affected connected component
    for affected_id in pairs(affected_nets) do
        local net = storage.networks.list[affected_id]
        if net and net.members then
            for _, member in ipairs(net.members) do
                if member.entity and member.entity.valid then
                    local ports = port_defs.get_ports(member.entity)
                    local port = ports and ports[member.port_index]

                    if port and port.pressure and port.pressure ~= 0 then
                        local key = member.unit_number .. ":" .. member.port_index
                        fixed_sources[key] = true
                        calculated[key] = port.pressure

                        table.insert(queue, {
                            key = key,
                            unit_number = member.unit_number,
                            pressure = port.pressure,
                            flow = port.flow,
                            entered_via_join = false
                        })
                    end
                end
            end
        end
    end

    -- 4. Multi-source BFS traversal constrained to the connected subgraph
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
                        local n_entity, n_port = get_entity_and_port(neighbor_key)

                        if n_entity and n_port then
                            local n_unit = n_entity.unit_number
                            local n_flow = n_port.flow

                            -- Internal hops (same entity) cost 0 dropoff; external hops cost PRESSURE_DROPOFF
                            local dropoff = (curr.unit_number == n_unit) and 0 or PRESSURE_DROPOFF

                            local next_p = 0
                            if curr_p > 0 then
                                next_p = math.max(0, curr_p - dropoff)
                            elseif curr_p < 0 then
                                next_p = math.min(0, curr_p + dropoff)
                            end

                            if next_p ~= 0 then
                                if can_propagate(curr, n_unit, n_flow, conn_type, next_p) then
                                    local existing_p = calculated[neighbor_key] or 0

                                    local next_entered_via_join
                                    if curr.unit_number == n_unit then
                                        next_entered_via_join = curr.entered_via_join
                                    else
                                        next_entered_via_join = (conn_type == "join")
                                    end

                                    if existing_p == 0 or math.abs(next_p) > math.abs(existing_p) then
                                        calculated[neighbor_key] = next_p
                                        table.insert(queue, {
                                            key = neighbor_key,
                                            unit_number = n_unit,
                                            pressure = next_p,
                                            flow = n_flow,
                                            entered_via_join = next_entered_via_join
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
    end

    -- 5. Commit calculated pressure values back to persistent storage
    for key, val in pairs(calculated) do
        storage.port_pressures[key] = val
    end

    return affected_nets
end

return networks_pressure