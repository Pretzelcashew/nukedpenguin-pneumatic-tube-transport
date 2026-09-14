local flow_engine = require("scripts.flow.flow-engine")
local projector_settings = require("scripts.projectors.projector-settings")
local capsule_transit = require("scripts.capsules.capsule-transit")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local hub_spill = require("scripts.hubs.hub-spill")
local binary_heap = require("scripts.utils.binary-heap")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local flow_kinetic = require("scripts.flow.flow-kinetic")
local timed_motion = require("scripts.utils.timed-motion")

local capsule_ballistics = {}

local USE_TIMED_ARRIVAL = true
capsule_ballistics.USE_TIMED_ARRIVAL = USE_TIMED_ARRIVAL

local MAX_BEAM_DISTANCE = 500
local HOP_DISTANCE = 5
-- SPEED TWEAK: Set to 6 for normal speed (50 tiles/sec).
-- Set to 60 for 10x slow-mo, or 30 for 5x slow-mo!
local TICKS_PER_HOP = 60
local TICKS_PER_TILE = TICKS_PER_HOP / HOP_DISTANCE

capsule_ballistics.MAX_BEAM_DISTANCE = MAX_BEAM_DISTANCE
capsule_ballistics.HOP_DISTANCE = HOP_DISTANCE
capsule_ballistics.TICKS_PER_HOP = TICKS_PER_HOP
capsule_ballistics.TICKS_PER_TILE = TICKS_PER_TILE
trajectory_bvh.TICKS_PER_TILE = TICKS_PER_TILE

function capsule_ballistics.apply_crash_damage(surface, crash_pos, q_lvl, owner_unit, capsule)
    if not (surface and surface.valid and crash_pos) then return end
    local base_damage = projector_settings.PROJECTILE_DAMAGE or 250
    local q_multiplier = 1 + 0.3 * (q_lvl or 0)
    local full_damage = math.floor(base_damage * q_multiplier)

    local proj_entity = owner_unit and storage.active_projectors and storage.active_projectors[owner_unit]
    local p_force = (proj_entity and proj_entity.valid and proj_entity.force) or "neutral"

    pcall(function()
        surface.create_entity{
            name = "explosion",
            position = crash_pos
        }
        surface.play_sound{
            path = "utility/explosion",
            position = crash_pos,
            volume_modifier = 0.8
        }
    end)

    local CRASH_RADIUS = 3.5
    local targets = surface.find_entities_filtered{
        position = crash_pos,
        radius = CRASH_RADIUS
    }

    local damaged_units = {}

    for _, target in ipairs(targets) do
        if target.valid and target.health and target.destructible ~= false then
            local t_name = target.name
            local t_type = target.type
            local is_spill_holder = (t_name == "visible-capsule-holder" or t_name == "spilled-capsule-holder")
            local is_immune = flow_kinetic.PROXY_NAMES[t_name] or is_spill_holder
                or t_type == "resource" or t_type == "entity-ghost" or t_type == "tile-ghost"
                or t_type == "item-entity" or t_type == "corpse" or t_type == "character-corpse"
                or t_type == "flying-robot" or t_type == "logistic-robot" or t_type == "construction-robot"

            if not is_immune then
                damaged_units[target.unit_number or target] = true
                local dist = math.sqrt((target.position.x - crash_pos.x)^2 + (target.position.y - crash_pos.y)^2)
                local dmg = full_damage
                if dist > 1.5 then
                    local ratio = math.min(1.0, (dist - 1.5) / (CRASH_RADIUS - 1.5))
                    dmg = math.max(1, math.floor(full_damage * (1 - 0.7 * ratio)))
                end
                target.damage(dmg, p_force, "impact")
            end
        end
    end

    for _, player in pairs(game.connected_players) do
        local char = player.character
        if char and char.valid and char.surface == surface and not damaged_units[char.unit_number or char] then
            local cpos = char.position
            local dist = math.sqrt((cpos.x - crash_pos.x)^2 + (cpos.y - crash_pos.y)^2)
            if dist <= CRASH_RADIUS then
                damaged_units[char.unit_number or char] = true
                local dmg = full_damage
                if dist > 1.5 then
                    local ratio = math.min(1.0, (dist - 1.5) / (CRASH_RADIUS - 1.5))
                    dmg = math.max(1, math.floor(full_damage * (1 - 0.7 * ratio)))
                end
                char.damage(dmg, p_force, "impact")
            end
        end
    end
end

--------------------------------------------------------------------------------
-- BEAM PORT KEYS & ENDPOINT RESOLUTION
--------------------------------------------------------------------------------
function capsule_ballistics.make_beam_port_key(unit_number, dx, dy, dist)
    return string.format("kinetic:%d:%d,%d:%d", unit_number, math.floor(dx or 0), math.floor(dy or 0), dist)
end

function capsule_ballistics.get_beam_endpoint(unit_number, dx, dy, start_dist)
    local min_dist = math.max(1, start_dist or 1)
    for dist = min_dist, MAX_BEAM_DISTANCE do
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
    if hit_receiver_unit and storage.active_projectors and storage.active_projectors[hit_receiver_unit] then
        local r_ent = storage.active_projectors[hit_receiver_unit]
        if r_ent and r_ent.valid then
            terminal_pos = {
                x = (dx ~= 0) and (r_ent.position.x - dx * 1.5) or muzzle_node.pos.x,
                y = (dy ~= 0) and (r_ent.position.y - dy * 1.5) or muzzle_node.pos.y
            }
        end
    end

    local current_tick = game.tick
    local total_dist = math.abs(terminal_pos.x - muzzle_node.pos.x) + math.abs(terminal_pos.y - muzzle_node.pos.y)
    local flight_ticks = math.max(TICKS_PER_HOP, math.ceil(total_dist * TICKS_PER_TILE))

    if USE_TIMED_ARRIVAL and muzzle_node and terminal_pos then
        local surface = game.surfaces[muzzle_node.surface_name]
        if surface and surface.valid then
            local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
            if tree then
                local owner_rec = tree.trajectories and tree.trajectories[beam_owner]
                if not (owner_rec and owner_rec.segments and next(owner_rec.segments)) then
                    tree:insert_trajectory(beam_owner, muzzle_node.pos, terminal_pos)
                end
            end
        end
    end

    capsule.entered_via_pressure = false
    capsule.beam_flight = {
        start_pos = { x = muzzle_node.pos.x, y = muzzle_node.pos.y },
        orig_terminal_pos = { x = terminal_pos.x, y = terminal_pos.y },
        orig_receiver = hit_receiver_unit,
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
        owner = beam_owner,
        owner_id = beam_owner,
        id = capsule.capsule_id or capsule.id,
        capsule_id = capsule.capsule_id or capsule.id,
        ticks_per_tile = TICKS_PER_TILE,
        total_dist = total_dist,
        dir = { x = dx, y = dy },
        q_level = muzzle_node.q_level or 0
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
                            if drop > 0 and drop > best_drop then
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
        capsule.entered_via_pressure = false

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
        local q_lvl = (current_node and current_node.q_level) or 0
        capsule_ballistics.apply_crash_damage(surface, obstacle_pos, q_lvl, beam_owner, capsule)
        runner.mark_capsule_unparked(capsule)
        local crash_port_key = capsule.from_port_key
        capsule_ballistics.remove_flight(cap_id, beam_owner)
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

    if not capsule.entered_via_pressure then
        return nil
    end

    if not capsule_transit.is_electromagnetic_capsule(capsule) then
        return nil
    end

    local proj_entity = storage.active_projectors[unit_number]
    if not (proj_entity and proj_entity.valid and projector_settings.is_projector_active(proj_entity)) then
        return nil
    end
    if not projector_settings.can_fire(proj_entity) then
        return nil
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
                return nil
            end

            local max_cap = projector_settings.MAX_ENDPOINT_CAPSULES or 2
            local endpoint_count = capsule_ballistics.count_endpoint_capsules(unit_number, endpoint_key, endpoint_node)
            if endpoint_count >= max_cap then
                return nil
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
                        capsule_ballistics.apply_crash_damage(surface, { x = tx, y = ty }, q_lvl, unit_number, capsule)
                        runner.mark_capsule_unparked(capsule)
                        hub_spill.spill_capsule(cap_id, surface, { x = tx, y = ty }, nil, true)
                        runner.wake_parked_capsules(from_port_key)
                        return nil
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

    return nil
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
        capsule.beam_flight = nil
        if capsule_ballistics.catch_in_receiver(capsule, receiver_entity, runner) then
            return true, true
        end
        return true, false
    else
        capsule.beam_flight = nil
        if surface and surface.valid and term_pos then
            local q_lvl = (node and node.q_level) or (bf and bf.q_level) or 0
            local owner_unit = (node and (node.beam_owner or node.unit_number)) or (bf and bf.owner)
            capsule_ballistics.apply_crash_damage(surface, term_pos, q_lvl, owner_unit, capsule)
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
            local q_lvl = bf.q_level or 0
            capsule_ballistics.apply_crash_damage(surface, obst_pos, q_lvl, bf.owner, capsule)
            runner.mark_capsule_unparked(capsule)
            local dead_port_key = capsule.from_port_key
            capsule_ballistics.remove_flight(id, bf.owner)
            hub_spill.spill_capsule(id, surface, obst_pos, nil, true)
            if dead_port_key then
                runner.wake_parked_capsules(dead_port_key)
            end
        else
            capsule.last_pos = next_pos

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
    return timed_motion.get_arrival_heap()
end

function capsule_ballistics.dispatch_timed_launch(capsule, muzzle_node, from_port_key, runner)
    local cap_id = capsule.capsule_id or capsule.id
    capsule.in_timed_flight = true
    capsule.entered_via_pressure = false
    capsule.from_port_key = nil
    capsule.last_port_key = from_port_key
    capsule.to_port_key = nil
    runner.mark_capsule_unparked(capsule)

    if capsule.beam_flight then
        capsule.beam_flight.id = cap_id
        capsule.beam_flight.capsule_id = cap_id
        capsule.beam_flight.owner_id = (capsule.beam_flight and capsule.beam_flight.owner) or muzzle_node.beam_owner or muzzle_node.unit_number
        capsule.beam_flight.owner = capsule.beam_flight.owner_id
        timed_motion.schedule_flight(capsule.beam_flight)
    end

    runner.wake_parked_capsules(from_port_key)
    capsule_renderer.update_arrival_dots(capsule, cap_id)
    return "timed_launched"
end

function capsule_ballistics.update_projector_flights(beam_owner)
    if not beam_owner then return end
    local p_flights = storage.projector_flights and storage.projector_flights[beam_owner]
    if not (p_flights and #p_flights > 0) then return end

    local current_tick = game.tick
    local heap = capsule_ballistics.get_arrival_heap()

    for i = #p_flights, 1, -1 do
        local f_rec = p_flights[i]
        local cap_id = f_rec.capsule_id
        local cap = storage.capsules and storage.capsules[cap_id]
        local bf = cap and cap.beam_flight

        if cap and bf and bf.owner == beam_owner then
            local elapsed_ticks = math.max(0, current_tick - (bf.start_tick or current_tick))
            local cur_dist = math.max(0, math.floor(elapsed_ticks / TICKS_PER_TILE))
            local ep_key, ep_node = capsule_ballistics.get_beam_endpoint(beam_owner, bf.dx, bf.dy, cur_dist + 1)
            if ep_node and ep_node.pos then
                local new_term = { x = ep_node.pos.x, y = ep_node.pos.y }
                local new_receiver = ep_node.hit_receiver
                if new_receiver and storage.active_projectors and storage.active_projectors[new_receiver] then
                    local r_ent = storage.active_projectors[new_receiver]
                    if r_ent and r_ent.valid then
                        new_term = {
                            x = (bf.dx ~= 0) and (r_ent.position.x - bf.dx * 1.5) or bf.start_pos.x,
                            y = (bf.dy ~= 0) and (r_ent.position.y - bf.dy * 1.5) or bf.start_pos.y
                        }
                    end
                end
                local old_term = bf.terminal_pos
                local pos_changed = (old_term == nil) or (old_term.x ~= new_term.x) or (old_term.y ~= new_term.y)
                local receiver_changed = (bf.hit_receiver_unit ~= new_receiver)

                if pos_changed or receiver_changed then
                    timed_motion.shift_horizon(bf, new_term, current_tick, TICKS_PER_HOP)
                    bf.hit_receiver_unit = new_receiver

                    local surface = game.surfaces[bf.surface_name or "nauvis"]
                    if surface and surface.valid then
                        local tree = trajectory_bvh.get_surface_tree(storage, surface.index)
                        if tree then
                            tree:insert_trajectory(beam_owner, bf.start_pos, new_term)
                            trajectory_bvh.refresh_active_renders()
                        end
                    end

                    capsule_renderer.update_arrival_dots(cap, cap_id)
                end
            end
        end
    end
end

function capsule_ballistics.finalize_timed_arrival(capsule, id, runner)
    capsule_renderer.destroy_arrival_dot(capsule)
    local bf = capsule.beam_flight
    if not bf then
        capsule.in_timed_flight = nil
        capsule_ballistics.remove_flight(id)
        runner.remove_capsule(id)
        return
    end

    local beam_owner = bf.owner
    capsule.in_timed_flight = nil
    capsule_ballistics.remove_flight(id, beam_owner)

    bf.current_hop = bf.total_hops
    local handled, arrived = capsule_ballistics.handle_endpoint_arrival(capsule, id, nil, bf, runner)
    if not handled or not arrived then
        local hit_receiver_unit = bf.hit_receiver_unit
        local r_ports = hit_receiver_unit and storage.flow_unit_ports and storage.flow_unit_ports[hit_receiver_unit]
        local dock_port = nil
        if r_ports then
            for _, rp in ipairs(r_ports) do
                local rn = storage.flow_nodes and storage.flow_nodes[rp]
                if rn and not (rn.is_muzzle or rn.kinetic_transmit) then
                    dock_port = rp
                    break
                end
            end
        end
        capsule.beam_flight = nil
        if dock_port then
            capsule.from_port_key = dock_port
            capsule.last_pos = bf.terminal_pos
            capsule.surface_name = bf.surface_name
            capsule.entered_via_pressure = false
            capsule_queries.update_capsule_occupancy(capsule)
            runner.mark_capsule_parked(capsule)
            runner.wake_parked_capsules(dock_port)
        else
            runner.remove_capsule(id)
        end
    end
end

function capsule_ballistics.step_timed_arrivals(current_tick, runner)
    timed_motion.step_arrivals(current_tick, function(top_id)
        local capsule = storage.capsules and storage.capsules[top_id]
        if capsule and capsule.in_timed_flight then
            capsule_ballistics.finalize_timed_arrival(capsule, top_id, runner)
        end
    end)
end

function capsule_ballistics._legacy_step_timed_arrivals(current_tick, runner)
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
    if capsule_id and storage.capsules and storage.capsules[capsule_id] then
        capsule_renderer.destroy_arrival_dot(storage.capsules[capsule_id])
    end
    timed_motion.remove_flight(capsule_id, beam_owner)
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
    flow_kinetic.step_pending_bvh_segments(game.tick)
end

function capsule_ballistics.handle_motion_obstacle_changed(surface, entity, bb, is_removal, motion_hits)
    if not (surface and surface.valid and bb and motion_hits and #motion_hits > 0) then return end

    local current_tick = game.tick
    local affected_corridors = {}
    for i = 1, #motion_hits do
        local cid = motion_hits[i].owner_id
        if cid and not affected_corridors[cid] then
            affected_corridors[cid] = true
        end
    end

    local flights_store = storage.timed_flights or storage.projector_flights
    if not flights_store then return end

    for cid in pairs(affected_corridors) do
        local flights = flights_store[cid]
        if flights and #flights > 0 then
            for f = 1, #flights do
                local f_rec = flights[f]
                local cap_id = f_rec and f_rec.capsule_id
                local cap = cap_id and storage.capsules and storage.capsules[cap_id]
                local bf = cap and cap.beam_flight

                if bf and cap.in_timed_flight then
                    local dx = bf.dx or (bf.dir and bf.dir.x) or 0
                    local dy = bf.dy or (bf.dir and bf.dir.y) or 0
                    local sp = bf.start_pos

                    bf.orig_terminal_pos = bf.orig_terminal_pos or { x = bf.terminal_pos.x, y = bf.terminal_pos.y }
                    bf.orig_receiver = (bf.orig_receiver ~= nil and bf.orig_receiver) or bf.hit_receiver_unit

                    local intersects = false
                    local obst_dist = 0

                    if dx ~= 0 and dy == 0 then
                        if bb.left_top.y - 0.45 <= sp.y and sp.y <= bb.right_bottom.y + 0.45 then
                            local entry_x = (dx > 0) and bb.left_top.x or bb.right_bottom.x
                            obst_dist = (entry_x - sp.x) * dx
                            intersects = true
                        end
                    elseif dy ~= 0 and dx == 0 then
                        if bb.left_top.x - 0.45 <= sp.x and sp.x <= bb.right_bottom.x + 0.45 then
                            local entry_y = (dy > 0) and bb.left_top.y or bb.right_bottom.y
                            obst_dist = (entry_y - sp.y) * dy
                            intersects = true
                        end
                    end

                    if intersects then
                        local elapsed_ticks = math.max(0, current_tick - (bf.start_tick or current_tick))
                        local tpt = bf.ticks_per_tile or TICKS_PER_TILE
                        local cur_dist = elapsed_ticks / tpt

                        if not is_removal then
                            local cur_term_dist = math.abs(bf.terminal_pos.x - sp.x) + math.abs(bf.terminal_pos.y - sp.y)
                            if obst_dist > cur_dist and obst_dist < cur_term_dist then
                                local is_receiver = (entity.name == "pneumatic-projector")
                                local new_term
                                if is_receiver then
                                    new_term = {
                                        x = (dx ~= 0) and (entity.position.x - dx * 1.5) or sp.x,
                                        y = (dy ~= 0) and (entity.position.y - dy * 1.5) or sp.y
                                    }
                                    bf.hit_receiver_unit = entity.unit_number
                                else
                                    local crash_dist = math.max(cur_dist + 0.5, obst_dist - 0.5)
                                    new_term = {
                                        x = sp.x + dx * crash_dist,
                                        y = sp.y + dy * crash_dist
                                    }
                                    bf.hit_receiver_unit = nil
                                end
                                timed_motion.shift_horizon(bf, new_term, current_tick, TICKS_PER_HOP)
                                capsule_renderer.update_arrival_dots(cap, cap_id)
                            end
                        else
                            local orig_term = bf.orig_terminal_pos
                            local orig_dist = math.abs(orig_term.x - sp.x) + math.abs(orig_term.y - sp.y)
                            if obst_dist > cur_dist then
                                local sx = sp.x + dx * (cur_dist + 0.5)
                                local sy = sp.y + dy * (cur_dist + 0.5)
                                local ex = orig_term.x
                                local ey = orig_term.y
                                local area = {
                                    { math.min(sx, ex) - 0.45, math.min(sy, ey) - 0.45 },
                                    { math.max(sx, ex) + 0.45, math.max(sy, ey) + 0.45 }
                                }
                                local cands = surface.find_entities_filtered{ area = area }
                                local closest_dist = orig_dist
                                local closest_rec = bf.orig_receiver

                                for _, cand in ipairs(cands) do
                                    if cand.valid and cand ~= entity then
                                        local is_ignorable = flow_kinetic.IGNORABLE_TYPES[cand.type] or flow_kinetic.PROXY_NAMES[cand.name]
                                        if not is_ignorable and cand.type == "gate" then
                                            if not (cand.is_closed and cand.is_closed()) then
                                                is_ignorable = true
                                            end
                                        end
                                        if not is_ignorable then
                                            local cbb = cand.bounding_box
                                            local d = (dx ~= 0) and (((dx > 0 and cbb.left_top.x or cbb.right_bottom.x) - sp.x) * dx)
                                                                 or (((dy > 0 and cbb.left_top.y or cbb.right_bottom.y) - sp.y) * dy)
                                            if d > cur_dist and d < closest_dist then
                                                closest_dist = d
                                                closest_rec = (cand.name == "pneumatic-projector") and cand.unit_number or nil
                                            end
                                        end
                                    end
                                end

                                local new_term = nil
                                if closest_dist >= orig_dist then
                                    new_term = { x = orig_term.x, y = orig_term.y }
                                    bf.hit_receiver_unit = bf.orig_receiver
                                else
                                    local crash_dist = math.max(cur_dist + 0.5, closest_dist - 0.5)
                                    new_term = {
                                        x = sp.x + dx * crash_dist,
                                        y = sp.y + dy * crash_dist
                                    }
                                    bf.hit_receiver_unit = closest_rec
                                end

                                timed_motion.shift_horizon(bf, new_term, current_tick, TICKS_PER_HOP)
                                capsule_renderer.update_arrival_dots(cap, cap_id)
                            end
                        end
                    end
                end
            end
        end
    end
end

flow_kinetic.update_projector_flights = capsule_ballistics.update_projector_flights
flow_kinetic.handle_motion_obstacle_changed = capsule_ballistics.handle_motion_obstacle_changed

return capsule_ballistics
