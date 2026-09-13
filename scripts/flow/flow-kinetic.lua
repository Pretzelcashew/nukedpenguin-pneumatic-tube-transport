local flow_common = require("scripts.flow.flow-common")
local flow_renderer = require("scripts.flow.flow-renderer")
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

    if cur_dist > last_boundary then
        local seg_idx = math.floor(cur_dist / 16) + 1
        local seg_key = string.format("%d,%d:%d", node.dir.x, node.dir.y, seg_idx)
        local start_pos = { x = mx + node.dir.x * last_boundary, y = my + node.dir.y * last_boundary }
        local end_pos = { x = node.pos.x, y = node.pos.y }
        local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
        if tree then
            tree:insert_segment(owner_unit, seg_key, start_pos, end_pos, last_boundary, cur_dist, seg_idx)
            trajectory_bvh.refresh_active_renders()
        end
    else
        trajectory_bvh.refresh_active_renders()
    end
end

function flow_kinetic.unregister_trajectory_in_bvh(owner_unit, surface_name, force)
    if not owner_unit then return end
    if not force and storage.projector_flights and storage.projector_flights[owner_unit] and #storage.projector_flights[owner_unit] > 0 then
        storage.pending_bvh_removals = storage.pending_bvh_removals or {}
        storage.pending_bvh_removals[owner_unit] = surface_name or true
        return
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

function flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
    if not (node and node.dist and node.dir) then return end
    local cur_dist = node.dist
    if cur_dist % 16 ~= 0 then
        local seg_idx = math.floor(cur_dist / 16) + 1
        local seg_key = string.format("%d,%d:%d", node.dir.x, node.dir.y, seg_idx)
        local surface = game.surfaces[node.surface_name]
        if surface and surface.valid and storage.surface_bvh then
            local tree = storage.surface_bvh[surface.index]
            if tree then
                trajectory_bvh.attach(tree)
                tree:remove_segment(node.beam_owner or node.unit_number, seg_key)
                trajectory_bvh.refresh_active_renders()
            end
        end
    end
end

function flow_kinetic.unregister_segment_in_bvh(node)
    if not (node and node.dist and node.dist % 16 == 0 and node.dir) then return end
    local seg_idx = node.dist / 16
    local seg_key = string.format("%d,%d:%d", node.dir.x, node.dir.y, seg_idx)
    local surface = game.surfaces[node.surface_name]
    if surface and surface.valid and storage.surface_bvh then
        local tree = storage.surface_bvh[surface.index]
        if tree then
            trajectory_bvh.attach(tree)
            tree:remove_segment(node.beam_owner or node.unit_number, seg_key)
            trajectory_bvh.refresh_active_renders()
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
                node.is_endpoint = true
                node.is_prominent_kinetic = true
                node.is_beam_node = true
                node.capsule_transmit = true
                node.hit_receiver = nil
                flow_kinetic.register_endpoint_in_bvh(node)
                flow_renderer.update_kinetic_pos_render(pkey)
                wake_port_fn(pkey)
            elseif target_kinetic > 1 and node.dir then
                local nx = node.pos.x + node.dir.x
                local ny = node.pos.y + node.dir.y
                local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
                local occ = flow_kinetic.check_tile_obstruction(surface, nx, ny, owner_entity)

                if occ.blocked then
                    node.is_endpoint = true
                    node.is_prominent_kinetic = true
                    node.is_beam_node = true
                    node.capsule_transmit = true
                    node.hit_receiver = occ.is_receiver and occ.receiver and occ.receiver.unit_number or nil
                    flow_kinetic.register_endpoint_in_bvh(node)
                    flow_renderer.update_kinetic_pos_render(pkey)
                    wake_port_fn(pkey)

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
                if node.is_endpoint then
                    flow_kinetic.unregister_endpoint_remainder_in_bvh(node)
                end
                if node.dist and node.dist % 16 == 0 then
                    flow_kinetic.unregister_segment_in_bvh(node)
                end
                flow_common.destroy_node(pkey)
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
    if not (entity and entity.valid and entity.bounding_box and storage.active_projectors) then return end
    if IGNORABLE_TYPES[entity.type] or PROXY_NAMES[entity.name] then return end
    local bb = entity.bounding_box
    local surf_name = entity.surface.name

    enqueue_port_fn = enqueue_port_fn or enqueue_port
    wake_port_fn = wake_port_fn or wake_port_parked

    for unit_number, proj in pairs(storage.active_projectors) do
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
                        local check_min = math.max(0, d_start - 1)
                        local check_max = math.min(max_reach, d_end + 1)

                        for dist = check_min, check_max do
                            local pkey = (dist == 0)
                                and (tostring(unit_number) .. ":" .. tostring(muzzle_node.port_index))
                                or  make_beam_port_key(unit_number, dx, dy, dist)

                            local b_node = storage.flow_nodes and storage.flow_nodes[pkey]
                            if b_node then
                                if is_removal and b_node.is_endpoint then
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
    if not unit_number then return end
    flow_kinetic.unregister_trajectory_in_bvh(unit_number)

    for pkey, node in pairs(storage.flow_nodes or {}) do
        if node and node.beam_owner == unit_number and not node.is_muzzle then
            flow_renderer.destroy_kinetic_pos_render(pkey)
            flow_common.destroy_node(pkey)
        end
    end
end

return flow_kinetic
