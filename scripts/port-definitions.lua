-- scripts/port-definitions.lua
local port_definitions = {

    -- FIXED HUBS
    ["capsule-hub-horizontal"] = {
        [defines.direction.north] = {
            { flow = "any", connection = "join", offset = {x = -0.5, y = -0.5} },
            { flow = "any", connection = "join", offset = {x =  0.5, y = -0.5} },
            { flow = "any", connection = "join", offset = {x = -0.5, y =  0.5} },
            { flow = "any", connection = "join", offset = {x =  0.5, y =  0.5} },
            { flow = "any", connection = "join", offset = {x = -1.0, y =  0.0} },
            { flow = "any", connection = "join", offset = {x =  1.0, y =  0.0} }
        }
    },

    ["capsule-hub-vertical"] = {
        [defines.direction.north] = {
            { flow = "any", connection = "join", offset = {x =  0.0, y = -1.0} },
            { flow = "any", connection = "join", offset = {x =  0.0, y =  1.0} },
            { flow = "any", connection = "join", offset = {x = -0.5, y = -0.5} },
            { flow = "any", connection = "join", offset = {x = -0.5, y =  0.5} },
            { flow = "any", connection = "join", offset = {x =  0.5, y = -0.5} },
            { flow = "any", connection = "join", offset = {x =  0.5, y =  0.5} }
        }
    },

    -- ROTATABLE TUBES
    ["pneumatic-tube"] = {
        [defines.direction.north] = {
            { flow = "any", connection = "merge", offset = {x = 0.0, y = -1.0} },
            { flow = "any", connection = "merge", offset = {x = 0.0, y =  1.0} }
        },
        [defines.direction.south] = {
            { flow = "any", connection = "merge", offset = {x = 0.0, y = -1.0} },
            { flow = "any", connection = "merge", offset = {x = 0.0, y =  1.0} }
        },
        [defines.direction.east] = {
            { flow = "any", connection = "merge", offset = {x = -1.0, y = 0.0} },
            { flow = "any", connection = "merge", offset = {x =  1.0, y = 0.0} }
        },
        [defines.direction.west] = {
            { flow = "any", connection = "merge", offset = {x = -1.0, y = 0.0} },
            { flow = "any", connection = "merge", offset = {x =  1.0, y = 0.0} }
        }
    },

    -- ROTATABLE PUMPS
    ["pneumatic-pump"] = {
        [defines.direction.north] = {
            { flow = "in",  connection = "join", offset = {x = 0.0, y =  1.0} },
            { flow = "out", connection = "join", offset = {x = 0.0, y = -1.0} }
        },
        [defines.direction.east] = {
            { flow = "in",  connection = "join", offset = {x = -1.0, y = 0.0} },
            { flow = "out", connection = "join", offset = {x =  1.0, y = 0.0} }
        },
        [defines.direction.south] = {
            { flow = "in",  connection = "join", offset = {x = 0.0, y = -1.0} },
            { flow = "out", connection = "join", offset = {x = 0.0, y =  1.0} }
        },
        [defines.direction.west] = {
            { flow = "in",  connection = "join", offset = {x =  1.0, y = 0.0} },
            { flow = "out", connection = "join", offset = {x = -1.0, y = 0.0} }
        }
    }
}

function port_definitions.get_ports(entity)
    return port_definitions[entity.name][entity.direction]
end

return port_definitions