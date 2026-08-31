data:extend({
  {
    type = "container",
    name = "capsule-hub-horizontal",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.5, result = "capsule-hub-horizontal"},
    max_health = 250,
    collision_box = {{-0.9, -0.4}, {0.9, 0.4}},
    selection_box = {{-1.0, -0.5}, {1.0, 0.5}},
    inventory_size = 10,
    inventory_type = "with_filters_and_bar",
    picture = {
      layers = {
        {
          filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
          width = 64,
          height = 64,
          scale = 0.5,
          shift = {-0.5, 0},
          tint = {r = 0.6, g = 0.8, b = 1.0, a = 1.0}
        },
        {
          filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
          width = 64,
          height = 64,
          scale = 0.5,
          shift = {0.5, 0},
          tint = {r = 0.6, g = 0.8, b = 1.0, a = 1.0}
        }
      }
    },
    circuit_wire_connection_point = circuit_connector_definitions["chest"].points,
    circuit_connector_sprites = circuit_connector_definitions["chest"].sprites,
    circuit_wire_max_distance = default_circuit_wire_max_distance
  },
  {
    type = "container",
    name = "capsule-hub-vertical",
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.5, result = "capsule-hub-vertical"},
    max_health = 250,
    collision_box = {{-0.4, -0.9}, {0.4, 0.9}},
    selection_box = {{-0.5, -1.0}, {0.5, 1.0}},
    inventory_size = 10,
    inventory_type = "with_filters_and_bar",
    picture = {
      layers = {
        {
          filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
          width = 64,
          height = 64,
          scale = 0.5,
          shift = {0, -0.5},
          tint = {r = 0.4, g = 0.9, b = 0.9, a = 1.0}
        },
        {
          filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
          width = 64,
          height = 64,
          scale = 0.5,
          shift = {0, 0.5},
          tint = {r = 0.4, g = 0.9, b = 0.9, a = 1.0}
        }
      }
    },
    circuit_wire_connection_point = circuit_connector_definitions["chest"].points,
    circuit_connector_sprites = circuit_connector_definitions["chest"].sprites,
    circuit_wire_max_distance = default_circuit_wire_max_distance
  },
  {
    type = "container",
    name = "invisible-capsule-holder",
    icon = "__base__/graphics/icons/wooden-chest.png",
    icon_size = 64,
    flags = {
      "not-on-map",
      "placeable-off-grid",
      "no-automated-item-removal",
      "no-automated-item-insertion"
    },
    hidden = true,
    hidden_in_factoriopedia = true,
    max_health = 1,
    destructible = false,
    operable = true,
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    collision_mask = {layers = {}},
    inventory_size = 255,
    picture = util.empty_sprite()
  },
  {
    type = "container",
    name = "visible-capsule-holder",
    icon = "__base__/graphics/icons/iron-chest.png",
    icon_size = 64,
    flags = {
      "placeable-neutral",
      "player-creation",
      "no-automated-item-insertion",
      "no-automated-item-removal",
      "no-copy-paste"
    },
    minable = {mining_time = 0.2},
    max_health = 150,
    destructible = true,
    operable = true, -- Operable: Enables Ctrl+Click fast-looting
    collision_mask = {layers = {}},
    collision_box = {{-0.2, -0.2}, {0.2, 0.2}},
    selection_box = {{-0.3, -0.3}, {0.3, 0.3}},
    inventory_size = 255,
    inventory_type = "with_bar",
    picture = {
      layers = {
        {
          filename = "__base__/graphics/entity/iron-chest/iron-chest.png",
          width = 64,
          height = 64,
          scale = 0.25,
          shift = {0, 0}
        }
      }
    },
    circuit_wire_connection_point = circuit_connector_definitions["chest"].points,
    circuit_connector_sprites = circuit_connector_definitions["chest"].sprites,
    circuit_wire_max_distance = default_circuit_wire_max_distance
  },
  {
    type = "simple-entity-with-owner",
    name = "pneumatic-tube",
    icon = "__base__/graphics/icons/pipe.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    rotatable = true,
    operable = true,
    minable = {mining_time = 0.2, result = "pneumatic-tube"},
    max_health = 100,
    collision_box = {{-0.4, -0.9}, {0.4, 0.9}},
    selection_box = {{-0.5, -1.0}, {0.5, 1.0}},
    picture = {
      north = {
        layers = {
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-vertical.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {0, -0.5},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          },
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-vertical.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {0, 0.5},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          }
        }
      },
      east = {
        layers = {
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-horizontal.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {-0.5, 0},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          },
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-horizontal.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {0.5, 0},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          }
        }
      },
      south = {
        layers = {
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-vertical.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {0, -0.5},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          },
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-vertical.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {0, 0.5},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          }
        }
      },
      west = {
        layers = {
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-horizontal.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {-0.5, 0},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          },
          {
            filename = "__base__/graphics/entity/pipe/pipe-straight-horizontal.png",
            priority = "extra-high",
            width = 128,
            height = 128,
            scale = 0.5,
            shift = {0.5, 0},
            tint = {r = 0.5, g = 0.9, b = 0.5, a = 1.0}
          }
        }
      }
    }
  },
  {
    type = "electric-energy-interface",
    name = "pneumatic-pump",
    icon = "__base__/graphics/icons/pump.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    rotatable = true,
    fast_replaceable_group = "pneumatic-pump",
    minable = {mining_time = 0.2, result = "pneumatic-pump"},
    max_health = 180,
    collision_box = {{-0.4, -0.9}, {0.4, 0.9}},
    selection_box = {{-0.5, -1.0}, {0.5, 1.0}},
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "3kJ",
      input_flow_limit = "60kW"
    },
    energy_usage = "30kW",
    pictures = {
      north = {
        filename = "__base__/graphics/entity/pump/pump-north.png",
        priority = "high",
        width = 64,
        height = 128,
        scale = 0.5,
        tint = {r = 1.0, g = 0.7, b = 0.3, a = 1.0}
      },
      east = {
        filename = "__base__/graphics/entity/pump/pump-east.png",
        priority = "high",
        width = 128,
        height = 64,
        scale = 0.5,
        tint = {r = 1.0, g = 0.7, b = 0.3, a = 1.0}
      },
      south = {
        filename = "__base__/graphics/entity/pump/pump-south.png",
        priority = "high",
        width = 64,
        height = 128,
        scale = 0.5,
        tint = {r = 1.0, g = 0.7, b = 0.3, a = 1.0}
      },
      west = {
        filename = "__base__/graphics/entity/pump/pump-west.png",
        priority = "high",
        width = 128,
        height = 64,
        scale = 0.5,
        tint = {r = 1.0, g = 0.7, b = 0.3, a = 1.0}
      }
    }
  },
  {
    type = "simple-entity-with-owner",
    name = "junction",
    icon = "__base__/graphics/icons/iron-chest.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.2, result = "junction"},
    max_health = 100,
    collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    picture = {
      layers = {
        {
          filename = "__base__/graphics/entity/iron-chest/iron-chest.png",
          width = 64,
          height = 64,
          scale = 0.5,
          shift = {0, 0},
          tint = {r = 1.0, g = 0.9, b = 0.3, a = 1.0}
        }
      }
    }
  },
  {
    type = "simple-entity-with-owner",
    name = "crossflow-junction",
    icon = "__base__/graphics/icons/iron-chest.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.2, result = "crossflow-junction"},
    max_health = 100,
    collision_box = {{-0.4, -0.4}, {0.4, 0.4}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    picture = {
      layers = {
        {
          filename = "__base__/graphics/entity/iron-chest/iron-chest.png",
          width = 64,
          height = 64,
          scale = 0.5,
          shift = {0, 0},
          tint = {r = 0.8, g = 0.4, b = 0.9, a = 1.0}
        }
      }
    }
  }
})