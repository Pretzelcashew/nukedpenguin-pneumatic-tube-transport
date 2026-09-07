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


### Revision: Pneumatic Capsule Counter Wavefront Range Engine
**Date:** 2026-09-07 13:34 (EDT)
**Context:** Implement Task 4 of the Capsule Counter plan, creating the delta wavefront propagation and boundary collision engine in `counter-range.lua` to partition tube networks into non-overlapping owned segment territories.
**Key Changes:**
1. **Wavefront Range Engine (`scripts/counters/counter-range.lua`):** Created `counter-range.lua` maintaining `storage.counter_levels`, `storage.counter_owners`, `storage.counter_queue`, and `storage.counter_owned_nodes`. Range seeds (15) decay by 1 level per hop down to 1 along tube nodes, with equal-level rival collisions resolving neutrally to eliminate double-counting. Implemented $O(1)$ segment territory lookups (`counter_range.get_owned_nodes`), defensive lazy storage initialization, and a `/check-counters` status debug command.
2. **Sensing Node Attribute Preservation (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to record `port.sense` attributes on `storage.flow_nodes`, allowing physical counter sensing ports to act as range emitters during graph traversal.
3. **Background Scanner Integration (`scripts/active-device-scanner.lua`):** Registered `pneumatic-capsule-counter` in the 15-tick background scanner. Energy state changes (`entity.energy > 0`) automatically trigger unit port enqueuing for immediate range expansion or recession.
4. **Runtime Lifecycle & Surface Hydration (`control.lua`):** Integrated `counter_range` storage initialization and event listeners into `control.lua`, scanning surfaces on load and initialization to register existing counters cleanly.


### Revision: Pneumatic Capsule Counter Wavefront Overlay & Flow Engine Unification
**Date:** 2026-09-07 14:26 (EDT)
**Context:** Implement Task 5 of the Capsule Counter plan, unifying sensing range wavefront propagation directly into `flow-engine.lua` for single-pipeline execution, adding Alt-Mode visual range overlays, deterministic midpoint tie-breaking, and symmetric recession/cleanup handling.
**Key Changes:**
1. **Flow Engine Wavefront Unification (`scripts/flow/flow-engine.lua`):** Refactored counter sensing range propagation directly into `flow_engine.step`, sharing the primary topological graph, queue, time-sliced batcher, and event listeners with pressure flow.
2. **Deterministic Territory Tie-Breaking (`scripts/flow/flow-engine.lua`):** Implemented deterministic `unit_number` tie-breaking for equal-distance midpoint collisions (`cand_level == max_cand_level`), eliminating neutral gap tiles and guaranteeing contiguous counter territory splits.
3. **Sensing Overlay Rendering & Alt-Mode Toggle (`scripts/flow/flow-engine.lua` & `scripts/debug-manager.lua`):** Implemented `update_counter_pos_render` rendering range level integers and owner color dots on tube nodes in Alt Mode. Added `/toggle-counter-range` (`/pt-toggle-counter-range`) command, shortcut, and Control Panel checkbox operating independently from pressure flow overlays.
4. **Natural Recession Waves & Disconnection Cleanup (`scripts/flow/flow-engine.lua` & `scripts/counters/counter-range.lua`):** Refactored `counter-range.lua` into a lightweight query API delegating queueing to `flow-engine.lua`. Updated entity removal and unpowering to enqueue root ports without pre-wiping levels, enabling 1-tile-per-tick recession waves for surviving counter takeover while instantly purging unconnected emission port renders on frame 0.