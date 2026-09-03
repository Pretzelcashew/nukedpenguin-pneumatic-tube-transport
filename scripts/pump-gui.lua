local events = require("scripts.events")
local pump_settings = require("scripts.pump-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local gui_components = require("scripts.utils.gui-components")

local pump_gui = {}

local GUI_FRAME_NAME = "pump_configuration_frame"

local function notify_change(unit_number)
    local entity = storage.active_pumps and storage.active_pumps[unit_number]
    if entity and entity.valid then
        active_device_scanner.notify_settings_changed(entity)
    end
end

function pump_gui.close(player)
    if player.gui.screen[GUI_FRAME_NAME] then
        player.gui.screen[GUI_FRAME_NAME].destroy()
    end
    if player.opened and player.opened.valid and player.opened.name == GUI_FRAME_NAME then
        player.opened = nil
    end
end

function pump_gui.open(player, entity)
    if not (player and player.valid and entity and entity.valid) then return end

    pump_gui.close(player)

    local settings = pump_settings.get(entity.unit_number)

    local main_frame = gui_components.create_relative_window(player, nil, GUI_FRAME_NAME)
    if not main_frame then return end

    -- Titlebar Header
    gui_components.add_header(main_frame, "Pneumatic Pump Configuration", "pump_close_button", { unit_number = entity.unit_number })

    -- Global Wire Channel Toggles
    gui_components.add_wire_channel_toggles(main_frame, {
        read_red_name = "pump_read_red",
        read_green_name = "pump_read_green",
        read_red_state = settings.read_red ~= false,
        read_green_state = settings.read_green ~= false,
        tags = { unit_number = entity.unit_number }
    })

    -- Configuration Card
    local card_frame = gui_components.add_card_frame(main_frame, "vertical")

    -- Enable Checkbox Header
    local header_flow = card_frame.add{ type = "flow", direction = "horizontal" }
    header_flow.style.vertical_align = "center"
    header_flow.add{
        type = "checkbox",
        name = "pump_enable",
        caption = "Enable Pump",
        state = settings.enabled,
        tags = { unit_number = entity.unit_number }
    }

    -- Circuit Network Enable Row
    local cond = settings.enable_condition or { first_signal = nil, comparator = "=", constant = 0 }
    gui_components.add_circuit_condition_panel(card_frame, {
        checkbox_name = "pump_use_circuit_enable",
        checkbox_caption = "Circuit Enable",
        checkbox_state = settings.use_circuit_enable or false,
        signal = cond.first_signal,
        comparator = cond.comparator or "=",
        constant = cond.constant or 0,
        signal_button_name = "pump_circuit_signal",
        comparator_dropdown_name = "pump_circuit_comparator",
        constant_textfield_name = "pump_circuit_constant",
        tags = { unit_number = entity.unit_number }
    })

    player.opened = main_frame
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name == "pump_close_button" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            pump_gui.close(player)
        end
    end
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number) then return end

    local settings = pump_settings.get(tags.unit_number)

    if element.name == "pump_read_red" then
        settings.read_red = element.state
    elseif element.name == "pump_read_green" then
        settings.read_green = element.state
    elseif element.name == "pump_enable" then
        settings.enabled = element.state
    elseif element.name == "pump_use_circuit_enable" then
        settings.use_circuit_enable = element.state
    end

    notify_change(tags.unit_number)
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number) then return end

    local settings = pump_settings.get(tags.unit_number)

    if element.name == "pump_circuit_signal" then
        settings.enable_condition.first_signal = element.elem_value
        notify_change(tags.unit_number)
    end
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number) then return end

    local settings = pump_settings.get(tags.unit_number)

    if element.name == "pump_circuit_comparator" then
        settings.enable_condition.comparator = gui_components.get_comparator_by_index(element.selected_index)
        notify_change(tags.unit_number)
    end
end

local function on_gui_text_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number) then return end

    local settings = pump_settings.get(tags.unit_number)

    if element.name == "pump_circuit_constant" then
        settings.enable_condition.constant = tonumber(element.text) or 0
        notify_change(tags.unit_number)
    end
end

local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.custom then
        local element = event.element
        if element and element.valid and element.name == GUI_FRAME_NAME then
            local player = game.get_player(event.player_index)
            if player and player.valid then
                pump_gui.close(player)
            end
        end
    end
end

events.on_event(defines.events.on_gui_click, on_gui_click)
events.on_event(defines.events.on_gui_closed, on_gui_closed)
events.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
events.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
events.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
events.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)

return pump_gui