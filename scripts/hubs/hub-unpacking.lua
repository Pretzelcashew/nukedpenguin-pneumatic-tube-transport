local hub_settings = require("scripts.hubs.hub-settings")
local capsule_manager = require("scripts.capsules.capsule-manager")

local hub_unpacking = {}

local scratch_req_names = {}
local scratch_req_qualities = {}
local scratch_req_counts = {}
local scratch_req_sizes = {}
local scratch_req_keys = {}

local scratch_partial = {}
local scratch_filtered = {}

local function clear_scratch()
    for i = 1, #scratch_req_keys do
        local key = scratch_req_keys[i]
        scratch_req_names[key] = nil
        scratch_req_qualities[key] = nil
        scratch_req_counts[key] = nil
        scratch_req_sizes[key] = nil
        scratch_req_keys[i] = nil
    end
    for k in pairs(scratch_partial) do scratch_partial[k] = nil end
    for k in pairs(scratch_filtered) do scratch_filtered[k] = nil end
end

local function can_insert_all(holder_inv, hub_inv)
    if not (holder_inv and hub_inv) then return false end
    if holder_inv.is_empty() then return true end

    local max_usable_slot = #hub_inv
    if hub_inv.supports_bar() then
        max_usable_slot = math.min(max_usable_slot, hub_inv.get_bar() - 1)
    end
    if max_usable_slot <= 0 then return false end

    clear_scratch()

    local max_holder_slot = (holder_inv.supports_bar()) and math.min(#holder_inv, holder_inv.get_bar() - 1) or #holder_inv
    local num_req_keys = 0

    for i = 1, max_holder_slot do
        local stack = holder_inv[i]
        if stack and stack.valid_for_read then
            local q_obj = stack.quality
            local q_name = (q_obj and q_obj.name) or "normal"
            local item_name = stack.name
            local key = (q_name == "normal") and item_name or (item_name .. "|" .. q_name)

            if not scratch_req_counts[key] then
                scratch_req_counts[key] = 0
                scratch_req_names[key] = item_name
                scratch_req_qualities[key] = q_name
                local proto = stack.prototype
                scratch_req_sizes[key] = (proto and proto.stack_size) or 50
                num_req_keys = num_req_keys + 1
                scratch_req_keys[num_req_keys] = key
            end
            scratch_req_counts[key] = scratch_req_counts[key] + stack.count
        end
    end

    if num_req_keys == 0 then
        return true
    end

    local supports_filters = hub_inv.supports_filters()

    -- Fast-path for empty container without filters: calculate total slots needed directly
    if hub_inv.is_empty() and not supports_filters then
        local total_slots_needed = 0
        for i = 1, num_req_keys do
            local key = scratch_req_keys[i]
            total_slots_needed = total_slots_needed + math.ceil(scratch_req_counts[key] / scratch_req_sizes[key])
        end
        return total_slots_needed <= max_usable_slot
    end

    local unmapped_empty_slots = 0

    for i = 1, max_usable_slot do
        local stack = hub_inv[i]
        local raw_filter = supports_filters and hub_inv.get_filter(i)

        if stack and stack.valid_for_read then
            local q_obj = stack.quality
            local q_name = (q_obj and q_obj.name) or "normal"
            local item_name = stack.name
            local key = (q_name == "normal") and item_name or (item_name .. "|" .. q_name)
            local proto = stack.prototype
            local max_size = (proto and proto.stack_size) or 50
            local space = max_size - stack.count
            if space > 0 then
                scratch_partial[key] = (scratch_partial[key] or 0) + space
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
                        local f_key = (filter_quality == "normal") and filter_name or (filter_name .. "|" .. filter_quality)
                        scratch_filtered[f_key] = (scratch_filtered[f_key] or 0) + 1
                    else
                        scratch_filtered[filter_name] = (scratch_filtered[filter_name] or 0) + 1
                    end
                else
                    unmapped_empty_slots = unmapped_empty_slots + 1
                end
            else
                unmapped_empty_slots = unmapped_empty_slots + 1
            end
        end
    end

    for i = 1, num_req_keys do
        local key = scratch_req_keys[i]
        local item_name = scratch_req_names[key]
        local req_quality = scratch_req_qualities[key]
        local stack_size = scratch_req_sizes[key]
        local remaining = scratch_req_counts[key]

        if scratch_partial[key] and scratch_partial[key] > 0 then
            local fit = math.min(remaining, scratch_partial[key])
            remaining = remaining - fit
            scratch_partial[key] = scratch_partial[key] - fit
        end

        if remaining > 0 then
            local slots_needed = math.ceil(remaining / stack_size)

            local q_filter_key = (req_quality == "normal") and item_name or (item_name .. "|" .. req_quality)
            if scratch_filtered[q_filter_key] and scratch_filtered[q_filter_key] > 0 then
                local use_filtered = math.min(slots_needed, scratch_filtered[q_filter_key])
                slots_needed = slots_needed - use_filtered
                scratch_filtered[q_filter_key] = scratch_filtered[q_filter_key] - use_filtered
            end

            if slots_needed > 0 and scratch_filtered[item_name] and scratch_filtered[item_name] > 0 then
                local use_filtered = math.min(slots_needed, scratch_filtered[item_name])
                slots_needed = slots_needed - use_filtered
                scratch_filtered[item_name] = scratch_filtered[item_name] - use_filtered
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
    local phys_capsule = capsule_manager.get(capsule_tracker.id)

    if not phys_capsule or not phys_capsule.holder or not phys_capsule.holder.valid then
        return true
    end

    if not hub_settings.can_receive(hub_entity) then
        return false
    end

    local holder_inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    local hub_inv = hub_entity.get_inventory(defines.inventory.chest)

    if not holder_inv or not hub_inv then return false end
    if holder_inv.is_empty() then return true end

    local hub_unit = hub_entity.unit_number
    local cur_hub_count = hub_inv.get_item_count()
    local cur_hub_bar = hub_inv.supports_bar() and hub_inv.get_bar() or 0
    local cur_cap_count = holder_inv.get_item_count()

    -- State Guard: Short-circuit if destination container space and capsule payload have not changed
    if capsule_tracker.last_failed_hub == hub_unit
       and cur_hub_count >= (capsule_tracker.last_failed_hub_count or 0)
       and cur_hub_bar <= (capsule_tracker.last_failed_hub_bar or 0)
       and cur_cap_count >= (capsule_tracker.last_failed_cap_count or 0) then
        return false
    end

    if not can_insert_all(holder_inv, hub_inv) then
        capsule_tracker.last_failed_hub = hub_unit
        capsule_tracker.last_failed_hub_count = cur_hub_count
        capsule_tracker.last_failed_hub_bar = cur_hub_bar
        capsule_tracker.last_failed_cap_count = cur_cap_count
        return false
    end

    capsule_tracker.last_failed_hub = nil
    capsule_tracker.last_failed_hub_count = nil
    capsule_tracker.last_failed_hub_bar = nil
    capsule_tracker.last_failed_cap_count = nil

    local max_holder_slot = (holder_inv and holder_inv.supports_bar()) and math.min(#holder_inv, holder_inv.get_bar() - 1) or #holder_inv
    for i = 1, max_holder_slot do
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

    capsule_manager.remove(capsule_tracker.id)

    storage.hub_receive_locks = storage.hub_receive_locks or {}
    storage.hub_receive_locks[hub_unit] = true

    return true
end

return hub_unpacking