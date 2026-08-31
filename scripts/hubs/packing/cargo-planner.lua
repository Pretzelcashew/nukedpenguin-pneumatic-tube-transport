-- FILE: scripts/hubs/packing/cargo-planner.lua

local capsule_defs = require("scripts.capsules.capsule-definitions")

local cargo_planner = {}

--- Evaluates the slot cost factor for a given item type based on capsule slot cost definitions
--- @param item_name string
--- @param capsule_def table
--- @return number Slot cost per stack (e.g. 0.5 for bio items, 1.0 for inorganic)
function cargo_planner.get_item_slot_cost(item_name, capsule_def)
    if not (capsule_def and capsule_def.slot_costs) then
        return 1.0
    end
    if capsule_defs.is_bio_item(item_name) then
        return capsule_def.slot_costs.bio_item or 0.5
    end
    return capsule_def.slot_costs.inorganic or 1.0
end

function cargo_planner.plan_single_type_cargo(item_name, stack_size, sources, max_slots, require_full_stacks, allow_consolidation, capsule_def)
    local plan = { extractions = {}, insertions = {}, slots_used = 0 }
    local slot_cost = cargo_planner.get_item_slot_cost(item_name, capsule_def)
    local max_affordable_stacks = math.floor(max_slots / slot_cost)

    if allow_consolidation then
        local total_count = 0
        local quality_name = sources[1] and sources[1].quality_name or "normal"
        for _, src in ipairs(sources) do total_count = total_count + src.count end

        local possible_full_stacks = math.floor(total_count / stack_size)
        local stacks_to_take = math.min(possible_full_stacks, max_affordable_stacks)

        if stacks_to_take > 0 then
            local items_needed = stacks_to_take * stack_size
            for _, src in ipairs(sources) do
                if items_needed <= 0 then break end
                local take_amount = math.min(src.count, items_needed)
                table.insert(plan.extractions, {
                    slot_index = src.slot_index,
                    count = take_amount,
                    is_primary_leftover = src.is_primary_leftover
                })
                items_needed = items_needed - take_amount
            end

            for k = 1, stacks_to_take do
                table.insert(plan.insertions, { name = item_name, count = stack_size, quality = quality_name })
            end
            plan.slots_used = stacks_to_take * slot_cost
        end

    elseif require_full_stacks then
        local full_sources = {}
        for _, src in ipairs(sources) do
            if src.count == stack_size then
                table.insert(full_sources, src)
            end
        end

        local stacks_to_take = math.min(#full_sources, max_affordable_stacks)
        for k = 1, stacks_to_take do
            local src = full_sources[k]
            table.insert(plan.extractions, {
                slot_index = src.slot_index,
                count = stack_size,
                is_primary_leftover = src.is_primary_leftover
            })
            table.insert(plan.insertions, { name = item_name, count = stack_size, quality = src.quality_name })
        end
        plan.slots_used = stacks_to_take * slot_cost

    else
        local stacks_to_take = math.min(#sources, max_affordable_stacks)
        for k = 1, stacks_to_take do
            local src = sources[k]
            table.insert(plan.extractions, {
                slot_index = src.slot_index,
                count = src.count,
                is_primary_leftover = src.is_primary_leftover
            })
            table.insert(plan.insertions, { name = item_name, count = src.count, quality = src.quality_name })
        end
        plan.slots_used = stacks_to_take * slot_cost
    end

    return plan
end

function cargo_planner.build_packing_plan(grouped_inventory, group_order, max_cargo_slots, capsule_def, self_slot_cost, required_min_slots)
    local require_full_stacks = capsule_def.full_stacks or false
    local allow_consolidation = require_full_stacks and (capsule_def.consolidate_stacks or false)
    local packing_plan = { extractions = {}, insertions = {}, slots_used = 0 }

    if capsule_def.mixed_cargo then
        local remaining_slots = max_cargo_slots
        for _, group_key in ipairs(group_order) do
            if remaining_slots <= 0 then break end
            local grp = grouped_inventory[group_key]
            local plan = cargo_planner.plan_single_type_cargo(grp.item_name, grp.stack_size, grp.sources, remaining_slots, require_full_stacks, allow_consolidation, capsule_def)

            for _, ext in ipairs(plan.extractions) do table.insert(packing_plan.extractions, ext) end
            for _, ins in ipairs(plan.insertions) do table.insert(packing_plan.insertions, ins) end

            packing_plan.slots_used = packing_plan.slots_used + plan.slots_used
            remaining_slots = remaining_slots - plan.slots_used
        end
    else
        local best_plan = { extractions = {}, insertions = {}, slots_used = 0 }
        local max_found_slots = -1

        for _, group_key in ipairs(group_order) do
            local grp = grouped_inventory[group_key]
            local plan = cargo_planner.plan_single_type_cargo(grp.item_name, grp.stack_size, grp.sources, max_cargo_slots, require_full_stacks, allow_consolidation, capsule_def)
            local num_slots = plan.slots_used
            local total_processed = #plan.insertions + self_slot_cost

            if total_processed >= required_min_slots and num_slots > max_found_slots then
                max_found_slots = num_slots
                best_plan = plan
            end
        end

        packing_plan = best_plan
    end

    return packing_plan
end

return cargo_planner