local cc = data.raw["constant-combinator"]["constant-combinator"]
local em_plant = data.raw["assembling-machine"]["electromagnetic-plant"]

local projector_tint = {r = 0.85, g = 0.35, b = 0.95, a = 1.0}
local scale_factor = 0.75 -- Scale from 4x4 down to 3x3 footprint (3 / 4)

local projector_icon = (em_plant and em_plant.icon) or "__space-age__/graphics/icons/electromagnetic-plant.png"
local projector_icon_size = (em_plant and em_plant.icon_size) or 64

local empty_sprite = util.empty_sprite()

-- Deepcopy and scale/tint sprite or animation layers from Electromagnetic Plant
local function scale_and_tint_layers(anim, scale_mult, tint)
  if not anim then return nil end
  local copy = table.deepcopy(anim)

  local function process_layer(layer)
    if not layer or type(layer) ~= "table" then return end
    layer.scale = (layer.scale or 1) * scale_mult
    if layer.shift then
      layer.shift = {layer.shift[1] * scale_mult, layer.shift[2] * scale_mult}
    end
    if tint and not layer.draw_as_shadow then
      layer.tint = tint
    end
  end

  local function walk(obj)
    if not obj or type(obj) ~= "table" then return end
    if obj.layers then
      for _, layer in ipairs(obj.layers) do
        process_layer(layer)
      end
    elseif obj.filename or obj.filenames or obj.stripes then
      process_layer(obj)
    else
      if obj.north or obj.east or obj.south or obj.west then
        walk(obj.north)
        walk(obj.east)
        walk(obj.south)
        walk(obj.west)
      end
    end
  end

  walk(copy)
  return copy
end

-- Resolve base graphics composite from Space Age electromagnetic plant
local em_graphics = em_plant and em_plant.graphics_set
local base_anim = em_graphics and (em_graphics.animation or em_graphics.idle_animation)
local scaled_anim = scale_and_tint_layers(base_anim, scale_factor, projector_tint)

local projector_animations = nil
local projector_animation = nil

if scaled_anim then
  if scaled_anim.north or scaled_anim.east or scaled_anim.south or scaled_anim.west then
    projector_animations = scaled_anim
  else
    projector_animations = {
      north = scaled_anim,
      east = table.deepcopy(scaled_anim),
      south = table.deepcopy(scaled_anim),
      west = table.deepcopy(scaled_anim)
    }
  end
else
  -- Fallback sprite if graphics_set was unavailable
  local fallback_picture = {
    filename = "__space-age__/graphics/entity/electromagnetic-plant/electromagnetic-plant.png",
    width = 256,
    height = 256,
    scale = 0.5 * scale_factor,
    tint = projector_tint
  }
  projector_animations = {
    north = fallback_picture,
    east = fallback_picture,
    south = fallback_picture,
    west = fallback_picture
  }
end

-- Circuit proxy prototype (operable = true, selection_priority = 60 for wire tool targeting)
local proxy = table.deepcopy(cc)
proxy.name = "pneumatic-projector-circuit-proxy"
proxy.icon = projector_icon
proxy.icon_size = projector_icon_size
proxy.flags = {
  "player-creation",
  "placeable-off-grid",
  "not-deconstructable",
  "hide-alt-info",
  "no-copy-paste"
}
proxy.placeable_by = {item = "pneumatic-projector", count = 0}
proxy.collision_box = {{0, 0}, {0, 0}}
proxy.collision_mask = {layers = {}}
proxy.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
proxy.selection_priority = 60
proxy.draw_selection_box = false
proxy.operable = true
proxy.item_slot_count = 40
proxy.minable = nil
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
  -- Physical main projector entity (3x3 footprint)
  {
    type = "electric-energy-interface",
    name = "pneumatic-projector",
    icons = {
      {
        icon = projector_icon,
        icon_size = projector_icon_size,
        tint = projector_tint
      }
    },
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    rotatable = true,
    selection_priority = 50,
    minable = {mining_time = 0.5, result = "pneumatic-projector"},
    max_health = 500,
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    fast_replaceable_group = "pneumatic-projector",
    additional_pastable_entities = {"pneumatic-projector"},
    gui_mode = "all",
    continuous_animation = true,
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "9MJ",
      input_flow_limit = "9MW",
      drain = "3MW"
    },
    energy_usage = "3MW",
    animations = projector_animations,
    open_sound = em_plant and em_plant.open_sound,
    close_sound = em_plant and em_plant.close_sound,
    working_sound = em_plant and em_plant.working_sound
  },

  -- Proxy entity
  proxy
})