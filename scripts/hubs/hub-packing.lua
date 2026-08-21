-- FILE: scripts/hubs/hub-packing.lua
local events = require("scripts.events")
local networks = require("scripts.networks.networks")
local liminal_surface_mgr = require("scripts.surfaces.liminal-surface")
local capsule_manager = require("scripts.capsules.capsule-manager")

local hub_packing = {}

local valid_hubs = {
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true
}

function hub_packing.evaluate_inventory(entity)
    if not (entity and entity.valid) then return end
    if not valid_hubs[entity.name] then return end

    local inventory = entity.get_inventory(defines.inventory.chest)
    if not inventory or inventory.is_empty() then return end

    local capsule_found = false
    local total_items = 0

    -- Scan through the inventory slots to count items and look for a capsule
    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read then
            total_items = total_items + 1
            if stack.name == "item-capsule" then
                capsule_found = true
            end
        end
    end

    -- Trigger if we have a capsule and at least one other item
    if capsule_found and total_items > 1 then
        -- 1. Grab the optimized liminal surface
        local liminal_surface = liminal_surface_mgr.get()
        
        -- 2. Create the holder on the liminal surface
        local holder = liminal_surface.create_entity{
            name = "invisible-capsule-holder",
            position = {0, 0}, 
            force = entity.force
        }
        
        local dest_inv = holder.get_inventory(defines.inventory.chest)
        
        -- 3. Transfer absolutely EVERYTHING to the holder
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack and stack.valid_for_read then
                dest_inv.insert(stack)
                stack.clear()
            end
        end
        
        capsule_manager.register(holder)
        game.print(string.format("[PACKED] Entire inventory moved to holder %d on liminal surface", holder.unit_number))
    end
end

return hub_packing