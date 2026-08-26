-- prototypes/technology.lua

data:extend({
  {
    type = "technology",
    name = "pneumatic-transport",
    icon = "__base__/graphics/technology/logistic-robotics.png",
    icon_size = 256,
    prerequisites = {
      "advanced-circuit",
      "fluid-handling",
      "logistics-2"
    },
    effects = {
      {
        type = "unlock-recipe",
        recipe = "pneumatic-tube"
      },
      {
        type = "unlock-recipe",
        recipe = "junction"
      },
      {
        type = "unlock-recipe",
        recipe = "pneumatic-pump"
      },
      {
        type = "unlock-recipe",
        recipe = "capsule-hub-horizontal"
      },
      {
        type = "unlock-recipe",
        recipe = "capsule-hub-vertical"
      },
      {
        type = "unlock-recipe",
        recipe = "item-capsule"
      }
    },
    unit = {
      count = 350,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 45
    },
    order = "c-a-a"
  }
})