local am2 = data.raw["assembling-machine"]["assembling-machine-2"]
local cc = data.raw["constant-combinator"]["constant-combinator"]

local am2_icon = am2.icon or (am2.icons and am2.icons[1].icon)
local am2_icon_size = am2.icon_size or (am2.icons and am2.icons[1].icon_size) or 64

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
    selection_priority = 50,
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "10kJ",
      input_flow_limit = "100kW"
    },
    energy_usage = "50kW",
    gui_mode = "none",
    animation = am2.graphics_set and am2.graphics_set.animation or am2.animation
  },

  -- Hidden constant combinator proxy for circuit logic
  {
    type = "constant-combinator",
    name = "pneumatic-diverter-circuit-proxy",
    icon = am2_icon,
    icon_size = am2_icon_size,
    flags = {
      "placeable-off-grid",
      "not-on-map",
      "not-deconstructable",
      "not-blueprintable",
      "hide-alt-info",
      "not-selectable-in-game"
    },
    collision_box = {{0, 0}, {0, 0}},
    selection_priority = 0,
    item_slot_count = 10,
    circuit_wire_connection_points = cc.circuit_wire_connection_points,
    circuit_connector_sprites = cc.circuit_connector_sprites,
    circuit_wire_max_distance = cc.circuit_wire_max_distance or default_circuit_wire_max_distance
  }
})