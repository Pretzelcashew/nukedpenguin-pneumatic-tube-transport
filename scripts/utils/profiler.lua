local profiler = {}

-- Master release switch: set to false to completely disable and compile out the profiler for release builds
profiler.ENABLED = true

local window_ticks = 60
local current_tick_count = 0

local accumulators = {}
local latest_results = {}
local snapshot_countdown = 0
local snapshot_target_player = nil

local event_accumulators = {}
local event_counts = {}
local handler_accumulators = {}
local handler_counts = {}
local latest_event_results = {}

local bvh_accumulators = {}
local bvh_counts = {}
local bvh_breach_count = 0
local latest_bvh_results = {}

local system_order = {
    "Flow Engine",
    "Capsule Motion",
    "Capsules: Tube Traversal",
    "Capsules: Ballistics",
    "Capsules: Frame Sync",
    "Hub Logistics",
    "Device Scanner",
    "Scanner: Counters",
    "Scanner: Diverters",
    "Scanner: Pumps",
    "Scanner: Projectors",
    "Scanner: Cache",
    "Counter Logic",
    "Counter Range",
    "Proxy Manager",
    "Diverter Logic",
    "Pump Logic",
    "Projector Logic",
    "Debug Manager",
}

local function get_create_profiler()
    if helpers and helpers.create_profiler then
        return helpers.create_profiler
    elseif game and game.create_profiler then
        return game.create_profiler
    end
    return nil
end

function profiler.resolve_name(handler, custom_name)
    if custom_name and custom_name ~= "" then
        return custom_name
    end

    if type(handler) == "function" then
        local info = debug.getinfo(handler, "S")
        if info and info.source then
            local src = info.source:lower()
            if src:find("flow") then
                return "Flow Engine"
            elseif src:find("capsule") then
                return "Capsule Motion"
            elseif src:find("hub") then
                return "Hub Logistics"
            elseif src:find("scanner") or src:find("active%-device") then
                return "Device Scanner"
            elseif src:find("counter") then
                return "Counter Logic"
            elseif src:find("diverter") then
                return "Diverter Logic"
            elseif src:find("pump") then
                return "Pump Logic"
            elseif src:find("projector") then
                return "Projector Logic"
            elseif src:find("proxy") then
                return "Proxy Manager"
            elseif src:find("debug") then
                return "Debug Manager"
            else
                local filename = src:match("([^/\\]+)%.lua$")
                if filename then
                    return filename
                end
            end
        end
    end

    return "Other"
end

function profiler.is_active()
    if not profiler.ENABLED then
        return false
    end

    if snapshot_countdown > 0 then
        return true
    end

    if storage and storage.debug then
        for _, dbg in pairs(storage.debug) do
            if dbg and dbg.master and dbg.profiler then
                return true
            end
        end
    end

    if game and game.players then
        for _, player in pairs(game.players) do
            if player and player.valid and player.gui.screen["pneumatic_debug_panel"] then
                return true
            end
        end
    end

    return false
end

function profiler.is_event_log_active()
    if not profiler.ENABLED then return false end
    if storage and storage.debug then
        for _, dbg in pairs(storage.debug) do
            if dbg and dbg.master and (dbg.event_log or dbg.profiler) then
                return true
            end
        end
    end
    return false
end

local function safe_add(target, other)
    if not (target and target.valid and other and other.valid) then return end
    local ok = pcall(function() target.add(other) end)
    if not ok then
        pcall(function() target:add(other) end)
    end
end

local function safe_divide(target, number)
    if not (target and target.valid and number and number > 0) then return end
    local ok = pcall(function() target.divide(number) end)
    if not ok then
        pcall(function() target:divide(number) end)
    end
end

local function safe_stop(target)
    if not (target and target.valid) then return end
    local ok = pcall(function() target.stop() end)
    if not ok then
        pcall(function() target:stop() end)
    end
end

function profiler.start_timer()
    local create = get_create_profiler()
    if not create then return nil end
    return create()
end

function profiler.start_sub_timer(name)
    if not profiler.ENABLED or not profiler.is_active() then return nil end
    local create = get_create_profiler()
    if not create then return nil end
    return create()
end

function profiler.stop_sub_timer(name, timer)
    if not timer or not timer.valid then return end
    safe_stop(timer)

    if not accumulators[name] then
        accumulators[name] = timer
    else
        safe_add(accumulators[name], timer)
    end
end

function profiler.stop_timer(system_name, timer)
    if not timer or not timer.valid then return end
    safe_stop(timer)

    local name = system_name or "Other"

    if not accumulators[name] then
        accumulators[name] = timer
    else
        safe_add(accumulators[name], timer)
    end

    local create = get_create_profiler()
    if not accumulators["__TOTAL__"] then
        if create then
            local tot = create(true)
            safe_add(tot, timer)
            accumulators["__TOTAL__"] = tot
        end
    else
        safe_add(accumulators["__TOTAL__"], timer)
    end
end

function profiler.record_bvh(op_name, timer, is_breach)
    if not timer or not timer.valid then return end
    safe_stop(timer)

    local name = op_name or "BVH"
    local bvh_key = "BVH: " .. name

    if is_breach then
        bvh_breach_count = bvh_breach_count + 1
        if profiler.is_event_log_active() then
            local msg = {"", "[PT BVH] Shell breach (", name, "): ", timer}
            if storage and storage.debug then
                for p_idx, dbg in pairs(storage.debug) do
                    if dbg and dbg.master and (dbg.event_log or dbg.profiler) then
                        local p = game.get_player(p_idx)
                        if p and p.valid then p.print(msg) end
                    end
                end
            end
        end
    end

    bvh_counts[name] = (bvh_counts[name] or 0) + 1
    local create = get_create_profiler()
    if not bvh_accumulators[name] then
        if create then
            local t_acc = create(true)
            safe_add(t_acc, timer)
            bvh_accumulators[name] = t_acc
        end
    else
        safe_add(bvh_accumulators[name], timer)
    end

    if not accumulators[bvh_key] then
        accumulators[bvh_key] = timer
    else
        safe_add(accumulators[bvh_key], timer)
    end
end

function profiler.record_event_handler(event_name, handler_name, timer, log_active)
    if not timer or not timer.valid then return end
    safe_stop(timer)

    local h_name = handler_name or "Other"
    local ev_name = event_name or "unknown_event"
    local combo_key = ev_name .. "::" .. h_name

    if log_active then
        local msg = {"", "[PT Event] ", ev_name, " ➔ ", h_name, ": ", timer}
        if storage and storage.debug then
            for p_idx, dbg in pairs(storage.debug) do
                if dbg and dbg.master and (dbg.event_log or dbg.profiler) then
                    local p = game.get_player(p_idx)
                    if p and p.valid then p.print(msg) end
                end
            end
        end
    end

    if not accumulators[h_name] then
        accumulators[h_name] = timer
    else
        safe_add(accumulators[h_name], timer)
    end

    local create = get_create_profiler()
    if not accumulators["__TOTAL__"] then
        if create then
            local tot = create(true)
            safe_add(tot, timer)
            accumulators["__TOTAL__"] = tot
        end
    else
        safe_add(accumulators["__TOTAL__"], timer)
    end

    event_counts[ev_name] = (event_counts[ev_name] or 0) + 1
    if not event_accumulators[ev_name] then
        if create then
            local ev_tot = create(true)
            safe_add(ev_tot, timer)
            event_accumulators[ev_name] = ev_tot
        end
    else
        safe_add(event_accumulators[ev_name], timer)
    end

    handler_counts[combo_key] = (handler_counts[combo_key] or 0) + 1
    if not handler_accumulators[combo_key] then
        if create then
            local h_tot = create(true)
            safe_add(h_tot, timer)
            handler_accumulators[combo_key] = h_tot
        end
    else
        safe_add(handler_accumulators[combo_key], timer)
    end
end

function profiler.print_summary(player)
    if not (player and player.valid) then return end

    if not latest_results["__TOTAL__"] then
        player.print("[PT Profiler] Gathering initial 60-tick performance sample...")
        return
    end

    player.print({
        "",
        "[font=default-bold][PT Profiler (60t avg)][/font] Total Mod UPS Impact: [color=yellow]",
        latest_results["__TOTAL__"],
        "[/color]"
    })

    player.print({
        "",
        "  [color=cyan]• Core:[/color] Flow: ",
        latest_results["Flow Engine"] or "-",
        " | Capsules: ",
        latest_results["Capsule Motion"] or "-",
        " | Hubs: ",
        latest_results["Hub Logistics"] or "-"
    })

    player.print({
        "",
        "  [color=cyan]• Scanner:[/color] Total: ",
        latest_results["Device Scanner"] or "-",
        " [color=0.7,0.7,0.7](Counters: [/color]",
        latest_results["Scanner: Counters"] or "-",
        " [color=0.7,0.7,0.7]| Diverters: [/color]",
        latest_results["Scanner: Diverters"] or "-",
        " [color=0.7,0.7,0.7]| Pumps: [/color]",
        latest_results["Scanner: Pumps"] or "-",
        " [color=0.7,0.7,0.7]| Projectors: [/color]",
        latest_results["Scanner: Projectors"] or "-",
        " [color=0.7,0.7,0.7])[/color]"
    })

    local known = {
        ["__TOTAL__"] = true,
        ["Flow Engine"] = true,
        ["Capsule Motion"] = true,
        ["Capsules: Tube Traversal"] = true,
        ["Capsules: Ballistics"] = true,
        ["Capsules: Frame Sync"] = true,
        ["Hub Logistics"] = true,
        ["Device Scanner"] = true,
        ["Scanner: Counters"] = true,
        ["Scanner: Diverters"] = true,
        ["Scanner: Pumps"] = true,
        ["Scanner: Projectors"] = true,
        ["Scanner: Cache"] = true,
    }

    local extra_parts = { "", "  [color=cyan]• Other:[/color] " }
    local has_extra = false
    for name, prof in pairs(latest_results) do
        if not known[name] and #extra_parts < 16 then
            if has_extra then
                table.insert(extra_parts, " | ")
            end
            table.insert(extra_parts, name .. ": ")
            table.insert(extra_parts, prof)
            has_extra = true
        end
    end
    if has_extra then
        player.print(extra_parts)
    end

    local has_events = false
    for ev_name, ev_data in pairs(latest_event_results) do
        if ev_name ~= "on_tick" then
            has_events = true
            local ev_parts = {
                "",
                "  [color=orange]⚡ Event: [/color][font=default-bold]",
                ev_name,
                "[/font] (",
                tostring(ev_data.count),
                "x) Total: [color=yellow]",
                ev_data.total,
                "[/color] | Avg/call: [color=green]",
                ev_data.avg or "-",
                "[/color]"
            }
            player.print(ev_parts)

            for _, h in ipairs(ev_data.handlers) do
                player.print({
                    "",
                    "     [color=0.75,0.75,0.75]↳ ",
                    h.name,
                    " (",
                    tostring(h.count),
                    "x):[/color] ",
                    h.total,
                    " [color=0.6,0.6,0.6](avg ",
                    h.avg or "-",
                    ")[/color]"
                })
            end
        end
    end
end

function profiler.trigger_snapshot(player_index)
    if not profiler.ENABLED then
        local p = game.get_player(player_index)
        if p and p.valid then
            p.print("[PT Profiler] Profiler is disabled in this release build.")
        end
        return
    end

    if latest_results["__TOTAL__"] then
        local p = game.get_player(player_index)
        if p and p.valid then
            profiler.print_summary(p)
        end
    else
        snapshot_countdown = window_ticks
        snapshot_target_player = player_index
        local p = game.get_player(player_index)
        if p and p.valid then
            p.print("[PT Profiler] Profiler initiated: sampling live systems over 60 ticks...")
        end
    end
end

function profiler.finish_tick()
    current_tick_count = current_tick_count + 1

    if snapshot_countdown > 0 then
        snapshot_countdown = snapshot_countdown - 1
        if snapshot_countdown == 0 and snapshot_target_player then
            local p = game.get_player(snapshot_target_player)
            if p and p.valid then
                profiler.print_summary(p)
            end
            snapshot_target_player = nil
        end
    end

    if current_tick_count >= window_ticks then
        local create = get_create_profiler()

        local finished = {}
        for name, accum in pairs(accumulators) do
            if accum and accum.valid then
                safe_divide(accum, window_ticks)
                finished[name] = accum
            end
        end
        latest_results = finished
        accumulators = {}

        local finished_events = {}
        for ev_name, ev_accum in pairs(event_accumulators) do
            if ev_accum and ev_accum.valid then
                local count = event_counts[ev_name] or 1
                local avg_timer = create and create(true)
                if avg_timer then
                    safe_add(avg_timer, ev_accum)
                    safe_divide(avg_timer, count)
                end

                local handlers_list = {}
                local prefix = ev_name .. "::"
                for combo_key, h_accum in pairs(handler_accumulators) do
                    if combo_key:sub(1, #prefix) == prefix and h_accum and h_accum.valid then
                        local h_name = combo_key:sub(#prefix + 1)
                        local h_count = handler_counts[combo_key] or 1
                        local h_avg = create and create(true)
                        if h_avg then
                            safe_add(h_avg, h_accum)
                            safe_divide(h_avg, h_count)
                        end
                        handlers_list[#handlers_list + 1] = {
                            name = h_name,
                            count = h_count,
                            total = h_accum,
                            avg = h_avg
                        }
                    end
                end

                finished_events[ev_name] = {
                    total = ev_accum,
                    count = count,
                    avg = avg_timer,
                    handlers = handlers_list
                }
            end
        end
        latest_event_results = finished_events
        event_accumulators = {}
        event_counts = {}
        handler_accumulators = {}
        handler_counts = {}

        local finished_bvh = {}
        for b_name, b_accum in pairs(bvh_accumulators) do
            if b_accum and b_accum.valid then
                local count = bvh_counts[b_name] or 1
                local avg_t = create and create(true)
                if avg_t then
                    safe_add(avg_t, b_accum)
                    safe_divide(avg_t, count)
                end
                finished_bvh[b_name] = {
                    total = b_accum,
                    count = count,
                    avg = avg_t
                }
            end
        end
        latest_bvh_results = finished_bvh
        latest_bvh_results.__breach_count__ = bvh_breach_count
        bvh_accumulators = {}
        bvh_counts = {}
        bvh_breach_count = 0

        current_tick_count = 0

        if storage and storage.debug then
            for p_idx, dbg in pairs(storage.debug) do
                if dbg and dbg.master and dbg.profiler then
                    local p = game.get_player(p_idx)
                    if p and p.valid then
                        profiler.print_summary(p)
                    end
                end
            end
        end
    end
end

function profiler.get_latest_results()
    return latest_results
end

function profiler.get_latest_event_results()
    return latest_event_results
end

function profiler.get_latest_bvh_results()
    return latest_bvh_results
end

function profiler.print_bvh_summary(player)
    if not (player and player.valid) then return end

    player.print("[font=default-bold][PT BVH Performance Report (Latest 60t Window)][/font]")

    local surf = player.surface
    local s_idx = surf and surf.index or 1
    local vp_tree = storage.viewport_bvh and storage.viewport_bvh[s_idx]
    local mo_tree = storage.motion_bvh and storage.motion_bvh[s_idx]
    local su_tree = storage.surface_bvh and storage.surface_bvh[s_idx]
    local v_set = storage.player_visible_set and storage.player_visible_set[player.index]
    local vis_count = 0
    if v_set then for _ in pairs(v_set) do vis_count = vis_count + 1 end end

    local vp_nodes = vp_tree and (vp_tree.size or 0) or 0
    local vp_free = vp_tree and (vp_tree.free_count or 0) or 0
    local mo_nodes = mo_tree and (mo_tree.size or 0) or 0
    local mo_free = mo_tree and (mo_tree.free_count or 0) or 0
    local su_nodes = su_tree and (su_tree.size or 0) or 0
    local su_free = su_tree and (su_tree.free_count or 0) or 0

    player.print({
        "",
        "  [color=cyan]• Active Trees:[/color] Viewport: ", tostring(vp_nodes), " nodes (", tostring(vp_free), " pooled) | Motion: ",
        tostring(mo_nodes), " nodes (", tostring(mo_free), " pooled) | Surface: ",
        tostring(su_nodes), " nodes (", tostring(su_free), " pooled)"
    })
    player.print({
        "",
        "  [color=cyan]• Player Viewport:[/color] Corridors currently visible on-screen: [color=yellow]", tostring(vis_count), "[/color]"
    })

    local bvh_res = latest_bvh_results
    local has_any = false
    if bvh_res then
        for op_name, data in pairs(bvh_res) do
            if op_name ~= "__breach_count__" then
                has_any = true
                player.print({
                    "",
                    "  [color=orange]⚡ ", op_name, ":[/color] ",
                    tostring(data.count), " calls | Total: [color=yellow]", data.total, "[/color] | Avg/call: [color=green]", data.avg or "-", "[/color]"
                })
            end
        end
    end

    local breaches = bvh_res and bvh_res.__breach_count__ or 0
    player.print({
        "",
        "  [color=cyan]• Shell Breaches:[/color] ", tostring(breaches), " boundary crosses in sampling window."
    })

    if not has_any then
        player.print("  [color=0.7,0.7,0.7]No BVH operations recorded in the latest window (quiescent).[/color]")
    end
end

function profiler.get_system_stats()
    local stats = {
        flow_queue_depth = 0,
        flow_node_count = 0,
        active_capsules = 0,
        parked_capsules = 0,
        in_flight_capsules = 0,
        arrival_heap_size = 0,
        active_hubs = 0,
        active_pumps = 0,
        active_diverters = 0,
        active_counters = 0,
        active_projectors = 0,
    }

    local heap = storage.timed_arrival_heap or storage.kinetic_arrival_heap
    stats.arrival_heap_size = heap and heap.size or 0

    if not storage then return stats end

    if storage.flow_queue then
        for _ in pairs(storage.flow_queue) do
            stats.flow_queue_depth = stats.flow_queue_depth + 1
        end
    end

    if storage.flow_nodes then
        for _ in pairs(storage.flow_nodes) do
            stats.flow_node_count = stats.flow_node_count + 1
        end
    end

    if storage.active_capsules then
        for _ in pairs(storage.active_capsules) do
            stats.active_capsules = stats.active_capsules + 1
        end
    end

    if storage.capsules then
        for _, cap in pairs(storage.capsules) do
            if cap.in_timed_flight then
                stats.in_flight_capsules = stats.in_flight_capsules + 1
            end
        end
    end

    if storage.parked_by_port then
        for _, port_caps in pairs(storage.parked_by_port) do
            if type(port_caps) == "table" then
                for _ in pairs(port_caps) do
                    stats.parked_capsules = stats.parked_capsules + 1
                end
            end
        end
    end

    if storage.active_hubs then
        for _ in pairs(storage.active_hubs) do
            stats.active_hubs = stats.active_hubs + 1
        end
    end

    if storage.active_pumps then
        for _ in pairs(storage.active_pumps) do
            stats.active_pumps = stats.active_pumps + 1
        end
    end

    if storage.active_diverters then
        for _ in pairs(storage.active_diverters) do
            stats.active_diverters = stats.active_diverters + 1
        end
    end

    if storage.active_counters then
        for _ in pairs(storage.active_counters) do
            stats.active_counters = stats.active_counters + 1
        end
    end

    if storage.active_projectors then
        for _ in pairs(storage.active_projectors) do
            stats.active_projectors = stats.active_projectors + 1
        end
    end

    return stats
end

return profiler
