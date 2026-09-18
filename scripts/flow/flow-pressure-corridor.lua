local timed_motion = require("scripts.utils.timed-motion")
local viewport_bvh = require("scripts.utils.viewport-bvh")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local capsule_queries = require("scripts.capsules.capsule-queries")

local flow_pressure_corridor = {}

--- Creates a single 1-tube seed corridor pinned in the motion BVH
--- @param pkey string Entry port key
--- @param node table Entry port node record
--- @param partner_key string Exit port key
--- @param partner_node table Exit port node record
--- @param flow_dir table {x, y} flow direction vector
--- @param target_flow number Current pressure level
--- @return string corridor_id
--- Probes forward through contiguous colinear tubes up to a 16-tile leaf boundary
--- and inserts the segment into both trajectory_bvh and motion_bvh
function flow_pressure_corridor.create_seed_corridor(pkey, node, partner_key, partner_node, flow_dir, target_flow)
    storage.pressure_corridors = storage.pressure_corridors or {}
    storage.port_to_pressure_corridor = storage.port_to_pressure_corridor or {}

    local existing_id = storage.port_to_pressure_corridor[pkey] or storage.port_to_pressure_corridor[partner_key]
    if existing_id and storage.pressure_corridors[existing_id] then
        return existing_id
    end

    local surface = (node.entity and node.entity.valid and node.entity.surface)
        or (node.surface_name and game.surfaces[node.surface_name])
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index

    if not target_flow or target_flow == 0 then return nil end

    -- Pressure budget is in discrete entity/port hops, NOT physical tiles
    local hops_budget = math.abs(target_flow)
    local hops_spent = 0

    -- 1. Probe the contiguous straight run tracking both hops and physical world distance
    local covered_ports = {}
    local cur_in = pkey
    local cur_node = node
    local total_dist = 0
    local last_out_node = partner_node
    local last_out_key = partner_key
    local handoff_target = nil

    local MAX_LEAF = 16
    local is_stopped = false
    while total_dist < MAX_LEAF and hops_spent < hops_budget do
        local out_k, dir, out_n = flow_pressure_corridor.get_colinear_partner(cur_in, cur_node)
        if not (out_k and dir and out_n) then is_stopped = true break end
        if dir.x ~= flow_dir.x or dir.y ~= flow_dir.y then is_stopped = true break end

        local step_span = math.abs(out_n.pos.x - cur_node.pos.x) + math.abs(out_n.pos.y - cur_node.pos.y)
        if step_span < 0.05 then step_span = 1.0 end

        total_dist = total_dist + step_span
        hops_spent = hops_spent + 1
        last_out_node = out_n
        last_out_key = out_k
        covered_ports[#covered_ports + 1] = cur_in
        covered_ports[#covered_ports + 1] = out_k

        -- Inspect next connection
        local neighbors = storage.flow_connections and storage.flow_connections[out_k]
        local n_count = 0
        local next_in = nil
        if neighbors then
            for n_k in pairs(neighbors) do
                n_count = n_count + 1
                next_in = n_k
            end
        end

        next_node = (n_count == 1 and next_in) and storage.flow_nodes and storage.flow_nodes[next_in]
        if n_count ~= 1 or not next_node or hops_spent >= hops_budget then
            handoff_target = next_in
            is_stopped = true
            break
        end

        handoff_target = next_in
        cur_in = next_in
        cur_node = next_node
    end

    if total_dist <= 0 then total_dist = 1.0 end

    storage.next_pressure_corridor_id = (storage.next_pressure_corridor_id or 0) + 1
    local corridor_id = "pcorridor:" .. tostring(storage.next_pressure_corridor_id)

    local sp = { x = node.pos.x, y = node.pos.y }
    local ep = { x = last_out_node.pos.x, y = last_out_node.pos.y }

    -- 2. Insert Segment 1 into BVH trees (without static dots until wavefront arrives)
    local seg1_key = string.format("%d,%d:1", flow_dir.x, flow_dir.y)

    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    if traj_tree then
        traj_tree:insert_segment(corridor_id, seg1_key, sp, ep, 0, total_dist, 1)
        trajectory_bvh.refresh_active_renders()
    end

    local motion_tree = timed_motion.get_motion_tree(s_idx)
    if motion_tree then
        local leaf = motion_tree:insert_segment(corridor_id, seg1_key, sp, ep, 0, total_dist, 1)
        if leaf then
            leaf.has_trail = nil
            leaf.trail_count = nil
            leaf.dir = { x = flow_dir.x, y = flow_dir.y }
            leaf.q_level = node.q_level or 0
            leaf.pressure_corridor = true
            leaf.pressure_level = target_flow
            viewport_bvh.on_segment_registered(s_idx, leaf)
        end
    end

    if traj_tree then
        trajectory_bvh.refresh_active_renders()
    end

    storage.pinned_corridors = storage.pinned_corridors or {}
    storage.pinned_corridors[corridor_id] = true

    storage.pressure_corridors[corridor_id] = {
        id = corridor_id,
        unit_number = node.unit_number,
        surface_index = s_idx,
        entry_port = pkey,
        exit_port = last_out_key,
        handoff_port = handoff_target,
        start_pos = sp,
        end_pos = ep,
        dir = { x = flow_dir.x, y = flow_dir.y },
        dist = total_dist,
        flow_level = target_flow,
        hops_spent = hops_spent,
        hops_budget = hops_budget,
        status = "traveling",
        num_segs = 1,
        covered_ports = covered_ports,
        capsule_count = 0
    }

    for i = 1, #covered_ports do
        storage.port_to_pressure_corridor[covered_ports[i]] = corridor_id
    end

    -- Option 1: 1 tick per port-pair hop (matching flow engine spread rate)
    local flight_ticks = math.max(1, hops_spent)
    local flight_id = "pscope:" .. corridor_id
    local current_tick = game.tick
    local arrival_tick = current_tick + flight_ticks

    timed_motion.schedule_flight{
        id = flight_id,
        owner_id = corridor_id,
        surface_name = (surface and surface.name) or "nauvis",
        surface_index = s_idx,
        start_pos = sp,
        terminal_pos = ep,
        dir = flow_dir,
        start_tick = current_tick,
        arrival_tick = arrival_tick,
        ticks_per_tile = tpt,
        flight_ticks = flight_ticks,
        kind = "pressure_scope",
        on_arrival = "pressure_scope_arrival",
        seg_idx = 1,
        metadata = {
            corridor_id = corridor_id,
            target_flow = target_flow,
            hops_budget = hops_budget,
            hops_spent = hops_spent,
            cur_in = next_in,
            cur_node = next_node,
            total_dist = total_dist,
            is_stopped = is_stopped,
            handoff_target = handoff_target
        }
    }

    game.print(string.format(
        "[color=cyan][PressureCorridor:PROBE][/color] Launched wave '%s': Segment 1 (%.1f tiles, %d ticks) -> advancing...",
        corridor_id, total_dist, flight_ticks
    ))

    return corridor_id
end

--- Attempts to launch a capsule into a pressure corridor as a peaceful timed flight
--- @param capsule table The runner capsule record
--- @param from_port_key string Current port key
--- @param runner table The capsule runner module
--- @return string|nil "timed_launched" if dispatched, nil if full or not an entrance
function flow_pressure_corridor.try_corridor_launch(capsule, from_port_key, runner)
    if not (capsule and from_port_key and storage.pressure_corridors) then return nil end
    local corridor_id = flow_pressure_corridor.get_corridor_for_port(from_port_key)
    if not corridor_id then return nil end

    local cor = storage.pressure_corridors[corridor_id]
    if not cor then return nil end

    -- Verify capsule is at the entrance port of this corridor
    if cor.entry_port ~= from_port_key then
        return nil
    end

    -- Capacity Guard: 1 capsule per tile max
    local max_cap = math.max(1, math.floor(cor.dist or 1))
    local cur_cap = cor.capsule_count or 0
    if cur_cap >= max_cap then
        runner.mark_capsule_parked(capsule)
        return nil
    end

    local cap_id = capsule.capsule_id or capsule.id
    local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or timed_motion.DEFAULT_TICKS_PER_TILE
    local flight_ticks = math.max(1, math.ceil(cor.dist * tpt))
    local current_tick = game.tick

    local record = timed_motion.create_record{
        id = cap_id,
        owner_id = corridor_id,
        surface_name = cor.surface_name or "nauvis",
        surface_index = cor.surface_index or 1,
        start_pos = cor.start_pos,
        terminal_pos = cor.end_pos,
        dir = cor.dir,
        start_tick = current_tick,
        ticks_per_tile = tpt,
        flight_ticks = flight_ticks,
        kind = "pressure_corridor_capsule",
        on_arrival = "pressure_corridor_arrival",
        metadata = {
            corridor_id = corridor_id,
            handoff_port = cor.handoff_port
        }
    }

    if not record then return nil end

    capsule.in_timed_flight = true
    capsule.from_port_key = nil
    capsule.last_port_key = from_port_key
    capsule.to_port_key = nil
    runner.mark_capsule_unparked(capsule)

    timed_motion.schedule_flight(record)
    cor.capsule_count = cur_cap + 1

    game.print(string.format(
        "[color=cyan][PressureCorridor:LAUNCH][/color] Capsule #%d entered '%s' (dist=%.1f tiles, %d ticks, queue=%d/%d)",
        cap_id, corridor_id, cor.dist, flight_ticks, cor.capsule_count, max_cap
    ))

    return "timed_launched"
end

--- Peaceful arrival handler: lands capsule at destination junction port with zero damage
--- @param flight_id number Capsule runner ID
--- @param flight table Timed flight record
--- @param current_tick number Arrival tick
--- @param runner table The capsule runner module
function flow_pressure_corridor.handle_corridor_arrival(flight_id, flight, current_tick, runner)
    if not flight then return end
    local cap_id = flight.capsule_id or flight_id
    local capsule = storage.capsules and storage.capsules[cap_id]
    if not capsule then return end

    local cor_id = (flight.metadata and flight.metadata.corridor_id) or flight.owner_id
    local cor = cor_id and storage.pressure_corridors and storage.pressure_corridors[cor_id]

    -- 1. Free corridor capacity & wake sleeping capsules at entrance
    if cor then
        cor.capsule_count = math.max(0, (cor.capsule_count or 1) - 1)
        if runner and cor.entry_port then
            runner.wake_parked_capsules(cor.entry_port)
        end
    end

    -- 2. Clear timed flight state
    capsule.in_timed_flight = nil
    timed_motion.remove_flight(cap_id, cor_id)

    -- 3. Resolve destination handoff port
    local dest_port = (cor and cor.handoff_port) or (flight.metadata and flight.metadata.handoff_port)
    if not dest_port and cor and cor.exit_port then
        local neighbors = storage.flow_connections and storage.flow_connections[cor.exit_port]
        if neighbors then
            for n_k in pairs(neighbors) do
                dest_port = n_k
                break
            end
        end
        dest_port = dest_port or cor.exit_port
    end

    -- 4. Hand off capsule into classic motion graph at junction port
    capsule.last_pos = { x = flight.terminal_pos.x, y = flight.terminal_pos.y }
    capsule.from_port_key = dest_port
    capsule.to_port_key = nil
    capsule.last_port_key = (cor and cor.exit_port) or flight.from_port_key

    capsule_queries.update_capsule_occupancy(capsule)
    if runner then
        runner.mark_capsule_parked(capsule)
        runner.wake_parked_capsules(dest_port)
    end

    game.print(string.format(
        "[color=green][PressureCorridor:ARRIVAL][/color] Capsule #%d finished corridor '%s' -> handed off to %s!",
        cap_id, tostring(cor_id), tostring(dest_port)
    ))
end

--- Boundary arrival: finalizes current leaf dots, then steps to next leaf or terminates
function flow_pressure_corridor.handle_scope_arrival(flight_id, flight, current_tick, runner)
    if not flight then return end
    local meta = flight.metadata or {}
    local corridor_id = meta.corridor_id or flight.owner_id
    local cor = storage.pressure_corridors and storage.pressure_corridors[corridor_id]
    if not cor then return end

    local s_idx = flight.surface_index or 1
    local dir = flight.dir or { x = 0, y = 0 }
    local cur_seg = flight.seg_idx or 1
    local seg_key = string.format("%d,%d:%d", dir.x, dir.y, cur_seg)

    -- 1. Finalize completed leaf trail dots
    local motion_tree = timed_motion.get_motion_tree(s_idx)
    if motion_tree then
        local owner_rec = motion_tree.trajectories and motion_tree.trajectories[corridor_id]
        local leaf = owner_rec and owner_rec.segments and owner_rec.segments[seg_key]
        if leaf then
            leaf.has_trail = true
            leaf.trail_count = math.max(1, math.floor(leaf.d_end - leaf.d_start))
            leaf.pressure_corridor = true
            leaf.pressure_level = meta.target_flow or 10
            viewport_bvh.on_leaf_static_changed(s_idx, leaf)
        end
    end

    -- 2. Check if corridor journey is complete
    local can_continue = (not meta.is_stopped) and meta.cur_in and meta.cur_node and (meta.hops_spent < meta.hops_budget)

    if not can_continue then
        cor.status = "stationary"
        cor.dist = meta.total_dist or flight.total_dist
        cor.end_pos = { x = flight.terminal_pos.x, y = flight.terminal_pos.y }
        timed_motion.remove_flight(flight_id, corridor_id)

        local rem_pressure = (cor.flow_level > 0) and (cor.flow_level - cor.hops_spent) or (cor.flow_level + cor.hops_spent)
        cor.rem_pressure = rem_pressure

        game.print(string.format(
            "[color=green][PressureCorridor:REACHED][/color] '%s' completed: %.1f tiles (%d leaves, %d hops spent) P_rem=%d handoff=%s",
            corridor_id, cor.dist, cor.num_segs, cor.hops_spent, rem_pressure, tostring(cor.handoff_port)
        ))
        return
    end

    -- 3. Probe next 16-tile segment
    local MAX_LEAF = 16
    local next_in = meta.cur_in
    local next_node = meta.cur_node
    local next_seg_dist = 0
    local hops_spent = meta.hops_spent
    local hops_budget = meta.hops_budget
    local last_out_node = next_node
    local last_out_key = nil
    local is_stopped = false

    while next_seg_dist < MAX_LEAF and hops_spent < hops_budget do
        local out_k, f_dir, out_n = flow_pressure_corridor.get_colinear_partner(next_in, next_node)
        if not (out_k and f_dir and out_n) then is_stopped = true break end
        if f_dir.x ~= dir.x or f_dir.y ~= dir.y then is_stopped = true break end

        local step_span = math.abs(out_n.pos.x - next_node.pos.x) + math.abs(out_n.pos.y - next_node.pos.y)
        if step_span < 0.05 then step_span = 1.0 end

        next_seg_dist = next_seg_dist + step_span
        hops_spent = hops_spent + 1
        last_out_node = out_n
        last_out_key = out_k

        storage.port_to_pressure_corridor[next_in] = corridor_id
        storage.port_to_pressure_corridor[out_k] = corridor_id
        cor.covered_ports[#cor.covered_ports + 1] = next_in
        cor.covered_ports[#cor.covered_ports + 1] = out_k

        local neighbors = storage.flow_connections and storage.flow_connections[out_k]
        local n_count = 0
        local next_cand_in = nil
        if neighbors then
            for n_k in pairs(neighbors) do
                n_count = n_count + 1
                next_cand_in = n_k
            end
        end

        local next_cand_node = (n_count == 1 and next_cand_in) and storage.flow_nodes and storage.flow_nodes[next_cand_in]
        if n_count ~= 1 or not next_cand_node or hops_spent >= hops_budget then
            is_stopped = true
            next_in = next_cand_in
            break
        end

        next_in = next_cand_in
        next_node = next_cand_node
    end

    if next_seg_dist <= 0 then next_seg_dist = 1.0 end

    local next_seg_idx = cur_seg + 1
    local next_seg_key = string.format("%d,%d:%d", dir.x, dir.y, next_seg_idx)
    local seg_start = { x = flight.terminal_pos.x, y = flight.terminal_pos.y }
    local seg_end = { x = last_out_node.pos.x, y = last_out_node.pos.y }
    local d_start = meta.total_dist
    local d_end = d_start + next_seg_dist

    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    if traj_tree then
        traj_tree:insert_segment(corridor_id, next_seg_key, seg_start, seg_end, d_start, d_end, next_seg_idx)
        trajectory_bvh.refresh_active_renders()
    end

    if motion_tree then
        local leaf = motion_tree:insert_segment(corridor_id, next_seg_key, seg_start, seg_end, d_start, d_end, next_seg_idx)
        if leaf then
            leaf.has_trail = nil
            leaf.trail_count = nil
            leaf.dir = { x = dir.x, y = dir.y }
            leaf.q_level = cor.q_level or 0
            leaf.pressure_corridor = true
            leaf.pressure_level = cor.flow_level
            viewport_bvh.on_segment_registered(s_idx, leaf)
        end
    end

    cor.num_segs = next_seg_idx
    cor.hops_spent = hops_spent
    cor.exit_port = last_out_key or cor.exit_port
    cor.handoff_port = next_in

    local seg_hops = hops_spent - meta.hops_spent
    local flight_ticks = math.max(1, seg_hops)
    local arrival_tick = current_tick + flight_ticks

    flight.start_pos = seg_start
    flight.terminal_pos = seg_end
    flight.seg_idx = next_seg_idx
    flight.flight_ticks = flight_ticks
    flight.start_tick = current_tick
    flight.arrival_tick = arrival_tick

    meta.hops_spent = hops_spent
    meta.total_dist = d_end
    meta.cur_in = next_in
    meta.cur_node = next_node
    meta.is_stopped = is_stopped
    meta.handoff_target = next_in

    local heap = timed_motion.get_arrival_heap()
    if heap then
        heap:push(flight_id, arrival_tick, flight_id)
    end

    game.print(string.format(
        "[color=cyan][PressureCorridor:PROBE][/color] '%s': Segment %d (%.1f tiles, %d ticks) -> advancing...",
        corridor_id, next_seg_idx, next_seg_dist, flight_ticks
    ))
end

timed_motion.register_arrival_handler("pressure_scope_arrival", flow_pressure_corridor.handle_scope_arrival)
timed_motion.register_arrival_handler("pressure_corridor_arrival", flow_pressure_corridor.handle_corridor_arrival)

--- Removes a seed corridor from the BVH and clears viewport dots
--- @param corridor_id string
function flow_pressure_corridor.remove_corridor(corridor_id)
    if not corridor_id then return end
    local cor = storage.pressure_corridors and storage.pressure_corridors[corridor_id]
    if not cor then return end

    local s_idx = cor.surface_index or 1
    local num_segs = cor.num_segs or 1
    local dir = cor.dir or { x = 0, y = 0 }

    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    local motion_tree = timed_motion.get_motion_tree(s_idx)

    for s = 1, num_segs do
        local seg_key = string.format("%d,%d:%d", dir.x, dir.y, s)
        if traj_tree then
            traj_tree:remove_segment(corridor_id, seg_key)
        end
        if motion_tree then
            motion_tree:remove_segment(corridor_id, seg_key)
        end
        viewport_bvh.on_segment_removed(s_idx, corridor_id, seg_key)
    end

    if traj_tree then
        trajectory_bvh.refresh_active_renders()
    end

    if storage.pinned_corridors then
        storage.pinned_corridors[corridor_id] = nil
    end

    if storage.port_to_pressure_corridor then
        if cor.entry_port then storage.port_to_pressure_corridor[cor.entry_port] = nil end
        if cor.exit_port then storage.port_to_pressure_corridor[cor.exit_port] = nil end
    end

    storage.pressure_corridors[corridor_id] = nil

    game.print(string.format(
        "[color=red][PressureCorridor:REMOVED][/color] Teardown corridor '%s' on unit #%d -> BVH leaf unpinned!",
        corridor_id, cor.unit_number or 0
    ))
end

--- Returns the active corridor ID owning a port, if any
--- @param pkey string
--- @return string|nil corridor_id
function flow_pressure_corridor.get_corridor_for_port(pkey)
    return storage.port_to_pressure_corridor and storage.port_to_pressure_corridor[pkey]
end

--- Reactively determines if a port on an entity is an unbranched, colinear straight through-pass
--- @param pkey string The port key being evaluated
--- @param node table The flow node record
--- @return string|nil partner_key Port key of the colinear exit port, or nil if not straight
--- @return table|string flow_dir Vector {x, y} exiting the entity, or string reason if failed
--- @return table|nil partner_node The flow node record of the partner port
function flow_pressure_corridor.get_colinear_partner(pkey, node)
    if not (node and node.unit_number and node.group and node.dir) then
        return nil, "missing_node_data"
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
    if not unit_ports then
        return nil, "no_unit_ports"
    end

    local partner_key = nil
    local partner_node = nil
    local candidate_count = 0

    for _, check_pkey in pairs(unit_ports) do
        if check_pkey ~= pkey then
            local check_node = storage.flow_nodes and storage.flow_nodes[check_pkey]
            if check_node and check_node.group == node.group and check_node.pressure_transmit then
                candidate_count = candidate_count + 1
                partner_key = check_pkey
                partner_node = check_node
            end
        end
    end

    -- If candidate count > 1: entity has multiple exits in this group (Branch)
    -- If candidate count == 0: entity has no exit in this group (Terminus)
    if candidate_count == 0 then
        return nil, "terminus"
    elseif candidate_count > 1 then
        return nil, "branch"
    end

    if not (partner_node and partner_node.dir) then
        return nil, "partner_missing_dir"
    end

    -- Colinearity test: straight through-pass ports face exactly 180 degrees opposite
    -- e.g. Port 1 dir={0, -1} (North entry), Port 2 dir={0, 1} (South exit)
    local is_colinear = (node.dir.x + partner_node.dir.x == 0) and (node.dir.y + partner_node.dir.y == 0)
    if not is_colinear then
        return nil, "bend"
    end

    -- Exit direction follows partner port's outward normal
    local flow_dir = { x = partner_node.dir.x, y = partner_node.dir.y }
    return partner_key, flow_dir, partner_node
end

--- Hook A: Called when an emitter node (e.g. pump output/intake) begins positive or negative emission
function flow_pressure_corridor.on_pressure_emit(pkey, node, target_flow, current_flow)
    local ent_name = (node.entity and node.entity.valid and node.entity.name) or "emitter"
    local u_num = node.unit_number or 0

    local neighbors = storage.flow_connections and storage.flow_connections[pkey]
    local neighbor_count = 0
    local neighbor_key = nil
    if neighbors then
        for n_key in pairs(neighbors) do
            neighbor_count = neighbor_count + 1
            neighbor_key = n_key
        end
    end

    game.print(string.format(
        "[color=cyan][PressureCorridor:EMIT][/color] Port %s (%s #%d): flow=%d | connected_to=%s (count=%d)",
        pkey, ent_name, u_num, target_flow, tostring(neighbor_key), neighbor_count
    ))
end

--- Hook B: Called when pressure first transmits into a passive pneumatic port
function flow_pressure_corridor.on_pressure_transmit(pkey, node, target_flow, current_flow)
    local ent_name = (node.entity and node.entity.valid and node.entity.name) or "node"
    local u_num = node.unit_number or 0

    local partner_key, flow_dir, partner_node = flow_pressure_corridor.get_colinear_partner(pkey, node)

    if partner_key and flow_dir then
        local neighbors = storage.flow_connections and storage.flow_connections[partner_key]
        local neighbor_count = 0
        local next_conn = nil
        if neighbors then
            for n_key in pairs(neighbors) do
                neighbor_count = neighbor_count + 1
                next_conn = n_key
            end
        end

        local corridor_id = flow_pressure_corridor.create_seed_corridor(pkey, node, partner_key, partner_node, flow_dir, target_flow)

        game.print(string.format(
            "[color=green][PressureCorridor:STRAIGHT][/color] %s (%s #%d) flow=%d | exit=%s dir=(%d,%d) | next_edge=%s (corridor=%s)",
            pkey, ent_name, u_num, target_flow, partner_key, flow_dir.x, flow_dir.y, tostring(next_conn), tostring(corridor_id)
        ))
        return true, corridor_id
    else
        local reason = (type(flow_dir) == "string" and flow_dir) or "unknown"
        game.print(string.format(
            "[color=orange][PressureCorridor:NON-STRAIGHT][/color] %s (%s #%d) flow=%d | stopped_by=%s",
            pkey, ent_name, u_num, target_flow, reason
        ))
        return false, reason
    end
end

return flow_pressure_corridor
