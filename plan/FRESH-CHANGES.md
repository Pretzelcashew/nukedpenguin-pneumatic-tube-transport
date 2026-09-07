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


### Revision: Pneumatic Capsule Counter State Persistence Module
**Date:** 2026-09-07 14:33 (EDT)
**Context:** Implement Task 6 of the Capsule Counter plan, creating `counter-settings.lua` to manage counter configuration storage, spatial device ID resolution, copy-paste cloning, blueprint serialization, and proxy resolution.
**Key Changes:**
1. **State Persistence Module (`scripts/counters/counter-settings.lua`):** Created `counter-settings.lua` maintaining `storage.counter_settings[dev_id]` with default schema (`vessels_target = "green"`, `cargo_target = "red"`, `total_target = "green"`, `total_signal = { type = "virtual", name = "signal-C" }`).
2. **Spatial Identification & Proxy Resolution (`scripts/counters/counter-settings.lua`):** Implemented `counter_settings.get_device_id` supporting real unit numbers and ghost string formats (`ghost@...`), and `counter_settings.get_proxy` to locate the associated `pneumatic-capsule-counter-circuit-proxy`.
3. **Copy-Paste & Blueprint Deserialization (`scripts/counters/counter-settings.lua`):** Implemented `counter_settings.copy` for deep-copying settings between entities/ghosts and `counter_settings.apply_blueprint_settings` for restoring configuration tables from blueprint tags.


### Revision: Pneumatic Capsule Counter Copy-Paste & Blueprint Serialization
**Date:** 2026-09-07 14:52 (EDT)
**Context:** Implement Task 7 of the Capsule Counter plan, integrating pneumatic capsule counter entities into active device scanning, live copy-paste workflows, ghost settings adoption, and blueprint tag serialization.
**Key Changes:**
1. **Target Registration & Live Copy-Paste (`scripts/device-settings-copier.lua`):** Added `pneumatic-capsule-counter` to `TARGET_NAMES`, mapped `pneumatic-capsule-counter-circuit-proxy` target resolution to the main entity, implemented live entity copy-paste handling, and added top-level safe loading for `counter-gui`.
2. **Blueprint Serialization & Wire Target Resolution (`scripts/device-settings-copier.lua`):** Updated `on_player_setup_blueprint` to serialize counter settings tags (`pneumatic_settings`), append proxy entities, and record 4-tuple wire connections. Updated `process_entity_built_wire_tags` to restore proxy circuit wire links upon blueprint placement.
3. **Active Scanner Hooks & Ghost Settings Adoption (`scripts/active-device-scanner.lua`):** Added `init_settings` and `apply_blueprint_settings` hooks to the `pneumatic-capsule-counter` scanner spec, enabled device ID resolution, and integrated ghost-to-real settings adoption, blueprint pasting, and storage cleanup on entity removal or rotation.


### Revision: Pneumatic Capsule Counter Logic Engine & Circuit Signal Emitter
**Date:** 2026-09-07 15:01 (EDT)
**Context:** Implement Task 8 of the Capsule Counter plan, creating counter-logic.lua to calculate capsule vessel counts, cargo item inventories, and total capsule counts within owned tube territories, writing signal filters directly to the circuit proxy combinator on active scanner ticks.
**Key Changes:**
1. **Counter Logic Module (`scripts/counters/counter-logic.lua`):** Created `counter-logic.lua` providing `counter_logic.update_signals(counter_entity)`. Resolves owned segment nodes (`counter_range.get_owned_nodes`), queries active capsules without double-counting, extracts vessel item/quality breakdowns, cargo contents, and total capsule count (virtual signal C), and writes accumulated signals to the circuit proxy control behavior (`section.filters`). Automatically clears output signals when unpowered (`entity.energy == 0`) or unconfigured.
2. **Active Scanner Hooks & Reactive Triggers (`scripts/active-device-scanner.lua`):** Required `counter_logic` in `active-device-scanner.lua`. Added an `on_scan` hook to the `pneumatic-capsule-counter` scanner spec for 15-tick periodic signal updates, and wired immediate signal recalculations upon power state toggles (`check_and_update_state`) and settings change notifications (`notify_settings_changed`).


### Revision: Explicit Port Transmission Schema & Sensing Boundary Isolation
**Date:** 2026-09-07 15:40 (EDT)
**Context:** Refactor overloaded port transmission properties into domain-specific flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) to prevent counter range wavefronts from leaking across active machine boundaries while guaranteeing smooth capsule transit through pumps and diverters.
**Key Changes:**
1. **Explicit Port Transmission Registry (`scripts/flow/port-defs.lua`):** Replaced single `transmit` property with domain-specific booleans (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) across all registered entity port definitions. Explicitly disabled `sense_transmit` and `pressure_transmit` on machines (`pneumatic-pump`, `pneumatic-diverter`, `capsule-hub`, `pneumatic-capsule-counter`) while retaining `capsule_transmit = true` on transit machines.
2. **Flow & Sensing Wavefront Engine Alignment (`scripts/flow/flow-engine.lua`):** Recorded explicit transmission flags during node registration (`connect_entity`). Refactored passive gas pressure checks to require `pressure_transmit`, counter range wavefront propagation to require `sense_transmit`, and internal step queueing to evaluate domain-specific changes independently.
3. **Capsule Movement Target Validation (`scripts/capsules/capsule-runner.lua`):** Updated candidate hop generation, target hop validity checks (`is_hop_valid`), and hub outbound port selection to inspect `capsule_transmit` and `cross_transit`. Completely prevents capsules from targeting pure sensing ports while guaranteeing uninhibited capsule motion through pumps and diverters.