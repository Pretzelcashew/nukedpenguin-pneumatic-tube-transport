local liminal_surface = {}

local SURFACE_NAME = "liminal_surface"
local GRID_SPACING = 8
local GRID_WIDTH = 50

--- Initializes persistent storage for the liminal surface grid allocation system.
function liminal_surface.init_storage()
    storage.liminal_grid = storage.liminal_grid or {
        next_index = 0,
        free_slots = {}
    }
end

--- Retrieves the liminal surface, creating it as an unconstrained surface if it doesn't exist.
function liminal_surface.get()
    local surface = game.surfaces[SURFACE_NAME]
    if surface then return surface end

    local map_gen_settings = {
        width = 0,
        height = 0,
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
    surface.generate_with_lab_tiles = true
    
    return surface
end

--- Ensures the chunk containing a position is synchronously generated on the surface.
--- @param surface LuaSurface
--- @param pos MapPosition
function liminal_surface.ensure_chunk_at(surface, pos)
    if not (surface and surface.valid and pos and pos.x and pos.y) then return end
    local chunk_pos = { math.floor(pos.x / 32), math.floor(pos.y / 32) }
    if not surface.is_chunk_generated(chunk_pos) then
        surface.request_to_generate_chunks(pos, 0)
        surface.force_generate_chunk_requests()
    end
end

--- Allocates a spaced grid position on liminal_surface, reusing freed positions when available.
--- @return MapPosition position {x = number, y = number}
function liminal_surface.allocate_position()
    liminal_surface.init_storage()
    local grid = storage.liminal_grid

    if #grid.free_slots > 0 then
        return table.remove(grid.free_slots)
    end

    local idx = grid.next_index
    grid.next_index = idx + 1

    local col = idx % GRID_WIDTH
    local row = math.floor(idx / GRID_WIDTH)

    return {
        x = col * GRID_SPACING,
        y = row * GRID_SPACING
    }
end

--- Releases a grid position back into the free_slots pool for future reuse.
--- @param pos MapPosition|table
function liminal_surface.release_position(pos)
    if not (pos and pos.x and pos.y) then return end
    liminal_surface.init_storage()
    table.insert(storage.liminal_grid.free_slots, { x = pos.x, y = pos.y })
end

--- Finds a liminal capsule holder entity near a given surface position by proximity.
--- @param pos MapPosition Position on liminal_surface to search near
--- @param radius number|nil Search radius (default 3.5)
--- @return LuaEntity|nil holder
function liminal_surface.find_holder_near(pos, radius)
    if not (pos and pos.x and pos.y) then return nil end
    local surface = liminal_surface.get()
    local search_radius = radius or 3.5
    local entities = surface.find_entities_filtered{
        position = pos,
        radius = search_radius,
        type = "container"
    }
    for _, entity in ipairs(entities) do
        if entity.name == "invisible-capsule-holder" or entity.name == "visible-capsule-holder" then
            return entity
        end
    end
    return nil
end

return liminal_surface