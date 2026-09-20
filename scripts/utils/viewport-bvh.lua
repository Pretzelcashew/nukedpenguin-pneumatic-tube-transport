--- Player Viewport Spatial BVH & Hysteresis Caching (Phase 3)
-- Manages spatial observer trees per surface tracking active player viewports.
-- Employs three concentric hysteresis bounds:
--   1. Inner Shrunk AABB: Zoom-in contraction threshold.
--   2. Padded Viewport AABB: Active culling boundary (+12 tiles padding).
--   3. Outer Fat AABB: Hysteresis shell (+24 tiles shell). Camera motion within
--      causes 0 BVH updates. Only breaches re-index into storage.viewport_bvh[surface_index].

local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local render_pool = require("scripts.utils.render-pool")
local profiler = require("scripts.utils.profiler")
local motion_protocols = require("scripts.utils.motion-protocols")

local viewport_bvh = {}

-- Top script bool for Viewport BVH culling effectiveness testing
local DEBUG_RENDER_VIEWPORTS = false
local DEBUG_VIEWPORT_SCALE = 0.5

local PAD_TILES = 12       -- Padding beyond visible screen edge to prevent pop-in during fast travel
local SHELL_TILES = 16     -- Fixed hysteresis margin (exactly 1 BVH corridor leaf = 16 tiles)
local SHRINK_THRESHOLD = 0.75 -- Trigger fat AABB resize/recenter if viewport scales 25% smaller

local QUALITY_BEAM_PALETTE = {
    [0] = { core = {r = 1.00, g = 0.60, b = 0.90, a = 0.95} },
    [1] = { core = {r = 1.00, g = 0.70, b = 0.95, a = 0.95} },
    [2] = { core = {r = 1.00, g = 0.80, b = 1.00, a = 0.98} },
    [3] = { core = {r = 1.00, g = 0.90, b = 1.00, a = 0.98} },
    [4] = { core = {r = 1.00, g = 1.00, b = 1.00, a = 1.00} },
    [5] = { core = {r = 1.00, g = 1.00, b = 1.00, a = 1.00} }
}

local MINOR_DOT_COLOR = {r = 0.90, g = 0.20, b = 0.70, a = 0.75}

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

    local f_hw = (w * 0.5) / (32 * zoom)
    local f_hh = (h * 0.5) / (32 * zoom)
    return f_hw, f_hh
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

    local entry = storage.player_viewports[p_idx]
    local p_zoom = player.zoom or 1.0
    if not override_pos and not override_radii and entry and entry.leaf and entry.surface_index == s_idx then
        if cx == entry.last_player_x and cy == entry.last_player_y and p_zoom == entry.last_zoom then
            entry.breached_this_tick = false
            return entry
        end
    end

    local f_hw, f_hh
    if override_radii then
        f_hw, f_hh = override_radii.hw, override_radii.hh
    else
        f_hw, f_hh = viewport_bvh.get_player_frustum_radii(player)
    end

    local pad_hw, pad_hh
    if DEBUG_RENDER_VIEWPORTS and not override_radii then
        pad_hw = f_hw * DEBUG_VIEWPORT_SCALE
        pad_hh = f_hh * DEBUG_VIEWPORT_SCALE
    else
        pad_hw = f_hw + PAD_TILES
        pad_hh = f_hh + PAD_TILES
    end
    local fat_hw = pad_hw + SHELL_TILES
    local fat_hh = pad_hh + SHELL_TILES
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

        local fat_min_x = cx - fat_hw
        local fat_max_x = cx + fat_hw
        local fat_min_y = cy - fat_hh
        local fat_max_y = cy + fat_hh

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
            baseline_pad_hw = pad_hw,
            baseline_pad_hh = pad_hh,
            center_x = cx,
            center_y = cy,
            last_player_x = cx,
            last_player_y = cy,
            last_zoom = p_zoom,
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
    local view_settings = player.game_view_settings
    local alt_mode = (view_settings and view_settings.show_entity_info) == true
    if entry.last_alt_mode == nil then
        entry.last_alt_mode = alt_mode
    elseif entry.last_alt_mode ~= alt_mode then
        entry.last_alt_mode = alt_mode
        local v_set = viewport_bvh.get_visible_set(p_idx)
        if not alt_mode then
            for _, item in pairs(v_set) do
                viewport_bvh.detach_static_render(p_idx, item)
            end
        else
            for _, item in pairs(v_set) do
                if item.leaf and (item.leaf.static_render_spec or item.leaf.has_trail) then
                    viewport_bvh.attach_static_render(p_idx, item, surf)
                end
            end
        end
    end

    entry.last_player_x = cx
    entry.last_player_y = cy
    entry.last_zoom = p_zoom
    entry.pad_min_x = pad_min_x
    entry.pad_max_x = pad_max_x
    entry.pad_min_y = pad_min_y
    entry.pad_max_y = pad_max_y

    local breached_outer = (pad_min_x < entry.fat_min_x or pad_max_x > entry.fat_max_x or pad_min_y < entry.fat_min_y or pad_max_y > entry.fat_max_y)
    local breached_inner = (pad_hw < (entry.baseline_pad_hw or pad_hw) * SHRINK_THRESHOLD
        or pad_hh < (entry.baseline_pad_hh or pad_hh) * SHRINK_THRESHOLD)

    if breached_outer or breached_inner then
        local fat_min_x = cx - fat_hw
        local fat_max_x = cx + fat_hw
        local fat_min_y = cy - fat_hh
        local fat_max_y = cy + fat_hh

        entry.fat_min_x = fat_min_x
        entry.fat_max_x = fat_max_x
        entry.fat_min_y = fat_min_y
        entry.fat_max_y = fat_max_y
        entry.baseline_pad_hw = pad_hw
        entry.baseline_pad_hh = pad_hh
        entry.center_x = cx
        entry.center_y = cy
        entry.breached_this_tick = true
        entry.updates_count = (entry.updates_count or 0) + 1

        local t_sync = profiler.start_timer()
        local tree = viewport_bvh.get_tree(s_idx)
        trajectory_bvh.update(tree, entry.leaf, fat_min_x, fat_min_y, fat_max_x, fat_max_y)
        viewport_bvh.sync_player_visibility(p_idx, s_idx)
        if t_sync then profiler.record_bvh("Visibility Sync", t_sync, true) end
    else
        entry.breached_this_tick = false
    end

    local dbg = storage.debug and storage.debug[p_idx]
    if not DEBUG_RENDER_VIEWPORTS and dbg then
        dbg.viewport_bvh = false
    end
    local wants_overlay = DEBUG_RENDER_VIEWPORTS or (dbg and dbg.master and dbg.viewport_bvh)
    if wants_overlay then
        viewport_bvh.draw_for_player(p_idx)
    elseif storage.viewport_renders and storage.viewport_renders[p_idx] then
        viewport_bvh.clear_renders(p_idx)
    end

    return entry
end

--- Updates all connected players and purges disconnected players from viewport trees
function viewport_bvh.update_all_players()
    local t_vp = profiler.start_timer()
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
            viewport_bvh.clear_renders(p_idx)
            storage.player_viewports[p_idx] = nil
        end
    end
    if t_vp then profiler.record_bvh("Viewport", t_vp) end
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

--- Dedicated static render subprotocol implementation for targeting reticle beams
function viewport_bvh.attach_reticle_static_render(player_index, item, surface)
    if not (item and item.leaf) then return end
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local leaf = item.leaf
    item.render_objects = item.render_objects or {}
    local objects = item.render_objects

    local reticle = storage.projector_reticles and storage.projector_reticles[item.owner_id]
    local min_allowed = -1
    if reticle and reticle.retreat_tick then
        local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or 1.2
        local elapsed_retreat = math.max(0, game.tick - reticle.retreat_tick)
        min_allowed = math.floor(elapsed_retreat / tpt)
    end

    local count = leaf.trail_count or (leaf.has_trail and leaf.d_end and leaf.d_start and (leaf.d_end - leaf.d_start)) or 0
    for idx, obj in pairs(objects) do
        if type(idx) == "number" and idx > count then
            render_pool.recycle(player_index, obj)
            objects[idx] = nil
        end
    end
    item.trail_dots_count = count

    if leaf.has_trail or count > 0 then
        item.trail_attached = true
        local q_level = leaf.q_level or (reticle and reticle.q_level) or 0
        local palette = QUALITY_BEAM_PALETTE[q_level] or QUALITY_BEAM_PALETTE[0]
        local d_base = leaf.d_start or 0
        local dx = (reticle and reticle.dir and reticle.dir.x) or (leaf.dir and leaf.dir.x) or 0
        local dy = (reticle and reticle.dir and reticle.dir.y) or (leaf.dir and leaf.dir.y) or 0
        if dx == 0 and dy == 0 then
            local ep = leaf.end_pos
            local sp_raw = leaf.start_pos
            if ep and sp_raw and (ep.x ~= sp_raw.x or ep.y ~= sp_raw.y) then
                if ep.x > sp_raw.x then dx = 1 elseif ep.x < sp_raw.x then dx = -1 end
                if ep.y > sp_raw.y then dy = 1 elseif ep.y < sp_raw.y then dy = -1 end
            end
        end
        local r_sp = reticle and reticle.start_pos
        local sp = r_sp and { x = r_sp.x + dx * d_base, y = r_sp.y + dy * d_base } or leaf.start_pos

        if sp and (dx ~= 0 or dy ~= 0) then
            for i = 1, count do
                local d = d_base + i
                if d > min_allowed then
                    if not (objects[i] and objects[i].valid) then
                        local dot_pos = { x = sp.x + dx * i, y = sp.y + dy * i }
                        if d % 5 == 0 then
                    local prom = render_pool.lease_circle{
                        color = palette.core,
                        radius = 0.16,
                        filled = true,
                        target = dot_pos,
                        surface = surface,
                        players = { player }
                    }
                    if prom then objects[i] = prom end
                else
                    local min_dot = render_pool.lease_circle{
                        color = MINOR_DOT_COLOR,
                        radius = 0.08,
                        filled = true,
                        target = dot_pos,
                        surface = surface,
                        players = { player }
                    }
                            if min_dot then objects[i] = min_dot end
                        end
                    end
                else
                    if objects[i] then
                        render_pool.recycle(player_index, objects[i])
                        objects[i] = nil
                    end
                end
            end
            item.trail_dots_count = count
        end
    end

    local spec = leaf.static_render_spec
    local pos = leaf.static_pos

    local total_d = (reticle and reticle.total_dist) or (leaf.d_end or 50)
    if not (spec and pos and min_allowed < total_d) then
        if item.endpoint_attached then
            if objects["endpoint_sprite"] then render_pool.recycle(player_index, objects["endpoint_sprite"]) objects["endpoint_sprite"] = nil end
            if objects["endpoint_ring"] then render_pool.recycle(player_index, objects["endpoint_ring"]) objects["endpoint_ring"] = nil end
            if objects["endpoint_circ"] then render_pool.recycle(player_index, objects["endpoint_circ"]) objects["endpoint_circ"] = nil end
            item.endpoint_attached = nil
            item.last_endpoint_pos = nil
            item.last_endpoint_spec = nil
        end
    else
        local pos_changed = not item.last_endpoint_pos or (item.last_endpoint_pos.x ~= pos.x or item.last_endpoint_pos.y ~= pos.y)
        local spec_changed = (item.last_endpoint_spec ~= spec)
        if item.endpoint_attached and (pos_changed or spec_changed) then
            if objects["endpoint_sprite"] then render_pool.recycle(player_index, objects["endpoint_sprite"]) objects["endpoint_sprite"] = nil end
            if objects["endpoint_ring"] then render_pool.recycle(player_index, objects["endpoint_ring"]) objects["endpoint_ring"] = nil end
            if objects["endpoint_circ"] then render_pool.recycle(player_index, objects["endpoint_circ"]) objects["endpoint_circ"] = nil end
            item.endpoint_attached = nil
        end

        if not item.endpoint_attached then
            item.endpoint_attached = true
            item.last_endpoint_pos = { x = pos.x, y = pos.y }
            item.last_endpoint_spec = spec
            if spec.sprite then
        local sp = render_pool.lease_sprite{
            sprite = spec.sprite,
            target = pos,
            surface = surface,
            x_scale = spec.scale or 0.6,
            y_scale = spec.scale or 0.6,
            tint = spec.tint,
            render_layer = "entity-info-icon-above",
            players = { player }
        }
        if sp then objects["endpoint_sprite"] = sp end
    end

    if spec.has_ring or spec.ring_radius then
        local ring = render_pool.lease_circle{
            color = spec.ring_color or spec.color or { r = 1.0, g = 0.4, b = 0.25, a = 0.85 },
            radius = spec.ring_radius or 0.42,
            filled = false,
            width = spec.ring_width or 2,
            target = pos,
            surface = surface,
            players = { player }
        }
        if ring then objects["endpoint_ring"] = ring end
    end

    if not spec.sprite or spec.radius then
        local circ = render_pool.lease_circle{
            color = spec.color or { r = 1.0, g = 0.4, b = 0.25, a = 0.95 },
            radius = spec.radius or 0.24,
            filled = (spec.filled ~= false),
            width = spec.width or 2,
            target = pos,
            surface = surface,
            players = { player }
        }
        if circ then objects["endpoint_circ"] = circ end
    end
        end
    end

    item.render_objects = objects
end

--- Attaches and leases static render objects for a leaf in a player's visible set via subprotocol
--- @param player_index number
--- @param item table Visible set entry
--- @param surface LuaSurface
function viewport_bvh.attach_static_render(player_index, item, surface)
    if not (item and item.leaf) then return end
    local static_fn = motion_protocols.get_subprotocol(item.owner_id, "static_render")
    if not static_fn and (item.leaf.static_render_spec or item.leaf.has_trail) then
        static_fn = motion_protocols.static_renders["reticle_static"]
    end
    if static_fn then
        static_fn(player_index, item, surface)
    end
end

motion_protocols.register_static_render("reticle_static", viewport_bvh.attach_reticle_static_render)

--- Detaches and recycles static render objects for a leaf in a player's visible set
--- @param player_index number
--- @param item table Visible set entry
function viewport_bvh.detach_static_render(player_index, item)
    if item and item.render_objects then
        render_pool.recycle_many(player_index, item.render_objects)
        item.render_objects = nil
    end
    if item and item.objects then
        render_pool.recycle_many(player_index, item.objects)
        item.objects = nil
    end
    if item then
        item.trail_attached = nil
        item.endpoint_attached = nil
        item.trail_dots_count = nil
        item.last_endpoint_pos = nil
        item.last_endpoint_spec = nil
    end
end

--- Notifies observers that a leaf's static render specification has changed
--- @param surface_index number
--- @param leaf table
function viewport_bvh.on_leaf_static_changed(surface_index, leaf)
    if not (surface_index and leaf) then return end
    local key = tostring(leaf.owner_id) .. ":" .. tostring(leaf.seg_key)
    local surf = game.surfaces[surface_index]
    if not (surf and surf.valid) then return end

    local updated_players = {}
    if storage.player_visible_set then
        for p_idx, v_set in pairs(storage.player_visible_set) do
            local item = v_set[key]
            if item then
                updated_players[p_idx] = true
                item.leaf = leaf
                local player = game.get_player(p_idx)
                local view_settings = player and player.valid and player.game_view_settings
                local alt_mode = view_settings and view_settings.show_entity_info
                if alt_mode then
                    viewport_bvh.attach_static_render(p_idx, item, surf)
                else
                    viewport_bvh.detach_static_render(p_idx, item)
                end
            end
        end
    end

    local observing = {}
    viewport_bvh.query_players_in_box(surface_index, leaf.min_x, leaf.min_y, leaf.max_x, leaf.max_y, observing)
    for i = 1, #observing do
        local p_idx = observing[i]
        if not updated_players[p_idx] then
            local player = game.get_player(p_idx)
            local view_settings = player and player.valid and player.game_view_settings
            local alt_mode = view_settings and view_settings.show_entity_info

            local v_set = viewport_bvh.get_visible_set(p_idx)
            local item = v_set[key]
            if not item then
                item = {
                    leaf = leaf,
                    key = key,
                    owner_id = leaf.owner_id,
                    seg_key = leaf.seg_key,
                    render_objects = nil
                }
                v_set[key] = item
            else
                item.leaf = leaf
            end

            if alt_mode then
                viewport_bvh.attach_static_render(p_idx, item, surf)
            else
                viewport_bvh.detach_static_render(p_idx, item)
            end
        end
    end
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

    local player = game.get_player(player_index)
    local view_settings = player and player.valid and player.game_view_settings
    local alt_mode = view_settings and view_settings.show_entity_info
    local surf = player and player.valid and player.surface

    for i = 1, #hits do
        local leaf = hits[i]
        local key = tostring(leaf.owner_id) .. ":" .. tostring(leaf.seg_key)
        new_set_keys[key] = leaf
        local item = current_set[key]
        if not item then
            item = {
                leaf = leaf,
                key = key,
                owner_id = leaf.owner_id,
                seg_key = leaf.seg_key,
                render_objects = nil
            }
            current_set[key] = item
            if alt_mode and (leaf.static_render_spec or leaf.has_trail) and surf then
                viewport_bvh.attach_static_render(player_index, item, surf)
            end
        else
            item.leaf = leaf
            if alt_mode and (leaf.static_render_spec or leaf.has_trail) and not item.render_objects and surf then
                viewport_bvh.attach_static_render(player_index, item, surf)
            end
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

    local key = tostring(leaf.owner_id) .. ":" .. tostring(leaf.seg_key)
    local surf = game.surfaces[surface_index]
    for i = 1, #observing do
        local p_idx = observing[i]
        local player = game.get_player(p_idx)
        local view_settings = player and player.valid and player.game_view_settings
        local alt_mode = view_settings and view_settings.show_entity_info

        local v_set = viewport_bvh.get_visible_set(p_idx)
        local item = v_set[key]
        if not item then
            item = {
                leaf = leaf,
                key = key,
                owner_id = leaf.owner_id,
                seg_key = leaf.seg_key,
                render_objects = nil
            }
            v_set[key] = item
        else
            item.leaf = leaf
        end

        if alt_mode and (leaf.static_render_spec or leaf.has_trail) and surf and surf.valid then
            viewport_bvh.attach_static_render(p_idx, item, surf)
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
                    item.render_objects = nil
                end
                if item.objects then
                    render_pool.recycle_many(p_idx, item.objects)
                    item.objects = nil
                end
                v_set[match_key] = nil
            end
        else
            for k, item in pairs(v_set) do
                if item.owner_id == owner_id or k:sub(1, #match_prefix) == match_prefix then
                    if item.render_objects then
                        render_pool.recycle_many(p_idx, item.render_objects)
                        item.render_objects = nil
                    end
                    if item.objects then
                        render_pool.recycle_many(p_idx, item.objects)
                        item.objects = nil
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
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end
    local surf = player.surface
    if not (surf and surf.valid) then return end

    local entry = storage.player_viewports and storage.player_viewports[player_index]
    if not entry then return end

    storage.viewport_renders = storage.viewport_renders or {}
    local renders = storage.viewport_renders[player_index]

    if renders and #renders >= 2 and renders[1].valid and renders[2].valid then
        local ok = pcall(function()
            renders[1].set_corners({ entry.pad_min_x, entry.pad_min_y }, { entry.pad_max_x, entry.pad_max_y })
            renders[2].set_corners({ entry.fat_min_x, entry.fat_min_y }, { entry.fat_max_x, entry.fat_max_y })
        end)
        if not ok then
            pcall(function()
                renders[1].left_top = { entry.pad_min_x, entry.pad_min_y }
                renders[1].right_bottom = { entry.pad_max_x, entry.pad_max_y }
                renders[2].left_top = { entry.fat_min_x, entry.fat_min_y }
                renders[2].right_bottom = { entry.fat_max_x, entry.fat_max_y }
            end)
        end
        if renders[3] and renders[3].valid then
            renders[3].target = { entry.center_x or player.position.x, entry.fat_min_y + 1 }
            renders[3].text = string.format("Player #%d Viewport [Green: Viewport | Cyan: Fat Shell | Updates: %d]", player_index, entry.updates_count or 1)
        end
        return
    end

    viewport_bvh.clear_renders(player_index)
    local renders = {}
    storage.viewport_renders[player_index] = renders


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
        color = { r = 0.1, g = 0.65, b = 1.0, a = 0.8 },
        width = 2,
        filled = false,
        left_top = { entry.fat_min_x, entry.fat_min_y },
        right_bottom = { entry.fat_max_x, entry.fat_max_y },
        surface = surf,
        players = { player }
    }
    renders[#renders + 1] = r3

    local txt = rendering.draw_text{
        text = string.format("Player #%d Viewport [Green: Viewport | Cyan: Fat Shell | Updates: %d]", player_index, entry.updates_count or 1),
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

    -- Test 4: 25% Scale Contraction (Zoom-In Recenter)
    local expanded_fat_hw = entry.fat_max_x - entry.center_x
    local zoomed_radii = { hw = 4, hh = 3 }
    viewport_bvh.update_player(p, orig_pos, zoomed_radii)
    local contracted_fat_hw = entry.fat_max_x - entry.center_x
    if not entry.breached_this_tick or contracted_fat_hw >= expanded_fat_hw then
        log_msg("[color=red][ViewportBVH Test] Test 4 FAILED: Zoom-in contraction breach did not shrink fat shell[/color]")
        return false
    end
    viewport_bvh.update_player(p, orig_pos)
    log_msg("[color=green][ViewportBVH Test] Test 4: 25% Scale Contraction (Zoom-In Recenter) -> PASSED[/color]")

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
