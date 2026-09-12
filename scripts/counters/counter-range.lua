-- File: scripts/counters/counter-range.lua

local flow_common = require("scripts.flow.flow-common")
local flow_renderer = require("scripts.flow.flow-renderer")
local capsule_manager = require("scripts.capsules.capsule-manager")

local counter_range = {}

function counter_range.init_storage()
    storage.counter_levels = storage.counter_levels or {}
    storage.counter_owners = storage.counter_owners or {}
    storage.counter_owned_nodes = storage.counter_owned_nodes or {}
    storage.active_counters = storage.active_counters or {}
    storage.counter_power_states = storage.counter_power_states or {}
    storage.counter_renders = storage.counter_renders or {}
    storage.counter_capsules = storage.counter_capsules or {}
    storage.counter_stable_summary = storage.counter_stable_summary or {}
    storage.counter_stable_capsules = storage.counter_stable_capsules or {}
    storage.counter_dynamic_capsules = storage.counter_dynamic_capsules or {}

    if not storage.counter_stable_summary_v3 then
        storage.counter_stable_summary_v3 = true
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
    if storage.counter_stable_summary then storage.counter_stable_summary[unit_number] = nil end
    if storage.counter_stable_capsules then storage.counter_stable_capsules[unit_number] = nil end
    if storage.counter_dynamic_capsules then storage.counter_dynamic_capsules[unit_number] = nil end
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

--- Returns the pre-aggregated stable capsule signal summary for a counter unit
--- @param counter_unit number
--- @return table|nil summary { capsule_count = number, vessels = table, cargo = table }
function counter_range.get_stable_summary(counter_unit)
    if not counter_unit then return nil end
    counter_range.init_storage()
    return storage.counter_stable_summary and storage.counter_stable_summary[counter_unit]
end

--- Returns the set of dynamic capsule IDs in this counter's sensing territory
--- @param counter_unit number
--- @return table<number, boolean>|nil
function counter_range.get_dynamic_capsules(counter_unit)
    if not counter_unit then return nil end
    counter_range.init_storage()
    return storage.counter_dynamic_capsules and storage.counter_dynamic_capsules[counter_unit]
end

local function add_capsule_to_summary(summary, sig_data)
    if not (summary and sig_data) then return end
    summary.capsule_count = (summary.capsule_count or 0) + 1

    local v = sig_data.vessel
    if v then
        local v_key = v.name .. "@" .. (v.quality or "normal")
        local entry = summary.vessels[v_key]
        if not entry then
            entry = {
                type = "item",
                name = v.name,
                quality = v.quality or "normal",
                count = 0
            }
            summary.vessels[v_key] = entry
        end
        entry.count = entry.count + 1
    end

    if sig_data.cargo then
        for _, c in ipairs(sig_data.cargo) do
            local c_key = c.name .. "@" .. (c.quality or "normal")
            local entry = summary.cargo[c_key]
            if not entry then
                entry = {
                    type = "item",
                    name = c.name,
                    quality = c.quality or "normal",
                    count = 0
                }
                summary.cargo[c_key] = entry
            end
            entry.count = entry.count + c.count
        end
    end
end

local function subtract_capsule_from_summary(summary, sig_data)
    if not (summary and sig_data) then return end
    summary.capsule_count = math.max(0, (summary.capsule_count or 1) - 1)

    local v = sig_data.vessel
    if v then
        local v_key = v.name .. "@" .. (v.quality or "normal")
        local entry = summary.vessels[v_key]
        if entry then
            entry.count = entry.count - 1
            if entry.count <= 0 then
                summary.vessels[v_key] = nil
            end
        end
    end

    if sig_data.cargo then
        for _, c in ipairs(sig_data.cargo) do
            local c_key = c.name .. "@" .. (c.quality or "normal")
            local entry = summary.cargo[c_key]
            if entry then
                entry.count = entry.count - c.count
                if entry.count <= 0 then
                    summary.cargo[c_key] = nil
                end
            end
        end
    end

    if summary.capsule_count <= 0 then
        summary.capsule_count = 0
        summary.vessels = {}
        summary.cargo = {}
    end
end

function counter_range.add_capsule_to_counter(counter_unit, cap_id)
    if not (counter_unit and cap_id) then return end

    storage.counter_capsules = storage.counter_capsules or {}
    local c_caps = storage.counter_capsules[counter_unit]
    if not c_caps then
        c_caps = {}
        storage.counter_capsules[counter_unit] = c_caps
    end
    if c_caps[cap_id] then
        return
    end
    c_caps[cap_id] = true

    local sig_data, is_stable = capsule_manager.get_signal_data(cap_id)
    if is_stable and sig_data then
        storage.counter_stable_capsules = storage.counter_stable_capsules or {}
        local s_caps = storage.counter_stable_capsules[counter_unit]
        if not s_caps then
            s_caps = {}
            storage.counter_stable_capsules[counter_unit] = s_caps
        end
        s_caps[cap_id] = sig_data

        storage.counter_stable_summary = storage.counter_stable_summary or {}
        local summary = storage.counter_stable_summary[counter_unit]
        if not summary then
            summary = { capsule_count = 0, vessels = {}, cargo = {} }
            storage.counter_stable_summary[counter_unit] = summary
        end
        add_capsule_to_summary(summary, sig_data)
    else
        storage.counter_dynamic_capsules = storage.counter_dynamic_capsules or {}
        local d_caps = storage.counter_dynamic_capsules[counter_unit]
        if not d_caps then
            d_caps = {}
            storage.counter_dynamic_capsules[counter_unit] = d_caps
        end
        d_caps[cap_id] = true
    end
end

function counter_range.remove_capsule_from_counter(counter_unit, cap_id)
    if not (counter_unit and cap_id) then return end

    if storage.counter_capsules and storage.counter_capsules[counter_unit] then
        storage.counter_capsules[counter_unit][cap_id] = nil
    end

    if storage.counter_stable_capsules and storage.counter_stable_capsules[counter_unit] then
        local sig_data = storage.counter_stable_capsules[counter_unit][cap_id]
        if sig_data then
            storage.counter_stable_capsules[counter_unit][cap_id] = nil
            if storage.counter_stable_summary and storage.counter_stable_summary[counter_unit] then
                subtract_capsule_from_summary(storage.counter_stable_summary[counter_unit], sig_data)
            end
        end
    end

    if storage.counter_dynamic_capsules and storage.counter_dynamic_capsules[counter_unit] then
        storage.counter_dynamic_capsules[counter_unit][cap_id] = nil
    end
end

--- Updates a capsule's territory registration when its from_port_key changes
--- @param capsule table
function counter_range.update_capsule_territory(capsule)
    if not capsule then return end
    local cap_id = capsule.capsule_id or capsule.id
    if not cap_id then return end

    local current_pkey = capsule.from_port_key
    local new_owner = current_pkey and storage.counter_owners and storage.counter_owners[current_pkey] or nil
    local old_owner = capsule.counter_owner

    if old_owner == new_owner then
        return
    end

    if old_owner then
        counter_range.remove_capsule_from_counter(old_owner, cap_id)
    end

    if new_owner then
        counter_range.add_capsule_to_counter(new_owner, cap_id)
    end

    capsule.counter_owner = new_owner
end

--- Finds a capsule in motion storage by either runner ID or capsule ID
--- @param cap_id number
--- @return table|nil
function counter_range.find_capsule_by_id(cap_id)
    if not (cap_id and storage.capsules) then return nil end
    if storage.capsules[cap_id] then return storage.capsules[cap_id] end
    for _, cap in pairs(storage.capsules) do
        if cap.capsule_id == cap_id or cap.id == cap_id then
            return cap
        end
    end
    return nil
end

--- Removes a capsule from territory registration upon arrival or removal
--- @param capsule_or_id table|number
function counter_range.unregister_capsule_territory(capsule_or_id)
    local cap_id = type(capsule_or_id) == "table" and (capsule_or_id.capsule_id or capsule_or_id.id) or capsule_or_id
    if not cap_id then return end

    local capsule = type(capsule_or_id) == "table" and capsule_or_id or (storage.capsules and (storage.capsules[cap_id] or counter_range.find_capsule_by_id(cap_id)))
    local old_owner = capsule and capsule.counter_owner

    if old_owner then
        counter_range.remove_capsule_from_counter(old_owner, cap_id)
    elseif storage.counter_capsules then
        for c_unit, c_caps in pairs(storage.counter_capsules) do
            if c_caps[cap_id] then
                counter_range.remove_capsule_from_counter(c_unit, cap_id)
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
    storage.counter_stable_summary = {}
    storage.counter_stable_capsules = {}
    storage.counter_dynamic_capsules = {}
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
                local stable_sum = storage.counter_stable_summary and storage.counter_stable_summary[unit_number]
                local stable_count = stable_sum and stable_sum.capsule_count or 0
                local dyn_map = storage.counter_dynamic_capsules and storage.counter_dynamic_capsules[unit_number]
                local dyn_count = 0
                if dyn_map then
                    for _ in pairs(dyn_map) do dyn_count = dyn_count + 1 end
                end
                game.print(string.format("[Counter Status] Counter #%d (%s at x=%.1f, y=%.1f): owns %d tube node(s), %d capsule(s) in territory (%d stable, %d dynamic)", unit_number, power, entity.position.x, entity.position.y, node_count, cap_count, stable_count, dyn_count))
            end
        end
        if count == 0 then
            game.print("[Counter Status] No active capsule counters registered in storage!")
        end
    end)
end

return counter_range