local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_motion = require("scripts.capsules.capsule-motion")
local capsule_lifecycle = require("scripts.capsules.capsule-lifecycle")
local capsule_renderer = require("scripts.capsules.capsule-renderer")

local capsule_runner = {}

capsule_runner.get_capsule_count_at_entity = capsule_queries.get_capsule_count_at_entity
capsule_runner.get_capsule_count_at_entity_network = capsule_queries.get_capsule_count_at_entity_network
capsule_runner.remove_capsule = capsule_queries.remove_capsule
capsule_runner.find_capsules_at_entity = capsule_queries.find_capsules_at_entity

local function init_storage()
    storage.capsules = storage.capsules or {}
    storage.next_capsule_id = storage.next_capsule_id or 1
end

local function update_capsules()
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
                if capsule_motion.handle_arrival(capsule, id) then break end

                capsule.to_port_key = capsule_motion.select_next_target(capsule)
                capsule.progress = 0.0

                if capsule.to_port_key then
                    local new_speed = capsule_motion.calculate_segment_speed(capsule.from_port_key, capsule.to_port_key)
                    if current_speed > 0 then
                        tiles_this_tick = tiles_this_tick * (new_speed / current_speed)
                    else
                        tiles_this_tick = new_speed
                    end
                    current_speed = new_speed
                end
            end

            local from_pos, surf = capsule_motion.get_port_world_pos(capsule.from_port_key)
            if not from_pos then
                capsule_queries.clear_capsule_render(capsule)
                storage.capsules[id] = nil
                break
            end
            
            surface = surf
            curr_pos = { x = from_pos.x, y = from_pos.y }

            if not capsule.to_port_key then break end

            local to_pos = capsule_motion.get_port_world_pos(capsule.to_port_key)
            if not to_pos then
                capsule.to_port_key = nil
                capsule.progress = 0.0
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
                
                if capsule_motion.handle_arrival(capsule, id) then break end
            else
                local remaining_distance = distance * (1.0 - capsule.progress)

                if tiles_this_tick >= remaining_distance then
                    tiles_this_tick = tiles_this_tick - remaining_distance
                    capsule.last_port_key = capsule.from_port_key
                    capsule.from_port_key = capsule.to_port_key
                    capsule.to_port_key = nil
                    capsule.progress = 0.0
                    curr_pos = { x = to_pos.x, y = to_pos.y }
                    
                    if capsule_motion.handle_arrival(capsule, id) then break end
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
            else
                capsule_renderer.render(capsule, id, curr_pos, surface)
            end
        end
    end
end

function capsule_runner.inject_from_hub(capsule_id, entity, passenger)
    init_storage()
    local ports = port_defs.get_ports(entity)
    if not ports then return false end

    local best_port_key = nil
    local max_drop = -math.huge
    local fallback_port_key = nil

    for p_idx, _ in ipairs(ports) do
        local key = entity.unit_number .. ":" .. p_idx
        
        if storage.networks and storage.networks.port_to_network then
            local net_id = storage.networks.port_to_network[key]
            if net_id then
                if not fallback_port_key then fallback_port_key = key end
                
                local flow_map = networks.get_metadata(net_id, "flow_map")
                local node = flow_map and flow_map[key]
                
                if node and node.outbound_hops then
                    for _, hop_key in ipairs(node.outbound_hops) do
                        local target_node = flow_map[hop_key]
                        if target_node and target_node.unit_number ~= entity.unit_number then
                            local drop = node.pressure - target_node.pressure
                            if drop > max_drop then
                                max_drop = drop
                                best_port_key = key
                            end
                        end
                    end
                end
            end
        end
    end

    local target_port_key = best_port_key or fallback_port_key
    if not target_port_key then return false end

    storage.capsules[capsule_id] = {
        id = capsule_id,
        capsule_id = capsule_id,
        from_port_key = target_port_key,
        to_port_key = nil,
        last_port_key = nil,
        progress = 0.0,
        render_id = nil,
        source_hub = entity.unit_number,
        passenger = passenger
    }
    return true
end

function capsule_runner.emergency_eject(player)
    if not (storage.capsules and player and player.valid) then return end

    for id, capsule in pairs(storage.capsules) do
        if capsule.passenger == player then
            local phys_capsule = capsule_manager.get(capsule.capsule_id or id)
            local surface = player.surface
            local curr_pos = player.position

            local safe_pos = surface.find_non_colliding_position("character", curr_pos, 4, 0.5) or curr_pos
            player.teleport(safe_pos, surface)

            surface.create_entity{
                name = "explosion",
                position = safe_pos
            }

            capsule_queries.clear_capsule_render(capsule)
            if phys_capsule and phys_capsule.holder and phys_capsule.holder.valid then
                phys_capsule.holder.destroy()
            end

            capsule_queries.remove_capsule(capsule.capsule_id or id)
            storage.capsules[id] = nil
            break
        end
    end
end

events.on_event(defines.events.on_tick, function(event)
    update_capsules()
end)

return capsule_runner