local util = require("util")

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

pump_settings.get_device_id = get_device_id

function pump_settings.get(unit_number)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return nil end

    storage.pump_settings = storage.pump_settings or {}
    if not storage.pump_settings[dev_id] then
        storage.pump_settings[dev_id] = {
            enabled = true,
            use_circuit_enable = false,
            enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
            read_red = true,
            read_green = true
        }
    else
        local s = storage.pump_settings[dev_id]
        if s.enabled == nil then s.enabled = true end
        if s.use_circuit_enable == nil then s.use_circuit_enable = false end
        if s.enable_condition == nil then
            s.enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        end
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
    end
    return storage.pump_settings[dev_id]
end

function pump_settings.copy(src_unit_number, dest_unit_number)
    local src_id = get_device_id(src_unit_number)
    local dest_id = get_device_id(dest_unit_number)
    if not (src_id and dest_id) then return nil end
    local src = storage.pump_settings and storage.pump_settings[src_id]
    if not src then return nil end

    storage.pump_settings = storage.pump_settings or {}
    local copy = util.table.deepcopy(src)
    storage.pump_settings[dest_id] = copy
    return copy
end

function pump_settings.apply_blueprint_settings(unit_number, blueprint_settings)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and blueprint_settings) then return nil end
    storage.pump_settings = storage.pump_settings or {}
    local copy = util.table.deepcopy(blueprint_settings)
    storage.pump_settings[dev_id] = copy
    return copy
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
    if not (entity and entity.valid) then return false end
    local dev_id = get_device_id(entity)
    if not dev_id then return false end

    local settings = pump_settings.get(dev_id)
    if not settings then return false end

    if entity.name == "entity-ghost" then
        return settings.enabled ~= false
    end

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