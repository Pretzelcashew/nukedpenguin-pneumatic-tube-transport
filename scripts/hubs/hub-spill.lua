-- FILE: scripts/hubs/hub-spill.lua
local capsule_manager = require("scripts.capsules.capsule-manager")

local hub_spill = {}

--- Spills or re-houses capsule contents when a hub entity is destroyed or removed
--- @param entity LuaEntity The hub entity being removed
function hub_spill.handle_hub_destruction(entity)
    if not (entity and entity.valid) then return end

    local unit_number = entity.unit_number
    if not storage.hub_compartments then return end

    local compartment = storage.hub_compartments[unit_number]
    if not compartment or #compartment == 0 then
        storage.hub_compartments[unit_number] = nil
        return
    end

    local surface = entity.surface
    local position = entity.position
    local force = entity.force

    for _, capsule_id in ipairs(compartment) do
        local capsule_data = capsule_manager.get(capsule_id)
        if capsule_data then
            local holder = capsule_data.holder
            local capsule_def = capsule_data.definition or {}
            local raw_spill = capsule_def.spill_contents

            -- Explicitly false suppresses spilling entirely
            if raw_spill ~= false then
                local mode = "ground"
                local container_proto = nil

                if type(raw_spill) == "string" then
                    mode = raw_spill
                elseif type(raw_spill) == "table" then
                    mode = raw_spill.mode or "ground"
                    container_proto = raw_spill.container
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
                                                enable_looted = true,
                                                force = force
                                            }
                                            stack.clear()
                                        end
                                    end
                                end
                            end
                        end

                    -- Mode: "ground" or "capsule" -> Spills cargo directly onto the floor
                    elseif holder_inv and not holder_inv.is_empty() then
                        for i = 1, #holder_inv do
                            local stack = holder_inv[i]
                            if stack and stack.valid_for_read then
                                surface.spill_item_stack{
                                    position = position,
                                    stack = stack,
                                    enable_looted = true,
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
    end

    -- Clear hub compartment record
    storage.hub_compartments[unit_number] = nil
end

return hub_spill