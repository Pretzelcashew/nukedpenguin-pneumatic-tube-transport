local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local capsule_queries = require("scripts.capsules.capsule-queries")
local hub_spill = require("scripts.hubs.hub-spill")
local events = require("scripts.events")

local capsule_lifecycle = {}

--- Calculates the research tier for bio capsule integrity (0 to 4) for a force
local function calculate_bio_integrity_level(force)
    if not (force and force.valid) then return 0 end
    if force.technologies["bio-capsule-integrity-4"] and force.technologies["bio-capsule-integrity-4"].researched then
        return 4
    elseif force.technologies["bio-capsule-integrity-3"] and force.technologies["bio-capsule-integrity-3"].researched then
        return 3
    elseif force.technologies["bio-capsule-integrity-2"] and force.technologies["bio-capsule-integrity-2"].researched then
        return 2
    elseif force.technologies["bio-capsule-integrity-1"] and force.technologies["bio-capsule-integrity-1"].researched then
        return 1
    end
    return 0
end

--- Returns cached bio integrity research tier for force from storage, populating cache on demand
function capsule_lifecycle.get_bio_integrity_level(force)
    if not (force and force.valid) then return 0 end
    storage.bio_integrity_levels = storage.bio_integrity_levels or {}
    local f_idx = force.index
    local cached = storage.bio_integrity_levels[f_idx]
    if cached == nil then
        cached = calculate_bio_integrity_level(force)
        storage.bio_integrity_levels[f_idx] = cached
    end
    return cached
end

-- Event Listeners to invalidate/update cached technology research levels
events.on_event(defines.events.on_research_finished, function(event)
    local tech = event.research
    if tech and tech.valid and string.sub(tech.name, 1, 22) == "bio-capsule-integrity-" then
        local force = tech.force
        if force and force.valid then
            storage.bio_integrity_levels = storage.bio_integrity_levels or {}
            storage.bio_integrity_levels[force.index] = calculate_bio_integrity_level(force)
        end
    end
end)

events.on_event(defines.events.on_research_reversed, function(event)
    local tech = event.research
    if tech and tech.valid and string.sub(tech.name, 1, 22) == "bio-capsule-integrity-" then
        local force = tech.force
        if force and force.valid then
            storage.bio_integrity_levels = storage.bio_integrity_levels or {}
            storage.bio_integrity_levels[force.index] = calculate_bio_integrity_level(force)
        end
    end
end)

events.on_event(defines.events.on_technology_effects_reset, function(event)
    local force = event.force
    if force and force.valid then
        storage.bio_integrity_levels = storage.bio_integrity_levels or {}
        storage.bio_integrity_levels[force.index] = calculate_bio_integrity_level(force)
    else
        storage.bio_integrity_levels = {}
    end
end)

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
    if def.spill_risk and ((game.tick + id) % 10 == 0) then
        local effective_risk = def.spill_risk
        local holder = phys_capsule.holder
        local force = (holder and holder.valid and holder.force) or (capsule.passenger and capsule.passenger.valid and capsule.passenger.force)

        if force then
            local tech_level = capsule_lifecycle.get_bio_integrity_level(force)

            -- Reduces baseline spill risk by 25% per tier (100% at L0, 75% at L1, 50% at L2, 25% at L3, 0% at L4)
            effective_risk = math.max(0, effective_risk * (1.0 - (tech_level * 0.25)))
        end

        if effective_risk > 0 then
            -- Scale 1-tick risk over 10 ticks: R_10 = 1 - (1 - r)^10
            local interval_risk = 1.0 - ((1.0 - effective_risk) ^ 10)
            if math.random() < interval_risk then
                hub_spill.spill_capsule(capsule.capsule_id or id, surface, curr_pos, nil, true)
                return true
            end
        end
    end

    -- 3. Refrigerated Capsule Spoilage Modifier & Tool Durability Drain
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

                -- Purge any stale spoil percent tracking entries beyond current max active slot
                for k in pairs(capsule.slot_spoil_percents) do
                    if k > max_slot then
                        capsule.slot_spoil_percents[k] = nil
                    end
                end

                -- Deduct tool durability strictly from the primary capsule shell slot
                if actively_cooling and phys_capsule.primary_slot then
                    local p_slot = phys_capsule.primary_slot
                    if p_slot <= max_slot then
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