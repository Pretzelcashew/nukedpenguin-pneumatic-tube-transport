local port_defs = {}

local definitions = {
    ["capsule-hub-horizontal"] = {
        [defines.direction.north] = {
            { offset = {x = -0.5, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x = -0.5, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x = -1.0, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x =  1.0, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true }
        }
    },

    ["capsule-hub-vertical"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x =  0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x = -0.5, y = -0.5}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x = -0.5, y =  0.5}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y = -0.5}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true },
            { offset = {x =  0.5, y =  0.5}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true }
        }
    },

    ["pneumatic-tube"] = {
        [defines.direction.north] = {
            { offset = {x = 0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x = 0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y = 0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.0, y = 0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x = -1.0, y = 0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.0, y = 0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["pneumatic-pump"] = {
        [defines.direction.north] = {
            { offset = {x = 0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y = 0.0}, dir = {x = -1, y =  0}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.0, y = 0.0}, dir = {x =  1, y =  0}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x = 0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  1.0, y = 0.0}, dir = {x =  1, y =  0}, group = 1, flow = -10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -1.0, y = 0.0}, dir = {x = -1, y =  0}, group = 1, flow =  10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["junction"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["crossflow-junction"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["stone-wall"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -0.5, y =  0.0}, dir = {x = -1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y =  0.0}, dir = {x =  1, y =  0}, group = 2, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["gate"] = {
        [defines.direction.north] = {
            { offset = {x = 0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x = 0.0, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x = 0.0, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x = -0.5, y = 0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y = 0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x = -0.5, y = 0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.5, y = 0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = true, sense_transmit = true, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["pneumatic-diverter"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.east] = {
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        },
        [defines.direction.west] = {
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, flow = 10, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false }
        }
    },

    ["pneumatic-capsule-counter"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y = -1.0}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.0, y =  1.0}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 }
        },
        [defines.direction.east] = {
            { offset = {x = -1.0, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  1.0, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 }
        },
        [defines.direction.west] = {
            { offset = {x = -1.0, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  1.0, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y = -0.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x = -0.5, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 },
            { offset = {x =  0.5, y =  0.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = false, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = false, sense = 15 }
        }
    },

    ["pneumatic-projector"] = {
        [defines.direction.north] = {
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = true,  cross_transit = true, is_muzzle = true },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false }
        },
        [defines.direction.east] = {
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = true,  cross_transit = true, is_muzzle = true },
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false }
        },
        [defines.direction.south] = {
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = true,  cross_transit = true, is_muzzle = true },
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false }
        },
        [defines.direction.west] = {
            { offset = {x = -1.5, y =  0.0}, dir = {x = -1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = true,  cross_transit = true, is_muzzle = true },
            { offset = {x =  0.0, y = -1.5}, dir = {x =  0, y = -1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x =  1.5, y =  0.0}, dir = {x =  1, y =  0}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false },
            { offset = {x =  0.0, y =  1.5}, dir = {x =  0, y =  1}, group = 1, capsule_transmit = true, pressure_transmit = false, sense_transmit = false, kinetic_transmit = false, cross_transit = true, is_muzzle = false }
        }
    }
}

port_defs.registered_names = {
    "capsule-hub-horizontal",
    "capsule-hub-vertical",
    "pneumatic-tube",
    "pneumatic-pump",
    "junction",
    "crossflow-junction",
    "pneumatic-diverter",
    "pneumatic-capsule-counter",
    "pneumatic-projector"
}

function port_defs.get_ports(entity)
    if not (entity and entity.valid) then return nil end
    local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
    local entity_ports = definitions[real_name]
    if not entity_ports then return nil end

    local dir = entity.direction or defines.direction.north
    if real_name == "pneumatic-projector" and storage and storage.projector_settings then
        local p_set = entity.unit_number and storage.projector_settings[entity.unit_number]
        if not p_set and entity.name == "entity-ghost" then
            local pos = entity.position
            local sname = entity.surface and entity.surface.name or "unknown"
            local px = pos and (pos.x or pos[1] or 0) or 0
            local py = pos and (pos.y or pos[2] or 0) or 0
            local ghost_key = "ghost@" .. real_name .. "@" .. sname .. "@" .. px .. "," .. py
            p_set = storage.projector_settings[ghost_key]
            if not p_set and storage.ghost_by_pos then
                local alt_key = real_name .. "@" .. sname .. "@" .. px .. "," .. py
                local g_id = storage.ghost_by_pos[alt_key] or storage.ghost_by_pos[ghost_key]
                if g_id then
                    p_set = storage.projector_settings[g_id]
                end
            end
        end
        if p_set and p_set.muzzle_dir then
            dir = p_set.muzzle_dir
        end
    end

    local ports = entity_ports[dir]
    if not ports then
        ports = entity_ports[defines.direction.north]
    end
    return ports
end

function port_defs.get_character_port_pos(pos, direction)
    if not pos then return nil end
    local cx = pos.x or pos[1]
    local cy = pos.y or pos[2]
    if not (cx and cy) then return nil end

    -- Candidate 1: North/South vertical beam alignment (x is half-integer, y is integer)
    local x1 = math.floor(cx) + 0.5
    local y1 = math.floor(cy + 0.5)
    local d1 = (cx - x1) * (cx - x1) + (cy - y1) * (cy - y1)

    -- Candidate 2: East/West horizontal beam alignment (x is integer, y is half-integer)
    local x2 = math.floor(cx + 0.5)
    local y2 = math.floor(cy) + 0.5
    local d2 = (cx - x2) * (cx - x2) + (cy - y2) * (cy - y2)

    local primary, secondary, alignment
    if math.abs(d1 - d2) < 0.15 and direction then
        if direction == defines.direction.east or direction == defines.direction.west then
            primary = {x = x2, y = y2}
            secondary = {x = x1, y = y1}
            alignment = "horizontal"
        else
            primary = {x = x1, y = y1}
            secondary = {x = x2, y = y2}
            alignment = "vertical"
        end
    elseif d1 <= d2 then
        primary = {x = x1, y = y1}
        secondary = {x = x2, y = y2}
        alignment = "vertical"
    else
        primary = {x = x2, y = y2}
        secondary = {x = x1, y = y1}
        alignment = "horizontal"
    end
    return primary, alignment, secondary
end

function port_defs.get_character_influence_positions(pos, direction)
    local primary, alignment, secondary = port_defs.get_character_port_pos(pos, direction)
    if not primary then return nil end

    local positions = { primary }
    if secondary then
        positions[#positions + 1] = secondary
    end
    return positions, primary
end

function port_defs.get_character_port(character)
    if not (character and character.valid) then return nil end
    local ppos, alignment = port_defs.get_character_port_pos(character.position, character.direction)
    if not ppos then return nil end
    return {
        unit_number = character.unit_number,
        entity = character,
        surface_name = character.surface.name,
        pos = ppos,
        alignment = alignment,
        capsule_transmit = true,
        pressure_transmit = false,
        sense_transmit = false,
        kinetic_transmit = true,
        is_character = true
    }
end

return port_defs
