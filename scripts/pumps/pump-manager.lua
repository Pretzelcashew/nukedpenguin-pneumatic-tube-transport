local pump_settings = require("scripts.pumps.pump-settings")
local diverter_settings = require("scripts.diverters.diverter-settings")

local pump_manager = {}

pump_manager.spec = {
    name = "pneumatic-pump",
    entity_names = { "pneumatic-pump" },
    storage_key = "active_pumps",

    get_device_id = function(entity)
        return pump_settings.get_device_id(entity)
    end,

    get_settings = function(dev_id)
        return storage.pump_settings and storage.pump_settings[dev_id]
    end,

    clear_settings = function(dev_id)
        if storage.pump_settings then
            storage.pump_settings[dev_id] = nil
        end
    end,

    copy_settings = function(src_id, dest_id, src_dir, dest_dir)
        return pump_settings.copy(src_id, dest_id)
    end,

    is_direction_compatible = function(src_dir, target_dir)
        local g_idx = diverter_settings.get_cardinal_index(src_dir)
        local e_idx = diverter_settings.get_cardinal_index(target_dir)
        return (g_idx % 2) == (e_idx % 2)
    end,

    init_settings = function(entity)
        local dev_id = pump_settings.get_device_id(entity)
        pump_settings.get(dev_id)
    end,

    apply_blueprint_settings = function(entity_or_id, settings)
        local dev_id = (type(entity_or_id) == "table") and pump_settings.get_device_id(entity_or_id) or entity_or_id
        pump_settings.apply_blueprint_settings(dev_id, settings)
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.pump_power_states = storage.pump_power_states or {}
        storage.pump_enabled_states = storage.pump_enabled_states or {}

        local is_powered = (entity.energy > 0)
        local is_enabled = pump_settings.is_pump_enabled(entity)

        local last_power = storage.pump_power_states[unit_number]
        local last_enabled = storage.pump_enabled_states[unit_number]

        if forced or is_powered ~= last_power or is_enabled ~= last_enabled then
            storage.pump_power_states[unit_number] = is_powered
            storage.pump_enabled_states[unit_number] = is_enabled
            return true
        end
        return false
    end,

    on_unregister = function(entity, unit_number)
        if storage.pump_power_states then storage.pump_power_states[unit_number] = nil end
        if storage.pump_enabled_states then storage.pump_enabled_states[unit_number] = nil end
    end
}

function pump_manager.notify_settings_changed(entity)
    local active_device_scanner = require("scripts.active-device-scanner")
    active_device_scanner.notify_settings_changed(entity)
end

return pump_manager
