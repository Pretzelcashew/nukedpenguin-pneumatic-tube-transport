-- scripts/networks/network-disconnect.lua
local events = require("scripts.events")
local network_invalidate = require("scripts.networks.network-invalidate")

local removal_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}

local function handle_entity_removed(event)
    network_invalidate.execute(event.entity)
end

for _, event_id in ipairs(removal_events) do
    events.on_event(event_id, handle_entity_removed)
end