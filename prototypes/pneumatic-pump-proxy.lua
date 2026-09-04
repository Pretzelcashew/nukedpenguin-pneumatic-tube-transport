local cc = data.raw["constant-combinator"]["constant-combinator"]
local pump = data.raw["electric-energy-interface"]["pneumatic-pump"]

local pump_icon = (pump and pump.icon) or "__base__/graphics/icons/pump.png"
local pump_icon_size = (pump and pump.icon_size) or 64

local proxy = table.deepcopy(cc)

proxy.name = "pneumatic-pump-circuit-proxy"
proxy.icon = pump_icon
proxy.icon_size = pump_icon_size
proxy.flags = {
  "player-creation",
  "placeable-off-grid",
  "not-deconstructable",
  "hide-alt-info",
  "no-copy-paste"
}
proxy.placeable_by = {item = "pneumatic-pump", count = 0}
proxy.collision_box = {{0, 0}, {0, 0}}
proxy.collision_mask = {layers = {}}
proxy.selection_box = {{-0.3, -0.3}, {0.3, 0.3}}
proxy.selection_priority = 0
proxy.draw_selection_box = false
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
  proxy
})