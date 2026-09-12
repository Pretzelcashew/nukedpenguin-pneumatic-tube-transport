local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local flow_renderer = require("scripts.flow.flow-renderer")
local flow_gate_interop = require("scripts.flow.flow-gate-interop")
local pump_settings = require("scripts.pumps.pump-settings")
local diverter_settings = require("scripts.diverters.diverter-settings")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local projector_settings = require("scripts.projectors.projector-settings")

local flow_engine = {}

local BATCH_SIZE = 50
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

local IGNORABLE_TYPES = {
    ["resource"] = true,
    ["entity-ghost"] = true,
    ["tile-ghost"] = true,
    ["character"] = true,
    ["car"] = true,
    ["spider-vehicle"] = true,
    ["unit"] = true,
    ["fish"] = true,
    ["item-entity"] = true,
    ["flying-robot"] = true,
    ["logistic-robot"] = true,
    ["construction-robot"] = true,
    ["combat-robot"] = true,
    ["projectile"] = true,
    ["smoke"] = true,
    ["smoke-with-trigger"] = true,
    ["sticker"] = true,
    ["highlight-box"] = true,
    ["speech-bubble"] = true,
    ["corpse"] = true,
    ["character-corpse"] = true,
    ["fire"] = true,
    ["particle"] = true,
    ["leaf-particle"] = true,
    ["item-request-proxy"] = true,
    ["deconstructible-tile-proxy"] = true,
    ["land-mine"] = true,
    ["cliff"] = true,
    ["elevated-straight-rail"] = true,
    ["elevated-curved-rail-a"] = true,
    ["elevated-curved-rail-b"] = true,
    ["elevated-half-diagonal-rail"] = true
}

local registered_entities = {}
for _, name in ipairs(port_defs.registered_names) do
    registered_entities[name] = true
end

local function is_standard_entity(name)
    return flow_gate_interop.is_standard_entity(name)
end

local function make_port_key(unit_number, port_index)
    return tostring(unit_number) .. ":" .. tostring(port_index)
end

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

function flow_engine.is_touching_active_flow(entity)
    return flow_gate_interop.is_touching_active_flow(entity, flow_engine.get_node_emitter_level, flow_engine.get_node_kinetic_emitter)
end

function flow_engine.is_touching_pneumatic_grid(entity)
    return flow_gate_interop.is_touching_pneumatic_grid(entity)
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
    for k, v in pairs(storage.kinetic_renders) do
        if type(k) == "string" then
            if type(v) == "table" then
                if v.dot and v.dot.valid then v.dot.destroy() end
                if v.ring and v.ring.valid then v.ring.destroy() end
            end
            storage.kinetic_renders[k] = nil
        end
    end
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
    flow_gate_interop.init_storage()

    -- Electromagnetic Projector Fields
    storage.active_projectors = storage.active_projectors or {}
    storage.projector_power_states = storage.projector_power_states or {}
    storage.projector_ready_states = storage.projector_ready_states or {}
    storage.projector_last_fired = storage.projector_last_fired or {}
    if storage.flow_nodes then
        for pkey, node in pairs(storage.flow_nodes) do
            if node and node.is_kinetic and node.is_endpoint then
                flow_engine.enqueue_port(pkey)
            end
        end
    end
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
    local is_powered = false
    if power_state ~= nil then
        is_powered = power_state
    else
        is_powered = projector_settings.is_powered(entity)
    end

    local enabled_state = storage.projector_enabled_states and storage.projector_enabled_states[unit_number]
    local is_enabled = false
    if enabled_state ~= nil then
        is_enabled = enabled_state
    else
        is_enabled = projector_settings.is_projector_enabled(entity)
    end

    if not (is_powered and is_enabled) then return 0 end

    local q_level = (entity.quality and entity.quality.level) or 0
    return math.floor(BASE_PROJECTOR_RANGE * (1 + 0.3 * q_level))
end

function flow_engine.get_kinetic_level(pkey)
    if not (pkey and storage.kinetic_levels) then return 0 end
    return storage.kinetic_levels[pkey] or 0
end

-- Aliased Renderer Primitives
local destroy_pos_renders = flow_renderer.destroy_pos_renders
local destroy_counter_renders = flow_renderer.destroy_counter_renders
local destroy_edge_render = flow_renderer.destroy_edge_render
local destroy_kinetic_pos_render = flow_renderer.destroy_kinetic_pos_render
local update_kinetic_pos_render = flow_renderer.update_kinetic_pos_render
local get_dominant_port_at_pos = flow_renderer.get_dominant_port_at_pos
local get_dominant_counter_at_pos = flow_renderer.get_dominant_counter_at_pos
local update_counter_pos_render = flow_renderer.update_counter_pos_render
local update_pos_render = flow_renderer.update_pos_render
local update_edge_render = flow_renderer.update_edge_render

-- Public Alt-Mode Visualization API Exports
flow_engine.clear_counter_renders = flow_renderer.clear_counter_renders
flow_engine.clear_flow_renders = flow_renderer.clear_flow_renders
flow_engine.clear_all_renders = flow_renderer.clear_all_renders
flow_engine.draw_all_counters = flow_renderer.draw_all_counters
flow_engine.draw_flow = flow_renderer.draw_flow
flow_engine.draw_all = flow_renderer.draw_all

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

            local is_ignorable = (IGNORABLE_TYPES[cand_type] == true) or (PROXY_NAMES[cand_name] == true)

            if not is_ignorable and cand_type == "gate" then
                if not (cand.is_closed and cand.is_closed()) then
                    is_ignorable = true
                end
            end
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
            if n_node and n_node.is_kinetic and n_node.beam_owner == node.beam_owner then
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
    flow_gate_interop.discover_adjacent_standard_entity(node, flow_engine.connect_entity)
end

function flow_engine.handle_interop_research_finished(force)
    flow_gate_interop.handle_interop_research_finished(force)
end

function flow_engine.handle_interop_research_reversed(force)
    flow_gate_interop.handle_interop_research_reversed(force, flow_engine.enqueue_port, flow_renderer.destroy_edge_render)
end

function flow_engine.notify_beam_obstruction_changed(entity, is_removal)
    if not (entity and entity.valid and entity.bounding_box and storage.active_projectors) then return end
    if IGNORABLE_TYPES[entity.type] or PROXY_NAMES[entity.name] then return end
    local bb = entity.bounding_box
    local surf_name = entity.surface.name

    for unit_number, proj in pairs(storage.active_projectors) do
        if proj and proj.valid and proj.surface.name == surf_name and proj ~= entity then
            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
            local muzzle_node = nil
            if u_ports then
                for i = 1, #u_ports do
                    local mn = storage.flow_nodes and storage.flow_nodes[u_ports[i]]
                    if mn and (mn.is_muzzle or mn.kinetic_transmit) and mn.dir then
                        muzzle_node = mn
                        break
                    end
                end
            end

            if muzzle_node and muzzle_node.dir then
                local dx = muzzle_node.dir.x
                local dy = muzzle_node.dir.y
                local mx = muzzle_node.pos.x
                local my = muzzle_node.pos.y

                local max_reach = flow_engine.get_node_kinetic_emitter(muzzle_node)
                if max_reach > 0 then
                    local intersects = false
                    local d_start = 0
                    local d_end = 0

                    if dx ~= 0 then
                        if bb.left_top.y - 0.45 <= my and my <= bb.right_bottom.y + 0.45 then
                            local d1 = (bb.left_top.x - mx) / dx
                            local d2 = (bb.right_bottom.x - mx) / dx
                            d_start = math.floor(math.min(d1, d2) - 0.5)
                            d_end = math.ceil(math.max(d1, d2) + 0.5)
                            if d_end >= 0 and d_start <= max_reach then
                                intersects = true
                            end
                        end
                    elseif dy ~= 0 then
                        if bb.left_top.x - 0.45 <= mx and mx <= bb.right_bottom.x + 0.45 then
                            local d1 = (bb.left_top.y - my) / dy
                            local d2 = (bb.right_bottom.y - my) / dy
                            d_start = math.floor(math.min(d1, d2) - 0.5)
                            d_end = math.ceil(math.max(d1, d2) + 0.5)
                            if d_end >= 0 and d_start <= max_reach then
                                intersects = true
                            end
                        end
                    end

                    if intersects then
                        local check_min = math.max(0, d_start - 1)
                        local check_max = math.min(max_reach, d_end + 1)

                        for dist = check_min, check_max do
                            local pkey = (dist == 0)
                                and make_port_key(unit_number, muzzle_node.port_index)
                                or  make_beam_port_key(unit_number, dx, dy, dist)

                            local b_node = storage.flow_nodes and storage.flow_nodes[pkey]
                            if b_node then
                                if is_removal and b_node.is_endpoint then
                                    b_node.is_endpoint = false
                                    b_node.hit_receiver = nil
                                    local is_prom = (not b_node.is_muzzle) and ((b_node.dist or 0) > 0) and ((b_node.dist or 0) % HOP_DISTANCE == 0)
                                    b_node.is_prominent_kinetic = is_prom
                                    b_node.is_beam_node = is_prom
                                    b_node.capsule_transmit = is_prom
                                end
                                flow_engine.enqueue_port(pkey)
                                wake_port_parked(pkey)
                            end
                        end
                    end
                end
            end
            if is_removal and u_ports then
                for _, upkey in ipairs(u_ports) do
                    wake_port_parked(upkey)
                end
            end
        end
    end
end

function flow_engine.step(tick)
    if not storage.kinetic_ore_obstruction_fixed then
        storage.kinetic_ore_obstruction_fixed = true
        if storage.flow_nodes then
            for pkey, node in pairs(storage.flow_nodes) do
                if node and node.is_kinetic and node.is_endpoint then
                    flow_engine.enqueue_port(pkey)
                end
            end
        end
    end
    if not storage.kinetic_rail_cliff_fixed then
        storage.kinetic_rail_cliff_fixed = true
        if storage.flow_nodes then
            for pkey, node in pairs(storage.flow_nodes) do
                if node and node.is_kinetic and node.is_endpoint then
                    flow_engine.enqueue_port(pkey)
                end
            end
        end
    end
    if not storage.projector_ports_initialized then
        storage.projector_ports_initialized = true
        if storage.active_projectors then
            for unit_number in pairs(storage.active_projectors) do
                flow_engine.enqueue_unit_ports(unit_number)
            end
        end
    end

    flow_gate_interop.step_gates(flow_engine.notify_beam_obstruction_changed, flow_engine.enqueue_unit_ports)
    flow_gate_interop.step_interop_queue(flow_engine.connect_entity)

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
        local node = storage.flow_nodes and storage.flow_nodes[pkey]

        if node and node.is_kinetic then
            if target_kinetic > 0 then
                if kinetic_changed then
                    storage.kinetic_levels[pkey] = target_kinetic
                    if node.is_muzzle then
                        update_pos_render(node.pos_key)
                    end
                end

                local surface = game.surfaces[node.surface_name]

                local has_downstream = false
                local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                        if n_node and n_node.is_kinetic and n_node.beam_owner == node.beam_owner and n_node.dist and node.dist and n_node.dist > node.dist then
                            has_downstream = true
                            break
                        end
                    end
                end

                if not has_downstream and surface and surface.valid then
                    if target_kinetic == 1 and not node.is_muzzle then
                        node.is_endpoint = true
                        node.is_prominent_kinetic = true
                        node.is_beam_node = true
                        node.capsule_transmit = true
                        node.hit_receiver = nil
                        update_kinetic_pos_render(pkey)
                        wake_port_parked(pkey)
                    elseif target_kinetic > 1 and node.dir then
                        local nx = node.pos.x + node.dir.x
                        local ny = node.pos.y + node.dir.y
                        local owner_entity = storage.active_projectors and storage.active_projectors[node.beam_owner or node.unit_number]
                        local occ = flow_engine.check_tile_obstruction(surface, nx, ny, owner_entity)

                        if occ.blocked then
                            node.is_endpoint = true
                            node.is_prominent_kinetic = true
                            node.is_beam_node = true
                            node.capsule_transmit = true
                            node.hit_receiver = occ.is_receiver and occ.receiver and occ.receiver.unit_number or nil
                            update_kinetic_pos_render(pkey)
                            wake_port_parked(pkey)

                            if occ.is_receiver and occ.receiver and occ.receiver.unit_number then
                                local r_unit = occ.receiver.unit_number
                                flow_engine.enqueue_unit_ports(r_unit)
                                local r_ports = storage.flow_unit_ports and storage.flow_unit_ports[r_unit]
                                if r_ports then
                                    for _, rp in ipairs(r_ports) do
                                        wake_port_parked(rp)
                                    end
                                end
                            end

                            local owner_unit = node.beam_owner or node.unit_number
                            local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[owner_unit]
                            if u_ports then
                                for _, upkey in ipairs(u_ports) do
                                    wake_port_parked(upkey)
                                end
                            end
                        else
                            local node_is_prom = (not node.is_muzzle) and ((node.dist or 0) > 0) and ((node.dist or 0) % HOP_DISTANCE == 0)
                            node.is_endpoint = false
                            node.hit_receiver = nil
                            node.is_prominent_kinetic = node_is_prom
                            node.is_beam_node = node_is_prom
                            node.capsule_transmit = node_is_prom

                            local next_dist = (node.dist or 0) + 1
                            local next_pkey = make_beam_port_key(node.beam_owner or node.unit_number, node.dir.x, node.dir.y, next_dist)
                            local next_pos_key = make_pos_key(node.surface_name, nx, ny)
                            local is_prom = (next_dist % HOP_DISTANCE == 0)

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

                            update_kinetic_pos_render(pkey)

                            if is_prom then
                                local owner_unit = node.beam_owner or node.unit_number
                                local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[owner_unit]
                                if u_ports then
                                    for _, upkey in ipairs(u_ports) do
                                        wake_port_parked(upkey)
                                    end
                                end
                            end
                        end
                    end
                else
                    local node_is_prom = (not node.is_muzzle) and ((node.dist or 0) > 0) and ((node.dist or 0) % HOP_DISTANCE == 0)
                    if node.is_endpoint or (node.is_prominent_kinetic ~= node_is_prom) then
                        node.is_endpoint = false
                        node.hit_receiver = nil
                        node.is_prominent_kinetic = node_is_prom
                        node.is_beam_node = node_is_prom
                        node.capsule_transmit = node_is_prom
                        update_kinetic_pos_render(pkey)
                    elseif kinetic_changed then
                        update_kinetic_pos_render(pkey)
                    end
                end
            else
                if kinetic_changed then
                    storage.kinetic_levels[pkey] = nil
                    destroy_kinetic_pos_render(pkey)

                    if not node.is_muzzle then
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
                    else
                        local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                        if neighbors then
                            for n_key in pairs(neighbors) do
                                flow_engine.enqueue_port(n_key)
                                wake_port_parked(n_key)
                            end
                        end
                        local u_ports = storage.flow_unit_ports and storage.flow_unit_ports[node.unit_number]
                        if u_ports then
                            for _, upkey in ipairs(u_ports) do
                                wake_port_parked(upkey)
                            end
                        end
                        wake_port_parked(pkey)
                    end
                    update_pos_render(node.pos_key)
                end
            end
        end

        local node = storage.flow_nodes and storage.flow_nodes[pkey]
        if node then
            flow_gate_interop.update_wall_locking(node, pkey, target_flow, target_range, flow_engine.enqueue_port)
            flow_gate_interop.check_wall_gate_demotion(node, pkey, target_flow, target_range, flow_engine.disconnect_entity)
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
                                   or (range_changed and node.sense_transmit and int_node.sense_transmit)
                                   or (kinetic_changed and (node.kinetic_transmit or node.cross_transit) and (int_node.kinetic_transmit or int_node.cross_transit)) then
                                    flow_engine.enqueue_port(int_key)
                                    wake_port_parked(int_key)
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
                    if kinetic_changed then
                        wake_port_parked(n_key)
                    end
                end
            else
                local eff_flow = storage.flow_levels and storage.flow_levels[pkey] or 0
                local eff_sense = storage.counter_levels and storage.counter_levels[pkey] or 0
                if eff_flow ~= 0 or eff_sense > 0 then
                    discover_adjacent_standard_entity(node)
                end
            end

            if kinetic_changed then
                wake_port_parked(pkey)
            end
        end
    end
end

local function handle_entity_reorientation(entity)
    if not (entity and entity.valid and entity.unit_number) then return end
    if entity.name == "entity-ghost" then return end

    local real_name = entity.name

    if real_name == "pneumatic-projector" then
        local u_num = entity.unit_number
        local dev_id = projector_settings.get_device_id(entity)
        if dev_id then
            projector_settings.set_muzzle_direction(dev_id, entity.direction)
        end

        flow_engine.notify_beam_obstruction_changed(entity, true)

        for pkey, fn in pairs(storage.flow_nodes or {}) do
            if fn and fn.hit_receiver == u_num then
                fn.is_endpoint = false
                fn.hit_receiver = nil
                local is_prom = (not fn.is_muzzle) and ((fn.dist or 0) > 0) and ((fn.dist or 0) % HOP_DISTANCE == 0)
                fn.is_prominent_kinetic = is_prom
                fn.is_beam_node = is_prom
                fn.capsule_transmit = is_prom
                flow_engine.enqueue_port(pkey)
                wake_port_parked(pkey)
            end
        end

        if storage.flow_unit_ports and storage.flow_unit_ports[u_num] then
            flow_engine.disconnect_entity(entity)
        end

        flow_engine.connect_entity(entity)
        flow_engine.notify_beam_obstruction_changed(entity, false)
    elseif registered_entities[real_name] then
        flow_engine.notify_beam_obstruction_changed(entity, true)
        if storage.flow_unit_ports and storage.flow_unit_ports[entity.unit_number] then
            flow_engine.disconnect_entity(entity)
        end
        flow_engine.connect_entity(entity)
        flow_engine.notify_beam_obstruction_changed(entity, false)
    elseif is_standard_entity(real_name) then
        flow_gate_interop.handle_standard_entity_reorientation(entity, flow_engine.disconnect_entity, flow_engine.connect_entity, flow_engine.notify_beam_obstruction_changed, flow_engine.get_node_emitter_level, flow_engine.get_node_kinetic_emitter)
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
        wake_port_parked(pkey)
        update_pos_render(pos_key)
        update_counter_pos_render(pos_key)
    end
end

function flow_engine.disconnect_entity(entity)
    if not (entity and entity.unit_number) then return end
    local unit_number = entity.unit_number

    if storage.active_projectors then storage.active_projectors[unit_number] = nil end
    if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end
    if storage.projector_ready_states then storage.projector_ready_states[unit_number] = nil end
    if storage.projector_last_fired then storage.projector_last_fired[unit_number] = nil end

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
            destroy_kinetic_pos_render(pkey)
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

    -- Immediate deconstruction lifecycle purge for destroyed projectors
    if storage.active_projectors and storage.active_projectors[unit_number] then
        for pkey, node in pairs(storage.flow_nodes or {}) do
            if node and node.beam_owner == unit_number and not node.is_muzzle then
                destroy_kinetic_pos_render(pkey)
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
                end

                if storage.flow_connections then storage.flow_connections[pkey] = nil end
                if storage.kinetic_levels then storage.kinetic_levels[pkey] = nil end
                storage.flow_nodes[pkey] = nil
                wake_port_parked(pkey)
            end
        end
    end

    -- Free and wake any endpoints across the factory that were targeting this destroyed machine
    for pkey, fn in pairs(storage.flow_nodes or {}) do
        if fn and fn.hit_receiver == unit_number then
            fn.is_endpoint = false
            fn.hit_receiver = nil
            local is_prom = (not fn.is_muzzle) and ((fn.dist or 0) > 0) and ((fn.dist or 0) % HOP_DISTANCE == 0)
            fn.is_prominent_kinetic = is_prom
            fn.is_beam_node = is_prom
            fn.capsule_transmit = is_prom
            flow_engine.enqueue_port(pkey)
            wake_port_parked(pkey)
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
    if storage.projector_ready_states then storage.projector_ready_states[unit_number] = nil end
    if storage.projector_last_fired then storage.projector_last_fired[unit_number] = nil end
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

            if real_name == "gate" or entity.type == "gate" then
                storage.active_gates = storage.active_gates or {}
                storage.active_gates[entity.unit_number] = entity
                storage.gate_open_states = storage.gate_open_states or {}
                storage.gate_open_states[entity.unit_number] = not (entity.is_closed and entity.is_closed())
                if script.register_on_object_destroyed then
                    local reg_id = script.register_on_object_destroyed(entity)
                    storage.object_destruction_map = storage.object_destruction_map or {}
                    storage.object_destruction_map[reg_id] = { type = "entity", unit_number = entity.unit_number }
                end
            end
            if registered_entities[real_name] then
                flow_engine.connect_entity(entity)
            elseif is_standard_entity(real_name) then
                flow_gate_interop.handle_standard_entity_build(entity, flow_engine.connect_entity, flow_engine.get_node_emitter_level, flow_engine.get_node_kinetic_emitter)
            end

            flow_engine.notify_beam_obstruction_changed(entity, false)
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
            if entity and entity.valid then
                flow_engine.notify_beam_obstruction_changed(entity, true)

                local u_num = entity.unit_number
                if u_num then
                    for pkey, fn in pairs(storage.flow_nodes or {}) do
                        if fn and fn.hit_receiver == u_num then
                            fn.is_endpoint = false
                            fn.hit_receiver = nil
                            local is_prom = (not fn.is_muzzle) and ((fn.dist or 0) > 0) and ((fn.dist or 0) % HOP_DISTANCE == 0)
                            fn.is_prominent_kinetic = is_prom
                            fn.is_beam_node = is_prom
                            fn.capsule_transmit = is_prom
                            flow_engine.enqueue_port(pkey)
                            wake_port_parked(pkey)
                        end
                    end
                end

                flow_engine.disconnect_entity(entity)
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
