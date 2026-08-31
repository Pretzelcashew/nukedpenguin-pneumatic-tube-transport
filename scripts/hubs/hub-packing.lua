local events = require("scripts.events")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")
local capsule_manager = require("scripts.capsules.capsule-manager")
local hub_defs = require("scripts.hubs.hub-definitions")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local quality_filter = require("scripts.hubs.packing.quality-filter")
local cargo_planner = require("scripts.hubs.packing.cargo-planner")
local capsule_runner = require("scripts.capsules.capsule-runner")
local hub_settings = require("scripts.hubs.hub-settings")
local item_transfer_handler = require("scripts.utils.item-transfer-handler")

local hub_packing = {}

--- Helper to safely test if an item stack is spoilable without triggering Factorio 2.0 LuaItemPrototype __index errors
local function is_stack_spoilable(stack)
    if not (stack and stack.valid_for_read) then return false end
    local proto = stack.prototype
    if proto and proto.get_spoil_ticks then
        local ticks = proto.get_spoil_ticks()
        if ticks and ticks > 0 then
            return true
        end
    end
    if stack.spoil_tick and stack.spoil_tick > 0 then
        return true
    end
    if stack.spoil_percent and stack.spoil_percent > 0 then
        return true
    end
    return false
end

--- Evaluates if an item stack is spoilable into physical units (biters, pentapods, etc.)
--- Uses strict C++ prototype property inspection and exact matrix lookups (zero fuzzy string matching).
local function is_unit_spoilable(stack)
    if not (stack and stack.valid_for_read) then return false end
    if not is_stack_spoilable(stack) then return false end

    local proto = stack.prototype
    if proto and proto.spoil_to_trigger_result then
        return true
    end

    if capsule_defs.is_unit_spoilable and capsule_defs.is_unit_spoilable(stack.name) then
        return true
    end

    return false
end

function hub_packing.evaluate_inventory(entity)
    if not (entity and entity.valid) then return end

    local hub_def = hub_defs.types[entity.name]
    if not (hub_def and hub_def.type == "hub") then return end

    local unit_number = entity.unit_number

    if not hub_settings.can_send(entity) then return end

    local inventory = entity.get_inventory(defines.inventory.chest)
    if not inventory then return end

    local settings = hub_settings.get(unit_number)
    if settings.use_receive_lock and storage.hub_receive_locks and storage.hub_receive_locks[unit_number] then
        if inventory.is_empty() then
            storage.hub_receive_locks[unit_number] = nil
        else
            return
        end
    end

    if inventory.is_empty() then return end

    local max_capacity = hub_def.capsule_capacity or 1
    local current_occupants = capsule_runner.get_capsule_count_at_entity(unit_number)
    if current_occupants >= max_capacity then return end

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

    -- Handle Player Transit Capsule dispatch
    local passenger = nil
    if capsule_def.is_player_transit then
        local nearby_players = entity.surface.find_entities_filtered{
            type = "character",
            position = entity.position,
            radius = 2.5
        }
        if #nearby_players > 0 and nearby_players[1].player then
            passenger = nearby_players[1].player
        else
            return
        end
    end

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

    if max_cargo_slots < 0 and not capsule_def.is_player_transit then return end

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

    local packing_plan = cargo_planner.build_packing_plan(
        grouped_inventory, group_order, math.max(0, max_cargo_slots), capsule_def, self_slot_cost, required_min_slots
    )

    local total_slots_processed = #packing_plan.insertions + self_slot_cost
    if total_slots_processed < required_min_slots and not capsule_def.is_player_transit then return end

    -- Evaluate whether cargo or primary vessel can spoil into physical units
    local spill_contents = capsule_def.spill_contents
    local units_allowed = true
    if type(spill_contents) == "table" and spill_contents.units == false then
        units_allowed = false
    elseif spill_contents == false then
        units_allowed = false
    end

    local is_unit_cargo = false
    if units_allowed then
        if is_unit_spoilable(inventory[primary_slot]) then
            is_unit_cargo = true
        end
        if not is_unit_cargo then
            for i = 1, #inventory do
                local stack = inventory[i]
                if stack and stack.valid_for_read and is_unit_spoilable(stack) then
                    is_unit_cargo = true
                    break
                end
            end
        end
    end

    local requires_wide_cell = is_unit_cargo and units_allowed

    local liminal_surface = liminal_surface_mgr.get()
    local holder_prototype = capsule_def.holder_type or "invisible-capsule-holder"
    local holder_pos, allocated_is_wide = liminal_surface_mgr.allocate_position(requires_wide_cell)

    -- Synchronously ensure target chunk exists and cell tiles/moat are painted before entity creation
    liminal_surface_mgr.ensure_chunk_at(liminal_surface, holder_pos, allocated_is_wide)

    local holder = liminal_surface.create_entity{
        name = holder_prototype,
        position = holder_pos,
        force = entity.force
    }
    local dest_inv = holder.get_inventory(defines.inventory.chest)

    -- Dynamically bound holder cargohold size to exact capsule capacity
    local required_holder_slots = math.max(total_capacity, self_slot_cost)
    if dest_inv and dest_inv.supports_bar() and required_holder_slots > 0 then
        local bar_limit = math.min(#dest_inv + 1, required_holder_slots + 1)
        dest_inv.set_bar(bar_limit)
    end

    -- 1. Insert Cargo Extractions First, track dominant payload item name & evaluate spoilability
    local dominant_cargo_item = nil
    local max_cargo_count = 0
    local cargo_counts = {}
    local has_spoilable_items = false

    local max_search = (dest_inv and dest_inv.supports_bar()) and (dest_inv.get_bar() - 1) or #dest_inv

    for _, ext in ipairs(packing_plan.extractions) do
        local stack = inventory[ext.slot_index]
        if stack and stack.valid_for_read then
            local item_name = stack.name
            local original_count = stack.count
            local amount_to_transfer = math.min(ext.count, original_count)

            if is_stack_spoilable(stack) then
                has_spoilable_items = true
            end

            cargo_counts[item_name] = (cargo_counts[item_name] or 0) + amount_to_transfer
            if cargo_counts[item_name] > max_cargo_count then
                max_cargo_count = cargo_counts[item_name]
                dominant_cargo_item = item_name
            end

            item_transfer_handler.transfer_stack(stack, dest_inv, max_search, amount_to_transfer)
        end
    end

    local dominant_payload_item = dominant_cargo_item or capsule_name

    -- 2. Insert and Track Primary Capsule Shell Slot
    local primary_holder_slot = nil
    local primary_stack = inventory[primary_slot]
    if primary_stack and primary_stack.valid_for_read then
        if is_stack_spoilable(primary_stack) then
            has_spoilable_items = true
        end

        if capsule_def.include_self and not capsule_def.destroy_self then
            local target_slot = nil
            for i = 1, max_search do
                if not dest_inv[i].valid_for_read then
                    target_slot = i
                    break
                end
            end

            local transferred = false
            if target_slot then
                if dest_inv[target_slot].transfer_stack(primary_stack, 1) then
                    transferred = true
                    primary_holder_slot = target_slot
                end
            end

            if not transferred then
                local src_grid = primary_stack.grid
                local stack_spec = item_transfer_handler.build_stack_spec(primary_stack, 1)

                if primary_stack.count > 1 then
                    primary_stack.count = primary_stack.count - 1
                else
                    primary_stack.clear()
                end

                if target_slot then
                    dest_inv[target_slot].set_stack(stack_spec)
                    primary_holder_slot = target_slot
                    if src_grid and src_grid.valid then
                        item_transfer_handler.copy_equipment_grid(src_grid, dest_inv[target_slot])
                    end
                else
                    local inserted = dest_inv.insert(stack_spec)
                    if inserted > 0 then
                        for i = 1, max_search do
                            if dest_inv[i].valid_for_read and dest_inv[i].name == primary_stack.name then
                                primary_holder_slot = i
                                if src_grid and src_grid.valid then
                                    item_transfer_handler.copy_equipment_grid(src_grid, dest_inv[i])
                                end
                                break
                            end
                        end
                    end
                end
            end
        elseif capsule_def.include_self or capsule_def.destroy_self then
            if primary_stack.count > 1 then
                primary_stack.count = primary_stack.count - 1
            else
                primary_stack.clear()
            end
        end
    end

    if capsule_def.destroy_holder_if_empty and dest_inv.is_empty() and not passenger then
        local pos = holder.position
        holder.destroy()
        liminal_surface_mgr.release_position(pos, allocated_is_wide)
        return
    end

    local capsule_id = capsule_manager.register(holder, capsule_name, primary_holder_slot, dominant_payload_item, has_spoilable_items, allocated_is_wide)
    if capsule_id then
        local success = capsule_runner.inject_from_hub(capsule_id, entity, passenger)
        if not success then
            capsule_manager.remove(capsule_id)
        end
    end
end

return hub_packing