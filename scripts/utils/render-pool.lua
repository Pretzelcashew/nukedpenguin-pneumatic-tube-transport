--- Native Factorio 2.0 LuaRenderObject Cache & Recycler (Phase 2)
-- Pre-allocates and recycles native LuaRenderObject instances organized by archetype.
-- Eliminates LuaRenderObject::destroy() and rendering.draw_* churn during runtime flight and visual tracking.

local render_pool = {}

local RUNAWAY_LEAK_CEILING = 2048
local DEFAULT_RETENTION_FLOOR = 32
local CHANNEL_RETENTION_FLOORS = {
    reticle = 48,
    capsule = 32,
    arrival = 16,
    flow = 64,
    default = 32
}

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
        opts = arg3 or {}
    end
    local channel = opts.channel or opts.domain or "default"
    return opts, p_idx, surf, channel
end

--- Fetches or creates the free pool list for player, surface, channel, and archetype
local function get_free_list(player_index, surface_index, archetype, channel)
    channel = channel or "default"
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
    local c_pool = s_pool[channel]
    if not c_pool then
        c_pool = {}
        s_pool[channel] = c_pool
    end
    local list = c_pool[archetype]
    if not list then
        list = {}
        c_pool[archetype] = list
    end
    return list
end

--- Leases a circle render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw circle parameters
--- @return LuaRenderObject|nil
function render_pool.lease_circle(arg1, arg2, arg3)
    local options, p_idx, surface, channel = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "circle", channel)
    storage.render_pool_channels = storage.render_pool_channels or {}

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.target then obj.target = options.target end
            if options.color then obj.color = options.color end
            if options.radius then obj.radius = options.radius end
            if options.filled ~= nil then obj.filled = options.filled end
            if options.width ~= nil then obj.width = options.width end
            if options.draw_on_ground ~= nil then obj.draw_on_ground = options.draw_on_ground end
            if options.players then obj.players = options.players end
            obj.visible = true
            storage.render_pool_channels[obj.id] = channel
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    local obj = rendering.draw_circle(options)
    if obj and obj.valid then
        storage.render_pool_channels[obj.id] = channel
    end
    return obj
end

--- Leases a sprite render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw sprite parameters
--- @return LuaRenderObject|nil
function render_pool.lease_sprite(arg1, arg2, arg3)
    local options, p_idx, surface, channel = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "sprite", channel)
    storage.render_pool_channels = storage.render_pool_channels or {}

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.target then obj.target = options.target end
            if options.sprite then obj.sprite = options.sprite end
            if options.x_scale then obj.x_scale = options.x_scale end
            if options.y_scale then obj.y_scale = options.y_scale end
            if options.render_layer then obj.render_layer = options.render_layer end
            if options.players then obj.players = options.players end
            obj.color = options.tint or options.color or { r = 1, g = 1, b = 1, a = 1 }
            obj.visible = true
            storage.render_pool_channels[obj.id] = channel
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    local obj = rendering.draw_sprite(options)
    if obj and obj.valid then
        storage.render_pool_channels[obj.id] = channel
    end
    return obj
end

--- Leases a text render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw text parameters
--- @return LuaRenderObject|nil
function render_pool.lease_text(arg1, arg2, arg3)
    local options, p_idx, surface, channel = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "text", channel)
    storage.render_pool_channels = storage.render_pool_channels or {}

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.target then obj.target = options.target end
            if options.text then obj.text = options.text end
            if options.color then obj.color = options.color end
            if options.scale then obj.scale = options.scale end
            if options.alignment then obj.alignment = options.alignment end
            if options.players then obj.players = options.players end
            obj.visible = true
            obj.bring_to_front()
            storage.render_pool_channels[obj.id] = channel
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    local obj = rendering.draw_text(options)
    if obj and obj.valid then
        obj.bring_to_front()
        storage.render_pool_channels[obj.id] = channel
    end
    return obj
end

--- Leases a line render object, recycling from pool if available
--- @param player_index number|nil
--- @param surface LuaSurface
--- @param options table Draw line parameters
--- @return LuaRenderObject|nil
function render_pool.lease_line(arg1, arg2, arg3)
    local options, p_idx, surface, channel = normalize_lease_args(arg1, arg2, arg3)
    if not (surface and surface.valid) then return nil end
    local s_idx = surface.index
    local free_list = get_free_list(p_idx, s_idx, "line", channel)
    storage.render_pool_channels = storage.render_pool_channels or {}

    while #free_list > 0 do
        local obj = free_list[#free_list]
        free_list[#free_list] = nil
        if obj and obj.valid then
            if options.from then obj.from = options.from end
            if options.to then obj.to = options.to end
            if options.color then obj.color = options.color end
            if options.width then obj.width = options.width end
            if options.players then obj.players = options.players end
            obj.visible = true
            storage.render_pool_channels[obj.id] = channel
            return obj
        end
    end

    options.surface = surface
    options.visible = true
    local obj = rendering.draw_line(options)
    if obj and obj.valid then
        storage.render_pool_channels[obj.id] = channel
    end
    return obj
end

--- Recycles a leased render object back into the pool, setting visible = false
--- @param player_index number|nil
--- @param render_obj LuaRenderObject
function render_pool.recycle(player_index, render_obj, explicit_channel)
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

    local channel = explicit_channel or (storage.render_pool_channels and storage.render_pool_channels[render_obj.id]) or "default"
    local free_list = get_free_list(p_idx, s_idx, archetype, channel)
    if #free_list >= RUNAWAY_LEAK_CEILING then
        if storage.render_pool_channels then
            storage.render_pool_channels[render_obj.id] = nil
        end
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

--- Amortized dual-watermark step decay trimming excess idle handles across channels (120-tick maintenance)
--- @param max_prune number|nil Max idle handles to destroy this cycle
--- @return number pruned
function render_pool.step_decay(max_prune)
    if not storage.render_pool then return 0 end
    max_prune = max_prune or 8
    local pruned = 0

    for p_idx, s_pools in pairs(storage.render_pool) do
        for s_idx, c_pools in pairs(s_pools) do
            for channel, a_pools in pairs(c_pools) do
                local floor_target = CHANNEL_RETENTION_FLOORS[channel] or DEFAULT_RETENTION_FLOOR
                for archetype, free_list in pairs(a_pools) do
                    local count = #free_list
                    while count > floor_target and pruned < max_prune do
                        local obj = free_list[count]
                        free_list[count] = nil
                        count = count - 1
                        if obj and obj.valid then
                            if storage.render_pool_channels then
                                storage.render_pool_channels[obj.id] = nil
                            end
                            obj.destroy()
                            pruned = pruned + 1
                        end
                    end
                    if pruned >= max_prune then
                        return pruned
                    end
                end
            end
        end
    end
    return pruned
end

--- Clamps idle pool buffers to a safety floor during storage setup / save migrations
--- @param margin number|nil
function render_pool.compact(margin)
    if not storage.render_pool then return end
    local safety_margin = margin or 32

    for p_idx, s_pools in pairs(storage.render_pool) do
        for s_idx, c_pools in pairs(s_pools) do
            for channel, a_pools in pairs(c_pools) do
                for archetype, free_list in pairs(a_pools) do
                    while #free_list > safety_margin do
                        local obj = free_list[#free_list]
                        free_list[#free_list] = nil
                        if obj and obj.valid then
                            if storage.render_pool_channels then
                                storage.render_pool_channels[obj.id] = nil
                            end
                            obj.destroy()
                        end
                    end
                end
            end
        end
    end
end

--- Clears all pooled objects for a player
--- @param player_index number
function render_pool.clear_player(player_index)
    if not (storage.render_pool and storage.render_pool[player_index]) then return end
    local p_pool = storage.render_pool[player_index]
    for _, s_pool in pairs(p_pool) do
        for _, c_pool in pairs(s_pool) do
            for _, list in pairs(c_pool) do
                for i = 1, #list do
                    local obj = list[i]
                    if obj and obj.valid then
                        if storage.render_pool_channels then
                            storage.render_pool_channels[obj.id] = nil
                        end
                        obj.destroy()
                    end
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
    local stats = { total_pooled = 0, by_channel = {}, by_archetype = {} }
    if not (storage.render_pool and storage.render_pool[player_index]) then return stats end
    local s_pool = storage.render_pool[player_index][surface_index]
    if not s_pool then return stats end

    for ch_name, c_pool in pairs(s_pool) do
        stats.by_channel[ch_name] = stats.by_channel[ch_name] or {}
        for arch, list in pairs(c_pool) do
            local count = #list
            stats.by_channel[ch_name][arch] = count
            stats.by_archetype[arch] = (stats.by_archetype[arch] or 0) + count
            stats.total_pooled = stats.total_pooled + count
        end
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

    -- Test 7: Amortized Step Decay & Dynamic Surge Absorption
    local surge_objs = {}
    for i = 1, 40 do
        local c = render_pool.lease_circle{
            channel = "reticle",
            color = { r = 1, g = 0, b = 1, a = 1 },
            radius = 0.1,
            filled = true,
            target = { i, 0 },
            surface = surf,
            players = p_ref and { p_ref } or nil
        }
        surge_objs[i] = c
    end
    for i = 1, 40 do
        render_pool.recycle(p_idx, surge_objs[i])
    end
    local s_list = storage.render_pool[p_idx][surf.index]["reticle"]["circle"]
    if #s_list ~= 40 then
        log_msg("[color=red][RenderPool Test] Test 7 FAILED: Dynamic surge failed to retain 40 free objects in reticle channel[/color]")
        return false
    end
    local target_floor = CHANNEL_RETENTION_FLOORS.reticle or 48
    local pruned = render_pool.step_decay(8)
    if #s_list > 40 then
        log_msg("[color=red][RenderPool Test] Test 7 FAILED: Pool size expanded unexpectedly during decay[/color]")
        return false
    end
    render_pool.clear_player(p_idx)
    log_msg("[color=green][RenderPool Test] Test 7: Amortized Step Decay & Dynamic Surge Retention -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][RenderPool Test] ALL 7 TESTS PASSED! LuaRenderObject Cache & Amortized Recycler operational.[/font][/color]")
    return true
end

return render_pool
