local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local flow_common = require("scripts.flow.flow-common")
local flow_renderer = require("scripts.flow.flow-renderer")
local flow_gate_interop = require("scripts.flow.flow-gate-interop")
local flow_kinetic = require("scripts.flow.flow-kinetic")
local pump_settings = require("scripts.pumps.pump-settings")
local diverter_settings = require("scripts.diverters.diverter-settings")
local counter_range = require("scripts.counters.counter-range")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local projector_settings = require("scripts.projectors.projector-settings")
local motion_protocols = require("scripts.utils.motion-protocols")
local timed_motion = require("scripts.utils.timed-motion")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local viewport_bvh = require("scripts.utils.viewport-bvh")
local render_pool = require("scripts.utils.render-pool")

local flow_engine = {}

local USE_PRESSURE_CORRIDORS = true
flow_common.USE_PRESSURE_CORRIDORS = USE_PRESSURE_CORRIDORS

local BATCH_SIZE = 50
local MAX_FLOW = 10
local DEFAULT_RANGE_SEED = 15
local BASE_PROJECTOR_RANGE = 50
local HOP_DISTANCE = 5

local PROXY_NAMES = {
    ["pneumatic-pump-circuit-proxy"] = true,
    ["pneumatic-diverter-circuit-proxy"] = true,
    ["pneumatic-capsule-counter-circuit-proxy"] = true,
    ["pneumatic-capsule-counter-red-proxy"] = true,
    ["pneumatic-capsule-counter-green-proxy"] = true,
    ["pneumatic-projector-circuit-proxy"] = true
}

local IGNORABLE_TYPES = {
    ["resource"] = true,
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
    ["character"] = true,
    ["car"] = true,
    ["spider-vehicle"] = true,
    ["unit"] = true,
    ["fish"] = true,
    ["item-entity"] = true,
    ["flying-robot"] = true,
    ["logistic-robot"] = true,
    ["construction-robot"] = true,
    ["combat-robot"] = true,
    ["projectile"] = true,
    ["smoke"] = true,
    ["smoke-with-trigger"] = true,
    ["sticker"] = true,
    ["highlight-box"] = true,
    ["speech-bubble"] = true,
    ["corpse"] = true,
    ["character-corpse"] = true,
    ["fire"] = true,
    ["particle"] = true,
    ["leaf-particle"] = true,
    ["item-request-proxy"] = true,
    ["deconstructible-tile-proxy"] = true,
    ["land-mine"] = true,
    ["cliff"] = true,
    ["elevated-straight-rail"] = true,
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true
}

local registered_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    registered_entities[name] = true
end

local function is_standard_entity(name)
    return flow_gate_interop.is_standard_entity(name)
end

local make_port_key = flow_common.make_port_key
local make_pos_key = flow_common.make_pos_key
local make_edge_key = flow_common.make_edge_key
local wake_port_parked = flow_common.wake_port_parked

flow_engine.wake_port_parked = flow_common.wake_port_parked
flow_engine.wake_parked_capsules = flow_common.wake_port_parked

function flow_engine.is_touching_active_flow(entity)
    return flow_gate_interop.is_touching_active_flow(entity, flow_engine.get_node_emitter_level, flow_engine.get_node_kinetic_emitter)
end

function flow_engine.is_touching_pneumatic_grid(entity)
    return flow_gate_interop.is_touching_pneumatic_grid(entity)
end

function flow_engine.init_storage()
    storage.flow_nodes = storage.flow_nodes or {}
    storage.flow_grid = storage.flow_grid or {}
    storage.flow_connections = storage.flow_connections or {}
    storage.flow_levels = storage.flow_levels or {}
    storage.flow_queue = storage.flow_queue or {}
    storage.flow_unit_ports = storage.flow_unit_ports or {}
    storage.flow_renders = storage.flow_renders or {}
    storage.flow_edge_renders = storage.flow_edge_renders or {}
    storage.kinetic_renders = storage.kinetic_renders or {}
    storage.character_colliders = storage.character_colliders or {}
    storage.character_last_pos_key = storage.character_last_pos_key or {}
    storage.character_last_cpos = storage.character_last_cpos or {}
    storage.character_last_surface = storage.character_last_surface or {}
    for k, v in pairs(storage.kinetic_renders) do
        if type(k) == "string" then
            if type(v) == "table" then
                if v.dot and v.dot.valid then v.dot.destroy() end
                if v.ring and v.ring.valid then v.ring.destroy() end
            end
            storage.kinetic_renders[k] = nil
        end
    end
    storage.kinetic_levels = storage.kinetic_levels or {}
    storage.parked_by_port = storage.parked_by_port or {}
    storage.object_destruction_map = storage.object_destruction_map or {}
    storage.pressure_corridors = storage.pressure_corridors or {}
    storage.corridor_tip_flows = storage.corridor_tip_flows or {}

    -- Counter Range Fields
    storage.counter_levels = storage.counter_levels or {}
    storage.counter_owners = storage.counter_owners or {}
    storage.counter_owned_nodes = storage.counter_owned_nodes or {}
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.counter_renders = storage.counter_renders or {}
    storage.counter_capsules = storage.counter_capsules or {}
    if not storage.counter_capsules_initialized then
        storage.counter_capsules_initialized = true
        counter_range.rebuild_territory_capsules()
    end

    -- Walls and Gates Fields
    flow_gate_interop.init_storage()

    -- Electromagnetic Projector Fields
    storage.active_projectors = storage.active_projectors or {}
    storage.projector_power_states = storage.projector_power_states or {}
    storage.projector_ready_states = storage.projector_ready_states or {}
    storage.projector_last_fired = storage.projector_last_fired or {}
    storage.pending_bvh_segments = storage.pending_bvh_segments or {}
    storage.blocked_reticles = storage.blocked_reticles or {}
    storage.blocked_reticles_by_reg = storage.blocked_reticles_by_reg or {}
    storage.reticle_blocked_by = storage.reticle_blocked_by or {}
    storage.reticle_gates = storage.reticle_gates or {}
    if storage.flow_nodes then
        for pkey, node in pairs(storage.flow_nodes) do
            if node and node.is_kinetic and node.is_endpoint then
                flow_engine.enqueue_port(pkey)
            end
        end
    end
end

function flow_engine.enqueue_port(pkey)
    flow_common.enqueue_port(pkey)
end

function flow_engine.enqueue_projector(unit_number)
    flow_common.enqueue_unit_ports(unit_number)
end

function flow_engine.enqueue_unit_ports(unit_number)
    flow_common.enqueue_unit_ports(unit_number)
end

motion_protocols.register_protocol("pressure_corridor", {
    medium = "pneumatic_network",
    progression = "chained_segment",
    head = "none",
    trail = "none",
    disruption = "silent_halt",
    arrival = "none",
    static_render = "pressure_static",
    detector = "tube_connectivity",
    clearance_policy = "none"
})

local function is_gate_open(unit_number)
    if not (unit_number and storage.active_gates and storage.active_gates[unit_number]) then
        return false
    end
    local gate = storage.active_gates[unit_number]
    if not (gate and gate.valid) then return false end
    if gate.is_opened and gate.is_opened() then return true end
    if gate.is_opening and gate.is_opening() then return true end
    return false
end
flow_engine.is_gate_open = is_gate_open

local function scan_pneumatic_colinear_reach(in_pkey, in_node, out_pkey, out_node, flow_level)
    local dx = out_node.dir.x
    local dy = out_node.dir.y
    local curr_out = out_pkey
    local curr_out_node = out_node
    local initial_len = math.floor(math.abs(out_node.pos.x - in_node.pos.x) + math.abs(out_node.pos.y - in_node.pos.y) + 0.5)
    local total_dist = math.max(1, initial_len)
    local corridor_entities = { [in_node.unit_number] = { [in_node.group or 1] = true } }
    local terminal_branch_pkey = nil

    local max_reach = math.max(1, math.abs(flow_level or 10))

    while total_dist < max_reach do
        local conns = storage.flow_connections and storage.flow_connections[curr_out]
        if not conns or next(conns) == nil then
            break
        end

        local next_in_pkey = nil
        for n_key in pairs(conns) do
            next_in_pkey = n_key
            break
        end

        local next_in_node = storage.flow_nodes and storage.flow_nodes[next_in_pkey]
        if not next_in_node then break end

        local next_unit = next_in_node.unit_number
        local next_grp = next_in_node.group or 1
        if not next_unit or (corridor_entities[next_unit] and corridor_entities[next_unit][next_grp]) then break end
        if is_gate_open(next_unit) then break end

        local next_u_ports = storage.flow_unit_ports and storage.flow_unit_ports[next_unit]
        if not next_u_ports then break end

        local found_straight_exit = nil
        local found_exit_node = nil
        for _, other_key in ipairs(next_u_ports) do
            if other_key ~= next_in_pkey then
                local other_node = storage.flow_nodes and storage.flow_nodes[other_key]
                if other_node and other_node.group == next_in_node.group then
                    if flow_common.is_colinear_straight_internal(next_in_pkey, next_in_node, other_key, other_node) then
                        if other_node.dir and other_node.dir.x == dx and other_node.dir.y == dy then
                            found_straight_exit = other_key
                            found_exit_node = other_node
                            break
                        end
                    end
                end
            end
        end

        if not (found_straight_exit and found_exit_node) then
            terminal_branch_pkey = next_in_pkey
            break
        end

        local seg_len = math.floor(math.abs(found_exit_node.pos.x - next_in_node.pos.x) + math.abs(found_exit_node.pos.y - next_in_node.pos.y) + 0.5)
        if seg_len <= 0 then seg_len = 1 end
        total_dist = total_dist + seg_len

        corridor_entities[next_unit] = corridor_entities[next_unit] or {}
        corridor_entities[next_unit][next_in_node.group or 1] = true
        curr_out = found_straight_exit
        curr_out_node = found_exit_node
    end

    return total_dist, terminal_branch_pkey, corridor_entities, curr_out
end

function flow_engine.on_pressure_begin_transmit(in_pkey, in_node, out_pkey, out_node, flow_level)
    if not (in_node and out_node and in_node.pos and out_node.pos and out_node.dir) then return end
    if is_gate_open(in_node.unit_number) then return end
    local in_conns = storage.flow_connections and storage.flow_connections[in_pkey]
    local is_emitter = in_node.emitter and in_node.emitter ~= 0
    if not (is_emitter or (in_conns and next(in_conns) ~= nil)) then return end
    if USE_PRESSURE_CORRIDORS and storage.corridor_tip_flows and storage.corridor_tip_flows[in_pkey] then return end

    local corridor_id = "corridor:" .. in_pkey .. "->" .. out_pkey
    local opposing_id = "corridor:" .. out_pkey .. "->" .. in_pkey
    if storage.pressure_corridors and storage.pressure_corridors[opposing_id] then
        flow_engine.unseed_pressure_corridor(opposing_id, true)
    end

    storage.pressure_corridors = storage.pressure_corridors or {}
    local existing = storage.pressure_corridors[corridor_id]
    if existing and existing.flow_level == flow_level and existing.status ~= "receding" then
        return
    end

    if existing then
        flow_engine.unseed_pressure_corridor(corridor_id, true)
    end

    local surface_name = in_node.surface_name
    local surface = surface_name and game.surfaces[surface_name]
    if not (surface and surface.valid) then return end
    local s_idx = surface.index

    local source_pkey = nil
    local source_unit = nil
    if is_emitter then
        source_pkey = in_pkey
        source_unit = in_node.unit_number
    elseif in_conns then
        for neighbor_key in pairs(in_conns) do
            local n_node = storage.flow_nodes and storage.flow_nodes[neighbor_key]
            if n_node then
                source_pkey = neighbor_key
                source_unit = n_node.unit_number
                break
            end
        end
    end
    if not source_unit then return end

    local total_dist, terminal_branch_pkey, corridor_entities, last_out_pkey = scan_pneumatic_colinear_reach(in_pkey, in_node, out_pkey, out_node, flow_level)
    local dx = out_node.dir.x
    local dy = out_node.dir.y
    local start_pos = { x = in_node.pos.x, y = in_node.pos.y }
    local terminal_pos = { x = start_pos.x + dx * total_dist, y = start_pos.y + dy * total_dist }
    local max_seg_idx = math.max(1, math.ceil(total_dist / 16))

    storage.pressure_corridors[corridor_id] = {
        id = corridor_id,
        in_pkey = in_pkey,
        out_pkey = out_pkey,
        source_pkey = source_pkey,
        source_unit = source_unit,
        unit_number = in_node.unit_number,
        surface_name = surface_name,
        surface_index = s_idx,
        start_pos = start_pos,
        terminal_pos = terminal_pos,
        dir = { x = dx, y = dy },
        total_dist = total_dist,
        current_reach = 1,
        flow_level = flow_level,
        initial_flow = math.abs(flow_level or 10),
        decay_mag = math.abs(flow_level or 10),
        q_level = in_node.q_level or 0,
        group = in_node.group or 1,
        max_seg_idx = max_seg_idx,
        corridor_entities = corridor_entities,
        terminal_branch_pkey = terminal_branch_pkey,
        last_out_pkey = last_out_pkey,
        start_tick = game.tick,
        status = "growing",
        registered_segs = 1,
        ticks_per_tile = 2
    }

    motion_protocols.protocols[corridor_id] = motion_protocols.protocols["pressure_corridor"]

    local motion_tree = timed_motion.get_motion_tree(s_idx)
    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    local corr_leaves = {}

    for s = 1, 1 do
        local s_start = 0
        local s_end = math.min(16, total_dist)
        local seg_key = string.format("%d,%d:%d", dx, dy, s)
        local seg_start_pos = { x = start_pos.x + dx * s_start, y = start_pos.y + dy * s_start }
        local seg_end_pos = { x = start_pos.x + dx * s_end, y = start_pos.y + dy * s_end }

        if motion_tree then
            local leaf = motion_tree:insert_segment(corridor_id, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
            if leaf then
                leaf.dir = { x = dx, y = dy }
                leaf.q_level = in_node.q_level or 0
                leaf.has_trail = true
                leaf.trail_count = math.max(0, math.floor(s_end - s_start + 0.5))
                corr_leaves[seg_key] = leaf
                viewport_bvh.on_segment_registered(s_idx, leaf)
            end
        end

        if traj_tree then
            traj_tree:insert_segment(corridor_id, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
        end
    end

    storage.pressure_corridors[corridor_id].leaves = corr_leaves
    if traj_tree then
        trajectory_bvh.refresh_active_renders()
    end
end

function flow_engine.on_pressure_stop_transmit(in_pkey, in_node, out_pkey, out_node)
    local corridor_id = "corridor:" .. in_pkey .. "->" .. out_pkey
    local corr = storage.pressure_corridors and storage.pressure_corridors[corridor_id]
    if corr and corr.status ~= "receding" then
        corr.status = "receding"
        corr.retreat_tick = game.tick
        local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
        corr.end_decay_tick = game.tick + math.max(15, init_mag * 3)
    end
end

function flow_engine.split_pressure_corridor(cid, corr, unit_number, ent_pos, is_branch)
    if not (cid and corr and unit_number) then return end
    if corr.status == "receding" then return end

    local s_idx = corr.surface_index or 1
    local dx = corr.dir.x
    local dy = corr.dir.y

    if not ent_pos then
        local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
        if unit_ports then
            for _, pk in pairs(unit_ports) do
                local nd = storage.flow_nodes and storage.flow_nodes[pk]
                if nd and nd.pos then
                    ent_pos = nd.pos
                    break
                end
            end
        end
    end
    if not ent_pos then return end

    local axis_dist = (ent_pos.x - corr.start_pos.x) * dx + (ent_pos.y - corr.start_pos.y) * dy

    local upstream_entities = {}
    local downstream_entities = {}
    local corr_group = corr.group or 1
    if corr.corridor_entities then
        for u, grp_data in pairs(corr.corridor_entities) do
            if u ~= unit_number and not is_gate_open(u) then
                local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u]
                local u_node = nil
                if u_ports then
                    for _, pk in pairs(u_ports) do
                        local nd = storage.flow_nodes and storage.flow_nodes[pk]
                        if nd and (nd.group == corr_group or (type(grp_data) == "table" and grp_data[nd.group])) then
                            u_node = nd
                            break
                        end
                    end
                end
                if u_node and u_node.pos then
                    local u_dist = (u_node.pos.x - corr.start_pos.x) * dx + (u_node.pos.y - corr.start_pos.y) * dy
                    if u_dist < axis_dist then
                        upstream_entities[u] = grp_data
                    else
                        downstream_entities[u] = grp_data
                    end
                end
            end
        end
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    local new_up_out_pkey = nil
    local new_down_in_pkey = nil
    local branch_in_pkey = nil
    if unit_ports then
        for _, pk in pairs(unit_ports) do
            local conns = storage.flow_connections and storage.flow_connections[pk]
            if conns then
                for n_key in pairs(conns) do
                    local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                    if n_node then
                        if upstream_entities[n_node.unit_number] then
                            if n_node.dir and n_node.dir.x == dx and n_node.dir.y == dy then
                                new_up_out_pkey = n_key
                                branch_in_pkey = pk
                            end
                        elseif downstream_entities[n_node.unit_number] then
                            new_down_in_pkey = n_key
                        end
                    end
                end
            end
        end
    end

    if not new_up_out_pkey then
        local max_up_dist = -1
        for u in pairs(upstream_entities) do
            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u]
            if u_ports then
                for _, pk in pairs(u_ports) do
                    local nd = storage.flow_nodes and storage.flow_nodes[pk]
                    if nd and (nd.group == corr_group) and nd.pos and nd.dir and nd.dir.x == dx and nd.dir.y == dy then
                        local d = (nd.pos.x - corr.start_pos.x) * dx + (nd.pos.y - corr.start_pos.y) * dy
                        if d > max_up_dist then
                            max_up_dist = d
                            new_up_out_pkey = pk
                        end
                    end
                end
            end
        end
    end

    if not branch_in_pkey and new_up_out_pkey and unit_ports then
        for _, pk in pairs(unit_ports) do
            local conns = storage.flow_connections and storage.flow_connections[pk]
            if conns and conns[new_up_out_pkey] then
                branch_in_pkey = pk
                break
            end
        end
    end

    if not new_down_in_pkey then
        local min_down_dist = 999999
        for u in pairs(downstream_entities) do
            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u]
            if u_ports then
                for _, pk in pairs(u_ports) do
                    local nd = storage.flow_nodes and storage.flow_nodes[pk]
                    if nd and (nd.group == corr_group) and nd.pos and nd.dir and nd.dir.x == -dx and nd.dir.y == -dy then
                        local d = (nd.pos.x - corr.start_pos.x) * dx + (nd.pos.y - corr.start_pos.y) * dy
                        if d < min_down_dist then
                            min_down_dist = d
                            new_down_in_pkey = pk
                        end
                    end
                end
            end
        end
    end

    local up_node = new_up_out_pkey and storage.flow_nodes and storage.flow_nodes[new_up_out_pkey]
    local exact_up_dist = 0
    if up_node and up_node.pos then
        local d = (up_node.pos.x - corr.start_pos.x) * dx + (up_node.pos.y - corr.start_pos.y) * dy
        exact_up_dist = math.floor(math.abs(d) + 0.5)
    end

    local orig_terminal_branch = corr.terminal_branch_pkey
    local orig_last_out = corr.last_out_pkey
    local orig_branch_enqueued = corr.branch_enqueued
    local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)

    local down_in_node = new_down_in_pkey and storage.flow_nodes and storage.flow_nodes[new_down_in_pkey]
    local down_out_pkey = nil
    local down_out_node = nil

    if down_in_node then
        local down_u_ports = storage.flow_unit_ports and storage.flow_unit_ports[down_in_node.unit_number]
        if down_u_ports then
            for _, other_key in ipairs(down_u_ports) do
                if other_key ~= new_down_in_pkey then
                    local other_node = storage.flow_nodes and storage.flow_nodes[other_key]
                    if other_node and other_node.group == down_in_node.group then
                        if flow_common.is_colinear_straight_internal(new_down_in_pkey, down_in_node, other_key, other_node) then
                            if other_node.dir and other_node.dir.x == dx and other_node.dir.y == dy then
                                down_out_pkey = other_key
                                down_out_node = other_node
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    local exact_down_dist = nil
    if down_in_node and down_in_node.pos then
        local d = (down_in_node.pos.x - corr.start_pos.x) * dx + (down_in_node.pos.y - corr.start_pos.y) * dy
        exact_down_dist = math.floor(math.abs(d) + 0.5)
    end

    local down_flow_mag = exact_down_dist and math.max(0, init_mag - exact_down_dist) or 0
    local down_flow_level = (corr.flow_level and corr.flow_level < 0) and -down_flow_mag or down_flow_mag

    if down_in_node and down_out_node and down_flow_mag >= 1 then
        local down_total_dist, down_term_branch, down_corridor_entities, down_last_out = scan_pneumatic_colinear_reach(
            new_down_in_pkey, down_in_node, down_out_pkey, down_out_node, down_flow_level
        )
        local down_cid = cid .. ":severed:" .. tostring(exact_up_dist) .. ":" .. tostring(game.tick)
        local down_start_pos = { x = down_in_node.pos.x, y = down_in_node.pos.y }
        local down_terminal_pos = { x = down_start_pos.x + dx * down_total_dist, y = down_start_pos.y + dy * down_total_dist }
        local down_max_seg = math.max(1, math.ceil(down_total_dist / 16))

        local down_corr = {
            id = down_cid,
            in_pkey = new_down_in_pkey,
            out_pkey = down_out_pkey,
            source_pkey = nil,
            source_unit = nil,
            unit_number = down_in_node.unit_number,
            surface_name = corr.surface_name,
            surface_index = s_idx,
            start_pos = down_start_pos,
            terminal_pos = down_terminal_pos,
            dir = { x = dx, y = dy },
            total_dist = down_total_dist,
            current_reach = down_total_dist,
            flow_level = down_flow_level,
            initial_flow = down_flow_mag,
            decay_mag = down_flow_mag,
            q_level = corr.q_level or 0,
            group = down_in_node.group or 1,
            max_seg_idx = down_max_seg,
            corridor_entities = down_corridor_entities,
            terminal_branch_pkey = down_term_branch,
            last_out_pkey = down_last_out,
            branch_enqueued = (down_term_branch ~= nil),
            start_tick = corr.start_tick,
            status = "receding",
            retreat_tick = game.tick,
            end_decay_tick = game.tick + math.max(15, down_flow_mag * 3),
            registered_segs = down_max_seg,
            ticks_per_tile = corr.ticks_per_tile or 2,
            leaves = {}
        }

        motion_protocols.protocols[down_cid] = motion_protocols.protocols["pressure_corridor"]

        local motion_tree = timed_motion.get_motion_tree(s_idx)
        local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
        local down_leaves = {}

        for s = 1, down_max_seg do
            local s_start = (s - 1) * 16
            local s_end = math.min(s * 16, down_total_dist)
            local seg_key = string.format("%d,%d:%d", dx, dy, s)
            local seg_start_pos = { x = down_start_pos.x + dx * s_start, y = down_start_pos.y + dy * s_start }
            local seg_end_pos = { x = down_start_pos.x + dx * s_end, y = down_start_pos.y + dy * s_end }

            if motion_tree then
                local leaf = motion_tree:insert_segment(down_cid, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
                if leaf then
                    leaf.dir = { x = dx, y = dy }
                    leaf.q_level = corr.q_level or 0
                    leaf.has_trail = true
                    leaf.trail_count = math.max(0, math.floor(s_end - s_start + 0.5))
                    down_leaves[seg_key] = leaf
                    viewport_bvh.on_segment_registered(s_idx, leaf)
                end
            end

            if traj_tree then
                traj_tree:insert_segment(down_cid, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
            end
        end

        down_corr.leaves = down_leaves
        storage.pressure_corridors[down_cid] = down_corr

        if down_last_out and storage.corridor_tip_flows then
            local tip_mag = math.max(0, down_flow_mag - (down_total_dist - 1))
            local rem_level = (tip_mag > 0) and ((down_flow_level < 0) and -tip_mag or tip_mag) or nil
            storage.corridor_tip_flows[down_last_out] = rem_level
            local out_node = storage.flow_nodes and storage.flow_nodes[down_last_out]
            if out_node then
                flow_renderer.update_pos_render(out_node.pos_key)
            end
            if down_term_branch then
                flow_engine.enqueue_port(down_term_branch)
                flow_common.wake_port_parked(down_term_branch)
            end
            flow_common.wake_port_parked(down_last_out)
        end
    else
        if orig_last_out and storage.corridor_tip_flows and storage.corridor_tip_flows[orig_last_out] then
            storage.corridor_tip_flows[orig_last_out] = nil
            local out_node = storage.flow_nodes and storage.flow_nodes[orig_last_out]
            if out_node then
                flow_renderer.update_pos_render(out_node.pos_key)
            end
            if orig_terminal_branch then
                flow_engine.enqueue_port(orig_terminal_branch)
                flow_common.wake_port_parked(orig_terminal_branch)
            end
            flow_common.wake_port_parked(orig_last_out)
        end
    end

    if exact_up_dist < 1 then
        if orig_last_out and storage.corridor_tip_flows and storage.corridor_tip_flows[orig_last_out] then
            storage.corridor_tip_flows[orig_last_out] = nil
            local old_node = storage.flow_nodes and storage.flow_nodes[orig_last_out]
            if old_node then
                flow_renderer.update_pos_render(old_node.pos_key)
            end
            flow_common.wake_port_parked(orig_last_out)
        end
        corr.last_out_pkey = nil
        corr.terminal_branch_pkey = nil
        flow_engine.unseed_pressure_corridor(cid, true)
        if is_branch then
            flow_common.enqueue_unit_ports(unit_number)
        end
        return
    end

    corr.total_dist = exact_up_dist
    corr.terminal_pos = { x = corr.start_pos.x + dx * exact_up_dist, y = corr.start_pos.y + dy * exact_up_dist }
    corr.current_reach = math.min(corr.current_reach or exact_up_dist, exact_up_dist)
    corr.corridor_entities = upstream_entities
    if is_branch and branch_in_pkey then
        corr.terminal_branch_pkey = branch_in_pkey
        corr.branch_enqueued = true
    else
        corr.terminal_branch_pkey = nil
        corr.branch_enqueued = nil
    end
    if new_up_out_pkey then
        corr.last_out_pkey = new_up_out_pkey
    end

    local motion_tree = timed_motion.get_motion_tree(s_idx)
    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    local old_reg_segs = math.max(corr.registered_segs or 1, corr.max_seg_idx or 1)
    local new_max_segs = math.max(1, math.ceil(exact_up_dist / 16))

    corr.max_seg_idx = new_max_segs
    corr.registered_segs = new_max_segs

    for s = new_max_segs + 1, old_reg_segs do
        local seg_key = string.format("%d,%d:%d", dx, dy, s)
        if motion_tree then
            motion_tree:remove_segment(cid, seg_key)
        end
        viewport_bvh.on_segment_removed(s_idx, cid, seg_key)
        if traj_tree then
            traj_tree:remove_segment(cid, seg_key)
        end
        if corr.leaves then
            corr.leaves[seg_key] = nil
        end
    end

    local s = new_max_segs
    local seg_key = string.format("%d,%d:%d", dx, dy, s)
    if motion_tree then
        motion_tree:remove_segment(cid, seg_key)
    end
    viewport_bvh.on_segment_removed(s_idx, cid, seg_key)
    if traj_tree then
        traj_tree:remove_segment(cid, seg_key)
    end

    local s_start = (s - 1) * 16
    local s_end = exact_up_dist
    local seg_start_pos = { x = corr.start_pos.x + dx * s_start, y = corr.start_pos.y + dy * s_start }
    local seg_end_pos = { x = corr.start_pos.x + dx * s_end, y = corr.start_pos.y + dy * s_end }

    if motion_tree then
        local leaf = motion_tree:insert_segment(cid, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
        if leaf then
            leaf.dir = { x = dx, y = dy }
            leaf.q_level = corr.q_level or 0
            leaf.has_trail = true
            leaf.trail_count = math.max(0, math.floor(s_end - s_start + 0.5))
            corr.leaves = corr.leaves or {}
            corr.leaves[seg_key] = leaf
            viewport_bvh.on_segment_registered(s_idx, leaf)
        end
    end

    if traj_tree then
        traj_tree:insert_segment(cid, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
        trajectory_bvh.refresh_active_renders()
    end

    if corr.current_reach >= exact_up_dist then
        corr.status = "active"
        if corr.leaves then
            for _, leaf in pairs(corr.leaves) do
                viewport_bvh.on_leaf_static_changed(s_idx, leaf)
            end
        end
    end

    if orig_last_out and orig_last_out ~= corr.last_out_pkey and orig_last_out ~= down_last_out then
        if storage.corridor_tip_flows and storage.corridor_tip_flows[orig_last_out] then
            storage.corridor_tip_flows[orig_last_out] = nil
            local old_node = storage.flow_nodes and storage.flow_nodes[orig_last_out]
            if old_node then
                flow_renderer.update_pos_render(old_node.pos_key)
            end
            flow_common.wake_port_parked(orig_last_out)
        end
    end

    if corr.last_out_pkey then
        local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
        local tip_mag = math.max(0, init_mag - (corr.total_dist - 1))
        local rem_level = (tip_mag > 0) and ((corr.flow_level and corr.flow_level < 0) and -tip_mag or tip_mag) or nil
        if storage.corridor_tip_flows then
            storage.corridor_tip_flows[corr.last_out_pkey] = rem_level
        end
        local out_node = storage.flow_nodes and storage.flow_nodes[corr.last_out_pkey]
        if out_node then
            flow_renderer.update_pos_render(out_node.pos_key)
        end
        flow_common.wake_port_parked(corr.last_out_pkey)
        flow_engine.enqueue_port(corr.last_out_pkey)
        if is_branch and branch_in_pkey then
            flow_engine.enqueue_port(branch_in_pkey)
            flow_common.enqueue_unit_ports(unit_number)
            flow_common.wake_port_parked(branch_in_pkey)
        end
    end
end

function flow_engine.unseed_pressure_corridor(corridor_id, force)
    local corr = storage.pressure_corridors and storage.pressure_corridors[corridor_id]
    if not corr then return end

    if not force and corr.status ~= "receding" then
        corr.status = "receding"
        corr.retreat_tick = game.tick
        return
    end

    if corr.last_out_pkey and storage.corridor_tip_flows and storage.corridor_tip_flows[corr.last_out_pkey] then
        storage.corridor_tip_flows[corr.last_out_pkey] = nil
        local out_node = storage.flow_nodes and storage.flow_nodes[corr.last_out_pkey]
        if out_node then
            flow_renderer.update_pos_render(out_node.pos_key)
        end
        if corr.terminal_branch_pkey then
            flow_engine.enqueue_port(corr.terminal_branch_pkey)
            flow_common.wake_port_parked(corr.terminal_branch_pkey)
        end
        flow_common.wake_port_parked(corr.last_out_pkey)
    end

    local s_idx = corr.surface_index or 1
    local motion_tree = timed_motion.get_motion_tree(s_idx)
    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    local num_segs = math.max(corr.registered_segs or 1, corr.max_seg_idx or 1)

    for s = 1, num_segs do
        local seg_key = string.format("%d,%d:%d", corr.dir.x, corr.dir.y, s)
        if motion_tree then
            motion_tree:remove_segment(corridor_id, seg_key)
        end
        viewport_bvh.on_segment_removed(s_idx, corridor_id, seg_key)
        if traj_tree then
            traj_tree:remove_segment(corridor_id, seg_key)
        end
    end

    viewport_bvh.on_segment_removed(s_idx, corridor_id, nil)

    if traj_tree then
        trajectory_bvh.refresh_active_renders()
    end

    if corr.source_pkey then
        flow_engine.enqueue_port(corr.source_pkey)
        flow_common.wake_port_parked(corr.source_pkey)
    end
    if corr.in_pkey then
        flow_engine.enqueue_port(corr.in_pkey)
        flow_common.wake_port_parked(corr.in_pkey)
    end

    motion_protocols.protocols[corridor_id] = nil
    storage.pressure_corridors[corridor_id] = nil
end

function flow_engine.step_pressure_corridors(tick)
    local corridors = storage.pressure_corridors
    if not (corridors and next(corridors) ~= nil) then return end

    if storage.corridor_tip_flows and next(storage.corridor_tip_flows) ~= nil then
        for pkey in pairs(storage.corridor_tip_flows) do
            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node and is_gate_open(node.unit_number) then
                storage.corridor_tip_flows[pkey] = nil
                flow_renderer.update_pos_render(node.pos_key)
                flow_common.wake_port_parked(pkey)
            end
        end
    end

    for cid, corr in pairs(corridors) do
        local tpt = corr.ticks_per_tile or 2
        local s_idx = corr.surface_index

        local src_alive = true
        if corr.source_pkey then
            local src_node = storage.flow_nodes and storage.flow_nodes[corr.source_pkey]
            local src_flow = (storage.corridor_tip_flows and storage.corridor_tip_flows[corr.source_pkey])
                or (storage.flow_levels and storage.flow_levels[corr.source_pkey]) or 0
            local in_conns = storage.flow_connections and storage.flow_connections[corr.in_pkey]
            local is_self_emitter = (corr.source_pkey == corr.in_pkey) and (src_node and src_node.emitter and src_node.emitter ~= 0)
            if (not src_node) or (src_flow == 0 and not is_self_emitter) or (not is_self_emitter and (not in_conns or not in_conns[corr.source_pkey])) then
                src_alive = false
            end
        else
            src_alive = false
        end

        if not src_alive and corr.status ~= "receding" then
            corr.status = "receding"
            corr.retreat_tick = tick
            local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
            corr.end_decay_tick = tick + math.max(15, init_mag * 3)
        end

        if corr.status ~= "receding" and corr.corridor_entities then
            for u in pairs(corr.corridor_entities) do
                if is_gate_open(u) then
                    flow_engine.split_pressure_corridor(cid, corr, u)
                    break
                end
            end
        end

        if corr.status ~= "receding" and corr.last_out_pkey then
            local conns = storage.flow_connections and storage.flow_connections[corr.last_out_pkey]
            if conns then
                for n_key in pairs(conns) do
                    local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                    if n_node and storage.active_gates and storage.active_gates[n_node.unit_number] then
                        if not is_gate_open(n_node.unit_number) then
                            flow_engine.wake_corridor_tip(corr)
                            break
                        end
                    end
                end
            end
        end

        if corr.status == "growing" then
            local elapsed = math.max(0, tick - corr.start_tick)
            local current_reach = math.min(corr.total_dist, math.floor(elapsed / tpt) + 1)
            corr.current_reach = current_reach
            local cur_seg_target = math.max(1, math.ceil(current_reach / 16))

            if cur_seg_target > corr.registered_segs then
                local motion_tree = timed_motion.get_motion_tree(s_idx)
                local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
                local sp = corr.start_pos
                local dx = corr.dir.x
                local dy = corr.dir.y

                for s = corr.registered_segs + 1, cur_seg_target do
                    local s_start = (s - 1) * 16
                    local s_end = math.min(s * 16, corr.total_dist)
                    local seg_key = string.format("%d,%d:%d", dx, dy, s)
                    local seg_start_pos = { x = sp.x + dx * s_start, y = sp.y + dy * s_start }
                    local seg_end_pos = { x = sp.x + dx * s_end, y = sp.y + dy * s_end }

                    if motion_tree then
                        local leaf = motion_tree:insert_segment(cid, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
                        if leaf then
                            leaf.dir = { x = dx, y = dy }
                            leaf.q_level = corr.q_level or 0
                            leaf.has_trail = true
                            leaf.trail_count = math.max(0, math.floor(s_end - s_start + 0.5))
                            corr.leaves = corr.leaves or {}
                            corr.leaves[seg_key] = leaf
                            viewport_bvh.on_segment_registered(s_idx, leaf)
                        end
                    end
                    if traj_tree then
                        traj_tree:insert_segment(cid, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
                    end
                end
                corr.registered_segs = cur_seg_target
                if traj_tree then trajectory_bvh.refresh_active_renders() end
            end

            if current_reach >= corr.total_dist then
                corr.status = "active"
                corr.current_reach = corr.total_dist
                if corr.leaves then
                    for _, leaf in pairs(corr.leaves) do
                        viewport_bvh.on_leaf_static_changed(s_idx, leaf)
                    end
                end
                local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
                local tip_mag = math.max(0, init_mag - (corr.total_dist - 1))
                local rem_level = (tip_mag > 0) and ((corr.flow_level and corr.flow_level < 0) and -tip_mag or tip_mag) or 0
                if rem_level ~= 0 and corr.last_out_pkey then
                    storage.corridor_tip_flows = storage.corridor_tip_flows or {}
                    storage.corridor_tip_flows[corr.last_out_pkey] = rem_level
                    local out_node = storage.flow_nodes and storage.flow_nodes[corr.last_out_pkey]
                    if out_node then
                        flow_renderer.update_pos_render(out_node.pos_key)
                    end
                end
                if corr.terminal_branch_pkey and not corr.branch_enqueued then
                    corr.branch_enqueued = true
                    flow_engine.enqueue_port(corr.terminal_branch_pkey)
                    local tb_node = storage.flow_nodes and storage.flow_nodes[corr.terminal_branch_pkey]
                    if tb_node then
                        flow_common.enqueue_unit_ports(tb_node.unit_number)
                    end
                    flow_common.wake_port_parked(corr.terminal_branch_pkey)
                end
                if corr.last_out_pkey then
                    flow_common.wake_port_parked(corr.last_out_pkey)
                end
            end
        elseif corr.status == "receding" then
            local decay_duration = corr.end_decay_tick and (corr.end_decay_tick - corr.retreat_tick) or 30
            local elapsed = math.max(0, tick - (corr.retreat_tick or tick))
            local tau = math.min(1.0, elapsed / decay_duration)
            local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
            local p_head = math.ceil(init_mag * (1.0 - tau))
            local slope = 1.0 - tau
            local cur_tip_mag = (p_head <= 0) and 0 or math.max(0, math.ceil(p_head - (corr.total_dist - 1) * slope))

            if corr.last_out_pkey and storage.corridor_tip_flows then
                local target_tip = (cur_tip_mag > 0) and ((corr.flow_level < 0) and -cur_tip_mag or cur_tip_mag) or nil
                if storage.corridor_tip_flows[corr.last_out_pkey] ~= target_tip then
                    storage.corridor_tip_flows[corr.last_out_pkey] = target_tip
                    local out_node = storage.flow_nodes and storage.flow_nodes[corr.last_out_pkey]
                    if out_node then
                        flow_renderer.update_pos_render(out_node.pos_key)
                    end
                    if corr.terminal_branch_pkey then
                        flow_engine.enqueue_port(corr.terminal_branch_pkey)
                        flow_common.wake_port_parked(corr.terminal_branch_pkey)
                    end
                    flow_common.wake_port_parked(corr.last_out_pkey)
                end
            end

            if tick >= (corr.end_decay_tick or 0) then
                flow_engine.unseed_pressure_corridor(cid, true)
            end
        end
    end
end

function flow_engine.get_node_emitter_level(node)
    if not node or not node.emitter or node.emitter == 0 then return 0 end
    local unit_number = node.unit_number

    local pump_power = storage.pump_power_states and storage.pump_power_states[unit_number]
    if pump_power ~= nil then
        if not pump_power then return 0 end
        local pump_enabled = storage.pump_enabled_states and storage.pump_enabled_states[unit_number]
        if pump_enabled == false then return 0 end
        local q_level = node.q_level or 0
        local flow_mag = math.floor(10 * (1 + 0.3 * q_level))
        return (node.emitter > 0) and flow_mag or -flow_mag
    end

    if storage.active_pumps and storage.active_pumps[unit_number] then
        local pump_entity = storage.active_pumps[unit_number]
        if not (pump_entity and pump_entity.valid) then return 0 end
        local is_powered = (pump_entity.energy > 0)
        storage.pump_power_states = storage.pump_power_states or {}
        storage.pump_power_states[unit_number] = is_powered
        if not is_powered then return 0 end
        local is_enabled = pump_settings.is_pump_enabled(pump_entity)
        storage.pump_enabled_states = storage.pump_enabled_states or {}
        storage.pump_enabled_states[unit_number] = is_enabled
        if not is_enabled then return 0 end
        local q_level = (pump_entity.quality and pump_entity.quality.level) or (node and node.q_level) or 0
        local flow_mag = math.floor(10 * (1 + 0.3 * q_level))
        return (node.emitter > 0) and flow_mag or -flow_mag
    end

    local diverter_power = storage.diverter_power_states and storage.diverter_power_states[unit_number]
    if diverter_power ~= nil then
        if not diverter_power then return 0 end
        local port_idx = node.port_index
        local port_states = storage.diverter_port_states and storage.diverter_port_states[unit_number]
        if port_states and port_states[port_idx] == false then return 0 end
        local d_settings = storage.diverter_settings and storage.diverter_settings[unit_number]
        local p_setting = d_settings and d_settings.ports and d_settings.ports[port_idx]
        local q_level = node.q_level or 0
        local flow_mag = math.floor(10 * (1 + 0.3 * q_level))
        return (p_setting and p_setting.mode == "input") and -flow_mag or flow_mag
    end

    if storage.active_diverters and storage.active_diverters[unit_number] then
        local div_entity = storage.active_diverters[unit_number]
        if not (div_entity and div_entity.valid) then return 0 end
        local is_powered = (div_entity.energy > 0)
        storage.diverter_power_states = storage.diverter_power_states or {}
        storage.diverter_power_states[unit_number] = is_powered
        if not is_powered then return 0 end
        local port_idx = node.port_index
        local is_port_on = diverter_settings.is_port_enabled(div_entity, port_idx)
        storage.diverter_port_states = storage.diverter_port_states or {}
        storage.diverter_port_states[unit_number] = storage.diverter_port_states[unit_number] or {}
        storage.diverter_port_states[unit_number][port_idx] = is_port_on
        if not is_port_on then return 0 end
        local d_settings = storage.diverter_settings and storage.diverter_settings[unit_number]
        local p_setting = d_settings and d_settings.ports and d_settings.ports[port_idx]
        local q_level = (div_entity.quality and div_entity.quality.level) or (node and node.q_level) or 0
        local flow_mag = math.floor(10 * (1 + 0.3 * q_level))
        return (p_setting and p_setting.mode == "input") and -flow_mag or flow_mag
    end

    return node.emitter
end

function flow_engine.get_node_kinetic_emitter(node)
    return flow_kinetic.get_node_kinetic_emitter(node)
end

function flow_engine.get_kinetic_level(pkey)
    if not (pkey and storage.kinetic_levels) then return 0 end
    return storage.kinetic_levels[pkey] or 0
end

-- Aliased Renderer Primitives
local destroy_pos_renders = flow_renderer.destroy_pos_renders
local destroy_counter_renders = flow_renderer.destroy_counter_renders
local destroy_edge_render = flow_renderer.destroy_edge_render
local destroy_kinetic_pos_render = flow_renderer.destroy_kinetic_pos_render
local update_kinetic_pos_render = flow_renderer.update_kinetic_pos_render
local get_dominant_port_at_pos = flow_renderer.get_dominant_port_at_pos
local get_dominant_counter_at_pos = flow_renderer.get_dominant_counter_at_pos
local update_counter_pos_render = flow_renderer.update_counter_pos_render
local update_pos_render = flow_renderer.update_pos_render
local update_edge_render = flow_renderer.update_edge_render

-- Public Alt-Mode Visualization API Exports
flow_engine.clear_counter_renders = flow_renderer.clear_counter_renders
flow_engine.clear_flow_renders = flow_renderer.clear_flow_renders
flow_engine.clear_all_renders = flow_renderer.clear_all_renders
flow_engine.draw_all_counters = flow_renderer.draw_all_counters
flow_engine.draw_flow = flow_renderer.draw_flow
flow_engine.draw_all = flow_renderer.draw_all
flow_engine.update_character_renders = flow_renderer.update_character_renders
flow_engine.destroy_character_renders = flow_renderer.destroy_character_renders

flow_engine.check_tile_obstruction = flow_kinetic.check_tile_obstruction
flow_engine.notify_beam_obstruction_changed = flow_kinetic.handle_obstacle_changed

local function compute_port_counter_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0, nil end

    local unit_number = node.unit_number

    if storage.active_walls and storage.active_walls[unit_number] then
        local locked_group = storage.wall_locked_group and storage.wall_locked_group[unit_number]
        if locked_group and node.group ~= locked_group then
            return 0, nil
        end
    end

    if storage.active_counters and storage.active_counters[unit_number] then
        local counter_entity = storage.active_counters[unit_number]
        if not (counter_entity and counter_entity.valid) then
            return 0, nil
        end

        local is_powered = (counter_entity.energy > 0)
        local last_power = storage.counter_power_states[unit_number]
        if last_power ~= is_powered then
            storage.counter_power_states[unit_number] = is_powered
            flow_engine.enqueue_unit_ports(unit_number)
        end

        if not is_powered then
            return 0, nil
        end

        local q_level = (counter_entity.quality and counter_entity.quality.level) or (node and node.q_level) or 0
        local seed = math.floor(DEFAULT_RANGE_SEED * (1 + 0.3 * q_level))
        return seed, unit_number
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports then return 0, nil end

    local max_cand_level = 0
    local winning_owner = nil

    for _, check_pkey in pairs(unit_ports) do
        local check_node = storage.flow_nodes and storage.flow_nodes[check_pkey]
        if check_node then
            local is_self = (check_pkey == pkey)
            local can_transmit_internally = node.sense_transmit and check_node.sense_transmit and (node.group ~= nil) and (check_node.group == node.group)

            if is_self or can_transmit_internally then
                local neighbors = storage.flow_connections and storage.flow_connections[check_pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        local n_level = storage.counter_levels and storage.counter_levels[n_key] or 0
                        local n_owner = storage.counter_owners and storage.counter_owners[n_key]

                        if n_level > 1 and n_owner ~= nil and storage.active_counters and storage.active_counters[n_owner] and storage.counter_power_states[n_owner] ~= false then
                            local cand_level = n_level - 1
                            if cand_level > max_cand_level then
                                max_cand_level = cand_level
                                winning_owner = n_owner
                            elseif cand_level == max_cand_level and cand_level > 0 then
                                if winning_owner == nil or n_owner < winning_owner then
                                    winning_owner = n_owner
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if max_cand_level == 0 or winning_owner == nil then
        return 0, nil
    end

    return max_cand_level, winning_owner
end

local function set_port_counter_ownership(pkey, target_level, target_owner)
    local current_level = storage.counter_levels and storage.counter_levels[pkey] or 0
    local current_owner = storage.counter_owners and storage.counter_owners[pkey]

    if target_level == current_level and target_owner == current_owner then
        return false
    end

    if current_owner and storage.counter_owned_nodes and storage.counter_owned_nodes[current_owner] then
        storage.counter_owned_nodes[current_owner][pkey] = nil
    end

    if target_level > 0 and target_owner ~= nil then
        storage.counter_levels[pkey] = target_level
        storage.counter_owners[pkey] = target_owner
        storage.counter_owned_nodes[target_owner] = storage.counter_owned_nodes[target_owner] or {}
        storage.counter_owned_nodes[target_owner][pkey] = true
    else
        storage.counter_levels[pkey] = nil
        storage.counter_owners[pkey] = nil
    end

    counter_range.handle_port_owner_changed(pkey)

    return true
end

local function is_colinear_straight_internal(pkey_a, node_a, pkey_b, node_b)
    return flow_common.is_colinear_straight_internal(pkey_a, node_a, pkey_b, node_b)
end
flow_engine.is_colinear_straight_internal = flow_common.is_colinear_straight_internal

local function _legacy_is_colinear_straight_internal(pkey_a, node_a, pkey_b, node_b)
    if not (node_a and node_b) then return false end
    if node_a.unit_number ~= node_b.unit_number then return false end
    if not (node_a.group and node_b.group and node_a.group == node_b.group) then return false end
    if not (node_a.dir and node_b.dir and node_a.offset and node_b.offset) then return false end

    if (node_a.dir.x + node_b.dir.x ~= 0) or (node_a.dir.y + node_b.dir.y ~= 0) then
        return false
    end

    if node_a.dir.x == 0 then
        if math.abs(node_a.offset.x - node_b.offset.x) > 0.001 then return false end
    else
        if math.abs(node_a.offset.y - node_b.offset.y) > 0.001 then return false end
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node_a.unit_number]
    if unit_ports then
        for _, other_key in pairs(unit_ports) do
            if other_key ~= pkey_a and other_key ~= pkey_b then
                local other_node = storage.flow_nodes and storage.flow_nodes[other_key]
                if other_node and other_node.group == node_a.group then
                    local conns = storage.flow_connections and storage.flow_connections[other_key]
                    if conns and next(conns) ~= nil then
                        return false
                    end
                end
            end
        end
    end

    return true
end

local function compute_port_flow_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0 end

    if node.emitter and node.emitter ~= 0 then
        return flow_engine.get_node_emitter_level(node)
    end

    if USE_PRESSURE_CORRIDORS then
        if storage.corridor_tip_flows and storage.corridor_tip_flows[pkey] then
            return 0
        end
        if storage.pressure_corridors then
            for _, corr in pairs(storage.pressure_corridors) do
                if corr.status ~= "receding" and corr.corridor_entities and corr.in_pkey ~= pkey then
                    local ent_record = corr.corridor_entities[node.unit_number]
                    if ent_record then
                        local matches_group = (type(ent_record) == "table" and ent_record[node.group])
                            or (ent_record == node.group)
                            or (ent_record == true and (not corr.group or corr.group == node.group))
                        if matches_group then
                            return 0
                        end
                    end
                end
            end
        end
    end

    local unit_number = node.unit_number
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports then return 0 end

    local max_pos = 0
    local min_neg = 0

    for _, check_pkey in pairs(unit_ports) do
        local check_node = storage.flow_nodes and storage.flow_nodes[check_pkey]
        if check_node then
            local is_self = (check_pkey == pkey)
            local can_transmit_internally = node.pressure_transmit and check_node.pressure_transmit and (node.group ~= nil) and (check_node.group == node.group)
            if USE_PRESSURE_CORRIDORS and can_transmit_internally and not is_self then
                local pkey_conns = storage.flow_connections and storage.flow_connections[pkey]
                local has_external = pkey_conns and (next(pkey_conns) ~= nil)
                if (not has_external) or is_colinear_straight_internal(check_pkey, check_node, pkey, node) then
                    can_transmit_internally = false
                end
            end

            if is_self or can_transmit_internally then
                local neighbors = storage.flow_connections and storage.flow_connections[check_pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        local n_level = (storage.corridor_tip_flows and storage.corridor_tip_flows[n_key]) or (storage.flow_levels and storage.flow_levels[n_key]) or 0
                        if n_level > 1 then
                            local incoming = n_level - 1
                            if incoming > max_pos then
                                max_pos = incoming
                            end
                        elseif n_level < -1 then
                            local incoming = n_level + 1
                            if incoming < min_neg then
                                min_neg = incoming
                            end
                        end
                    end
                end
            end
        end
    end

    local pos_mag = max_pos
    local neg_mag = math.abs(min_neg)

    if pos_mag > neg_mag then
        return max_pos
    elseif neg_mag > pos_mag then
        return min_neg
    else
        return 0
    end
end

local function discover_adjacent_standard_entity(node)
    flow_gate_interop.discover_adjacent_standard_entity(node, flow_engine.connect_entity)
end

function flow_engine.handle_interop_research_finished(force)
    flow_gate_interop.handle_interop_research_finished(force)
end

function flow_engine.handle_interop_research_reversed(force)
    flow_gate_interop.handle_interop_research_reversed(force, flow_engine.enqueue_port, flow_renderer.destroy_edge_render)
end

function flow_engine.step(tick)
    if not storage.kinetic_ore_obstruction_fixed then
        storage.kinetic_ore_obstruction_fixed = true
        if storage.flow_nodes then
            for pkey, node in pairs(storage.flow_nodes) do
                if node and node.is_kinetic and node.is_endpoint then
                    flow_engine.enqueue_port(pkey)
                end
            end
        end
    end
    if not storage.kinetic_rail_cliff_fixed then
        storage.kinetic_rail_cliff_fixed = true
        if storage.flow_nodes then
            for pkey, node in pairs(storage.flow_nodes) do
                if node and node.is_kinetic and node.is_endpoint then
                    flow_engine.enqueue_port(pkey)
                end
            end
        end
    end
    if not storage.projector_ports_initialized then
        storage.projector_ports_initialized = true
        if storage.active_projectors then
            for unit_number in pairs(storage.active_projectors) do
                flow_engine.enqueue_unit_ports(unit_number)
            end
        end
    end
    if not storage.flow_quality_scaling_initialized then
        storage.flow_quality_scaling_initialized = true
        if storage.active_pumps then
            for unit_number in pairs(storage.active_pumps) do
                flow_engine.enqueue_unit_ports(unit_number)
            end
        end
        if storage.active_diverters then
            for unit_number in pairs(storage.active_diverters) do
                flow_engine.enqueue_unit_ports(unit_number)
            end
        end
        if storage.active_counters then
            for unit_number in pairs(storage.active_counters) do
                flow_engine.enqueue_unit_ports(unit_number)
            end
        end
    end

    flow_gate_interop.step_gates(flow_kinetic.handle_obstacle_changed, flow_engine.enqueue_unit_ports)
    flow_gate_interop.step_interop_queue(flow_engine.connect_entity)
    flow_kinetic.step_character_colliders(flow_engine.enqueue_port, flow_common.wake_port_parked)
    flow_kinetic.step_reticle_obstacles()
    viewport_bvh.update_all_players()
    flow_engine.step_pressure_corridors(tick)

    if not storage.flow_queue or next(storage.flow_queue) == nil then return end

    local batch = {}
    local batch_count = 0
    local batch_limit = BATCH_SIZE
    if next(storage.flow_queue) ~= nil then
        local q_count = 0
        for _ in pairs(storage.flow_queue) do
            q_count = q_count + 1
            if q_count > 500 then
                batch_limit = 200
                break
            end
        end
    end

    for pkey in pairs(storage.flow_queue) do
        batch_count = batch_count + 1
        batch[batch_count] = pkey
        storage.flow_queue[pkey] = nil
        if batch_count >= batch_limit then
            break
        end
    end

    for i = 1, batch_count do
        local pkey = batch[i]
        local node = storage.flow_nodes and storage.flow_nodes[pkey]

        local flow_changed = false
        local range_changed = false
        local kinetic_changed = false
        local target_flow = 0

        if node and node.is_kinetic then
            kinetic_changed = flow_kinetic.step_port(node, pkey, flow_engine.enqueue_port, wake_port_parked)
        else
            -- 1. Pressure Flow Wavefront
            target_flow = compute_port_flow_level(pkey)
            local current_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
            flow_changed = (target_flow ~= current_flow)

        if flow_changed then
            if target_flow ~= 0 then
                storage.flow_levels[pkey] = target_flow
            else
                storage.flow_levels[pkey] = nil
            end

            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node then
                update_pos_render(node.pos_key)
            end
        end

            -- 2. Capsule Counter Range Wavefront
            local target_range, target_owner = compute_port_counter_level(pkey)
            range_changed = set_port_counter_ownership(pkey, target_range, target_owner)

        if range_changed then
            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node then
                update_counter_pos_render(node.pos_key)
            end
        end

        if node then
            flow_gate_interop.update_wall_locking(node, pkey, target_flow, target_range, flow_engine.enqueue_port)
            flow_gate_interop.check_wall_gate_demotion(node, pkey, target_flow, target_range, flow_engine.disconnect_entity)
        end
        end

        if flow_changed or range_changed or kinetic_changed then
            if node then
                local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
                if unit_ports and node.group then
                    for _, int_key in pairs(unit_ports) do
                        if int_key ~= pkey then
                            local int_node = storage.flow_nodes and storage.flow_nodes[int_key]
                            if int_node and int_node.group == node.group then
                                local allow_flow = flow_changed and node.pressure_transmit and int_node.pressure_transmit
                                if allow_flow and USE_PRESSURE_CORRIDORS then
                                    local int_conns = storage.flow_connections and storage.flow_connections[int_key]
                                    local has_external = int_conns and (next(int_conns) ~= nil)
                                    local is_straight = is_colinear_straight_internal(pkey, node, int_key, int_node)
                                    if (not has_external) or is_straight then
                                        allow_flow = false
                                    end
                                    if is_straight then
                                        local in_conns = storage.flow_connections and storage.flow_connections[pkey]
                                        local has_in = (in_conns and next(in_conns) ~= nil) or (node.emitter and node.emitter ~= 0)
                                        local curr_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
                                        if has_in and curr_flow ~= 0 then
                                            flow_engine.on_pressure_begin_transmit(pkey, node, int_key, int_node, curr_flow)
                                        else
                                            flow_engine.on_pressure_stop_transmit(pkey, node, int_key, int_node)
                                        end
                                    end
                                end
                                if allow_flow
                                   or (range_changed and node.sense_transmit and int_node.sense_transmit)
                                   or (kinetic_changed and (node.kinetic_transmit or node.cross_transit) and (int_node.kinetic_transmit or int_node.cross_transit)) then
                                    flow_engine.enqueue_port(int_key)
                                    wake_port_parked(int_key)
                                end
                            end
                        end
                    end
                end
            end

            local neighbors = storage.flow_connections and storage.flow_connections[pkey]
            if neighbors and next(neighbors) ~= nil then
                for n_key in pairs(neighbors) do
                    flow_engine.enqueue_port(n_key)
                    if flow_changed then
                        update_edge_render(pkey, n_key)
                    end
                    wake_port_parked(n_key)
                end
            else
                local eff_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
                local eff_sense = storage.counter_levels and storage.counter_levels[pkey] or 0
                if eff_flow ~= 0 or eff_sense > 0 then
                    discover_adjacent_standard_entity(node)
                end
            end

            wake_port_parked(pkey)
        end

        if USE_PRESSURE_CORRIDORS and (not flow_changed) and node and node.pressure_transmit then
            local curr_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
            if curr_flow ~= 0 then
                local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
                if unit_ports and node.group then
                    local in_conns = storage.flow_connections and storage.flow_connections[pkey]
                    local has_in = (in_conns and next(in_conns) ~= nil) or (node.emitter and node.emitter ~= 0)
                    if has_in then
                        for _, int_key in pairs(unit_ports) do
                            if int_key ~= pkey then
                                local int_node = storage.flow_nodes and storage.flow_nodes[int_key]
                                if int_node and int_node.group == node.group and int_node.pressure_transmit then
                                    if is_colinear_straight_internal(pkey, node, int_key, int_node) then
                                        local cid = "corridor:" .. pkey .. "->" .. int_key
                                        local existing = storage.pressure_corridors and storage.pressure_corridors[cid]
                                        if (not existing) or existing.status == "receding" then
                                            local int_conns = storage.flow_connections and storage.flow_connections[int_key]
                                            local has_ext = int_conns and (next(int_conns) ~= nil)
                                            if has_ext then
                                                flow_engine.on_pressure_begin_transmit(pkey, node, int_key, int_node, curr_flow)
                                                update_pos_render(node.pos_key)
                                            end
                                        elseif existing and existing.status == "active" then
                                            flow_engine.wake_corridor_tip(existing)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function handle_entity_reorientation(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if entity.name == "entity-ghost" then return end

    local real_name = entity.name

    if real_name == "pneumatic-projector" then
        local u_num = entity.unit_number
        local dev_id = projector_settings.get_device_id(entity)
        if dev_id then
            projector_settings.set_muzzle_direction(dev_id, entity.direction)
        end

        flow_kinetic.clear_receiver_references(u_num, flow_engine.enqueue_port, wake_port_parked)

        if storage.flow_unit_ports and storage.flow_unit_ports[u_num] then
            flow_engine.disconnect_entity(entity)
        end

        flow_engine.connect_entity(entity)
        flow_kinetic.handle_obstacle_changed(entity, false, flow_engine.enqueue_port, wake_port_parked)
    elseif registered_entities[real_name] then
        flow_kinetic.handle_obstacle_changed(entity, true, flow_engine.enqueue_port, wake_port_parked)
        if storage.flow_unit_ports and storage.flow_unit_ports[entity.unit_number] then
            flow_engine.disconnect_entity(entity)
        end
        flow_engine.connect_entity(entity)
        flow_kinetic.handle_obstacle_changed(entity, false, flow_engine.enqueue_port, wake_port_parked)
    elseif is_standard_entity(real_name) then
        flow_gate_interop.handle_standard_entity_reorientation(entity, flow_engine.disconnect_entity, flow_engine.connect_entity, flow_kinetic.handle_obstacle_changed, flow_engine.get_node_emitter_level, flow_kinetic.get_node_kinetic_emitter)
    end
end

function flow_engine.wake_corridor_tip(corr)
    if not (corr and corr.status ~= "receding") then return false end
    local tip_pkey = corr.last_out_pkey
    if not tip_pkey then return false end

    local dx = corr.dir.x
    local dy = corr.dir.y
    local max_reach = math.max(1, math.abs(corr.initial_flow or corr.flow_level or 10))
    local curr_out = tip_pkey
    local added_dist = 0
    local terminal_branch = nil

    while corr.total_dist + added_dist < max_reach do
        local conns = storage.flow_connections and storage.flow_connections[curr_out]
        if not conns or next(conns) == nil then break end

        local n_in_key = nil
        for nk in pairs(conns) do
            n_in_key = nk
            break
        end

        local n_in_node = storage.flow_nodes and storage.flow_nodes[n_in_key]
        if not n_in_node then break end

        local u = n_in_node.unit_number
        local u_grp = n_in_node.group or 1
        if not u then break end
        if corr.corridor_entities[u] and ((type(corr.corridor_entities[u]) == "table" and corr.corridor_entities[u][u_grp]) or corr.corridor_entities[u] == true) then break end
        if is_gate_open(u) then break end

        local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u]
        if not u_ports then break end

        local found_exit = nil
        local found_exit_node = nil
        for _, ok in ipairs(u_ports) do
            if ok ~= n_in_key then
                local on = storage.flow_nodes and storage.flow_nodes[ok]
                if on and on.group == n_in_node.group then
                    if flow_common.is_colinear_straight_internal(n_in_key, n_in_node, ok, on) then
                        if on.dir and on.dir.x == dx and on.dir.y == dy then
                            found_exit = ok
                            found_exit_node = on
                            break
                        end
                    end
                end
            end
        end

        if not (found_exit and found_exit_node) then
            terminal_branch = n_in_key
            break
        end

        local seg_len = math.floor(math.abs(found_exit_node.pos.x - n_in_node.pos.x) + math.abs(found_exit_node.pos.y - n_in_node.pos.y) + 0.5)
        if seg_len <= 0 then seg_len = 1 end
        added_dist = added_dist + seg_len
        if type(corr.corridor_entities[u]) ~= "table" then
            corr.corridor_entities[u] = { [u_grp] = true }
        else
            corr.corridor_entities[u][u_grp] = true
        end
        curr_out = found_exit
    end

    if added_dist > 0 then
        local old_total_dist = corr.total_dist
        local old_last_out = corr.last_out_pkey
        local s_idx = corr.surface_index or 1

        if old_last_out and old_last_out ~= curr_out then
            if storage.corridor_tip_flows and storage.corridor_tip_flows[old_last_out] then
                storage.corridor_tip_flows[old_last_out] = nil
                local old_node = storage.flow_nodes and storage.flow_nodes[old_last_out]
                if old_node then flow_renderer.update_pos_render(old_node.pos_key) end
            end
            flow_common.wake_port_parked(old_last_out)
        end

        corr.total_dist = corr.total_dist + added_dist
        corr.terminal_pos = { x = corr.start_pos.x + dx * corr.total_dist, y = corr.start_pos.y + dy * corr.total_dist }
        corr.last_out_pkey = curr_out
        corr.terminal_branch_pkey = terminal_branch
        corr.branch_enqueued = nil
        corr.max_seg_idx = math.max(1, math.ceil(corr.total_dist / 16))

        local s_curr = corr.registered_segs or 1
        local s_start = (s_curr - 1) * 16
        local s_end = math.min(s_curr * 16, corr.total_dist)
        local seg_key = string.format("%d,%d:%d", dx, dy, s_curr)
        local motion_tree = timed_motion.get_motion_tree(s_idx)
        local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
        if motion_tree then motion_tree:remove_segment(corr.id, seg_key) end
        viewport_bvh.on_segment_removed(s_idx, corr.id, seg_key)
        if traj_tree then traj_tree:remove_segment(corr.id, seg_key) end

        local seg_start_pos = { x = corr.start_pos.x + dx * s_start, y = corr.start_pos.y + dy * s_start }
        local seg_end_pos = { x = corr.start_pos.x + dx * s_end, y = corr.start_pos.y + dy * s_end }
        if motion_tree then
            local leaf = motion_tree:insert_segment(corr.id, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s_curr)
            if leaf then
                leaf.dir = { x = dx, y = dy }
                leaf.q_level = corr.q_level or 0
                leaf.has_trail = true
                leaf.trail_count = math.max(0, math.floor(s_end - s_start + 0.5))
                corr.leaves = corr.leaves or {}
                corr.leaves[seg_key] = leaf
                viewport_bvh.on_segment_registered(s_idx, leaf)
            end
        end
        if traj_tree then
            traj_tree:insert_segment(corr.id, seg_key, seg_start_pos, seg_end_pos, s_start, s_end, s_curr)
            trajectory_bvh.refresh_active_renders()
        end

        corr.status = "growing"
        local tpt = corr.ticks_per_tile or 2
        corr.start_tick = game.tick - math.max(0, (corr.current_reach - 1) * tpt)

        for u in pairs(corr.corridor_entities) do
            flow_common.enqueue_unit_ports(u)
        end
        flow_common.wake_port_parked(curr_out)
        if terminal_branch then
            flow_engine.enqueue_port(terminal_branch)
            local tb_node = storage.flow_nodes and storage.flow_nodes[terminal_branch]
            if tb_node then
                flow_common.enqueue_unit_ports(tb_node.unit_number)
            end
            flow_common.wake_port_parked(terminal_branch)
        end
        return true
    elseif terminal_branch and terminal_branch ~= corr.terminal_branch_pkey then
        corr.terminal_branch_pkey = terminal_branch
        local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
        local tip_mag = math.max(0, init_mag - (corr.total_dist - 1))
        local rem_level = (tip_mag > 0) and ((corr.flow_level and corr.flow_level < 0) and -tip_mag or tip_mag) or 0
        if corr.status == "active" then
            corr.branch_enqueued = true
            if rem_level ~= 0 and corr.last_out_pkey then
                storage.corridor_tip_flows = storage.corridor_tip_flows or {}
                storage.corridor_tip_flows[corr.last_out_pkey] = rem_level
                local out_node = storage.flow_nodes and storage.flow_nodes[corr.last_out_pkey]
                if out_node then flow_renderer.update_pos_render(out_node.pos_key) end
            end
            flow_engine.enqueue_port(terminal_branch)
            local tb_node = storage.flow_nodes and storage.flow_nodes[terminal_branch]
            if tb_node then
                flow_common.enqueue_unit_ports(tb_node.unit_number)
            end
            flow_common.wake_port_parked(terminal_branch)
            flow_common.wake_port_parked(corr.last_out_pkey)
        end
        return true
    end
    return false
end

function flow_engine.connect_entity(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if entity.name == "entity-ghost" then return end
    local real_name = entity.name
    if not (registered_entities[real_name] or is_standard_entity(real_name)) then return end

    local unit_number = entity.unit_number

    if storage.flow_unit_ports and storage.flow_unit_ports[unit_number] and next(storage.flow_unit_ports[unit_number]) ~= nil then
        flow_engine.disconnect_entity(entity)
    end

    if storage.soft_interop_registry then
        storage.soft_interop_registry[unit_number] = nil
    end
    if storage.interop_activation_queue then
        storage.interop_activation_queue[unit_number] = nil
    end

    if script.register_on_object_destroyed then
        local reg_id = script.register_on_object_destroyed(entity)
        storage.object_destruction_map = storage.object_destruction_map or {}
        storage.object_destruction_map[reg_id] = { type = "entity", unit_number = unit_number }
    end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local surface_name = entity.surface.name
    local ex, ey = entity.position.x, entity.position.y

    if real_name == "stone-wall" then
        storage.active_walls = storage.active_walls or {}
        storage.active_walls[unit_number] = entity
    elseif entity.name == "gate" then
        storage.active_gates = storage.active_gates or {}
        storage.active_gates[unit_number] = entity
    elseif entity.name == "pneumatic-capsule-counter" then
        storage.active_counters = storage.active_counters or {}
        storage.active_counters[unit_number] = entity
        storage.counter_power_states = storage.counter_power_states or {}
        storage.counter_power_states[unit_number] = (entity.energy > 0)
    elseif real_name == "pneumatic-projector" then
        storage.active_projectors = storage.active_projectors or {}
        storage.active_projectors[unit_number] = entity
    end

    storage.flow_unit_ports[unit_number] = storage.flow_unit_ports[unit_number] or {}

    local q_level = (entity.quality and entity.quality.level) or 0
    local ports_data = {}

    for port_index, port in ipairs(ports) do
        local px, py = ex + port.offset.x, ey + port.offset.y
        local pkey = make_port_key(unit_number, port_index)
        local pos_key = make_pos_key(surface_name, px, py)

        storage.flow_unit_ports[unit_number][port_index] = pkey

        local is_muzzle_port = (port.kinetic_transmit == true or port.is_muzzle == true)
        local eff_emitter = nil
        if port.flow and port.flow ~= 0 then
            local flow_mag = math.floor(math.abs(port.flow) * (1 + 0.3 * q_level))
            eff_emitter = (port.flow > 0) and flow_mag or -flow_mag
        end
        local eff_sense = port.sense and math.floor(port.sense * (1 + 0.3 * q_level)) or nil

        storage.flow_nodes[pkey] = {
            unit_number = unit_number,
            beam_owner = is_muzzle_port and unit_number or nil,
            port_index = port_index,
            pos_key = pos_key,
            pos = {x = px, y = py},
            offset = {x = port.offset.x, y = port.offset.y},
            dir = port.dir and {x = port.dir.x, y = port.dir.y} or nil,
            surface_name = surface_name,
            emitter = eff_emitter,
            sense = eff_sense,
            group = port.group,
            capsule_transmit = (port.capsule_transmit == true),
            pressure_transmit = (port.pressure_transmit == true),
            sense_transmit = (port.sense_transmit == true),
            kinetic_transmit = is_muzzle_port,
            is_muzzle = is_muzzle_port,
            is_kinetic = is_muzzle_port,
            dist = is_muzzle_port and 0 or nil,
            q_level = q_level,
            cross_transit = (port.cross_transit == true)
        }

        ports_data[port_index] = {
            pkey = pkey,
            pos_key = pos_key,
            is_muzzle_port = is_muzzle_port,
            eff_emitter = eff_emitter,
            eff_sense = eff_sense
        }
    end

    for port_index = 1, #ports_data do
        local pd = ports_data[port_index]
        storage.flow_grid[pd.pos_key] = storage.flow_grid[pd.pos_key] or {}
        storage.flow_grid[pd.pos_key][pd.pkey] = true
    end

    local touched_corridors = {}
    local connected_units = {}
    for port_index = 1, #ports_data do
        local pd = ports_data[port_index]
        local pkey = pd.pkey
        local pos_key = pd.pos_key
        local is_muzzle_port = pd.is_muzzle_port
        local eff_emitter = pd.eff_emitter
        local eff_sense = pd.eff_sense

        for existing_pkey in pairs(storage.flow_grid[pos_key]) do
            local existing_node = storage.flow_nodes[existing_pkey]
            if existing_node and existing_node.unit_number ~= unit_number then
                local compatible = not (is_muzzle_port or existing_node.kinetic_transmit)
                if compatible then
                    storage.flow_connections[pkey] = storage.flow_connections[pkey] or {}
                    storage.flow_connections[existing_pkey] = storage.flow_connections[existing_pkey] or {}

                    storage.flow_connections[pkey][existing_pkey] = true
                    storage.flow_connections[existing_pkey][pkey] = true
                    connected_units[existing_node.unit_number] = true
                    connected_units[unit_number] = true

                    local existing_has_flow = (storage.flow_levels and (storage.flow_levels[existing_pkey] or 0) ~= 0)
                        or (storage.counter_levels and (storage.counter_levels[existing_pkey] or 0) > 0)
                        or (existing_node.emitter and existing_node.emitter ~= 0)
                        or (existing_node.sense and existing_node.sense > 0)
                    local has_flow = (eff_emitter ~= nil and eff_emitter ~= 0) or (eff_sense ~= nil and eff_sense > 0)

                    if has_flow or existing_has_flow or USE_PRESSURE_CORRIDORS then
                        flow_engine.enqueue_port(existing_pkey)
                        flow_engine.enqueue_port(pkey)
                        if USE_PRESSURE_CORRIDORS then
                            flow_common.enqueue_unit_ports(existing_node.unit_number)
                            flow_common.enqueue_unit_ports(unit_number)
                            if storage.pressure_corridors then
                                for _, corr in pairs(storage.pressure_corridors) do
                                    if corr.status ~= "receding" and (corr.last_out_pkey == existing_pkey or corr.last_out_pkey == pkey) then
                                        touched_corridors[corr.id] = corr
                                    end
                                end
                            end
                        end
                        wake_port_parked(existing_pkey)
                        wake_port_parked(pkey)
                    end
                end
            end
        end

        if (eff_emitter ~= nil and eff_emitter ~= 0) or (eff_sense ~= nil and eff_sense > 0) then
            flow_engine.enqueue_port(pkey)
            wake_port_parked(pkey)
        end
        discover_adjacent_standard_entity(storage.flow_nodes[pkey])
        update_pos_render(pos_key)
        update_counter_pos_render(pos_key)
    end

    if USE_PRESSURE_CORRIDORS then
        local corridors_to_split = {}
        if storage.pressure_corridors and next(connected_units) ~= nil then
            for cid, corr in pairs(storage.pressure_corridors) do
                if corr.status ~= "receding" and corr.corridor_entities then
                    local dx = corr.dir.x
                    local dy = corr.dir.y
                    local corr_grp = corr.group or 1
                    for u in pairs(connected_units) do
                        local grp_data = corr.corridor_entities[u]
                        if grp_data then
                            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u]
                            local in_pk, out_pk = nil, nil
                            local in_nd, out_nd = nil, nil
                            if u_ports then
                                for _, pk in ipairs(u_ports) do
                                    local nd = storage.flow_nodes and storage.flow_nodes[pk]
                                    if nd and (nd.group == corr_grp or (type(grp_data) == "table" and grp_data[nd.group])) and nd.dir then
                                        if nd.dir.x == -dx and nd.dir.y == -dy then
                                            in_pk = pk
                                            in_nd = nd
                                        elseif nd.dir.x == dx and nd.dir.y == dy then
                                            out_pk = pk
                                            out_nd = nd
                                        end
                                    end
                                end
                            end

                            if in_pk and out_pk then
                                if not flow_common.is_colinear_straight_internal(in_pk, in_nd, out_pk, out_nd) then
                                    local u_pos = in_nd.pos
                                    local dist = (u_pos.x - corr.start_pos.x) * dx + (u_pos.y - corr.start_pos.y) * dy
                                    if not corridors_to_split[cid] or dist < corridors_to_split[cid].dist then
                                        corridors_to_split[cid] = { corr = corr, unit = u, dist = dist, pos = u_pos }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        for cid, data in pairs(corridors_to_split) do
            flow_engine.split_pressure_corridor(cid, data.corr, data.unit, data.pos, true)
        end

        for _, corr in pairs(touched_corridors) do
            if not corridors_to_split[corr.id] then
                flow_engine.wake_corridor_tip(corr)
            end
        end
    end
end

function flow_engine.disconnect_entity(entity)
    if not (entity and entity.unit_number) then return end
    local unit_number = entity.unit_number

    if storage.active_projectors then storage.active_projectors[unit_number] = nil end
    if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end
    if storage.projector_ready_states then storage.projector_ready_states[unit_number] = nil end
    if storage.projector_last_fired then storage.projector_last_fired[unit_number] = nil end

    if storage.soft_interop_registry then
        storage.soft_interop_registry[unit_number] = nil
    end
    if storage.interop_activation_queue then
        storage.interop_activation_queue[unit_number] = nil
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports then return end

    local ent_pos = entity.position
    if not ent_pos and unit_ports then
        local sum_x, sum_y, cnt = 0, 0, 0
        for _, pk in pairs(unit_ports) do
            local nd = storage.flow_nodes and storage.flow_nodes[pk]
            if nd and nd.pos then
                sum_x = sum_x + nd.pos.x
                sum_y = sum_y + nd.pos.y
                cnt = cnt + 1
            end
        end
        if cnt > 0 then
            ent_pos = { x = sum_x / cnt, y = sum_y / cnt }
        end
    end

    if storage.pressure_corridors then
        local to_split = {}
        local to_recede = {}
        for cid, corr in pairs(storage.pressure_corridors) do
            local touches_entity = (corr.corridor_entities and corr.corridor_entities[unit_number])
            local touches_source = (corr.source_unit == unit_number) or (corr.unit_number == unit_number and not touches_entity)
            if touches_entity then
                if corr.status ~= "receding" then
                    to_split[cid] = corr
                end
            elseif touches_source then
                if corr.status ~= "receding" then
                    to_recede[cid] = corr
                end
            end
        end

        for cid, corr in pairs(to_recede) do
            corr.status = "receding"
            corr.retreat_tick = game.tick
            local init_mag = math.abs(corr.initial_flow or corr.flow_level or 10)
            corr.end_decay_tick = game.tick + math.max(15, init_mag * 3)
        end

        for cid, corr in pairs(to_split) do
            flow_engine.split_pressure_corridor(cid, corr, unit_number, ent_pos)
        end
    end

    for port_index, pkey in pairs(unit_ports) do
        local node = storage.flow_nodes and storage.flow_nodes[pkey]
        local pos_key = node and node.pos_key

        if storage.pressure_corridors then
            for cid, corr in pairs(storage.pressure_corridors) do
                if corr.terminal_branch_pkey == pkey then
                    corr.terminal_branch_pkey = nil
                    corr.branch_enqueued = nil
                    flow_common.wake_port_parked(corr.last_out_pkey)
                end
            end
        end

        flow_common.destroy_node(pkey)

        if pos_key then
            update_pos_render(pos_key)
            update_counter_pos_render(pos_key)
        end
        destroy_kinetic_pos_render(pkey)
    end

    if storage.flow_unit_ports then
        storage.flow_unit_ports[unit_number] = nil
    end

    if storage.active_walls then storage.active_walls[unit_number] = nil end
    if storage.active_gates then storage.active_gates[unit_number] = nil end
    if storage.gate_open_states then storage.gate_open_states[unit_number] = nil end
    if storage.gate_cutoff_states then storage.gate_cutoff_states[unit_number] = nil end
    if storage.wall_locked_group then storage.wall_locked_group[unit_number] = nil end
    if storage.active_counters then storage.active_counters[unit_number] = nil end
    if storage.counter_power_states then storage.counter_power_states[unit_number] = nil end
end

function flow_engine.handle_capsule_destroyed(capsule_id)
    if not capsule_id then return end

    local cap = storage.capsules and storage.capsules[capsule_id]
    local target_key = cap and cap.from_port_key

    if storage.parked_by_port and cap then
        if cap.parked_at_port then
            local bucket = storage.parked_by_port[cap.parked_at_port]
            if bucket then
                bucket[capsule_id] = nil
                if next(bucket) == nil then
                    storage.parked_by_port[cap.parked_at_port] = nil
                end
            end
        end
    end

    if cap and cap.passenger and cap.passenger.valid then
        local player = cap.passenger
        local surface = player.surface
        local pos = player.position
        local safe_pos = surface and surface.find_non_colliding_position("character", pos, 4, 0.5) or pos
        if safe_pos and surface then
            player.teleport(safe_pos, surface)
        end
    end

    capsule_queries.remove_capsule(capsule_id)
    capsule_manager.remove(capsule_id)

    if target_key then
        wake_port_parked(target_key)
    end
end

function flow_engine.handle_object_destroyed(unit_number)
    if not unit_number then return end

    local is_tracked = (storage.flow_unit_ports and storage.flow_unit_ports[unit_number] ~= nil)
        or (storage.active_projectors and storage.active_projectors[unit_number] ~= nil)
        or (storage.active_hubs and storage.active_hubs[unit_number] ~= nil)
        or (storage.hub_compartments and storage.hub_compartments[unit_number] ~= nil)
    if not is_tracked then return end

    if storage.active_projectors and storage.active_projectors[unit_number] then
        flow_kinetic.clear_receiver_references(unit_number, flow_engine.enqueue_port, wake_port_parked)
        flow_kinetic.handle_projector_destroyed(unit_number)
    end

    if storage.soft_interop_registry then
        storage.soft_interop_registry[unit_number] = nil
    end
    if storage.interop_activation_queue then
        storage.interop_activation_queue[unit_number] = nil
    end

    if storage.hub_compartments and storage.hub_compartments[unit_number] then
        local compartment = storage.hub_compartments[unit_number]
        for _, capsule_id in ipairs(compartment) do
            capsule_queries.remove_capsule(capsule_id)
            capsule_manager.remove(capsule_id)
        end
        storage.hub_compartments[unit_number] = nil
    end

    local runner_ids = capsule_queries.find_capsules_at_entity(unit_number)
    for _, id in ipairs(runner_ids) do
        local cap = storage.capsules and storage.capsules[id]
        if not (cap and (cap.in_timed_flight or cap.beam_flight)) then
            local capsule_id = cap and (cap.capsule_id or cap.id) or id

            if storage.parked_by_port and cap then
            if cap.parked_at_port then
                local bucket = storage.parked_by_port[cap.parked_at_port]
                if bucket then
                    bucket[capsule_id] = nil
                    if next(bucket) == nil then
                        storage.parked_by_port[cap.parked_at_port] = nil
                    end
                end
            end
        end

            capsule_queries.remove_capsule(capsule_id)
            capsule_manager.remove(capsule_id)
        end
    end

    flow_engine.enqueue_unit_ports(unit_number)
    flow_engine.disconnect_entity({ unit_number = unit_number })

    if storage.active_hubs then storage.active_hubs[unit_number] = nil end
    if storage.hub_settings then storage.hub_settings[unit_number] = nil end
    if storage.hub_receive_locks then storage.hub_receive_locks[unit_number] = nil end
    if storage.active_pumps then storage.active_pumps[unit_number] = nil end
    if storage.pump_power_states then storage.pump_power_states[unit_number] = nil end
    if storage.pump_enabled_states then storage.pump_enabled_states[unit_number] = nil end
    if storage.pump_settings then storage.pump_settings[unit_number] = nil end
    if storage.active_diverters then storage.active_diverters[unit_number] = nil end
    if storage.diverter_power_states then storage.diverter_power_states[unit_number] = nil end
    if storage.diverter_port_states then storage.diverter_port_states[unit_number] = nil end
    if storage.diverter_settings then storage.diverter_settings[unit_number] = nil end
    if storage.active_counters then storage.active_counters[unit_number] = nil end
    if storage.counter_power_states then storage.counter_power_states[unit_number] = nil end
    if storage.counter_capsules and storage.counter_capsules[unit_number] then
        for cap_id in pairs(storage.counter_capsules[unit_number]) do
            local cap = storage.capsules and storage.capsules[cap_id]
            if cap and cap.counter_owner == unit_number then
                cap.counter_owner = nil
            end
        end
        storage.counter_capsules[unit_number] = nil
    end
    if storage.spilled_containers then storage.spilled_containers[unit_number] = nil end
    if storage.active_walls then storage.active_walls[unit_number] = nil end
    if storage.active_gates then storage.active_gates[unit_number] = nil end
    if storage.gate_open_states then storage.gate_open_states[unit_number] = nil end
    if storage.gate_cutoff_states then storage.gate_cutoff_states[unit_number] = nil end
    if storage.wall_locked_group then storage.wall_locked_group[unit_number] = nil end
    if storage.active_projectors then storage.active_projectors[unit_number] = nil end
    if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end
    if storage.projector_ready_states then storage.projector_ready_states[unit_number] = nil end
    if storage.projector_last_fired then storage.projector_last_fired[unit_number] = nil end
end

function flow_engine.register_events()
    local function print_queue_status()
        local q_len = storage.flow_queue and table_size(storage.flow_queue) or 0
        local node_len = storage.flow_nodes and table_size(storage.flow_nodes) or 0
        local flow_len = storage.flow_levels and table_size(storage.flow_levels) or 0
        local sense_len = storage.counter_levels and table_size(storage.counter_levels) or 0
        local kinetic_len = storage.kinetic_levels and table_size(storage.kinetic_levels) or 0
        game.print(string.format("[Flow Queue] Pending in queue: %d | Total graph nodes: %d | Pressure active: %d | Sensing active: %d | Kinetic active: %d", q_len, node_len, flow_len, sense_len, kinetic_len))
    end

    commands.add_command("check-queue", "Display pneumatic flow engine queue and active node counts", print_queue_status)
    commands.add_command("check-flow", "Display pneumatic flow engine queue and active node counts", print_queue_status)
    commands.add_command("clear-queue", "Flush pneumatic flow queue to 0", function()
        storage.flow_queue = {}
        game.print("[Flow Queue] Flow queue flushed to 0!")
    end)

    events.on_event(defines.events.on_tick, function(event)
        flow_engine.step(event.tick)
    end)

    events.on_event(defines.events.on_research_finished, function(event)
        local research = event.research
        if research and research.valid and research.name == "pneumatic-fence-gate-interoperability" then
            flow_engine.handle_interop_research_finished(research.force)
        end
    end)

    events.on_event(defines.events.on_research_reversed, function(event)
        local research = event.research
        if research and research.valid and research.name == "pneumatic-fence-gate-interoperability" then
            flow_engine.handle_interop_research_reversed(research.force)
        end
    end)

    events.on_event(defines.events.on_object_destroyed, function(event)
        local reg_id = event.registration_number
        if not reg_id then return end

        local u_num = event.useful_id
        if u_num and storage.blocked_reticles and storage.blocked_reticles[u_num] then
            local to_wake = {}
            for rid in pairs(storage.blocked_reticles[u_num]) do
                to_wake[#to_wake + 1] = rid
            end
            storage.blocked_reticles[u_num] = nil
            for i = 1, #to_wake do
                local rid = to_wake[i]
                local ret = storage.projector_reticles and storage.projector_reticles[rid]
                if ret then
                    flow_kinetic.resume_reticle_probing(ret)
                end
            end
        end

        if storage.blocked_reticles_by_reg and storage.blocked_reticles_by_reg[reg_id] then
            local to_wake = {}
            for rid in pairs(storage.blocked_reticles_by_reg[reg_id]) do
                to_wake[#to_wake + 1] = rid
            end
            storage.blocked_reticles_by_reg[reg_id] = nil
            for i = 1, #to_wake do
                local rid = to_wake[i]
                local ret = storage.projector_reticles and storage.projector_reticles[rid]
                if ret then
                    flow_kinetic.resume_reticle_probing(ret)
                end
            end
        end

        if not storage.object_destruction_map then return end
        local entry = storage.object_destruction_map[reg_id]
        if not entry then return end

        storage.object_destruction_map[reg_id] = nil

        if type(entry) == "table" then
            if entry.type == "capsule" then
                flow_engine.handle_capsule_destroyed(entry.id)
            elseif entry.type == "entity" then
                flow_engine.handle_object_destroyed(entry.unit_number)
            end
        elseif type(entry) == "number" then
            flow_engine.handle_object_destroyed(entry)
        end
    end)

    local build_events = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.script_raised_revive,
        defines.events.on_entity_cloned
    }
    if defines.events.on_space_platform_built_entity then
        table.insert(build_events, defines.events.on_space_platform_built_entity)
    end

    for _, event_id in ipairs(build_events) do
        events.on_event(event_id, function(event)
            local entity = event.entity or event.destination
            if not (entity and entity.valid) then return end
            if entity.name == "entity-ghost" then return end

            local real_name = entity.name

            if real_name == "gate" or entity.type == "gate" then
                storage.active_gates = storage.active_gates or {}
                storage.active_gates[entity.unit_number] = entity
                storage.gate_open_states = storage.gate_open_states or {}
                storage.gate_open_states[entity.unit_number] = not (entity.is_closed and entity.is_closed())
                if script.register_on_object_destroyed then
                    local reg_id = script.register_on_object_destroyed(entity)
                    storage.object_destruction_map = storage.object_destruction_map or {}
                    storage.object_destruction_map[reg_id] = { type = "entity", unit_number = entity.unit_number }
                end
            end
            if registered_entities[real_name] then
                flow_engine.connect_entity(entity)
            elseif is_standard_entity(real_name) then
                flow_gate_interop.handle_standard_entity_build(entity, flow_engine.connect_entity, flow_engine.get_node_emitter_level, flow_kinetic.get_node_kinetic_emitter)
            end

            flow_kinetic.handle_obstacle_changed(entity, false, flow_engine.enqueue_port, wake_port_parked)
        end)
    end

    local removal_events = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.events.script_raised_destroy
    }
    if defines.events.on_space_platform_mined_entity then
        table.insert(removal_events, defines.events.on_space_platform_mined_entity)
    end

    for _, event_id in ipairs(removal_events) do
        events.on_event(event_id, function(event)
            local entity = event.entity
            if entity and entity.valid then
                flow_kinetic.handle_obstacle_changed(entity, true, flow_engine.enqueue_port, wake_port_parked)

                local u_num = entity.unit_number
                if u_num and (entity.name == "pneumatic-projector" or (storage.active_projectors and storage.active_projectors[u_num])) then
                    flow_kinetic.clear_receiver_references(u_num, flow_engine.enqueue_port, wake_port_parked)
                    flow_kinetic.handle_projector_destroyed(u_num)
                end

                flow_engine.disconnect_entity(entity)
            end
        end)
    end

    if defines.events.on_marked_for_deconstruction then
        events.on_event(defines.events.on_marked_for_deconstruction, function(event)
            local entity = event.entity
            if entity and entity.valid and entity.name == "pneumatic-projector" then
                if entity.unit_number then
                    flow_engine.enqueue_unit_ports(entity.unit_number)
                end
            end
        end)
    end

    if defines.events.on_cancelled_deconstruction then
        events.on_event(defines.events.on_cancelled_deconstruction, function(event)
            local entity = event.entity
            if entity and entity.valid and entity.name == "pneumatic-projector" then
                if entity.unit_number then
                    flow_engine.enqueue_unit_ports(entity.unit_number)
                end
            end
        end)
    end

    events.on_event(defines.events.on_player_rotated_entity, function(event)
        handle_entity_reorientation(event.entity)
    end)

    events.on_event(defines.events.on_player_flipped_entity, function(event)
        handle_entity_reorientation(event.entity)
    end)
end

return flow_engine
