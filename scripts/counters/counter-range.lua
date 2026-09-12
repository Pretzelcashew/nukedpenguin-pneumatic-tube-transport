-- File: scripts/counters/counter-range.lua

local flow_common = require("scripts.flow.flow-common")
local flow_renderer = require("scripts.flow.flow-renderer")

local counter_range = {}

function counter_range.init_storage()
    storage.counter_levels = storage.counter_levels or {}
    storage.counter_owners = storage.counter_owners or {}
    storage.counter_owned_nodes = storage.counter_owned_nodes or {}
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.counter_renders = storage.counter_renders or {}
    storage.counter_capsules = storage.counter_capsules or {}

    if not storage.counter_capsules_initialized then
        storage.counter_capsules_initialized = true
        counter_range.rebuild_territory_capsules()
    end
end

function counter_range.enqueue_port(pkey)
    flow_common.enqueue_port(pkey)
end

function counter_range.enqueue_unit_ports(unit_number)
    flow_common.enqueue_unit_ports(unit_number)
end

function counter_range.register_counter(entity)
    counter_range.init_storage()
    if not (entity and entity.valid and entity.unit_number) then return end

    local unit_number = entity.unit_number
    if not storage.active_counters[unit_number] then
        storage.active_counters[unit_number] = entity
    end

    counter_range.enqueue_unit_ports(unit_number)
end

function counter_range.unregister_counter(unit_number)
    counter_range.init_storage()
    if not unit_number then return end
    if storage.counter_capsules and storage.counter_capsules[unit_number] then
        for cap_id in pairs(storage.counter_capsules[unit_number]) do
            local cap = storage.capsules and storage.capsules[cap_id]
            if cap and cap.counter_owner == unit_number then
                cap.counter_owner = nil
            end
        end
        storage.counter_capsules[unit_number] = nil
    end
    flow_common.enqueue_unit_ports(unit_number)
end

function counter_range.get_owned_nodes(counter_unit)
    counter_range.init_storage()
    if not counter_unit then return {} end
    return storage.counter_owned_nodes[counter_unit] or {}
end

--- Returns the map of capsule IDs currently present in this counter's sensing territory
--- @param counter_unit number
--- @return table<number, boolean>|nil
function counter_range.get_territory_capsules(counter_unit)
    if not counter_unit then return nil end
    counter_range.init_storage()
    return storage.counter_capsules and storage.counter_capsules[counter_unit]
end

--- Updates a capsule's territory registration when its from_port_key changes
--- @param capsule table
function counter_range.update_capsule_territory(capsule)
    if not capsule then return end
    local cap_id = capsule.id or capsule.capsule_id
    if not cap_id then return end

    local current_pkey = capsule.from_port_key
    local new_owner = current_pkey and storage.counter_owners and storage.counter_owners[current_pkey] or nil
    local old_owner = capsule.counter_owner

    if old_owner == new_owner then
        return
    end

    if old_owner and storage.counter_capsules and storage.counter_capsules[old_owner] then
        storage.counter_capsules[old_owner][cap_id] = nil
    end

    if new_owner then
        storage.counter_capsules = storage.counter_capsules or {}
        local c_caps = storage.counter_capsules[new_owner]
        if not c_caps then
            c_caps = {}
            storage.counter_capsules[new_owner] = c_caps
        end
        c_caps[cap_id] = true
    end

    capsule.counter_owner = new_owner
end

--- Removes a capsule from territory registration upon arrival or removal
--- @param capsule_or_id table|number
function counter_range.unregister_capsule_territory(capsule_or_id)
    local cap_id = type(capsule_or_id) == "table" and (capsule_or_id.id or capsule_or_id.capsule_id) or capsule_or_id
    if not cap_id then return end

    local capsule = type(capsule_or_id) == "table" and capsule_or_id or (storage.capsules and storage.capsules[cap_id])
    local old_owner = capsule and capsule.counter_owner

    if old_owner and storage.counter_capsules and storage.counter_capsules[old_owner] then
        storage.counter_capsules[old_owner][cap_id] = nil
    elseif not old_owner and storage.counter_capsules then
        for _, c_caps in pairs(storage.counter_capsules) do
            if c_caps[cap_id] then
                c_caps[cap_id] = nil
            end
        end
    end

    if capsule then
        capsule.counter_owner = nil
    end
end

--- Handles a change in counter ownership for a specific port key (e.g. from wavefront step)
--- @param pkey string
function counter_range.handle_port_owner_changed(pkey)
    if not (pkey and storage.capsules) then return end

    if storage.parked_by_port and storage.parked_by_port[pkey] then
        for cap_id in pairs(storage.parked_by_port[pkey]) do
            local cap = storage.capsules[cap_id]
            if cap then
                counter_range.update_capsule_territory(cap)
            end
        end
    end

    local node = storage.flow_nodes and storage.flow_nodes[pkey]
    local u_num = node and node.unit_number
    if not u_num then
        local colon = string.find(pkey, ":", 1, true)
        u_num = colon and tonumber(string.sub(pkey, 1, colon - 1))
    end

    if u_num and storage.occupancy and storage.occupancy.by_entity_all then
        local caps_at_ent = storage.occupancy.by_entity_all[u_num]
        if caps_at_ent then
            for cap_id in pairs(caps_at_ent) do
                local cap = storage.capsules[cap_id]
                if cap and cap.from_port_key == pkey then
                    counter_range.update_capsule_territory(cap)
                end
            end
        end
    end
end

--- One-time sweep to rebuild counter_capsules index from all active capsules
function counter_range.rebuild_territory_capsules()
    storage.counter_capsules = {}
    if not storage.capsules then return end
    for _, capsule in pairs(storage.capsules) do
        capsule.counter_owner = nil
        counter_range.update_capsule_territory(capsule)
    end
end

function counter_range.clear_all_renders(player_index)
    flow_renderer.clear_counter_renders(player_index)
end

function counter_range.draw_all(player_index)
    flow_renderer.draw_all_counters(player_index)
end

function counter_range.register_events()
    commands.add_command("check-counters", "Display active pneumatic capsule counter status and range territory", function()
        counter_range.init_storage()
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
                local caps_map = storage.counter_capsules and storage.counter_capsules[unit_number]
                local cap_count = 0
                if caps_map then
                    for _ in pairs(caps_map) do cap_count = cap_count + 1 end
                end
                game.print(string.format("[Counter Status] Counter #%d (%s at x=%.1f, y=%.1f): owns %d tube node(s), %d capsule(s) in territory", unit_number, power, entity.position.x, entity.position.y, node_count, cap_count))
            end
        end
        if count == 0 then
            game.print("[Counter Status] No active capsule counters registered in storage!")
        end
    end)
end

return counter_range