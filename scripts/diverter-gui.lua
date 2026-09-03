local events = require("scripts.events")
local diverter_settings = require("scripts.diverter-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local gui_components = require("scripts.utils.gui-components")

local diverter_gui = {}

local GUI_FRAME_NAME = "diverter_configuration_frame"
local PORT_DIRECTIONS = { "North", "East", "South", "West" }

local function notify_change(unit_number)
    local entity = storage.active_diverters and storage.active_diverters[unit_number]
    if entity and entity.valid then
        active_device_scanner.notify_settings_changed(entity)
    end
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

    local main_frame = gui_components.create_relative_window(player, nil, GUI_FRAME_NAME)
    if not main_frame then return end

    -- Titlebar Header
    gui_components.add_header(main_frame, "Pneumatic Diverter Configuration", "diverter_close_button", { unit_number = entity.unit_number })

    -- Global Wire Channel Toggles
    gui_components.add_wire_channel_toggles(main_frame, {
        read_red_name = "diverter_read_red",
        read_green_name = "diverter_read_green",
        read_red_state = settings.read_red ~= false,
        read_green_state = settings.read_green ~= false,
        tags = { unit_number = entity.unit_number }
    })

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
        header_flow.style.vertical_align = "center"
        header_flow.add{
            type = "checkbox",
            name = "port_enable",
            caption = "Port " .. i .. " (" .. dir_name .. ")",
            state = port_data.enabled,
            tags = { unit_number = entity.unit_number, port_index = i }
        }

        -- Circuit Network Enable Row
        local cond = port_data.enable_condition or { first_signal = nil, comparator = "=", constant = 0 }
        gui_components.add_circuit_condition_panel(card_frame, {
            checkbox_name = "port_use_circuit_enable",
            checkbox_caption = "Circuit Enable",
            checkbox_state = port_data.use_circuit_enable or false,
            signal = cond.first_signal,
            comparator = cond.comparator or "=",
            constant = cond.constant or 0,
            signal_button_name = "port_circuit_signal",
            comparator_dropdown_name = "port_circuit_comparator",
            constant_textfield_name = "port_circuit_constant",
            tags = { unit_number = entity.unit_number, port_index = i }
        })

        -- Item Flow Direction Toggle (Pull vs Push)
        local is_pull = (port_data.mode == "input")
        gui_components.add_labeled_switch(card_frame, {
            switch_name = "port_direction_switch",
            is_left = is_pull,
            left_label = "Pull (Input)",
            right_label = "Push (Output)",
            tags = { unit_number = entity.unit_number, port_index = i }
        })

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
        gui_components.add_labeled_switch(card_frame, {
            switch_name = "port_filter_mode_switch",
            is_left = is_whitelist,
            left_label = "Whitelist",
            right_label = "Blacklist",
            tags = { unit_number = entity.unit_number, port_index = i }
        })

        -- Filter Slots
        local slots_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        slots_flow.style.horizontal_spacing = 8

        for j = 1, 5 do
            local filter_data = port_data.filters[j] or { comparator = "=", item = nil }
            gui_components.add_filter_slot(slots_flow, {
                button_name = "filter_item_button",
                dropdown_name = "filter_comparator_dropdown",
                item = filter_data.item,
                comparator = filter_data.comparator or "=",
                tags = { unit_number = entity.unit_number, port_index = i, slot_index = j }
            })
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
    if not (tags and tags.unit_number) then return end

    local settings = diverter_settings.get(tags.unit_number)

    if element.name == "diverter_read_red" then
        settings.read_red = element.state
        notify_change(tags.unit_number)
        return
    elseif element.name == "diverter_read_green" then
        settings.read_green = element.state
        notify_change(tags.unit_number)
        return
    end

    if not tags.port_index then return end
    local port = settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_enable" then
        port.enabled = element.state
    elseif element.name == "port_use_circuit_enable" then
        port.use_circuit_enable = element.state
    elseif element.name == "port_use_filters" then
        port.use_filters = element.state
    end

    notify_change(tags.unit_number)
end

local function on_gui_switch_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_direction_switch" then
        local is_pull = (element.switch_state == "left")
        port.mode = is_pull and "input" or "output"
        gui_components.update_switch_labels(element, "Pull (Input)", "Push (Output)")

    elseif element.name == "port_filter_mode_switch" then
        local is_whitelist = (element.switch_state == "left")
        port.filter_mode = is_whitelist and "whitelist" or "blacklist"
        gui_components.update_switch_labels(element, "Whitelist", "Blacklist")
    end

    notify_change(tags.unit_number)
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_circuit_signal" then
        port.enable_condition.first_signal = element.elem_value
        notify_change(tags.unit_number)
        return
    end

    if tags.slot_index and port.filters[tags.slot_index] then
        port.filters[tags.slot_index].item = element.elem_value
        notify_change(tags.unit_number)
    end
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_circuit_comparator" then
        port.enable_condition.comparator = gui_components.get_comparator_by_index(element.selected_index)
        notify_change(tags.unit_number)
        return
    end

    if tags.slot_index and port.filters[tags.slot_index] and element.name == "filter_comparator_dropdown" then
        port.filters[tags.slot_index].comparator = gui_components.get_comparator_by_index(element.selected_index)
        notify_change(tags.unit_number)
    end
end

local function on_gui_text_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_circuit_constant" then
        port.enable_condition.constant = tonumber(element.text) or 0
        notify_change(tags.unit_number)
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
events.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)

return diverter_gui