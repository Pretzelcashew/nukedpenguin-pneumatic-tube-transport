-- FILE: scripts/hubs/hub-packing.lua
local events = require("scripts.events")
local networks = require("scripts.networks.networks")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")
local capsule_manager = require("scripts.capsules.capsule-manager")
local hub_defs = require("scripts.hubs.hub-definitions")
local capsule_defs = require("scripts.capsules.capsule-definitions")

local hub_packing = {}

function hub_packing.evaluate_inventory(entity)
    if not (entity and entity.valid) then return end

    -- Verify entity is a registered hub
    local hub_def = hub_defs.types[entity.name]
    if not (hub_def and hub_def.type == "hub") then return end

    local inventory = entity.get_inventory(defines.inventory.chest)
    if not inventory or inventory.is_empty() then return end

    local active_capsule_name = nil
    local capsule_found = false
    local total_items = 0

    -- Scan through the inventory slots using definitions
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            total_items = total_items + 1
            
            local cap_def = capsule_defs.types[stack.name]
            if cap_def then
                capsule_found = true
                active_capsule_name = stack.name
            end
        end
    end

    -- Trigger packing rule match
    if capsule_found and total_items > 1 then
        local liminal_surface = liminal_surface_mgr.get()
        
        local holder = liminal_surface.create_entity{
            name = "invisible-capsule-holder",
            position = {0, 0}, 
            force = entity.force
        }
        
        local dest_inv = holder.get_inventory(defines.inventory.chest)
        
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack and stack.valid_for_read then
                dest_inv.insert(stack)
                stack.clear()
            end
        end
        
        capsule_manager.register(holder, active_capsule_name)
        game.print(string.format("[PACKED] Entire inventory moved to holder %d on liminal surface", holder.unit_number))
    end
end

return hub_packing