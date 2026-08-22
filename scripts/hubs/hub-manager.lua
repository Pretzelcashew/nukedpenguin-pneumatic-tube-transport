-- FILE: scripts/hubs/hub-manager.lua
local events = require("scripts.events")
local hub_packing = require("scripts.hubs.hub-packing")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_spill = require("scripts.hubs.hub-spill")

local hub_manager = {}

-- Add a new hub to the active registry
local function on_hub_built(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    local def = hub_defs.types[entity.name]
    if def and def.type == "hub" then
        storage.active_hubs = storage.active_hubs or {}
        storage.active_hubs[entity.unit_number] = entity
    end
end

-- Remove a hub from active registry and clean up compartment memory
local function on_hub_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    local unit_number = entity.unit_number
    local def = hub_defs.types[entity.name]
    if def then
        -- Execute spill mechanics before clearing active registry entries
        hub_spill.handle_hub_destruction(entity)

        if storage.active_hubs then
            storage.active_hubs[unit_number] = nil
        end
    end
end

-- The interleaved background scanner
local function on_tick(event)
    if not storage.active_hubs then return end

    local current_tick = event.tick
    for unit_number, entity in pairs(storage.active_hubs) do
        if (unit_number + current_tick) % 10 == 0 then
            if entity.valid then
                hub_packing.evaluate_inventory(entity)
            else
                storage.active_hubs[unit_number] = nil
                if storage.hub_compartments then storage.hub_compartments[unit_number] = nil end
            end
        end
    end
end

-- Hook into Factorio's build events
events.on_event(defines.events.on_built_entity, on_hub_built)
events.on_event(defines.events.on_robot_built_entity, on_hub_built)
events.on_event(defines.events.script_raised_built, on_hub_built)
events.on_event(defines.events.script_raised_revive, on_hub_built)

-- Hook into Factorio's destruction events
events.on_event(defines.events.on_player_mined_entity, on_hub_removed)
events.on_event(defines.events.on_robot_mined_entity, on_hub_removed)
events.on_event(defines.events.on_entity_died, on_hub_removed)
events.on_event(defines.events.script_raised_destroy, on_hub_removed)

-- Hook the interleaved tick loop
events.on_event(defines.events.on_tick, on_tick)

return hub_manager