local util = require("util")

local hub_settings = {}

local function get_device_id(entity)
    if not entity then return nil end
    if type(entity) == "number" or type(entity) == "string" then
        return entity
    end
    if not entity.valid then return nil end
    if entity.unit_number then
        return entity.unit_number
    end
    local pos = entity.position
    local sname = entity.surface and entity.surface.name or "unknown"
    local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name
    local px = pos and (pos.x or pos[1] or 0) or 0
    local py = pos and (pos.y or pos[2] or 0) or 0
    return "ghost@" .. real_name .. "@" .. sname .. "@" .. px .. "," .. py
end

hub_settings.get_device_id = get_device_id

function hub_settings.get(unit_number)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return nil end

    storage.hub_settings = storage.hub_settings or {}
    if not storage.hub_settings[dev_id] then
        storage.hub_settings[dev_id] = {
            can_send = true,
            use_circuit_send = false,
            send_condition = {
                first_signal = nil,
                comparator = "<",
                constant = 0
            },
            can_receive = true,
            use_circuit_receive = false,
            receive_condition = {
                first_signal = nil,
                comparator = "<",
                constant = 0
            },
            use_receive_lock = true,
            nest_capsules = true,
            read_red = true,
            read_green = true
        }
    else
        local s = storage.hub_settings[dev_id]
        if s.use_circuit_send == nil then s.use_circuit_send = false end
        if s.send_condition == nil then s.send_condition = { first_signal = nil, comparator = "<", constant = 0 } end
        if s.use_circuit_receive == nil then s.use_circuit_receive = false end
        if s.receive_condition == nil then s.receive_condition = { first_signal = nil, comparator = "<", constant = 0 } end
        if s.use_receive_lock == nil then s.use_receive_lock = true end
        if s.nest_capsules == nil then s.nest_capsules = true end
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
    end
    return storage.hub_settings[dev_id]
end

function hub_settings.copy(src_unit_number, dest_unit_number)
    local src_id = get_device_id(src_unit_number)
    local dest_id = get_device_id(dest_unit_number)
    if not (src_id and dest_id) then return nil end
    local src = storage.hub_settings and storage.hub_settings[src_id]
    if not src then return nil end

    storage.hub_settings = storage.hub_settings or {}
    local copy = util.table.deepcopy(src)
    if copy.nest_capsules == nil then copy.nest_capsules = true end
    storage.hub_settings[dest_id] = copy
    return copy
end

function hub_settings.apply_blueprint_settings(unit_number, blueprint_settings)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and blueprint_settings) then return nil end
    storage.hub_settings = storage.hub_settings or {}
    local copy = util.table.deepcopy(blueprint_settings)
    if copy.nest_capsules == nil then copy.nest_capsules = true end
    storage.hub_settings[dev_id] = copy
    return copy
end

local function evaluate_condition(val, operator, target)
    if operator == "<" then return val < target
    elseif operator == ">" then return val > target
    elseif operator == "=" then return val == target
    elseif operator == "≥" or operator == ">=" then return val >= target
    elseif operator == "≤" or operator == "<=" then return val <= target
    elseif operator == "≠" or operator == "!=" then return val ~= target
    end
    return false
end

function hub_settings.evaluate_circuit_condition(entity, condition, read_red, read_green)
    if not condition or not condition.first_signal then
        return false
    end

    local red_conn = read_red and defines.wire_connector_id.circuit_red or nil
    local green_conn = read_green and defines.wire_connector_id.circuit_green or nil

    if not red_conn and not green_conn then
        return evaluate_condition(0, condition.comparator or "<", condition.constant or 0)
    end

    local val = 0
    if red_conn and green_conn then
        val = entity.get_signal(condition.first_signal, red_conn, green_conn) or 0
    elseif red_conn then
        val = entity.get_signal(condition.first_signal, red_conn) or 0
    elseif green_conn then
        val = entity.get_signal(condition.first_signal, green_conn) or 0
    end

    return evaluate_condition(val, condition.comparator or "<", condition.constant or 0)
end

function hub_settings.can_send(entity)
    if not (entity and entity.valid) then return false end
    local dev_id = get_device_id(entity)
    if not dev_id then return false end
    local settings = hub_settings.get(dev_id)

    if entity.name == "entity-ghost" then
        return settings.can_send
    end

    if settings.use_circuit_send then
        return hub_settings.evaluate_circuit_condition(entity, settings.send_condition, settings.read_red, settings.read_green)
    end

    return settings.can_send
end

function hub_settings.can_receive(entity)
    if not (entity and entity.valid) then return false end
    local dev_id = get_device_id(entity)
    if not dev_id then return false end
    local settings = hub_settings.get(dev_id)

    if entity.name == "entity-ghost" then
        return settings.can_receive
    end

    if settings.use_circuit_receive then
        return hub_settings.evaluate_circuit_condition(entity, settings.receive_condition, settings.read_red, settings.read_green)
    end

    return settings.can_receive
end

return hub_settings