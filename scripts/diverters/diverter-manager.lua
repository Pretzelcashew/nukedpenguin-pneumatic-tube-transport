local diverter_settings = require("scripts.diverters.diverter-settings")
local diverter_renderer = require("scripts.diverters.diverter-renderer")

local diverter_manager = {}

function diverter_manager.clear_compiled_filters(unit_number)
    local dev_id = diverter_settings.get_device_id(unit_number)
    local d_settings = dev_id and storage.diverter_settings and storage.diverter_settings[dev_id]
    if d_settings and d_settings.ports then
        for i = 1, 4 do
            if d_settings.ports[i] then
                d_settings.ports[i]._compiled = nil
            end
        end
    end
end

diverter_manager.spec = {
    name = "pneumatic-diverter",
    entity_names = { "pneumatic-diverter" },
    storage_key = "active_diverters",

    get_device_id = function(entity)
        return diverter_settings.get_device_id(entity)
    end,

    get_settings = function(dev_id)
        return storage.diverter_settings and storage.diverter_settings[dev_id]
    end,

    clear_settings = function(dev_id)
        if storage.diverter_settings then
            storage.diverter_settings[dev_id] = nil
        end
    end,

    copy_settings = function(src_id, dest_id, src_dir, dest_dir)
        return diverter_settings.copy(src_id, dest_id, src_dir, dest_dir)
    end,

    init_settings = function(entity)
        local dev_id = diverter_settings.get_device_id(entity)
        diverter_settings.get(dev_id)
    end,

    apply_blueprint_settings = function(entity_or_id, settings)
        local dev_id = (type(entity_or_id) == "table") and diverter_settings.get_device_id(entity_or_id) or entity_or_id
        diverter_settings.apply_blueprint_settings(dev_id, settings)
    end,

    on_rotate = function(entity, event)
        local dev_id = diverter_settings.get_device_id(entity)
        if event.previous_direction ~= nil then
            diverter_settings.rotate_ports(dev_id, event.previous_direction, entity.direction)
        elseif event.horizontal ~= nil or event.vertical ~= nil then
            diverter_settings.flip_ports(dev_id, event.horizontal, event.vertical)
        end
    end,

    on_rotate_delta = function(dev_id, old_dir, new_dir)
        diverter_settings.rotate_ports(dev_id, old_dir, new_dir)
    end,

    on_settings_changed = function(entity, is_ghost)
        diverter_renderer.update_render(entity)
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.diverter_power_states = storage.diverter_power_states or {}
        storage.diverter_port_states = storage.diverter_port_states or {}

        local is_powered = (entity.energy > 0)
        local last_power = storage.diverter_power_states[unit_number]
        local last_ports = storage.diverter_port_states[unit_number] or {}

        local port_changed = false
        local current_ports = {}
        for i = 1, 4 do
            local state = diverter_settings.is_port_enabled(entity, i)
            current_ports[i] = state
            if state ~= last_ports[i] then
                port_changed = true
            end
        end

        if forced or is_powered ~= last_power or port_changed then
            storage.diverter_power_states[unit_number] = is_powered
            storage.diverter_port_states[unit_number] = current_ports
            diverter_manager.clear_compiled_filters(unit_number)
            return true
        end
        return false
    end,

    on_unregister = function(entity, unit_number)
        if storage.diverter_power_states then storage.diverter_power_states[unit_number] = nil end
        if storage.diverter_port_states then storage.diverter_port_states[unit_number] = nil end
        diverter_renderer.clear_render(unit_number)
    end
}

function diverter_manager.notify_settings_changed(entity)
    local active_device_scanner = require("scripts.active-device-scanner")
    active_device_scanner.notify_settings_changed(entity)
end

return diverter_manager
