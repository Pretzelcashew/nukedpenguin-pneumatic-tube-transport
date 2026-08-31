local am2 = data.raw["assembling-machine"]["assembling-machine-2"]
local cc = data.raw["constant-combinator"]["constant-combinator"]

local am2_icon = am2.icon or (am2.icons and am2.icons[1].icon)
local am2_icon_size = am2.icon_size or (am2.icons and am2.icons[1].icon_size) or 64

-- Deepcopy and tint assembling-machine-2 animation (matching item icon emerald)
local diverter_animation = table.deepcopy(am2.graphics_set and am2.graphics_set.animation or am2.animation)
local diverter_tint = {r = 0.25, g = 0.80, b = 0.60, a = 1.0}

if diverter_animation and diverter_animation.layers then
  for _, layer in ipairs(diverter_animation.layers) do
    if not layer.draw_as_shadow then
      layer.tint = diverter_tint
    end
  end
elseif diverter_animation then
  diverter_animation.tint = diverter_tint
end

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

local empty_sprite = util.empty_sprite()
proxy.sprites = {
  north = empty_sprite,
  east = empty_sprite,
  south = empty_sprite,
  west = empty_sprite
}
proxy.activity_led_sprites = {
  north = empty_sprite,
  east = empty_sprite,
  south = empty_sprite,
  west = empty_sprite
}

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
    animation = diverter_animation
  },

  -- Hidden circuit proxy
  proxy
})