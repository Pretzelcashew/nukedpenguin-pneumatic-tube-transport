-- File: scripts/flow/port-defs.lua

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
    },

    -- Vanilla Gate (Axis-Locked Pedestrian Crosswalk)
    ["gate"] = {
        [defines.direction.east] = {
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        }
    },

    -- Vanilla Wall Passthrough Collar (2-port inline passthrough)
    ["stone-wall"] = {
        [defines.direction.east] = {
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x = -0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, cross_transit = false }
        }
    }
}

-- Only active pneumatic machinery are tracked directly on startup by control.lua
port_defs.registered_names = {
    "capsule-hub-horizontal",
    "capsule-hub-vertical",
    "pneumatic-tube",
    "pneumatic-pump",
    "junction",
    "crossflow-junction",
    "pneumatic-diverter",
    "pneumatic-capsule-counter"
}
table.sort(port_defs.registered_names)

function port_defs.is_gate_closed(entity)
    if not (entity and entity.valid) then return false end
    if entity.is_closed then
        local ok, closed = pcall(entity.is_closed)
        if ok then
            return closed == true
        end
    end
    return false
end

function port_defs.get_gate_transmission_state(entity)
    local is_closed = true
    if entity and entity.valid then
        if entity.is_closed then
            local ok, closed = pcall(entity.is_closed)
            if ok then
                is_closed = (closed == true)
            end
        end
    end
    return {
        capsule_transmit = is_closed,
        pressure_transmit = is_closed,
        sense_transmit = true
    }
end

function port_defs.get_ports(entity, override_direction, dynamic_state)
    if not (entity and (entity.valid or entity.name)) then return nil end
    local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
    local entity_ports = definitions[real_name]
    if not entity_ports then return nil end

    local dir = override_direction
    if dir == "horizontal" or dir == "east" or dir == "west" or dir == "x" then
        dir = defines.direction.east
    elseif dir == "vertical" or dir == "north" or dir == "south" or dir == "y" then
        dir = defines.direction.north
    end

    if not dir then
        dir = entity.direction
    end

    dir = dir or defines.direction.north
    local ports = entity_ports[dir]
    if not ports then
        ports = entity_ports[defines.direction.north]
    end

    if dynamic_state and real_name == "gate" then
        local state = port_defs.get_gate_transmission_state(entity)
        local dynamic_ports = {}
        for i = 1, #ports do
            local p = ports[i]
            dynamic_ports[i] = {
                offset = p.offset,
                group = p.group,
                flow = p.flow,
                sense = p.sense,
                cross_transit = p.cross_transit,
                capsule_transmit = state.capsule_transmit,
                pressure_transmit = state.pressure_transmit,
                sense_transmit = true
            }
        end
        return dynamic_ports
    end

    return ports
end

return port_defs