local events = require("scripts.events")
local diverter_settings = require("scripts.diverter-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local gui_components = require("scripts.utils.gui-components")

local diverter_gui = {}

local GUI_FRAME_NAME = "diverter_configuration_frame"
local SLOT_CONFIG_FRAME_NAME = "filter_slot_config_frame"
local PORT_DIRECTIONS = { "North", "East", "South", "West" }

local function notify_change(unit_number)
    local entity = storage.active_diverters and storage.active_diverters[unit_number]
    if entity and entity.valid then
        active_device_scanner.notify_settings_changed(entity)
    end
end

local function find_element_by_name(element, name)
    if not (element and element.valid) then return nil end
    if element.name == name then return element end
    for _, child in ipairs(element.children) do
        local found = find_element_by_name(child, name)
        if found then return found end
    end
    return nil
end

function diverter_gui.close_slot_config(player)
    if not (player and player.valid) then return end
    local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
    if config_frame and config_frame.valid then
        local tags = config_frame.tags or {}
        if tags.unit_number and tags.port_index and tags.slot_index then
            diverter_gui.refresh_main_slot_button(player, tags.unit_number, tags.port_index, tags.slot_index, false)
        end
        config_frame.destroy()
    end
    local main_frame = player.gui.screen[GUI_FRAME_NAME]
    if main_frame and main_frame.valid then
        player.opened = main_frame
    end
end

function diverter_gui.close(player)
    if not (player and player.valid) then return end
    diverter_gui.close_slot_config(player)
    if player.gui.screen[GUI_FRAME_NAME] then
        player.gui.screen[GUI_FRAME_NAME].destroy()
    end
    if player.opened and player.opened.valid and player.opened.name == GUI_FRAME_NAME then
        player.opened = nil
    end
end

function diverter_gui.refresh_main_slot_button(player, unit_number, port_index, slot_index, is_active)
    if not (player and player.valid) then return end
    local main_frame = player.gui.screen[GUI_FRAME_NAME]
    if not main_frame then return end

    local button_name = "diverter_slot_" .. port_index .. "_" .. slot_index
    local slot_btn = find_element_by_name(main_frame, button_name)
    if slot_btn then
        local settings = diverter_settings.get(unit_number)
        local port = settings and settings.ports and settings.ports[port_index]
        local filter_data = port and port.filters and port.filters[slot_index]
        if filter_data then
            gui_components.update_overlay_slot_button(slot_btn, filter_data.item, filter_data.comparator, filter_data.quality, is_active)
        end
    end
end

function diverter_gui.open_slot_config(player, unit_number, port_index, slot_index)
    if not (player and player.valid) then return end

    diverter_gui.close_slot_config(player)

    local settings = diverter_settings.get(unit_number)
    local port = settings and settings.ports and settings.ports[port_index]
    if not port then return end
    local filter_data = port.filters[slot_index] or { comparator = "Any Quality", quality = "normal", item = nil }

    local config_frame = player.gui.screen.add{
        type = "frame",
        name = SLOT_CONFIG_FRAME_NAME,
        direction = "vertical",
        tags = { unit_number = unit_number, port_index = port_index, slot_index = slot_index }
    }
    config_frame.auto_center = true

    local dir_name = PORT_DIRECTIONS[port_index] or ("Port " .. port_index)
    local title = "Configure Filter (Port " .. port_index .. " - " .. dir_name .. ", Slot " .. slot_index .. ")"
    gui_components.add_header(config_frame, title, "slot_config_close_button", { unit_number = unit_number, port_index = port_index, slot_index = slot_index })

    local card_frame = gui_components.add_card_frame(config_frame, "vertical")

    local item_flow = card_frame.add{ type = "flow", direction = "horizontal" }
    item_flow.style.vertical_align = "center"
    item_flow.style.horizontal_spacing = 10
    item_flow.style.bottom_margin = 8

    item_flow.add{ type = "label", caption = "Item Selection:" }
    item_flow.add{
        type = "choose-elem-button",
        name = "slot_config_item_button",
        elem_type = "item",
        item = filter_data.item,
        tags = { unit_number = unit_number, port_index = port_index, slot_index = slot_index }
    }

    gui_components.add_quality_control_bar(card_frame, {
        comparator = filter_data.comparator or "Any Quality",
        quality = filter_data.quality or "normal",
        tags = { unit_number = unit_number, port_index = port_index, slot_index = slot_index }
    })

    diverter_gui.refresh_main_slot_button(player, unit_number, port_index, slot_index, true)
end

function diverter_gui.open(player, entity)
    if not (player and player.valid and entity and entity.valid) then return end

    diverter_gui.close(player)

    local settings = diverter_settings.get(entity.unit_number)

    local main_frame = gui_components.create_relative_window(player, nil, GUI_FRAME_NAME)
    if not main_frame then return end

    gui_components.add_header(main_frame, "Pneumatic Diverter Configuration", "diverter_close_button", { unit_number = entity.unit_number })

    gui_components.add_wire_channel_toggles(main_frame, {
        read_red_name = "diverter_read_red",
        read_green_name = "diverter_read_green",
        read_red_state = settings.read_red ~= false,
        read_green_state = settings.read_green ~= false,
        tags = { unit_number = entity.unit_number }
    })

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

        local header_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        header_flow.style.vertical_align = "center"
        header_flow.add{
            type = "checkbox",
            name = "port_enable",
            caption = "Port " .. i .. " (" .. dir_name .. ")",
            state = port_data.enabled,
            tags = { unit_number = entity.unit_number, port_index = i }
        }

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

        local is_pull = (port_data.mode == "input")
        gui_components.add_labeled_switch(card_frame, {
            switch_name = "port_direction_switch",
            is_left = is_pull,
            left_label = "Pull (Input)",
            right_label = "Push (Output)",
            tags = { unit_number = entity.unit_number, port_index = i }
        })

        card_frame.add{ type = "line", direction = "horizontal" }

        local filter_enable_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        filter_enable_flow.style.vertical_align = "center"
        filter_enable_flow.add{
            type = "checkbox",
            name = "port_use_filters",
            caption = "Use filters",
            state = port_data.use_filters,
            tags = { unit_number = entity.unit_number, port_index = i }
        }

        local is_whitelist = (port_data.filter_mode == "whitelist")
        gui_components.add_labeled_switch(card_frame, {
            switch_name = "port_filter_mode_switch",
            is_left = is_whitelist,
            left_label = "Whitelist",
            right_label = "Blacklist",
            tags = { unit_number = entity.unit_number, port_index = i }
        })

        local slots_flow = card_frame.add{ type = "flow", direction = "horizontal" }
        slots_flow.style.horizontal_spacing = 6

        for j = 1, 5 do
            local filter_data = port_data.filters[j] or { comparator = "Any Quality", quality = "normal", item = nil }
            gui_components.create_overlay_slot_button(slots_flow, {
                button_name = "diverter_slot_" .. i .. "_" .. j,
                item = filter_data.item,
                comparator = filter_data.comparator or "Any Quality",
                quality = filter_data.quality or "normal",
                tags = {
                    unit_number = entity.unit_number,
                    port_index = i,
                    slot_index = j,
                    slot_button_click = true
                }
            })
        end
    end

    player.opened = main_frame
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags or {}
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    if element.name == "diverter_close_button" then
        diverter_gui.close(player)
        return
    end

    if element.name == "slot_config_close_button" or element.name == "quality_confirm_button" then
        diverter_gui.close_slot_config(player)
        return
    end

    if element.name:find("quality_tier_radio_") then
        local chosen_tier = element.name:gsub("quality_tier_radio_", "")
        if tags.unit_number and tags.port_index and tags.slot_index then
            local settings = diverter_settings.get(tags.unit_number)
            local port = settings and settings.ports and settings.ports[tags.port_index]
            if port and port.filters and port.filters[tags.slot_index] then
                port.filters[tags.slot_index].quality = chosen_tier

                local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
                if config_frame then
                    for _, tier in ipairs(gui_components.QUALITY_TIERS) do
                        local btn = find_element_by_name(config_frame, "quality_tier_radio_" .. tier)
                        if btn then
                            local b_style = "slot_button"
                            if tier == chosen_tier then
                                if helpers and helpers.is_valid_sprite_path("style/flib_selected_slot_button") then
                                    b_style = "flib_selected_slot_button"
                                else
                                    b_style = "yellow_slot_button"
                                end
                            end
                            btn.style = b_style
                            btn.style.width = 28
                            btn.style.height = 28
                            btn.style.padding = 2
                        end
                    end
                end

                diverter_gui.refresh_main_slot_button(player, tags.unit_number, tags.port_index, tags.slot_index, true)
                notify_change(tags.unit_number)
            end
        end
        return
    end

    if tags.slot_button_click and tags.unit_number and tags.port_index and tags.slot_index then
        diverter_gui.open_slot_config(player, tags.unit_number, tags.port_index, tags.slot_index)
        return
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

    local player = game.get_player(event.player_index)
    local settings = diverter_settings.get(tags.unit_number)
    local port = settings and settings.ports and settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_circuit_signal" then
        port.enable_condition.first_signal = element.elem_value
        notify_change(tags.unit_number)
        return
    end

    if element.name == "slot_config_item_button" and tags.slot_index and port.filters[tags.slot_index] then
        port.filters[tags.slot_index].item = element.elem_value
        if player then
            diverter_gui.refresh_main_slot_button(player, tags.unit_number, tags.port_index, tags.slot_index, true)
        end
        notify_change(tags.unit_number)
    end
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number and tags.port_index) then return end

    local player = game.get_player(event.player_index)
    local settings = diverter_settings.get(tags.unit_number)
    local port = settings and settings.ports and settings.ports[tags.port_index]
    if not port then return end

    if element.name == "port_circuit_comparator" then
        port.enable_condition.comparator = gui_components.get_comparator_by_index(element.selected_index)
        notify_change(tags.unit_number)
        return
    end

    if element.name == "quality_comparator_dropdown" and tags.slot_index and port.filters[tags.slot_index] then
        local chosen_comp = gui_components.get_quality_comparator_by_index(element.selected_index)
        port.filters[tags.slot_index].comparator = chosen_comp
        if player then
            diverter_gui.refresh_main_slot_button(player, tags.unit_number, tags.port_index, tags.slot_index, true)
        end
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
        if element and element.valid then
            local player = game.get_player(event.player_index)
            if not (player and player.valid) then return end

            if element.name == GUI_FRAME_NAME then
                local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
                if config_frame and config_frame.valid then
                    diverter_gui.close_slot_config(player)
                else
                    diverter_gui.close(player)
                end
            elseif element.name == SLOT_CONFIG_FRAME_NAME then
                diverter_gui.close_slot_config(player)
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