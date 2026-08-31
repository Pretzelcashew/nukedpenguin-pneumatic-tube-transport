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

local capsule_runner = {}

capsule_runner.get_capsule_count_at_entity = capsule_queries.get_capsule_count_at_entity
capsule_runner.get_capsule_count_at_entity_network = capsule_queries.get_capsule_count_at_entity_network
capsule_runner.find_capsules_at_entity = capsule_queries.find_capsules_at_entity

--- Clears retry delay on all parked capsules, forcing an immediate pathfinding / unpacking retry.
function capsule_runner.wake_parked_capsules()
    if not storage.capsules then return end
    for _, capsule in pairs(storage.capsules) do
        if not capsule.to_port_key then
            capsule.next_retry_tick = nil
        end
    end
end

function capsule_runner.remove_capsule(capsule_id)
    capsule_queries.remove_capsule(capsule_id)
    capsule_runner.wake_parked_capsules()
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

    for id, capsule in pairs(storage.capsules) do
        local current_speed = capsule_motion.calculate_segment_speed(capsule.from_port_key, capsule.to_port_key)
        local tiles_this_tick = current_speed
        local surface = nil
        local curr_pos = nil
        local safety_counter = 0

        while tiles_this_tick > 0 and safety_counter < 50 do
            safety_counter = safety_counter + 1

            if not capsule.to_port_key then
                local can_retry = not capsule.next_retry_tick or (current_tick and current_tick >= capsule.next_retry_tick)
                if can_retry then
                    if capsule_motion.handle_arrival(capsule, id) then
                        capsule_runner.wake_parked_capsules()
                        break
                    end

                    capsule.to_port_key = capsule_motion.select_next_target(capsule)
                    capsule.progress = 0.0
                    capsule_queries.update_capsule_occupancy(capsule)

                    if capsule.to_port_key then
                        capsule.next_retry_tick = nil
                        local new_speed = capsule_motion.calculate_segment_speed(capsule.from_port_key, capsule.to_port_key)
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

            local from_pos, surf = capsule_motion.get_port_world_pos(capsule.from_port_key)
            if not from_pos then
                capsule_queries.remove_capsule(id)
                capsule_runner.wake_parked_capsules()
                break
            end
            
            surface = surf
            curr_pos = { x = from_pos.x, y = from_pos.y }

            if not capsule.to_port_key then break end

            local to_pos = capsule_motion.get_port_world_pos(capsule.to_port_key)
            if not to_pos then
                capsule.to_port_key = nil
                capsule.progress = 0.0
                capsule.next_retry_tick = (current_tick or 0) + PARKED_RETRY_INTERVAL
                capsule_queries.update_capsule_occupancy(capsule)
                capsule_runner.wake_parked_capsules()
                break
            end

            local dx = to_pos.x - from_pos.x
            local dy = to_pos.y - from_pos.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= 0.001 then
                capsule.last_port_key = capsule.from_port_key
                capsule.from_port_key = capsule.to_port_key
                capsule.to_port_key = nil
                capsule.progress = 0.0
                capsule_queries.update_capsule_occupancy(capsule)
                
                capsule_motion.handle_arrival(capsule, id)
                capsule_runner.wake_parked_capsules()
                if not storage.capsules[id] then break end
            else
                local remaining_distance = distance * (1.0 - capsule.progress)

                if tiles_this_tick >= remaining_distance then
                    tiles_this_tick = tiles_this_tick - remaining_distance
                    capsule.last_port_key = capsule.from_port_key
                    capsule.from_port_key = capsule.to_port_key
                    capsule.to_port_key = nil
                    capsule.progress = 0.0
                    curr_pos = { x = to_pos.x, y = to_pos.y }
                    capsule_queries.update_capsule_occupancy(capsule)
                    
                    capsule_motion.handle_arrival(capsule, id)
                    capsule_runner.wake_parked_capsules()
                    if not storage.capsules[id] then break end
                else
                    capsule.progress = capsule.progress + (tiles_this_tick / distance)
                    curr_pos.x = from_pos.x + dx * capsule.progress
                    curr_pos.y = from_pos.y + dy * capsule.progress
                    tiles_this_tick = 0
                end
            end
        end

        if storage.capsules[id] then
            if curr_pos and surface and capsule_lifecycle.update(capsule, id, curr_pos, surface) then
                -- Capsule ruptured mid-transit
                capsule_runner.wake_parked_capsules()
            else
                capsule_renderer.render(capsule, id, curr_pos, surface)
            end
        end
    end
end

function capsule_runner.inject_from_hub(capsule_id, entity, passenger)
    init_storage()

    local best_port_key, fallback_port_key = capsule_motion.find_best_hub_outbound_port(entity, capsule_id, nil)
    local target_port_key = best_port_key or fallback_port_key
    if not target_port_key then return false end

    local new_capsule = {
        id = capsule_id,
        capsule_id = capsule_id,
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
    capsule_runner.wake_parked_capsules()
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

            capsule_manager.remove(capsule.capsule_id or id)
            capsule_queries.remove_capsule(id)
            capsule_runner.wake_parked_capsules()
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