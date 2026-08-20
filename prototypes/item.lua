data:extend({
  {
    type = "item",
    name = "item-capsule",
    icon = "__base__/graphics/icons/iron-plate.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "a[capsule]",
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
  }
})