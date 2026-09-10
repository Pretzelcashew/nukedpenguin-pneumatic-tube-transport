local util = require("util")

local projector_settings = {}

projector_settings.MINIMUM_ENERGY_JOULES = 3000000 -- 3 MW passive baseline (3 MJ stored)

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

local function get_cardinal_index(dir)
    if not dir then return 1 end
    if defines and defines.direction then
        if dir == defines.direction.north then return 1 end
        if dir == defines.direction.east then return 2 end
        if dir == defines.direction.south then return 3 end
        if dir == defines.direction.west then return 4 end
    end
    if dir == 0 then return 1
    elseif dir == 1 or dir == 2 or dir == 4 then return 2
    elseif dir == 3 or dir == 4 or dir == 8 then return 3
    elseif dir == 6 or dir == 12 then return 4
    end
    return ((math.floor(dir / 4)) % 4) + 1
end

projector_settings.get_cardinal_index = get_cardinal_index

local function index_to_direction(idx)
    if defines and defines.direction then
        if idx == 1 then return defines.direction.north
        elseif idx == 2 then return defines.direction.east
        elseif idx == 3 then return defines.direction.south
        elseif idx == 4 then return defines.direction.west
        end
    end
    if idx == 1 then return 0
    elseif idx == 2 then return 2
    elseif idx == 3 then return 4
    elseif idx == 4 then return 6
    end
    return 0
end

projector_settings.index_to_direction = index_to_direction

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

projector_settings.get_device_id = get_device_id

function projector_settings.get(unit_number, entity_opt)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return nil end

    storage.projector_settings = storage.projector_settings or {}
    if not storage.projector_settings[dev_id] then
        local initial_dir = defines.direction.north
        if entity_opt and entity_opt.valid and entity_opt.direction then
            initial_dir = entity_opt.direction
        elseif type(unit_number) == "table" and unit_number.valid and unit_number.direction then
            initial_dir = unit_number.direction
        end

        storage.projector_settings[dev_id] = {
            muzzle_dir = initial_dir,
            enabled = true,
            use_circuit_enable = false,
            enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
            read_red = true,
            read_green = true
        }
    else
        local s = storage.projector_settings[dev_id]
        if s.muzzle_dir == nil then
            s.muzzle_dir = defines.direction.north
        end
        if s.enabled == nil then s.enabled = true end
        if s.use_circuit_enable == nil then s.use_circuit_enable = false end
        if s.enable_condition == nil then
            s.enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        end
        if s.read_red == nil then s.read_red = true end
        if s.read_green == nil then s.read_green = true end
    end
    return storage.projector_settings[dev_id]
end

function projector_settings.rotate_muzzle_by_steps(unit_number, steps)
    local dev_id = get_device_id(unit_number)
    if not dev_id or not steps then return nil end
    steps = steps % 4
    if steps == 0 then return nil end

    local settings = projector_settings.get(dev_id)
    if not settings then return nil end

    local current_idx = get_cardinal_index(settings.muzzle_dir)
    local new_idx = ((current_idx - 1 + steps) % 4) + 1
    settings.muzzle_dir = index_to_direction(new_idx)
    return settings
end

function projector_settings.rotate_muzzle(unit_number, previous_direction, new_direction)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and previous_direction and new_direction) then return nil end
    local old_idx = get_cardinal_index(previous_direction)
    local new_idx = get_cardinal_index(new_direction)
    if old_idx and new_idx then
        local steps = (new_idx - old_idx) % 4
        if steps ~= 0 then
            return projector_settings.rotate_muzzle_by_steps(dev_id, steps)
        end
    end
    return nil
end

function projector_settings.set_muzzle_direction(unit_number, direction)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and direction) then return nil end
    local settings = projector_settings.get(dev_id)
    if not settings then return nil end
    settings.muzzle_dir = direction
    return settings
end

function projector_settings.copy(src_unit_number, dest_unit_number, src_direction, dest_direction)
    local src_id = get_device_id(src_unit_number)
    local dest_id = get_device_id(dest_unit_number)
    if not (src_id and dest_id) then return nil end
    local src = storage.projector_settings and storage.projector_settings[src_id]
    if not src then return nil end

    storage.projector_settings = storage.projector_settings or {}
    local copy = util.table.deepcopy(src)

    if src_direction and dest_direction then
        local old_idx = get_cardinal_index(src_direction)
        local new_idx = get_cardinal_index(dest_direction)
        if old_idx and new_idx then
            local steps = (new_idx - old_idx) % 4
            if steps ~= 0 then
                local cur_idx = get_cardinal_index(copy.muzzle_dir)
                local rotated_idx = ((cur_idx - 1 + steps) % 4) + 1
                copy.muzzle_dir = index_to_direction(rotated_idx)
            end
        end
    end

    storage.projector_settings[dest_id] = copy
    return copy
end

function projector_settings.apply_blueprint_settings(unit_number, blueprint_settings)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and blueprint_settings) then return nil end
    storage.projector_settings = storage.projector_settings or {}
    local copy = util.table.deepcopy(blueprint_settings)
    storage.projector_settings[dev_id] = copy
    return copy
end

function projector_settings.get_proxy(entity)
    if not (entity and entity.valid) then return nil end
    local proxies = entity.surface.find_entities_filtered{
        name = "pneumatic-projector-circuit-proxy",
        position = entity.position
    }
    return proxies[1]
end

function projector_settings.evaluate_circuit_condition(proxy_entity, condition, read_red, read_green)
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

function projector_settings.is_projector_enabled(entity)
    if not (entity and entity.valid) then return false end
    local dev_id = get_device_id(entity)
    if not dev_id then return false end

    local settings = projector_settings.get(dev_id, entity)
    if not settings then return false end

    if entity.name == "entity-ghost" then
        return settings.enabled ~= false
    end

    if settings.use_circuit_enable then
        local proxy = projector_settings.get_proxy(entity)
        if not proxy then return false end
        local read_red = settings.read_red ~= false
        local read_green = settings.read_green ~= false
        return projector_settings.evaluate_circuit_condition(proxy, settings.enable_condition, read_red, read_green)
    end

    return settings.enabled ~= false
end

function projector_settings.is_powered(entity)
    if not (entity and entity.valid) then return false end
    if entity.name == "entity-ghost" then return false end
    return entity.energy >= projector_settings.MINIMUM_ENERGY_JOULES
end

function projector_settings.is_projector_active(entity)
    return projector_settings.is_powered(entity) and projector_settings.is_projector_enabled(entity)
end

return projector_settings