local events = require("scripts.events")
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
local BATCH_SIZE = 50

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

local function get_port_emitter_flow(entity, port_index)
    if not (entity and entity.valid) then return nil end
    local ports = port_defs.get_ports(entity)
    if ports and ports[port_index] then
        return ports[port_index].flow
    end
    return nil
end

local function is_any_player_rendering_flow()
    for _, player in pairs(game.players) do
        if is_debug_active("new_flow", player.index) then
            return true
        end
    end
    return false
end

function flow_engine.init_storage()
    storage.flow_port_registry = storage.flow_port_registry or {}
    storage.flow_port_connections = storage.flow_port_connections or {}
    storage.flow_entities = storage.flow_entities or {}
    storage.flow_emitters = storage.flow_emitters or {}
    storage.flow_levels = storage.flow_levels or {}
    storage.flow_queue = storage.flow_queue or {}
    storage.new_flow_render_objects = storage.new_flow_render_objects or {}
    storage.flow_render_dirty = storage.flow_render_dirty or false
end

function flow_engine.enqueue_port(pkey)
    if not pkey then return end
    storage.flow_queue = storage.flow_queue or {}
    storage.flow_queue[pkey] = true
end

function flow_engine.enqueue_entity(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    local ports = port_defs.get_ports(entity)
    if ports then
        for port_index = 1, #ports do
            flow_engine.enqueue_port(make_port_key(entity.unit_number, port_index))
        end
    end
end

local function compute_port_flow_level(pkey)
    local unit_num, port_idx = parse_port_key(pkey)
    if not unit_num then return 0 end

    local entity = storage.flow_entities[unit_num]
    if not (entity and entity.valid) then return 0 end

    local emitter_flow = get_port_emitter_flow(entity, port_idx)
    if emitter_flow then
        return emitter_flow
    end

    local ports = port_defs.get_ports(entity)
    if not ports then return 0 end

    local max_pos = 0
    local min_neg = 0

    for p_i = 1, #ports do
        local check_pkey = make_port_key(unit_num, p_i)
        local neighbors = storage.flow_port_connections and storage.flow_port_connections[check_pkey]
        if neighbors then
            for neighbor_key, _ in pairs(neighbors) do
                local n_level = storage.flow_levels[neighbor_key] or 0
                if n_level > 1 then
                    local incoming = n_level - 1
                    if incoming > max_pos then
                        max_pos = incoming
                    end
                elseif n_level < -1 then
                    local incoming = n_level + 1
                    if incoming < min_neg then
                        min_neg = incoming
                    end
                end
            end
        end
    end

    local pos_mag = max_pos
    local neg_mag = math.abs(min_neg)

    if pos_mag > neg_mag then
        return max_pos
    elseif neg_mag > pos_mag then
        return min_neg
    else
        return 0
    end
end

-- Staged Time-Sliced Step Engine with Throttled Visual Re-Rendering
function flow_engine.step(tick)
    storage.flow_queue = storage.flow_queue or {}
    local queue_has_items = next(storage.flow_queue) ~= nil

    if queue_has_items then
        storage.flow_port_connections = storage.flow_port_connections or {}
        storage.flow_entities = storage.flow_entities or {}
        storage.flow_emitters = storage.flow_emitters or {}
        storage.flow_levels = storage.flow_levels or {}

        local batch = {}
        local batch_count = 0

        for pkey, _ in pairs(storage.flow_queue) do
            batch_count = batch_count + 1
            batch[batch_count] = pkey
            storage.flow_queue[pkey] = nil
            if batch_count >= BATCH_SIZE then
                break
            end
        end

        for i = 1, batch_count do
            local pkey = batch[i]
            local unit_num, port_idx = parse_port_key(pkey)
            if unit_num then
                local entity = storage.flow_entities[unit_num]
                local target_level = compute_port_flow_level(pkey)
                local current_level = storage.flow_levels[pkey] or 0

                if target_level ~= current_level then
                    storage.flow_render_dirty = true
                    if target_level ~= 0 then
                        storage.flow_levels[pkey] = target_level
                    else
                        storage.flow_levels[pkey] = nil
                    end

                    if entity and entity.valid then
                        local ports = port_defs.get_ports(entity)
                        if ports then
                            for p_i = 1, #ports do
                                local int_key = make_port_key(unit_num, p_i)
                                if int_key ~= pkey then
                                    storage.flow_queue[int_key] = true
                                end
                            end
                        end
                    end

                    local neighbors = storage.flow_port_connections[pkey]
                    if neighbors then
                        for neighbor_key, _ in pairs(neighbors) do
                            storage.flow_queue[neighbor_key] = true
                        end
                    end
                end
            else
                if storage.flow_levels[pkey] then
                    storage.flow_levels[pkey] = nil
                    storage.flow_render_dirty = true
                end
            end
        end
    end

    -- Visual re-rendering is throttled (max 4 Hz during sweep, or immediately when idle)
    local is_idle = next(storage.flow_queue) == nil
    if storage.flow_render_dirty and is_any_player_rendering_flow() then
        if is_idle or (tick and tick % 15 == 0) then
            storage.flow_render_dirty = false
            flow_engine.redraw_all()
        end
    end
end

events.on_event(defines.events.on_tick, function(event)
    flow_engine.step(event.tick)
end)

function flow_engine.clear_all(player_index)
    if not player_index then
        for p_idx, objs in pairs(storage.new_flow_render_objects or {}) do
            for _, obj in ipairs(objs) do
                if obj and obj.valid then
                    obj.destroy()
                end
            end
            storage.new_flow_render_objects[p_idx] = {}
        end
        return
    end

    storage.new_flow_render_objects = storage.new_flow_render_objects or {}
    local objs = storage.new_flow_render_objects[player_index]
    if objs then
        for _, obj in ipairs(objs) do
            if obj and obj.valid then
                obj.destroy()
            end
        end
    end
    storage.new_flow_render_objects[player_index] = {}
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
    if not player_index then return end

    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    flow_engine.clear_all(player_index)

    if not is_debug_active("new_flow", player_index) then return end

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

                    local abs_level = math.abs(level)
                    local circle_color
                    if level > 0 then
                        circle_color = {r = 0, g = 0.4 + (abs_level / MAX_FLOW) * 0.6, b = 1, a = 0.8}
                    else
                        circle_color = {r = 1, g = 0.3 + (abs_level / MAX_FLOW) * 0.7, b = 0, a = 0.8}
                    end

                    local c_obj = rendering.draw_circle{
                        color = circle_color,
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
                                            local line_color = (level > 0)
                                                and {r = 0, g = 0.7, b = 1, a = 0.8}
                                                or {r = 1, g = 0.5, b = 0, a = 0.8}
                                            local l_obj = rendering.draw_line{
                                                color = line_color,
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
        flow_engine.enqueue_entity(entity)
    end
end)

removal_listener.on_entity_removed(function(entity, event)
    if entity and entity.unit_number then
        storage.flow_entities = storage.flow_entities or {}
        storage.flow_emitters = storage.flow_emitters or {}
        storage.flow_entities[entity.unit_number] = nil
        storage.flow_emitters[entity.unit_number] = nil
        flow_engine.enqueue_entity(entity)
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
        flow_engine.enqueue_entity(entity)
    end
end)

return flow_engine