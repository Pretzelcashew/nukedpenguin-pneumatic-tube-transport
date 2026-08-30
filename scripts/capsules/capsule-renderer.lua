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
    if not (surface and surface.valid and curr_pos and curr_pos.x and curr_pos.y) then
        capsule_queries.clear_capsule_render(capsule)
        return
    end

    local passenger = capsule.passenger
    local passenger_valid = passenger and passenger.valid
    local passenger_index = passenger_valid and passenger.index or nil
    local surface_index = surface.index

    -- Build a player debug active key for capsule rendering overlay
    local debug_key_tbl = {}
    for _, player in pairs(game.players) do
        if is_debug_active("capsules", player.index) then
            table.insert(debug_key_tbl, player.index)
        end
    end
    local debug_key = table.concat(debug_key_tbl, ",")

    local cache = capsule.render_cache
    local render_id = capsule.render_id

    -- Validate that all existing render handles are still valid C++ objects
    local render_objects_valid = true
    if render_id then
        if type(render_id) == "table" then
            for _, obj in ipairs(render_id) do
                if not (obj and obj.valid) then
                    render_objects_valid = false
                    break
                end
            end
        elseif not (render_id.valid) then
            render_objects_valid = false
        end
    else
        render_objects_valid = false
    end

    -- Evaluate dominant item lazily only when debug rendering is active and there is no passenger
    local dominant_item = nil
    if debug_key ~= "" and not passenger_valid then
        if cache and cache.dominant_item and cache.pos_x == curr_pos.x and cache.pos_y == curr_pos.y and render_objects_valid then
            dominant_item = cache.dominant_item
        else
            dominant_item = capsule_renderer.get_dominant_item(capsule.capsule_id or id)
        end
    end

    -- Check if current state matches cached render state
    local state_matches = cache
        and render_objects_valid
        and cache.surface_index == surface_index
        and cache.passenger_index == passenger_index
        and cache.debug_key == debug_key
        and cache.dominant_item == dominant_item

    if state_matches then
        local pos_changed = (cache.pos_x ~= curr_pos.x or cache.pos_y ~= curr_pos.y)
        if not pos_changed then
            -- Case 1: Stationary capsule with unchanged render state -> Zero allocation NO-OP
            return
        end

        -- Case 2: Moving capsule with unchanged render state -> Fast in-place target position update
        if type(render_id) == "table" and cache.target_offsets then
            for i, render_obj in ipairs(render_id) do
                local offset_y = cache.target_offsets[i] or 0
                if offset_y ~= 0 then
                    render_obj.target = { curr_pos.x, curr_pos.y + offset_y }
                else
                    render_obj.target = curr_pos
                end
            end
        elseif render_id then
            render_id.target = curr_pos
        end

        cache.pos_x = curr_pos.x
        cache.pos_y = curr_pos.y
        return
    end

    -- Case 3: State changed or handles invalid -> Destroy old render objects and re-create
    capsule_queries.clear_capsule_render(capsule)

    if debug_key ~= "" and not passenger_valid and dominant_item == nil then
        dominant_item = capsule_renderer.get_dominant_item(capsule.capsule_id or id)
    end

    local render_objects = {}
    local target_offsets = {}

    if passenger_valid then
        local eject_text = rendering.draw_text{
            text = "[Shift + E] Emergency Eject",
            surface = surface,
            target = { curr_pos.x, curr_pos.y + 0.8 },
            color = { r = 1, g = 0.9, b = 0.3, a = 1.0 },
            players = { passenger },
            alignment = "center",
            scale = 0.9
        }
        table.insert(render_objects, eject_text)
        table.insert(target_offsets, 0.8)
    end

    for _, player in pairs(game.players) do
        if is_debug_active("capsules", player.index) then
            if passenger_valid then
                local ring = rendering.draw_circle{
                    color = { r = 0, g = 0.8, b = 1, a = 0.9 },
                    radius = 0.45,
                    filled = false,
                    width = 3,
                    target = curr_pos,
                    surface = surface,
                    players = { player }
                }
                table.insert(render_objects, ring)
                table.insert(target_offsets, 0)
            else
                if dominant_item then
                    local ring = rendering.draw_circle{
                        color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                        radius = 0.35,
                        filled = false,
                        width = 2,
                        target = curr_pos,
                        surface = surface,
                        players = { player }
                    }
                    table.insert(render_objects, ring)
                    table.insert(target_offsets, 0)

                    local sprite = rendering.draw_sprite{
                        sprite = "item/" .. dominant_item,
                        target = curr_pos,
                        surface = surface,
                        x_scale = 0.55,
                        y_scale = 0.55,
                        players = { player }
                    }
                    table.insert(render_objects, sprite)
                    table.insert(target_offsets, 0)
                else
                    local dot = rendering.draw_circle{
                        color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                        radius = 0.25,
                        filled = true,
                        target = curr_pos,
                        surface = surface,
                        players = { player }
                    }
                    table.insert(render_objects, dot)
                    table.insert(target_offsets, 0)
                end
            end
        end
    end

    if #render_objects > 0 then
        capsule.render_id = render_objects
        capsule.render_cache = {
            surface_index = surface_index,
            pos_x = curr_pos.x,
            pos_y = curr_pos.y,
            passenger_index = passenger_index,
            debug_key = debug_key,
            dominant_item = dominant_item,
            target_offsets = target_offsets
        }
    else
        capsule.render_id = nil
        capsule.render_cache = {
            surface_index = surface_index,
            pos_x = curr_pos.x,
            pos_y = curr_pos.y,
            passenger_index = passenger_index,
            debug_key = debug_key,
            dominant_item = dominant_item,
            target_offsets = nil
        }
    end
end

return capsule_renderer