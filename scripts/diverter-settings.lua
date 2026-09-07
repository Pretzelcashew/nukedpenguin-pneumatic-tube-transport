local util = require("util")

local diverter_settings = {}

diverter_settings.DEFAULT_CAPACITY = 2

local DIRECTION_TO_INDEX = {
    [0]  = 1, -- North
    [1]  = 1,
    [2]  = 2, -- East (4-way) or NE
    [3]  = 4, -- West (4-way)
    [4]  = 2, -- East (16-way)
    [8]  = 3, -- South (16-way)
    [12] = 4  -- West (16-way)
}
if defines and defines.direction then
    DIRECTION_TO_INDEX[defines.direction.north] = 1
    DIRECTION_TO_INDEX[defines.direction.east]  = 2
    DIRECTION_TO_INDEX[defines.direction.south] = 3
    DIRECTION_TO_INDEX[defines.direction.west]  = 4
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

diverter_settings.get_device_id = get_device_id

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

function diverter_settings.get(unit_number)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return nil end

    storage.diverter_settings = storage.diverter_settings or {}
    if not storage.diverter_settings[dev_id] then
        storage.diverter_settings[dev_id] = {
            capacity = diverter_settings.DEFAULT_CAPACITY,
            read_red = true,
            read_green = true,
            ports = {
                [1] = {
                    enabled = true, use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input", use_filters = false, filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [2] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [3] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [4] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [5] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil }
                    }
                },
                [2] = {
                    enabled = true, use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input", use_filters = false, filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [2] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [3] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [4] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [5] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil }
                    }
                },
                [3] = {
                    enabled = true, use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input", use_filters = false, filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [2] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [3] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [4] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [5] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil }
                    }
                },
                [4] = {
                    enabled = true, use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input", use_filters = false, filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [2] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [3] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [4] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil },
                        [5] = { comparator = "Any Quality", quality = "normal", item = nil, explicit_quality = nil }
                    }
                }
            }
        }
    else
        local s = storage.diverter_settings[dev_id]
        if s.capacity == nil then s.capacity = diverter_settings.DEFAULT_CAPACITY end
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
        if s.ports then
            for i = 1, 4 do
                local p = s.ports[i]
                if p then
                    if p.enabled == nil then p.enabled = true end
                    if p.use_circuit_enable == nil then p.use_circuit_enable = false end
                    if p.use_filters == nil then p.use_filters = false end
                    if p.filter_mode == nil then p.filter_mode = "whitelist" end
                    if p.mode == nil then p.mode = "input" end
                end
            end
        end
    end
    return storage.diverter_settings[dev_id]
end

function diverter_settings.rotate_ports_by_steps(unit_number, steps)
    local dev_id = get_device_id(unit_number)
    if not dev_id or not steps then return nil end
    steps = steps % 4
    if steps == 0 then return nil end

    local settings = diverter_settings.get(dev_id)
    if not (settings and settings.ports) then return nil end

    local old_ports = settings.ports
    local new_ports = {}

    for p = 1, 4 do
        local new_p = ((p - 1 + steps) % 4) + 1
        new_ports[new_p] = old_ports[p]
        if new_ports[new_p] then
            new_ports[new_p]._compiled = nil
        end
    end

    settings.ports = new_ports
    return settings
end

function diverter_settings.rotate_ports(unit_number, previous_direction, new_direction)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and previous_direction and new_direction) then return nil end
    local old_idx = DIRECTION_TO_INDEX[previous_direction]
    local new_idx = DIRECTION_TO_INDEX[new_direction]
    if old_idx and new_idx then
        local steps = (new_idx - old_idx) % 4
        if steps ~= 0 then
            return diverter_settings.rotate_ports_by_steps(dev_id, steps)
        end
    end
    return nil
end

function diverter_settings.flip_ports(unit_number, horizontal, vertical)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return nil end
    local settings = diverter_settings.get(dev_id)
    if not (settings and settings.ports) then return nil end

    local old_ports = settings.ports
    local new_ports = {}
    for i = 1, 4 do
        new_ports[i] = old_ports[i]
    end

    if horizontal then
        new_ports[2], new_ports[4] = new_ports[4], new_ports[2]
    end

    if vertical then
        new_ports[1], new_ports[3] = new_ports[3], new_ports[1]
    end

    for i = 1, 4 do
        if new_ports[i] then
            new_ports[i]._compiled = nil
        end
    end

    settings.ports = new_ports
    return settings
end

function diverter_settings.copy(src_unit_number, dest_unit_number, src_direction, dest_direction)
    local src_id = get_device_id(src_unit_number)
    local dest_id = get_device_id(dest_unit_number)
    if not (src_id and dest_id) then return nil end
    local src = diverter_settings.get(src_id)
    if not src then return nil end

    storage.diverter_settings = storage.diverter_settings or {}
    local copy = util.table.deepcopy(src)
    if copy.ports then
        for i = 1, 4 do
            if copy.ports[i] then
                copy.ports[i]._compiled = nil
            end
        end
        if src_direction and dest_direction then
            local old_idx = DIRECTION_TO_INDEX[src_direction]
            local new_idx = DIRECTION_TO_INDEX[dest_direction]
            if old_idx and new_idx then
                local steps = (new_idx - old_idx) % 4
                if steps ~= 0 then
                    local old_ports = copy.ports
                    local new_ports = {}
                    for p = 1, 4 do
                        local new_p = ((p - 1 + steps) % 4) + 1
                        new_ports[new_p] = old_ports[p]
                    end
                    copy.ports = new_ports
                end
            end
        end
    end
    storage.diverter_settings[dest_id] = copy
    return copy
end

function diverter_settings.copy_port(unit_number, port_index)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and port_index) then return nil end
    local settings = diverter_settings.get(dev_id)
    local port = settings and settings.ports and settings.ports[port_index]
    if not port then return nil end

    local copy = util.table.deepcopy(port)
    copy._compiled = nil
    return copy
end

function diverter_settings.paste_port(unit_number, port_index, src_port_data)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and port_index and src_port_data) then return nil end
    local settings = diverter_settings.get(dev_id)
    local port = settings and settings.ports and settings.ports[port_index]
    if not port then return nil end

    local copy = util.table.deepcopy(src_port_data)
    copy._compiled = nil
    settings.ports[port_index] = copy
    return copy
end

function diverter_settings.apply_blueprint_settings(unit_number, blueprint_settings)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and blueprint_settings) then return nil end
    storage.diverter_settings = storage.diverter_settings or {}
    local copy = util.table.deepcopy(blueprint_settings)
    if copy.ports then
        for i = 1, 4 do
            if copy.ports[i] then
                copy.ports[i]._compiled = nil
            end
        end
    end
    storage.diverter_settings[dev_id] = copy
    return copy
end

function diverter_settings.get_capacity(unit_number)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return diverter_settings.DEFAULT_CAPACITY end
    local s = storage.diverter_settings and storage.diverter_settings[dev_id]
    return (s and s.capacity) or diverter_settings.DEFAULT_CAPACITY
end

function diverter_settings.get_proxy(entity)
    if not (entity and entity.valid) then return nil end
    local proxies = entity.surface.find_entities_filtered{
        name = "pneumatic-diverter-circuit-proxy",
        position = entity.position
    }
    return proxies[1]
end

function diverter_settings.evaluate_circuit_condition(proxy_entity, condition, read_red, read_green)
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

function diverter_settings.is_port_enabled(entity, port_index)
    if not (entity and entity.valid) then return false end
    local dev_id = get_device_id(entity)
    if not dev_id then return false end

    local settings = diverter_settings.get(dev_id)
    local p_setting = settings and settings.ports and settings.ports[port_index]
    if not p_setting then return false end

    if entity.name == "entity-ghost" then
        return p_setting.enabled ~= false
    end

    if p_setting.use_circuit_enable then
        local proxy = diverter_settings.get_proxy(entity)
        if not proxy then return false end
        local read_red = settings.read_red ~= false
        local read_green = settings.read_green ~= false
        return diverter_settings.evaluate_circuit_condition(proxy, p_setting.enable_condition, read_red, read_green)
    end

    return p_setting.enabled ~= false
end

return diverter_settings