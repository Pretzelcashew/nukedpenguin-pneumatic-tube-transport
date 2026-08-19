-- scripts/port-connections.lua
local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

local function get_port_world_position(entity, port)
    return {
        x = entity.position.x + port.offset.x,
        y = entity.position.y + port.offset.y
    }
end

local function positions_match(pos1, pos2)
    local epsilon = 0.05
    return math.abs(pos1.x - pos2.x) < epsilon and math.abs(pos1.y - pos2.y) < epsilon
end

local function handle_entity_placed(event)
    local entity = event.entity or event.created_entity
    if not (entity and entity.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then 
        game.print(string.format("[Debug] Ignored %s (No port definitions found)", entity.name))
        return 
    end

    storage.port_connections = storage.port_connections or {}
    local connections_found = 0

    game.print(string.format("[Debug] Placed %s at (%.1f, %.1f) | Direction: %s | Total Ports: %d", 
        entity.name, entity.position.x, entity.position.y, tostring(entity.direction), #ports))

    for port_index, port in ipairs(ports) do
        local port_pos = get_port_world_position(entity, port)

        game.print(string.format("  ├─ Probing Port %d at offset (%.1f, %.1f) -> world pos (%.2f, %.2f)", 
            port_index, port.offset.x, port.offset.y, port_pos.x, port_pos.y))

        -- Use a bounding box search around the port tile to guarantee catching adjacent entities
        local search_area = {
            {port_pos.x - 0.5, port_pos.y - 0.5},
            {port_pos.x + 0.5, port_pos.y + 0.5}
        }

        local candidates = entity.surface.find_entities_filtered{
            area = search_area
        }

        game.print(string.format("  │    └─ Surface area search found %d candidate entities nearby", #candidates))

        if #candidates <= 1 then
            game.print("  │    └─ [Fail] No other entities found in search area.")
        else
            for _, neighbor in ipairs(candidates) do
                if neighbor ~= entity and neighbor.valid then
                    local neighbor_ports = port_defs.get_ports(neighbor)

                    if not neighbor_ports then
                        game.print(string.format("  │    └─ [Fail] Candidate '%s' has no port definitions.", neighbor.name))
                    else
                        local matched_any = false
                        for n_index, n_port in ipairs(neighbor_ports) do
                            local n_port_pos = get_port_world_position(neighbor, n_port)

                            if positions_match(port_pos, n_port_pos) then
                                matched_any = true
                                table.insert(storage.port_connections, {
                                    entity_a = entity,
                                    port_a = port_index,
                                    entity_b = neighbor,
                                    port_b = n_index,
                                    connection_type = port.connection
                                })

                                connections_found = connections_found + 1
                                game.print(string.format(
                                    "  │    └─ [SUCCESS] Linked Port %d <-> %s Port %d [Mode: %s]",
                                    port_index, neighbor.name, n_index, port.connection
                                ))
                            end
                        end

                        if not matched_any then
                            game.print(string.format("  │    └─ [Fail] Candidate '%s' present, but no ports aligned with (%.2f, %.2f).", 
                                neighbor.name, port_pos.x, port_pos.y))
                        end
                    end
                end
            end
        end
    end

    if connections_found == 0 then
        game.print("  └─ Result: 0 connections established for this entity.")
    else
        game.print(string.format("  └─ Result: Successfully established %d connection(s).", connections_found))
    end
end

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_placed)
end