local port_renderer = require("scripts.ports.port-renderer")
local networks_flow = require("scripts.networks.networks-flow")
local flow_engine = require("scripts.flow.flow-engine")
local events = require("scripts.events")

local FLOW_VERSION = settings.startup["pneumatic-flow-version"] and settings.startup["pneumatic-flow-version"].value or "v1"
local debug_manager = {}
local PANEL_NAME = "pneumatic_debug_panel"

local function get_debug(player_index)
    storage.debug = storage.debug or {}
    if not player_index then return nil end

    if not storage.debug[player_index] then
        storage.debug[player_index] = {
            master = true,
            ports = false,
            flow = true,
            new_flow = true,
            capsules = true,
            peek = false,
            prints = false,
            filter = nil,
        }
    else
        if storage.debug[player_index].peek == nil then
            storage.debug[player_index].peek = false
        end
        if storage.debug[player_index].new_flow == nil then
            storage.debug[player_index].new_flow = true
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
    safe_set_shortcut_toggled(player, "pt-toggle-flow", master and (FLOW_VERSION == "v1") and (dbg.flow == true))
    safe_set_shortcut_toggled(player, "pt-toggle-new-flow", master and (FLOW_VERSION == "v2") and (dbg.new_flow == true))
    safe_set_shortcut_toggled(player, "pt-toggle-capsules", master and (dbg.capsules == true))
    safe_set_shortcut_toggled(player, "pt-toggle-capsule-peek", master and (dbg.peek == true))
    safe_set_shortcut_toggled(player, "pt-toggle-ports", master and (FLOW_VERSION == "v1") and (dbg.ports == true))
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

    local chk_flow = content.pneumatic_debug_chk_flow
    if chk_flow then
        chk_flow.enabled = master and (FLOW_VERSION == "v1")
        chk_flow.state = master and (FLOW_VERSION == "v1") and (dbg.flow == true)
    end

    local chk_new_flow = content.pneumatic_debug_chk_new_flow
    if chk_new_flow then
        chk_new_flow.enabled = master and (FLOW_VERSION == "v2")
        chk_new_flow.state = master and (FLOW_VERSION == "v2") and (dbg.new_flow == true)
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

    local chk_ports = content.pneumatic_debug_chk_ports
    if chk_ports then
        chk_ports.enabled = master and (FLOW_VERSION == "v1")
        chk_ports.state = master and (FLOW_VERSION == "v1") and (dbg.ports == true)
    end

    local chk_prints = content.pneumatic_debug_chk_prints
    if chk_prints then
        chk_prints.enabled = master
        chk_prints.state = master and (dbg.prints == true)
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

    if FLOW_VERSION == "v1" then
        content_frame.add{
            type = "checkbox",
            name = "pneumatic_debug_chk_flow",
            caption = {"gui-debug.toggle-flow"},
            state = master and (dbg.flow == true),
            enabled = master
        }
    end

    if FLOW_VERSION == "v2" then
        content_frame.add{
            type = "checkbox",
            name = "pneumatic_debug_chk_new_flow",
            caption = "Flow Engine (Alt Mode)",
            state = master and (dbg.new_flow == true),
            enabled = master
        }
    end

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

    if FLOW_VERSION == "v1" then
        content_frame.add{
            type = "checkbox",
            name = "pneumatic_debug_chk_ports",
            caption = {"gui-debug.toggle-ports"},
            state = master and (dbg.ports == true),
            enabled = master
        }
    end

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

    if FLOW_VERSION == "v1" then
        if is_debug_active("ports", player_index) then port_renderer.draw_all(player_index) else port_renderer.clear_all(player_index) end
        if is_debug_active("flow", player_index) then networks_flow.draw_all(player_index) else networks_flow.clear_all(player_index) end
    end
    if FLOW_VERSION == "v2" then
        if is_debug_active("new_flow", player_index) then flow_engine.draw_all(player_index) else flow_engine.clear_all_renders(player_index) end
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

local function toggle_ports(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.ports = not dbg.ports

    if FLOW_VERSION == "v1" then
        if is_debug_active("ports", player_index) then port_renderer.draw_all(player_index) else port_renderer.clear_all(player_index) end
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Ports: " .. (dbg.ports and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_flow(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.flow = not dbg.flow

    if FLOW_VERSION == "v1" then
        if is_debug_active("flow", player_index) then networks_flow.draw_all(player_index) else networks_flow.clear_all(player_index) end
    end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Flow Overlay: " .. (dbg.flow and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_new_flow(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.new_flow = not dbg.new_flow

    if is_debug_active("new_flow", player_index) and (FLOW_VERSION == "v2") then flow_engine.draw_all(player_index) else flow_engine.clear_all_renders(player_index) end

    update_player_shortcuts(player_index)
    debug_manager.refresh_panel(player_index)
    player.print("[Debug] Flow Overlay: " .. (dbg.new_flow and "[ENABLED]" or "[DISABLED]"))
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

commands.add_command("pneumatic-panel", "Toggle the Pneumatic Debug & Control Panel", function(cmd) if cmd.player_index then debug_manager.toggle_panel(cmd.player_index) end end)
commands.add_command("debug-panel", "Toggle the Pneumatic Debug & Control Panel", function(cmd) if cmd.player_index then debug_manager.toggle_panel(cmd.player_index) end end)
commands.add_command("toggle-debug", "Toggle master debug state", function(cmd) if cmd.player_index then toggle_master(cmd.player_index) end end)
commands.add_command("toggle-prints", "Toggle game debug prints", function(cmd) if cmd.player_index then toggle_prints(cmd.player_index) end end)
commands.add_command("toggle-ports", "Toggle port overlay", function(cmd) if cmd.player_index then toggle_ports(cmd.player_index) end end)
commands.add_command("toggle-flow", "Toggle flow vector overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_flow(cmd.player_index) end end)
commands.add_command("toggle-new-flow", "Toggle flow vector overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_new_flow(cmd.player_index) end end)
commands.add_command("toggle-capsules", "Toggle capsule overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_capsules(cmd.player_index) end end)
commands.add_command("toggle-capsule-peek", "Toggle capsule peeking overlay on hovered entity (Alt Mode)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("debug-filter", "Set a prefix text filter on received debug prints", function(cmd) if cmd.player_index then set_debug_filter(cmd.player_index, cmd.parameter) end end)
commands.add_command("debug-filter-reset", "Reset the debug print prefix text filter", function(cmd) if cmd.player_index then reset_debug_filter(cmd.player_index, cmd.parameter) end end)

commands.add_command("capsule-peek", "Toggle capsule peeking overlay on hovered entity (Alias)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("pt-toggle-debug", "Toggle master debug state (Alias)", function(cmd) if cmd.player_index then toggle_master(cmd.player_index) end end)
commands.add_command("pt-toggle-flow", "Toggle flow vector overlay (Alias)", function(cmd) if cmd.player_index then toggle_flow(cmd.player_index) end end)
commands.add_command("pt-toggle-new-flow", "Toggle flow vector overlay (Alias)", function(cmd) if cmd.player_index then toggle_new_flow(cmd.player_index) end end)
commands.add_command("pt-toggle-capsules", "Toggle capsule overlay (Alias)", function(cmd) if cmd.player_index then toggle_capsules(cmd.player_index) end end)
commands.add_command("pt-toggle-capsule-peek", "Toggle capsule peeking overlay (Alias)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("pt-toggle-ports", "Toggle port overlay (Alias)", function(cmd) if cmd.player_index then toggle_ports(cmd.player_index) end end)
commands.add_command("pt-toggle-prints", "Toggle game debug prints (Alias)", function(cmd) if cmd.player_index then toggle_prints(cmd.player_index) end end)

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
        if FLOW_VERSION == "v1" then
            if is_debug_active("ports", p_idx) then port_renderer.draw_all(p_idx) else port_renderer.clear_all(p_idx) end
            if is_debug_active("flow", p_idx) then networks_flow.draw_all(p_idx) else networks_flow.clear_all(p_idx) end
        end
        if FLOW_VERSION == "v2" then
            if is_debug_active("new_flow", p_idx) then flow_engine.draw_all(p_idx) else flow_engine.clear_all_renders(p_idx) end
        end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_flow" then
        dbg.flow = element.state
        if FLOW_VERSION == "v1" then
            if is_debug_active("flow", p_idx) then networks_flow.draw_all(p_idx) else networks_flow.clear_all(p_idx) end
        end
        update_player_shortcuts(p_idx)
        debug_manager.refresh_panel(p_idx)
    elseif name == "pneumatic_debug_chk_new_flow" then
        dbg.new_flow = element.state
        if FLOW_VERSION == "v2" then
            if is_debug_active("new_flow", p_idx) then flow_engine.draw_all(p_idx) else flow_engine.clear_all_renders(p_idx) end
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
    elseif name == "pneumatic_debug_chk_ports" then
        dbg.ports = element.state
        if FLOW_VERSION == "v1" then
            if is_debug_active("ports", p_idx) then port_renderer.draw_all(p_idx) else port_renderer.clear_all(p_idx) end
        end
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

return debug_manager