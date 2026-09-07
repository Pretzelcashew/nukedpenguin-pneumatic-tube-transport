local util = require("util")

local counter_settings = {}

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

counter_settings.get_device_id = get_device_id

function counter_settings.get(unit_number)
    local dev_id = get_device_id(unit_number)
    if not dev_id then return nil end

    storage.counter_settings = storage.counter_settings or {}
    if not storage.counter_settings[dev_id] then
        storage.counter_settings[dev_id] = {
            vessels_target = "green",
            cargo_target = "red",
            total_target = "green",
            total_signal = { type = "virtual", name = "signal-C" }
        }
    else
        local s = storage.counter_settings[dev_id]
        if s.vessels_target == nil then s.vessels_target = "green" end
        if s.cargo_target == nil then s.cargo_target = "red" end
        if s.total_target == nil then s.total_target = "green" end
        if s.total_signal == nil then
            s.total_signal = { type = "virtual", name = "signal-C" }
        end
    end
    return storage.counter_settings[dev_id]
end

function counter_settings.copy(src_unit_number, dest_unit_number)
    local src_id = get_device_id(src_unit_number)
    local dest_id = get_device_id(dest_unit_number)
    if not (src_id and dest_id) then return nil end
    local src = storage.counter_settings and storage.counter_settings[src_id]
    if not src then return nil end

    storage.counter_settings = storage.counter_settings or {}
    local copy = util.table.deepcopy(src)
    storage.counter_settings[dest_id] = copy
    return copy
end

function counter_settings.apply_blueprint_settings(unit_number, blueprint_settings)
    local dev_id = get_device_id(unit_number)
    if not (dev_id and blueprint_settings) then return nil end
    storage.counter_settings = storage.counter_settings or {}
    local copy = util.table.deepcopy(blueprint_settings)
    if copy.vessels_target == nil then copy.vessels_target = "green" end
    if copy.cargo_target == nil then copy.cargo_target = "red" end
    if copy.total_target == nil then copy.total_target = "green" end
    if copy.total_signal == nil then
        copy.total_signal = { type = "virtual", name = "signal-C" }
    end
    storage.counter_settings[dev_id] = copy
    return copy
end

function counter_settings.get_proxy(entity)
    if not (entity and entity.valid) then return nil end
    local proxies = entity.surface.find_entities_filtered{
        name = "pneumatic-capsule-counter-circuit-proxy",
        position = entity.position
    }
    return proxies[1]
end

return counter_settings