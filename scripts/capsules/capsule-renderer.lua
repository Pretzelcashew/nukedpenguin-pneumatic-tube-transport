local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_queries = require("scripts.capsules.capsule-queries")
require("scripts.debug-manager")

local capsule_renderer = {}

function capsule_renderer.get_dominant_item(capsule_id)
    local cap_data = capsule_manager.get(capsule_id)
    if not (cap_data and cap_data.holder and cap_data.holder.valid) then
        return nil
    end

    local inventory = cap_data.holder.get_inventory(defines.inventory.chest)
    if not (inventory and inventory.valid and not inventory.is_empty()) then
        return nil
    end

    local max_cargo_count = 0
    local dominant_cargo_item = nil
    local max_vessel_count = 0
    local dominant_vessel_item = nil
    local primary_slot = cap_data.primary_slot

    for i = 1, #inventory do
        local stack = inventory[i]
        if stack and stack.valid_for_read and stack.count > 0 then
            if primary_slot and i == primary_slot then
                if stack.count > max_vessel_count then
                    max_vessel_count = stack.count
                    dominant_vessel_item = stack.name
                end
            else
                if stack.count > max_cargo_count then
                    max_cargo_count = stack.count
                    dominant_cargo_item = stack.name
                end
            end
        end
    end

    return dominant_cargo_item or dominant_vessel_item or (cap_data.definition and cap_data.definition.name)
end

function capsule_renderer.render(capsule, id, curr_pos, surface)
    capsule_queries.clear_capsule_render(capsule)

    if not (surface and curr_pos) then return end

    local render_objects = {}

    -- Render emergency exit hotkey prompt visible ONLY to the active passenger
    if capsule.passenger and capsule.passenger.valid then
        local eject_text = rendering.draw_text{
            text = "[Shift + E] Emergency Eject",
            surface = surface,
            target = { curr_pos.x, curr_pos.y + 0.8 },
            color = { r = 1, g = 0.9, b = 0.3, a = 1.0 },
            players = { capsule.passenger },
            alignment = "center",
            scale = 0.9
        }
        table.insert(render_objects, eject_text)
    end

    -- Visual debug overlays
    if is_debug_active("capsules") then
        if capsule.passenger and capsule.passenger.valid then
            local ring = rendering.draw_circle{
                color = { r = 0, g = 0.8, b = 1, a = 0.9 },
                radius = 0.45,
                filled = false,
                width = 3,
                target = curr_pos,
                surface = surface
            }
            table.insert(render_objects, ring)
        else
            local dominant_item = capsule_renderer.get_dominant_item(capsule.capsule_id or id)
            if dominant_item then
                local ring = rendering.draw_circle{
                    color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                    radius = 0.35,
                    filled = false,
                    width = 2,
                    target = curr_pos,
                    surface = surface
                }
                table.insert(render_objects, ring)

                local sprite = rendering.draw_sprite{
                    sprite = "item/" .. dominant_item,
                    target = curr_pos,
                    surface = surface,
                    x_scale = 0.55,
                    y_scale = 0.55
                }
                table.insert(render_objects, sprite)
            else
                local dot = rendering.draw_circle{
                    color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                    radius = 0.25,
                    filled = true,
                    target = curr_pos,
                    surface = surface
                }
                table.insert(render_objects, dot)
            end
        end
    end

    if #render_objects > 0 then
        capsule.render_id = render_objects
    end
end

return capsule_renderer