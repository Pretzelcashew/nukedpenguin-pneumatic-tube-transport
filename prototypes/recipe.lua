data:extend({
  {
    type = "recipe",
    name = "item-capsule",
    enabled = false,
    energy_required = 2.0,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 1},
      {type = "item", name = "plastic-bar", amount = 1}
    },
    results = {
      {type = "item", name = "item-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "biodegradable-capsule",
    categories = {"organic"},
    enabled = false,
    energy_required = 1.0,
    ingredients = {
      {type = "item", name = "carbon-fiber", amount = 1},
      {type = "item", name = "jelly", amount = 2},
      {type = "fluid", name = "sulfuric-acid", amount = 4}
    },
    results = {
      {type = "item", name = "biodegradable-capsule", amount = 4}
    }
  },
  {
    type = "recipe",
    name = "refrigerated-capsule",
    categories = {"crafting-with-fluid"},
    enabled = false,
    energy_required = 3.0,
    ingredients = {
      {type = "fluid", name = "fluoroketone-cold", amount = 125},
      {type = "item", name = "lithium-plate", amount = 8},
      {type = "item", name = "superconductor", amount = 10},
      {type = "item", name = "low-density-structure", amount = 2}
    },
    results = {
      {type = "item", name = "refrigerated-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "recharge-refrigerated-capsule",
    categories = {"crafting-with-fluid"},
    enabled = false,
    energy_required = 2.0,
    icons = {
      { icon = "__space-age__/graphics/icons/ice.png", icon_size = 64, tint = {r = 0.40, g = 0.80, b = 1.00, a = 1.0} }
    },
    ingredients = {
      {type = "item", name = "spent-refrigerated-capsule", amount = 1},
      {type = "fluid", name = "fluoroketone-cold", amount = 125}
    },
    results = {
      {type = "item", name = "refrigerated-capsule", amount = 1},
      {type = "fluid", name = "fluoroketone-hot", amount = 100}
    }
  },
  {
    type = "recipe",
    name = "reinforced-capsule",
    enabled = false,
    energy_required = 4.0,
    ingredients = {
      {type = "item", name = "tungsten-carbide", amount = 8},
      {type = "item", name = "low-density-structure", amount = 2}
    },
    results = {
      {type = "item", name = "reinforced-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "player-transit-capsule",
    enabled = false,
    energy_required = 5.0,
    ingredients = {
      {type = "item", name = "low-density-structure", amount = 2},
      {type = "item", name = "advanced-circuit", amount = 1}
    },
    results = {
      {type = "item", name = "player-transit-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "capsule-hub-horizontal",
    enabled = false,
    energy_required = 3.5,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 16},
      {type = "item", name = "advanced-circuit", amount = 10}
    },
    results = {
      {type = "item", name = "capsule-hub-horizontal", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "capsule-hub-vertical",
    enabled = false,
    energy_required = 3.5,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 16},
      {type = "item", name = "advanced-circuit", amount = 10}
    },
    results = {
      {type = "item", name = "capsule-hub-vertical", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "pneumatic-tube",
    enabled = false,
    energy_required = 1.0,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 2},
      {type = "item", name = "plastic-bar", amount = 8}
    },
    results = {
      {type = "item", name = "pneumatic-tube", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "pneumatic-pump",
    enabled = false,
    energy_required = 3.0,
    ingredients = {
      {type = "item", name = "pneumatic-tube", amount = 1},
      {type = "item", name = "engine-unit", amount = 1}
    },
    results = {
      {type = "item", name = "pneumatic-pump", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "junction",
    enabled = false,
    energy_required = 1.5,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 4},
      {type = "item", name = "plastic-bar", amount = 4}
    },
    results = {
      {type = "item", name = "junction", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "crossflow-junction",
    enabled = false,
    energy_required = 1.5,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 4},
      {type = "item", name = "plastic-bar", amount = 4}
    },
    results = {
      {type = "item", name = "crossflow-junction", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "pneumatic-diverter",
    enabled = false,
    energy_required = 3.0,
    ingredients = {
      {type = "item", name = "pneumatic-tube", amount = 4},
      {type = "item", name = "engine-unit", amount = 4},
      {type = "item", name = "advanced-circuit", amount = 12}
    },
    results = {
      {type = "item", name = "pneumatic-diverter", amount = 1}
    }
  }
})