local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")

local flow_engine = {}

local BATCH_SIZE = 50
local MAX_FLOW = 10

local registered_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    registered_entities[name] = true
end

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

local function make_pos_key(surface_name, x, y)
    local rx = math.floor(x * 10 + 0.5) / 10
    local ry = math.floor(y * 10 + 0.5) / 10
    return string.format("%s@%.1f,%.1f", surface_name, rx, ry)
end

local function make_edge_key(key_a, key_b)
    return key_a < key_b and (key_a .. "|" .. key_b) or (key_b .. "|" .. key_a)
end

function flow_engine.init_storage()
    storage.flow_nodes = storage.flow_nodes or {}
    storage.flow_grid = storage.flow_grid or {}
    storage.flow_connections = storage.flow_connections or {}
    storage.flow_levels = storage.flow_levels or {}
    storage.flow_queue = storage.flow_queue or {}
    storage.flow_unit_ports = storage.flow_unit_ports or {}
    storage.flow_renders = storage.flow_renders or {}
    storage.flow_edge_renders = storage.flow_edge_renders or {}
end

function flow_engine.enqueue_port(pkey)
    if pkey and storage.flow_queue then
        storage.flow_queue[pkey] = true
    end
end

--------------------------------------------------------------------------------
-- GRANULAR RENDER MANAGER (O(1) Per-Port Updates & Cleanup)
--------------------------------------------------------------------------------

local function destroy_port_renders(pkey)
    for p_idx, p_renders in pairs(storage.flow_renders or {}) do
        local objs = p_renders[pkey]
        if objs then
            if objs.circle and objs.circle.valid then objs.circle.destroy() end
            if objs.text and objs.text.valid then objs.text.destroy() end
            p_renders[pkey] = nil
        end
    end
end

local function destroy_edge_render(edge_key)
    for p_idx, e_renders in pairs(storage.flow_edge_renders or {}) do
        local line_obj = e_renders[edge_key]
        if line_obj and line_obj.valid then
            line_obj.destroy()
        end
        e_renders[edge_key] = nil
    end
end

local function update_port_render(pkey, level)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then
        destroy_port_renders(pkey)
        return
    end

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if is_debug_active("new_flow", p_idx) then
            storage.flow_renders[p_idx] = storage.flow_renders[p_idx] or {}
            local p_renders = storage.flow_renders[p_idx]

            if level == 0 or not level then
                destroy_port_renders(pkey)
            else
                local abs_level = math.abs(level)
                local circle_color = (level > 0)
                    and {r = 0, g = 0.4 + (abs_level / MAX_FLOW) * 0.6, b = 1, a = 0.8}
                    or  {r = 1, g = 0.3 + (abs_level / MAX_FLOW) * 0.7, b = 0, a = 0.8}

                local pos = node.pos
                local surface = game.surfaces[node.surface_name]

                local current = p_renders[pkey]
                if current and current.circle and current.circle.valid and current.text and current.text.valid then
                    current.circle.color = circle_color
                    current.text.text = tostring(level)
                else
                    destroy_port_renders(pkey)
                    if surface and surface.valid then
                        local c_obj = rendering.draw_circle{
                            color = circle_color,
                            radius = 0.15,
                            filled = true,
                            target = pos,
                            surface = surface,
                            players = { player }
                        }
                        local t_obj = rendering.draw_text{
                            text = tostring(level),
                            surface = surface,
                            target = {x = pos.x, y = pos.y - 0.25},
                            color = {r = 1, g = 1, b = 1, a = 0.9},
                            scale = 0.7,
                            alignment = "center",
                            players = { player }
                        }
                        p_renders[pkey] = { circle = c_obj, text = t_obj }
                    end
                end
            end
        else
            destroy_port_renders(pkey)
        end
    end
end

local function update_edge_render(key_a, key_b)
    local edge_key = make_edge_key(key_a, key_b)
    local level_a = storage.flow_levels and storage.flow_levels[key_a] or 0
    local level_b = storage.flow_levels and storage.flow_levels[key_b] or 0
    local node_a = storage.flow_nodes and storage.flow_nodes[key_a]
    local node_b = storage.flow_nodes and storage.flow_nodes[key_b]

    if level_a == 0 and level_b == 0 or not node_a or not node_b then
        destroy_edge_render(edge_key)
        return
    end

    local active_level = (level_a ~= 0) and level_a or level_b
    local line_color = (active_level > 0)
        and {r = 0, g = 0.7, b = 1, a = 0.8}
        or  {r = 1, g = 0.5, b = 0, a = 0.8}

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if is_debug_active("new_flow", p_idx) then
            storage.flow_edge_renders[p_idx] = storage.flow_edge_renders[p_idx] or {}
            local e_renders = storage.flow_edge_renders[p_idx]
            local existing = e_renders[edge_key]

            if existing and existing.valid then
                existing.color = line_color
            else
                local surface = game.surfaces[node_a.surface_name]
                if surface and surface.valid then
                    local l_obj = rendering.draw_line{
                        color = line_color,
                        width = 3,
                        from = node_a.pos,
                        to = node_b.pos,
                        surface = surface,
                        players = { player }
                    }
                    e_renders[edge_key] = l_obj
                end
            end
        else
            destroy_edge_render(edge_key)
        end
    end
end

function flow_engine.clear_all_renders(player_index)
    if player_index then
        if storage.flow_renders and storage.flow_renders[player_index] then
            for pkey, objs in pairs(storage.flow_renders[player_index]) do
                if objs.circle and objs.circle.valid then objs.circle.destroy() end
                if objs.text and objs.text.valid then objs.text.destroy() end
            end
            storage.flow_renders[player_index] = {}
        end
        if storage.flow_edge_renders and storage.flow_edge_renders[player_index] then
            for e_key, line_obj in pairs(storage.flow_edge_renders[player_index]) do
                if line_obj and line_obj.valid then line_obj.destroy() end
            end
            storage.flow_edge_renders[player_index] = {}
        end
    else
        for _, player in pairs(game.players) do
            flow_engine.clear_all_renders(player.index)
        end
    end
end

function flow_engine.draw_all(player_index)
    for pkey, level in pairs(storage.flow_levels or {}) do
        update_port_render(pkey, level)
        local neighbors = storage.flow_connections and storage.flow_connections[pkey]
        if neighbors then
            for n_key, _ in pairs(neighbors) do
                update_edge_render(pkey, n_key)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- SPATIAL CONNECTION TOPOLOGY MANAGEMENT
--------------------------------------------------------------------------------

function flow_engine.connect_entity(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if not registered_entities[entity.name] then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local unit_number = entity.unit_number
    local surface_name = entity.surface.name
    local ex, ey = entity.position.x, entity.position.y

    storage.flow_unit_ports[unit_number] = storage.flow_unit_ports[unit_number] or {}

    for port_index, port in ipairs(ports) do
        local px, py = ex + port.offset.x, ey + port.offset.y
        local pkey = make_port_key(unit_number, port_index)
        local pos_key = make_pos_key(surface_name, px, py)

        storage.flow_unit_ports[unit_number][port_index] = pkey

        storage.flow_nodes[pkey] = {
            unit_number = unit_number,
            port_index = port_index,
            pos_key = pos_key,
            pos = {x = px, y = py},
            surface_name = surface_name,
            emitter = port.flow,
            group = port.group,
            transmit = (port.transmit ~= false)
        }

        storage.flow_grid[pos_key] = storage.flow_grid[pos_key] or {}

        for existing_pkey, _ in pairs(storage.flow_grid[pos_key]) do
            local existing_node = storage.flow_nodes[existing_pkey]
            if existing_node and existing_node.unit_number ~= unit_number then
                storage.flow_connections[pkey] = storage.flow_connections[pkey] or {}
                storage.flow_connections[existing_pkey] = storage.flow_connections[existing_pkey] or {}

                storage.flow_connections[pkey][existing_pkey] = true
                storage.flow_connections[existing_pkey][pkey] = true

                flow_engine.enqueue_port(existing_pkey)
            end
        end

        storage.flow_grid[pos_key][pkey] = true
        flow_engine.enqueue_port(pkey)
    end
end

function flow_engine.disconnect_entity(entity)
    if not (entity and entity.unit_number) then return end

    local unit_number = entity.unit_number
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports then return end

    for port_index, pkey in pairs(unit_ports) do
        local node = storage.flow_nodes and storage.flow_nodes[pkey]
        if node then
            local pos_key = node.pos_key

            if storage.flow_grid and storage.flow_grid[pos_key] then
                storage.flow_grid[pos_key][pkey] = nil
                if next(storage.flow_grid[pos_key]) == nil then
                    storage.flow_grid[pos_key] = nil
                end
            end

            local neighbors = storage.flow_connections and storage.flow_connections[pkey]
            if neighbors then
                for n_key, _ in pairs(neighbors) do
                    if storage.flow_connections[n_key] then
                        storage.flow_connections[n_key][pkey] = nil
                        if next(storage.flow_connections[n_key]) == nil then
                            storage.flow_connections[n_key] = nil
                        end
                    end
                    destroy_edge_render(make_edge_key(pkey, n_key))
                    flow_engine.enqueue_port(n_key)
                end
                storage.flow_connections[pkey] = nil
            end

            destroy_port_renders(pkey)
            if storage.flow_levels then storage.flow_levels[pkey] = nil end
            if storage.flow_nodes then storage.flow_nodes[pkey] = nil end
        end

        flow_engine.enqueue_port(pkey)
    end

    if storage.flow_unit_ports then
        storage.flow_unit_ports[unit_number] = nil
    end
end

--------------------------------------------------------------------------------
-- WAVEFRONT PROPAGATION STEPPER
--------------------------------------------------------------------------------

local function compute_port_flow_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0 end

    if node.emitter then
        return node.emitter
    end

    local unit_number = node.unit_number
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports then return 0 end

    local max_pos = 0
    local min_neg = 0

    for _, check_pkey in pairs(unit_ports) do
        local check_node = storage.flow_nodes and storage.flow_nodes[check_pkey]
        if check_node then
            local is_self = (check_pkey == pkey)
            local can_transmit_internally = node.transmit and check_node.transmit and (node.group ~= nil) and (check_node.group == node.group)

            if is_self or can_transmit_internally then
                local neighbors = storage.flow_connections and storage.flow_connections[check_pkey]
                if neighbors then
                    for n_key, _ in pairs(neighbors) do
                        local n_level = storage.flow_levels and storage.flow_levels[n_key] or 0
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

function flow_engine.step(tick)
    if not storage.flow_queue or next(storage.flow_queue) == nil then return end

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
        local target_level = compute_port_flow_level(pkey)
        local current_level = storage.flow_levels and storage.flow_levels[pkey] or 0

        if target_level ~= current_level then
            if target_level ~= 0 then
                storage.flow_levels[pkey] = target_level
            else
                storage.flow_levels[pkey] = nil
            end

            update_port_render(pkey, target_level)

            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node and node.transmit then
                local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
                if unit_ports and node.group then
                    for _, int_key in pairs(unit_ports) do
                        if int_key ~= pkey then
                            local int_node = storage.flow_nodes and storage.flow_nodes[int_key]
                            if int_node and int_node.transmit and int_node.group == node.group then
                                flow_engine.enqueue_port(int_key)
                            end
                        end
                    end
                end
            end

            local neighbors = storage.flow_connections and storage.flow_connections[pkey]
            if neighbors then
                for n_key, _ in pairs(neighbors) do
                    flow_engine.enqueue_port(n_key)
                    update_edge_render(pkey, n_key)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- EVENT REGISTRATION MANAGER
--------------------------------------------------------------------------------

function flow_engine.register_events()
    events.on_event(defines.events.on_tick, function(event)
        flow_engine.step(event.tick)
    end)

    local build_events = {
        defines.events.on_built_entity,
        defines.events.on_robot_built_entity,
        defines.events.script_raised_built,
        defines.events.script_raised_revive,
        defines.events.on_entity_cloned
    }
    if defines.events.on_space_platform_built_entity then
        table.insert(build_events, defines.events.on_space_platform_built_entity)
    end

    for _, event_id in ipairs(build_events) do
        events.on_event(event_id, function(event)
            local entity = event.entity
            if entity and entity.valid then
                flow_engine.connect_entity(entity)
            end
        end)
    end

    local removal_events = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.events.script_raised_destroy
    }
    if defines.events.on_space_platform_mined_entity then
        table.insert(removal_events, defines.events.on_space_platform_mined_entity)
    end

    for _, event_id in ipairs(removal_events) do
        events.on_event(event_id, function(event)
            local entity = event.entity
            if entity then
                flow_engine.disconnect_entity(entity)
            end
        end)
    end

    events.on_event(defines.events.on_player_rotated_entity, function(event)
        local entity = event.entity
        if entity and entity.valid then
            flow_engine.disconnect_entity(entity)
            flow_engine.connect_entity(entity)
        end
    end)

    events.on_event(defines.events.on_player_flipped_entity, function(event)
        local entity = event.entity
        if entity and entity.valid then
            flow_engine.disconnect_entity(entity)
            flow_engine.connect_entity(entity)
        end
    end)
end

return flow_engine