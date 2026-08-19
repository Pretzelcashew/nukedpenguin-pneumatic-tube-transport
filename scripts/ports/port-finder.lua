-- scripts/ports/port-finder.lua
local port_defs = require("scripts.ports.port-definitions")

local port_finder = {}

function port_finder.find_connections(entity)
    local ports = port_defs.get_ports(entity)
    if not ports then return {} end

    local connections = {}
    local surface = entity.surface
    local ex, ey = entity.position.x, entity.position.y

    for port_index, port in ipairs(ports) do
        local px, py = ex + port.offset.x, ey + port.offset.y

        -- The engine filters ghosts, trees, and non-port entities automatically
        local candidates = surface.find_entities_filtered{
            area = {{px - 0.5, py - 0.5}, {px + 0.5, py + 0.5}},
            name = port_defs.registered_names
        }

        for _, neighbor in ipairs(candidates) do
            if neighbor ~= entity then
                local neighbor_ports = port_defs.get_ports(neighbor)
                local nx, ny = neighbor.position.x, neighbor.position.y

                for n_index, n_port in ipairs(neighbor_ports) do
                    if math.abs((nx + n_port.offset.x) - px) < 0.05 and math.abs((ny + n_port.offset.y) - py) < 0.05 then
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

    return connections
end

return port_finder