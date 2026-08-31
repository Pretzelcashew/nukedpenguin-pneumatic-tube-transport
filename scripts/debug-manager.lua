local port_renderer = require("scripts.ports.port-renderer")
local networks_flow = require("scripts.networks.networks-flow")
local events = require("scripts.events")

local debug_manager = {}

local function get_debug(player_index)
    storage.debug = storage.debug or {}
    if not player_index then return nil end

    if not storage.debug[player_index] then
        storage.debug[player_index] = {
            master = true,
            ports = false,
            flow = true,
            capsules = true,
            peek = false,
            prints = false,
        }
    else
        if storage.debug[player_index].peek == nil then
            storage.debug[player_index].peek = false
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
    safe_set_shortcut_toggled(player, "pt-toggle-debug", master)
    safe_set_shortcut_toggled(player, "pt-toggle-flow", master and (dbg.flow == true))
    safe_set_shortcut_toggled(player, "pt-toggle-capsules", master and (dbg.capsules == true))
    safe_set_shortcut_toggled(player, "pt-toggle-capsule-peek", master and (dbg.peek == true))
    safe_set_shortcut_toggled(player, "pt-toggle-ports", master and (dbg.ports == true))
end

function debug_manager.sync_shortcuts(player_index)
    update_player_shortcuts(player_index)
end

function debug_print(msg, target_player)
    if target_player then
        local p_idx = type(target_player) == "table" and target_player.index or target_player
        if is_debug_active("prints", p_idx) then
            local p = game.get_player(p_idx)
            if p then p.print(msg) end
        end
    else
        for _, p in pairs(game.players) do
            if is_debug_active("prints", p.index) then
                p.print(msg)
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

local function toggle_master(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.master = not dbg.master

    if is_debug_active("ports", player_index) then port_renderer.draw_all(player_index) else port_renderer.clear_all(player_index) end
    if is_debug_active("flow", player_index) then networks_flow.draw_all(player_index) else networks_flow.clear_all(player_index) end

    update_player_shortcuts(player_index)
    player.print("[Debug] Master: " .. (dbg.master and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_prints(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.prints = not dbg.prints
    update_player_shortcuts(player_index)
    player.print("[Debug] Prints: " .. (dbg.prints and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_ports(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.ports = not dbg.ports

    if is_debug_active("ports", player_index) then port_renderer.draw_all(player_index) else port_renderer.clear_all(player_index) end
    update_player_shortcuts(player_index)
    player.print("[Debug] Ports: " .. (dbg.ports and "[ENABLED]" or "[DISABLED]"))
end

local function toggle_flow(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.flow = not dbg.flow

    if is_debug_active("flow", player_index) then networks_flow.draw_all(player_index) else networks_flow.clear_all(player_index) end
    update_player_shortcuts(player_index)
    player.print("[Debug] Flow Overlay: " .. (dbg.flow and "[ENABLED]" or "[DISABLED]"))
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
    player.print("[Debug] Capsule Peek: " .. (dbg.peek and "[ENABLED]" or "[DISABLED]"))
end

-- Primary Commands
commands.add_command("toggle-debug", "Toggle master debug state", function(cmd) if cmd.player_index then toggle_master(cmd.player_index) end end)
commands.add_command("toggle-prints", "Toggle game debug prints", function(cmd) if cmd.player_index then toggle_prints(cmd.player_index) end end)
commands.add_command("toggle-ports", "Toggle port overlay", function(cmd) if cmd.player_index then toggle_ports(cmd.player_index) end end)
commands.add_command("toggle-flow", "Toggle flow vector overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_flow(cmd.player_index) end end)
commands.add_command("toggle-capsules", "Toggle capsule overlay (Alt Mode)", function(cmd) if cmd.player_index then toggle_capsules(cmd.player_index) end end)
commands.add_command("toggle-capsule-peek", "Toggle capsule peeking overlay on hovered entity (Alt Mode)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)

-- Command Aliases for Consistency & Backward Compatibility
commands.add_command("capsule-peek", "Toggle capsule peeking overlay on hovered entity (Alias)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("pt-toggle-debug", "Toggle master debug state (Alias)", function(cmd) if cmd.player_index then toggle_master(cmd.player_index) end end)
commands.add_command("pt-toggle-flow", "Toggle flow vector overlay (Alias)", function(cmd) if cmd.player_index then toggle_flow(cmd.player_index) end end)
commands.add_command("pt-toggle-capsules", "Toggle capsule overlay (Alias)", function(cmd) if cmd.player_index then toggle_capsules(cmd.player_index) end end)
commands.add_command("pt-toggle-capsule-peek", "Toggle capsule peeking overlay (Alias)", function(cmd) if cmd.player_index then toggle_peek(cmd.player_index) end end)
commands.add_command("pt-toggle-ports", "Toggle port overlay (Alias)", function(cmd) if cmd.player_index then toggle_ports(cmd.player_index) end end)
commands.add_command("pt-toggle-prints", "Toggle game debug prints (Alias)", function(cmd) if cmd.player_index then toggle_prints(cmd.player_index) end end)

-- Listen for Shortcut Bar Clicks
events.on_event(defines.events.on_lua_shortcut, function(event)
    local p_name = event.prototype_name
    local p_idx = event.player_index
    if not (p_name and p_idx) then return end

    if p_name == "pt-toggle-debug" then
        toggle_master(p_idx)
    elseif p_name == "pt-toggle-flow" then
        toggle_flow(p_idx)
    elseif p_name == "pt-toggle-capsules" then
        toggle_capsules(p_idx)
    elseif p_name == "pt-toggle-capsule-peek" then
        toggle_peek(p_idx)
    elseif p_name == "pt-toggle-ports" then
        toggle_ports(p_idx)
    end
end)

-- Synchronize Shortcuts on Player Init/Join
events.on_event(defines.events.on_player_created, function(event)
    update_player_shortcuts(event.player_index)
end)

return debug_manager