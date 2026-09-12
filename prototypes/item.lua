local palette = {
  -- Capsule items
  standard        = {r = 0.85, g = 0.70, b = 0.70, a = 1.0}, -- Silvery-Red
  bio             = {r = 0.40, g = 0.85, b = 0.40, a = 1.0}, -- Leaf Green
  refrigerated    = {r = 0.40, g = 0.80, b = 1.00, a = 1.0}, -- Cryo Cyan
  spent           = {r = 0.50, g = 0.55, b = 0.60, a = 1.0}, -- Dim Slate
  reinforced      = {r = 1.00, g = 0.65, b = 0.20, a = 1.0}, -- Bronze
  electromagnetic = {r = 0.85, g = 0.35, b = 0.95, a = 1.0}, -- Holmium Pink-Magenta
  vacuum          = {r = 0.30, g = 0.50, b = 0.90, a = 1.0}, -- Deep Vacuum Blue
  spent_vacuum    = {r = 0.40, g = 0.45, b = 0.55, a = 1.0}, -- Dim Vacuum Slate
  player          = {r = 0.90, g = 0.35, b = 0.85, a = 1.0}, -- Magenta

  -- Synced entity tints
  hub_h        = {r = 0.60, g = 0.80, b = 1.00, a = 1.0}, -- Light Blue (Horizontal Hub)
  hub_v        = {r = 0.40, g = 0.90, b = 0.90, a = 1.0}, -- Cyan (Vertical Hub)
  tube         = {r = 0.50, g = 0.90, b = 0.50, a = 1.0}, -- Tube Green
  pump         = {r = 1.00, g = 0.70, b = 0.30, a = 1.0}, -- Pump Orange
  junction     = {r = 1.00, g = 0.90, b = 0.30, a = 1.0}, -- Junction Yellow
  crossflow    = {r = 0.80, g = 0.40, b = 0.90, a = 1.0}, -- Crossflow Purple
  diverter     = {r = 0.25, g = 0.80, b = 0.60, a = 1.0}, -- Diverter Emerald
  counter      = {r = 0.30, g = 0.85, b = 0.70, a = 1.0}, -- Counter Teal
  projector    = {r = 0.85, g = 0.35, b = 0.95, a = 1.0}, -- Projector Magenta
}

local function icon(path, tint)
  return {{ icon = path, icon_size = 64, tint = tint }}
end

data:extend({
  -- Dedicated Inventory Tab
  {
    type = "item-group",
    name = "pneumatics",
    icon = "__base__/graphics/icons/pipe.png",
    icon_size = 64,
    order = "z-pneumatics"
  },

  -- Dedicated Subgroup Row 1: Infrastructure
  {
    type = "item-subgroup",
    name = "pneumatic-transport",
    group = "pneumatics",
    order = "a"
  },

  -- Dedicated Subgroup Row 2: Capsules
  {
    type = "item-subgroup",
    name = "pneumatic-capsules",
    group = "pneumatics",
    order = "b"
  },

  -- Infrastructure Line Items
  {
    type = "item",
    name = "pneumatic-tube",
    icons = icon("__base__/graphics/icons/pipe.png", palette.tube),
    subgroup = "pneumatic-transport",
    order = "a[tube]",
    stack_size = 50,
    place_result = "pneumatic-tube"
  },
  {
    type = "item",
    name = "pneumatic-pump",
    icons = icon("__base__/graphics/icons/pump.png", palette.pump),
    subgroup = "pneumatic-transport",
    order = "b[pump]",
    stack_size = 20,
    place_result = "pneumatic-pump"
  },
  {
    type = "item",
    name = "junction",
    icons = icon("__base__/graphics/icons/iron-chest.png", palette.junction),
    subgroup = "pneumatic-transport",
    order = "c[junction]",
    stack_size = 50,
    place_result = "junction"
  },
  {
    type = "item",
    name = "crossflow-junction",
    icons = icon("__base__/graphics/icons/iron-chest.png", palette.crossflow),
    subgroup = "pneumatic-transport",
    order = "d[crossflow-junction]",
    stack_size = 50,
    place_result = "crossflow-junction"
  },
  {
    type = "item",
    name = "pneumatic-diverter",
    icons = icon("__base__/graphics/icons/assembling-machine-2.png", palette.diverter),
    subgroup = "pneumatic-transport",
    order = "e[diverter]",
    stack_size = 10,
    place_result = "pneumatic-diverter"
  },
  {
    type = "item",
    name = "capsule-hub-horizontal",
    icons = icon("__base__/graphics/icons/steel-chest.png", palette.hub_h),
    subgroup = "pneumatic-transport",
    order = "f[hub-horizontal]",
    stack_size = 5,
    place_result = "capsule-hub-horizontal"
  },
  {
    type = "item",
    name = "capsule-hub-vertical",
    icons = icon("__base__/graphics/icons/steel-chest.png", palette.hub_v),
    subgroup = "pneumatic-transport",
    order = "g[hub-vertical]",
    stack_size = 5,
    place_result = "capsule-hub-vertical"
  },
  {
    type = "item",
    name = "pneumatic-capsule-counter",
    icons = icon("__base__/graphics/icons/decider-combinator.png", palette.counter),
    subgroup = "pneumatic-transport",
    order = "h[counter]",
    stack_size = 20,
    place_result = "pneumatic-capsule-counter"
  },
  {
    type = "item",
    name = "pneumatic-projector",
    icons = icon("__space-age__/graphics/icons/electromagnetic-plant.png", palette.projector),
    subgroup = "pneumatic-transport",
    order = "i[projector]",
    stack_size = 10,
    weight = 50 * kg,
    place_result = "pneumatic-projector"
  },
  {
    type = "item",
    name = "electromagnetic-harness",
    icons = icon("__base__/graphics/icons/discharge-defense-equipment.png", palette.electromagnetic),
    place_as_equipment_result = "electromagnetic-harness",
    subgroup = "pneumatic-transport",
    order = "j[electromagnetic-harness]",
    stack_size = 5,
    weight = 10 * kg
  },
  {
    type = "belt-immunity-equipment",
    name = "electromagnetic-harness",
    sprite = {
      filename = "__base__/graphics/equipment/discharge-defense-equipment.png",
      width = 128,
      height = 128,
      priority = "medium",
      scale = 0.5,
      tint = palette.electromagnetic
    },
    shape = {
      width = 2,
      height = 2,
      type = "full"
    },
    energy_source = {
      type = "electric",
      buffer_capacity = "2MJ",
      input_flow_limit = "1MW",
      drain = "20kW",
      usage_priority = "secondary-input"
    },
    energy_consumption = "100kW",
    categories = {"armor"}
  },

  -- Capsule Vessels Line Items (weight = 50 * kg enables 20 capsules per cargo rocket)
  {
    type = "item",
    name = "item-capsule",
    icons = icon("__base__/graphics/icons/iron-plate.png", palette.standard),
    subgroup = "pneumatic-capsules",
    order = "a[standard]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "biodegradable-capsule",
    icons = icon("__base__/graphics/icons/wood.png", palette.bio),
    subgroup = "pneumatic-capsules",
    order = "b[biodegradable]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "refrigerated-capsule",
    icons = icon("__space-age__/graphics/icons/ice.png", palette.refrigerated),
    subgroup = "pneumatic-capsules",
    order = "c[refrigerated]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "spent-refrigerated-capsule",
    icons = icon("__space-age__/graphics/icons/ice.png", palette.spent),
    subgroup = "pneumatic-capsules",
    order = "d[spent-refrigerated]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "reinforced-capsule",
    icons = icon("__base__/graphics/icons/steel-plate.png", palette.reinforced),
    subgroup = "pneumatic-capsules",
    order = "e[reinforced]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "electromagnetic-capsule",
    icons = icon("__space-age__/graphics/icons/superconductor.png", palette.electromagnetic),
    subgroup = "pneumatic-capsules",
    order = "f[electromagnetic]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "vacuum-capsule",
    icons = icon("__base__/graphics/icons/accumulator.png", palette.vacuum),
    subgroup = "pneumatic-capsules",
    order = "g[vacuum]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "spent-vacuum-capsule",
    icons = icon("__base__/graphics/icons/accumulator.png", palette.spent_vacuum),
    subgroup = "pneumatic-capsules",
    order = "h[spent-vacuum]",
    stack_size = 1,
    weight = 50 * kg
  },
  {
    type = "item",
    name = "player-transit-capsule",
    icons = icon("__base__/graphics/icons/car.png", palette.player),
    subgroup = "pneumatic-capsules",
    order = "i[player]",
    stack_size = 1,
    weight = 50 * kg
  }
})