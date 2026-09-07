local decider = data.raw["decider-combinator"]["decider-combinator"]
local cc = data.raw["constant-combinator"]["constant-combinator"]

local counter_icon = (decider and decider.icon) or (decider and decider.icons and decider.icons[1].icon) or "__base__/graphics/icons/decider-combinator.png"
local counter_icon_size = (decider and decider.icon_size) or (decider and decider.icons and decider.icons[1].icon_size) or 64

local counter_tint = {r = 0.30, g = 0.85, b = 0.70, a = 1.0}

-- Deepcopy decider combinator 4-way sprites and apply teal tint
local counter_pictures = table.deepcopy(decider.sprites)

local function apply_tint_to_sprite(sprite, tint)
  if not sprite then return end
  if sprite.layers then
    for _, layer in ipairs(sprite.layers) do
      if not layer.draw_as_shadow then
        layer.tint = tint
      end
    end
  elseif type(sprite) == "table" and not sprite.draw_as_shadow then
    sprite.tint = tint
  end
end

if counter_pictures then
  apply_tint_to_sprite(counter_pictures.north, counter_tint)
  apply_tint_to_sprite(counter_pictures.east, counter_tint)
  apply_tint_to_sprite(counter_pictures.south, counter_tint)
  apply_tint_to_sprite(counter_pictures.west, counter_tint)
end

local proxy = table.deepcopy(cc)

proxy.name = "pneumatic-capsule-counter-circuit-proxy"
proxy.icon = counter_icon
proxy.icon_size = counter_icon_size
proxy.flags = {
  "player-creation",
  "placeable-off-grid",
  "not-deconstructable",
  "hide-alt-info",
  "no-copy-paste"
}
proxy.placeable_by = {item = "pneumatic-capsule-counter", count = 0}
proxy.collision_box = {{0, 0}, {0, 0}}
proxy.collision_mask = {layers = {}}
proxy.selection_box = {{-0.3, -0.3}, {0.3, 0.3}}
proxy.selection_priority = 60
proxy.draw_selection_box = false
proxy.operable = true
proxy.item_slot_count = 40
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
  -- Physical main counter entity
  {
    type = "electric-energy-interface",
    name = "pneumatic-capsule-counter",
    icon = counter_icon,
    icon_size = counter_icon_size,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    rotatable = true,
    selection_priority = 50,
    minable = {mining_time = 0.3, result = "pneumatic-capsule-counter"},
    max_health = 200,
    collision_box = {{-0.4, -0.9}, {0.4, 0.9}},
    selection_box = {{-0.5, -1.0}, {0.5, 1.0}},
    fast_replaceable_group = "pneumatic-capsule-counter",
    additional_pastable_entities = {"pneumatic-capsule-counter"},
    gui_mode = "all",
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "3kJ",
      input_flow_limit = "60kW"
    },
    energy_usage = "30kW",
    pictures = counter_pictures
  },

  -- Circuit proxy combinator
  proxy
})