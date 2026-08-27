local hub_settings = require("scripts.hubs.hub-settings")

local hub_unpacking = {}

local function can_insert_all(holder_inv, hub_inv)
    local required_items = {}

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

    local has_items = false
    for _ in pairs(required_items) do
        has_items = true
        break
    end
    if not has_items then return true end

    local max_usable_slot = #hub_inv
    if hub_inv.supports_bar() then
        max_usable_slot = math.min(max_usable_slot, hub_inv.get_bar() - 1)
    end

    local supports_filters = hub_inv.supports_filters()
    local partial_capacities = {}
    local filtered_empty_slots = {}
    local unmapped_empty_slots = 0

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

    for key, req in pairs(required_items) do
        local remaining = req.count

        if partial_capacities[key] and partial_capacities[key] > 0 then
            local fit = math.min(remaining, partial_capacities[key])
            remaining = remaining - fit
            partial_capacities[key] = partial_capacities[key] - fit
        end

        if remaining > 0 then
            local slots_needed = math.ceil(remaining / req.stack_size)

            local q_filter_key = req.name .. "|" .. req.quality
            if filtered_empty_slots[q_filter_key] and filtered_empty_slots[q_filter_key] > 0 then
                local use_filtered = math.min(slots_needed, filtered_empty_slots[q_filter_key])
                slots_needed = slots_needed - use_filtered
                filtered_empty_slots[q_filter_key] = filtered_empty_slots[q_filter_key] - use_filtered
            end

            if slots_needed > 0 and filtered_empty_slots[req.name] and filtered_empty_slots[req.name] > 0 then
                local use_filtered = math.min(slots_needed, filtered_empty_slots[req.name])
                slots_needed = slots_needed - use_filtered
                filtered_empty_slots[req.name] = filtered_empty_slots[req.name] - use_filtered
            end

            if slots_needed > 0 then
                if slots_needed > unmapped_empty_slots then
                    return false
                end
                unmapped_empty_slots = unmapped_empty_slots - slots_needed
            end
        end
    end

    return true
end

function hub_unpacking.capture(capsule_tracker, hub_entity)
    local phys_capsule = storage.active_capsules and storage.active_capsules[capsule_tracker.id]

    if not phys_capsule or not phys_capsule.holder or not phys_capsule.holder.valid then
        return true
    end

    if not hub_settings.can_receive(hub_entity) then
        return false
    end

    local holder_inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    local hub_inv = hub_entity.get_inventory(defines.inventory.chest)

    if not holder_inv or not hub_inv then return false end

    if not can_insert_all(holder_inv, hub_inv) then
        return false
    end

    for i = 1, #holder_inv do
        local stack = holder_inv[i]
        if stack and stack.valid_for_read then
            hub_inv.insert(stack)
        end
    end

    -- Safely exit player passenger adjacent to receiving hub entity
    if capsule_tracker.passenger and capsule_tracker.passenger.valid then
        local safe_pos = hub_entity.surface.find_non_colliding_position("character", hub_entity.position, 3, 0.5)
        if safe_pos then
            capsule_tracker.passenger.teleport(safe_pos, hub_entity.surface)
        end
    end

    phys_capsule.holder.destroy()
    storage.active_capsules[capsule_tracker.id] = nil

    storage.hub_receive_locks = storage.hub_receive_locks or {}
    storage.hub_receive_locks[hub_entity.unit_number] = true

    return true
end

return hub_unpacking