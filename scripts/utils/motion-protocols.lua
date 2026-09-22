local motion_protocols = {}

-- Composable Subprotocol Facet Registries
motion_protocols.heads = {}
motion_protocols.trails = {}
motion_protocols.disruptions = {}
motion_protocols.arrivals = {}
motion_protocols.static_renders = {}
motion_protocols.detectors = {}
motion_protocols.clearance_policies = {}
motion_protocols.protocols = {}

-- Canonical Render Pool Channel Constants
motion_protocols.CHANNELS = {
    RETICLE = "reticle",
    CAPSULE = "capsule",
    ARRIVAL = "arrival",
    FLOW = "flow",
    DEFAULT = "default"
}

--------------------------------------------------------------------------------
-- SPATIAL AXIS PROJECTION HELPERS
--------------------------------------------------------------------------------
--- Calculates 1D on-axis distance from start_pos along cardinal dir to an AABB bounding box
--- @param sp table { x, y }
--- @param dir table { x, y }
--- @param bb table { left_top = {x, y}, right_bottom = {x, y} }
--- @param width_margin number|nil
--- @return boolean intersects, number distance
function motion_protocols.calculate_axis_distance(sp, dir, bb, width_margin)
    local margin = width_margin or 0.45
    local dx = dir.x or 0
    local dy = dir.y or 0

    if dx > 0 then
        if (bb.left_top.y - margin <= sp.y) and (sp.y <= bb.right_bottom.y + margin) then
            local d = (bb.left_top.x <= sp.x and bb.right_bottom.x >= sp.x - 0.5) and 0.1 or (bb.left_top.x - sp.x)
            return true, d
        end
    elseif dx < 0 then
        if (bb.left_top.y - margin <= sp.y) and (sp.y <= bb.right_bottom.y + margin) then
            local d = (bb.right_bottom.x >= sp.x and bb.left_top.x <= sp.x + 0.5) and 0.1 or (sp.x - bb.right_bottom.x)
            return true, d
        end
    elseif dy > 0 then
        if (bb.left_top.x - margin <= sp.x) and (sp.x <= bb.right_bottom.x + margin) then
            local d = (bb.left_top.y <= sp.y and bb.right_bottom.y >= sp.y - 0.5) and 0.1 or (bb.left_top.y - sp.y)
            return true, d
        end
    elseif dy < 0 then
        if (bb.left_top.x - margin <= sp.x) and (sp.x <= bb.right_bottom.x + margin) then
            local d = (bb.right_bottom.y >= sp.y and bb.left_top.y <= sp.y + 0.5) and 0.1 or (sp.y - bb.right_bottom.y)
            return true, d
        end
    end

    return false, 0
end

--------------------------------------------------------------------------------
-- PROGRESSION TIMING WINDOW RESOLUTION
--------------------------------------------------------------------------------
function motion_protocols.get_progression_window(flight, flight_rec, leaf, d_start, d_end, tpt)
    local proto_src = nil
    if flight_rec and (flight_rec.protocol or flight_rec.kind or flight_rec.on_arrival) then
        proto_src = flight_rec
    elseif flight and (flight.protocol or flight.kind or flight.on_arrival) then
        proto_src = flight
    else
        proto_src = flight or flight_rec
    end

    local proto = motion_protocols.get_protocol(proto_src)
    local prog_type = proto and proto.progression or "continuous"
    local has_visible_head = (proto and proto.head ~= "none")

    if prog_type == "chained_segment" then
        local f_seg = (flight_rec and flight_rec.seg_idx) or (flight and flight.seg_idx) or 1
        local l_seg = leaf and leaf.seg_idx or 1
        if f_seg == l_seg then
            local t_entry = (flight and flight.start_tick) or (flight_rec and flight_rec.start_tick) or 0
            local t_exit = (flight and flight.arrival_tick) or (flight_rec and flight_rec.arrival_tick) or (t_entry + math.ceil((d_end - d_start) * tpt))
            return t_entry, t_exit, has_visible_head
        else
            return -1, -1, has_visible_head
        end
    else
        local t_start = (flight and flight.start_tick) or (flight_rec and flight_rec.start_tick) or 0
        local t_entry = t_start + math.floor(d_start * tpt)
        local t_exit = t_start + math.ceil(d_end * tpt)
        return t_entry, t_exit, has_visible_head
    end
end

--------------------------------------------------------------------------------
-- SUBPROTOCOL REGISTRATION API
--------------------------------------------------------------------------------
function motion_protocols.register_head(name, handler)
    motion_protocols.heads[name] = handler
end

function motion_protocols.register_trail(name, handler)
    motion_protocols.trails[name] = handler
end

function motion_protocols.register_disruption(name, handler)
    motion_protocols.disruptions[name] = handler
end

function motion_protocols.register_arrival(name, handler)
    motion_protocols.arrivals[name] = handler
end

function motion_protocols.register_static_render(name, handler)
    motion_protocols.static_renders[name] = handler
end

function motion_protocols.register_detector(name, handler)
    motion_protocols.detectors[name] = handler
end

function motion_protocols.register_clearance_policy(name, policy_spec)
    motion_protocols.clearance_policies[name] = {
        name = name,
        on_forward = policy_spec.on_forward,
        on_backward = policy_spec.on_backward
    }
end

function motion_protocols.dispatch_clearance_policy(flight_or_ret, d_obst, d_current, entity, is_removal, current_tick, extra)
    local proto = motion_protocols.get_protocol(flight_or_ret)
    local policy = proto and motion_protocols.clearance_policies[proto.clearance_policy]
    if not policy then return false end

    if d_obst > (d_current + 0.05) then
        if policy.on_forward then
            policy.on_forward(flight_or_ret, d_obst, d_current, entity, is_removal, current_tick, extra)
            return true
        end
    else
        if policy.on_backward then
            policy.on_backward(flight_or_ret, d_obst, d_current, entity, is_removal, current_tick, extra)
            return true
        end
    end
    return false
end

function motion_protocols.register_protocol(name, spec)
    local p_entry = {
        name = name,
        protocol = name,
        medium = spec.medium or "open_air",
        progression = spec.progression or "continuous",
        head = spec.head or "none",
        trail = spec.trail or "none",
        disruption = spec.disruption or "none",
        arrival = spec.arrival or spec.on_arrival or "none",
        static_render = spec.static_render or "none",
        detector = spec.detector or "open_air_solids",
        clearance_policy = spec.clearance_policy or "discrete_projectile",
        render_channel = spec.render_channel or (name == "projector_scope" and "reticle") or (name == "capsule" and "capsule") or "default",
        custom_data = spec.custom_data
    }
    motion_protocols.protocols[name] = p_entry
    return p_entry
end

function motion_protocols.get_render_channel(name_or_flight)
    local proto = motion_protocols.get_protocol(name_or_flight)
    return (proto and proto.render_channel) or "default"
end

function motion_protocols.get_protocol(name_or_flight)
    if not name_or_flight then
        return motion_protocols.protocols["capsule"]
    end
    if type(name_or_flight) == "table" then
        -- Return directly if an already-resolved protocol definition table was passed
        if name_or_flight.head ~= nil and name_or_flight.disruption ~= nil then
            return name_or_flight
        end
        local p_name = name_or_flight.protocol or name_or_flight.name or name_or_flight.kind or (type(name_or_flight.on_arrival) == "string" and name_or_flight.on_arrival)
        if not p_name then
            -- Infer reticle identity from structural state
            if name_or_flight.projector_unit ~= nil or name_or_flight.head_flight_id ~= nil or name_or_flight.anti_flight_id ~= nil or name_or_flight.retreat_tick ~= nil or name_or_flight.head_render_spec ~= nil then
                p_name = "projector_scope"
            elseif name_or_flight.beam_flight ~= nil or name_or_flight.passenger ~= nil or name_or_flight.capsule_type ~= nil then
                p_name = "capsule"
            end
        end
        return (p_name and motion_protocols.protocols[p_name]) or motion_protocols.protocols["capsule"]
    end
    return motion_protocols.protocols[name_or_flight] or motion_protocols.protocols["capsule"]
end

function motion_protocols.get_subprotocol(name_or_flight, facet)
    local proto = motion_protocols.get_protocol(name_or_flight)
    if not (proto and facet) then return nil end
    local sub_name = proto[facet]
    if not sub_name or sub_name == "none" then return nil end

    local registry = motion_protocols[facet .. "s"] or motion_protocols[facet]
    return registry and registry[sub_name]
end

--------------------------------------------------------------------------------
-- DEFAULT FALLBACKS & NULL SUBPROTOCOLS
--------------------------------------------------------------------------------
motion_protocols.register_head("none", nil)
motion_protocols.register_trail("none", nil)
motion_protocols.register_disruption("none", function(flight, interruption)
    -- Default non-disruptive behavior: no-op
    return false
end)
motion_protocols.register_arrival("none", function(flight_id, flight, current_tick, runner)
    -- Default silent completion
    return true
end)

motion_protocols.register_arrival("tube_hop", function(flight_id, flight, current_tick, runner)
    if runner and runner.handle_tube_hop_arrival then
        return runner.handle_tube_hop_arrival(flight_id, flight, current_tick)
    end
    return true
end)

--------------------------------------------------------------------------------
-- ALTERNATIVE PROTOCOL B: DISRUPTION SUBPROTOCOLS
--------------------------------------------------------------------------------
-- Alternative disruption defaults (flags evaluated during terminal arrival)
motion_protocols.register_disruption("silent_halt", function(bf, cap, cap_id, surface, entity, bb, is_removal, current_tick)
    if bf then bf.silent_halt = true end
    return true
end)

motion_protocols.register_disruption("peaceful_spill", function(bf, cap, cap_id, surface, entity, bb, is_removal, current_tick)
    if bf then bf.peaceful_spill = true end
    return true
end)

--------------------------------------------------------------------------------
-- PRE-REGISTER BASE PROTOCOLS (EXACT EQUIVALENCE PRESERVATION)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- CORE DETECTOR & CLEARANCE SUBPROTOCOLS
--------------------------------------------------------------------------------
-- Detector: Pneumatic Network Graph (checks if pipe/node exists in flow grid)
motion_protocols.register_detector("tube_connectivity", function(node_or_edge)
    if not node_or_edge or not node_or_edge.valid then
        return true, false -- Missing/broken tube = barrier
    end
    return false, node_or_edge.is_dock or false
end)

-- 1. Ballistic Cargo & Passenger Capsule
motion_protocols.register_protocol("capsule", {
    medium = "open_air",
    progression = "continuous",
    head = "capsule_head",
    trail = "none",
    disruption = "ballistic_crash",
    arrival = "capsule_terminal",
    detector = "open_air_solids",
    clearance_policy = "discrete_projectile",
    render_channel = "capsule"
})

-- 2. Projector Sighting Laser Probe
motion_protocols.register_protocol("projector_scope", {
    medium = "open_air",
    progression = "chained_segment",
    head = "hazard_reticle",
    trail = "reticle_dots",
    disruption = "reticle_slice",
    arrival = "scope_step",
    static_render = "reticle_static",
    detector = "open_air_solids",
    clearance_policy = "optical_ray"
})

-- 3. Temporal Anti-Reticle Wake Reeling (Arrival cleanup flight: no visible head, no in-flight trail)
motion_protocols.register_protocol("anti_reticle", {
    medium = "open_air",
    progression = "chained_segment",
    head = "none",
    trail = "none",
    disruption = "none",
    arrival = "anti_reticle_step",
    detector = "open_air_solids",
    clearance_policy = "none"
})

-- Alias for backwards compatibility
motion_protocols.register_protocol("projectile", {
    medium = "open_air",
    progression = "continuous",
    head = "custom_flight",
    trail = "none",
    disruption = "ballistic_crash",
    arrival = "none"
})

-- 4. Pressurized Pneumatic Tube 1-Tile Hop
motion_protocols.register_protocol("tube_hop", {
    medium = "pneumatic_network",
    progression = "continuous",
    head = "capsule_head",
    trail = "none",
    disruption = "none",
    arrival = "tube_hop",
    detector = "tube_connectivity",
    clearance_policy = "none",
    render_channel = "capsule"
})

--------------------------------------------------------------------------------
-- AUTOMATED VERIFICATION SUITE
--------------------------------------------------------------------------------
function motion_protocols.run_tests(player)
    local function log_msg(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_msg("[color=yellow][MotionProtocols Test][/color] Starting Modular Subprotocol Architecture self-test...")

    -- Test 1: Subprotocol Registry & Default Fallbacks
    local cap_proto = motion_protocols.get_protocol("capsule")
    if not cap_proto or cap_proto.head ~= "capsule_head" or cap_proto.disruption ~= "ballistic_crash" then
        log_msg("[color=red][MotionProtocols Test] Test 1 FAILED: Capsule base protocol definition mismatch[/color]")
        return false
    end
    local fallback_proto = motion_protocols.get_protocol("unregistered_protocol_xyz")
    if not fallback_proto or fallback_proto.name ~= "capsule" then
        log_msg("[color=red][MotionProtocols Test] Test 1 FAILED: Unregistered protocol failed to fall back to capsule[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 1: Base Registry & Fallback Resolution -> PASSED[/color]")

    -- Test 2: Subprotocol Overlap & Composition (Custom Mixin)
    motion_protocols.register_protocol("test_hybrid_flight", {
        medium = "pneumatic_network",
        progression = "continuous",
        head = "capsule_head",          -- Inherited from Capsule
        trail = "reticle_dots",         -- Inherited from Reticle
        disruption = "peaceful_spill",  -- Alternative Protocol B
        arrival = "none"
    })
    local hybrid = motion_protocols.get_protocol("test_hybrid_flight")
    if not (hybrid and hybrid.head == "capsule_head" and hybrid.trail == "reticle_dots" and hybrid.disruption == "peaceful_spill") then
        log_msg("[color=red][MotionProtocols Test] Test 2 FAILED: Hybrid protocol failed to compose overlapping subprotocols[/color]")
        return false
    end
    local head_fn = motion_protocols.get_subprotocol(hybrid, "head")
    local trail_fn = motion_protocols.get_subprotocol(hybrid, "trail")
    local disrupt_fn = motion_protocols.get_subprotocol(hybrid, "disruption")
    if not (head_fn and trail_fn and disrupt_fn) then
        log_msg(string.format("[color=red][MotionProtocols Test] Test 2 FAILED: Missing delegate (head=%s, trail=%s, disrupt=%s)[/color]",
            tostring(head_fn ~= nil), tostring(trail_fn ~= nil), tostring(disrupt_fn ~= nil)))
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 2: Overlapping Subprotocol Composition -> PASSED[/color]")

    -- Test 3: Progression Window Timing Resolution
    local dummy_continuous = { start_tick = 1000, protocol = "capsule" }
    local dummy_leaf = { d_start = 16, d_end = 32, seg_idx = 2 }
    local tpt = 1.2
    local t_entry_c, t_exit_c, vis_c = motion_protocols.get_progression_window(dummy_continuous, nil, dummy_leaf, 16, 32, tpt)
    local expected_entry_c = 1000 + math.floor(16 * tpt)
    local expected_exit_c = 1000 + math.ceil(32 * tpt)
    if t_entry_c ~= expected_entry_c or t_exit_c ~= expected_exit_c or not vis_c then
        log_msg(string.format("[color=red][MotionProtocols Test] Test 3 FAILED: Continuous window mismatch: entry=%s (exp %s), exit=%s (exp %s)[/color]",
            tostring(t_entry_c), tostring(expected_entry_c), tostring(t_exit_c), tostring(expected_exit_c)))
        return false
    end

    local dummy_scope = { start_tick = 1000, arrival_tick = 1020, protocol = "projector_scope" }
    local dummy_rec_matching = { seg_idx = 2, protocol = "projector_scope" }
    local t_entry_s, t_exit_s = motion_protocols.get_progression_window(dummy_scope, dummy_rec_matching, dummy_leaf, 16, 32, tpt)
    if t_entry_s ~= 1000 or t_exit_s ~= 1020 then
        log_msg(string.format("[color=red][MotionProtocols Test] Test 3 FAILED: Chained segment window mismatch (entry=%s exp 1000, exit=%s exp 1020)[/color]",
            tostring(t_entry_s), tostring(t_exit_s)))
        return false
    end
    local dummy_rec_mismatched = { seg_idx = 1 }
    local t_entry_m, t_exit_m = motion_protocols.get_progression_window(dummy_scope, dummy_rec_mismatched, dummy_leaf, 16, 32, tpt)
    if t_entry_m ~= -1 or t_exit_m ~= -1 then
        log_msg("[color=red][MotionProtocols Test] Test 3 FAILED: Chained segment failed to return -1 on non-matching segment[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 3: Progression Window Timing Resolution -> PASSED[/color]")

    -- Test 4: Alternative Disruption Flags
    local test_bf = { start_pos = { x = 0, y = 0 }, terminal_pos = { x = 50, y = 0 }, dir = { x = 1, y = 0 }, dx = 1, dy = 0 }
    local p_disrupt = motion_protocols.disruptions["peaceful_spill"]
    if not p_disrupt then
        log_msg("[color=red][MotionProtocols Test] Test 4 FAILED: peaceful_spill disruption subprotocol not registered[/color]")
        return false
    end
    local s_disrupt = motion_protocols.disruptions["silent_halt"]
    if not s_disrupt then
        log_msg("[color=red][MotionProtocols Test] Test 4 FAILED: silent_halt disruption subprotocol not registered[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 4: Alternative Disruption Subprotocols -> PASSED[/color]")

    -- Test 5: Head & Trail Facet Independence
    local anti_proto = motion_protocols.get_protocol("anti_reticle")
    local anti_head = motion_protocols.get_subprotocol(anti_proto, "head")
    if anti_head ~= nil then
        log_msg("[color=red][MotionProtocols Test] Test 5 FAILED: anti_reticle head subprotocol expected nil but found handler[/color]")
        return false
    end
    local cap_proto = motion_protocols.get_protocol("capsule")
    local cap_head = motion_protocols.get_subprotocol(cap_proto, "head")
    if cap_head == nil then
        log_msg("[color=red][MotionProtocols Test] Test 5 FAILED: capsule failed to resolve capsule_head subprotocol[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 5: Head & Trail Facet Independence -> PASSED[/color]")

    -- Test 6: Disruption Detector Subprotocols
    local air_det = motion_protocols.detectors["open_air_solids"]
    if not air_det then
        log_msg("[color=red][MotionProtocols Test] Test 6 FAILED: open_air_solids detector not registered[/color]")
        return false
    end
    local tube_det = motion_protocols.detectors["tube_connectivity"]
    if not tube_det or not tube_det(nil) then
        log_msg("[color=red][MotionProtocols Test] Test 6 FAILED: tube_connectivity detector failed on missing node[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 6: Disruption Detector Subprotocols -> PASSED[/color]")

    -- Test 7: Directional Clearance Policies (Forward vs Backward Bifurcation)
    local test_forward_called = false
    local test_backward_called = false
    motion_protocols.register_clearance_policy("test_policy", {
        on_forward = function() test_forward_called = true end,
        on_backward = function() test_backward_called = true end
    })
    local test_flight = { protocol = "test_clearance", clearance_policy = "test_policy" }
    motion_protocols.register_protocol("test_clearance", test_flight)

    -- Forward disruption (d_obst > d_current)
    motion_protocols.dispatch_clearance_policy(test_flight, 50, 20, nil, false, 1000)
    if not test_forward_called or test_backward_called then
        log_msg("[color=red][MotionProtocols Test] Test 7 FAILED: Forward clearance policy dispatch incorrect[/color]")
        return false
    end

    -- Backward disruption (d_obst <= d_current)
    test_forward_called = false
    test_backward_called = false
    motion_protocols.dispatch_clearance_policy(test_flight, 10, 20, nil, false, 1000)
    if not test_backward_called or test_forward_called then
        log_msg("[color=red][MotionProtocols Test] Test 7 FAILED: Backward clearance policy dispatch incorrect[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 7: Directional Clearance Policies (Forward vs Backward) -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][MotionProtocols Test] ALL 7 TESTS PASSED! Detector and Clearance Protocols operational.[/font][/color]")
    return true
end

commands.add_command("test-motion-protocols", "Run self-tests on the Modular Subprotocol Architecture", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    motion_protocols.run_tests(player)
end)
commands.add_command("pt-test-motion-protocols", "Run self-tests on the Modular Subprotocol Architecture (Alias)", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    motion_protocols.run_tests(player)
end)

--------------------------------------------------------------------------------
-- OPEN-AIR LEAF SPATIAL SCANNER (MODULAR DETECTOR DELEGATE)
--------------------------------------------------------------------------------
function motion_protocols.scan_open_air_leaf(surface, start_pos, dir, step_dist, sender_unit, reticle_id, kin_mod)
    if not (surface and surface.valid and start_pos and dir and step_dist and step_dist > 0) then return nil end
    local dx = dir.x or 0
    local dy = dir.y or 0
    if dx == 0 and dy == 0 then return nil end

    local min_x, max_x, min_y, max_y
    if dx ~= 0 then
        min_x = math.min(start_pos.x - dx * 0.5, start_pos.x + dx * step_dist)
        max_x = math.max(start_pos.x - dx * 0.5, start_pos.x + dx * step_dist)
        min_y = start_pos.y - 0.45
        max_y = start_pos.y + 0.45
    else
        min_x = start_pos.x - 0.45
        max_x = start_pos.x + 0.45
        min_y = math.min(start_pos.y - dy * 0.5, start_pos.y + dy * step_dist)
        max_y = math.max(start_pos.y - dy * 0.5, start_pos.y + dy * step_dist)
    end

    local candidates = surface.find_entities_filtered{
        area = {{min_x, min_y}, {max_x, max_y}}
    }

    local closest_dist = step_dist + 0.05
    local closest_entity = nil
    local detector_fn = motion_protocols.get_subprotocol("projector_scope", "detector")
        or motion_protocols.detectors["open_air_solids"]

    local flow_kinetic = kin_mod

    for _, cand in ipairs(candidates) do
        local is_self = (cand.unit_number and sender_unit and cand.unit_number == sender_unit)
        if cand.valid and not is_self then
            local is_obstacle = detector_fn(cand, surface)
            if not is_obstacle and cand.type == "gate" and reticle_id and cand.unit_number then
                local ret = storage.projector_reticles and storage.projector_reticles[reticle_id]
                if ret and ret.start_pos then
                    local cbb = cand.bounding_box
                    local _, abs_dist = motion_protocols.calculate_axis_distance(ret.start_pos, ret.dir, cbb, 0.05)
                    flow_kinetic.register_corridor_gate(reticle_id, cand, abs_dist or step_dist or 1, false)
                end
            end

            if is_obstacle then
                local cbb = cand.bounding_box
                if cand.type == "character" then
                    local pos = cand.position
                    local tx = math.floor(pos.x)
                    local ty = math.floor(pos.y)
                    cbb = {
                        left_top = { x = tx, y = ty },
                        right_bottom = { x = tx + 1.0, y = ty + 1.0 }
                    }
                end
                local on_axis, d = motion_protocols.calculate_axis_distance(start_pos, dir, cbb, 0.05)
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

return motion_protocols
