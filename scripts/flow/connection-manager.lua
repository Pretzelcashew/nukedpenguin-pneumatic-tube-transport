local creation_listener = require("scripts.flow.creation-listener")
local removal_listener = require("scripts.flow.removal-listener")
local state_listener = require("scripts.flow.state-listener")
local port_defs = require("scripts.flow.port-defs")
local flow_engine = require("scripts.flow.flow-engine")

local connection_manager = {}

function connection_manager.init_storage()
    storage.flow_port_registry = storage.flow_port_registry or {}
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.flow_unit_ports = storage.flow_unit_ports or {}
end

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

local function make_pos_key(surface_name, x, y)
    local rx = math.floor(x * 10 + 0.5) / 10
    local ry = math.floor(y * 10 + 0.5) / 10
    return string.format("%s@%.1f,%.1f", surface_name, rx, ry)
end

function connection_manager.connect_entity(entity, player_idx)
    if not (entity and entity.valid and entity.unit_number) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    storage.flow_port_registry = storage.flow_port_registry or {}
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.flow_unit_ports = storage.flow_unit_ports or {}

    local surface_name = entity.surface.name
    local ex, ey = entity.position.x, entity.position.y
    local unit_number = entity.unit_number

    storage.flow_unit_ports[unit_number] = storage.flow_unit_ports[unit_number] or {}

    for port_index, port in ipairs(ports) do
        local px, py = ex + port.offset.x, ey + port.offset.y
        local pos_key = make_pos_key(surface_name, px, py)
        local port_key_a = make_port_key(unit_number, port_index)

        storage.flow_unit_ports[unit_number][port_index] = pos_key

        storage.flow_port_registry[pos_key] = storage.flow_port_registry[pos_key] or {}

        for existing_key, existing in pairs(storage.flow_port_registry[pos_key]) do
            if existing.unit_number ~= unit_number then
                storage.flow_port_connections[port_key_a] = storage.flow_port_connections[port_key_a] or {}
                storage.flow_port_connections[existing_key] = storage.flow_port_connections[existing_key] or {}

                if not storage.flow_port_connections[port_key_a][existing_key] then
                    storage.flow_port_connections[port_key_a][existing_key] = true
                    storage.flow_port_connections[existing_key][port_key_a] = true

                    flow_engine.enqueue_port(existing_key)

                    debug_print(string.format("[Flow Engine] Connected %s #%d (Port %d) <-> #%d (Port %d) at %s",
                        entity.name, unit_number, port_index,
                        existing.unit_number, existing.port_index,
                        pos_key
                    ), player_idx)
                end
            end
        end

        storage.flow_port_registry[pos_key][port_key_a] = {
            unit_number = unit_number,
            port_index = port_index,
            entity_name = entity.name
        }

        flow_engine.enqueue_port(port_key_a)
    end
end

function connection_manager.disconnect_entity(entity, player_idx)
    if not (entity and entity.unit_number) then return end

    storage.flow_port_registry = storage.flow_port_registry or {}
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.flow_unit_ports = storage.flow_unit_ports or {}

    local unit_number = entity.unit_number
    local unit_ports = storage.flow_unit_ports[unit_number]

    if unit_ports then
        for port_index, pos_key in pairs(unit_ports) do
            local port_key_a = make_port_key(unit_number, port_index)

            if storage.flow_port_registry[pos_key] then
                storage.flow_port_registry[pos_key][port_key_a] = nil
                if next(storage.flow_port_registry[pos_key]) == nil then
                    storage.flow_port_registry[pos_key] = nil
                end
            end

            local connections = storage.flow_port_connections[port_key_a]
            if connections then
                for port_key_b, _ in pairs(connections) do
                    if storage.flow_port_connections[port_key_b] then
                        storage.flow_port_connections[port_key_b][port_key_a] = nil
                        if next(storage.flow_port_connections[port_key_b]) == nil then
                            storage.flow_port_connections[port_key_b] = nil
                        end
                    end

                    flow_engine.enqueue_port(port_key_b)

                    debug_print(string.format("[Flow Engine] Disconnected #%d (Port %d) <-> Port %s",
                        unit_number, port_index, port_key_b
                    ), player_idx)
                end
                storage.flow_port_connections[port_key_a] = nil
            end

            flow_engine.enqueue_port(port_key_a)
        end

        storage.flow_unit_ports[unit_number] = nil
    else
        if not entity.valid then return end
        local ports = port_defs.get_ports(entity)
        if not ports then return end

        local surface_name = entity.surface.name
        local ex, ey = entity.position.x, entity.position.y

        for port_index, port in ipairs(ports) do
            local px, py = ex + port.offset.x, ey + port.offset.y
            local pos_key = make_pos_key(surface_name, px, py)
            local port_key_a = make_port_key(unit_number, port_index)

            if storage.flow_port_registry[pos_key] then
                storage.flow_port_registry[pos_key][port_key_a] = nil
                if next(storage.flow_port_registry[pos_key]) == nil then
                    storage.flow_port_registry[pos_key] = nil
                end
            end

            local connections = storage.flow_port_connections[port_key_a]
            if connections then
                for port_key_b, _ in pairs(connections) do
                    if storage.flow_port_connections[port_key_b] then
                        storage.flow_port_connections[port_key_b][port_key_a] = nil
                        if next(storage.flow_port_connections[port_key_b]) == nil then
                            storage.flow_port_connections[port_key_b] = nil
                        end
                    end

                    flow_engine.enqueue_port(port_key_b)

                    debug_print(string.format("[Flow Engine] Disconnected %s #%d (Port %d) <-> Port %s",
                        entity.name, unit_number, port_index, port_key_b
                    ), player_idx)
                end
                storage.flow_port_connections[port_key_a] = nil
            end

            flow_engine.enqueue_port(port_key_a)
        end
    end
end

creation_listener.on_entity_created(function(entity, event)
    local player_idx = event and event.player_index
    connection_manager.connect_entity(entity, player_idx)
end)

removal_listener.on_entity_removed(function(entity, event)
    local player_idx = event and event.player_index
    connection_manager.disconnect_entity(entity, player_idx)
end)

state_listener.on_entity_state_changed(function(entity, event)
    local player_idx = event and event.player_index
    connection_manager.disconnect_entity(entity, player_idx)
    connection_manager.connect_entity(entity, player_idx)
end)

return connection_manager