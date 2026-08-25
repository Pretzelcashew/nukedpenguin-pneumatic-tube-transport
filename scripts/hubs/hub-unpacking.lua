-- scripts/hubs/hub-unpacking.lua
local hub_unpacking = {}

--- Virtual Cargo Check: Verifies hub can fit every item currently in the liminal holder.
local function can_insert_all(holder_inv, hub_inv)
    local required_items = {}

    -- 1. Aggregate all stacks (cargo + item-capsule vessel) inside the liminal holder
    for i = 1, #holder_inv do
        local stack = holder_inv[i]
        if stack and stack.valid_for_read then
            local q_name = (stack.quality and stack.quality.name) or "normal"
            local key = stack.name .. "|" .. q_name
            if not required_items[key] then
                required_items[key] = { name = stack.name, quality = q_name, count = 0 }
            end
            required_items[key].count = required_items[key].count + stack.count
        end
    end

    -- 2. Verify the destination hub chest has room for the entire payload
    for _, req in pairs(required_items) do
        local insertable = hub_inv.get_insertable_count({ name = req.name, quality = req.quality })
        if insertable < req.count then
            return false -- Hub cannot take everything in one swoop
        end
    end

    return true
end

--- Attempts to transfer all contents from the liminal holder to the hub.
--- Returns true if fully unpacked and destroyed, false if bypassing.
function hub_unpacking.capture(capsule_tracker, hub_entity)
    local phys_capsule = storage.active_capsules and storage.active_capsules[capsule_tracker.id]
    
    if not phys_capsule or not phys_capsule.holder or not phys_capsule.holder.valid then
        return true 
    end

    local holder_inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    local hub_inv = hub_entity.get_inventory(defines.inventory.chest)

    if not holder_inv or not hub_inv then return false end

    -- VIRTUAL CARGO CHECK: Abort immediately if the hub can't accept every item
    if not can_insert_all(holder_inv, hub_inv) then
        return false 
    end

    -- Transfer all stacks (cargo + vessel item) directly to the hub
    for i = 1, #holder_inv do
        local stack = holder_inv[i]
        if stack and stack.valid_for_read then
            hub_inv.insert(stack)
        end
    end

    -- Destroy liminal holder and unregister active capsule
    phys_capsule.holder.destroy()
    storage.active_capsules[capsule_tracker.id] = nil
    
    -- APPLY THE MECHANICAL LATCH
    storage.hub_receive_locks = storage.hub_receive_locks or {}
    storage.hub_receive_locks[hub_entity.unit_number] = true
    
    return true
end

return hub_unpacking