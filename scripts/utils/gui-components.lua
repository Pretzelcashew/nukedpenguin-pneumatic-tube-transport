local gui_components = {}

gui_components.COMPARATORS = { "=", "≥", "≤", ">", "<", "≠" }
gui_components.QUALITY_COMPARATORS = { "Any", ">", "<", "=", "≥", "≤", "≠" }
gui_components.QUALITY_TIERS = { "normal", "uncommon", "rare", "epic", "legendary" }

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

--- Returns the 1-based index of a quality comparator string in QUALITY_COMPARATORS.
--- @param comp string|nil
--- @return integer
function gui_components.get_quality_comparator_index(comp)
    if comp == "Any" or comp == "Any Quality" or comp == "any" then return 1 end
    for i, v in ipairs(gui_components.QUALITY_COMPARATORS) do
        if v == comp then return i end
    end
    return 1
end

--- Returns the quality comparator string at the given index.
--- @param index integer|nil
--- @return string
function gui_components.get_quality_comparator_by_index(index)
    return gui_components.QUALITY_COMPARATORS[index] or "Any"
end

--- Safely returns a validated sprite path for a quality tier or wildcard symbol.
--- Returns our registered 'pneumatic_any_quality_badge' sprite prototype.
--- @param quality_name string|nil
--- @return string|nil
function gui_components.get_quality_sprite(quality_name)
    -- Handle Wildcard / Any Quality requests
    if not quality_name or quality_name == "" or quality_name == "any" or quality_name == "Any Quality" or quality_name == "quality/any" then
        if helpers and helpers.is_valid_sprite_path("pneumatic_any_quality_badge") then
            return "pneumatic_any_quality_badge"
        elseif helpers and helpers.is_valid_sprite_path("quality/quality-unknown") then
            return "quality/quality-unknown"
        elseif helpers and helpers.is_valid_sprite_path("utility/quality_icon") then
            return "utility/quality_icon"
        end
        return "pneumatic_any_quality_badge"
    end

    -- Handle specific quality tiers (normal, uncommon, rare, epic, legendary)
    local name_str = tostring(quality_name)
    local path = name_str:sub(1, 8) == "quality/" and name_str or ("quality/" .. name_str)
    if helpers and helpers.is_valid_sprite_path(path) then
        return path
    end

    if quality_name == "normal" and helpers and helpers.is_valid_sprite_path("quality/normal") then
        return "quality/normal"
    end

    return nil
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

--- Extracts item name and quality string from a string or table item specifier.
--- @param item_value string|table|nil
--- @return string|nil item_name, string|nil quality_name
function gui_components.get_item_name_and_quality(item_value)
    if not item_value then return nil, nil end
    if type(item_value) == "table" then
        return item_value.name, item_value.quality
    elseif type(item_value) == "string" then
        return item_value, nil
    end
    return nil, nil
end

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
    comp_dropdown.style.width = config.comparator_width or 40

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
--- @param parent LuaGuiElement
--- @param config table Configuration table: { button_name, item, comparator, quality, is_selected, tags, width, height }
--- @return LuaGuiElement button
function gui_components.create_overlay_slot_button(parent, config)
    config = config or {}
    local item_name = (type(config.item) == "table" and config.item.name) or (type(config.item) == "string" and config.item or nil)
    local sprite_path = (item_name and item_name ~= "") and ("item/" .. item_name) or ""

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
        sprite = sprite_path,
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

--- Updates an existing overlay slot button's item sprite, comparator badge, and quality icon.
--- Uses pneumatic_any_quality_badge for wildcard quality overlay rendering.
--- @param button LuaGuiElement
--- @param item string|table|nil Item name or specifier
--- @param comparator string|nil Comparator string ("Any", "Any Quality", ">", "<", "=", "≥", "≤", "≠")
--- @param quality string|nil Quality tier ("normal", "uncommon", "rare", "epic", "legendary")
--- @param is_selected boolean|nil Active selection highlight state
function gui_components.update_overlay_slot_button(button, item, comparator, quality, is_selected)
    if not (button and button.valid) then return end

    local item_name = (type(item) == "table" and item.name) or (type(item) == "string" and item or nil)
    button.sprite = (item_name and item_name ~= "") and ("item/" .. item_name) or ""

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

    local comp = comparator or "Any"
    local qual = quality or "normal"

    if comp == "Any" or comp == "Any Quality" then
        if item_name then
            local q_sprite_path = gui_components.get_quality_sprite("any")
            if q_sprite_path then
                local q_sprite = bottom_flow.add{
                    type = "sprite",
                    name = "quality_badge",
                    sprite = q_sprite_path,
                    ignored_by_interaction = true
                }
                q_sprite.style.width = 12
                q_sprite.style.height = 12
                q_sprite.style.stretch_image_to_widget_size = true
            end
        end
    else
        local badge_label = bottom_flow.add{
            type = "label",
            name = "comparator_badge",
            caption = gui_components.format_active_label(comp, true),
            ignored_by_interaction = true
        }
        badge_label.style.font = "default-semibold"
        badge_label.style.padding = 0
        badge_label.style.margin = 0
        badge_label.style.top_margin = -3

        if (qual and qual ~= "" and qual ~= "normal") or (not item_name) then
            local q_sprite_path = gui_components.get_quality_sprite(qual)
            if q_sprite_path then
                local q_sprite = bottom_flow.add{
                    type = "sprite",
                    name = "quality_badge",
                    sprite = q_sprite_path,
                    ignored_by_interaction = true
                }
                q_sprite.style.width = 12
                q_sprite.style.height = 12
                q_sprite.style.stretch_image_to_widget_size = true
            end
        end
    end
end

--- Adds the Factorio 2.0 Native Item & Quality Selector Control Bar Layout.
--- Uses rich text tag [img=pneumatic_any_quality_badge] for the dropdown wildcard icon.
--- @param parent LuaGuiElement
--- @param config table Configuration table: { comparator, quality, tags }
--- @return LuaGuiElement bar_frame, table elements_map
function gui_components.add_quality_control_bar(parent, config)
    config = config or {}
    local curr_comp = config.comparator or "Any"
    local curr_qual = config.quality or "normal"

    local deep_frame = parent.add{
        type = "frame",
        direction = "horizontal",
        style = "deep_frame_in_shallow_frame"
    }
    deep_frame.style.padding = 4
    deep_frame.style.horizontally_stretchable = true

    local bar_flow = deep_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    bar_flow.style.vertical_align = "center"
    bar_flow.style.horizontal_spacing = 8
    bar_flow.style.horizontally_stretchable = true

    local dropdown_items = {
        "[img=pneumatic_any_quality_badge]",
        ">",
        "<",
        "=",
        "≥",
        "≤",
        "≠"
    }

    local comp_dd = bar_flow.add{
        type = "drop-down",
        name = "quality_comparator_dropdown",
        items = dropdown_items,
        selected_index = gui_components.get_quality_comparator_index(curr_comp),
        tags = config.tags
    }
    comp_dd.style.width = 68

    local radio_flow = bar_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    radio_flow.style.horizontal_spacing = 0

    local radio_buttons = {}
    for i, tier in ipairs(gui_components.QUALITY_TIERS) do
        local capital_tier = tier:sub(1,1):upper() .. tier:sub(2)

        local btn_style = "slot_button"
        if tier == curr_qual then
            if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
                btn_style = "flib_selected_slot_button"
            else
                btn_style = "yellow_slot_button"
            end
        end

        local q_sprite_path = gui_components.get_quality_sprite(tier) or ""

        local btn = radio_flow.add{
            type = "sprite-button",
            name = "quality_tier_radio_" .. tier,
            sprite = q_sprite_path,
            style = btn_style,
            tooltip = "Quality: " .. capital_tier,
            tags = config.tags
        }
        btn.style.width = 28
        btn.style.height = 28
        btn.style.padding = 4

        radio_buttons[tier] = btn
    end

    local spacer = bar_flow.add{ type = "empty-widget" }
    spacer.style.horizontally_stretchable = true

    local confirm_btn = bar_flow.add{
        type = "sprite-button",
        name = "quality_confirm_button",
        sprite = "utility/check_mark",
        style = "confirm_button",
        tooltip = "Confirm (E)",
        tags = config.tags
    }
    confirm_btn.style.width = 28
    confirm_btn.style.height = 28

    return deep_frame, {
        comparator_dropdown = comp_dd,
        quality_buttons = radio_buttons,
        confirm_button = confirm_btn
    }
end

--- Updates the visual selection style of quality tier radio buttons inside a container frame.
--- @param container LuaGuiElement Parent container containing quality_tier_radio_ buttons
--- @param selected_tier string The active quality tier ("normal", "uncommon", etc.)
function gui_components.update_quality_tier_selection(container, selected_tier)
    if not (container and container.valid) then return end
    for _, tier in ipairs(gui_components.QUALITY_TIERS) do
        local btn_name = "quality_tier_radio_" .. tier
        local btn = container[btn_name]
        if not (btn and btn.valid) then
            -- Fallback search if nested inside inner flows
            local function find_btn(elem)
                if not (elem and elem.valid) then return nil end
                if elem.name == btn_name then return elem end
                for _, child in ipairs(elem.children) do
                    local found = find_btn(child)
                    if found then return found end
                end
                return nil
            end
            btn = find_btn(container)
        end

        if btn and btn.valid then
            local b_style = "slot_button"
            if tier == selected_tier then
                if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
                    b_style = "flib_selected_slot_button"
                else
                    b_style = "yellow_slot_button"
                end
            end
            btn.style = b_style
            btn.style.width = 28
            btn.style.height = 28
            btn.style.padding = 4
        end
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