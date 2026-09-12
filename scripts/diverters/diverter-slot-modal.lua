local diverter_settings = require("scripts.diverters.diverter-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local gui_components = require("scripts.utils.gui-components")

local diverter_slot_modal = {}

diverter_slot_modal.FRAME_NAME = "filter_slot_config_frame"
diverter_slot_modal.GUI_FRAME_NAME = "diverter_configuration_frame"

local SLOT_CONFIG_FRAME_NAME = diverter_slot_modal.FRAME_NAME
local GUI_FRAME_NAME = diverter_slot_modal.GUI_FRAME_NAME

local PORT_DIRECTIONS = {
    "North " .. gui_components.COLOR_BLUE .. "▲" .. gui_components.COLOR_END,
    "East " .. gui_components.COLOR_BLUE .. "▶" .. gui_components.COLOR_END,
    "South " .. gui_components.COLOR_BLUE .. "▼" .. gui_components.COLOR_END,
    "West " .. gui_components.COLOR_BLUE .. "◀" .. gui_components.COLOR_END
}

diverter_slot_modal.PORT_DIRECTIONS = PORT_DIRECTIONS

local draft_filters = {}
local confirm_ticks = {}

local function find_element_by_name(element, name)
    if not (element and element.valid) then return nil end
    if element.name == name then return element end
    for _, child in ipairs(element.children) do
        local found = find_element_by_name(child, name)
        if found then return found end
    end
    return nil
end

diverter_slot_modal.find_element_by_name = find_element_by_name

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

diverter_slot_modal.notify_change = notify_change

function diverter_slot_modal.refresh_main_slot_button(player, unit_number, port_index, slot_index, is_active)
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

diverter_slot_modal.refresh_slot_button = diverter_slot_modal.refresh_main_slot_button

function diverter_slot_modal.get_draft(player_index)
    return draft_filters[player_index]
end

function diverter_slot_modal.record_confirm(player_index, tick)
    confirm_ticks[player_index] = tick
end

function diverter_slot_modal.was_confirmed(player_index, tick)
    return confirm_ticks[player_index] == tick
end

function diverter_slot_modal.is_open(player)
    if not (player and player.valid) then return false end
    local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
    return (config_frame and config_frame.valid) and true or false
end

function diverter_slot_modal.close(player, should_apply)
    if not (player and player.valid) then return end
    local p_index = player.index
    local draft = draft_filters[p_index]

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

        diverter_slot_modal.refresh_main_slot_button(player, unit_number, port_index, slot_index, false)
        draft_filters[p_index] = nil
    end

    local main_frame = player.gui.screen[GUI_FRAME_NAME]
    if main_frame and main_frame.valid then
        player.opened = main_frame
    end
end

diverter_slot_modal.close_slot_config = diverter_slot_modal.close

function diverter_slot_modal.open(player, unit_number, port_index, slot_index)
    if not (player and player.valid) then return end

    diverter_slot_modal.close(player, false)

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

    diverter_slot_modal.refresh_main_slot_button(player, unit_number, port_index, slot_index, true)
end

diverter_slot_modal.open_slot_config = diverter_slot_modal.open

function diverter_slot_modal.handle_click(player, element, tags)
    if not (element and element.valid and player and player.valid) then return false end

    if element.name == "slot_config_close_button" then
        diverter_slot_modal.close(player, false)
        return true
    end

    if element.name == "quality_confirm_button" then
        diverter_slot_modal.close(player, true)
        return true
    end

    if element.name:find("quality_tier_radio_") then
        local chosen_tier = element.name:gsub("quality_tier_radio_", "")
        local draft = draft_filters[player.index]
        if draft then
            local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
            draft.comparator, draft.quality = gui_components.handle_quality_tier_click(config_frame, draft.comparator, chosen_tier)
            draft.explicit_quality = true
        end
        return true
    end

    return false
end

function diverter_slot_modal.handle_elem_changed(player, element, tags)
    if not (element and element.valid and player and player.valid) then return false end

    if element.name == "slot_config_item_button" then
        local draft = draft_filters[player.index]
        if draft then
            gui_components.handle_filter_item_change(draft, element.elem_value)

            local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
            if config_frame and config_frame.valid then
                gui_components.update_quality_control_bar(config_frame, draft.comparator, draft.quality)
            end
        end
        return true
    end

    return false
end

function diverter_slot_modal.handle_selection_state_changed(player, element, tags)
    if not (element and element.valid and player and player.valid) then return false end

    if element.name == "quality_comparator_dropdown" then
        local draft = draft_filters[player.index]
        if draft then
            local config_frame = player.gui.screen[SLOT_CONFIG_FRAME_NAME]
            draft.comparator, draft.quality = gui_components.handle_quality_comparator_change(config_frame, element.selected_index, draft.quality)

            if draft.comparator == "Any" or draft.comparator == "Any Quality" then
                draft.explicit_quality = nil
            else
                draft.explicit_quality = true
            end
        end
        return true
    end

    return false
end

return diverter_slot_modal
