local counter_settings = require("scripts.counters.counter-settings")
local counter_logic = require("scripts.counters.counter-logic")
local counter_range = require("scripts.counters.counter-range")

local counter_manager = {}

counter_manager.spec = {
    name = "pneumatic-capsule-counter",
    entity_names = { "pneumatic-capsule-counter" },
    storage_key = "active_counters",

    get_device_id = function(entity)
        return counter_settings.get_device_id(entity)
    end,

    get_settings = function(dev_id)
        return storage.counter_settings and storage.counter_settings[dev_id]
    end,

    clear_settings = function(dev_id)
        if storage.counter_settings then
            storage.counter_settings[dev_id] = nil
        end
    end,

    copy_settings = function(src_id, dest_id, src_dir, dest_dir)
        return counter_settings.copy(src_id, dest_id)
    end,

    init_settings = function(entity)
        local dev_id = counter_settings.get_device_id(entity)
        counter_settings.get(dev_id)
    end,

    apply_blueprint_settings = function(entity_or_id, settings)
        local dev_id = (type(entity_or_id) == "table") and counter_settings.get_device_id(entity_or_id) or entity_or_id
        counter_settings.apply_blueprint_settings(dev_id, settings)
    end,

    on_settings_changed = function(entity, is_ghost)
        if not is_ghost then
            counter_logic.update_signals(entity)
        end
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.counter_power_states = storage.counter_power_states or {}

        local is_powered = (entity.energy > 0)
        local last_power = storage.counter_power_states[unit_number]

        if forced or is_powered ~= last_power then
            storage.counter_power_states[unit_number] = is_powered
            counter_logic.update_signals(entity)
            return true
        end
        return false
    end,

    on_scan = function(entity)
        counter_logic.update_signals(entity)
    end,

    on_unregister = function(entity, unit_number)
        if storage.counter_power_states then storage.counter_power_states[unit_number] = nil end
        counter_range.unregister_counter(unit_number)
    end
}

function counter_manager.notify_settings_changed(entity)
    local active_device_scanner = require("scripts.active-device-scanner")
    active_device_scanner.notify_settings_changed(entity)
end

return counter_manager
