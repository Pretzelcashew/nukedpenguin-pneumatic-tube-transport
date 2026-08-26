local hub_settings = {}

function hub_settings.get(unit_number)
    storage.hub_settings = storage.hub_settings or {}
    if not storage.hub_settings[unit_number] then
        storage.hub_settings[unit_number] = {
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
            read_red = true,
            read_green = true
        }
    else
        local s = storage.hub_settings[unit_number]
        if s.use_circuit_send == nil then s.use_circuit_send = false end
        if s.send_condition == nil then s.send_condition = { first_signal = nil, comparator = "<", constant = 0 } end
        if s.use_circuit_receive == nil then s.use_circuit_receive = false end
        if s.receive_condition == nil then s.receive_condition = { first_signal = nil, comparator = "<", constant = 0 } end
        if s.use_receive_lock == nil then s.use_receive_lock = true end
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
    end
    return storage.hub_settings[unit_number]
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
    -- Unconfigured signal cannot be evaluated
    if not condition or not condition.first_signal then
        return false
    end

    -- Build connector parameters only for enabled channels
    local red_conn = read_red and defines.wire_connector_id.circuit_red or nil
    local green_conn = read_green and defines.wire_connector_id.circuit_green or nil

    -- If no wire channels are enabled, signal defaults to 0
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
    local settings = hub_settings.get(entity.unit_number)

    -- Circuit network mode overrides manual state and evaluates signals directly
    if settings.use_circuit_send then
        return hub_settings.evaluate_circuit_condition(entity, settings.send_condition, settings.read_red, settings.read_green)
    end

    return settings.can_send
end

function hub_settings.can_receive(entity)
    if not (entity and entity.valid) then return false end
    local settings = hub_settings.get(entity.unit_number)

    -- Circuit network mode overrides manual state and evaluates signals directly
    if settings.use_circuit_receive then
        return hub_settings.evaluate_circuit_condition(entity, settings.receive_condition, settings.read_red, settings.read_green)
    end

    return settings.can_receive
end

return hub_settings