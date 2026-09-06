local events = require("scripts.events")
local debug_manager = require("scripts.debug-manager")

local copier_hotkey_debug = {}

local function get_state(player_index)
    storage.hotkey_debug = storage.hotkey_debug or {}
    if not storage.hotkey_debug[player_index] then
        storage.hotkey_debug[player_index] = {
            active = false,
            last_tick = 0
        }
    end
    return storage.hotkey_debug[player_index]
end

local function on_shift_input(event)
    local player_index = event.player_index
    local state = get_state(player_index)

    state.last_tick = event.tick

    if not state.active then
        state.active = true
        debug_print("[Hotkey Debug] SHIFT", player_index)
    end
end

local function on_tick(event)
    if not storage.hotkey_debug then return end

    for player_index, state in pairs(storage.hotkey_debug) do
        if state and state.active then
            if event.tick - state.last_tick > 15 then
                state.active = false
                debug_print("[Hotkey Debug] UNSHIFT", player_index)
            end
        end
    end
end

function copier_hotkey_debug.register_events()
    events.on_event("pneumatic-shift-key", on_shift_input)
    events.on_event(defines.events.on_tick, on_tick)
end

return copier_hotkey_debug