local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_motion = require("scripts.capsules.capsule-motion")
local capsule_lifecycle = require("scripts.capsules.capsule-lifecycle")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local liminal_surface = require("scripts.surfaces.liminal-surface")
local networks_flow = require("scripts.networks.networks-flow")

local PARKED_RETRY_INTERVAL = 10
local DEFAULT_MIN_SPEED = 4.0 / 60.0

local scratch_pos = { x = 0, y = 0 }

local capsule_runner = {}

capsule_runner.get_capsule_count_at_entity = capsule_queries.get_capsule_count_at_entity
capsule_runner.get_capsule_count_at_entity_network = capsule_queries.get_capsule_count_at_entity_network
capsule_runner.find_capsules_at_entity = capsule_queries.find_capsules_at_entity

--- Clears retry delay on parked capsules affected by a freed port, entity, or network state change.
--- If no target is specified, wakes all parked capsules as a global fallback.
--- @param target string|number|table|nil port_key ("101:1"), unit_number, net_id, affected_nets table, or nil
function capsule_runner.wake_parked_capsules(target)
    if not storage.capsules then return end

    if not target then
        for _, capsule in pairs(storage.capsules) do
            if not capsule.to_port_key then
                capsule.next_retry_tick = nil
                capsule.last_failed_hub = nil
            end
        end
        return
    end

    local woke_capsules = {}

    local function wake_entity_capsules(u_num)
        if not (u_num and storage.occupancy and storage.occupancy.by_entity_from) then return end
        local from_slot = storage.occupancy.by_entity_from[u_num]
        if from_slot and from_slot.caps then
            for cap_id in pairs(from_slot.caps) do
                if not woke_capsules[cap_id] then
                    local cap = storage.capsules[cap_id]
                    if cap and not cap.to_port_key then
                        cap.next_retry_tick = nil
                        cap.last_failed_hub = nil
                        woke_capsules[cap_id] = true
                    end
                end
            end
        end
    end

    local function wake_network_capsules(net_id)
        if not (net_id and storage.networks and storage.networks.list) then return end
        local net = storage.networks.list[net_id]
        if net and net.members then
            for _, member in ipairs(net.members) do
                wake_entity_capsules(member.unit_number)
            end
        end
    end

    if type(target) == "table" then
        for k, v in pairs(target) do
            local net_id = (type(k) == "number" and k) or (type(v) == "number" and v)
            if net_id then
                wake_network_capsules(net_id)
            end
        end
    elseif type(target) == "string" then
        local u_num = capsule_queries.get_port_info(target)
        local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[target]
        if net_id then
            wake_network_capsules(net_id)
        end
        if u_num then
            wake_entity_capsules(u_num)
        end
    elseif type(target) == "number" then
        if storage.networks and storage.networks.list and storage.networks.list[target] then
            wake_network_capsules(target)
        end
        wake_entity_capsules(target)
    end
end

function capsule_runner.remove_capsule(capsule_id)
    local capsule = storage.capsules and storage.capsules[capsule_id]
    local target_key = capsule and (capsule.from_port_key or capsule.to_port_key)
    capsule_queries.remove_capsule(capsule_id)
    capsule_runner.wake_parked_capsules(target_key)
end

local function init_storage()
    storage.capsules = storage.capsules or {}
    storage.next_capsule_id = storage.next_capsule_id or 1
end

--- Retrieves the current physical world position and surface of a transit capsule counterpart
--- @param capsule_id number
--- @return MapPosition|nil position
--- @return LuaSurface|nil surface
function capsule_runner.get_capsule_location(capsule_id)
    if not storage.capsules then return nil, nil end
    local capsule = storage.capsules[capsule_id]
    if not capsule then return nil, nil end

    if capsule.seg_from_x and capsule.surface and capsule.surface.valid then
        if capsule.to_port_key and capsule.seg_to_key == capsule.to_port_key then
            local progress = capsule.progress or 0.0
            return {
                x = capsule.seg_from_x + capsule.seg_dx * progress,
                y = capsule.seg_from_y + capsule.seg_dy * progress
            }, capsule.surface
        else
            return { x = capsule.seg_from_x, y = capsule.seg_from_y }, capsule.surface
        end
    end

    local from_pos, surf = capsule_motion.get_port_world_pos(capsule.from_port_key)
    if not (from_pos and surf) then return nil, nil end

    if capsule.to_port_key then
        local to_pos = capsule_motion.get_port_world_pos(capsule.to_port_key)
        if to_pos then
            local progress = capsule.progress or 0.0
            local dx = to_pos.x - from_pos.x
            local dy = to_pos.y - from_pos.y
            return {
                x = from_pos.x + dx * progress,
                y = from_pos.y + dy * progress
            }, surf
        end
    end

    return { x = from_pos.x, y = from_pos.y }, surf
end

--- Handles an entity created or spawned on liminal_surface (e.g. from item spoilage)
--- Recreates spoiled units on the real-world transit capsule surface preserving quality and health.
--- @param entity LuaEntity
local function handle_liminal_entity_spawn(entity)
    if not (entity and entity.valid) then return end

    local surface = entity.surface
    if not (surface and surface.valid and surface.name == "liminal_surface") then return end

    -- Ignore container holder entities
    if entity.name == "invisible-capsule-holder" or entity.name == "visible-capsule-holder" then
        return
    end

    local holder = liminal_surface.find_holder_near(entity.position, 3.5)
    if not (holder and holder.valid) then
        entity.destroy()
        return
    end

    local capsule_id = holder.unit_number
    local capsule_data = capsule_manager.get(capsule_id)
    if not capsule_data then
        entity.destroy()
        return
    end

    local def = capsule_data.definition
    local spill_contents = def and def.spill_contents
    local units_allowed = true
    if type(spill_contents) == "table" and spill_contents.units == false then
        units_allowed = false
    elseif spill_contents == false then
        units_allowed = false
    end

    if not units_allowed then
        entity.destroy()
        return
    end

    local target_pos, target_surface = capsule_runner.get_capsule_location(capsule_id)
    if target_pos and target_surface and target_surface.valid then
        local safe_pos = target_surface.find_non_colliding_position(entity.name, target_pos, 6, 0.5) or target_pos
        local entity_name = entity.name
        local entity_force = entity.force
        local entity_quality = entity.quality
        local entity_health = entity.health

        local params = {
            name = entity_name,
            position = safe_pos,
            force = entity_force
        }

        -- Preserve Factorio 2.0 item/unit Quality
        if entity_quality then
            params.quality = entity_quality
        end

        local created = target_surface.create_entity(params)
        if created and created.valid then
            -- Preserve current health (naturally preserves negative health regen decay)
            if entity_health and created.health then
                created.health = entity_health
            end
        end

        entity.destroy()
    else
        entity.destroy()
    end
end

local function update_capsules(current_tick)
    if not storage.capsules then return end

    -- Pre-evaluate player viewport eligibility & Alt Mode settings once per tick
    capsule_renderer.prepare_frame()

    for id, capsule in pairs(storage.capsules) do
        if capsule.seg_from_key ~= capsule.from_port_key or capsule.seg_to_key ~= capsule.to_port_key then
            capsule_motion.setup_segment(capsule)
        end

        local current_speed = capsule.seg_speed or DEFAULT_MIN_SPEED
        local tiles_this_tick = current_speed
        local surface = capsule.surface
        local curr_pos = nil
        local safety_counter = 0

        while tiles_this_tick > 0 and safety_counter < 50 do
            safety_counter = safety_counter + 1

            if not capsule.to_port_key then
                local can_retry = not capsule.next_retry_tick or (current_tick and current_tick >= capsule.next_retry_tick)
                if can_retry then
                    local arr_port = capsule.from_port_key
                    if capsule_motion.handle_arrival(capsule, id) then
                        capsule_runner.wake_parked_capsules(arr_port)
                        break
                    end

                    local prev_from = capsule.from_port_key
                    capsule.to_port_key = capsule_motion.select_next_target(capsule)
                    capsule.progress = 0.0
                    capsule_queries.update_capsule_occupancy(capsule)

                    if capsule.to_port_key then
                        capsule.next_retry_tick = nil
                        capsule_motion.setup_segment(capsule)
                        capsule_runner.wake_parked_capsules(prev_from)
                        local new_speed = capsule.seg_speed or DEFAULT_MIN_SPEED
                        if current_speed > 0 then
                            tiles_this_tick = tiles_this_tick * (new_speed / current_speed)
                        else
                            tiles_this_tick = new_speed
                        end
                        current_speed = new_speed
                    else
                        capsule.next_retry_tick = (current_tick or 0) + PARKED_RETRY_INTERVAL
                    end
                end
            end

            if not (capsule.entity_from and capsule.entity_from.valid) then
                local bad_port = capsule.from_port_key
                capsule_queries.remove_capsule(id)
                capsule_runner.wake_parked_capsules(bad_port)
                break
            end

            surface = capsule.surface
            scratch_pos.x = capsule.seg_from_x
            scratch_pos.y = capsule.seg_from_y
            curr_pos = scratch_pos

            if not capsule.to_port_key then break end

            if not (capsule.entity_to and capsule.entity_to.valid) then
                local bad_to = capsule.to_port_key
                capsule.to_port_key = nil
                capsule.progress = 0.0
                capsule_queries.update_capsule_occupancy(capsule)
                capsule_motion.setup_segment(capsule)
                capsule_runner.wake_parked_capsules(bad_to)
                break
            end

            local distance = capsule.seg_dist
            if distance <= 0.001 then
                local vacated_port = capsule.last_port_key or capsule.from_port_key
                capsule.last_port_key = capsule.from_port_key
                capsule.from_port_key = capsule.to_port_key
                capsule.to_port_key = nil
                capsule.progress = 0.0
                capsule_queries.update_capsule_occupancy(capsule)
                capsule_motion.setup_segment(capsule)

                local arr_port = capsule.from_port_key
                if capsule_motion.handle_arrival(capsule, id) then
                    capsule_runner.wake_parked_capsules(arr_port)
                    if not storage.capsules[id] then break end
                else
                    if vacated_port then
                        capsule_runner.wake_parked_capsules(vacated_port)
                    end
                end
            else
                local remaining_distance = distance * (1.0 - capsule.progress)

                if tiles_this_tick >= remaining_distance then
                    tiles_this_tick = tiles_this_tick - remaining_distance
                    local vacated_port = capsule.last_port_key or capsule.from_port_key
                    capsule.last_port_key = capsule.from_port_key
                    capsule.from_port_key = capsule.to_port_key
                    capsule.to_port_key = nil
                    capsule.progress = 0.0
                    scratch_pos.x = capsule.seg_to_x
                    scratch_pos.y = capsule.seg_to_y
                    curr_pos = scratch_pos
                    capsule_queries.update_capsule_occupancy(capsule)
                    capsule_motion.setup_segment(capsule)

                    local arr_port = capsule.from_port_key
                    if capsule_motion.handle_arrival(capsule, id) then
                        capsule_runner.wake_parked_capsules(arr_port)
                        if not storage.capsules[id] then break end
                    else
                        if vacated_port then
                            capsule_runner.wake_parked_capsules(vacated_port)
                        end
                    end
                else
                    capsule.progress = capsule.progress + (tiles_this_tick / distance)
                    scratch_pos.x = capsule.seg_from_x + capsule.seg_dx * capsule.progress
                    scratch_pos.y = capsule.seg_from_y + capsule.seg_dy * capsule.progress
                    curr_pos = scratch_pos
                    tiles_this_tick = 0
                end
            end
        end

        if storage.capsules[id] then
            if curr_pos and surface and capsule_lifecycle.update(capsule, id, curr_pos, surface) then
                -- Capsule ruptured mid-transit
                capsule_runner.wake_parked_capsules(capsule.from_port_key)
            else
                capsule_renderer.render(capsule, id, curr_pos, surface)
            end
        end
    end
end

function capsule_runner.inject_from_hub(capsule_id, entity, passenger)
    init_storage()

    local cap_data = capsule_manager.get(capsule_id)
    local dominant_item = (cap_data and cap_data.dominant_item) or capsule_renderer.get_dominant_item(capsule_id)

    local best_port_key, fallback_port_key = capsule_motion.find_best_hub_outbound_port(entity, capsule_id, nil)
    local target_port_key = best_port_key or fallback_port_key
    if not target_port_key then return false end

    local new_capsule = {
        id = capsule_id,
        capsule_id = capsule_id,
        dominant_item = dominant_item,
        from_port_key = target_port_key,
        to_port_key = nil,
        last_port_key = nil,
        progress = 0.0,
        render_id = nil,
        render_cache = nil,
        source_hub = entity.unit_number,
        passenger = passenger
    }

    storage.capsules[capsule_id] = new_capsule
    capsule_queries.update_capsule_occupancy(new_capsule)
    capsule_motion.setup_segment(new_capsule)
    capsule_runner.wake_parked_capsules(target_port_key)
    return true
end

function capsule_runner.emergency_eject(player)
    if not (storage.capsules and player and player.valid) then return end

    for id, capsule in pairs(storage.capsules) do
        if capsule.passenger == player then
            local surface = player.surface
            local curr_pos = player.position

            local safe_pos = surface.find_non_colliding_position("character", curr_pos, 4, 0.5) or curr_pos
            player.teleport(safe_pos, surface)

            surface.create_entity{
                name = "explosion",
                position = safe_pos
            }

            local target_key = capsule.from_port_key or capsule.to_port_key
            capsule_manager.remove(capsule.capsule_id or id)
            capsule_queries.remove_capsule(id)
            capsule_runner.wake_parked_capsules(target_key)
            break
        end
    end
end

-- Hook entity creation events for instant spoilage handling
events.on_event(defines.events.on_trigger_created_entity, function(event)
    handle_liminal_entity_spawn(event.entity)
end)

events.on_event(defines.events.on_entity_spawned, function(event)
    handle_liminal_entity_spawn(event.entity)
end)

events.on_event(defines.events.script_raised_built, function(event)
    handle_liminal_entity_spawn(event.entity)
end)

events.on_event(defines.events.on_built_entity, function(event)
    handle_liminal_entity_spawn(event.entity)
end)

events.on_event(defines.events.on_tick, function(event)
    update_capsules(event.tick)

    if event.tick % 60 == 0 then
        local liminal_surf = game.surfaces["liminal_surface"]
        if liminal_surf and liminal_surf.valid then
            local entities = liminal_surf.find_entities_filtered{
                type = {"unit", "turret"}
            }
            for _, entity in ipairs(entities) do
                handle_liminal_entity_spawn(entity)
            end
        end
    end
end)

-- Register flow update listener to wake parked capsules when network flow changes
networks_flow.register_listener(capsule_runner.wake_parked_capsules)

return capsule_runner