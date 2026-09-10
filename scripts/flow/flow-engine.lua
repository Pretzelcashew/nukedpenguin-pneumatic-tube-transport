local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local pump_settings = require("scripts.pump-settings")
local diverter_settings = require("scripts.diverter-settings")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local projector_settings = require("scripts.projector-settings")

local flow_engine = {}

local BATCH_SIZE = 50
local INTEROP_BATCH_SIZE = 10
local MAX_FLOW = 10
local DEFAULT_RANGE_SEED = 15
local BASE_PROJECTOR_RANGE = 50
local HOP_DISTANCE = 5

local PROXY_NAMES = {
    ["pneumatic-pump-circuit-proxy"] = true,
    ["pneumatic-diverter-circuit-proxy"] = true,
    ["pneumatic-capsule-counter-circuit-proxy"] = true,
    ["pneumatic-capsule-counter-red-proxy"] = true,
    ["pneumatic-capsule-counter-green-proxy"] = true,
    ["pneumatic-projector-circuit-proxy"] = true
}

local OWNER_PALETTE = {
    {r = 0.30, g = 0.85, b = 0.70}, -- Teal
    {r = 0.20, g = 0.70, b = 1.00}, -- Electric cyan
    {r = 0.90, g = 0.40, b = 0.95}, -- Bright magenta
    {r = 0.30, g = 0.90, b = 0.35}, -- Emerald green
    {r = 1.00, g = 0.65, b = 0.15}, -- Bright amber
    {r = 1.00, g = 0.30, b = 0.40}, -- Coral red
    {r = 0.60, g = 0.50, b = 1.00}, -- Lavender blue
    {r = 0.85, g = 0.95, b = 0.20}, -- Lemon yellow
}

local QUALITY_BEAM_PALETTE = {
    [0] = { core = {r = 1.00, g = 0.60, b = 0.90, a = 0.95} },
    [1] = { core = {r = 1.00, g = 0.70, b = 0.95, a = 0.95} },
    [2] = { core = {r = 1.00, g = 0.80, b = 1.00, a = 0.98} },
    [3] = { core = {r = 1.00, g = 0.90, b = 1.00, a = 0.98} },
    [4] = { core = {r = 1.00, g = 1.00, b = 1.00, a = 1.00} },
    [5] = { core = {r = 1.00, g = 1.00, b = 1.00, a = 1.00} }
}

local MINOR_DOT_COLOR = {r = 0.90, g = 0.20, b = 0.70, a = 0.75}

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

local function is_standard_entity(name)
    return (name == "stone-wall" or name == "gate")
end

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

-- Distinct port key scoped to unit, direction vector, and distance so different directions never collide
local function make_beam_port_key(unit_number, dx, dy, dist)
    return string.format("kinetic:%d:%d,%d:%d", unit_number, math.floor(dx or 0), math.floor(dy or 0), dist)
end

local function make_pos_key(surface_name, x, y)
    local rx = math.floor(x * 10 + 0.5) / 10
    local ry = math.floor(y * 10 + 0.5) / 10
    return string.format("%s@%.1f,%.1f", surface_name, rx, ry)
end

local function make_edge_key(key_a, key_b)
    return key_a < key_b and (key_a .. "|" .. key_b) or (key_b .. "|" .. key_a)
end

local function wake_port_parked(pkey)
    if not (pkey and storage.parked_by_port) then return end
    local bucket = storage.parked_by_port[pkey]
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

local function is_gate_terminator(unit_number)
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
    if not unit_ports or #unit_ports < 2 then return true end

    local has_gate_1 = false
    local neighbors_1 = storage.flow_connections and storage.flow_connections[unit_ports[1]]
    if neighbors_1 then
        for n_key in pairs(neighbors_1) do
            local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
            if n_node and storage.active_gates and storage.active_gates[n_node.unit_number] then
                has_gate_1 = true
                break
            end
        end
    end

    local has_gate_2 = false
    local neighbors_2 = storage.flow_connections and storage.flow_connections[unit_ports[2]]
    if neighbors_2 then
        for n_key in pairs(neighbors_2) do
            local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
            if n_node and storage.active_gates and storage.active_gates[n_node.unit_number] then
                has_gate_2 = true
                break
            end
        end
    end

    return not (has_gate_1 and has_gate_2)
end

local function is_port_flow_active(pkey)
    if not pkey then return false end
    if storage.flow_levels and (storage.flow_levels[pkey] or 0) ~= 0 then return true end
    if storage.counter_levels and (storage.counter_levels[pkey] or 0) > 0 then return true end
    if storage.kinetic_levels and (storage.kinetic_levels[pkey] or 0) > 0 then return true end
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if node and node.emitter and flow_engine.get_node_emitter_level(node) ~= 0 then return true end
    return false
end

function flow_engine.is_touching_active_flow(entity)
    if not (entity and entity.valid and storage.flow_grid) then return false end
    local ports = port_defs.get_ports(entity)
    if not ports then return false end

    local surface_name = entity.surface.name
    local ex, ey = entity.position.x, entity.position.y

    for _, port in ipairs(ports) do
        local px = ex + port.offset.x
        local py = ey + port.offset.y
        local pos_key = make_pos_key(surface_name, px, py)
        local grid_ports = storage.flow_grid[pos_key]
        if grid_ports then
            for existing_pkey in pairs(grid_ports) do
                if is_port_flow_active(existing_pkey) then return true end
            end
        end
    end
    return false
end

function flow_engine.is_touching_pneumatic_grid(entity)
    if not (entity and entity.valid and storage.flow_grid) then return false end
    local ports = port_defs.get_ports(entity)
    if not ports then return false end

    local surface_name = entity.surface.name
    local ex, ey = entity.position.x, entity.position.y

    for _, port in ipairs(ports) do
        local px = ex + port.offset.x
        local py = ey + port.offset.y
        local pos_key = make_pos_key(surface_name, px, py)
        if storage.flow_grid[pos_key] and next(storage.flow_grid[pos_key]) ~= nil then
            return true
        end
    end
    return false
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
    storage.kinetic_renders = storage.kinetic_renders or {}
    storage.kinetic_levels = storage.kinetic_levels or {}
    storage.parked_by_port = storage.parked_by_port or {}
    storage.object_destruction_map = storage.object_destruction_map or {}

    -- Counter Range Fields
    storage.counter_levels = storage.counter_levels or {}
    storage.counter_owners = storage.counter_owners or {}
    storage.counter_owned_nodes = storage.counter_owned_nodes or {}
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.counter_renders = storage.counter_renders or {}

    -- Walls and Gates Fields
    storage.active_walls = storage.active_walls or {}
    storage.active_gates = storage.active_gates or {}
    storage.gate_open_states = storage.gate_open_states or {}
    storage.gate_cutoff_states = storage.gate_cutoff_states or {}
    storage.wall_locked_group = storage.wall_locked_group or {}
    storage.soft_interop_registry = storage.soft_interop_registry or {}
    storage.interop_activation_queue = storage.interop_activation_queue or {}

    -- Electromagnetic Projector Fields
    storage.active_projectors = storage.active_projectors or {}
    storage.projector_power_states = storage.projector_power_states or {}
end

function flow_engine.enqueue_port(pkey)
    if pkey and storage.flow_queue then
        storage.flow_queue[pkey] = true
    end
end

function flow_engine.enqueue_projector(unit_number)
    flow_engine.enqueue_unit_ports(unit_number)
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
    if not node or not node.emitter or node.emitter == 0 then return 0 end
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
        return (p_setting and p_setting.mode == "input") and -10 or 10
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
        return (p_setting and p_setting.mode == "input") and -10 or 10
    end

    return node.emitter
end

function flow_engine.get_node_kinetic_emitter(node)
    if not node or not node.kinetic_transmit or not node.is_muzzle then return 0 end
    local unit_number = node.unit_number
    local entity = storage.active_projectors and storage.active_projectors[unit_number]
    if not (entity and entity.valid) then return 0 end

    local power_state = storage.projector_power_states and storage.projector_power_states[unit_number]
    local is_powered = (power_state ~= nil) and power_state or (entity.energy > 0)
    local is_enabled = storage.projector_enabled_states and (storage.projector_enabled_states[unit_number] ~= false)
    if not (is_powered and is_enabled) then return 0 end

    local q_level = (entity.quality and entity.quality.level) or 0
    return math.floor(BASE_PROJECTOR_RANGE * (1 + 0.3 * q_level))
end

function flow_engine.get_kinetic_level(pkey)
    if not (pkey and storage.kinetic_levels) then return 0 end
    return storage.kinetic_levels[pkey] or 0
end

local function destroy_pos_renders(pos_key, player_index)
    if player_index then
        local p_renders = storage.flow_renders and storage.flow_renders[player_index]
        if p_renders and p_renders[pos_key] then
            local objs = p_renders[pos_key]
            if objs.circle and objs.circle.valid then objs.circle.destroy() end
            if objs.text and objs.text.valid then objs.text.destroy() end
            p_renders[pos_key] = nil
        end
    else
        for _, p_renders in pairs(storage.flow_renders or {}) do
            local objs = p_renders[pos_key]
            if objs then
                if objs.circle and objs.circle.valid then objs.circle.destroy() end
                if objs.text and objs.text.valid then objs.text.destroy() end
                p_renders[pos_key] = nil
            end
        end
    end
end

local function destroy_counter_renders(pos_key, player_index)
    if player_index then
        local p_renders = storage.counter_renders and storage.counter_renders[player_index]
        if p_renders and p_renders[pos_key] then
            local objs = p_renders[pos_key]
            if objs.circle and objs.circle.valid then objs.circle.destroy() end
            if objs.text and objs.text.valid then objs.text.destroy() end
            p_renders[pos_key] = nil
        end
    else
        for _, p_renders in pairs(storage.counter_renders or {}) do
            local objs = p_renders[pos_key]
            if objs then
                if objs.circle and objs.circle.valid then objs.circle.destroy() end
                if objs.text and objs.text.valid then objs.text.destroy() end
                p_renders[pos_key] = nil
            end
        end
    end
end

local function destroy_edge_render(edge_key, player_index)
    if player_index then
        local e_renders = storage.flow_edge_renders and storage.flow_edge_renders[player_index]
        if e_renders and e_renders[edge_key] then
            local line_obj = e_renders[edge_key]
            if line_obj and line_obj.valid then line_obj.destroy() end
            e_renders[edge_key] = nil
        end
    else
        for _, e_renders in pairs(storage.flow_edge_renders or {}) do
            local line_obj = e_renders[edge_key]
            if line_obj and line_obj.valid then line_obj.destroy() end
            e_renders[edge_key] = nil
        end
    end
end

local function destroy_kinetic_pos_render(pos_key)
    if not (pos_key and storage.kinetic_renders) then return end
    local entry = storage.kinetic_renders[pos_key]
    if entry then
        if entry.dot and entry.dot.valid then entry.dot.destroy() end
        if entry.ring and entry.ring.valid then entry.ring.destroy() end
        storage.kinetic_renders[pos_key] = nil
    end
end

local function update_kinetic_pos_render(pos_key, pos, surface, is_prominent, is_endpoint, is_receiver, q_level)
    destroy_kinetic_pos_render(pos_key)
    if not (surface and surface.valid and pos) then return end

    local palette = QUALITY_BEAM_PALETTE[q_level or 0] or QUALITY_BEAM_PALETTE[0]
    storage.kinetic_renders = storage.kinetic_renders or {}

    local dot_obj = nil
    local ring_obj = nil

    if is_prominent then
        dot_obj = rendering.draw_circle{
            color = palette.core,
            radius = 0.16,
            filled = true,
            target = pos,
            surface = surface,
            only_in_alt_mode = true
        }
    else
        dot_obj = rendering.draw_circle{
            color = MINOR_DOT_COLOR,
            radius = 0.08,
            filled = true,
            target = pos,
            surface = surface,
            only_in_alt_mode = true
        }
    end

    if is_endpoint then
        local ring_color = is_receiver
            and {r = 0.20, g = 0.90, b = 1.00, a = 0.90}
            or  {r = 1.00, g = 0.35, b = 0.20, a = 0.90}
        local ring_radius = is_receiver and 0.35 or 0.30

        ring_obj = rendering.draw_circle{
            color = ring_color,
            radius = ring_radius,
            filled = false,
            width = 2,
            target = pos,
            surface = surface,
            only_in_alt_mode = true
        }
    end

    storage.kinetic_renders[pos_key] = { dot = dot_obj, ring = ring_obj }
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
    if not (is_debug_active and is_debug_active("counter_range")) then
        destroy_counter_renders(pos_key)
        return
    end

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
                destroy_counter_renders(pos_key, p_idx)
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
            destroy_counter_renders(pos_key, p_idx)
        end
    end
end

local function update_pos_render(pos_key)
    if not is_debug_active("new_flow") then
        destroy_pos_renders(pos_key)
        return
    end

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
                destroy_pos_renders(pos_key, p_idx)
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
            destroy_pos_renders(pos_key, p_idx)
        end
    end
end

local function update_edge_render(key_a, key_b)
    if not is_debug_active("new_flow") then
        destroy_edge_render(make_edge_key(key_a, key_b))
        return
    end

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
                destroy_edge_render(edge_key, p_idx)
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
            destroy_edge_render(edge_key, p_idx)
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

function flow_engine.clear_flow_renders(player_index)
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
    else
        for _, player in pairs(game.players) do
            flow_engine.clear_flow_renders(player.index)
        end
    end

    if storage.kinetic_renders then
        for pos_key, entry in pairs(storage.kinetic_renders) do
            if entry.dot and entry.dot.valid then entry.dot.destroy() end
            if entry.ring and entry.ring.valid then entry.ring.destroy() end
        end
        storage.kinetic_renders = {}
    end
end

function flow_engine.clear_all_renders(player_index)
    flow_engine.clear_flow_renders(player_index)
    flow_engine.clear_counter_renders(player_index)
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

function flow_engine.draw_flow(player_index)
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

function flow_engine.draw_all(player_index)
    flow_engine.draw_flow(player_index)
    flow_engine.draw_all_counters(player_index)
end

function flow_engine.check_tile_obstruction(surface, tx, ty, sender_entity)
    if not (surface and surface.valid) then return { blocked = false, is_receiver = false } end
    local candidates = surface.find_entities_filtered{
        area = {{tx - 0.45, ty - 0.45}, {tx + 0.45, ty + 0.45}}
    }
    local sender_unit = (sender_entity and sender_entity.valid) and sender_entity.unit_number or nil

    for _, cand in ipairs(candidates) do
        if cand.valid and cand ~= sender_entity and cand.unit_number ~= sender_unit then
            local cand_name = cand.name
            local cand_type = cand.type

            local is_ignorable = (cand_type == "entity-ghost")
                or (cand_type == "character")
                or (cand_type == "car")
                or (cand_type == "spider-vehicle")
                or (cand_type == "item-entity")
                or (cand_type == "flying-robot")
                or (cand_type == "logistic-robot")
                or (cand_type == "construction-robot")
                or (cand_type == "projectile")
                or (cand_type == "smoke-with-trigger")
                or (cand_type == "sticker")
                or (cand_type == "highlight-box")
                or (cand_type == "speech-bubble")
                or (PROXY_NAMES[cand_name] == true)

            if not is_ignorable then
                if cand_name == "pneumatic-projector" then
                    return { blocked = true, is_receiver = true, receiver = cand }
                else
                    return { blocked = true, is_receiver = false, obstacle = cand }
                end
            end
        end
    end

    return { blocked = false, is_receiver = false }
end

local function compute_port_kinetic_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0 end

    if node.is_muzzle then
        return flow_engine.get_node_kinetic_emitter(node)
    end

    if not node.is_kinetic then return 0 end

    local surface = game.surfaces[node.surface_name]
    if surface and surface.valid then
        local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
        local occ = flow_engine.check_tile_obstruction(surface, node.pos.x, node.pos.y, owner_entity)
        if occ.blocked then
            return 0
        end
    end

    local max_upstream = 0
    local neighbors = storage.flow_connections and storage.flow_connections[pkey]
    if neighbors then
        for n_key in pairs(neighbors) do
            local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
            if n_node and n_node.is_kinetic then
                local is_upstream = n_node.is_muzzle or (n_node.dist and node.dist and n_node.dist < node.dist)
                if is_upstream then
                    local n_level = storage.kinetic_levels and storage.kinetic_levels[n_key] or 0
                    if n_level > max_upstream then
                        max_upstream = n_level
                    end
                end
            end
        end
    end

    if max_upstream > 1 then
        return max_upstream - 1
    else
        return 0
    end
end

local function compute_port_counter_level(pkey)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if not node then return 0, nil end

    local unit_number = node.unit_number

    if storage.active_walls and storage.active_walls[unit_number] then
        local locked_group = storage.wall_locked_group and storage.wall_locked_group[unit_number]
        if locked_group and node.group ~= locked_group then
            return 0, nil
        end
    end

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

    if node.emitter and node.emitter ~= 0 then
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

local function discover_adjacent_standard_entity(node)
    if not (node and node.pos and node.surface_name) then return end
    local surface = game.surfaces[node.surface_name]
    if not (surface and surface.valid) then return end

    local dx, dy = 0, 0
    if node.dir then
        dx = node.dir.x or 0
        dy = node.dir.y or 0
    else
        local off_x = node.offset and node.offset.x or 0
        local off_y = node.offset and node.offset.y or 0
        dx = (off_x > 0.05 and 1) or (off_x < -0.05 and -1) or 0
        dy = (off_y > 0.05 and 1) or (off_y < -0.05 and -1) or 0
    end

    if dx == 0 and dy == 0 then return end

    local target_pos = { x = node.pos.x + dx * 0.5, y = node.pos.y + dy * 0.5 }
    local candidates = surface.find_entities_filtered{
        position = target_pos,
        name = {"stone-wall", "gate"}
    }

    local cand = candidates[1]
    if cand and cand.valid and cand.unit_number then
        if not (storage.flow_unit_ports and storage.flow_unit_ports[cand.unit_number]) then
            local tech = cand.force and cand.force.technologies and cand.force.technologies["pneumatic-fence-gate-interoperability"]
            if not tech or tech.researched then
                flow_engine.connect_entity(cand)
            else
                storage.soft_interop_registry = storage.soft_interop_registry or {}
                storage.soft_interop_registry[cand.unit_number] = cand
                if script.register_on_object_destroyed then
                    local reg_id = script.register_on_object_destroyed(cand)
                    storage.object_destruction_map = storage.object_destruction_map or {}
                    storage.object_destruction_map[reg_id] = { type = "entity", unit_number = cand.unit_number }
                end
            end
        end
    end
end

function flow_engine.handle_interop_research_finished(force)
    if not storage.soft_interop_registry then return end
    storage.interop_activation_queue = storage.interop_activation_queue or {}

    for unit_number, entity in pairs(storage.soft_interop_registry) do
        if entity and entity.valid then
            if not force or entity.force == force then
                storage.interop_activation_queue[unit_number] = entity
                storage.soft_interop_registry[unit_number] = nil
            end
        else
            storage.soft_interop_registry[unit_number] = nil
        end
    end
end

function flow_engine.handle_interop_research_reversed(force)
    if storage.interop_activation_queue then
        storage.soft_interop_registry = storage.soft_interop_registry or {}
        for unit_number, entity in pairs(storage.interop_activation_queue) do
            if entity and entity.valid then
                if not force or entity.force == force then
                    storage.soft_interop_registry[unit_number] = entity
                    storage.interop_activation_queue[unit_number] = nil
                end
            else
                storage.interop_activation_queue[unit_number] = nil
            end
        end
    end

    local active_walls = storage.active_walls or {}
    local active_gates = storage.active_gates or {}

    local function is_interop_unit(unit_number)
        return (active_walls[unit_number] ~= nil) or (active_gates[unit_number] ~= nil)
    end

    local function sever_boundary_interfaces(registry)
        for unit_number, entity in pairs(registry) do
            if entity and entity.valid and (not force or entity.force == force) then
                local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
                if u_ports then
                    for _, wall_pkey in pairs(u_ports) do
                        local neighbors = storage.flow_connections and storage.flow_connections[wall_pkey]
                        if neighbors then
                            local to_sever = {}
                            for n_key in pairs(neighbors) do
                                local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                                if n_node and not is_interop_unit(n_node.unit_number) then
                                    to_sever[#to_sever + 1] = n_key
                                end
                            end

                            for i = 1, #to_sever do
                                local reg_pkey = to_sever[i]

                                if storage.flow_connections[wall_pkey] then
                                    storage.flow_connections[wall_pkey][reg_pkey] = nil
                                    if next(storage.flow_connections[wall_pkey]) == nil then
                                        storage.flow_connections[wall_pkey] = nil
                                    end
                                end

                                if storage.flow_connections[reg_pkey] then
                                    storage.flow_connections[reg_pkey][wall_pkey] = nil
                                    if next(storage.flow_connections[reg_pkey]) == nil then
                                        storage.flow_connections[reg_pkey] = nil
                                    end
                                end

                                destroy_edge_render(make_edge_key(wall_pkey, reg_pkey))
                                flow_engine.enqueue_port(reg_pkey)
                                flow_engine.enqueue_port(wall_pkey)
                                wake_port_parked(reg_pkey)
                                wake_port_parked(wall_pkey)
                            end
                        end
                    end
                end
            end
        end
    end

    sever_boundary_interfaces(active_walls)
    sever_boundary_interfaces(active_gates)
end

function flow_engine.step(tick)
    if storage.active_gates then
        for unit_number, gate in pairs(storage.active_gates) do
            if gate and gate.valid then
                local is_open = not (gate.is_closed and gate.is_closed())
                local last_open = storage.gate_open_states and storage.gate_open_states[unit_number]
                local is_term = is_open and is_gate_terminator(unit_number)
                local last_term = storage.gate_cutoff_states and storage.gate_cutoff_states[unit_number]

                if is_open ~= last_open or is_term ~= last_term then
                    storage.gate_open_states = storage.gate_open_states or {}
                    storage.gate_open_states[unit_number] = is_open
                    storage.gate_cutoff_states = storage.gate_cutoff_states or {}
                    storage.gate_cutoff_states[unit_number] = is_term

                    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
                    if unit_ports then
                        if not is_open or not is_term then
                            for _, p in pairs(unit_ports) do
                                local p_node = storage.flow_nodes and storage.flow_nodes[p]
                                if p_node then
                                    p_node.capsule_transmit = true
                                    p_node.pressure_transmit = true
                                    p_node.sense_transmit = true
                                end
                            end
                        else
                            for _, p in pairs(unit_ports) do
                                local p_node = storage.flow_nodes and storage.flow_nodes[p]
                                if p_node then
                                    p_node.capsule_transmit = false
                                    p_node.pressure_transmit = false
                                end
                            end
                        end
                    end

                    flow_engine.enqueue_unit_ports(unit_number)

                    if not is_open or not is_term then
                        if unit_ports then
                            for _, p in pairs(unit_ports) do
                                wake_port_parked(p)
                                local neighbors = storage.flow_connections and storage.flow_connections[p]
                                if neighbors then
                                    for n_key in pairs(neighbors) do
                                        wake_port_parked(n_key)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if storage.interop_activation_queue and next(storage.interop_activation_queue) ~= nil then
        local batch = {}
        local count = 0
        for unit_number, entity in pairs(storage.interop_activation_queue) do
            count = count + 1
            batch[count] = { unit_number = unit_number, entity = entity }
            storage.interop_activation_queue[unit_number] = nil
            if count >= INTEROP_BATCH_SIZE then
                break
            end
        end

        for i = 1, count do
            local item = batch[i]
            local entity = item.entity
            if entity and entity.valid then
                if flow_engine.is_touching_pneumatic_grid(entity) then
                    flow_engine.connect_entity(entity)
                    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[item.unit_number]
                    if unit_ports then
                        for _, p in pairs(unit_ports) do
                            local neighbors = storage.flow_connections and storage.flow_connections[p]
                            if neighbors then
                                for n_key in pairs(neighbors) do
                                    wake_port_parked(n_key)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

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

        -- 1. Pressure Flow Wavefront
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

        -- 2. Capsule Counter Range Wavefront
        local target_range, target_owner = compute_port_counter_level(pkey)
        local range_changed = set_port_counter_ownership(pkey, target_range, target_owner)

        if range_changed then
            local node = storage.flow_nodes and storage.flow_nodes[pkey]
            if node then
                update_counter_pos_render(node.pos_key)
            end
        end

        -- 3. Kinetic Flow Wavefront (Unified queue step for 1-tile/tick advance & recession)
        local target_kinetic = compute_port_kinetic_level(pkey)
        local current_kinetic = storage.kinetic_levels and storage.kinetic_levels[pkey] or 0
        local kinetic_changed = (target_kinetic ~= current_kinetic)

        if kinetic_changed then
            local node = storage.flow_nodes and storage.flow_nodes[pkey]

            if target_kinetic > 0 then
                storage.kinetic_levels[pkey] = target_kinetic

                if node then
                    local surface = game.surfaces[node.surface_name]

                    -- Terminal endpoint check at maximum reach
                    if target_kinetic == 1 and not node.is_muzzle then
                        node.is_endpoint = true
                        node.is_prominent_kinetic = true
                        node.is_beam_node = true
                        node.capsule_transmit = true
                        node.hit_receiver = nil
                    end

                    update_kinetic_pos_render(
                        node.pos_key,
                        node.pos,
                        surface,
                        node.is_prominent_kinetic,
                        node.is_endpoint,
                        node.hit_receiver ~= nil,
                        node.q_level
                    )

                    -- Advance step: Discover and connect next tile in direction
                    if target_kinetic > 1 and node.dir and not node.is_endpoint then
                        local has_downstream = false
                        local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                        if neighbors then
                            for n_key in pairs(neighbors) do
                                local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                                if n_node and n_node.is_kinetic and n_node.dist and node.dist and n_node.dist > node.dist then
                                    has_downstream = true
                                    break
                                end
                            end
                        end

                        if not has_downstream and surface and surface.valid then
                            local nx = node.pos.x + node.dir.x
                            local ny = node.pos.y + node.dir.y
                            local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
                            local occ = flow_engine.check_tile_obstruction(surface, nx, ny, owner_entity)

                            local next_dist = (node.dist or 0) + 1
                            local next_pkey = make_beam_port_key(node.beam_owner or node.unit_number, node.dir.x, node.dir.y, next_dist)
                            local next_pos_key = make_pos_key(node.surface_name, nx, ny)
                            local is_prom = (next_dist % HOP_DISTANCE == 0) or occ.blocked

                            if occ.blocked then
                                node.is_endpoint = true
                                node.is_prominent_kinetic = true
                                node.is_beam_node = true
                                node.capsule_transmit = true
                                node.hit_receiver = occ.is_receiver and occ.receiver and occ.receiver.unit_number or nil
                                update_kinetic_pos_render(
                                    node.pos_key,
                                    node.pos,
                                    surface,
                                    node.is_prominent_kinetic,
                                    true,
                                    occ.is_receiver,
                                    node.q_level
                                )
                                wake_port_parked(pkey)
                            else
                                storage.flow_nodes[next_pkey] = {
                                    unit_number = node.beam_owner or node.unit_number,
                                    beam_owner = node.beam_owner or node.unit_number,
                                    port_index = 100 + next_dist,
                                    pos_key = next_pos_key,
                                    pos = {x = nx, y = ny},
                                    dir = {x = node.dir.x, y = node.dir.y},
                                    surface_name = node.surface_name,
                                    dist = next_dist,
                                    is_kinetic = true,
                                    is_beam_node = is_prom,
                                    is_prominent_kinetic = is_prom,
                                    capsule_transmit = is_prom,
                                    pressure_transmit = false,
                                    sense_transmit = false,
                                    kinetic_transmit = true,
                                    cross_transit = false,
                                    q_level = node.q_level,
                                    is_endpoint = false
                                }

                                storage.flow_grid[next_pos_key] = storage.flow_grid[next_pos_key] or {}
                                storage.flow_grid[next_pos_key][next_pkey] = true

                                storage.flow_connections[pkey] = storage.flow_connections[pkey] or {}
                                storage.flow_connections[next_pkey] = storage.flow_connections[next_pkey] or {}
                                storage.flow_connections[pkey][next_pkey] = true
                                storage.flow_connections[next_pkey][pkey] = true

                                flow_engine.enqueue_port(next_pkey)
                                wake_port_parked(pkey)
                                wake_port_parked(next_pkey)
                            end
                        end
                    end
                end
            else
                -- Recession step: Cleanly recedes 1 tile per tick
                storage.kinetic_levels[pkey] = nil

                if node then
                    destroy_kinetic_pos_render(node.pos_key)

                    if node.is_kinetic and not node.is_muzzle then
                        if storage.flow_grid and storage.flow_grid[node.pos_key] then
                            storage.flow_grid[node.pos_key][pkey] = nil
                            if next(storage.flow_grid[node.pos_key]) == nil then
                                storage.flow_grid[node.pos_key] = nil
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
                                flow_engine.enqueue_port(n_key)
                                wake_port_parked(n_key)
                            end
                            storage.flow_connections[pkey] = nil
                        end

                        storage.flow_nodes[pkey] = nil
                        wake_port_parked(pkey)
                    end
                end
            end
        end

        local node = storage.flow_nodes and storage.flow_nodes[pkey]
        if node and storage.active_walls and storage.active_walls[node.unit_number] then
            local u_num = node.unit_number
            local cur_locked = storage.wall_locked_group and storage.wall_locked_group[u_num]

            if not cur_locked then
                if target_flow ~= 0 or (target_range and target_range > 0) then
                    storage.wall_locked_group = storage.wall_locked_group or {}
                    storage.wall_locked_group[u_num] = node.group

                    local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u_num]
                    if u_ports then
                        for _, p in pairs(u_ports) do
                            local p_node = storage.flow_nodes and storage.flow_nodes[p]
                            if p_node then
                                local matches = (p_node.group == node.group)
                                p_node.capsule_transmit = matches
                                p_node.pressure_transmit = matches
                                p_node.sense_transmit = matches
                                if not matches then
                                    flow_engine.enqueue_port(p)
                                end
                            end
                        end
                    end
                end
            else
                local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u_num]
                if u_ports then
                    local active_has_pressure = false
                    for _, p in pairs(u_ports) do
                        local p_node = storage.flow_nodes and storage.flow_nodes[p]
                        if p_node and p_node.group == cur_locked then
                            local f = (p == pkey) and target_flow or (storage.flow_levels and storage.flow_levels[p] or 0)
                            local s = (p == pkey) and target_range or (storage.counter_levels and storage.counter_levels[p] or 0)
                            if f ~= 0 or (s and s > 0) then
                                active_has_pressure = true
                                break
                            end
                        end
                    end

                    if not active_has_pressure then
                        storage.wall_locked_group[u_num] = nil

                        for _, p in pairs(u_ports) do
                            local p_node = storage.flow_nodes and storage.flow_nodes[p]
                            if p_node then
                                p_node.capsule_transmit = true
                                p_node.pressure_transmit = true
                                p_node.sense_transmit = true
                            end
                            flow_engine.enqueue_port(p)
                            wake_port_parked(p)
                            local neighbors = storage.flow_connections and storage.flow_connections[p]
                            if neighbors then
                                for n_key in pairs(neighbors) do
                                    flow_engine.enqueue_port(n_key)
                                    wake_port_parked(n_key)
                                end
                            end
                        end
                    end
                end
            end
        end

        if node then
            local u_num = node.unit_number
            local is_wall_entity = storage.active_walls and storage.active_walls[u_num]
            local is_gate_entity = storage.active_gates and storage.active_gates[u_num]

            if is_wall_entity or is_gate_entity then
                local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[u_num]
                if u_ports then
                    local has_flow = false
                    for _, check_p in pairs(u_ports) do
                        local f = (check_p == pkey) and target_flow or (storage.flow_levels and storage.flow_levels[check_p] or 0)
                        local s = (check_p == pkey) and target_range or (storage.counter_levels and storage.counter_levels[check_p] or 0)
                        if f ~= 0 or (s and s > 0) then
                            has_flow = true
                            break
                        end
                    end

                    if not has_flow then
                        local ent = is_gate_entity or is_wall_entity
                        if ent and ent.valid then
                            local tech = ent.force and ent.force.technologies and ent.force.technologies["pneumatic-fence-gate-interoperability"]
                            if tech and not tech.researched then
                                flow_engine.disconnect_entity(ent)
                                if flow_engine.is_touching_pneumatic_grid(ent) then
                                    storage.soft_interop_registry = storage.soft_interop_registry or {}
                                    storage.soft_interop_registry[u_num] = ent
                                end
                            end
                        end
                    end
                end
            end
        end

        if flow_changed or range_changed or kinetic_changed then
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
            if neighbors and next(neighbors) ~= nil then
                for n_key in pairs(neighbors) do
                    flow_engine.enqueue_port(n_key)
                    if flow_changed then
                        update_edge_render(pkey, n_key)
                    end
                end
            else
                local eff_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
                local eff_sense = storage.counter_levels and storage.counter_levels[pkey] or 0
                if eff_flow ~= 0 or eff_sense > 0 then
                    discover_adjacent_standard_entity(node)
                end
            end
        end
    end
end

local function handle_entity_reorientation(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if entity.name == "entity-ghost" then return end

    local real_name = entity.name

    if real_name == "pneumatic-projector" then
        local dev_id = projector_settings.get_device_id(entity)
        if dev_id then
            projector_settings.set_muzzle_direction(dev_id, entity.direction)
        end

        if storage.flow_unit_ports and storage.flow_unit_ports[entity.unit_number] then
            flow_engine.disconnect_entity(entity)
        end

        flow_engine.connect_entity(entity)
    elseif registered_entities[real_name] then
        if storage.flow_unit_ports and storage.flow_unit_ports[entity.unit_number] then
            flow_engine.disconnect_entity(entity)
        end
        flow_engine.connect_entity(entity)
    elseif is_standard_entity(real_name) then
        local was_connected = (storage.flow_unit_ports and storage.flow_unit_ports[entity.unit_number] ~= nil)
        if was_connected then
            flow_engine.disconnect_entity(entity)
        end

        local tech = entity.force and entity.force.technologies and entity.force.technologies["pneumatic-fence-gate-interoperability"]
        local is_researched = (not tech) or tech.researched

        if is_researched then
            if flow_engine.is_touching_pneumatic_grid(entity) then
                flow_engine.connect_entity(entity)
            end
        else
            if flow_engine.is_touching_active_flow(entity) then
                storage.soft_interop_registry = storage.soft_interop_registry or {}
                storage.soft_interop_registry[entity.unit_number] = entity
                if script.register_on_object_destroyed then
                    local reg_id = script.register_on_object_destroyed(entity)
                    storage.object_destruction_map = storage.object_destruction_map or {}
                    storage.object_destruction_map[reg_id] = { type = "entity", unit_number = entity.unit_number }
                end
            elseif storage.soft_interop_registry then
                storage.soft_interop_registry[entity.unit_number] = nil
            end
        end
    end
end

function flow_engine.connect_entity(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if entity.name == "entity-ghost" then return end
    local real_name = entity.name
    if not (registered_entities[real_name] or is_standard_entity(real_name)) then return end

    local unit_number = entity.unit_number

    if storage.flow_unit_ports and storage.flow_unit_ports[unit_number] and next(storage.flow_unit_ports[unit_number]) ~= nil then
        flow_engine.disconnect_entity(entity)
    end

    if storage.soft_interop_registry then
        storage.soft_interop_registry[unit_number] = nil
    end
    if storage.interop_activation_queue then
        storage.interop_activation_queue[unit_number] = nil
    end

    if script.register_on_object_destroyed then
        local reg_id = script.register_on_object_destroyed(entity)
        storage.object_destruction_map = storage.object_destruction_map or {}
        storage.object_destruction_map[reg_id] = { type = "entity", unit_number = unit_number }
    end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local surface_name = entity.surface.name
    local ex, ey = entity.position.x, entity.position.y

    if real_name == "stone-wall" then
        storage.active_walls = storage.active_walls or {}
        storage.active_walls[unit_number] = entity
    elseif entity.name == "gate" then
        storage.active_gates = storage.active_gates or {}
        storage.active_gates[unit_number] = entity
    elseif entity.name == "pneumatic-capsule-counter" then
        storage.active_counters = storage.active_counters or {}
        storage.active_counters[unit_number] = entity
        storage.counter_power_states = storage.counter_power_states or {}
        storage.counter_power_states[unit_number] = (entity.energy > 0)
    elseif real_name == "pneumatic-projector" then
        storage.active_projectors = storage.active_projectors or {}
        storage.active_projectors[unit_number] = entity
    end

    storage.flow_unit_ports[unit_number] = storage.flow_unit_ports[unit_number] or {}

    local q_level = (entity.quality and entity.quality.level) or 0

    for port_index, port in ipairs(ports) do
        local px, py = ex + port.offset.x, ey + port.offset.y
        local pkey = make_port_key(unit_number, port_index)
        local pos_key = make_pos_key(surface_name, px, py)

        storage.flow_unit_ports[unit_number][port_index] = pkey

        local is_muzzle_port = (port.kinetic_transmit == true or port.is_muzzle == true)
        local eff_emitter = (port.flow and port.flow ~= 0) and port.flow or nil

        storage.flow_nodes[pkey] = {
            unit_number = unit_number,
            beam_owner = unit_number,
            port_index = port_index,
            pos_key = pos_key,
            pos = {x = px, y = py},
            offset = {x = port.offset.x, y = port.offset.y},
            dir = port.dir and {x = port.dir.x, y = port.dir.y} or nil,
            surface_name = surface_name,
            emitter = eff_emitter,
            sense = port.sense,
            group = port.group,
            capsule_transmit = (port.capsule_transmit == true),
            pressure_transmit = (port.pressure_transmit == true),
            sense_transmit = (port.sense_transmit == true),
            kinetic_transmit = is_muzzle_port,
            is_muzzle = is_muzzle_port,
            is_kinetic = is_muzzle_port,
            dist = is_muzzle_port and 0 or nil,
            q_level = q_level,
            cross_transit = (port.cross_transit == true)
        }

        storage.flow_grid[pos_key] = storage.flow_grid[pos_key] or {}

        for existing_pkey in pairs(storage.flow_grid[pos_key]) do
            local existing_node = storage.flow_nodes[existing_pkey]
            if existing_node and existing_node.unit_number ~= unit_number then
                local compatible = not (is_muzzle_port or existing_node.kinetic_transmit)
                if compatible then
                    storage.flow_connections[pkey] = storage.flow_connections[pkey] or {}
                    storage.flow_connections[existing_pkey] = storage.flow_connections[existing_pkey] or {}

                    storage.flow_connections[pkey][existing_pkey] = true
                    storage.flow_connections[existing_pkey][pkey] = true

                    flow_engine.enqueue_port(existing_pkey)
                    wake_port_parked(existing_pkey)
                    wake_port_parked(pkey)
                end
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

    if storage.active_projectors then storage.active_projectors[unit_number] = nil end
    if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end

    if storage.soft_interop_registry then
        storage.soft_interop_registry[unit_number] = nil
    end
    if storage.interop_activation_queue then
        storage.interop_activation_queue[unit_number] = nil
    end

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
                    wake_port_parked(n_key)
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
            if storage.kinetic_levels then storage.kinetic_levels[pkey] = nil end
            if storage.flow_nodes then storage.flow_nodes[pkey] = nil end

            update_pos_render(pos_key)
            update_counter_pos_render(pos_key)
            destroy_kinetic_pos_render(pos_key)
        end

        flow_engine.enqueue_port(pkey)
        wake_port_parked(pkey)
    end

    if storage.flow_unit_ports then
        storage.flow_unit_ports[unit_number] = nil
    end

    if storage.active_walls then storage.active_walls[unit_number] = nil end
    if storage.active_gates then storage.active_gates[unit_number] = nil end
    if storage.gate_open_states then storage.gate_open_states[unit_number] = nil end
    if storage.gate_cutoff_states then storage.gate_cutoff_states[unit_number] = nil end
    if storage.wall_locked_group then storage.wall_locked_group[unit_number] = nil end
    if storage.active_counters then storage.active_counters[unit_number] = nil end
    if storage.counter_power_states then storage.counter_power_states[unit_number] = nil end
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

    if target_key then
        wake_port_parked(target_key)
    end
end

function flow_engine.handle_object_destroyed(unit_number)
    if not unit_number then return end

    -- Immediate deconstruction lifecycle purge for destroyed projectors (leaves zero lingering nodes or renders)
    if storage.active_projectors and storage.active_projectors[unit_number] then
        for pkey, node in pairs(storage.flow_nodes or {}) do
            if node and node.beam_owner == unit_number and not node.is_muzzle then
                destroy_kinetic_pos_render(node.pos_key)
                if storage.flow_grid and storage.flow_grid[node.pos_key] then
                    storage.flow_grid[node.pos_key][pkey] = nil
                    if next(storage.flow_grid[node.pos_key]) == nil then
                        storage.flow_grid[node.pos_key] = nil
                    end
                end
                if storage.flow_connections then storage.flow_connections[pkey] = nil end
                if storage.kinetic_levels then storage.kinetic_levels[pkey] = nil end
                storage.flow_nodes[pkey] = nil
                wake_port_parked(pkey)
            end
        end
    end

    if storage.soft_interop_registry then
        storage.soft_interop_registry[unit_number] = nil
    end
    if storage.interop_activation_queue then
        storage.interop_activation_queue[unit_number] = nil
    end

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
    if storage.active_walls then storage.active_walls[unit_number] = nil end
    if storage.active_gates then storage.active_gates[unit_number] = nil end
    if storage.gate_open_states then storage.gate_open_states[unit_number] = nil end
    if storage.gate_cutoff_states then storage.gate_cutoff_states[unit_number] = nil end
    if storage.wall_locked_group then storage.wall_locked_group[unit_number] = nil end
    if storage.active_projectors then storage.active_projectors[unit_number] = nil end
    if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end
end

function flow_engine.register_events()
    events.on_event(defines.events.on_tick, function(event)
        flow_engine.step(event.tick)
    end)

    events.on_event(defines.events.on_research_finished, function(event)
        local research = event.research
        if research and research.valid and research.name == "pneumatic-fence-gate-interoperability" then
            flow_engine.handle_interop_research_finished(research.force)
        end
    end)

    events.on_event(defines.events.on_research_reversed, function(event)
        local research = event.research
        if research and research.valid and research.name == "pneumatic-fence-gate-interoperability" then
            flow_engine.handle_interop_research_reversed(research.force)
        end
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
            if not (entity and entity.valid) then return end
            if entity.name == "entity-ghost" then return end

            local real_name = entity.name

            if registered_entities[real_name] then
                flow_engine.connect_entity(entity)
            elseif is_standard_entity(real_name) then
                local tech = entity.force and entity.force.technologies and entity.force.technologies["pneumatic-fence-gate-interoperability"]
                local is_researched = (not tech) or tech.researched

                if is_researched then
                    if flow_engine.is_touching_pneumatic_grid(entity) then
                        flow_engine.connect_entity(entity)
                    end
                else
                    if flow_engine.is_touching_active_flow(entity) then
                        storage.soft_interop_registry = storage.soft_interop_registry or {}
                        storage.soft_interop_registry[entity.unit_number] = entity
                        if script.register_on_object_destroyed then
                            local reg_id = script.register_on_object_destroyed(entity)
                            storage.object_destruction_map = storage.object_destruction_map or {}
                            storage.object_destruction_map[reg_id] = { type = "entity", unit_number = entity.unit_number }
                        end
                    end
                end
            else
                -- General entity placement: check if new structure occludes active kinetic beam nodes
                if storage.flow_grid and entity.bounding_box then
                    local bb = entity.bounding_box
                    local min_x = math.floor(bb.left_top.x + 0.5)
                    local max_x = math.floor(bb.right_bottom.x + 0.5)
                    local min_y = math.floor(bb.left_top.y + 0.5)
                    local max_y = math.floor(bb.right_bottom.y + 0.5)
                    local surf_name = entity.surface.name

                    for gx = min_x, max_x do
                        for gy = min_y, max_y do
                            local pkey_check = make_pos_key(surf_name, gx, gy)
                            local grid_ports = storage.flow_grid[pkey_check]
                            if grid_ports then
                                for pkey in pairs(grid_ports) do
                                    local node = storage.flow_nodes and storage.flow_nodes[pkey]
                                    if node and node.is_kinetic then
                                        flow_engine.enqueue_port(pkey)
                                        wake_port_parked(pkey)
                                    end
                                end
                            end
                        end
                    end
                end
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

                -- If an obstacle blocking a beam was removed, wake and re-evaluate intersecting beam endpoints
                if storage.flow_grid and entity.bounding_box then
                    local bb = entity.bounding_box
                    local min_x = math.floor(bb.left_top.x + 0.5)
                    local max_x = math.floor(bb.right_bottom.x + 0.5)
                    local min_y = math.floor(bb.left_top.y + 0.5)
                    local max_y = math.floor(bb.right_bottom.y + 0.5)
                    local surf_name = entity.surface.name

                    for gx = min_x, max_x do
                        for gy = min_y, max_y do
                            local pkey_check = make_pos_key(surf_name, gx, gy)
                            local grid_ports = storage.flow_grid[pkey_check]
                            if grid_ports then
                                for pkey in pairs(grid_ports) do
                                    local node = storage.flow_nodes and storage.flow_nodes[pkey]
                                    if node and node.is_kinetic then
                                        node.is_endpoint = false
                                        node.hit_receiver = nil
                                        flow_engine.enqueue_port(pkey)
                                        wake_port_parked(pkey)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    if defines.events.on_marked_for_deconstruction then
        events.on_event(defines.events.on_marked_for_deconstruction, function(event)
            local entity = event.entity
            if entity and entity.valid and entity.name == "pneumatic-projector" then
                if entity.unit_number then
                    flow_engine.enqueue_unit_ports(entity.unit_number)
                end
            end
        end)
    end

    if defines.events.on_cancelled_deconstruction then
        events.on_event(defines.events.on_cancelled_deconstruction, function(event)
            local entity = event.entity
            if entity and entity.valid and entity.name == "pneumatic-projector" then
                if entity.unit_number then
                    flow_engine.enqueue_unit_ports(entity.unit_number)
                end
            end
        end)
    end

    events.on_event(defines.events.on_player_rotated_entity, function(event)
        handle_entity_reorientation(event.entity)
    end)

    events.on_event(defines.events.on_player_flipped_entity, function(event)
        handle_entity_reorientation(event.entity)
    end)
end

return flow_engine