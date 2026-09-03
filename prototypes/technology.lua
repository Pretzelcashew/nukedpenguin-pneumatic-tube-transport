local palette = {
  transport   = {r = 0.40, g = 0.70, b = 0.90, a = 1.0}, -- Pressure Cyan
  specialized = {r = 0.85, g = 0.45, b = 0.95, a = 1.0}, -- Advanced Purple
  bio         = {r = 0.40, g = 0.85, b = 0.40, a = 1.0}, -- Leaf Green
  reinforced  = {r = 1.00, g = 0.65, b = 0.20, a = 1.0}, -- Bronze
  refrigerated= {r = 0.40, g = 0.80, b = 1.00, a = 1.0}, -- Cryo Cyan
  bio_1       = {r = 0.65, g = 0.85, b = 0.45, a = 1.0}, -- Soft Sprout Green
  bio_2       = {r = 0.45, g = 0.85, b = 0.35, a = 1.0}, -- Leaf Green
  bio_3       = {r = 0.25, g = 0.85, b = 0.25, a = 1.0}, -- Forest Green
  bio_4       = {r = 0.10, g = 0.90, b = 0.45, a = 1.0}, -- Radiant Emerald
}

local function tech_icon(path, tint, size)
  return {{ icon = path, icon_size = size or 256, tint = tint }}
end

data:extend({
  -- Base Pneumatic Infrastructure Tech
  {
    type = "technology",
    name = "pneumatic-transport",
    icons = tech_icon("__base__/graphics/technology/logistic-system.png", palette.transport),
    prerequisites = {
      "steel-processing",
      "plastics",
      "engine",
      "advanced-circuit"
    },
    unit = {
      count = 150,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      },
      time = 30
    },
    effects = {
      { type = "unlock-recipe", recipe = "item-capsule" },
      { type = "unlock-recipe", recipe = "capsule-hub-horizontal" },
      { type = "unlock-recipe", recipe = "capsule-hub-vertical" },
      { type = "unlock-recipe", recipe = "pneumatic-tube" },
      { type = "unlock-recipe", recipe = "pneumatic-pump" },
      { type = "unlock-recipe", recipe = "junction" }
    },
    order = "c-a[pneumatic-transport]"
  },

  -- Advanced Pneumatic Infrastructure Tech
  {
    type = "technology",
    name = "specialized-pneumatic-capsules",
    icons = tech_icon("__base__/graphics/technology/plastics.png", palette.specialized),
    prerequisites = {
      "pneumatic-transport",
      "chemical-science-pack",
      "engine",
      "advanced-circuit",
      "low-density-structure"
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 45
    },
    effects = {
      { type = "unlock-recipe", recipe = "pneumatic-diverter" },
      { type = "unlock-recipe", recipe = "crossflow-junction" },
      { type = "unlock-recipe", recipe = "player-transit-capsule" }
    },
    order = "c-a[specialized-pneumatic-capsules]"
  },

  -- Gleba Planet Unlocks: Biocapsule (Requires carbon fiber & sulfur processing)
  {
    type = "technology",
    name = "biodegradable-capsule",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.bio),
    prerequisites = {
      "agricultural-science-pack",
      "pneumatic-transport",
      "carbon-fiber",
      "sulfur-processing"
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 45
    },
    effects = {
      { type = "unlock-recipe", recipe = "biodegradable-capsule" }
    },
    order = "c-b[biodegradable-capsule]"
  },

  -- Vulcanus Planet Unlocks: Reinforced Capsule (Requires tungsten carbide & LDS)
  {
    type = "technology",
    name = "reinforced-capsule",
    icons = tech_icon("__base__/graphics/technology/steel-processing.png", palette.reinforced),
    prerequisites = {
      "metallurgic-science-pack",
      "pneumatic-transport",
      "tungsten-carbide",
      "low-density-structure"
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"metallurgic-science-pack", 1}
      },
      time = 45
    },
    effects = {
      { type = "unlock-recipe", recipe = "reinforced-capsule" }
    },
    order = "c-b[reinforced-capsule]"
  },

  -- Aquilo Planet Unlocks: Refrigerated Capsule & Recharge (Requires cryogenic plant, lithium processing, electromagnetic plant & LDS)
  {
    type = "technology",
    name = "refrigerated-capsule",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.refrigerated),
    prerequisites = {
      "cryogenic-science-pack",
      "pneumatic-transport",
      "cryogenic-plant",
      "lithium-processing",
      "electromagnetic-plant",
      "low-density-structure"
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"cryogenic-science-pack", 1}
      },
      time = 45
    },
    effects = {
      { type = "unlock-recipe", recipe = "refrigerated-capsule" },
      { type = "unlock-recipe", recipe = "recharge-refrigerated-capsule" }
    },
    order = "c-b[refrigerated-capsule]"
  },

  -- Bio Capsule Integrity Upgrade Research Tiers
  {
    type = "technology",
    name = "bio-capsule-integrity-1",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.bio_1),
    prerequisites = {"biodegradable-capsule"},
    unit = {
      count = 100,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 30
    },
    order = "c-c[bio-capsule-integrity-1]"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-2",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.bio_2),
    prerequisites = {"bio-capsule-integrity-1"},
    unit = {
      count = 200,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 30
    },
    order = "c-c[bio-capsule-integrity-2]"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-3",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.bio_3),
    prerequisites = {"bio-capsule-integrity-2"},
    unit = {
      count = 350,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1}
      },
      time = 45
    },
    order = "c-c[bio-capsule-integrity-3]"
  },
  {
    type = "technology",
    name = "bio-capsule-integrity-4",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.bio_4),
    prerequisites = {"bio-capsule-integrity-3", "cryogenic-science-pack"},
    unit = {
      count = 500,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"cryogenic-science-pack", 1}
      },
      time = 60
    },
    order = "c-c[bio-capsule-integrity-4]"
  }
})