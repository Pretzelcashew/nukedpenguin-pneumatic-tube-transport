data:extend({
  {
    type = "item",
    name = "item-capsule",
    icon = "__base__/graphics/icons/iron-plate.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]-a[standard]",
    stack_size = 1
  },
  {
    type = "item",
    name = "biodegradable-capsule",
    icon = "__base__/graphics/icons/wood.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]-b[biodegradable]",
    stack_size = 1
  },
  {
    type = "tool",
    name = "refrigerated-capsule",
    icon = "__space-age__/graphics/icons/ice.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]-c[refrigerated]",
    stack_size = 1,
    durability = 100
  },
  {
    type = "item",
    name = "spent-refrigerated-capsule",
    icon = "__space-age__/graphics/icons/ice.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]-c[refrigerated-spent]",
    stack_size = 1
  },
  {
    type = "item",
    name = "reinforced-capsule",
    icon = "__base__/graphics/icons/steel-plate.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]-d[reinforced]",
    stack_size = 1
  },
  {
    type = "item",
    name = "player-transit-capsule",
    icon = "__base__/graphics/icons/car.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]-e[player]",
    stack_size = 1
  },
  {
    type = "item",
    name = "capsule-hub-horizontal",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    subgroup = "storage",
    order = "b[hub-horizontal]",
    stack_size = 5,
    place_result = "capsule-hub-horizontal"
  },
  {
    type = "item",
    name = "capsule-hub-vertical",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    subgroup = "storage",
    order = "b[hub-vertical]",
    stack_size = 5,
    place_result = "capsule-hub-vertical"
  },
  {
    type = "item",
    name = "pneumatic-tube",
    icon = "__base__/graphics/icons/pipe.png",
    icon_size = 64,
    subgroup = "energy-pipe-distribution",
    order = "a[pneumatic-tube]",
    stack_size = 50,
    place_result = "pneumatic-tube"
  },
  {
    type = "item",
    name = "pneumatic-pump",
    icon = "__base__/graphics/icons/pump.png",
    icon_size = 64,
    subgroup = "energy-pipe-distribution",
    order = "b[pneumatic-pump]",
    stack_size = 20,
    place_result = "pneumatic-pump"
  },
  {
    type = "item",
    name = "junction",
    icon = "__base__/graphics/icons/iron-chest.png",
    icon_size = 64,
    subgroup = "storage",
    order = "z[junction]",
    stack_size = 50,
    place_result = "junction"
  },
  {
    type = "item",
    name = "crossflow-junction",
    icon = "__base__/graphics/icons/iron-chest.png",
    icon_size = 64,
    subgroup = "storage",
    order = "z[crossflow-junction]",
    stack_size = 50,
    place_result = "crossflow-junction"
  }
})