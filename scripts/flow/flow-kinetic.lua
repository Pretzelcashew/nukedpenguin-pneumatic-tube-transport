local flow_common = require("scripts.flow.flow-common")
local flow_renderer = require("scripts.flow.flow-renderer")
local port_defs = require("scripts.flow.port-defs")
local projector_settings = require("scripts.projectors.projector-settings")
local binary_heap = require("scripts.utils.binary-heap")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local timed_motion = require("scripts.utils.timed-motion")
local viewport_bvh = require("scripts.utils.viewport-bvh")

local flow_kinetic = {}

local BASE_PROJECTOR_RANGE = 50
local HOP_DISTANCE = 5

local ENABLE_KINETIC_FLOW_PROPAGATION = false
flow_kinetic.ENABLE_KINETIC_FLOW_PROPAGATION = ENABLE_KINETIC_FLOW_PROPAGATION

local DEFAULT_HEAD_SPEC = {
    color = { r = 1.0, g = 0.4, b = 0.25, a = 0.95 },
    radius = 0.24,
    has_ring = true,
    ring_radius = 0.42,
    ring_color = { r = 1.0, g = 0.4, b = 0.25, a = 0.85 },
    ring_width = 2
}
local RECEIVER_HEAD_SPEC = {
    color = { r = 0.2, g = 0.85, b = 1.0, a = 0.95 },
    radius = 0.24,
    has_ring = true,
    ring_radius = 0.42,
    ring_color = { r = 0.2, g = 0.85, b = 1.0, a = 0.85 },
    ring_width = 2
}
flow_kinetic.DEFAULT_HEAD_SPEC = DEFAULT_HEAD_SPEC
flow_kinetic.RECEIVER_HEAD_SPEC = RECEIVER_HEAD_SPEC

local function get_entity_bounding_box(ent)
    if not (ent and ent.valid) then return nil end
    local bb = ent.bounding_box
    if ent.type == "character" then
        local pos = ent.position
        local tx = math.floor(pos.x)
        local ty = math.floor(pos.y)
        return {
            left_top = { x = tx, y = ty },
            right_bottom = { x = tx + 1.0, y = ty + 1.0 }
        }
    end
    return bb
end

function flow_kinetic.get_cooldown_heap()
    if not storage.projector_cooldown_heap then
        storage.projector_cooldown_heap = binary_heap.new()
    else
        binary_heap.attach(storage.projector_cooldown_heap)
    end
    return storage.projector_cooldown_heap
end

function flow_kinetic.set_cooldown(owner_unit, duration)
    if not owner_unit then return end
    duration = duration or projector_settings.WANT_EMISSION_COOLDOWN_TICKS or 60
    local target_tick = game.tick + duration
    storage.projector_cooldown_until = storage.projector_cooldown_until or {}
    storage.projector_cooldown_until[owner_unit] = target_tick
end

function flow_kinetic.clear_cooldown(owner_unit)
    if not owner_unit then return end
    if storage.projector_cooldown_until then
        storage.projector_cooldown_until[owner_unit] = nil
    end
    local heap = storage.projector_cooldown_heap
    if heap then
        binary_heap.attach(heap)
        heap:remove(owner_unit)
    end
end

function flow_kinetic.step_cooldown_heap(current_tick)
    local heap = storage.projector_cooldown_heap
    if not heap or heap.size == 0 then return end
    current_tick = current_tick or game.tick

    binary_heap.attach(heap)

    while heap.size > 0 do
        local top_id, top_prio = heap:peek()
        if not top_prio or top_prio > current_tick then
            break
        end

        heap:pop()
        local unit_number = top_id
        local proj = storage.active_projectors and storage.active_projectors[unit_number]
        if proj and proj.valid and projector_settings.is_powered(proj) and projector_settings.is_projector_enabled(proj) then
            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
            local muzzle_node = nil
            local muzzle_pkey = nil
            if u_ports then
                for i = 1, #u_ports do
                    local pkey = u_ports[i]
                    local node = storage.flow_nodes and storage.flow_nodes[pkey]
                    if node and node.is_muzzle then
                        muzzle_node = node
                        muzzle_pkey = pkey
                        break
                    end
                end
            end

            if muzzle_node and muzzle_pkey then
                local max_range = flow_kinetic.get_node_kinetic_emitter(muzzle_node)
                if max_range and max_range > 0 then
                    flow_kinetic.on_muzzle_want_emission(muzzle_node, muzzle_pkey, max_range, true)
                end
            end
        end
    end
end

function flow_kinetic.count_in_flight_capsules(owner_unit)
    if not owner_unit then return 0 end
    local flights_store = storage.timed_flights or storage.projector_flights
    local flights = flights_store and flights_store[owner_unit]
    if not flights then return 0 end
    local count = 0
    for i = 1, #flights do
        local f = flights[i]
        if f and (f.kind == nil or f.kind == "capsule") then
            count = count + 1
        end
    end
    return count
end

function flow_kinetic.remove_capsule_corridor(owner_unit, surface_index, surface_name)
    if not owner_unit then return end
    timed_motion.remove_corridor(surface_index, owner_unit)
    flow_kinetic.unregister_trajectory_in_bvh(owner_unit, surface_name, true)
    if storage.pinned_corridors then
        storage.pinned_corridors[owner_unit] = nil
    end
    if storage.decaying_corridors then
        storage.decaying_corridors[owner_unit] = nil
    end
end

function flow_kinetic.unlink_projector_receiver(proj_unit, surface_index, surface_name)
    if not proj_unit then return end
    if storage.projector_scope and storage.projector_scope[proj_unit] then
        storage.projector_scope[proj_unit].receiver_unit = nil
    end

    local in_transit = flow_kinetic.count_in_flight_capsules(proj_unit)
    if in_transit == 0 then
        flow_kinetic.remove_capsule_corridor(proj_unit, surface_index, surface_name)
    else
        storage.decaying_corridors = storage.decaying_corridors or {}
        storage.decaying_corridors[proj_unit] = {
            surface_index = surface_index,
            surface_name = surface_name
        }
    end
end

function flow_kinetic.orphan_reticle(owner_unit, reason)
    if not owner_unit then return end
    if reason == "destroyed" or reason == "unregistered" then
        flow_kinetic.clear_cooldown(owner_unit)
    end
    storage.projector_reticles = storage.projector_reticles or {}
    storage.projector_scope = storage.projector_scope or {}

    local scope = storage.projector_scope[owner_unit]
    if not scope then
        if flow_kinetic.count_in_flight_capsules(owner_unit) == 0 then
            flow_kinetic.remove_capsule_corridor(owner_unit)
        end
        return
    end

    local reticle_id = (type(scope) == "table" and scope.reticle_id) or (type(scope) == "number" and scope)
    storage.projector_scope[owner_unit] = nil

    if not reticle_id then
        if flow_kinetic.count_in_flight_capsules(owner_unit) == 0 then
            flow_kinetic.remove_capsule_corridor(owner_unit)
        end
        return
    end
    local reticle = storage.projector_reticles[reticle_id]
    if not reticle or reticle.status == "retreating" then
        flow_kinetic.unregister_reticle_obstacle(reticle_id)
        if flow_kinetic.count_in_flight_capsules(owner_unit) == 0 then
            flow_kinetic.remove_capsule_corridor(owner_unit)
        end
        return
    end

    reticle.projector_unit = nil
    reticle.pending_receiver = nil
    reticle.hit_receiver = nil
    reticle.head_render_spec = DEFAULT_HEAD_SPEC
    reticle.status = (reticle.status == "growing") and "growing" or "stationary"
    local current_tick = game.tick
    reticle.retreat_tick = current_tick

    local s_idx = reticle.surface_index or 1
    local s_name = reticle.surface_name or "nauvis"

    local in_transit_capsules = flow_kinetic.count_in_flight_capsules(owner_unit)
    if in_transit_capsules == 0 then
        flow_kinetic.remove_capsule_corridor(owner_unit, s_idx, s_name)
    else
        storage.decaying_corridors = storage.decaying_corridors or {}
        storage.decaying_corridors[owner_unit] = {
            surface_index = s_idx,
            surface_name = s_name
        }
    end
    local motion_tree = timed_motion.get_motion_tree(s_idx)
    if motion_tree and reticle.seg_key then
        local owner_rec = motion_tree.trajectories and motion_tree.trajectories[reticle_id]
        local leaf = owner_rec and owner_rec.segments and owner_rec.segments[reticle.seg_key]
        if leaf and leaf.static_render_spec == RECEIVER_HEAD_SPEC then
            leaf.static_render_spec = DEFAULT_HEAD_SPEC
            viewport_bvh.on_leaf_static_changed(s_idx, leaf)
        end
    end

    local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or timed_motion.DEFAULT_TICKS_PER_TILE
    local anti_flight_id = "anti:" .. tostring(reticle_id)
    reticle.anti_flight_id = anti_flight_id

    local first_step = math.min(16, reticle.total_dist)
    local next_term = {
        x = reticle.start_pos.x + reticle.dir.x * first_step,
        y = reticle.start_pos.y + reticle.dir.y * first_step
    }

    flow_kinetic.launch_timed_flight{
        id = anti_flight_id,
        owner_id = reticle_id,
        surface_name = reticle.surface_name,
        start_pos = { x = reticle.start_pos.x, y = reticle.start_pos.y },
        terminal_pos = next_term,
        dir = { x = reticle.dir.x, y = reticle.dir.y },
        kind = "anti_reticle",
        on_arrival = "anti_reticle",
        remaining_distance = reticle.total_dist,
        max_distance = reticle.total_dist,
        seg_idx = 1,
        reticle_id = reticle_id,
        ticks_per_tile = tpt
    }
end

function flow_kinetic.on_muzzle_want_emission(node, pkey, target_kinetic, kinetic_changed)
    if not (node and node.is_muzzle and node.dir and node.pos and node.surface_name) then return end
    local owner_id = node.beam_owner or node.unit_number
    if not owner_id then return end

    storage.projector_scope = storage.projector_scope or {}
    storage.projector_reticles = storage.projector_reticles or {}
    local scope = storage.projector_scope[owner_id]
    if scope then
        if type(scope) == "table" and (scope.status == "endpoint" or scope.status == "traveling") then
            return
        elseif type(scope) == "number" and timed_motion.get_flight(scope) then
            return
        else
            storage.projector_scope[owner_id] = nil
        end
    end

    local current_tick = game.tick
    local cooldown_until = storage.projector_cooldown_until and storage.projector_cooldown_until[owner_id]
    if cooldown_until and current_tick < cooldown_until then
        local heap = flow_kinetic.get_cooldown_heap()
        if heap then
            heap:push(owner_id, cooldown_until, { pkey = pkey, target_kinetic = target_kinetic })
        end
        return
    end

    local max_range = target_kinetic or flow_kinetic.get_node_kinetic_emitter(node)
    if not max_range or max_range <= 0 then return end

    flow_kinetic.set_cooldown(owner_id)

    local dx = node.dir.x
    local dy = node.dir.y
    local step = math.min(16, max_range)

    storage.next_reticle_id = (storage.next_reticle_id or 0) + 1
    local reticle_id = storage.next_reticle_id

    local full_reach = max_range
    local surface = game.surfaces[node.surface_name]
    local obst = flow_kinetic.scan_leaf_rect(surface, node.pos, node.dir, step, owner_id, reticle_id)
    local initial_obstacle = nil
    if obst and obst.dist then
        step = math.max(0.1, obst.dist)
        max_range = step
        initial_obstacle = obst.entity
    end

    local start_pos = { x = node.pos.x, y = node.pos.y }
    local terminal_pos = { x = node.pos.x + dx * step, y = node.pos.y + dy * step }

    storage.projector_scope[owner_id] = {
        reticle_id = reticle_id,
        flight_id = reticle_id,
        status = "traveling"
    }
    storage.pinned_corridors = storage.pinned_corridors or {}
    storage.pinned_corridors[reticle_id] = true

    local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or timed_motion.DEFAULT_TICKS_PER_TILE
    local is_rec = initial_obstacle and initial_obstacle.valid and initial_obstacle.name == "pneumatic-projector"
    storage.projector_reticles[reticle_id] = {
        id = reticle_id,
        projector_unit = owner_id,
        pending_receiver = is_rec and initial_obstacle.unit_number or nil,
        hit_receiver = nil,
        surface_name = node.surface_name,
        surface_index = (game.surfaces[node.surface_name] and game.surfaces[node.surface_name].index) or 1,
        start_pos = { x = node.pos.x, y = node.pos.y },
        terminal_pos = { x = node.pos.x + dx * max_range, y = node.pos.y + dy * max_range },
        dir = { x = dx, y = dy },
        q_level = node.q_level or 0,
        max_reach = full_reach,
        max_range = max_range,
        total_dist = max_range,
        status = "growing",
        start_tick = game.tick,
        ticks_per_tile = tpt,
        head_flight_id = reticle_id,
        head_render_spec = DEFAULT_HEAD_SPEC
    }

    if initial_obstacle then
        flow_kinetic.register_reticle_obstacle(reticle_id, initial_obstacle)
    end

    flow_kinetic.launch_timed_flight{
        id = reticle_id,
        owner_id = reticle_id,
        surface_name = node.surface_name,
        start_pos = start_pos,
        terminal_pos = terminal_pos,
        dir = { x = dx, y = dy },
        kind = "projector_scope",
        on_arrival = "projector_scope",
        remaining_distance = max_range,
        max_distance = max_range,
        seg_idx = 1,
        reticle_id = reticle_id,
        projector_unit = owner_id,
        q_level = node.q_level or 0,
        render_spec = DEFAULT_HEAD_SPEC,
    }
end

function flow_kinetic.on_muzzle_stop_emission(node, pkey)
    local owner_id = node and (node.beam_owner or node.unit_number)
    if owner_id then
        flow_kinetic.orphan_reticle(owner_id, "stop_emission")
    end
end

function flow_kinetic._legacy_on_muzzle_stop_emission(node, pkey)
    local owner_id = node and (node.beam_owner or node.unit_number)
    if owner_id then
        local surf = node.surface_name and game.surfaces[node.surface_name]
        local s_idx = (surf and surf.valid and surf.index) or 1
        flow_kinetic.unregister_trajectory_in_bvh(owner_id, node.surface_name, true)
        timed_motion.remove_corridor(s_idx, owner_id)
        if storage.projector_scope then
            storage.projector_scope[owner_id] = nil
        end
        local flights_store = storage.timed_flights or storage.projector_flights
        local active_flights = flights_store and flights_store[owner_id]
        if active_flights then
            for i = #active_flights, 1, -1 do
                timed_motion.remove_flight(active_flights[i].id or active_flights[i].capsule_id, owner_id)
            end
        end
    end
end

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

flow_kinetic.IGNORABLE_TYPES = IGNORABLE_TYPES
flow_kinetic.PROXY_NAMES = PROXY_NAMES

local make_beam_port_key = flow_common.make_beam_port_key
local make_pos_key = flow_common.make_pos_key
local make_port_key = flow_common.make_port_key
local enqueue_port = flow_common.enqueue_port
local wake_port_parked = flow_common.wake_port_parked

function flow_kinetic.register_segment_in_bvh(surface, owner_unit, dir, d_start, d_end, seg_idx, mx, my)
    if not (surface and surface.valid and dir) then return end
    local seg_key = string.format("%d,%d:%d", dir.x, dir.y, seg_idx)
    local start_pos = { x = mx + dir.x * d_start, y = my + dir.y * d_start }
    local end_pos = { x = mx + dir.x * d_end, y = my + dir.y * d_end }
    local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
    if tree then
        if storage.pending_bvh_segments then
            for i = #storage.pending_bvh_segments, 1, -1 do
                local item = storage.pending_bvh_segments[i]
                if item.owner_id == owner_unit and item.seg_key == seg_key then
                    table.remove(storage.pending_bvh_segments, i)
                end
            end
        end
        tree:insert_segment(owner_unit, seg_key, start_pos, end_pos, d_start, d_end, seg_idx)
        trajectory_bvh.refresh_active_renders()
    end
end

function flow_kinetic.register_endpoint_in_bvh(node)
    local surface = game.surfaces[node.surface_name]
    if not (surface and surface.valid and node.dir and node.dist) then return end
    local owner_unit = node.beam_owner or node.unit_number
    local start_pos = {
        x = node.pos.x - node.dir.x * node.dist,
        y = node.pos.y - node.dir.y * node.dist
    }
    local cur_dist = node.dist or 0
    local last_boundary = math.floor(cur_dist / 16) * 16
    local mx = node.pos.x - node.dir.x * cur_dist
    local my = node.pos.y - node.dir.y * cur_dist

    local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
    if tree then

        if cur_dist > last_boundary then
            local seg_idx = math.floor(cur_dist / 16) + 1
            local seg_key = string.format("%d,%d:rem:%d", node.dir.x, node.dir.y, cur_dist)
            local start_pos = { x = mx + node.dir.x * last_boundary, y = my + node.dir.y * last_boundary }
            local end_pos = { x = node.pos.x, y = node.pos.y }
            tree:insert_segment(owner_unit, seg_key, start_pos, end_pos, last_boundary, cur_dist, seg_idx)
            trajectory_bvh.refresh_active_renders()
        end
    end
end

function flow_kinetic.unregister_trajectory_in_bvh(owner_unit, surface_name, force)
    if not owner_unit then return end
    if storage.pending_bvh_removals then
        storage.pending_bvh_removals[owner_unit] = nil
    end

    if surface_name then
        local surface = game.surfaces[surface_name]
        if surface and surface.valid and storage.surface_bvh then
            local tree = storage.surface_bvh[surface.index]
            if tree then
                trajectory_bvh.attach(tree)
                tree:remove_trajectory(owner_unit)
            end
        end
    elseif storage.surface_bvh then
        for _, tree in pairs(storage.surface_bvh) do
            trajectory_bvh.attach(tree)
            tree:remove_trajectory(owner_unit)
        end
    end
    trajectory_bvh.refresh_active_renders()
end

function flow_kinetic.unregister_segment_in_bvh(node)
    if not (node and node.dist and node.dir) then return end
    local cur_dist = node.dist
    local surface = game.surfaces[node.surface_name]
    if surface and surface.valid and storage.surface_bvh then
        local tree = storage.surface_bvh[surface.index]
        if tree then
            trajectory_bvh.attach(tree)
            local owner_u = node.beam_owner or node.unit_number
            local owner_rec = tree.trajectories and tree.trajectories[owner_u]
            if owner_rec and owner_rec.segments then
                local to_remove = nil
                local current_tick = game.tick
                for seg_key, leaf in pairs(owner_rec.segments) do
                    if leaf.d_end == cur_dist then
                        local has_capsule, max_exit = trajectory_bvh.has_flight_in_leaf(leaf, storage.projector_flights, current_tick)
                        if has_capsule then
                            leaf.pending_removal = true
                            leaf.removal_expiry_tick = max_exit
                            storage.pending_bvh_segments = storage.pending_bvh_segments or {}
                            storage.pending_bvh_segments[#storage.pending_bvh_segments + 1] = {
                                surface_index = surface.index,
                                owner_id = owner_u,
                                seg_key = seg_key,
                                leaf = leaf
                            }
                        else
                            to_remove = to_remove or {}
                            to_remove[#to_remove + 1] = seg_key
                        end
                    end
                end
                if to_remove then
                    for i = 1, #to_remove do
                        tree:remove_segment(owner_u, to_remove[i])
                    end
                    trajectory_bvh.refresh_active_renders()
                end
            end
        end
    end
end

function flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
    if not (node and node.dist and node.dir) then return end
    local cur_dist = node.dist
    local surface = game.surfaces[node.surface_name]
    if surface and surface.valid and storage.surface_bvh then
        local tree = storage.surface_bvh[surface.index]
        if tree then
            trajectory_bvh.attach(tree)
            local owner_u = node.beam_owner or node.unit_number
            local owner_rec = tree.trajectories and tree.trajectories[owner_u]
            if owner_rec and owner_rec.segments then
                local rem_key = string.format("%d,%d:rem:%d", node.dir.x, node.dir.y, cur_dist)
                if owner_rec.segments[rem_key] then
                    tree:remove_segment(owner_u, rem_key)
                    trajectory_bvh.refresh_active_renders()
                end
            end
        end
    end
end

function flow_kinetic.get_node_kinetic_emitter(node)
    if not node or not node.kinetic_transmit or not node.is_muzzle then return 0 end
    local unit_number = node.unit_number
    local entity = storage.active_projectors and storage.active_projectors[unit_number]
    if not (entity and entity.valid) then return 0 end

    local power_state = storage.projector_power_states and storage.projector_power_states[unit_number]
    local is_powered = false
    if power_state ~= nil then
        is_powered = power_state
    else
        is_powered = projector_settings.is_powered(entity)
    end

    local enabled_state = storage.projector_enabled_states and storage.projector_enabled_states[unit_number]
    local is_enabled = false
    if enabled_state ~= nil then
        is_enabled = enabled_state
    else
        is_enabled = projector_settings.is_projector_enabled(entity)
    end

    if not (is_powered and is_enabled) then return 0 end

    local q_level = (entity.quality and entity.quality.level) or 0
    return math.floor(BASE_PROJECTOR_RANGE * (1 + 0.3 * q_level))
end

function flow_kinetic.check_tile_obstruction(surface, tx, ty, sender_entity)
    if not (surface and surface.valid) then return { blocked = false, is_receiver = false } end

    if storage.character_colliders then
        local pos_key = make_pos_key(surface.name, tx, ty)
        local char_collider = storage.character_colliders[pos_key]
        if char_collider and char_collider.valid then
            return { blocked = true, is_receiver = false, obstacle = char_collider, is_character = true }
        end
    end

    local candidates = surface.find_entities_filtered{
        area = {{tx - 0.45, ty - 0.45}, {tx + 0.45, ty + 0.45}}
    }
    local sender_unit = (sender_entity and sender_entity.valid) and sender_entity.unit_number or nil

    for _, cand in ipairs(candidates) do
        local is_self = (cand == sender_entity) or (sender_unit and cand.unit_number and cand.unit_number == sender_unit)
        if cand.valid and not is_self then
            local cand_name = cand.name
            local cand_type = cand.type

            local is_ignorable = (IGNORABLE_TYPES[cand_type] == true) or (PROXY_NAMES[cand_name] == true)

            if not is_ignorable and cand_type == "gate" then
                if not (cand.is_closed and cand.is_closed()) then
                    is_ignorable = true
                end
            end
            if not is_ignorable then
                if cand_name == "pneumatic-projector" then
                    return { blocked = true, is_receiver = true, receiver = cand }
                else
                    return { blocked = true, is_receiver = false, obstacle = cand }
                end
            end
        end
    end

    return { blocked = false, is_receiver = false }
end

local function compute_port_kinetic_level(node, pkey)
    if not node then return 0 end

    if node.is_muzzle then
        return flow_kinetic.get_node_kinetic_emitter(node)
    end

    if not ENABLE_KINETIC_FLOW_PROPAGATION then return 0 end

    if not node.is_kinetic then return 0 end

    local surface = game.surfaces[node.surface_name]
    if surface and surface.valid then
        local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
        local occ = flow_kinetic.check_tile_obstruction(surface, node.pos.x, node.pos.y, owner_entity)
        if occ.blocked then
            return 0
        end
    end

    local max_upstream = 0
    local neighbors = storage.flow_connections and storage.flow_connections[pkey]
    if neighbors then
        for n_key in pairs(neighbors) do
            local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
            if n_node and n_node.is_kinetic and n_node.beam_owner == node.beam_owner then
                local is_upstream = n_node.is_muzzle or (n_node.dist and node.dist and n_node.dist < node.dist)
                if is_upstream then
                    local n_level = storage.kinetic_levels and storage.kinetic_levels[n_key] or 0
                    if n_level > max_upstream then
                        max_upstream = n_level
                    end
                end
            end
        end
    end

    if max_upstream > 1 then
        return max_upstream - 1
    else
        return 0
    end
end

local function dock_receiver_endpoint(node, pkey, nx, ny, receiver_ent, enqueue_port_fn, wake_port_fn)
    if node.is_endpoint then
        flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
    end
    local node_is_prom = (not node.is_muzzle) and ((node.dist or 0) > 0) and ((node.dist or 0) % HOP_DISTANCE == 0)
    node.is_endpoint = false
    node.hit_receiver = nil
    node.is_prominent_kinetic = node_is_prom
    node.is_beam_node = node_is_prom
    node.capsule_transmit = node_is_prom

    local rx = (node.dir.x ~= 0) and (receiver_ent.position.x - node.dir.x * 1.5) or node.pos.x
    local ry = (node.dir.y ~= 0) and (receiver_ent.position.y - node.dir.y * 1.5) or node.pos.y
    local next_dist = (node.dist or 0) + 1
    local next_pkey = make_beam_port_key(node.beam_owner or node.unit_number, node.dir.x, node.dir.y, next_dist)
    local next_pos_key = make_pos_key(node.surface_name, rx, ry)

    storage.flow_nodes[next_pkey] = {
        unit_number = node.beam_owner or node.unit_number,
        beam_owner = node.beam_owner or node.unit_number,
        port_index = 100 + next_dist,
        pos_key = next_pos_key,
        pos = {x = rx, y = ry},
        dir = {x = node.dir.x, y = node.dir.y},
        surface_name = node.surface_name,
        dist = next_dist,
        is_kinetic = true,
        is_beam_node = true,
        is_prominent_kinetic = true,
        capsule_transmit = true,
        pressure_transmit = false,
        sense_transmit = false,
        kinetic_transmit = true,
        cross_transit = false,
        q_level = node.q_level,
        is_endpoint = true,
        hit_receiver = receiver_ent.unit_number
    }

    storage.kinetic_levels[next_pkey] = math.max(1, (storage.kinetic_levels[pkey] or 2) - 1)
    flow_common.add_node_to_grid(next_pos_key, next_pkey)
    flow_common.link_ports(pkey, next_pkey)

    flow_kinetic.register_endpoint_in_bvh(storage.flow_nodes[next_pkey])
    flow_renderer.update_kinetic_pos_render(pkey)
    flow_renderer.update_kinetic_pos_render(next_pkey)
    wake_port_fn(pkey)
    wake_port_fn(next_pkey)

    local owner_unit = node.beam_owner or node.unit_number
    if flow_kinetic.update_projector_flights then
        flow_kinetic.update_projector_flights(owner_unit)
    end

    local r_unit = receiver_ent.unit_number
    local r_ports = storage.flow_unit_ports and storage.flow_unit_ports[r_unit]
    if r_ports then
        for _, rp in ipairs(r_ports) do
            enqueue_port_fn(rp)
            wake_port_fn(rp)
        end
    end
end

function flow_kinetic.step_port(node, pkey, enqueue_port_fn, wake_port_fn)
    local target_kinetic = compute_port_kinetic_level(node, pkey)
    local current_kinetic = storage.kinetic_levels and storage.kinetic_levels[pkey] or 0
    local kinetic_changed = (target_kinetic ~= current_kinetic)

    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    if target_kinetic > 0 then
        if kinetic_changed then
            storage.kinetic_levels[pkey] = target_kinetic
            if node.is_muzzle then
                flow_renderer.update_pos_render(node.pos_key)
            end
        end

        if node.is_muzzle and flow_kinetic.on_muzzle_want_emission then
            flow_kinetic.on_muzzle_want_emission(node, pkey, target_kinetic, kinetic_changed)
        end

        if not ENABLE_KINETIC_FLOW_PROPAGATION then
            return kinetic_changed
        end

        local surface = game.surfaces[node.surface_name]

        local has_downstream = false
        local neighbors = storage.flow_connections and storage.flow_connections[pkey]
        if neighbors then
            for n_key in pairs(neighbors) do
                local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                if n_node and n_node.is_kinetic and n_node.beam_owner == node.beam_owner and n_node.dist and node.dist and n_node.dist > node.dist then
                    has_downstream = true
                    break
                end
            end
        end

        if not has_downstream and surface and surface.valid then
            if target_kinetic == 1 and not node.is_muzzle then
                local nx = node.dir and (node.pos.x + node.dir.x)
                local ny = node.dir and (node.pos.y + node.dir.y)
                local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
                local occ = (nx and ny) and flow_kinetic.check_tile_obstruction(surface, nx, ny, owner_entity) or { blocked = false, is_receiver = false }
                if occ.blocked and occ.is_receiver and occ.receiver then
                    dock_receiver_endpoint(node, pkey, nx, ny, occ.receiver, enqueue_port_fn, wake_port_fn)
                    return kinetic_changed
                end
                node.is_endpoint = true
                node.is_prominent_kinetic = true
                node.is_beam_node = true
                node.capsule_transmit = true
                node.hit_receiver = nil
                flow_kinetic.register_endpoint_in_bvh(node)
                flow_renderer.update_kinetic_pos_render(pkey)
                wake_port_fn(pkey)
                local owner_unit = node.beam_owner or node.unit_number
                if flow_kinetic.update_projector_flights then
                    flow_kinetic.update_projector_flights(owner_unit)
                end
            elseif target_kinetic > 1 and node.dir then
                local nx = node.pos.x + node.dir.x
                local ny = node.pos.y + node.dir.y
                local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
                local occ = flow_kinetic.check_tile_obstruction(surface, nx, ny, owner_entity)

                if occ.blocked then
                    if occ.is_receiver and occ.receiver then
                        if node.is_endpoint then
                            flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
                        end
                        node.is_endpoint = false
                        node.hit_receiver = nil
                        local rx = (node.dir.x ~= 0) and (occ.receiver.position.x - node.dir.x * 1.5) or node.pos.x
                        local ry = (node.dir.y ~= 0) and (occ.receiver.position.y - node.dir.y * 1.5) or node.pos.y
                        local next_dist = (node.dist or 0) + 1
                        local next_pkey = make_beam_port_key(node.beam_owner or node.unit_number, node.dir.x, node.dir.y, next_dist)
                        local next_pos_key = make_pos_key(node.surface_name, rx, ry)

                        storage.flow_nodes[next_pkey] = {
                            unit_number = node.beam_owner or node.unit_number,
                            beam_owner = node.beam_owner or node.unit_number,
                            port_index = 100 + next_dist,
                            pos_key = next_pos_key,
                            pos = {x = rx, y = ry},
                            dir = {x = node.dir.x, y = node.dir.y},
                            surface_name = node.surface_name,
                            dist = next_dist,
                            is_kinetic = true,
                            is_beam_node = true,
                            is_prominent_kinetic = true,
                            capsule_transmit = true,
                            pressure_transmit = false,
                            sense_transmit = false,
                            kinetic_transmit = true,
                            cross_transit = false,
                            q_level = node.q_level,
                            is_endpoint = true,
                            hit_receiver = occ.receiver.unit_number
                        }

                        flow_common.add_node_to_grid(next_pos_key, next_pkey)
                        flow_common.link_ports(pkey, next_pkey)

                        flow_kinetic.register_endpoint_in_bvh(storage.flow_nodes[next_pkey])
                        storage.kinetic_levels[next_pkey] = math.max(1, (storage.kinetic_levels[pkey] or 2) - 1)
                        flow_renderer.update_kinetic_pos_render(pkey)
                        flow_renderer.update_kinetic_pos_render(next_pkey)
                        wake_port_fn(pkey)
                        wake_port_fn(next_pkey)
                    else
                        node.is_endpoint = true
                        node.is_prominent_kinetic = true
                        node.is_beam_node = true
                        node.capsule_transmit = true
                        node.hit_receiver = nil
                        flow_kinetic.register_endpoint_in_bvh(node)
                        flow_renderer.update_kinetic_pos_render(pkey)
                        wake_port_fn(pkey)
                    end

                    local owner_unit = node.beam_owner or node.unit_number
                    if flow_kinetic.update_projector_flights then
                        flow_kinetic.update_projector_flights(owner_unit)
                    end

                    if occ.is_receiver and occ.receiver and occ.receiver.unit_number then
                        local r_unit = occ.receiver.unit_number
                        local r_ports = storage.flow_unit_ports and storage.flow_unit_ports[r_unit]
                        if r_ports then
                            for _, rp in ipairs(r_ports) do
                                enqueue_port_fn(rp)
                                wake_port_fn(rp)
                            end
                        end
                    end

                    local owner_unit = node.beam_owner or node.unit_number
                    local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[owner_unit]
                    if u_ports then
                        for _, upkey in ipairs(u_ports) do
                            wake_port_fn(upkey)
                        end
                    end
                else
                    if node.is_endpoint then
                        flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
                    end
                    local node_is_prom = (not node.is_muzzle) and ((node.dist or 0) > 0) and ((node.dist or 0) % HOP_DISTANCE == 0)
                    node.is_endpoint = false
                    node.hit_receiver = nil
                    node.is_prominent_kinetic = node_is_prom
                    node.is_beam_node = node_is_prom
                    node.capsule_transmit = node_is_prom

                    local next_dist = (node.dist or 0) + 1
                    local next_pkey = make_beam_port_key(node.beam_owner or node.unit_number, node.dir.x, node.dir.y, next_dist)
                    local next_pos_key = make_pos_key(node.surface_name, nx, ny)
                    local is_prom = (next_dist % HOP_DISTANCE == 0)

                    storage.flow_nodes[next_pkey] = {
                        unit_number = node.beam_owner or node.unit_number,
                        beam_owner = node.beam_owner or node.unit_number,
                        port_index = 100 + next_dist,
                        pos_key = next_pos_key,
                        pos = {x = nx, y = ny},
                        dir = {x = node.dir.x, y = node.dir.y},
                        surface_name = node.surface_name,
                        dist = next_dist,
                        is_kinetic = true,
                        is_beam_node = is_prom,
                        is_prominent_kinetic = is_prom,
                        capsule_transmit = is_prom,
                        pressure_transmit = false,
                        sense_transmit = false,
                        kinetic_transmit = true,
                        cross_transit = false,
                        q_level = node.q_level,
                        is_endpoint = false
                    }

                    flow_common.add_node_to_grid(next_pos_key, next_pkey)
                    flow_common.link_ports(pkey, next_pkey)

                    flow_common.enqueue_port(next_pkey)
                    flow_common.wake_port_parked(pkey)
                    flow_common.wake_port_parked(next_pkey)

                    flow_renderer.update_kinetic_pos_render(pkey)

                    if next_dist % 16 == 0 then
                        local owner_u = node.beam_owner or node.unit_number
                        local mx = nx - node.dir.x * next_dist
                        local my = ny - node.dir.y * next_dist
                        flow_kinetic.register_segment_in_bvh(surface, owner_u, node.dir, next_dist - 16, next_dist, next_dist / 16, mx, my)
                    end

                    if is_prom then
                        local owner_unit = node.beam_owner or node.unit_number
                        local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[owner_unit]
                        if u_ports then
                            for _, upkey in ipairs(u_ports) do
                                wake_port_fn(upkey)
                            end
                        end
                    end
                end
            end
        else
            local node_is_prom = (not node.is_muzzle) and ((node.dist or 0) > 0) and ((node.dist or 0) % HOP_DISTANCE == 0)
            if node.is_endpoint or (node.is_prominent_kinetic ~= node_is_prom) then
                if node.is_endpoint then
                    flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
                end
                node.is_endpoint = false
                node.hit_receiver = nil
                node.is_prominent_kinetic = node_is_prom
                node.is_beam_node = node_is_prom
                node.capsule_transmit = node_is_prom
                flow_renderer.update_kinetic_pos_render(pkey)
            elseif kinetic_changed then
                flow_renderer.update_kinetic_pos_render(pkey)
            end
        end
    else
        if kinetic_changed then
            storage.kinetic_levels[pkey] = nil
            flow_renderer.destroy_kinetic_pos_render(pkey)

            if node.is_muzzle and flow_kinetic.on_muzzle_stop_emission then
                flow_kinetic.on_muzzle_stop_emission(node, pkey)
            end

            if not node.is_muzzle then
                flow_kinetic.unregister_segment_in_bvh(node)
                local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                flow_common.destroy_node(pkey)
                if neighbors then
                    for n_key in pairs(neighbors) do
                        enqueue_port_fn(n_key)
                        wake_port_fn(n_key)
                    end
                end
            else
                local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        flow_common.enqueue_port(n_key)
                        flow_common.wake_port_parked(n_key)
                    end
                end
                local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
                if u_ports then
                    for _, upkey in ipairs(u_ports) do
                        flow_common.wake_port_parked(upkey)
                    end
                end
                flow_common.wake_port_parked(pkey)
            end
            flow_renderer.update_pos_render(node.pos_key)
        end
    end

    return kinetic_changed
end

function flow_kinetic.scan_leaf_rect(surface, start_pos, dir, step_dist, sender_unit, reticle_id)
    if not (surface and surface.valid and start_pos and dir and step_dist and step_dist > 0) then return nil end
    local dx = dir.x or 0
    local dy = dir.y or 0
    if dx == 0 and dy == 0 then return nil end

    local min_x, max_x, min_y, max_y
    if dx ~= 0 then
        min_x = math.min(start_pos.x, start_pos.x + dx * step_dist)
        max_x = math.max(start_pos.x, start_pos.x + dx * step_dist)
        min_y = start_pos.y - 0.45
        max_y = start_pos.y + 0.45
    else
        min_x = start_pos.x - 0.45
        max_x = start_pos.x + 0.45
        min_y = math.min(start_pos.y, start_pos.y + dy * step_dist)
        max_y = math.max(start_pos.y, start_pos.y + dy * step_dist)
    end

    local candidates = surface.find_entities_filtered{
        area = {{min_x, min_y}, {max_x, max_y}}
    }

    local closest_dist = step_dist + 0.05
    local closest_entity = nil

    for _, cand in ipairs(candidates) do
        local is_self = (cand.unit_number and sender_unit and cand.unit_number == sender_unit)
        if cand.valid and not is_self then
            local c_type = cand.type
            local c_name = cand.name
            local is_ignorable = (IGNORABLE_TYPES[c_type] == true) or (PROXY_NAMES[c_name] == true)
            if not is_ignorable and c_type == "gate" then
                if not (cand.is_closed and cand.is_closed()) then
                    is_ignorable = true
                    if reticle_id and cand.unit_number then
                        local ret = storage.projector_reticles and storage.projector_reticles[reticle_id]
                        if ret and ret.start_pos then
                            local cbb = cand.bounding_box
                            local abs_dist = (ret.dir.x > 0 and (cbb.left_top.x - ret.start_pos.x))
                                or (ret.dir.x < 0 and (ret.start_pos.x - cbb.right_bottom.x))
                                or (ret.dir.y > 0 and (cbb.left_top.y - ret.start_pos.y))
                                or (ret.dir.y < 0 and (ret.start_pos.y - cbb.right_bottom.y))
                                or (step_dist or 1)
                            flow_kinetic.register_corridor_gate(reticle_id, cand, abs_dist, false)
                        end
                    end
                end
            end

            if not is_ignorable then
                local cbb = get_entity_bounding_box(cand)
                local d = nil
                local on_axis = false

                if dx > 0 then
                    on_axis = (cbb.left_top.y - 0.05 <= start_pos.y and start_pos.y <= cbb.right_bottom.y + 0.05)
                    d = (cbb.left_top.x <= start_pos.x + 0.05 and start_pos.x < cbb.right_bottom.x - 0.05) and 0.1 or (cbb.left_top.x - start_pos.x)
                elseif dx < 0 then
                    on_axis = (cbb.left_top.y - 0.05 <= start_pos.y and start_pos.y <= cbb.right_bottom.y + 0.05)
                    d = (cbb.left_top.x + 0.05 < start_pos.x and start_pos.x <= cbb.right_bottom.x + 0.05) and 0.1 or (start_pos.x - cbb.right_bottom.x)
                elseif dy > 0 then
                    on_axis = (cbb.left_top.x - 0.05 <= start_pos.x and start_pos.x <= cbb.right_bottom.x + 0.05)
                    d = (cbb.left_top.y <= start_pos.y + 0.05 and start_pos.y < cbb.right_bottom.y - 0.05) and 0.1 or (cbb.left_top.y - start_pos.y)
                elseif dy < 0 then
                    on_axis = (cbb.left_top.x - 0.05 <= start_pos.x and start_pos.x <= cbb.right_bottom.x + 0.05)
                    d = (cbb.left_top.y + 0.05 < start_pos.y and start_pos.y <= cbb.right_bottom.y + 0.05) and 0.1 or (start_pos.y - cbb.right_bottom.y)
                end

                if on_axis and d and d > 0.05 and d <= closest_dist then
                    closest_dist = d
                    closest_entity = cand
                end
            end
        end
    end

    if closest_entity then
        return {
            dist = closest_dist,
            entity = closest_entity
        }
    end
    return nil
end

function flow_kinetic.register_reticle_obstacle(reticle_id, obstacle_entity)
    if not (reticle_id and obstacle_entity and obstacle_entity.valid) then return end
    flow_kinetic.unregister_reticle_obstacle(reticle_id)
    storage.blocked_reticles = storage.blocked_reticles or {}
    storage.reticle_blocked_by = storage.reticle_blocked_by or {}

    local u_num = obstacle_entity.unit_number
    local reg_id = nil
    if script.register_on_object_destroyed then
        pcall(function()
            reg_id = script.register_on_object_destroyed(obstacle_entity)
        end)
    end

    if u_num then
        storage.blocked_reticles[u_num] = storage.blocked_reticles[u_num] or {}
        storage.blocked_reticles[u_num][reticle_id] = true
    end

    if reg_id then
        storage.blocked_reticles_by_reg = storage.blocked_reticles_by_reg or {}
        storage.blocked_reticles_by_reg[reg_id] = storage.blocked_reticles_by_reg[reg_id] or {}
        storage.blocked_reticles_by_reg[reg_id][reticle_id] = true
    end

    storage.reticle_blocked_by[reticle_id] = {
        unit_number = u_num,
        reg_id = reg_id
    }

    if obstacle_entity.type == "gate" and u_num then
        local ret = storage.projector_reticles and storage.projector_reticles[reticle_id]
        if ret and ret.start_pos then
            local cbb = obstacle_entity.bounding_box
            local abs_dist = (ret.dir.x > 0 and (cbb.left_top.x - ret.start_pos.x))
                or (ret.dir.x < 0 and (ret.start_pos.x - cbb.right_bottom.x))
                or (ret.dir.y > 0 and (cbb.left_top.y - ret.start_pos.y))
                or (ret.dir.y < 0 and (ret.start_pos.y - cbb.right_bottom.y))
                or (ret.total_dist or 1)
            flow_kinetic.register_corridor_gate(reticle_id, obstacle_entity, abs_dist, true)
        end
    end
end

function flow_kinetic.register_corridor_gate(reticle_id, gate_entity, dist, is_closed)
    if not (reticle_id and gate_entity and gate_entity.valid and gate_entity.unit_number) then return end
    storage.reticle_gates = storage.reticle_gates or {}
    storage.reticle_gates[reticle_id] = storage.reticle_gates[reticle_id] or {}
    storage.reticle_gates[reticle_id][gate_entity.unit_number] = {
        entity = gate_entity,
        unit_number = gate_entity.unit_number,
        dist = dist,
        state = is_closed and "closed" or "open"
    }
end

function flow_kinetic.step_reticle_obstacles()
    if not (storage.reticle_gates and next(storage.reticle_gates) ~= nil) then return end

    local current_tick = game.tick
    for reticle_id, gates in pairs(storage.reticle_gates) do
        local ret = storage.projector_reticles and storage.projector_reticles[reticle_id]
        if not ret then
            storage.reticle_gates[reticle_id] = nil
        else
            local is_retreating = (ret.status == "retreating")
            local tpt = ret.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE
            local dist_cleared = (is_retreating and ret.retreat_tick) and ((current_tick - ret.retreat_tick) / tpt) or 0

            for u_num, gate_data in pairs(gates) do
                local gate = gate_data.entity
                if not (gate and gate.valid) then
                    gates[u_num] = nil
                elseif is_retreating and dist_cleared >= (gate_data.dist - 0.05) then
                    gates[u_num] = nil
                elseif not is_retreating and ret.total_dist and ret.total_dist < (gate_data.dist - 0.5) then
                    gates[u_num] = nil
                else
                    local is_closed = not (gate.is_closed and not gate.is_closed())
                    local prev_state = gate_data.state

                    if prev_state == "closed" and not is_closed then
                        gate_data.state = "open"
                        flow_kinetic.handle_reticle_obstacle_cleared(gate)
                    elseif prev_state == "open" and is_closed then
                        gate_data.state = "closed"
                        flow_kinetic.truncate_reticle(ret, gate_data.dist, gate)
                    end
                end
            end
            if next(gates) == nil then
                storage.reticle_gates[reticle_id] = nil
            end
        end
    end
end

function flow_kinetic.unregister_reticle_obstacle(reticle_id)
    if not (reticle_id and storage.reticle_blocked_by) then return end
    local entry = storage.reticle_blocked_by[reticle_id]
    if not entry then return end
    storage.reticle_blocked_by[reticle_id] = nil

    if entry.unit_number and storage.blocked_reticles and storage.blocked_reticles[entry.unit_number] then
        storage.blocked_reticles[entry.unit_number][reticle_id] = nil
        if next(storage.blocked_reticles[entry.unit_number]) == nil then
            storage.blocked_reticles[entry.unit_number] = nil
        end
    end

    if entry.reg_id and storage.blocked_reticles_by_reg and storage.blocked_reticles_by_reg[entry.reg_id] then
        storage.blocked_reticles_by_reg[entry.reg_id][reticle_id] = nil
        if next(storage.blocked_reticles_by_reg[entry.reg_id]) == nil then
            storage.blocked_reticles_by_reg[entry.reg_id] = nil
        end
    end
end

function flow_kinetic.resume_reticle_probing(reticle)
    if not reticle or reticle.status == "retreating" then return end
    local reticle_id = reticle.id
    flow_kinetic.unregister_reticle_obstacle(reticle_id)
    local prev_receiver = reticle.hit_receiver
    local proj_unit = reticle.projector_unit
    reticle.pending_receiver = nil
    reticle.hit_receiver = nil
    reticle.head_render_spec = DEFAULT_HEAD_SPEC
    if prev_receiver and proj_unit then
        flow_kinetic.unlink_projector_receiver(proj_unit, reticle.surface_index, reticle.surface_name)
    elseif proj_unit and storage.projector_scope and storage.projector_scope[proj_unit] then
        storage.projector_scope[proj_unit].receiver_unit = nil
    end
    local s_idx = reticle.surface_index or 1
    local motion_tree = timed_motion.get_motion_tree(s_idx)
    if motion_tree and reticle.seg_key then
        local owner_rec = motion_tree.trajectories and motion_tree.trajectories[reticle_id]
        local leaf = owner_rec and owner_rec.segments and owner_rec.segments[reticle.seg_key]
        if leaf and leaf.static_render_spec then
            leaf.static_render_spec = DEFAULT_HEAD_SPEC
            viewport_bvh.on_leaf_static_changed(s_idx, leaf)
        end
    end

    local proj_unit = reticle.projector_unit
    if proj_unit then
        local proj = storage.active_projectors and storage.active_projectors[proj_unit]
        if not (proj and proj.valid and projector_settings.is_powered(proj) and projector_settings.is_projector_enabled(proj)) then
            return
        end
    end

    local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[proj_unit]
    local muzzle_node = nil
    if u_ports then
        for i = 1, #u_ports do
            local mn = storage.flow_nodes and storage.flow_nodes[u_ports[i]]
            if mn and (mn.is_muzzle or mn.kinetic_transmit) then
                muzzle_node = mn
                break
            end
        end
    end

    local max_reach = (muzzle_node and flow_kinetic.get_node_kinetic_emitter(muzzle_node)) or reticle.max_reach or 50
    reticle.max_reach = max_reach
    local cur_dist = reticle.total_dist or 0
    if cur_dist >= max_reach then return end

    if reticle.anti_flight_id then
        local anti = timed_motion.get_flight(reticle.anti_flight_id)
        if anti then
            local extra = max_reach - (anti.max_distance or cur_dist)
            if extra > 0 then
                anti.remaining_distance = (anti.remaining_distance or 0) + extra
                anti.max_distance = max_reach
            end
        end
    end

    local dx = reticle.dir.x
    local dy = reticle.dir.y
    local s_idx = reticle.surface_index or 1
    local surface = game.surfaces[reticle.surface_name or "nauvis"]
    if not (surface and surface.valid) then return end

    local cur_seg_idx = math.max(1, math.floor(cur_dist / 16) + 1)
    local seg_boundary = cur_seg_idx * 16
    local dist_to_boundary = seg_boundary - cur_dist

    local rem_reach = max_reach - cur_dist
    local step = math.min(dist_to_boundary, rem_reach)
    if step <= 0.05 then
        cur_seg_idx = cur_seg_idx + 1
        seg_boundary = cur_seg_idx * 16
        dist_to_boundary = 16
        step = math.min(16, rem_reach)
    end

    local cur_pos = { x = reticle.terminal_pos.x, y = reticle.terminal_pos.y }
    local obst = flow_kinetic.scan_leaf_rect(surface, cur_pos, reticle.dir, step, proj_unit, reticle_id)
    local next_obst_entity = nil
    if obst and obst.dist then
        step = math.max(0.1, obst.dist)
        rem_reach = step
        next_obst_entity = obst.entity
    end

    local target_pos = {
        x = cur_pos.x + dx * step,
        y = cur_pos.y + dy * step
    }

    local target_seg_key = string.format("%d,%d:%d", dx, dy, cur_seg_idx)
    local d_start = (cur_seg_idx - 1) * 16
    local new_d_end = cur_dist + step
    local seg_start_pos = {
        x = reticle.start_pos.x + dx * d_start,
        y = reticle.start_pos.y + dy * d_start
    }

    local motion_tree = timed_motion.get_motion_tree(s_idx)
    if motion_tree then
        if reticle.seg_key and reticle.seg_key ~= target_seg_key then
            local owner_rec = motion_tree.trajectories and motion_tree.trajectories[reticle_id]
            local prev_leaf = owner_rec and owner_rec.segments and owner_rec.segments[reticle.seg_key]
            if prev_leaf and prev_leaf.static_render_spec then
                prev_leaf.static_pos = nil
                prev_leaf.static_render_spec = nil
                viewport_bvh.on_leaf_static_changed(s_idx, prev_leaf)
            end
        end
        local leaf = motion_tree:insert_segment(reticle_id, target_seg_key, seg_start_pos, target_pos, d_start, new_d_end, cur_seg_idx)
        if leaf then
            leaf.static_pos = nil
            leaf.static_render_spec = nil
            leaf.has_trail = nil
            leaf.dir = { x = dx, y = dy }
            leaf.q_level = reticle.q_level or 0
            leaf.trail_count = math.max(0, math.floor(cur_dist - d_start))
            viewport_bvh.on_segment_registered(s_idx, leaf)
            viewport_bvh.on_leaf_static_changed(s_idx, leaf)
        end
    end

    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    if traj_tree then
        traj_tree:insert_segment(reticle_id, target_seg_key, seg_start_pos, target_pos, d_start, new_d_end, cur_seg_idx)
        trajectory_bvh.refresh_active_renders()
    end

    reticle.status = "growing"
    reticle.head_flight_id = reticle_id
    reticle.terminal_pos = { x = target_pos.x, y = target_pos.y }
    reticle.endpoint_pos = { x = target_pos.x, y = target_pos.y }
    reticle.total_dist = new_d_end
    reticle.seg_key = target_seg_key

    if storage.projector_scope and proj_unit then
        storage.projector_scope[proj_unit] = {
            reticle_id = reticle_id,
            flight_id = reticle_id,
            status = "traveling",
            receiver_unit = nil
        }
    end

    if next_obst_entity then
        flow_kinetic.register_reticle_obstacle(reticle_id, next_obst_entity)
        local is_receiver = (proj_unit ~= nil) and next_obst_entity.valid and (next_obst_entity.name == "pneumatic-projector")
        reticle.pending_receiver = is_receiver and next_obst_entity.unit_number or nil
    end

    local tpt = reticle.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE
    flow_kinetic.launch_timed_flight{
        id = reticle_id,
        owner_id = reticle_id,
        surface_name = reticle.surface_name,
        start_pos = cur_pos,
        terminal_pos = target_pos,
        dir = { x = dx, y = dy },
        kind = "projector_scope",
        on_arrival = "projector_scope",
        remaining_distance = rem_reach,
        max_distance = max_reach,
        seg_idx = cur_seg_idx,
        reticle_id = reticle_id,
        projector_unit = proj_unit,
        q_level = reticle.q_level or 0,
        ticks_per_tile = tpt,
        flight_start_dist = cur_dist,
        render_spec = DEFAULT_HEAD_SPEC
    }
end

function flow_kinetic.handle_reticle_obstacle_cleared(entity)
    if not (entity and storage.projector_reticles) then return end
    local u_num = entity.unit_number
    local to_wake = {}

    if u_num and storage.blocked_reticles and storage.blocked_reticles[u_num] then
        for rid in pairs(storage.blocked_reticles[u_num]) do
            local blocked_by = storage.reticle_blocked_by and storage.reticle_blocked_by[rid]
            if not blocked_by or blocked_by.unit_number == u_num then
                to_wake[#to_wake + 1] = rid
            end
        end
        storage.blocked_reticles[u_num] = nil
    end

    for i = 1, #to_wake do
        local rid = to_wake[i]
        local ret = storage.projector_reticles[rid]
        if ret then
            local cur_flight = ret.head_flight_id and timed_motion.get_flight(ret.head_flight_id)
            local is_flying = (ret.status == "growing" and cur_flight ~= nil)

            if is_flying then
                flow_kinetic.unregister_reticle_obstacle(rid)
                local prev_receiver = ret.hit_receiver
                local proj_unit = ret.projector_unit
                ret.pending_receiver = nil
                ret.hit_receiver = nil
                ret.head_render_spec = DEFAULT_HEAD_SPEC
                cur_flight.render_spec = DEFAULT_HEAD_SPEC
                if prev_receiver and proj_unit then
                    flow_kinetic.unlink_projector_receiver(proj_unit, ret.surface_index, ret.surface_name)
                elseif proj_unit and storage.projector_scope and storage.projector_scope[proj_unit] then
                    storage.projector_scope[proj_unit].receiver_unit = nil
                end
                local full_reach = ret.max_reach or 50
                ret.max_range = full_reach
                ret.total_dist = full_reach
                local flight_start = cur_flight.flight_start_dist or (((cur_flight.seg_idx or 1) - 1) * 16)
                cur_flight.remaining_distance = math.max(0, full_reach - flight_start)
            else
                flow_kinetic.resume_reticle_probing(ret)
            end
        end
    end
end

function flow_kinetic.purge_retreating_reticle(reticle_id)
    local ret = storage.projector_reticles and storage.projector_reticles[reticle_id]
    if not ret then return end

    if ret.anti_flight_id then
        timed_motion.remove_flight(ret.anti_flight_id, reticle_id)
    end
    if ret.head_flight_id then
        timed_motion.remove_flight(ret.head_flight_id, reticle_id)
    end

    local s_idx = reticle.surface_index or 1
    if storage.pinned_corridors then
        storage.pinned_corridors[reticle_id] = nil
    end

    timed_motion.remove_corridor(s_idx, reticle_id)
    flow_kinetic.unregister_trajectory_in_bvh(reticle_id, ret.surface_name, true)
    viewport_bvh.on_segment_removed(s_idx, reticle_id)
    storage.projector_reticles[reticle_id] = nil
end

function flow_kinetic.get_obstacle_chain_bounds(surface, sp, dir, hit_entity, min_dist, max_dist)
    if not (surface and surface.valid and sp and dir and hit_entity and hit_entity.valid) then
        return nil, nil
    end
    local dx = dir.x or 0
    local dy = dir.y or 0
    if dx == 0 and dy == 0 then return nil, nil end

    local function get_bounds(ent)
        if not (ent and ent.valid and ent.bounding_box) then return nil, nil end
        local cbb = get_entity_bounding_box(ent)
        local on_axis = false
        local c_entry = nil
        local c_exit = nil

        if dx > 0 then
            on_axis = (cbb.left_top.y - 0.05 <= sp.y and sp.y <= cbb.right_bottom.y + 0.05)
            c_entry = cbb.left_top.x - sp.x
            c_exit = cbb.right_bottom.x - sp.x
        elseif dx < 0 then
            on_axis = (cbb.left_top.y - 0.05 <= sp.y and sp.y <= cbb.right_bottom.y + 0.05)
            c_entry = sp.x - cbb.right_bottom.x
            c_exit = sp.x - cbb.left_top.x
        elseif dy > 0 then
            on_axis = (cbb.left_top.x - 0.05 <= sp.x and sp.x <= cbb.right_bottom.x + 0.05)
            c_entry = cbb.left_top.y - sp.y
            c_exit = cbb.right_bottom.y - sp.y
        elseif dy < 0 then
            on_axis = (cbb.left_top.x - 0.05 <= sp.x and sp.x <= cbb.right_bottom.x + 0.05)
            c_entry = sp.y - cbb.right_bottom.y
            c_exit = sp.y - cbb.left_top.y
        end

        if on_axis and c_entry and c_exit then
            return c_entry, c_exit
        end
        return nil, nil
    end

    local e_entry, e_exit = get_bounds(hit_entity)
    if not (e_entry and e_exit) then return nil, nil end

    local cur_entry = e_entry
    local cur_exit = e_exit

    local min_x, max_x, min_y, max_y
    if dx ~= 0 then
        min_x = math.min(sp.x + dx * min_dist, sp.x + dx * max_dist)
        max_x = math.max(sp.x + dx * min_dist, sp.x + dx * max_dist)
        min_y = sp.y - 0.45
        max_y = sp.y + 0.45
    else
        min_x = sp.x - 0.45
        max_x = sp.x + 0.45
        min_y = math.min(sp.y + dy * min_dist, sp.y + dy * max_dist)
        max_y = math.max(sp.y + dy * min_dist, sp.y + dy * max_dist)
    end

    local candidates = surface.find_entities_filtered{
        area = {{min_x, min_y}, {max_x, max_y}}
    }

    local intervals = {}
    for _, cand in ipairs(candidates) do
        if cand.valid and not (IGNORABLE_TYPES[cand.type] or PROXY_NAMES[cand.name]) then
            local is_ignorable = false
            if cand.type == "gate" and not (cand.is_closed and cand.is_closed()) then
                is_ignorable = true
            end
            if not is_ignorable then
                local c_en, c_ex = get_bounds(cand)
                if c_en and c_ex then
                    intervals[#intervals + 1] = { entry = c_en, exit = c_ex }
                end
            end
        end
    end

    local changed = true
    while changed do
        changed = false
        for i = 1, #intervals do
            local inv = intervals[i]
            if not inv.used then
                if inv.entry <= (cur_exit + 0.75) and inv.exit >= (cur_entry - 0.75) then
                    if inv.entry < cur_entry then
                        cur_entry = inv.entry
                        changed = true
                    end
                    if inv.exit > cur_exit then
                        cur_exit = inv.exit
                        changed = true
                    end
                    inv.used = true
                end
            end
        end
    end

    cur_entry = math.max(min_dist, cur_entry)
    cur_exit = math.min(max_dist, cur_exit)
    return cur_entry, cur_exit
end

function flow_kinetic.find_obstacle_chain_exit(surface, sp, dir, entry_dist, max_dist, initial_entity)
    local cur_exit = entry_dist
    local dx = dir.x or 0
    local dy = dir.y or 0
    if not (surface and surface.valid and sp and (dx ~= 0 or dy ~= 0)) then
        return cur_exit
    end

    local function get_entity_bounds(ent)
        if not (ent and ent.valid and ent.bounding_box) then return nil, nil end
        local cbb = get_entity_bounding_box(ent)
        local on_axis = false
        local c_entry = nil
        local c_exit = nil

        if dx > 0 then
            on_axis = (cbb.left_top.y - 0.05 <= sp.y and sp.y <= cbb.right_bottom.y + 0.05)
            c_entry = cbb.left_top.x - sp.x
            c_exit = cbb.right_bottom.x - sp.x
        elseif dx < 0 then
            on_axis = (cbb.left_top.y - 0.05 <= sp.y and sp.y <= cbb.right_bottom.y + 0.05)
            c_entry = sp.x - cbb.right_bottom.x
            c_exit = sp.x - cbb.left_top.x
        elseif dy > 0 then
            on_axis = (cbb.left_top.x - 0.05 <= sp.x and sp.x <= cbb.right_bottom.x + 0.05)
            c_entry = cbb.left_top.y - sp.y
            c_exit = cbb.right_bottom.y - sp.y
        elseif dy < 0 then
            on_axis = (cbb.left_top.x - 0.05 <= sp.x and sp.x <= cbb.right_bottom.x + 0.05)
            c_entry = sp.y - cbb.right_bottom.y
            c_exit = sp.y - cbb.left_top.y
        end

        if on_axis and c_entry and c_exit then
            return c_entry, c_exit
        end
        return nil, nil
    end

    if initial_entity then
        local _, i_exit = get_entity_bounds(initial_entity)
        if i_exit and i_exit > cur_exit then
            cur_exit = i_exit
        end
    end

    if cur_exit >= max_dist then
        return max_dist
    end

    local min_x, max_x, min_y, max_y
    if dx ~= 0 then
        min_x = math.min(sp.x + dx * entry_dist, sp.x + dx * max_dist)
        max_x = math.max(sp.x + dx * entry_dist, sp.x + dx * max_dist)
        min_y = sp.y - 0.45
        max_y = sp.y + 0.45
    else
        min_x = sp.x - 0.45
        max_x = sp.x + 0.45
        min_y = math.min(sp.y + dy * entry_dist, sp.y + dy * max_dist)
        max_y = math.max(sp.y + dy * entry_dist, sp.y + dy * max_dist)
    end

    local candidates = surface.find_entities_filtered{
        area = {{min_x, min_y}, {max_x, max_y}}
    }

    local intervals = {}
    for _, cand in ipairs(candidates) do
        if cand.valid and not (IGNORABLE_TYPES[cand.type] or PROXY_NAMES[cand.name]) then
            local is_ignorable = false
            if cand.type == "gate" and not (cand.is_closed and cand.is_closed()) then
                is_ignorable = true
            end
            if not is_ignorable then
                local c_entry, c_exit = get_entity_bounds(cand)
                if c_entry and c_exit and c_exit > entry_dist then
                    intervals[#intervals + 1] = { entry = c_entry, exit = c_exit }
                end
            end
        end
    end

    local extended = true
    while extended do
        extended = false
        for i = 1, #intervals do
            local inv = intervals[i]
            if inv.entry <= (cur_exit + 0.75) and inv.exit > cur_exit then
                cur_exit = inv.exit
                extended = true
                if cur_exit >= max_dist then
                    return max_dist
                end
            end
        end
    end

    return math.min(max_dist, cur_exit)
end

function flow_kinetic.truncate_reticle(reticle, obst_dist, obstacle_entity)
    if not (reticle and obst_dist) then return end
    local max_dist = reticle.max_reach or reticle.total_dist or reticle.max_range or 50
    if obst_dist >= max_dist then return end

    local s_idx = reticle.surface_index or 1
    local motion_tree = timed_motion.get_motion_tree(s_idx)
    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    local reticle_id = reticle.id
    local dx = reticle.dir.x
    local dy = reticle.dir.y
    local sp = reticle.start_pos
    local surface = game.surfaces[reticle.surface_name or "nauvis"]

    local chain_entry, chain_exit = flow_kinetic.get_obstacle_chain_bounds(surface, sp, reticle.dir, obstacle_entity, 0, max_dist)
    local entry_dist = chain_entry or obst_dist
    local exit_dist = chain_exit or obst_dist

    local prev_blocked_by = storage.reticle_blocked_by and storage.reticle_blocked_by[reticle.id]

    if obstacle_entity and obstacle_entity.valid then
        flow_kinetic.register_reticle_obstacle(reticle.id, obstacle_entity)
    end

    local collision_pos = {
        x = sp.x + dx * entry_dist,
        y = sp.y + dy * entry_dist
    }

    local is_live = false
    if reticle.projector_unit and reticle.status ~= "retreating" then
        local proj = storage.active_projectors and storage.active_projectors[reticle.projector_unit]
        if proj and proj.valid and projector_settings.is_powered(proj) and projector_settings.is_projector_enabled(proj) then
            is_live = true
        end
    end

    local is_receiver = (reticle.projector_unit ~= nil) and obstacle_entity and obstacle_entity.valid and (obstacle_entity.name == "pneumatic-projector")
    local hit_rec_unit = is_receiver and obstacle_entity.unit_number or nil
    local prev_receiver = reticle.hit_receiver
    reticle.pending_receiver = nil
    reticle.hit_receiver = hit_rec_unit
    if prev_receiver and prev_receiver ~= hit_rec_unit and reticle.projector_unit then
        flow_kinetic.unlink_projector_receiver(reticle.projector_unit, s_idx, reticle.surface_name)
    end

    local head_spec = is_receiver and RECEIVER_HEAD_SPEC or DEFAULT_HEAD_SPEC
    reticle.head_render_spec = head_spec
    local hazard_spec = head_spec

    local full_reach = reticle.max_reach or reticle.max_range or 50
    local old_total_dist = reticle.total_dist or reticle.max_range or full_reach
    local cur_flight = reticle.head_flight_id and timed_motion.get_flight(reticle.head_flight_id)
    local was_growing = (reticle.status == "growing" and cur_flight ~= nil)
    local cur_h_dist = nil

    if was_growing then
        local cur_pos = timed_motion.get_interpolated_position(cur_flight, game.tick)
        cur_h_dist = cur_pos and (math.abs(cur_pos.x - sp.x) + math.abs(cur_pos.y - sp.y))
    end

    if was_growing and cur_h_dist and entry_dist > (cur_h_dist + 0.05) then
        flow_kinetic.update_reticle_horizon(reticle, entry_dist, obstacle_entity, cur_flight)
        return
    end

    local head_was_severed = was_growing and cur_h_dist and (cur_h_dist > exit_dist + 0.2)

    if not head_was_severed and cur_h_dist and cur_h_dist < old_total_dist then
        old_total_dist = cur_h_dist
    end

    local head_pos = { x = sp.x + dx * old_total_dist, y = sp.y + dy * old_total_dist }

    reticle.total_dist = entry_dist
    reticle.terminal_pos = { x = collision_pos.x, y = collision_pos.y }
    reticle.endpoint_pos = { x = collision_pos.x, y = collision_pos.y }

    if not head_was_severed and reticle.head_flight_id then
        timed_motion.remove_flight(reticle.head_flight_id, reticle_id)
    end
    reticle.head_flight_id = nil
    if reticle.status == "growing" then
        reticle.status = "stationary"
    end

    if reticle.anti_flight_id then
        local anti = timed_motion.get_flight(reticle.anti_flight_id)
        if anti and (anti.remaining_distance or 0) > obst_dist then
            anti.remaining_distance = obst_dist
        end
    end

    local target_seg_idx = math.max(1, math.floor(obst_dist / 16) + 1)
    reticle.seg_key = string.format("%d,%d:%d", dx, dy, target_seg_idx)

    if motion_tree and motion_tree.trajectories and motion_tree.trajectories[reticle_id] then
        local owner_rec = motion_tree.trajectories[reticle_id]
        if owner_rec.segments then
            local to_remove = {}
            for seg_key, leaf in pairs(owner_rec.segments) do
                local s_idx_num = leaf.seg_idx or tonumber(seg_key:match(":(%d+)$")) or 1
                if s_idx_num > target_seg_idx then
                    to_remove[#to_remove + 1] = seg_key
                elseif s_idx_num == target_seg_idx then
                    leaf.d_end = entry_dist
                    leaf.end_pos = { x = collision_pos.x, y = collision_pos.y }
                    leaf.trail_count = math.max(0, math.floor(entry_dist - leaf.d_start))
                    leaf.static_pos = { x = collision_pos.x, y = collision_pos.y }
                    leaf.static_render_spec = hazard_spec
                    leaf.min_x = math.min(leaf.start_pos.x, collision_pos.x) - 0.45
                    leaf.max_x = math.max(leaf.start_pos.x, collision_pos.x) + 0.45
                    leaf.min_y = math.min(leaf.start_pos.y, collision_pos.y) - 0.45
                    leaf.max_y = math.max(leaf.start_pos.y, collision_pos.y) + 0.45
                    viewport_bvh.on_leaf_static_changed(s_idx, leaf)
                else
                    leaf.static_pos = nil
                    leaf.static_render_spec = nil
                end
            end

            for i = 1, #to_remove do
                local r_key = to_remove[i]
                motion_tree:remove_segment(reticle_id, r_key)
                if traj_tree then
                    traj_tree:remove_segment(reticle_id, r_key)
                end
                viewport_bvh.on_segment_removed(s_idx, reticle_id, r_key)
            end
        end
    end

    if traj_tree and traj_tree.trajectories and traj_tree.trajectories[reticle_id] then
        local t_rec = traj_tree.trajectories[reticle_id]
        if t_rec.segments then
            local to_remove_traj = {}
            for seg_key, leaf in pairs(t_rec.segments) do
                local s_idx_num = leaf.seg_idx or tonumber(seg_key:match(":(%d+)$")) or 1
                if s_idx_num > target_seg_idx then
                    to_remove_traj[#to_remove_traj + 1] = seg_key
                elseif s_idx_num == target_seg_idx then
                    leaf.d_end = entry_dist
                    leaf.end_pos = { x = collision_pos.x, y = collision_pos.y }
                    leaf.min_x = math.min(leaf.start_pos.x, collision_pos.x) - 0.45
                    leaf.max_x = math.max(leaf.start_pos.x, collision_pos.x) + 0.45
                    leaf.min_y = math.min(leaf.start_pos.y, collision_pos.y) - 0.45
                    leaf.max_y = math.max(leaf.start_pos.y, collision_pos.y) + 0.45
                end
            end
            for i = 1, #to_remove_traj do
                traj_tree:remove_segment(reticle_id, to_remove_traj[i])
            end
            trajectory_bvh.refresh_active_renders()
        end
    end

    if reticle.projector_unit and storage.projector_scope then
        storage.projector_scope[reticle.projector_unit] = {
            reticle_id = reticle_id,
            status = "endpoint",
            endpoint_pos = { x = collision_pos.x, y = collision_pos.y },
            surface_name = reticle.surface_name,
            seg_key = reticle.seg_key,
            receiver_unit = hit_rec_unit
        }
    end

    if is_receiver and hit_rec_unit and reticle.projector_unit and flow_kinetic.notify_projector_receiver_docked then
        flow_kinetic.notify_projector_receiver_docked(reticle.projector_unit, hit_rec_unit, reticle_id)
    end

    local downstream_dist = (head_was_severed and (full_reach - exit_dist)) or (old_total_dist - exit_dist)

    local is_split_candidate = (reticle.projector_unit ~= nil)

    if downstream_dist <= 0.2 or not is_split_candidate then
        if head_was_severed and cur_flight then
            timed_motion.remove_flight(cur_flight.id, reticle_id)
        end
        return
    end

    if downstream_dist > 0.2 then
        storage.next_reticle_id = (storage.next_reticle_id or 0) + 1
        local down_id = storage.next_reticle_id
        reticle.downstream_reticle_id = down_id

        local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or reticle.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE
        local down_term = head_was_severed and { x = sp.x + dx * full_reach, y = sp.y + dy * full_reach } or head_pos
        local down_dist = head_was_severed and full_reach or old_total_dist
        local exit_seg_idx = math.max(1, math.floor(exit_dist / 16) + 1)
        local max_seg_idx = math.max(1, math.floor(down_dist / 16) + 1)
        local cur_flight_seg = head_was_severed and (cur_flight.seg_idx or exit_seg_idx) or max_seg_idx

        storage.projector_reticles[down_id] = {
            id = down_id,
            projector_unit = nil,
            surface_name = reticle.surface_name,
            surface_index = s_idx,
            start_pos = { x = sp.x, y = sp.y },
            terminal_pos = { x = down_term.x, y = down_term.y },
            endpoint_pos = { x = down_term.x, y = down_term.y },
            dir = { x = dx, y = dy },
            q_level = reticle.q_level or 0,
            max_reach = full_reach,
            max_range = down_dist,
            total_dist = down_dist,
            status = head_was_severed and "growing" or "stationary",
            start_tick = reticle.start_tick or game.tick,
            retreat_tick = game.tick - math.floor(exit_dist * tpt),
            ticks_per_tile = tpt,
            seg_key = string.format("%d,%d:%d", dx, dy, cur_flight_seg),
            head_render_spec = DEFAULT_HEAD_SPEC,
            head_flight_id = head_was_severed and down_id or nil
        }

        storage.pinned_corridors = storage.pinned_corridors or {}
        storage.pinned_corridors[down_id] = true

        if not head_was_severed then
            local registered_obstacle = false
            if prev_blocked_by and prev_blocked_by.unit_number then
                local u_num = prev_blocked_by.unit_number
                local reg_id = prev_blocked_by.reg_id
                storage.blocked_reticles = storage.blocked_reticles or {}
                storage.blocked_reticles[u_num] = storage.blocked_reticles[u_num] or {}
                storage.blocked_reticles[u_num][down_id] = true
                if reg_id then
                    storage.blocked_reticles_by_reg = storage.blocked_reticles_by_reg or {}
                    storage.blocked_reticles_by_reg[reg_id] = storage.blocked_reticles_by_reg[reg_id] or {}
                    storage.blocked_reticles_by_reg[reg_id][down_id] = true
                end
                storage.reticle_blocked_by = storage.reticle_blocked_by or {}
                storage.reticle_blocked_by[down_id] = {
                    unit_number = u_num,
                    reg_id = reg_id
                }
                registered_obstacle = true
            end

            if not registered_obstacle and surface and surface.valid and down_dist < (full_reach - 0.05) then
                local cands = surface.find_entities_filtered{
                    area = {{down_term.x - 0.5, down_term.y - 0.5}, {down_term.x + 0.5, down_term.y + 0.5}}
                }
                for _, cand in ipairs(cands) do
                    if cand.valid and not (IGNORABLE_TYPES[cand.type] or PROXY_NAMES[cand.name]) then
                        local is_ignorable = false
                        if cand.type == "gate" and not (cand.is_closed and cand.is_closed()) then
                            is_ignorable = true
                        end
                        if not is_ignorable then
                            flow_kinetic.register_reticle_obstacle(down_id, cand)
                            break
                        end
                    end
                end
            end

            if storage.reticle_gates and storage.reticle_gates[reticle.id] then
                for g_unit, g_data in pairs(storage.reticle_gates[reticle.id]) do
                    if g_data.dist > (exit_dist + 0.05) then
                        storage.reticle_gates[down_id] = storage.reticle_gates[down_id] or {}
                        storage.reticle_gates[down_id][g_unit] = g_data
                    end
                end
            end
        end
        local seg_boundary = exit_seg_idx * 16
        local dist_to_boundary = seg_boundary - exit_dist

        local populate_up_to_seg = head_was_severed and cur_flight_seg or max_seg_idx

        for s = exit_seg_idx, populate_up_to_seg do
            local s_start = (s - 1) * 16
            local is_active_seg = head_was_severed and (s == cur_flight_seg)
            local s_end
            if is_active_seg then
                local f_start = cur_flight.flight_start_dist or s_start
                s_end = f_start + cur_flight.total_dist
            else
                s_end = math.min(s * 16, down_dist)
            end

            if s_end > (exit_dist + 0.05) then
                local s_key = string.format("%d,%d:%d", dx, dy, s)
                local seg_start_pos = { x = sp.x + dx * s_start, y = sp.y + dy * s_start }
                local seg_end_pos = { x = sp.x + dx * s_end, y = sp.y + dy * s_end }
                local is_last_seg = (s == max_seg_idx or s_end >= down_dist - 0.05)

                if traj_tree then
                    traj_tree:insert_segment(down_id, s_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
                end

                if motion_tree then
                    local leaf = motion_tree:insert_segment(down_id, s_key, seg_start_pos, seg_end_pos, s_start, s_end, s)
                    if leaf then
                        leaf.dir = { x = dx, y = dy }
                        leaf.q_level = reticle.q_level or 0
                        if is_active_seg then
                            leaf.has_trail = nil
                            leaf.trail_count = nil
                            leaf.static_render_spec = nil
                            leaf.static_pos = nil
                        else
                            leaf.has_trail = true
                            leaf.trail_count = math.max(0, math.floor(s_end - s_start))
                            if is_last_seg and not head_was_severed then
                                leaf.static_render_spec = DEFAULT_HEAD_SPEC
                                leaf.static_pos = { x = down_term.x, y = down_term.y }
                            else
                                leaf.static_render_spec = nil
                                leaf.static_pos = nil
                            end
                        end
                        viewport_bvh.on_segment_registered(s_idx, leaf)
                    end
                end
            end
        end

        if traj_tree then
            trajectory_bvh.refresh_active_renders()
        end

        if head_was_severed then
            local heap = timed_motion.get_arrival_heap()
            if heap then
                heap:remove(cur_flight.id)
            end
            timed_motion.remove_flight(cur_flight.id, reticle.id)

            cur_flight.id = down_id
            cur_flight.owner_id = down_id
            cur_flight.reticle_id = down_id
            cur_flight.projector_unit = nil
            timed_motion.schedule_flight(cur_flight)
        end

        local rem_dist = down_dist - exit_dist
        local anti_seg_idx = exit_seg_idx
        local anti_start = { x = sp.x + dx * exit_dist, y = sp.y + dy * exit_dist }
        local first_step = math.min(dist_to_boundary, rem_dist)

        if dist_to_boundary <= 0.05 and rem_dist > dist_to_boundary then
            anti_seg_idx = exit_seg_idx + 1
            anti_start = { x = sp.x + dx * seg_boundary, y = sp.y + dy * seg_boundary }
            rem_dist = rem_dist - dist_to_boundary
            first_step = math.min(16, rem_dist)
        end

        local anti_flight_id = "anti:" .. tostring(down_id)
        storage.projector_reticles[down_id].anti_flight_id = anti_flight_id

        local anti_next_term = {
            x = anti_start.x + dx * first_step,
            y = anti_start.y + dy * first_step
        }

        flow_kinetic.launch_timed_flight{
            id = anti_flight_id,
            owner_id = down_id,
            surface_name = reticle.surface_name,
            start_pos = anti_start,
            terminal_pos = anti_next_term,
            dir = { x = dx, y = dy },
            kind = "anti_reticle",
            on_arrival = "anti_reticle",
            remaining_distance = rem_dist,
            max_distance = rem_dist,
            seg_idx = anti_seg_idx,
            reticle_id = down_id,
            ticks_per_tile = tpt
        }
    end
end

function flow_kinetic.update_reticle_horizon(reticle, obst_dist, obstacle_entity, flight)
    if not (reticle and obst_dist and obst_dist > 0) then return end
    flight = flight or (reticle.head_flight_id and timed_motion.get_flight(reticle.head_flight_id))
    if not flight then return end

    local is_receiver = (reticle.projector_unit ~= nil) and obstacle_entity and obstacle_entity.valid and (obstacle_entity.name == "pneumatic-projector")
    local prev_receiver = reticle.hit_receiver
    reticle.pending_receiver = is_receiver and obstacle_entity.unit_number or nil
    reticle.hit_receiver = nil
    reticle.head_render_spec = DEFAULT_HEAD_SPEC
    if prev_receiver and reticle.projector_unit then
        flow_kinetic.unlink_projector_receiver(reticle.projector_unit, s_idx, reticle.surface_name)
    end
    flight.render_spec = DEFAULT_HEAD_SPEC
    flight.projector_unit = flight.projector_unit or reticle.projector_unit
    flight.reticle_id = flight.reticle_id or reticle.id

    if obstacle_entity and obstacle_entity.valid then
        flow_kinetic.register_reticle_obstacle(reticle.id, obstacle_entity)
    end

    local r_dx = reticle.dir.x
    local r_dy = reticle.dir.y
    local r_sp = reticle.start_pos
    local s_idx = reticle.surface_index or 1

    -- Clamp reticle maximum reach and target endpoint
    reticle.total_dist = obst_dist
    reticle.max_range = obst_dist
    local collision_pos = {
        x = r_sp.x + r_dx * obst_dist,
        y = r_sp.y + r_dy * obst_dist
    }
    reticle.terminal_pos = { x = collision_pos.x, y = collision_pos.y }
    reticle.endpoint_pos = { x = collision_pos.x, y = collision_pos.y }

    local flight_sp = flight.start_pos
    local flight_tp = flight.terminal_pos
    local flight_start_dist = math.abs(flight_sp.x - r_sp.x) + math.abs(flight_sp.y - r_sp.y)
    local seg_idx = flight.seg_idx or 1
    local seg_max_dist = seg_idx * 16

    if obst_dist <= (seg_max_dist + 0.001) then
        -- Obstacle lies within current flight segment: clamp this segment's target & arrival
        local seg_dist = obst_dist - flight_start_dist
        flight.terminal_pos = { x = collision_pos.x, y = collision_pos.y }
        flight.total_dist = seg_dist
        flight.remaining_distance = seg_dist

        local tpt = flight.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE
        local new_flight_ticks = math.max(1, math.ceil(seg_dist * tpt))
        local current_tick = game.tick
        local new_arrival_tick = flight.start_tick + new_flight_ticks
        if new_arrival_tick <= current_tick then
            new_arrival_tick = current_tick + 1
        end

        flight.flight_ticks = new_flight_ticks
        flight.arrival_tick = new_arrival_tick

        -- Update in active flights store
        local flights_store = storage.timed_flights or storage.projector_flights
        if flights_store and flight.owner_id and flights_store[flight.owner_id] then
            local flights = flights_store[flight.owner_id]
            for f = 1, #flights do
                if flights[f].id == flight.id or flights[f].capsule_id == flight.id then
                    flights[f].arrival_tick = new_arrival_tick
                    flights[f].duration = new_flight_ticks
                    break
                end
            end
        end

        -- Re-balance binary arrival heap
        local heap = timed_motion.get_arrival_heap()
        if heap then
            heap:remove(flight.id)
            heap:push(flight.id, new_arrival_tick, flight.id)
        end

        -- Update leaf geometry in motion and trajectory BVH
        local seg_key = string.format("%d,%d:%d", r_dx, r_dy, flight.seg_idx or 1)
        local motion_tree = timed_motion.get_motion_tree(s_idx)
        if motion_tree and motion_tree.trajectories and motion_tree.trajectories[reticle.id] then
            local owner_rec = motion_tree.trajectories[reticle.id]
            local leaf = owner_rec and owner_rec.segments and owner_rec.segments[seg_key]
            if leaf then
                leaf.d_end = obst_dist
                leaf.end_pos = { x = collision_pos.x, y = collision_pos.y }
                leaf.min_x = math.min(leaf.start_pos.x, collision_pos.x) - 0.45
                leaf.max_x = math.max(leaf.start_pos.x, collision_pos.x) + 0.45
                leaf.min_y = math.min(leaf.start_pos.y, collision_pos.y) - 0.45
                leaf.max_y = math.max(leaf.start_pos.y, collision_pos.y) + 0.45
            end
        end
        local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
        if traj_tree and traj_tree.trajectories and traj_tree.trajectories[reticle.id] then
            local owner_rec = traj_tree.trajectories[reticle.id]
            local leaf = owner_rec and owner_rec.segments and owner_rec.segments[seg_key]
            if leaf then
                leaf.d_end = obst_dist
                leaf.end_pos = { x = collision_pos.x, y = collision_pos.y }
                leaf.min_x = math.min(leaf.start_pos.x, collision_pos.x) - 0.45
                leaf.max_x = math.max(leaf.start_pos.x, collision_pos.x) + 0.45
                leaf.min_y = math.min(leaf.start_pos.y, collision_pos.y) - 0.45
                leaf.max_y = math.max(leaf.start_pos.y, collision_pos.y) + 0.45
            end
        end
    else
        -- Obstacle lies in a downstream segment: clamp flight's total remaining distance
        flight.remaining_distance = obst_dist - flight_start_dist
    end

    -- Prune any pre-existing segments beyond obst_dist
    local target_seg_idx = math.max(1, math.floor(obst_dist / 16) + 1)
    local motion_tree = timed_motion.get_motion_tree(s_idx)
    local traj_tree = trajectory_bvh.get_surface_tree(storage, s_idx)
    if motion_tree and motion_tree.trajectories and motion_tree.trajectories[reticle.id] then
        local owner_rec = motion_tree.trajectories[reticle.id]
        if owner_rec.segments then
            local to_remove = {}
            for k, leaf in pairs(owner_rec.segments) do
                local s_num = leaf.seg_idx or tonumber(k:match(":(%d+)$")) or 1
                if s_num > target_seg_idx then
                    to_remove[#to_remove + 1] = k
                end
            end
            for i = 1, #to_remove do
                local r_key = to_remove[i]
                motion_tree:remove_segment(reticle.id, r_key)
                if traj_tree then
                    traj_tree:remove_segment(reticle.id, r_key)
                end
                viewport_bvh.on_segment_removed(s_idx, reticle.id, r_key)
            end
        end
    end

    if traj_tree and traj_tree.trajectories and traj_tree.trajectories[reticle.id] then
        local t_rec = traj_tree.trajectories[reticle.id]
        if t_rec.segments then
            local to_remove_traj = {}
            for k, leaf in pairs(t_rec.segments) do
                local s_num = leaf.seg_idx or tonumber(k:match(":(%d+)$")) or 1
                if s_num > target_seg_idx then
                    to_remove_traj[#to_remove_traj + 1] = k
                end
            end
            for i = 1, #to_remove_traj do
                traj_tree:remove_segment(reticle.id, to_remove_traj[i])
            end
            trajectory_bvh.refresh_active_renders()
        end
    end
end

function flow_kinetic.queue_reticle_obstacle(r_id, entity, o_dist)
    if not (r_id and entity and entity.valid) then return end
    storage.pending_reticle_obstacles = storage.pending_reticle_obstacles or {}
    local r_queue = storage.pending_reticle_obstacles[r_id]
    if not r_queue then
        r_queue = {}
        storage.pending_reticle_obstacles[r_id] = r_queue
    end
    r_queue[#r_queue + 1] = {
        entity = entity,
        o_dist = o_dist
    }
end

function flow_kinetic.flush_pending_reticle_obstacles()
    local pending = storage.pending_reticle_obstacles
    if not (pending and next(pending) ~= nil) then return end
    storage.pending_reticle_obstacles = nil

    for r_id, queue in pairs(pending) do
        local ret = storage.projector_reticles and storage.projector_reticles[r_id]
        if ret then
            local r_dx = ret.dir.x
            local r_dy = ret.dir.y
            local r_sp = ret.start_pos
            local full_reach = ret.max_reach or 50
            local beam_reach = (ret.status == "growing" and full_reach) or ret.total_dist or ret.max_range or full_reach

            local closest_dist = math.huge
            local closest_entity = nil

            for i = 1, #queue do
                local item = queue[i]
                local ent = item.entity
                if ent and ent.valid then
                    local bb = get_entity_bounding_box(ent)
                    local o_dist = nil
                    local on_axis = false

                    if r_dx > 0 then
                        on_axis = (bb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= bb.right_bottom.y + 0.05)
                        o_dist = bb.left_top.x - r_sp.x
                    elseif r_dx < 0 then
                        on_axis = (bb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= bb.right_bottom.y + 0.05)
                        o_dist = r_sp.x - bb.right_bottom.x
                    elseif r_dy > 0 then
                        on_axis = (bb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= bb.right_bottom.x + 0.05)
                        o_dist = bb.left_top.y - r_sp.y
                    elseif r_dy < 0 then
                        on_axis = (bb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= bb.right_bottom.x + 0.05)
                        o_dist = r_sp.y - bb.right_bottom.y
                    end

                    local is_retreating = (ret.status == "retreating")
                    local is_behind_wake = false
                    if is_retreating and ret.retreat_tick then
                        local el_ret = math.max(0, game.tick - ret.retreat_tick)
                        local d_cleared = math.floor(el_ret / (ret.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE))
                        if o_dist and o_dist <= (d_cleared + 0.05) then
                            is_behind_wake = true
                        end
                    end

                    if on_axis and o_dist and o_dist > 0.05 and o_dist < beam_reach and not is_behind_wake then
                        if o_dist < closest_dist then
                            closest_dist = o_dist
                            closest_entity = ent
                        end
                    end
                end
            end

            if closest_entity and closest_dist < math.huge then
                local cur_flight = ret.head_flight_id and timed_motion.get_flight(ret.head_flight_id)
                local is_growing = (ret.status == "growing" and cur_flight ~= nil)
                local cur_head_dist = ret.total_dist or ret.max_range or full_reach

                if is_growing then
                    local cur_pos = timed_motion.get_interpolated_position(cur_flight, game.tick)
                    cur_head_dist = math.abs(cur_pos.x - r_sp.x) + math.abs(cur_pos.y - r_sp.y)
                end

                if is_growing and closest_dist > (cur_head_dist + 0.05) then
                    flow_kinetic.update_reticle_horizon(ret, closest_dist, closest_entity, cur_flight)
                elseif ret.projector_unit ~= nil then
                    flow_kinetic.truncate_reticle(ret, closest_dist, closest_entity)
                end

                local down_id = ret.downstream_reticle_id
                if down_id and storage.projector_reticles and storage.projector_reticles[down_id] then
                    local surf = game.surfaces[ret.surface_name or "nauvis"]
                    local _, down_exit = flow_kinetic.get_obstacle_chain_bounds(surf, r_sp, ret.dir, closest_entity, 0, full_reach)
                    local exit_d = down_exit or closest_dist
                    for i = 1, #queue do
                        local item = queue[i]
                        local ent = item.entity
                        if ent and ent.valid and item.o_dist and item.o_dist > (exit_d + 0.05) then
                            flow_kinetic.queue_reticle_obstacle(down_id, ent, item.o_dist)
                        end
                    end
                end
            end
        end
    end

    if storage.pending_reticle_obstacles and next(storage.pending_reticle_obstacles) ~= nil then
        flow_kinetic.flush_pending_reticle_obstacles()
    end
end

function flow_kinetic.handle_obstacle_changed_v2(entity, is_removal, enqueue_port_fn, wake_port_fn)
    if not (entity and entity.valid and entity.bounding_box) then return end
    if IGNORABLE_TYPES[entity.type] or PROXY_NAMES[entity.name] then return end
    local bb = get_entity_bounding_box(entity)
    local surface = entity.surface
    if not (surface and surface.valid) then return end

    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    local MARGIN = 2.5
    if storage.motion_bvh and storage.motion_bvh[surface.index] then
        local motion_tree = storage.motion_bvh[surface.index]
        local motion_hits = {}
        trajectory_bvh.query_box(motion_tree, bb.left_top.x - MARGIN, bb.left_top.y - MARGIN, bb.right_bottom.x + MARGIN, bb.right_bottom.y + MARGIN, motion_hits)
        if #motion_hits > 0 then
            if flow_kinetic.handle_motion_obstacle_changed then
                flow_kinetic.handle_motion_obstacle_changed(surface, entity, bb, is_removal, motion_hits)
            end

            if is_removal and storage.projector_reticles then
                flow_kinetic.handle_reticle_obstacle_cleared(entity)
            elseif not is_removal and storage.projector_reticles then
                local checked_owners = {}
                for i = 1, #motion_hits do
                    local hit_leaf = motion_hits[i]
                    local r_id = hit_leaf.owner_id
                    if r_id and not checked_owners[r_id] then
                        checked_owners[r_id] = true
                        local ret = storage.projector_reticles[r_id]
                        if ret then
                            local is_self = ret.projector_unit and (entity.unit_number == ret.projector_unit
                                or (storage.active_projectors and storage.active_projectors[ret.projector_unit] == entity))
                            if not is_self then
                                local r_dx = ret.dir.x
                                local r_dy = ret.dir.y
                                local r_sp = ret.start_pos
                                local o_dist = nil
                                local on_axis = false

                                if r_dx > 0 then
                                    on_axis = (bb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= bb.right_bottom.y + 0.05)
                                    o_dist = bb.left_top.x - r_sp.x
                                elseif r_dx < 0 then
                                    on_axis = (bb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= bb.right_bottom.y + 0.05)
                                    o_dist = r_sp.x - bb.right_bottom.x
                                elseif r_dy > 0 then
                                    on_axis = (bb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= bb.right_bottom.x + 0.05)
                                    o_dist = bb.left_top.y - r_sp.y
                                elseif r_dy < 0 then
                                    on_axis = (bb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= bb.right_bottom.x + 0.05)
                                    o_dist = r_sp.y - bb.right_bottom.y
                                end

                                local full_reach = ret.max_reach or 50
                                local beam_reach = (ret.status == "growing" and full_reach) or ret.total_dist or ret.max_range or full_reach

                                local is_retreating = (ret.status == "retreating")
                                local is_behind_wake = false
                                if is_retreating and ret.retreat_tick then
                                    local el_ret = math.max(0, game.tick - ret.retreat_tick)
                                    local d_cleared = math.floor(el_ret / (ret.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE))
                                    if o_dist and o_dist <= (d_cleared + 0.05) then
                                        is_behind_wake = true
                                    end
                                end

                                if on_axis and o_dist and o_dist > 0.05 and o_dist < beam_reach and not is_behind_wake then
                                    flow_kinetic.queue_reticle_obstacle(r_id, entity, o_dist)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return flow_kinetic._legacy_handle_obstacle_changed(entity, is_removal, enqueue_port_fn, wake_port_fn)
end

function flow_kinetic.dock_incoming_reticles_at_projector(entity)
    if not (entity and entity.valid and entity.bounding_box and entity.surface and entity.surface.valid) then return end
    local surface = entity.surface
    local s_idx = surface.index
    local motion_tree = storage.motion_bvh and storage.motion_bvh[s_idx]
    if not (motion_tree and storage.projector_reticles) then return end

    local bb = entity.bounding_box
    local EPSILON = 0.5
    local motion_hits = {}
    trajectory_bvh.query_box(motion_tree, bb.left_top.x - EPSILON, bb.left_top.y - EPSILON, bb.right_bottom.x + EPSILON, bb.right_bottom.y + EPSILON, motion_hits)
    if #motion_hits == 0 then return end

    local checked = {}
    for i = 1, #motion_hits do
        local r_id = motion_hits[i].owner_id
        if r_id and not checked[r_id] then
            checked[r_id] = true
            local ret = storage.projector_reticles[r_id]
            if ret and ret.projector_unit and ret.projector_unit ~= entity.unit_number and ret.status ~= "retreating" then
                local tp = ret.terminal_pos or ret.endpoint_pos
                if tp and tp.x >= bb.left_top.x - EPSILON and tp.x <= bb.right_bottom.x + EPSILON
                   and tp.y >= bb.left_top.y - EPSILON and tp.y <= bb.right_bottom.y + EPSILON then
                    ret.hit_receiver = entity.unit_number
                        ret.pending_receiver = nil
                        ret.head_render_spec = flow_kinetic.RECEIVER_HEAD_SPEC
                        flow_kinetic.register_reticle_obstacle(r_id, entity)
                        local m_tree = timed_motion.get_motion_tree(s_idx)
                        if m_tree and ret.seg_key then
                            local owner_rec = m_tree.trajectories and m_tree.trajectories[r_id]
                            local leaf = owner_rec and owner_rec.segments and owner_rec.segments[ret.seg_key]
                            if leaf then
                                leaf.static_render_spec = flow_kinetic.RECEIVER_HEAD_SPEC
                                viewport_bvh.on_leaf_static_changed(s_idx, leaf)
                            end
                        end
                        if storage.projector_scope and storage.projector_scope[ret.projector_unit] then
                            storage.projector_scope[ret.projector_unit].receiver_unit = entity.unit_number
                        end
                        if flow_kinetic.notify_projector_receiver_docked then
                            flow_kinetic.notify_projector_receiver_docked(ret.projector_unit, entity.unit_number, r_id)
                        end
                    end
            end
        end
    end
end

function flow_kinetic.handle_obstacle_changed(entity, is_removal, enqueue_port_fn, wake_port_fn)
    if not is_removal and entity and entity.valid and entity.name == "pneumatic-projector" then
        flow_kinetic.dock_incoming_reticles_at_projector(entity)
    end
    return flow_kinetic.handle_obstacle_changed_v2(entity, is_removal, enqueue_port_fn, wake_port_fn)
end

function flow_kinetic._legacy_handle_obstacle_changed(entity, is_removal, enqueue_port_fn, wake_port_fn)
    if not (entity and entity.valid and entity.bounding_box) then return end
    if IGNORABLE_TYPES[entity.type] or PROXY_NAMES[entity.name] then return end
    local bb = get_entity_bounding_box(entity)
    local surface = entity.surface
    if not (surface and surface.valid) then return end
    local surf_name = surface.name

    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    local MARGIN = 2.5
    if storage.motion_bvh and storage.motion_bvh[surface.index] then
        local motion_tree = storage.motion_bvh[surface.index]
        local motion_hits = {}
        trajectory_bvh.query_box(motion_tree, bb.left_top.x - MARGIN, bb.left_top.y - MARGIN, bb.right_bottom.x + MARGIN, bb.right_bottom.y + MARGIN, motion_hits)
        if #motion_hits > 0 then
            if flow_kinetic.handle_motion_obstacle_changed then
                flow_kinetic.handle_motion_obstacle_changed(surface, entity, bb, is_removal, motion_hits)
            end

            if is_removal and storage.projector_reticles then
                flow_kinetic.handle_reticle_obstacle_cleared(entity)
            elseif not is_removal and storage.projector_reticles then
                local checked_owners = {}
                for i = 1, #motion_hits do
                    local hit_leaf = motion_hits[i]
                    local r_id = hit_leaf.owner_id
                    if r_id and not checked_owners[r_id] then
                        checked_owners[r_id] = true
                        local ret = storage.projector_reticles[r_id]
                        if ret then
                            local is_self = ret.projector_unit and (entity.unit_number == ret.projector_unit
                                or (storage.active_projectors and storage.active_projectors[ret.projector_unit] == entity))
                            if not is_self then
                                local r_dx = ret.dir.x
                                local r_dy = ret.dir.y
                                local r_sp = ret.start_pos
                                local o_dist = nil
                                local on_axis = false

                                if r_dx > 0 then
                                    on_axis = (bb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= bb.right_bottom.y + 0.05)
                                    o_dist = bb.left_top.x - r_sp.x
                                elseif r_dx < 0 then
                                    on_axis = (bb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= bb.right_bottom.y + 0.05)
                                    o_dist = r_sp.x - bb.right_bottom.x
                                elseif r_dy > 0 then
                                    on_axis = (bb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= bb.right_bottom.x + 0.05)
                                    o_dist = bb.left_top.y - r_sp.y
                                elseif r_dy < 0 then
                                    on_axis = (bb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= bb.right_bottom.x + 0.05)
                                    o_dist = r_sp.y - bb.right_bottom.y
                                end

                                local full_reach = ret.max_reach or 50
                                local beam_reach = (ret.status == "growing" and full_reach) or ret.total_dist or ret.max_range or full_reach

                                local is_retreating = (ret.status == "retreating")
                                local is_behind_wake = false
                                if is_retreating and ret.retreat_tick then
                                    local el_ret = math.max(0, game.tick - ret.retreat_tick)
                                    local d_cleared = math.floor(el_ret / (ret.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE))
                                    if o_dist and o_dist <= (d_cleared + 0.05) then
                                        is_behind_wake = true
                                    end
                                end

                                if on_axis and o_dist and o_dist > 0.05 and o_dist < beam_reach and not is_behind_wake then
                                    flow_kinetic.queue_reticle_obstacle(r_id, entity, o_dist)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
    if not (tree and storage.active_projectors) then return end

    local hits = {}
    tree:query_box(bb.left_top.x - MARGIN, bb.left_top.y - MARGIN, bb.right_bottom.x + MARGIN, bb.right_bottom.y + MARGIN, hits)
    if #hits == 0 then return end

    local affected_owners = {}
    for i = 1, #hits do
        local leaf = hits[i]
        local owner_id = leaf.owner_id
        if owner_id then
            local ret = storage.projector_reticles and storage.projector_reticles[owner_id]
            if ret and ret.projector_unit then
                affected_owners[ret.projector_unit] = true
            elseif not affected_owners[owner_id] then
                affected_owners[owner_id] = true
            end
        end
    end

    for unit_number in pairs(affected_owners) do
        local proj = storage.active_projectors[unit_number]
        if proj and proj.valid and proj.surface.name == surf_name and proj ~= entity then
            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
            local muzzle_node = nil
            if u_ports then
                for i = 1, #u_ports do
                    local mn = storage.flow_nodes and storage.flow_nodes[u_ports[i]]
                    if mn and (mn.is_muzzle or mn.kinetic_transmit) and mn.dir then
                        muzzle_node = mn
                        break
                    end
                end
            end

            if muzzle_node and muzzle_node.dir then
                local dx = muzzle_node.dir.x
                local dy = muzzle_node.dir.y
                local mx = muzzle_node.pos.x
                local my = muzzle_node.pos.y

                local max_reach = flow_kinetic.get_node_kinetic_emitter(muzzle_node)
                if max_reach > 0 then
                    local intersects = false
                    local d_start = 0
                    local d_end = 0

                    if dx ~= 0 then
                        if bb.left_top.y - 0.45 <= my and my <= bb.right_bottom.y + 0.45 then
                            local d1 = (bb.left_top.x - mx) / dx
                            local d2 = (bb.right_bottom.x - mx) / dx
                            d_start = math.floor(math.min(d1, d2) - 0.5)
                            d_end = math.ceil(math.max(d1, d2) + 0.5)
                            if d_end >= 0 and d_start <= max_reach then
                                intersects = true
                            end
                        end
                    elseif dy ~= 0 then
                        if bb.left_top.x - 0.45 <= mx and mx <= bb.right_bottom.x + 0.45 then
                            local d1 = (bb.left_top.y - my) / dy
                            local d2 = (bb.right_bottom.y - my) / dy
                            d_start = math.floor(math.min(d1, d2) - 0.5)
                            d_end = math.ceil(math.max(d1, d2) + 0.5)
                            if d_end >= 0 and d_start <= max_reach then
                                intersects = true
                            end
                        end
                    end

                    if intersects then
                        local check_min = math.max(0, d_start - 2)
                        local check_max = math.min(max_reach, d_end + 2)

                        for dist = check_min, check_max do
                            local pkey = (dist == 0)
                                and (tostring(unit_number) .. ":" .. tostring(muzzle_node.port_index))
                                or  make_beam_port_key(unit_number, dx, dy, dist)

                            local b_node = storage.flow_nodes and storage.flow_nodes[pkey]
                            if b_node then
                                if is_removal and b_node.is_endpoint then
                                    flow_kinetic.unregister_endpoint_remainder_in_bvh(b_node)
                                    b_node.is_endpoint = false
                                    b_node.hit_receiver = nil
                                    local is_prom = (not b_node.is_muzzle) and ((b_node.dist or 0) > 0) and ((b_node.dist or 0) % HOP_DISTANCE == 0)
                                    b_node.is_prominent_kinetic = is_prom
                                    b_node.is_beam_node = is_prom
                                    b_node.capsule_transmit = is_prom
                                end
                                enqueue_port_fn(pkey)
                                wake_port_fn(pkey)
                            end
                        end
                    end
                end
            end
            if is_removal and u_ports then
                for _, upkey in ipairs(u_ports) do
                    wake_port_fn(upkey)
                end
            end
        end
    end
end

function flow_kinetic.clear_receiver_references(receiver_unit, enqueue_port_fn, wake_port_fn)
    if not receiver_unit then return end
    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    for pkey, fn in pairs(storage.flow_nodes or {}) do
        if fn and fn.hit_receiver == receiver_unit then
            fn.is_endpoint = false
            fn.hit_receiver = nil
            local is_prom = (not fn.is_muzzle) and ((fn.dist or 0) > 0) and ((fn.dist or 0) % HOP_DISTANCE == 0)
            fn.is_prominent_kinetic = is_prom
            fn.is_beam_node = is_prom
            fn.capsule_transmit = is_prom
            enqueue_port_fn(pkey)
            wake_port_fn(pkey)
        end
    end

    if storage.projector_reticles then
        for r_id, ret in pairs(storage.projector_reticles) do
            if ret.hit_receiver == receiver_unit or ret.pending_receiver == receiver_unit then
                local was_hit = (ret.hit_receiver == receiver_unit)
                local proj_unit = ret.projector_unit
                ret.hit_receiver = nil
                ret.pending_receiver = nil
                ret.head_render_spec = DEFAULT_HEAD_SPEC
                if was_hit and proj_unit then
                    flow_kinetic.unlink_projector_receiver(proj_unit, ret.surface_index, ret.surface_name)
                elseif proj_unit and storage.projector_scope and storage.projector_scope[proj_unit] then
                    storage.projector_scope[proj_unit].receiver_unit = nil
                end
                local s_idx = ret.surface_index or 1
                local motion_tree = timed_motion.get_motion_tree(s_idx)
                if motion_tree and ret.seg_key then
                    local owner_rec = motion_tree.trajectories and motion_tree.trajectories[r_id]
                    local leaf = owner_rec and owner_rec.segments and owner_rec.segments[ret.seg_key]
                    if leaf and leaf.static_render_spec then
                        leaf.static_render_spec = DEFAULT_HEAD_SPEC
                        viewport_bvh.on_leaf_static_changed(s_idx, leaf)
                    end
                end
            end
        end
    end
end

function flow_kinetic.handle_projector_destroyed(unit_number)
    flow_kinetic.orphan_reticle(unit_number, "destroyed")
end

function flow_kinetic.handle_projector_rotated(unit_number)
    flow_kinetic.orphan_reticle(unit_number, "rotated")
end

local CARDINALS = {
    {dx =  1, dy =  0},
    {dx = -1, dy =  0},
    {dx =  0, dy =  1},
    {dx =  0, dy = -1}
}

local function wake_beam_pointing_at(surface_name, target_pos, is_evacuation, enqueue_port_fn, wake_port_fn)
    if not (surface_name and target_pos and storage.flow_grid) then return end
    for i = 1, 4 do
        local c = CARDINALS[i]
        local nx = target_pos.x - c.dx
        local ny = target_pos.y - c.dy
        local n_key = make_pos_key(surface_name, nx, ny)
        local ports = storage.flow_grid[n_key]
        if ports then
            for pkey in pairs(ports) do
                local b_node = storage.flow_nodes and storage.flow_nodes[pkey]
                if b_node and b_node.is_kinetic and b_node.dir and b_node.dir.x == c.dx and b_node.dir.y == c.dy then
                    if is_evacuation and b_node.is_endpoint then
                        flow_kinetic.unregister_endpoint_remainder_in_bvh(b_node)
                        b_node.is_endpoint = false
                        b_node.hit_receiver = nil
                        local is_prom = (not b_node.is_muzzle) and ((b_node.dist or 0) > 0) and ((b_node.dist or 0) % HOP_DISTANCE == 0)
                        b_node.is_prominent_kinetic = is_prom
                        b_node.is_beam_node = is_prom
                        b_node.capsule_transmit = is_prom
                    end
                    enqueue_port_fn(pkey)
                    wake_port_fn(pkey)
                end
            end
        end
    end
end

function flow_kinetic.step_character_colliders(enqueue_port_fn, wake_port_fn)
    flow_kinetic.flush_pending_reticle_obstacles()
    storage.character_colliders = storage.character_colliders or {}
    storage.character_last_keys = storage.character_last_keys or {}
    storage.character_last_surface = storage.character_last_surface or {}

    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    local active_chars = {}

    for _, player in pairs(game.connected_players) do
        local char = player.character
        if char and char.valid and char.surface and char.surface.valid then
            local char_key = char.unit_number or player.index
            active_chars[char_key] = true
            local sname = char.surface.name

            local positions = port_defs.get_character_influence_positions(char.position, char.direction)
            if positions then
                local new_keys = {}
                for i = 1, #positions do
                    local p = positions[i]
                    local k = make_pos_key(sname, p.x, p.y)
                    new_keys[k] = p
                end

                local old_keys = storage.character_last_keys[char_key] or {}

                -- 1. Evacuate positions no longer in 1-node influence
                local evacuated_any = false
                for old_k, old_p in pairs(old_keys) do
                    if not new_keys[old_k] then
                        evacuated_any = true
                        storage.character_colliders[old_k] = nil
                        wake_beam_pointing_at(sname, old_p, true, enqueue_port_fn, wake_port_fn)
                        if flow_kinetic.handle_motion_obstacle_changed and char.valid and char.surface then
                            local evac_bb = {
                                left_top = { x = old_p.x - 0.45, y = old_p.y - 0.45 },
                                right_bottom = { x = old_p.x + 0.45, y = old_p.y + 0.45 }
                            }
                            local m_tree = storage.motion_bvh and storage.motion_bvh[char.surface.index]
                            if m_tree then
                                local m_hits = {}
                                trajectory_bvh.query_box(m_tree, evac_bb.left_top.x - 2.5, evac_bb.left_top.y - 2.5, evac_bb.right_bottom.x + 2.5, evac_bb.right_bottom.y + 2.5, m_hits)
                                if #m_hits > 0 then
                                    flow_kinetic.handle_motion_obstacle_changed(char.surface, char, evac_bb, true, m_hits)
                                end
                            end
                        end
                    end
                end

                local u_num = char.unit_number
                if evacuated_any and u_num and storage.blocked_reticles and storage.blocked_reticles[u_num] then
                    local to_check = {}
                    for rid in pairs(storage.blocked_reticles[u_num]) do
                        to_check[#to_check + 1] = rid
                    end

                    for i = 1, #to_check do
                        local rid = to_check[i]
                        local ret = storage.projector_reticles and storage.projector_reticles[rid]
                        if ret and ret.surface_name == sname then
                            local cbb = char.bounding_box
                            local r_dx = ret.dir.x
                            local r_dy = ret.dir.y
                            local r_sp = ret.start_pos
                            local on_axis = false
                            local o_dist = nil

                            if r_dx > 0 then
                                on_axis = (cbb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= cbb.right_bottom.y + 0.05)
                                o_dist = cbb.left_top.x - r_sp.x
                            elseif r_dx < 0 then
                                on_axis = (cbb.left_top.y - 0.05 <= r_sp.y and r_sp.y <= cbb.right_bottom.y + 0.05)
                                o_dist = r_sp.x - cbb.right_bottom.x
                            elseif r_dy > 0 then
                                on_axis = (cbb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= cbb.right_bottom.x + 0.05)
                                o_dist = cbb.left_top.y - r_sp.y
                            elseif r_dy < 0 then
                                on_axis = (cbb.left_top.x - 0.05 <= r_sp.x and r_sp.x <= cbb.right_bottom.x + 0.05)
                                o_dist = r_sp.y - cbb.right_bottom.y
                            end

                            local max_reach = ret.max_reach or 50
                            if not on_axis or not o_dist or o_dist <= 0.05 or o_dist >= max_reach then
                                flow_kinetic.handle_reticle_obstacle_cleared(char)
                            else
                                local cur_flight = ret.head_flight_id and timed_motion.get_flight(ret.head_flight_id)
                                local is_growing = (ret.status == "growing" and cur_flight ~= nil)
                                local cur_head_dist = ret.total_dist or 0

                                if is_growing then
                                    local cur_pos = timed_motion.get_interpolated_position(cur_flight, game.tick)
                                    cur_head_dist = math.abs(cur_pos.x - r_sp.x) + math.abs(cur_pos.y - r_sp.y)
                                end

                                if is_growing then
                                    if o_dist <= (cur_head_dist + 0.05) then
                                        flow_kinetic.truncate_reticle(ret, o_dist, char)
                                    else
                                        local cur_target = ret.total_dist or cur_head_dist
                                        if math.abs(o_dist - cur_target) > 0.1 then
                                            if o_dist < cur_target then
                                                flow_kinetic.update_reticle_horizon(ret, o_dist, char, cur_flight)
                                            else
                                                flow_kinetic.handle_reticle_obstacle_cleared(char)
                                            end
                                        end
                                    end
                                else
                                    local cur_total = ret.total_dist or 0
                                    if math.abs(o_dist - cur_total) > 0.1 then
                                        if o_dist < cur_total then
                                            flow_kinetic.truncate_reticle(ret, o_dist, char)
                                        else
                                            flow_kinetic.handle_reticle_obstacle_cleared(char)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                -- 2. Occupy newly entered positions
                for new_k, new_p in pairs(new_keys) do
                    storage.character_colliders[new_k] = char
                    if not old_keys[new_k] then
                        flow_kinetic.handle_obstacle_changed(char, false, enqueue_port_fn, wake_port_fn)
                        local ports = storage.flow_grid and storage.flow_grid[new_k]
                        if ports then
                            for pkey in pairs(ports) do
                                local b_node = storage.flow_nodes and storage.flow_nodes[pkey]
                                if b_node and b_node.is_kinetic then
                                    enqueue_port_fn(pkey)
                                    wake_port_fn(pkey)
                                end
                            end
                        end
                        wake_beam_pointing_at(sname, new_p, false, enqueue_port_fn, wake_port_fn)
                        if flow_kinetic.handle_motion_obstacle_changed and char.valid and char.surface then
                            local c_bb = char.bounding_box
                            local m_tree = storage.motion_bvh and storage.motion_bvh[char.surface.index]
                            if m_tree then
                                local m_hits = {}
                                trajectory_bvh.query_box(m_tree, c_bb.left_top.x - 2.5, c_bb.left_top.y - 2.5, c_bb.right_bottom.x + 2.5, c_bb.right_bottom.y + 2.5, m_hits)
                                if #m_hits > 0 then
                                    flow_kinetic.handle_motion_obstacle_changed(char.surface, char, c_bb, false, m_hits)
                                end
                            end
                        end
                    end
                end

                storage.character_last_keys[char_key] = new_keys
                storage.character_last_surface[char_key] = sname
            end
        end
    end

    -- 3. Cleanup disconnected or dead characters
    for char_key, old_keys in pairs(storage.character_last_keys) do
        if not active_chars[char_key] then
            local sname = storage.character_last_surface and storage.character_last_surface[char_key]
            if old_keys and sname then
                for old_k, old_p in pairs(old_keys) do
                    storage.character_colliders[old_k] = nil
                    wake_beam_pointing_at(sname, old_p, true, enqueue_port_fn, wake_port_fn)
                end
            end
            if storage.blocked_reticles and storage.blocked_reticles[char_key] then
                flow_kinetic.handle_reticle_obstacle_cleared({ unit_number = char_key })
            end
            storage.character_last_keys[char_key] = nil
            if storage.character_last_surface then storage.character_last_surface[char_key] = nil end
        end
    end

    flow_kinetic.step_pending_bvh_segments(game.tick)
    flow_kinetic.step_cooldown_heap(game.tick)
    flow_kinetic.flush_pending_reticle_obstacles()
end

function flow_kinetic.step_pending_bvh_segments(current_tick)
    flow_kinetic.flush_pending_reticle_obstacles()
    local pending = storage.pending_bvh_segments
    if not pending or #pending == 0 then return end

    local p_flights = storage.projector_flights
    local write_idx = 1
    local changed = false

    for i = 1, #pending do
        local item = pending[i]
        local leaf = item.leaf
        local tree = storage.surface_bvh and storage.surface_bvh[item.surface_index]

        local owner_rec = tree and tree.trajectories and tree.trajectories[item.owner_id]
        local current_leaf = owner_rec and owner_rec.segments and owner_rec.segments[item.seg_key]

        if not (leaf and current_leaf) then
            -- Leaf or trajectory was already removed
        elseif current_leaf ~= leaf then
            -- Segment was re-registered or replaced by advancing beam; drop stale deletion
        elseif leaf.pending_removal ~= true then
            -- Segment was re-activated
        else
            local owner_flights = p_flights and p_flights[item.owner_id]
            local can_remove = false

            if not (owner_flights and #owner_flights > 0) then
                can_remove = true
            elseif current_tick > (leaf.removal_expiry_tick or 0) then
                can_remove = true
            end

            if can_remove then
                trajectory_bvh.attach(tree)
                tree:remove_segment(item.owner_id, item.seg_key)
                changed = true
            else
                if write_idx ~= i then
                    pending[write_idx] = item
                end
                write_idx = write_idx + 1
            end
        end
    end

    for i = write_idx, #pending do
        pending[i] = nil
    end

    if changed then
        trajectory_bvh.refresh_active_renders()
    end
end

return flow_kinetic
