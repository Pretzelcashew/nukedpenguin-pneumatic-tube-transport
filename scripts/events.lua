local profiler = require("scripts.utils.profiler")

local events = {}
local handlers = {}

local event_names = {}
for name, id in pairs(defines.events) do
    event_names[id] = name
end

function events.get_event_name(event_id)
    if type(event_id) == "string" then
        return event_id
    end
    return event_names[event_id] or ("event_" .. tostring(event_id))
end

-- Register a function to run when a specific event fires
function events.on_event(event_id, handler, custom_name)
    local name = profiler.resolve_name(handler, custom_name)
    local entry = { func = handler, name = name }

    -- If this is the first handler for this event, tell Factorio to listen for it
    if not handlers[event_id] then
        handlers[event_id] = {}
        
        script.on_event(event_id, function(event)
            if not profiler.is_active() then
                for _, h in ipairs(handlers[event_id]) do
                    h.func(event)
                end
                return
            end

            local ev_name = events.get_event_name(event_id)
            local is_tick = (event_id == defines.events.on_tick)
            local log_active = profiler.is_event_log_active() and not is_tick
            for _, h in ipairs(handlers[event_id]) do
                local t = profiler.start_timer()
                h.func(event)
                profiler.record_event_handler(ev_name, h.name, t, log_active)
            end

            if is_tick then
                profiler.finish_tick()
            end
        end)
    end
    
    -- Add the handler entry to the list
    table.insert(handlers[event_id], entry)
end

return events