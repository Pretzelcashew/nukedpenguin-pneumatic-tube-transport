-- scripts/port-definitions.lua
local port_definitions = {
    
    ["capsule-hub-horizontal"] = {
        -- 6 Ports using your specific offsets
        ports = {
            { id = "top_left",     offset = {x = -0.5, y = -1.0}, direction = defines.direction.north },
            { id = "top_right",    offset = {x =  0.5, y = -1.0}, direction = defines.direction.north },
            { id = "bottom_left",  offset = {x = -0.5, y =  1.0}, direction = defines.direction.south },
            { id = "bottom_right", offset = {x =  0.5, y =  1.0}, direction = defines.direction.south },
            { id = "far_left",     offset = {x = -2.0, y =  0.0}, direction = defines.direction.west },
            { id = "far_right",    offset = {x =  2.0, y =  0.0}, direction = defines.direction.east }
        }
    },

    ["capsule-hub-vertical"] = {
        -- 6 Ports using the flipped offsets for the vertical orientation
        ports = {
            { id = "far_top",      offset = {x =  0.0, y = -2.0}, direction = defines.direction.north },
            { id = "far_bottom",   offset = {x =  0.0, y =  2.0}, direction = defines.direction.south },
            { id = "left_top",     offset = {x = -1.0, y = -0.5}, direction = defines.direction.west },
            { id = "left_bottom",  offset = {x = -1.0, y =  0.5}, direction = defines.direction.west },
            { id = "right_top",    offset = {x =  1.0, y = -0.5}, direction = defines.direction.east },
            { id = "right_bottom", offset = {x =  1.0, y =  0.5}, direction = defines.direction.east }
        }
    }
}

return port_definitions