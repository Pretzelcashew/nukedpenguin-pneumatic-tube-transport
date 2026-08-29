local cc = data.raw["constant-combinator"]["constant-combinator"]
local pump = data.raw["electric-energy-interface"]["pneumatic-pump"]

local pump_icon = (pump and pump.icon) or "__base__/graphics/icons/pump.png"
local pump_icon_size = (pump and pump.icon_size) or 64

local proxy = table.deepcopy(cc)

proxy.name = "pneumatic-pump-circuit-proxy"
proxy.icon = pump_icon
proxy.icon_size = pump_icon_size
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
  proxy
})