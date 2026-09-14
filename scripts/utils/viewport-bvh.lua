--- Player Viewport Spatial BVH & Hysteresis Caching (Phase 3)
-- Manages spatial observer trees per surface tracking active player viewports.
-- Employs three concentric hysteresis bounds:
--   1. Inner Shrunk AABB: Zoom-in contraction threshold.
--   2. Padded Viewport AABB: Active culling boundary (+12 tiles padding).
--   3. Outer Fat AABB: Hysteresis shell (+24 tiles shell). Camera motion within
--      causes 0 BVH updates. Only breaches re-index into storage.viewport_bvh[surface_index].

local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local render_pool = require("scripts.utils.render-pool")

local viewport_bvh = {}

local PAD_TILES = 12       -- Padding beyond visible screen edge to prevent pop-in during fast travel
local SHELL_TILES = 24     -- Outer hysteresis shell margin beyond padded viewport
local SHRINK_RATIO = 0.5   -- Zoom-in contraction threshold ratio

--- Fetches or creates the dedicated viewport BVH for a surface
--- @param surface_index number
--- @return table tree
function viewport_bvh.get_tree(surface_index)
    storage.viewport_bvh = storage.viewport_bvh or {}
    local tree = storage.viewport_bvh[surface_index]
    if not tree then
        tree = trajectory_bvh.new_tree(surface_index)
        storage.viewport_bvh[surface_index] = tree
    else
        trajectory_bvh.attach(tree)
    end
    return tree
end

--- Calculates the raw half-dimensions in tiles of a player's screen frustum
--- @param player LuaPlayer
--- @return number frustum_hw, number frustum_hh
function viewport_bvh.get_player_frustum_radii(player)
    local res = player.display_resolution or { width = 1920, height = 1080 }
    local w = res.width or 1920
    local h = res.height or 1080
    local zoom = player.zoom or 1.0
    if zoom <= 0 then zoom = 1.0 end
    local scale = player.display_scale or 1.0
    if scale <= 0 then scale = 1.0 end

    local tile_w = (w / scale) / (32 * zoom)
    local tile_h = (h / scale) / (32 * zoom)
    local hw = math.min(150, tile_w * 0.5)
    local hh = math.min(150, tile_h * 0.5)
    return hw, hh
end

--- Updates or initializes a single player's concentric hysteresis viewports
--- @param player LuaPlayer
--- @return table entry
function viewport_bvh.update_player(player, override_pos, override_radii)
    storage.player_viewports = storage.player_viewports or {}
    local p_idx = player.index
    local surf = player.surface
    if not (surf and surf.valid) then return nil end
    local s_idx = surf.index

    local p_pos = override_pos or player.position
    local cx = p_pos.x
    local cy = p_pos.y

    local f_hw, f_hh
    if override_radii then
        f_hw, f_hh = override_radii.hw, override_radii.hh
    else
        f_hw, f_hh = viewport_bvh.get_player_frustum_radii(player)
    end
    local pad_hw = f_hw + PAD_TILES
    local pad_hh = f_hh + PAD_TILES
    local pad_min_x = cx - pad_hw
    local pad_max_x = cx + pad_hw
    local pad_min_y = cy - pad_hh
    local pad_max_y = cy + pad_hh

    local entry = storage.player_viewports[p_idx]

    -- Case 1: Fresh player initialization or surface transition
    if not entry or entry.surface_index ~= s_idx or not entry.leaf then
        if entry and entry.leaf and entry.surface_index then
            local old_tree = storage.viewport_bvh and storage.viewport_bvh[entry.surface_index]
            if old_tree then
                trajectory_bvh.remove(old_tree, entry.leaf)
            end
        end

        local fat_hw = pad_hw + SHELL_TILES
        local fat_hh = pad_hh + SHELL_TILES
        local fat_min_x = cx - fat_hw
        local fat_max_x = cx + fat_hw
        local fat_min_y = cy - fat_hh
        local fat_max_y = cy + fat_hh

        local inner_hw = fat_hw * SHRINK_RATIO
        local inner_hh = fat_hh * SHRINK_RATIO
        local inner_min_x = cx - inner_hw
        local inner_max_x = cx + inner_hw
        local inner_min_y = cy - inner_hh
        local inner_max_y = cy + inner_hh

        entry = {
            player_index = p_idx,
            surface_index = s_idx,
            pad_min_x = pad_min_x,
            pad_max_x = pad_max_x,
            pad_min_y = pad_min_y,
            pad_max_y = pad_max_y,
            fat_min_x = fat_min_x,
            fat_max_x = fat_max_x,
            fat_min_y = fat_min_y,
            fat_max_y = fat_max_y,
            inner_min_x = inner_min_x,
            inner_max_x = inner_max_x,
            inner_min_y = inner_min_y,
            inner_max_y = inner_max_y,
            center_x = cx,
            center_y = cy,
            breached_this_tick = true,
            updates_count = 1,
            leaf = nil
        }

        local tree = viewport_bvh.get_tree(s_idx)
        local leaf = {
            min_x = fat_min_x,
            min_y = fat_min_y,
            max_x = fat_max_x,
            max_y = fat_max_y,
            player_index = p_idx,
            player_entry = entry
        }
        entry.leaf = trajectory_bvh.insert(tree, leaf, "player:" .. p_idx)
        storage.player_viewports[p_idx] = entry
        viewport_bvh.sync_player_visibility(p_idx, s_idx)
        return entry
    end

    -- Case 2: Existing entry on same surface -> Test concentric hysteresis boundaries
    entry.pad_min_x = pad_min_x
    entry.pad_max_x = pad_max_x
    entry.pad_min_y = pad_min_y
    entry.pad_max_y = pad_max_y

    local breached_outer = (pad_min_x < entry.fat_min_x or pad_max_x > entry.fat_max_x or pad_min_y < entry.fat_min_y or pad_max_y > entry.fat_max_y)
    local breached_inner = (pad_min_x > entry.inner_min_x and pad_max_x < entry.inner_max_x and pad_min_y > entry.inner_min_y and pad_max_y < entry.inner_max_y)

    if breached_outer or breached_inner then
        local fat_hw = pad_hw + SHELL_TILES
        local fat_hh = pad_hh + SHELL_TILES
        local fat_min_x = cx - fat_hw
        local fat_max_x = cx + fat_hw
        local fat_min_y = cy - fat_hh
        local fat_max_y = cy + fat_hh

        local inner_hw = fat_hw * SHRINK_RATIO
        local inner_hh = fat_hh * SHRINK_RATIO
        local inner_min_x = cx - inner_hw
        local inner_max_x = cx + inner_hw
        local inner_min_y = cy - inner_hh
        local inner_max_y = cy + inner_hh

        entry.fat_min_x = fat_min_x
        entry.fat_max_x = fat_max_x
        entry.fat_min_y = fat_min_y
        entry.fat_max_y = fat_max_y
        entry.inner_min_x = inner_min_x
        entry.inner_max_x = inner_max_x
        entry.inner_min_y = inner_min_y
        entry.inner_max_y = inner_max_y
        entry.center_x = cx
        entry.center_y = cy
        entry.breached_this_tick = true
        entry.updates_count = (entry.updates_count or 0) + 1

        local tree = viewport_bvh.get_tree(s_idx)
        trajectory_bvh.update(tree, entry.leaf, fat_min_x, fat_min_y, fat_max_x, fat_max_y)
        viewport_bvh.sync_player_visibility(p_idx, s_idx)
    else
        entry.breached_this_tick = false
    end

    return entry
end

--- Updates all connected players and purges disconnected players from viewport trees
function viewport_bvh.update_all_players()
    storage.player_viewports = storage.player_viewports or {}
    local active_indices = {}

    for _, player in pairs(game.players) do
        if player and player.valid and player.connected ~= false then
            active_indices[player.index] = true
            viewport_bvh.update_player(player)
        end
    end

    for p_idx, entry in pairs(storage.player_viewports) do
        if not active_indices[p_idx] then
            if entry.leaf and entry.surface_index then
                local tree = storage.viewport_bvh and storage.viewport_bvh[entry.surface_index]
                if tree then
                    trajectory_bvh.remove(tree, entry.leaf)
                end
            end
            viewport_bvh.clear_player_visible_set(p_idx)
            storage.player_viewports[p_idx] = nil
        end
    end
end

--- Checks if a world position is inside any player's active padded viewport on a surface in O(log N)
--- @param surface_index number
--- @param x number
--- @param y number
--- @return boolean
function viewport_bvh.is_in_any_viewport(surface_index, x, y)
    if not (storage.viewport_bvh and surface_index and x and y) then return false end
    local tree = storage.viewport_bvh[surface_index]
    if not (tree and tree.root) then return false end

    local hits = {}
    trajectory_bvh.query_box(tree, x - 0.1, y - 0.1, x + 0.1, y + 0.1, hits)
    if #hits == 0 then return false end

    for i = 1, #hits do
        local entry = hits[i].player_entry
        if entry then
            if x >= entry.pad_min_x and x <= entry.pad_max_x and y >= entry.pad_min_y and y <= entry.pad_max_y then
                return true
            end
        end
    end
    return false
end

--- Queries all players whose outer fat viewport shells overlap an AABB box
--- @param surface_index number
--- @param min_x number
--- @param min_y number
--- @param max_x number
--- @param max_y number
--- @param out_players table Array of player indices
--- @return table out_players
function viewport_bvh.query_players_in_box(surface_index, min_x, min_y, max_x, max_y, out_players)
    out_players = out_players or {}
    if not (storage.viewport_bvh and surface_index) then return out_players end
    local tree = storage.viewport_bvh[surface_index]
    if not (tree and tree.root) then return out_players end

    local hits = {}
    trajectory_bvh.query_box(tree, min_x, min_y, max_x, max_y, hits)
    for i = 1, #hits do
        local leaf = hits[i]
        if leaf.player_index then
            out_players[#out_players + 1] = leaf.player_index
        end
    end
    return out_players
end

--- Fetches all active padded viewports for a surface (backward-compatible array format)
--- @param surface_index number
--- @return table array of { left, right, top, bottom, player_index }
function viewport_bvh.get_active_viewports(surface_index)
    local results = {}
    if not storage.player_viewports then return results end
    for p_idx, entry in pairs(storage.player_viewports) do
        if entry.surface_index == surface_index then
            results[#results + 1] = {
                left = entry.pad_min_x,
                right = entry.pad_max_x,
                top = entry.pad_min_y,
                bottom = entry.pad_max_y,
                player_index = p_idx
            }
        end
    end
    return results
end

--------------------------------------------------------------------------------
-- ACTIVE VISIBILITY SETS & OBSERVER INTERSECTION (PHASE 4)
--------------------------------------------------------------------------------
--- Returns a player's active visible set dictionary
--- @param player_index number
--- @return table visible_set
function viewport_bvh.get_visible_set(player_index)
    storage.player_visible_set = storage.player_visible_set or {}
    local set = storage.player_visible_set[player_index]
    if not set then
        set = {}
        storage.player_visible_set[player_index] = set
    end
    return set
end

--- Clears all active visible nodes and recycles leased visual handles for a player
--- @param player_index number
function viewport_bvh.clear_player_visible_set(player_index)
    if not (storage.player_visible_set and storage.player_visible_set[player_index]) then return end
    local set = storage.player_visible_set[player_index]
    for _, item in pairs(set) do
        if item.render_objects then
            render_pool.recycle_many(player_index, item.render_objects)
            item.render_objects = nil
        end
    end
    storage.player_visible_set[player_index] = nil
end

--- Fetches or creates the dedicated motion corridor BVH for a surface (Phase 6)
--- @param surface_index number
--- @return table tree
function viewport_bvh.get_motion_tree(surface_index)
    storage.motion_bvh = storage.motion_bvh or {}
    local tree = storage.motion_bvh[surface_index]
    if not tree then
        tree = trajectory_bvh.new_tree(surface_index)
        storage.motion_bvh[surface_index] = tree
    else
        trajectory_bvh.attach(tree)
    end
    return tree
end

--- Synchronizes a player's active visible set against the surface motion BVH on breach
--- @param player_index number
--- @param surface_index number
function viewport_bvh.sync_player_visibility(player_index, surface_index)
    local entry = storage.player_viewports and storage.player_viewports[player_index]
    if not entry then return end

    local motion_tree = viewport_bvh.get_motion_tree(surface_index)
    if not (motion_tree and motion_tree.root) then
        viewport_bvh.clear_player_visible_set(player_index)
        return
    end

    local hits = {}
    trajectory_bvh.query_box(motion_tree, entry.fat_min_x, entry.fat_min_y, entry.fat_max_x, entry.fat_max_y, hits)

    local current_set = viewport_bvh.get_visible_set(player_index)
    local new_set_keys = {}

    for i = 1, #hits do
        local leaf = hits[i]
        local key = leaf.key or (tostring(leaf.owner_id) .. ":" .. tostring(leaf.seg_key))
        new_set_keys[key] = leaf
        if not current_set[key] then
            current_set[key] = {
                leaf = leaf,
                key = key,
                owner_id = leaf.owner_id,
                seg_key = leaf.seg_key,
                render_objects = nil
            }
        else
            current_set[key].leaf = leaf
        end
    end

    for key, item in pairs(current_set) do
        if not new_set_keys[key] then
            if item.render_objects then
                render_pool.recycle_many(player_index, item.render_objects)
                item.render_objects = nil
            end
            current_set[key] = nil
        end
    end
end

--- Event hook called when a motion corridor or entity is registered in the motion BVH
--- @param surface_index number
--- @param leaf table Leaf node in motion BVH
function viewport_bvh.on_segment_registered(surface_index, leaf)
    if not (surface_index and leaf) then return end
    local observing = {}
    viewport_bvh.query_players_in_box(surface_index, leaf.min_x, leaf.min_y, leaf.max_x, leaf.max_y, observing)
    if #observing == 0 then return end

    local key = leaf.key or (tostring(leaf.owner_id) .. ":" .. tostring(leaf.seg_key))
    for i = 1, #observing do
        local p_idx = observing[i]
        local v_set = viewport_bvh.get_visible_set(p_idx)
        if not v_set[key] then
            v_set[key] = {
                leaf = leaf,
                key = key,
                owner_id = leaf.owner_id,
                seg_key = leaf.seg_key,
                render_objects = nil
            }
        else
            v_set[key].leaf = leaf
        end
    end
end

--- Event hook called when a motion corridor or entity is removed from the motion BVH
--- @param surface_index number|nil
--- @param owner_id number
--- @param seg_key any|nil
function viewport_bvh.on_segment_removed(surface_index, owner_id, seg_key)
    if not (storage.player_visible_set and owner_id) then return end
    local match_prefix = tostring(owner_id) .. ":"
    local match_key = seg_key and (match_prefix .. tostring(seg_key))

    for p_idx, v_set in pairs(storage.player_visible_set) do
        if match_key then
            local item = v_set[match_key]
            if item then
                if item.render_objects then
                    render_pool.recycle_many(p_idx, item.render_objects)
                end
                v_set[match_key] = nil
            end
        else
            for k, item in pairs(v_set) do
                if item.owner_id == owner_id or k:sub(1, #match_prefix) == match_prefix then
                    if item.render_objects then
                        render_pool.recycle_many(p_idx, item.render_objects)
                    end
                    v_set[k] = nil
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- VISUAL DEBUG OVERLAYS (CONCENTRIC HYSTERESIS BOXES)
--------------------------------------------------------------------------------
function viewport_bvh.clear_renders(player_index)
    storage.viewport_renders = storage.viewport_renders or {}
    local list = storage.viewport_renders[player_index]
    if list then
        for i = 1, #list do
            local r = list[i]
            if r and r.valid then r.destroy() end
        end
        storage.viewport_renders[player_index] = nil
    end
end

function viewport_bvh.draw_for_player(player_index)
    viewport_bvh.clear_renders(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    local surf = player.surface
    if not (surf and surf.valid) then return end

    local entry = storage.player_viewports and storage.player_viewports[player_index]
    if not entry then return end

    storage.viewport_renders = storage.viewport_renders or {}
    local renders = {}
    storage.viewport_renders[player_index] = renders

    -- Box 1: Inner Shrunk AABB (Gold)
    local r1 = rendering.draw_rectangle{
        color = { r = 1.0, g = 0.8, b = 0.2, a = 0.5 },
        width = 1,
        filled = false,
        left_top = { entry.inner_min_x, entry.inner_min_y },
        right_bottom = { entry.inner_max_x, entry.inner_max_y },
        surface = surf,
        players = { player }
    }
    renders[#renders + 1] = r1

    -- Box 2: Padded Viewport AABB (Green)
    local r2 = rendering.draw_rectangle{
        color = { r = 0.2, g = 0.9, b = 0.3, a = 0.8 },
        width = 2,
        filled = false,
        left_top = { entry.pad_min_x, entry.pad_min_y },
        right_bottom = { entry.pad_max_x, entry.pad_max_y },
        surface = surf,
        players = { player }
    }
    renders[#renders + 1] = r2

    -- Box 3: Outer Fat AABB (Cyan)
    local r3 = rendering.draw_rectangle{
        color = { r = 0.1, g = 0.6, b = 1.0, a = 0.4 },
        width = 2,
        filled = false,
        left_top = { entry.fat_min_x, entry.fat_min_y },
        right_bottom = { entry.fat_max_x, entry.fat_max_y },
        surface = surf,
        players = { player }
    }
    renders[#renders + 1] = r3

    local txt = rendering.draw_text{
        text = string.format("Player #%d Viewport [Hysteresis Shell | Updates: %d]", player_index, entry.updates_count or 1),
        surface = surf,
        target = { entry.center_x or player.position.x, entry.fat_min_y + 1 },
        color = { r = 0.8, g = 1.0, b = 1.0, a = 0.9 },
        scale = 0.8,
        alignment = "center",
        players = { player }
    }
    renders[#renders + 1] = txt
end

function viewport_bvh.toggle_debug_overlay(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    storage.debug = storage.debug or {}
    local dbg = storage.debug[player_index]
    if not dbg then return end

    dbg.viewport_bvh = not dbg.viewport_bvh
    if dbg.viewport_bvh then
        viewport_bvh.draw_for_player(player_index)
        player.print("[Debug] Viewport BVH Hysteresis Overlay: [color=green][ENABLED][/color]")
    else
        viewport_bvh.clear_renders(player_index)
        player.print("[Debug] Viewport BVH Hysteresis Overlay: [color=red][DISABLED][/color]")
    end
end

--------------------------------------------------------------------------------
-- AUTOMATED TEST SUITE
--------------------------------------------------------------------------------
function viewport_bvh.run_tests(player)
    local function log_msg(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_msg("[color=yellow][ViewportBVH Test][/color] Starting concentric hysteresis viewport self-test...")

    local p = player or (game.players and game.players[1])
    if not (p and p.valid) then
        log_msg("[color=red][ViewportBVH Test] Aborted: No valid player context[/color]")
        return false
    end

    -- Test 1: Concentric Bounds Initialization & Insertion
    local entry = viewport_bvh.update_player(p)
    if not (entry and entry.leaf and entry.leaf.is_leaf) then
        log_msg("[color=red][ViewportBVH Test] Test 1 FAILED: Viewport leaf initialization failed[/color]")
        return false
    end
    local tree = viewport_bvh.get_tree(p.surface.index)
    if tree.size < 1 then
        log_msg("[color=red][ViewportBVH Test] Test 1 FAILED: Tree size < 1 after update_player[/color]")
        return false
    end
    log_msg("[color=green][ViewportBVH Test] Test 1: Concentric Bounds Initialization & BVH Insertion -> PASSED[/color]")

    -- Test 2: Intra-Shell Motion (0 BVH Updates)
    local updates_start = entry.updates_count or 1
    local orig_pos = { x = p.position.x, y = p.position.y }
    local shift_pos = { x = orig_pos.x + 5, y = orig_pos.y }
    viewport_bvh.update_player(p, shift_pos)
    if entry.breached_this_tick or (entry.updates_count or 0) ~= updates_start then
        log_msg("[color=red][ViewportBVH Test] Test 2 FAILED: Intra-shell shift falsely triggered BVH update[/color]")
        return false
    end
    log_msg("[color=green][ViewportBVH Test] Test 2: Intra-Shell Camera Motion (0 BVH updates) -> PASSED[/color]")

    -- Test 3: Outer Fat Boundary Breach & Recentering
    local orig_fat_max_x = entry.fat_max_x
    local breach_pos = { x = orig_pos.x + 50, y = orig_pos.y }
    viewport_bvh.update_player(p, breach_pos)
    if not entry.breached_this_tick or entry.fat_max_x == orig_fat_max_x then
        log_msg("[color=red][ViewportBVH Test] Test 3 FAILED: Viewport fat box did not recenter on breach[/color]")
        return false
    end
    viewport_bvh.update_player(p, orig_pos)
    log_msg("[color=green][ViewportBVH Test] Test 3: Outer Boundary Breach & Recentering -> PASSED[/color]")

    -- Test 4: Inner Shrunk AABB Contraction (Zoom-In Recenter)
    local expanded_fat_hw = entry.fat_max_x - entry.center_x
    local zoomed_radii = { hw = 4, hh = 3 }
    viewport_bvh.update_player(p, orig_pos, zoomed_radii)
    local contracted_fat_hw = entry.fat_max_x - entry.center_x
    if not entry.breached_this_tick or contracted_fat_hw >= expanded_fat_hw then
        log_msg("[color=red][ViewportBVH Test] Test 4 FAILED: Inner zoom-in contraction breach did not shrink fat shell[/color]")
        return false
    end
    viewport_bvh.update_player(p, orig_pos)
    log_msg("[color=green][ViewportBVH Test] Test 4: Inner Shrunk AABB Contraction (Zoom-In Recenter) -> PASSED[/color]")

    -- Test 5: Spatial Hit-Testing & Observer Queries
    local hit = viewport_bvh.is_in_any_viewport(p.surface.index, p.position.x, p.position.y)
    if not hit then
        log_msg("[color=red][ViewportBVH Test] Test 4 FAILED: is_in_any_viewport failed for player position[/color]")
        return false
    end

    local observing = {}
    viewport_bvh.query_players_in_box(p.surface.index, p.position.x - 2, p.position.y - 2, p.position.x + 2, p.position.y + 2, observing)
    if #observing == 0 or observing[1] ~= p.index then
        log_msg("[color=red][ViewportBVH Test] Test 4 FAILED: query_players_in_box did not return observing player[/color]")
        return false
    end
    log_msg("[color=green][ViewportBVH Test] Test 5: Spatial Point & Observer Queries -> PASSED[/color]")

    -- Test 6: Observer Intersection on Viewport Breach
    local dummy_leaf = {
        min_x = p.position.x + 20, min_y = p.position.y - 1,
        max_x = p.position.x + 36, max_y = p.position.y + 1,
        owner_id = 8888, seg_key = "1,0:test",
        key = "8888:1,0:test", is_leaf = true
    }
    local m_tree = viewport_bvh.get_motion_tree(p.surface.index)
    trajectory_bvh.insert(m_tree, dummy_leaf, dummy_leaf.key)

    viewport_bvh.sync_player_visibility(p.index, p.surface.index)
    local v_set = viewport_bvh.get_visible_set(p.index)
    if not v_set[dummy_leaf.key] then
        log_msg("[color=red][ViewportBVH Test] Test 6 FAILED: Corridor not added to player_visible_set[/color]")
        return false
    end

    viewport_bvh.update_player(p, { x = p.position.x + 500, y = p.position.y })
    if v_set[dummy_leaf.key] ~= nil then
        log_msg("[color=red][ViewportBVH Test] Test 6 FAILED: Corridor not evicted after viewport breach[/color]")
        return false
    end
    viewport_bvh.update_player(p, orig_pos)
    trajectory_bvh.remove(m_tree, dummy_leaf)
    log_msg("[color=green][ViewportBVH Test] Test 6: Observer Intersection on Viewport Breach -> PASSED[/color]")

    -- Test 7: Event-Driven Corridor Registration & Removal
    local dummy_leaf2 = {
        min_x = p.position.x - 5, min_y = p.position.y - 1,
        max_x = p.position.x + 5, max_y = p.position.y + 1,
        owner_id = 9999, seg_key = "0,1:event",
        key = "9999:0,1:event", is_leaf = true
    }
    viewport_bvh.on_segment_registered(p.surface.index, dummy_leaf2)
    if not v_set[dummy_leaf2.key] then
        log_msg("[color=red][ViewportBVH Test] Test 7 FAILED: on_segment_registered did not subscribe observing player[/color]")
        return false
    end

    viewport_bvh.on_segment_removed(p.surface.index, 9999, "0,1:event")
    if v_set[dummy_leaf2.key] ~= nil then
        log_msg("[color=red][ViewportBVH Test] Test 7 FAILED: on_segment_removed did not unsubscribe player[/color]")
        return false
    end
    log_msg("[color=green][ViewportBVH Test] Test 7: Event-Driven Corridor Registration & Removal -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][ViewportBVH Test] ALL 7 TESTS PASSED! Observer Intersection Engine & Active Visibility Sets operational.[/font][/color]")
    return true
end

return viewport_bvh
