local events = require("scripts.events")
local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_queries = require("scripts.capsules.capsule-queries")
local item_transfer_handler = require("scripts.utils.item-transfer-handler")

local hub_spill = {}

--- Scans and cleans up spilled container entities:
--- Immediately destroys the container entity if all contents have been extracted or mined.
local function process_spilled_containers()
    if not storage.spilled_containers then return end

    local has_active = false
    for unit_number, entity in pairs(storage.spilled_containers) do
        has_active = true
        if not (entity and entity.valid) then
            storage.spilled_containers[unit_number] = nil
        else
            local inv = entity.get_inventory(defines.inventory.chest)
            if not inv or inv.is_empty() then
                entity.destroy()
                storage.spilled_containers[unit_number] = nil
            end
        end
    end

    if not has_active then
        storage.spilled_containers = nil
    end
end

-- Periodically check spilled containers for auto-cleanup (60-tick / 1s interval)
events.on_event(defines.events.on_tick, function(event)
    if storage.spilled_containers and (event.tick % 60 == 0) then
        process_spilled_containers()
    end
end)

-- Instantly dismiss container GUI on open
events.on_event(defines.events.on_gui_opened, function(event)
    local entity = event.entity
    if entity and entity.valid and entity.name == "visible-capsule-holder" then
        local player = game.get_player(event.player_index)
        if player then
            player.opened = nil
        end
    end
end)

-- Re-enforce bar set to slot 1 if settings are pasted onto spilled container
events.on_event(defines.events.on_entity_settings_pasted, function(event)
    local destination = event.destination
    if destination and destination.valid and destination.name == "visible-capsule-holder" then
        local inv = destination.get_inventory(defines.inventory.chest)
        if inv and inv.supports_bar() then
            inv.set_bar(1)
        end
    end
end)

--- Central hook for spilling a liminal capsule's contents and cleaning up all motion, render, and holder state
--- @param capsule_id number The unit_number of the holder entity / capsule ID
--- @param surface LuaSurface Surface to spill items onto
--- @param position MapPosition Map position for spill location
--- @param force LuaForce|string|nil Force for container or item looting ownership
--- @param create_explosion boolean|nil Optional flag to spawn explosion visual effect
function hub_spill.spill_capsule(capsule_id, surface, position, force, create_explosion)
    if create_explosion and surface and position then
        surface.create_entity{
            name = "explosion",
            position = position
        }
    end

    local cap_runner = storage.capsules and storage.capsules[capsule_id]
    if cap_runner and cap_runner.passenger and cap_runner.passenger.valid then
        local player = cap_runner.passenger
        local safe_pos = surface and surface.find_non_colliding_position("character", position, 4, 0.5) or position
        if safe_pos and surface then
            player.teleport(safe_pos, surface)
        end
    end

    -- Clean up motion runner tracking, parked index, and visual overlays via leaf query module
    capsule_queries.remove_capsule(capsule_id)

    local capsule_data = capsule_manager.get(capsule_id)
    if not capsule_data then return end

    local holder = capsule_data.holder
    local capsule_def = capsule_data.definition or {}
    local raw_spill = capsule_def.spill_contents

    -- Resolve fallback force from holder entity if not explicitly provided (e.g., mid-transit rupture)
    local effective_force = force or (holder and holder.valid and holder.force) or "player"

    -- Explicitly false suppresses spilling entirely
    if raw_spill ~= false then
        local mode = "ground"
        local container_proto = nil
        local mark_decon = false

        if type(raw_spill) == "string" then
            mode = raw_spill
        elseif type(raw_spill) == "table" then
            mode = raw_spill.mode or "ground"
            container_proto = raw_spill.container
            if raw_spill.mark_for_deconstruction ~= nil then
                mark_decon = raw_spill.mark_for_deconstruction
            end
        end

        if holder and holder.valid then
            local holder_inv = holder.get_inventory(defines.inventory.chest)

            -- Mode: "container" -> Unloads cargo into chest entity, spills overflow onto floor
            if mode == "container" and container_proto and holder_inv and not holder_inv.is_empty() then
                local container_entity = surface.create_entity{
                    name = container_proto,
                    position = position,
                    force = effective_force,
                    raise_built = true
                }

                if container_entity and container_entity.valid then
                    container_entity.operable = true -- Operable: Enables Ctrl+Click fast-looting

                    if mark_decon then
                        container_entity.order_deconstruction(effective_force)
                    end

                    local container_inv = container_entity.get_inventory(defines.inventory.chest)
                    if container_inv then
                        local max_container_slot = #container_inv
                        for i = 1, #holder_inv do
                            local stack = holder_inv[i]
                            if stack and stack.valid_for_read then
                                local transferred = item_transfer_handler.transfer_stack(stack, container_inv, max_container_slot)
                                if not transferred and stack.valid_for_read then
                                    item_transfer_handler.spill_stack(surface, position, stack, mark_decon, effective_force)
                                    stack.clear()
                                end
                            end
                        end

                        if container_inv.is_empty() then
                            container_entity.destroy()
                        else
                            if container_inv.supports_bar() then
                                container_inv.set_bar(1) -- Lock all slots against manual insertion while allowing item extraction
                            end
                            storage.spilled_containers = storage.spilled_containers or {}
                            storage.spilled_containers[container_entity.unit_number] = container_entity
                        end
                    end
                end

            -- Mode: "ground" -> Spills cargo directly onto the floor and marks for deconstruction
            elseif holder_inv and not holder_inv.is_empty() then
                for i = 1, #holder_inv do
                    local stack = holder_inv[i]
                    if stack and stack.valid_for_read then
                        item_transfer_handler.spill_stack(surface, position, stack, mark_decon, effective_force)
                        stack.clear()
                    end
                end
            end
        end
    end

    -- Destroys liminal holder and unregisters capsule from active tracking
    capsule_manager.remove(capsule_id)
end

--- Spills or re-houses capsule contents when any network component (hub, pipe, pump, junction) is removed
--- @param entity LuaEntity The network entity being removed
function hub_spill.handle_entity_destruction(entity)
    if not (entity and entity.valid) then return end

    local unit_number = entity.unit_number
    local surface = entity.surface
    local position = entity.position
    local force = entity.force

    -- 1. Unload hub compartment contents if present
    if storage.hub_compartments and storage.hub_compartments[unit_number] then
        local compartment = storage.hub_compartments[unit_number]
        for _, capsule_id in ipairs(compartment) do
            hub_spill.spill_capsule(capsule_id, surface, position, force)
        end
        storage.hub_compartments[unit_number] = nil
    end

    -- 2. Query active/in-transit/parked capsules occupying this entity's ports
    local runner_ids = capsule_queries.find_capsules_at_entity(unit_number)

    for _, id in ipairs(runner_ids) do
        local cap = storage.capsules and storage.capsules[id]
        local capsule_id = cap and (cap.capsule_id or cap.id) or id

        hub_spill.spill_capsule(capsule_id, surface, position, force)
    end
end

-- Preserve backwards compatibility for hub-manager
hub_spill.handle_hub_destruction = hub_spill.handle_entity_destruction

-- Register entity removal listeners directly within hub-spill to keep module graph acyclic
local removal_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.script_raised_destroy
}
if defines.events.on_space_platform_mined_entity then
    table.insert(removal_events, defines.events.on_space_platform_mined_entity)
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, function(event)
        local entity = event.entity
        if entity and entity.valid then
            hub_spill.handle_entity_destruction(entity)
        end
    end)
end

return hub_spill