local events = require("scripts.events")
local hub_packing = require("scripts.hubs.hub-packing")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_spill = require("scripts.hubs.hub-spill")

local hub_manager = {}

local GUI_FRAME_NAME = "hub_operational_mode_frame"

local function get_hub_settings(unit_number)
    storage.hub_settings = storage.hub_settings or {}
    if not storage.hub_settings[unit_number] then
        storage.hub_settings[unit_number] = { can_send = true, can_receive = true }
    end
    return storage.hub_settings[unit_number]
end

local function close_hub_gui(player)
    if player.gui.relative[GUI_FRAME_NAME] then
        player.gui.relative[GUI_FRAME_NAME].destroy()
    end
end

-- Add a new hub to the active registry
local function on_hub_built(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    local def = hub_defs.types[entity.name]
    if def and def.type == "hub" then
        storage.active_hubs = storage.active_hubs or {}
        storage.active_hubs[entity.unit_number] = entity
        get_hub_settings(entity.unit_number)
    end
end

-- Remove a hub from active registry and settings
local function on_hub_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    local unit_number = entity.unit_number
    local def = hub_defs.types[entity.name]
    if def then
        hub_spill.handle_hub_destruction(entity)

        if storage.active_hubs then
            storage.active_hubs[unit_number] = nil
        end
        if storage.hub_settings then
            storage.hub_settings[unit_number] = nil
        end
    end
end

-- GUI Event Handlers
local function on_gui_opened(event)
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local def = hub_defs.types[entity.name]
    if not (def and def.type == "hub") then return end

    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    close_hub_gui(player)

    local settings = get_hub_settings(entity.unit_number)

    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right
    }

    local frame = player.gui.relative.add{
        type = "frame",
        name = GUI_FRAME_NAME,
        direction = "vertical",
        caption = "Hub Operational Mode",
        anchor = anchor
    }

    local inner_flow = frame.add{
        type = "flow",
        direction = "vertical"
    }

    inner_flow.add{
        type = "checkbox",
        name = "hub_toggle_can_send",
        caption = "Allow Sending (Dispatch)",
        state = settings.can_send,
        tags = { unit_number = entity.unit_number }
    }

    inner_flow.add{
        type = "checkbox",
        name = "hub_toggle_can_receive",
        caption = "Allow Receiving (Arrival)",
        state = settings.can_receive,
        tags = { unit_number = entity.unit_number }
    }
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    if element.name == "hub_toggle_can_send" or element.name == "hub_toggle_can_receive" then
        local unit_number = element.tags and element.tags.unit_number
        if unit_number then
            local settings = get_hub_settings(unit_number)
            if element.name == "hub_toggle_can_send" then
                settings.can_send = element.state
            elseif element.name == "hub_toggle_can_receive" then
                settings.can_receive = element.state
            end
        end
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

-- The interleaved background scanner
local function on_tick(event)
    if not storage.active_hubs then return end

    local current_tick = event.tick
    for unit_number, entity in pairs(storage.active_hubs) do
        if (unit_number + current_tick) % 10 == 0 then
            if entity.valid then
                hub_packing.evaluate_inventory(entity)
            else
                storage.active_hubs[unit_number] = nil
            end
        end
    end
end

-- Hook into Factorio's build events
events.on_event(defines.events.on_built_entity, on_hub_built)
events.on_event(defines.events.on_robot_built_entity, on_hub_built)
events.on_event(defines.events.script_raised_built, on_hub_built)
events.on_event(defines.events.script_raised_revive, on_hub_built)

-- Hook into Factorio's destruction events
events.on_event(defines.events.on_player_mined_entity, on_hub_removed)
events.on_event(defines.events.on_robot_mined_entity, on_hub_removed)
events.on_event(defines.events.on_entity_died, on_hub_removed)
events.on_event(defines.events.script_raised_destroy, on_hub_removed)

-- Hook GUI events
events.on_event(defines.events.on_gui_opened, on_gui_opened)
events.on_event(defines.events.on_gui_closed, on_gui_closed)
events.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)

-- Hook the interleaved tick loop
events.on_event(defines.events.on_tick, on_tick)

return hub_manager