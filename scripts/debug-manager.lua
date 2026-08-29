local port_renderer = require("scripts.ports.port-renderer")
local networks_flow = require("scripts.networks.networks-flow")

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
            prints = false,
        }
    end
    return storage.debug[player_index]
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

commands.add_command("toggle-debug", "Toggle master debug state", function(command)
    local player_index = command.player_index
    if not player_index then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.master = not dbg.master

    if is_debug_active("ports", player_index) then port_renderer.draw_all(player_index) else port_renderer.clear_all(player_index) end
    if is_debug_active("flow", player_index) then networks_flow.draw_all(player_index) else networks_flow.clear_all(player_index) end

    player.print("[Debug] Master: " .. (dbg.master and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-prints", "Toggle game debug prints", function(command)
    local player_index = command.player_index
    if not player_index then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.prints = not dbg.prints
    player.print("[Debug] Prints: " .. (dbg.prints and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-ports", "Toggle port overlay", function(command)
    local player_index = command.player_index
    if not player_index then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.ports = not dbg.ports

    if is_debug_active("ports", player_index) then port_renderer.draw_all(player_index) else port_renderer.clear_all(player_index) end
    player.print("[Debug] Ports: " .. (dbg.ports and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-flow", "Toggle flow vector overlay (Alt Mode)", function(command)
    local player_index = command.player_index
    if not player_index then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.flow = not dbg.flow

    if is_debug_active("flow", player_index) then networks_flow.draw_all(player_index) else networks_flow.clear_all(player_index) end
    player.print("[Debug] Flow Overlay: " .. (dbg.flow and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-capsules", "Toggle capsule overlay", function(command)
    local player_index = command.player_index
    if not player_index then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local dbg = get_debug(player_index)
    dbg.capsules = not dbg.capsules
    player.print("[Debug] Capsules: " .. (dbg.capsules and "[ENABLED]" or "[DISABLED]"))
end)

return debug_manager