-- scripts/capsule-runner.lua
local port_defs = require("scripts.ports.port-definitions")
local events = require("scripts.events")

local capsule_runner = {}

-- Speed configuration: 3 tiles per second = 0.05 tiles per tick
local TILES_PER_SECOND = 3
local SPEED_PER_TICK = TILES_PER_SECOND / 60

--- Looks up the world position of any port key
local function get_port_position(port_key)
    if not (storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local net = storage.networks.list[net_id]
    if not net then return nil end

    local u_num, p_idx = port_key:match("^(%d+):(%d+)$")
    u_num, p_idx = tonumber(u_num), tonumber(p_idx)

    for _, member in ipairs(net.members) do
        if member.unit_number == u_num and member.port_index == p_idx then
            if member.entity and member.entity.valid then
                local ports = port_defs.get_ports(member.entity)
                if ports and ports[p_idx] then
                    local offset = ports[p_idx].offset
                    return {
                        x = member.entity.position.x + offset.x,
                        y = member.entity.position.y + offset.y,
                        surface = member.entity.surface
                    }
                end
            end
        end
    end
    return nil
end

--- Retrieves the pre-built flow_map node for a given port key
local function get_flow_node(port_key)
    if not (storage.networks and storage.networks.port_to_network) then return nil end
    local net_id = storage.networks.port_to_network[port_key]
    if not net_id then return nil end

    local net = storage.networks.list[net_id]
    return net and net.metadata and net.metadata.flow_map and net.metadata.flow_map[port_key]
end

--- Selects the next hop using a round-robin index across available next_hops or handoffs
local function pick_next_hop(port_key)
    local node = get_flow_node(port_key)
    if not node then return nil end

    local options = (#node.next_hops > 0) and node.next_hops or node.handoffs
    if #options == 0 then return nil end

    node.rr_index = ((node.rr_index or 0) % #options) + 1
    return options[node.rr_index]
end

--- Moves active capsules frame-by-frame along the flow map
local function update_capsules()
    if not storage.capsules then return end

    for id, cap in pairs(storage.capsules) do
        cap.distance = cap.distance + SPEED_PER_TICK

        -- Advance across segments if capsule reached or passed the target port
        while cap.distance >= cap.segment_length do
            cap.distance = cap.distance - cap.segment_length
            cap.from_key = cap.to_key
            cap.from_pos = cap.to_pos

            local next_key = pick_next_hop(cap.from_key)
            if not next_key then
                -- Despawn at terminal dead end
                if cap.render_obj and cap.render_obj.valid then cap.render_obj.destroy() end
                storage.capsules[id] = nil
                goto continue
            end

            local next_pos = get_port_position(next_key)
            if not next_pos then
                if cap.render_obj and cap.render_obj.valid then cap.render_obj.destroy() end
                storage.capsules[id] = nil
                goto continue
            end

            cap.to_key = next_key
            cap.to_pos = next_pos

            local dx = cap.to_pos.x - cap.from_pos.x
            local dy = cap.to_pos.y - cap.from_pos.y
            cap.segment_length = math.sqrt(dx * dx + dy * dy)
            
            -- Instant transfer across zero-distance network boundary handoffs
            if cap.segment_length == 0 then
                cap.segment_length = 0.0001
            end
        end

        -- Linear position interpolation between start and end port positions
        local t = cap.distance / cap.segment_length
        local cur_x = cap.from_pos.x + (cap.to_pos.x - cap.from_pos.x) * t
        local cur_y = cap.from_pos.y + (cap.to_pos.y - cap.from_pos.y) * t

        -- Update or render visual indicator
        if cap.render_obj and cap.render_obj.valid then
            cap.render_obj.target = { cur_x, cur_y }
        else
            cap.render_obj = rendering.draw_circle{
                color = { r = 1, g = 0.8, b = 0 }, -- Gold indicator dot
                radius = 0.25,
                filled = true,
                target = { cur_x, cur_y },
                surface = cap.from_pos.surface
            }
        end

        ::continue::
    end
end

-- Register tick loop with event manager
events.on_event(defines.events.on_tick, function()
    update_capsules()
end)

-- Debug Commands
commands.add_command("spawn-capsule", "Spawns a test capsule at the selected entity", function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local entity = player.selected
    if not (entity and entity.valid) then
        player.print("[Capsule] Hover over a network entity first!")
        return
    end

    local ports = port_defs.get_ports(entity)
    if not ports then
        player.print("[Capsule] Selected entity has no defined ports!")
        return
    end

    local start_key = entity.unit_number .. ":1"
    local start_pos = get_port_position(start_key)
    if not start_pos then
        player.print("[Capsule] Port is not registered in an active network!")
        return
    end

    local next_key = pick_next_hop(start_key)
    if not next_key then
        player.print("[Capsule] No outbound flow path available from this port!")
        return
    end

    local next_pos = get_port_position(next_key)
    if not next_pos then return end

    local dx = next_pos.x - start_pos.x
    local dy = next_pos.y - start_pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then dist = 0.0001 end

    storage.next_capsule_id = (storage.next_capsule_id or 0) + 1
    local id = storage.next_capsule_id

    storage.capsules = storage.capsules or {}
    storage.capsules[id] = {
        id = id,
        from_key = start_key,
        from_pos = start_pos,
        to_key = next_key,
        to_pos = next_pos,
        distance = 0,
        segment_length = dist
    }

    player.print(string.format("[Capsule] Spawned #%d at port %s moving toward %s", id, start_key, next_key))
end)

commands.add_command("clear-capsules", "Clears all active capsules from the map", function(event)
    local player = game.get_player(event.player_index)
    if storage.capsules then
        for _, cap in pairs(storage.capsules) do
            if cap.render_obj and cap.render_obj.valid then
                cap.render_obj.destroy()
            end
        end
    end
    storage.capsules = {}
    if player then player.print("[Capsule] All active capsules cleared.") end
end)

return capsule_runner