local events = {}
local handlers = {}

-- Register a function to run when a specific event fires
function events.on_event(event_id, handler)
    -- If this is the first handler for this event, tell Factorio to listen for it
    if not handlers[event_id] then
        handlers[event_id] = {}
        
        script.on_event(event_id, function(event)
            for _, func in ipairs(handlers[event_id]) do
                func(event)
            end
        end)
    end
    
    -- Add the handler to the list
    table.insert(handlers[event_id], handler)
end

return events