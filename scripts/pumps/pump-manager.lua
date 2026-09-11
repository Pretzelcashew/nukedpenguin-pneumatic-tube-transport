local active_device_scanner = require("scripts.active-device-scanner")

local pump_manager = {}

function pump_manager.notify_settings_changed(entity)
    active_device_scanner.notify_settings_changed(entity)
end

return pump_manager