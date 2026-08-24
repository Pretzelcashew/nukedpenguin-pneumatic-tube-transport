-- scripts/networks/networks-flow.lua
local networks = require("scripts.networks.networks")
local port_defs = require("scripts.ports.port-definitions")
local events = require("scripts.events")

local networks_flow = {}

--- Safely looks up an entity's port pressure using existing network data
local function get_port_pressure(unit_number, port_index)
    local key = unit_number .. ":" .. port_index
    local net_id = storage.networks.port_to_network[key]
    if not net_id then return 0 end
    
    local net = storage.networks.list[net_id]
    if not net then return 0 end

    for _, member in ipairs(net.members) do
        if member.unit_number == tonumber(unit_number) and member.port_index == tonumber(port_index) then
            if member.entity and member.entity.valid then
                local ports = port_defs.get_ports(member.entity)
                return ports and ports[tonumber(port_index)] and ports[tonumber(port_index)].pressure or 0
            end
        end
    end
    return 0
end

--- Safely looks up any port's world position across any network
local function get_port_position(port_key)
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local net = storage.networks.list[net_id]
    if not net then return nil end

    local u_num, p_idx = port_key:match("^(%d+):(%d+)$")
    u_num, p_idx = tonumber(u_num), tonumber(p_idx)

    for _, member in ipairs(net.members) do
        if member.unit_number == u_num and member.port_index == p_idx then
            if member.entity and member.entity.valid then
                local ports = port_defs.get_ports(member.entity)
                if ports and ports[p_idx] then
                    local offset = ports[p_idx].offset
                    return {
                        pos = { x = member.entity.position.x + offset.x, y = member.entity.position.y + offset.y },
                        surface = member.entity.surface
                    }
                end
            end
        end
    end
    return nil
end

--- Generates and stores the flow map data for a network
function networks_flow.build(network_id)
    networks.init()
    local net = storage.networks.list[network_id]
    if not net then return end

    local pressures = {}
    local queue = {}
    local terminators = {}

    -- 1. Seed pressure anchors
    for _, member in ipairs(net.members) do
        local port_key = member.unit_number .. ":" .. member.port_index
        local explicit_pressure = 0

        if member.entity and member.entity.valid then
            local ports = port_defs.get_ports(member.entity)
            if ports and ports[member.port_index] then
                explicit_pressure = ports[member.port_index].pressure or 0
            end
        end

        local neighbors = storage.port_connections[port_key]
        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                if conn_type == "join" then
                    local n_unit, n_port = neighbor_key:match("^(%d+):(%d+)$")
                    local neighbor_pressure = get_port_pressure(n_unit, n_port)
                    
                    terminators[port_key] = terminators[port_key] or {}
                    table.insert(terminators[port_key], { 
                        handoff_to = neighbor_key, 
                        pressure = neighbor_pressure 
                    })

                    if neighbor_pressure ~= 0 and explicit_pressure == 0 then
                        explicit_pressure = neighbor_pressure
                    end
                end
            end
        end

        if explicit_pressure ~= 0 then
            pressures[port_key] = explicit_pressure
            table.insert(queue, { key = port_key, pressure = explicit_pressure })
        end
    end

    -- 2. Propagate pressure
    local decay_rate = 5
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1

        local current_key = current.key
        local current_pressure = current.pressure

        local neighbors = storage.port_connections[current_key]
        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                if conn_type == "merge" then
                    local next_pressure
                    if current_pressure > 0 then
                        next_pressure = math.max(0, current_pressure - decay_rate)
                    elseif current_pressure < 0 then
                        next_pressure = math.min(0, current_pressure + decay_rate)
                    else
                        next_pressure = 0
                    end

                    if next_pressure ~= 0 and (pressures[neighbor_key] == nil or math.abs(next_pressure) > math.abs(pressures[neighbor_key])) then
                        pressures[neighbor_key] = next_pressure
                        table.insert(queue, { key = neighbor_key, pressure = next_pressure })
                    end
                end
            end
        end
    end

    for _, member in ipairs(net.members) do
        local port_key = member.unit_number .. ":" .. member.port_index
        if pressures[port_key] == nil then
            pressures[port_key] = 0
        end
    end

    -- 3. Construct flow map
    local flow_map = {}
    for _, member in ipairs(net.members) do
        local port_key = member.unit_number .. ":" .. member.port_index
        local node_pressure = pressures[port_key]
        local node_flow = { next_hops = {}, handoffs = {}, pressure = node_pressure }
        local current_unit = port_key:match("^(%d+):")
        
        local current_port_idx = member.port_index
        local ports = member.entity and member.entity.valid and port_defs.get_ports(member.entity)

        local neighbors = storage.port_connections[port_key]
        if neighbors then
            for neighbor_key, conn_type in pairs(neighbors) do
                if conn_type == "merge" then
                    local neighbor_unit = neighbor_key:match("^(%d+):")
                    local is_internal = (current_unit == neighbor_unit)
                    local neighbor_pressure = pressures[neighbor_key] or 0

                    if is_internal then
                        local neighbor_port_idx = tonumber(neighbor_key:match(":(%d+)$"))
                        local c_port = ports and ports[current_port_idx]
                        local n_port = ports and ports[neighbor_port_idx]

                        -- Check if we are inside a directional entity (like a pump)
                        if c_port and n_port and (c_port.flow ~= "any" or n_port.flow ~= "any") then
                            if c_port.flow == "in" and n_port.flow == "out" then
                                table.insert(node_flow.next_hops, neighbor_key)
                            end
                        else
                            -- Standard omnidirectional routing (junctions, tubes)
                            if neighbor_pressure < node_pressure then
                                table.insert(node_flow.next_hops, neighbor_key)
                            end
                        end
                    else
                        -- External spatial routing
                        if neighbor_pressure < node_pressure then
                            table.insert(node_flow.next_hops, neighbor_key)
                        end
                    end
                end
            end
        end

        if terminators[port_key] then
            for _, handoff in ipairs(terminators[port_key]) do
                table.insert(node_flow.handoffs, handoff.handoff_to)
            end
        end
        flow_map[port_key] = node_flow
    end

    -- 4. Prune dead-end internal routes only when a better path exists
    local changed = true
    while changed do
        changed = false
        for port_key, node in pairs(flow_map) do
            if #node.next_hops > 1 then
                local active_hops = {}
                local dead_hops = {}
                local current_unit = port_key:match("^(%d+):")

                for _, hop_key in ipairs(node.next_hops) do
                    local hop_unit = hop_key:match("^(%d+):")
                    local hop_node = flow_map[hop_key]
                    
                    local is_internal = (current_unit == hop_unit)
                    local is_dead_end = hop_node and (#hop_node.next_hops == 0 and #hop_node.handoffs == 0)

                    if is_internal and is_dead_end then
                        table.insert(dead_hops, hop_key)
                    else
                        table.insert(active_hops, hop_key)
                    end
                end

                if #active_hops > 0 and #dead_hops > 0 then
                    node.next_hops = active_hops
                    changed = true
                end
            end
        end
    end

    networks.set_metadata(network_id, "flow_map", flow_map)
    return flow_map
end

--- OPTIONAL: Purely visual debug renderer (reads from built flow map)
function networks_flow.draw_debug(network_id)
    local net = storage.networks.list[network_id]
    if not (net and net.metadata and net.metadata.flow_map) then return end

    local flow_map = net.metadata.flow_map

    storage.flow_renders = storage.flow_renders or {}
    if storage.flow_renders[network_id] then
        for _, render_obj in ipairs(storage.flow_renders[network_id]) do
            if render_obj and render_obj.valid then render_obj.destroy() end
        end
    end
    storage.flow_renders[network_id] = {}

    local positions = {}
    for _, member in ipairs(net.members) do
        if member.entity and member.entity.valid then
            local ports = port_defs.get_ports(member.entity)
            if ports and ports[member.port_index] then
                local offset = ports[member.port_index].offset
                positions[member.unit_number .. ":" .. member.port_index] = {
                    pos = { x = member.entity.position.x + offset.x, y = member.entity.position.y + offset.y },
                    surface = member.entity.surface
                }
            end
        end
    end

    for port_key, node in pairs(flow_map) do
        local origin = positions[port_key]
        if origin then
            if node.pressure ~= nil then
                local t_obj = rendering.draw_text{
                    text = tostring(node.pressure),
                    surface = origin.surface,
                    target = origin.pos,
                    color = {r = 1, g = 1, b = 1},
                    alignment = "center",
                    scale = 0.8,
                    time_to_live = 600
                }
                table.insert(storage.flow_renders[network_id], t_obj)
            end

            for _, next_hop in ipairs(node.next_hops) do
                local dest = positions[next_hop]
                if dest then
                    local l_obj = rendering.draw_line{
                        color = {r = 0, g = 1, b = 0},
                        width = 2,
                        from = origin.pos,
                        to = dest.pos,
                        surface = origin.surface,
                        time_to_live = 600
                    }
                    table.insert(storage.flow_renders[network_id], l_obj)
                end
            end

            for _, handoff_key in ipairs(node.handoffs) do
                local dest = positions[handoff_key] or get_port_position(handoff_key)
                if dest then
                    local l_obj = rendering.draw_line{
                        color = {r = 0, g = 1, b = 0},
                        width = 2,
                        from = origin.pos,
                        to = dest.pos,
                        surface = origin.surface,
                        time_to_live = 600
                    }
                    table.insert(storage.flow_renders[network_id], l_obj)
                end

                local c_obj = rendering.draw_circle{
                    color = {r = 0, g = 0.5, b = 1},
                    radius = 0.25,
                    filled = true,
                    target = origin.pos,
                    surface = origin.surface,
                    time_to_live = 600
                }
                table.insert(storage.flow_renders[network_id], c_obj)
            end
        end
    end
end

-- Refresh debug visuals every 10s
events.on_event(defines.events.on_tick, function(event)
    if event.tick % 600 == 0 then
        if not storage.networks or not storage.networks.list then return end
        for net_id, _ in pairs(storage.networks.list) do
            networks_flow.build(net_id)
            networks_flow.draw_debug(net_id)
        end
    end
end)

return networks_flow