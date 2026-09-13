local flow_engine = require("scripts.flow.flow-engine")
local projector_settings = require("scripts.projectors.projector-settings")
local capsule_transit = require("scripts.capsules.capsule-transit")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local hub_spill = require("scripts.hubs.hub-spill")
local binary_heap = require("scripts.utils.binary-heap")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local flow_kinetic = require("scripts.flow.flow-kinetic")

local capsule_ballistics = {}

local USE_TIMED_ARRIVAL = true
capsule_ballistics.USE_TIMED_ARRIVAL = USE_TIMED_ARRIVAL

local MAX_BEAM_DISTANCE = 500
local HOP_DISTANCE = 5
capsule_ballistics.MAX_BEAM_DISTANCE = MAX_BEAM_DISTANCE
capsule_ballistics.HOP_DISTANCE = HOP_DISTANCE

--------------------------------------------------------------------------------
-- AUDIO & PARTICLE VISUAL EFFECTS
--------------------------------------------------------------------------------
function capsule_ballistics.play_dispatch_effects(surface, pos)
    if not (surface and surface.valid and pos) then return end
    pcall(function()
        surface.create_entity{
            name = "spark-explosion",
            position = pos
        }
    end)
    pcall(function()
        surface.play_sound{
            path = "utility/wire_connect",
            position = pos,
            volume_modifier = 1.0
        }
    end)
end

function capsule_ballistics.play_flight_effects(surface, pos)
    if not (surface and surface.valid and pos) then return end
    pcall(function()
        surface.create_entity{
            name = "spark-explosion",
            position = pos
        }
    end)
end

function capsule_ballistics.play_catchment_effects(surface, pos)
    if not (surface and surface.valid and pos) then return end
    pcall(function()
        surface.create_entity{
            name = "spark-explosion",
            position = pos
        }
    end)
    pcall(function()
        surface.play_sound{
            path = "utility/wire_connect",
            position = pos,
            volume_modifier = 0.9
        }
    end)
end

--------------------------------------------------------------------------------
-- BEAM PORT KEYS & ENDPOINT RESOLUTION
--------------------------------------------------------------------------------
function capsule_ballistics.make_beam_port_key(unit_number, dx, dy, dist)
    return string.format("kinetic:%d:%d,%d:%d", unit_number, math.floor(dx or 0), math.floor(dy or 0), dist)
end

function capsule_ballistics.get_beam_endpoint(unit_number, dx, dy)
    for dist = 1, MAX_BEAM_DISTANCE do
        local check_key = capsule_ballistics.make_beam_port_key(unit_number, dx, dy, dist)
        local check_node = storage.flow_nodes and storage.flow_nodes[check_key]
        if not check_node then break end
        if check_node.is_endpoint then
            return check_key, check_node
        end
    end
    return nil, nil
end

function capsule_ballistics.count_endpoint_capsules(unit_number, endpoint_key, endpoint_node)
    local count = 0

    if storage.parked_by_port and storage.parked_by_port[endpoint_key] then
        for _ in pairs(storage.parked_by_port[endpoint_key]) do
            count = count + 1
        end
    end

    local hit_receiver_unit = endpoint_node and endpoint_node.hit_receiver
    if hit_receiver_unit and storage.flow_unit_ports and storage.flow_unit_ports[hit_receiver_unit] then
        local r_ports = storage.flow_unit_ports[hit_receiver_unit]
        for i = 1, #r_ports do
            local rpkey = r_ports[i]
            if storage.parked_by_port and storage.parked_by_port[rpkey] then
                for _ in pairs(storage.parked_by_port[rpkey]) do
                    count = count + 1
                end
            end
        end
    end

    if storage.capsules then
        for _, cap in pairs(storage.capsules) do
            if cap.beam_flight and cap.beam_flight.owner == unit_number then
                if cap.from_port_key ~= endpoint_key then
                    count = count + 1
                end
            end
        end
    end

    return count
end

--------------------------------------------------------------------------------
-- BALLISTIC FLIGHT TRAJECTORY INITIALIZATION
--------------------------------------------------------------------------------
function capsule_ballistics.init_capsule_beam_flight(capsule, muzzle_node)
    if not (capsule and muzzle_node and muzzle_node.dir) then return end
    local beam_owner = muzzle_node.beam_owner or muzzle_node.unit_number
    local dx = muzzle_node.dir.x
    local dy = muzzle_node.dir.y
    local surface_name = muzzle_node.surface_name

    local hop_positions = {}
    local hop_count = 0
    local terminal_pos = nil
    local hit_receiver_unit = nil

    for dist = 1, MAX_BEAM_DISTANCE do
        local check_key = capsule_ballistics.make_beam_port_key(beam_owner, dx, dy, dist)
        local check_node = storage.flow_nodes and storage.flow_nodes[check_key]
        if not check_node then break end

        if check_node.is_prominent_kinetic or check_node.is_endpoint then
            hop_count = hop_count + 1
            hop_positions[hop_count] = { x = check_node.pos.x, y = check_node.pos.y }
            if check_node.is_endpoint then
                terminal_pos = { x = check_node.pos.x, y = check_node.pos.y }
                hit_receiver_unit = check_node.hit_receiver
                break
            end
        end
    end

    if hop_count == 0 then
        hop_count = 1
        hop_positions[1] = {
            x = muzzle_node.pos.x + dx * HOP_DISTANCE,
            y = muzzle_node.pos.y + dy * HOP_DISTANCE
        }
    end

    if not terminal_pos then
        terminal_pos = hop_positions[hop_count]
    end

    local current_tick = game.tick
    local flight_ticks = math.max(6, hop_count * 6)

    if USE_TIMED_ARRIVAL and muzzle_node and terminal_pos then
        local surface = game.surfaces[muzzle_node.surface_name]
        if surface and surface.valid then
            local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
            if tree then
                tree:insert_trajectory(beam_owner, muzzle_node.pos, terminal_pos)
            end
        end
    end

    capsule.beam_flight = {
        start_pos = { x = muzzle_node.pos.x, y = muzzle_node.pos.y },
        start_tick = current_tick,
        arrival_tick = current_tick + flight_ticks,
        flight_ticks = flight_ticks,
        surface_name = surface_name or "nauvis",
        dx = dx,
        dy = dy,
        current_hop = 1,
        total_hops = hop_count,
        hop_positions = hop_positions,
        terminal_pos = terminal_pos,
        hit_receiver_unit = hit_receiver_unit,
        owner = beam_owner
    }
end

--------------------------------------------------------------------------------
-- RECEIVER CATCHMENT & INJECTION
--------------------------------------------------------------------------------
function capsule_ballistics.catch_in_receiver(capsule, receiver_entity, runner)
    if not (capsule and receiver_entity and receiver_entity.valid) then return false end
    local r_unit = receiver_entity.unit_number
    local r_ports = storage.flow_unit_ports and storage.flow_unit_ports[r_unit]
    if not r_ports then return false end

    local best_ext_key = nil
    local best_r_pkey = nil
    local best_drop = -math.huge

    for _, r_pkey in ipairs(r_ports) do
        local r_node = storage.flow_nodes and storage.flow_nodes[r_pkey]
        if r_node and not (r_node.is_muzzle or r_node.kinetic_transmit) and not r_node.is_beam_node then
            local neighbors = storage.flow_connections and storage.flow_connections[r_pkey]
            if neighbors then
                for ext_key in pairs(neighbors) do
                    local ext_node = storage.flow_nodes and storage.flow_nodes[ext_key]
                    if ext_node and ext_node.unit_number ~= r_unit and ext_node.capsule_transmit then
                        if runner.has_capacity(r_pkey, ext_key) then
                            local ext_level = storage.flow_levels and storage.flow_levels[ext_key] or 0
                            local drop = -ext_level
                            if drop >= 0 and drop > best_drop then
                                best_drop = drop
                                best_ext_key = ext_key
                                best_r_pkey = r_pkey
                            end
                        end
                    end
                end
            end
        end
    end

    if best_ext_key and best_r_pkey then
        runner.mark_capsule_unparked(capsule)
        local prev_key = capsule.from_port_key
        capsule.last_port_key = best_r_pkey
        capsule.from_port_key = best_ext_key
        capsule.to_port_key = nil
        capsule.beam_flight = nil

        local ext_node = storage.flow_nodes and storage.flow_nodes[best_ext_key]
        if ext_node and ext_node.pos then
            capsule.last_pos = { x = ext_node.pos.x, y = ext_node.pos.y }
            capsule.surface_name = ext_node.surface_name
        end

        capsule_queries.update_capsule_occupancy(capsule)
        runner.wake_parked_capsules(prev_key)
        runner.wake_parked_capsules(best_ext_key)
        runner.wake_parked_capsules(r_unit)

        local prev_node = storage.flow_nodes and storage.flow_nodes[prev_key]
        local sender_unit = prev_node and (prev_node.beam_owner or prev_node.unit_number)
        if sender_unit and sender_unit ~= r_unit then
            runner.wake_parked_capsules(sender_unit)
        end
        capsule_ballistics.play_catchment_effects(receiver_entity.surface, receiver_entity.position)
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- KINETIC HOP & LAUNCH ADVANCEMENT (CALLED DURING TARGET RESOLUTION)
--------------------------------------------------------------------------------
function capsule_ballistics.advance_kinetic_trajectory(capsule, current_node, unit_number, runner)
    if current_node.is_endpoint then
        return nil
    end

    local beam_owner = current_node.beam_owner or unit_number
    local dir = current_node.dir
    if not dir then return nil end

    local cur_dist = current_node.dist or 0
    local surface = game.surfaces[current_node.surface_name]
    local owner_entity = storage.active_projectors and storage.active_projectors[beam_owner]
    local cap_id = capsule.capsule_id or capsule.id

    local next_prominent_key = nil
    local obstacle_pos = nil
    local hit_player_entity = nil
    local found_obstacle = false

    for d = cur_dist + 1, cur_dist + HOP_DISTANCE do
        local cand_key = capsule_ballistics.make_beam_port_key(beam_owner, dir.x, dir.y, d)
        local cand_node = storage.flow_nodes and storage.flow_nodes[cand_key]
        local tx = current_node.pos.x + dir.x * (d - cur_dist)
        local ty = current_node.pos.y + dir.y * (d - cur_dist)

        if surface and surface.valid then
            local player_target = capsule_transit.check_player_collision(surface, tx, ty, capsule)
            if player_target then
                found_obstacle = player_target
                obstacle_pos = { x = tx, y = ty }
                hit_player_entity = player_target
                break
            end

            local occ = flow_engine.check_tile_obstruction(surface, tx, ty, owner_entity)
            if occ.blocked and not occ.is_receiver then
                found_obstacle = occ.obstacle or true
                obstacle_pos = { x = tx, y = ty }
                break
            end
        end

        local cand_level = storage.kinetic_levels and storage.kinetic_levels[cand_key] or 0
        if not cand_node or cand_level <= 0 then
            found_obstacle = true
            obstacle_pos = { x = tx, y = ty }
            break
        end

        if cand_node.is_prominent_kinetic or cand_node.is_endpoint then
            next_prominent_key = cand_key
            break
        end
    end

    if found_obstacle and obstacle_pos and surface and surface.valid then
        if hit_player_entity and hit_player_entity.valid then
            local q_lvl = (current_node and current_node.q_level) or 0
            local dmg = math.floor((projector_settings.PROJECTILE_DAMAGE or 250) * (1 + 0.3 * q_lvl))
            local p_force = (owner_entity and owner_entity.valid and owner_entity.force) or (hit_player_entity.force) or "neutral"
            hit_player_entity.damage(dmg, p_force, "impact")
        end
        runner.mark_capsule_unparked(capsule)
        local crash_port_key = capsule.from_port_key
        hub_spill.spill_capsule(cap_id, surface, obstacle_pos, nil, true)
        runner.wake_parked_capsules(crash_port_key)
        return nil
    end

    if next_prominent_key then
        if capsule.beam_flight then
            capsule.beam_flight.current_hop = (capsule.beam_flight.current_hop or 1) + 1
        end
        return next_prominent_key
    end

    return nil
end

function capsule_ballistics.try_projector_launch(capsule, unit_number, runner)
    if not (storage.active_projectors and storage.active_projectors[unit_number]) then
        return nil
    end

    if not capsule_transit.is_electromagnetic_capsule(capsule) then
        return nil
    end

    local proj_entity = storage.active_projectors[unit_number]
    if not (proj_entity and proj_entity.valid and projector_settings.is_projector_active(proj_entity)) then
        return "docked"
    end
    if not projector_settings.can_fire(proj_entity) then
        return "docked"
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    local muzzle_pkey = nil
    local muzzle_node = nil
    if unit_ports then
        for i = 1, #unit_ports do
            local pkey = unit_ports[i]
            local pnode = storage.flow_nodes and storage.flow_nodes[pkey]
            if pnode and (pnode.is_muzzle or pnode.kinetic_transmit) then
                muzzle_pkey = pkey
                muzzle_node = pnode
                break
            end
        end
    end

    if muzzle_node and muzzle_node.dir then
        local muzzle_level = flow_engine.get_kinetic_level(muzzle_pkey)
        if muzzle_level > 0 then
            local dx = muzzle_node.dir.x
            local dy = muzzle_node.dir.y

            local endpoint_key, endpoint_node = capsule_ballistics.get_beam_endpoint(unit_number, dx, dy)
            if not endpoint_node then
                return "docked"
            end

            local max_cap = projector_settings.MAX_ENDPOINT_CAPSULES or 2
            local endpoint_count = capsule_ballistics.count_endpoint_capsules(unit_number, endpoint_key, endpoint_node)
            if endpoint_count >= max_cap then
                return "docked"
            end

            local cap_id = capsule.capsule_id or capsule.id
            local from_port_key = capsule.from_port_key

            for d = 1, HOP_DISTANCE do
                local cand_key = capsule_ballistics.make_beam_port_key(unit_number, dx, dy, d)
                local cand_node = storage.flow_nodes and storage.flow_nodes[cand_key]
                local cand_level = storage.kinetic_levels and storage.kinetic_levels[cand_key] or 0
                local tx = muzzle_node.pos.x + dx * d
                local ty = muzzle_node.pos.y + dy * d
                local surface = game.surfaces[muzzle_node.surface_name]

                if surface and surface.valid then
                    local player_target = capsule_transit.check_player_collision(surface, tx, ty, capsule)
                    if player_target then
                        local launch_cost = projector_settings.get_launch_energy(proj_entity)
                        proj_entity.energy = math.max(0, proj_entity.energy - launch_cost)
                        storage.projector_last_fired = storage.projector_last_fired or {}
                        storage.projector_last_fired[unit_number] = game.tick
                        if storage.projector_ready_states then
                            storage.projector_ready_states[unit_number] = false
                        end

                        local q_lvl = muzzle_node.q_level or 0
                        local dmg = math.floor((projector_settings.PROJECTILE_DAMAGE or 250) * (1 + 0.3 * q_lvl))
                        local p_force = (proj_entity and proj_entity.valid and proj_entity.force) or (player_target.force) or "neutral"
                        player_target.damage(dmg, p_force, "impact")
                        runner.mark_capsule_unparked(capsule)
                        hub_spill.spill_capsule(cap_id, surface, { x = tx, y = ty }, nil, true)
                        runner.wake_parked_capsules(from_port_key)
                        return "docked"
                    end
                end

                if cand_node and cand_level > 0 then
                    if cand_node.is_prominent_kinetic or cand_node.is_endpoint then
                        if runner.has_capacity(from_port_key, cand_key) then
                            local launch_cost = projector_settings.get_launch_energy(proj_entity)
                            proj_entity.energy = math.max(0, proj_entity.energy - launch_cost)
                            storage.projector_last_fired = storage.projector_last_fired or {}
                            storage.projector_last_fired[unit_number] = game.tick
                            if storage.projector_ready_states then
                                storage.projector_ready_states[unit_number] = false
                            end

                            capsule_ballistics.init_capsule_beam_flight(capsule, muzzle_node)
                            if USE_TIMED_ARRIVAL then
                                return capsule_ballistics.dispatch_timed_launch(capsule, muzzle_node, from_port_key, runner)
                            end
                            return cand_key
                        end
                    end
                end
            end
        end
    end

    return "docked"
end

--------------------------------------------------------------------------------
-- BALLISTIC ENDPOINT ARRIVAL & IN-FLIGHT MOTION ADVANCEMENT
--------------------------------------------------------------------------------
function capsule_ballistics.handle_endpoint_arrival(capsule, id, node, bf, runner)
    local is_beam_endpoint = false
    if node then
        if (node.is_beam_node or node.is_prominent_kinetic) and node.is_endpoint then
            is_beam_endpoint = true
        end
    elseif bf and bf.current_hop and bf.total_hops and bf.current_hop >= bf.total_hops then
        is_beam_endpoint = true
    end

    if not is_beam_endpoint then
        return false, false
    end

    local hit_receiver_unit = (node and node.hit_receiver) or (bf and bf.hit_receiver_unit)
    local receiver_entity = hit_receiver_unit and storage.active_projectors and storage.active_projectors[hit_receiver_unit]
    local surface = (node and game.surfaces[node.surface_name])
        or (bf and bf.surface_name and game.surfaces[bf.surface_name])
        or (capsule.surface_name and game.surfaces[capsule.surface_name])
    local term_pos = (node and node.pos) or (bf and bf.terminal_pos) or capsule.last_pos

    if receiver_entity and receiver_entity.valid then
        if capsule_ballistics.catch_in_receiver(capsule, receiver_entity, runner) then
            capsule.beam_flight = nil
            return true, true
        end
        return true, false
    else
        capsule.beam_flight = nil
        if surface and surface.valid and term_pos then
            local player_target = capsule_transit.check_player_collision(surface, term_pos.x, term_pos.y, capsule)
            if player_target and player_target.valid then
                local dmg = projector_settings.PROJECTILE_DAMAGE or 250
                local p_force = (player_target.force) or "neutral"
                player_target.damage(dmg, p_force, "impact")
            end
            hub_spill.spill_capsule(id, surface, term_pos, nil, true)
        else
            runner.remove_capsule(id)
        end
        return true, true
    end
end

function capsule_ballistics.advance_in_flight_capsule(capsule, id, bf, current_tick, stagger_ticks, runner)
    local surface = game.surfaces[bf.surface_name or capsule.surface_name or "nauvis"]

    if bf.current_hop >= bf.total_hops then
        runner.handle_arrival(capsule, id)
    else
        local next_pos = bf.hop_positions[bf.current_hop] or bf.terminal_pos

        local obstructed = false
        local obst_pos = nil
        local hit_player_entity = nil
        if surface and surface.valid and capsule.last_pos and next_pos then
            local sx, sy = capsule.last_pos.x, capsule.last_pos.y
            local dx = (next_pos.x > sx and 1) or (next_pos.x < sx and -1) or 0
            local dy = (next_pos.y > sy and 1) or (next_pos.y < sy and -1) or 0
            local steps = math.max(math.abs(next_pos.x - sx), math.abs(next_pos.y - sy))
            for step = 1, math.floor(steps) do
                local cx = sx + dx * step
                local cy = sy + dy * step

                local player_target = capsule_transit.check_player_collision(surface, cx, cy, capsule)
                if player_target then
                    obstructed = true
                    obst_pos = { x = cx, y = cy }
                    hit_player_entity = player_target
                    break
                end

                local occ = flow_engine.check_tile_obstruction(surface, cx, cy, nil)
                if occ.blocked and not occ.is_receiver then
                    obstructed = true
                    obst_pos = { x = cx, y = cy }
                    break
                end
            end
        end

        if obstructed and obst_pos and surface and surface.valid then
            if hit_player_entity and hit_player_entity.valid then
                local dmg = projector_settings.PROJECTILE_DAMAGE or 250
                local p_force = (hit_player_entity.force) or "neutral"
                hit_player_entity.damage(dmg, p_force, "impact")
            end
            runner.mark_capsule_unparked(capsule)
            local dead_port_key = capsule.from_port_key
            hub_spill.spill_capsule(id, surface, obst_pos, nil, true)
            if dead_port_key then
                runner.wake_parked_capsules(dead_port_key)
            end
        else
            capsule.last_pos = next_pos
            capsule_ballistics.play_flight_effects(surface, next_pos)

            if surface and surface.valid and next_pos then
                capsule_renderer.render(capsule, id, next_pos, surface)
            end
            capsule.next_retry_tick = current_tick + stagger_ticks
        end
    end
end

--------------------------------------------------------------------------------
-- TIMED ARRIVAL SCHEDULER & STEPPER
--------------------------------------------------------------------------------
function capsule_ballistics.get_arrival_heap()
    if not storage.kinetic_arrival_heap then
        storage.kinetic_arrival_heap = binary_heap.new()
    else
        binary_heap.attach(storage.kinetic_arrival_heap)
    end
    return storage.kinetic_arrival_heap
end

function capsule_ballistics.dispatch_timed_launch(capsule, muzzle_node, from_port_key, runner)
    local cap_id = capsule.capsule_id or capsule.id
    capsule.in_timed_flight = true
    capsule.from_port_key = nil
    capsule.last_port_key = from_port_key
    capsule.to_port_key = nil
    runner.mark_capsule_unparked(capsule)

    local heap = capsule_ballistics.get_arrival_heap()
    local arrival_tick = capsule.beam_flight and capsule.beam_flight.arrival_tick or (game.tick + 6)
    heap:push(cap_id, arrival_tick, cap_id)

    local beam_owner = (capsule.beam_flight and capsule.beam_flight.owner) or muzzle_node.beam_owner or muzzle_node.unit_number
    if beam_owner then
        storage.projector_flights = storage.projector_flights or {}
        storage.projector_flights[beam_owner] = storage.projector_flights[beam_owner] or {}
        local p_flights = storage.projector_flights[beam_owner]
        p_flights[#p_flights + 1] = {
            capsule_id = cap_id,
            start_tick = capsule.beam_flight and capsule.beam_flight.start_tick or game.tick,
            arrival_tick = arrival_tick,
            duration = capsule.beam_flight and capsule.beam_flight.flight_ticks or (arrival_tick - game.tick)
        }
    end

    local surface = game.surfaces[muzzle_node.surface_name]
    capsule_ballistics.play_dispatch_effects(surface, muzzle_node.pos)
    runner.wake_parked_capsules(from_port_key)
    return "timed_launched"
end

function capsule_ballistics.finalize_timed_arrival(capsule, id, runner)
    capsule.in_timed_flight = nil
    local bf = capsule.beam_flight
    if not bf then
        capsule_ballistics.remove_flight(id)
        runner.remove_capsule(id)
        return
    end

    local beam_owner = bf.owner
    capsule_ballistics.remove_flight(id, beam_owner)

    bf.current_hop = bf.total_hops
    local handled, arrived = capsule_ballistics.handle_endpoint_arrival(capsule, id, nil, bf, runner)
    if not handled or not arrived then
        local hit_receiver_unit = bf.hit_receiver_unit
        local r_ports = hit_receiver_unit and storage.flow_unit_ports and storage.flow_unit_ports[hit_receiver_unit]
        local dock_port = r_ports and r_ports[1]
        if dock_port then
            capsule.from_port_key = dock_port
            capsule.last_pos = bf.terminal_pos
            capsule.surface_name = bf.surface_name
            capsule_queries.update_capsule_occupancy(capsule)
            runner.mark_capsule_parked(capsule)
        else
            runner.remove_capsule(id)
        end
    end
end

function capsule_ballistics.step_timed_arrivals(current_tick, runner)
    local heap = storage.kinetic_arrival_heap
    if not heap then return end
    binary_heap.attach(heap)
    if heap.size == 0 then return end

    while heap.size > 0 do
        local top_id, arrival_tick = heap:peek()
        if not top_id or arrival_tick > current_tick then
            break
        end

        heap:pop()
        local capsule = storage.capsules and storage.capsules[top_id]
        if capsule and capsule.in_timed_flight then
            capsule_ballistics.finalize_timed_arrival(capsule, top_id, runner)
        end
    end
end

function capsule_ballistics.remove_flight(capsule_id, beam_owner)
    if not storage.projector_flights then return end
    if beam_owner and storage.projector_flights[beam_owner] then
        local p_flights = storage.projector_flights[beam_owner]
        for i = #p_flights, 1, -1 do
            if p_flights[i].capsule_id == capsule_id then
                table.remove(p_flights, i)
                break
            end
        end
        if #p_flights == 0 then
            storage.projector_flights[beam_owner] = nil
            if storage.pending_bvh_removals and storage.pending_bvh_removals[beam_owner] then
                local sname = storage.pending_bvh_removals[beam_owner]
                storage.pending_bvh_removals[beam_owner] = nil
                flow_kinetic.unregister_trajectory_in_bvh(beam_owner, type(sname) == "string" and sname or nil, true)
            end
        end
    else
        for owner, p_flights in pairs(storage.projector_flights) do
            for i = #p_flights, 1, -1 do
                if p_flights[i].capsule_id == capsule_id then
                    table.remove(p_flights, i)
                    break
                end
            end
            if #p_flights == 0 then
                storage.projector_flights[owner] = nil
                if storage.pending_bvh_removals and storage.pending_bvh_removals[owner] then
                    local sname = storage.pending_bvh_removals[owner]
                    storage.pending_bvh_removals[owner] = nil
                    flow_kinetic.unregister_trajectory_in_bvh(owner, type(sname) == "string" and sname or nil, true)
                end
            end
        end
    end
end

return capsule_ballistics
