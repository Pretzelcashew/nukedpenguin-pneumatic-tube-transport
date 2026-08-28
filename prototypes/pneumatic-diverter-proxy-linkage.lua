local events = require("scripts.events")

local DIVERTER_NAME = "pneumatic-diverter"
local PROXY_NAME = "pneumatic-diverter-circuit-proxy"

local function on_created(event)
  local entity = event.entity or event.created_entity
  if entity and entity.valid and entity.name == DIVERTER_NAME then
    local proxy = entity.surface.create_entity{
      name = PROXY_NAME,
      position = entity.position,
      force = entity.force
    }
    if proxy then
      proxy.destructible = false
      proxy.operable = false
    end
  end
end

local function on_removed(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == DIVERTER_NAME then
    local proxies = entity.surface.find_entities_filtered{
      name = PROXY_NAME,
      position = entity.position
    }
    for _, proxy in ipairs(proxies) do
      proxy.destroy()
    end
  end
end

local function on_gui_opened(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == DIVERTER_NAME then
    local player = game.get_player(event.player_index)
    if player then
      -- Synchronously close the vanilla energy window before rendering
      player.opened = nil

      -- Open your custom GUI frame here:
      -- build_diverter_gui(player, entity)
    end
  end
end

-- Creation Listeners
events.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}, on_created)

-- Removal Listeners
events.on_event({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy
}, on_removed)

-- GUI Override Listener
events.on_event(defines.events.on_gui_opened, on_gui_opened)