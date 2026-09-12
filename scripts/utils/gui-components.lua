local gui_filter_spec = require("scripts.utils.gui.gui-filter-spec")
local gui_quality_bar = require("scripts.utils.gui.gui-quality-bar")

local gui_components = {}

gui_components.COMPARATORS = gui_filter_spec.COMPARATORS
gui_components.QUALITY_COMPARATORS = gui_filter_spec.QUALITY_COMPARATORS
gui_components.QUALITY_TIERS = gui_filter_spec.QUALITY_TIERS

gui_components.COLOR_ACTIVE = "[color=255,174,0]"
gui_components.COLOR_INACTIVE = "[color=160,160,160]"
gui_components.COLOR_WHITE = "[color=255,255,255]"
gui_components.COLOR_BLUE = "[color=100,200,255]"
gui_components.COLOR_END = "[/color]"

gui_components.get_comparator_index = gui_filter_spec.get_comparator_index
gui_components.get_comparator_by_index = gui_filter_spec.get_comparator_by_index
gui_components.get_quality_comparator_index = gui_filter_spec.get_quality_comparator_index
gui_components.get_quality_comparator_by_index = gui_filter_spec.get_quality_comparator_by_index

gui_components.get_quality_sprite = gui_filter_spec.get_quality_sprite

gui_components.format_active_label = gui_filter_spec.format_active_label
gui_components.format_white_label = gui_filter_spec.format_white_label
gui_components.get_item_name_and_quality = gui_filter_spec.get_item_name_and_quality

gui_components.get_filter_display_spec = gui_filter_spec.get_filter_display_spec

gui_components.get_active_filters = gui_filter_spec.get_active_filters
gui_components.clear_filter_slot = gui_filter_spec.clear_filter_slot
gui_components.handle_overlay_slot_click = gui_filter_spec.handle_overlay_slot_click
gui_components.handle_filter_item_change = gui_filter_spec.handle_filter_item_change

--- Creates a main GUI frame window for a player.
--- @param player LuaPlayer
--- @param anchor_spec table|nil Optional relative anchor spec
--- @param frame_name string Name of the frame element
--- @param title string|nil Header title caption (optional)
--- @return LuaGuiElement|nil
function gui_components.create_relative_window(player, anchor_spec, frame_name, title)
    if not (player and player.valid) then return nil end

    if player.gui.screen[frame_name] then
        player.gui.screen[frame_name].destroy()
    end
    if player.gui.relative[frame_name] then
        player.gui.relative[frame_name].destroy()
    end

    local main_frame
    if anchor_spec then
        main_frame = player.gui.relative.add{
            type = "frame",
            name = frame_name,
            direction = "vertical",
            caption = title,
            anchor = anchor_spec
        }
    else
        main_frame = player.gui.screen.add{
            type = "frame",
            name = frame_name,
            direction = "vertical",
            caption = title
        }
        main_frame.auto_center = true
    end

    return main_frame
end

--- Adds a standard titlebar header with title, drag handle, and close button.
--- Configures drag targets so clicking anywhere on the header bar allows window dragging.
--- @param parent_frame LuaGuiElement
--- @param title_text string
--- @param close_button_name string|nil
--- @param tags table|nil
--- @return LuaGuiElement title_flow, LuaGuiElement|nil close_button
function gui_components.add_header(parent_frame, title_text, close_button_name, tags)
    local title_flow = parent_frame.add{ type = "flow", direction = "horizontal" }
    title_flow.style.vertical_align = "center"
    title_flow.drag_target = parent_frame

    local title_label = title_flow.add{
        type = "label",
        style = "frame_title",
        caption = title_text or "",
        ignored_by_interaction = true
    }

    local drag_spacer = title_flow.add{
        type = "empty-widget",
        style = "draggable_space"
    }
    drag_spacer.style.horizontally_stretchable = true
    drag_spacer.style.vertically_stretchable = true
    drag_spacer.drag_target = parent_frame

    local close_button
    if close_button_name then
        close_button = title_flow.add{
            type = "sprite-button",
            name = close_button_name,
            style = "frame_action_button",
            sprite = "utility/close",
            tags = tags
        }
    end

    return title_flow, close_button
end

--- Adds an inner shallow frame and bordered card container.
--- @param parent LuaGuiElement
--- @param direction string|nil "vertical" or "horizontal" (default "vertical")
--- @return LuaGuiElement card_frame, LuaGuiElement inner_frame
function gui_components.add_card_frame(parent, direction)
    local inner_frame = parent.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding"
    }

    local card_frame = inner_frame.add{
        type = "frame",
        direction = direction or "vertical",
        style = "bordered_frame"
    }

    return card_frame, inner_frame
end

--- Adds standard Red/Green wire channel checkboxes to a parent container.
--- @param parent LuaGuiElement
--- @param config table Table with configuration options
--- @return LuaGuiElement wire_flow, LuaGuiElement red_cb, LuaGuiElement green_cb
function gui_components.add_wire_channel_toggles(parent, config)
    config = config or {}
    local wire_flow = parent.add{ type = "flow", direction = "horizontal" }
    wire_flow.style.vertical_align = "center"
    wire_flow.style.horizontal_spacing = config.spacing or 12

    local red_cb = wire_flow.add{
        type = "checkbox",
        name = config.read_red_name or "read_red",
        caption = config.read_red_caption or "Read Red Wire",
        state = config.read_red_state ~= false,
        tags = config.tags
    }

    local green_cb = wire_flow.add{
        type = "checkbox",
        name = config.read_green_name or "read_green",
        caption = config.read_green_caption or "Read Green Wire",
        state = config.read_green_state ~= false,
        tags = config.tags
    }

    return wire_flow, red_cb, green_cb
end

--- Adds a standard circuit network enable condition row.
--- @param parent LuaGuiElement
--- @param config table Configuration table
--- @return LuaGuiElement circuit_flow, table elements_map
function gui_components.add_circuit_condition_panel(parent, config)
    config = config or {}
    local circuit_flow = parent.add{ type = "flow", direction = "horizontal" }
    circuit_flow.style.vertical_align = "center"
    circuit_flow.style.horizontal_spacing = config.spacing or 6

    local cb
    if config.checkbox_name then
        cb = circuit_flow.add{
            type = "checkbox",
            name = config.checkbox_name,
            caption = config.checkbox_caption or "Circuit Enable",
            state = config.checkbox_state or false,
            tags = config.tags
        }
    end

    local cond = config.condition or {}
    local first_signal = config.signal or cond.first_signal
    local comparator = config.comparator or cond.comparator or "="
    local constant = config.constant or cond.constant or 0

    local signal_btn = circuit_flow.add{
        type = "choose-elem-button",
        name = config.signal_button_name or "circuit_signal",
        elem_type = "signal",
        signal = first_signal,
        tags = config.tags
    }

    local comp_dropdown = circuit_flow.add{
        type = "drop-down",
        name = config.comparator_dropdown_name or "circuit_comparator",
        items = gui_components.COMPARATORS,
        selected_index = gui_components.get_comparator_index(comparator),
        tags = config.tags
    }
    comp_dropdown.style.width = config.comparator_width or 55

    local const_tf = circuit_flow.add{
        type = "textfield",
        name = config.constant_textfield_name or "circuit_constant",
        text = tostring(constant),
        numeric = true,
        allow_negative = true,
        tags = config.tags
    }
    const_tf.style.width = config.constant_width or 60

    return circuit_flow, {
        checkbox = cb,
        signal_button = signal_btn,
        comparator_dropdown = comp_dropdown,
        constant_textfield = const_tf
    }
end

--- Creates a 40x40 square slot button with bottom-left corner badges and optional active selection outline.
--- Configures mouse_button_filter to allow both Left and Right click interaction events.
--- @param parent LuaGuiElement
--- @param config table Configuration table: { button_name, item, comparator, quality, is_selected, tags, width, height }
--- @return LuaGuiElement button
function gui_components.create_overlay_slot_button(parent, config)
    config = config or {}

    local button_style = "slot_button"
    if config.is_selected then
        if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
            button_style = "flib_selected_slot_button"
        else
            button_style = "yellow_slot_button"
        end
    end

    local button = parent.add{
        type = "sprite-button",
        name = config.button_name or "filter_slot_button",
        style = button_style,
        sprite = "",
        mouse_button_filter = { "left", "right" },
        tags = config.tags
    }
    button.style.width = config.width or 40
    button.style.height = config.height or 40
    button.style.padding = 0

    local content_flow = button.add{
        type = "flow",
        name = "content_flow",
        direction = "vertical",
        ignored_by_interaction = true
    }
    content_flow.style.width = 34
    content_flow.style.height = 34
    content_flow.style.padding = {1, 1, 1, 1}
    content_flow.style.vertical_spacing = 0

    local top_spacer = content_flow.add{
        type = "empty-widget",
        ignored_by_interaction = true
    }
    top_spacer.style.vertically_stretchable = true

    local bottom_flow = content_flow.add{
        type = "flow",
        name = "bottom_flow",
        direction = "horizontal",
        ignored_by_interaction = true
    }
    bottom_flow.style.height = 12
    bottom_flow.style.vertical_align = "bottom"
    bottom_flow.style.horizontal_align = "left"
    bottom_flow.style.horizontal_spacing = 1

    gui_components.update_overlay_slot_button(button, config.item, config.comparator, config.quality, config.is_selected)

    return button
end

--- Updates an existing overlay slot button using gui_components.get_filter_display_spec.
--- Native behavior: Omits the '=' comparator label overlay and renders non-equal badges in native high-contrast white.
--- Supports standalone quality filter button icon display when no item is selected.
--- @param button LuaGuiElement
--- @param item string|table|nil Item name or specifier
--- @param comparator string|nil Comparator string ("Any", "Any Quality", ">", "<", "=", "≥", "≤", "≠")
--- @param quality string|nil Quality tier ("normal", "uncommon", "rare", "epic", "legendary")
--- @param is_selected boolean|nil Active selection highlight state
function gui_components.update_overlay_slot_button(button, item, comparator, quality, is_selected)
    if not (button and button.valid) then return end

    local spec = gui_components.get_filter_display_spec(item, comparator, quality)

    if spec.main_sprite and helpers.is_valid_sprite_path(spec.main_sprite) then
        button.sprite = spec.main_sprite
    else
        button.sprite = ""
    end

    local button_style = "slot_button"
    if is_selected then
        if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
            button_style = "flib_selected_slot_button"
        else
            button_style = "yellow_slot_button"
        end
    end
    button.style = button_style
    button.style.width = 40
    button.style.height = 40
    button.style.padding = 0

    local content_flow = button["content_flow"]
    if not (content_flow and content_flow.valid) then return end

    local bottom_flow = content_flow["bottom_flow"]
    if not (bottom_flow and bottom_flow.valid) then return end

    bottom_flow.clear()

    if spec.is_active then
        if spec.show_comp and spec.comp_text then
            local badge_label = bottom_flow.add{
                type = "label",
                name = "comparator_badge",
                caption = gui_components.format_white_label(spec.comp_text),
                ignored_by_interaction = true
            }
            badge_label.style.font = "default-semibold"
            badge_label.style.padding = 0
            badge_label.style.margin = 0
            badge_label.style.top_margin = -3
        end

        if spec.badge_sprite and helpers.is_valid_sprite_path(spec.badge_sprite) then
            local q_sprite = bottom_flow.add{
                type = "sprite",
                name = "quality_badge",
                sprite = spec.badge_sprite,
                ignored_by_interaction = true
            }
            q_sprite.style.width = 12
            q_sprite.style.height = 12
            q_sprite.style.stretch_image_to_widget_size = true
        end
    end
end

gui_components.add_quality_control_bar = gui_quality_bar.add_quality_control_bar
gui_components.update_quality_control_bar = gui_quality_bar.update_quality_control_bar
gui_components.update_quality_tier_selection = gui_quality_bar.update_quality_tier_selection
gui_components.handle_quality_tier_click = gui_quality_bar.handle_quality_tier_click
gui_components.handle_quality_comparator_change = gui_quality_bar.handle_quality_comparator_change

--- Adds a spatial '+' shape arrow selector widget to a parent GUI container.
--- Renders a 3x3 grid table with North, West, Center, East, and South button positions.
--- Device GUIs can subscribe to/enable individual parts (north, west, center, east, south).
--- @param parent LuaGuiElement Parent GUI element
--- @param config table|nil Optional configuration table
--- @return LuaGuiElement grid_table, table elements_map Map of created buttons { north, west, center, east, south }
function gui_components.add_spatial_arrow_selector(parent, config)
    config = config or {}
    local button_size = config.button_size or 36
    local name_prefix = config.name_prefix or "spatial_arrow"

    local table_grid = parent.add{
        type = "table",
        name = config.grid_name or (name_prefix .. "_selector_grid"),
        column_count = 3,
        tags = config.tags
    }
    table_grid.style.horizontal_spacing = config.spacing or 2
    table_grid.style.vertical_spacing = config.spacing or 2

    local default_defs = {
        north  = { caption = "▲", tooltip = "North" },
        west   = { caption = "◀", tooltip = "West" },
        center = { caption = "",  tooltip = "Center" },
        east   = { caption = "▶", tooltip = "East" },
        south  = { caption = "▼", tooltip = "South" }
    }

    local grid_sequence = {
        false,     "north",  false,
        "west",    "center", "east",
        false,     "south",  false
    }

    local parts_config = config.parts
    local elements_map = {}

    for _, item in ipairs(grid_sequence) do
        if not item then
            local spacer = table_grid.add{
                type = "empty-widget"
            }
            spacer.style.width = button_size
            spacer.style.height = button_size
        else
            local part_key = item
            local default_def = default_defs[part_key]
            local part_spec = parts_config and parts_config[part_key]

            local is_enabled = false
            local spec_tbl = nil

            if parts_config == nil then
                is_enabled = true
            elseif type(part_spec) == "boolean" then
                is_enabled = part_spec
            elseif type(part_spec) == "table" then
                is_enabled = (part_spec.enabled ~= false)
                spec_tbl = part_spec
            end

            if not is_enabled then
                local spacer = table_grid.add{
                    type = "empty-widget",
                    name = name_prefix .. "_" .. part_key .. "_disabled_spacer"
                }
                spacer.style.width = button_size
                spacer.style.height = button_size
            else
                spec_tbl = spec_tbl or {}
                local btn_name = spec_tbl.name or (name_prefix .. "_" .. part_key)
                local caption = spec_tbl.caption or default_def.caption
                local sprite = spec_tbl.sprite or default_def.sprite
                local tooltip = spec_tbl.tooltip or default_def.tooltip
                local is_selected = spec_tbl.selected == true
                local btn_enabled = spec_tbl.enabled_state ~= false

                local merged_tags = {}
                if config.tags then
                    for k, v in pairs(config.tags) do merged_tags[k] = v end
                end
                if spec_tbl.tags then
                    for k, v in pairs(spec_tbl.tags) do merged_tags[k] = v end
                end
                if merged_tags.spatial_part == nil then
                    merged_tags.spatial_part = part_key
                end

                local style = spec_tbl.style
                if not style then
                    if is_selected then
                        if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
                            style = "flib_selected_slot_button"
                        else
                            style = "yellow_slot_button"
                        end
                    else
                        style = "slot_button"
                    end
                end

                local elem_type = (sprite and sprite ~= "") and "sprite-button" or (spec_tbl.type or "sprite-button")

                local button
                if elem_type == "sprite-button" then
                    button = table_grid.add{
                        type = "sprite-button",
                        name = btn_name,
                        sprite = sprite or "",
                        caption = caption,
                        tooltip = tooltip,
                        style = style,
                        enabled = btn_enabled,
                        tags = merged_tags
                    }
                else
                    button = table_grid.add{
                        type = "button",
                        name = btn_name,
                        caption = caption,
                        tooltip = tooltip,
                        style = style,
                        enabled = btn_enabled,
                        tags = merged_tags
                    }
                end

                button.style.width = button_size
                button.style.height = button_size
                button.style.padding = 0

                elements_map[part_key] = button
            end
        end
    end

    return table_grid, elements_map
end

--- Updates an existing spatial arrow selector button element.
--- @param button LuaGuiElement
--- @param config table Table with updates: { caption, sprite, tooltip, selected, enabled_state, style }
function gui_components.update_spatial_arrow_button(button, config)
    if not (button and button.valid) then return end
    config = config or {}

    if config.caption ~= nil then
        button.caption = config.caption
    end
    if config.sprite ~= nil and button.type == "sprite-button" then
        button.sprite = config.sprite
    end
    if config.tooltip ~= nil then
        button.tooltip = config.tooltip
    end
    if config.enabled_state ~= nil then
        button.enabled = config.enabled_state
    end

    if config.style then
        button.style = config.style
    elseif config.selected ~= nil then
        local is_selected = config.selected == true
        local style = "slot_button"
        if is_selected then
            if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
                style = "flib_selected_slot_button"
            else
                style = "yellow_slot_button"
            end
        end
        button.style = style
    end
end

--- Adds a labeled horizontal switch (e.g. Whitelist/Blacklist, Input/Output).
--- @param parent LuaGuiElement
--- @param config table Configuration table
--- @return LuaGuiElement flow, LuaGuiElement switch_elem, LuaGuiElement left_lbl, LuaGuiElement right_lbl
function gui_components.add_labeled_switch(parent, config)
    config = config or {}
    local flow = parent.add{ type = "flow", direction = "horizontal" }
    flow.style.vertical_align = "center"
    flow.style.horizontal_spacing = config.spacing or 6

    local is_left = (config.is_left == true)

    local left_lbl = flow.add{
        type = "label",
        caption = gui_components.format_active_label(config.left_label or "Left", is_left)
    }

    local switch_elem = flow.add{
        type = "switch",
        name = config.switch_name or "mode_switch",
        allow_none = false,
        switch_state = is_left and "left" or "right",
        tags = config.tags
    }

    local right_lbl = flow.add{
        type = "label",
        caption = gui_components.format_active_label(config.right_label or "Right", not is_left)
    }

    return flow, switch_elem, left_lbl, right_lbl
end

--- Updates colored text captions on labels adjacent to a switch element after a state change.
--- @param switch_element LuaGuiElement
--- @param left_text string
--- @param right_text string
function gui_components.update_switch_labels(switch_element, left_text, right_text)
    if not (switch_element and switch_element.valid and switch_element.parent) then return end
    local children = switch_element.parent.children
    local left_label = children[1]
    local right_label = children[3]
    local is_left = (switch_element.switch_state == "left")

    if left_label and left_label.valid and left_text then
        left_label.caption = gui_components.format_active_label(left_text, is_left)
    end
    if right_label and right_label.valid and right_text then
        right_label.caption = gui_components.format_active_label(right_text, not is_left)
    end
end

--- Helper to serialize/normalize a circuit condition structure.
--- @param condition_table table|nil
--- @return table
function gui_components.parse_condition(condition_table)
    local cond = condition_table or {}
    return {
        first_signal = cond.first_signal,
        comparator = cond.comparator or "=",
        constant = tonumber(cond.constant) or 0
    }
end

--- Updates the signal field of a condition table in-place or returns a new condition table.
--- @param condition_table table|nil
--- @param signal SignalID|nil
--- @return table
function gui_components.update_condition_signal(condition_table, signal)
    condition_table = condition_table or { first_signal = nil, comparator = "=", constant = 0 }
    condition_table.first_signal = signal
    return condition_table
end

--- Updates the comparator field of a condition table.
--- @param condition_table table|nil
--- @param comparator string|nil
--- @return table
function gui_components.update_condition_comparator(condition_table, comparator)
    condition_table = condition_table or { first_signal = nil, comparator = "=", constant = 0 }
    condition_table.comparator = comparator or "="
    return condition_table
end

--- Updates the constant field of a condition textfield.
--- @param condition_table table|nil
--- @param text_value string|number|nil
--- @return table
function gui_components.update_condition_constant(condition_table, text_value)
    condition_table = condition_table or { first_signal = nil, comparator = "=", constant = 0 }
    condition_table.constant = tonumber(text_value) or 0
    return condition_table
end

return gui_components