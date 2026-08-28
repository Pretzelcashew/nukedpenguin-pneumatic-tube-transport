local am2 = data.raw["assembling-machine"]["assembling-machine-2"]
local cc = data.raw["constant-combinator"]["constant-combinator"]

local am2_icon = am2.icon or (am2.icons and am2.icons[1].icon)
local am2_icon_size = am2.icon_size or (am2.icons and am2.icons[1].icon_size) or 64

-- Clone constant-combinator so the circuit proxy inherits all required LED/sprite structures
local proxy = table.deepcopy(cc)

proxy.name = "pneumatic-diverter-circuit-proxy"
proxy.icon = am2_icon
proxy.icon_size = am2_icon_size
proxy.flags = {
  "placeable-off-grid",
  "not-on-map",
  "not-deconstructable",
  "not-blueprintable",
  "hide-alt-info",
  "not-selectable-in-game"
}
proxy.collision_box = {{0, 0}, {0, 0}}
proxy.selection_priority = 0
proxy.item_slot_count = 10
proxy.minable = nil

data:extend({
  -- Physical machine (Power & Graphics)
  {
    type = "electric-energy-interface",
    name = "pneumatic-diverter",
    icon = am2_icon,
    icon_size = am2_icon_size,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.3, result = "pneumatic-diverter"},
    max_health = 250,
    collision_box = am2.collision_box,
    selection_box = am2.selection_box,
    gui_mode = "all", -- Kept operable so left-click / 'E' fires on_gui_opened
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "10kJ",
      input_flow_limit = "100kW"
    },
    energy_usage = "50kW",
    animation = am2.graphics_set and am2.graphics_set.animation or am2.animation
  },

  -- Hidden circuit proxy
  proxy
})