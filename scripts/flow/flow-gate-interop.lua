local port_defs = require("scripts.flow.port-defs")
local flow_common = require("scripts.flow.flow-common")

local flow_gate_interop = {}

local INTEROP_BATCH_SIZE = 10

local make_pos_key = flow_common.make_pos_key
local make_edge_key = flow_common.make_edge_key
local wake_port_parked = flow_common.wake_port_parked

function flow_gate_interop.is_standard_entity(name)
    return (name == "stone-wall" or name == "gate")
end

function flow_gate_interop.is_gate_terminator(unit_number)
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

local function is_port_flow_active(pkey, get_emitter_level_fn, get_kinetic_emitter_fn)
    if not pkey then return false end
    if storage.flow_levels and (storage.flow_levels[pkey] or 0) ~= 0 then return true end
    if storage.counter_levels and (storage.counter_levels[pkey] or 0) > 0 then return true end
    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    if node and node.emitter and get_emitter_level_fn and get_emitter_level_fn(node) ~= 0 then return true end
    if node and node.is_muzzle and get_kinetic_emitter_fn and get_kinetic_emitter_fn(node) ~= 0 then return true end
    return false
end

function flow_gate_interop.is_touching_active_flow(entity, get_emitter_level_fn, get_kinetic_emitter_fn)
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
                if is_port_flow_active(existing_pkey, get_emitter_level_fn, get_kinetic_emitter_fn) then return true end
            end
        end
    end
    return false
end

function flow_gate_interop.is_touching_pneumatic_grid(entity)
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

function flow_gate_interop.init_storage()
    storage.active_walls = storage.active_walls or {}
    storage.active_gates = storage.active_gates or {}
    storage.gate_open_states = storage.gate_open_states or {}
    storage.gate_cutoff_states = storage.gate_cutoff_states or {}
    storage.wall_locked_group = storage.wall_locked_group or {}
    storage.soft_interop_registry = storage.soft_interop_registry or {}
    storage.interop_activation_queue = storage.interop_activation_queue or {}

    if storage.active_gates and game and game.surfaces then
        for _, surface in pairs(game.surfaces) do
            local gates = surface.find_entities_filtered{type = "gate"}
            for _, g in ipairs(gates) do
                if g.valid and g.unit_number and g.name ~= "entity-ghost" then
                    storage.active_gates[g.unit_number] = g
                    if script.register_on_object_destroyed then
                        local reg_id = script.register_on_object_destroyed(g)
                        storage.object_destruction_map = storage.object_destruction_map or {}
                        storage.object_destruction_map[reg_id] = { type = "entity", unit_number = g.unit_number }
                    end
                end
            end
        end
    end
end

function flow_gate_interop.discover_adjacent_standard_entity(node, connect_entity_fn)
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
                connect_entity_fn(cand)
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

function flow_gate_interop.handle_interop_research_finished(force)
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

function flow_gate_interop.handle_interop_research_reversed(force, enqueue_port_fn, destroy_edge_render_fn)
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

                                if destroy_edge_render_fn then
                                    destroy_edge_render_fn(make_edge_key(wall_pkey, reg_pkey))
                                end
                                if enqueue_port_fn then
                                    enqueue_port_fn(reg_pkey)
                                    enqueue_port_fn(wall_pkey)
                                end
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

function flow_gate_interop.step_gates(notify_obstruction_fn, enqueue_unit_ports_fn)
    if not storage.active_gates then return end
    for unit_number, gate in pairs(storage.active_gates) do
        if gate and gate.valid then
            local is_open = not (gate.is_closed and gate.is_closed())
            local last_open = storage.gate_open_states and storage.gate_open_states[unit_number]
            local is_term = is_open and flow_gate_interop.is_gate_terminator(unit_number)
            local last_term = storage.gate_cutoff_states and storage.gate_cutoff_states[unit_number]

            if is_open ~= last_open or is_term ~= last_term then
                local open_changed = (is_open ~= last_open)
                storage.gate_open_states = storage.gate_open_states or {}
                storage.gate_open_states[unit_number] = is_open
                storage.gate_cutoff_states = storage.gate_cutoff_states or {}
                storage.gate_cutoff_states[unit_number] = is_term

                if open_changed and notify_obstruction_fn then
                    notify_obstruction_fn(gate, is_open)
                end

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

                if enqueue_unit_ports_fn then
                    enqueue_unit_ports_fn(unit_number)
                end

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

function flow_gate_interop.step_interop_queue(connect_entity_fn)
    if not (storage.interop_activation_queue and next(storage.interop_activation_queue) ~= nil) then return end

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
            if flow_gate_interop.is_touching_pneumatic_grid(entity) then
                connect_entity_fn(entity)
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

function flow_gate_interop.update_wall_locking(node, pkey, target_flow, target_range, enqueue_port_fn)
    if not (node and storage.active_walls and storage.active_walls[node.unit_number]) then return end
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
                        if not matches and enqueue_port_fn then
                            enqueue_port_fn(p)
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
                    if enqueue_port_fn then enqueue_port_fn(p) end
                    wake_port_parked(p)
                    local neighbors = storage.flow_connections and storage.flow_connections[p]
                    if neighbors then
                        for n_key in pairs(neighbors) do
                            if enqueue_port_fn then enqueue_port_fn(n_key) end
                            wake_port_parked(n_key)
                        end
                    end
                end
            end
        end
    end
end

function flow_gate_interop.check_wall_gate_demotion(node, pkey, target_flow, target_range, disconnect_entity_fn)
    if not node then return end
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
                        disconnect_entity_fn(ent)
                        if flow_gate_interop.is_touching_pneumatic_grid(ent) then
                            storage.soft_interop_registry = storage.soft_interop_registry or {}
                            storage.soft_interop_registry[u_num] = ent
                        end
                    end
                end
            end
        end
    end
end

function flow_gate_interop.handle_standard_entity_reorientation(entity, disconnect_entity_fn, connect_entity_fn, notify_obstruction_fn, get_emitter_fn, get_kinetic_emitter_fn)
    if notify_obstruction_fn then
        notify_obstruction_fn(entity, true)
    end
    local was_connected = (storage.flow_unit_ports and storage.flow_unit_ports[entity.unit_number] ~= nil)
    if was_connected then
        disconnect_entity_fn(entity)
    end

    local tech = entity.force and entity.force.technologies and entity.force.technologies["pneumatic-fence-gate-interoperability"]
    local is_researched = (not tech) or tech.researched

    if is_researched then
        if flow_gate_interop.is_touching_pneumatic_grid(entity) then
            connect_entity_fn(entity)
        end
    else
        if flow_gate_interop.is_touching_active_flow(entity, get_emitter_fn, get_kinetic_emitter_fn) then
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
    if notify_obstruction_fn then
        notify_obstruction_fn(entity, false)
    end
end

function flow_gate_interop.handle_standard_entity_build(entity, connect_entity_fn, get_emitter_fn, get_kinetic_emitter_fn)
    local tech = entity.force and entity.force.technologies and entity.force.technologies["pneumatic-fence-gate-interoperability"]
    local is_researched = (not tech) or tech.researched

    if is_researched then
        if flow_gate_interop.is_touching_pneumatic_grid(entity) then
            connect_entity_fn(entity)
        end
    else
        if flow_gate_interop.is_touching_active_flow(entity, get_emitter_fn, get_kinetic_emitter_fn) then
            storage.soft_interop_registry = storage.soft_interop_registry or {}
            storage.soft_interop_registry[entity.unit_number] = entity
            if script.register_on_object_destroyed then
                local reg_id = script.register_on_object_destroyed(entity)
                storage.object_destruction_map = storage.object_destruction_map or {}
                storage.object_destruction_map[reg_id] = { type = "entity", unit_number = entity.unit_number }
            end
        end
    end
end

return flow_gate_interop
