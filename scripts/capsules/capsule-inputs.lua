local events = require("scripts.events")
local capsule_runner = require("scripts.capsules.capsule-runner")

events.on_event("capsule-emergency-exit", function(event)
    local player = game.get_player(event.player_index)
    if player and player.valid then
        capsule_runner.emergency_eject(player)
    end
end)