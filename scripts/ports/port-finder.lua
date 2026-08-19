-- scripts/port-finder.lua
local port_defs = require("scripts.ports.port-definitions")

local port_finder = {}

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

function port_finder.find_connections(entity)
    if not (entity and entity.valid) then return {} end

    local ports = port_defs.get_ports(entity)
    if not ports then return {} end

    local connections = {}

    for port_index, port in ipairs(ports) do
        local port_pos = get_port_world_position(entity, port)
        local search_area = {
            {port_pos.x - 0.5, port_pos.y - 0.5},
            {port_pos.x + 0.5, port_pos.y + 0.5}
        }

        local candidates = entity.surface.find_entities_filtered{ area = search_area }

        for _, neighbor in ipairs(candidates) do
            if neighbor ~= entity and neighbor.valid then
                local neighbor_ports = port_defs.get_ports(neighbor)

                if neighbor_ports then
                    for n_index, n_port in ipairs(neighbor_ports) do
                        local n_pos = get_port_world_position(neighbor, n_port)

                        if positions_match(port_pos, n_pos) then
                            table.insert(connections, {
                                port_index = port_index,
                                neighbor = neighbor,
                                neighbor_port_index = n_index
                            })
                        end
                    end
                end
            end
        end
    end

    return connections
end

return port_finder