local item_transfer_handler = {}

--- Copies equipment grid contents from a source item stack (or grid object) to a destination item stack
--- @param src_stack_or_grid LuaItemStack|LuaEquipmentGrid
--- @param dest_stack LuaItemStack
function item_transfer_handler.copy_equipment_grid(src_stack_or_grid, dest_stack)
    if not (src_stack_or_grid and dest_stack and dest_stack.valid_for_read) then return end

    local src_grid = nil
    if src_stack_or_grid.object_name == "LuaEquipmentGrid" then
        src_grid = src_stack_or_grid
    elseif src_stack_or_grid.grid and src_stack_or_grid.grid.valid then
        src_grid = src_stack_or_grid.grid
    end

    if not (src_grid and src_grid.valid) then return end

    local equipment_list = src_grid.equipment
    if not (equipment_list and #equipment_list > 0) then return end

    local dest_grid = dest_stack.grid or dest_stack.create_grid()
    if not (dest_grid and dest_grid.valid) then return end

    for _, eq in ipairs(equipment_list) do
        if eq and eq.valid then
            local placed = dest_grid.put{
                name = eq.name,
                position = eq.position,
                quality = eq.quality
            }
            if placed and placed.valid then
                if eq.energy then placed.energy = eq.energy end
                if eq.shield and eq.shield > 0 then placed.shield = eq.shield end
            end
        end
    end
end

--- Builds a complete SimpleItemStack specification table preserving all vanilla Factorio 2.0 metadata
--- @param stack LuaItemStack
--- @param count number|nil Optional explicit stack count
--- @return table SimpleItemStack spec
function item_transfer_handler.build_stack_spec(stack, count)
    local spec = {
        name = stack.name,
        count = count or stack.count,
        quality = stack.quality
    }
    if stack.health and stack.health < 1.0 then
        spec.health = stack.health
    end
    if stack.spoil_percent and stack.spoil_percent > 0 then
        spec.spoil_percent = stack.spoil_percent
    end
    if stack.is_tool and stack.durability then
        spec.durability = stack.durability
    end
    if stack.is_ammo and stack.ammo then
        spec.ammo = stack.ammo
    end
    if stack.is_item_with_tags then
        spec.tags = stack.tags
        spec.custom_description = stack.custom_description
    end
    return spec
end

--- Transfers items from a source stack to a target inventory slot-by-slot preserving metadata & equipment grid
--- @param src_stack LuaItemStack
--- @param dest_inv LuaInventory
--- @param max_dest_slot number|nil Maximum destination inventory slot to search
--- @param amount number|nil Optional explicit transfer count
--- @return boolean transferred
function item_transfer_handler.transfer_stack(src_stack, dest_inv, max_dest_slot, amount)
    if not (src_stack and src_stack.valid_for_read and dest_inv and dest_inv.valid) then return false end

    local count_to_transfer = amount or src_stack.count
    if count_to_transfer <= 0 then return false end

    local max_slot = max_dest_slot
    if not max_slot then
        max_slot = #dest_inv
        if dest_inv.supports_bar() then
            local bar = dest_inv.get_bar()
            if bar then
                max_slot = math.min(#dest_inv, bar - 1)
            end
        end
    end

    if max_slot <= 0 then return false end

    local item_name = src_stack.name
    local item_quality = src_stack.quality
    local src_grid = src_stack.grid
    local original_count = src_stack.count

    -- Attempt native C++ transfer_stack into matching or empty slots
    for j = 1, max_slot do
        local dest_slot = dest_inv[j]
        if dest_slot and dest_slot.valid then
            if not dest_slot.valid_for_read or (dest_slot.name == item_name and dest_slot.quality == item_quality) then
                if dest_slot.transfer_stack(src_stack, count_to_transfer) then
                    return true
                end
            end
        end
    end

    -- Fallback: Use build_stack_spec and insert / set_stack + equipment grid copy
    if src_stack.valid_for_read then
        local stack_spec = item_transfer_handler.build_stack_spec(src_stack, count_to_transfer)
        local inserted = dest_inv.insert(stack_spec)
        if inserted >= original_count then
            src_stack.clear()
        else
            src_stack.count = original_count - inserted
        end

        if inserted > 0 and src_grid and src_grid.valid then
            for j = 1, max_slot do
                if dest_inv[j].valid_for_read and dest_inv[j].name == item_name then
                    item_transfer_handler.copy_equipment_grid(src_grid, dest_inv[j])
                    break
                end
            end
        end

        return inserted > 0
    end

    return false
end

--- Transfers all stacks from a source inventory into a target inventory preserving metadata and equipment grids
--- @param src_inv LuaInventory
--- @param dest_inv LuaInventory
--- @param max_src_slot number|nil
--- @param max_dest_slot number|nil
function item_transfer_handler.transfer_inventory(src_inv, dest_inv, max_src_slot, max_dest_slot)
    if not (src_inv and src_inv.valid and dest_inv and dest_inv.valid) then return false end

    local src_max = max_src_slot or ((src_inv.supports_bar() and math.min(#src_inv, src_inv.get_bar() - 1)) or #src_inv)
    local dest_max = max_dest_slot or ((dest_inv.supports_bar() and math.min(#dest_inv, dest_inv.get_bar() - 1)) or #dest_inv)

    for i = 1, src_max do
        local stack = src_inv[i]
        if stack and stack.valid_for_read then
            item_transfer_handler.transfer_stack(stack, dest_inv, dest_max)
        end
    end
end

--- Spills an item stack onto a surface position preserving Factorio 2.0 metadata and marking for deconstruction if requested
--- @param surface LuaSurface
--- @param position MapPosition
--- @param stack LuaItemStack|table
--- @param mark_decon boolean|nil
--- @param force LuaForce|string|nil
function item_transfer_handler.spill_stack(surface, position, stack, mark_decon, force)
    if not (surface and surface.valid and position) then return end

    local stack_to_spill = stack
    if stack and stack.object_name == "LuaItemStack" and stack.valid_for_read then
        stack_to_spill = item_transfer_handler.build_stack_spec(stack)
    end

    local spilled_entities = surface.spill_item_stack{
        position = position,
        stack = stack_to_spill,
        enable_looted = mark_decon,
        force = force
    }

    if mark_decon and force and spilled_entities then
        for _, item_entity in ipairs(spilled_entities) do
            if item_entity and item_entity.valid then
                item_entity.order_deconstruction(force)
            end
        end
    end
end

return item_transfer_handler