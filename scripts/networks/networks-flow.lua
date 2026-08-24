-- scripts/networks/networks-flow.lua
local networks = require("scripts.networks.networks")
local port_defs = require("scripts.ports.port-definitions")
local flow_renderer = require("scripts.networks.networks-flow-renderer")
local flow_cull = require("scripts.networks.flow-cull")

local networks_flow = {}

-- Toggle to enable or disable debug drawing overlays
networks_flow.DEBUG_RENDER = true

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

--- Look up an entity and port definition across any network in storage
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

function networks_flow.build(net_id)
    networks.init()
    local net = storage.networks.list[net_id]
    if not (net and net.members) then 
        if networks_flow.DEBUG_RENDER then
            flow_renderer.clear(net_id)
        end
        return 
    end

    local flow_map = {}

    -- 1. Gather local network members
    for _, member in ipairs(net.members) do
        local entity = member.entity
        if entity and entity.valid then
            local key = get_port_key(member.unit_number, member.port_index)
            local ports = port_defs.get_ports(entity)
            local port = ports and ports[member.port_index]

            if port then
                flow_map[key] = {
                    key = key,
                    unit_number = member.unit_number,
                    port_index = member.port_index,
                    entity = entity,
                    offset = port.offset,
                    pos = { 
                        x = entity.position.x + port.offset.x, 
                        y = entity.position.y + port.offset.y, 
                        surface = entity.surface.name 
                    },
                    pressure = port.pressure or 0,
                    flow_dir = port.flow,
                    outbound_hops = {}
                }
            end
        end
    end

    -- 2. Resolve cross-network boundary neighbor ports
    local boundary_keys = {}
    for key, _ in pairs(flow_map) do
        local neighbors = storage.port_connections and storage.port_connections[key]
        if neighbors then
            for neighbor_key, _ in pairs(neighbors) do
                if not flow_map[neighbor_key] then
                    boundary_keys[neighbor_key] = true
                end
            end
        end
    end

    for b_key in pairs(boundary_keys) do
        local entity, port = get_entity_and_port(b_key)
        if entity and port then
            local unit_num, p_idx = b_key:match("^(%d+):(%d+)$")
            flow_map[b_key] = {
                key = b_key,
                unit_number = tonumber(unit_num),
                port_index = tonumber(p_idx),
                entity = entity,
                offset = port.offset,
                pos = { 
                    x = entity.position.x + port.offset.x, 
                    y = entity.position.y + port.offset.y, 
                    surface = entity.surface.name 
                },
                pressure = port.pressure or 0,
                flow_dir = port.flow,
                outbound_hops = {}
            }
        end
    end

    -- 3. Build outbound vector hops
    for key, node in pairs(flow_map) do
        local neighbors = storage.port_connections and storage.port_connections[key]
        if neighbors then
            for neighbor_key, _ in pairs(neighbors) do
                local neighbor_node = flow_map[neighbor_key]
                if neighbor_node then
                    local p_delta = node.pressure - neighbor_node.pressure
                    if p_delta > 0 or (p_delta == 0 and node.flow_dir ~= "in" and neighbor_node.flow_dir ~= "out") then
                        table.insert(node.outbound_hops, neighbor_key)
                    end
                end
            end
        end
    end

    -- 4. Cull dead-end internal paths
    flow_map = flow_cull.process(flow_map)

    -- 5. Store flow map metadata; draw or clear render objects based on flag
    networks.set_metadata(net_id, "flow_map", flow_map)
    
    if networks_flow.DEBUG_RENDER then
        flow_renderer.draw(net_id)
    else
        flow_renderer.clear(net_id)
    end
end

return networks_flow