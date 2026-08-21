local liminal_surface = {}

local SURFACE_NAME = "liminal_surface"

--- Retrieves the liminal surface, creating it as a 1x1 void if it doesn't exist.
function liminal_surface.get()
    local surface = game.surfaces[SURFACE_NAME]
    if surface then return surface end

    -- Strictly clamp the surface to 1x1 tiles and strip all autoplace generation
    local map_gen_settings = {
        width = 1,
        height = 1,
        autoplace_controls = {},
        default_enable_all_autoplace_controls = false,
        autoplace_settings = {
            entity = { treat_missing_as_default = false },
            decorative = { treat_missing_as_default = false },
            tile = { treat_missing_as_default = false }
        },
        water = "none",
        starting_area = "none",
        peaceful_mode = true
    }

    surface = game.create_surface(SURFACE_NAME, map_gen_settings)
    surface.generate_with_lab_tiles = true -- Provides a clean, neutral floor for the 1x1 area
    
    return surface
end

return liminal_surface