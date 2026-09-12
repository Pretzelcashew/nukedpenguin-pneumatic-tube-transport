local flow_engine = require("scripts.flow.flow-engine")
local capsule_runner = require("scripts.capsules.capsule-runner")
local projector_settings = require("scripts.projectors.projector-settings")

local projector_manager = {}

projector_manager.spec = {
    name = "pneumatic-projector",
    entity_names = { "pneumatic-projector" },
    storage_key = "active_projectors",

    get_device_id = function(entity)
        return projector_settings.get_device_id(entity)
    end,

    get_settings = function(dev_id)
        return storage.projector_settings and storage.projector_settings[dev_id]
    end,

    clear_settings = function(dev_id)
        if storage.projector_settings then
            storage.projector_settings[dev_id] = nil
        end
    end,

    copy_settings = function(src_id, dest_id, src_dir, dest_dir)
        return projector_settings.copy(src_id, dest_id, src_dir, dest_dir)
    end,

    init_settings = function(entity)
        local dev_id = projector_settings.get_device_id(entity)
        projector_settings.get(dev_id, entity)
    end,

    apply_blueprint_settings = function(entity_or_id, settings)
        local dev_id = (type(entity_or_id) == "table") and projector_settings.get_device_id(entity_or_id) or entity_or_id
        projector_settings.apply_blueprint_settings(dev_id, settings)
    end,

    on_rotate = function(entity, event)
        local dev_id = projector_settings.get_device_id(entity)
        if event.previous_direction ~= nil then
            projector_settings.rotate_muzzle(dev_id, event.previous_direction, entity.direction)
        end
    end,

    on_rotate_delta = function(dev_id, old_dir, new_dir)
        projector_settings.rotate_muzzle(dev_id, old_dir, new_dir)
    end,

    check_and_update_state = function(entity, forced)
        local unit_number = entity.unit_number
        storage.projector_power_states = storage.projector_power_states or {}
        storage.projector_enabled_states = storage.projector_enabled_states or {}
        storage.projector_muzzle_states = storage.projector_muzzle_states or {}
        storage.projector_ready_states = storage.projector_ready_states or {}

        local is_powered = projector_settings.is_powered(entity)
        local is_enabled = projector_settings.is_projector_enabled(entity)
        local is_ready = projector_settings.can_fire(entity)

        local dev_id = projector_settings.get_device_id(entity)
        local p_set = projector_settings.get(dev_id, entity)
        local current_muzzle = p_set and p_set.muzzle_dir or entity.direction

        local last_power = storage.projector_power_states[unit_number]
        local last_enabled = storage.projector_enabled_states[unit_number]
        local last_muzzle = storage.projector_muzzle_states[unit_number]
        local last_ready = storage.projector_ready_states[unit_number]

        local muzzle_changed = (current_muzzle ~= last_muzzle)
        local ready_changed = (is_ready ~= last_ready)

        if forced or is_powered ~= last_power or is_enabled ~= last_enabled or muzzle_changed or ready_changed then
            storage.projector_power_states[unit_number] = is_powered
            storage.projector_enabled_states[unit_number] = is_enabled
            storage.projector_muzzle_states[unit_number] = current_muzzle
            storage.projector_ready_states[unit_number] = is_ready

            if muzzle_changed and entity.valid and not (entity.name == "entity-ghost") then
                flow_engine.notify_beam_obstruction_changed(entity, true)

                -- Free and wake any incoming beam endpoints that were targeting this machine's old orientation
                for pkey, fn in pairs(storage.flow_nodes or {}) do
                    if fn and fn.hit_receiver == unit_number then
                        fn.is_endpoint = false
                        fn.hit_receiver = nil
                        flow_engine.enqueue_port(pkey)
                        capsule_runner.wake_parked_capsules(pkey)
                    end
                end

                flow_engine.disconnect_entity(entity)
                flow_engine.connect_entity(entity)
                flow_engine.notify_beam_obstruction_changed(entity, false)
            end

            return true
        end
        return false
    end,

    on_unregister = function(entity, unit_number)
        if storage.projector_power_states then storage.projector_power_states[unit_number] = nil end
        if storage.projector_enabled_states then storage.projector_enabled_states[unit_number] = nil end
        if storage.projector_muzzle_states then storage.projector_muzzle_states[unit_number] = nil end
        if storage.projector_ready_states then storage.projector_ready_states[unit_number] = nil end
        if storage.projector_last_fired then storage.projector_last_fired[unit_number] = nil end
    end
}

function projector_manager.notify_settings_changed(entity)
    local active_device_scanner = require("scripts.active-device-scanner")
    active_device_scanner.notify_settings_changed(entity)
end

return projector_manager
