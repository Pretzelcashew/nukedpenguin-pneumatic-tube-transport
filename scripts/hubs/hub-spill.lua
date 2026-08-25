local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_queries = require("scripts.capsules.capsule-queries")

local hub_spill = {}

--- Spills an individual capsule's payload items and safely removes its liminal holder
--- @param capsule_id number The unit_number of the holder entity / capsule ID
--- @param surface LuaSurface Surface to spill items onto
--- @param position MapPosition Map position for spill location
--- @param force LuaForce|string Force for container or item looting ownership
function hub_spill.spill_capsule(capsule_id, surface, position, force)
    local capsule_data = capsule_manager.get(capsule_id)
    if not capsule_data then return end

    local holder = capsule_data.holder
    local capsule_def = capsule_data.definition or {}
    local raw_spill = capsule_def.spill_contents

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

            -- Mode: "container" -> Unloads cargo into chest entity, spills overflow
            if mode == "container" and container_proto and holder_inv and not holder_inv.is_empty() then
                local container_entity = surface.create_entity{
                    name = container_proto,
                    position = position,
                    force = force,
                    raise_built = true
                }

                if container_entity and container_entity.valid then
                    if mark_decon then
                        container_entity.order_deconstruction(force)
                    end

                    local container_inv = container_entity.get_inventory(defines.inventory.chest)
                    if container_inv then
                        for i = 1, #holder_inv do
                            local stack = holder_inv[i]
                            if stack and stack.valid_for_read then
                                local original_count = stack.count
                                local inserted = container_inv.insert(stack)
                                if inserted >= original_count then
                                    stack.clear()
                                else
                                    stack.count = original_count - inserted
                                    surface.spill_item_stack{
                                        position = position,
                                        stack = stack,
                                        enable_looted = mark_decon,
                                        force = force
                                    }
                                    stack.clear()
                                end
                            end
                        end
                    end
                end

            -- Mode: "ground" -> Spills cargo directly onto the floor
            elseif holder_inv and not holder_inv.is_empty() then
                for i = 1, #holder_inv do
                    local stack = holder_inv[i]
                    if stack and stack.valid_for_read then
                        surface.spill_item_stack{
                            position = position,
                            stack = stack,
                            enable_looted = mark_decon,
                            force = force
                        }
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
        local capsule_id = cap and (cap.capsule_id or cap.id)

        -- Clear motion tracking and render object
        capsule_queries.remove_capsule(id)

        -- Spill payload and destroy liminal holder
        if capsule_id then
            hub_spill.spill_capsule(capsule_id, surface, position, force)
        end
    end
end

-- Preserve backwards compatibility for hub-manager
hub_spill.handle_hub_destruction = hub_spill.handle_entity_destruction

return hub_spill