--- Native Factorio 2.0 LuaRenderObject Cache & Recycler (Phase 2)
-- Pre-allocates and recycles native LuaRenderObject instances organized by archetype.
-- Eliminates LuaRenderObject::destroy() and rendering.draw_* churn during runtime flight and visual tracking.

local render_pool = {}

local MAX_POOL_PER_ARCHETYPE = 128 -- High-water mark per archetype per surface per player

--- Normalizes lease arguments to support both single-table and multi-argument signatures
local function normalize_lease_args(arg1, arg2, arg3)
    local opts, p_idx, surf
    if type(arg1) == "table" then
        opts = arg1
        surf = opts.surface
        local pl = opts.players
        p_idx = (pl and pl[1] and pl[1].valid and pl[1].index) or 1
    else
        p_idx = arg1 or 1
        surf = arg2
        opts = arg3
    end
    return opts, p_idx, surf
end

--- Fetches or creates the free pool list for player, surface, and archetype
local function get_free_list(player_index, surface_index, archetype)
    storage.render_pool = storage.render_pool or {}
    local p_pool = storage.render_pool[player_index]
    if not p_pool then
        p_pool = {}
        storage.render_pool[player_index] = p_pool
    end
    local s_pool = p_pool[surface_index]
    if not s_pool then
        s_pool = {}
        p_pool[surface_index] = s_pool
    end
    local list = s_pool[archetype]
    if not list then
        list = {}
        s_pool[archetype] = list
    end
    return list
end

--- Leases a circle render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw circle parameters
--- @return LuaRenderObject|nil
function render_pool.lease_circle(arg1, arg2, arg3)
    local options, p_idx, surface = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "circle")

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.target then obj.target = options.target end
            obj.color = options.color or { r = 1, g = 1, b = 1, a = 1 }
            obj.radius = options.radius or 1
            obj.filled = (options.filled == true)
            obj.width = options.width or 1
            obj.only_in_alt_mode = (options.only_in_alt_mode == true)
            if options.players then
                obj.players = options.players
            else
                obj.players = nil
            end
            obj.visible = true
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    return rendering.draw_circle(options)
end

--- Leases a sprite render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw sprite parameters
--- @return LuaRenderObject|nil
function render_pool.lease_sprite(arg1, arg2, arg3)
    local options, p_idx, surface = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "sprite")

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.target then obj.target = options.target end
            if options.sprite then obj.sprite = options.sprite end
            if options.x_scale then obj.x_scale = options.x_scale end
            if options.y_scale then obj.y_scale = options.y_scale end
            if options.render_layer then obj.render_layer = options.render_layer end
            if options.only_in_alt_mode ~= nil then obj.only_in_alt_mode = options.only_in_alt_mode end
            if options.players then obj.players = options.players end
            if options.tint then obj.tint = options.tint end
            obj.visible = true
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    return rendering.draw_sprite(options)
end

--- Leases a text render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw text parameters
--- @return LuaRenderObject|nil
function render_pool.lease_text(arg1, arg2, arg3)
    local options, p_idx, surface = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "text")

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.target then obj.target = options.target end
            if options.text then obj.text = options.text end
            if options.color then obj.color = options.color end
            if options.scale then obj.scale = options.scale end
            if options.alignment then obj.alignment = options.alignment end
            if options.only_in_alt_mode ~= nil then obj.only_in_alt_mode = options.only_in_alt_mode end
            if options.players then obj.players = options.players end
            obj.visible = true
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    return rendering.draw_text(options)
end

--- Leases a line render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw line parameters
--- @return LuaRenderObject|nil
function render_pool.lease_line(arg1, arg2, arg3)
    local options, p_idx, surface = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "line")

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.from then obj.from = options.from end
            if options.to then obj.to = options.to end
            if options.color then obj.color = options.color end
            if options.width then obj.width = options.width end
            if options.only_in_alt_mode ~= nil then obj.only_in_alt_mode = options.only_in_alt_mode end
            if options.players then obj.players = options.players end
            obj.visible = true
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    return rendering.draw_line(options)
end

--- Recycles a leased render object back into the pool, setting visible = false
--- @param player_index number|nil
--- @param render_obj LuaRenderObject
function render_pool.recycle(player_index, render_obj)
    if not (render_obj and render_obj.valid) then return end
    if render_obj.visible == false then return end
    render_obj.visible = false

    local archetype = render_obj.type
    local surf = render_obj.surface
    if not (surf and surf.valid) then return end
    local s_idx = surf.index

    local p_idx = player_index
    if not p_idx then
        local players = render_obj.players
        if players and #players > 0 and players[1].valid then
            p_idx = players[1].index
        else
            p_idx = 1
        end
    end

    if archetype == "circle" then
        render_obj.color = { r = 1, g = 1, b = 1, a = 1 }
        render_obj.radius = 1
        render_obj.filled = false
        render_obj.width = 1
        render_obj.only_in_alt_mode = false
    elseif archetype == "text" then
        render_obj.text = ""
        render_obj.color = { r = 1, g = 1, b = 1, a = 1 }
        render_obj.scale = 1
        render_obj.alignment = "left"
        render_obj.only_in_alt_mode = false
    elseif archetype == "line" then
        render_obj.color = { r = 1, g = 1, b = 1, a = 1 }
        render_obj.width = 1
        render_obj.only_in_alt_mode = false
    elseif archetype == "sprite" then
        render_obj.tint = { r = 1, g = 1, b = 1, a = 1 }
        render_obj.x_scale = 1
        render_obj.y_scale = 1
        render_obj.only_in_alt_mode = false
    end

    local free_list = get_free_list(p_idx, s_idx, archetype)
    if #free_list >= MAX_POOL_PER_ARCHETYPE then
        render_obj.destroy()
        return
    end

    free_list[#free_list + 1] = render_obj
end

--- Recycles an array or dictionary of render objects
--- @param player_index number|nil
--- @param objects table
function render_pool.recycle_many(player_index, objects)
    if not objects then return end
    for _, obj in pairs(objects) do
        render_pool.recycle(player_index, obj)
    end
end

render_pool.release = render_pool.recycle
render_pool.release_circle = render_pool.recycle
render_pool.release_sprite = render_pool.recycle
render_pool.release_text = render_pool.recycle
render_pool.release_line = render_pool.recycle
render_pool.release_many = render_pool.recycle_many

--- Clears all pooled objects for a player
--- @param player_index number
function render_pool.clear_player(player_index)
    if not (storage.render_pool and storage.render_pool[player_index]) then return end
    local p_pool = storage.render_pool[player_index]
    for _, s_pool in pairs(p_pool) do
        for _, list in pairs(s_pool) do
            for i = 1, #list do
                local obj = list[i]
                if obj and obj.valid then
                    obj.destroy()
                end
            end
        end
    end
    storage.render_pool[player_index] = nil
end

--- Clears all pooled objects across all players and surfaces
function render_pool.clear_all()
    if not storage.render_pool then return end
    for p_idx in pairs(storage.render_pool) do
        render_pool.clear_player(p_idx)
    end
    storage.render_pool = {}
end

--- Returns pool statistics for diagnostic inspection
--- @param player_index number
--- @param surface_index number
--- @return table stats
function render_pool.get_stats(player_index, surface_index)
    local stats = { total_pooled = 0, by_archetype = {} }
    if not (storage.render_pool and storage.render_pool[player_index]) then return stats end
    local s_pool = storage.render_pool[player_index][surface_index]
    if not s_pool then return stats end

    for arch, list in pairs(s_pool) do
        local count = #list
        stats.by_archetype[arch] = count
        stats.total_pooled = stats.total_pooled + count
    end
    return stats
end

--- Runs an automated test suite verifying leasing, recycling, property mutation, and zero allocations
--- @param player LuaPlayer|nil
--- @return boolean success
function render_pool.run_tests(player)
    local function log_msg(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_msg("[color=yellow][RenderPool Test][/color] Starting LuaRenderObject pool self-test...")

    local surf = (player and player.valid and player.surface) or game.surfaces[1]
    local p_idx = (player and player.valid and player.index) or 1
    local p_ref = (player and player.valid and player) or nil

    -- Test 1: Circle Leasing & Initialization
    local c1 = render_pool.lease_circle(p_idx, surf, {
        color = { r = 1, g = 0, b = 0, a = 1 },
        radius = 0.5,
        filled = true,
        target = { 0, 0 },
        players = p_ref and { p_ref } or nil
    })
    if not (c1 and c1.valid and c1.visible) then
        log_msg("[color=red][RenderPool Test] Test 1 FAILED: Circle lease or visibility invalid[/color]")
        return false
    end
    local c1_id = c1.id
    log_msg("[color=green][RenderPool Test] Test 1: Circle Leasing -> PASSED[/color]")

    -- Test 2: Recycling & Visibility Masking
    render_pool.recycle(p_idx, c1)
    if c1.visible ~= false then
        log_msg("[color=red][RenderPool Test] Test 2 FAILED: Render object visibility should be false after recycling[/color]")
        return false
    end
    log_msg("[color=green][RenderPool Test] Test 2: Recycling & In-place Masking -> PASSED[/color]")

    -- Test 3: Zero-Allocation Handle Reuse & Property Mutation
    local c2 = render_pool.lease_circle(p_idx, surf, {
        color = { r = 0, g = 1, b = 0, a = 1 },
        radius = 0.75,
        filled = false,
        width = 2,
        target = { 10, 10 },
        players = p_ref and { p_ref } or nil
    })
    if c2.id ~= c1_id then
        log_msg("[color=red][RenderPool Test] Test 3 FAILED: Expected reused render id " .. tostring(c1_id) .. ", got new id " .. tostring(c2.id) .. "[/color]")
        return false
    end
    if c2.visible ~= true or c2.radius ~= 0.75 or c2.width ~= 2 or c2.filled ~= false then
        log_msg("[color=red][RenderPool Test] Test 3 FAILED: In-place property mutations did not apply properly[/color]")
        return false
    end
    log_msg("[color=green][RenderPool Test] Test 3: Zero-Allocation Handle Reuse -> PASSED (0 C++ object churn)[/color]")

    -- Test 4: Sprite Billboard Leasing & Mutation
    local s1 = render_pool.lease_sprite(p_idx, surf, {
        sprite = "utility/warning_icon",
        target = { 5, 5 },
        x_scale = 0.5,
        y_scale = 0.5,
        players = p_ref and { p_ref } or nil
    })
    if not (s1 and s1.valid and s1.visible) then
        log_msg("[color=red][RenderPool Test] Test 4 FAILED: Sprite lease invalid[/color]")
        return false
    end
    local s1_id = s1.id
    render_pool.recycle(p_idx, s1)
    local s2 = render_pool.lease_sprite(p_idx, surf, {
        sprite = "utility/confirm_slot",
        target = { 15, 15 },
        x_scale = 0.8,
        y_scale = 0.8,
        players = p_ref and { p_ref } or nil
    })
    if s2.id ~= s1_id or s2.sprite ~= "utility/confirm_slot" then
        log_msg("[color=red][RenderPool Test] Test 4 FAILED: Sprite handle not reused or sprite not updated[/color]")
        return false
    end
    log_msg("[color=green][RenderPool Test] Test 4: Sprite Billboard Leasing & Mutation -> PASSED[/color]")

    -- Test 5: Text Billboard Leasing & Mutation
    local t1 = render_pool.lease_text(p_idx, surf, {
        text = "Phase 2 Test",
        target = { 0, 2 },
        color = { r = 1, g = 1, b = 1, a = 1 },
        scale = 1.0,
        players = p_ref and { p_ref } or nil
    })
    if not (t1 and t1.valid and t1.visible) then
        log_msg("[color=red][RenderPool Test] Test 5 FAILED: Text lease invalid[/color]")
        return false
    end
    local t1_id = t1.id
    render_pool.recycle(p_idx, t1)
    local t2 = render_pool.lease_text(p_idx, surf, {
        text = "Phase 2 Mutated",
        target = { 0, 4 },
        color = { r = 1, g = 1, b = 0, a = 1 },
        scale = 1.2,
        players = p_ref and { p_ref } or nil
    })
    if t2.id ~= t1_id or t2.text ~= "Phase 2 Mutated" then
        log_msg("[color=red][RenderPool Test] Test 5 FAILED: Text handle not reused or text not updated[/color]")
        return false
    end
    log_msg("[color=green][RenderPool Test] Test 5: Text Billboard Leasing & Mutation -> PASSED[/color]")

    -- Test 6: Clean Pool Wipe
    render_pool.recycle(p_idx, c2)
    render_pool.recycle(p_idx, s2)
    render_pool.recycle(p_idx, t2)
    render_pool.clear_player(p_idx)
    local stats = render_pool.get_stats(p_idx, surf.index)
    if stats.total_pooled ~= 0 then
        log_msg("[color=red][RenderPool Test] Test 6 FAILED: Pool count should be 0 after clear_player[/color]")
        return false
    end
    log_msg("[color=green][RenderPool Test] Test 6: Pool Cleanup & Destruction -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][RenderPool Test] ALL 6 TESTS PASSED! LuaRenderObject Cache & Recycler operational.[/font][/color]")
    return true
end

return render_pool
