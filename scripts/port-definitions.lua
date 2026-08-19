-- scripts/port-definitions.lua
local port_definitions = {

    -- FIXED HUBS
    ["capsule-hub-horizontal"] = {
        ports = {
            { offset = {x = -0.5, y = -0.5} },
            { offset = {x =  0.5, y = -0.5} },
            { offset = {x = -0.5, y =  0.5} },
            { offset = {x =  0.5, y =  0.5} },
            { offset = {x = -1.0, y =  0.0} },
            { offset = {x =  1.0, y =  0.0} }
        }
    },

    ["capsule-hub-vertical"] = {
        ports = {
            { offset = {x =  0.0, y = -1.0} },
            { offset = {x =  0.0, y =  1.0} },
            { offset = {x = -0.5, y = -0.5} },
            { offset = {x = -0.5, y =  0.5} },
            { offset = {x =  0.5, y = -0.5} },
            { offset = {x =  0.5, y =  0.5} }
        }
    },

    -- ROTATABLE TUBES (Bi-directional ports)
    ["pneumatic-tube"] = {
        by_direction = {
            [defines.direction.north] = {
                { offset = {x = 0.0, y = -1.0} },
                { offset = {x = 0.0, y =  1.0} }
            },
            [defines.direction.south] = {
                { offset = {x = 0.0, y = -1.0} },
                { offset = {x = 0.0, y =  1.0} }
            },
            [defines.direction.east] = {
                { offset = {x = -1.0, y = 0.0} },
                { offset = {x =  1.0, y = 0.0} }
            },
            [defines.direction.west] = {
                { offset = {x = -1.0, y = 0.0} },
                { offset = {x =  1.0, y = 0.0} }
            }
        }
    },

    -- ROTATABLE PUMPS (Input vs. Output flow)
    ["pneumatic-pump"] = {
        by_direction = {
            [defines.direction.north] = {
                { type = "input",  offset = {x = 0.0, y =  1.0} },
                { type = "output", offset = {x = 0.0, y = -1.0} }
            },
            [defines.direction.east] = {
                { type = "input",  offset = {x = -1.0, y = 0.0} },
                { type = "output", offset = {x =  1.0, y = 0.0} }
            },
            [defines.direction.south] = {
                { type = "input",  offset = {x = 0.0, y = -1.0} },
                { type = "output", offset = {x = 0.0, y =  1.0} }
            },
            [defines.direction.west] = {
                { type = "input",  offset = {x =  1.0, y = 0.0} },
                { type = "output", offset = {x = -1.0, y = 0.0} }
            }
        }
    }
}

function port_definitions.get_ports(entity)
    local def = port_definitions[entity.name]
    if not def then return nil end
    return def.ports or (def.by_direction and def.by_direction[entity.direction])
end

return port_definitions