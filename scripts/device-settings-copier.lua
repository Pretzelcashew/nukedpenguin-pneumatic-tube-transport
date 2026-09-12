local events = require("scripts.events")
local pump_settings = require("scripts.pumps.pump-settings")
local diverter_settings = require("scripts.diverters.diverter-settings")
local counter_settings = require("scripts.counters.counter-settings")
local projector_settings = require("scripts.projectors.projector-settings")
local hub_settings = require("scripts.hubs.hub-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local hub_manager = require("scripts.hubs.hub-manager")
local pump_gui = require("scripts.pumps.pump-gui")
local diverter_gui = require("scripts.diverters.diverter-gui")
local ok_cgui, counter_gui = pcall(require, "scripts.counters.counter-gui")
if not ok_cgui then counter_gui = nil end
local proxy_manager = require("scripts.proxy-manager")
local diverter_renderer = require("scripts.diverters.diverter-renderer")
local blueprint_sync = require("scripts.utils.blueprint-sync")
local util = require("util")

local device_settings_copier = {}

local HUB_NAMES = {
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true
}

local TARGET_NAMES = {
    ["pneumatic-pump"] = true,
    ["pneumatic-diverter"] = true,
    ["pneumatic-capsule-counter"] = true,
    ["capsule-hub-horizontal"] = true,
    ["capsule-hub-vertical"] = true,
    ["pneumatic-projector"] = true
}

local function resolve_target_entity(entity)
    if not (entity and entity.valid) then return nil end
    local name = entity.name == "entity-ghost" and entity.ghost_name or entity.name

    if TARGET_NAMES[name] then
        return entity
    end
    if name == "pneumatic-pump-circuit-proxy" or name == "pneumatic-diverter-circuit-proxy" or name == "pneumatic-capsule-counter-circuit-proxy" or name == "pneumatic-capsule-counter-red-proxy" or name == "pneumatic-capsule-counter-green-proxy" or name == "pneumatic-projector-circuit-proxy" then
        local main_name = name:gsub("%-circuit%-proxy", ""):gsub("%-red%-proxy", ""):gsub("%-green%-proxy", "")
        local main = entity.surface.find_entity(main_name, entity.position)
        if not (main and main.valid) then
            local ghosts = entity.surface.find_entities_filtered{
                ghost_name = main_name,
                position = entity.position
            }
            if ghosts and ghosts[1] and ghosts[1].valid then
                main = ghosts[1]
            end
        end
        if main and main.valid then return main end
    end
    return nil
end

device_settings_copier.clean_blueprint_orphans = blueprint_sync.clean_blueprint_orphans
device_settings_copier.extract_settings_from_blueprint_source = blueprint_sync.extract_settings_from_blueprint_source

local function on_copy_settings(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local selected = resolve_target_entity(player.selected)
    if not selected then return end

    storage.player_copy_buffer = storage.player_copy_buffer or {}
    storage.player_copy_buffer[event.player_index] = selected
end

local function apply_live_settings_copy(source, destination, player)
    destination = resolve_target_entity(destination)
    if not (destination and destination.valid) then
        return false
    end

    local dest_name = destination.name == "entity-ghost" and destination.ghost_name or destination.name
    local source_entity = resolve_target_entity(source)

    if source_entity and source_entity.valid then
        if source_entity == destination or source_entity.unit_number == destination.unit_number then
            return false
        end

        local src_name = source_entity.name == "entity-ghost" and source_entity.ghost_name or source_entity.name
        local success = false

        if src_name == "pneumatic-pump" and dest_name == "pneumatic-pump" then
            if pump_settings.copy(source_entity.unit_number, destination.unit_number) then
                success = true
                active_device_scanner.notify_settings_changed(destination)
                if player and player.valid and player.opened and player.opened.valid and player.opened.name == "pump_configuration_frame" then
                    pump_gui.open(player, destination)
                end
            end

        elseif src_name == "pneumatic-diverter" and dest_name == "pneumatic-diverter" then
            if diverter_settings.copy(source_entity.unit_number, destination.unit_number, source_entity.direction, destination.direction) then
                success = true
                active_device_scanner.notify_settings_changed(destination)
                if player and player.valid and player.opened and player.opened.valid and player.opened.name == "diverter_configuration_frame" then
                    diverter_gui.open(player, destination)
                end
            end

        elseif src_name == "pneumatic-capsule-counter" and dest_name == "pneumatic-capsule-counter" then
            if counter_settings.copy(source_entity.unit_number, destination.unit_number) then
                success = true
                active_device_scanner.notify_settings_changed(destination)
                if player and player.valid and player.opened and player.opened.valid and player.opened.name == "counter_configuration_frame" then
                    if counter_gui and counter_gui.open then
                        counter_gui.open(player, destination)
                    end
                end
            end

        elseif src_name == "pneumatic-projector" and dest_name == "pneumatic-projector" then
            if projector_settings.copy(source_entity.unit_number, destination.unit_number, source_entity.direction, destination.direction) then
                success = true
                active_device_scanner.notify_settings_changed(destination)
            end

        elseif HUB_NAMES[src_name] and HUB_NAMES[dest_name] then
            if hub_settings.copy(source_entity.unit_number, destination.unit_number) then
                success = true
                hub_manager.notify_settings_changed(destination)
            end
        end

        return success
    else
        local bp_settings, bp_direction = blueprint_sync.extract_settings_from_blueprint_source(source, destination)
        if bp_settings then
            if dest_name == "pneumatic-pump" then
                pump_settings.apply_blueprint_settings(destination.unit_number, bp_settings)
                active_device_scanner.notify_settings_changed(destination)
                return true
            elseif dest_name == "pneumatic-diverter" then
                if bp_direction and destination.direction ~= bp_direction then
                    local prev_dir = destination.direction
                    destination.direction = bp_direction
                    diverter_settings.rotate_ports(destination.unit_number, prev_dir, bp_direction)
                end
                diverter_settings.apply_blueprint_settings(destination.unit_number, bp_settings)
                diverter_renderer.update_render(destination)
                active_device_scanner.notify_settings_changed(destination)
                return true
            elseif dest_name == "pneumatic-capsule-counter" then
                counter_settings.apply_blueprint_settings(destination.unit_number, bp_settings)
                active_device_scanner.notify_settings_changed(destination)
                return true
            elseif dest_name == "pneumatic-projector" then
                if bp_direction and destination.direction ~= bp_direction then
                    local prev_dir = destination.direction
                    destination.direction = bp_direction
                    projector_settings.rotate_muzzle(destination.unit_number, prev_dir, bp_direction)
                end
                projector_settings.apply_blueprint_settings(destination.unit_number, bp_settings)
                active_device_scanner.notify_settings_changed(destination)
                return true
            elseif HUB_NAMES[dest_name] then
                hub_settings.apply_blueprint_settings(destination.unit_number, bp_settings)
                hub_manager.notify_settings_changed(destination)
                return true
            end
        end
    end

    return false
end

local function on_paste_settings(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local destination = resolve_target_entity(player.selected)
    if not destination then return end

    storage.player_copy_buffer = storage.player_copy_buffer or {}
    local source = storage.player_copy_buffer[event.player_index]

    if not (source and source.valid) then
        if player.entity_copy_source and player.entity_copy_source.valid then
            source = player.entity_copy_source
        end
    end

    if source then
        apply_live_settings_copy(source, destination, player)
    end
end

local function on_entity_settings_pasted(event)
    local player = event.player_index and game.get_player(event.player_index)
    local source = event.source
    local destination = event.destination

    if player and player.valid and source and type(source) == "userdata" and source.valid then
        storage.player_copy_buffer = storage.player_copy_buffer or {}
        storage.player_copy_buffer[player.index] = source
    end

    apply_live_settings_copy(source, destination, player)
end

device_settings_copier.process_entity_built_wire_tags = blueprint_sync.process_entity_built_wire_tags

function device_settings_copier.register_events()
    events.on_event("pneumatic-copy-settings", on_copy_settings)
    events.on_event("pneumatic-paste-settings", on_paste_settings)
    events.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)
    blueprint_sync.register_events()
end

return device_settings_copier