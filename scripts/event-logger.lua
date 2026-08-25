local events = require("scripts.events")

local exclusion = true
local event_filters = {
    "on_tick",
    "on_chunk_charted"
}

local function is_in_list(target_event)
    for _, event_name in ipairs(event_filters) do
        if event_name == target_event then
            return true
        end
    end
    return false
end

for event_name, event_id in pairs(defines.events) do
    events.on_event(event_id, function(event)
        local in_list = is_in_list(event_name)
        local should_process = false

        if exclusion then
            -- Blacklist mode: process if NOT in the list
            should_process = not in_list
        else
            -- Whitelist mode: process if IN the list
            should_process = in_list
        end

        if should_process then
            debug_print("Event fired: " .. event_name)
        end
    end)
end