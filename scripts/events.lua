local profiler = require("scripts.utils.profiler")

local events = {}
local handlers = {}

-- Register a function to run when a specific event fires
function events.on_event(event_id, handler, custom_name)
    local name = profiler.resolve_name(handler, custom_name)
    local entry = { func = handler, name = name }

    -- If this is the first handler for this event, tell Factorio to listen for it
    if not handlers[event_id] then
        handlers[event_id] = {}
        
        script.on_event(event_id, function(event)
            local is_tick = (event_id == defines.events.on_tick)
            local is_active = is_tick and profiler.is_active()

            if not is_active then
                for _, h in ipairs(handlers[event_id]) do
                    h.func(event)
                end
            else
                for _, h in ipairs(handlers[event_id]) do
                    local t = profiler.start_timer()
                    h.func(event)
                    profiler.stop_timer(h.name, t)
                end
                profiler.finish_tick()
            end
        end)
    end
    
    -- Add the handler entry to the list
    table.insert(handlers[event_id], entry)
end

return events