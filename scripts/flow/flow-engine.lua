local creation_listener = require("scripts.flow.creation-listener")
local removal_listener = require("scripts.flow.removal-listener")
local state_listener = require("scripts.flow.state-listener")
local port_defs = require("scripts.flow.port-defs")

local flow_engine = {}

local EMITTER_NAMES = {
    ["pneumatic-pump"] = true,
    ["pneumatic-diverter"] = true,
}

local MAX_FLOW = 10

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

local function parse_port_key(key)
    local u, p = key:match("(%d+):(%d+)")
    if u and p then
        return tonumber(u), tonumber(p)
    end
    return nil, nil
end

function flow_engine.init_storage()
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.flow_entities = storage.flow_entities or {}
    storage.flow_emitters = storage.flow_emitters or {}
    storage.flow_levels = storage.flow_levels or {}
    storage.new_flow_render_objects = storage.new_flow_render_objects or {}
end

function flow_engine.recalculate()
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.flow_entities = storage.flow_entities or {}
    storage.flow_emitters = storage.flow_emitters or {}
    storage.flow_levels = {}

    local queue = {}

    for unit_number, entity in pairs(storage.flow_emitters) do
        if entity and entity.valid then
            local ports = port_defs.get_ports(entity)
            if ports then
                for port_index = 1, #ports do
                    local pkey = make_port_key(unit_number, port_index)
                    storage.flow_levels[pkey] = MAX_FLOW
                    table.insert(queue, {key = pkey, level = MAX_FLOW})
                end
            end
        else
            storage.flow_emitters[unit_number] = nil
        end
    end

    local head = 1
    while head <= #queue do
        local item = queue[head]
        head = head + 1

        local current_key = item.key
        local current_level = item.level

        if current_level > 1 then
            local next_level = current_level - 1
            local unit_num, port_idx = parse_port_key(current_key)

            if unit_num then
                local entity = storage.flow_entities[unit_num]
                if entity and entity.valid then
                    local ports = port_defs.get_ports(entity)
                    if ports then
                        for other_idx = 1, #ports do
                            if other_idx ~= port_idx then
                                local int_key = make_port_key(unit_num, other_idx)
                                if not storage.flow_levels[int_key] or storage.flow_levels[int_key] < current_level then
                                    storage.flow_levels[int_key] = current_level
                                    table.insert(queue, {key = int_key, level = current_level})
                                end
                            end
                        end
                    end
                end
            end

            local neighbors = storage.flow_port_connections[current_key]
            if neighbors then
                for neighbor_key, _ in pairs(neighbors) do
                    if not storage.flow_levels[neighbor_key] or storage.flow_levels[neighbor_key] < next_level then
                        storage.flow_levels[neighbor_key] = next_level
                        table.insert(queue, {key = neighbor_key, level = next_level})
                    end
                end
            end
        end
    end

    debug_print("[Flow Engine] Recalculated water-like flow. Active flow ports: " .. tostring(table_size(storage.flow_levels)))

    flow_engine.redraw_all()
end

function flow_engine.clear_all(player_index)
    storage.new_flow_render_objects = storage.new_flow_render_objects or {}
    if player_index then
        local objs = storage.new_flow_render_objects[player_index]
        if objs then
            for _, obj in ipairs(objs) do
                if obj and obj.valid then
                    obj.destroy()
                end
            end
        end
        storage.new_flow_render_objects[player_index] = {}
    else
        for p_idx, objs in pairs(storage.new_flow_render_objects) do
            for _, obj in ipairs(objs) do
                if obj and obj.valid then
                    obj.destroy()
                end
            end
            storage.new_flow_render_objects[p_idx] = {}
        end
    end
end

function flow_engine.draw_all(player_index)
    if player_index then
        flow_engine.draw_for_player(player_index)
    else
        for _, player in pairs(game.players) do
            flow_engine.draw_for_player(player.index)
        end
    end
end

function flow_engine.redraw_all()
    for _, player in pairs(game.players) do
        if is_debug_active("new_flow", player.index) then
            flow_engine.draw_for_player(player.index)
        else
            flow_engine.clear_all(player.index)
        end
    end
end

function flow_engine.draw_for_player(player_index)
    flow_engine.clear_all(player_index)

    if not is_debug_active("new_flow", player_index) then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    storage.flow_levels = storage.flow_levels or {}
    storage.flow_entities = storage.flow_entities or {}
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.new_flow_render_objects = storage.new_flow_render_objects or {}

    local render_list = {}
    local drawn_edges = {}

    for pkey, level in pairs(storage.flow_levels) do
        local unit_num, port_idx = parse_port_key(pkey)
        if unit_num and port_idx then
            local entity = storage.flow_entities[unit_num]
            if entity and entity.valid then
                local ports = port_defs.get_ports(entity)
                if ports and ports[port_idx] then
                    local port = ports[port_idx]
                    local px = entity.position.x + port.offset.x
                    local py = entity.position.y + port.offset.y
                    local surface = entity.surface
                    local pos = {x = px, y = py}

                    local c_obj = rendering.draw_circle{
                        color = {r = 0, g = 0.4 + (level / MAX_FLOW) * 0.6, b = 1, a = 0.8},
                        radius = 0.15,
                        filled = true,
                        target = pos,
                        surface = surface,
                        players = { player }
                    }
                    table.insert(render_list, c_obj)

                    local t_obj = rendering.draw_text{
                        text = tostring(level),
                        surface = surface,
                        target = {x = px, y = py - 0.25},
                        color = {r = 1, g = 1, b = 1, a = 0.9},
                        scale = 0.7,
                        alignment = "center",
                        players = { player }
                    }
                    table.insert(render_list, t_obj)

                    local neighbors = storage.flow_port_connections[pkey]
                    if neighbors then
                        for neighbor_key, _ in pairs(neighbors) do
                            local edge_id = pkey < neighbor_key and (pkey .. "|" .. neighbor_key) or (neighbor_key .. "|" .. pkey)
                            if not drawn_edges[edge_id] then
                                drawn_edges[edge_id] = true
                                local n_unit, n_port_idx = parse_port_key(neighbor_key)
                                if n_unit and n_port_idx then
                                    local n_entity = storage.flow_entities[n_unit]
                                    if n_entity and n_entity.valid then
                                        local n_ports = port_defs.get_ports(n_entity)
                                        if n_ports and n_ports[n_port_idx] then
                                            local n_port = n_ports[n_port_idx]
                                            local npos = {
                                                x = n_entity.position.x + n_port.offset.x,
                                                y = n_entity.position.y + n_port.offset.y
                                            }
                                            local l_obj = rendering.draw_line{
                                                color = {r = 0, g = 0.7, b = 1, a = 0.8},
                                                width = 3,
                                                from = pos,
                                                to = npos,
                                                surface = surface,
                                                players = { player }
                                            }
                                            table.insert(render_list, l_obj)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    storage.new_flow_render_objects[player_index] = render_list
end

creation_listener.on_entity_created(function(entity, event)
    if entity and entity.valid and entity.unit_number then
        storage.flow_entities = storage.flow_entities or {}
        storage.flow_emitters = storage.flow_emitters or {}
        storage.flow_entities[entity.unit_number] = entity
        if EMITTER_NAMES[entity.name] then
            storage.flow_emitters[entity.unit_number] = entity
        end
        flow_engine.recalculate()
    end
end)

removal_listener.on_entity_removed(function(entity, event)
    if entity and entity.unit_number then
        storage.flow_entities = storage.flow_entities or {}
        storage.flow_emitters = storage.flow_emitters or {}
        storage.flow_entities[entity.unit_number] = nil
        storage.flow_emitters[entity.unit_number] = nil
        flow_engine.recalculate()
    end
end)

state_listener.on_entity_state_changed(function(entity, event)
    if entity and entity.valid and entity.unit_number then
        storage.flow_entities = storage.flow_entities or {}
        storage.flow_emitters = storage.flow_emitters or {}
        storage.flow_entities[entity.unit_number] = entity
        if EMITTER_NAMES[entity.name] then
            storage.flow_emitters[entity.unit_number] = entity
        end
        flow_engine.recalculate()
    end
end)

return flow_engine