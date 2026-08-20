-- scripts/ports/port-definitions.lua
local port_defs = {}

local definitions = {
    -- FIXED HUBS
    ["capsule-hub-horizontal"] = {
        [defines.direction.north] = {
            { group = 1, flow = "any", connection = "join", offset = {x = -0.5, y = -0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x =  0.5, y = -0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x = -0.5, y =  0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x =  0.5, y =  0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x = -1.0, y =  0.0} },
            { group = 1, flow = "any", connection = "join", offset = {x =  1.0, y =  0.0} }
        }
    },

    ["capsule-hub-vertical"] = {
        [defines.direction.north] = {
            { group = 1, flow = "any", connection = "join", offset = {x =  0.0, y = -1.0} },
            { group = 1, flow = "any", connection = "join", offset = {x =  0.0, y =  1.0} },
            { group = 1, flow = "any", connection = "join", offset = {x = -0.5, y = -0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x = -0.5, y =  0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x =  0.5, y = -0.5} },
            { group = 1, flow = "any", connection = "join", offset = {x =  0.5, y =  0.5} }
        }
    },

    -- ROTATABLE TUBES
    ["pneumatic-tube"] = {
        [defines.direction.north] = {
            { group = 1, flow = "any", connection = "merge", offset = {x = 0.0, y = -1.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x = 0.0, y =  1.0} }
        },
        [defines.direction.south] = {
            { group = 1, flow = "any", connection = "merge", offset = {x = 0.0, y = -1.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x = 0.0, y =  1.0} }
        },
        [defines.direction.east] = {
            { group = 1, flow = "any", connection = "merge", offset = {x = -1.0, y = 0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  1.0, y = 0.0} }
        },
        [defines.direction.west] = {
            { group = 1, flow = "any", connection = "merge", offset = {x = -1.0, y = 0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  1.0, y = 0.0} }
        }
    },

    -- ROTATABLE PUMPS
    ["pneumatic-pump"] = {
        [defines.direction.north] = {
            { group = 1, flow = "in",  connection = "join", offset = {x = 0.0, y =  1.0} },
            { group = 1, flow = "out", connection = "join", offset = {x = 0.0, y = -1.0} }
        },
        [defines.direction.east] = {
            { group = 1, flow = "in",  connection = "join", offset = {x = -1.0, y = 0.0} },
            { group = 1, flow = "out", connection = "join", offset = {x =  1.0, y = 0.0} }
        },
        [defines.direction.south] = {
            { group = 1, flow = "in",  connection = "join", offset = {x = 0.0, y = -1.0} },
            { group = 1, flow = "out", connection = "join", offset = {x = 0.0, y =  1.0} }
        },
        [defines.direction.west] = {
            { group = 1, flow = "in",  connection = "join", offset = {x =  1.0, y = 0.0} },
            { group = 1, flow = "out", connection = "join", offset = {x = -1.0, y = 0.0} }
        }
    },

    ["junction"] = {
        [defines.direction.north] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        }
    },
}

-- Flat array for engine-level filtering in find_entities_filtered
port_defs.registered_names = {}
for entity_name in pairs(definitions) do
    table.insert(port_defs.registered_names, entity_name)
end

-- scripts/ports/port-definitions.lua
function port_defs.get_ports(entity)
    local entity_ports = definitions[entity.name]
    if not entity_ports then return nil end

    local ports = entity_ports[entity.direction]
    if not ports then
        error(string.format("[Port Definitions] Missing direction definition '%s' for entity '%s'", tostring(entity.direction), entity.name))
    end

    return ports
end

return port_defs