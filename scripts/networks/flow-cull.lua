-- scripts/networks/flow-cull.lua
local flow_cull = {}

local function is_external_hop(node, target_key, flow_map)
    local target_node = flow_map[target_key]
    return target_node and (target_node.unit_number ~= node.unit_number)
end

local function count_external_hops(key, node, flow_map)
    local count = 0

    for _, hop_key in ipairs(node.outbound_hops) do
        if is_external_hop(node, hop_key, flow_map) then
            count = count + 1
        end
    end

    for _, other_node in pairs(flow_map) do
        if other_node.unit_number ~= node.unit_number then
            for _, hop_key in ipairs(other_node.outbound_hops) do
                if hop_key == key then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function flow_cull.process(flow_map)
    if not flow_map then return flow_map end

    local entity_port_counts = {}
    for _, node in pairs(flow_map) do
        entity_port_counts[node.unit_number] = (entity_port_counts[node.unit_number] or 0) + 1
    end

    -- 1. Clear outbound paths for ports on multi-port entities (>2 ports) that lack external links
    for key, node in pairs(flow_map) do
        local port_count = entity_port_counts[node.unit_number] or 0
        if port_count > 2 then
            if count_external_hops(key, node, flow_map) == 0 then
                node.outbound_hops = {}
            end
        end
    end

    -- 2. Iteratively prune internal dead-ends
    local changed = true
    local max_iterations = 20
    local iteration = 0

    while changed and iteration < max_iterations do
        changed = false
        iteration = iteration + 1

        for _, node in pairs(flow_map) do
            local port_count = entity_port_counts[node.unit_number] or 0

            if port_count > 2 then
                local valid_hops = {}

                for _, hop_key in ipairs(node.outbound_hops) do
                    local target_node = flow_map[hop_key]

                    if target_node then
                        local is_internal = (target_node.unit_number == node.unit_number)

                        if is_internal then
                            if #target_node.outbound_hops > 0 then
                                table.insert(valid_hops, hop_key)
                            end
                        else
                            table.insert(valid_hops, hop_key)
                        end
                    end
                end

                if #valid_hops ~= #node.outbound_hops then
                    node.outbound_hops = valid_hops
                    changed = true
                end
            end
        end
    end

    return flow_map
end

return flow_cull