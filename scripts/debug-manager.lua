local flow_engine = require("scripts.flow.flow-engine")
local events = require("scripts.events")
local profiler = require("scripts.utils.profiler")
local binary_heap = require("scripts.utils.binary-heap")
local capsule_lifecycle = require("scripts.capsules.capsule-lifecycle")

local debug_manager = {}
debug_manager.binary_heap = binary_heap
local PANEL_NAME = "pneumatic_debug_panel"

local function get_debug(player_index)
    storage.debug = storage.debug or {}
    if not player_index then return nil end

    if not storage.debug[player_index] then
        storage.debug[player_index] = {
            master = true,
            new_flow = true,
            counter_range = true,
            capsules = true,
            peek = false,
            prints = false,
            profiler = false,
            filter = nil,
        }
    else
        if storage.debug[player_index].peek == nil then
            storage.debug[player_index].peek = false
        end
        if storage.debug[player_index].new_flow == nil then
            storage.debug[player_index].new_flow = true
        end
        if storage.debug[player_index].counter_range == nil then
            storage.debug[player_index].counter_range = true
        end
        if storage.debug[player_index].profiler == nil or storage.debug[player_index].profiler == true then
            storage.debug[player_index].profiler = false
        end
    end
    return storage.debug[player_index]
end

local function safe_set_shortcut_toggled(player, name, state)
    if player and player.valid then
        pcall(function()
            player.set_shortcut_toggled(name, state)
        end)
    end
end

local function update_player_shortcuts(player_index)
    if not player_index then return end
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    if not dbg then return end

    local master = dbg.master == true
    safe_set_shortcut_toggled(player, "pt-debug-panel", master)
    safe_set_shortcut_toggled(player, "pt-toggle-debug", master)
    safe_set_shortcut_toggled(player, "pt-toggle-flow", master and (dbg.new_flow == true))
    safe_set_shortcut_toggled(player, "pt-toggle-new-flow", master and (dbg.new_flow == true))
    safe_set_shortcut_toggled(player, "pt-toggle-counter-range", master and (dbg.counter_range == true))
    safe_set_shortcut_toggled(player, "pt-toggle-capsules", master and (dbg.capsules == true))
    safe_set_shortcut_toggled(player, "pt-toggle-capsule-peek", master and (dbg.peek == true))
end

function debug_manager.sync_shortcuts(player_index)
    update_player_shortcuts(player_index)
end

local function passes_filter(dbg, msg)
    if not dbg or not dbg.filter or dbg.filter == "" then
        return true
    end
    if type(msg) ~= "string" then
        return false
    end
    return msg:sub(1, #dbg.filter) == dbg.filter
end

function debug_print(msg, target_player)
    if target_player then
        local p_idx = type(target_player) == "table" and target_player.index or target_player
        if is_debug_active("prints", p_idx) then
            local dbg = get_debug(p_idx)
            if passes_filter(dbg, msg) then
                local p = game.get_player(p_idx)
                if p then p.print(msg) end
            end
        end
    else
        for _, p in pairs(game.players) do
            if is_debug_active("prints", p.index) then
                local dbg = get_debug(p.index)
                if passes_filter(dbg, msg) then
                    p.print(msg)
                end
            end
        end
    end
end

function is_debug_active(feature, target_player)
    if target_player then
        local p_idx = type(target_player) == "table" and target_player.index or target_player
        local dbg = get_debug(p_idx)
        return dbg and dbg.master and (dbg[feature] == true)
    end

    for _, p in pairs(game.players) do
        local dbg = get_debug(p.index)
        if dbg and dbg.master and (dbg[feature] == true) then
            return true
        end
    end
    return false
end

function debug_manager.close_panel(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local frame = player.gui.screen[PANEL_NAME]
    if frame then
        frame.destroy()
    end
end

function debug_manager.refresh_panel(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local frame = player.gui.screen[PANEL_NAME]
    if not frame then return end

    local dbg = get_debug(player_index)
    local master = dbg.master == true

    local content = frame.content_frame
    if not content then return end

    local master_flow = content.master_flow
    if master_flow and master_flow.pneumatic_debug_chk_master then
        master_flow.pneumatic_debug_chk_master.state = master
    end

    local chk_new_flow = content.pneumatic_debug_chk_new_flow
    if chk_new_flow then
        chk_new_flow.enabled = master
        chk_new_flow.state = master and (dbg.new_flow == true)
    end

    local chk_counter_range = content.pneumatic_debug_chk_counter_range
    if chk_counter_range then
        chk_counter_range.enabled = master
        chk_counter_range.state = master and (dbg.counter_range == true)
    end

    local chk_capsules = content.pneumatic_debug_chk_capsules
    if chk_capsules then
        chk_capsules.enabled = master
        chk_capsules.state = master and (dbg.capsules == true)
    end

    local chk_peek = content.pneumatic_debug_chk_peek
    if chk_peek then
        chk_peek.enabled = master
        chk_peek.state = master and (dbg.peek == true)
    end

    local chk_prints = content.pneumatic_debug_chk_prints
    if chk_prints then
        chk_prints.enabled = master
        chk_prints.state = master and (dbg.prints == true)
    end

    if not profiler.ENABLED then return end
    local tbl_frame = content.profiler_table_frame
    local prof_table = tbl_frame and tbl_frame.pneumatic_debug_profiler_table
    if prof_table and prof_table.valid then
        local stats = profiler.get_system_stats()
        local results = profiler.get_latest_results()

        local function set_cell(name, val)
            local el = prof_table[name]
            if el and el.valid then
                pcall(function() el.caption = val end)
            end
        end

        set_cell("lbl_time_flow", results["Flow Engine"] or "-")
        set_cell("lbl_ctx_flow", "Queue: " .. stats.flow_queue_depth .. " | Nodes: " .. stats.flow_node_count)

        set_cell("lbl_time_capsules", results["Capsule Motion"] or "-")
        set_cell("lbl_ctx_capsules", "Active: " .. stats.active_capsules .. " (Parked: " .. stats.parked_capsules .. ")")

        set_cell("lbl_time_hubs", results["Hub Logistics"] or "-")
        set_cell("lbl_ctx_hubs", "Active Hubs: " .. stats.active_hubs)

        set_cell("lbl_time_scanner", results["Device Scanner"] or "-")
        set_cell("lbl_time_counters", results["Scanner: Counters"] or "-")
        set_cell("lbl_ctx_counters", stats.active_counters .. " Counters")
        set_cell("lbl_time_diverters", results["Scanner: Diverters"] or "-")
        set_cell("lbl_ctx_diverters", stats.active_diverters .. " Diverters")
        set_cell("lbl_time_pumps", results["Scanner: Pumps"] or "-")
        set_cell("lbl_ctx_pumps", stats.active_pumps .. " Pumps")
        set_cell("lbl_time_projectors", results["Scanner: Projectors"] or "-")
        set_cell("lbl_ctx_projectors", stats.active_projectors .. " Projectors")
        set_cell("lbl_time_cache", results["Scanner: Cache"] or "-")

        if results["__TOTAL__"] then
            set_cell("lbl_time_total", {"", "[font=default-bold]", results["__TOTAL__"], "[/font]"})
        else
            set_cell("lbl_time_total", "[font=default-bold]Sampling...[/font]")
        end
    end
end

function debug_manager.open_panel(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    debug_manager.close_panel(player_index)

    local dbg = get_debug(player_index)
    local master = dbg.master == true

    local frame = player.gui.screen.add{
        type = "frame",
        name = PANEL_NAME,
        direction = "vertical"
    }
    frame.auto_center = true
    player.opened = frame

    local title_flow = frame.add{type = "flow", name = "title_flow", direction = "horizontal"}
    title_flow.style.vertical_align = "center"

    title_flow.add{
        type = "label",
        caption = {"gui-debug.panel-title"},
        style = "frame_title"
    }

    local drag_handle = title_flow.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    drag_handle.style.height = 24
    drag_handle.style.horizontally_stretchable = true
    drag_handle.drag_target = frame

    title_flow.add{
        type = "sprite-button",
        name = "pneumatic_debug_close",
        sprite = "utility/close",
        style = "frame_action_button"
    }

    local content_frame = frame.add{
        type = "frame",
        name = "content_frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    }
    content_frame.style.padding = 12

    local master_flow = content_frame.add{type = "flow", name = "master_flow", direction = "horizontal"}
    master_flow.style.vertical_align = "center"
    master_flow.style.bottom_margin = 8

    master_flow.add{
        type = "checkbox",
        name = "pneumatic_debug_chk_master",
        caption = {"gui-debug.master-enable"},
        state = master
    }

    content_frame.add{type = "line", direction = "horizontal"}

    local overlay_label = content_frame.add{
        type = "label",
        caption = {"gui-debug.overlays-header"},
        style = "caption_label"
    }
    overlay_label.style.top_margin = 4
    overlay_label.style.bottom_margin = 4

    content_frame.add{
        type = "checkbox",
        name = "pneumatic_debug_chk_new_flow",
        caption = "Flow & Kinetic Beams (Alt Mode)",
        state = master and (dbg.new_flow == true),
        enabled = master
    }

    content_frame.add{
        type = "checkbox",
        name = "pneumatic_debug_chk_counter_range",
        caption = "Counter Range Overlay (Alt Mode)",
        state = master and (dbg.counter_range == true),
        enabled = master
    }

    content_frame.add{
        type = "checkbox",
        name = "pneumatic_debug_chk_capsules",
        caption = {"gui-debug.toggle-capsules"},
        state = master and (dbg.capsules == true),
        enabled = master
    }

    content_frame.add{
        type = "checkbox",
        name = "pneumatic_debug_chk_peek",
        caption = {"gui-debug.toggle-peek"},
        state = master and (dbg.peek == true),
        enabled = master
    }

    content_frame.add{type = "line", direction = "horizontal"}

    local logging_label = content_frame.add{
        type = "label",
        caption = {"gui-debug.logging-header"},
        style = "caption_label"
    }
    logging_label.style.top_margin = 4
    logging_label.style.bottom_margin = 4

    content_frame.add{
        type = "checkbox",
        name = "pneumatic_debug_chk_prints",
        caption = {"gui-debug.toggle-prints"},
        state = master and (dbg.prints == true),
        enabled = master
    }

    if profiler.ENABLED then
        content_frame.add{type = "line", direction = "horizontal"}

        local profiler_label = content_frame.add{
            type = "label",
            caption = "Live Subsystem Performance (60t avg)",
            style = "caption_label"
        }
        profiler_label.style.top_margin = 4
        profiler_label.style.bottom_margin = 4

    local btn_flow = content_frame.add{
        type = "flow",
        name = "profiler_btn_flow",
        direction = "horizontal"
    }
    btn_flow.style.vertical_align = "center"
    btn_flow.style.top_margin = 2
    btn_flow.style.bottom_margin = 4

    btn_flow.add{
        type = "button",
        name = "pneumatic_debug_btn_profile_now",
        caption = "Snapshot to Console",
        style = "button"
    }

    btn_flow.add{
        type = "button",
        name = "pneumatic_debug_btn_profile_refresh",
        caption = "Refresh",
        style = "button"
    }

    local tbl_frame = content_frame.add{
        type = "frame",
        name = "profiler_table_frame",
        style = "deep_frame_in_shallow_frame",
        direction = "vertical"
    }
    tbl_frame.style.padding = 6
    tbl_frame.style.top_margin = 4
    tbl_frame.style.horizontally_stretchable = true

    local prof_table = tbl_frame.add{
        type = "table",
        name = "pneumatic_debug_profiler_table",
        column_count = 3,
        draw_horizontal_lines = true
    }
    prof_table.style.horizontally_stretchable = true
    prof_table.style.horizontal_spacing = 16

    local stats = profiler.get_system_stats()
    local results = profiler.get_latest_results()

    prof_table.add{type = "label", caption = "[font=default-bold]Subsystem / Task[/font]"}
    prof_table.add{type = "label", caption = "[font=default-bold]Execution Time[/font]"}
    prof_table.add{type = "label", caption = "[font=default-bold]Workload Detail[/font]"}

    prof_table.add{type = "label", caption = "Flow Engine"}
    prof_table.add{type = "label", name = "lbl_time_flow", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_flow", caption = "Queue: " .. stats.flow_queue_depth .. " | Nodes: " .. stats.flow_node_count}

    prof_table.add{type = "label", caption = "Capsule Motion"}
    prof_table.add{type = "label", name = "lbl_time_capsules", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_capsules", caption = "Active: " .. stats.active_capsules .. " (Parked: " .. stats.parked_capsules .. ")"}

    prof_table.add{type = "label", caption = "Hub Logistics"}
    prof_table.add{type = "label", name = "lbl_time_hubs", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_hubs", caption = "Active Hubs: " .. stats.active_hubs}

    prof_table.add{type = "label", caption = "[font=default-semibold]Device Scanner[/font]"}
    prof_table.add{type = "label", name = "lbl_time_scanner", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_scanner", caption = "15t Polling Cycle"}

    prof_table.add{type = "label", caption = "  [color=0.75,0.75,0.75]↳ Counters[/color]"}
    prof_table.add{type = "label", name = "lbl_time_counters", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_counters", caption = stats.active_counters .. " Counters"}

    prof_table.add{type = "label", caption = "  [color=0.75,0.75,0.75]↳ Diverters[/color]"}
    prof_table.add{type = "label", name = "lbl_time_diverters", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_diverters", caption = stats.active_diverters .. " Diverters"}

    prof_table.add{type = "label", caption = "  [color=0.75,0.75,0.75]↳ Pumps[/color]"}
    prof_table.add{type = "label", name = "lbl_time_pumps", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_pumps", caption = stats.active_pumps .. " Pumps"}

    prof_table.add{type = "label", caption = "  [color=0.75,0.75,0.75]↳ Projectors[/color]"}
    prof_table.add{type = "label", name = "lbl_time_projectors", caption = "-"}
    prof_table.add{type = "label", name = "lbl_ctx_projectors", caption = stats.active_projectors .. " Projectors"}

    prof_table.add{type = "label", caption = "  [color=0.75,0.75,0.75]↳ Cache Prune[/color]"}
    prof_table.add{type = "label", name = "lbl_time_cache", caption = "-"}
    prof_table.add{type = "label", caption = "Fast-replace prune"}

    prof_table.add{type = "label", caption = "[font=default-bold]TOTAL Mod Script Time[/font]"}
    prof_table.add{type = "label", name = "lbl_time_total", caption = "[font=default-bold]Sampling...[/font]"}
    prof_table.add{type = "label", caption = "[font=default-bold]Combined Mod UPS Impact[/font]"}

        debug_manager.refresh_panel(player_index)
    end
end

function debug_manager.toggle_panel(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local existing = player.gui.screen[PANEL_NAME]
    if existing then
        debug_manager.close_panel(player_index)
    else
        debug_manager.open_panel(player_index)
    end
end

local function toggle_master(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.master = not dbg.master

    if is_debug_active("new_flow", player_index) then
        flow_engine.draw_flow(player_index)
    else
        flow_engine.clear_flow_renders(player_index)
    end

    if is_debug_active("counter_range", player_index) then
        flow_engine.draw_all_counters(player_index)
    else
        flow_engine.clear_counter_renders(player_index)
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Master: " .. (dbg.master and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_prints(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.prints = not dbg.prints

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Prints: " .. (dbg.prints and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_profiler(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.profiler = not dbg.profiler

    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Live Profiler Console Stream: " .. (dbg.profiler and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_new_flow(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.new_flow = not dbg.new_flow

    if is_debug_active("new_flow", player_index) then
        flow_engine.draw_flow(player_index)
    else
        flow_engine.clear_flow_renders(player_index)
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Flow & Kinetic Beams: " .. (dbg.new_flow and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_counter_range(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.counter_range = not dbg.counter_range

    if is_debug_active("counter_range", player_index) then
        flow_engine.draw_all_counters(player_index)
    else
        flow_engine.clear_counter_renders(player_index)
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Counter Range Overlay: " .. (dbg.counter_range and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_capsules(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.capsules = not dbg.capsules
    if dbg.capsules then
        dbg.peek = false
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Capsules: " .. (dbg.capsules and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_peek(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.peek = not dbg.peek
    if dbg.peek then
        dbg.capsules = false
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Capsule Peek: " .. (dbg.peek and "[ENABLED]" or "[DISABLED]"))
end

local function set_debug_filter(player_index, filter_text)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    if not filter_text or filter_text == "" then
        player.print("[Debug] Usage: /debug-filter <filter text>")
        return
    end

    local cleaned = filter_text:match('^"(.*)"$') or filter_text:match("^'(.*)'$") or filter_text

    local dbg = get_debug(player_index)
    dbg.filter = cleaned
    player.print("[Debug] Filter set to: \"" .. cleaned .. "\"")
end

local function reset_debug_filter(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.filter = nil
    player.print("[Debug] Filter reset.")
end

local function clear_and_reconstruct_renders(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    flow_engine.clear_all_renders(player_index)

    if is_debug_active("new_flow", player_index) then
        flow_engine.draw_flow(player_index)
    end
    if is_debug_active("counter_range", player_index) then
        flow_engine.draw_all_counters(player_index)
    end

    player.print("[Debug] Overlays cleared and reconstructed.")
end

commands.add_command("pneumatic-panel", "Toggle the Pneumatic Debug & Control Panel", function(cmd) if cmd.player_index then debug_manager.toggle_panel(cmd.player_index) end end)
commands.add_command("debug-panel", "Toggle the Pneumatic Debug & Control Panel", function(cmd) if cmd.player_index then debug_manager.toggle_panel(cmd.player_index) end end)
commands.add_command("toggle-debug", "Toggle master debug state", function(cmd) if cmd.player_index then toggle_master(cmd.player_index) end end)
commands.add_command("toggle-prints", "Toggle game debug prints", function(cmd) if cmd.player_index then toggle_prints(cmd.player_index) end end)
commands.add_command("toggle-flow", "Toggle flow vector and kinetic beam overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_new_flow(cmd.player_index) end end)
commands.add_command("toggle-new-flow", "Toggle flow vector and kinetic beam overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_new_flow(cmd.player_index) end end)
commands.add_command("toggle-counter-range", "Toggle counter range overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_counter_range(cmd.player_index) end end)
commands.add_command("toggle-capsules", "Toggle capsule overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_capsules(cmd.player_index) end end)
commands.add_command("toggle-capsule-peek", "Toggle capsule peeking overlay on hovered entity (Alt Mode)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("toggle-profiler", "Toggle streaming 60-tick live performance profiler to chat", function(cmd) if cmd.player_index then toggle_profiler(cmd.player_index) end end)
commands.add_command("profile-snapshot", "Print a live performance snapshot of all subsystems to chat", function(cmd) if cmd.player_index then profiler.trigger_snapshot(cmd.player_index) end end)
commands.add_command("clear-renders", "Wipe and reconstruct all active Alt-Mode rendering overlays (Sandbox cleanup)", function(cmd) if cmd.player_index then clear_and_reconstruct_renders(cmd.player_index) end end)
commands.add_command("debug-filter", "Set a prefix text filter on received debug prints", function(cmd) if cmd.player_index then set_debug_filter(cmd.player_index, cmd.parameter) end end)
commands.add_command("debug-filter-reset", "Reset the debug print prefix text filter", function(cmd) if cmd.player_index then reset_debug_filter(cmd.player_index, cmd.parameter) end end)

commands.add_command("capsule-peek", "Toggle capsule peeking overlay on hovered entity (Alias)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("pt-toggle-debug", "Toggle master debug state (Alias)", function(cmd) if cmd.player_index then toggle_master(cmd.player_index) end end)
commands.add_command("pt-toggle-flow", "Toggle flow vector and kinetic beam overlay (Alias)", function(cmd) if cmd.player_index then toggle_new_flow(cmd.player_index) end end)
commands.add_command("pt-toggle-new-flow", "Toggle flow vector and kinetic beam overlay (Alias)", function(cmd) if cmd.player_index then toggle_new_flow(cmd.player_index) end end)
commands.add_command("pt-toggle-counter-range", "Toggle counter range overlay (Alias)", function(cmd) if cmd.player_index then toggle_counter_range(cmd.player_index) end end)
commands.add_command("pt-toggle-capsules", "Toggle capsule overlay (Alias)", function(cmd) if cmd.player_index then toggle_capsules(cmd.player_index) end end)
commands.add_command("pt-toggle-capsule-peek", "Toggle capsule peeking overlay (Alias)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("pt-toggle-prints", "Toggle game debug prints (Alias)", function(cmd) if cmd.player_index then toggle_prints(cmd.player_index) end end)
commands.add_command("pt-toggle-profiler", "Toggle streaming 60-tick live performance profiler to chat (Alias)", function(cmd) if cmd.player_index then toggle_profiler(cmd.player_index) end end)
commands.add_command("pt-profile", "Print a live performance snapshot of all subsystems to chat (Alias)", function(cmd) if cmd.player_index then profiler.trigger_snapshot(cmd.player_index) end end)
commands.add_command("pt-clear-renders", "Wipe and reconstruct all active Alt-Mode rendering overlays (Alias)", function(cmd) if cmd.player_index then clear_and_reconstruct_renders(cmd.player_index) end end)
commands.add_command("pt-test-heap", "Run self-tests on the reusable binary heap priority queue", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    binary_heap.run_tests(player)
end)
commands.add_command("test-heap", "Run self-tests on the reusable binary heap priority queue (Alias)", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    binary_heap.run_tests(player)
end)

local function print_spoil_heap_status(player_index)
    local stats = capsule_lifecycle.get_heap_stats()
    local p = player_index and game.get_player(player_index)
    local line
    if stats.count == 0 then
        line = "[Spoil Heap] Active timers: 0 | Reusable buffer capacity: " .. stats.capacity .. " (Empty)"
    else
        local rem_str = stats.ticks_remaining and (stats.ticks_remaining .. " ticks (" .. string.format("%.1fs", stats.ticks_remaining / 60) .. ")") or "now"
        line = "[Spoil Heap] Active timers: " .. stats.count .. " | Buffer capacity: " .. stats.capacity .. " | Next: Capsule #" .. tostring(stats.next_id) .. " at tick " .. tostring(stats.next_tick) .. " (in " .. rem_str .. ")"
    end
    if p and p.valid then
        p.print(line)
    else
        log(line)
    end
end

commands.add_command("check-spoil-heap", "Check status of the binary heap spoil timer scheduler", function(cmd)
    print_spoil_heap_status(cmd.player_index)
end)
commands.add_command("pt-check-spoil-heap", "Check status of the binary heap spoil timer scheduler (Alias)", function(cmd)
    print_spoil_heap_status(cmd.player_index)
end)

events.on_event(defines.events.on_lua_shortcut, function(event)
    local p_name = event.prototype_name
    local p_idx = event.player_index
    if not (p_name and p_idx) then return end

    if p_name == "pt-debug-panel" or p_name:sub(1, 10) == "pt-toggle-" then
        debug_manager.toggle_panel(p_idx)
    end
end)

events.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not (element and element.valid) then return end

    if element.name == "pneumatic_debug_close" then
        debug_manager.close_panel(event.player_index)
    elseif element.name == "pneumatic_debug_btn_profile_now" then
        profiler.trigger_snapshot(event.player_index)
    elseif element.name == "pneumatic_debug_btn_profile_refresh" then
        debug_manager.refresh_panel(event.player_index)
    end
end)

events.on_event(defines.events.on_gui_closed, function(event)
    local element = event.element
    if element and element.valid and element.name == PANEL_NAME then
        debug_manager.close_panel(event.player_index)
    end
end)

events.on_event(defines.events.on_gui_checked_state_changed, function(event)
    local element = event.element
    if not (element and element.valid) then return end
    local p_idx = event.player_index
    local dbg = get_debug(p_idx)
    if not dbg then return end

    local name = element.name
    if name == "pneumatic_debug_chk_master" then
        dbg.master = element.state
        if is_debug_active("new_flow", p_idx) then
            flow_engine.draw_flow(p_idx)
        else
            flow_engine.clear_flow_renders(p_idx)
        end
        if is_debug_active("counter_range", p_idx) then
            flow_engine.draw_all_counters(p_idx)
        else
            flow_engine.clear_counter_renders(p_idx)
        end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_new_flow" then
        dbg.new_flow = element.state
        if is_debug_active("new_flow", p_idx) then
            flow_engine.draw_flow(p_idx)
        else
            flow_engine.clear_flow_renders(p_idx)
        end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_counter_range" then
        dbg.counter_range = element.state
        if is_debug_active("counter_range", p_idx) then
            flow_engine.draw_all_counters(p_idx)
        else
            flow_engine.clear_counter_renders(p_idx)
        end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_capsules" then
        dbg.capsules = element.state
        if dbg.capsules then dbg.peek = false end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_peek" then
        dbg.peek = element.state
        if dbg.peek then dbg.capsules = false end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_prints" then
        dbg.prints = element.state
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    end
end)

events.on_event(defines.events.on_player_created, function(event)
    update_player_shortcuts(event.player_index)
end)

events.on_event(defines.events.on_tick, function(event)
    if not profiler.ENABLED then return end
    if event.tick % 60 ~= 0 then return end
    for _, player in pairs(game.players) do
        if player and player.valid and player.gui.screen[PANEL_NAME] then
            debug_manager.refresh_panel(player.index)
        end
    end
end, "Debug Manager")

return debug_manager
