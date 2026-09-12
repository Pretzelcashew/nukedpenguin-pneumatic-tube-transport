local profiler = {}

-- Master release switch: set to false to completely disable and compile out the profiler for release builds
profiler.ENABLED = true

local window_ticks = 60
local current_tick_count = 0

local accumulators = {}
local latest_results = {}
local snapshot_countdown = 0
local snapshot_target_player = nil

local system_order = {
    "Flow Engine",
    "Capsule Motion",
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
        local finished = {}
        for name, accum in pairs(accumulators) do
            if accum and accum.valid then
                safe_divide(accum, window_ticks)
                finished[name] = accum
            end
        end

        latest_results = finished
        accumulators = {}
        current_tick_count = 0

    end
end

function profiler.get_latest_results()
    return latest_results
end

function profiler.get_system_stats()
    local stats = {
        flow_queue_depth = 0,
        flow_node_count = 0,
        active_capsules = 0,
        parked_capsules = 0,
        active_hubs = 0,
        active_pumps = 0,
        active_diverters = 0,
        active_counters = 0,
        active_projectors = 0,
    }

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
