#### 0.3.23


### Revision: Hardened Mod Packager and Release Export Manifest
**Date:** 2026-09-11 19:48 EDT
**Context:** Hardened the automated release packager against accidental configuration file omission and established explicit build-safety protocols for external drive packaging.
**Key Changes:**
1. **Mod Packaging Pipeline (`package.py`):** Extended `EXPORT.md` resolution to search `plan/core/` before root and destination fallbacks, added an interactive `(y/N)` execution gate when rules are absent, and documented multi-drive synchronization requirements.
2. **Release Export Manifest (`plan/core/EXPORT.md`):** Relocated active release exclusion rules out of archive staging into `plan/core/`, adding explicit anti-archival headers, script usage warnings, and cross-drive sync directives.


### Revision: Modularize Flow Engine into Renderer and Gate Interoperability Subsystems
**Date:** 2026-09-11 22:20 EDT
**Context:** Decomposed the monolithic 2,511-line `flow-engine.lua` into isolated domain modules to decouple Alt-Mode visual rendering and defensive structure interoperability from core wavefront graph simulation.
**Key Changes:**
1. **Flow Overlay Renderer (`scripts/flow/flow-renderer.lua`):** Extracted all Alt-Mode graphical drawing routines (`draw_circle`, `draw_line`, `draw_text`), visual color palettes, dominant pressure and counter query primitives, and per-player render registries (`storage.flow_renders`, `storage.counter_renders`, `storage.kinetic_renders`, `storage.flow_edge_renders`).
2. **Fence & Gate Interoperability Engine (`scripts/flow/flow-gate-interop.lua`):** Encapsulated stone-wall dual-channel orthogonal axis locking (`storage.wall_locked_group`), terminator gate state tracking and outer boundary containment cutoff sync (`storage.gate_cutoff_states`), pre-research soft-registry discovery (`storage.soft_interop_registry`), and throttled research activation queue drainage (`storage.interop_activation_queue`).
3. **Wavefront Graph Simulation Core (`scripts/flow/flow-engine.lua`):** Reduced core file size by over 1,700 lines down to ~720 lines by aliasing visual primitives to `flow-renderer` and delegating defensive structure lifecycle handlers to `flow-gate-interop` while strictly preserving public API signatures and 0-tick idle queue execution.


### Revision: Modularize Kinetic Flow and Centralize Shared Graph Primitives
**Date:** 2026-09-11 23:36 EDT
**Context:** Decomposed the flow engine into dedicated domain modules and extracted a shared graph foundation in `flow-common.lua` to eliminate duplicate waking loops and resolve a scope-shadowing wavefront stall.
**Key Changes:**
1. **Shared Flow Foundation (`scripts/flow/flow-common.lua`):** Established a low-level base module containing the single source of truth for capsule waking (`wake_port_parked`), queue management (`enqueue_port`), spatial coordinate hashing, and atomic graph mutations (`destroy_node`, `link_ports`, `sever_ports`) to prevent circular dependency hazards and code duplication.
2. **Kinetic Projection Engine (`scripts/flow/flow-kinetic.lua`):** Encapsulated electromagnetic projector beam projection, discrete line-of-sight obstacle queries, receiver catchment, and 5-tile ballistic hop chains while delegating graph mutations and waking calls to `flow-common`.
3. **Wavefront Simulation Core (`scripts/flow/flow-engine.lua`):** Resolved local scope shadowing of `flow_changed` and `range_changed` inside the step loop that stalled pressure propagation across tubes, decoupled gas pressure from `storage.kinetic_levels`, and broadened neighbor waking across all flow changes.
4. **Alt-Mode Overlay Renderer (`scripts/flow/flow-renderer.lua`):** Filtered dominant pressure port evaluations to ignore kinetic nodes, preventing open-air kinetic beam reach levels from rendering as gas pressure numbers or cyan circles.


### Revision: Scale Pump, Diverter, and Counter Flow Emissions with Quality
**Date:** 2026-09-12 00:11 EDT
**Context:** Extended the standard Factorio 30% per-tier quality scaling formula from electromagnetic projectors to pneumatic pumps, diverters, and capsule counters, increasing pressure propagation reach and sensing territory with quality tier.
**Key Changes:**
1. **Flow Simulation Scaling (`scripts/flow/flow-engine.lua`):** Evaluated runtime flow emission levels for pumps and diverters (base 10) and sensing seeds for capsule counters (base 15) using `math.floor(base * (1 + 0.3 * q_level))`, applied scaling during entity node connection, and added a one-time migration sweep across active devices.
2. **Alt-Mode Overlay Renderer (`scripts/flow/flow-renderer.lua`):** Clamped pressure level intensity ratios to `MAX_FLOW` using `math.min` to prevent Alt-Mode circle color component overflow when visualizing pressure levels exceeding 10.


### Revision: Implement Electromagnetic Harness Equipment for Powered Projector Player Launches
**Date:** 2026-09-12 00:51 EDT
**Context:** Added personal electromagnetic harness equipment to enable players to safely traverse electromagnetic projectors in player transit capsules while enforcing power buffer requirements and suppressing self-collision damage.
**Key Changes:**
1. **Harness Equipment & Prototype Definitions (`prototypes/item.lua`, `prototypes/recipe.lua`, `prototypes/technology.lua`):** Registered the `electromagnetic-harness` 2x2 suit equipment module and item with a 2 MJ buffer, 1 MW charge limit, and 20 kW idle drain; added the Fulgora electromagnetic manufacturing recipe and dedicated research technology node.
2. **Projector Intake & Launch Gatekeeping (`scripts/capsules/capsule-runner.lua`):** Extended `is_electromagnetic_capsule` and added `player_has_harness` to inspect player armor grids for active harnesses with over 100 kJ of stored energy, permitting powered transit capsules to enter projector intake docks and launch.
3. **Self-Collision Suppression (`scripts/capsules/capsule-runner.lua`):** Refined `check_player_collision` to verify player indices and character entity references against the capsule passenger, preventing projectiles from colliding with their own riders upon leaving the muzzle or during ballistic hops.
4. **Localization (`locale/en/config.cfg`):** Added English localization strings for the item, equipment module, crafting recipe, and technology unlock.


### Revision: Modularize Capsule Runner into Transit and Ballistics Subsystems
**Date:** 2026-09-12 09:53 EDT
**Context:** Decomposed the monolithic `capsule-runner.lua` into isolated domain modules for player transit safety and projector ballistics, eliminating patch collision hazards and bringing file sizes strictly below the 500-line ceiling.
**Key Changes:**
1. **Player Transit & Equipment Safety (`scripts/capsules/capsule-transit.lua`):** Extracted electromagnetic harness equipment energy inspection (>100 kJ gatekeeping), capsule electromagnetic classification, single-pass zero-allocation player bounding-box scratch caching (`scratch_player_targets`), self-collision suppression, and passenger emergency ejection.
2. **Kinetic Ballistics & Projector Physics (`scripts/capsules/capsule-ballistics.lua`):** Encapsulated electromagnetic projector launch dispatch (9 MJ capacitor requirement), 5-tile prominent kinetic hop progression, line-of-sight obstacle raycasting, receiver dock catchment, in-flight momentum preservation across sender deconstruction, and audio-visual spark/sound triggers.
3. **Tube Motion Simulation Coordinator (`scripts/capsules/capsule-runner.lua`):** Reduced core file size by over 500 lines down to ~490 lines, delegating projectile flight and passenger safety while preserving 6-tick staggered hop cadence, positive pressure graph traversal, diverter slot quality filtering, and backwards-compatible public API facade aliases.


### Revision: Modularize Active Device Scanner into Domain Subsystem Managers
**Date:** 2026-09-12 10:32 EDT
**Context:** Decomposed the monolithic 828-line active device scanner into dedicated domain managers to eliminate repetitive entity branching ladders and decouple machine-specific simulation from core 15-tick cadence dispatching.
**Key Changes:**
1. **Domain Subsystem Managers (`scripts/counters/counter-manager.lua`, `scripts/projectors/projector-manager.lua`, `scripts/pumps/pump-manager.lua`, `scripts/diverters/diverter-manager.lua`):** Created dedicated managers for capsule counters and electromagnetic projectors, and expanded hollow pump and diverter manager stubs into complete domain modules encapsulating device specifications, power/enable evaluations, orientation deltas, and Alt-Mode render triggers.
2. **Polymorphic Device Contract (`scripts/active-device-scanner.lua`):** Eliminated 14 hardcoded entity-type branching ladders across ghost adoption, fast-replacement caching, blueprint pasting, and entity destruction in favor of standardized polymorphic `spec` methods (`copy_settings`, `clear_settings`, `get_settings`, `is_direction_compatible`, `on_rotate_delta`, `on_settings_changed`).
3. **Scanner Core Slimming (`scripts/active-device-scanner.lua`):** Decoupled direct dependencies on individual device settings, logic, and renderer modules, reducing core scanner file size by ~360 lines down to ~470 lines while strictly preserving 15-tick cadence execution and storage schemas.


### Revision: Modularize Declarative GUI Components into Filter Spec and Quality Subsystems
**Date:** 2026-09-12 11:00 EDT
**Context:** Decomposed the monolithic 1,038-line `gui-components.lua` into dedicated domain modules for filter specifications and interactive quality selector bars to resolve separation-of-concerns violations and unblock modal dialog extractions.
**Key Changes:**
1. **Filter Display & Specification Engine (`scripts/utils/gui/gui-filter-spec.lua`):** Encapsulated Factorio 2.0 filter display specification queries (`get_filter_display_spec`, `get_active_filters`), quality sprite path resolution, rich text color formatters, comparator indexing, and native item/quality slot selection state mutations.
2. **Quality Control Bar Controller (`scripts/utils/gui/gui-quality-bar.lua`):** Encapsulated the 5-tier quality radio button layout builder (`add_quality_control_bar`), selection highlight updates, comparator dropdown synchronization, and native tier click event handlers.
3. **Window Layout Core & Public Facade (`scripts/utils/gui-components.lua`):** Streamlined the core component module to focus strictly on window frames, headers, switches, circuit condition panels, and spatial arrow selectors while preserving complete backwards-compatible public API aliases for all existing caller modules.


### Revision: Modularize Device Settings Copier into Blueprint Sync Subsystem
**Date:** 2026-09-12 11:34 EDT
**Context:** Decomposed the monolithic 794-line device settings copier to decouple blueprint serialization and proxy wire preservation from live player copy-paste interaction, while hardening workspace developer prompts against patch delimiter collisions and wildcard hallucinations.
**Key Changes:**
1. **Blueprint Synchronization Engine (`scripts/utils/blueprint-sync.lua`):** Encapsulated blueprint entity tag packing and extraction (`pneumatic_settings`), 4-element circuit wire tuple serialization across hidden channel and terminal proxies, zero-tick built wire target resolution, and blueprint book orphan proxy scrubbing (`clean_blueprint_orphans`).
2. **Live Device Settings Copier (`scripts/device-settings-copier.lua`):** Streamlined core file by over 600 lines down to 183 lines (~77% reduction), focusing strictly on player copy buffers (`storage.player_copy_buffer`), hotkey handlers, relative orientation deltas, and open GUI refreshes while delegating blueprint events and exposing backwards-compatible public API facade aliases.
3. **Developer Interaction & Workflow Hardening (`plan/core/PROMPT-AG-DIFF.md`, `plan/core/WORKFLOW.md`):** Codified the Facade Delegation Rule for codebase modularization, explicitly mandated 100% literal string matching without ellipsis (`...`) or gap wildcards, and restricted diff patcher execution strictly to source code files while establishing full file overwrites for documentation.


### Revision: Modularize Diverter GUI into Slot Modal Subsystem
**Date:** 2026-09-12 11:49 EDT
**Context:** Decomposed the monolithic 753-line diverter configuration GUI into dedicated domain modules to decouple modal slot filtering and draft state management from the main 4-port layout.
**Key Changes:**
1. **Diverter Slot Configuration Modal (`scripts/diverters/diverter-slot-modal.lua`):** Encapsulated the popup filter configuration frame (`filter_slot_config_frame`), draft filter state buffers (`draft_filters`), tick confirmation tracking (`confirm_ticks`), quality control bar event handlers, item choose-element changes, and confirm/cancel commit lifecycles.
2. **Main Diverter GUI & Facade Integration (`scripts/diverters/diverter-gui.lua`):** Streamlined the core frame module to focus strictly on the 4-direction port overview, 3x3 direction arrow selector, and per-port clipboard tools, exposing backwards-compatible public API facade aliases while delegating modal events to the new modal controller.


### Revision: Preserve Diverter Circuit Proxies on Ghost Build and Sync Ghost GUI Settings
**Date:** 2026-09-12 12:01 EDT
**Context:** Resolved circuit proxy deletion during ghost replacement caused by exact coordinate matching on 2x2 diverters, and ensured ghost entities inherit and display blueprint and pasted settings before physical construction.
**Key Changes:**
1. **Proxy Lifecycle & Spatial Discovery (`scripts/proxy-manager.lua`):** Introduced radius-based host entity discovery (`radius = 0.5`) in `find_main_at` and `on_object_destroyed`, preventing ghost cleanup routines from falsely destroying active circuit proxies when physical 2x2 diverters replace ghosts, and corrected Y-axis offset calculations.
2. **Ghost Blueprint Tag Extraction (`scripts/active-device-scanner.lua`):** Updated entity construction hooks to inspect `entity.tags` for ghosts alongside `event.tags`, applying blueprint settings immediately upon placement rather than overwriting ghost records with default blank configs.
3. **Live Ghost Settings Copying (`scripts/device-settings-copier.lua`):** Updated copy-paste dispatchers to resolve spatial device IDs on ghost targets, serializing active settings directly into `destination.tags` across pumps, diverters, counters, projectors, and hubs.
4. **Ghost GUI Initialization & Live Refresh (`scripts/diverters/diverter-gui.lua`, `scripts/pumps/pump-gui.lua`, `scripts/counters/counter-gui.lua`):** Added fallback tag restoration to GUI opening lifecycles to guarantee pasted ghost settings display prior to placement, and registered `on_settings_changed` subscribers to auto-refresh open windows on paste events.


### Revision: Normalize Refrigerated Capsule Crafting and Closed-Loop Recharge Recipes
**Date:** 2026-09-12 12:44 EDT
**Context:** Corrected thermodynamic fluid balance for refrigerated capsules by eliminating hot coolant byproduct output from the initial crafting recipe while preserving the closed-loop thermal coolant exchange on recharge.
**Key Changes:**
1. **Capsule Manufacturing Recipe (`prototypes/recipe.lua`):** Removed `fluoroketone-hot` byproduct from `refrigerated-capsule` results so newly crafted capsules retain coolant internally without generating phantom fluid.
2. **Coolant Recharge Recipe (`prototypes/recipe.lua`):** Configured explicit `main_product = "refrigerated-capsule"` and disabled `auto_recycle` on `recharge-refrigerated-capsule`, maintaining a net-zero 1:1 fluoroketone thermal displacement loop without recycler interference.


### Revision: Eliminate Quiescent Flow Flooding and Deconstruction Teardown Spikes
**Date:** 2026-09-12 14:01 EDT
**Context:** Resolved severe ambient UPS degradation on unpressurized pneumatic networks and eliminated multi-second freezes during mass deconstruction by gating passive queue insertions, evicting dead nodes, and removing redundant full-graph receiver scans.
**Key Changes:**
1. **Passive Graph Connection Gating (`scripts/flow/flow-engine.lua`):** Guarded port enqueuing in `connect_entity` to only insert ports into `storage.flow_queue` if active pressure, vacuum, sensing range, or emitters are present, preventing unpressurized grids from flooding the queue and keeping ambient simulation script time at 0.01 ms (60 UPS).
2. **Scroller & Receiver Deconstruction Optimization (`scripts/flow/flow-engine.lua`):** Restricted `flow_kinetic.clear_receiver_references` scans during removal events strictly to `pneumatic-projector` entities, eliminating multi-million-iteration graph loops when mining non-projector structures like junctions and tubes.
3. **Queue Eviction and Inactive Severance (`scripts/flow/flow-common.lua`):** Evicted destroyed nodes from `storage.flow_queue` immediately in `destroy_node`, and restricted neighbor enqueuing strictly to edges that carried active pressure or sensing while preserving 100% of neighbor capsule waking (`wake_port_parked`).
4. **Teardown Deduplication & Render Guards (`scripts/flow/flow-engine.lua`):** Added an `is_tracked` guard to `handle_object_destroyed` to skip redundant second teardown passes for entities already unlinked by mining events, and bypassed render dictionary cleanup loops in `disconnect_entity` when overlays are disabled.
5. **Adaptive Batching & Queue Diagnostics (`scripts/flow/flow-engine.lua`):** Scaled `flow_engine.step` batch limits dynamically to 200 items/tick when queue depth exceeds 500 to settle massive blueprint stamps within 2–3 seconds, and registered `/check-queue`, `/check-flow`, and `/clear-queue` console commands for in-game queue inspection.


### Revision: Implement Live Subsystem Performance Profiler and In-GUI Diagnostic Table
**Date:** 2026-09-12 17:08 EDT
**Context:** Implemented a sub-millisecond live subsystem performance profiler using native Factorio engine timers to isolate per-tick UPS bottlenecks across individual machines and simulation loops without chat console spam.
**Key Changes:**
1. **Subsystem Profiler Engine (`scripts/utils/profiler.lua`):** Established non-serialized native `LuaProfiler` accumulation routines, defensive single-argument method wrappers (`safe_add`, `safe_divide`, `safe_stop`), sub-routine timers, 60-tick window averaging, chunked snapshot formatting staying strictly below the 20-parameter `LocalisedString` limit, and an explicit master release switch (`profiler.ENABLED`).
2. **Centralized Event Hook Instrumentation (`scripts/events.lua`):** Wrapped event dispatching to automatically identify and classify subsystem handlers via `debug.getinfo`, recording tick execution times when active while maintaining zero overhead when idle.
3. **Active Device Scanner Sub-Timers (`scripts/active-device-scanner.lua`):** Instrumented `scan_active_devices` with dedicated sub-profilers isolating execution times for counters, diverters, pumps, projectors, and fast-replace cache pruning.
4. **Pneumatic Control Panel Live Table (`scripts/debug-manager.lua`):** Embedded an in-frame 3-column performance table dynamically refreshing live execution durations and entity workload metrics every second, purged chat streaming loops in favor of an on-demand snapshot action, and guarded profiler UI components behind `profiler.ENABLED`.


### Revision: Event-Driven Capsule Counter Territory Indexing
**Date:** 2026-09-12 17:35 EDT
**Context:** Resolved a major 1.83 ms scanner performance bottleneck caused by Capsule Counters polling hundreds of network sensor dots every 15 ticks by transitioning to an event-driven territory membership index.
**Key Changes:**
1. **Territory Capsule Index & Lifecycle (`scripts/counters/counter-range.lua`):** Established `storage.counter_capsules` to track resident capsule IDs per counter, implemented O(1) entry/exit transitions (`update_capsule_territory`, `unregister_capsule_territory`), added port ownership change listeners (`handle_port_owner_changed`), ensured clean destruction cleanup, and migrated active capsules on startup.
2. **Hop Occupancy & Removal Hooks (`scripts/capsules/capsule-queries.lua`):** Hooked `update_capsule_occupancy` and `remove_capsule` to update counter territory membership in lockstep with discrete 6-tick capsule motion and despawning.
3. **Territory-Scoped Signal Calculation (`scripts/counters/counter-logic.lua`):** Replaced full-network tube dot scans and per-entity table allocations with direct iteration over `counter_range.get_territory_capsules`, reducing active counter scan times from ~1.83 ms down to sub-microsecond levels.
4. **Wavefront Dynamic Boundary Sync (`scripts/flow/flow-engine.lua`):** Integrated `set_port_counter_ownership` with `counter_range.handle_port_owner_changed` to update resident capsules during wavefront expansion or recession, and purged counter capsule tracking upon entity destruction.


### Revision: Stable Capsule Signal Memoization and Incremental Territory Indexing
**Date:** 2026-09-12 18:11 EDT
**Context:** Optimized capsule counter background scanning by establishing a reusable capsule stability classifier and memoizing immutable circuit signal contributions upon packing. Decoupled territory exit subtraction from holder entity destruction by storing signal footprints directly in counter territory tables, eliminating periodic C++ inventory polling for unchanging cargo.
**Key Changes:**
1. **Capsule Stability Classifier (`scripts/capsules/capsule-definitions.lua`):** Centralized spoilability predicates (`is_stack_spoilable`, `is_unit_spoilable`) and implemented `is_dynamic_capsule` and `is_stable_capsule`, classifying invariant shells and non-spoilable cargo (including vacuum capsules whose durability changes at hubs) as fully stable while scoping dynamic handling strictly to refrigerated and player transit capsules.
2. **Signal Footprint Memoization (`scripts/capsules/capsule-manager.lua`):** Added `extract_holder_signal_data`, `get_signal_data`, and `is_stable` to pre-compute and store immutable vessel and cargo circuit signals directly on `storage.active_capsules[capsule_id].signal_data` during registration.
3. **Hub Packing Integration (`scripts/hubs/hub-packing.lua`):** Replaced local stack and unit spoilability checks with centralized `capsule_defs` predicates and evaluated the capsule stability flag upon packing to initialize memoized tracking.
4. **Incremental Territory Tracking & Unregistration Hardening (`scripts/counters/counter-range.lua`):** Established `storage.counter_stable_summary`, `storage.counter_stable_capsules`, and `storage.counter_dynamic_capsules`; stored signal data directly in territory tracking tables so exit subtraction succeeds even after holder entities are destroyed by hub unpacking; guarded additions against duplicate entries; standardized ID lookups to prioritize `capsule.capsule_id`; added zero-count dictionary purging; and added an automated sweep (`counter_stable_summary_v3`) to clear phantom counts on save load.
5. **Zero C++ Polling Logic (`scripts/counters/counter-logic.lua`):** Refactored `counter_logic.update_signals` to stream pre-aggregated stable signal summaries directly from memory into proxy filter tables, eliminating Factorio C++ entity and inventory queries for stable logistics networks and restricting slot iteration strictly to active dynamic capsules.


### Revision: Virtual Memory Cargo Suspension and Waveform Collapse for Refrigerated Transit
**Date:** 2026-09-12 20:18 EDT  
**Context:** Resolved premature C++ container spoilage decay and asymptotic 1-tick recheck loops on refrigerated capsules by suspending perishable cargo in Lua virtual memory during flight and collapsing it into physical stacks upon hub delivery or destruction.  
**Key Changes:**
1. **Virtual Memory Cargo Extraction (`scripts/hubs/hub-packing.lua`, `scripts/capsules/capsule-manager.lua`):** Suspended cargo items in refrigerated capsules inside `cap_data.virtual_cargo` as stack specifications rather than inserting them into physical liminal chest slots, shielding them from Factorio's engine-level 1.0 container decay. Normalized quality prototype resolution to strings to prevent concatenation failures.
2. **True Dilated Dual-Horizon Scheduling (`scripts/capsules/capsule-lifecycle.lua`):** Replaced the 1-second periodic scan loop with a true dilated horizon calculation waking up only at $\min(t_{\text{coolant}}, t_{\text{spoil\_dilated}})$. Preserved the flat 1 charge/second chamber model (Option A) with closed-form mathematical calculations for elapsed time, charge drain, and spent-hull transitions.
3. **Delivery and Spillage Waveform Collapse (`scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-manager.lua`):** Implemented `capsule_manager.collapse_virtual_cargo` to evaluate final dilated spoilage and coolant deductions upon delivery or destruction. Extended `hub-unpacking` space validation (`can_insert_all`) to account for virtual cargo, materializing exact stacks into hub inventories or spill containers.
4. **Dominant Cargo Inspection (`scripts/capsules/capsule-renderer.lua`):** Updated `get_dominant_item` to evaluate `virtual_cargo` entries when present, preventing refrigerated capsule shells from overwriting payload identities and restoring accurate cargo icons to Alt-Mode overlays, HUD indicators, and diverter filtering.
5. **Zero C++ Counter Polling (`scripts/counters/counter-logic.lua`, `scripts/counters/counter-range.lua`):** Integrated dynamic and virtual cargo into territory signal summaries, updating them via liminal state changes and completely removing the 15-tick C++ inventory scanning loop in counter logic.
6. **Acyclic Module Graph Architecture (`scripts/capsules/capsule-manager.lua`, `scripts/hubs/hub-spill.lua`):** Hosted the virtual collapse logic in the leaf `capsule-manager` module, removing circular requires between `capsule-lifecycle` and `hub-spill` to prevent engine startup recursion crashes.


### Revision: Virtualize Unit-Producing Spoilables, Unify Latent Scheduling, and Retire Liminal Moat
**Date:** 2026-09-12 21:15 EDT
**Context:** Eliminated physical enemy hatching and the secondary water moat grid on the liminal surface by expanding virtual cargo suspension to all unit-producing spoilables, transitioning all perishable cargo to event-driven latent timer scheduling and retiring periodic 60-tick inventory polling.
**Key Changes:**
1. **Selective Virtualization Pipeline (`scripts/hubs/hub-packing.lua`, `scripts/capsules/capsule-definitions.lua`):** Configured hub packing to virtualize spoilables in refrigerated capsules and unit-producing cargo (`biter-egg`, `pentapod-egg`, `captive-biter-spawner`) in any capsule, while classifying all spoilable carriers as dynamic in `capsule_defs.is_dynamic_capsule`.
2. **Moat Grid Retirement & Grid Unification (`scripts/surfaces/liminal-surface.lua`, `scripts/hubs/hub-packing.lua`):** Removed the 8-tile wide moat grid, water border painting, and wide-cell allocation requirements, standardizing all liminal holder slots onto a single compact 2-tile lab tile grid.
3. **Latent Spoil Scheduling & Zero-Polling Render Core (`scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-renderer.lua`):** Unified scheduling across virtual memory and physical stacks via `schedule_dynamic_cargo`, purged 60-tick periodic inventory polling from the renderer, and ensured spoilage state changes push visual cache invalidations and territory signal updates on the exact tick of decay.
4. **Dynamic Spoil Trigger Resolution & Quality Inheritance (`scripts/capsules/capsule-lifecycle.lua`):** Inspected C++ `spoil_to_trigger_result` prototype metadata to dynamically resolve spawn entities (`big-wriggler-pentapod-premature`, `big-biter`, `behemoth-biter`) and scaled unit counts by `items_per_trigger` (`ceil(count / items_per_trigger)`), inheriting the egg's exact quality tier on the spawned unit.
5. **Direct In-World Spawning & Legacy Moat Watcher Removal (`scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-runner.lua`):** Resolved real-world map coordinates from active flow nodes and hubs to spawn hatched enemies directly at the capsule's in-flight position, strictly banning liminal surface fallbacks and removing the legacy `handle_liminal_entity_spawn` event listeners and 60-tick unit search loop.
6. **Hybrid Signal Extraction & Coolant Depletion Guards (`scripts/capsules/capsule-manager.lua`):** Extended `extract_holder_signal_data` to aggregate both physical holder contents and virtual cargo specifications simultaneously, and guarded `collapse_virtual_cargo` so non-refrigerated capsules carrying unit-spoilables never convert into spent refrigerated shells.


### Revision: Reusable Pooled Binary Heap and Event-Driven Spoilage Scheduler
**Date:** 2026-09-12 22:48 EDT  
**Context:** Replaced O(N) per-capsule spoilage polling in the motion runner with an O(1) pooled indexed binary min-heap, eliminated immortal 1% coolant regeneration loops, and established event-driven eviction for completed cargo.  
**Key Changes:**
1. **Indexed Binary Heap Engine (`scripts/utils/binary-heap.lua`):** Established a reusable priority queue paired with an O(1) reverse hash map (`indices[id] = pos`), sliding virtual line buffer boundary (`size`) with zero-allocation table pooling, stable FIFO tie-breaking, and a 7-suite automated self-test runner (`/test-heap`).
2. **Event-Driven Spoil Scheduling (`scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-runner.lua`):** Decoupled dynamic spoilage evaluation from the 6-tick motion runner into a global `storage.spoil_heap` processed via `capsule_lifecycle.step_spoil_heap`, reducing idle tick cost from O(N) per-capsule table iterations to a single O(1) peek comparison.
3. **Coolant Depletion & Spent Conversion (`scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-manager.lua`):** Resolved the 1% immortal coolant regeneration bug by lowering the health clamp floor from `0.01` to `0.0001`, allowing final cooling charges to deplete to 0 and converting shells to `spent-refrigerated-capsule` while strictly inheriting the parent quality tier (`qual_name`) and refreshing Alt-Mode render caches.
4. **Automatic Stable Demotion & Eviction (`scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-manager.lua`):** Updated `calculate_virtual_dilated_recheck` to return `nil` when zero perishable items remain, evicting spoiled capsules from the heap, demoting them to `is_stable = true`, and evicting arriving or destroyed capsules in `capsule_manager.remove`.
5. **Diagnostic Inspection Commands (`scripts/debug-manager.lua`):** Registered strictly read-only `/check-spoil-heap` and `/pt-check-spoil-heap` commands reporting active timer depth, buffer capacity, and next scheduled capsule without modifying heap state.


### Revision: Timed Kinetic Arrival Scheduler and Spatial Trajectory BVH
**Date:** 2026-09-13 00:54 EDT
**Context:** Replaced per-capsule 6-tick hop traversal along kinetic projector beams with an event-driven binary min-heap arrival scheduler and introduced a surface-partitioned spatial Bounding Volume Hierarchy (BVH) for zero-polling observer viewport rendering.
**Key Changes:**
1. **Timed Kinetic Arrival Scheduler (`scripts/capsules/capsule-ballistics.lua`, `scripts/capsules/capsule-runner.lua`):** Scheduled projectile arrivals in `storage.kinetic_arrival_heap` with master toggle (`USE_TIMED_ARRIVAL`), immediately unparking launcher intake docks on dispatch to eliminate backpressure lockstep delays while resolving hot-reload metatable detachment.
2. **Spatial Trajectory BVH Engine (`scripts/utils/trajectory-bvh.lua`):** Implemented a surface-partitioned dynamic AABB tree subdividing beam corridors into discrete 16-tile leaf segments with closed-form distance timing ($1.2\text{ ticks/tile}$), tight diagonal bounding, and automated test suite (`/test-bvh`).
3. **Observer-Driven Viewport Culling (`scripts/capsules/capsule-renderer.lua`):** Replaced 60 Hz global capsule polling loops with `query_visible_flights` hit-testing against active player screen viewports, interpolating 60 FPS motion and passenger positions strictly for on-screen corridor segments.
4. **Deconstruction Momentum Preservation (`scripts/flow/flow-engine.lua`, `scripts/hubs/hub-spill.lua`):** Guarded in-flight timed projectiles from deconstruction teardown and ground spillage, preserving ballistic flight to downstream receivers when origin projectors are mined.
5. **BVH Visualization & Diagnostic Overlays (`scripts/debug-manager.lua`, `scripts/utils/trajectory-bvh.lua`):** Registered `/toggle-bvh` and `/pt-toggle-bvh` commands with in-game rendering routines displaying hierarchical parent boxes and green 16-tile leaf segments with live distance labels.


### Revision: Natural Queue-Driven Kinetic BVH Recession and Projector Port Dot Cleanup
**Date:** 2026-09-13 01:24 EDT
**Context:** Resolved persistent Alt-Mode port dots remaining after projector deconstruction and eliminated inconsistent BVH corridor segment removals by replacing instant deconstruction purges with natural 1-tile-per-tick flow queue recession.
**Key Changes:**
1. **Natural Wavefront & BVH Recession (`scripts/flow/flow-kinetic.lua`, `scripts/flow/flow-engine.lua`):** Removed synchronous node purges and forced BVH wipes on projector rotation and deconstruction (`handle_projector_destroyed`, `handle_projector_rotated`). Severing the muzzle node now enqueues the first kinetic beam tile into `storage.flow_queue`, driving natural 1-tile-per-tick queue recession across the beam.
2. **Uniform BVH Segment Unregistration (`scripts/flow/flow-kinetic.lua`):** Configured `unregister_segment_in_bvh` to remove corridor segments strictly when the receding wavefront reaches `leaf.d_end == cur_dist`, ensuring segments peel away sequentially whether an endpoint remainder segment exists or the beam terminates on a 16-tile boundary. Truncated forward orphaned segments upon new endpoint registration in `register_endpoint_in_bvh`.
3. **Projector Port Dot Deconstruction Cleanup (`scripts/flow/flow-engine.lua`):** Scoped `beam_owner` in `storage.flow_nodes` strictly to kinetic launch muzzles, preserving passive intake port coordinates during entity teardown so `flow_engine.disconnect_entity` cleanly wipes Alt-Mode intake and muzzle dots via `destroy_pos_renders`.
4. **BVH Key Normalization and Detached Node Safety (`scripts/utils/trajectory-bvh.lua`):** Guarded `remove_leaf_node` against nil parent references during structural tree collapses and aligned fallback `insert_trajectory` segment keys to standard directional string formatting (`dx,dy:s`).
5. **Flight Record Eviction & Spill Cleanup (`scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-ballistics.lua`):** Hooked `capsule_runner.remove_capsule` and ballistic collision/spill handlers to clear records from `storage.projector_flights`, preventing orphaned in-flight references from lingering in memory.


### Revision: Grid-Aligned Character Port Collision and Kinetic Beam Interception
**Date:** 2026-09-13 12:07 EDT
**Context:** Enabled player characters to act as mobile 1-tile grid entities on the pneumatic network, resolving dual-axis half-offset alignment with electromagnetic projector beams and enabling pure spatial hash-map beam interception and regrowth.
**Key Changes:**
1. **Dual-Grid Character Port Resolution (`scripts/flow/port-defs.lua`):** Implemented `get_character_port_pos` and `get_character_port` to calculate distance squared against North/South (half-x, int-y) and East/West (int-x, half-y) projector beam alignments, dynamically snapping moving characters to the matching beam axis with directional tie-breaking.
2. **Alt-Mode Character Dot Overlay (`scripts/flow/flow-renderer.lua`):** Added `update_character_renders` and `destroy_character_renders` to render a 0.12r magenta dot at the character's grid-aligned port position, leveraging in-place C++ `current.target` mutation to eliminate garbage collection overhead.
3. **Kinetic Grid Port Collider & Hash-Map Wakeups (`scripts/flow/flow-kinetic.lua`):** Added an $O(1)$ spatial check to `check_tile_obstruction` and implemented `step_character_colliders` with a 4-cardinal `wake_beam_pointing_at` neighbor lookup in `storage.flow_grid`, intercepting incoming beams upon entering a tile and unblocking preceding endpoints (`d_start - 1`) upon evacuation without ray-box scans.
4. **Step Loop & Lifecycle Wiring (`scripts/flow/flow-engine.lua`):** Initialized character collider and position tracking tables in `init_storage`, wired collider transitions and overlay updates into `flow_engine.step` prior to queue sleep checks, and exported public facade aliases.


### Revision: Expand Player Kinetic Port Footprint to 1-Node Influence Radius
**Date:** 2026-09-13 12:35 EDT
**Context:** Resolved repetitive beam unblocking and micro-wake chatter caused by single-tile character collider transitions and axis-snapping jitter during player motion along kinetic beam corridors.
**Key Changes:**
1. **1-Node Multi-Axis Influence Footprint (`scripts/flow/port-defs.lua`):** Implemented `get_character_influence_positions` to generate a 1-node radius neighborhood spanning both primary and secondary grid alignments, and widened the `get_character_port_pos` directional deadband to 0.15 to prevent diagonal axis oscillation while walking.
2. **Delta Influence Set Management (`scripts/flow/flow-kinetic.lua`):** Refactored `step_character_colliders` to track active influence keys (`storage.character_last_keys`), maintaining continuous collider coverage across overlapping tiles during movement and restricting wakeups strictly to nodes that completely exit the 1-node footprint.


### Revision: Defer Kinetic BVH Segment Unregistration for In-Flight Capsule Time Slices
**Date:** 2026-09-13 13:03 EDT
**Context:** Resolved viewport capsule rendering dropouts caused by building obstructions, character collisions, and beam recession waves abruptly purging BVH spatial segments while projectiles were still traversing their spatiotemporal intervals.
**Key Changes:**
1. **Temporal Flight Boundary Inspection (`scripts/utils/trajectory-bvh.lua`):** Implemented `trajectory_bvh.has_flight_in_leaf` to check if active projectile flights are traversing or approaching a leaf node's time slice window based on calculated departure ticks ($t_{\text{exit}} = t_{\text{start}} + \lceil d_{\text{end}} \times 1.2 \rceil$).
2. **Deferred Segment Unregistration & Remainder Namespacing (`scripts/flow/flow-kinetic.lua`):** Purged premature forward segment truncation from `register_endpoint_in_bvh`, isolated remainder keys with `:rem:%d` so terminal bounds do not overwrite full 16-tile segments, deferred receding segment removals in `unregister_segment_in_bvh` when active flights remain, and added `step_pending_bvh_segments` for zero-allocation in-place queue compaction.
3. **Launch Trajectory Re-insertion Guard & Arrival Cleanup (`scripts/capsules/capsule-ballistics.lua`):** Guarded batch trajectory insertion during projectile launch to avoid wiping active incremental or deferred BVH segments, and triggered immediate pending segment pruning upon flight arrival or collision in `remove_flight`.
4. **Storage Schema Persistence (`scripts/flow/flow-engine.lua`):** Initialized `storage.pending_bvh_segments` in `flow_engine.init_storage` to guarantee persistent tracking across save and load cycles.


### Revision: Isolate Remainder Unregistration and Guard Regrown BVH Segments
**Date:** 2026-09-13 13:55 EDT
**Context:** Resolved a critical BVH index regression where beam regrowth after obstacle movement or evacuation failed to restore upstream corridor segments (e.g., missing `[0-16]`), caused by remainder unregistration aliasing and stale deferred deletion queues purging newly inserted leaves.
**Key Changes:**
1. **Isolated Remainder Unregistration (`scripts/flow/flow-kinetic.lua`):** Decoupled `unregister_endpoint_remainder_in_bvh` from general segment unregistration so advancing terminal nodes specifically target matching `:rem:%d` keys, preventing boundary endpoints (e.g., tile 16 or 32) from mistakenly purging full 16-tile corridor segments.
2. **Pending Removal Invalidation (`scripts/flow/flow-kinetic.lua`):** Updated `register_segment_in_bvh` to immediately scrub matching pending removal items from `storage.pending_bvh_segments` whenever a corridor segment regrows.
3. **Reference Equality Guard (`scripts/flow/flow-kinetic.lua`):** Hardened `step_pending_bvh_segments` to verify that the active tree node strictly matches the queued leaf reference (`current_leaf == leaf`), preventing deferred cleanup sweeps from unindexing freshly regrown segments.


### Revision: Dynamic Crash Site Rescheduling and Occlusion Clearance for Ballistic Projectiles
**Date:** 2026-09-13 18:52 EDT
**Context:** Enabled in-flight kinetic projectiles scheduled for impact to dynamically recalculate their crash sites and arrival horizons when corridor occlusions move, clear, or realign with downstream receivers before impact occurs, eliminating phantom mid-air crashes.
**Key Changes:**
1. **Dynamic Projector Flight Updater (`scripts/capsules/capsule-ballistics.lua`):** Implemented `update_projector_flights` to evaluate capsule positions from elapsed flight time ($1.2\text{ ticks/tile}$), raycast forward along the beam vector for active obstacles or receivers, recalculate terminal coordinates, hop chains, and arrival horizons, re-index arrival heap entries in `storage.kinetic_arrival_heap`, and synchronize spatial BVH trajectories.
2. **Just-In-Time Impact Clearance Guard (`scripts/capsules/capsule-ballistics.lua`):** Hardened `finalize_timed_arrival` to verify physical obstacle presence at `bf.terminal_pos` before executing spillage, dynamically extending cleared or receiver-aligned projectiles forward to downstream targets without premature destruction.
3. **Corridor Occlusion Event Hooks (`scripts/flow/flow-kinetic.lua`):** Wired `update_projector_flights` into `handle_obstacle_changed`, `step_port`, `wake_beam_pointing_at`, and `step_character_colliders`, immediately triggering trajectory recalculations when structures are built or mined, gates toggle, or characters traverse beam paths.


### Revision: Calibrate Kinetic Beam Endpoints and Implement Player Impact Crash Damage
**Date:** 2026-09-13 20:33 EDT
**Context:** Resolved projectile fly-throughs past severed endpoints by purging unbounded in-flight raycasts, calibrated character colliders to their true grid ports, and fixed impact damage so players and vehicles take splash damage while crash spill containers remain protected.
**Key Changes:**
1. **Character Port Footprint Calibration (`scripts/flow/port-defs.lua`):** Restricted `get_character_influence_positions` strictly to the character's primary and secondary grid-aligned port coordinates, eliminating artificial 1-node boundary padding that caused kinetic beams to terminate 1–2 tiles prematurely.
2. **Graph-Bound Trajectory Synchronization (`scripts/capsules/capsule-ballistics.lua`):** Replaced unbounded 50-tile in-flight raycasts in `update_projector_flights` with active flow graph endpoint queries (`get_beam_endpoint`), preventing projectiles from retargeting to disconnected downstream projectors across severed gaps.
3. **Crash Damage Engine & Immunity Refinement (`scripts/capsules/capsule-ballistics.lua`):** Implemented `apply_crash_damage` with a 3.5-tile blast radius and quality-scaled impact falloff, replaced beam-ignorable filters with dedicated entity immunity checks so players and vehicles take impact damage, and shielded `visible-capsule-holder` spill containers from damage.
4. **Immediate Non-Receiver Arrival Finalization (`scripts/capsules/capsule-ballistics.lua`):** Streamlined `finalize_timed_arrival` to immediately trigger impact spillage and crash damage upon reaching non-receiver endpoints, preventing false clearance re-checks from rescheduling arrivals into endless fly-through loops.


### Revision: Timed Arrival Dot Visualizer and Dynamic Trajectory Reticle Sync
**Date:** 2026-09-13 21:43 EDT
**Context:** Implemented visual arrival target reticles for in-flight timed capsules to display scheduled landing positions and crash sites on the map, dynamically reflecting in-flight obstacle clearance and trajectory updates with player-scoped debug controls.
**Key Changes:**
1. **Arrival Dot Visualizer & Viewport Synchronization (`scripts/capsules/capsule-renderer.lua`):** Implemented `render_arrival_dot_for_player` and `sync_all_arrival_dots` to render dual-component arrival reticles (capsule variant color inner dot, green receiver ring, or orange-red obstacle crash ring), updating target positions in-place on existing render objects to eliminate allocation churn.
2. **Ballistic State & Trajectory Hook Integration (`scripts/capsules/capsule-ballistics.lua`):** Wired arrival dot generation into `dispatch_timed_launch`, dynamically shifted reticle targets to updated coordinates during occlusion recalculations in `update_projector_flights`, and ensured immediate destruction on arrival or impact in `finalize_timed_arrival` and `remove_flight`.
3. **Decoupled Debug Toggle & Panel Controls (`scripts/debug-manager.lua`):** Added the `arrival_dots` player storage setting and migration, added the "Timed Arrival Dots" checkbox to the Pneumatic Debug Panel, and registered `/toggle-arrival-dots` console commands while keeping the module decoupled from runtime rendering requirements to prevent circular load cycles.


### Revision: Restore Projectile Forward Horizon Scanning and Acyclic Module Dispatch
**Date:** 2026-09-13 23:55 EDT  
**Context:** Resolved silent in-flight capsule update failures and backwards-teleport crash bugs caused by dead module loader table lookups and muzzle-bound endpoint queries that lacked forward momentum awareness.  
**Key Changes:**
1. **Acyclic Module Dispatch Linkage (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Replaced dead `package.loaded["scripts.capsules.capsule-ballistics"]` lookups across all five event sites in `flow-kinetic.lua` with direct invocations of `flow_kinetic.update_projector_flights`, populated directly by `capsule-ballistics.lua` at script load time.
2. **Timestamp-Aware Forward Horizon Scanning (`scripts/capsules/capsule-ballistics.lua`):** Extended `capsule_ballistics.get_beam_endpoint` with an optional `start_dist` parameter and calculated current distance from elapsed ticks ($\lfloor (t_{\text{now}} - t_{\text{start}}) / 1.2 \rfloor$), restricting endpoint discovery strictly to tiles ahead ($dist > cur\_dist$) to prevent obstacles behind flying capsules from pulling them backward.
3. **Control Flow & Endpoint Nesting Repair (`scripts/capsules/capsule-ballistics.lua`):** Repaired conditional block nesting in `update_projector_flights` to ensure arrival tick recalculation, binary heap rebalancing, BVH bounding updates, and arrival reticle synchronization trigger reliably whenever the downstream endpoint changes.
4. **Targeted Non-Spammy Diagnostic Logging (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Embedded scoped `[KINETIC-DEBUG]` visual logging covering wake triggers, endpoint state transitions, and in-flight target adjustments while strictly bypassing intermediate advancing queue steps.


### Revision: Spatial BVH Obstacle Hit-Testing and Timestamp-Aware Forward Projectile Tracking
**Date:** 2026-09-14 00:30 EDT  
**Context:** Replaced the brute-force O(N) projector scan on entity placement and deconstruction with hierarchical Trajectory BVH queries, eliminated the backwards-teleporting flight crash bug via timestamp-aware forward distance scanning, and silenced premature flight target updates during intermediate beam regrowth.  
**Key Changes:**
1. **Spatial Obstacle Interception (`scripts/flow/flow-kinetic.lua`):** Replaced the map-wide `storage.active_projectors` scan in `handle_obstacle_changed` with a surface-isolated dynamic BVH query (`tree:query_box`), pruning empty-space build/mine checks in $O(\log N)$ time and enqueuing only the intersected beam distance slice.
2. **Endpoint Finalization Gating (`scripts/flow/flow-kinetic.lua`):** Suppressed intermediate `update_projector_flights` dispatches during 1-tile-per-tick beam regrowth, restricting flight rescheduling strictly to confirmed endpoint events (max range open-air terminations, receiver docks, or obstacle collisions).
3. **Forward Horizon Flight Scanning (`scripts/capsules/capsule-ballistics.lua`):** Enforced timestamp-aware forward scanning in `update_projector_flights` using elapsed ticks ($d > \text{cur\_dist}$), ignoring occlusions behind flying projectiles to prevent backward-teleport crashes while maintaining forward ballistic momentum.
4. **Diagnostic Logging & Profiling (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Cleaned up diagnostic chat output by gating `update_projector_flights` calls behind non-empty flight sets, eliminating console spam on idle beam state transitions.


### Revision: Harden Forward Projectile Tracking and Retire Character Feet Dot Overlay
**Date:** 2026-09-14 00:53 EDT  
**Context:** Resolved projectile backward-sucking crashes by enforcing forward-only horizon scanning based on elapsed flight time, eliminated map-wide brute-force projector scans on entity events via the Trajectory BVH, purged diagnostic chat logging, and retired visual feet dots while preserving the underlying physical grid collider.  
**Key Changes:**
1. **In-Flight Horizon Scanning & Momentum Preservation (`scripts/capsules/capsule-ballistics.lua`):** Calculated distance traveled from elapsed ticks ($1.2\text{ ticks/tile}$) and scoped `get_beam_endpoint` strictly ahead ($dist > cur\_dist$), ignoring rear beam recession and preventing in-flight capsules from teleporting backward to crash when players cross launcher muzzles.
2. **Spatial BVH Obstacle Interception (`scripts/flow/flow-kinetic.lua`):** Replaced the map-wide `storage.active_projectors` scan in `handle_obstacle_changed` with a localized Trajectory BVH query (`tree:query_box`), early-exiting on empty space in $O(\log N)$ time and alerting only directly intersected beam corridors.
3. **Acyclic Module Linkage & Console Cleanup (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Directly linked `flow_kinetic.update_projector_flights` at load time and purged all raw `[KINETIC-DEBUG]` chat logging from runtime execution paths.
4. **Character Footprint Visual Retirement (`scripts/flow/flow-engine.lua`, `scripts/flow/flow-renderer.lua`):** Removed the 60 Hz `update_character_renders` step invocation and deactivated character drawing routines while wiping existing render circles on save load, preserving the underlying $O(1)$ discrete dual-grid collider (`storage.character_colliders`) for silent 60 UPS physical beam blocking.


### Revision: Continuous Ballistic Interpolation, Receiver Edge Docking, and Speed Scaling
**Date:** 2026-09-14 01:28 EDT  
**Context:** Resolved in-flight projectile position snapping during dynamic obstacle rescheduling by calculating position from continuous origin-relative velocity, eliminated the gap between kinetic beams and receiving projectors by docking endpoints to perimeter edge sockets, synchronized arrival heap durations to traveled distance, and introduced a configurable speed scaling constant for ballistics testing.  
**Key Changes:**
1. **Continuous Velocity Interpolation (`scripts/capsules/capsule-renderer.lua`):** Refactored `get_interpolated_position` to calculate capsule coordinates from elapsed ticks and constant forward velocity along the travel vector (`start_pos + dir * dist_traveled`) clamped to the destination, eliminating frame-to-frame position snapping when downstream arrival ticks and terminal coordinates recalculate.
2. **Receiver Edge Hull Docking (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Updated kinetic wavefront propagation to create receiver terminal nodes at the perimeter edge socket ($cx - dir.x \times 1.5, cy - dir.y \times 1.5$) rather than stopping on preceding tiles in the dirt, and aligned ballistics destination coordinates and timed arrival dots to the exact same perimeter socket.
3. **Distance-Synchronized Arrival Timing (`scripts/capsules/capsule-ballistics.lua`):** Scaled `flight_ticks` directly from traveled distance (`ceil(total_dist * TICKS_PER_TILE)`) at launch and dynamic recalculation, eliminating hop quantization mismatches and keeping binary heap arrival popping in exact frame-perfect synchrony with visual arrival.
4. **Configurable Ballistics Speed Constant (`scripts/capsules/capsule-ballistics.lua`, `scripts/utils/trajectory-bvh.lua`):** Established `TICKS_PER_HOP` and `TICKS_PER_TILE` constants in capsule ballistics propagated to the Trajectory BVH, enabling single-value speed adjustments (e.g. 10× slow-motion testing at 60 ticks/hop vs normal 6 ticks/hop) without desynchronizing viewport spatial culling.


### Revision: Instantiable Procedural BVH and High-Water Node Recycling Pool
**Date:** 2026-09-14 09:50 EDT
**Context:** Refactored the Trajectory Bounding Volume Hierarchy from a metatable-bound class into an instantiable, procedural spatial tree engine to guarantee save/load serialization safety without metatables. Implemented a zero-allocation high-water mark recycling pool for tree nodes, expanded the API with generic procedural primitives, and calibrated automated self-tests to dynamically adapt to configurable ballistic flight speeds.
**Key Changes:**
1. **Procedural Tree Schema (`scripts/utils/trajectory-bvh.lua`):** Implemented `trajectory_bvh.new_tree(surface_index)` returning pure data tables with decoupled state (`root`, `size`, `free_nodes`, `free_count`, `leaves_by_key`), hardened `attach` to lazily migrate older schema formats, and eliminated metatable dependencies for Factorio `storage` serialization safety.
2. **High-Water Node Recycling Pool (`scripts/utils/trajectory-bvh.lua`):** Implemented `lease_node` and `recycle_node` to reuse detached internal nodes and segment leaves across beam fluctuations, eliminating Lua garbage collection churn and memory fragmentation.
3. **Generic Procedural BVH API (`scripts/utils/trajectory-bvh.lua`):** Exported procedural methods taking `tree` as their first parameter (`insert`, `remove`, `update`, `get_leaf`, `clear`, `capacity`), supported polymorphic `query_box` handling both AABB tables and 4-point scalar coordinates, and maintained 100% backwards-compatible colon-syntax for existing kinetic callers.
4. **Speed-Agnostic Automated Test Suite (`scripts/utils/trajectory-bvh.lua`):** Extended `/test-bvh` with Test 5 (pure table operations with metatables stripped) and Test 6 (zero-reallocation recycling verification), and updated Test 3 to dynamically calculate spatiotemporal distance arrival windows against `TICKS_PER_TILE`.
5. **Roadmap Architecture Expansion (`MOTION-REFACTOR.md`):** Formulated Phase 1.5 defining working-set proportional gating, amortized trickle decay, and save-file serialization compaction across both Spatial Trajectory BVHs and Indexed Binary Heaps.


### Revision: Dual-Watermark Pool Deflation, Amortized Decay, and Boundary Compaction
**Date:** 2026-09-14 10:02 EDT
**Context:** Implemented Phase 1.5 of the Motion Refactor to eliminate memory retention and save-file serialization bloat across both high-water pooling structures (Spatial Trajectory BVH free lists and Indexed Binary Heap sliding buffers) following deconstruction spikes or arrival bursts.
**Key Changes:**
1. **Binary Heap Sliding Buffer Deflation (`scripts/utils/binary-heap.lua`):** Implemented `step_decay` with dual-watermark hysteresis (trigger ceiling at `size * 3 + 128`, retention floor at `size * 1.5 + 64`), truncating up to 8 idle tail slots per cycle into `nil` without allocation thrashing. Added `compact(safety_margin)` for immediate tail truncation.
2. **Trajectory BVH Proportional Gating & Pool Decay (`scripts/utils/trajectory-bvh.lua`):** Gated `recycle_node` to drop detached nodes directly to Lua GC once `free_count >= max(64, size * 2)`. Implemented amortized `step_decay` with dual-watermark bounds and added `compact(safety_margin)` for immediate free list clamping.
3. **Save-File Boundary Compaction (`control.lua`):** Clamped cold buffers for `storage.spoil_heap`, `storage.kinetic_arrival_heap`, and all trees in `storage.surface_bvh` and `storage.viewport_bvh` to 64 safety items during `setup_storage` (`on_init` and `on_configuration_changed`), preventing deconstructed megabases from inflating save files or autosave times.
4. **Low-Frequency Maintenance Cadence (`control.lua`):** Registered a 120-tick maintenance cycle via `script.on_nth_tick(120)` to bleed down surplus pooling buffers smoothly over 10–30 seconds.
5. **Automated Verification Suites (`scripts/utils/binary-heap.lua`, `scripts/utils/trajectory-bvh.lua`):** Extended `/test-heap` with Test 8 and `/test-bvh` with Test 7, validating working-set limits, step-by-step evictions, and compaction boundaries.


### Revision: Native LuaRenderObject Cache and Zero-Allocation Recycling Pool
**Date:** 2026-09-14 10:15 EDT
**Context:** Implemented Phase 2 of the Motion Refactor to eliminate LuaRenderObject allocation and destruction churn during runtime capsule flight, timed arrival tracking, and viewport culling.
**Key Changes:**
1. **Centralized Render Pool Engine (`scripts/utils/render-pool.lua`):** Created a high-throughput cache for native Factorio 2.0 `LuaRenderObject` instances partitioned by player, surface, and visual archetype (`circle`, `sprite`, `text`, `line`). Leased handles mutate properties in-place while recycled objects toggle `visible = false` into player free lists with a 128-object per-archetype high-water mark ceiling.
2. **Polymorphic Table Signatures (`scripts/utils/render-pool.lua`):** Implemented `normalize_lease_args` supporting both single-table call syntax (`lease_circle{...}`) matching Factorio's native `rendering.draw_*` API and multi-argument signatures (`lease_circle(player_index, surface, options)`).
3. **Capsule Flight & Arrival Dot Integration (`scripts/capsules/capsule-renderer.lua`):** Replaced direct engine calls with `render_pool.lease_*` for passenger eject alerts, status rings, dominant cargo icons, fallback dots, and timed arrival reticles. Replaced object destruction on viewport exit with `recycle_capsule_render`.
4. **Debug & Diagnostic Suite (`scripts/debug-manager.lua`, `scripts/utils/render-pool.lua`):** Added the `/test-render-pool` command verifying leasing, recycling, zero-allocation handle reuse (0 C++ object churn), property updates, and clean pool destruction across 6 automated stages, and linked pool clearing into `/clear-renders`.


### Revision: Player Viewport Spatial BVH and Concentric Hysteresis Caching
**Date:** 2026-09-14 10:25 EDT
**Context:** Implemented Phase 3 of the Motion Refactor to decouple observer tracking from runtime game polling and establish a surface-partitioned spatial index of player screens.
**Key Changes:**
1. **Viewport Spatial Tree Engine (`scripts/utils/viewport-bvh.lua`):** Created dedicated surface trees in `storage.viewport_bvh[surface_index]` indexing player viewports as dynamic leaves via `trajectory_bvh`.
2. **Concentric Hysteresis Bounds (`scripts/utils/viewport-bvh.lua`):** Formulated a 3-tier bounding model per player:
   - *Inner Shrunk AABB (0.5× width/height):* Detects zoom-in contraction to shrink oversized shells.
   - *Padded Viewport AABB (+12 tiles):* The active culling boundary preventing pop-in during high-speed transit.
   - *Outer Fat Shell (+24 tiles):* The spatial hysteresis shell. Camera motion within this boundary incurs 0 tree updates; only breaches trigger `trajectory_bvh.update`.
3. **Logarithmic Viewport Queries (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Replaced linear per-player array scans in `capsule_renderer.is_in_any_viewport` with $O(\log N_{\text{players}})$ spatial BVH queries (`is_in_any_viewport`, `query_players_in_box`).
4. **Debug & Visualizer Suite (`scripts/debug-manager.lua`, `scripts/utils/viewport-bvh.lua`):** Added the `/test-viewport-bvh` test suite validating initialization, intra-shell zero-update stability, boundary breach recentering, zoom-in contraction, and spatial hit-testing across 5 automated stages, alongside `/toggle-viewport-bvh` rendering concentric gold/green/cyan bounding boxes in Alt Mode.


### Revision: Observer Intersection Engine and Active Visibility Sets
**Date:** 2026-09-14 10:30 EDT
**Context:** Implemented Phase 4 of the Motion Refactor to establish an event-driven notification bridge connecting observer viewports to motion corridors without polling whole maps or active capsules.
**Key Changes:**
1. **Active Visibility Sets (`scripts/utils/viewport-bvh.lua`):** Established `storage.player_visible_set[player_index]` to track on-screen motion corridors and spatial segments per player, formalizing `storage.motion_bvh` alongside `storage.surface_bvh`.
2. **Hysteresis Breach Synchronization (`scripts/utils/viewport-bvh.lua`):** Wired `sync_player_visibility` into player viewport boundary breaches, performing differential spatial queries against the surface motion BVH to subscribe entering nodes and evict leaving nodes while recycling visual primitives to `render_pool`.
3. **Corridor Event Subscriptions (`scripts/flow/flow-kinetic.lua`):** Integrated `viewport_bvh.on_segment_registered` and `on_segment_removed` across kinetic beam segment registration, remainder registration, endpoint shifts, and beam recession waves, alerting only overlapping player viewports in $O(\log N_{\text{players}})$ time.
4. **Verification Expansion (`scripts/utils/viewport-bvh.lua`):** Extended `/test-viewport-bvh` with Test 6 (observer intersection on viewport breach) and Test 7 (event-driven corridor registration and removal), bringing the automated verification suite to 7 passing stages.


### Revision: Per-Player Sliding-Scale Render Dispatcher and Speed-Agnostic Telemetry
**Date:** 2026-09-14 10:55 EDT
**Context:** Implemented Phase 5 of the Motion Refactor to execute closed-form vector interpolation strictly over local on-screen corridor segments per player, and resolved lingering static dock render handles upon timed projectile launch.
**Key Changes:**
1. **Per-Player Render Dispatcher (`scripts/capsules/capsule-renderer.lua`):** Replaced map-wide BVH flight searches with `dispatch_player_renders`, iterating strictly over the localized `storage.player_visible_set[player_index]` flat table ($O(N_{\text{visible\_on\_screen}})$ complexity).
2. **Cadence Governor & Interleaving (`scripts/capsules/capsule-renderer.lua`, `scripts/debug-manager.lua`):** Implemented individual player refresh cadences ($C \in \{1, 2, 3, 6\}$ ticks) with phase-staggered interleaving (`(tick + p_idx) % C == 0`) and early exits for Alt-Mode toggle-off, disabled capsule overlays, or map chart view (0.00 ms script cost).
3. **Ghost Render Purge on Launch (`scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-renderer.lua`):** Exported `clear_capsule_render` and invoked it immediately when a projector launch is triggered, alongside a per-tick cleanup sweep in `update_timed_capsules`, preventing static tube/dock visual handles from remaining orphaned at launcher ports during ballistic flight.
4. **Decoupled Clear Hooks (`scripts/debug-manager.lua`, `scripts/capsules/capsule-renderer.lua`):** Established `debug_manager.register_clear_hook` to eliminate circular top-level `require` recursion between debug management and capsule rendering.
5. **Speed-Agnostic Verification (`scripts/capsules/capsule-renderer.lua`):** Registered `/set-render-cadence <1|2|3|6>` and added `/test-render-dispatcher`, dynamically evaluating closed-form vector math against `TICKS_PER_TILE`, early-exit conditions, cadence phase interleaving, and in-place target mutation across 5 passing stages.


### Revision: Decouple Flight Corridor Motion BVH from Projector Beam Occlusion
**Date:** 2026-09-14 11:35 EDT
**Context:** Decoupled the observer flight corridor motion BVH from the projector's physical beam occlusion tree to prevent in-flight projectiles from prematurely losing visual rendering when launcher beams flicker, unpower, rotate, or recede.
**Key Changes:**
1. **Dedicated Flight Corridor Spatial Tree (`scripts/utils/viewport-bvh.lua`, `scripts/utils/timed-motion.lua`):** Broken the aliasing between `storage.surface_bvh` and `storage.motion_bvh`, formalizing `storage.motion_bvh[surface_index]` as an autonomous spatial tree dedicated strictly to in-flight projectile trajectories and observer viewport culling.
2. **Projector Beam Decoupling (`scripts/flow/flow-kinetic.lua`):** Removed observer viewport registration and removal hooks (`viewport_bvh.on_segment_registered`, `viewport_bvh.on_segment_removed`) from kinetic beam step loops and recession handlers, reserving `storage.surface_bvh` exclusively for beam line-of-sight raycasting and Phase 7 beam dot virtualization.
3. **Corridor Lifecycle & Flight Pinning (`scripts/utils/timed-motion.lua`):** Implemented `ensure_corridor` and `remove_corridor` in `timed_motion` to partition flight paths into 16-tile static leaves, notify player viewports upon projectile dispatch, pin corridors in memory while flights remain active, and retire leaves only after the last capsule lands or impacts.
4. **Maintenance Compaction & Decay Sync (`control.lua`):** Added `storage.motion_bvh` to save-file boundary pool compaction during `setup_storage` and low-frequency amortized free list decay on 120-tick maintenance cycles.
5. **Comprehensive Verification:** Validated all 17 automated test stages across `/test-timed-motion` (5 stages), `/test-viewport-bvh` (7 stages), and `/test-render-dispatcher` (5 stages), confirming zero dropped frames during flight and clean observer set eviction.


### Revision: Restore Receiver Target Ring Rendering and Perimeter Socket Snapping
**Date:** 2026-09-14 11:59 EDT
**Context:** Resolved missing kinetic target rings and socket alignment offsets on receiving projectors by assigning active kinetic levels to receiver terminal nodes and snapping endpoint positions directly to perimeter intake sockets.
**Key Changes:**
1. **Receiver Dock Kinetic Level Assignment (`scripts/flow/flow-kinetic.lua`):** Assigned `storage.kinetic_levels[next_pkey]` upon receiver detection so `flow_renderer.update_kinetic_pos_render` validates an active level (>0) and renders the cyan receiver target ring (`radius = 0.35`).
2. **Perimeter Edge Socket Snapping (`scripts/flow/flow-kinetic.lua`):** Snapped receiver endpoint coordinates to the projector's perimeter edge socket (`cx - dir.x * 1.5, cy - dir.y * 1.5`), centering the visual target ring, arrival reticle dot, and ballistic landing coordinates directly on the intake dock socket.
3. **Unified Reach Horizon Docking (`scripts/flow/flow-kinetic.lua`):** Unified receiver docking across both intermediate flight hops and maximum-reach terminations (`target_kinetic == 1`), ensuring beams reliably dock with projectors placed at terminal boundaries.
4. **Preceding Endpoint Demotion (`scripts/flow/flow-kinetic.lua`):** Cleared `is_endpoint` and unregistered endpoint remainder segments from preceding nodes when advancing to a receiver dock, eliminating phantom duplicate rings.


### Revision: Enforce Pressure-Entry Projector Gatekeeping and Motion BVH Occlusion
**Date:** 2026-09-14 12:35 EDT
**Context:** Resolved premature projectile launching at receiver docks by gating launch dispatch strictly behind pressure-driven intake entries, docked received capsules to passive intake sockets, and connected in-flight kinetic capsules to dynamic obstacle occlusion via the motion corridor BVH independently of projector entities.
**Key Changes:**
1. **Pressure-Entry Launch Gatekeeping (`scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-ballistics.lua`):** Added the `entered_via_pressure` transit flag set strictly when a capsule hops across an external edge into a projector via pressure gradients, and gated `try_projector_launch` behind this flag so kinetically received capsules cannot immediately fire from the receiver.
2. **Intake Dock Catchment & Snapping (`scripts/capsules/capsule-ballistics.lua`):** Corrected receiver endpoint fallback parking in `finalize_timed_arrival` to resolve non-muzzle passive intake sockets rather than defaulting to the launch muzzle (`r_ports[1]`), ensuring received capsules park cleanly until siphoned out by connected line vacuum.
3. **Decoupled Motion Corridor Occlusion (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Linked `handle_obstacle_changed` and `step_character_colliders` to query `storage.motion_bvh` directly, enabling in-flight kinetic projectiles to detect newly placed, removed, or character obstacles and shift arrival horizons even after the origin projector has been deconstructed.