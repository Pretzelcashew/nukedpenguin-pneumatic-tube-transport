-- File: scripts/flow/flow-engine.lua

local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local pump_settings = require("scripts.pump-settings")
local diverter_settings = require("scripts.diverter-settings")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")

local flow_engine = {}

local BATCH_SIZE = 50
local MAX_FLOW = 10
local DEFAULT_RANGE_SEED = 15

local OWNER_PALETTE = {
    {r = 0.30, g = 0.85, b = 0.70}, -- Teal (counter primary)
    {r = 0.20, g = 0.70, b = 1.00}, -- Electric cyan
    {r = 0.90, g = 0.40, b = 0.95}, -- Bright magenta
    {r = 0.30, g = 0.90, b = 0.35}, -- Emerald green
    {r = 1.00, g = 0.65, b = 0.15}, -- Bright amber
    {r = 1.00, g = 0.30, b = 0.40}, -- Coral red
    {r = 0.60, g = 0.50, b = 1.00}, -- Lavender blue
    {r = 0.85, g = 0.95, b = 0.20}, -- Lemon yellow
}

local function get_owner_color(unit_number)
    if not unit_number then
        return {r = 0.30, g = 0.85, b = 0.70, a = 0.8}
    end
    local idx = ((unit_number - 1) % #OWNER_PALETTE) + 1
    local col = OWNER_PALETTE[idx]
    return {r = col.r, g = col.g, b = col.b, a = 0.8}
end

local registered_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    registered_entities[name] = true
end

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
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
    storage.parked_by_port = storage.parked_by_port or {}
    storage.object_destruction_map = storage.object_destruction_map or {}

    -- Counter Range Wavefront Fields
    storage.counter_levels = storage.counter_levels or {}
    storage.counter_owners = storage.counter_owners or {}
    storage.counter_owned_nodes = storage.counter_owned_nodes or {}
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.counter_renders = storage.counter_renders or {}
end

function flow_engine.enqueue_port(pkey)
    if pkey and storage.flow_queue then
        storage.flow_queue[pkey] = true
    end
end

function flow_engine.enqueue_unit_ports(unit_number)
    if not unit_number then return end
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if unit_ports then
        for i = 1, #unit_ports do
            flow_engine.enqueue_port(unit_ports[i])
        end
    end
end

function flow_engine.get_node_emitter_level(node)
    if not node or not node.emitter then return 0 end

    local unit_number = node.unit_number

    local pump_power = storage.pump_power_states and storage.pump_power_states[unit_number]
    if pump_power ~= nil then
        if not pump_power then return 0 end
        local pump_enabled = storage.pump_enabled_states and storage.pump_enabled_states[unit_number]
        if pump_enabled == false then return 0 end
        return node.emitter
    end

    if storage.active_pumps and storage.active_pumps[unit_number] then
        local pump_entity = storage.active_pumps[unit_number]
        if not (pump_entity and pump_entity.valid) then return 0 end

        local is_powered = (pump_entity.energy > 0)
        storage.pump_power_states = storage.pump_power_states or {}
        storage.pump_power_states[unit_number] = is_powered
        if not is_powered then return 0 end

        local is_enabled = pump_settings.is_pump_enabled(pump_entity)
        storage.pump_enabled_states = storage.pump_enabled_states or {}
        storage.pump_enabled_states[unit_number] = is_enabled
        if not is_enabled then return 0 end

        return node.emitter
    end

    local diverter_power = storage.diverter_power_states and storage.diverter_power_states[unit_number]
    if diverter_power ~= nil then
        if not diverter_power then return 0 end
        local port_idx = node.port_index
        local port_states = storage.diverter_port_states and storage.diverter_port_states[unit_number]
        if port_states and port_states[port_idx] == false then return 0 end

        local d_settings = storage.diverter_settings and storage.diverter_settings[unit_number]
        local p_setting = d_settings and d_settings.ports and d_settings.ports[port_idx]
        if p_setting and p_setting.mode == "input" then
            return -10
        else
            return 10
        end
    end

    if storage.active_diverters and storage.active_diverters[unit_number] then
        local div_entity = storage.active_diverters[unit_number]
        if not (div_entity and div_entity.valid) then return 0 end

        local is_powered = (div_entity.energy > 0)
        storage.diverter_power_states = storage.diverter_power_states or {}
        storage.diverter_power_states[unit_number] = is_powered
        if not is_powered then return 0 end

        local port_idx = node.port_index
        local is_port_on = diverter_settings.is_port_enabled(div_entity, port_idx)
        storage.diverter_port_states = storage.diverter_port_states or {}
        storage.diverter_port_states[unit_number] = storage.diverter_port_states[unit_number] or {}
        storage.diverter_port_states[unit_number][port_idx] = is_port_on
        if not is_port_on then return 0 end

        local d_settings = storage.diverter_settings and storage.diverter_settings[unit_number]
        local p_setting = d_settings and d_settings.ports and d_settings.ports[port_idx]
        if p_setting and p_setting.mode == "input" then
            return -10
        else
            return 10
        end
    end

    return node.emitter
end

local function destroy_pos_renders(pos_key)
    for p_idx, p_renders in pairs(storage.flow_renders or {}) do
        local objs = p_renders[pos_key]
        if objs then
            if objs.circle and objs.circle.valid then objs.circle.destroy() end
            if objs.text and objs.text.valid then objs.text.destroy() end
            p_renders[pos_key] = nil
        end
    end
end

local function destroy_counter_renders(pos_key)
    for p_idx, p_renders in pairs(storage.counter_renders or {}) do
        local objs = p_renders[pos_key]
        if objs then
            if objs.circle and objs.circle.valid then objs.circle.destroy() end
            if objs.text and objs.text.valid then objs.text.destroy() end
            p_renders[pos_key] = nil
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

local function get_dominant_port_at_pos(pos_key)
    local grid_ports = storage.flow_grid and storage.flow_grid[pos_key]
    if not grid_ports then return nil, 0 end

    local best_node = nil
    local max_mag = -1
    local best_level = 0

    for pkey in pairs(grid_ports) do
        local node = storage.flow_nodes and storage.flow_nodes[pkey]
        if node then
            local level = storage.flow_levels and storage.flow_levels[pkey] or 0
            local mag = math.abs(level)
            if mag > max_mag then
                max_mag = mag
                best_level = level
                best_node = node
            elseif mag == max_mag and max_mag > 0 then
                if level > best_level then
                    best_node = node
                    best_level = level
                elseif level == best_level and node.emitter and not (best_node and best_node.emitter) then
                    best_node = node
                    best_level = level
                end
            end
        end
    end

    return best_node, best_level
end

local function get_dominant_counter_at_pos(pos_key)
    local grid_ports = storage.flow_grid and storage.flow_grid[pos_key]
    if not grid_ports then return nil, 0, nil end

    local best_node = nil
    local max_level = 0
    local best_owner = nil

    for pkey in pairs(grid_ports) do
        local node = storage.flow_nodes and storage.flow_nodes[pkey]
        if node then
            local level = storage.counter_levels and storage.counter_levels[pkey] or 0
            local owner = storage.counter_owners and storage.counter_owners[pkey]
            if level > max_level and owner ~= nil then
                max_level = level
                best_owner = owner
                best_node = node
            end
        end
    end

    return best_node, max_level, best_owner
end

local function update_counter_pos_render(pos_key)
    if not (is_debug_active and is_debug_active("counter_range")) then return end

    local node, level, owner = get_dominant_counter_at_pos(pos_key)
    if not node or level == 0 or owner == nil then
        destroy_counter_renders(pos_key)
        return
    end

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if is_debug_active("counter_range", p_idx) then
            storage.counter_renders[p_idx] = storage.counter_renders[p_idx] or {}
            local p_renders = storage.counter_renders[p_idx]

            local circle_color = get_owner_color(owner)
            local pos = node.pos
            local surface = game.surfaces[node.surface_name]

            local current = p_renders[pos_key]
            if current and current.circle and current.circle.valid and current.text and current.text.valid then
                current.circle.color = circle_color
                current.text.text = tostring(level)
            else
                destroy_counter_renders(pos_key)
                if surface and surface.valid then
                    local c_obj = rendering.draw_circle{
                        color = circle_color,
                        radius = 0.15,
                        filled = true,
                        target = pos,
                        surface = surface,
                        only_in_alt_mode = true,
                        players = { player }
                    }
                    local t_obj = rendering.draw_text{
                        text = tostring(level),
                        surface = surface,
                        target = {x = pos.x, y = pos.y - 0.25},
                        color = {r = 1, g = 1, b = 1, a = 0.9},
                        scale = 0.7,
                        alignment = "center",
                        only_in_alt_mode = true,
                        players = { player }
                    }
                    p_renders[pos_key] = { circle = c_obj, text = t_obj }
                end
            end
        else
            destroy_counter_renders(pos_key)
        end
    end
end

local function update_pos_render(pos_key)
    if not is_debug_active("new_flow") then return end

    local node, level = get_dominant_port_at_pos(pos_key)
    if not node or level == 0 then
        destroy_pos_renders(pos_key)
        return
    end

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if is_debug_active("new_flow", p_idx) then
            storage.flow_renders[p_idx] = storage.flow_renders[p_idx] or {}
            local p_renders = storage.flow_renders[p_idx]

            local abs_level = math.abs(level)
            local circle_color = (level > 0)
                and {r = 0, g = 0.4 + (abs_level / MAX_FLOW) * 0.6, b = 1, a = 0.8}
                or  {r = 1, g = 0.3 + (abs_level / MAX_FLOW) * 0.7, b = 0, a = 0.8}

            local pos = node.pos
            local surface = game.surfaces[node.surface_name]

            local current = p_renders[pos_key]
            if current and current.circle and current.circle.valid and current.text and current.text.valid then
                current.circle.color = circle_color
                current.text.text = tostring(level)
            else
                destroy_pos_renders(pos_key)
                if surface and surface.valid then
                    local c_obj = rendering.draw_circle{
                        color = circle_color,
                        radius = 0.15,
                        filled = true,
                        target = pos,
                        surface = surface,
                        only_in_alt_mode = true,
                        players = { player }
                    }
                    local t_obj = rendering.draw_text{
                        text = tostring(level),
                        surface = surface,
                        target = {x = pos.x, y = pos.y - 0.25},
                        color = {r = 1, g = 1, b = 1, a = 0.9},
                        scale = 0.7,
                        alignment = "center",
                        only_in_alt_mode = true,
                        players = { player }
                    }
                    p_renders[pos_key] = { circle = c_obj, text = t_obj }
                end
            end
        else
            destroy_pos_renders(pos_key)
        end
    end
end

local function update_edge_render(key_a, key_b)
    if not is_debug_active("new_flow") then return end

    local edge_key = make_edge_key(key_a, key_b)
    local level_a = storage.flow_levels and storage.flow_levels[key_a] or 0
    local level_b = storage.flow_levels and storage.flow_levels[key_b] or 0
    local node_a = storage.flow_nodes and storage.flow_nodes[key_a]
    local node_b = storage.flow_nodes and storage.flow_nodes[key_b]

    if (level_a == 0 and level_b == 0) or not node_a or not node_b then
        destroy_edge_render(edge_key)
        return
    end

    if node_a.pos_key == node_b.pos_key then
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
                        only_in_alt_mode = true,
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

function flow_engine.clear_counter_renders(player_index)
    if player_index then
        if storage.counter_renders and storage.counter_renders[player_index] then
            for pos_key, objs in pairs(storage.counter_renders[player_index]) do
                if objs.circle and objs.circle.valid then objs.circle.destroy() end
                if objs.text and objs.text.valid then objs.text.destroy() end
            end
            storage.counter_renders[player_index] = {}
        end
    else
        for _, player in pairs(game.players) do
            flow_engine.clear_counter_renders(player.index)
        end
    end
end

function flow_engine.clear_all_renders(player_index)
    if player_index then
        if storage.flow_renders and storage.flow_renders[player_index] then
            for pos_key, objs in pairs(storage.flow_renders[player_index]) do
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
        flow_engine.clear_counter_renders(player_index)
    else
        for _, player in pairs(game.players) do
            flow_engine.clear_all_renders(player.index)
        end
    end
end

function flow_engine.draw_all_counters(player_index)
    local pos_keys = {}
    local count = 0
    for pos_key in pairs(storage.flow_grid or {}) do
        count = count + 1
        pos_keys[count] = pos_key
    end

    table.sort(pos_keys)

    for i = 1, count do
        update_counter_pos_render(pos_keys[i])
    end
end

function flow_engine.draw_all(player_index)
    local pos_keys = {}
    local count = 0
    for pos_key in pairs(storage.flow_grid or {}) do
        count = count + 1
        pos_keys[count] = pos_key
    end

    table.sort(pos_keys)

    for i = 1, count do
        local pos_key = pos_keys[i]
        update_pos_render(pos_key)
        update_counter_pos_render(pos_key)
        local grid_ports = storage.flow_grid[pos_key]
        if grid_ports then
            for pkey in pairs(grid_ports) do
                local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        update_edge_render(pkey, n_key)
                    end
                end
            end
        end
    end
end

function flow_engine.connect_entity(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if not registered_entities[entity.name] then return end

    local unit_number = entity.unit_number

    if script.register_on_object_destroyed then
        local reg_id = script.register_on_object_destroyed(entity)
        storage.object_destruction_map = storage.object_destruction_map or {}
        storage.object_destruction_map[reg_id] = { type = "entity", unit_number = unit_number }
    end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

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
            sense = port.sense,
            group = port.group,
            capsule_transmit = (port.capsule_transmit == true),
            pressure_transmit = (port.pressure_transmit == true),
            sense_transmit = (port.sense_transmit == true),
            cross_transit = (port.cross_transit == true)
        }

        storage.flow_grid[pos_key] = storage.flow_grid[pos_key] or {}

        for existing_pkey in pairs(storage.flow_grid[pos_key]) do
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
        update_pos_render(pos_key)
        update_counter_pos_render(pos_key)
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
                for n_key in pairs(neighbors) do
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

            if storage.counter_owners and storage.counter_owners[pkey] then
                local owner = storage.counter_owners[pkey]
                if storage.counter_owned_nodes and storage.counter_owned_nodes[owner] then
                    storage.counter_owned_nodes[owner][pkey] = nil
                end
                storage.counter_owners[pkey] = nil
            end

            if storage.flow_levels then storage.flow_levels[pkey] = nil end
            if storage.counter_levels then storage.counter_levels[pkey] = nil end
            if storage.flow_nodes then storage.flow_nodes[pkey] = nil end

            update_pos_render(pos_key)
            update_counter_pos_render(pos_key)
        end

        flow_engine.enqueue_port(pkey)
    end

    if storage.flow_unit_ports then
        storage.flow_unit_ports[unit_number] = nil
    end
end

function flow_engine.handle_capsule_destroyed(capsule_id)
    if not capsule_id then return end

    local cap = storage.capsules and storage.capsules[capsule_id]
    local target_key = cap and cap.from_port_key

    if storage.parked_by_port and cap then
        if cap.parked_at_port then
            local bucket = storage.parked_by_port[cap.parked_at_port]
            if bucket then
                bucket[capsule_id] = nil
                if next(bucket) == nil then
                    storage.parked_by_port[cap.parked_at_port] = nil
                end
            end
        end
    end

    if cap and cap.passenger and cap.passenger.valid then
        local player = cap.passenger
        local surface = player.surface
        local pos = player.position
        local safe_pos = surface and surface.find_non_colliding_position("character", pos, 4, 0.5) or pos
        if safe_pos and surface then
            player.teleport(safe_pos, surface)
        end
    end

    capsule_queries.remove_capsule(capsule_id)
    capsule_manager.remove(capsule_id)

    if target_key and storage.parked_by_port then
        local bucket = storage.parked_by_port[target_key]
        if bucket then
            for cap_id in pairs(bucket) do
                local parked_cap = storage.capsules and storage.capsules[cap_id]
                if parked_cap and parked_cap.to_port_key == nil then
                    parked_cap.next_retry_tick = nil
                    parked_cap.last_failed_hub = nil
                    parked_cap.last_port_key = nil
                end
            end
        end
    end
end

function flow_engine.handle_object_destroyed(unit_number)
    if not unit_number then return end

    if storage.hub_compartments and storage.hub_compartments[unit_number] then
        local compartment = storage.hub_compartments[unit_number]
        for _, capsule_id in ipairs(compartment) do
            capsule_queries.remove_capsule(capsule_id)
            capsule_manager.remove(capsule_id)
        end
        storage.hub_compartments[unit_number] = nil
    end

    local runner_ids = capsule_queries.find_capsules_at_entity(unit_number)
    for _, id in ipairs(runner_ids) do
        local cap = storage.capsules and storage.capsules[id]
        local capsule_id = cap and (cap.capsule_id or cap.id) or id

        if storage.parked_by_port and cap then
            if cap.parked_at_port then
                local bucket = storage.parked_by_port[cap.parked_at_port]
                if bucket then
                    bucket[capsule_id] = nil
                    if next(bucket) == nil then
                        storage.parked_by_port[cap.parked_at_port] = nil
                    end
                end
            end
        end

        capsule_queries.remove_capsule(capsule_id)
        capsule_manager.remove(capsule_id)
    end

    flow_engine.enqueue_unit_ports(unit_number)
    flow_engine.disconnect_entity({ unit_number = unit_number })

    if storage.active_hubs then storage.active_hubs[unit_number] = nil end
    if storage.hub_settings then storage.hub_settings[unit_number] = nil end
    if storage.hub_receive_locks then storage.hub_receive_locks[unit_number] = nil end
    if storage.active_pumps then storage.active_pumps[unit_number] = nil end
    if storage.pump_power_states then storage.pump_power_states[unit_number] = nil end
    if storage.pump_enabled_states then storage.pump_enabled_states[unit_number] = nil end
    if storage.pump_settings then storage.pump_settings[unit_number] = nil end
    if storage.active_diverters then storage.active_diverters[unit_number] = nil end
    if storage.diverter_power_states then storage.diverter_power_states[unit_number] = nil end
    if storage.diverter_port_states then storage.diverter_port_states[unit_number] = nil end
    if storage.diverter_settings then storage.diverter_settings[unit_number] = nil end
    if storage.active_counters then storage.active_counters[unit_number] = nil end
    if storage.counter_power_states then storage.counter_power_states[unit_number] = nil end
    if storage.spilled_containers then storage.spilled_containers[unit_number] = nil end
end

local function compute_port_counter_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0, nil end

    local unit_number = node.unit_number

    if storage.active_counters and storage.active_counters[unit_number] then
        local counter_entity = storage.active_counters[unit_number]
        if not (counter_entity and counter_entity.valid) then
            return 0, nil
        end

        local is_powered = (counter_entity.energy > 0)
        local last_power = storage.counter_power_states[unit_number]
        if last_power ~= is_powered then
            storage.counter_power_states[unit_number] = is_powered
            flow_engine.enqueue_unit_ports(unit_number)
        end

        if not is_powered then
            return 0, nil
        end

        local seed = node.sense or DEFAULT_RANGE_SEED
        return seed, unit_number
    end

    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports then return 0, nil end

    local max_cand_level = 0
    local winning_owner = nil

    for _, check_pkey in pairs(unit_ports) do
        local check_node = storage.flow_nodes and storage.flow_nodes[check_pkey]
        if check_node then
            local is_self = (check_pkey == pkey)
            local can_transmit_internally = node.sense_transmit and check_node.sense_transmit and (node.group ~= nil) and (check_node.group == node.group)

            if is_self or can_transmit_internally then
                local neighbors = storage.flow_connections and storage.flow_connections[check_pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        local n_level = storage.counter_levels and storage.counter_levels[n_key] or 0
                        local n_owner = storage.counter_owners and storage.counter_owners[n_key]

                        if n_level > 1 and n_owner ~= nil and storage.active_counters and storage.active_counters[n_owner] and storage.counter_power_states[n_owner] ~= false then
                            local cand_level = n_level - 1
                            if cand_level > max_cand_level then
                                max_cand_level = cand_level
                                winning_owner = n_owner
                            elseif cand_level == max_cand_level and cand_level > 0 then
                                if winning_owner == nil or n_owner < winning_owner then
                                    winning_owner = n_owner
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if max_cand_level == 0 or winning_owner == nil then
        return 0, nil
    end

    return max_cand_level, winning_owner
end

local function set_port_counter_ownership(pkey, target_level, target_owner)
    local current_level = storage.counter_levels and storage.counter_levels[pkey] or 0
    local current_owner = storage.counter_owners and storage.counter_owners[pkey]

    if target_level == current_level and target_owner == current_owner then
        return false
    end

    if current_owner and storage.counter_owned_nodes and storage.counter_owned_nodes[current_owner] then
        storage.counter_owned_nodes[current_owner][pkey] = nil
    end

    if target_level > 0 and target_owner ~= nil then
        storage.counter_levels[pkey] = target_level
        storage.counter_owners[pkey] = target_owner
        storage.counter_owned_nodes[target_owner] = storage.counter_owned_nodes[target_owner] or {}
        storage.counter_owned_nodes[target_owner][pkey] = true
    else
        storage.counter_levels[pkey] = nil
        storage.counter_owners[pkey] = nil
    end

    return true
end

local function compute_port_flow_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0 end

    if node.emitter then
        return flow_engine.get_node_emitter_level(node)
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
            local can_transmit_internally = node.pressure_transmit and check_node.pressure_transmit and (node.group ~= nil) and (check_node.group == node.group)

            if is_self or can_transmit_internally then
                local neighbors = storage.flow_connections and storage.flow_connections[check_pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
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

    for pkey in pairs(storage.flow_queue) do
        batch_count = batch_count + 1
        batch[batch_count] = pkey
        storage.flow_queue[pkey] = nil
        if batch_count >= BATCH_SIZE then
            break
        end
    end

    for i = 1, batch_count do
        local pkey = batch[i]

        -- Evaluate Pressure Flow
        local target_flow = compute_port_flow_level(pkey)
        local current_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
        local flow_changed = (target_flow ~= current_flow)

        if flow_changed then
            if target_flow ~= 0 then
                storage.flow_levels[pkey] = target_flow
            else
                storage.flow_levels[pkey] = nil
            end

            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node then
                update_pos_render(node.pos_key)
            end
        end

        -- Evaluate Counter Sensing Range
        local target_range, target_owner = compute_port_counter_level(pkey)
        local range_changed = set_port_counter_ownership(pkey, target_range, target_owner)

        if range_changed then
            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node then
                update_counter_pos_render(node.pos_key)
            end
        end

        -- Propagation
        if flow_changed or range_changed then
            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node then
                local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
                if unit_ports and node.group then
                    for _, int_key in pairs(unit_ports) do
                        if int_key ~= pkey then
                            local int_node = storage.flow_nodes and storage.flow_nodes[int_key]
                            if int_node and int_node.group == node.group then
                                if (flow_changed and node.pressure_transmit and int_node.pressure_transmit)
                                   or (range_changed and node.sense_transmit and int_node.sense_transmit) then
                                    flow_engine.enqueue_port(int_key)
                                end
                            end
                        end
                    end
                end
            end

            local neighbors = storage.flow_connections and storage.flow_connections[pkey]
            if neighbors then
                for n_key in pairs(neighbors) do
                    flow_engine.enqueue_port(n_key)
                    if flow_changed then
                        update_edge_render(pkey, n_key)
                    end
                end
            end
        end
    end
end

function flow_engine.register_events()
    events.on_event(defines.events.on_tick, function(event)
        flow_engine.step(event.tick)
    end)

    events.on_event(defines.events.on_object_destroyed, function(event)
        local reg_id = event.registration_number
        if not reg_id or not storage.object_destruction_map then return end

        local entry = storage.object_destruction_map[reg_id]
        if not entry then return end

        storage.object_destruction_map[reg_id] = nil

        if type(entry) == "table" then
            if entry.type == "capsule" then
                flow_engine.handle_capsule_destroyed(entry.id)
            elseif entry.type == "entity" then
                flow_engine.handle_object_destroyed(entry.unit_number)
            end
        elseif type(entry) == "number" then
            flow_engine.handle_object_destroyed(entry)
        end
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
            local entity = event.entity or event.destination
            if entity and entity.valid then
                flow_engine.connect_entity(entity)
            end
        end)
    end

    local removal_events = {
        defines.events.on_player_mined_entity,
        defines.events.on_robot_mined_entity,
        defines.events.on_entity_died,
        defines.script_raised_destroy
    }
    if defines.events.on_space_platform_mined_entity then
        table.insert(removal_events, defines.events.on_space_platform_mined_entity)
    end

    for _, event_id in ipairs(removal_events) do
        events.on_event(event_id, function(event)
            local entity = event.entity
            if entity and entity.valid then
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