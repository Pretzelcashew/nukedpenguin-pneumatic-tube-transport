local palette = {
  -- Capsule items
  standard     = {r = 0.85, g = 0.70, b = 0.70, a = 1.0}, -- Silvery-Red
  bio          = {r = 0.40, g = 0.85, b = 0.40, a = 1.0}, -- Leaf Green
  refrigerated = {r = 0.40, g = 0.80, b = 1.00, a = 1.0}, -- Cryo Cyan
  spent        = {r = 0.50, g = 0.55, b = 0.60, a = 1.0}, -- Dim Slate
  reinforced   = {r = 1.00, g = 0.65, b = 0.20, a = 1.0}, -- Bronze
  player       = {r = 0.90, g = 0.35, b = 0.85, a = 1.0}, -- Magenta

  -- Synced entity tints
  hub_h        = {r = 0.60, g = 0.80, b = 1.00, a = 1.0}, -- Light Blue (Horizontal Hub)
  hub_v        = {r = 0.40, g = 0.90, b = 0.90, a = 1.0}, -- Cyan (Vertical Hub)
  tube         = {r = 0.50, g = 0.90, b = 0.50, a = 1.0}, -- Tube Green
  pump         = {r = 1.00, g = 0.70, b = 0.30, a = 1.0}, -- Pump Orange
  junction     = {r = 1.00, g = 0.90, b = 0.30, a = 1.0}, -- Junction Yellow
  crossflow    = {r = 0.80, g = 0.40, b = 0.90, a = 1.0}, -- Crossflow Purple
  diverter     = {r = 0.25, g = 0.80, b = 0.60, a = 1.0}, -- Diverter Emerald
}

local function icon(path, tint)
  return {{ icon = path, icon_size = 64, tint = tint }}
end

data:extend({
  {
    type = "item",
    name = "item-capsule",
    icons = icon("__base__/graphics/icons/iron-plate.png", palette.standard),
    subgroup = "intermediate-product",
    order = "a[capsule]-a[standard]",
    stack_size = 1
  },
  {
    type = "item",
    name = "biodegradable-capsule",
    icons = icon("__base__/graphics/icons/wood.png", palette.bio),
    subgroup = "intermediate-product",
    order = "a[capsule]-b[biodegradable]",
    stack_size = 1
  },
  {
    type = "tool",
    name = "refrigerated-capsule",
    icons = icon("__space-age__/graphics/icons/ice.png", palette.refrigerated),
    subgroup = "intermediate-product",
    order = "a[capsule]-c[refrigerated]",
    stack_size = 1,
    durability = 100
  },
  {
    type = "item",
    name = "spent-refrigerated-capsule",
    icons = icon("__space-age__/graphics/icons/ice.png", palette.spent),
    subgroup = "intermediate-product",
    order = "a[capsule]-c[refrigerated-spent]",
    stack_size = 1
  },
  {
    type = "item",
    name = "reinforced-capsule",
    icons = icon("__base__/graphics/icons/steel-plate.png", palette.reinforced),
    subgroup = "intermediate-product",
    order = "a[capsule]-d[reinforced]",
    stack_size = 1
  },
  {
    type = "item",
    name = "player-transit-capsule",
    icons = icon("__base__/graphics/icons/car.png", palette.player),
    subgroup = "intermediate-product",
    order = "a[capsule]-e[player]",
    stack_size = 1
  },
  {
    type = "item",
    name = "capsule-hub-horizontal",
    icons = icon("__base__/graphics/icons/steel-chest.png", palette.hub_h),
    subgroup = "storage",
    order = "b[hub-horizontal]",
    stack_size = 5,
    place_result = "capsule-hub-horizontal"
  },
  {
    type = "item",
    name = "capsule-hub-vertical",
    icons = icon("__base__/graphics/icons/steel-chest.png", palette.hub_v),
    subgroup = "storage",
    order = "b[hub-vertical]",
    stack_size = 5,
    place_result = "capsule-hub-vertical"
  },
  {
    type = "item",
    name = "pneumatic-tube",
    icons = icon("__base__/graphics/icons/pipe.png", palette.tube),
    subgroup = "energy-pipe-distribution",
    order = "a[pneumatic-tube]",
    stack_size = 50,
    place_result = "pneumatic-tube"
  },
  {
    type = "item",
    name = "pneumatic-pump",
    icons = icon("__base__/graphics/icons/pump.png", palette.pump),
    subgroup = "energy-pipe-distribution",
    order = "b[pneumatic-pump]",
    stack_size = 20,
    place_result = "pneumatic-pump"
  },
  {
    type = "item",
    name = "junction",
    icons = icon("__base__/graphics/icons/iron-chest.png", palette.junction),
    subgroup = "storage",
    order = "z[junction]",
    stack_size = 50,
    place_result = "junction"
  },
  {
    type = "item",
    name = "crossflow-junction",
    icons = icon("__base__/graphics/icons/iron-chest.png", palette.crossflow),
    subgroup = "storage",
    order = "z[crossflow-junction]",
    stack_size = 50,
    place_result = "crossflow-junction"
  },
  {
    type = "item",
    name = "pneumatic-diverter",
    icons = icon("__base__/graphics/icons/assembling-machine-2.png", palette.diverter),
    subgroup = "storage",
    order = "z[pneumatic-diverter]",
    stack_size = 10,
    place_result = "pneumatic-diverter"
  }
})