local flow_common = {}

-- Spatial and Port Key Formatting Primitives
function flow_common.make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

function flow_common.make_beam_port_key(unit_number, dx, dy, dist)
    return string.format("kinetic:%d:%d,%d:%d", unit_number, math.floor(dx or 0), math.floor(dy or 0), dist)
end

function flow_common.make_pos_key(surface_name, x, y)
    local rx = math.floor(x * 10 + 0.5) / 10
    local ry = math.floor(y * 10 + 0.5) / 10
    return string.format("%s@%.1f,%.1f", surface_name, rx, ry)
end

function flow_common.make_edge_key(key_a, key_b)
    return key_a < key_b and (key_a .. "|" .. key_b) or (key_b .. "|" .. key_a)
end

-- Waking Engine (SINGLE SOURCE OF TRUTH)
function flow_common.wake_port_parked(pkey)
    if not (pkey and storage.parked_by_port) then return end
    local bucket = storage.parked_by_port[pkey]
    if bucket then
        for cap_id in pairs(bucket) do
            local parked_cap = storage.capsules and storage.capsules[cap_id]
            if parked_cap and parked_cap.to_port_key == nil then
                parked_cap.next_retry_tick = nil
                parked_cap.last_failed_hub = nil
                parked_cap.last_port_key = nil
            end
        end
    end
end

-- Wavefront Queue Enqueue Primitives
function flow_common.enqueue_port(pkey)
    if pkey and storage.flow_queue then
        storage.flow_queue[pkey] = true
    end
end

function flow_common.enqueue_unit_ports(unit_number)
    if not unit_number then return end
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if unit_ports then
        for i = 1, #unit_ports do
            flow_common.enqueue_port(unit_ports[i])
        end
    end
end

-- Graph Topology Primitives (SINGLE SOURCE OF TRUTH)
function flow_common.link_ports(key_a, key_b)
    if not (key_a and key_b) then return end
    storage.flow_connections = storage.flow_connections or {}
    storage.flow_connections[key_a] = storage.flow_connections[key_a] or {}
    storage.flow_connections[key_b] = storage.flow_connections[key_b] or {}
    storage.flow_connections[key_a][key_b] = true
    storage.flow_connections[key_b][key_a] = true
end

function flow_common.sever_ports(key_a, key_b)
    if not (key_a and key_b and storage.flow_connections) then return end
    if storage.flow_connections[key_a] then
        storage.flow_connections[key_a][key_b] = nil
        if next(storage.flow_connections[key_a]) == nil then
            storage.flow_connections[key_a] = nil
        end
    end
    if storage.flow_connections[key_b] then
        storage.flow_connections[key_b][key_a] = nil
        if next(storage.flow_connections[key_b]) == nil then
            storage.flow_connections[key_b] = nil
        end
    end
end

function flow_common.add_node_to_grid(pos_key, pkey)
    storage.flow_grid = storage.flow_grid or {}
    storage.flow_grid[pos_key] = storage.flow_grid[pos_key] or {}
    storage.flow_grid[pos_key][pkey] = true
end

function flow_common.remove_node_from_grid(pos_key, pkey)
    if storage.flow_grid and storage.flow_grid[pos_key] then
        storage.flow_grid[pos_key][pkey] = nil
        if next(storage.flow_grid[pos_key]) == nil then
            storage.flow_grid[pos_key] = nil
        end
    end
end

-- Atomic Graph Node Teardown: clears grid, severs edges, notifies neighbors, wakes capsules
function flow_common.destroy_node(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return end

    if node.pos_key then
        flow_common.remove_node_from_grid(node.pos_key, pkey)
    end

    local neighbors = storage.flow_connections and storage.flow_connections[pkey]
    if neighbors then
        for n_key in pairs(neighbors) do
            if storage.flow_connections[n_key] then
                storage.flow_connections[n_key][pkey] = nil
                if next(storage.flow_connections[n_key]) == nil then
                    storage.flow_connections[n_key] = nil
                end
            end
            if storage.flow_nodes and storage.flow_nodes[n_key] then
                local n_node = storage.flow_nodes[n_key]
                local had_active = (storage.flow_levels and storage.flow_levels[pkey] ~= nil)
                    or (storage.counter_levels and storage.counter_levels[pkey] ~= nil)
                    or (storage.kinetic_levels and storage.kinetic_levels[pkey] ~= nil)
                    or (node and node.emitter)
                    or (storage.flow_levels and storage.flow_levels[n_key] ~= nil)
                    or (storage.counter_levels and storage.counter_levels[n_key] ~= nil)
                    or (storage.kinetic_levels and storage.kinetic_levels[n_key] ~= nil)
                    or (n_node and n_node.emitter)

                if had_active then
                    flow_common.enqueue_port(n_key)
                end
                flow_common.wake_port_parked(n_key)
            end
        end
        storage.flow_connections[pkey] = nil
    end

    if storage.flow_queue then storage.flow_queue[pkey] = nil end
    if storage.flow_levels then storage.flow_levels[pkey] = nil end
    if storage.counter_levels then storage.counter_levels[pkey] = nil end
    if storage.kinetic_levels then storage.kinetic_levels[pkey] = nil end
    if storage.counter_owners and storage.counter_owners[pkey] then
        local owner = storage.counter_owners[pkey]
        if storage.counter_owned_nodes and storage.counter_owned_nodes[owner] then
            storage.counter_owned_nodes[owner][pkey] = nil
        end
        storage.counter_owners[pkey] = nil
    end

    storage.flow_nodes[pkey] = nil
    flow_common.wake_port_parked(pkey)
end

return flow_common
