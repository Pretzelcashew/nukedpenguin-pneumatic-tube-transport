local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")

local port_renderer = {}

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

function port_renderer.draw_ports_for_entity(entity, player)
    if not (entity and entity.valid and player and player.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    storage.port_render_objects = storage.port_render_objects or {}
    storage.port_render_objects[player.index] = storage.port_render_objects[player.index] or {}

    for _, port in ipairs(ports) do
        local circle = rendering.draw_circle{
            color = {r = 0, g = 1, b = 0.2, a = 0.8},
            radius = 0.12,
            filled = true,
            target = { entity = entity, offset = port.offset },
            surface = entity.surface,
            render_layer = "wires-above",
            players = { player }
        }
        table.insert(storage.port_render_objects[player.index], circle)
    end
end

function port_renderer.clear_all(player_index)
    storage.port_render_objects = storage.port_render_objects or {}

    if player_index then
        for _, obj in ipairs(storage.port_render_objects[player_index] or {}) do
            if obj and obj.valid then
                obj.destroy()
            end
        end
        storage.port_render_objects[player_index] = {}
    else
        for p_idx, objects in pairs(storage.port_render_objects) do
            for _, obj in ipairs(objects or {}) do
                if obj and obj.valid then
                    obj.destroy()
                end
            end
        end
        storage.port_render_objects = {}
    end
end

function port_renderer.draw_all(player_index)
    if player_index then
        local player = game.get_player(player_index)
        if not (player and player.valid) then return end

        port_renderer.clear_all(player_index)
        if not is_debug_active("ports", player_index) then return end

        local drawn_units = {}
        for _, net in pairs(storage.networks and storage.networks.list or {}) do
            for _, member in ipairs(net.members or {}) do
                if member.entity and member.entity.valid and not drawn_units[member.unit_number] then
                    drawn_units[member.unit_number] = true
                    port_renderer.draw_ports_for_entity(member.entity, player)
                end
            end
        end
    else
        for _, player in pairs(game.players) do
            port_renderer.draw_all(player.index)
        end
    end
end

local function handle_entity_created(event)
    for _, player in pairs(game.players) do
        if is_debug_active("ports", player.index) then
            port_renderer.draw_ports_for_entity(event.entity, player)
        end
    end
end

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_created)
end

return port_renderer