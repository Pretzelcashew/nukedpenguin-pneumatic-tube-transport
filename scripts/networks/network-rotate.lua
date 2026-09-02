local events = require("scripts.events")
local network_invalidate = require("scripts.networks.network-invalidate")
local network_validate = require("scripts.networks.network-validate")
local pump_manager = require("scripts.networks.pump-manager")
local diverter_manager = require("scripts.networks.diverter-manager")

local FLOW_VERSION = settings.startup["pneumatic-flow-version"] and settings.startup["pneumatic-flow-version"].value or "v1"

-- Group all orientation-altering events here
local update_events = {
    defines.events.on_player_rotated_entity,
    defines.events.on_player_flipped_entity
}

local function handle_entity_orientation_changed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    if FLOW_VERSION == "v1" then
        -- 1. Sever all old connections tied to the previous physical state
        network_invalidate.execute(entity)
        
        -- 2. Scan space and re-establish connections for the new orientation
        network_validate.execute(entity)
    end

    -- 3. Synchronize power/port state caches and trigger targeted flow map rebuilds
    if entity.name == "pneumatic-pump" then
        pump_manager.notify_settings_changed(entity)
    elseif entity.name == "pneumatic-diverter" then
        diverter_manager.notify_settings_changed(entity)
    end
end

-- Hook into Factorio's event bus
for _, event_id in ipairs(update_events) do
    events.on_event(event_id, handle_entity_orientation_changed)
end