local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local capsule_queries = require("scripts.capsules.capsule-queries")
local hub_spill = require("scripts.hubs.hub-spill")

local capsule_lifecycle = {}

--- Handles per-tick passenger position synchronization, spill risk, and refrigerated mechanics
function capsule_lifecycle.update(capsule, id, curr_pos, surface)
    local phys_capsule = capsule_manager.get(capsule.capsule_id or id)
    if not (phys_capsule and phys_capsule.definition) then return false end

    local def = phys_capsule.definition

    -- 1. Player Transit Teleportation
    if capsule.passenger and capsule.passenger.valid then
        capsule.passenger.teleport(curr_pos, surface)
    end

    -- 2. Mid-Transit Structural Failure (Biodegradable / Fragile Spill Risk)
    if def.spill_risk and math.random() < def.spill_risk then
        hub_spill.spill_capsule(capsule.capsule_id or id, surface, curr_pos, nil, true)
        return true
    end

    -- 3. Refrigerated Capsule Spoilage Modifier & Tool Durability Drain
    local modifier = def.spoilage_modifier or 1.0
    if modifier < 1.0 and ((game.tick + id) % 60 == 0) then
        if phys_capsule.holder and phys_capsule.holder.valid then
            local inv = phys_capsule.holder.get_inventory(defines.inventory.chest)
            if inv and inv.valid and not inv.is_empty() then
                capsule.slot_spoil_percents = capsule.slot_spoil_percents or {}
                local actively_cooling = false

                for i = 1, #inv do
                    local stack = inv[i]
                    if stack and stack.valid_for_read and stack.spoil_percent > 0 then
                        local current_spoil = stack.spoil_percent
                        local last_spoil = capsule.slot_spoil_percents[i]

                        if last_spoil and current_spoil > last_spoil then
                            actively_cooling = true
                            local raw_delta = current_spoil - last_spoil
                            local target_spoil = math.max(0.0, last_spoil + (raw_delta * modifier))

                            local stack_spec = {
                                name = stack.name,
                                count = stack.count,
                                quality = stack.quality,
                                spoil_percent = target_spoil
                            }

                            if stack.is_tool then
                                stack_spec.durability = stack.durability
                            end

                            if stack.is_ammo then
                                stack_spec.ammo = stack.ammo
                            end

                            if stack.is_item_with_tags then
                                stack_spec.custom_description = stack.custom_description
                                stack_spec.tags = stack.tags
                            end

                            inv[i].clear()
                            inv[i].set_stack(stack_spec)
                            capsule.slot_spoil_percents[i] = target_spoil
                        else
                            capsule.slot_spoil_percents[i] = current_spoil
                        end
                    else
                        capsule.slot_spoil_percents[i] = nil
                    end
                end

                -- Deduct tool durability strictly from the primary capsule shell slot
                if actively_cooling and phys_capsule.primary_slot then
                    local p_slot = phys_capsule.primary_slot
                    if p_slot <= #inv then
                        local stack = inv[p_slot]
                        if stack and stack.valid_for_read and stack.is_tool then
                            local caps_def = capsule_defs.types[stack.name]
                            if caps_def and caps_def.spoilage_modifier and caps_def.spoilage_modifier < 1.0 then
                                local current_durability = stack.durability or 1000
                                local new_durability = current_durability - 1

                                if new_durability <= 0 then
                                    local spent_item_name = caps_def.spent_capsule_item or "spent-refrigerated-capsule"
                                    local quality = stack.quality
                                    inv[p_slot].clear()
                                    inv[p_slot].set_stack({
                                        name = spent_item_name,
                                        count = 1,
                                        quality = quality
                                    })
                                    phys_capsule.definition = capsule_defs.types[spent_item_name] or phys_capsule.definition
                                else
                                    stack.durability = new_durability
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