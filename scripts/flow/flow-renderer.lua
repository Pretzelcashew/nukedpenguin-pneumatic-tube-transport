local flow_renderer = {}

local MAX_FLOW = 10

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
local PROJECTOR_INTAKE_COLOR = {r = 0.20, g = 0.85, b = 1.00, a = 0.90}
local PROJECTOR_MUZZLE_COLOR = {r = 0.90, g = 0.20, b = 0.70, a = 0.90}

local function check_debug(flag, p_idx)
    if p_idx then
        return is_debug_active and is_debug_active(flag, p_idx)
    else
        return is_debug_active and is_debug_active(flag)
    end
end

local function get_owner_color(unit_number)
    if not unit_number then
        return {r = 0.30, g = 0.85, b = 0.70, a = 0.8}
    end
    local idx = ((unit_number - 1) % #OWNER_PALETTE) + 1
    local col = OWNER_PALETTE[idx]
    return {r = col.r, g = col.g, b = col.b, a = 0.8}
end

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

local function make_edge_key(key_a, key_b)
    return key_a < key_b and (key_a .. "|" .. key_b) or (key_b .. "|" .. key_a)
end

flow_renderer.make_edge_key = make_edge_key

function flow_renderer.destroy_pos_renders(pos_key, player_index)
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

function flow_renderer.destroy_counter_renders(pos_key, player_index)
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

function flow_renderer.destroy_edge_render(edge_key, player_index)
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

function flow_renderer.destroy_kinetic_pos_render(pkey, player_index)
    if not (pkey and storage.kinetic_renders) then return end
    if player_index then
        local p_renders = storage.kinetic_renders[player_index]
        if p_renders and p_renders[pkey] then
            local entry = p_renders[pkey]
            if entry.dot and entry.dot.valid then entry.dot.destroy() end
            if entry.ring and entry.ring.valid then entry.ring.destroy() end
            p_renders[pkey] = nil
        end
    else
        for _, p_renders in pairs(storage.kinetic_renders) do
            if type(p_renders) == "table" and p_renders[pkey] then
                local entry = p_renders[pkey]
                if entry.dot and entry.dot.valid then entry.dot.destroy() end
                if entry.ring and entry.ring.valid then entry.ring.destroy() end
                p_renders[pkey] = nil
            end
        end
    end
end

function flow_renderer.update_kinetic_pos_render(pkey, player_index)
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    local level = storage.kinetic_levels and storage.kinetic_levels[pkey] or 0

    if not node or level == 0 or not node.is_kinetic then
        flow_renderer.destroy_kinetic_pos_render(pkey, player_index)
        return
    end

    local surface = game.surfaces[node.surface_name]
    if not (surface and surface.valid and node.pos) then
        flow_renderer.destroy_kinetic_pos_render(pkey, player_index)
        return
    end

    local q_level = node.q_level or 0
    local palette = QUALITY_BEAM_PALETTE[q_level] or QUALITY_BEAM_PALETTE[0]
    local is_prominent = (node.is_prominent_kinetic == true)
    local is_endpoint = (node.is_endpoint == true)
    local is_receiver = (node.hit_receiver ~= nil)
    local pos = node.pos

    local function draw_for_player(player, p_idx)
        if check_debug("new_flow", p_idx) then
            storage.kinetic_renders[p_idx] = storage.kinetic_renders[p_idx] or {}
            local p_renders = storage.kinetic_renders[p_idx]

            local current = p_renders[pkey]
            if current and current.dot and current.dot.valid
               and ((not is_endpoint and not current.ring) or (is_endpoint and current.ring and current.ring.valid))
               and (current.is_prominent == is_prominent)
               and (current.is_receiver == is_receiver)
               and (current.q_level == q_level) then
                return
            end

            flow_renderer.destroy_kinetic_pos_render(pkey, p_idx)

            local dot_obj = nil
            local ring_obj = nil

            if is_prominent then
                dot_obj = rendering.draw_circle{
                    color = palette.core,
                    radius = 0.16,
                    filled = true,
                    target = pos,
                    surface = surface,
                    only_in_alt_mode = true,
                    players = { player }
                }
            else
                dot_obj = rendering.draw_circle{
                    color = MINOR_DOT_COLOR,
                    radius = 0.08,
                    filled = true,
                    target = pos,
                    surface = surface,
                    only_in_alt_mode = true,
                    players = { player }
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
                    only_in_alt_mode = true,
                    players = { player }
                }
            end

            p_renders[pkey] = {
                dot = dot_obj,
                ring = ring_obj,
                is_prominent = is_prominent,
                is_receiver = is_receiver,
                q_level = q_level
            }
        else
            flow_renderer.destroy_kinetic_pos_render(pkey, p_idx)
        end
    end

    if player_index then
        local player = game.get_player(player_index)
        if player and player.valid then
            draw_for_player(player, player_index)
        end
    else
        if not check_debug("new_flow") then
            flow_renderer.destroy_kinetic_pos_render(pkey)
            return
        end

        for _, player in pairs(game.players) do
            draw_for_player(player, player.index)
        end
    end
end

function flow_renderer.get_dominant_port_at_pos(pos_key)
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

function flow_renderer.get_dominant_counter_at_pos(pos_key)
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

function flow_renderer.update_counter_pos_render(pos_key)
    if not check_debug("counter_range") then
        flow_renderer.destroy_counter_renders(pos_key)
        return
    end

    local node, level, owner = flow_renderer.get_dominant_counter_at_pos(pos_key)
    if not node or level == 0 or owner == nil then
        flow_renderer.destroy_counter_renders(pos_key)
        return
    end

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if check_debug("counter_range", p_idx) then
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
                flow_renderer.destroy_counter_renders(pos_key, p_idx)
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
            flow_renderer.destroy_counter_renders(pos_key, p_idx)
        end
    end
end

function flow_renderer.update_pos_render(pos_key)
    if not check_debug("new_flow") then
        flow_renderer.destroy_pos_renders(pos_key)
        return
    end

    local node, level = flow_renderer.get_dominant_port_at_pos(pos_key)
    if not node then
        flow_renderer.destroy_pos_renders(pos_key)
        return
    end

    local is_projector_port = (level == 0) and (storage.active_projectors and storage.active_projectors[node.unit_number] ~= nil and (node.port_index or 0) <= 4)
    local is_intake = is_projector_port and (not node.is_muzzle)
    local muzzle_pkey = is_projector_port and node.is_muzzle and make_port_key(node.unit_number, node.port_index) or nil
    local is_muzzle_idle = muzzle_pkey and ((storage.kinetic_levels and storage.kinetic_levels[muzzle_pkey] or 0) == 0)

    if level == 0 and not is_intake and not is_muzzle_idle then
        flow_renderer.destroy_pos_renders(pos_key)
        return
    end

    local pos = node.pos
    local surface = game.surfaces[node.surface_name]

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if check_debug("new_flow", p_idx) then
            storage.flow_renders[p_idx] = storage.flow_renders[p_idx] or {}
            local p_renders = storage.flow_renders[p_idx]
            local current = p_renders[pos_key]

            if is_intake or is_muzzle_idle then
                local dot_color = is_intake and PROJECTOR_INTAKE_COLOR or PROJECTOR_MUZZLE_COLOR
                local render_type = is_intake and "intake" or "muzzle"
                if current and current.circle and current.circle.valid and current.render_type == render_type then
                    -- Already valid dot
                else
                    flow_renderer.destroy_pos_renders(pos_key, p_idx)
                    if surface and surface.valid then
                        local c_obj = rendering.draw_circle{
                            color = dot_color,
                            radius = 0.12,
                            filled = true,
                            target = pos,
                            surface = surface,
                            only_in_alt_mode = true,
                            players = { player }
                        }
                        p_renders[pos_key] = { circle = c_obj, text = nil, is_intake = is_intake, render_type = render_type }
                    end
                end
            else
                local abs_level = math.abs(level)
                local circle_color = (level > 0)
                    and {r = 0, g = 0.4 + (abs_level / MAX_FLOW) * 0.6, b = 1, a = 0.8}
                    or  {r = 1, g = 0.3 + (abs_level / MAX_FLOW) * 0.7, b = 0, a = 0.8}

                if current and current.circle and current.circle.valid and current.text and current.text.valid and not current.is_intake then
                    current.circle.color = circle_color
                    current.text.text = tostring(level)
                else
                    flow_renderer.destroy_pos_renders(pos_key, p_idx)
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
            end
        else
            flow_renderer.destroy_pos_renders(pos_key, p_idx)
        end
    end
end

function flow_renderer.update_edge_render(key_a, key_b)
    if not check_debug("new_flow") then
        flow_renderer.destroy_edge_render(make_edge_key(key_a, key_b))
        return
    end

    local edge_key = make_edge_key(key_a, key_b)
    local level_a = storage.flow_levels and storage.flow_levels[key_a] or 0
    local level_b = storage.flow_levels and storage.flow_levels[key_b] or 0
    local node_a = storage.flow_nodes and storage.flow_nodes[key_a]
    local node_b = storage.flow_nodes and storage.flow_nodes[key_b]

    if (level_a == 0 and level_b == 0) or not node_a or not node_b then
        flow_renderer.destroy_edge_render(edge_key)
        return
    end

    if node_a.pos_key == node_b.pos_key then
        flow_renderer.destroy_edge_render(edge_key)
        return
    end

    local active_level = (level_a ~= 0) and level_a or level_b
    local line_color = (active_level > 0)
        and {r = 0, g = 0.7, b = 1, a = 0.8}
        or  {r = 1, g = 0.5, b = 0, a = 0.8}

    for _, player in pairs(game.players) do
        local p_idx = player.index
        if check_debug("new_flow", p_idx) then
            storage.flow_edge_renders[p_idx] = storage.flow_edge_renders[p_idx] or {}
            local e_renders = storage.flow_edge_renders[p_idx]
            local existing = e_renders[edge_key]

            if existing and existing.valid then
                existing.color = line_color
            else
                flow_renderer.destroy_edge_render(edge_key, p_idx)
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
            flow_renderer.destroy_edge_render(edge_key, p_idx)
        end
    end
end

function flow_renderer.clear_counter_renders(player_index)
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
            flow_renderer.clear_counter_renders(player.index)
        end
    end
end

function flow_renderer.clear_flow_renders(player_index)
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
        if storage.kinetic_renders and storage.kinetic_renders[player_index] then
            for pkey, entry in pairs(storage.kinetic_renders[player_index]) do
                if entry.dot and entry.dot.valid then entry.dot.destroy() end
                if entry.ring and entry.ring.valid then entry.ring.destroy() end
            end
            storage.kinetic_renders[player_index] = {}
        end
    else
        for _, player in pairs(game.players) do
            flow_renderer.clear_flow_renders(player.index)
        end
        if storage.kinetic_renders then
            for k, v in pairs(storage.kinetic_renders) do
                if type(k) == "string" and type(v) == "table" then
                    if v.dot and v.dot.valid then v.dot.destroy() end
                    if v.ring and v.ring.valid then v.ring.destroy() end
                    storage.kinetic_renders[k] = nil
                end
            end
        end
    end
end

function flow_renderer.clear_all_renders(player_index)
    flow_renderer.clear_flow_renders(player_index)
    flow_renderer.clear_counter_renders(player_index)
end

function flow_renderer.draw_all_counters(player_index)
    local pos_keys = {}
    local count = 0
    for pos_key in pairs(storage.flow_grid or {}) do
        count = count + 1
        pos_keys[count] = pos_key
    end

    table.sort(pos_keys)

    for i = 1, count do
        flow_renderer.update_counter_pos_render(pos_keys[i])
    end
end

function flow_renderer.draw_flow(player_index)
    local pos_keys = {}
    local count = 0
    for pos_key in pairs(storage.flow_grid or {}) do
        count = count + 1
        pos_keys[count] = pos_key
    end

    table.sort(pos_keys)

    for i = 1, count do
        local pos_key = pos_keys[i]
        flow_renderer.update_pos_render(pos_key)
        local grid_ports = storage.flow_grid[pos_key]
        if grid_ports then
            for pkey in pairs(grid_ports) do
                local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        flow_renderer.update_edge_render(pkey, n_key)
                    end
                end
            end
        end
    end

    if storage.kinetic_levels then
        for pkey in pairs(storage.kinetic_levels) do
            flow_renderer.update_kinetic_pos_render(pkey, player_index)
        end
    end
end

function flow_renderer.draw_all(player_index)
    flow_renderer.draw_flow(player_index)
    flow_renderer.draw_all_counters(player_index)
end

return flow_renderer
