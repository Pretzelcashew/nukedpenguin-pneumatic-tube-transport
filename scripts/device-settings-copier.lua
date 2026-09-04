local events = require("scripts.events")
local pump_settings = require("scripts.pump-settings")
local diverter_settings = require("scripts.diverter-settings")
local hub_settings = require("scripts.hubs.hub-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local hub_manager = require("scripts.hubs.hub-manager")
local pump_gui = require("scripts.pump-gui")
local diverter_gui = require("scripts.diverter-gui")
local util = require("util")

local device_settings_copier = {}

local HUB_NAMES = {
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true
}

local TARGET_NAMES = {
    ["pneumatic-pump"] = true,
    ["pneumatic-diverter"] = true,
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true
}

local function resolve_target_entity(entity)
    if not (entity and entity.valid) then return nil end
    if TARGET_NAMES[entity.name] then
        return entity
    end
    if entity.name == "pneumatic-pump-circuit-proxy" or entity.name == "pneumatic-diverter-circuit-proxy" then
        local main_name = entity.name:gsub("-circuit-proxy", "")
        local main = entity.surface.find_entity(main_name, entity.position)
        if main and main.valid then return main end
    end
    return nil
end

local function on_copy_settings(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local selected = resolve_target_entity(player.selected)
    if not selected then return end

    storage.player_copy_buffer = storage.player_copy_buffer or {}
    storage.player_copy_buffer[event.player_index] = {
        entity_name = selected.name,
        unit_number = selected.unit_number
    }
end

local function on_paste_settings(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local destination = resolve_target_entity(player.selected)
    if not destination then return end

    storage.player_copy_buffer = storage.player_copy_buffer or {}
    local buffer = storage.player_copy_buffer[event.player_index]
    if not buffer or not buffer.unit_number then return end

    local src_unit = buffer.unit_number
    local dest_unit = destination.unit_number
    if src_unit == dest_unit then return end

    local src_name = buffer.entity_name
    local dest_name = destination.name

    if src_name == "pneumatic-pump" and dest_name == "pneumatic-pump" then
        if pump_settings.copy(src_unit, dest_unit) then
            active_device_scanner.notify_settings_changed(destination)
            if player.opened and player.opened.valid and player.opened.name == "pump_configuration_frame" then
                pump_gui.open(player, destination)
            end
        end

    elseif src_name == "pneumatic-diverter" and dest_name == "pneumatic-diverter" then
        if diverter_settings.copy(src_unit, dest_unit) then
            active_device_scanner.notify_settings_changed(destination)
            if player.opened and player.opened.valid and player.opened.name == "diverter_configuration_frame" then
                diverter_gui.open(player, destination)
            end
        end

    elseif HUB_NAMES[src_name] and HUB_NAMES[dest_name] then
        if hub_settings.copy(src_unit, dest_unit) then
            hub_manager.notify_settings_changed(destination)
        end
    end
end

local function on_entity_settings_pasted(event)
    local source = resolve_target_entity(event.source)
    local destination = resolve_target_entity(event.destination)
    if not (source and destination and source.unit_number ~= destination.unit_number) then return end

    local player = event.player_index and game.get_player(event.player_index)

    if source.name == "pneumatic-pump" and destination.name == "pneumatic-pump" then
        pump_settings.copy(source.unit_number, destination.unit_number)
        active_device_scanner.notify_settings_changed(destination)
        if player and player.valid and player.opened and player.opened.valid and player.opened.name == "pump_configuration_frame" then
            pump_gui.open(player, destination)
        end

    elseif source.name == "pneumatic-diverter" and destination.name == "pneumatic-diverter" then
        diverter_settings.copy(source.unit_number, destination.unit_number)
        active_device_scanner.notify_settings_changed(destination)
        if player and player.valid and player.opened and player.opened.valid and player.opened.name == "diverter_configuration_frame" then
            diverter_gui.open(player, destination)
        end

    elseif HUB_NAMES[source.name] and HUB_NAMES[destination.name] then
        hub_settings.copy(source.unit_number, destination.unit_number)
        hub_manager.notify_settings_changed(destination)
    end
end

local function on_player_setup_blueprint(event)
    local blueprint = event.stack or event.record
    if not (blueprint and blueprint.set_blueprint_entity_tag) then return end

    local mapping = event.mapping
    if not mapping then return end

    if type(mapping) == "userdata" and mapping.get then
        mapping = mapping.get()
    end
    if type(mapping) ~= "table" then return end

    for bp_index, entity in pairs(mapping) do
        if entity and entity.valid and entity.unit_number then
            local name = entity.name
            if name == "pneumatic-pump" then
                local s = pump_settings.get(entity.unit_number)
                if s then
                    blueprint.set_blueprint_entity_tag(bp_index, "pneumatic_settings", util.table.deepcopy(s))
                end
            elseif name == "pneumatic-diverter" then
                local s = diverter_settings.get(entity.unit_number)
                if s then
                    local copy = util.table.deepcopy(s)
                    if copy.ports then
                        for i = 1, 4 do
                            if copy.ports[i] then copy.ports[i]._compiled = nil end
                        end
                    end
                    blueprint.set_blueprint_entity_tag(bp_index, "pneumatic_settings", copy)
                end
            elseif HUB_NAMES[name] then
                local s = hub_settings.get(entity.unit_number)
                if s then
                    blueprint.set_blueprint_entity_tag(bp_index, "pneumatic_settings", util.table.deepcopy(s))
                end
            end
        end
    end
end

function device_settings_copier.register_events()
    events.on_event("pneumatic-copy-settings", on_copy_settings)
    events.on_event("pneumatic-paste-settings", on_paste_settings)
    events.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)
    events.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)
end

return device_settings_copier