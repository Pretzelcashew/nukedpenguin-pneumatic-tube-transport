local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_queries = require("scripts.capsules.capsule-queries")
require("scripts.debug-manager")

local capsule_renderer = {}

-- Module-scoped per-frame player viewport cache & scratch structures
local last_prepared_tick = -1
local active_debug_players = {}
local active_debug_count = 0

local scratch_debug_players = {}
local scratch_debug_keys = {}

--- Pre-evaluates player viewport eligibility, Alt Mode state, and hover peeking unit numbers once per tick.
function capsule_renderer.prepare_frame()
    local current_tick = game.tick
    if last_prepared_tick == current_tick then
        return
    end
    last_prepared_tick = current_tick

    active_debug_count = 0

    local players = game.players
    for _, player in pairs(players) do
        if player and player.valid then
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

    -- Clear trailing references in pre-allocated array
    for i = active_debug_count + 1, #active_debug_players do
        active_debug_players[i] = nil
    end
end

--- Returns the dominant item string for a capsule.
--- Serves cached payload metadata instantly unless force_refresh is true.
--- Short-circuits force_refresh for capsules marked with no spoilable items.
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

    if not (cap_data and cap_data.holder and cap_data.holder.valid) then
        return cap_data and cap_data.dominant_item
    end

    local inventory = cap_data.holder.get_inventory(defines.inventory.chest)
    if not (inventory and inventory.valid and not inventory.is_empty()) then
        return cap_data.dominant_item or (cap_data.definition and cap_data.definition.name)
    end

    local max_cargo_count = 0
    local dominant_cargo_item = nil
    local max_vessel_count = 0
    local dominant_vessel_item = nil
    local primary_slot = cap_data.primary_slot

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

    if cap_data then
        cap_data.dominant_item = dominant_item
    end
    if storage.capsules and storage.capsules[capsule_id] then
        storage.capsules[capsule_id].dominant_item = dominant_item
    end

    return dominant_item
end

function capsule_renderer.render(capsule, id, curr_pos, surface)
    if not (surface and surface.valid and curr_pos and curr_pos.x and curr_pos.y) then
        capsule_queries.clear_capsule_render(capsule)
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

    -- Evaluate dominant item lazily with a 60-tick periodic recheck to capture natural engine spoilage on parked capsules containing spoilable items
    local dominant_item = nil
    if debug_key ~= 0 and debug_key ~= "" and not passenger_valid then
        local cap_id = capsule.capsule_id or id
        local cap_data = capsule_manager.get(cap_id)
        local has_spoilable = cap_data and (cap_data.has_spoilable_items ~= false)

        local tick_offset = cap_id or 0
        local recheck_spoilage = has_spoilable and ((game.tick + tick_offset) % 60 == 0)

        if cache and cache.dominant_item and cache.pos_x == curr_pos.x and cache.pos_y == curr_pos.y and render_objects_valid and not recheck_spoilage then
            dominant_item = cache.dominant_item
        else
            dominant_item = capsule_renderer.get_dominant_item(cap_id, recheck_spoilage)
        end
    end

    -- Check if current state matches cached render state
    local state_matches = cache
        and render_objects_valid
        and cache.surface_index == surface_index
        and cache.passenger_index == passenger_index
        and cache.debug_key == debug_key
        and cache.dominant_item == dominant_item

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

    -- Case 3: State changed, spoilage refreshed, or handles invalid -> Destroy old render objects and re-create
    capsule_queries.clear_capsule_render(capsule)

    if debug_key ~= 0 and debug_key ~= "" and not passenger_valid and dominant_item == nil then
        dominant_item = capsule_renderer.get_dominant_item(capsule.capsule_id or id)
    end

    local render_objects = {}
    local target_offsets = {}

    if passenger_valid then
        local eject_text = rendering.draw_text{
            text = "[Shift + E] Emergency Eject",
            surface = surface,
            target = { curr_pos.x, curr_pos.y + 0.8 },
            color = { r = 1, g = 0.9, b = 0.3, a = 1.0 },
            players = { passenger },
            alignment = "center",
            scale = 0.9
        }
        table.insert(render_objects, eject_text)
        table.insert(target_offsets, 0.8)
    end

    for i = 1, debug_player_count do
        local player = scratch_debug_players[i]
        if passenger_valid then
            local ring = rendering.draw_circle{
                color = { r = 0, g = 0.8, b = 1, a = 0.9 },
                radius = 0.45,
                filled = false,
                width = 3,
                target = curr_pos,
                surface = surface,
                players = { player }
            }
            table.insert(render_objects, ring)
            table.insert(target_offsets, 0)
        else
            if dominant_item then
                local ring = rendering.draw_circle{
                    color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                    radius = 0.35,
                    filled = false,
                    width = 2,
                    target = curr_pos,
                    surface = surface,
                    players = { player }
                }
                table.insert(render_objects, ring)
                table.insert(target_offsets, 0)

                local sprite = rendering.draw_sprite{
                    sprite = "item/" .. dominant_item,
                    target = curr_pos,
                    surface = surface,
                    x_scale = 0.55,
                    y_scale = 0.55,
                    players = { player }
                }
                table.insert(render_objects, sprite)
                table.insert(target_offsets, 0)
            else
                local dot = rendering.draw_circle{
                    color = { r = 1, g = 0.84, b = 0, a = 0.9 },
                    radius = 0.25,
                    filled = true,
                    target = curr_pos,
                    surface = surface,
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
            target_offsets = nil
        }
    end
end

return capsule_renderer