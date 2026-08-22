-- FILE: scripts/hubs/hub-packing.lua
local events = require("scripts.events")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")
local capsule_manager = require("scripts.capsules.capsule-manager")
local hub_defs = require("scripts.hubs.hub-definitions")
local capsule_defs = require("scripts.capsules.capsule-definitions")

local quality_filter = require("scripts.hubs.packing.quality-filter")
local cargo_planner = require("scripts.hubs.packing.cargo-planner")

local hub_packing = {}

function hub_packing.evaluate_inventory(entity)
    if not (entity and entity.valid) then return end

    local hub_def = hub_defs.types[entity.name]
    if not (hub_def and hub_def.type == "hub") then return end

    -- 0. EARLY CAPACITY GUARD
    -- Checks the hub's compartment array size before touching entity inventories
    local unit_number = entity.unit_number
    storage.hub_compartments = storage.hub_compartments or {}
    storage.hub_compartments[unit_number] = storage.hub_compartments[unit_number] or {}
    local compartment = storage.hub_compartments[unit_number]

    local max_capacity = hub_def.capsule_capacity or 1
    if #compartment >= max_capacity then
        return
    end

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
                    quality_level = stack.quality.level or quality_filter.QUALITY_LEVELS[stack.quality.name] or 0
                    quality_name = stack.quality.name or "normal"
                end
                break
            end
        end
    end

    if not primary_slot then return end

    -- 2. Calculate capacity & limits
    local quality_bonus = quality_level * (capsule_def.quality_affected_capacity or 0)
    local total_capacity = capsule_def.base_capacity + quality_bonus
    local self_slot_cost = capsule_def.include_self and 1 or 0
    local max_cargo_slots = total_capacity - self_slot_cost

    local required_min_slots = 0
    if type(capsule_def.minimum_cargo) == "string" and capsule_def.minimum_cargo:lower() == "ceil" then
        required_min_slots = total_capacity
    elseif type(capsule_def.minimum_cargo) == "number" then
        required_min_slots = capsule_def.minimum_cargo
    end

    if max_cargo_slots < 0 then return end

    -- 3. Filter and group inventory
    local allow_consolidation = (capsule_def.full_stacks or false) and (capsule_def.consolidate_stacks or false)
    local mq_setting = capsule_def.mixed_quality
    local allow_mixed_quality = (mq_setting == true or mq_setting == "any")
    local is_strict_capsule = (mq_setting == "strict" or mq_setting == "capsule")
    local is_vessel_lock = (mq_setting == "vessel")

    local grouped_inventory = {}
    local group_order = {}

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            local item_name = stack.name
            local item_q_name = stack.quality and stack.quality.name or "normal"
            local item_q_level = (stack.quality and stack.quality.level) or quality_filter.QUALITY_LEVELS[item_q_name] or 0
            local avail_count = stack.count
            local is_primary_leftover = (i == primary_slot)

            if is_primary_leftover then avail_count = avail_count - 1 end

            local vessel_lock_pass = not is_vessel_lock or (item_q_level == quality_level)

            if avail_count > 0 and vessel_lock_pass and quality_filter.is_quality_allowed(item_q_name, item_q_level, quality_level, capsule_def.quality_filter) then
                local group_key = item_name
                if not allow_mixed_quality or allow_consolidation or is_strict_capsule then
                    group_key = item_name .. "@" .. item_q_name
                end

                if not grouped_inventory[group_key] then
                    grouped_inventory[group_key] = {
                        item_name = item_name,
                        stack_size = stack.prototype.stack_size,
                        sources = {}
                    }
                    table.insert(group_order, group_key)
                end

                table.insert(grouped_inventory[group_key].sources, {
                    slot_index = i,
                    count = avail_count,
                    quality_name = item_q_name,
                    is_primary_leftover = is_primary_leftover
                })
            end
        end
    end

    -- Enforce 'strict' / 'capsule' single quality lock across different item types
    if is_strict_capsule and #group_order > 0 then
        local target_quality = grouped_inventory[group_order[1]].sources[1].quality_name
        local filtered_order = {}

        for _, key in ipairs(group_order) do
            if key:find("@" .. target_quality .. "$") then
                table.insert(filtered_order, key)
            end
        end
        group_order = filtered_order
    end

    -- 4. Calculate transfer plan
    local packing_plan = cargo_planner.build_packing_plan(
        grouped_inventory, group_order, max_cargo_slots, capsule_def, self_slot_cost, required_min_slots
    )

    local total_slots_processed = #packing_plan.insertions + self_slot_cost
    if total_slots_processed < required_min_slots then return end

    -- 5. Spawn holder
    local liminal_surface = liminal_surface_mgr.get()
    local holder_prototype = capsule_def.holder_type or "invisible-capsule-holder"
    local holder = liminal_surface.create_entity{
        name = holder_prototype,
        position = {0, 0},
        force = entity.force
    }
    local dest_inv = holder.get_inventory(defines.inventory.chest)

    -- 6. Execute extractions & insertions
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
        dest_inv.insert{name = ins.name, count = ins.count, quality = ins.quality}
    end

    -- 7. Handle primary capsule lifecycle
    local primary_stack = inventory[primary_slot]
    if primary_stack and primary_stack.valid_for_read then
        if capsule_def.include_self and not capsule_def.destroy_self then
            dest_inv.insert{name = primary_stack.name, count = 1, quality = quality_name}
        end

        if capsule_def.include_self or capsule_def.destroy_self then
            if primary_stack.count > 1 then
                primary_stack.count = primary_stack.count - 1
            else
                primary_stack.clear()
            end
        end
    end

    -- 8. Final checks & compartment loading
    if capsule_def.destroy_holder_if_empty and dest_inv.is_empty() then
        holder.destroy()
        return
    end

    local capsule_id = capsule_manager.register(holder, capsule_name)
    if capsule_id then
        table.insert(compartment, capsule_id)
    end
end

return hub_packing