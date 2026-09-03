local gui_components = {}

gui_components.COMPARATORS = { "=", "≥", "≤", ">", "<", "≠" }
gui_components.COLOR_ACTIVE = "[color=255,174,0]"
gui_components.COLOR_INACTIVE = "[color=160,160,160]"
gui_components.COLOR_END = "[/color]"

--- Returns the 1-based index of a comparator string in COMPARATORS.
--- @param comp string|nil
--- @return integer
function gui_components.get_comparator_index(comp)
    for i, v in ipairs(gui_components.COMPARATORS) do
        if v == comp then return i end
    end
    return 1
end

--- Returns the comparator string at the given index.
--- @param index integer|nil
--- @return string
function gui_components.get_comparator_by_index(index)
    return gui_components.COMPARATORS[index] or "="
end

--- Formats caption text with active or inactive color tags.
--- @param text string
--- @param is_active boolean
--- @return string
function gui_components.format_active_label(text, is_active)
    if is_active then
        return gui_components.COLOR_ACTIVE .. text .. gui_components.COLOR_END
    else
        return gui_components.COLOR_INACTIVE .. text .. gui_components.COLOR_END
    end
end

--- Creates a main GUI frame window for a player.
--- Supports both centered screen frames and relative anchored frames.
--- @param player LuaPlayer
--- @param anchor_spec table|nil Optional relative anchor spec (e.g. { gui = defines.relative_gui_type.container_gui, position = defines.relative_gui_position.right })
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
            anchor = anchor_spec
        }
    else
        main_frame = player.gui.screen.add{
            type = "frame",
            name = frame_name,
            direction = "vertical"
        }
        main_frame.auto_center = true
    end

    return main_frame
end

--- Adds a standard titlebar header with title, drag handle, and close button.
--- @param parent_frame LuaGuiElement
--- @param title_text string
--- @param close_button_name string|nil
--- @param tags table|nil
--- @return LuaGuiElement title_flow, LuaGuiElement|nil close_button
function gui_components.add_header(parent_frame, title_text, close_button_name, tags)
    local title_flow = parent_frame.add{ type = "flow", direction = "horizontal" }
    title_flow.style.vertical_align = "center"

    title_flow.add{
        type = "label",
        style = "frame_title",
        caption = title_text or ""
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
--- @param config table Table with optional read_red_name, read_green_name, read_red_state, read_green_state, spacing, tags
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
--- Includes Circuit Enable checkbox, signal selector, comparator dropdown, and constant textfield.
--- @param parent LuaGuiElement
--- @param config table Configuration table
--- @return LuaGuiElement circuit_flow, table elements_map
function gui_components.add_circuit_condition_panel(parent, config)
    config = config or {}
    local circuit_flow = parent.add{ type = "flow", direction = "horizontal" }
    circuit_flow.style.vertical_align = "center"
    circuit_flow.style.horizontal_spacing = config.spacing or 6

    local cb = circuit_flow.add{
        type = "checkbox",
        name = config.checkbox_name or "use_circuit_enable",
        caption = config.checkbox_caption or "Circuit Enable",
        state = config.checkbox_state or false,
        tags = config.tags
    }

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
    comp_dropdown.style.width = config.comparator_width or 40

    local const_tf = circuit_flow.add{
        type = "textfield",
        name = config.constant_textfield_name or "circuit_constant",
        text = tostring(constant),
        numeric = true,
        allow_negative = true,
        tags = config.tags
    }
    const_tf.style.width = config.constant_width or 50

    return circuit_flow, {
        checkbox = cb,
        signal_button = signal_btn,
        comparator_dropdown = comp_dropdown,
        constant_textfield = const_tf
    }
end

--- Adds a single item filter slot with item selector and comparator dropdown.
--- @param parent LuaGuiElement
--- @param config table Configuration table
--- @return LuaGuiElement slot_column, LuaGuiElement elem_btn, LuaGuiElement dropdown
function gui_components.add_filter_slot(parent, config)
    config = config or {}
    local slot_column = parent.add{ type = "flow", direction = "vertical" }
    slot_column.style.horizontal_align = "center"
    slot_column.style.vertical_spacing = config.spacing or 2

    local elem_btn = slot_column.add{
        type = "choose-elem-button",
        name = config.button_name or "filter_item_button",
        elem_type = "item",
        item = config.item,
        tags = config.tags
    }

    local dropdown = slot_column.add{
        type = "drop-down",
        name = config.dropdown_name or "filter_comparator_dropdown",
        items = gui_components.COMPARATORS,
        selected_index = gui_components.get_comparator_index(config.comparator or "="),
        tags = config.tags
    }
    dropdown.style.width = config.dropdown_width or 40

    return slot_column, elem_btn, dropdown
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

--- Updates the constant field of a condition table from text or number input.
--- @param condition_table table|nil
--- @param text_value string|number|nil
--- @return table
function gui_components.update_condition_constant(condition_table, text_value)
    condition_table = condition_table or { first_signal = nil, comparator = "=", constant = 0 }
    condition_table.constant = tonumber(text_value) or 0
    return condition_table
end

return gui_components