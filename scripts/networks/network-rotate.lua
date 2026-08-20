-- scripts/networks/network-rotate.lua
local events = require("scripts.events")
local network_invalidate = require("scripts.networks.network-invalidate")
local network_validate = require("scripts.networks.network-validate")

-- Group all orientation-altering events here
local update_events = {
    defines.events.on_player_rotated_entity,
    defines.events.on_player_flipped_entity
}

local function handle_entity_orientation_changed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    -- 1. Sever all old connections tied to the previous physical state
    network_invalidate.execute(entity)
    
    -- 2. Scan space and re-establish connections for the new orientation
    network_validate.execute(entity)
end

-- Hook into Factorio's event bus
for _, event_id in ipairs(update_events) do
    events.on_event(event_id, handle_entity_orientation_changed)
end