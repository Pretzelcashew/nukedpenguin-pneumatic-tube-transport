data:extend({
  {
    type = "recipe",
    name = "item-capsule",
    enabled = false,
    energy_required = 2.0,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 4},
      {type = "item", name = "plastic-bar", amount = 2},
      {type = "item", name = "electronic-circuit", amount = 1}
    },
    results = {
      {type = "item", name = "item-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "biodegradable-capsule",
    enabled = false,
    energy_required = 1.0,
    ingredients = {
      {type = "item", name = "wood", amount = 4},
      {type = "item", name = "plastic-bar", amount = 1},
      {type = "item", name = "iron-plate", amount = 1}
    },
    results = {
      {type = "item", name = "biodegradable-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "refrigerated-capsule",
    enabled = false,
    energy_required = 3.0,
    ingredients = {
      {type = "item", name = "item-capsule", amount = 1},
      {type = "item", name = "copper-cable", amount = 6},
      {type = "item", name = "plastic-bar", amount = 4},
      {type = "item", name = "electronic-circuit", amount = 2}
    },
    results = {
      {type = "item", name = "refrigerated-capsule", amount = 1}
    }
  },
  {
    type = "recipe",
    name = "reinforced-capsule",
    enabled = false,
    energy_required = 4.0,
    ingredients = {
      {type = "item", name = "item-capsule", amount = 1},
      {type = "item", name = "steel-plate", amount = 8},
      {type = "item", name = "advanced-circuit", amount = 2}
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
      {type = "item", name = "item-capsule", amount = 1},
      {type = "item", name = "steel-plate", amount = 10},
      {type = "item", name = "advanced-circuit", amount = 4},
      {type = "item", name = "electric-engine-unit", amount = 1}
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
      {type = "item", name = "steel-chest", amount = 1},
      {type = "item", name = "steel-plate", amount = 4},
      {type = "item", name = "advanced-circuit", amount = 2},
      {type = "item", name = "electric-engine-unit", amount = 1}
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
      {type = "item", name = "steel-chest", amount = 1},
      {type = "item", name = "steel-plate", amount = 4},
      {type = "item", name = "advanced-circuit", amount = 2},
      {type = "item", name = "electric-engine-unit", amount = 1}
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
      {type = "item", name = "copper-plate", amount = 1},
      {type = "item", name = "plastic-bar", amount = 1}
    },
    results = {
      {type = "item", name = "pneumatic-tube", amount = 2}
    }
  },
  {
    type = "recipe",
    name = "pneumatic-pump",
    enabled = false,
    energy_required = 3.0,
    ingredients = {
      {type = "item", name = "pump", amount = 1},
      {type = "item", name = "engine-unit", amount = 1},
      {type = "item", name = "steel-plate", amount = 5},
      {type = "item", name = "advanced-circuit", amount = 2}
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
      {type = "item", name = "pneumatic-tube", amount = 4},
      {type = "item", name = "steel-plate", amount = 2},
      {type = "item", name = "advanced-circuit", amount = 1}
    },
    results = {
      {type = "item", name = "junction", amount = 1}
    }
  }
})