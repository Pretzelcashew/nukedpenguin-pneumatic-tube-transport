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

--- Resolves a valid sprite path for the blacklist 'no' symbol.
--- Checks Factorio native utility sprite first, falling back to registered prototype.
--- @return string|nil
local function get_blacklist_sprite()
    if helpers and helpers.is_valid_sprite_path("utility/filter_blacklist") then
        return "utility/filter_blacklist"
    elseif helpers and helpers.is_valid_sprite_path("pneumatic_filter_blacklist") then
        return "pneumatic_filter_blacklist"
    end
    return nil
end

--- Helper to draw high-contrast white text with a black drop shadow in world space.
--- @param text string
--- @param surface LuaSurface
--- @param entity LuaEntity
--- @param cx number
--- @param cy number
--- @param text_scale number
--- @param alignment string "left"|"center"|"right"
--- @return RenderObject shadow_obj, RenderObject main_obj
local function draw_text_with_shadow(text, surface, entity, cx, cy, text_scale, alignment)
    alignment = alignment or "center"
    local shadow_obj = rendering.draw_text{
        text = text,
        surface = surface,
        target = { entity = entity, offset = { cx + 0.015, cy + 0.015 } },
        color = { r = 0, g = 0, b = 0, a = 1 },
        scale = text_scale,
        font = "default-semibold",
        alignment = alignment,
        vertical_alignment = "middle",
        only_in_alt_mode = true
    }
    local main_obj = rendering.draw_text{
        text = text,
        surface = surface,
        target = { entity = entity, offset = { cx, cy } },
        color = { r = 1, g = 1, b = 1, a = 1 },
        scale = text_scale,
        font = "default-semibold",
        alignment = alignment,
        vertical_alignment = "middle",
        only_in_alt_mode = true
    }
    return shadow_obj, main_obj
end

--- Helper to draw a sprite with pitch-black outline backing and optional down-right drop shadow.
--- @param sprite string
--- @param surface LuaSurface
--- @param entity LuaEntity
--- @param cx number
--- @param cy number
--- @param sprite_scale number
--- @param render_layer_above string
--- @param draw_shadow boolean
--- @return table array_of_render_objects
local function draw_sprite_with_outline_and_shadow(sprite, surface, entity, cx, cy, sprite_scale, render_layer_above, draw_shadow)
    local objs = {}

    -- 1. Solid pitch-black outline centered behind sprite
    local outline = rendering.draw_sprite{
        sprite = sprite,
        target = { entity = entity, offset = { cx, cy } },
        surface = surface,
        x_scale = sprite_scale * OUTLINE_SCALE_MULTIPLIER,
        y_scale = sprite_scale * OUTLINE_SCALE_MULTIPLIER,
        tint = BLACK_TINT,
        render_layer = "entity-info-icon",
        only_in_alt_mode = true
    }
    table.insert(objs, outline)

    -- 2. Solid pitch-black drop shadow offset down-right
    if draw_shadow then
        local shadow = rendering.draw_sprite{
            sprite = sprite,
            target = { entity = entity, offset = { cx + SHADOW_OFFSET_X, cy + SHADOW_OFFSET_Y } },
            surface = surface,
            x_scale = sprite_scale * SHADOW_SCALE_MULTIPLIER,
            y_scale = sprite_scale * SHADOW_SCALE_MULTIPLIER,
            tint = BLACK_TINT,
            render_layer = "entity-info-icon",
            only_in_alt_mode = true
        }
        table.insert(objs, shadow)
    end

    -- 3. Main full-color sprite
    local main_sprite_obj = rendering.draw_sprite{
        sprite = sprite,
        target = { entity = entity, offset = { cx, cy } },
        surface = surface,
        x_scale = sprite_scale,
        y_scale = sprite_scale,
        render_layer = render_layer_above or "entity-info-icon-above",
        only_in_alt_mode = true
    }
    table.insert(objs, main_sprite_obj)

    return objs
end

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
--- Achieves 1:1 visual parity with native Factorio 2.0 inserters by placing comparator symbols cleanly to the
--- left of bottom-left quality badges, avoiding badge overlap while reusing unified gui_components display specifications.
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
            local active_filters = gui_components.get_active_filters(port.filters, 4)
            local item_count = #active_filters
            local is_blacklist = (port.filter_mode == "blacklist")

            -- Native Factorio behavior: Render overlay if we have item/quality filters assigned OR if we are in Whitelist mode with 0 items (blocking all)
            if item_count > 0 or (not is_blacklist) then
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

                    if item_count > 0 then
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
                            local spec = active_filters[idx]
                            local off = offsets[idx]
                            local cx = bx + off.x
                            local cy = by + off.y

                            if spec.has_item then
                                local sprite_path = spec.main_sprite
                                if sprite_path and helpers.is_valid_sprite_path(sprite_path) then
                                    -- 1. Main item icon with black outline and drop shadow
                                    local main_objs = draw_sprite_with_outline_and_shadow(sprite_path, surface, entity, cx, cy, scale, "entity-info-icon-above", true)
                                    for _, o in ipairs(main_objs) do table.insert(new_objs, o) end

                                    -- 2. Bottom-left corner badges (Native Factorio 2.0 Inserter Layout)
                                    local comp_text = spec.comp_text
                                    local badge_sprite = spec.badge_sprite
                                    local has_badge = (badge_sprite and helpers.is_valid_sprite_path(badge_sprite))

                                    if comp_text and has_badge then
                                        -- Quality badge sits in bottom-left corner of item icon
                                        local badge_x = cx - (scale * 0.18)
                                        local badge_y = cy + (scale * 0.24)
                                        local badge_scale = scale * 0.40

                                        -- Comparator symbol sits cleanly to the LEFT of the quality badge
                                        local comp_x = cx - (scale * 0.38)
                                        local comp_y = cy + (scale * 0.24)
                                        local text_scale = scale * 0.90

                                        local s1, t1 = draw_text_with_shadow(comp_text, surface, entity, comp_x, comp_y, text_scale, "right")
                                        table.insert(new_objs, s1)
                                        table.insert(new_objs, t1)

                                        local badge_objs = draw_sprite_with_outline_and_shadow(badge_sprite, surface, entity, badge_x, badge_y, badge_scale, "entity-info-icon-above", false)
                                        for _, o in ipairs(badge_objs) do table.insert(new_objs, o) end

                                    elseif comp_text then
                                        -- Standalone comparator symbol
                                        local comp_x = cx - (scale * 0.28)
                                        local comp_y = cy + (scale * 0.26)
                                        local text_scale = scale * 0.90

                                        local s1, t1 = draw_text_with_shadow(comp_text, surface, entity, comp_x, comp_y, text_scale, "center")
                                        table.insert(new_objs, s1)
                                        table.insert(new_objs, t1)

                                    elseif has_badge then
                                        -- Standalone quality tier badge
                                        local badge_x = cx - (scale * 0.28)
                                        local badge_y = cy + (scale * 0.28)
                                        local badge_scale = scale * 0.40

                                        local badge_objs = draw_sprite_with_outline_and_shadow(badge_sprite, surface, entity, badge_x, badge_y, badge_scale, "entity-info-icon-above", false)
                                        for _, o in ipairs(badge_objs) do table.insert(new_objs, o) end
                                    end
                                end

                            elseif spec.is_standalone_quality then
                                -- Standalone Quality Filter Rendering (Native Factorio 2.0 Inserter Parity)
                                local qual_sprite = spec.badge_sprite or spec.main_sprite
                                if qual_sprite and helpers.is_valid_sprite_path(qual_sprite) then
                                    local comp_text = spec.comp_text

                                    if comp_text then
                                        -- Side-by-side horizontal layout: [ Comparator Symbol ] [ Quality Badge ]
                                        local comp_x = cx - (scale * 0.18)
                                        local comp_y = cy
                                        local badge_x = cx + (scale * 0.18)
                                        local badge_y = cy
                                        local badge_scale = scale * 0.65

                                        local s1, t1 = draw_text_with_shadow(comp_text, surface, entity, comp_x, comp_y, scale * 0.95, "center")
                                        table.insert(new_objs, s1)
                                        table.insert(new_objs, t1)

                                        local badge_objs = draw_sprite_with_outline_and_shadow(qual_sprite, surface, entity, badge_x, badge_y, badge_scale, "entity-info-icon-above", true)
                                        for _, o in ipairs(badge_objs) do table.insert(new_objs, o) end

                                    else
                                        -- Centered quality badge
                                        local badge_scale = scale * 0.85
                                        local badge_objs = draw_sprite_with_outline_and_shadow(qual_sprite, surface, entity, cx, cy, badge_scale, "entity-info-icon-above", true)
                                        for _, o in ipairs(badge_objs) do table.insert(new_objs, o) end
                                    end
                                end
                            end

                            -- Prominent blacklist 'no' symbol overlay per slot
                            if is_blacklist then
                                local blacklist_sprite = get_blacklist_sprite()
                                if blacklist_sprite then
                                    local bl_x = cx + (scale * 0.05)
                                    local bl_y = cy - (scale * 0.05)
                                    local bl_scale = scale * 0.88

                                    local bl_objs = draw_sprite_with_outline_and_shadow(blacklist_sprite, surface, entity, bl_x, bl_y, bl_scale, "entity-info-icon-above", true)
                                    for _, o in ipairs(bl_objs) do table.insert(new_objs, o) end
                                end
                            end
                        end

                    else
                        -- Standalone "no" symbol when item_count == 0 and filter_mode is whitelist (blocks all flow)
                        local blacklist_sprite = get_blacklist_sprite()
                        if blacklist_sprite then
                            local bl_scale = 0.45
                            local bl_objs = draw_sprite_with_outline_and_shadow(blacklist_sprite, surface, entity, bx, by, bl_scale, "entity-info-icon-above", true)
                            for _, o in ipairs(bl_objs) do table.insert(new_objs, o) end
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