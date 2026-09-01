local port_defs = {}

local definitions = {
    ["capsule-hub-horizontal"] = {
        [defines.direction.north] = {
            { offset = {x = -0.5, y = -0.5} },
            { offset = {x =  0.5, y = -0.5} },
            { offset = {x = -0.5, y =  0.5} },
            { offset = {x =  0.5, y =  0.5} },
            { offset = {x = -1.0, y =  0.0} },
            { offset = {x =  1.0, y =  0.0} }
        }
    },

    ["capsule-hub-vertical"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.0} },
            { offset = {x =  0.0, y =  1.0} },
            { offset = {x = -0.5, y = -0.5} },
            { offset = {x = -0.5, y =  0.5} },
            { offset = {x =  0.5, y = -0.5} },
            { offset = {x =  0.5, y =  0.5} }
        }
    },

    ["pneumatic-tube"] = {
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
    },

    ["pneumatic-pump"] = {
        [defines.direction.north] = {
            { offset = {x = 0.0, y =  1.0}, flow = -10 },
            { offset = {x = 0.0, y = -1.0}, flow =  10 }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y = 0.0}, flow = -10 },
            { offset = {x =  1.0, y = 0.0}, flow =  10 }
        },
        [defines.direction.south] = {
            { offset = {x = 0.0, y = -1.0}, flow = -10 },
            { offset = {x = 0.0, y =  1.0}, flow =  10 }
        },
        [defines.direction.west] = {
            { offset = {x =  1.0, y = 0.0}, flow = -10 },
            { offset = {x = -1.0, y = 0.0}, flow =  10 }
        }
    },

    ["junction"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        }
    },

    ["crossflow-junction"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5} },
            { offset = {x =  0.0, y =  0.5} },
            { offset = {x = -0.5, y =  0.0} },
            { offset = {x =  0.5, y =  0.0} }
        }
    },

    ["pneumatic-diverter"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.5}, flow = 10 },
            { offset = {x =  1.5, y =  0.0}, flow = 10 },
            { offset = {x =  0.0, y =  1.5}, flow = 10 },
            { offset = {x = -1.5, y =  0.0}, flow = 10 }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -1.5}, flow = 10 },
            { offset = {x =  1.5, y =  0.0}, flow = 10 },
            { offset = {x =  0.0, y =  1.5}, flow = 10 },
            { offset = {x = -1.5, y =  0.0}, flow = 10 }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -1.5}, flow = 10 },
            { offset = {x =  1.5, y =  0.0}, flow = 10 },
            { offset = {x =  0.0, y =  1.5}, flow = 10 },
            { offset = {x = -1.5, y =  0.0}, flow = 10 }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -1.5}, flow = 10 },
            { offset = {x =  1.5, y =  0.0}, flow = 10 },
            { offset = {x =  0.0, y =  1.5}, flow = 10 },
            { offset = {x = -1.5, y =  0.0}, flow = 10 }
        }
    }
}

port_defs.registered_names = {}
for entity_name in pairs(definitions) do
    table.insert(port_defs.registered_names, entity_name)
end

function port_defs.get_ports(entity)
    if not (entity and entity.valid) then return nil end
    local entity_ports = definitions[entity.name]
    if not entity_ports then return nil end

    local dir = entity.direction or defines.direction.north
    local ports = entity_ports[dir]
    if not ports then
        ports = entity_ports[defines.direction.north]
    end
    return ports
end

return port_defs