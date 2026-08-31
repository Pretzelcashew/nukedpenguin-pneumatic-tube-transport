local liminal_surface = {}

local SURFACE_NAME = "liminal_surface"

-- Dual Grid Spacing & Domain Configuration
local WIDE_SPACING = 8
local WIDE_GRID_WIDTH = 50

local TIGHT_SPACING = 2
local TIGHT_GRID_WIDTH = 100
local TIGHT_BASE_Y = -100

--- Initializes persistent storage for the liminal surface grid allocation system.
function liminal_surface.init_storage()
    storage.liminal_grid = storage.liminal_grid or {}
    local grid = storage.liminal_grid

    if grid.wide_next_index == nil then
        grid.wide_next_index = grid.next_index or 0
        grid.wide_free_slots = grid.free_slots or {}
        grid.tight_next_index = 0
        grid.tight_free_slots = {}
    end
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

--- Paints cell platform and moat perimeter tiles for a liminal grid position.
--- @param surface LuaSurface
--- @param pos MapPosition
--- @param is_wide boolean
local function paint_cell_tiles(surface, pos, is_wide)
    if not (surface and surface.valid and pos) then return end

    local cx = math.floor(pos.x)
    local cy = math.floor(pos.y)

    local tiles = {}
    if is_wide then
        -- 7x7 block: 3x3 island platform centered at (cx, cy) surrounded by a 2-tile thick water moat
        for dx = -3, 3 do
            for dy = -3, 3 do
                local tx = cx + dx
                local ty = cy + dy
                if math.abs(dx) <= 1 and math.abs(dy) <= 1 then
                    table.insert(tiles, { name = "lab-dark-1", position = { tx, ty } })
                else
                    table.insert(tiles, { name = "water", position = { tx, ty } })
                end
            end
        end
    else
        table.insert(tiles, { name = "lab-dark-1", position = { cx, cy } })
    end

    surface.set_tiles(tiles, true)
end

--- Ensures the chunk containing a position is synchronously generated on the surface and tiles painted.
--- @param surface LuaSurface
--- @param pos MapPosition
--- @param is_wide boolean|nil
function liminal_surface.ensure_chunk_at(surface, pos, is_wide)
    if not (surface and surface.valid and pos and pos.x and pos.y) then return end
    local chunk_pos = { math.floor(pos.x / 32), math.floor(pos.y / 32) }
    if not surface.is_chunk_generated(chunk_pos) then
        surface.request_to_generate_chunks(pos, 0)
        surface.force_generate_chunk_requests()
    end
    paint_cell_tiles(surface, pos, is_wide == true)
end

--- Allocates a position on liminal_surface, reusing freed positions when available.
--- Selectively uses wide 8-tile cells for unit-spoilable cargo and tight 2-tile slots for non-unit cargo.
--- Position coordinates are offset by +0.5 to align entity centers perfectly with tile centers.
--- @param is_wide boolean|nil
--- @return MapPosition position {x = number, y = number}
--- @return boolean is_wide
function liminal_surface.allocate_position(is_wide)
    liminal_surface.init_storage()
    local grid = storage.liminal_grid

    if is_wide then
        if #grid.wide_free_slots > 0 then
            return table.remove(grid.wide_free_slots), true
        end

        local idx = grid.wide_next_index
        grid.wide_next_index = idx + 1

        local col = idx % WIDE_GRID_WIDTH
        local row = math.floor(idx / WIDE_GRID_WIDTH)

        return {
            x = col * WIDE_SPACING + 0.5,
            y = row * WIDE_SPACING + 0.5
        }, true
    else
        if #grid.tight_free_slots > 0 then
            return table.remove(grid.tight_free_slots), false
        end

        local idx = grid.tight_next_index
        grid.tight_next_index = idx + 1

        local col = idx % TIGHT_GRID_WIDTH
        local row = math.floor(idx / TIGHT_GRID_WIDTH)

        return {
            x = col * TIGHT_SPACING + 0.5,
            y = (TIGHT_BASE_Y - (row * TIGHT_SPACING)) + 0.5
        }, false
    end
end

--- Releases a grid position back into the appropriate free_slots pool for future reuse.
--- @param pos MapPosition|table
--- @param is_wide boolean|nil
function liminal_surface.release_position(pos, is_wide)
    if not (pos and pos.x and pos.y) then return end
    liminal_surface.init_storage()

    local wide_slot = is_wide
    if wide_slot == nil then
        wide_slot = (pos.y >= 0)
    end

    if wide_slot then
        table.insert(storage.liminal_grid.wide_free_slots, { x = pos.x, y = pos.y })
    else
        table.insert(storage.liminal_grid.tight_free_slots, { x = pos.x, y = pos.y })
    end
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