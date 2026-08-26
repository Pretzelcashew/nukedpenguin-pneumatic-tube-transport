local events = require("scripts.events")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_settings = require("scripts.hubs.hub-settings")

local hub_gui = {}

local GUI_FRAME_NAME = "hub_operational_mode_frame"
local OPERATORS = {"<", ">", "=", "≥", "≤", "≠"}

local function get_operator_index(op)
    for i, v in ipairs(OPERATORS) do
        if v == op then return i end
    end
    return 1
end

local function close_hub_gui(player)
    if player.gui.relative[GUI_FRAME_NAME] then
        player.gui.relative[GUI_FRAME_NAME].destroy()
    end
end

local function on_gui_opened(event)
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local def = hub_defs.types[entity.name]
    if not (def and def.type == "hub") then return end

    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    close_hub_gui(player)

    local settings = hub_settings.get(entity.unit_number)

    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right
    }

    local main_frame = player.gui.relative.add{
        type = "frame",
        name = GUI_FRAME_NAME,
        direction = "vertical",
        caption = "Circuit connection",
        anchor = anchor
    }

    -- Header wire channel toggles
    local header_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    header_flow.style.vertical_align = "center"
    header_flow.add{
        type = "label",
        caption = "Input"
    }

    local filler = header_flow.add{
        type = "empty-widget"
    }
    filler.style.horizontally_stretchable = true

    header_flow.add{
        type = "checkbox",
        name = "hub_wire_red",
        caption = "R",
        state = settings.read_red,
        tags = { unit_number = entity.unit_number }
    }
    header_flow.add{
        type = "checkbox",
        name = "hub_wire_green",
        caption = "G",
        state = settings.read_green,
        tags = { unit_number = entity.unit_number }
    }

    main_frame.add{ type = "line", direction = "horizontal" }

    -- Send Control Row & Condition Selectors
    local send_flow_1 = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    send_flow_1.style.vertical_align = "center"
    send_flow_1.add{
        type = "checkbox",
        name = "hub_enable_send",
        caption = "Enable send",
        state = settings.can_send,
        tags = { unit_number = entity.unit_number }
    }
    send_flow_1.add{
        type = "checkbox",
        name = "hub_use_circuit_send",
        caption = "Use circuit network",
        state = settings.use_circuit_send,
        tags = { unit_number = entity.unit_number }
    }

    local send_cond_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    send_cond_flow.style.vertical_align = "center"
    send_cond_flow.add{
        type = "choose-elem-button",
        name = "hub_send_signal",
        elem_type = "signal",
        signal = settings.send_condition.first_signal,
        tags = { unit_number = entity.unit_number }
    }
    send_cond_flow.add{
        type = "drop-down",
        name = "hub_send_operator",
        items = OPERATORS,
        selected_index = get_operator_index(settings.send_condition.comparator),
        tags = { unit_number = entity.unit_number }
    }
    local send_text = send_cond_flow.add{
        type = "textfield",
        name = "hub_send_constant",
        text = tostring(settings.send_condition.constant or 0),
        numeric = true,
        allow_negative = true,
        tags = { unit_number = entity.unit_number }
    }
    send_text.style.width = 60

    main_frame.add{ type = "line", direction = "horizontal" }

    -- Receive Control Row
    local recv_flow_1 = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    recv_flow_1.style.vertical_align = "center"
    recv_flow_1.add{
        type = "checkbox",
        name = "hub_enable_receive",
        caption = "Enable receive",
        state = settings.can_receive,
        tags = { unit_number = entity.unit_number }
    }
    recv_flow_1.add{
        type = "checkbox",
        name = "hub_use_circuit_receive",
        caption = "Use circuit network",
        state = settings.use_circuit_receive,
        tags = { unit_number = entity.unit_number }
    }

    -- Receive Condition Selectors
    local recv_cond_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    recv_cond_flow.style.vertical_align = "center"
    recv_cond_flow.add{
        type = "choose-elem-button",
        name = "hub_receive_signal",
        elem_type = "signal",
        signal = settings.receive_condition.first_signal,
        tags = { unit_number = entity.unit_number }
    }
    recv_cond_flow.add{
        type = "drop-down",
        name = "hub_receive_operator",
        items = OPERATORS,
        selected_index = get_operator_index(settings.receive_condition.comparator),
        tags = { unit_number = entity.unit_number }
    }
    local recv_text = recv_cond_flow.add{
        type = "textfield",
        name = "hub_receive_constant",
        text = tostring(settings.receive_condition.constant or 0),
        numeric = true,
        allow_negative = true,
        tags = { unit_number = entity.unit_number }
    }
    recv_text.style.width = 60

    -- Dedicated Receive Latch Option Row
    local recv_latch_flow = main_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    recv_latch_flow.style.top_margin = 4
    recv_latch_flow.add{
        type = "checkbox",
        name = "hub_use_receive_lock",
        caption = "Lock send after receiving until empty",
        state = settings.use_receive_lock,
        tags = { unit_number = entity.unit_number }
    }
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)
    local parent = element.parent

    if element.name == "hub_wire_red" then
        settings.read_red = element.state
    elseif element.name == "hub_wire_green" then
        settings.read_green = element.state
    elseif element.name == "hub_enable_send" then
        settings.can_send = element.state
        if not element.state then
            settings.use_circuit_send = false
            if parent and parent.hub_use_circuit_send then
                parent.hub_use_circuit_send.state = false
            end
        end
    elseif element.name == "hub_use_circuit_send" then
        settings.use_circuit_send = element.state
        if element.state then
            settings.can_send = true
            if parent and parent.hub_enable_send then
                parent.hub_enable_send.state = true
            end
        end
    elseif element.name == "hub_enable_receive" then
        settings.can_receive = element.state
        if not element.state then
            settings.use_circuit_receive = false
            if parent and parent.hub_use_circuit_receive then
                parent.hub_use_circuit_receive.state = false
            end
        end
    elseif element.name == "hub_use_circuit_receive" then
        settings.use_circuit_receive = element.state
        if element.state then
            settings.can_receive = true
            if parent and parent.hub_enable_receive then
                parent.hub_enable_receive.state = true
            end
        end
    elseif element.name == "hub_use_receive_lock" then
        settings.use_receive_lock = element.state
    end
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)

    if element.name == "hub_send_signal" then
        settings.send_condition.first_signal = element.elem_value
    elseif element.name == "hub_receive_signal" then
        settings.receive_condition.first_signal = element.elem_value
    end
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)

    if element.name == "hub_send_operator" then
        settings.send_condition.comparator = OPERATORS[element.selected_index] or "<"
    elseif element.name == "hub_receive_operator" then
        settings.receive_condition.comparator = OPERATORS[element.selected_index] or "<"
    end
end

local function on_gui_text_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)

    if element.name == "hub_send_constant" then
        settings.send_condition.constant = tonumber(element.text) or 0
    elseif element.name == "hub_receive_constant" then
        settings.receive_condition.constant = tonumber(element.text) or 0
    end
end

local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.entity then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            close_hub_gui(player)
        end
    end
end

events.on_event(defines.events.on_gui_opened, on_gui_opened)
events.on_event(defines.events.on_gui_closed, on_gui_closed)
events.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
events.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
events.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
events.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)

return hub_gui