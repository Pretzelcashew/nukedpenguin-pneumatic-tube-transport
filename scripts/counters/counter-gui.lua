local events = require("scripts.events")
local counter_settings = require("scripts.counters.counter-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local gui_components = require("scripts.utils.gui-components")

local counter_gui = {}

local GUI_FRAME_NAME = "counter_configuration_frame"

local function notify_change(entity_or_dev_id)
    local dev_id = counter_settings.get_device_id(entity_or_dev_id)
    if not dev_id then return end

    local entity = nil
    if type(entity_or_dev_id) == "table" and entity_or_dev_id.valid then
        entity = entity_or_dev_id
    elseif storage.active_counters and storage.active_counters[dev_id] then
        entity = storage.active_counters[dev_id]
    elseif storage.ghost_devices and storage.ghost_devices[dev_id] then
        entity = storage.ghost_devices[dev_id]
    end

    if entity and entity.valid then
        active_device_scanner.notify_settings_changed(entity)
    end
end

local function target_has_channel(target_value, channel)
    if target_value == "both" then
        return true
    elseif channel == "red" then
        return (target_value == "red")
    elseif channel == "green" then
        return (target_value == "green")
    end
    return false
end

local function compute_target_from_channels(red_active, green_active)
    if red_active and green_active then
        return "both"
    elseif red_active then
        return "red"
    elseif green_active then
        return "green"
    else
        return "off"
    end
end

function counter_gui.close(player)
    if not (player and player.valid) then return end
    if player.gui.screen[GUI_FRAME_NAME] then
        player.gui.screen[GUI_FRAME_NAME].destroy()
    end
    if player.opened and player.opened.valid and player.opened.name == GUI_FRAME_NAME then
        player.opened = nil
    end
end

function counter_gui.open(player, entity)
    if not (player and player.valid and entity and entity.valid) then return end

    counter_gui.close(player)

    local dev_id = counter_settings.get_device_id(entity)
    local settings = counter_settings.get(dev_id)

    if entity.name == "entity-ghost" then
        storage.ghost_devices = storage.ghost_devices or {}
        storage.ghost_devices[dev_id] = entity
    end

    local main_frame = gui_components.create_relative_window(player, nil, GUI_FRAME_NAME)
    if not main_frame then return end
    main_frame.tags = { dev_id = dev_id }

    -- Titlebar Header
    gui_components.add_header(
        main_frame,
        "Pneumatic Counter Configuration",
        "counter_close_button",
        { dev_id = dev_id }
    )

    -- Card Frame
    local card_frame = gui_components.add_card_frame(main_frame, "vertical")
    card_frame.style.horizontal_align = "left"

    -- Section 1: Capsule Vessels Routing
    local vessels_flow = card_frame.add{ type = "flow", direction = "vertical" }
    vessels_flow.style.bottom_margin = 6

    vessels_flow.add{
        type = "label",
        style = "caption_label",
        caption = "Capsule Vessels Routing"
    }

    local vessels_opts_flow = vessels_flow.add{ type = "flow", direction = "horizontal" }
    vessels_opts_flow.style.horizontal_spacing = 16

    vessels_opts_flow.add{
        type = "checkbox",
        caption = "Red Wire",
        state = target_has_channel(settings.vessels_target, "red"),
        tags = {
            dev_id = dev_id,
            setting_target = "vessels_target",
            wire_channel = "red"
        }
    }
    vessels_opts_flow.add{
        type = "checkbox",
        caption = "Green Wire",
        state = target_has_channel(settings.vessels_target, "green"),
        tags = {
            dev_id = dev_id,
            setting_target = "vessels_target",
            wire_channel = "green"
        }
    }

    card_frame.add{ type = "line", direction = "horizontal" }

    -- Section 2: Cargo Contents Routing
    local cargo_flow = card_frame.add{ type = "flow", direction = "vertical" }
    cargo_flow.style.top_margin = 4
    cargo_flow.style.bottom_margin = 6

    cargo_flow.add{
        type = "label",
        style = "caption_label",
        caption = "Cargo Contents Routing"
    }

    local cargo_opts_flow = cargo_flow.add{ type = "flow", direction = "horizontal" }
    cargo_opts_flow.style.horizontal_spacing = 16

    cargo_opts_flow.add{
        type = "checkbox",
        caption = "Red Wire",
        state = target_has_channel(settings.cargo_target, "red"),
        tags = {
            dev_id = dev_id,
            setting_target = "cargo_target",
            wire_channel = "red"
        }
    }
    cargo_opts_flow.add{
        type = "checkbox",
        caption = "Green Wire",
        state = target_has_channel(settings.cargo_target, "green"),
        tags = {
            dev_id = dev_id,
            setting_target = "cargo_target",
            wire_channel = "green"
        }
    }

    card_frame.add{ type = "line", direction = "horizontal" }

    -- Section 3: Total Capsule Count Routing & Signal Selection
    local total_flow = card_frame.add{ type = "flow", direction = "vertical" }
    total_flow.style.top_margin = 4

    total_flow.add{
        type = "label",
        style = "caption_label",
        caption = "Total Capsule Count Routing"
    }

    local total_opts_flow = total_flow.add{ type = "flow", direction = "horizontal" }
    total_opts_flow.style.horizontal_spacing = 16

    total_opts_flow.add{
        type = "checkbox",
        caption = "Red Wire",
        state = target_has_channel(settings.total_target, "red"),
        tags = {
            dev_id = dev_id,
            setting_target = "total_target",
            wire_channel = "red"
        }
    }
    total_opts_flow.add{
        type = "checkbox",
        caption = "Green Wire",
        state = target_has_channel(settings.total_target, "green"),
        tags = {
            dev_id = dev_id,
            setting_target = "total_target",
            wire_channel = "green"
        }
    }

    local total_signal_flow = total_flow.add{ type = "flow", direction = "horizontal" }
    total_signal_flow.style.vertical_align = "center"
    total_signal_flow.style.top_margin = 6
    total_signal_flow.style.horizontal_spacing = 8

    total_signal_flow.add{
        type = "label",
        caption = "Total Count Signal:"
    }

    total_signal_flow.add{
        type = "choose-elem-button",
        name = "counter_total_signal",
        elem_type = "signal",
        signal = settings.total_signal,
        tags = {
            dev_id = dev_id,
            action = "set_total_signal"
        }
    }

    player.opened = main_frame
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name == "counter_close_button" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            counter_gui.close(player)
        end
    end
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.dev_id and tags.setting_target and tags.wire_channel) then return end

    local settings = counter_settings.get(tags.dev_id)
    if not settings then return end

    local current_target = settings[tags.setting_target]
    local is_red = target_has_channel(current_target, "red")
    local is_green = target_has_channel(current_target, "green")

    if tags.wire_channel == "red" then
        is_red = element.state
    elseif tags.wire_channel == "green" then
        is_green = element.state
    end

    settings[tags.setting_target] = compute_target_from_channels(is_red, is_green)

    notify_change(tags.dev_id)
end

local function on_gui_elem_changed(event)
    local element = event.element
    if not (element and element.valid) then return end
    local tags = element.tags
    if not (tags and tags.dev_id and tags.action == "set_total_signal") then return end

    local settings = counter_settings.get(tags.dev_id)
    if not settings then return end

    settings.total_signal = element.elem_value
    notify_change(tags.dev_id)
end

local function on_gui_closed(event)
    local element = event.element
    if element and element.valid and element.name == GUI_FRAME_NAME then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            counter_gui.close(player)
        end
    end
end

local function on_gui_opened(event)
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local real_name = is_ghost and entity.ghost_name or entity.name

    if real_name == "pneumatic-capsule-counter" or real_name == "pneumatic-capsule-counter-circuit-proxy" then
        local player = game.get_player(event.player_index)
        if player and player.valid then
            local main_entity = entity
            if real_name == "pneumatic-capsule-counter-circuit-proxy" then
                local mains = entity.surface.find_entities_filtered{
                    name = "pneumatic-capsule-counter",
                    position = entity.position
                }
                if mains[1] and mains[1].valid then
                    main_entity = mains[1]
                end
            end
            counter_gui.open(player, main_entity)
        end
    end
end

events.on_event(defines.events.on_gui_opened, on_gui_opened)
events.on_event(defines.events.on_gui_closed, on_gui_closed)
events.on_event(defines.events.on_gui_click, on_gui_click)
events.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
events.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)

if active_device_scanner.on_settings_changed then
    active_device_scanner.on_settings_changed(function(entity)
        if not (entity and entity.valid) then return end
        local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
        if real_name == "pneumatic-capsule-counter" then
            local dev_id = counter_settings.get_device_id(entity)
            for _, player in pairs(game.players) do
                if player and player.valid and player.opened and player.opened.valid and player.opened.name == GUI_FRAME_NAME then
                    local open_tags = player.opened.tags
                    if open_tags and open_tags.dev_id == dev_id then
                        counter_gui.open(player, entity)
                    end
                end
            end
        end
    end)
end

return counter_gui