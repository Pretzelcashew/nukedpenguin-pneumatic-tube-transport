local flow_common = require("scripts.flow.flow-common")
local flow_renderer = require("scripts.flow.flow-renderer")
local port_defs = require("scripts.flow.port-defs")
local projector_settings = require("scripts.projectors.projector-settings")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")

local flow_kinetic = {}

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

    local rx = receiver_ent.position.x - node.dir.x * 1.5
    local ry = receiver_ent.position.y - node.dir.y * 1.5
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
                        local rx = occ.receiver.position.x - node.dir.x * 1.5
                        local ry = occ.receiver.position.y - node.dir.y * 1.5
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

function flow_kinetic.handle_obstacle_changed(entity, is_removal, enqueue_port_fn, wake_port_fn)
    if not (entity and entity.valid and entity.bounding_box) then return end
    if IGNORABLE_TYPES[entity.type] or PROXY_NAMES[entity.name] then return end
    local bb = entity.bounding_box
    local surface = entity.surface
    if not (surface and surface.valid) then return end
    local surf_name = surface.name

    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    local MARGIN = 2.5
    if flow_kinetic.handle_motion_obstacle_changed and storage.motion_bvh and storage.motion_bvh[surface.index] then
        local motion_tree = storage.motion_bvh[surface.index]
        local motion_hits = {}
        trajectory_bvh.query_box(motion_tree, bb.left_top.x - MARGIN, bb.left_top.y - MARGIN, bb.right_bottom.x + MARGIN, bb.right_bottom.y + MARGIN, motion_hits)
        if #motion_hits > 0 then
            flow_kinetic.handle_motion_obstacle_changed(surface, entity, bb, is_removal, motion_hits)
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
        if owner_id and not affected_owners[owner_id] then
            affected_owners[owner_id] = true
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
end

function flow_kinetic.handle_projector_destroyed(unit_number)
    -- Queue-driven recession handles beam nodes and BVH segments naturally
end

function flow_kinetic.handle_projector_rotated(unit_number)
    -- Queue-driven recession handles beam nodes and BVH segments naturally
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
                for old_k, old_p in pairs(old_keys) do
                    if not new_keys[old_k] then
                        storage.character_colliders[old_k] = nil
                        wake_beam_pointing_at(sname, old_p, true, enqueue_port_fn, wake_port_fn)
                        if flow_kinetic.handle_motion_obstacle_changed and char.valid and char.surface then
                            local c_bb = char.bounding_box
                            local m_tree = storage.motion_bvh and storage.motion_bvh[char.surface.index]
                            if m_tree then
                                local m_hits = {}
                                trajectory_bvh.query_box(m_tree, c_bb.left_top.x - 2.5, c_bb.left_top.y - 2.5, c_bb.right_bottom.x + 2.5, c_bb.right_bottom.y + 2.5, m_hits)
                                if #m_hits > 0 then
                                    flow_kinetic.handle_motion_obstacle_changed(char.surface, char, c_bb, true, m_hits)
                                end
                            end
                        end
                    end
                end

                -- 2. Occupy newly entered positions
                for new_k, new_p in pairs(new_keys) do
                    storage.character_colliders[new_k] = char
                    if not old_keys[new_k] then
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
            storage.character_last_keys[char_key] = nil
            if storage.character_last_surface then storage.character_last_surface[char_key] = nil end
        end
    end

    flow_kinetic.step_pending_bvh_segments(game.tick)
end

function flow_kinetic.step_pending_bvh_segments(current_tick)
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
