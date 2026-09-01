local creation_listener = require("scripts.flow.creation-listener")
local removal_listener = require("scripts.flow.removal-listener")
local state_listener = require("scripts.flow.state-listener")
local port_defs = require("scripts.flow.port-defs")
local debug_manager = require("scripts.debug-manager")

local connection_manager = {}

function connection_manager.init_storage()
    storage.flow_port_connections = storage.flow_port_connections or {}
end

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

function connection_manager.connect_entity(entity, player_idx)
    if not (entity and entity.valid and entity.unit_number) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    storage.flow_port_connections = storage.flow_port_connections or {}

    local surface = entity.surface
    local ex, ey = entity.position.x, entity.position.y

    for port_index, port in ipairs(ports) do
        local px, py = ex + port.offset.x, ey + port.offset.y
        local port_key_a = make_port_key(entity.unit_number, port_index)

        local candidates = surface.find_entities_filtered{
            area = {{px - 0.5, py - 0.5}, {px + 0.5, py + 0.5}},
            name = port_defs.registered_names
        }

        for _, neighbor in ipairs(candidates) do
            if neighbor ~= entity and neighbor.valid and neighbor.unit_number then
                local neighbor_ports = port_defs.get_ports(neighbor)
                if neighbor_ports then
                    local nx, ny = neighbor.position.x, neighbor.position.y

                    for n_index, n_port in ipairs(neighbor_ports) do
                        if math.abs((nx + n_port.offset.x) - px) < 0.05 and math.abs((ny + n_port.offset.y) - py) < 0.05 then
                            local port_key_b = make_port_key(neighbor.unit_number, n_index)

                            storage.flow_port_connections[port_key_a] = storage.flow_port_connections[port_key_a] or {}
                            storage.flow_port_connections[port_key_b] = storage.flow_port_connections[port_key_b] or {}

                            if not storage.flow_port_connections[port_key_a][port_key_b] then
                                storage.flow_port_connections[port_key_a][port_key_b] = true
                                storage.flow_port_connections[port_key_b][port_key_a] = true

                                debug_print(string.format("[Flow Engine] Connected %s #%d (Port %d) <-> %s #%d (Port %d) at (%.1f, %.1f)",
                                    entity.name, entity.unit_number, port_index,
                                    neighbor.name, neighbor.unit_number, n_index,
                                    px, py
                                ), player_idx)
                            end
                        end
                    end
                end
            end
        end
    end
end

function connection_manager.disconnect_entity(entity, player_idx)
    if not (entity and entity.valid and entity.unit_number) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    storage.flow_port_connections = storage.flow_port_connections or {}

    for port_index = 1, #ports do
        local port_key_a = make_port_key(entity.unit_number, port_index)
        local connections = storage.flow_port_connections[port_key_a]

        if connections then
            for port_key_b, _ in pairs(connections) do
                if storage.flow_port_connections[port_key_b] then
                    storage.flow_port_connections[port_key_b][port_key_a] = nil
                    if next(storage.flow_port_connections[port_key_b]) == nil then
                        storage.flow_port_connections[port_key_b] = nil
                    end
                end

                debug_print(string.format("[Flow Engine] Disconnected %s #%d (Port %d) <-> Port %s",
                    entity.name, entity.unit_number, port_index, port_key_b
                ), player_idx)
            end
            storage.flow_port_connections[port_key_a] = nil
        end
    end
end

-- Hook lifecycle listeners
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