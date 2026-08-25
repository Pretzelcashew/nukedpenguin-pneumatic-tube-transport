-- scripts/networks/network-disconnect.lua
local events = require("scripts.events")
local network_invalidate = require("scripts.networks.network-invalidate")
local hub_spill = require("scripts.hubs.hub-spill")

local removal_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}

local function handle_entity_removed(event)
    local entity = event.entity
    if entity and entity.valid then
        hub_spill.handle_entity_destruction(entity)
        network_invalidate.execute(entity)
    end
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end