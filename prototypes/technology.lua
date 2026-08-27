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
        recipe = "crossflow-junction"
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
  },
  {
    type = "technology",
    name = "specialized-pneumatic-capsules",
    icon = "__base__/graphics/technology/logistic-system.png",
    icon_size = 256,
    prerequisites = {
      "pneumatic-transport"
    },
    effects = {
      {
        type = "unlock-recipe",
        recipe = "refrigerated-capsule"
      },
      {
        type = "unlock-recipe",
        recipe = "reinforced-capsule"
      },
      {
        type = "unlock-recipe",
        recipe = "player-transit-capsule"
      }
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 30
    },
    order = "c-a-b"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-1",
    icon = "__base__/graphics/technology/logistic-robotics.png",
    icon_size = 256,
    prerequisites = {
      "agricultural-science-pack",
      "pneumatic-transport"
    },
    effects = {
      {
        type = "unlock-recipe",
        recipe = "biodegradable-capsule"
      }
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 30
    },
    order = "c-a-c1"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-2",
    icon = "__base__/graphics/technology/logistic-robotics.png",
    icon_size = 256,
    prerequisites = {
      "bio-capsule-integrity-1"
    },
    effects = {},
    unit = {
      count = 1000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 45
    },
    order = "c-a-c2"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-3",
    icon = "__base__/graphics/technology/logistic-robotics.png",
    icon_size = 256,
    prerequisites = {
      "bio-capsule-integrity-2"
    },
    effects = {},
    unit = {
      count = 4000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 60
    },
    order = "c-a-c3"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-4",
    icon = "__base__/graphics/technology/logistic-robotics.png",
    icon_size = 256,
    prerequisites = {
      "bio-capsule-integrity-3"
    },
    effects = {},
    unit = {
      count = 16000,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 60
    },
    order = "c-a-c4"
  }
})