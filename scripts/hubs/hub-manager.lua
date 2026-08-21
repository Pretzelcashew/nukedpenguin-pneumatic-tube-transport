-- FILE: scripts/hubs/hub-manager.lua
local events = require("scripts.events")
local hub_packing = require("scripts.hubs.hub-packing")

local hub_manager = {}

local valid_hubs = {
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true
}

-- Add a new hub to the active registry
local function on_hub_built(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    if valid_hubs[entity.name] then
        storage.active_hubs = storage.active_hubs or {}
        -- Using unit_number as the key makes tracking and deletion O(1)
        storage.active_hubs[entity.unit_number] = entity
    end
end

-- Remove a hub from the active registry
local function on_hub_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    if valid_hubs[entity.name] and storage.active_hubs then
        storage.active_hubs[entity.unit_number] = nil
    end
end

-- The staggered background scanner
local function on_tick(event)
    -- Only run every 10 ticks (6 times a second)
    if event.tick % 10 ~= 0 then return end
    if not storage.active_hubs then return end

    for unit_number, entity in pairs(storage.active_hubs) do
        if entity.valid then
            -- Fire the scanner we built earlier
            hub_packing.evaluate_inventory(entity)
        else
            -- Failsafe: clean up dead entities that somehow missed the removal event
            storage.active_hubs[unit_number] = nil
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

-- Hook the staggered tick loop
events.on_event(defines.events.on_tick, on_tick)

return hub_manager