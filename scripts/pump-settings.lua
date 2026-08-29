local pump_settings = {}

local function evaluate_condition(val, operator, target)
    if operator == "<" then return val < target
    elseif operator == ">" then return val > target
    elseif operator == "=" or operator == "==" then return val == target
    elseif operator == "≥" or operator == ">=" then return val >= target
    elseif operator == "≤" or operator == "<=" then return val <= target
    elseif operator == "≠" or operator == "!=" then return val ~= target
    end
    return false
end

function pump_settings.get(unit_number)
    storage.pump_settings = storage.pump_settings or {}
    if not storage.pump_settings[unit_number] then
        storage.pump_settings[unit_number] = {
            enabled = true,
            use_circuit_enable = false,
            enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
            read_red = true,
            read_green = true
        }
    else
        local s = storage.pump_settings[unit_number]
        if s.enabled == nil then s.enabled = true end
        if s.use_circuit_enable == nil then s.use_circuit_enable = false end
        if s.enable_condition == nil then
            s.enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        end
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
    end
    return storage.pump_settings[unit_number]
end

function pump_settings.get_proxy(entity)
    if not (entity and entity.valid) then return nil end
    local proxies = entity.surface.find_entities_filtered{
        name = "pneumatic-pump-circuit-proxy",
        position = entity.position
    }
    return proxies[1]
end

function pump_settings.evaluate_circuit_condition(proxy_entity, condition, read_red, read_green)
    if not (proxy_entity and proxy_entity.valid) then return false end
    if not condition or not condition.first_signal then return false end

    local red_conn = read_red and defines.wire_connector_id.circuit_red or nil
    local green_conn = read_green and defines.wire_connector_id.circuit_green or nil

    if not red_conn and not green_conn then
        return evaluate_condition(0, condition.comparator or "=", condition.constant or 0)
    end

    local val = 0
    if red_conn and green_conn then
        val = proxy_entity.get_signal(condition.first_signal, red_conn, green_conn) or 0
    elseif red_conn then
        val = proxy_entity.get_signal(condition.first_signal, red_conn) or 0
    elseif green_conn then
        val = proxy_entity.get_signal(condition.first_signal, green_conn) or 0
    end

    return evaluate_condition(val, condition.comparator or "=", condition.constant or 0)
end

function pump_settings.is_pump_enabled(entity)
    if not (entity and entity.valid and entity.unit_number) then return false end
    local settings = pump_settings.get(entity.unit_number)
    if not settings then return false end

    if settings.use_circuit_enable then
        local proxy = pump_settings.get_proxy(entity)
        if not proxy then return false end
        local read_red = settings.read_red ~= false
        local read_green = settings.read_green ~= false
        return pump_settings.evaluate_circuit_condition(proxy, settings.enable_condition, read_red, read_green)
    end

    return settings.enabled ~= false
end

return pump_settings