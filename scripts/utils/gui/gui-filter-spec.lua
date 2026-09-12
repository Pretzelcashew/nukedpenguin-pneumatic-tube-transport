local gui_filter_spec = {}

gui_filter_spec.COMPARATORS = { "=", "≥", "≤", ">", "<", "≠" }
gui_filter_spec.QUALITY_COMPARATORS = { "Any", ">", "<", "=", "≥", "≤", "≠" }
gui_filter_spec.QUALITY_TIERS = { "normal", "uncommon", "rare", "epic", "legendary" }

gui_filter_spec.COLOR_ACTIVE = "[color=255,174,0]"
gui_filter_spec.COLOR_INACTIVE = "[color=160,160,160]"
gui_filter_spec.COLOR_WHITE = "[color=255,255,255]"
gui_filter_spec.COLOR_BLUE = "[color=100,200,255]"
gui_filter_spec.COLOR_END = "[/color]"

--- Returns the 1-based index of a comparator string in COMPARATORS.
--- @param comp string|nil
--- @return integer
function gui_filter_spec.get_comparator_index(comp)
    for i, v in ipairs(gui_filter_spec.COMPARATORS) do
        if v == comp then return i end
    end
    return 1
end

--- Returns the comparator string at the given index.
--- @param index integer|nil
--- @return string
function gui_filter_spec.get_comparator_by_index(index)
    return gui_filter_spec.COMPARATORS[index] or "="
end

--- Returns the 1-based index of a quality comparator string in QUALITY_COMPARATORS.
--- @param comp string|nil
--- @return integer
function gui_filter_spec.get_quality_comparator_index(comp)
    if comp == "Any" or comp == "Any Quality" or comp == "any" then return 1 end
    for i, v in ipairs(gui_filter_spec.QUALITY_COMPARATORS) do
        if v == comp then return i end
    end
    return 1
end

--- Returns the quality comparator string at the given index.
--- @param index integer|nil
--- @return string
function gui_filter_spec.get_quality_comparator_by_index(index)
    return gui_filter_spec.QUALITY_COMPARATORS[index] or "Any"
end

--- Safely returns a validated sprite path for a quality tier or wildcard symbol.
--- Returns our registered 'pneumatic_any_quality_badge' sprite prototype.
--- @param quality_name string|nil
--- @return string|nil
function gui_filter_spec.get_quality_sprite(quality_name)
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
function gui_filter_spec.format_active_label(text, is_active)
    if is_active then
        return gui_filter_spec.COLOR_ACTIVE .. text .. gui_filter_spec.COLOR_END
    else
        return gui_filter_spec.COLOR_INACTIVE .. text .. gui_filter_spec.COLOR_END
    end
end

--- Formats caption text with white color tags for high-contrast slot button overlay rendering.
--- @param text string
--- @return string
function gui_filter_spec.format_white_label(text)
    return gui_filter_spec.COLOR_WHITE .. (text or "") .. gui_filter_spec.COLOR_END
end

--- Extracts item name and quality string from a string or table item specifier.
--- @param item_value string|table|nil
--- @return string|nil item_name, string|nil quality_name
function gui_filter_spec.get_item_name_and_quality(item_value)
    if not item_value then return nil, nil end
    if type(item_value) == "table" then
        return item_value.name, item_value.quality
    elseif type(item_value) == "string" then
        return item_value, nil
    end
    return nil, nil
end

--- Evaluates a filter entry (item, comparator, quality) and returns a standardized display specification.
--- Unifies filter element resolution across GUI slot buttons and Alt-Mode world overlay renderers.
--- @param item string|table|nil Item name or specifier table
--- @param comparator string|nil Comparator string ("Any", "Any Quality", ">", "<", "=", "≥", "≤", "≠")
--- @param quality string|nil Quality tier ("normal", "uncommon", "rare", "epic", "legendary")
--- @return table display_spec
function gui_filter_spec.get_filter_display_spec(item, comparator, quality)
    local item_name = (type(item) == "table" and item.name) or (type(item) == "string" and item or nil)
    local comp = comparator or "Any"
    local qual = quality or "normal"

    local has_item = (item_name ~= nil and item_name ~= "")
    local is_any_comp = (comp == "Any" or comp == "Any Quality")
    local has_quality = (not is_any_comp) or (qual ~= "normal")
    local show_comp = (comp ~= "=" and not is_any_comp)

    local main_sprite = nil
    if has_item then
        main_sprite = "item/" .. item_name
    elseif has_quality and (comp == "=" or is_any_comp) then
        main_sprite = gui_filter_spec.get_quality_sprite(qual)
    end

    local badge_sprite = nil
    if has_item then
        if is_any_comp then
            badge_sprite = gui_filter_spec.get_quality_sprite("any")
        elseif show_comp then
            badge_sprite = gui_filter_spec.get_quality_sprite(qual)
        elseif qual and qual ~= "" and qual ~= "normal" then
            badge_sprite = gui_filter_spec.get_quality_sprite(qual)
        end
    elseif has_quality and show_comp then
        badge_sprite = gui_filter_spec.get_quality_sprite(qual)
    end

    return {
        has_item = has_item,
        has_quality = has_quality,
        is_active = (has_item or has_quality),
        item_name = item_name,
        comparator = comp,
        quality = qual,
        show_comp = show_comp,
        comp_text = show_comp and comp or nil,
        main_sprite = main_sprite,
        badge_sprite = badge_sprite,
        is_standalone_quality = (not has_item and has_quality)
    }
end

--- Extracts up to max_count active filter entries from a port filter table,
--- returning a list of filter display specifications.
--- @param filter_slots table|nil List of filter slot tables from port settings
--- @param max_count integer|nil Maximum filters to extract (default 4)
--- @return table active_specs Array of display_spec tables
function gui_filter_spec.get_active_filters(filter_slots, max_count)
    local active_specs = {}
    local limit = max_count or 4
    if not filter_slots then return active_specs end

    for j = 1, #filter_slots do
        local slot = filter_slots[j]
        if slot then
            local spec = gui_filter_spec.get_filter_display_spec(slot.item, slot.comparator, slot.quality)
            if spec.is_active then
                table.insert(active_specs, spec)
                if #active_specs >= limit then break end
            end
        end
    end

    return active_specs
end

--- Resets a filter slot data structure back to its unassigned default state.
--- @param filter_data table|nil
--- @return table
function gui_filter_spec.clear_filter_slot(filter_data)
    filter_data = filter_data or {}
    filter_data.comparator = "Any Quality"
    filter_data.quality = "normal"
    filter_data.item = nil
    filter_data.explicit_quality = nil
    return filter_data
end

--- Reusable event handler for clicks on overlay slot buttons.
--- Automatically clears the slot on right-click or returns "open_config" on left-click.
--- @param event table GUI event object from on_gui_click
--- @param filter_data table Filter slot data structure
--- @return string action "cleared" | "open_config"
function gui_filter_spec.handle_overlay_slot_click(event, filter_data)
    if event and event.button == defines.mouse_button_type.right then
        gui_filter_spec.clear_filter_slot(filter_data)
        return "cleared"
    end
    return "open_config"
end

--- Reusable handler for item selection changes on filter slots.
--- Applies native Factorio quality rules: defaults to '=' + 'normal' only if the slot is currently blank ("Any Quality").
--- If a comparator/quality is already configured, selecting an item leaves them untouched.
--- Clearing an item removes the item selection while preserving any explicitly configured quality settings.
--- @param filter_data table Filter slot data structure
--- @param new_item string|table|nil The newly selected item
--- @return table filter_data
function gui_filter_spec.handle_filter_item_change(filter_data, new_item)
    filter_data = filter_data or {}
    if new_item then
        local comp = filter_data.comparator
        if comp == "Any Quality" or comp == "Any" or comp == nil then
            filter_data.comparator = "="
            filter_data.quality = "normal"
        end
        filter_data.explicit_quality = true
        filter_data.item = new_item
    else
        filter_data.item = nil
        if filter_data.comparator == "Any Quality" or filter_data.comparator == "Any" or filter_data.comparator == nil then
            filter_data.comparator = "Any Quality"
            filter_data.quality = "normal"
            filter_data.explicit_quality = nil
        end
    end
    return filter_data
end

return gui_filter_spec
