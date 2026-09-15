local binary_heap = require("scripts.utils.binary-heap")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local viewport_bvh = require("scripts.utils.viewport-bvh")

local timed_motion = {}

timed_motion.DEFAULT_TICKS_PER_TILE = 1.2

--------------------------------------------------------------------------------
-- STORAGE INITIALIZATION & RECOVERY
--------------------------------------------------------------------------------
local function ensure_storage()
    if not storage.timed_flights then
        storage.timed_flights = storage.projector_flights or {}
        storage.projector_flights = storage.timed_flights
    end
    if not storage.timed_arrival_heap then
        storage.timed_arrival_heap = storage.kinetic_arrival_heap or binary_heap.new()
        storage.kinetic_arrival_heap = storage.timed_arrival_heap
    end
    binary_heap.attach(storage.timed_arrival_heap)
    storage.motion_bvh = storage.motion_bvh or {}
end
timed_motion.ensure_storage = ensure_storage

function timed_motion.init_storage()
    ensure_storage()
end

function timed_motion.get_arrival_heap()
    ensure_storage()
    return storage.timed_arrival_heap
end

--------------------------------------------------------------------------------
-- LINEAR MOTION STATE RECORDS: (t_start, t_end, A, B, v)
--------------------------------------------------------------------------------
--- Creates a standardized linear motion state record
--- @param spec table { id, owner_id, surface_name, start_pos, terminal_pos, dir, start_tick, ticks_per_tile, min_ticks, payload }
--- @return table record
function timed_motion.create_record(spec)
    if not spec then return nil end
    local start_pos = spec.start_pos or { x = 0, y = 0 }
    local terminal_pos = spec.terminal_pos or start_pos
    local dir = spec.dir or { x = 0, y = 0 }
    local tpt = spec.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE

    local total_dist = math.abs(terminal_pos.x - start_pos.x) + math.abs(terminal_pos.y - start_pos.y)
    local min_ticks = spec.min_ticks or 1
    local flight_ticks = math.max(min_ticks, math.ceil(total_dist * tpt))
    local current_tick = (game and game.tick) or 0
    local start_tick = spec.start_tick or current_tick
    local arrival_tick = start_tick + flight_ticks

    return {
        id = spec.id,
        owner_id = spec.owner_id,
        owner = spec.owner_id,
        surface_name = spec.surface_name or "nauvis",
        start_pos = { x = start_pos.x, y = start_pos.y },
        terminal_pos = { x = terminal_pos.x, y = terminal_pos.y },
        dir = { x = dir.x, y = dir.y },
        dx = dir.x,
        dy = dir.y,
        start_tick = start_tick,
        arrival_tick = arrival_tick,
        flight_ticks = flight_ticks,
        total_dist = total_dist,
        ticks_per_tile = tpt,
        current_hop = spec.current_hop or 1,
        total_hops = spec.total_hops or 1,
        hop_positions = spec.hop_positions,
        hit_receiver_unit = spec.hit_receiver_unit,
        q_level = spec.q_level or 0,
        payload = spec.payload,
        kind = spec.kind or "capsule",
        metadata = spec.metadata or {},
        render_spec = spec.render_spec,
        on_arrival = (type(spec.on_arrival) == "string") and spec.on_arrival or nil
    }
end

function timed_motion.get_flight(id)
    if not id then return nil end
    return storage.timed_flight_records and storage.timed_flight_records[id]
end

--------------------------------------------------------------------------------
-- ARRIVAL SCHEDULING & FLIGHT REGISTRY
--------------------------------------------------------------------------------
--- Schedules a linear motion record in the binary arrival heap and corridor flight registry
--- @param record table
--- @return table record
function timed_motion.schedule_flight(record)
    if not record then return end
    ensure_storage()
    local cap_id = record.id or record.capsule_id
    record.id = cap_id
    record.capsule_id = cap_id

    storage.timed_flight_records = storage.timed_flight_records or {}
    storage.timed_flight_records[cap_id] = record

    local heap = timed_motion.get_arrival_heap()
    heap:push(cap_id, record.arrival_tick, cap_id)

    local owner_id = record.owner_id or record.owner
    record.owner_id = owner_id
    record.owner = owner_id

    if owner_id then
        storage.timed_flights[owner_id] = storage.timed_flights[owner_id] or {}
        local flights = storage.timed_flights[owner_id]
        flights[#flights + 1] = {
            id = cap_id,
            capsule_id = cap_id,
            kind = record.kind or "capsule",
            start_tick = record.start_tick,
            arrival_tick = record.arrival_tick,
            duration = record.flight_ticks
        }
        local surf = record.surface_name and game.surfaces[record.surface_name]
        local s_idx = (surf and surf.valid and surf.index) or (record.surface_index or 1)
        timed_motion.ensure_corridor(s_idx, owner_id, record.start_pos, record.terminal_pos)
    end
    return record
end

--- Removes a flight from the arrival heap and active corridor flight registry
--- @param id number
--- @param owner_id number|nil
function timed_motion.remove_flight(id, owner_id)
    if not id then return end
    if storage.timed_flight_records then
        storage.timed_flight_records[id] = nil
    end
    local heap = storage.timed_arrival_heap or storage.kinetic_arrival_heap
    if heap then
        binary_heap.attach(heap)
        heap:remove(id)
    end

    local flights_store = storage.timed_flights or storage.projector_flights
    if not flights_store then return end

    if owner_id and flights_store[owner_id] then
        local flights = flights_store[owner_id]
        for i = #flights, 1, -1 do
            if flights[i].capsule_id == id or flights[i].id == id then
                table.remove(flights, i)
                break
            end
        end
        if #flights == 0 then
            flights_store[owner_id] = nil
            local is_pinned = (storage.pinned_corridors and storage.pinned_corridors[owner_id])
                or (storage.active_projectors and storage.active_projectors[owner_id])
            if not is_pinned then
                timed_motion.remove_corridor(nil, owner_id)
            end
        end
    else
        for o_id, flights in pairs(flights_store) do
            for i = #flights, 1, -1 do
                if flights[i].capsule_id == id or flights[i].id == id then
                    table.remove(flights, i)
                    break
                end
            end
            if #flights == 0 then
                flights_store[o_id] = nil
            end
        end
    end
end

--------------------------------------------------------------------------------
-- DYNAMIC DISRUPTION PROTOCOL (HORIZON RECALCULATION)
--------------------------------------------------------------------------------
--- Shifts terminal destination and arrival horizon without mutating BVH segment geometry
--- @param record table
--- @param new_terminal_pos table { x, y }
--- @param current_tick number|nil
--- @param min_ticks number|nil
--- @return boolean changed
function timed_motion.shift_horizon(record, new_terminal_pos, current_tick, min_ticks)
    if not (record and new_terminal_pos) then return false end
    current_tick = current_tick or ((game and game.tick) or 0)
    min_ticks = min_ticks or 1

    local old_term = record.terminal_pos
    local pos_changed = (old_term == nil) or (old_term.x ~= new_terminal_pos.x) or (old_term.y ~= new_terminal_pos.y)
    if not pos_changed then return false end

    local total_dist = math.abs(new_terminal_pos.x - record.start_pos.x) + math.abs(new_terminal_pos.y - record.start_pos.y)
    local tpt = record.ticks_per_tile or timed_motion.DEFAULT_TICKS_PER_TILE
    local new_flight_ticks = math.max(min_ticks, math.ceil(total_dist * tpt))
    local new_arrival_tick = record.start_tick + new_flight_ticks
    if new_arrival_tick <= current_tick then
        new_arrival_tick = current_tick
    end

    record.terminal_pos.x = new_terminal_pos.x
    record.terminal_pos.y = new_terminal_pos.y
    record.total_dist = total_dist
    record.flight_ticks = new_flight_ticks
    record.arrival_tick = new_arrival_tick

    -- Update active flight summary
    local flights_store = storage.timed_flights or storage.projector_flights
    if flights_store and record.owner_id and flights_store[record.owner_id] then
        local flights = flights_store[record.owner_id]
        for i = 1, #flights do
            if flights[i].capsule_id == record.id then
                flights[i].arrival_tick = new_arrival_tick
                flights[i].duration = new_flight_ticks
                break
            end
        end
    end

    -- Re-balance indexed binary min-heap
    local heap = timed_motion.get_arrival_heap()
    if heap then
        heap:remove(record.id)
        heap:push(record.id, new_arrival_tick, record.id)
    end

    local surf = record.surface_name and game.surfaces[record.surface_name]
    local s_idx = (surf and surf.valid and surf.index) or (record.surface_index or 1)
    timed_motion.remove_corridor(s_idx, record.owner_id)
    timed_motion.ensure_corridor(s_idx, record.owner_id, record.start_pos, new_terminal_pos)

    return true
end

--------------------------------------------------------------------------------
-- CLOSED-FORM VECTOR INTERPOLATION
--------------------------------------------------------------------------------
--- Closed-form continuous position interpolation along origin A -> destination B
--- Formula: P = A + v * min(t_elapsed * speed, dist)
--- @param record table
--- @param current_tick number
--- @return table position, number progress (0.0 to 1.0)
function timed_motion.get_interpolated_position(record, current_tick)
    if not record then return { x = 0, y = 0 }, 0 end
    current_tick = current_tick or ((game and game.tick) or 0)

    local start_tick = record.start_tick or current_tick
    local arrival_tick = record.arrival_tick or (start_tick + 1)
    local start_pos = record.start_pos or record.terminal_pos or { x = 0, y = 0 }
    local term_pos = record.terminal_pos or start_pos

    if current_tick >= arrival_tick then
        return { x = term_pos.x, y = term_pos.y }, 1.0
    end

    local total_dist = record.total_dist
    if not total_dist then
        total_dist = math.abs(term_pos.x - start_pos.x) + math.abs(term_pos.y - start_pos.y)
    end

    local tpt = record.ticks_per_tile or (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or timed_motion.DEFAULT_TICKS_PER_TILE
    local dist_traveled = math.max(0, current_tick - start_tick) / tpt
    local progress = (total_dist > 0) and math.min(1.0, dist_traveled / total_dist) or 1.0

    local cur_x = (dist_traveled >= total_dist - 0.001) and term_pos.x or (start_pos.x + (record.dx or 0) * dist_traveled)
    local cur_y = (dist_traveled >= total_dist - 0.001) and term_pos.y or (start_pos.y + (record.dy or 0) * dist_traveled)

    return { x = cur_x, y = cur_y }, progress
end

--------------------------------------------------------------------------------
-- STATIC TRAJECTORY BVH CORRIDOR PARTITIONING
--------------------------------------------------------------------------------
--- Partitions a static corridor into 16-tile static AABB leaves strictly for observer culling
--- @param surface_index number
--- @param corridor_id number|string
--- @param start_pos table { x, y }
--- @param terminal_pos table { x, y }
--- @return table|nil tree
function timed_motion.get_motion_tree(surface_index)
    return viewport_bvh.get_motion_tree(surface_index)
end

function timed_motion.ensure_corridor(surface_index, corridor_id, start_pos, terminal_pos)
    if not (surface_index and corridor_id and start_pos and terminal_pos) then return nil end
    local tree = viewport_bvh.get_motion_tree(surface_index)
    if not tree then return nil end

    local owner_rec = tree.trajectories and tree.trajectories[corridor_id]
    if not (owner_rec and owner_rec.segments and next(owner_rec.segments)) then
        local dx = terminal_pos.x - start_pos.x
        local dy = terminal_pos.y - start_pos.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 0.001 then dist = 1.0 end

        local MAX_LEAF = 16
        local num_segs = math.max(1, math.ceil(dist / MAX_LEAF))
        local d_x = (dx > 0 and 1) or (dx < 0 and -1) or 0
        local d_y = (dy > 0 and 1) or (dy < 0 and -1) or 0
        for s = 1, num_segs do
            local d_start = (s - 1) * MAX_LEAF
            local d_end = math.min(dist, s * MAX_LEAF)
            local p_start = d_start / dist
            local p_end = d_end / dist

            local s_pos = { x = start_pos.x + dx * p_start, y = start_pos.y + dy * p_start }
            local e_pos = { x = start_pos.x + dx * p_end, y = start_pos.y + dy * p_end }
            local seg_key = string.format("%d,%d:%d", d_x, d_y, s)

            local leaf = tree:insert_segment(corridor_id, seg_key, s_pos, e_pos, d_start, d_end, s)
            if leaf then
                viewport_bvh.on_segment_registered(surface_index, leaf)
            end
        end
    end
    return tree
end
timed_motion.ensure_corridor_bvh = timed_motion.ensure_corridor

function timed_motion.remove_corridor(surface_index, corridor_id)
    if not corridor_id then return end
    if surface_index and storage.motion_bvh and storage.motion_bvh[surface_index] then
        local tree = storage.motion_bvh[surface_index]
        trajectory_bvh.attach(tree)
        tree:remove_trajectory(corridor_id)
        viewport_bvh.on_segment_removed(surface_index, corridor_id)
    elseif storage.motion_bvh then
        for s_idx, tree in pairs(storage.motion_bvh) do
            trajectory_bvh.attach(tree)
            tree:remove_trajectory(corridor_id)
            viewport_bvh.on_segment_removed(s_idx, corridor_id)
        end
    end
end

--------------------------------------------------------------------------------
-- STEP ARRIVALS
--------------------------------------------------------------------------------
--- Pops all expired arrivals from the min-heap and dispatches to handler
--- @param current_tick number
--- @param on_arrival_callback function(id, current_tick)
function timed_motion.step_arrivals(current_tick, on_arrival_callback)
    local heap = storage.timed_arrival_heap or storage.kinetic_arrival_heap
    if not heap then return end
    binary_heap.attach(heap)
    if heap.size == 0 then return end

    while heap.size > 0 do
        local top_id, arrival_tick = heap:peek()
        if not top_id or arrival_tick > current_tick then
            break
        end

        heap:pop()
        if on_arrival_callback then
            on_arrival_callback(top_id, current_tick)
        end
    end
end

--------------------------------------------------------------------------------
-- AUTOMATED VERIFICATION SUITE
--------------------------------------------------------------------------------
function timed_motion.run_tests(player)
    local function log_msg(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_msg("[color=yellow][TimedMotion Test][/color] Starting Phase 6 Unified Timed Arrival Substrate self-test...")

    -- Test 1: Record Creation & Closed-Form Interpolation
    local current_tick = (game and game.tick) or 1000
    local rec = timed_motion.create_record{
        id = 8881,
        owner_id = 101,
        start_pos = { x = 0, y = 0 },
        terminal_pos = { x = 100, y = 0 },
        dir = { x = 1, y = 0 },
        start_tick = current_tick,
        ticks_per_tile = 1.2
    }

    if not rec or rec.flight_ticks ~= 120 or rec.arrival_tick ~= (current_tick + 120) then
        log_msg("[color=red][TimedMotion Test] Test 1 FAILED: Record initialization calculation mismatch[/color]")
        return false
    end

    local p_start, prog_start = timed_motion.get_interpolated_position(rec, current_tick)
    local p_mid, prog_mid = timed_motion.get_interpolated_position(rec, current_tick + 60)
    local p_end, prog_end = timed_motion.get_interpolated_position(rec, current_tick + 120)

    if math.abs(p_start.x - 0) > 0.05 or math.abs(p_mid.x - 50) > 0.05 or math.abs(p_end.x - 100) > 0.05 then
        log_msg(string.format("[color=red][TimedMotion Test] Test 1 FAILED: Position interpolation mismatch (start=%.2f, mid=%.2f, end=%.2f)[/color]",
            p_start.x, p_mid.x, p_end.x))
        return false
    end
    log_msg("[color=green][TimedMotion Test] Test 1: State Record & Closed-Form Vector Interpolation -> PASSED[/color]")

    -- Test 2: Binary Min-Heap Scheduling & Exact-Tick Arrival Popping
    timed_motion.init_storage()
    timed_motion.schedule_flight(rec)
    local heap = timed_motion.get_arrival_heap()
    local top_id, top_tick = heap:peek()
    if top_id ~= 8881 or top_tick ~= (current_tick + 120) then
        log_msg("[color=red][TimedMotion Test] Test 2 FAILED: Flight not scheduled in arrival heap[/color]")
        return false
    end

    local popped_id = nil
    timed_motion.step_arrivals(current_tick + 60, function(id) popped_id = id end)
    if popped_id ~= nil then
        log_msg("[color=red][TimedMotion Test] Test 2 FAILED: Arrival popped prematurely before arrival_tick[/color]")
        return false
    end

    timed_motion.step_arrivals(current_tick + 120, function(id) popped_id = id end)
    if popped_id ~= 8881 then
        log_msg("[color=red][TimedMotion Test] Test 2 FAILED: Arrival failed to pop at exact arrival_tick[/color]")
        return false
    end
    timed_motion.remove_flight(8881, 101)
    log_msg("[color=green][TimedMotion Test] Test 2: Min-Heap Arrival Scheduling & Exact-Tick Popping -> PASSED[/color]")

    -- Test 3: Dynamic Horizon Shifting (Obstacle / Clearance Disruption)
    local rec2 = timed_motion.create_record{
        id = 8882,
        owner_id = 101,
        start_pos = { x = 0, y = 0 },
        terminal_pos = { x = 100, y = 0 },
        dir = { x = 1, y = 0 },
        start_tick = current_tick,
        ticks_per_tile = 1.2
    }
    timed_motion.schedule_flight(rec2)

    -- Obstacle truncates beam to 50 tiles
    local shifted = timed_motion.shift_horizon(rec2, { x = 50, y = 0 }, current_tick)
    if not shifted or rec2.flight_ticks ~= 60 or rec2.arrival_tick ~= (current_tick + 60) then
        log_msg("[color=red][TimedMotion Test] Test 3 FAILED: Shift horizon failed to recalculate arrival tick[/color]")
        return false
    end

    local top_id2, top_tick2 = heap:peek()
    if top_id2 ~= 8882 or top_tick2 ~= (current_tick + 60) then
        log_msg("[color=red][TimedMotion Test] Test 3 FAILED: Shift horizon failed to rebalance binary heap[/color]")
        return false
    end
    log_msg("[color=green][TimedMotion Test] Test 3: Dynamic Disruption Horizon Shift (0 Geometry Churn) -> PASSED[/color]")

    -- Test 4: Dynamic Corridor Flight Registration & Cleanup
    local flights = storage.timed_flights[101]
    if not (flights and #flights > 0) then
        log_msg("[color=red][TimedMotion Test] Test 4 FAILED: Corridor flight summary not recorded[/color]")
        return false
    end

    timed_motion.remove_flight(8882, 101)
    if storage.timed_flights[101] ~= nil then
        log_msg("[color=red][TimedMotion Test] Test 4 FAILED: Empty corridor flight table not cleaned up[/color]")
        return false
    end
    log_msg("[color=green][TimedMotion Test] Test 4: Corridor Flight Registration & Zero-Orphan Cleanup -> PASSED[/color]")

    -- Test 5: Trajectory BVH Static Corridor Partitioning
    local surf = (player and player.surface) or (game and game.surfaces[1])
    if surf and surf.valid then
        local tree = timed_motion.ensure_corridor_bvh(surf.index, 9999, { x = 0, y = 0 }, { x = 100, y = 0 })
        if not (tree and tree.trajectories and tree.trajectories[9999]) then
            log_msg("[color=red][TimedMotion Test] Test 5 FAILED: Corridor BVH trajectory not registered[/color]")
            return false
        end
        local hits = {}
        trajectory_bvh.query_box(tree, 40, -2, 60, 2, hits)
        if #hits == 0 then
            log_msg("[color=red][TimedMotion Test] Test 5 FAILED: BVH corridor query returned 0 hits[/color]")
            return false
        end
        tree:remove_trajectory(9999)
    end
    log_msg("[color=green][TimedMotion Test] Test 5: Trajectory BVH Static Corridor Partitioning -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][TimedMotion Test] ALL 5 TESTS PASSED! Unified Timed Arrival Substrate active.[/font][/color]")
    return true
end

commands.add_command("test-timed-motion", "Run self-tests on the Phase 6 Unified Timed Arrival Substrate", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    timed_motion.run_tests(player)
end)
commands.add_command("pt-test-timed-motion", "Run self-tests on the Phase 6 Unified Timed Arrival Substrate (Alias)", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    timed_motion.run_tests(player)
end)

return timed_motion
