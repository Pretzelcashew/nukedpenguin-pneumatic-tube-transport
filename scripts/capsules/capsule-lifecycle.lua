local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local capsule_queries = require("scripts.capsules.capsule-queries")
local hub_spill = require("scripts.hubs.hub-spill")
local item_transfer_handler = require("scripts.utils.item-transfer-handler")

local capsule_lifecycle = {}

--- Handles per-tick passenger position synchronization, spill risk, and refrigerated mechanics
function capsule_lifecycle.update(capsule, id, curr_pos, surface)
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

return capsule_lifecycle