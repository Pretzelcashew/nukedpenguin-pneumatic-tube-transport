-- scripts/hubs/hub-unpacking.lua
local hub_unpacking = {}

--- Attempts to transfer items from the physical capsule to the hub.
--- Returns true if fully unpacked and destroyed, false if parked/waiting.
function hub_unpacking.capture(capsule_tracker, hub_entity)
    local phys_capsule = storage.active_capsules and storage.active_capsules[capsule_tracker.id]
    
    if not phys_capsule or not phys_capsule.holder or not phys_capsule.holder.valid then
        return true 
    end

    local holder_inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    local hub_inv = hub_entity.get_inventory(defines.inventory.chest)

    if not holder_inv or not hub_inv then return false end

    local all_transferred = true

    for i = 1, #holder_inv do
        local stack = holder_inv[i]
        if stack and stack.valid_for_read then
            local inserted = hub_inv.insert(stack)
            if inserted > 0 then
                stack.count = stack.count - inserted
            end
            
            if stack.valid_for_read and stack.count > 0 then
                all_transferred = false
            end
        end
    end

    if all_transferred then
        phys_capsule.holder.destroy()
        storage.active_capsules[capsule_tracker.id] = nil
        
        -- APPLY THE MECHANICAL LATCH
        storage.hub_receive_locks = storage.hub_receive_locks or {}
        storage.hub_receive_locks[hub_entity.unit_number] = true
        
        return true
    end

    return false
end

return hub_unpacking