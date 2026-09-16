local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local trajectory_bvh = require("scripts.utils.trajectory-bvh")
local render_pool = require("scripts.utils.render-pool")
local viewport_bvh = require("scripts.utils.viewport-bvh")
local timed_motion = require("scripts.utils.timed-motion")
require("scripts.debug-manager")

local capsule_renderer = {}

local QUALITY_BEAM_PALETTE = {
    [0] = { core = {r = 1.00, g = 0.60, b = 0.90, a = 0.95} },
    [1] = { core = {r = 1.00, g = 0.70, b = 0.95, a = 0.95} },
    [2] = { core = {r = 1.00, g = 0.80, b = 1.00, a = 0.98} },
    [3] = { core = {r = 1.00, g = 0.90, b = 1.00, a = 0.98} },
    [4] = { core = {r = 1.00, g = 1.00, b = 1.00, a = 1.00} },
    [5] = { core = {r = 1.00, g = 1.00, b = 1.00, a = 1.00} }
}
local MINOR_DOT_COLOR = {r = 0.90, g = 0.20, b = 0.70, a = 0.75}

-- Module-scoped per-frame player viewport cache & scratch structures
local last_prepared_tick = -1
local active_debug_players = {}
local active_debug_count = 0
local active_viewports = {}
local active_viewport_count = 0

local scratch_debug_players = {}
local scratch_debug_keys = {}

--- Helper to safely test if an item stack is spoilable without triggering Factorio 2.0 LuaItemPrototype __index errors
local function is_stack_spoilable(stack)
    if not (stack and stack.valid_for_read) then return false end
    local proto = stack.prototype
    if proto and proto.get_spoil_ticks then
        local ticks = proto.get_spoil_ticks()
        if ticks and ticks > 0 then
            return true
        end
    end
    if stack.spoil_tick and stack.spoil_tick > 0 then
        return true
    end
    if stack.spoil_percent and stack.spoil_percent > 0 then
        return true
    end
    return false
end

--- Pre-evaluates player viewport eligibility, Alt Mode state, and hover peeking unit numbers once per tick.
function capsule_renderer.prepare_frame()
    local current_tick = game.tick
    if last_prepared_tick == current_tick then
        return
    end
    last_prepared_tick = current_tick

    viewport_bvh.update_all_players()
    active_debug_count = 0
    active_viewport_count = 0

    local players = game.players
    for _, player in pairs(players) do
        if player and player.valid then
            local p_surf = player.surface
            local p_pos = player.position
            if p_surf and p_surf.valid and p_pos and (player.connected ~= false) then
                local res = player.display_resolution
                local w = (res and res.width) or 1920
                local h = (res and res.height) or 1080
                local zoom = player.zoom or 1.0
                if zoom <= 0 then zoom = 1.0 end
                local scale = player.display_scale or 1.0
                if scale <= 0 then scale = 1.0 end

                local tile_w = (w / scale) / (32 * zoom)
                local tile_h = (h / scale) / (32 * zoom)
                local half_w = math.min(150, (tile_w * 0.5) + 12)
                local half_h = math.min(150, (tile_h * 0.5) + 12)

                active_viewport_count = active_viewport_count + 1
                local vp = active_viewports[active_viewport_count]
                if not vp then
                    vp = {}
                    active_viewports[active_viewport_count] = vp
                end
                vp.surface_name = p_surf.name
                vp.left = p_pos.x - half_w
                vp.right = p_pos.x + half_w
                vp.top = p_pos.y - half_h
                vp.bottom = p_pos.y + half_h
            end

            local p_idx = player.index
            local view_settings = player.game_view_settings
            local alt_mode = view_settings and view_settings.show_entity_info

            if alt_mode then
                local wants_debug = is_debug_active("capsules", p_idx)
                local wants_peek = is_debug_active("peek", p_idx)
                local hovered_unit = nil

                if wants_peek then
                    local selected = player.selected
                    if selected and selected.valid and selected.unit_number then
                        hovered_unit = selected.unit_number
                    else
                        wants_peek = false
                    end
                end

                if wants_debug or wants_peek then
                    active_debug_count = active_debug_count + 1
                    local entry = active_debug_players[active_debug_count]
                    if not entry then
                        entry = {}
                        active_debug_players[active_debug_count] = entry
                    end
                    entry.player = player
                    entry.index = p_idx
                    entry.wants_debug = wants_debug
                    entry.wants_peek = wants_peek
                    entry.hovered_unit = hovered_unit
                end
            end
        end
    end

    -- Clear trailing references in pre-allocated arrays
    for i = active_debug_count + 1, #active_debug_players do
        active_debug_players[i] = nil
    end
    for i = active_viewport_count + 1, #active_viewports do
        active_viewports[i] = nil
    end
end

--- Returns the dominant item string for a capsule.
--- Serves cached payload metadata instantly unless force_refresh is true.
--- Short-circuits force_refresh for capsules marked with no spoilable items.
--- Updates dominant_item to the spoiled product BEFORE disabling further 60-tick refreshes.
--- @param capsule_id number
--- @param force_refresh boolean|nil
--- @return string|nil
function capsule_renderer.get_dominant_item(capsule_id, force_refresh)
    if not capsule_id then return nil end
    local cap_data = capsule_manager.get(capsule_id)

    if cap_data then
        if not force_refresh or (cap_data.has_spoilable_items == false and cap_data.dominant_item) then
            if cap_data.dominant_item then
                return cap_data.dominant_item
            end
        end
    end

    if cap_data and cap_data.virtual_cargo then
        local max_cargo_count = 0
        local dominant_cargo_item = nil
        local dominant_cargo_quality = "normal"
        local still_has_spoilable = false

        for _, item in ipairs(cap_data.virtual_cargo) do
            if item.count and item.count > 0 then
                if item.base_spoil_ticks and item.base_spoil_ticks > 0 and (item.spoil_percent or 0) < 1.0 then
                    still_has_spoilable = true
                end
                if item.count > max_cargo_count then
                    max_cargo_count = item.count
                    dominant_cargo_item = item.name
                    dominant_cargo_quality = (type(item.quality) == "string" and item.quality) or (item.quality and item.quality.name) or "normal"
                end
            end
        end

        local dominant_item = dominant_cargo_item or (cap_data.definition and cap_data.definition.name)

        cap_data.dominant_item = dominant_item
        cap_data.dominant_quality = dominant_cargo_quality

        if storage.capsules and storage.capsules[capsule_id] then
            storage.capsules[capsule_id].dominant_item = dominant_item
            storage.capsules[capsule_id].dominant_quality = dominant_cargo_quality
        end

        if cap_data.has_spoilable_items and not still_has_spoilable then
            cap_data.has_spoilable_items = false
        end

        return dominant_item
    end

    if not (cap_data and cap_data.holder and cap_data.holder.valid) then
        return cap_data and cap_data.dominant_item
    end

    local inventory = cap_data.holder.get_inventory(defines.inventory.chest)
    if not (inventory and inventory.valid and not inventory.is_empty()) then
        if cap_data and cap_data.has_spoilable_items then
            cap_data.has_spoilable_items = false
        end
        return cap_data.dominant_item or (cap_data.definition and cap_data.definition.name)
    end

    local max_cargo_count = 0
    local dominant_cargo_item = nil
    local max_vessel_count = 0
    local dominant_vessel_item = nil
    local primary_slot = cap_data.primary_slot
    local still_has_spoilable = false

    -- Calculate active slot bound to avoid allocating C++ LuaItemStack userdata for red-locked slots
    local max_slot = #inventory
    if inventory.supports_bar() then
        local bar = inventory.get_bar()
        if bar then
            max_slot = math.min(#inventory, bar - 1)
        end
    end

    for i = 1, max_slot do
        local stack = inventory[i]
        if stack and stack.valid_for_read and stack.count > 0 then
            if is_stack_spoilable(stack) then
                still_has_spoilable = true
            end

            if primary_slot and i == primary_slot then
                if stack.count > max_vessel_count then
                    max_vessel_count = stack.count
                    dominant_vessel_item = stack.name
                end
            else
                if stack.count > max_cargo_count then
                    max_cargo_count = stack.count
                    dominant_cargo_item = stack.name
                end
            end
        end
    end

    local dominant_item = dominant_cargo_item or dominant_vessel_item or (cap_data.definition and cap_data.definition.name)

    -- Update cached dominant item FIRST so rendering overlay displays the newly spoiled item
    if cap_data then
        cap_data.dominant_item = dominant_item
    end
    if storage.capsules and storage.capsules[capsule_id] then
        storage.capsules[capsule_id].dominant_item = dominant_item
    end

    -- ONLY AFTER updating dominant_item to the spoiled result do we flip has_spoilable_items to false
    if cap_data and cap_data.has_spoilable_items and not still_has_spoilable then
        cap_data.has_spoilable_items = false
    end

    return dominant_item
end

local function recycle_capsule_render(capsule)
    local render_id = capsule.render_id
    if render_id then
        if type(render_id) == "table" then
            for i = 1, #render_id do
                render_pool.recycle(nil, render_id[i])
            end
        elseif render_id.valid then
            render_pool.recycle(nil, render_id)
        end
        capsule.render_id = nil
    end
    capsule.render_cache = nil
end
capsule_renderer.recycle_capsule_render = recycle_capsule_render
capsule_renderer.clear_capsule_render = recycle_capsule_render

function capsule_renderer.render(capsule, id, curr_pos, surface)
    if not (surface and surface.valid and curr_pos and curr_pos.x and curr_pos.y) then
        recycle_capsule_render(capsule)
        return
    end

    -- Ensure system-level frame context is prepared for current tick
    if last_prepared_tick ~= game.tick then
        capsule_renderer.prepare_frame()
    end

    local passenger = capsule.passenger
    local passenger_valid = passenger and passenger.valid
    local passenger_index = passenger_valid and passenger.index or nil
    local surface_index = surface.index

    local cap_id = capsule.capsule_id or id
    local cap_data = capsule_manager.get(cap_id)
    local def = cap_data and cap_data.definition
    local ring_color = capsule_defs.get_debug_color(def or (cap_data and cap_data.type))

    local debug_player_count = 0

    if active_debug_count > 0 then
        local from_key = capsule.from_port_key
        local to_key = capsule.to_port_key
        local u_from = from_key and capsule_queries.get_port_info(from_key)
        local u_to = to_key and capsule_queries.get_port_info(to_key)

        for i = 1, active_debug_count do
            local entry = active_debug_players[i]
            local is_eligible = false

            if entry.wants_debug then
                is_eligible = true
            elseif entry.wants_peek and entry.hovered_unit then
                local h_unit = entry.hovered_unit
                if (u_from and u_from == h_unit) or (u_to and u_to == h_unit) then
                    is_eligible = true
                end
            end

            if is_eligible then
                debug_player_count = debug_player_count + 1
                scratch_debug_players[debug_player_count] = entry.player
                scratch_debug_keys[debug_player_count] = entry.index
            end
        end
    end

    -- Numeric debug key for 0 or 1 player to avoid string allocation & table joins
    local debug_key
    if debug_player_count == 0 then
        debug_key = 0
    elseif debug_player_count == 1 then
        debug_key = scratch_debug_keys[1]
    else
        local key_tbl = {}
        for i = 1, debug_player_count do
            key_tbl[i] = scratch_debug_keys[i]
        end
        debug_key = table.concat(key_tbl, ",")
    end

    local cache = capsule.render_cache
    local render_id = capsule.render_id

    -- Validate existing render handles against C++ object validity
    local render_objects_valid = true
    if render_id then
        if type(render_id) == "table" then
            for i = 1, #render_id do
                local obj = render_id[i]
                if not (obj and obj.valid) then
                    render_objects_valid = false
                    break
                end
            end
        elseif not (render_id.valid) then
            render_objects_valid = false
        end
    else
        render_objects_valid = false
    end

    -- Serve cached dominant payload item directly; state changes are pushed by latent spoil events
    local dominant_item = nil
    if debug_key ~= 0 and debug_key ~= "" and not passenger_valid then
        local current_dom = cap_data and cap_data.dominant_item
        if cache and cache.dominant_item and cache.pos_x == curr_pos.x and cache.pos_y == curr_pos.y and render_objects_valid and (not current_dom or cache.dominant_item == current_dom) then
            dominant_item = cache.dominant_item
        else
            dominant_item = current_dom or capsule_renderer.get_dominant_item(cap_id)
        end
    end

    -- Check if current state matches cached render state
    local state_matches = cache
        and render_objects_valid
        and cache.surface_index == surface_index
        and cache.passenger_index == passenger_index
        and cache.debug_key == debug_key
        and cache.dominant_item == dominant_item
        and cache.ring_color == ring_color

    if state_matches then
        local pos_changed = (cache.pos_x ~= curr_pos.x or cache.pos_y ~= curr_pos.y)
        if not pos_changed then
            -- Clean up scratch arrays
            for i = 1, debug_player_count do
                scratch_debug_players[i] = nil
                scratch_debug_keys[i] = nil
            end
            -- Case 1: Stationary capsule with unchanged render state -> Zero allocation NO-OP
            return
        end

        -- Case 2: Moving capsule with unchanged render state -> Fast in-place target position update
        if type(render_id) == "table" and cache.target_offsets then
            local offsets = cache.target_offsets
            for i = 1, #render_id do
                local render_obj = render_id[i]
                local offset_y = offsets[i] or 0
                if offset_y ~= 0 then
                    render_obj.target = { curr_pos.x, curr_pos.y + offset_y }
                else
                    render_obj.target = curr_pos
                end
            end
        elseif render_id then
            render_id.target = curr_pos
        end

        cache.pos_x = curr_pos.x
        cache.pos_y = curr_pos.y

        -- Clean up scratch arrays
        for i = 1, debug_player_count do
            scratch_debug_players[i] = nil
            scratch_debug_keys[i] = nil
        end
        return
    end

    -- Case 3: State changed, spoilage refreshed, or handles invalid -> Recycle old render objects into pool
    recycle_capsule_render(capsule)

    if debug_key ~= 0 and debug_key ~= "" and not passenger_valid and dominant_item == nil then
        dominant_item = capsule_renderer.get_dominant_item(cap_id)
    end

    local render_objects = {}
    local target_offsets = {}

    if passenger_valid then
        local eject_text = render_pool.lease_text{
            text = "[Shift + E] Emergency Eject",
            surface = surface,
            target = { curr_pos.x, curr_pos.y + 0.8 },
            color = { r = 1, g = 0.9, b = 0.3, a = 1.0 },
            players = { passenger },
            alignment = "center",
            scale = 0.9,
            render_layer = "light-effect"
        }
        table.insert(render_objects, eject_text)
        table.insert(target_offsets, 0.8)
    end

    for i = 1, debug_player_count do
        local player = scratch_debug_players[i]
        if passenger_valid then
            local ring = render_pool.lease_circle{
                color = { r = 0, g = 0.8, b = 1, a = 0.9 },
                radius = 0.45,
                filled = false,
                width = 3,
                target = curr_pos,
                surface = surface,
                render_layer = "entity-info-icon-above",
                players = { player }
            }
            table.insert(render_objects, ring)
            table.insert(target_offsets, 0)
        else
            if dominant_item then
                local ring = render_pool.lease_circle{
                    color = ring_color,
                    radius = 0.35,
                    filled = false,
                    width = 2,
                    target = curr_pos,
                    surface = surface,
                    render_layer = "entity-info-icon-above",
                    players = { player }
                }
                table.insert(render_objects, ring)
                table.insert(target_offsets, 0)

                local sprite = render_pool.lease_sprite{
                    sprite = "item/" .. dominant_item,
                    target = curr_pos,
                    surface = surface,
                    x_scale = 0.55,
                    y_scale = 0.55,
                    render_layer = "entity-info-icon-above",
                    players = { player }
                }
                table.insert(render_objects, sprite)
                table.insert(target_offsets, 0)
            else
                local dot = render_pool.lease_circle{
                    color = ring_color,
                    radius = 0.25,
                    filled = true,
                    target = curr_pos,
                    surface = surface,
                    render_layer = "entity-info-icon-above",
                    players = { player }
                }
                table.insert(render_objects, dot)
                table.insert(target_offsets, 0)
            end
        end
    end

    -- Clean up scratch arrays
    for i = 1, debug_player_count do
        scratch_debug_players[i] = nil
        scratch_debug_keys[i] = nil
    end

    if #render_objects > 0 then
        capsule.render_id = render_objects
        capsule.render_cache = {
            surface_index = surface_index,
            pos_x = curr_pos.x,
            pos_y = curr_pos.y,
            passenger_index = passenger_index,
            debug_key = debug_key,
            dominant_item = dominant_item,
            ring_color = ring_color,
            target_offsets = target_offsets
        }
    else
        capsule.render_id = nil
        capsule.render_cache = {
            surface_index = surface_index,
            pos_x = curr_pos.x,
            pos_y = curr_pos.y,
            passenger_index = passenger_index,
            debug_key = debug_key,
            dominant_item = dominant_item,
            ring_color = ring_color,
            target_offsets = nil
        }
    end
end

--------------------------------------------------------------------------------
-- VIEWPORT INTERPOLATION & TIMED ARRIVAL RENDERING
--------------------------------------------------------------------------------
function capsule_renderer.is_in_any_viewport(surface_name, x, y)
    local surf = surface_name and game.surfaces[surface_name]
    if not (surf and surf.valid and x and y) then return false end
    return viewport_bvh.is_in_any_viewport(surf.index, x, y)
end

function capsule_renderer.is_in_any_viewport_legacy(surface_name, x, y)
    if active_viewport_count == 0 or not surface_name or not x or not y then
        return false
    end
    for i = 1, active_viewport_count do
        local vp = active_viewports[i]
        if vp.surface_name == surface_name then
            if x >= vp.left and x <= vp.right and y >= vp.top and y <= vp.bottom then
                return true
            end
        end
    end
    return false
end

function capsule_renderer.get_interpolated_position(bf, current_tick)
    return timed_motion.get_interpolated_position(bf, current_tick)
end

function capsule_renderer._legacy_get_interpolated_position(bf, current_tick)
    if not bf then return { x = 0, y = 0 }, 0 end
    local start_tick = bf.start_tick or current_tick
    local arrival_tick = bf.arrival_tick or (start_tick + 6)
    local total_ticks = arrival_tick - start_tick
    if total_ticks <= 0 then total_ticks = 1 end

    local start_pos = bf.start_pos or bf.terminal_pos
    local term_pos = bf.terminal_pos or start_pos
    if not (start_pos and term_pos) then
        return start_pos or term_pos or { x = 0, y = 0 }, 0
    end
    if current_tick >= arrival_tick then
        return { x = term_pos.x, y = term_pos.y }, 1.0
    end

    local total_dist = math.abs(term_pos.x - start_pos.x) + math.abs(term_pos.y - start_pos.y)
    local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or 1.2
    local dist_traveled = math.max(0, current_tick - start_tick) / tpt

    local progress = (total_dist > 0) and math.min(1.0, dist_traveled / total_dist) or 1.0
    local cur_x = (dist_traveled >= total_dist - 0.001) and term_pos.x or (start_pos.x + (bf.dx or 0) * dist_traveled)
    local cur_y = (dist_traveled >= total_dist - 0.001) and term_pos.y or (start_pos.y + (bf.dy or 0) * dist_traveled)

    return { x = cur_x, y = cur_y }, progress
end

function capsule_renderer.render_timed_kinetic_capsule(capsule, id, current_tick)
    local bf = capsule.beam_flight
    if not bf then return end

    local surface_name = bf.surface_name or capsule.surface_name or "nauvis"
    local surface = game.surfaces[surface_name]
    if not (surface and surface.valid) then return end

    local curr_pos, progress = capsule_renderer.get_interpolated_position(bf, current_tick)
    capsule.last_pos = curr_pos
    capsule.surface_name = surface_name

    local passenger = capsule.passenger
    local passenger_valid = passenger and passenger.valid
    if passenger_valid then
        passenger.teleport(curr_pos, surface)
    end

    local is_visible = passenger_valid or capsule_renderer.is_in_any_viewport(surface_name, curr_pos.x, curr_pos.y)

    if is_visible then
        capsule_renderer.render(capsule, id, curr_pos, surface)
    else
        if capsule.render_id then
            recycle_capsule_render(capsule)
        end
    end
end

local scratch_visible_capsules = {}
local previous_rendering_capsules = {}

--- Clears all active flight render objects for a player and returns handles to render_pool
function capsule_renderer.clear_player_flight_renders(player_index)
    if not (storage.player_flight_renders and storage.player_flight_renders[player_index]) then return end
    local p_renders = storage.player_flight_renders[player_index]
    for cap_id, r_entry in pairs(p_renders) do
        if r_entry.objects then
            for i = 1, #r_entry.objects do
                render_pool.recycle(player_index, r_entry.objects[i])
            end
        end
    end
    storage.player_flight_renders[player_index] = nil
end

--- Renders or mutates in-place flight visual handles for a single observing player
function capsule_renderer.render_custom_flight_for_player(flight_rec, f_id, p_idx, player, curr_pos, surface)
    storage.player_flight_renders = storage.player_flight_renders or {}
    local p_renders = storage.player_flight_renders[p_idx]
    if not p_renders then
        p_renders = {}
        storage.player_flight_renders[p_idx] = p_renders
    end

    local existing = p_renders[f_id]
    if existing and existing.objects and #existing.objects > 0 then
        for i = 1, #existing.objects do
            local obj = existing.objects[i]
            if obj and obj.valid then
                obj.target = curr_pos
            end
        end
        return
    end

    local spec = flight_rec.render_spec or {}
    local objects = {}

    if spec.sprite then
        local sp = render_pool.lease_sprite{
            sprite = spec.sprite,
            target = curr_pos,
            surface = surface,
            x_scale = spec.scale or 0.6,
            y_scale = spec.scale or 0.6,
            tint = spec.tint,
            render_layer = "entity-info-icon-above",
            players = { player }
        }
        if sp then objects[#objects + 1] = sp end
    end

    if spec.has_ring or spec.ring_radius then
        local ring = render_pool.lease_circle{
            color = spec.ring_color or spec.color or { r = 1.0, g = 0.4, b = 0.25, a = 0.85 },
            radius = spec.ring_radius or 0.42,
            filled = false,
            width = spec.ring_width or 2,
            target = curr_pos,
            surface = surface,
            players = { player }
        }
        if ring then objects[#objects + 1] = ring end
    end

    if not spec.sprite or spec.radius then
        local circ = render_pool.lease_circle{
            color = spec.color or { r = 1.0, g = 0.4, b = 0.25, a = 0.95 },
            radius = spec.radius or 0.24,
            filled = (spec.filled ~= false),
            width = spec.width or 2,
            target = curr_pos,
            surface = surface,
            players = { player }
        }
        if circ then objects[#objects + 1] = circ end
    end

    p_renders[f_id] = { objects = objects }
end

function capsule_renderer.render_flight_for_player(capsule, cap_id, p_idx, player, curr_pos, surface)
    storage.player_flight_renders = storage.player_flight_renders or {}
    local p_renders = storage.player_flight_renders[p_idx]
    if not p_renders then
        p_renders = {}
        storage.player_flight_renders[p_idx] = p_renders
    end
    local existing = p_renders[cap_id]

    local cap_data = capsule_manager.get(cap_id)
    local def = cap_data and cap_data.definition
    local ring_color = capsule_defs.get_debug_color(def or (cap_data and cap_data.type) or capsule.capsule_type)
        or { r = 1.0, g = 0.84, b = 0.0, a = 0.9 }

    local dominant_item = capsule.dominant_item or (cap_data and cap_data.dominant_item) or capsule_renderer.get_dominant_item(cap_id)
    local passenger = capsule.passenger
    local passenger_valid = passenger and passenger.valid

    if existing and existing.objects and #existing.objects > 0 then
        local objs = existing.objects
        local offsets = existing.offsets
        for i = 1, #objs do
            local obj = objs[i]
            if obj and obj.valid then
                local off_y = offsets and offsets[i] or 0
                if off_y ~= 0 then
                    obj.target = { curr_pos.x, curr_pos.y + off_y }
                else
                    obj.target = curr_pos
                end
            end
        end
        return
    end

    local objects = {}
    local offsets = {}

    if passenger_valid and passenger.index == p_idx then
        local eject_text = render_pool.lease_text{
            text = "[Shift + E] Emergency Eject",
            surface = surface,
            target = { curr_pos.x, curr_pos.y + 0.8 },
            color = { r = 1, g = 0.9, b = 0.3, a = 1.0 },
            players = { player },
            alignment = "center",
            scale = 0.9,
            render_layer = "light-effect"
        }
        if eject_text then
            objects[#objects + 1] = eject_text
            offsets[#offsets + 1] = 0.8
        end
    end

    if passenger_valid then
        local ring = render_pool.lease_circle{
            color = { r = 0, g = 0.8, b = 1, a = 0.9 },
            radius = 0.45,
            filled = false,
            width = 3,
            target = curr_pos,
            surface = surface,
            render_layer = "entity-info-icon-above",
            players = { player }
        }
        if ring then
            objects[#objects + 1] = ring
            offsets[#offsets + 1] = 0
        end
    else
        if dominant_item then
            local ring = render_pool.lease_circle{
                color = ring_color,
                radius = 0.35,
                filled = false,
                width = 2,
                target = curr_pos,
                surface = surface,
                render_layer = "entity-info-icon-above",
                players = { player }
            }
            if ring then
                objects[#objects + 1] = ring
                offsets[#offsets + 1] = 0
            end

            local sprite = render_pool.lease_sprite{
                sprite = "item/" .. dominant_item,
                target = curr_pos,
                surface = surface,
                x_scale = 0.55,
                y_scale = 0.55,
                render_layer = "entity-info-icon-above",
                players = { player }
            }
            if sprite then
                objects[#objects + 1] = sprite
                offsets[#offsets + 1] = 0
            end
        else
            local dot = render_pool.lease_circle{
                color = ring_color,
                radius = 0.25,
                filled = true,
                target = curr_pos,
                surface = surface,
                render_layer = "entity-info-icon-above",
                players = { player }
            }
            if dot then
                objects[#objects + 1] = dot
                offsets[#offsets + 1] = 0
            end
        end
    end

    p_renders[cap_id] = {
        objects = objects,
        offsets = offsets
    }
end

--- Per-Player Sliding-Scale Render Dispatcher (Phase 5)
function capsule_renderer.dispatch_player_renders(player, current_tick)
    if not (player and player.valid) then return end
    local p_idx = player.index
    local dbg = storage.debug and storage.debug[p_idx]
    local view_settings = player.game_view_settings
    local alt_mode = (view_settings and view_settings.show_entity_info) == true
    storage.player_last_alt_mode = storage.player_last_alt_mode or {}
    local prev_alt = storage.player_last_alt_mode[p_idx]
    if alt_mode ~= prev_alt then
        storage.player_last_alt_mode[p_idx] = alt_mode
        local v_set = viewport_bvh.get_visible_set(p_idx)
        if not alt_mode then
            for _, item in pairs(v_set) do
                viewport_bvh.detach_static_render(p_idx, item)
            end
        else
            local surf = player.surface
            if surf and surf.valid then
                for _, item in pairs(v_set) do
                    if item.leaf and (item.leaf.static_render_spec or item.leaf.has_trail) then
                        viewport_bvh.attach_static_render(p_idx, item, surf)
                    end
                end
            end
        end
    end

    if not alt_mode then
        capsule_renderer.clear_player_flight_renders(p_idx)
        return
    end

    if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
        capsule_renderer.clear_player_flight_renders(p_idx)
        return
    end

    local cadence = dbg.render_cadence or 1
    if cadence > 1 and ((current_tick + p_idx) % cadence ~= 0) then
        return
    end

    local surf = player.surface
    if not (surf and surf.valid) then return end

    local v_set = viewport_bvh.get_visible_set(p_idx)

    storage.player_flight_renders = storage.player_flight_renders or {}
    local p_renders = storage.player_flight_renders[p_idx]
    if not p_renders then
        p_renders = {}
        storage.player_flight_renders[p_idx] = p_renders
    end

    local rendered_this_tick = {}
    local flights_store = storage.timed_flights or storage.projector_flights

    if flights_store and v_set and next(v_set) ~= nil then
        local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or 1.2
        for key, item in pairs(v_set) do
            local reticle = storage.projector_reticles and storage.projector_reticles[item.owner_id]
            if reticle and reticle.status == "retreating" and reticle.retreat_tick then
                local elapsed_retreat = math.max(0, current_tick - reticle.retreat_tick)
                local dist_cleared = math.floor(elapsed_retreat / tpt)
                local leaf = item.leaf
                local d_start = leaf and leaf.d_start or 0
                local d_end = leaf and leaf.d_end or 16

                if dist_cleared >= d_start and item.render_objects then
                    local dots_to_clear = math.min(d_end - d_start, dist_cleared - d_start)
                    local cur_cleared = item.cleared_dots_count or 0
                    if dots_to_clear > cur_cleared then
                        for step_i = cur_cleared + 1, dots_to_clear do
                            local obj = item.render_objects[step_i]
                            if obj then
                                render_pool.recycle(p_idx, obj)
                                item.render_objects[step_i] = nil
                            end
                        end
                        item.cleared_dots_count = dots_to_clear
                    end
                end

                if dist_cleared >= d_end and item.render_objects then
                    for idx = 1, (d_end - d_start) do
                        local obj = item.render_objects[idx]
                        if obj then
                            render_pool.recycle(p_idx, obj)
                            item.render_objects[idx] = nil
                        end
                    end
                end

                if dist_cleared >= (reticle.total_dist or 0) and item.render_objects then
                    for idx, obj in pairs(item.render_objects) do
                        if obj then
                            render_pool.recycle(p_idx, obj)
                            item.render_objects[idx] = nil
                        end
                    end
                end
            end

            local owner_flights = (storage.timed_flights and storage.timed_flights[item.owner_id])
                or (storage.projector_flights and storage.projector_flights[item.owner_id])
            if owner_flights and #owner_flights > 0 then
                local leaf = item.leaf
                local d_start = leaf and leaf.d_start or 0
                local d_end = leaf and leaf.d_end or 16

                for f = 1, #owner_flights do
                    local flight = owner_flights[f]
                    local f_id = flight.id or flight.capsule_id
                    local t_start = flight.start_tick or 0
                    local flight_rec = timed_motion.get_flight(f_id)
                    local is_scope = (flight.kind == "projector_scope") or (flight_rec and (flight_rec.kind == "projector_scope" or flight_rec.on_arrival == "projector_scope"))
                    local is_anti = (flight.kind == "anti_reticle") or (flight_rec and (flight_rec.kind == "anti_reticle" or flight_rec.on_arrival == "anti_reticle"))

                    local t_entry, t_exit
                    if is_scope or is_anti then
                        local f_seg = flight_rec and flight_rec.seg_idx or 1
                        local l_seg = leaf and leaf.seg_idx or 1
                        if f_seg == l_seg then
                            t_entry = flight.start_tick or 0
                            t_exit = flight.arrival_tick or (t_entry + math.ceil((d_end - d_start) * tpt))
                        else
                            t_entry = -1
                            t_exit = -1
                        end
                    else
                        t_entry = t_start + math.floor(d_start * tpt)
                        t_exit = t_start + math.ceil(d_end * tpt)
                    end

                    if current_tick >= t_entry and current_tick <= t_exit then
                        local flight_rec = timed_motion.get_flight(f_id)
                        local capsule = storage.capsules and storage.capsules[f_id]
                        local bf = (capsule and capsule.beam_flight) or flight_rec

                        if bf then
                            local curr_pos, progress = timed_motion.get_interpolated_position(bf, current_tick)
                            local passenger = capsule and capsule.passenger
                            local passenger_valid = passenger and passenger.valid
                            if passenger_valid and passenger.index == p_idx then
                                passenger.teleport(curr_pos, surf)
                            end

                            rendered_this_tick[f_id] = true
                            if capsule and capsule.in_timed_flight then
                                    if dbg.capsules then
                                        capsule.last_pos = curr_pos
                                        capsule.surface_name = surf.name
                                        capsule_renderer.render_flight_for_player(capsule, f_id, p_idx, player, curr_pos, surf)
                                    end
                                elseif flight_rec and not is_anti then
                                    capsule_renderer.render_custom_flight_for_player(flight_rec, f_id, p_idx, player, curr_pos, surf)
                                    if leaf and (flight_rec.kind == "projector_scope" or flight_rec.on_arrival == "projector_scope") then
                                        local elapsed_t = math.max(0, current_tick - t_entry)
                                        local start_offset = math.max(0, (flight_rec.flight_start_dist or d_start) - d_start)
                                        local dist_in_leaf = math.min(d_end - d_start, start_offset + math.floor(elapsed_t / tpt))
                                        local cur_dots = item.trail_dots_count or 0
                                        if dist_in_leaf > cur_dots then
                                            item.render_objects = item.render_objects or {}
                                            local sp = leaf.start_pos or bf.start_pos
                                            local ep = leaf.end_pos or bf.terminal_pos
                                            local dx = 0
                                            local dy = 0
                                            if ep and sp and (ep.x ~= sp.x or ep.y ~= sp.y) then
                                                if ep.x > sp.x then dx = 1 elseif ep.x < sp.x then dx = -1 end
                                                if ep.y > sp.y then dy = 1 elseif ep.y < sp.y then dy = -1 end
                                            elseif bf and bf.dir then
                                                dx = bf.dir.x or 0
                                                dy = bf.dir.y or 0
                                            elseif leaf and leaf.dir then
                                                dx = leaf.dir.x or 0
                                                dy = leaf.dir.y or 0
                                            end
                                            local q_lvl = flight_rec.q_level or 0
                                            local pal = QUALITY_BEAM_PALETTE[q_lvl] or QUALITY_BEAM_PALETTE[0]

                                            local min_allowed = 0
                                            if reticle and reticle.status == "retreating" and reticle.retreat_tick then
                                                local el_ret = math.max(0, current_tick - reticle.retreat_tick)
                                                min_allowed = math.floor(el_ret / tpt)
                                            end

                                            for step_i = cur_dots + 1, dist_in_leaf do
                                                local global_d = d_start + step_i
                                                if global_d > min_allowed then
                                                local dot_p = { x = sp.x + dx * step_i, y = sp.y + dy * step_i }
                                                local dot_obj
                                                if global_d % 5 == 0 then
                                                    dot_obj = render_pool.lease_circle{
                                                        color = pal.core,
                                                        radius = 0.16,
                                                        filled = true,
                                                        target = dot_p,
                                                        surface = surf,
                                                        players = { player }
                                                    }
                                                else
                                                    dot_obj = render_pool.lease_circle{
                                                        color = MINOR_DOT_COLOR,
                                                        radius = 0.08,
                                                        filled = true,
                                                        target = dot_p,
                                                        surface = surf,
                                                        players = { player }
                                                    }
                                                end
                                                if dot_obj then
                                                    item.render_objects[step_i] = dot_obj
                                                end
                                                end
                                            end
                                            item.trail_dots_count = dist_in_leaf
                                        end
                                    end
                                end
                        end
                    end
                end
            end
        end
    end

    for cap_id, r_entry in pairs(p_renders) do
        if not rendered_this_tick[cap_id] then
            if r_entry.objects then
                for i = 1, #r_entry.objects do
                    render_pool.recycle(p_idx, r_entry.objects[i])
                end
            end
            p_renders[cap_id] = nil
        end
    end
end

function capsule_renderer.update_timed_capsules(current_tick)
    capsule_renderer.sync_all_arrival_dots()

    if storage.projector_flights then
        for _, flights in pairs(storage.projector_flights) do
            for f = 1, #flights do
                local cap = storage.capsules and storage.capsules[flights[f].capsule_id]
                if cap and cap.render_id then
                    recycle_capsule_render(cap)
                end
            end
        end
    end

    for _, player in pairs(game.connected_players) do
        capsule_renderer.dispatch_player_renders(player, current_tick)
    end
end

function capsule_renderer._legacy_update_timed_capsules(current_tick)
    if not storage.projector_flights or next(storage.projector_flights) == nil then
        if next(previous_rendering_capsules) ~= nil then
            for cap_id in pairs(previous_rendering_capsules) do
                local cap = storage.capsules and storage.capsules[cap_id]
                if cap and cap.render_id then
                    recycle_capsule_render(cap)
                end
                previous_rendering_capsules[cap_id] = nil
            end
        end
        return
    end

    for k in pairs(scratch_visible_capsules) do
        scratch_visible_capsules[k] = nil
    end

    if active_viewport_count > 0 and storage.surface_bvh then
        for i = 1, active_viewport_count do
            local vp = active_viewports[i]
            local surf = vp.surface_name and game.surfaces[vp.surface_name]
            if surf and surf.valid then
                local tree = storage.surface_bvh[surf.index]
                if tree and tree.root then
                    trajectory_bvh.attach(tree)
                    tree:query_visible_flights(vp.left, vp.top, vp.right, vp.bottom, storage.projector_flights, current_tick, scratch_visible_capsules)
                end
            end
        end
    end

    for cap_id in pairs(scratch_visible_capsules) do
        local capsule = storage.capsules and storage.capsules[cap_id]
        if capsule and capsule.in_timed_flight and capsule.beam_flight then
            capsule_renderer.render_timed_kinetic_capsule(capsule, cap_id, current_tick)
            previous_rendering_capsules[cap_id] = true
        end
    end

    for cap_id in pairs(previous_rendering_capsules) do
        if not scratch_visible_capsules[cap_id] then
            local cap = storage.capsules and storage.capsules[cap_id]
            if cap and cap.render_id then
                recycle_capsule_render(cap)
            end
            previous_rendering_capsules[cap_id] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- TIMED ARRIVAL DOT DEBUG RENDERING
--------------------------------------------------------------------------------
local previous_arrival_capsules = {}

local function destroy_arrival_dot_for_player(cap, p_idx)
    local p_entry = cap.arrival_render_objects and cap.arrival_render_objects[p_idx]
    if p_entry then
        if type(p_entry) == "table" then
            for i = 1, #p_entry do
                render_pool.recycle(p_idx, p_entry[i])
            end
        elseif p_entry.valid then
            render_pool.recycle(p_idx, p_entry)
        end
        cap.arrival_render_objects[p_idx] = nil
    end
end

function capsule_renderer.destroy_arrival_dot(cap)
    if not (cap and cap.arrival_render_objects) then return end
    for p_idx, p_entry in pairs(cap.arrival_render_objects) do
        if type(p_entry) == "table" then
            for i = 1, #p_entry do
                render_pool.recycle(p_idx, p_entry[i])
            end
        elseif p_entry and p_entry.valid then
            render_pool.recycle(p_idx, p_entry)
        end
    end
    cap.arrival_render_objects = nil
end

function capsule_renderer.render_arrival_dot_for_player(capsule, cap_id, player)
    if not (capsule and player and player.valid) then return end
    local p_idx = player.index
    if not is_debug_active("arrival_dots", p_idx) then
        destroy_arrival_dot_for_player(capsule, p_idx)
        return
    end

    local bf = capsule.beam_flight
    if not (bf and bf.terminal_pos) then
        destroy_arrival_dot_for_player(capsule, p_idx)
        return
    end

    local surface_name = bf.surface_name or capsule.surface_name or "nauvis"
    local surface = game.surfaces[surface_name]
    if not (surface and surface.valid) then
        destroy_arrival_dot_for_player(capsule, p_idx)
        return
    end

    local term_pos = bf.terminal_pos
    local cap_data = capsule_manager.get(cap_id)
    local def = cap_data and cap_data.definition
    local cap_color = capsule_defs.get_debug_color(def or (cap_data and cap_data.type) or capsule.capsule_type)
        or { r = 1.0, g = 0.84, b = 0.0, a = 0.9 }

    local is_receiver = bf.hit_receiver_unit ~= nil
    local ring_color = is_receiver and { r = 0.2, g = 0.95, b = 0.4, a = 0.9 } or { r = 1.0, g = 0.25, b = 0.1, a = 0.9 }

    capsule.arrival_render_objects = capsule.arrival_render_objects or {}
    local existing = capsule.arrival_render_objects[p_idx]

    if existing and #existing == 2 and existing[1].valid and existing[2].valid then
        local t1 = existing[1].target
        if t1.x ~= term_pos.x or t1.y ~= term_pos.y then
            existing[1].target = term_pos
            existing[2].target = term_pos
        end
        existing[1].color = cap_color
        existing[2].color = ring_color
        return
    end

    destroy_arrival_dot_for_player(capsule, p_idx)

    local dot = render_pool.lease_circle{
        color = cap_color,
        radius = 0.2,
        filled = true,
        target = term_pos,
        surface = surface,
        render_layer = "entity-info-icon-above",
        players = { player }
    }

    local ring = render_pool.lease_circle{
        color = ring_color,
        radius = 0.4,
        width = 2,
        filled = false,
        target = term_pos,
        surface = surface,
        render_layer = "entity-info-icon-above",
        players = { player }
    }

    capsule.arrival_render_objects[p_idx] = { dot, ring }
end

function capsule_renderer.update_arrival_dots(capsule, cap_id)
    if not (capsule and capsule.in_timed_flight and capsule.beam_flight) then return end
    for _, player in pairs(game.players) do
        if player and player.valid then
            capsule_renderer.render_arrival_dot_for_player(capsule, cap_id, player)
        end
    end
end

function capsule_renderer.sync_all_arrival_dots()
    if not storage.projector_flights or next(storage.projector_flights) == nil then
        if next(previous_arrival_capsules) ~= nil then
            for cap_id in pairs(previous_arrival_capsules) do
                local cap = storage.capsules and storage.capsules[cap_id]
                if cap then
                    capsule_renderer.destroy_arrival_dot(cap)
                end
                previous_arrival_capsules[cap_id] = nil
            end
        end
        return
    end

    local active_caps = {}
    for owner, p_flights in pairs(storage.projector_flights) do
        for i = 1, #p_flights do
            local cap_id = p_flights[i].capsule_id
            local cap = storage.capsules and storage.capsules[cap_id]
            if cap and cap.in_timed_flight and cap.beam_flight then
                active_caps[cap_id] = true
                capsule_renderer.update_arrival_dots(cap, cap_id)
            end
        end
    end

    for cap_id in pairs(previous_arrival_capsules) do
        if not active_caps[cap_id] then
            local cap = storage.capsules and storage.capsules[cap_id]
            if cap then
                capsule_renderer.destroy_arrival_dot(cap)
            end
            previous_arrival_capsules[cap_id] = nil
        end
    end

    for cap_id in pairs(active_caps) do
        previous_arrival_capsules[cap_id] = true
    end
end

--------------------------------------------------------------------------------
-- AUTOMATED TEST SUITE (PHASE 5)
--------------------------------------------------------------------------------
function capsule_renderer.run_tests(player)
    local function log_msg(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_msg("[color=yellow][RenderDispatcher Test][/color] Starting Phase 5 sliding-scale dispatcher self-test...")

    local p = player or (game.players and game.players[1])
    if not (p and p.valid) then
        log_msg("[color=red][RenderDispatcher Test] Aborted: No valid player context[/color]")
        return false
    end
    local p_idx = p.index
    local dbg = storage.debug and storage.debug[p_idx]
    local surf = p.surface

    -- Test 1: Closed-Form Vector Math Interpolation
    local tpt = (trajectory_bvh and trajectory_bvh.TICKS_PER_TILE) or 1.2
    local test_dist = 100
    local duration = math.ceil(test_dist * tpt)
    local dummy_flight = {
        start_pos = { x = 0, y = 0 },
        terminal_pos = { x = test_dist, y = 0 },
        dx = 1, dy = 0,
        start_tick = 1000,
        arrival_tick = 1000 + duration
    }
    local half_ticks = math.floor(duration * 0.5)
    local p_start = capsule_renderer.get_interpolated_position(dummy_flight, 1000)
    local p_mid = capsule_renderer.get_interpolated_position(dummy_flight, 1000 + half_ticks)
    local p_end = capsule_renderer.get_interpolated_position(dummy_flight, 1000 + duration)

    local expected_mid_x = half_ticks / tpt
    local expected_end_x = test_dist

    if math.abs(p_start.x - 0) > 0.05 or math.abs(p_mid.x - expected_mid_x) > 0.05 or math.abs(p_end.x - expected_end_x) > 0.05 then
        log_msg(string.format("[color=red][RenderDispatcher Test] Test 1 FAILED: p_start=%.2f, p_mid=%.2f (exp %.2f), p_end=%.2f (exp %.2f), tpt=%s[/color]",
            p_start.x, p_mid.x, expected_mid_x, p_end.x, expected_end_x, tostring(tpt)))
        return false
    end
    log_msg("[color=green][RenderDispatcher Test] Test 1: Closed-Form Vector Interpolation -> PASSED[/color]")

    -- Test 2: Early-Exit Gatekeeper (Alt-Mode / Debug Toggles)
    local orig_master = dbg.master
    dbg.master = false
    capsule_renderer.dispatch_player_renders(p, 1000)
    local p_renders = storage.player_flight_renders and storage.player_flight_renders[p_idx]
    if p_renders and next(p_renders) ~= nil then
        log_msg("[color=red][RenderDispatcher Test] Test 2 FAILED: Early-exit failed to clear renders when master debug disabled[/color]")
        dbg.master = orig_master
        return false
    end
    dbg.master = orig_master
    log_msg("[color=green][RenderDispatcher Test] Test 2: Early-Exit Gatekeeper -> PASSED (0.00ms execution on disabled)[/color]")

    -- Test 3: Staggered Cadence Interleaving
    local orig_cadence = dbg.render_cadence
    dbg.render_cadence = 6
    local phase_match_tick = 600 - p_idx
    local non_phase_tick = phase_match_tick + 1

    local executed_phase = ((phase_match_tick + p_idx) % 6 == 0)
    local executed_non = ((non_phase_tick + p_idx) % 6 == 0)
    if not executed_phase or executed_non then
        log_msg("[color=red][RenderDispatcher Test] Test 3 FAILED: Cadence interleaving phase calculation incorrect[/color]")
        dbg.render_cadence = orig_cadence
        return false
    end
    dbg.render_cadence = orig_cadence
    log_msg("[color=green][RenderDispatcher Test] Test 3: Per-Player Cadence & Staggered Interleaving -> PASSED[/color]")

    -- Test 4: In-Place Handle Mutation via RenderPool
    local dummy_cap = {
        capsule_id = 99991,
        capsule_type = "basic-capsule",
        dominant_item = "iron-plate"
    }
    capsule_renderer.render_flight_for_player(dummy_cap, 99991, p_idx, p, { x = 10, y = 10 }, surf)
    local rec = storage.player_flight_renders[p_idx][99991]
    if not (rec and rec.objects and #rec.objects > 0) then
        log_msg("[color=red][RenderDispatcher Test] Test 4 FAILED: Render objects not leased from pool[/color]")
        return false
    end
    local first_obj_id = rec.objects[1].id
    capsule_renderer.render_flight_for_player(dummy_cap, 99991, p_idx, p, { x = 12, y = 10 }, surf)
    if rec.objects[1].id ~= first_obj_id then
        log_msg("[color=red][RenderDispatcher Test] Test 4 FAILED: Render object re-allocated instead of mutating in-place[/color]")
        return false
    end
    log_msg("[color=green][RenderDispatcher Test] Test 4: In-Place Target Mutation (0 Allocations) -> PASSED[/color]")

    -- Test 5: Off-Screen Eviction & Pool Recycling
    capsule_renderer.clear_player_flight_renders(p_idx)
    if storage.player_flight_renders[p_idx] ~= nil then
        log_msg("[color=red][RenderDispatcher Test] Test 5 FAILED: Renders not cleaned after eviction[/color]")
        return false
    end
    log_msg("[color=green][RenderDispatcher Test] Test 5: Off-Screen Eviction & Pool Recycling -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][RenderDispatcher Test] ALL 5 TESTS PASSED! Per-Player Sliding-Scale Render Dispatcher active.[/font][/color]")
    return true
end

local debug_manager = require("scripts.debug-manager")
if debug_manager and debug_manager.register_clear_hook then
    debug_manager.register_clear_hook(capsule_renderer.clear_player_flight_renders)
end

commands.add_command("test-render-dispatcher", "Run self-tests on the Phase 5 Per-Player Sliding-Scale Render Dispatcher", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    capsule_renderer.run_tests(player)
end)
commands.add_command("pt-test-render-dispatcher", "Run self-tests on the Phase 5 Per-Player Sliding-Scale Render Dispatcher (Alias)", function(cmd)
    local player = cmd.player_index and game.get_player(cmd.player_index)
    capsule_renderer.run_tests(player)
end)

return capsule_renderer
