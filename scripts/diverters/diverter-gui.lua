local events = require("scripts.events")
local diverter_settings = require("scripts.diverters.diverter-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local gui_components = require("scripts.utils.gui-components")
local diverter_slot_modal = require("scripts.diverters.diverter-slot-modal")

local diverter_gui = {}

local GUI_FRAME_NAME = "diverter_configuration_frame"
local SLOT_CONFIG_FRAME_NAME = "filter_slot_config_frame"
local PORT_DIRECTIONS = {
    "North " .. gui_components.COLOR_BLUE .. "▲" .. gui_components.COLOR_END,
    "East " .. gui_components.COLOR_BLUE .. "▶" .. gui_components.COLOR_END,
    "South " .. gui_components.COLOR_BLUE .. "▼" .. gui_components.COLOR_END,
    "West " .. gui_components.COLOR_BLUE .. "◀" .. gui_components.COLOR_END
}

diverter_gui.close_slot_config = diverter_slot_modal.close
diverter_gui.open_slot_config = diverter_slot_modal.open

local function get_element_tags(element)
    if not (element and element.valid) then return {} end
    local merged_tags = {}

    local curr = element
    while curr and curr.valid do
        if curr.tags then
            for k, v in pairs(curr.tags) do
                if merged_tags[k] == nil then
                    merged_tags[k] = v
                end
            end
        end
        curr = curr.parent
    end

    return merged_tags
end

local function notify_change(unit_number)
    if not unit_number then return end
    local entity = (storage.active_diverters and storage.active_diverters[unit_number]) or
                   (storage.ghost_devices and storage.ghost_devices[unit_number])
    if not (entity and entity.valid) then
        if storage.ghost_devices then
            for _, g in pairs(storage.ghost_devices) do
                if g and g.valid then
                    local gid = diverter_settings.get_device_id(g)
                    if gid == unit_number then
                        entity = g
                        break
                    end
                end
            end
        end
    end
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

local function _deprecated_close_slot_config(player, should_apply)
    if not (player and player.valid) then return end
    local p_index = player.index
    local draft = nil

    local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
    if config_frame and config_frame.valid then
        config_frame.destroy()
    end

    if draft then
        local unit_number = draft.unit_number
        local port_index = draft.port_index
        local slot_index = draft.slot_index

        if should_apply then
            local settings = diverter_settings.get(unit_number)
            local port = settings and settings.ports and settings.ports[port_index]
            if port and port.filters and port.filters[slot_index] then
                local comp = draft.comparator or "Any Quality"
                local qual = draft.quality or "normal"
                if comp == "Any Quality" or comp == "Any" then
                    qual = "normal"
                end
                port.filters[slot_index] = {
                    item = draft.item,
                    comparator = comp,
                    quality = qual,
                    explicit_quality = (comp ~= "Any Quality" and comp ~= "Any") and draft.explicit_quality or nil
                }
                notify_change(unit_number)
            end
        end

        diverter_gui.refresh_main_slot_button(player, unit_number, port_index, slot_index, false)
        draft_filters[p_index] = nil
    end

    local main_frame = player.gui.screen[GUI_FRAME_NAME]
    if main_frame and main_frame.valid then
        player.opened = main_frame
    end
end

function diverter_gui.close(player)
    if not (player and player.valid) then return end
    diverter_gui.close_slot_config(player, false)
    if player.gui.screen[GUI_FRAME_NAME] then
        player.gui.screen[GUI_FRAME_NAME].destroy()
    end
    if player.opened and player.opened.valid and player.opened.name == GUI_FRAME_NAME then
        player.opened = nil
    end
end

function diverter_gui.refresh_if_open(unit_number)
    if not unit_number then return end
    for _, player in pairs(game.players) do
        if player and player.valid then
            local main_frame = player.gui.screen[GUI_FRAME_NAME]
            if main_frame and main_frame.valid then
                local inner_frame = find_element_by_name(main_frame, "diverter_inner_frame")
                if inner_frame and inner_frame.valid and inner_frame.tags then
                    local frame_id = inner_frame.tags.unit_number
                    if frame_id == unit_number then
                        local draft = diverter_slot_modal.get_draft(player.index)
                        local view = inner_frame.tags.current_view or "all"
                        diverter_gui.render_content_layout(inner_frame, unit_number, view)

                        if draft and draft.unit_number == unit_number then
                            diverter_gui.refresh_main_slot_button(player, draft.unit_number, draft.port_index, draft.slot_index, true)
                        end
                    end
                end
            end
        end
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

local function _deprecated_open_slot_config(player, unit_number, port_index, slot_index)
    if not (player and player.valid) then return end

    diverter_gui.close_slot_config(player, false)

    local settings = diverter_settings.get(unit_number)
    local port = settings and settings.ports and settings.ports[port_index]
    if not port then return end

    local filter_data = port.filters[slot_index] or { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil }

    local comp = filter_data.comparator or "Any Quality"
    local qual = filter_data.quality or "normal"
    if comp == "Any Quality" or comp == "Any" then
        qual = "normal"
    end

    draft_filters[player.index] = {
        unit_number = unit_number,
        port_index = port_index,
        slot_index = slot_index,
        item = filter_data.item,
        comparator = comp,
        quality = qual,
        explicit_quality = (comp ~= "Any Quality" and comp ~= "Any") and filter_data.explicit_quality or nil
    }

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
        comparator = comp,
        quality = qual,
        tags = { unit_number = unit_number, port_index = port_index, slot_index = slot_index }
    })

    diverter_gui.refresh_main_slot_button(player, unit_number, port_index, slot_index, true)
end

function diverter_gui.render_content_layout(inner_frame, unit_number, current_view)
    if not (inner_frame and inner_frame.valid) then return end
    inner_frame.clear()
    inner_frame.tags = { unit_number = unit_number, current_view = current_view }

    local settings = diverter_settings.get(unit_number)
    if not settings then return end

    local main_flow = inner_frame.add{
        type = "flow",
        name = "diverter_main_flow",
        direction = "horizontal",
        tags = { unit_number = unit_number }
    }
    main_flow.style.vertical_align = "top"
    main_flow.style.horizontal_spacing = 12

    local selector_card = gui_components.add_card_frame(main_flow, "vertical")
    selector_card.style.vertical_align = "center"

    local sel_title = selector_card.add{
        type = "label",
        caption = "Direction View",
        style = "bold_label"
    }
    sel_title.style.bottom_margin = 4

    local parts_spec = {
        north  = { selected = (current_view == 1), tags = { unit_number = unit_number, view_port = 1 } },
        east   = { selected = (current_view == 2), tags = { unit_number = unit_number, view_port = 2 } },
        south  = { selected = (current_view == 3), tags = { unit_number = unit_number, view_port = 3 } },
        west   = { selected = (current_view == 4), tags = { unit_number = unit_number, view_port = 4 } },
        center = { caption = "All", tooltip = "Show All Direction Ports", selected = (current_view == "all"), tags = { unit_number = unit_number, view_port = "all" } }
    }

    gui_components.add_spatial_arrow_selector(selector_card, {
        name_prefix = "diverter_spatial",
        button_size = 36,
        spacing = 2,
        parts = parts_spec,
        tags = { unit_number = unit_number }
    })

    local ports_container = main_flow.add{
        type = "flow",
        name = "diverter_ports_container",
        direction = "vertical",
        tags = { unit_number = unit_number }
    }

    local active_ports = {}
    if current_view == "all" then
        active_ports = { 1, 2, 3, 4 }
    elseif type(current_view) == "number" and current_view >= 1 and current_view <= 4 then
        active_ports = { current_view }
    else
        active_ports = { 1 }
    end

    local grid_table = ports_container.add{
        type = "table",
        name = "ports_grid_table",
        column_count = (current_view == "all" and 2 or 1),
        horizontal_spacing = 12,
        vertical_spacing = 12,
        tags = { unit_number = unit_number }
    }

    local player_index = inner_frame.player_index
    local has_clipboard = (player_index and storage.port_clipboard and storage.port_clipboard[player_index] ~= nil) or false

    local copy_sprite = "utility/copy"
    if helpers and not helpers.is_valid_sprite_path(copy_sprite) then
        copy_sprite = helpers.is_valid_sprite_path("utility/export_slot") and "utility/export_slot" or ""
    end

    local paste_sprite = "utility/paste"
    if helpers and not helpers.is_valid_sprite_path(paste_sprite) then
        paste_sprite = helpers.is_valid_sprite_path("utility/import_slot") and "utility/import_slot" or ""
    end

    for _, i in ipairs(active_ports) do
        local port_data = settings.ports[i]
        local dir_name = PORT_DIRECTIONS[i] or ("Port " .. i)

        local card_frame = grid_table.add{
            type = "frame",
            direction = "vertical",
            style = "bordered_frame",
            tags = { unit_number = unit_number, port_index = i }
        }

        local header_flow = card_frame.add{
            type = "flow",
            direction = "horizontal",
            tags = { unit_number = unit_number, port_index = i }
        }
        header_flow.style.vertical_align = "center"
        header_flow.add{
            type = "checkbox",
            name = "port_enable",
            caption = "Port " .. i .. " (" .. dir_name .. ")",
            state = port_data.enabled,
            tags = { unit_number = unit_number, port_index = i }
        }

        local header_spacer = header_flow.add{ type = "empty-widget" }
        header_spacer.style.horizontally_stretchable = true

        local copy_btn = header_flow.add{
            type = "sprite-button",
            name = "port_copy_button",
            sprite = copy_sprite,
            caption = (copy_sprite == "") and "Copy" or nil,
            style = "tool_button",
            tooltip = "Copy Port " .. i .. " settings",
            tags = { unit_number = unit_number, port_index = i }
        }
        copy_btn.style.width = 24
        copy_btn.style.height = 24
        copy_btn.style.padding = 2

        local paste_btn = header_flow.add{
            type = "sprite-button",
            name = "port_paste_button",
            sprite = paste_sprite,
            caption = (paste_sprite == "") and "Paste" or nil,
            style = "tool_button",
            tooltip = has_clipboard and ("Paste copied settings to Port " .. i) or "No port settings in clipboard",
            enabled = has_clipboard,
            tags = { unit_number = unit_number, port_index = i }
        }
        paste_btn.style.width = 24
        paste_btn.style.height = 24
        paste_btn.style.padding = 2

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
            tags = { unit_number = unit_number, port_index = i }
        })

        local is_pull = (port_data.mode == "input")
        gui_components.add_labeled_switch(card_frame, {
            switch_name = "port_direction_switch",
            is_left = is_pull,
            left_label = "Pull (Input)",
            right_label = "Push (Output)",
            tags = { unit_number = unit_number, port_index = i }
        })

        card_frame.add{ type = "line", direction = "horizontal" }

        local filter_enable_flow = card_frame.add{
            type = "flow",
            direction = "horizontal",
            tags = { unit_number = unit_number, port_index = i }
        }
        filter_enable_flow.style.vertical_align = "center"
        filter_enable_flow.add{
            type = "checkbox",
            name = "port_use_filters",
            caption = "Use filters",
            state = port_data.use_filters,
            tags = { unit_number = unit_number, port_index = i }
        }

        local is_whitelist = (port_data.filter_mode == "whitelist")
        gui_components.add_labeled_switch(card_frame, {
            switch_name = "port_filter_mode_switch",
            is_left = is_whitelist,
            left_label = "Whitelist",
            right_label = "Blacklist",
            tags = { unit_number = unit_number, port_index = i }
        })

        local slots_flow = card_frame.add{
            type = "flow",
            direction = "horizontal",
            tags = { unit_number = unit_number, port_index = i }
        }
        slots_flow.style.horizontal_spacing = 6

        for j = 1, 5 do
            local filter_data = port_data.filters[j] or { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil }
            gui_components.create_overlay_slot_button(slots_flow, {
                button_name = "diverter_slot_" .. i .. "_" .. j,
                item = filter_data.item,
                comparator = filter_data.comparator or "Any Quality",
                quality = filter_data.quality or "normal",
                tags = {
                    unit_number = unit_number,
                    port_index = i,
                    slot_index = j,
                    slot_button_click = true
                }
            })
        end
    end
end

function diverter_gui.open(player, entity, initial_view)
    if not (player and player.valid and entity and entity.valid) then return end

    diverter_gui.close(player)

    local current_view = initial_view or "all"
    local dev_id = diverter_settings.get_device_id(entity)
    if entity.name == "entity-ghost" and entity.tags and entity.tags.pneumatic_settings then
        if not storage.diverter_settings or not storage.diverter_settings[dev_id] then
            diverter_settings.apply_blueprint_settings(dev_id, entity.tags.pneumatic_settings)
        end
    end
    local settings = diverter_settings.get(dev_id)

    if entity.name == "entity-ghost" then
        storage.ghost_devices = storage.ghost_devices or {}
        storage.ghost_devices[dev_id] = entity
    end

    local main_frame = gui_components.create_relative_window(player, nil, GUI_FRAME_NAME)
    if not main_frame then return end

    gui_components.add_header(main_frame, "Pneumatic Diverter Configuration", "diverter_close_button", { unit_number = dev_id })

    gui_components.add_wire_channel_toggles(main_frame, {
        read_red_name = "diverter_read_red",
        read_green_name = "diverter_read_green",
        read_red_state = settings.read_red ~= false,
        read_green_state = settings.read_green ~= false,
        tags = { unit_number = dev_id }
    })

    local inner_frame = main_frame.add{
        type = "frame",
        name = "diverter_inner_frame",
        style = "inside_shallow_frame_with_padding",
        tags = { unit_number = dev_id }
    }

    diverter_gui.render_content_layout(inner_frame, dev_id, current_view)

    player.opened = main_frame
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = get_element_tags(element)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    if element.name == "diverter_close_button" then
        diverter_gui.close(player)
        return
    end

    if diverter_slot_modal.handle_click(player, element, tags) then
        return
    end

    if element.name == "port_copy_button" and tags.unit_number and tags.port_index then
        local copied_port = diverter_settings.copy_port(tags.unit_number, tags.port_index)
        if copied_port then
            storage.port_clipboard = storage.port_clipboard or {}
            storage.port_clipboard[player.index] = copied_port
            player.create_local_flying_text{
                text = "Port " .. tags.port_index .. " settings copied",
                create_at_cursor = true
            }
            diverter_gui.refresh_if_open(tags.unit_number)
        end
        return
    end

    if element.name == "port_paste_button" and tags.unit_number and tags.port_index then
        local clipboard = storage.port_clipboard and storage.port_clipboard[player.index]
        if clipboard then
            diverter_settings.paste_port(tags.unit_number, tags.port_index, clipboard)
            notify_change(tags.unit_number)
            player.create_local_flying_text{
                text = "Pasted settings to Port " .. tags.port_index,
                create_at_cursor = true
            }
            diverter_gui.refresh_if_open(tags.unit_number)
        end
        return
    end

    if tags.view_port ~= nil and tags.unit_number then
        local main_frame = player.gui.screen[GUI_FRAME_NAME]
        if main_frame and main_frame.valid then
            diverter_gui.close_slot_config(player, false)
            local current_view = tags.view_port
            local inner_frame = find_element_by_name(main_frame, "diverter_inner_frame")
            if inner_frame then
                diverter_gui.render_content_layout(inner_frame, tags.unit_number, current_view)
            end
        end
        return
    end


    if tags.slot_button_click and tags.unit_number and tags.port_index and tags.slot_index then
        local settings = diverter_settings.get(tags.unit_number)
        local port = settings and settings.ports and settings.ports[tags.port_index]
        if port and port.filters and port.filters[tags.slot_index] then
            local action = gui_components.handle_overlay_slot_click(event, port.filters[tags.slot_index])
            if action == "cleared" then
                local draft = diverter_slot_modal.get_draft(player.index)
                if draft and draft.unit_number == tags.unit_number and draft.port_index == tags.port_index and draft.slot_index == tags.slot_index then
                    diverter_gui.close_slot_config(player, false)
                end
                diverter_gui.refresh_main_slot_button(player, tags.unit_number, tags.port_index, tags.slot_index, false)
                notify_change(tags.unit_number)
            else
                diverter_gui.open_slot_config(player, tags.unit_number, tags.port_index, tags.slot_index)
            end
        end
        return
    end
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = get_element_tags(element)
    if not tags.unit_number then return end

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
    local port = settings.ports and settings.ports[tags.port_index]
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
    local tags = get_element_tags(element)
    if not (tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings and settings.ports and settings.ports[tags.port_index]
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

    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local tags = get_element_tags(element)
    if not tags.unit_number then return end

    if element.name == "port_circuit_signal" and tags.port_index then
        local settings = diverter_settings.get(tags.unit_number)
        local port = settings and settings.ports and settings.ports[tags.port_index]
        if port then
            port.enable_condition.first_signal = element.elem_value
            notify_change(tags.unit_number)
        end
        return
    end

    if diverter_slot_modal.handle_elem_changed(player, element, tags) then
        return
    end
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local tags = get_element_tags(element)
    if not tags.unit_number then return end

    if element.name == "port_circuit_comparator" and tags.port_index then
        local settings = diverter_settings.get(tags.unit_number)
        local port = settings and settings.ports and settings.ports[tags.port_index]
        if port then
            port.enable_condition.comparator = gui_components.get_comparator_by_index(element.selected_index)
            notify_change(tags.unit_number)
        end
        return
    end

    if diverter_slot_modal.handle_selection_state_changed(player, element, tags) then
        return
    end

    if false and element.name == "quality_comparator_dropdown" then
        local draft = nil
        if draft then
            local config_frame = nil
            draft.comparator, draft.quality = gui_components.handle_quality_comparator_change(config_frame, element.selected_index, draft.quality)

            if draft.comparator == "Any" or draft.comparator == "Any Quality" then
                draft.explicit_quality = nil
            else
                draft.explicit_quality = true
            end
        end
    end
end

local function on_gui_text_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = get_element_tags(element)
    if not (tags.unit_number and tags.port_index) then return end

    local settings = diverter_settings.get(tags.unit_number)
    local port = settings and settings.ports and settings.ports[tags.port_index]
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

            local was_confirmed = diverter_slot_modal.was_confirmed(event.player_index, event.tick)

            if element.name == diverter_slot_modal.FRAME_NAME then
                diverter_gui.close_slot_config(player, was_confirmed)
            elseif element.name == GUI_FRAME_NAME then
                if diverter_slot_modal.is_open(player) then
                    diverter_gui.close_slot_config(player, was_confirmed)
                else
                    diverter_gui.close(player)
                end
            end
        end
    end
end

events.on_event("pneumatic-confirm-gui", function(event)
    diverter_slot_modal.record_confirm(event.player_index, event.tick)
end)

events.on_event(defines.events.on_gui_click, on_gui_click)
events.on_event(defines.events.on_gui_closed, on_gui_closed)
events.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
events.on_event(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
events.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
events.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
events.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)

if active_device_scanner.on_settings_changed then
    active_device_scanner.on_settings_changed(function(entity)
        if not (entity and entity.valid) then return end
        local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
        if real_name == "pneumatic-diverter" then
            local dev_id = diverter_settings.get_device_id(entity)
            diverter_gui.refresh_if_open(dev_id)
        end
    end)
end

return diverter_gui
