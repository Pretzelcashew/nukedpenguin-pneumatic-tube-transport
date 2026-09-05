local diverter_settings = require("scripts.diverter-settings")
local port_defs = require("scripts.flow.port-defs")
local gui_components = require("scripts.utils.gui-components")

local diverter_renderer = {}

--- Distance in tiles to shift filter icon overlays inward from port coordinates towards entity center (0,0),
--- preventing overlap with flow indicator dots.
local PORT_INWARD_OFFSET = 0.55

--- Pitch-black solid tint for high-contrast outline and drop shadow
local BLACK_TINT = { r = 0, g = 0, b = 0, a = 1.0 }

local OUTLINE_SCALE_MULTIPLIER = 1.3
local SHADOW_SCALE_MULTIPLIER = 1.3
local SHADOW_OFFSET_X = 0.04
local SHADOW_OFFSET_Y = 0.04

--- Clears and destroys active Alt Mode render objects for a given diverter unit number.
--- @param unit_number number
function diverter_renderer.clear_render(unit_number)
    if not unit_number then return end
    storage.diverter_render_objects = storage.diverter_render_objects or {}
    local old_objs = storage.diverter_render_objects[unit_number]
    if old_objs then
        for i = 1, #old_objs do
            local obj = old_objs[i]
            if obj and obj.valid then
                obj.destroy()
            end
        end
        storage.diverter_render_objects[unit_number] = nil
    end
end

--- Updates or creates Alt Mode filter overlays for a diverter entity.
--- Renders up to 4 configured filter item icons per port in a clean, balanced 2x2 grid,
--- matching native Factorio Alt-mode filter icon scale, spacing, bottom-left comparators and quality badges.
--- @param entity LuaEntity
function diverter_renderer.update_render(entity)
    if not (entity and entity.valid) then return end
    local unit_number = entity.unit_number
    if not unit_number then return end

    diverter_renderer.clear_render(unit_number)

    local settings = diverter_settings.get(unit_number)
    if not (settings and settings.ports) then return end

    local port_definitions = port_defs.get_ports(entity)
    if not port_definitions then return end

    local new_objs = {}
    local surface = entity.surface

    for port_index = 1, 4 do
        local port = settings.ports[port_index]
        if port and port.use_filters and port.filters then
            local active_filters = {}
            for j = 1, 5 do
                local filter = port.filters[j]
                if filter and filter.item and filter.item ~= "" then
                    table.insert(active_filters, {
                        item = filter.item,
                        comparator = filter.comparator or "Any Quality",
                        quality = filter.quality or "normal"
                    })
                    if #active_filters == 4 then break end
                end
            end

            local item_count = #active_filters
            if item_count > 0 then
                local port_def = port_definitions[port_index]
                if port_def and port_def.offset then
                    local base_pos = port_def.offset
                    local bx = base_pos.x
                    local by = base_pos.y

                    -- Shift base position inward towards entity center (0,0) to prevent flow dot overlap
                    local dist = math.sqrt(bx * bx + by * by)
                    if dist > 0 then
                        local dir_x = bx / dist
                        local dir_y = by / dist
                        bx = bx - dir_x * PORT_INWARD_OFFSET
                        by = by - dir_y * PORT_INWARD_OFFSET
                    end

                    local scale
                    local offsets = {}

                    if item_count == 1 then
                        scale = 0.52
                        offsets[1] = { x = 0, y = 0 }
                    elseif item_count == 2 then
                        scale = 0.46
                        offsets[1] = { x = -0.22, y = 0 }
                        offsets[2] = { x =  0.22, y = 0 }
                    else
                        scale = 0.42
                        offsets[1] = { x = -0.22, y = -0.22 }
                        offsets[2] = { x =  0.22, y = -0.22 }
                        offsets[3] = { x = -0.22, y =  0.22 }
                        offsets[4] = { x =  0.22, y =  0.22 }
                    end

                    for idx = 1, item_count do
                        local filter_entry = active_filters[idx]
                        local item_name = filter_entry.item
                        local sprite_path = "item/" .. item_name
                        if helpers.is_valid_sprite_path(sprite_path) then
                            local off = offsets[idx]
                            local cx = bx + off.x
                            local cy = by + off.y

                            -- 1. Solid pitch-black outline centered behind icon
                            local outline_obj = rendering.draw_sprite{
                                sprite = sprite_path,
                                target = { entity = entity, offset = { cx, cy } },
                                surface = surface,
                                x_scale = scale * OUTLINE_SCALE_MULTIPLIER,
                                y_scale = scale * OUTLINE_SCALE_MULTIPLIER,
                                tint = BLACK_TINT,
                                render_layer = "entity-info-icon",
                                only_in_alt_mode = true
                            }
                            table.insert(new_objs, outline_obj)

                            -- 2. Solid pitch-black drop shadow offset down-right
                            local shadow_obj = rendering.draw_sprite{
                                sprite = sprite_path,
                                target = { entity = entity, offset = { cx + SHADOW_OFFSET_X, cy + SHADOW_OFFSET_Y } },
                                surface = surface,
                                x_scale = scale * SHADOW_SCALE_MULTIPLIER,
                                y_scale = scale * SHADOW_SCALE_MULTIPLIER,
                                tint = BLACK_TINT,
                                render_layer = "entity-info-icon",
                                only_in_alt_mode = true
                            }
                            table.insert(new_objs, shadow_obj)

                            -- 3. Main item icon rendered in full color on top
                            local sprite_obj = rendering.draw_sprite{
                                sprite = sprite_path,
                                target = { entity = entity, offset = { cx, cy } },
                                surface = surface,
                                x_scale = scale,
                                y_scale = scale,
                                render_layer = "entity-info-icon-above",
                                only_in_alt_mode = true
                            }
                            table.insert(new_objs, sprite_obj)

                            -- 4. Bottom-left corner comparator symbol and/or quality badge
                            local comp = filter_entry.comparator or "Any Quality"
                            local qual = filter_entry.quality or "normal"

                            local show_comp = (comp ~= "=" and comp ~= "Any" and comp ~= "Any Quality")
                            local comp_text = show_comp and comp or nil

                            local badge_sprite = nil
                            if comp == "Any" or comp == "Any Quality" then
                                badge_sprite = gui_components.get_quality_sprite("any")
                            elseif qual and qual ~= "" and qual ~= "normal" then
                                badge_sprite = gui_components.get_quality_sprite(qual)
                            end

                            local has_badge = (badge_sprite and helpers.is_valid_sprite_path(badge_sprite))

                            if comp_text and has_badge then
                                -- Both comparator symbol and quality badge side-by-side at bottom-left
                                local comp_x = cx - (scale * 0.36)
                                local comp_y = cy + (scale * 0.26)
                                local badge_x = cx - (scale * 0.14)
                                local badge_y = cy + (scale * 0.28)
                                local badge_scale = scale * 0.38

                                local comp_shadow = rendering.draw_text{
                                    text = comp_text,
                                    surface = surface,
                                    target = { entity = entity, offset = { comp_x + 0.015, comp_y + 0.015 } },
                                    color = { r = 0, g = 0, b = 0, a = 1 },
                                    scale = scale * 0.85,
                                    font = "default-semibold",
                                    alignment = "center",
                                    vertical_alignment = "middle",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, comp_shadow)

                                local comp_obj = rendering.draw_text{
                                    text = comp_text,
                                    surface = surface,
                                    target = { entity = entity, offset = { comp_x, comp_y } },
                                    color = { r = 1, g = 1, b = 1, a = 1 },
                                    scale = scale * 0.85,
                                    font = "default-semibold",
                                    alignment = "center",
                                    vertical_alignment = "middle",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, comp_obj)

                                local badge_outline = rendering.draw_sprite{
                                    sprite = badge_sprite,
                                    target = { entity = entity, offset = { badge_x, badge_y } },
                                    surface = surface,
                                    x_scale = badge_scale * OUTLINE_SCALE_MULTIPLIER,
                                    y_scale = badge_scale * OUTLINE_SCALE_MULTIPLIER,
                                    tint = BLACK_TINT,
                                    render_layer = "entity-info-icon",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, badge_outline)

                                local badge_sprite_obj = rendering.draw_sprite{
                                    sprite = badge_sprite,
                                    target = { entity = entity, offset = { badge_x, badge_y } },
                                    surface = surface,
                                    x_scale = badge_scale,
                                    y_scale = badge_scale,
                                    render_layer = "entity-info-icon-above",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, badge_sprite_obj)

                            elseif comp_text then
                                -- Comparator symbol only at bottom-left
                                local comp_x = cx - (scale * 0.28)
                                local comp_y = cy + (scale * 0.26)

                                local comp_shadow = rendering.draw_text{
                                    text = comp_text,
                                    surface = surface,
                                    target = { entity = entity, offset = { comp_x + 0.015, comp_y + 0.015 } },
                                    color = { r = 0, g = 0, b = 0, a = 1 },
                                    scale = scale * 0.85,
                                    font = "default-semibold",
                                    alignment = "center",
                                    vertical_alignment = "middle",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, comp_shadow)

                                local comp_obj = rendering.draw_text{
                                    text = comp_text,
                                    surface = surface,
                                    target = { entity = entity, offset = { comp_x, comp_y } },
                                    color = { r = 1, g = 1, b = 1, a = 1 },
                                    scale = scale * 0.85,
                                    font = "default-semibold",
                                    alignment = "center",
                                    vertical_alignment = "middle",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, comp_obj)

                            elseif has_badge then
                                -- Quality badge only at bottom-left
                                local badge_x = cx - (scale * 0.28)
                                local badge_y = cy + (scale * 0.28)
                                local badge_scale = scale * 0.40

                                local badge_outline = rendering.draw_sprite{
                                    sprite = badge_sprite,
                                    target = { entity = entity, offset = { badge_x, badge_y } },
                                    surface = surface,
                                    x_scale = badge_scale * OUTLINE_SCALE_MULTIPLIER,
                                    y_scale = badge_scale * OUTLINE_SCALE_MULTIPLIER,
                                    tint = BLACK_TINT,
                                    render_layer = "entity-info-icon",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, badge_outline)

                                local badge_sprite_obj = rendering.draw_sprite{
                                    sprite = badge_sprite,
                                    target = { entity = entity, offset = { badge_x, badge_y } },
                                    surface = surface,
                                    x_scale = badge_scale,
                                    y_scale = badge_scale,
                                    render_layer = "entity-info-icon-above",
                                    only_in_alt_mode = true
                                }
                                table.insert(new_objs, badge_sprite_obj)
                            end
                        end
                    end
                end
            end
        end
    end

    if #new_objs > 0 then
        storage.diverter_render_objects = storage.diverter_render_objects or {}
        storage.diverter_render_objects[unit_number] = new_objs
    end
end

return diverter_renderer