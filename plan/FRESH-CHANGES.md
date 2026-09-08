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


### Revision: Pneumatic Capsule Counter Relative Configuration GUI
**Date:** 2026-09-07 15:50 (EDT)
**Context:** Implement Task 9 of the Capsule Counter plan, creating `counter-gui.lua` to provide an interactive configuration window for capsule counter entities and proxies, featuring dual-wire checkbox channel routing for vessels, cargo, and total capsule counts alongside virtual signal selection.
**Key Changes:**
1. **Relative Configuration Frame (`scripts/counters/counter-gui.lua`):** Created `counter-gui.lua` providing `open` and `close` functions to build and anchor `counter_configuration_frame` using `gui_components.create_relative_window` with header controls and card layout.
2. **Dual-Wire Channel Routing Controls (`scripts/counters/counter-gui.lua`):** Implemented dual "Red Wire" and "Green Wire" checkbox options across three configuration sections (Capsule Vessels, Cargo Contents, Total Capsule Count), seamlessly converting UI checkbox states to and from underlying setting schema targets (`"off"`, `"red"`, `"green"`, `"both"`).
3. **Signal Selection & Reactive Event Handling (`scripts/counters/counter-gui.lua`):** Integrated a `choose-elem-button` for Total Capsule Count virtual signal selection and registered event listeners (`on_gui_opened`, `on_gui_closed`, `on_gui_click`, `on_gui_checked_state_changed`, `on_gui_elem_changed`) to update `storage.counter_settings` and dispatch scanner setting notifications.


### Revision: Pneumatic Capsule Counter Triple-Proxy Channel Isolation & Full Integration
**Date:** 2026-09-07 16:17 (EDT)
**Context:** Implement Task 10 of the Capsule Counter plan, introducing a triple-proxy architecture (selectable terminal proxy plus hidden Red and Green channel proxies) to guarantee zero cross-channel signal bleed across circuit networks, while adding English locale definitions and control script initialization.
**Key Changes:**
1. **Triple-Proxy Prototypes (`prototypes/pneumatic-capsule-counter.lua`):** Registered `pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy` (`selection_priority = 0`, `operable = false`) alongside the main `pneumatic-capsule-counter-circuit-proxy` terminal (`selection_priority = 60`, `operable = true`).
2. **Sub-Proxy Lifecycle & Internal Wiring (`scripts/proxy-manager.lua`):** Extended `proxy_manager.register_pair` to support sub-proxy schemas. Automatically spawns, teleports, and connects internal Red and Green wire bridges (`connect_sub_proxies`) between channel proxies and the main terminal proxy on build/rotate events, and purges all three proxies upon entity deconstruction (`destroy_all_proxies_at`).
3. **Channel-Isolated Signal Dispatch (`scripts/counters/counter-logic.lua` & `scripts/counters/counter-settings.lua`):** Added `counter_settings.get_channel_proxies` and updated `counter_logic.update_signals` to write Red-target signals strictly to the Red channel proxy and Green-target signals strictly to the Green channel proxy while keeping the main terminal proxy filters empty, eliminating cross-network signal bleed.
4. **Active Scanner & Target Resolution (`scripts/active-device-scanner.lua` & `scripts/device-settings-copier.lua`):** Added sub-proxy names to `PROXY_NAMES` to bypass scanner tracking and updated `resolve_target_entity` to resolve sub-proxy handles back to the physical counter entity.
5. **Locale Definitions & Top-Level Require Registration (`locale/en/config.cfg` & `control.lua`):** Added English entity, item, recipe, and technology captions and descriptions. Registered `counter-settings`, `counter-gui`, and `counter-logic` as top-level `require` statements in `control.lua`.


### Revision: Hub Pressure Differential Enforcement & Cross-Transit Flow Isolation
**Date:** 2026-09-07 18:03 (EDT)
**Context:** Enforce strict positive pressure differential requirements for hub outbound capsule dispatch and cross-transit motion, preventing hubs from dumping capsules onto unpressurized or opposing-pressure target ports.
**Key Changes:**
1. **Per-Port Outbound Pressure Evaluation (`scripts/capsules/capsule-runner.lua`):** Refactored `find_best_hub_outbound_port` to measure pressure drops (`touching_level - target_level`) per individual touching port rather than applying a global hub entity maximum. Initialized `max_drop = 0` to require target ports to have strictly lower pressure than the hub's touching exit port.
2. **Strict Outbound Injection Guard (`scripts/capsules/capsule-runner.lua`):** Updated `inject_from_hub` to abort and return `false` if no valid outbound port with a positive pressure drop is found, eliminating fallback dispatches onto unpressurized or opposing flow lines.
3. **Cross-Transit Exit Port Isolation (`scripts/capsules/capsule-runner.lua`):** Updated `select_next_target` for `cross_transit` entities to calculate candidate pressure drops directly against the touching exit port (`level_exit - level_cand > 0`), preventing transiting capsules from exiting hubs into zero or negative pressure differential nodes.
4. **Hub Packing Early Exit Guard (`scripts/hubs/hub-packing.lua`):** Added an early outbound port validation check to `hub_packing.evaluate_inventory`, aborting cargo extraction and liminal holder creation whenever no valid lower-pressure outbound route is available.


### Revision: Pneumatic Capsule Counter Signal Picker Clearing & Quality Preservation
**Date:** 2026-09-07 18:24 (EDT)
**Context:** Fix an issue where clearing the total count signal picker in the Capsule Counter GUI instantly reverted to default signal-C, and ensure selected signal quality is preserved on circuit proxy output filters.
**Key Changes:**
1. **Signal Clear Persistence & Fallback Removal (`scripts/counters/counter-settings.lua` & `scripts/counters/counter-logic.lua`):** Removed hardcoded fallback initializations (`signal-C`) from existing settings retrieval (`counter_settings.get`), blueprint settings application, and logic signal evaluation. Clearing the choose-elem-button in `counter-gui.lua` now persists `total_signal = nil` without being overwritten on GUI refresh or tick scans.
2. **Quality-Aware Circuit Signal Emission (`scripts/counters/counter-logic.lua`):** Updated `counter_logic.update_signals` to extract `total_signal.quality` dynamically rather than hardcoding `"normal"` quality during channel signal aggregation, correctly reflecting chosen signal quality levels on output circuit proxy filters.


### Revision: Independent Flow & Counter Overlay Render Lifecycle
**Date:** 2026-09-07 20:55 (EDT)
**Context:** Fix issue where toggling pressure flow overlays off wiped active counter range overlays by decoupling render destruction and drawing logic in flow-engine.lua and debug-manager.lua.
**Key Changes:**
1. **Domain-Specific Render Management (`scripts/flow/flow-engine.lua`):** Created `flow_engine.clear_flow_renders` and `flow_engine.draw_flow` to manipulate pressure flow circles, text labels, and vector lines independently from counter sensing range overlays.
2. **Per-Player Overlay Destruction Bounds (`scripts/flow/flow-engine.lua`):** Refactored `destroy_pos_renders`, `destroy_counter_renders`, and `destroy_edge_render` to support optional `player_index` targeting, preventing single-player overlay clears from destroying rendering objects for other players in multiplayer.
3. **Decoupled Debug Command & GUI Toggles (`scripts/debug-manager.lua`):** Refactored `toggle_new_flow`, `toggle_counter_range`, `toggle_master`, and GUI event handlers to call domain-specific draw/clear methods rather than blanket `clear_all_renders`, preserving counter range overlays when flow overlays are disabled.


### Revision: Hub Capsule Nesting Default Off & Setting Encapsulation
**Date:** 2026-09-07 22:02 (EDT)
**Context:** Change the hub capsule nesting default state to disabled (`false`) and encapsulate status checks behind a centralized settings helper function, ensuring newly placed hubs immediately transport standard cargo and eliminating duplicated fallback logic.
**Key Changes:**
1. **Default State & Helper Registration (`scripts/hubs/hub-settings.lua`):** Updated the default `nest_capsules` property to `false` across storage initialization, copy-paste cloning, and blueprint tag deserialization routines. Registered `hub_settings.is_nesting_enabled` helper function to centralize truth evaluation.
2. **Packing Engine Integration (`scripts/hubs/hub-packing.lua`):** Refactored `evaluate_inventory` to inspect nesting permissions via `hub_settings.is_nesting_enabled`, allowing hubs to default to standard item cargo packing upon placement without requiring manual GUI intervention.
3. **GUI State Alignment (`scripts/hubs/hub-gui.lua`):** Updated relative container GUI initialization to set the "Nest capsules" checkbox state directly from `hub_settings.is_nesting_enabled`.


### Revision: Bio Capsule Shell Lifecycle & Net Cargo Capacity Tooltips
**Date:** 2026-09-07 22:42 (EDT)
**Context:** Refactor single-use capsule lifecycle so biological primary capsule shells travel in-transit with cargo, dissolve strictly upon destination unpacking or spills, and accurately report net cargo stack capacities in locale tooltips.
**Key Changes:**
1. **Primary Shell Packing Priority (`scripts/hubs/hub-packing.lua`):** Swapped holder inventory insertion order to transfer primary capsule shells (`include_self`) into slot 1 before cargo extractions, preventing bio capsule shells from being displaced or destroyed at the origin hub during packing.
2. **Single-Use Dissolution & Unpacking (`scripts/hubs/hub-unpacking.lua`):** Updated `can_insert_all` to ignore primary shell slots for `destroy_self` capsules when checking destination chest capacity, clearing the shell (`holder_inv[ignore_slot].clear()`) upon arrival prior to cargo stack transfers.
3. **In-Transit Spill Dissolution (`scripts/hubs/hub-spill.lua`):** Updated `spill_capsule` to inspect `capsule_def.destroy_self` and clear primary shell slots prior to spilling cargo onto the ground or into spill containers, dissolving bio capsule shells cleanly during mid-transit ruptures or entity destructions.
4. **Net Cargo Stack Locale Tooltips (`locale/en/config.cfg`):** Updated item descriptions for `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, and `reinforced-capsule` to report net usable cargo stack counts (1, 1, 2, 2, 5) matching actual cargohold limits.


### Revision: Explicit Net Cargo Capacity Schema & Liminal Bar Limit Refactor
**Date:** 2026-09-07 23:20 (EDT)
**Context:** Standardize capsule capacity declarations around explicit net usable cargo slots (`cargo_capacity`) and adjust liminal holder inventory bar limits in `hub-packing.lua` to dynamically accommodate fractional-cost items.
**Key Changes:**
1. **Explicit Net Cargo Capacity Schema (`scripts/capsules/capsule-definitions.lua`):** Replaced total-container offset properties (`base_capacity` with `include_self = true`) across all capsule prototypes with explicit net usable cargo capacities (`cargo_capacity`), declaring that normal bio and standard item capsules hold 1 net cargo slot, refrigerated capsules hold 2, reinforced capsules hold 5, and player transit capsules hold 0.
2. **Fractional Slot Cost Bar Limit Calculation (`scripts/hubs/hub-packing.lua`):** Fixed a bug where `dest_inv.set_bar()` derived physical container slot limits directly from total capacity rather than dividing by `min_slot_cost`. Calculating physical holder slots via `math.floor(max_cargo_slots / min_slot_cost)` unlocks the necessary container slots (e.g., 3 physical slots for 1 primary shell + 2 bio items at 0.5 cost) without payload truncation.


### Revision: Bio-Capsule Rupture Risk Deprecation & Tech Tree Streamlining
**Date:** 2026-09-08 08:23 (EDT)
**Context:** Deprecate punitive mid-transit rupture mechanics and research upgrade tiers for biodegradable capsules, while adding missing technology locale definitions to resolve UI errors.
**Key Changes:**
1. **Bio-Capsule Definition & Lifecycle Refactor (`scripts/capsules/capsule-definitions.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Removed `spill_risk` property from `biodegradable-capsule` and purged research tier calculations (`bio_integrity_levels`) and event listeners from `capsule-lifecycle.lua`, while preserving the generic `spill_risk` evaluation framework for extensible capsule support.
2. **Technology Tree Streamlining (`prototypes/technology.lua`):** Removed the four `bio-capsule-integrity-1` through `4` upgrade technology nodes, retaining strictly the baseline `biodegradable-capsule` research unlock node.
3. **Locale Completion & Rupture Text Purge (`locale/en/config.cfg`):** Removed all item and technology locale descriptions referencing transit rupture risks and integrity upgrades. Added missing localized technology captions and descriptions for `biodegradable-capsule`, `reinforced-capsule`, and `refrigerated-capsule` to eliminate "Unknown key" UI rendering errors.
4. **Storage Cleanup (`control.lua`):** Deprecated `storage.bio_integrity_levels` persistent tracking table across runtime initialization and configuration change handlers.


### Revision: Capsule Counter Dedicated Technology & Legacy Engine Purge
**Date:** 2026-09-08 08:36 (EDT)
**Context:** Introduce a dedicated research node for the Pneumatic Capsule Counter requiring Circuit Network technology, while purging residual legacy v1 flow engine references from settings, locale, and runtime comments.
**Key Changes:**
1. **Capsule Counter Dedicated Research (`prototypes/technology.lua` & `locale/en/config.cfg`):** Created the `capsule-counter` technology node (prerequisites: `pneumatic-transport`, `circuit-network`; 100 cycles @ 30s) unlocking the `pneumatic-capsule-counter` recipe. Unlinked the counter unlock from baseline `pneumatic-transport` technology. Added localized English title and description while updating `pneumatic-transport` locale text to reflect the decoupled research tree.
2. **Legacy v1 Flow Engine Cleanup (`locale/en/config.cfg`, `settings.lua` & `control.lua`):** Removed obsolete `pneumatic-flow-version` mod setting locale keys from `config.cfg`. Purged lingering comments referencing legacy v1 flow network graph/builder settings across `settings.lua` and `control.lua`.


### Revision: Reinforced Capsule Bulk Enforcement & Electromagnetic Capsule Fulgora Integration
**Date:** 2026-09-08 09:14 (EDT)
**Context:** Enforce strict single-type full-capacity bulk transport for reinforced capsules and implement the Fulgora electromagnetic capsule allowing unrestricted mixed-cargo transit.
**Key Changes:**
1. **Reinforced Capsule Bulk Constraint Enforcement (`scripts/capsules/capsule-definitions.lua` & `locale/en/config.cfg`):** Refactored `reinforced-capsule` properties (`mixed_cargo = false`, `mixed_quality = "strict"`, `minimum_cargo = "ceil"`, `full_stacks = true`) to enforce strict bulk transport, requiring all cargo slots to be completely filled with a single item type of uniform quality before packing.
2. **Electromagnetic Capsule Definition (`scripts/capsules/capsule-definitions.lua`):** Registered `electromagnetic-capsule` with 2 net usable cargo slots (+1 per quality tier), configured with `mixed_cargo = true`, `mixed_quality = "any"`, `minimum_cargo = 1`, and `full_stacks = false` to enable unrestricted mixing of item types, partial stack quantities, and qualities.
3. **Prototype & Recipe Declarations (`prototypes/item.lua` & `prototypes/recipe.lua`):** Registered `electromagnetic-capsule` item prototype (stack size 1, subgroup `pneumatic-capsules`, order `f[electromagnetic]`) with a Holmium pink-magenta tint, and added its crafting recipe requiring 5 superconductors, 2 low-density structures, and 10 scrap.
4. **Technology Research Node (`prototypes/technology.lua`):** Created the `electromagnetic-capsule` research node (prerequisites: `electromagnetic-science-pack`, `pneumatic-transport`, `electromagnetic-plant`; 250 cycles @ 45s) unlocking the electromagnetic capsule recipe, featuring the superconductor icon with Holmium pink-magenta tinting.
5. **Locale Definitions (`locale/en/config.cfg`):** Added English localized names and descriptions for the electromagnetic capsule item, recipe, and technology while updating reinforced capsule descriptions to reflect the strict full-capacity bulk transport rule.


### Revision: Stack-Proportional Fractional Capacity & Smart Post-Packing Inventory Bar Clamping
**Date:** 2026-09-08 09:42 (EDT)
**Context:** Implement the `mixed_quantity` capacity accounting flag for electromagnetic capsules to scale slot costs by item stack size, and replace static upfront inventory bar clamping guesswork on liminal holders with dynamic post-packing clamping.
**Key Changes:**
1. **Electromagnetic Capsule Fractional Capacity Schema (`scripts/capsules/capsule-definitions.lua`):** Added `mixed_quantity = true` to `electromagnetic-capsule` prototype definition and explicitly set `mixed_quantity = false` across all other capsule prototypes.
2. **Fractional Slot Cost Planning Engine (`scripts/hubs/packing/cargo-planner.lua`):** Updated `plan_single_type_cargo` in `cargo-planner.lua` to calculate per-item unit slot costs (`base_slot_cost / stack_size`) when `mixed_quantity` is enabled, enabling partial item stacks to consume fractional capsule volume proportional to their item count.
3. **Smart Dynamic Post-Packing Inventory Bar Clamping (`scripts/hubs/hub-packing.lua`):** Replaced static upfront inventory bar clamping math on the hidden liminal holder with dynamic post-packing clamping. Transfers primary shell and cargo extractions using full inventory depth (`max_search = #dest_inv`), evaluates the highest occupied slot index (`last_occupied_slot`), and sets `dest_inv.set_bar(last_occupied_slot + 1)` to lock trailing empty slots cleanly.


### Revision: Standard Capsule Quality-Clamped Multi-Cargo Schema & Locale Refactor
**Date:** 2026-09-08 10:11 (EDT)
**Context:** Refactor the Standard Pneumatic Capsule into a quality-clamped multi-stack logistics backbone, allowing mixed item types and qualities up to the capsule's quality tier without overlapping with strict bulk or partial-stack container roles.
**Key Changes:**
1. **Quality-Clamped Multi-Cargo Schema (`scripts/capsules/capsule-definitions.lua`):** Configured `item-capsule` with `mixed_cargo = true`, `mixed_quality = "any"`, `quality_filter = "ceil"`, `minimum_cargo = 2`, and `full_stacks = true`. Enables multi-item and multi-quality transport clamped to the capsule's quality tier while requiring full item stacks and dispatching as soon as 1 full stack is loaded.
2. **Locale Description Alignment (`locale/en/config.cfg`):** Updated localized English item description for `item-capsule` to explicitly communicate its full-stack, quality-clamped mixed cargo capacity rules.


### Revision: Biological Capsule Restrictions & Normalized Base Cargo Capacity
**Date:** 2026-09-08 11:33 (EDT)
**Context:** Restrict refrigerated capsules strictly to biological cargo and normalize baseline stack capacities across all capsule variants to establish a clear quality scaling progression and eliminate capacity power spikes.
**Key Changes:**
1. **Refrigerated Biological Restriction & Schema Alignment (`scripts/capsules/capsule-definitions.lua` & `scripts/hubs/hub-packing.lua`):** Configured `bio_only = true` on `refrigerated-capsule` and `spent-refrigerated-capsule` prototypes and added a `bio_only` validation check (`not capsule_def.bio_only or capsule_defs.is_bio_item(item_name)`) to the item candidate loop in `hub-packing.lua` to exclude non-biological items from loading into refrigerated shells.
2. **Normalized Base Capacity & Quality Scaling Schema (`scripts/capsules/capsule-definitions.lua`):** Standardized base cargo capacities across all capsule prototypes: set Standard, Biodegradable, Refrigerated, Spent Refrigerated, and Electromagnetic capsules to base capacity 1 stack (`cargo_capacity = 1`, `quality_affected_capacity = 1`), and Reinforced capsules to base capacity 2 stacks (`cargo_capacity = 2`, `quality_affected_capacity = 2`).
3. **Locale Description Updates (`locale/en/config.cfg`):** Updated English localized descriptions for `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, and `electromagnetic-capsule` to clearly communicate biological cargo restrictions and updated stack capacity scaling rules.


### Revision: Vacuum Capsule Data Prototypes, Tech Tree & Locale Registration
**Date:** 2026-09-08 11:57 (EDT)
**Context:** Implement Task 1 of the Vacuum Capsule plan, registering item, tool, recipe, technology research node, English locale, and capsule definition schemas for the vacuum capsule and spent shell ahead of transport belt siphoning engine integration.
**Key Changes:**
1. **Item & Tool Declarations (`prototypes/item.lua`):** Registered `vacuum-capsule` as a tool prototype (durability 100, order `g[vacuum]`) with a deep vacuum blue icon tint, and registered `spent-vacuum-capsule` item (stack size 1, order `h[spent-vacuum]`) under the `pneumatic-capsules` subgroup.
2. **Crafting & Recharge Recipes (`prototypes/recipe.lua`):** Added crafting recipe for `vacuum-capsule` requiring processing units, low-density structures, and accumulators, and added `recharge-vacuum-capsule` recipe requiring a spent capsule shell and 2 batteries under subgroup `pneumatic-capsules`.
3. **Space Science Technology Node (`prototypes/technology.lua`):** Created the `vacuum-capsule` research node (prerequisites: `space-science-pack`, `pneumatic-transport`; 250 cycles @ 45s) unlocking the vacuum capsule crafting and assembly recharging recipes.
4. **Capsule Definition Registry (`scripts/capsules/capsule-definitions.lua`):** Registered `vacuum-capsule` and `spent-vacuum-capsule` schemas configured with 1 net usable cargo slot (+1 per quality tier), full stack enforcement, quality-clamped cargo rules (`quality_filter = "ceil"`), `spent_capsule_item` transition link, and distinct RGBA debug overlay colors.
5. **English Locale Definitions (`locale/en/config.cfg`):** Added localized names, tooltips, and descriptions for `vacuum-capsule` and `spent-vacuum-capsule` items, recipes, and technology research nodes.