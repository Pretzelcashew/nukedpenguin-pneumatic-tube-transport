### Revision: Pneumatic Capsule Counter Data Stage & Prototype Declarations
**Date:** 2026-09-07 10:21 (EDT)
**Context:** Implement Task 1 of the Capsule Counter plan, registering entity, item, recipe, technology, and hidden circuit proxy prototypes ahead of runtime range propagation and logic engine integration.
**Key Changes:**
1. **Capsule Counter Entity & Proxy (`prototypes/pneumatic-capsule-counter.lua`):** Registered the main physical entity `pneumatic-capsule-counter` (`electric-energy-interface`, 1x2 footprint, 30 kW energy usage, `selection_priority = 50`) configured with `gui_mode = "all"`. Registered its companion `pneumatic-capsule-counter-circuit-proxy` (`constant-combinator`, `selection_priority = 60`, `operable = true`, `placeable_by` main item, `"player-creation"` flag).
2. **Tinted Decider Sprite Graphics (`prototypes/pneumatic-capsule-counter.lua`):** Deepcopied 4-way directional sprites from `data.raw["decider-combinator"]["decider-combinator"]` and applied a distinct teal tint (`r = 0.30, g = 0.85, b = 0.70`), visually differentiating the counter structure from pumps and hubs.
3. **Item & Recipe Declarations (`prototypes/item.lua` & `prototypes/recipe.lua`):** Registered `pneumatic-capsule-counter` item under subgroup `pneumatic-transport` (order `h[counter]`, stack size 20) with a matching teal icon tint, and added its crafting recipe requiring tubes, advanced circuits, and arithmetic combinators.
4. **Technology Unlock & Data Registration (`prototypes/technology.lua` & `data.lua`):** Linked the counter recipe unlock effect directly to the baseline `pneumatic-transport` technology research node and required `prototypes.pneumatic-capsule-counter` in `data.lua`.


### Revision: Pneumatic Capsule Counter Circuit Proxy Pair Lifecycle Integration
**Date:** 2026-09-07 10:29 (EDT)
**Context:** Implement Task 2 of the Capsule Counter plan, linking the physical counter entity with its hidden circuit proxy pair in `proxy-manager.lua` to enable proxy creation, wire retention, selection Z-indexing, and orphan cleanup.
**Key Changes:**
1. **Proxy Pair Registration (`scripts/proxy-manager.lua`):** Registered the `pneumatic-capsule-counter` and `pneumatic-capsule-counter-circuit-proxy` pair via `proxy_manager.register_pair` with a forward-compatible `on_open_gui` stub handler delegating to `counter_gui.open`.
2. **Lifecycle & Selection Z-Indexing Integration (`scripts/proxy-manager.lua`):** Bound the counter proxy pair into the centralized proxy manager lifecycle, automatically enabling proxy creation on build/ghost placement, `selection_priority = 60` teleportation on rotation, additive wire connection migrations (`transfer_wire_connections`), orphan proxy destruction on main entity removal, and sandbox wipe cleanup (`storage.proxy_destruction_map`).


### Revision: Pneumatic Capsule Counter Sensing Port Alignment
**Date:** 2026-09-07 11:02 (EDT)
**Context:** Implement Task 3 of the Capsule Counter plan, registering directional sensing ports for the physical and ghost counter entities in port-defs.lua to enable topological node registration and range wavefront propagation.
**Key Changes:**
1. **Counter Port Registry Alignment (`scripts/flow/port-defs.lua`):** Registered `pneumatic-capsule-counter` port definitions across all four cardinal directions (`north`, `south`, `east`, `west`), assigning six spatial sensing connection offsets per orientation matching hub footprint layouts.
2. **Sensing Power & Isolation Configuration (`scripts/flow/port-defs.lua`):** Configured sensing ports with a `sense = 15` range seed rating while specifying `transmit = false`, `cross_transit = false`, and omitting gas `flow` pressure emission to ensure counter structures sense adjacent tube networks without acting as transit conduits or gas emitters.