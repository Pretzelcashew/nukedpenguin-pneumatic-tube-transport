local active_device_scanner = require("scripts.active-device-scanner")

local diverter_manager = {}

function diverter_manager.notify_settings_changed(entity)
    active_device_scanner.notify_settings_changed(entity)
end

return diverter_manager