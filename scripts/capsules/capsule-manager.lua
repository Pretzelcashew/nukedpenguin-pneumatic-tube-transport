local capsule_defs = require("scripts.capsules.capsule-definitions")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")
local item_transfer_handler = require("scripts.utils.item-transfer-handler")

local capsule_manager = {}

function capsule_manager.init()
    storage.active_capsules = storage.active_capsules or {}
end

--- Registers a newly created holder entity into the tracking system
--- @param holder_entity LuaEntity The liminal holder entity
--- @param capsule_item_name string Name of the capsule prototype
--- @param primary_slot number|nil Index of the slot containing the primary capsule item in holder inventory
--- @param dominant_item string|nil Name of the dominant payload item
--- @param dominant_quality string|nil Quality tier of the dominant payload item ("normal", "uncommon", etc.)
--- @param has_spoilable_items boolean|nil Whether any item in the capsule can spoil
--- @param is_wide boolean|nil Whether allocated in a wide 8-tile unit cell
--- @param is_stable boolean|nil Whether this capsule has immutable cargo and shell identity
function capsule_manager.register(holder_entity, capsule_item_name, primary_slot, dominant_item, dominant_quality, has_spoilable_items, is_wide, is_stable, virtual_cargo)
    if not (holder_entity and holder_entity.valid) then return nil end

    local def = capsule_defs.types[capsule_item_name]
    if not def then return nil end

    capsule_manager.init()
    local capsule_id = holder_entity.unit_number
    local pos = holder_entity.position

    if script.register_on_object_destroyed then
        local reg_id = script.register_on_object_destroyed(holder_entity)
        storage.object_destruction_map = storage.object_destruction_map or {}
        storage.object_destruction_map[reg_id] = { type = "capsule", id = capsule_id }
    end

    if is_stable == nil then
        is_stable = capsule_defs.is_stable_capsule(capsule_item_name, has_spoilable_items == true)
    end

    local signal_data = capsule_manager.extract_holder_signal_data(holder_entity, primary_slot, dominant_item or capsule_item_name, dominant_quality or "normal", virtual_cargo)

    storage.active_capsules[capsule_id] = {
        holder = holder_entity,
        type = def.type,
        capsule_type = capsule_item_name,
        definition = def,
        primary_slot = primary_slot,
        position = { x = pos.x, y = pos.y },
        dominant_item = dominant_item or capsule_item_name,
        dominant_quality = dominant_quality or "normal",
        has_spoilable_items = has_spoilable_items == true,
        is_wide = is_wide == true,
        is_stable = is_stable == true,
        signal_data = signal_data,
        virtual_cargo = virtual_cargo
    }

    return capsule_id
end

--- Retrieves the capsule tracking data
--- @param capsule_id number
--- @return table|nil
function capsule_manager.get(capsule_id)
    if not storage.active_capsules then return nil end
    return storage.active_capsules[capsule_id]
end

--- Retrieves the primary capsule item stack from the holder inventory, if present and valid
--- @param capsule_id number
--- @return LuaItemStack|nil stack
--- @return number|nil slot_index
function capsule_manager.get_primary_stack(capsule_id)
    local data = capsule_manager.get(capsule_id)
    if not (data and data.holder and data.holder.valid and data.primary_slot) then
        return nil, nil
    end
    local inv = data.holder.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid and data.primary_slot <= #inv) then
        return nil, nil
    end
    local stack = inv[data.primary_slot]
    if stack and stack.valid_for_read then
        return stack, data.primary_slot
    end
    return nil, data.primary_slot
end

--- Safely destroys the holder entity, releases its grid position, and removes it from the registry
--- @param capsule_id number
function capsule_manager.remove(capsule_id)
    if not storage.active_capsules then return end

    local data = storage.active_capsules[capsule_id]
    if data then
        local pos = data.position or (data.holder and data.holder.valid and data.holder.position)
        if data.holder and data.holder.valid then
            data.holder.destroy()
        end
        if pos then
            liminal_surface_mgr.release_position(pos, data.is_wide)
        end
        storage.active_capsules[capsule_id] = nil
    end
end
--- Checks whether a capsule ID corresponds to an electromagnetic capsule
--- @param capsule_id number
--- @return boolean
function capsule_manager.is_electromagnetic(capsule_id)
    if not (capsule_id and storage.active_capsules) then return false end
    local cap_data = storage.active_capsules[capsule_id]
    if not cap_data then return false end
    return cap_data.capsule_type == "electromagnetic-capsule"
        or (cap_data.definition and (cap_data.definition.is_electromagnetic == true or cap_data.definition.name == "electromagnetic-capsule"))
end

--- Extracts and memoizes immutable signal contribution for a stable capsule
--- @param holder_entity LuaEntity
--- @param primary_slot number|nil
--- @param fallback_name string|nil
--- @param fallback_quality string|nil
--- @param virtual_cargo table|nil
--- @return table signal_data
function capsule_manager.extract_holder_signal_data(holder_entity, primary_slot, fallback_name, fallback_quality, virtual_cargo)
    local v_name = fallback_name or "item-capsule"
    local v_qual = fallback_quality or "normal"
    local cargo_list = {}
    local cargo_map = {}

    if holder_entity and holder_entity.valid then
        local inv = holder_entity.get_inventory(defines.inventory.chest)
        if inv and inv.valid and not inv.is_empty() then
            local prim_idx = primary_slot or 1
            if prim_idx <= #inv then
                local p_stack = inv[prim_idx]
                if p_stack and p_stack.valid_for_read then
                    v_name = p_stack.name
                    v_qual = (p_stack.quality and p_stack.quality.name) or "normal"
                end
            end

            do
                for slot_idx = 1, #inv do
                    if slot_idx ~= prim_idx then
                        local stack = inv[slot_idx]
                        if stack and stack.valid_for_read and stack.count > 0 then
                        local q_name = (stack.quality and stack.quality.name) or "normal"
                        local key = stack.name .. "@" .. q_name
                        local entry = cargo_map[key]
                        if not entry then
                            entry = {
                                name = stack.name,
                                quality = q_name,
                                count = 0
                            }
                            cargo_map[key] = entry
                            table.insert(cargo_list, entry)
                        end
                        entry.count = entry.count + stack.count
                        end
                    end
                end
            end
        end
    end

    if virtual_cargo then
        for _, item in ipairs(virtual_cargo) do
            if item.count and item.count > 0 then
                local q_name = (type(item.quality) == "string" and item.quality) or (item.quality and item.quality.name) or "normal"
                local key = item.name .. "@" .. q_name
                local entry = cargo_map[key]
                if not entry then
                    entry = {
                        name = item.name,
                        quality = q_name,
                        count = 0
                    }
                    cargo_map[key] = entry
                    table.insert(cargo_list, entry)
                end
                entry.count = entry.count + item.count
            end
        end
    end

    return {
        vessel = {
            name = v_name,
            quality = v_qual,
            count = 1
        },
        cargo = cargo_list
    }
end

--- Retrieves the signal data for a capsule, lazily extracting and caching it if the capsule is stable
--- @param capsule_id number
--- @return table|nil signal_data
--- @return boolean is_stable
function capsule_manager.get_signal_data(capsule_id)
    if not (capsule_id and storage.active_capsules) then return nil, false end
    local cap_data = storage.active_capsules[capsule_id]
    if not cap_data then return nil, false end

    local is_stable = cap_data.is_stable
    if is_stable == nil then
        is_stable = capsule_defs.is_stable_capsule(cap_data.capsule_type, cap_data.has_spoilable_items)
        cap_data.is_stable = is_stable
    end

    if not cap_data.signal_data then
        cap_data.signal_data = capsule_manager.extract_holder_signal_data(
            cap_data.holder,
            cap_data.primary_slot,
            cap_data.capsule_type,
            cap_data.dominant_quality,
            cap_data.virtual_cargo
        )
    end
    return cap_data.signal_data, is_stable
end

--- Collapses virtual cargo waveform, applying time dilation to date and returning the finalized stack specs
--- @param phys_capsule table
--- @param current_tick number
--- @param capsule_id number|nil
--- @return table|nil virtual_cargo
function capsule_manager.collapse_virtual_cargo(phys_capsule, current_tick, capsule_id)
    if not (phys_capsule and phys_capsule.virtual_cargo) then return nil end
    local ref = phys_capsule.refrigeration
    local last_tick = (ref and (ref.last_update_tick or ref.pack_tick)) or current_tick
    local elapsed_ticks = math.max(0, current_tick - last_tick)

    local holder = phys_capsule.holder
    local inv = holder and holder.valid and holder.get_inventory(defines.inventory.chest)
    local p_slot = phys_capsule.primary_slot or 1
    local p_stack = (inv and inv.valid and p_slot <= #inv) and inv[p_slot]

    local caps_def = (p_stack and p_stack.valid_for_read) and capsule_defs.types[p_stack.name] or phys_capsule.definition
    local modifier = (caps_def and caps_def.spoilage_modifier) or 1.0
    local max_charges = (caps_def and p_stack and p_stack.valid_for_read) and capsule_defs.get_max_charges(caps_def, p_stack.quality) or 600
    local cur_health = (p_stack and p_stack.valid_for_read and p_stack.health) or 1.0
    local cur_charges = math.floor((cur_health * max_charges) + 0.5)

    local coolant_ticks = (modifier < 1.0) and (cur_charges * 60) or 0
    local cooled_ticks = 0
    local uncooled_ticks = 0
    local ran_out = false

    if elapsed_ticks > 0 then
        if coolant_ticks >= elapsed_ticks then
            cooled_ticks = elapsed_ticks
            uncooled_ticks = 0
            local charges_used = math.max(1, math.floor((elapsed_ticks + 30) / 60))
            local new_charges = math.max(0, cur_charges - charges_used)
            if new_charges <= 0 then
                ran_out = true
            elseif p_stack and p_stack.valid_for_read then
                p_stack.health = math.max(0.01, new_charges / max_charges)
            end
        else
            cooled_ticks = coolant_ticks
            uncooled_ticks = elapsed_ticks - coolant_ticks
            ran_out = (modifier < 1.0)
        end

        if ran_out and p_stack and p_stack.valid_for_read then
            local spent_item_name = caps_def.spent_capsule_item or "spent-refrigerated-capsule"
            local quality = p_stack.quality
            local src_grid = p_stack.grid
            inv[p_slot].clear()
            inv[p_slot].set_stack({
                name = spent_item_name,
                count = 1,
                quality = quality
            })
            if src_grid and src_grid.valid and inv[p_slot].valid_for_read then
                item_transfer_handler.copy_equipment_grid(src_grid, inv[p_slot])
            end
            phys_capsule.capsule_type = spent_item_name
            phys_capsule.definition = capsule_defs.types[spent_item_name] or phys_capsule.definition
        end

        for _, item in ipairs(phys_capsule.virtual_cargo) do
            if item.count and item.count > 0 and item.base_spoil_ticks and item.base_spoil_ticks > 0 then
                local spoil_delta = ((cooled_ticks * modifier) + (uncooled_ticks * 1.0)) / item.base_spoil_ticks
                local new_spoil = math.min(1.0, (item.spoil_percent or 0) + spoil_delta)
                item.spoil_percent = new_spoil

                if new_spoil >= 1.0 then
                    if item.is_unit then
                        item.count = 0
                    else
                        item.name = item.spoil_result or "spoilage"
                        local s_proto = prototypes.item[item.name]
                        item.base_spoil_ticks = (s_proto and s_proto.get_spoil_ticks and s_proto.get_spoil_ticks()) or 0
                        item.spoil_percent = 0
                        item.is_unit = false
                    end
                end
            end
        end

        if ref then
            ref.last_update_tick = current_tick
        end

        local max_c = 0
        local dom_c = nil
        local dom_q = "normal"
        for _, it in ipairs(phys_capsule.virtual_cargo) do
            if it.count and it.count > max_c then
                max_c = it.count
                dom_c = it.name
                dom_q = (type(it.quality) == "string" and it.quality) or (it.quality and it.quality.name) or "normal"
            end
        end
        if dom_c then
            phys_capsule.dominant_item = dom_c
            phys_capsule.dominant_quality = dom_q
            if storage.capsules and capsule_id and storage.capsules[capsule_id] then
                storage.capsules[capsule_id].dominant_item = dom_c
                storage.capsules[capsule_id].dominant_quality = dom_q
            end
        end
    end

    return phys_capsule.virtual_cargo
end

--- Checks whether a capsule ID corresponds to a stable capsule
--- @param capsule_id number
--- @return boolean
function capsule_manager.is_stable(capsule_id)
    if not (capsule_id and storage.active_capsules) then return false end
    local cap_data = storage.active_capsules[capsule_id]
    if not cap_data then return false end
    if cap_data.is_stable ~= nil then
        return cap_data.is_stable
    end
    local stable = capsule_defs.is_stable_capsule(cap_data.capsule_type, cap_data.has_spoilable_items)
    cap_data.is_stable = stable
    return stable
end

return capsule_manager
