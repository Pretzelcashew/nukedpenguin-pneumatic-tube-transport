local capsule_defs = require("scripts.capsules.capsule-definitions")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")

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
function capsule_manager.register(holder_entity, capsule_item_name, primary_slot, dominant_item, dominant_quality, has_spoilable_items, is_wide, is_stable)
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

    local signal_data = nil
    if is_stable then
        signal_data = capsule_manager.extract_holder_signal_data(holder_entity, primary_slot, dominant_item or capsule_item_name, dominant_quality or "normal")
    end

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
        signal_data = signal_data
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
--- @return table signal_data
function capsule_manager.extract_holder_signal_data(holder_entity, primary_slot, fallback_name, fallback_quality)
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

    if is_stable then
        if not cap_data.signal_data then
            cap_data.signal_data = capsule_manager.extract_holder_signal_data(
                cap_data.holder,
                cap_data.primary_slot,
                cap_data.capsule_type,
                cap_data.dominant_quality
            )
        end
        return cap_data.signal_data, true
    end

    return nil, false
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
