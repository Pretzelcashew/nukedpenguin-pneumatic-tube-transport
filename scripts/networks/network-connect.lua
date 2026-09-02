local events = require("scripts.events")
local network_validate = require("scripts.networks.network-validate")

local FLOW_VERSION = settings.startup["pneumatic-flow-version"] and settings.startup["pneumatic-flow-version"].value or "v1"

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

local function handle_entity_placed(event)
    network_validate.execute(event.entity)
end

if FLOW_VERSION == "v1" then
    for _, event_id in ipairs(build_events) do
        events.on_event(event_id, handle_entity_placed)
    end
end