local hub_unpacking = {}

--- Multi-Item Slot Simulation: Verifies destination hub chest can fit ALL payload stacks combined,
--- strictly respecting inventory bar limits AND slot item filters.
local function can_insert_all(holder_inv, hub_inv)
    local required_items = {}

    -- 1. Aggregate all required item quantities and stack sizes from liminal holder
    for i = 1, #holder_inv do
        local stack = holder_inv[i]
        if stack and stack.valid_for_read then
            local q_name = (stack.quality and stack.quality.name) or "normal"
            local key = stack.name .. "|" .. q_name
            if not required_items[key] then
                local proto = stack.prototype
                required_items[key] = {
                    name = stack.name,
                    quality = q_name,
                    count = 0,
                    stack_size = (proto and proto.stack_size) or 50
                }
            end
            required_items[key].count = required_items[key].count + stack.count
        end
    end

    -- If holder is empty, transfer is trivial
    local has_items = false
    for _ in pairs(required_items) do
        has_items = true
        break
    end
    if not has_items then return true end

    -- 2. Respect Inventory Bar Limits (Red crossed slots)
    local max_usable_slot = #hub_inv
    if hub_inv.supports_bar() then
        max_usable_slot = math.min(max_usable_slot, hub_inv.get_bar() - 1)
    end

    local supports_filters = hub_inv.supports_filters()

    -- 3. Map usable hub chest space up to the bar limit only
    local partial_capacities = {}
    local filtered_empty_slots = {} -- Maps filter_name or "filter_name|quality" -> count
    local unmapped_empty_slots = 0  -- Count of empty slots with no filter

    for i = 1, max_usable_slot do
        local stack = hub_inv[i]
        local raw_filter = supports_filters and hub_inv.get_filter(i)

        if stack and stack.valid_for_read then
            local q_name = (stack.quality and stack.quality.name) or "normal"
            local key = stack.name .. "|" .. q_name
            local proto = stack.prototype
            local max_size = (proto and proto.stack_size) or 50
            local space = max_size - stack.count
            if space > 0 then
                partial_capacities[key] = (partial_capacities[key] or 0) + space
            end
        else
            -- Slot is empty: extract name/quality strings if restricted by an item filter
            if raw_filter then
                local filter_name = nil
                local filter_quality = nil

                if type(raw_filter) == "table" then
                    filter_name = raw_filter.name
                    filter_quality = raw_filter.quality and (type(raw_filter.quality) == "table" and raw_filter.quality.name or raw_filter.quality)
                else
                    filter_name = raw_filter
                end

                if filter_name then
                    if filter_quality then
                        local f_key = filter_name .. "|" .. filter_quality
                        filtered_empty_slots[f_key] = (filtered_empty_slots[f_key] or 0) + 1
                    else
                        filtered_empty_slots[filter_name] = (filtered_empty_slots[filter_name] or 0) + 1
                    end
                else
                    unmapped_empty_slots = unmapped_empty_slots + 1
                end
            else
                unmapped_empty_slots = unmapped_empty_slots + 1
            end
        end
    end

    -- 4. Verify required items fit sequentially into partial stacks then empty slots
    for key, req in pairs(required_items) do
        local remaining = req.count

        -- Fill into matching partial stacks first
        if partial_capacities[key] and partial_capacities[key] > 0 then
            local fit = math.min(remaining, partial_capacities[key])
            remaining = remaining - fit
            partial_capacities[key] = partial_capacities[key] - fit
        end

        -- Allocate remaining items into matching filtered empty slots or unfiltered slots
        if remaining > 0 then
            local slots_needed = math.ceil(remaining / req.stack_size)

            -- Try quality-specific filtered empty slots first (e.g., "iron-ore|uncommon")
            local q_filter_key = req.name .. "|" .. req.quality
            if filtered_empty_slots[q_filter_key] and filtered_empty_slots[q_filter_key] > 0 then
                local use_filtered = math.min(slots_needed, filtered_empty_slots[q_filter_key])
                slots_needed = slots_needed - use_filtered
                filtered_empty_slots[q_filter_key] = filtered_empty_slots[q_filter_key] - use_filtered
            end

            -- Try generic item filtered empty slots (no quality restriction on filter, e.g., "iron-ore")
            if slots_needed > 0 and filtered_empty_slots[req.name] and filtered_empty_slots[req.name] > 0 then
                local use_filtered = math.min(slots_needed, filtered_empty_slots[req.name])
                slots_needed = slots_needed - use_filtered
                filtered_empty_slots[req.name] = filtered_empty_slots[req.name] - use_filtered
            end

            -- Use general unmapped empty slots for the rest
            if slots_needed > 0 then
                if slots_needed > unmapped_empty_slots then
                    return false -- Hub chest cannot fit payload due to item filters or full slots
                end
                unmapped_empty_slots = unmapped_empty_slots - slots_needed
            end
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

    -- OPERATIONAL MODE TOGGLE: Verify receive (arrival) permission
    local unit_number = hub_entity.unit_number
    if storage.hub_settings and storage.hub_settings[unit_number] then
        if storage.hub_settings[unit_number].can_receive == false then
            return false
        end
    end

    local holder_inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    local hub_inv = hub_entity.get_inventory(defines.inventory.chest)

    if not holder_inv or not hub_inv then return false end

    -- VIRTUAL CARGO CHECK: Abort immediately if hub chest cannot fit combined payload
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