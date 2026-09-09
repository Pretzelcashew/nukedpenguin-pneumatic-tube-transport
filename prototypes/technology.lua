local palette = {
  transport       = {r = 0.40, g = 0.70, b = 0.90, a = 1.0}, -- Pressure Cyan
  specialized     = {r = 0.85, g = 0.45, b = 0.95, a = 1.0}, -- Advanced Purple
  bio             = {r = 0.40, g = 0.85, b = 0.40, a = 1.0}, -- Leaf Green
  reinforced      = {r = 1.00, g = 0.65, b = 0.20, a = 1.0}, -- Bronze
  electromagnetic = {r = 0.85, g = 0.35, b = 0.95, a = 1.0}, -- Holmium Pink-Magenta
  refrigerated    = {r = 0.40, g = 0.80, b = 1.00, a = 1.0}, -- Cryo Cyan
  vacuum          = {r = 0.30, g = 0.50, b = 0.90, a = 1.0}, -- Deep Vacuum Blue
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

  -- Capsule Counter Research Tech
  {
    type = "technology",
    name = "capsule-counter",
    icons = tech_icon("__base__/graphics/technology/circuit-network.png", palette.transport),
    prerequisites = {
      "pneumatic-transport",
      "circuit-network"
    },
    unit = {
      count = 100,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      },
      time = 30
    },
    effects = {
      { type = "unlock-recipe", recipe = "pneumatic-capsule-counter" }
    },
    order = "c-a[capsule-counter]"
  },

  -- Pressurized Pneumatic Gates Research Tech
  {
    type = "technology",
    name = "pressurized-gates",
    icons = tech_icon("__base__/graphics/technology/gate.png", palette.transport),
    prerequisites = {
      "pneumatic-transport",
      "gate"
    },
    unit = {
      count = 100,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1}
      },
      time = 30
    },
    effects = {},
    order = "c-a[pressurized-gates]"
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

  -- Gleba Planet Unlocks: Biocapsule (Requires agricultural science pack)
  {
    type = "technology",
    name = "biodegradable-capsule",
    icons = tech_icon("__base__/graphics/technology/fluid-handling.png", palette.bio),
    prerequisites = {
      "agricultural-science-pack",
      "pneumatic-transport"
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

  -- Fulgora Planet Unlocks: Electromagnetic Capsule (Requires electromagnetic science pack & electromagnetic plant)
  {
    type = "technology",
    name = "electromagnetic-capsule",
    icons = tech_icon("__space-age__/graphics/icons/superconductor.png", palette.electromagnetic, 64),
    prerequisites = {
      "electromagnetic-science-pack",
      "pneumatic-transport",
      "electromagnetic-plant"
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"electromagnetic-science-pack", 1}
      },
      time = 45
    },
    effects = {
      { type = "unlock-recipe", recipe = "electromagnetic-capsule" }
    },
    order = "c-b[electromagnetic-capsule]"
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

  -- Space Science Technology: Vacuum Capsule
  {
    type = "technology",
    name = "vacuum-capsule",
    icons = tech_icon("__base__/graphics/technology/space-science-pack.png", palette.vacuum),
    prerequisites = {
      "space-science-pack",
      "pneumatic-transport"
    },
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 45
    },
    effects = {
      { type = "unlock-recipe", recipe = "vacuum-capsule" },
      { type = "unlock-recipe", recipe = "recharge-vacuum-capsule" }
    },
    order = "c-b[vacuum-capsule]"
  }
})