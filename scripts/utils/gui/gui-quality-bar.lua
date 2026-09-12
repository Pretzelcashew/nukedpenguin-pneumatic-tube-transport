local gui_filter_spec = require("scripts.utils.gui.gui-filter-spec")

local gui_quality_bar = {}

--- Adds the Factorio 2.0 Native Item & Quality Selector Control Bar Layout.
--- Uses rich text tag [img=pneumatic_any_quality_badge] for the dropdown wildcard icon.
--- @param parent LuaGuiElement
--- @param config table Configuration table: { comparator, quality, tags }
--- @return LuaGuiElement bar_frame, table elements_map
function gui_quality_bar.add_quality_control_bar(parent, config)
    config = config or {}
    local curr_comp = config.comparator or "Any"
    local curr_qual = config.quality or "normal"
    local is_any = (curr_comp == "Any" or curr_comp == "Any Quality")

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
        selected_index = gui_filter_spec.get_quality_comparator_index(curr_comp),
        tags = config.tags
    }
    comp_dd.style.width = 68

    local radio_flow = bar_flow.add{
        type = "flow",
        direction = "horizontal"
    }
    radio_flow.style.horizontal_spacing = 0

    local radio_buttons = {}
    for _, tier in ipairs(gui_filter_spec.QUALITY_TIERS) do
        local capital_tier = tier:sub(1,1):upper() .. tier:sub(2)

        local btn_style = "slot_button"
        if (not is_any) and (tier == curr_qual) then
            if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
                btn_style = "flib_selected_slot_button"
            else
                btn_style = "yellow_slot_button"
            end
        end

        local q_sprite_path = gui_filter_spec.get_quality_sprite(tier) or ""

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
        tooltip = "Confirm",
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

--- Updates both dropdown selection and quality tier radio button highlights in a container frame.
--- If comparator is "Any" or "Any Quality", unselects all quality tier buttons.
--- @param container LuaGuiElement Parent container containing quality_comparator_dropdown and quality_tier_radio_ buttons
--- @param comparator string|nil Comparator string ("Any", "Any Quality", "=", ">", etc.)
--- @param quality string|nil Active quality tier ("normal", "uncommon", etc.)
function gui_quality_bar.update_quality_control_bar(container, comparator, quality)
    if not (container and container.valid) then return end

    local is_any = (comparator == "Any" or comparator == "Any Quality")

    local comp_dd = container["quality_comparator_dropdown"]
    if not (comp_dd and comp_dd.valid) then
        local function find_dd(elem)
            if not (elem and elem.valid) then return nil end
            if elem.name == "quality_comparator_dropdown" then return elem end
            for _, child in ipairs(elem.children) do
                local found = find_dd(child)
                if found then return found end
            end
            return nil
        end
        comp_dd = find_dd(container)
    end

    if comp_dd and comp_dd.valid then
        comp_dd.selected_index = gui_filter_spec.get_quality_comparator_index(comparator)
    end

    for _, tier in ipairs(gui_filter_spec.QUALITY_TIERS) do
        local btn_name = "quality_tier_radio_" .. tier
        local btn = container[btn_name]
        if not (btn and btn.valid) then
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
            if (not is_any) and (tier == quality) then
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

--- Updates the visual selection style of quality tier radio buttons inside a container frame.
--- @param container LuaGuiElement Parent container
--- @param selected_tier string The active quality tier ("normal", "uncommon", etc.)
--- @param comparator string|nil Optional comparator ("Any Quality", "=", etc.)
function gui_quality_bar.update_quality_tier_selection(container, selected_tier, comparator)
    gui_quality_bar.update_quality_control_bar(container, comparator, selected_tier)
end

--- Encapsulates the native-like behavior when a quality tier button is clicked.
--- If current comparator is "Any Quality" / "Any", clicking a quality tier automatically switches the comparator to "=".
--- @param container LuaGuiElement Parent container frame
--- @param current_comparator string|nil Current comparator string
--- @param clicked_tier string The quality tier string clicked by the player
--- @return string new_comparator, string new_quality
function gui_quality_bar.handle_quality_tier_click(container, current_comparator, clicked_tier)
    local comp = current_comparator or "Any Quality"
    local qual = clicked_tier or "normal"

    if comp == "Any" or comp == "Any Quality" then
        comp = "="
    end

    gui_quality_bar.update_quality_control_bar(container, comp, qual)
    return comp, qual
end

--- Encapsulates the native-like behavior when the quality comparator dropdown choice changes.
--- Native behavior: Selecting "Any Quality" resets the remembered quality tier back to "normal".
--- @param container LuaGuiElement Parent container frame
--- @param selected_index integer Dropdown selected index
--- @param current_quality string|nil Current active quality tier
--- @return string new_comparator, string new_quality
function gui_quality_bar.handle_quality_comparator_change(container, selected_index, current_quality)
    local comp = gui_filter_spec.get_quality_comparator_by_index(selected_index)
    local qual = current_quality or "normal"

    if comp == "Any" or comp == "Any Quality" then
        qual = "normal"
    end

    gui_quality_bar.update_quality_control_bar(container, comp, qual)
    return comp, qual
end

return gui_quality_bar
