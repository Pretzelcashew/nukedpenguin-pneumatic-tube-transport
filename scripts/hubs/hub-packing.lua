-- FILE: scripts/hubs/hub-packing.lua
local events = require("scripts.events")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")
local capsule_manager = require("scripts.capsules.capsule-manager")
local hub_defs = require("scripts.hubs.hub-definitions")
local capsule_defs = require("scripts.capsules.capsule-definitions")

local hub_packing = {}

-- Helper to plan imaginary consolidation / full stack extractions for a single item type
local function plan_single_type_cargo(item_name, stack_size, sources, max_slots, require_full_stacks, allow_consolidation)
    local plan = { extractions = {}, insertions = {} }

    if allow_consolidation then
        -- 1. Imaginary Consolidation: Calculate total items and how many full stacks they yield
        local total_count = 0
        for _, src in ipairs(sources) do total_count = total_count + src.count end

        local possible_full_stacks = math.floor(total_count / stack_size)
        local stacks_to_take = math.min(possible_full_stacks, max_slots)

        if stacks_to_take > 0 then
            local items_needed = stacks_to_take * stack_size
            
            -- Plan physical extractions from hub slots (drain until items_needed == 0)
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

            -- Plan holder insertions as consolidated full stacks
            for k = 1, stacks_to_take do
                table.insert(plan.insertions, { name = item_name, count = stack_size })
            end
        end

    elseif require_full_stacks then
        -- 2. Strict Full Stacks: Only accept slots that are already individual full stacks
        local full_sources = {}
        for _, src in ipairs(sources) do
            if src.count == stack_size then
                table.insert(full_sources, src)
            end
        end

        local stacks_to_take = math.min(#full_sources, max_slots)
        for k = 1, stacks_to_take do
            local src = full_sources[k]
            table.insert(plan.extractions, {
                slot_index = src.slot_index,
                count = stack_size,
                is_primary_leftover = src.is_primary_leftover
            })
            table.insert(plan.insertions, { name = item_name, count = stack_size })
        end

    else
        -- 3. Standard: Take slots as they are
        local slots_to_take = math.min(#sources, max_slots)
        for k = 1, slots_to_take do
            local src = sources[k]
            table.insert(plan.extractions, {
                slot_index = src.slot_index,
                count = src.count,
                is_primary_leftover = src.is_primary_leftover
            })
            table.insert(plan.insertions, { name = item_name, count = src.count })
        end
    end

    return plan
end

function hub_packing.evaluate_inventory(entity)
    if not (entity and entity.valid) then return end

    local hub_def = hub_defs.types[entity.name]
    if not (hub_def and hub_def.type == "hub") then return end

    local inventory = entity.get_inventory(defines.inventory.chest)
    if not inventory or inventory.is_empty() then return end

    -- 1. Identify primary vessel capsule
    local primary_slot = nil
    local capsule_def = nil
    local capsule_name = nil
    local quality_level = 0
    local quality_name = "normal"

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            local def = capsule_defs.types[stack.name]
            if def then
                primary_slot = i
                capsule_def = def
                capsule_name = stack.name
                if stack.quality then
                    quality_level = stack.quality.level or 0
                    quality_name = stack.quality.name or "normal"
                end
                break
            end
        end
    end

    if not primary_slot then return end

    -- 2. Calculate capacity (base + quality bonus)
    local quality_bonus = quality_level * (capsule_def.quality_affected_capacity or 0)
    local total_capacity = capsule_def.base_capacity + quality_bonus

    local self_slot_cost = capsule_def.include_self and 1 or 0
    local max_cargo_slots = total_capacity - self_slot_cost

    -- Resolve polymorphic minimum_cargo
    local required_min_slots = 0
    if type(capsule_def.minimum_cargo) == "string" and capsule_def.minimum_cargo:lower() == "ceil" then
        required_min_slots = total_capacity
    elseif type(capsule_def.minimum_cargo) == "number" then
        required_min_slots = capsule_def.minimum_cargo
    end

    game.print(string.format("[HUB DEBUG] Found '%s' (%s, Level %d) | Base Cap: %d | Quality Bonus: +%d | Total Cap: %d | Max Cargo Slots: %d | Min Req: %d", 
        capsule_name, quality_name, quality_level, capsule_def.base_capacity, quality_bonus, total_capacity, max_cargo_slots, required_min_slots))

    if max_cargo_slots < 0 then
        game.print("[HUB DEBUG] Aborted: max_cargo_slots is less than 0 (cannot fit self)")
        return
    end

    -- 3. Group inventory by item type for imaginary pre-checks
    local require_full_stacks = capsule_def.full_stacks or false
    local allow_consolidation = require_full_stacks and (capsule_def.consolidate_stacks or false)

    local grouped_inventory = {}
    local item_order = {}

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            local item_name = stack.name
            local avail_count = stack.count
            local is_primary_leftover = (i == primary_slot)

            if is_primary_leftover then
                avail_count = avail_count - 1
            end

            if avail_count > 0 then
                if not grouped_inventory[item_name] then
                    grouped_inventory[item_name] = {
                        stack_size = stack.prototype.stack_size,
                        sources = {}
                    }
                    table.insert(item_order, item_name)
                end
                table.insert(grouped_inventory[item_name].sources, {
                    slot_index = i,
                    count = avail_count,
                    is_primary_leftover = is_primary_leftover
                })
            end
        end
    end

    -- Build transfer plan (Extractions & Consolidated Insertions)
    local packing_plan = { extractions = {}, insertions = {} }

    if capsule_def.mixed_cargo then
        -- Mixed Cargo: Fill cargo slots across multiple item types in inventory order
        local remaining_slots = max_cargo_slots
        for _, item_name in ipairs(item_order) do
            if remaining_slots <= 0 then break end
            local grp = grouped_inventory[item_name]
            local plan = plan_single_type_cargo(item_name, grp.stack_size, grp.sources, remaining_slots, require_full_stacks, allow_consolidation)

            for _, ext in ipairs(plan.extractions) do table.insert(packing_plan.extractions, ext) end
            for _, ins in ipairs(plan.insertions) do table.insert(packing_plan.insertions, ins) end

            remaining_slots = remaining_slots - #plan.insertions
        end
    else
        -- Single Item Type: Pick the single group offering the most valid slots
        local best_plan = { extractions = {}, insertions = {} }
        local max_found_slots = -1

        for _, item_name in ipairs(item_order) do
            local grp = grouped_inventory[item_name]
            local plan = plan_single_type_cargo(item_name, grp.stack_size, grp.sources, max_cargo_slots, require_full_stacks, allow_consolidation)
            local num_slots = #plan.insertions
            local total_processed = num_slots + self_slot_cost

            if total_processed >= required_min_slots and num_slots > max_found_slots then
                max_found_slots = num_slots
                best_plan = plan
            end
        end

        packing_plan = best_plan
    end

    -- 4. Evaluate minimum cargo requirement
    local total_slots_processed = #packing_plan.insertions + self_slot_cost

    if total_slots_processed < required_min_slots then
        game.print(string.format("[HUB DEBUG] Aborted: Could not find valid cargo configuration (Processed %d < Min Required %d)", 
            total_slots_processed, required_min_slots))
        return
    end

    -- 5. Create holder using dynamic holder_type
    local liminal_surface = liminal_surface_mgr.get()
    local holder_prototype = capsule_def.holder_type or "invisible-capsule-holder"
    
    local holder = liminal_surface.create_entity{
        name = holder_prototype,
        position = {0, 0},
        force = entity.force
    }

    local dest_inv = holder.get_inventory(defines.inventory.chest)

    -- 6. Execute physical extraction from Hub and insert consolidated stacks to Holder
    for _, ext in ipairs(packing_plan.extractions) do
        local stack = inventory[ext.slot_index]
        if stack and stack.valid_for_read then
            if stack.count > ext.count then
                stack.count = stack.count - ext.count
            else
                stack.clear()
            end
        end
    end

    for _, ins in ipairs(packing_plan.insertions) do
        dest_inv.insert{name = ins.name, count = ins.count}
    end

    -- 7. Process primary capsule item lifecycle
    local primary_stack = inventory[primary_slot]
    if primary_stack and primary_stack.valid_for_read then
        if capsule_def.include_self and not capsule_def.destroy_self then
            dest_inv.insert{
                name = primary_stack.name,
                count = 1,
                quality = quality_name
            }
            game.print(string.format("[HUB DEBUG] Primary capsule '%s' inserted into holder", capsule_name))
        end

        if capsule_def.include_self or capsule_def.destroy_self then
            if primary_stack.count > 1 then
                primary_stack.count = primary_stack.count - 1
            else
                primary_stack.clear()
            end
            local action = capsule_def.destroy_self and "destroyed" or "consumed"
            game.print(string.format("[HUB DEBUG] Primary capsule '%s' %s from hub chest", capsule_name, action))
        end
    end

    -- 8. Validate destroy_holder_if_empty
    if capsule_def.destroy_holder_if_empty and dest_inv.is_empty() then
        game.print(string.format("[HUB DEBUG] Aborted: Holder '%s' destroyed because inventory was empty", holder_prototype))
        holder.destroy()
        return
    end

    -- 9. Register populated holder
    local capsule_id = capsule_manager.register(holder, capsule_name)
    game.print(string.format("[PACK SUCCESS] Capsule %s -> Holder %d (%s) | Packed %d cargo slots", 
        capsule_name, capsule_id or holder.unit_number, holder_prototype, #packing_plan.insertions))
end

return hub_packing