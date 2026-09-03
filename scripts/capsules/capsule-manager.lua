local capsule_defs = require("scripts.capsules.capsule-definitions")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")

local capsule_manager = {}

function capsule_manager.init()
    storage.active_capsules = storage.active_capsules or {}
end

--- Registers a newly created holder entity into the tracking system
--- @param holder_entity LuaEntity The liminal holder entity
--- @param capsule_item_name string Name of the capsule prototype
--- @param primary_slot number|nil Index of the slot containing the primary capsule item in holder inventory
--- @param dominant_item string|nil Name of the dominant payload item
--- @param has_spoilable_items boolean|nil Whether any item in the capsule can spoil
--- @param is_wide boolean|nil Whether allocated in a wide 8-tile unit cell
function capsule_manager.register(holder_entity, capsule_item_name, primary_slot, dominant_item, has_spoilable_items, is_wide)
    if not (holder_entity and holder_entity.valid) then return nil end
    
    local def = capsule_defs.types[capsule_item_name]
    if not def then return nil end

    capsule_manager.init()
    local capsule_id = holder_entity.unit_number
    local pos = holder_entity.position

    if script.register_on_object_destroyed then
        local reg_id = script.register_on_object_destroyed(holder_entity)
        storage.object_destruction_map = storage.object_destruction_map or {}
        storage.object_destruction_map[reg_id] = { type = "capsule", id = capsule_id }
    end
    
    storage.active_capsules[capsule_id] = {
        holder = holder_entity,
        type = def.type,
        definition = def,
        primary_slot = primary_slot,
        position = { x = pos.x, y = pos.y },
        dominant_item = dominant_item or capsule_item_name,
        has_spoilable_items = has_spoilable_items == true,
        is_wide = is_wide == true
    }
    
    return capsule_id
end

--- Retrieves the capsule tracking data
--- @param capsule_id number
--- @return table|nil
function capsule_manager.get(capsule_id)
    if not storage.active_capsules then return nil end
    return storage.active_capsules[capsule_id]
end

--- Retrieves the primary capsule item stack from the holder inventory, if present and valid
--- @param capsule_id number
--- @return LuaItemStack|nil stack
--- @return number|nil slot_index
function capsule_manager.get_primary_stack(capsule_id)
    local data = capsule_manager.get(capsule_id)
    if not (data and data.holder and data.holder.valid and data.primary_slot) then
        return nil, nil
    end
    local inv = data.holder.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid and data.primary_slot <= #inv) then
        return nil, nil
    end
    local stack = inv[data.primary_slot]
    if stack and stack.valid_for_read then
        return stack, data.primary_slot
    end
    return nil, data.primary_slot
end

--- Safely destroys the holder entity, releases its grid position, and removes it from the registry
--- @param capsule_id number
function capsule_manager.remove(capsule_id)
    if not storage.active_capsules then return end
    
    local data = storage.active_capsules[capsule_id]
    if data then
        local pos = data.position or (data.holder and data.holder.valid and data.holder.position)
        if data.holder and data.holder.valid then
            data.holder.destroy()
        end
        if pos then
            liminal_surface_mgr.release_position(pos, data.is_wide)
        end
        storage.active_capsules[capsule_id] = nil
    end
end

return capsule_manager