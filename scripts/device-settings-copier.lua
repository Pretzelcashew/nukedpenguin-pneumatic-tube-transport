local events = require("scripts.events")
local pump_settings = require("scripts.pump-settings")
local diverter_settings = require("scripts.diverter-settings")
local hub_settings = require("scripts.hubs.hub-settings")
local active_device_scanner = require("scripts.active-device-scanner")
local hub_manager = require("scripts.hubs.hub-manager")
local pump_gui = require("scripts.pump-gui")
local diverter_gui = require("scripts.diverter-gui")
local proxy_manager = require("scripts.proxy-manager")
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

local function get_blueprints_from_event_and_player(event)
    local blueprints = {}
    local seen = {}

    local function add_bp(bp)
        if not bp then return end
        if type(bp) == "userdata" and not bp.valid then return end
        if seen[bp] then return end
        seen[bp] = true
        table.insert(blueprints, bp)
    end

    if event then
        add_bp(event.stack)
        add_bp(event.item)
        add_bp(event.record)
    end

    local player = event and event.player_index and game.get_player(event.player_index)
    if player and player.valid then
        add_bp(player.cursor_stack)
        add_bp(player.blueprint_to_setup)
        if player.opened then
            if type(player.opened) == "userdata" and player.opened.valid then
                add_bp(player.opened)
            end
        end
    end

    return blueprints
end

function device_settings_copier.clean_blueprint_orphans(blueprint)
    if not blueprint then return false end
    if type(blueprint) == "userdata" and not blueprint.valid then return false end

    local ok, bp_entities = pcall(function() return blueprint.get_blueprint_entities() end)
    if not ok or not bp_entities or #bp_entities == 0 then return false end

    local registered_proxies = proxy_manager.get_registered_proxies()
    if not registered_proxies or not next(registered_proxies) then return false end

    local main_entities = {}
    for _, entity in ipairs(bp_entities) do
        if entity and entity.name and entity.position then
            table.insert(main_entities, entity)
        end
    end

    local is_orphan = {}
    local has_orphans = false

    for i, entity in ipairs(bp_entities) do
        local proxy_spec = registered_proxies[entity.name]
        if proxy_spec and entity.position then
            local px = entity.position.x or entity.position[1]
            local py = entity.position.y or entity.position[2]

            if px and py then
                local offset_x = proxy_spec.offset and proxy_spec.offset.x or 0
                local offset_y = proxy_spec.offset and proxy_spec.offset.y or 0
                local expected_main_x = px - offset_x
                local expected_main_y = py - offset_y

                local found_main = false
                for _, main_ent in ipairs(main_entities) do
                    if main_ent.name == proxy_spec.main_entity_name and main_ent.position then
                        local mx = main_ent.position.x or main_ent.position[1]
                        local my = main_ent.position.y or main_ent.position[2]
                        if mx and my and math.abs(mx - expected_main_x) < 0.05 and math.abs(my - expected_main_y) < 0.05 then
                            found_main = true
                            break
                        end
                    end
                end

                if not found_main then
                    is_orphan[i] = true
                    has_orphans = true
                end
            end
        end
    end

    if not has_orphans then
        return false
    end

    local new_entities = {}
    local old_to_new = {}

    for i, entity in ipairs(bp_entities) do
        if not is_orphan[i] then
            local new_index = #new_entities + 1
            local old_num = entity.entity_number or i
            old_to_new[old_num] = new_index
            old_to_new[i] = new_index
            table.insert(new_entities, entity)
        end
    end

    for new_index, entity in ipairs(new_entities) do
        entity.entity_number = new_index

        if entity.tags then
            if entity.tags.pneumatic_bp_index then
                entity.tags.pneumatic_bp_index = new_index
            end
            if entity.tags.pneumatic_settings then
                if entity.tags.pneumatic_settings.my_bp_index then
                    entity.tags.pneumatic_settings.my_bp_index = new_index
                end
                if entity.tags.pneumatic_settings.wire_connections then
                    local clean_wires = {}
                    for _, wspec in ipairs(entity.tags.pneumatic_settings.wire_connections) do
                        local new_target = old_to_new[wspec.target_bp_index]
                        if new_target then
                            wspec.target_bp_index = new_target
                            table.insert(clean_wires, wspec)
                        end
                    end
                    entity.tags.pneumatic_settings.wire_connections = #clean_wires > 0 and clean_wires or nil
                end
            end
        end

        if entity.wires then
            local clean_bp_wires = {}
            for _, wtuple in ipairs(entity.wires) do
                local target_old = wtuple[3]
                local target_new = old_to_new[target_old]
                if target_new then
                    wtuple[3] = target_new
                    table.insert(clean_bp_wires, wtuple)
                end
            end
            entity.wires = #clean_bp_wires > 0 and clean_bp_wires or nil
        end
    end

    pcall(function() blueprint.set_blueprint_entities(new_entities) end)
    return true
end

local function clean_container_or_blueprint(bp)
    if not bp then return end
    if type(bp) == "userdata" and not bp.valid then return end

    local object_name = nil
    pcall(function() object_name = bp.object_name end)

    if object_name == "LuaItemStack" then
        if not bp.valid_for_read then return end

        local is_bp = false
        pcall(function() is_bp = bp.is_blueprint end)
        if is_bp then
            device_settings_copier.clean_blueprint_orphans(bp)
        end

        local is_book = false
        pcall(function() is_book = bp.is_blueprint_book end)
        if is_book then
            local ok, inv = pcall(function() return bp.get_inventory(defines.inventory.item_main) end)
            if ok and inv and inv.valid then
                for i = 1, #inv do
                    local child = inv[i]
                    if child and child.valid_for_read then
                        clean_container_or_blueprint(child)
                    end
                end
            end
        end

    elseif object_name == "LuaRecord" then
        local ok_ent, has_entities = pcall(function() return bp.get_blueprint_entities ~= nil end)
        if ok_ent and has_entities then
            device_settings_copier.clean_blueprint_orphans(bp)
        end

        local ok_cont, contents = pcall(function() return bp.contents end)
        if ok_cont and contents then
            for _, child_rec in pairs(contents) do
                clean_container_or_blueprint(child_rec)
            end
        end

    else
        local ok, has_get_bp = pcall(function() return bp.get_blueprint_entities ~= nil end)
        if ok and has_get_bp then
            device_settings_copier.clean_blueprint_orphans(bp)
        end
    end
end

local function on_blueprint_changed_event(event)
    local bps = get_blueprints_from_event_and_player(event)
    for _, bp in ipairs(bps) do
        clean_container_or_blueprint(bp)
    end
end

local function get_proxy_connector_id(connector_id)
    if defines and defines.wire_connector_id then
        if connector_id == defines.wire_connector_id.circuit_red or
           connector_id == defines.wire_connector_id.combinator_input_red or
           connector_id == defines.wire_connector_id.combinator_output_red then
            return defines.wire_connector_id.combinator_input_red or connector_id
        elseif connector_id == defines.wire_connector_id.circuit_green or
               connector_id == defines.wire_connector_id.combinator_input_green or
               connector_id == defines.wire_connector_id.combinator_output_green then
            return defines.wire_connector_id.combinator_input_green or connector_id
        end
    end
    return connector_id
end

local function add_bp_wire(bp_entity, src_conn_id, target_bp_index, tgt_conn_id)
    if not bp_entity then return end
    bp_entity.wires = bp_entity.wires or {}
    for _, w in ipairs(bp_entity.wires) do
        if w[1] == src_conn_id and w[2] == src_conn_id and w[3] == target_bp_index and w[4] == tgt_conn_id then
            return
        end
    end
    table.insert(bp_entity.wires, { src_conn_id, src_conn_id, target_bp_index, tgt_conn_id })
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
    if not blueprint then return end

    local mapping = event.mapping
    if not mapping then return end

    if type(mapping) == "userdata" and mapping.get then
        mapping = mapping.get()
    end
    if type(mapping) ~= "table" then return end

    local bp_entities = blueprint.get_blueprint_entities()
    if not bp_entities then return end

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

            local proxy = nil
            local proxy_name = nil
            if name == "pneumatic-pump" then
                proxy = pump_settings.get_proxy(entity)
                proxy_name = "pneumatic-pump-circuit-proxy"
            elseif name == "pneumatic-diverter" then
                proxy = diverter_settings.get_proxy(entity)
                proxy_name = "pneumatic-diverter-circuit-proxy"
            end

            if proxy and proxy.valid and proxy.unit_number then
                if not unit_to_bp_index[proxy.unit_number] then
                    local proxy_bp_index = #bp_entities + 1
                    unit_to_bp_index[proxy.unit_number] = proxy_bp_index
                    local main_bp = bp_entities[bp_index]
                    if main_bp then
                        table.insert(bp_entities, {
                            entity_number = proxy_bp_index,
                            name = proxy_name,
                            position = { x = main_bp.position.x, y = main_bp.position.y },
                            direction = main_bp.direction,
                            tags = {
                                pneumatic_bp_index = proxy_bp_index
                            }
                        })
                    end
                end
            end
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
                    local proxy_bp_index = unit_to_bp_index[proxy.unit_number]
                    local proxy_bp_entity = proxy_bp_index and bp_entities[proxy_bp_index]

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

                                            if bp_entities[target_bp_index] then
                                                bp_entities[target_bp_index].tags = bp_entities[target_bp_index].tags or {}
                                                bp_entities[target_bp_index].tags.pneumatic_bp_index = target_bp_index
                                            end

                                            if proxy_bp_entity then
                                                local src_conn_id = get_proxy_connector_id(connector_id)
                                                local tgt_conn_id = target_conn.wire_connector_id
                                                local target_owner_name = target_conn.owner.name
                                                if target_owner_name == "pneumatic-pump-circuit-proxy" or target_owner_name == "pneumatic-diverter-circuit-proxy" then
                                                    tgt_conn_id = get_proxy_connector_id(tgt_conn_id)
                                                end

                                                add_bp_wire(proxy_bp_entity, src_conn_id, target_bp_index, tgt_conn_id)
                                                if bp_entities[target_bp_index] then
                                                    add_bp_wire(bp_entities[target_bp_index], tgt_conn_id, proxy_bp_index, src_conn_id)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if #wire_data > 0 then
                            settings_copy.wire_connections = wire_data
                        end
                    end

                    if proxy_bp_entity then
                        proxy_bp_entity.tags = proxy_bp_entity.tags or {}
                        proxy_bp_entity.tags.pneumatic_bp_index = proxy_bp_index
                    end
                end

                local main_bp_entity = bp_entities[bp_index]
                if main_bp_entity then
                    main_bp_entity.tags = main_bp_entity.tags or {}
                    main_bp_entity.tags.pneumatic_settings = settings_copy
                    main_bp_entity.tags.pneumatic_bp_index = bp_index
                end
            end
        end
    end

    blueprint.set_blueprint_entities(bp_entities)
    clean_container_or_blueprint(blueprint)
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
    events.on_event(defines.events.on_player_configured_blueprint, on_blueprint_changed_event)
    events.on_event(defines.events.on_gui_closed, on_blueprint_changed_event)

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