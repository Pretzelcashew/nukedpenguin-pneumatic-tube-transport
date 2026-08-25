-- scripts/debug-manager.lua
local port_renderer = require("scripts.ports.port-renderer")
local networks_flow = require("scripts.networks.networks-flow")

local debug_manager = {}

local function get_debug()
    storage.debug = storage.debug or {
        master = true,  -- Master power switch (starts OFF)
        ports = false,    -- Sub-features ready to activate when master turns ON
        flow = false,
        capsules = true,
        prints = false,
    }
    return storage.debug
end

function debug_print(msg)
    local dbg = get_debug()
    if dbg.master and dbg.prints then
        game.print(msg)
    end
end

function is_debug_active(feature)
    local dbg = get_debug()
    return dbg.master and (dbg[feature] == true)
end

commands.add_command("toggle-debug", "Toggle master debug state", function()
    local dbg = get_debug()
    dbg.master = not dbg.master

    if is_debug_active("ports") then port_renderer.draw_all() else port_renderer.clear_all() end
    if is_debug_active("flow") then networks_flow.draw_all() else networks_flow.clear_all() end

    game.print("[Debug] Master: " .. (dbg.master and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-prints", "Toggle game debug prints", function()
    local dbg = get_debug()
    dbg.prints = not dbg.prints
    game.print("[Debug] Prints: " .. (dbg.prints and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-ports", "Toggle port overlay", function()
    local dbg = get_debug()
    dbg.ports = not dbg.ports

    if is_debug_active("ports") then port_renderer.draw_all() else port_renderer.clear_all() end
    game.print("[Debug] Ports: " .. (dbg.ports and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-flow", "Toggle flow vector overlay", function()
    local dbg = get_debug()
    dbg.flow = not dbg.flow

    if is_debug_active("flow") then networks_flow.draw_all() else networks_flow.clear_all() end
    game.print("[Debug] Flow: " .. (dbg.flow and "[ENABLED]" or "[DISABLED]"))
end)

commands.add_command("toggle-capsules", "Toggle capsule overlay", function()
    local dbg = get_debug()
    dbg.capsules = not dbg.capsules
    game.print("[Debug] Capsules: " .. (dbg.capsules and "[ENABLED]" or "[DISABLED]"))
end)

return debug_manager