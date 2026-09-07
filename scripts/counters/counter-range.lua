local events = require("scripts.events")

local counter_range = {}

local BATCH_SIZE = 50
local DEFAULT_RANGE_SEED = 15

local function ensure_storage()
    storage.counter_levels = storage.counter_levels or {}
    storage.counter_owners = storage.counter_owners or {}
    storage.counter_queue = storage.counter_queue or {}
    storage.counter_owned_nodes = storage.counter_owned_nodes or {}
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.flow_nodes = storage.flow_nodes or {}
    storage.flow_unit_ports = storage.flow_unit_ports or {}
    storage.flow_connections = storage.flow_connections or {}
end

function counter_range.init_storage()
    ensure_storage()
end

function counter_range.enqueue_port(pkey)
    ensure_storage()
    if pkey then
        storage.counter_queue[pkey] = true
    end
end

function counter_range.enqueue_unit_ports(unit_number)
    ensure_storage()
    if not unit_number then return end
    local unit_ports = storage.flow_unit_ports[unit_number]
    if unit_ports then
        for i = 1, #unit_ports do
            counter_range.enqueue_port(unit_ports[i])
        end
    end
end

function counter_range.enqueue_all()
    ensure_storage()
    for pkey in pairs(storage.flow_nodes) do
        counter_range.enqueue_port(pkey)
    end
end

function counter_range.register_counter(entity)
    ensure_storage()
    if not (entity and entity.valid and entity.unit_number) then return end

    local unit_number = entity.unit_number
    if not storage.active_counters[unit_number] then
        storage.active_counters[unit_number] = entity
        game.print(string.format("[Capsule Counter] Registered counter #%d at (%d, %d)", unit_number, entity.position.x, entity.position.y))
    end

    counter_range.enqueue_unit_ports(unit_number)
end

function counter_range.unregister_counter(unit_number)
    ensure_storage()
    if not unit_number then return end

    if storage.active_counters[unit_number] then
        game.print(string.format("[Capsule Counter] Unregistered counter #%d", unit_number))
        storage.active_counters[unit_number] = nil
    end

    storage.counter_power_states[unit_number] = nil

    local owned = storage.counter_owned_nodes[unit_number]
    if owned then
        for pkey in pairs(owned) do
            if storage.counter_owners[pkey] == unit_number then
                storage.counter_owners[pkey] = nil
                storage.counter_levels[pkey] = nil
                counter_range.enqueue_port(pkey)
            end
        end
        storage.counter_owned_nodes[unit_number] = nil
    end

    counter_range.enqueue_unit_ports(unit_number)
end

function counter_range.get_owned_nodes(counter_unit)
    ensure_storage()
    if not counter_unit then return {} end
    return storage.counter_owned_nodes[counter_unit] or {}
end

local function compute_port_counter_level(pkey)
    local node = storage.flow_nodes[pkey]
    if not node then return 0, nil end

    local unit_number = node.unit_number

    if storage.active_counters[unit_number] then
        local counter_entity = storage.active_counters[unit_number]
        if not (counter_entity and counter_entity.valid) then
            return 0, nil
        end

        local is_powered = (counter_entity.energy > 0)
        local last_power = storage.counter_power_states[unit_number]
        if last_power ~= is_powered then
            storage.counter_power_states[unit_number] = is_powered
            local state_str = is_powered and "POWERED ON" or "UNPOWERED (OFF)"
            game.print(string.format("[Capsule Counter] Counter #%d power state changed -> %s", unit_number, state_str))
        end

        if not is_powered then
            return 0, nil
        end

        local seed = node.sense or DEFAULT_RANGE_SEED
        return seed, unit_number
    end

    local unit_ports = storage.flow_unit_ports[unit_number]
    if not unit_ports then return 0, nil end

    local max_cand_level = 0
    local winning_owner = nil
    local is_contested = false

    for _, check_pkey in pairs(unit_ports) do
        local check_node = storage.flow_nodes[check_pkey]
        if check_node then
            local is_self = (check_pkey == pkey)
            local can_transmit_internally = node.transmit and check_node.transmit and (node.group ~= nil) and (check_node.group == node.group)

            if is_self or can_transmit_internally then
                local neighbors = storage.flow_connections[check_pkey]
                if neighbors then
                    for n_key in pairs(neighbors) do
                        local n_level = storage.counter_levels[n_key] or 0
                        local n_owner = storage.counter_owners[n_key]

                        if n_level > 1 and n_owner ~= nil then
                            local cand_level = n_level - 1
                            if cand_level > max_cand_level then
                                max_cand_level = cand_level
                                winning_owner = n_owner
                                is_contested = false
                            elseif cand_level == max_cand_level and cand_level > 0 then
                                if winning_owner ~= n_owner then
                                    is_contested = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if is_contested or max_cand_level == 0 or winning_owner == nil then
        return 0, nil
    end

    return max_cand_level, winning_owner
end

local function set_port_ownership(pkey, target_level, target_owner)
    local current_level = storage.counter_levels[pkey] or 0
    local current_owner = storage.counter_owners[pkey]

    if target_level == current_level and target_owner == current_owner then
        return false
    end

    if current_owner then
        local old_owned = storage.counter_owned_nodes[current_owner]
        if old_owned then
            old_owned[pkey] = nil
        end
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

function counter_range.step(tick)
    ensure_storage()
    if next(storage.counter_queue) == nil then return end

    local batch = {}
    local batch_count = 0

    for pkey in pairs(storage.counter_queue) do
        batch_count = batch_count + 1
        batch[batch_count] = pkey
        storage.counter_queue[pkey] = nil
        if batch_count >= BATCH_SIZE then
            break
        end
    end

    for i = 1, batch_count do
        local pkey = batch[i]
        local target_level, target_owner = compute_port_counter_level(pkey)
        local changed = set_port_ownership(pkey, target_level, target_owner)

        if changed then
            if target_owner then
                game.print(string.format("[Capsule Counter] Node %s -> Level %d (Owner #%d)", pkey, target_level, target_owner))
            else
                game.print(string.format("[Capsule Counter] Node %s -> Cleared/Neutral", pkey))
            end

            local node = storage.flow_nodes[pkey]
            if node and node.transmit then
                local unit_ports = storage.flow_unit_ports[node.unit_number]
                if unit_ports and node.group then
                    for _, int_key in pairs(unit_ports) do
                        if int_key ~= pkey then
                            local int_node = storage.flow_nodes[int_key]
                            if int_node and int_node.transmit and int_node.group == node.group then
                                counter_range.enqueue_port(int_key)
                            end
                        end
                    end
                end
            end

            local neighbors = storage.flow_connections[pkey]
            if neighbors then
                for n_key in pairs(neighbors) do
                    counter_range.enqueue_port(n_key)
                end
            end
        end
    end
end

function counter_range.register_events()
    events.on_event(defines.events.on_tick, function(event)
        counter_range.step(event.tick)
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
                local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
                if real_name == "pneumatic-capsule-counter" and entity.name ~= "entity-ghost" then
                    counter_range.register_counter(entity)
                end
                if entity.unit_number then
                    counter_range.enqueue_unit_ports(entity.unit_number)
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
                if entity.name == "pneumatic-capsule-counter" and entity.unit_number then
                    counter_range.unregister_counter(entity.unit_number)
                end
                if entity.unit_number then
                    counter_range.enqueue_unit_ports(entity.unit_number)
                end
            end
        end)
    end

    events.on_event(defines.events.on_player_rotated_entity, function(event)
        local entity = event.entity
        if entity and entity.valid and entity.unit_number then
            counter_range.enqueue_unit_ports(entity.unit_number)
        end
    end)

    events.on_event(defines.events.on_player_flipped_entity, function(event)
        local entity = event.entity
        if entity and entity.valid and entity.unit_number then
            counter_range.enqueue_unit_ports(entity.unit_number)
        end
    end)

    commands.add_command("check-counters", "Display active pneumatic capsule counter status and range territory", function()
        ensure_storage()
        local count = 0
        for unit_number, entity in pairs(storage.active_counters) do
            if entity and entity.valid then
                count = count + 1
                local owned = storage.counter_owned_nodes[unit_number]
                local node_count = 0
                if owned then
                    for _ in pairs(owned) do node_count = node_count + 1 end
                end
                local power = (entity.energy > 0) and "POWERED" or "UNPOWERED"
                game.print(string.format("[Counter Status] Counter #%d (%s at x=%.1f, y=%.1f): owns %d tube node(s)", unit_number, power, entity.position.x, entity.position.y, node_count))
            end
        end
        if count == 0 then
            game.print("[Counter Status] No active capsule counters registered in storage!")
        end
    end)
end

return counter_range