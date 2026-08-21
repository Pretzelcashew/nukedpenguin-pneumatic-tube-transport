local capsule_defs = require("scripts.capsules.capsule-definitions")

local capsule_manager = {}

function capsule_manager.init()
    storage.active_capsules = storage.active_capsules or {}
end

--- Registers a newly created holder entity into the tracking system
function capsule_manager.register(holder_entity, capsule_item_name)
    if not (holder_entity and holder_entity.valid) then return nil end
    
    -- Lookup capsule configuration rules
    local def = capsule_defs.types[capsule_item_name]
    if not def then return nil end

    capsule_manager.init()
    local capsule_id = holder_entity.unit_number
    
    storage.active_capsules[capsule_id] = {
        holder = holder_entity,
        type = def.type,
        definition = def
    }
    
    return capsule_id
end

--- Retrieves the capsule tracking data
function capsule_manager.get(capsule_id)
    if not storage.active_capsules then return nil end
    return storage.active_capsules[capsule_id]
end

--- Safely destroys the holder entity and removes it from the registry
function capsule_manager.remove(capsule_id)
    if not storage.active_capsules then return end
    
    local data = storage.active_capsules[capsule_id]
    if data then
        if data.holder and data.holder.valid then
            data.holder.destroy()
        end
        storage.active_capsules[capsule_id] = nil
    end
end

return capsule_manager