local diverter_settings = {}

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
    storage.diverter_settings = storage.diverter_settings or {}
    if not storage.diverter_settings[unit_number] then
        storage.diverter_settings[unit_number] = {
            read_red = true,
            read_green = true,
            ports = {
                [1] = { -- Port 1: North
                    enabled = true,
                    use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                },
                [2] = { -- Port 2: East
                    enabled = true,
                    use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                },
                [3] = { -- Port 3: South
                    enabled = true,
                    use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                },
                [4] = { -- Port 4: West
                    enabled = true,
                    use_circuit_enable = false,
                    enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                }
            }
        }
    else
        local s = storage.diverter_settings[unit_number]
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
        if s.ports then
            for i = 1, 4 do
                local p = s.ports[i]
                if p then
                    if p.use_circuit_enable == nil then p.use_circuit_enable = false end
                    if p.enable_condition == nil then
                        p.enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
                    end
                end
            end
        end
    end
    return storage.diverter_settings[unit_number]
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
    if not (entity and entity.valid and entity.unit_number) then return false end
    local settings = diverter_settings.get(entity.unit_number)
    local p_setting = settings and settings.ports and settings.ports[port_index]
    if not p_setting then return false end

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