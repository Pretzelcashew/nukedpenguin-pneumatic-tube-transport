local events = require("scripts.events")
local pump_settings = require("scripts.pump-settings")

local pump_gui = {}

local GUI_FRAME_NAME = "pump_configuration_frame"
local COMPARATORS = { "=", "≥", "≤", ">", "<", "≠" }

local function get_comparator_index(comp)
    for i, v in ipairs(COMPARATORS) do
        if v == comp then return i end
    end
    return 1
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
        caption = "Pneumatic Pump Configuration"
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
        name = "pump_close_button",
        style = "frame_action_button",
        sprite = "utility/close",
        tags = { unit_number = entity.unit_number }
    }

    -- Global Wire Channel Toggles
    local wire_flow = main_frame.add{ type = "flow", direction = "horizontal" }
    wire_flow.style.vertical_align = "center"
    wire_flow.style.horizontal_spacing = 12

    wire_flow.add{
        type = "checkbox",
        name = "pump_read_red",
        caption = "Read Red Wire",
        state = settings.read_red ~= false,
        tags = { unit_number = entity.unit_number }
    }

    wire_flow.add{
        type = "checkbox",
        name = "pump_read_green",
        caption = "Read Green Wire",
        state = settings.read_green ~= false,
        tags = { unit_number = entity.unit_number }
    }

    -- Configuration Card
    local inner_frame = main_frame.add{
        type = "frame",
        style = "inside_shallow_frame_with_padding"
    }

    local card_frame = inner_frame.add{
        type = "frame",
        direction = "vertical",
        style = "bordered_frame"
    }

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
    local circuit_flow = card_frame.add{ type = "flow", direction = "horizontal" }
    circuit_flow.style.vertical_align = "center"
    circuit_flow.style.horizontal_spacing = 6

    circuit_flow.add{
        type = "checkbox",
        name = "pump_use_circuit_enable",
        caption = "Circuit Enable",
        state = settings.use_circuit_enable or false,
        tags = { unit_number = entity.unit_number }
    }

    local cond = settings.enable_condition or { first_signal = nil, comparator = "=", constant = 0 }

    circuit_flow.add{
        type = "choose-elem-button",
        name = "pump_circuit_signal",
        elem_type = "signal",
        signal = cond.first_signal,
        tags = { unit_number = entity.unit_number }
    }

    local comp_dropdown = circuit_flow.add{
        type = "drop-down",
        name = "pump_circuit_comparator",
        items = COMPARATORS,
        selected_index = get_comparator_index(cond.comparator or "="),
        tags = { unit_number = entity.unit_number }
    }
    comp_dropdown.style.width = 40

    local const_tf = circuit_flow.add{
        type = "textfield",
        name = "pump_circuit_constant",
        text = tostring(cond.constant or 0),
        numeric = true,
        allow_negative = true,
        tags = { unit_number = entity.unit_number }
    }
    const_tf.style.width = 50

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
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number) then return end

    local settings = pump_settings.get(tags.unit_number)

    if element.name == "pump_circuit_signal" then
        settings.enable_condition.first_signal = element.elem_value
    end
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.unit_number) then return end

    local settings = pump_settings.get(tags.unit_number)

    if element.name == "pump_circuit_comparator" then
        settings.enable_condition.comparator = COMPARATORS[element.selected_index] or "="
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