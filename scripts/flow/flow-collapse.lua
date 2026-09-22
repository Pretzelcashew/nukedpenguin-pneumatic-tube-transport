local flow_common = require("scripts.flow.flow-common")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local viewport_bvh = require("scripts.utils.viewport-bvh")

local flow_collapse = {}

local MERGE_BATCH_SIZE = 2
local DIV_BATCH_SIZE = 1

local MACHINE_NAMES = {
    ["pneumatic-diverter"] = true,
    ["pneumatic-pump"] = true,
    ["pneumatic-capsule-counter"] = true,
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true,
    ["pneumatic-projector"] = true
}

function flow_collapse.init_storage()
    storage.collapsed_edges = storage.collapsed_edges or {}
    storage.run_by_port = storage.run_by_port or {}
    storage.collapse_queue = storage.collapse_queue or {}
    storage.collapse_queue_set = storage.collapse_queue_set or {}
    storage.division_queue = storage.division_queue or {}
    storage.division_queue_set = storage.division_queue_set or {}
    storage.next_run_id = storage.next_run_id or 1000000
end

-- Hook into flow_common atomic node teardown & edge severed events
flow_common.midsegment_removal_handler = function(pkey)
    flow_collapse.handle_node_destroyed(pkey)
end

flow_common.on_edge_severed_handler = function(n_key, severed_pkey)
    flow_collapse.handle_connection_removed(n_key)
end

function flow_collapse.enqueue_port(pkey)
    if not pkey then return end
    storage.collapse_queue = storage.collapse_queue or {}
    storage.collapse_queue_set = storage.collapse_queue_set or {}
    if not storage.collapse_queue_set[pkey] then
        storage.collapse_queue_set[pkey] = true
        table.insert(storage.collapse_queue, pkey)
    end
end

function flow_collapse.enqueue_unit_ports(unit_number)
    if not unit_number then return end
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if unit_ports then
        for i = 1, #unit_ports do
            flow_collapse.enqueue_port(unit_ports[i])
        end
    end
end

function flow_collapse.enqueue_division(run_id)
    if not run_id then return end
    storage.division_queue = storage.division_queue or {}
    storage.division_queue_set = storage.division_queue_set or {}
    if not storage.division_queue_set[run_id] then
        storage.division_queue_set[run_id] = true
        table.insert(storage.division_queue, run_id)
    end
end

function flow_collapse.get_run_for_node(pkey)
    if not (pkey and storage.run_by_port) then return nil end
    return storage.run_by_port[pkey]
end

function flow_collapse.is_unit_colinear_straight(unit_number, expected_axis)
    if not unit_number then return false end
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports or #unit_ports < 2 then return false end

    local p1 = unit_ports[1]
    local node1 = storage.flow_nodes and storage.flow_nodes[p1]
    if not (node1 and node1.pos and node1.pressure_transmit) then return false end

    local ent = node1.entity
    local ent_name = ent and ent.valid and ent.name
    if ent_name and MACHINE_NAMES[ent_name] then return false end

    for i = 1, #unit_ports do
        local pi = unit_ports[i]
        local ni = storage.flow_nodes and storage.flow_nodes[pi]
        for j = i + 1, #unit_ports do
            local pj = unit_ports[j]
            if flow_common.is_colinear_straight_internal(pi, pj) then
                if expected_axis then
                    local unit_axis = (ni and ni.dir and ni.dir.x ~= 0) and "x" or "y"
                    if unit_axis == expected_axis then
                        return true, pi, pj
                    end
                else
                    return true, pi, pj
                end
            end
        end
    end
    return false
end

function flow_collapse.invalidate_run(run_id)
    if not (run_id and storage.collapsed_edges) then return end
    local run = storage.collapsed_edges[run_id]
    if run and run.status ~= "dividing" then
        run.status = "dividing"
        flow_collapse.enqueue_division(run_id)
    end
end

function flow_collapse.handle_connection_added(pkey)
    if not pkey then return end
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    local u_num = node and node.unit_number
    if not u_num then return end

    if not flow_collapse.is_unit_colinear_straight(u_num) then
        local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u_num]
        if u_ports then
            for _, port_key in ipairs(u_ports) do
                local run_id = storage.run_by_port and storage.run_by_port[port_key]
                if run_id then
                    flow_collapse.invalidate_run(run_id)
                end
            end
        end
    else
        flow_collapse.enqueue_unit_ports(u_num)
    end
end

function flow_collapse.handle_connection_removed(n_key)
    if not n_key then return end
    local node = storage.flow_nodes and storage.flow_nodes[n_key]
    local u_num = node and node.unit_number
    if not u_num then return end

    if flow_collapse.is_unit_colinear_straight(u_num) then
        flow_collapse.enqueue_unit_ports(u_num)
    end
end

local function get_or_build_segment(pkey)
    if not pkey then return nil end
    local run_id = storage.run_by_port and storage.run_by_port[pkey]
    if run_id then
        local run = storage.collapsed_edges and storage.collapsed_edges[run_id]
        if run then
            if run.status == "dividing" then return nil end
            for u in pairs(run.units or {}) do
                if not flow_collapse.is_unit_colinear_straight(u, run.axis) then
                    flow_collapse.invalidate_run(run_id)
                    return nil
                end
            end
            return run
        end
    end

    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not (node and node.unit_number and node.pos and node.pressure_transmit) then
        return nil
    end

    local ent = node.entity
    local ent_name = ent and ent.valid and ent.name
    if ent_name and MACHINE_NAMES[ent_name] then
        return nil
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
    if not unit_ports or #unit_ports < 2 then return nil end

    local other_key = nil
    for i = 1, #unit_ports do
        local check_key = unit_ports[i]
        if check_key ~= pkey and flow_common.is_colinear_straight_internal(pkey, check_key) then
            other_key = check_key
            break
        end
    end
    if not other_key then return nil end

    local other_node = storage.flow_nodes[other_key]
    if not (other_node and other_node.pos) then return nil end

    local s_idx = nil
    if node.surface_name and game.surfaces[node.surface_name] then
        s_idx = game.surfaces[node.surface_name].index
    end

    local axis = (node.dir and node.dir.x ~= 0) and "x" or "y"

    return {
        is_run = false,
        unit_number = node.unit_number,
        length = 1,
        port_a = pkey,
        port_b = other_key,
        pos_a = { x = node.pos.x, y = node.pos.y },
        pos_b = { x = other_node.pos.x, y = other_node.pos.y },
        center_pos = { x = node.pos.x, y = node.pos.y },
        axis = axis,
        surface_index = s_idx,
        units = { [node.unit_number] = true },
        ports = { pkey, other_key }
    }
end

function flow_collapse.set_engine(engine)
    flow_collapse.engine = engine
end

local function compute_corridor_aabb(axis, start_pos, end_pos)
    local min_x, max_x, min_y, max_y
    if axis == "x" then
        local cy = start_pos.y
        min_y = cy - 0.5
        max_y = cy + 0.5
        min_x = math.min(start_pos.x, end_pos.x) - 0.5
        max_x = math.max(start_pos.x, end_pos.x) + 0.5
    else
        local cx = start_pos.x
        min_x = cx - 0.5
        max_x = cx + 0.5
        min_y = math.min(start_pos.y, end_pos.y) - 0.5
        max_y = math.max(start_pos.y, end_pos.y) + 0.5
    end
    return min_x, min_y, max_x, max_y
end

function flow_collapse.create_and_register_slices(run)
    local s_idx = run.surface_index
    local run_id = run.run_id
    local axis = run.axis or "x"
    local m_tree = viewport_bvh.get_motion_tree(s_idx)

    local sorted_units = {}
    for u in pairs(run.units or {}) do
        sorted_units[#sorted_units + 1] = u
    end

    table.sort(sorted_units, function(u1, u2)
        local p1 = storage.flow_unit_ports and storage.flow_unit_ports[u1] and storage.flow_unit_ports[u1][1]
        local n1 = p1 and storage.flow_nodes and storage.flow_nodes[p1]
        local p2 = storage.flow_unit_ports and storage.flow_unit_ports[u2] and storage.flow_unit_ports[u2][1]
        local n2 = p2 and storage.flow_nodes and storage.flow_nodes[p2]
        if n1 and n2 then
            if axis == "x" then
                return n1.pos.x < n2.pos.x
            else
                return n1.pos.y < n2.pos.y
            end
        end
        return u1 < u2
    end)

    local SLICE_MAX = 16
    local num_slices = math.max(1, math.ceil(#sorted_units / SLICE_MAX))
    local leaves = {}

    for seg_idx = 1, num_slices do
        local i_start = (seg_idx - 1) * SLICE_MAX + 1
        local i_end = math.min(#sorted_units, seg_idx * SLICE_MAX)
        local slice_units = {}
        local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge

        for idx = i_start, i_end do
            local u = sorted_units[idx]
            slice_units[u] = true
            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u]
            if u_ports then
                for p_idx = 1, #u_ports do
                    local node = storage.flow_nodes and storage.flow_nodes[u_ports[p_idx]]
                    if node and node.pos then
                        min_x = math.min(min_x, node.pos.x - 0.5)
                        max_x = math.max(max_x, node.pos.x + 0.5)
                        min_y = math.min(min_y, node.pos.y - 0.5)
                        max_y = math.max(max_y, node.pos.y + 0.5)
                    end
                end
            end
        end

        if axis == "x" then
            local cy = (min_y + max_y) * 0.5
            min_y = cy - 0.5
            max_y = cy + 0.5
        else
            local cx = (min_x + max_x) * 0.5
            min_x = cx - 0.5
            max_x = cx + 0.5
        end

        local leaf = {
            min_x = min_x,
            min_y = min_y,
            max_x = max_x,
            max_y = max_y,
            owner_id = run_id,
            seg_key = seg_idx,
            run_id = run_id,
            surface_index = s_idx,
            axis = axis,
            units = slice_units,
            is_run = true,
            static_render_spec = "flow_dot_static"
        }
        local key = tostring(run_id) .. ":" .. tostring(seg_idx)
        leaf.key = key

        trajectory_bvh.insert(m_tree, leaf, key)
        viewport_bvh.on_segment_registered(s_idx, leaf)
        leaves[seg_idx] = leaf
    end

    return leaves
end

local function evict_segment_leaf(seg)
    local s_idx = seg.surface_index
    if not s_idx then return end
    if seg.is_run then
        if seg.leaves then
            for _, leaf in ipairs(seg.leaves) do
                viewport_bvh.on_segment_removed(s_idx, seg.run_id, leaf.seg_key)
            end
        else
            viewport_bvh.on_segment_removed(s_idx, seg.run_id)
        end
        if storage.collapsed_edges then
            storage.collapsed_edges[seg.run_id] = nil
        end
    else
        viewport_bvh.on_segment_removed(s_idx, seg.unit_number, "base")
        if storage.motion_leaves and storage.motion_leaves[seg.unit_number] then
            storage.motion_leaves[seg.unit_number]["base"] = nil
        end
    end
end

function flow_collapse.merge_segments(seg_up, seg_down, pkey_up_exit, pkey_down_entry)
    if not (seg_up and seg_down and seg_up.surface_index and seg_up.surface_index == seg_down.surface_index) then
        return nil
    end
    if seg_up.status == "dividing" or seg_down.status == "dividing" then
        return nil
    end

    storage.next_run_id = (storage.next_run_id or 1000000) + 1
    local run_id = storage.next_run_id
    local s_idx = seg_up.surface_index

    local up_start_pkey = seg_up.is_run and seg_up.start_pkey or (seg_up.port_a == pkey_up_exit and seg_up.port_b or seg_up.port_a)
    local down_end_pkey = seg_down.is_run and seg_down.end_pkey or (seg_down.port_a == pkey_down_entry and seg_down.port_b or seg_down.port_a)

    local up_start_pos = seg_up.is_run and seg_up.start_pos or (seg_up.port_a == up_start_pkey and seg_up.pos_a or seg_up.pos_b)
    local down_end_pos = seg_down.is_run and seg_down.end_pos or (seg_down.port_a == down_end_pkey and seg_down.pos_a or seg_down.pos_b)

    local total_len = seg_up.length + seg_down.length
    local axis = seg_up.axis

    evict_segment_leaf(seg_up)
    evict_segment_leaf(seg_down)

    local combined_units = {}
    for u in pairs(seg_up.units or {}) do combined_units[u] = true end
    for u in pairs(seg_down.units or {}) do combined_units[u] = true end

    local combined_ports = {}
    for _, p in ipairs(seg_up.ports or {}) do combined_ports[#combined_ports + 1] = p end
    for _, p in ipairs(seg_down.ports or {}) do combined_ports[#combined_ports + 1] = p end

    local new_run = {
        is_run = true,
        run_id = run_id,
        length = total_len,
        start_pkey = up_start_pkey,
        end_pkey = down_end_pkey,
        start_pos = up_start_pos,
        end_pos = down_end_pos,
        axis = axis,
        surface_index = s_idx,
        units = combined_units,
        ports = combined_ports,
        child_a = seg_up,
        child_b = seg_down,
        status = "active"
    }
    new_run.leaves = flow_collapse.create_and_register_slices(new_run)

    storage.collapsed_edges[run_id] = new_run
    for _, pkey in ipairs(combined_ports) do
        storage.run_by_port[pkey] = run_id
    end

    flow_collapse.enqueue_port(up_start_pkey)
    flow_collapse.enqueue_port(down_end_pkey)

    return new_run
end

local function divide_run(run_id)
    if not (run_id and storage.collapsed_edges) then return end
    local run = storage.collapsed_edges[run_id]
    if not run then return end

    local s_idx = run.surface_index
    if s_idx then
        if run.leaves then
            for _, leaf in ipairs(run.leaves) do
                viewport_bvh.on_segment_removed(s_idx, run_id, leaf.seg_key)
            end
        else
            viewport_bvh.on_segment_removed(s_idx, run_id)
        end
    end
    storage.collapsed_edges[run_id] = nil

    local children = { run.child_a, run.child_b }
    for i = 1, 2 do
        local child = children[i]
        if child then
            if child.is_run then
                local delta_p = flow_common.get_colinear_gradient(child.start_pkey, child.end_pkey)
                local child_valid = (delta_p > 0)
                if child_valid then
                    for u in pairs(child.units or {}) do
                        if not flow_collapse.is_unit_colinear_straight(u, child.axis) then
                            child_valid = false
                            break
                        end
                    end
                end

                if not child_valid then
                    child.status = "dividing"
                    storage.collapsed_edges[child.run_id] = child
                    for _, pkey in ipairs(child.ports or {}) do
                        storage.run_by_port[pkey] = child.run_id
                    end
                    flow_collapse.enqueue_division(child.run_id)
                else
                    child.status = "active"
                    storage.collapsed_edges[child.run_id] = child
                    for _, pkey in ipairs(child.ports or {}) do
                        storage.run_by_port[pkey] = child.run_id
                    end
                    child.leaves = flow_collapse.create_and_register_slices(child)
                end
            else
                for _, pkey in ipairs(child.ports or {}) do
                    storage.run_by_port[pkey] = nil
                end
                if flow_collapse.engine then
                    flow_collapse.engine.register_entity_motion_leaf(child.unit_number)
                end
                flow_collapse.enqueue_unit_ports(child.unit_number)
            end
        end
    end
end

function flow_collapse.handle_node_destroyed(pkey)
    if not (pkey and storage.run_by_port) then return end
    local run_id = storage.run_by_port[pkey]
    if not (run_id and storage.collapsed_edges) then return end

    local run = storage.collapsed_edges[run_id]
    if not run then return end

    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    local mined_unit = node and node.unit_number

    local s_idx = run.surface_index
    if s_idx then
        if run.leaves then
            for _, leaf in ipairs(run.leaves) do
                viewport_bvh.on_segment_removed(s_idx, run_id, leaf.seg_key)
            end
        else
            viewport_bvh.on_segment_removed(s_idx, run_id)
        end
    end
    storage.collapsed_edges[run_id] = nil

    local engine = flow_collapse.engine
    for _, port_key in ipairs(run.ports or {}) do
        storage.run_by_port[port_key] = nil
    end

    for u_num in pairs(run.units or {}) do
        if u_num ~= mined_unit then
            if engine then
                engine.register_entity_motion_leaf(u_num)
            end
            flow_collapse.enqueue_unit_ports(u_num)
        end
    end
end

function flow_collapse.step(tick)
    if not storage.collapsed_edges then return end

    -- Phase A: Process unmerge/division queue (amortized at 1 per tick)
    local div_processed = 0
    while div_processed < DIV_BATCH_SIZE and #storage.division_queue > 0 do
        local run_id = table.remove(storage.division_queue, 1)
        storage.division_queue_set[run_id] = nil
        div_processed = div_processed + 1
        divide_run(run_id)
    end

    -- Phase B: Background check for zero gradient or broken colinearity (every 15 ticks)
    if tick % 15 == 0 then
        for r_id, run in pairs(storage.collapsed_edges) do
            if run.status == "active" then
                local delta_p = flow_common.get_colinear_gradient(run.start_pkey, run.end_pkey)
                local valid = (delta_p > 0)
                if valid then
                    for u in pairs(run.units or {}) do
                        if not flow_collapse.is_unit_colinear_straight(u, run.axis) then
                            valid = false
                            break
                        end
                    end
                end
                if not valid then
                    run.status = "dividing"
                    flow_collapse.enqueue_division(r_id)
                end
            end
        end
    end

    -- Phase C: Process pairwise merge queue (amortized at 2 per tick)
    local merge_processed = 0
    while merge_processed < MERGE_BATCH_SIZE and #storage.collapse_queue > 0 do
        local pkey = table.remove(storage.collapse_queue, 1)
        storage.collapse_queue_set[pkey] = nil
        merge_processed = merge_processed + 1

        local seg_a = get_or_build_segment(pkey)
        if seg_a and seg_a.status ~= "dividing" then
            local conns = storage.flow_connections and storage.flow_connections[pkey]
            if conns then
                for neighbor_key in pairs(conns) do
                    local seg_b = get_or_build_segment(neighbor_key)
                    if seg_b and seg_b ~= seg_a and seg_b.status ~= "dividing" then
                        if seg_a.surface_index == seg_b.surface_index and seg_a.axis == seg_b.axis then
                            local ay = seg_a.start_pos and seg_a.start_pos.y or (seg_a.pos_a and seg_a.pos_a.y)
                            local by = seg_b.start_pos and seg_b.start_pos.y or (seg_b.pos_a and seg_b.pos_a.y)
                            local ax = seg_a.start_pos and seg_a.start_pos.x or (seg_a.pos_a and seg_a.pos_a.x)
                            local bx = seg_b.start_pos and seg_b.start_pos.x or (seg_b.pos_a and seg_b.pos_a.x)

                            local aligned = false
                            if seg_a.axis == "x" and ay and by then
                                aligned = math.abs(ay - by) < 0.01
                            elseif seg_a.axis == "y" and ax and bx then
                                aligned = math.abs(ax - bx) < 0.01
                            end

                            if aligned then
                                local delta_p, dir_vec = flow_common.get_colinear_gradient(pkey, neighbor_key)
                                if delta_p > 0 and dir_vec then
                                    if dir_vec == "forward" then
                                        flow_collapse.merge_segments(seg_a, seg_b, pkey, neighbor_key)
                                    else
                                        flow_collapse.merge_segments(seg_b, seg_a, neighbor_key, pkey)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function flow_collapse.print_collapsed_edges()
    local total_runs = 0
    local q_merge = storage.collapse_queue and #storage.collapse_queue or 0
    local q_div = storage.division_queue and #storage.division_queue or 0

    game.print(string.format("[color=yellow][Collapsed Edges Diagnostic][/color] Merge Queue: %d | Division Queue: %d", q_merge, q_div))

    if storage.collapsed_edges then
        for run_id, run in pairs(storage.collapsed_edges) do
            total_runs = total_runs + 1
            if total_runs <= 20 then
                local delta_p = flow_common.get_colinear_gradient(run.start_pkey, run.end_pkey)
                local num_leaves = run.leaves and #run.leaves or math.max(1, math.ceil(run.length / 16))
                game.print(string.format("  -> [Run #%d] Len: %d tiles (%d slices) | Axis: %s | %s -> %s | Delta-P: %d | Status: %s",
                    run_id, run.length, num_leaves, run.axis or "?", tostring(run.start_pkey), tostring(run.end_pkey), delta_p, run.status or "active"))
            end
        end
    end
    game.print(string.format("Total active collapsed edges: %d", total_runs))
end

return flow_collapse