local events = require("scripts.events")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_settings = require("scripts.hubs.hub-settings")
local hub_manager = require("scripts.hubs.hub-manager")
local gui_components = require("scripts.utils.gui-components")

local hub_gui = {}

local GUI_FRAME_NAME = "hub_operational_mode_frame"

local function notify_change(unit_number)
    local entity = storage.active_hubs and storage.active_hubs[unit_number]
    if entity and entity.valid then
        hub_manager.notify_settings_changed(entity)
    end
end

function hub_gui.close(player)
    if player and player.valid and player.gui.relative[GUI_FRAME_NAME] then
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

    hub_gui.close(player)

    local settings = hub_settings.get(entity.unit_number)

    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right
    }

    local main_frame = gui_components.create_relative_window(player, anchor, GUI_FRAME_NAME, "Circuit connection")
    if not main_frame then return end

    -- Header Wire Channel Row
    local header_flow = main_frame.add{ type = "flow", direction = "horizontal" }
    header_flow.style.vertical_align = "center"
    header_flow.add{ type = "label", caption = "Input" }

    local filler = header_flow.add{ type = "empty-widget" }
    filler.style.horizontally_stretchable = true

    gui_components.add_wire_channel_toggles(header_flow, {
        read_red_name = "hub_wire_red",
        read_green_name = "hub_wire_green",
        read_red_caption = "R",
        read_green_caption = "G",
        read_red_state = settings.read_red ~= false,
        read_green_state = settings.read_green ~= false,
        tags = { unit_number = entity.unit_number }
    })

    main_frame.add{ type = "line", direction = "horizontal" }

    -- Send Settings Section
    local send_flow_1 = main_frame.add{ type = "flow", direction = "horizontal" }
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

    gui_components.add_circuit_condition_panel(main_frame, {
        signal = settings.send_condition.first_signal,
        comparator = settings.send_condition.comparator or "<",
        constant = settings.send_condition.constant or 0,
        signal_button_name = "hub_send_signal",
        comparator_dropdown_name = "hub_send_operator",
        constant_textfield_name = "hub_send_constant",
        tags = { unit_number = entity.unit_number }
    })

    main_frame.add{ type = "line", direction = "horizontal" }

    -- Receive Settings Section
    local recv_flow_1 = main_frame.add{ type = "flow", direction = "horizontal" }
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

    gui_components.add_circuit_condition_panel(main_frame, {
        signal = settings.receive_condition.first_signal,
        comparator = settings.receive_condition.comparator or "<",
        constant = settings.receive_condition.constant or 0,
        signal_button_name = "hub_receive_signal",
        comparator_dropdown_name = "hub_receive_operator",
        constant_textfield_name = "hub_receive_constant",
        tags = { unit_number = entity.unit_number }
    })

    -- Receive Lock Latch Section
    local recv_latch_flow = main_frame.add{ type = "flow", direction = "horizontal" }
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

    notify_change(unit_number)
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)

    if element.name == "hub_send_signal" then
        gui_components.update_condition_signal(settings.send_condition, element.elem_value)
    elseif element.name == "hub_receive_signal" then
        gui_components.update_condition_signal(settings.receive_condition, element.elem_value)
    end

    notify_change(unit_number)
end

local function on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)

    if element.name == "hub_send_operator" then
        local comp = gui_components.get_comparator_by_index(element.selected_index)
        gui_components.update_condition_comparator(settings.send_condition, comp)
    elseif element.name == "hub_receive_operator" then
        local comp = gui_components.get_comparator_by_index(element.selected_index)
        gui_components.update_condition_comparator(settings.receive_condition, comp)
    end

    notify_change(unit_number)
end

local function on_gui_text_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local unit_number = element.tags and element.tags.unit_number
    if not unit_number then return end

    local settings = hub_settings.get(unit_number)

    if element.name == "hub_send_constant" then
        gui_components.update_condition_constant(settings.send_condition, element.text)
    elseif element.name == "hub_receive_constant" then
        gui_components.update_condition_constant(settings.receive_condition, element.text)
    end

    notify_change(unit_number)
end

local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.entity then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            hub_gui.close(player)
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