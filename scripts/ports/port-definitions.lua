local diverter_settings = require("scripts.diverter-settings")
local pump_settings = require("scripts.pump-settings")

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
            { group = 1, flow = "in",  connection = "join", offset = {x = 0.0, y =  1.0}, pressure = -100 },
            { group = 1, flow = "out", connection = "join", offset = {x = 0.0, y = -1.0}, pressure = 100 }
        },
        [defines.direction.east] = {
            { group = 1, flow = "in",  connection = "join", offset = {x = -1.0, y = 0.0}, pressure = -100 },
            { group = 1, flow = "out", connection = "join", offset = {x =  1.0, y = 0.0}, pressure = 100 }
        },
        [defines.direction.south] = {
            { group = 1, flow = "in",  connection = "join", offset = {x = 0.0, y = -1.0}, pressure = -100 },
            { group = 1, flow = "out", connection = "join", offset = {x = 0.0, y =  1.0}, pressure = 100 }
        },
        [defines.direction.west] = {
            { group = 1, flow = "in",  connection = "join", offset = {x =  1.0, y = 0.0}, pressure = -100 },
            { group = 1, flow = "out", connection = "join", offset = {x = -1.0, y = 0.0}, pressure = 100 }
        }
    },

    ["junction"] = {
        [defines.direction.north] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.east] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.south] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.west] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        }
    },

    ["crossflow-junction"] = {
        [defines.direction.north] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 2, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 2, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.east] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 2, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 2, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.south] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 2, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 2, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        },
        [defines.direction.west] = {
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y = -0.5} },
            { group = 1, flow = "any", connection = "merge", offset = {x =  0.0, y =  0.5} },
            { group = 2, flow = "any", connection = "merge", offset = {x = -0.5, y =  0.0} },
            { group = 2, flow = "any", connection = "merge", offset = {x =  0.5, y =  0.0} }
        }
    },

    -- PNEUMATIC DIVERTER (Base Cardinal Port Offsets)
    ["pneumatic-diverter"] = {
        [defines.direction.north] = {
            { group = 1, offset = {x =  0.0, y = -1.5}, connection = "join" }, -- Port 1: North
            { group = 1, offset = {x =  1.5, y =  0.0}, connection = "join" }, -- Port 2: East
            { group = 1, offset = {x =  0.0, y =  1.5}, connection = "join" }, -- Port 3: South
            { group = 1, offset = {x = -1.5, y =  0.0}, connection = "join" }  -- Port 4: West
        },
        [defines.direction.east] = {
            { group = 1, offset = {x =  0.0, y = -1.5}, connection = "join" }, -- Port 1: North
            { group = 1, offset = {x =  1.5, y =  0.0}, connection = "join" }, -- Port 2: East
            { group = 1, offset = {x =  0.0, y =  1.5}, connection = "join" }, -- Port 3: South
            { group = 1, offset = {x = -1.5, y =  0.0}, connection = "join" }  -- Port 4: West
        },
        [defines.direction.south] = {
            { group = 1, offset = {x =  0.0, y = -1.5}, connection = "join" }, -- Port 1: North
            { group = 1, offset = {x =  1.5, y =  0.0}, connection = "join" }, -- Port 2: East
            { group = 1, offset = {x =  0.0, y =  1.5}, connection = "join" }, -- Port 3: South
            { group = 1, offset = {x = -1.5, y =  0.0}, connection = "join" }  -- Port 4: West
        },
        [defines.direction.west] = {
            { group = 1, offset = {x =  0.0, y = -1.5}, connection = "join" }, -- Port 1: North
            { group = 1, offset = {x =  1.5, y =  0.0}, connection = "join" }, -- Port 2: East
            { group = 1, offset = {x =  0.0, y =  1.5}, connection = "join" }, -- Port 3: South
            { group = 1, offset = {x = -1.5, y =  0.0}, connection = "join" }  -- Port 4: West
        }
    }
}

-- Flat array for engine-level filtering in find_entities_filtered
port_defs.registered_names = {}
for entity_name in pairs(definitions) do
    table.insert(port_defs.registered_names, entity_name)
end

function port_defs.get_ports(entity)
    local entity_ports = definitions[entity.name]
    if not entity_ports then return nil end

    local ports = entity_ports[entity.direction]
    if not ports then
        error(string.format("[Port Definitions] Missing direction definition '%s' for entity '%s'", tostring(entity.direction), entity.name))
    end

    if entity.name == "pneumatic-pump" and entity.unit_number then
        local is_enabled = pump_settings.is_pump_enabled(entity)
        local dynamic_ports = {}
        for i, base_port in ipairs(ports) do
            table.insert(dynamic_ports, {
                group = base_port.group,
                connection = base_port.connection,
                offset = base_port.offset,
                enabled = is_enabled,
                flow = is_enabled and base_port.flow or "none",
                pressure = is_enabled and base_port.pressure or nil
            })
        end
        return dynamic_ports
    end

    if entity.name == "pneumatic-diverter" and entity.unit_number then
        local settings = diverter_settings.get(entity.unit_number)
        if settings and settings.ports then
            local dynamic_ports = {}
            for i, base_port in ipairs(ports) do
                local p_setting = settings.ports[i]
                local is_enabled = diverter_settings.is_port_enabled(entity, i)
                local mode = p_setting and p_setting.mode or "input"

                local flow = "none"
                local pressure = nil

                if is_enabled then
                    if mode == "input" then
                        flow = "in"
                        pressure = -100
                    else
                        flow = "out"
                        pressure = 100
                    end
                end

                table.insert(dynamic_ports, {
                    group = base_port.group,
                    connection = base_port.connection,
                    offset = base_port.offset,
                    enabled = is_enabled,
                    flow = flow,
                    pressure = pressure
                })
            end
            return dynamic_ports
        end
    end

    return ports
end

return port_defs