local motion_protocols = {}

-- Composable Subprotocol Facet Registries
motion_protocols.heads = {}
motion_protocols.trails = {}
motion_protocols.disruptions = {}
motion_protocols.arrivals = {}
motion_protocols.static_renders = {}
motion_protocols.protocols = {}

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

function motion_protocols.register_protocol(name, spec)
    motion_protocols.protocols[name] = {
        name = name,
        protocol = name,
        medium = spec.medium or "open_air",
        progression = spec.progression or "continuous",
        head = spec.head or "none",
        trail = spec.trail or "none",
        disruption = spec.disruption or "none",
        arrival = spec.arrival or spec.on_arrival or "none",
        static_render = spec.static_render or "none",
        custom_data = spec.custom_data
    }
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

--------------------------------------------------------------------------------
-- ALTERNATIVE PROTOCOL B: DISRUPTION SUBPROTOCOLS
--------------------------------------------------------------------------------
-- Silent Halt: Clamps remaining distance cleanly on obstacle collision without explosion or spillage
motion_protocols.register_disruption("silent_halt", function(bf, cap, cap_id, surface, entity, bb, is_removal, current_tick)
    local capsule_ballistics = require("scripts.capsules.capsule-ballistics")
    return capsule_ballistics.handle_ballistic_disruption(bf, cap, cap_id, surface, entity, bb, is_removal, current_tick, true, true)
end)

-- Peaceful Spill: Clamps horizon on obstacle cut and drops safe container without explosive impact damage
motion_protocols.register_disruption("peaceful_spill", function(bf, cap, cap_id, surface, entity, bb, is_removal, current_tick)
    local capsule_ballistics = require("scripts.capsules.capsule-ballistics")
    return capsule_ballistics.handle_ballistic_disruption(bf, cap, cap_id, surface, entity, bb, is_removal, current_tick, true, false)
end)

--------------------------------------------------------------------------------
-- PRE-REGISTER BASE PROTOCOLS (EXACT EQUIVALENCE PRESERVATION)
--------------------------------------------------------------------------------
-- 1. Ballistic Cargo & Passenger Capsule
motion_protocols.register_protocol("capsule", {
    medium = "open_air",
    progression = "continuous",
    head = "capsule_head",
    trail = "none",
    disruption = "ballistic_crash",
    arrival = "capsule_terminal"
})

-- 2. Projector Sighting Laser Probe
motion_protocols.register_protocol("projector_scope", {
    medium = "open_air",
    progression = "chained_segment",
    head = "hazard_reticle",
    trail = "reticle_dots",
    disruption = "reticle_slice",
    arrival = "scope_step",
    static_render = "reticle_static"
})

-- 3. Temporal Anti-Reticle Wake Reeling (Arrival cleanup flight: no visible head, no in-flight trail)
motion_protocols.register_protocol("anti_reticle", {
    medium = "open_air",
    progression = "chained_segment",
    head = "none",
    trail = "none",
    disruption = "none",
    arrival = "anti_reticle_step"
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

--------------------------------------------------------------------------------
-- CANONICAL SUBPROTOCOL TEMPLATES (REFERENCE IMPLEMENTATIONS FOR NEW SYSTEMS)
--------------------------------------------------------------------------------
-- Template 1: In-Tube Wave / Sighting Probe (No visible head, quiet disruption)
motion_protocols.register_protocol("tube_wave", {
    medium = "pneumatic_network",
    progression = "continuous",
    head = "none",                  -- Reusable subprotocol: Completely invisible flying head
    trail = "none",                 -- Can hook into custom tube pulse or remain silent
    disruption = "silent_halt",     -- Reusable subprotocol: Stops propagation quietly on cut
    arrival = "none",               -- Plug in custom network query or inventory scan
    static_render = "none"
})

-- Template 2: In-Tube High-Speed Transit Flight (Capsule visuals, peaceful on deconstruction)
motion_protocols.register_protocol("tube_transit", {
    medium = "pneumatic_network",
    progression = "continuous",
    head = "capsule_head",          -- Subprotocol overlap: Reuses passenger HUD, ring, and cargo icons!
    trail = "none",
    disruption = "peaceful_spill",  -- Subprotocol overlap: Safe ground container, zero crash explosion!
    arrival = "capsule_terminal",   -- Subprotocol overlap: Docks into receiver/hub!
    static_render = "none"
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
    local wave_proto = motion_protocols.get_protocol("tube_wave")
    local wave_head = motion_protocols.get_subprotocol(wave_proto, "head")
    if wave_head ~= nil then
        log_msg("[color=red][MotionProtocols Test] Test 5 FAILED: tube_wave head subprotocol expected nil but found handler[/color]")
        return false
    end
    local transit_proto = motion_protocols.get_protocol("tube_transit")
    local transit_head = motion_protocols.get_subprotocol(transit_proto, "head")
    if transit_head == nil then
        log_msg("[color=red][MotionProtocols Test] Test 5 FAILED: tube_transit failed to resolve capsule_head subprotocol[/color]")
        return false
    end
    log_msg("[color=green][MotionProtocols Test] Test 5: Head & Trail Facet Independence -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][MotionProtocols Test] ALL 5 TESTS PASSED! Modular Subprotocol Architecture operational.[/font][/color]")
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

return motion_protocols
