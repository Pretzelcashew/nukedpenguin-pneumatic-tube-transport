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
    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    if TARGET_NAMES[name] then
        return entity
    end
    if name == "pneumatic-pump-circuit-proxy" or name == "pneumatic-diverter-circuit-proxy" then
        local main_name = name:gsub("-circuit-proxy", "")
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

    local name = selected.name
    if name == "entity-ghost" then name = selected.ghost_name end

    storage.player_copy_buffer = storage.player_copy_buffer or {}
    storage.player_copy_buffer[event.player_index] = {
        entity_name = name,
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
    if dest_name == "entity-ghost" then dest_name = destination.ghost_name end

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
    local src_name = source.name == "entity-ghost" and source.ghost_name or source.name
    local dest_name = destination.name == "entity-ghost" and destination.ghost_name or destination.name

    if src_name == "pneumatic-pump" and dest_name == "pneumatic-pump" then
        pump_settings.copy(source.unit_number, destination.unit_number)
        active_device_scanner.notify_settings_changed(destination)
        if player and player.valid and player.opened and player.opened.valid and player.opened.name == "pump_configuration_frame" then
            pump_gui.open(player, destination)
        end

    elseif src_name == "pneumatic-diverter" and dest_name == "pneumatic-diverter" then
        diverter_settings.copy(source.unit_number, destination.unit_number)
        active_device_scanner.notify_settings_changed(destination)
        if player and player.valid and player.opened and player.opened.valid and player.opened.name == "diverter_configuration_frame" then
            diverter_gui.open(player, destination)
        end

    elseif HUB_NAMES[src_name] and HUB_NAMES[dest_name] then
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

    local unit_to_bp_index = {}
    for bp_index, entity in pairs(mapping) do
        if entity and entity.valid and entity.unit_number then
            unit_to_bp_index[entity.unit_number] = bp_index
        end
    end

    for bp_index, entity in pairs(mapping) do
        if entity and entity.valid and entity.unit_number then
            local name = entity.name
            if name == "entity-ghost" then name = entity.ghost_name end

            local settings_copy = nil
            local proxy = nil

            if name == "pneumatic-pump" then
                local s = pump_settings.get(entity.unit_number)
                if s then settings_copy = util.table.deepcopy(s) end
                proxy = pump_settings.get_proxy(entity)

            elseif name == "pneumatic-diverter" then
                local s = diverter_settings.get(entity.unit_number)
                if s then
                    settings_copy = util.table.deepcopy(s)
                    if settings_copy.ports then
                        for i = 1, 4 do
                            if settings_copy.ports[i] then settings_copy.ports[i]._compiled = nil end
                        end
                    end
                end
                proxy = diverter_settings.get_proxy(entity)

            elseif HUB_NAMES[name] then
                local s = hub_settings.get(entity.unit_number)
                if s then settings_copy = util.table.deepcopy(s) end
            end

            if settings_copy or proxy then
                settings_copy = settings_copy or {}
                settings_copy.my_bp_index = bp_index

                if proxy and proxy.valid then
                    local connectors = proxy.get_wire_connectors(false)
                    if connectors then
                        local wire_data = {}
                        for connector_id, connector in pairs(connectors) do
                            if connector.connections then
                                for _, conn in ipairs(connector.connections) do
                                    local target_conn = conn.target
                                    if target_conn and target_conn.owner and target_conn.owner.valid then
                                        local target_unit = target_conn.owner.unit_number
                                        local target_bp_index = unit_to_bp_index[target_unit]
                                        if target_bp_index then
                                            table.insert(wire_data, {
                                                source_connector_id = connector_id,
                                                target_bp_index = target_bp_index,
                                                target_connector_id = target_conn.wire_connector_id
                                            })
                                            blueprint.set_blueprint_entity_tag(target_bp_index, "pneumatic_bp_index", target_bp_index)
                                        end
                                    end
                                end
                            end
                        end
                        if #wire_data > 0 then
                            settings_copy.wire_connections = wire_data
                        end
                    end
                end

                blueprint.set_blueprint_entity_tag(bp_index, "pneumatic_settings", settings_copy)
                blueprint.set_blueprint_entity_tag(bp_index, "pneumatic_bp_index", bp_index)
            end
        end
    end
end

function device_settings_copier.process_entity_built_wire_tags(entity, tags)
    if not (entity and entity.valid and tags) then return end

    local my_bp_index = tags.pneumatic_bp_index or (tags.pneumatic_settings and tags.pneumatic_settings.my_bp_index)
    if not my_bp_index then return end

    local surface_key = tostring(entity.surface.index)
    storage.bp_wire_cache = storage.bp_wire_cache or {}
    storage.bp_wire_cache[surface_key] = storage.bp_wire_cache[surface_key] or {}
    storage.pending_bp_wires = storage.pending_bp_wires or {}

    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    local target_for_wiring = entity
    if name == "pneumatic-pump" then
        target_for_wiring = pump_settings.get_proxy(entity) or entity
    elseif name == "pneumatic-diverter" then
        target_for_wiring = diverter_settings.get_proxy(entity) or entity
    end

    storage.bp_wire_cache[surface_key][my_bp_index] = target_for_wiring

    local settings = tags.pneumatic_settings
    if settings and settings.wire_connections and target_for_wiring.valid then
        for _, wire_spec in ipairs(settings.wire_connections) do
            local target_bp_index = wire_spec.target_bp_index
            local cached_target = storage.bp_wire_cache[surface_key][target_bp_index]

            if cached_target and cached_target.valid then
                local src_conn = target_for_wiring.get_wire_connector(wire_spec.source_connector_id, true)
                local tgt_conn = cached_target.get_wire_connector(wire_spec.target_connector_id, true)
                if src_conn and tgt_conn then
                    src_conn.connect_to(tgt_conn)
                end
            else
                table.insert(storage.pending_bp_wires, {
                    surface_key = surface_key,
                    source_entity = target_for_wiring,
                    source_connector_id = wire_spec.source_connector_id,
                    target_bp_index = target_bp_index,
                    target_connector_id = wire_spec.target_connector_id
                })
            end
        end
    end

    for i = #storage.pending_bp_wires, 1, -1 do
        local pending = storage.pending_bp_wires[i]
        if pending.surface_key == surface_key and pending.target_bp_index == my_bp_index then
            if pending.source_entity and pending.source_entity.valid and target_for_wiring.valid then
                local src_conn = pending.source_entity.get_wire_connector(pending.source_connector_id, true)
                local tgt_conn = target_for_wiring.get_wire_connector(pending.target_connector_id, true)
                if src_conn and tgt_conn then
                    src_conn.connect_to(tgt_conn)
                end
            end
            table.remove(storage.pending_bp_wires, i)
        end
    end
end

local function on_entity_built_wire_check(event)
    local entity = event.entity or event.destination
    if not (entity and entity.valid) then return end
    local tags = event.tags
    if tags and (tags.pneumatic_bp_index or (tags.pneumatic_settings and tags.pneumatic_settings.wire_connections)) then
        device_settings_copier.process_entity_built_wire_tags(entity, tags)
    end
end

function device_settings_copier.register_events()
    events.on_event("pneumatic-copy-settings", on_copy_settings)
    events.on_event("pneumatic-paste-settings", on_paste_settings)
    events.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)
    events.on_event(defines.events.on_player_setup_blueprint, on_player_setup_blueprint)

    local build_events = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.script_raised_revive,
        defines.events.on_space_platform_built_entity,
        defines.events.on_entity_cloned
    }
    for _, id in ipairs(build_events) do
        events.on_event(id, on_entity_built_wire_check)
    end
end

return device_settings_copier