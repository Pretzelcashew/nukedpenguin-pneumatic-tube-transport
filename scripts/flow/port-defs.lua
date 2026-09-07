local port_defs = {}

local definitions = {
    ["capsule-hub-horizontal"] = {
        [defines.direction.north] = {
            { offset = {x = -0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x = -0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x = -1.0, y =  0.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x =  1.0, y =  0.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true }
        }
    },

    ["capsule-hub-vertical"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x =  0.0, y =  1.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x = -0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x = -0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = true }
        }
    },

    ["pneumatic-tube"] = {
        [defines.direction.north] = {
            { offset = {x = 0.0, y = -1.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = 0.0, y =  1.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x = 0.0, y = -1.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = 0.0, y =  1.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y = 0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  1.0, y = 0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x = -1.0, y = 0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  1.0, y = 0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        }
    },

    ["pneumatic-pump"] = {
        [defines.direction.north] = {
            { offset = {x = 0.0, y =  1.0}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y = -1.0}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y = 0.0}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  1.0, y = 0.0}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x = 0.0, y = -1.0}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y =  1.0}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  1.0, y = 0.0}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = -1.0, y = 0.0}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        }
    },

    ["junction"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        }
    },

    ["crossflow-junction"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        }
    },

    ["pneumatic-diverter"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, cross_transit = false }
        }
    },

    ["pneumatic-capsule-counter"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.0, y =  1.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -1.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.0, y =  1.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y =  0.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  1.0, y =  0.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 }
        },
        [defines.direction.west] = {
            { offset = {x = -1.0, y =  0.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  1.0, y =  0.0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, cross_transit = false, sense = 15 }
        }
    }
}

port_defs.registered_names = {}
for entity_name in pairs(definitions) do
    table.insert(port_defs.registered_names, entity_name)
end

function port_defs.get_ports(entity)
    if not (entity and entity.valid) then return nil end
    local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
    local entity_ports = definitions[real_name]
    if not entity_ports then return nil end

    local dir = entity.direction or defines.direction.north
    local ports = entity_ports[dir]
    if not ports then
        ports = entity_ports[defines.direction.north]
    end
    return ports
end

return port_defs