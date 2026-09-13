local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local capsule_queries = require("scripts.capsules.capsule-queries")
local hub_spill = require("scripts.hubs.hub-spill")
local item_transfer_handler = require("scripts.utils.item-transfer-handler")
local counter_range = require("scripts.counters.counter-range")
local binary_heap = require("scripts.utils.binary-heap")

local capsule_lifecycle = {}

local function get_spoil_heap()
    if not storage.spoil_heap then
        storage.spoil_heap = binary_heap.new()
        if storage.active_capsules then
            for cid, cap_data in pairs(storage.active_capsules) do
                if cap_data.virtual_cargo or cap_data.has_spoilable_items then
                    local tick = cap_data.next_spoil_tick
                    if tick then
                        storage.spoil_heap:push(cid, tick)
                    end
                end
            end
        end
    else
        binary_heap.attach(storage.spoil_heap)
    end
    return storage.spoil_heap
end
capsule_lifecycle.get_spoil_heap = get_spoil_heap

--- Finds the earliest spoil tick across all spoilable cargo stacks in the holder inventory
--- @param inv LuaInventory
--- @param max_slot number
--- @param primary_slot number|nil
--- @param current_tick number
--- @return number|nil min_spoil_tick
--- @return boolean has_spoilable
function capsule_lifecycle.find_earliest_spoil_tick(inv, max_slot, primary_slot, current_tick)
    local min_spoil_tick = nil
    local has_spoilable = false

    for i = 1, max_slot do
        if i ~= primary_slot then
            local stack = inv[i]
            if stack and stack.valid_for_read and capsule_defs.is_stack_spoilable(stack) then
                has_spoilable = true
                local s_tick = stack.spoil_tick
                if not (s_tick and s_tick > 0) then
                    local proto = stack.prototype
                    local base_ticks = proto and proto.get_spoil_ticks and proto.get_spoil_ticks()
                    if base_ticks and base_ticks > 0 then
                        local cur_pct = stack.spoil_percent or 0
                        s_tick = current_tick + math.max(1, math.floor((1.0 - cur_pct) * base_ticks))
                    end
                end
                if s_tick and s_tick > 0 then
                    if not min_spoil_tick or s_tick < min_spoil_tick then
                        min_spoil_tick = s_tick
                    end
                end
            end
        end
    end

    if min_spoil_tick and min_spoil_tick < current_tick then
        min_spoil_tick = current_tick
    end

    return min_spoil_tick, has_spoilable
end

--- Calculates the next recheck tick bounded by the earlier of cargo spoilage or coolant depletion horizon
--- @param phys_capsule table
--- @param inv LuaInventory
--- @param max_slot number
--- @param primary_slot number|nil
--- @param min_spoil_tick number|nil
--- @param current_tick number
--- @return number|nil
local function calculate_next_recheck_tick(phys_capsule, inv, max_slot, primary_slot, min_spoil_tick, current_tick)
    local def = phys_capsule.definition
    local is_refrig = def and (def.spoilage_modifier or 1.0) < 1.0
    if not is_refrig then
        return min_spoil_tick
    end

    local coolant_ticks = 0
    if primary_slot and primary_slot <= max_slot then
        local p_stack = inv[primary_slot]
        if p_stack and p_stack.valid_for_read then
            local caps_def = capsule_defs.types[p_stack.name]
            if caps_def and caps_def.spoilage_modifier and caps_def.spoilage_modifier < 1.0 then
                local max_charges = capsule_defs.get_max_charges(caps_def, p_stack.quality)
                local cur_health = p_stack.health or 1.0
                local cur_charges = math.floor((cur_health * max_charges) + 0.5)
                coolant_ticks = cur_charges * 60
            end
        end
    end

    if coolant_ticks <= 0 then
        return min_spoil_tick
    end

    local coolant_horizon = current_tick + coolant_ticks
    local earliest = min_spoil_tick and (min_spoil_tick - 1) or coolant_horizon
    local next_tick = math.min(coolant_horizon, earliest)
    return math.max(current_tick + 1, next_tick)
end

--- Initializes dynamic cargo tracking and calculates the next scheduled spoil recheck tick
--- @param phys_capsule table Active capsule tracking data
--- @param current_tick number
function capsule_lifecycle.schedule_dynamic_cargo(phys_capsule, current_tick)
    if not phys_capsule then return nil end
    local v_next = nil
    if phys_capsule.virtual_cargo then
        v_next = capsule_lifecycle.calculate_virtual_dilated_recheck(phys_capsule, current_tick)
        phys_capsule.virtual_next_spoil_tick = v_next
    end

    local p_next = nil
    local inv = phys_capsule.holder and phys_capsule.holder.valid and phys_capsule.holder.get_inventory(defines.inventory.chest)
    if inv and inv.valid and not inv.is_empty() then
        local max_slot = #inv
        if inv.supports_bar() then
            local bar = inv.get_bar()
            if bar then max_slot = math.min(#inv, bar - 1) end
        end
        local primary_slot = phys_capsule.primary_slot or 1
        local min_spoil_tick, has_spoilable = capsule_lifecycle.find_earliest_spoil_tick(inv, max_slot, primary_slot, current_tick)
        if has_spoilable then
            phys_capsule.has_spoilable_items = true
            phys_capsule.last_spoil_check_tick = current_tick
            p_next = calculate_next_recheck_tick(phys_capsule, inv, max_slot, primary_slot, min_spoil_tick, current_tick)
            phys_capsule.physical_next_spoil_tick = p_next
        else
            phys_capsule.physical_next_spoil_tick = nil
        end
    end

    local next_tick = (v_next and p_next) and math.min(v_next, p_next) or (v_next or p_next)
    phys_capsule.next_spoil_tick = next_tick

    if not next_tick and not (phys_capsule.definition and phys_capsule.definition.is_player_transit) then
        phys_capsule.has_spoilable_items = false
        phys_capsule.is_stable = true
    end

    local cap_id = phys_capsule.capsule_id or (phys_capsule.holder and phys_capsule.holder.valid and phys_capsule.holder.unit_number)
    if cap_id then
        local heap = get_spoil_heap()
        if next_tick then
            heap:push(cap_id, next_tick)
        else
            heap:remove(cap_id)
        end
    end

    return next_tick
end

function capsule_lifecycle.init_dynamic_cargo(phys_capsule, current_tick)
    return capsule_lifecycle.schedule_dynamic_cargo(phys_capsule, current_tick)
end

function capsule_lifecycle._legacy_init_dynamic_cargo(phys_capsule, current_tick)
    if not (phys_capsule and phys_capsule.holder and phys_capsule.holder.valid) then return end
    local inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid and not inv.is_empty()) then return end

    local max_slot = #inv
    if inv.supports_bar() then
        local bar = inv.get_bar()
        if bar then max_slot = math.min(#inv, bar - 1) end
    end
    local primary_slot = phys_capsule.primary_slot or 1

    phys_capsule.slot_spoil_percents = phys_capsule.slot_spoil_percents or {}
    for i = 1, max_slot do
        if i ~= primary_slot then
            local stack = inv[i]
            if stack and stack.valid_for_read and capsule_defs.is_stack_spoilable(stack) then
                phys_capsule.slot_spoil_percents[i] = stack.spoil_percent
            else
                phys_capsule.slot_spoil_percents[i] = nil
            end
        end
    end

    local min_spoil_tick, has_spoilable = capsule_lifecycle.find_earliest_spoil_tick(inv, max_slot, primary_slot, current_tick)
    if not has_spoilable then
        phys_capsule.has_spoilable_items = false
        local def = phys_capsule.definition
        if not (def and def.is_player_transit) then
            phys_capsule.is_stable = true
        end
        phys_capsule.next_spoil_tick = nil
        return
    end

    phys_capsule.last_spoil_check_tick = current_tick
    phys_capsule.next_spoil_tick = calculate_next_recheck_tick(phys_capsule, inv, max_slot, primary_slot, min_spoil_tick, current_tick)
end

--- Intercepts spoilable cargo before it spoils to apply refrigeration modifier and deduct cooling charges
--- @param phys_capsule table Active capsule tracking data
--- @param current_tick number
function capsule_lifecycle.intercept_refrigeration(phys_capsule, current_tick)
    if not (phys_capsule and phys_capsule.holder and phys_capsule.holder.valid) then return end
    local def = phys_capsule.definition
    local modifier = def and def.spoilage_modifier or 1.0
    if modifier >= 1.0 then return end

    local inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid and not inv.is_empty()) then return end

    local last_tick = phys_capsule.last_spoil_check_tick or current_tick
    local elapsed_ticks = math.max(0, current_tick - last_tick)
    if elapsed_ticks == 0 then return end

    local max_slot = #inv
    if inv.supports_bar() then
        local bar = inv.get_bar()
        if bar then max_slot = math.min(#inv, bar - 1) end
    end

    local p_slot = phys_capsule.primary_slot or 1
    local p_stack = (p_slot <= max_slot) and inv[p_slot]
    if not (p_stack and p_stack.valid_for_read) then return end

    local caps_def = capsule_defs.types[p_stack.name]
    if not (caps_def and caps_def.spoilage_modifier and caps_def.spoilage_modifier < 1.0) then return end

    local max_charges = capsule_defs.get_max_charges(caps_def, p_stack.quality)
    local cur_health = p_stack.health or 1.0
    local cur_charges = math.floor((cur_health * max_charges) + 0.5)

    -- 1 charge per 60 ticks (1 second) of active cooling
    local charges_needed = math.max(1, math.floor((elapsed_ticks + 30) / 60))
    local effective_modifier = modifier
    local ran_out = false

    if cur_charges >= charges_needed then
        local new_charges = cur_charges - charges_needed
        if new_charges <= 0 then
            ran_out = true
        else
            p_stack.health = math.max(0.0001, new_charges / max_charges)
        end
    else
        local cooled_ticks = cur_charges * 60
        local uncooled_ticks = math.max(0, elapsed_ticks - cooled_ticks)
        effective_modifier = (cooled_ticks * modifier + uncooled_ticks * 1.0) / elapsed_ticks
        ran_out = true
    end

    phys_capsule.slot_spoil_percents = phys_capsule.slot_spoil_percents or {}

    for i = 1, max_slot do
        if i ~= p_slot then
            local stack = inv[i]
            if stack and stack.valid_for_read and capsule_defs.is_stack_spoilable(stack) then
                local cur_spoil = stack.spoil_percent
                local last_spoil = phys_capsule.slot_spoil_percents[i] or 0
                if cur_spoil > last_spoil then
                    local raw_delta = cur_spoil - last_spoil
                    local target_spoil = math.max(0.0, math.min(0.999, last_spoil + (raw_delta * effective_modifier)))

                    local set_ok = pcall(function() stack.spoil_percent = target_spoil end)
                    if not set_ok or stack.spoil_percent ~= target_spoil then
                        local src_grid = stack.grid
                        local stack_spec = item_transfer_handler.build_stack_spec(stack)
                        stack_spec.spoil_percent = target_spoil
                        inv[i].clear()
                        inv[i].set_stack(stack_spec)
                        if src_grid and src_grid.valid and inv[i].valid_for_read then
                            item_transfer_handler.copy_equipment_grid(src_grid, inv[i])
                        end
                    end
                    phys_capsule.slot_spoil_percents[i] = target_spoil
                else
                    phys_capsule.slot_spoil_percents[i] = cur_spoil
                end
            else
                phys_capsule.slot_spoil_percents[i] = nil
            end
        end
    end

    if ran_out then
        local spent_item_name = caps_def.spent_capsule_item or "spent-refrigerated-capsule"
        local qual_name = (type(p_stack.quality) == "string" and p_stack.quality) or (p_stack.quality and p_stack.quality.name) or "normal"
        local src_grid = p_stack.grid
        inv[p_slot].clear()
        inv[p_slot].set_stack({
            name = spent_item_name,
            count = 1,
            quality = qual_name
        })
        if src_grid and src_grid.valid and inv[p_slot].valid_for_read then
            item_transfer_handler.copy_equipment_grid(src_grid, inv[p_slot])
        end
        phys_capsule.capsule_type = spent_item_name
        phys_capsule.definition = capsule_defs.types[spent_item_name] or phys_capsule.definition
    end

    phys_capsule.last_spoil_check_tick = current_tick
end

--- Processes scheduled dynamic cargo recheck, updating refrigerated state, cargo signals, and next recheck tick
--- @param capsule table Motion record
--- @param phys_capsule table Active capsule tracking data
--- @param current_tick number
function capsule_lifecycle.process_dynamic_cargo(capsule, phys_capsule, current_tick)
    if not (phys_capsule and phys_capsule.holder and phys_capsule.holder.valid) then return end

    local def = phys_capsule.definition
    if def and (def.spoilage_modifier or 1.0) < 1.0 then
        capsule_lifecycle.intercept_refrigeration(phys_capsule, current_tick)
    end

    local inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
    if not (inv and inv.valid and not inv.is_empty()) then return end

    local max_slot = #inv
    if inv.supports_bar() then
        local bar = inv.get_bar()
        if bar then max_slot = math.min(#inv, bar - 1) end
    end
    local primary_slot = phys_capsule.primary_slot or 1

    local cap_id = capsule and (capsule.capsule_id or capsule.id) or (phys_capsule.holder and phys_capsule.holder.unit_number)

    local max_cargo_c = 0
    local dom_cargo_item = nil
    local dom_cargo_qual = "normal"
    for s_idx = 1, max_slot do
        if s_idx ~= primary_slot then
            local stk = inv[s_idx]
            if stk and stk.valid_for_read and stk.count > max_cargo_c then
                max_cargo_c = stk.count
                dom_cargo_item = stk.name
                dom_cargo_qual = (stk.quality and stk.quality.name) or "normal"
            end
        end
    end
    if dom_cargo_item then
        phys_capsule.dominant_item = dom_cargo_item
        phys_capsule.dominant_quality = dom_cargo_qual
        if capsule then
            capsule.dominant_item = dom_cargo_item
            capsule.dominant_quality = dom_cargo_qual
            if capsule.render_cache and capsule.render_cache.dominant_item ~= dom_cargo_item then
                capsule.render_cache.dominant_item = nil
            end
        end
    end

    local old_sig_data = phys_capsule.signal_data
    local new_sig_data = capsule_manager.extract_holder_signal_data(
        phys_capsule.holder,
        phys_capsule.primary_slot,
        phys_capsule.dominant_item or phys_capsule.capsule_type,
        phys_capsule.dominant_quality or "normal",
        phys_capsule.virtual_cargo
    )
    phys_capsule.signal_data = new_sig_data

    if old_sig_data and counter_range.update_capsule_signals then
        counter_range.update_capsule_signals(cap_id, old_sig_data, new_sig_data)
    end

    local min_spoil_tick, has_spoilable = capsule_lifecycle.find_earliest_spoil_tick(inv, max_slot, primary_slot, current_tick)
    if not has_spoilable then
        phys_capsule.physical_next_spoil_tick = nil
        if not phys_capsule.virtual_cargo then
            phys_capsule.has_spoilable_items = false
            local cur_def = phys_capsule.definition
            if not (cur_def and cur_def.is_player_transit) then
                phys_capsule.is_stable = true
            end
        end
    else
        phys_capsule.last_spoil_check_tick = current_tick
        phys_capsule.physical_next_spoil_tick = calculate_next_recheck_tick(phys_capsule, inv, max_slot, primary_slot, min_spoil_tick, current_tick)
        local next_tick = phys_capsule.physical_next_spoil_tick
        phys_capsule.next_spoil_tick = next_tick
        if capsule then capsule.next_spoil_tick = next_tick end
    end
end

--- Calculates the next true dilated recheck tick for virtual cargo
--- @param phys_capsule table
--- @param current_tick number
--- @return number|nil
function capsule_lifecycle.calculate_virtual_dilated_recheck(phys_capsule, current_tick)
    if not (phys_capsule and phys_capsule.virtual_cargo) then return nil end

    local has_spoilable = false
    for _, item in ipairs(phys_capsule.virtual_cargo) do
        if item.count and item.count > 0 and item.base_spoil_ticks and item.base_spoil_ticks > 0 then
            has_spoilable = true
            break
        end
    end
    if not has_spoilable then return nil end

    local holder = phys_capsule.holder
    local inv = holder and holder.valid and holder.get_inventory(defines.inventory.chest)
    local p_slot = phys_capsule.primary_slot or 1
    local p_stack = (inv and inv.valid and p_slot <= #inv) and inv[p_slot]

    local caps_def = (p_stack and p_stack.valid_for_read) and capsule_defs.types[p_stack.name] or phys_capsule.definition
    local modifier = (caps_def and caps_def.spoilage_modifier) or 1.0
    local cur_health = (p_stack and p_stack.valid_for_read and p_stack.health) or 1.0
    local max_charges = (caps_def and p_stack and p_stack.valid_for_read) and capsule_defs.get_max_charges(caps_def, p_stack.quality) or 600
    local cur_charges = math.floor((cur_health * max_charges) + 0.5)

    local coolant_ticks = (modifier < 1.0) and (cur_charges * 60) or 0
    local coolant_horizon = (coolant_ticks > 0) and (current_tick + coolant_ticks) or nil

    local effective_mod = (coolant_ticks > 0) and modifier or 1.0
    local min_spoil_ticks = nil

    for _, item in ipairs(phys_capsule.virtual_cargo) do
        if item.count and item.count > 0 and item.base_spoil_ticks and item.base_spoil_ticks > 0 then
            local remaining_pct = math.max(0, 1.0 - (item.spoil_percent or 0))
            local ticks_to_spoil = math.ceil((remaining_pct * item.base_spoil_ticks) / effective_mod)
            if not min_spoil_ticks or ticks_to_spoil < min_spoil_ticks then
                min_spoil_ticks = ticks_to_spoil
            end
        end
    end

    local spoil_horizon = min_spoil_ticks and (current_tick + math.max(1, min_spoil_ticks)) or nil

    if coolant_horizon and spoil_horizon then
        return math.min(coolant_horizon, spoil_horizon)
    elseif spoil_horizon then
        return spoil_horizon
    end

    return nil
end

--- Updates virtual cargo spoilage under time dilation and manages cooling charge deductions
--- @param phys_capsule table
--- @param current_tick number
--- @param capsule_id number|nil
local function resolve_spoil_trigger_info(item_name)
    local proto = prototypes.item[item_name]
    if not proto then return nil, 1 end

    local spoil_trig = proto.spoil_to_trigger_result
    local items_per_trigger = (spoil_trig and spoil_trig.items_per_trigger) or 1
    local entity_name = nil

    if spoil_trig and spoil_trig.trigger then
        local function scan_effects(effects)
            if not effects then return nil end
            for _, eff in ipairs(effects) do
                if eff.type == "create-entity" and eff.entity_name then
                    return eff.entity_name
                end
            end
            return nil
        end

        local function scan_trigger(trig)
            if not trig then return nil end
            if trig.action_delivery then
                local ad = trig.action_delivery
                if ad.source_effects then
                    local ent = scan_effects(ad.source_effects)
                    if ent then return ent end
                end
                if ad.target_effects then
                    local ent = scan_effects(ad.target_effects)
                    if ent then return ent end
                end
            end
            if type(trig) == "table" then
                for _, sub in ipairs(trig) do
                    local ent = scan_trigger(sub)
                    if ent then return ent end
                end
            end
            return nil
        end

        entity_name = scan_trigger(spoil_trig.trigger)
    end

    if not entity_name then
        if item_name == "biter-egg" then
            entity_name = "big-biter"
            items_per_trigger = 25
        elseif item_name == "pentapod-egg" then
            entity_name = "big-wriggler-pentapod-premature"
            items_per_trigger = 1
        elseif item_name == "captive-biter-spawner" then
            entity_name = "behemoth-biter"
            items_per_trigger = 1
        end
    end

    if entity_name and not prototypes.entity[entity_name] then
        if item_name == "pentapod-egg" and prototypes.entity["small-wriggler-pentapod-premature"] then
            entity_name = "small-wriggler-pentapod-premature"
        elseif prototypes.entity["big-biter"] then
            entity_name = "big-biter"
        elseif prototypes.entity["small-biter"] then
            entity_name = "small-biter"
        else
            entity_name = nil
        end
    end

    return entity_name, items_per_trigger
end

function capsule_lifecycle.update_virtual_refrigeration(phys_capsule, current_tick, capsule_id, curr_pos, surface, capsule)
    if not (phys_capsule and phys_capsule.virtual_cargo) then return end
    phys_capsule.refrigeration = phys_capsule.refrigeration or { pack_tick = current_tick, last_update_tick = current_tick }
    local ref = phys_capsule.refrigeration

    local last_tick = ref.last_update_tick or ref.pack_tick or current_tick
    local elapsed_ticks = math.max(0, current_tick - last_tick)
    if elapsed_ticks == 0 then return end

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

    if coolant_ticks >= elapsed_ticks then
        cooled_ticks = elapsed_ticks
        uncooled_ticks = 0
        local charges_used = math.max(1, math.floor((elapsed_ticks + 30) / 60))
        local new_charges = math.max(0, cur_charges - charges_used)
        if new_charges <= 0 then
            ran_out = true
        elseif p_stack and p_stack.valid_for_read then
            p_stack.health = math.max(0.0001, new_charges / max_charges)
        end
    else
        cooled_ticks = coolant_ticks
        uncooled_ticks = elapsed_ticks - coolant_ticks
        ran_out = (modifier < 1.0)
    end

    if ran_out and p_stack and p_stack.valid_for_read then
        local spent_item_name = caps_def.spent_capsule_item or "spent-refrigerated-capsule"
        local qual_name = (type(p_stack.quality) == "string" and p_stack.quality) or (p_stack.quality and p_stack.quality.name) or "normal"
        local src_grid = p_stack.grid
        inv[p_slot].clear()
        inv[p_slot].set_stack({
            name = spent_item_name,
            count = 1,
            quality = qual_name
        })
        if src_grid and src_grid.valid and inv[p_slot].valid_for_read then
            item_transfer_handler.copy_equipment_grid(src_grid, inv[p_slot])
        end
        phys_capsule.capsule_type = spent_item_name
        phys_capsule.definition = capsule_defs.types[spent_item_name] or phys_capsule.definition
        if storage.capsules and capsule_id and storage.capsules[capsule_id] then
            storage.capsules[capsule_id].capsule_type = spent_item_name
            if storage.capsules[capsule_id].render_cache then
                storage.capsules[capsule_id].render_cache.variant_color = nil
            end
        end
    end

    local any_spoiled = false
    for _, item in ipairs(phys_capsule.virtual_cargo) do
        if item.count and item.count > 0 and item.base_spoil_ticks and item.base_spoil_ticks > 0 then
            local spoil_delta = ((cooled_ticks * modifier) + (uncooled_ticks * 1.0)) / item.base_spoil_ticks
            local new_spoil = math.min(1.0, (item.spoil_percent or 0) + spoil_delta)
            item.spoil_percent = new_spoil

            if new_spoil >= 1.0 then
                any_spoiled = true
                if item.is_unit then
                    local loc_pos = curr_pos
                    local loc_surf = surface
                    if not (loc_surf and loc_surf.valid and loc_pos and loc_surf.name ~= "liminal_surface") then
                        local cap = storage.capsules and (storage.capsules[capsule_id] or capsule)
                        local pkey = cap and cap.from_port_key
                        local node = pkey and storage.flow_nodes and storage.flow_nodes[pkey]
                        if node and node.surface_name then
                            loc_surf = game.surfaces[node.surface_name]
                            loc_pos = node.pos or (node.x and { x = node.x, y = node.y })
                        end
                        if not (loc_surf and loc_surf.valid and loc_pos and loc_surf.name ~= "liminal_surface") and cap and cap.source_hub then
                            local hub = storage.active_hubs and storage.active_hubs[cap.source_hub]
                            if hub and hub.valid then
                                loc_surf = hub.surface
                                loc_pos = hub.position
                            end
                        end
                        if not (loc_surf and loc_surf.valid and loc_pos and loc_surf.name ~= "liminal_surface") and cap and cap.last_pos and cap.surface_name then
                            loc_surf = game.surfaces[cap.surface_name]
                            loc_pos = cap.last_pos
                        end
                    end
                    local ent_name, per_trig = resolve_spoil_trigger_info(item.name)
                    if loc_surf and loc_surf.valid and loc_pos and loc_surf.name ~= "liminal_surface" and ent_name and prototypes.entity[ent_name] then
                        local spawn_count = math.max(1, math.ceil((item.count or 1) / per_trig))
                        local item_qual = (type(item.quality) == "string" and item.quality) or (item.quality and item.quality.name) or "normal"
                        for s_i = 1, spawn_count do
                            local safe_pos = loc_surf.find_non_colliding_position(ent_name, loc_pos, 4 + s_i * 0.5, 0.5) or loc_pos
                            loc_surf.create_entity{
                                name = ent_name,
                                position = safe_pos,
                                force = "enemy",
                                quality = item_qual
                            }
                        end
                    end
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

    ref.last_update_tick = current_tick

    if any_spoiled or ran_out then
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
        local new_dom = dom_c or (phys_capsule.definition and phys_capsule.definition.name) or phys_capsule.capsule_type
        phys_capsule.dominant_item = new_dom
        phys_capsule.dominant_quality = dom_q
        if storage.capsules and capsule_id and storage.capsules[capsule_id] then
            storage.capsules[capsule_id].dominant_item = new_dom
            storage.capsules[capsule_id].dominant_quality = dom_q
            if storage.capsules[capsule_id].render_cache then
                storage.capsules[capsule_id].render_cache.dominant_item = nil
            end
        end
    end

    if (any_spoiled or ran_out) and capsule_id then
        local old_sig = phys_capsule.signal_data
        local new_sig = capsule_manager.extract_holder_signal_data(
            phys_capsule.holder,
            phys_capsule.primary_slot,
            phys_capsule.capsule_type,
            phys_capsule.dominant_quality or "normal",
            phys_capsule.virtual_cargo
        )
        phys_capsule.signal_data = new_sig
        if old_sig and counter_range.update_capsule_signals then
            counter_range.update_capsule_signals(capsule_id, old_sig, new_sig)
        end
    end

    phys_capsule.next_spoil_tick = capsule_lifecycle.calculate_virtual_dilated_recheck(phys_capsule, current_tick)
end

--- Collapses the virtual cargo waveform, applying time dilation to date and returning the finalized stack specs
--- @param phys_capsule table
--- @param current_tick number
--- @param capsule_id number|nil
--- @return table|nil virtual_cargo
function capsule_lifecycle.collapse_virtual_cargo(phys_capsule, current_tick, capsule_id)
    return capsule_manager.collapse_virtual_cargo(phys_capsule, current_tick, capsule_id)
end

--- Finalizes refrigeration cooling on hub arrival or spill event before holder contents are unpacked
--- @param capsule_id number
--- @param current_tick number
function capsule_lifecycle.finalize_refrigeration(capsule_id, current_tick)
    if not capsule_id then return end
    local cap_data = capsule_manager.get(capsule_id)
    if not cap_data then return end

    if cap_data.virtual_cargo then
        capsule_lifecycle.collapse_virtual_cargo(cap_data, current_tick, capsule_id)
        return
    end

    if not (cap_data.has_spoilable_items and cap_data.definition) then return end
    if (cap_data.definition.spoilage_modifier or 1.0) < 1.0 then
        capsule_lifecycle.intercept_refrigeration(cap_data, current_tick)
    end
end

--- Handles per-tick passenger position synchronization, spill risk, and refrigerated mechanics
function capsule_lifecycle.legacy_update(capsule, id, curr_pos, surface)
    local phys_capsule = capsule_manager.get(capsule.capsule_id or id)
    if not (phys_capsule and phys_capsule.definition) then return false end

    local def = phys_capsule.definition

    -- 1. Player Transit Teleportation (Runs every tick for smooth player movement)
    if capsule.passenger and capsule.passenger.valid then
        capsule.passenger.teleport(curr_pos, surface)
    end

    -- 2. Mid-Transit Structural Failure (Evaluated every 10 ticks, staggered per capsule)
    if def.spill_risk and def.spill_risk > 0 and ((game.tick + id) % 10 == 0) then
        -- Scale 1-tick risk over 10 ticks: R_10 = 1 - (1 - r)^10
        local interval_risk = 1.0 - ((1.0 - def.spill_risk) ^ 10)
        if math.random() < interval_risk then
            hub_spill.spill_capsule(capsule.capsule_id or id, surface, curr_pos, nil, true)
            return true
        end
    end

    -- 3. Refrigerated Capsule Spoilage Modifier & Charge Drain
    local modifier = def.spoilage_modifier or 1.0
    if modifier < 1.0 and ((game.tick + id) % 60 == 0) then
        if phys_capsule.holder and phys_capsule.holder.valid then
            local inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
            if inv and inv.valid and not inv.is_empty() then
                capsule.slot_spoil_percents = capsule.slot_spoil_percents or {}
                local actively_cooling = false

                -- Calculate active slot bound to avoid allocating C++ LuaItemStack userdata for red-locked slots
                local max_slot = #inv
                if inv.supports_bar() then
                    local bar = inv.get_bar()
                    if bar then
                        max_slot = math.min(#inv, bar - 1)
                    end
                end

                for i = 1, max_slot do
                    local stack = inv[i]
                    if stack and stack.valid_for_read and stack.spoil_percent > 0 then
                        local current_spoil = stack.spoil_percent
                        local last_spoil = capsule.slot_spoil_percents[i]

                        if last_spoil and current_spoil > last_spoil then
                            actively_cooling = true
                            local raw_delta = current_spoil - last_spoil
                            local target_spoil = math.max(0.0, last_spoil + (raw_delta * modifier))

                            local src_grid = stack.grid
                            local stack_spec = item_transfer_handler.build_stack_spec(stack)
                            stack_spec.spoil_percent = target_spoil

                            inv[i].clear()
                            inv[i].set_stack(stack_spec)

                            if src_grid and src_grid.valid and inv[i].valid_for_read then
                                item_transfer_handler.copy_equipment_grid(src_grid, inv[i])
                            end

                            capsule.slot_spoil_percents[i] = target_spoil
                        else
                            capsule.slot_spoil_percents[i] = current_spoil
                        end
                    else
                        capsule.slot_spoil_percents[i] = nil
                    end
                end

                -- Purge any stale spoil percent tracking entries beyond current max active slot
                for k in pairs(capsule.slot_spoil_percents) do
                    if k > max_slot then
                        capsule.slot_spoil_percents[k] = nil
                    end
                end

                -- Deduct charge strictly from the primary capsule shell slot via stack.health
                if actively_cooling and phys_capsule.primary_slot then
                    local p_slot = phys_capsule.primary_slot
                    if p_slot <= max_slot then
                        local stack = inv[p_slot]
                        if stack and stack.valid_for_read then
                            local caps_def = capsule_defs.types[stack.name]
                            if caps_def and caps_def.spoilage_modifier and caps_def.spoilage_modifier < 1.0 then
                                local max_charges = capsule_defs.get_max_charges(caps_def, stack.quality)
                                local cur_health = stack.health or 1.0
                                local cur_charges = math.floor((cur_health * max_charges) + 0.5)

                                local new_charges = cur_charges - 1

                                if new_charges <= 0 then
                                    local spent_item_name = caps_def.spent_capsule_item or "spent-refrigerated-capsule"
                                    local quality = stack.quality
                                    local src_grid = stack.grid
                                    inv[p_slot].clear()
                                    inv[p_slot].set_stack({
                                        name = spent_item_name,
                                        count = 1,
                                        quality = quality
                                    })
                                    if src_grid and src_grid.valid and inv[p_slot].valid_for_read then
                                        item_transfer_handler.copy_equipment_grid(src_grid, inv[p_slot])
                                    end
                                    phys_capsule.definition = capsule_defs.types[spent_item_name] or phys_capsule.definition
                                else
                                    stack.health = math.max(0.01, new_charges / max_charges)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

--- Handles per-tick passenger position synchronization, spill risk, and refrigerated mechanics
function capsule_lifecycle.update(capsule, id, curr_pos, surface)
    local phys_capsule = capsule_manager.get(capsule.capsule_id or id)
    if not (phys_capsule and phys_capsule.definition) then return false end

    local def = phys_capsule.definition

    if capsule.passenger and capsule.passenger.valid then
        capsule.passenger.teleport(curr_pos, surface)
    end

    if def.spill_risk and def.spill_risk > 0 and ((game.tick + id) % 10 == 0) then
        local interval_risk = 1.0 - ((1.0 - def.spill_risk) ^ 10)
        if math.random() < interval_risk then
            hub_spill.spill_capsule(capsule.capsule_id or id, surface, curr_pos, nil, true)
            return true
        end
    end

    return false
end

local function get_capsule_world_location(cap_id)
    local cap = storage.capsules and storage.capsules[cap_id]
    if not cap then return nil, nil end
    local pkey = cap.from_port_key
    local node = pkey and storage.flow_nodes and storage.flow_nodes[pkey]
    if node and node.surface_name and node.pos then
        local surf = game.surfaces[node.surface_name]
        if surf and surf.valid then
            return node.pos, surf
        end
    end
    if cap.last_pos and cap.surface_name then
        local surf = game.surfaces[cap.surface_name]
        if surf and surf.valid then
            return cap.last_pos, surf
        end
    end
    return nil, nil
end

--- Advances the spoil heap by popping and processing any capsules whose recheck horizon has arrived
--- @param current_tick number
function capsule_lifecycle.step_spoil_heap(current_tick)
    local heap = get_spoil_heap()
    if not heap or heap:is_empty() then return end

    local limit = 500
    local processed = 0

    while processed < limit do
        local cap_id, spoil_tick = heap:peek()
        if not cap_id or spoil_tick > current_tick then
            break
        end

        heap:pop()
        processed = processed + 1

        local phys_capsule = capsule_manager.get(cap_id)
        if phys_capsule then
            local curr_pos, surface = get_capsule_world_location(cap_id)
            local motion_capsule = storage.capsules and storage.capsules[cap_id]

            if phys_capsule.virtual_cargo and (not phys_capsule.virtual_next_spoil_tick or current_tick >= phys_capsule.virtual_next_spoil_tick) then
                capsule_lifecycle.update_virtual_refrigeration(phys_capsule, current_tick, cap_id, curr_pos, surface, motion_capsule)
            end
            if phys_capsule.has_spoilable_items and (not phys_capsule.physical_next_spoil_tick or current_tick >= phys_capsule.physical_next_spoil_tick) then
                capsule_lifecycle.process_dynamic_cargo(motion_capsule, phys_capsule, current_tick)
            end

            local next_tick = capsule_lifecycle.schedule_dynamic_cargo(phys_capsule, current_tick)
            if motion_capsule then
                motion_capsule.next_spoil_tick = next_tick
            end
        end
    end
end

--- Returns diagnostic statistics for the spoil heap
--- @return table stats
function capsule_lifecycle.get_heap_stats()
    local heap = get_spoil_heap()
    local count = heap:count()
    local cap = heap:capacity()
    local next_id, next_tick = heap:peek()
    return {
        count = count,
        capacity = cap,
        next_id = next_id,
        next_tick = next_tick,
        ticks_remaining = next_tick and (next_tick - game.tick) or nil
    }
end

--- Purges any capsules from the spoil heap that no longer contain spoilable items
--- @return number purged_count
function capsule_lifecycle.purge_non_spoilables()
    local heap = get_spoil_heap()
    if not (heap and storage.active_capsules) then return 0 end
    local purged = 0
    for cid, cap_data in pairs(storage.active_capsules) do
        if heap:contains(cid) then
            local has_spoilable = false
            if cap_data.virtual_cargo then
                for _, item in ipairs(cap_data.virtual_cargo) do
                    if item.count and item.count > 0 and item.base_spoil_ticks and item.base_spoil_ticks > 0 then
                        has_spoilable = true
                        break
                    end
                end
            end
            if not has_spoilable and cap_data.holder and cap_data.holder.valid then
                local inv = cap_data.holder.get_inventory(defines.inventory.chest)
                if inv and inv.valid and not inv.is_empty() then
                    local p_slot = cap_data.primary_slot or 1
                    local _, has_p = capsule_lifecycle.find_earliest_spoil_tick(inv, #inv, p_slot, game.tick)
                    if has_p then has_spoilable = true end
                end
            end
            if not has_spoilable then
                heap:remove(cid)
                cap_data.next_spoil_tick = nil
                cap_data.virtual_next_spoil_tick = nil
                cap_data.physical_next_spoil_tick = nil
                cap_data.has_spoilable_items = false
                cap_data.is_stable = true
                purged = purged + 1
            end
        end
    end
    return purged
end

return capsule_lifecycle
