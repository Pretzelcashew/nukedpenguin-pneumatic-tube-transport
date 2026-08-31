local networks = require("scripts.networks.networks")

local flow_renderer = {}

local function clear_network_drawings(net_id, player_index)
    storage.flow_render_ids = storage.flow_render_ids or {}

    if player_index then
        local p_renders = storage.flow_render_ids[player_index]
        if p_renders and p_renders[net_id] then
            for _, render_obj in ipairs(p_renders[net_id]) do
                if render_obj and render_obj.valid then
                    render_obj.destroy()
                end
            end
            p_renders[net_id] = nil
        end
    else
        for p_idx, p_renders in pairs(storage.flow_render_ids) do
            if p_renders[net_id] then
                for _, render_obj in ipairs(p_renders[net_id]) do
                    if render_obj and render_obj.valid then
                        render_obj.destroy()
                    end
                end
                p_renders[net_id] = nil
            end
        end
    end
end

local function clear_orphaned_drawings(player_index)
    storage.flow_render_ids = storage.flow_render_ids or {}
    local valid_nets = storage.networks and storage.networks.list or {}

    if player_index then
        local p_renders = storage.flow_render_ids[player_index] or {}
        for net_id, _ in pairs(p_renders) do
            if not valid_nets[net_id] then
                clear_network_drawings(net_id, player_index)
            end
        end
    else
        for p_idx, p_renders in pairs(storage.flow_render_ids) do
            for net_id, _ in pairs(p_renders) do
                if not valid_nets[net_id] then
                    clear_network_drawings(net_id, p_idx)
                end
            end
        end
    end
end

function flow_renderer.draw(net_id, target_player_index)
    if target_player_index then
        clear_orphaned_drawings(target_player_index)
        clear_network_drawings(net_id, target_player_index)

        if not is_debug_active("flow", target_player_index) then return end
        local player = game.get_player(target_player_index)
        if not (player and player.valid) then return end

        local flow_map = networks.get_metadata(net_id, "flow_map")
        if not flow_map then return end

        storage.flow_render_ids = storage.flow_render_ids or {}
        storage.flow_render_ids[target_player_index] = storage.flow_render_ids[target_player_index] or {}

        local render_objects = {}

        for key, node in pairs(flow_map) do
            local entity = node.entity
            if entity and entity.valid then
                local offset = node.offset or { x = 0, y = 0 }

                local text_obj = rendering.draw_text{
                    text = string.format("P: %d", node.pressure),
                    surface = entity.surface,
                    target = { entity = entity, offset = { x = offset.x, y = offset.y - 0.25 } },
                    color = node.pressure > 0 and {r = 0.2, g = 1, b = 0.2} or {r = 1, g = 0.3, b = 0.3},
                    scale = 0.8,
                    alignment = "center",
                    only_in_alt_mode = true,
                    render_layer = "lower-object-above-shadow",
                    players = { player }
                }
                table.insert(render_objects, text_obj)

                for _, hop_key in ipairs(node.outbound_hops) do
                    local target_node = flow_map[hop_key]
                    if target_node and target_node.entity and target_node.entity.valid then
                        local target_offset = target_node.offset or { x = 0, y = 0 }

                        local line_obj = rendering.draw_line{
                            surface = entity.surface,
                            from = { entity = entity, offset = offset },
                            to = { entity = target_node.entity, offset = target_offset },
                            color = {r = 0, g = 0.8, b = 1, a = 0.8},
                            width = 2,
                            draw_on_ground = false,
                            only_in_alt_mode = true,
                            render_layer = "lower-object-above-shadow",
                            players = { player }
                        }
                        table.insert(render_objects, line_obj)
                    end
                end
            end
        end

        storage.flow_render_ids[target_player_index][net_id] = render_objects
    else
        for _, player in pairs(game.players) do
            flow_renderer.draw(net_id, player.index)
        end
    end
end

function flow_renderer.clear(net_id, target_player_index)
    clear_network_drawings(net_id, target_player_index)
    clear_orphaned_drawings(target_player_index)
end

return flow_renderer