local events = require("scripts.events")
local diverter_settings = require("scripts.diverter-settings")

local diverter_gui = {}

local GUI_FRAME_NAME = "diverter_configuration_frame"
local PORT_DIRECTIONS = { "North", "East", "South", "West" }
local COMPARATORS = { "=", "≥", "≤", ">", "<", "≠" }

local COLOR_ACTIVE = "[color=255,174,0]"
local COLOR_INACTIVE = "[color=160,160,160]"
local COLOR_END = "[/color]"

local function get_comparator_index(comp)
    for i, v in ipairs(COMPARATORS) do
        if v == comp then return i end
    end
    return 1
end

function diverter_gui.close(player)
    if player.gui.screen[GUI_FRAME_NAME] then
        player.gui.screen[GUI_FRAME_NAME].destroy()
    end
    if player.opened and player.opened.valid and player.opened.name == GUI_FRAME_NAME then
        player.opened = nil
    end
end

function diverter_gui.open(player, entity)
    if not (player and player.valid and entity and entity.valid) then return end

    diverter_gui.close(player)

    local settings = diverter_settings.get(entity.unit_number)

    local main_frame = player.gui.screen.add{
        type = "frame",
        name = GUI_FRAME_NAME,
        direction = "vertical"
    }
    main_frame.auto_center = true

    -- Titlebar
    local title_flow = main_frame.add{ type = "flow", direction = "horizontal" }
    title_flow.style.vertical_align = "center"

    title_flow.add{
        type = "label",
        style = "frame_title",
        caption = "Pneumatic Diverter Configuration"
    }

    local drag_spacer = title_flow.add{
        type = "empty-widget",
        style = "draggable_space"
    }
    drag_spacer.style.horizontally_stretchable = true
    drag_spacer.style.vertically_stretchable = true
    drag_spacer.drag_target = main_frame

    title_flow.add{
        type = "sprite-button",
        name = "diverter_close_button",
        style = "frame_action_button",
        sprite = "utility/close",
        tags = { unit_number = entity.unit_number }
    }

    -- 2x2 Port Grid Layout
    local inner_frame = main_frame.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding"
    }

    local grid_table = inner_frame.add{
        type = "table",
        column_count = 2,
        horizontal_spacing = 12,
        vertical_spacing = 12
    }

    for i = 1, 4 do
        local port_data = settings.ports[i]
        local dir_name = PORT_DIRECTIONS[i] or ("Port " .. i)

        local card_frame = grid_table.add{
            type = "frame",
            direction = "vertical",
            style = "bordered_frame"
        }

        -- Port Enable Checkbox Header
        local header_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        header_flow.add{
            type = "checkbox",
            name = "port_enable",
            caption = "Port " .. i .. " (" .. dir_name .. ")",
            state = port_data.enabled,
            tags = { unit_number = entity.unit_number, port_index = i }
        }

        -- Item Flow Direction Toggle (Pull vs Push)
        local is_pull = (port_data.mode == "input")
        local dir_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        dir_flow.style.vertical_align = "center"
        dir_flow.style.horizontal_spacing = 6

        dir_flow.add{
            type = "label",
            caption = (is_pull and COLOR_ACTIVE or COLOR_INACTIVE) .. "Pull (Input)" .. COLOR_END
        }

        dir_flow.add{
            type = "switch",
            name = "port_direction_switch",
            allow_none = false,
            switch_state = is_pull and "left" or "right",
            tags = { unit_number = entity.unit_number, port_index = i }
        }

        dir_flow.add{
            type = "label",
            caption = ((not is_pull) and COLOR_ACTIVE or COLOR_INACTIVE) .. "Push (Output)" .. COLOR_END
        }

        card_frame.add{ type = "line", direction = "horizontal" }

        -- Use Filters Checkbox
        local filter_enable_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        filter_enable_flow.style.vertical_align = "center"
        filter_enable_flow.add{
            type = "checkbox",
            name = "port_use_filters",
            caption = "Use filters",
            state = port_data.use_filters,
            tags = { unit_number = entity.unit_number, port_index = i }
        }

        -- Vanilla Whitelist / Blacklist Toggle
        local is_whitelist = (port_data.filter_mode == "whitelist")
        local filter_mode_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        filter_mode_flow.style.vertical_align = "center"
        filter_mode_flow.style.horizontal_spacing = 6

        filter_mode_flow.add{
            type = "label",
            caption = (is_whitelist and COLOR_ACTIVE or COLOR_INACTIVE) .. "Whitelist" .. COLOR_END
        }

        filter_mode_flow.add{
            type = "switch",
            name = "port_filter_mode_switch",
            allow_none = false,
            switch_state = is_whitelist and "left" or "right",
            tags = { unit_number = entity.unit_number, port_index = i }
        }

        filter_mode_flow.add{
            type = "label",
            caption = ((not is_whitelist) and COLOR_ACTIVE or COLOR_INACTIVE) .. "Blacklist" .. COLOR_END
        }

        -- Filter Slots: Item Picker Button top, Micro Comparator Dropdown bottom
        local slots_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        slots_flow.style.horizontal_spacing = 8

        for j = 1, 5 do
            local filter_data = port_data.filters[j] or { comparator = "=", item = nil }
            local slot_column = slots_flow.add{ type = "flow", direction = "vertical" }
            slot_column.style.horizontal_align = "center"
            slot_column.style.vertical_spacing = 2

            slot_column.add{
                type = "choose-elem-button",
                elem_type = "item",
                item = filter_data.item,
                tags = { unit_number = entity.unit_number, port_index = i, slot_index = j }
            }

            local dropdown = slot_column.add{
                type = "drop-down",
                name = "filter_comparator_dropdown",
                items = COMPARATORS,
                selected_index = get_comparator_index(filter_data.comparator),
                tags = { unit_number = entity.unit_number, port_index = i, slot_index = j }
            }
            dropdown.style.width = 40
        end
    end

    player.opened = main_frame
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name == "diverter_close_button" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            diverter_gui.close(player)
        end
    end
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_enable" then
        port.enabled = element.state
    elseif element.name == "port_use_filters" then
        port.use_filters = element.state
    end
end

local function on_gui_switch_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not port then return end

    local parent_children = element.parent.children
    local left_label = parent_children[1]
    local right_label = parent_children[3]

    if element.name == "port_direction_switch" then
        local is_pull = (element.switch_state == "left")
        port.mode = is_pull and "input" or "output"

        if left_label and left_label.valid then
            left_label.caption = (is_pull and COLOR_ACTIVE or COLOR_INACTIVE) .. "Pull (Input)" .. COLOR_END
        end
        if right_label and right_label.valid then
            right_label.caption = ((not is_pull) and COLOR_ACTIVE or COLOR_INACTIVE) .. "Push (Output)" .. COLOR_END
        end

    elseif element.name == "port_filter_mode_switch" then
        local is_whitelist = (element.switch_state == "left")
        port.filter_mode = is_whitelist and "whitelist" or "blacklist"

        if left_label and left_label.valid then
            left_label.caption = (is_whitelist and COLOR_ACTIVE or COLOR_INACTIVE) .. "Whitelist" .. COLOR_END
        end
        if right_label and right_label.valid then
            right_label.caption = ((not is_whitelist) and COLOR_ACTIVE or COLOR_INACTIVE) .. "Blacklist" .. COLOR_END
        end
    end
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index and tags.slot_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not (port and port.filters[tags.slot_index]) then return end

    port.filters[tags.slot_index].item = element.elem_value
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index and tags.slot_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not (port and port.filters[tags.slot_index]) then return end

    if element.name == "filter_comparator_dropdown" then
        port.filters[tags.slot_index].comparator = COMPARATORS[element.selected_index] or "="
    end
end

local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.custom then
        local element = event.element
        if element and element.valid and element.name == GUI_FRAME_NAME then
            local player = game.get_player(event.player_index)
            if player and player.valid then
                diverter_gui.close(player)
            end
        end
    end
end

events.on_event(defines.events.on_gui_click, on_gui_click)
events.on_event(defines.events.on_gui_closed, on_gui_closed)
events.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
events.on_event(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
events.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
events.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)

return diverter_gui