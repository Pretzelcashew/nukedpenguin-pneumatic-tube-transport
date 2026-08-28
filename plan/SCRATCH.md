local am2 = data.raw["assembling-machine"]["assembling-machine-2"]
local cc = data.raw["constant-combinator"]["constant-combinator"]

local am2_icon = am2.icon or (am2.icons and am2.icons[1].icon)
local am2_icon_size = am2.icon_size or (am2.icons and am2.icons[1].icon_size) or 64

data:extend({
  -- Physical machine (Power & Graphics)
  {
    type = "electric-energy-interface",
    name = "pneumatic-diverter",
    icon = am2_icon,
    icon_size = am2_icon_size,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.3, result = "pneumatic-diverter"},
    max_health = 250,
    collision_box = am2.collision_box,
    selection_box = am2.selection_box,
    selection_priority = 50,
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "10kJ",
      input_flow_limit = "100kW"
    },
    energy_usage = "50kW",
    gui_mode = "none",
    animation = am2.graphics_set and am2.graphics_set.animation or am2.animation
  },

  -- Hidden constant combinator proxy for circuit logic
  {
    type = "constant-combinator",
    name = "pneumatic-diverter-circuit-proxy",
    icon = am2_icon,
    icon_size = am2_icon_size,
    flags = {
      "placeable-off-grid",
      "not-on-map",
      "not-deconstructable",
      "not-blueprintable",
      "hide-alt-info",
      "not-selectable-in-game"
    },
    collision_box = {{0, 0}, {0, 0}},
    selection_priority = 0,
    item_slot_count = 10,
    circuit_wire_connection_points = cc.circuit_wire_connection_points,
    circuit_connector_sprites = cc.circuit_connector_sprites,
    circuit_wire_max_distance = cc.circuit_wire_max_distance or default_circuit_wire_max_distance
  }
})





Pneumatic Tube Transport

Fast, high-throughput item and player logistics via custom pressurized pipe networks. Route specialized capsules through pneumatic tubes, control flow with multi-port diverters, and blast across your factory in personal transit capsules.

### Key Features

* **High-Speed Pneumatic Networks:** Build custom pressure networks using tubes, horizontal/vertical hubs, pumps, junctions, and 4-way crossflow junctions.
* **Specialized Transit Capsules:**
  * **Standard Capsules:** Reliable baseline item transport.
  * **Biodegradable Capsules:** High-capacity vessels that safely dissolve upon delivery.
  * **Refrigerated Capsules:** Drastically slow down spoil times for perishable cargo during transit.
  * **Reinforced Capsules:** Heavy-duty shells designed for volatile items.
  * **Player Transit Capsules:** Hop inside the network to travel across your factory at high speed (press `SHIFT + E` to emergency eject!).
* **Smart Flow & Port Filtering:** Route capsules using 4-port directional diverters with configurable push/pull flow modes and per-port item filters (whitelists & blacklists).
* **Hub Circuit Integration:** Control container hub dispatching and receiving rules via manual toggles or red/green circuit network conditions.
* **Dynamic Pressure Simulation:** Real-time pressure gradients and pathing—network speed dynamically scales based on line pressure and pump power.
* **Built-in Visual Debugging:** Includes console diagnostic commands like `/toggle-flow` to project directional flow vectors and numerical pressure levels directly on world entities (along with `/toggle-ports`, `/toggle-capsules`, and `/toggle-debug`).
* **Space Age Integration:** Fully integrated tech tree supporting Space Age science progression and quality-aware item filtering.

---

### Developer Note

I vibe coded this entire mod with AI assistance—couldn't have built it without it! Special shoutout to CatFireDragon for encouraging me to actually make this mod in the first place.

This is an early release because I wanted to get it out into the community to gather feedback. I plan to actively update the mod with more features (including expanding circuit functionality to diverters), better balance, custom graphics, and performance optimizations. If you run into issues or have ideas, let me know!