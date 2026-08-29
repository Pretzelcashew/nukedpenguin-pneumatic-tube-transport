local networks = require("scripts.networks.networks")

local flow_renderer = {}

local function clear_network_drawings(net_id)
    storage.flow_render_ids = storage.flow_render_ids or {}
    if storage.flow_render_ids[net_id] then
        for _, render_obj in ipairs(storage.flow_render_ids[net_id]) do
            if render_obj and render_obj.valid then
                render_obj.destroy()
            end
        end
        storage.flow_render_ids[net_id] = nil
    end
end

--- Purges render objects for network IDs that no longer exist in storage
local function clear_orphaned_drawings()
    storage.flow_render_ids = storage.flow_render_ids or {}
    local valid_nets = storage.networks and storage.networks.list or {}

    for net_id, _ in pairs(storage.flow_render_ids) do
        if not valid_nets[net_id] then
            clear_network_drawings(net_id)
        end
    end
end

function flow_renderer.draw(net_id)
    clear_orphaned_drawings()
    clear_network_drawings(net_id)

    local flow_map = networks.get_metadata(net_id, "flow_map")
    if not flow_map then return end

    storage.flow_render_ids = storage.flow_render_ids or {}
    local render_objects = {}

    for key, node in pairs(flow_map) do
        local entity = node.entity
        if entity and entity.valid then
            local offset = node.offset or { x = 0, y = 0 }

            -- Draw pressure text anchored to entity port (visible only in alt mode)
            local text_obj = rendering.draw_text{
                text = string.format("P: %d", node.pressure),
                surface = entity.surface,
                target = { entity = entity, offset = { x = offset.x, y = offset.y - 0.25 } },
                color = node.pressure > 0 and {r = 0.2, g = 1, b = 0.2} or {r = 1, g = 0.3, b = 0.3},
                scale = 0.8,
                alignment = "center",
                only_in_alt_mode = true
            }
            table.insert(render_objects, text_obj)

            -- Draw directional flow vectors (visible only in alt mode)
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
                        only_in_alt_mode = true
                    }
                    table.insert(render_objects, line_obj)
                end
            end
        end
    end

    storage.flow_render_ids[net_id] = render_objects
end

function flow_renderer.clear(net_id)
    clear_network_drawings(net_id)
    clear_orphaned_drawings()
end

return flow_renderer