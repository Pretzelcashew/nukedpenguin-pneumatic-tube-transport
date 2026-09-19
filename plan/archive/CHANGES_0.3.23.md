### Revision: Prototype Subfolder Modularization and Workspace Hygiene
**Date:** 2026-09-11 18:22 EDT
**Context:** Consolidated machine and proxy prototype definitions out of the root prototype folder into a dedicated entities subfolder to decouple general data specifications from device implementations. Relocated loose documentation out of the runtime script directory and archived obsolete staging files to maintain clean repository hygiene.
**Key Changes:**
1. **Prototype Stage Loader (`data.lua`):** Updated prototype `require` paths to load `pneumatic-diverter`, `pneumatic-pump-proxy`, `pneumatic-capsule-counter`, and `pneumatic-projector` from `prototypes/entities/`.
2. **Device Prototypes (`prototypes/entities/`):** Moved physical machine and proxy prototype definitions (`pneumatic-diverter.lua`, `pneumatic-pump-proxy.lua`, `pneumatic-capsule-counter.lua`, `pneumatic-projector.lua`, and proxy linkage files) from `prototypes/` into `prototypes/entities/`.
3. **Documentation Hygiene (`docs/guides/capsule-definitions-guide.md`):** Moved `scripts_capsules_capsule-definitions-guide.md` out of the runtime script directory `scripts/capsules/` into `docs/guides/`.
4. **Staging Archive (`plan/archive/`):** Relocated historical changelog notes, scratchpad files, and export dumps (`CHANGES_0.3.23.md`, `SCRATCH.md`, and `EXPORT.md`) into `plan/archive/`.


### Revision: Device Scripts Subfolder Modularization and Consumer Import Synchronization
**Date:** 2026-09-11 18:39 EDT
**Context:** Grouped loose device logic, state definitions, renderers, and UI components into dedicated domain subdirectories (diverters, pumps, and projectors) to resolve top-level script directory asymmetry. Synchronized module import paths across the runtime loader, proxy manager, flow engine, and device background scanner to preserve clean dependency resolution.
**Key Changes:**
1. **Flow & Kinetic Simulation (`scripts/flow/flow-engine.lua`):** Updated module require statements for pump, diverter, and projector settings to import from `scripts/pumps/`, `scripts/diverters/`, and `scripts/projectors/`.
2. **Proxy Selection & UI Dispatch (`scripts/proxy-manager.lua`):** Realigned UI controller imports to target `scripts.pumps.pump-gui` and `scripts.diverters.diverter-gui` for proxy interaction handling.
3. **Runtime Entry Loader (`control.lua`):** Updated device module imports to load diverter, pump, and projector settings, GUIs, and world overlay renderers from their respective subfolders.
4. **Active Scanner & Settings Copier (`scripts/active-device-scanner.lua`, `scripts/device-settings-copier.lua`):** Updated all consumer imports for pump, diverter, and projector configuration handlers to reference the modular subdirectories.
5. **Capsule Motion & Projector Ballistics (`scripts/capsules/capsule-runner.lua`):** Updated diverter and projector settings dependencies to point to the new modular locations.
6. **Device Domain Modules (`scripts/diverters/`, `scripts/pumps/`):** Synchronized intra-module requires across `diverter-gui.lua`, `diverter-renderer.lua`, and `pump-gui.lua` to load sibling settings files cleanly.


### Revision: Purge Obsolete Pre-Unified Proxy Linkage Files
**Date:** 2026-09-11 19:03 EDT
**Context:** Purged legacy standalone proxy linkage scripts from prototypes/entities/ that were rendered obsolete by the centralized runtime proxy-manager.lua engine. Verified zero active references across prototype and runtime stages, removing dead code without impacting proxy behavior.
**Key Changes:**
1. **Diverter Proxy Linkage (`prototypes/entities/pneumatic-diverter-proxy-linkage.lua`):** Deleted unreferenced legacy linkage script superseded by unified proxy lifecycle handlers in `proxy-manager.lua`.
2. **Pump Proxy Linkage (`prototypes/entities/pneumatic-pump-proxy-linkage.lua`):** Deleted unreferenced legacy linkage script superseded by unified proxy lifecycle handlers in `proxy-manager.lua`.



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


### Revision: Enable Dynamic Projector Receiver Catchment for Mid-Flight Kinetic Corridors
**Date:** 2026-09-14 12:45 EDT
**Context:** Enabled newly constructed electromagnetic projectors intersecting active in-flight kinetic corridors to dynamically act as valid receivers rather than generic crash obstacles, snapping arrival horizons to perimeter intake sockets and catching payloads safely.
**Key Changes:**
1. **Dynamic Receiver Interception (`scripts/capsules/capsule-ballistics.lua`):** Refined `handle_motion_obstacle_changed` to inspect `entity.name == "pneumatic-projector"`, snapping terminal arrival coordinates directly to the projector's perimeter intake socket (`position - dir * 1.5`) and assigning `bf.hit_receiver_unit = entity.unit_number` for safe dock catchment, while preserving crash explosions and terminal spillage for non-projector structures.
2. **Visual Reticle Dynamic State Sync (`scripts/capsules/capsule-ballistics.lua`):** Synchronized `capsule_renderer.update_arrival_dots` during obstacle evaluation so the scheduled reticle immediately transitions from an orange crash ring to a green receiver ring when intercepted by a newly placed projector.


### Revision: Lock Colinear Receiver Docking and Enable Reverse Vacuum Evacuation
**Date:** 2026-09-14 13:05 EDT
**Context:** Resolved an axis-snapping regression where kinetic beam endpoints, Trajectory BVH leaf segments, and landing reticles dog-legged sideways when contacting 3x3 receiving projectors, and eliminated capsule trapping inside projectors by clearing last port memory and permitting reverse vacuum evacuation.
**Key Changes:**
1. **Invariant Perpendicular Coordinate Snapping (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Locked the perpendicular axis across all receiver docking calculations (`dock_receiver_endpoint`, `step_port`, `init_capsule_beam_flight`, `update_projector_flights`, `handle_motion_obstacle_changed`), ensuring vertical beams strictly preserve `node.pos.x` and horizontal beams strictly preserve `node.pos.y` rather than jumping to the receiver chassis center.
2. **Colinear BVH Remainder & Regrowth Geometry (`scripts/flow/flow-kinetic.lua`):** Aligned terminal remainder segment registration to the true beam vector, eliminating staggered multi-column leaf AABBs, skewed parent bounding boxes, and slanted post-deconstruction beam regrowth.
3. **Reverse Vacuum Evacuation & Siphoning (`scripts/capsules/capsule-ballistics.lua`, `scripts/capsules/capsule-runner.lua`):** Replaced hardcoded `"docked"` returns in `try_projector_launch` with `nil` so pathfinding falls through to candidate hop evaluation when unready to launch, cleared `capsule.last_port_key` upon entering projector docks, and registered capsules in the spatial parked index so reverse negative pressure can siphon them back out into the entry tube.


### Revision: Clear Ballistic Flight Records on Receiver Docking and Normalize Deconstruction Spilling
**Date:** 2026-09-14 14:15 EDT
**Context:** Resolved a severe lag spike and erroneous hypersonic crash explosion occurring when deconstructing an electromagnetic receiving projector holding a captured capsule by clearing ballistic flight state on arrival and permitting standard peaceful cargo spilling.
**Key Changes:**
1. **Receiver Arrival State Clearing (`scripts/capsules/capsule-ballistics.lua`):** Ensured `capsule.beam_flight = nil` is explicitly cleared upon contacting a valid receiver dock in `handle_endpoint_arrival` and `finalize_timed_arrival`, transitioning received capsules cleanly to stationary docked status.
2. **Deconstruction Spill Normalization (`scripts/hubs/hub-spill.lua`):** Refined `handle_entity_destruction` to filter out only active mid-air capsules (`cap.in_timed_flight` or `node.is_beam_node`), allowing docked capsules inside mined projectors to immediately trigger standard peaceful item spilling rather than falling through to dead-node emergency crash damage routines.


### Revision: Purge Kinetic Capsule Spark Particles and Audio Effects
**Date:** 2026-09-14 14:25 EDT
**Context:** Completely eliminated redundant mid-flight spark explosion particles and repetitive wire-connect audio triggers across the ballistics engine, motion runner, and renderer subsystems for clean and silent projectile flight.
**Key Changes:**
1. **Ballistics Audio-Visual Purge (`scripts/capsules/capsule-ballistics.lua`):** Deleted `play_dispatch_effects`, `play_flight_effects`, and `play_catchment_effects` along with all internal `spark-explosion` entity creations and `wire_connect` sound triggers.
2. **Motion Runner Dispatch Cleanups (`scripts/capsules/capsule-runner.lua`):** Stripped dispatch and hop effect invocations during prominent kinetic node and discrete step evaluations.
3. **Viewport Render Particle Removal (`scripts/capsules/capsule-renderer.lua`):** Removed periodic 3-tick `spark-explosion` entity generation blocks from both legacy and sliding-scale per-player render dispatch paths.


### Revision: Generalized Timed Motion Flights and Custom Render Pipeline
**Date:** 2026-09-14 18:15 EDT
**Context:** Decouples kinetic timed flight logic from strictly capsule entities, allowing arbitrary projectiles and entities to utilize timed ballistics, custom arrival callbacks, and viewport rendering.
**Key Changes:**
1. **Flight Record Registry (`scripts/utils/timed-motion.lua`):** Extended `create_record`, `schedule_flight`, and `remove_flight` to persist generic flight records in `storage.timed_flight_records` with support for custom `kind`, `render_spec`, `metadata`, and `on_arrival` callbacks.
2. **Dynamic Arrival Dispatch (`scripts/capsules/capsule-ballistics.lua`):** Introduced `arrival_handlers` and `register_arrival_handler` to route timed arrivals to entity-specific handlers or per-flight callbacks while preserving standard capsule arrival flows.
3. **Generic Flight Visuals (`scripts/capsules/capsule-renderer.lua`):** Added `render_custom_flight_for_player` using leased sprites and primitive circles, and updated `dispatch_player_renders` to interpolate and render non-capsule timed motion flights within viewport bounds.


### Revision: Decouple Generic Timed Ballistics and Free Motion Renderer from Capsule Runner
**Date:** 2026-09-14 21:05 EDT
**Context:** Decoupled the timed ballistic motion engine and viewport renderer from physical capsule containers, allowing electromagnetic projector muzzles to emit generic directional projectiles and register persistent 16-tile BVH corridors without requiring active inventory capsules.
**Key Changes:**
1. **Kinetic Wavefront Suppression & Muzzle Hooks (`scripts/flow/flow-kinetic.lua`):** Introduced the `ENABLE_KINETIC_FLOW_PROPAGATION` top-level boolean to suppress legacy 1-tile/tick kinetic flow dot wavefronts, establishing `on_muzzle_want_emission` and `on_muzzle_stop_emission` hooks that trigger when projectors evaluate positive kinetic emission.
2. **Unified Ballistic Launcher (`scripts/capsules/capsule-ballistics.lua`):** Implemented `capsule_ballistics.launch_timed_flight` to provide a single, reusable entry point for both capsules and generic projectiles, synchronizing flight durations with `trajectory_bvh.TICKS_PER_TILE` and binding acyclically onto `flow_kinetic` at script load time.
3. **Corridor Retention & Pinning (`scripts/utils/timed-motion.lua`):** Updated `remove_flight` to verify if corridor owners are active projectors before pruning BVH segments, ensuring 16-tile spatial corridors remain pinned in the BVH while muzzles are active rather than self-destructing on flight arrival.
4. **Viewport Renderer Decoupling (`scripts/capsules/capsule-renderer.lua`):** Removed `dbg.master` and `dbg.capsules` early-exits from `dispatch_player_renders` so custom ballistics render cleanly in standard Alt-Mode, unified flight lookups across `storage.timed_flights` and `storage.projector_flights`, and extended `render_custom_flight_for_player` to lease composite coral dots and target rings from `render_pool`.
5. **Frame Preparation Lifecycle (`scripts/capsules/capsule-runner.lua`):** Hoisted `prepare_frame`, `step_timed_arrivals`, and `update_timed_capsules` to the very top of `update_capsules` prior to `storage.capsules` emptiness guards, guaranteeing player viewport bounds (`storage.player_viewports`) and ballistic flights tick reliably on worlds with zero physical capsules.


### Revision: Purge Non-Serializable Lua Functions from Persistent Storage
**Date:** 2026-09-14 22:36 EDT
**Context:** Factorio autosaves were failing with an engine-level `on_save()` non-recoverable error caused by Lua function references stored directly in persistent `storage` tables. This session neutralized legacy heap comparator closures and enforced string-only callback identifiers across all timed motion flight records.
**Key Changes:**
1. **Storage Setup Migration (`control.lua`):** Stripped legacy `comparator` functions from active binary heaps (`spoil_heap`, `timed_arrival_heap`, `kinetic_arrival_heap`) and cleared function callbacks from `timed_flight_records` during `setup_storage()`.
2. **Heap Attachment Sanitization (`scripts/utils/binary-heap.lua`):** Added explicit `heap.comparator = nil` inside `binary_heap.attach` to neutralize lingering legacy comparator functions upon deserialization with zero runtime overhead.
3. **Flight Record Hardening (`scripts/utils/timed-motion.lua`):** Enforced string-only typing on `on_arrival` specifications in `timed_motion.create_record`, permanently preventing function closures from entering `storage.timed_flight_records`.
4. **Arrival Dispatch Resolution (`scripts/capsules/capsule-ballistics.lua`):** Updated `handle_timed_arrival` to resolve string `on_arrival` keys through the registered arrival handler table.


### Revision: Decouple Viewport BVH Culling from Coordinate Polling and Bound Hysteresis Margins
**Date:** 2026-09-14 23:44 EDT
**Context:** Periodic flight debug logging was spamming the chat console, and a redundant coordinate bounding check in the render loop was forcing per-tick flight polling while prematurely clipping coarse 16-tile BVH leaves. Additionally, the observer hysteresis shell expanded into a massive 128-tile off-screen void at far zoom levels due to a percentage-based margin multiplier.
**Key Changes:**
1. **Render Loop Hardening & Polling Purge (`scripts/capsules/capsule-renderer.lua`):** Purged 60-tick periodic console debug prints and eliminated redundant per-tick coordinate checks (`is_on_screen`), restoring event-driven coarse-grained leaf culling so projectiles render across the full length of any subscribed 16-tile BVH segment without coordinate polling.
2. **Fixed-Leaf Hysteresis Bounding (`scripts/utils/viewport-bvh.lua`):** Replaced the percentage-based shell multiplier with a fixed 16-tile margin (`SHELL_TILES = 16`), ensuring the hysteresis buffer equals exactly one static BVH leaf in every direction and capping the maximum trailing buffer to 32 tiles at any camera zoom level.
3. **Frustum Calculation & Dynamic Contraction (`scripts/utils/viewport-bvh.lua`):** Removed the 150-tile clamping ceiling and UI scale divisor from screen frustum calculations, replaced static world-space shrunk boxes with a 25% zoom-in contraction trigger (`SHRINK_THRESHOLD = 0.75`), and disabled debug test rendering in production.


### Revision: Multi-Segment Projector Scope Probing & Viewport Static Trail Rendering
**Date:** 2026-09-15 01:01 EDT
**Context:** Replaces recursive 16-tile muzzle probes with a chained multi-segment projector scope flight pipeline that populates corridor trajectories and binds static trail markers and endpoint indicators to viewport BVH leaves during Alt-mode.
**Key Changes:**
1. **Scope Arrival & Segment Chaining (`scripts/capsules/capsule-ballistics.lua`, `scripts/utils/timed-motion.lua`):** Implemented `handle_projector_scope_arrival` to step through successive 16-tile corridor segments until remaining range reaches zero, registering motion leaves and anchoring endpoint data in `storage.projector_scope`.
2. **Kinetic Probe Launch & Lifecycle (`scripts/flow/flow-kinetic.lua`, `scripts/projectors/projector-manager.lua`):** Converted muzzle emission to initiate tracked `projector_scope` flights bound to total emitter reach, with state cleanup on beam cessation and projector deconstruction.
3. **Incremental Dot Trail Rendering (`scripts/capsules/capsule-renderer.lua`):** Added leaf-relative segment matching for scope flights alongside incremental dot trail generation using quality-tiered beam color palettes.
4. **Static Leaf Attachments & Alt-Mode Sync (`scripts/utils/viewport-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Added static render leasing and recycling for persistent beam trails and endpoint reticles in viewport leaves, synchronizing visibility against player Alt-mode toggles.


### Revision: Decoupled Reticle Corridors, Anti-Reticle Temporal Wake Reeling, and Isolated Viewport Indexing
**Date:** 2026-09-15 09:07 EDT
**Context:** Projector beam corridors were previously coupled to physical entity unit numbers, causing key collisions, corrupted orientation math, and an inability to smoothly clean up wake trails upon machine rotation or power loss. This session decoupled reticle BVH ownership from physical projector entities, implemented an invisible anti-reticle arrival pipeline for tandem temporal wake reeling, and hardened viewport visible set namespacing against dot hijacking.
**Key Changes:**
1. **Decoupled Reticle Corridors & Orphaning (`scripts/flow/flow-kinetic.lua`, `scripts/projectors/projector-manager.lua`):** Assigned unique `reticle_id` identifiers to each emitted scope flight and corridor, allowing projectors to orphan active beams on rotation, power loss, or deconstruction and fire new beams immediately without BVH leaf collisions.
2. **Anti-Reticle Flight & Arrival Cleanup (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Scheduled invisible `anti_reticle` flights on the binary arrival heap to time-slice wake cleanup in 16-tile hops behind advancing reticles, unpinning `storage.pinned_corridors` and culling BVH segments upon reaching terminal endpoints.
3. **Tandem Flight & Temporal Wake Reeling (`scripts/capsules/capsule-renderer.lua`, `scripts/capsules/capsule-ballistics.lua`):** Enabled reticles and anti-reticles to advance concurrently in tandem, using closed-form temporal math (`dist_cleared`) to reel in wake dots for observers while suppressing sub-event dot updates when off-screen.
4. **Orthogonal Direction Derivation (`scripts/utils/viewport-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Replaced short-circuiting ternary direction lookups with explicit coordinate delta comparisons against segment `start_pos` and `end_pos`, eliminating 45-degree diagonal slants on cardinal beams.
5. **Viewport Visible Set Namespacing & Double-Free Guard (`scripts/utils/viewport-bvh.lua`, `scripts/utils/render-pool.lua`):** Enforced `owner_id:seg_key` namespacing across `v_set` entries to prevent concurrent beams from hijacking shared render arrays, and added an early-exit visibility guard to `render_pool.recycle` to prevent duplicate free-list insertions.
6. **Obstruction Decoupling (`scripts/flow/flow-kinetic.lua`):** Stubbed out premature obstacle-based reticle orphaning in `flow_kinetic.handle_obstacle_changed` to ensure building adjacent machines does not trigger false anti-reticle retreats.


### Revision: Hardened Tandem Flight Indexing, Wake-Boundary Suppression, and Viewport Lifecycle Pruning
**Date:** 2026-09-15 09:32 EDT
**Context:** Rapid projector rotation and multi-instance firing revealed visual artifacts during tandem flight, including chunked dot respawning, array index hole collisions under Lua's length operator, and orphaned handles lingering in player visible sets. This session stabilized concurrent reticle and anti-reticle flight by enforcing direct slot indexing, gating dot generation behind the trailing wake boundary, isolating endpoint visual handles from numeric step arrays, and connecting segment-level arrival hooks directly to the observer viewport tree.
**Key Changes:**
1. **Direct-Slot Dot Indexing (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Replaced `#item.render_objects + 1` with explicit slot indexing (`item.render_objects[step_i] = dot_obj` and `objects[i] = dot_obj`), permanently eliminating Lua `#` array hole collapse when trailing anti-reticles recycle early slots to `nil`.
2. **Wake-Boundary Dot Suppression (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Gated runtime and static dot spawning behind `min_allowed` (`dist_cleared`), preventing advancing heads and static changed hooks from resurrecting dots behind the retreating wake.
3. **Endpoint Primitive Namespacing (`scripts/utils/viewport-bvh.lua`):** Migrated static endpoint sprites, rings, and circles from numeric indices to dedicated string keys (`"endpoint_ring"`, `"endpoint_circ"`, `"endpoint_sprite"`), shielding endpoint indicators from the numeric dot clearing loop.
4. **Observer Viewport Segment Pruning (`scripts/capsules/capsule-ballistics.lua`):** Connected `viewport_bvh.on_segment_removed` to both intermediate 16-tile hops and terminal arrivals in `handle_anti_reticle_arrival`, immediately pruning dead corridor segments from `storage.player_visible_set`.


### Revision: Deconstruction & Script-Raised Destruction Projector Reticle Orphaning
**Date:** 2026-09-15 09:42 EDT
**Context:** In sandbox and map editor modes, deconstructing or instant-deleting projectors failed to orphan their reticles because `script_raised_destroy` was improperly referenced in `active-device-scanner.lua` and the engine's generic `on_object_destroyed` handler omitted projector destruction notifications. This session corrected the event reference and wired projector destruction hooks across both object destruction and removal pipelines.
**Key Changes:**
1. **Event Reference Correction (`scripts/active-device-scanner.lua`):** Corrected `defines.script_raised_destroy` to `defines.events.script_raised_destroy`, ensuring script, editor, and sandbox deconstruction events register properly.
2. **Object Destruction Lifecycle Hook (`scripts/flow/flow-engine.lua`):** Invoked `flow_kinetic.handle_projector_destroyed(unit_number)` inside `flow_engine.handle_object_destroyed`, guaranteeing instant deconstructions orphan active reticles.
3. **Entity Removal Dispatch (`scripts/flow/flow-engine.lua`):** Added projector destruction notifications inside the `removal_events` handler so robot deconstruction and entity mining reliably trigger reticle wake reeling.


### Revision: Leaf-Scoped Spatial Obstacle Interception and Reticle Corridor Truncation
**Date:** 2026-09-15 16:14 EDT
**Context:** Implemented the foundational spatial collision pipeline for Projector Refactor Task 1, replacing global raycasts with single-pass 16-tile leaf-scoped area queries timed with probe arrivals and enabling logarithmic corridor truncation on entity placement, gate closure, and character movement.
**Key Changes:**
1. **Observer Viewport Attachment (`scripts/flow/flow-kinetic.lua`):** Imported `viewport_bvh` at the top level to resolve nil global runtime exceptions during reticle segment removal and static leaf synchronization.
2. **Leaf-Scoped Spatial Hit Detection (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.scan_leaf_rect` to execute a single spatial query bounded strictly to each 16-tile BVH leaf rectangle during generation, calculating on-axis leading face distances and shielding the emitter chassis from self-collision.
3. **Spatiotemporal Probe Sweep Gating (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Integrated leaf rect obstacle checks into `on_muzzle_want_emission` for segment 1 and `handle_projector_scope_arrival` for segments 2+, clamping forward probe flights to the collision face and suppressing downstream leaf creation.
4. **On-Axis Reticle Corridor Truncation (`scripts/flow/flow-kinetic.lua`):** Created `flow_kinetic.truncate_reticle` to clamp live corridors and decaying wakes squarely at collision faces, updating terminal segment bounds, conditionally attaching obstacle hazard rings on live emitters, and recycling downstream leaf visuals via `viewport_bvh.on_segment_removed`.
5. **Logarithmic Reactive Interception (`scripts/flow/flow-kinetic.lua`):** Wired entity placement, defensive gate transitions, and character steps to query `motion_bvh` in $O(\log N)$ time, reclassified physical characters and vehicles as blocking obstacles in `IGNORABLE_TYPES`, and dispatched instant cardinal truncation.


### Revision: Pass Player Index to Viewport Render Pool Recycling
**Date:** 2026-09-15 16:30 EDT
**Context:** Intra-leaf trail dots and endpoint visual indicators were being orphaned in Factorio's native rendering engine upon corridor truncation because render_pool.recycle was invoked without the required player_index parameter, silently failing to return handles to the player free list.
**Key Changes:**
1. **Trail Dot Recycling Signature (`scripts/utils/viewport-bvh.lua`):** Passed `player_index` into `render_pool.recycle(player_index, objects[i])` during intra-leaf dot pruning, ensuring culled dots beyond the obstacle face properly hide and return to the player render pool.
2. **Endpoint Indicator Recycling Signature (`scripts/utils/viewport-bvh.lua`):** Added `player_index` to all `render_pool.recycle` invocations for `endpoint_sprite`, `endpoint_ring`, and `endpoint_circ`, preventing orphaned endpoint indicators during corridor truncation and position relocation.


### Revision: Dynamic Horizon Rescheduling and Forward Reticle Snap Suppression
**Date:** 2026-09-15 19:10 EDT
**Context:** Placing an entity or moving an obstacle into an advancing projector corridor was previously executing an unconditional `truncate_reticle` pass. While correct for cuts behind or directly at the advancing head, obstacles placed forward along the probe's remaining path caused the visual reticle to instantly teleport forward to the collision face ahead of schedule. This session decoupled forward obstacle detection from backward truncation, preserving backward cutoffs while updating flight records and rescheduling the binary arrival heap for smooth in-flight termination.
**Key Changes:**
1. **Real-Time Head Interpolation (`scripts/flow/flow-kinetic.lua`):** Integrated `timed_motion.get_interpolated_position` into `flow_kinetic.handle_obstacle_changed` to compute the advancing probe head's exact real-time cardinal distance (`cur_head_dist`) from the launch muzzle.
2. **Directional Interception Partitioning (`scripts/flow/flow-kinetic.lua`):** Gated `flow_kinetic.truncate_reticle` strictly to obstacles appearing at or behind the current head (`o_dist <= cur_head_dist + 0.05`), ensuring corridors snap backward immediately on upstream cuts.
3. **Dynamic Flight Horizon Rescheduling (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.update_reticle_horizon` for forward obstacles (`o_dist > cur_head_dist`), clamping `terminal_pos`, resizing active BVH leaf bounds in-place, recalculating arrival ticks at constant velocity, and rebalancing the binary arrival heap without visual pop.
4. **Scope Arrival Total Distance Synchronization (`scripts/capsules/capsule-ballistics.lua`):** Synchronized `reticle.total_dist` to the exact endpoint distance upon terminal arrival in `handle_projector_scope_arrival`.


### Revision: Obstacle Clearance, Canonical Corridor Regrowth, and Viewport Dot Recycling
**Date:** 2026-09-15 20:37 EDT
**Context:** Implemented Projector Refactor Task 3 to wake up truncated reticles upon obstacle removal (mined entities, opened gates, or combat destructions) and resume forward probing to maximum reach without resetting upstream trail dots or producing downstream ghost handles.
**Key Changes:**
1. **$O(1)$ Obstacle Soft-Registration (`scripts/flow/flow-kinetic.lua`, `scripts/flow/flow-engine.lua`):** Added soft-registration tables (`storage.blocked_reticles`, `storage.blocked_reticles_by_reg`, `storage.reticle_blocked_by`) linking blocking entity unit numbers and native `script.register_on_object_destroyed` registration IDs directly to blocked reticles. Removal events and `on_object_destroyed` callbacks wake registered reticles in $O(1)$ time without map-wide scans.
2. **Canonical Segment Boundary Regrowth (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.resume_reticle_probing` to compute distance to the current segment's canonical 16-tile boundary (`(cur_seg_idx * 16) - cur_dist`) and launch forward probe flights from the unblocked collision face, preserving full projector `max_reach` and updating both motion and trajectory BVH trees without coordinate drift.
3. **Independent BVH Recycler Pruning (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` and `update_reticle_horizon` to independently scan and prune downstream segments across both `motion_tree` and `traj_tree`, ensuring culled nodes cleanly return to `bvh.free_nodes` and `/toggle-bvh` debug boxes stay contiguous.
4. **Offset-Aware Flight Dot Progression (`scripts/capsules/capsule-renderer.lua`):** Updated `dispatch_player_renders` to compute in-flight dot progress relative to `flight_start_dist` (`start_offset + math.floor(elapsed_t / tpt)`), ensuring resumed flights starting mid-segment spawn dots immediately from the collision face rather than lagging at segment origin.
5. **Cumulative Leaf Trail Sync (`scripts/capsules/capsule-ballistics.lua`):** Updated `handle_projector_scope_arrival` to compute `leaf.trail_count` cumulatively from canonical segment origins (`total_leaf_dist`), synchronize `reticle.total_dist` across segment chains, and soft-register newly encountered downstream obstacles.
6. **Unconditional Viewport Dot Recycling (`scripts/utils/viewport-bvh.lua`):** Enhanced `attach_static_render` to unconditionally prune and recycle all numeric dot handles $> \text{count}$ back into the player render pool, and updated `on_leaf_static_changed` to broadcast truncation updates across all active subscribers in `storage.player_visible_set`, permanently eliminating lingering ghost dots downstream of obstructions.


### Revision: Projector Scope Stepping and Dynamic Reticle Obstacle Clearance
**Date:** 2026-09-15 21:14 (EDT)
**Context:** Resolves trajectory misalignment and boundary errors during mid-segment projector scope propagation, and ensures growing reticles correctly adjust distances when encountering or clearing obstacles mid-flight.
**Key Changes:**
1. **Scope Step & Trajectory Segmentation (`scripts/capsules/capsule-ballistics.lua`):** Added mid-segment boundary detection to preserve segment indexing and start offsets during sub-segment steps, clamped remaining distance to zero on obstacle impact, and bypassed premature trail finalization on partial chunks.
2. **Dynamic Obstacle Clearance & Reach Checks (`scripts/flow/flow-kinetic.lua`):** Enabled in-flight reticles to dynamically restore remaining flight distance when obstacles clear during growth, and updated obstacle collision scanning to check against full potential reach rather than truncated intermediate distances.


### Revision: Multi-Layer Obstacle Clearance and Reticle Jump Mitigation
**Date:** 2026-09-15 21:35 EDT
**Context:** Clearing a downstream obstacle while an upstream obstacle remained in front of an active projector caused the reticle to wake prematurely, ignore the adjacent blocking structure, and jump through obstacles to maximum reach. This session hardened obstacle registration with single-blocker unregistration, verified active ownership during entity clearance, added on-axis overlap hit detection, and clamped terminal segment bounds upon in-flight collisions.
**Key Changes:**
1. **Single-Owner Obstacle Registration (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.unregister_reticle_obstacle` at the start of `register_reticle_obstacle` to ensure reticles track only the closest active obstacle and purge obsolete downstream waking references in $O(1)$ time.
2. **Obstacle Clearance Ownership Verification (`scripts/flow/flow-kinetic.lua`):** Gated reticle waking in `handle_reticle_obstacle_cleared` behind explicit verification against `storage.reticle_blocked_by[rid]`, permanently preventing deconstructed or mined downstream entities from waking upstream-blocked beams.
3. **On-Axis Overlap Hit Detection (`scripts/flow/flow-kinetic.lua`):** Enhanced `scan_leaf_rect` to detect entities overlapping or touching the probe origin on-axis (`cbb.left_top.x <= start_pos.x + 0.05`), preventing resumed probes from bypassing structures standing directly at `start_pos`.
4. **Scope Arrival Boundary Clamping (`scripts/capsules/capsule-ballistics.lua`):** Recalculated `d_end` immediately upon collision in `handle_projector_scope_arrival`, ensuring trajectory BVH, motion BVH, and reticle total distance clamp accurately to the obstacle face.


### Revision: Dynamic Gate State Sync, Head-Bound Dot Trailing, and Trail Flicker Suppression
**Date:** 2026-09-16 08:32 EDT
**Context:** Projector corridors encountering dynamic obstacles like vanilla gates required decoupled state-transition monitoring to allow beams to grow through opened gates and truncate when gates close shut. Additionally, resumed flights starting mid-segment exhibited visual jumps due to unanchored dot offsets, fallback dot inflation in viewport leaf attachments, and a 1-frame trail flicker caused by full-segment detachment upon clearing static hazard rings. This session integrated an autonomous reticle gate registry, anchored in-flight dots strictly to physical head coordinates, and isolated endpoint indicator recycling from preserved segment trail dots.
**Key Changes:**
1. **Autonomous Reticle Gate Registry (`scripts/flow/flow-kinetic.lua`, `scripts/flow/flow-engine.lua`):** Added `storage.reticle_gates[reticle_id][gate_unit]` to monitor dynamic gate obstacles along active corridors independently of parent projector entities, resuming forward probing on gate open and invoking `truncate_reticle` on gate close.
2. **Physical Head-Bound Dot Progression (`scripts/capsules/capsule-renderer.lua`):** Replaced independent tick-based progress estimation with direct clamping against physical interpolated head coordinates (`math.floor(head_dist - d_start)`), permanently preventing dots from jumping ahead of the advancing reticle.
3. **Canonical Segment Origin Dot Anchoring (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Anchored dot coordinate placement strictly to canonical segment origins (`reticle.start_pos + dir * d_start`), eliminating offset double-addition on mid-segment resumed flights.
4. **Static Trail Fallback Hardening (`scripts/utils/viewport-bvh.lua`):** Gated full-segment dot fallbacks in `attach_static_render` behind explicit `leaf.has_trail == true` checks, preventing active in-flight leaves from prematurely spawning full-length trails.
5. **Selective Endpoint Pruning & Flicker Suppression (`scripts/utils/viewport-bvh.lua`):** Removed full-segment dot detachment when clearing `leaf.static_render_spec`, preserving valid upstream dots across obstacle waking and recycling only endpoint hazard indicators.


### Revision: Discrete Character Tile Evacuation and Downstream Beam Tracking
**Date:** 2026-09-16 08:48 EDT
**Context:** While characters obstructed beams reliably on entry, moving out of the beam or walking downstream failed to notify or clear the truncated reticles because the tile evacuation loop omitted reticle waking hooks. This session wired the reticle obstacle clearance and upstream/downstream adjustment directly into the existing discrete grid-tile evacuation pipeline in `step_character_colliders`.
**Key Changes:**
1. **Discrete Tile Evacuation Hook (`scripts/flow/flow-kinetic.lua`):** Flagged `evacuated_any` during discrete tile departures in `step_character_colliders` to gate reticle evaluation strictly to grid-tile boundary transitions without sub-pixel polling.
2. **On-Axis Directional Motion Resolution (`scripts/flow/flow-kinetic.lua`):** Evaluated character position changes against registered reticles upon tile evacuation: waking and regrowing beams when the player steps off-axis or walks downstream, and immediately applying `truncate_reticle` when the player steps upstream closer to the emitter.
3. **Character Disconnect & Death Lifecycle Clearing (`scripts/flow/flow-kinetic.lua`):** Connected the dead/disconnected character cleanup pass in `step_character_colliders` to `handle_reticle_obstacle_cleared`, ensuring abandoned beams resume forward probing automatically.


### Revision: Mid-Corridor Beam Severing and Autonomous Downstream Wake Reeling
**Date:** 2026-09-16 09:36 EDT
**Context:** Truncating an active or decaying projector corridor previously wiped all downstream segments instantly, causing harsh visual popping and leaving the truncated end feeling abrupt. This session implemented the core corridor severing pipeline for Projector Refactor Task 2, preserving the downstream beam as an autonomous retreating wake that reels away smoothly from the cut point.
**Key Changes:**
1. **Autonomous Downstream Slice Generation (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` to calculate downstream remaining distance (`old_total_dist - obst_dist`) and instantiate a new autonomous reticle ID (`down_id`) carrying over the original trail dots, total distance, and static endpoint indicator.
2. **Pre-Calibrated Wake Reeling (`scripts/flow/flow-kinetic.lua`):** Initialized the downstream slice with `status = "retreating"` and a back-calculated `retreat_tick` matching the obstacle distance, allowing observer viewport culling to hide upstream dots while preserving downstream dots.
3. **Discrete Anti-Reticle Flight Launch (`scripts/flow/flow-kinetic.lua`):** Scheduled an `anti_reticle` flight starting squarely at the collision boundary (`collision_pos`) to hop through downstream 16-tile segments, progressively reeling in dots and recycling BVH leaves upon reaching the old endpoint.
4. **Trailing Wake Boundary Guard (`scripts/flow/flow-kinetic.lua`):** Added `is_behind_wake` filtering to `handle_obstacle_changed`, preventing obstacles built behind an already-retreating wake from triggering redundant or out-of-order truncations.


### Revision: Obstacle Exit-Boundary Scanning and Solid Footprint Wake Suppression
**Date:** 2026-09-16 09:49 EDT
**Context:** When placing long structures (such as elevated rail ramps) or contiguous rows of obstacles across an active beam, the downstream wake previously retained dots rendered directly on top of the solid obstacle footprint, with the anti-reticle awkwardly traversing through the building chassis. This session implemented an obstacle exit-boundary scanner to identify the far collision face, immediately wiping all dots within the physical footprint and launching the retreating anti-reticle cleanly from the open-air exit boundary.
**Key Changes:**
1. **Contiguous Obstacle Exit Scanner (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.find_obstacle_chain_exit` to compute the far exit boundary (`exit_dist`) along the beam axis, iteratively extending through contiguous or overlapping obstacles (supporting single large entities like rail ramps, multi-building blueprints, and defensive walls).
2. **Solid Footprint Wake Suppression (`scripts/flow/flow-kinetic.lua`):** Calibrated the downstream reticle's `retreat_tick` directly to `game.tick - math.floor(exit_dist * tpt)`, preventing trail dots within the solid obstacle body ($d \le \text{exit\_dist}$) from ever spawning into observer viewports.
3. **Eclipsed Segment Culling (`scripts/flow/flow-kinetic.lua`):** Filtered out BVH leaf segments that lie entirely within the obstacle footprint ($s_{\text{end}} \le \text{exit\_dist}$), inserting only surviving open-air segments into `motion_tree` and `traj_tree`.
4. **Exit-Face Anti-Reticle Spawning (`scripts/flow/flow-kinetic.lua`):** Repositioned the downstream `anti_reticle` flight origin directly to the obstacle's exit boundary (`sp + dir * exit_dist`), cleanly reeling in only the surviving open-air wake toward the original terminal endpoint.


### Revision: Severed Reticle Head Preservation, Cadence Sync, and Chain Bounds
**Date:** 2026-09-16 10:19 EDT
**Context:** Placing multi-tile structures across an active beam previously created fragmented slices, stripped the front reticle head leaving headless tails, and caused trail dots to freeze before popping away in one frame due to a time-per-tile constant mismatch during slow-mo testing. This session stabilized the corridor severing pipeline by preserving the reticle head on severed wakes, synchronizing time-to-tile speeds across renderers, and resolving contiguous obstacle chains in a single spatial pass.
**Key Changes:**
1. **Reticle Head & Formed Tail Preservation (`scripts/flow/flow-kinetic.lua`):** Tracked `head_render_spec` across reticle lifecycles and attached the visual head indicator to the downstream slice's terminal leaf, ensuring severed wakes retain their full projectile identity with a visible head and trailing dots.
2. **Slow-Mo Cadence Synchronization (`scripts/flow/flow-kinetic.lua`):** Anchored `tpt` directly to `trajectory_bvh.TICKS_PER_TILE` across wake creation and horizon calculation, eliminating the 10x timing mismatch with `capsule-renderer.lua` and restoring smooth tick-by-tick progressive dot reeling.
3. **Contiguous Obstacle Chain Bounds (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.get_obstacle_chain_bounds` to compute the full entry and exit boundaries (`entry_dist`, `exit_dist`) across adjacent blocking entities, clamping the live beam at the near face while clearing matter footprints in one pass.
4. **Decaying Wake Child & Hazard Suppression (`scripts/flow/flow-kinetic.lua`):** Enforced that decaying wakes clamp at obstacles without active machine hazard rings and never spawn child reticles, preventing visual ring stacking when placing lines of entities.


### Revision: Severed Reticle Flight Path Adoption and Incremental Wake Reeling
**Date:** 2026-09-16 12:14 EDT
**Context:** Severing an active beam mid-corridor previously froze the forward head in mid-air due to premature flight destruction, while trailing wakes popped away in sudden 16-tile chunks because the per-tick dot-clearing loop was only checking item.render_objects instead of static leaf item.objects. This session enabled severed downstream slices to adopt active head flights and restored progressive tick-by-tick dot recycling across all wake types.
**Key Changes:**
1. **Progressive Wake Dot Recycling (`scripts/capsules/capsule-renderer.lua`):** Added `item.objects` fallback to `item.render_objects` in `dispatch_player_renders`, allowing the incremental wake-reeling loop to recycle dots from static BVH leaves tick-by-tick and eliminating 16-tile visual chunk pops.
2. **Concurrent Wake Reeling Gating (`scripts/capsules/capsule-renderer.lua`):** Gated wake dot clearance and suppression behind `reticle.retreat_tick` instead of requiring `status == "retreating"`, enabling tandem wake reeling behind advancing severed heads.
3. **Autonomous Severed Flight Adoption (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` to detect when a severed beam's head is still in flight (`head_was_severed`), re-homing the active `cur_flight` onto the downstream orphan (`down_id`) so the head continues traveling forward to full reach without freezing in mid-air.
4. **Stationary Severed State Retention (`scripts/flow/flow-kinetic.lua`):** Ensured beams that were already stopped at maximum reach or obstacles remain stationary when sliced, preserving static endpoints and launching tail-only anti-reticle reeling.


### Revision: Zero-Tick Obstacle Queuing, Adjacency Bridging, and Universal Reticle Head Retention
**Date:** 2026-09-16 12:42 EDT
**Context:** When placing a contiguous row of obstacles (such as drag-building defensive walls), beams were generating multiple short-lived 1-tile reticle fragments because adjacent Factorio collision boxes have a 0.4-tile gap that failed to merge under the previous 0.05-tile threshold, while an earlier duplicate-blocking guard was preventing downstream orphaned reticle creation once a beam reached maximum reach. Furthermore, previous severing logic was stripping endpoint indicators from retreating wakes under the assumption of "headless" reticles. This session introduced a zero-tick frame-slice obstruction queue, broadened obstacle adjacency merging, guaranteed downstream reticle severance at any range, and enforced that every reticle retains a visible head across its entire lifecycle.
**Key Changes:**
1. **Universal Reticle Head Retention (`scripts/flow/flow-kinetic.lua`):** Permanently purged headless wake concepts across truncation and wake-reeling routines; removed the retreating wake early-return and head-stripping assignments (`leaf.static_pos = nil`, `leaf.static_render_spec = nil`), ensuring both upstream collision faces and downstream severed endpoints retain valid `head_render_spec` structures and visual indicators.
2. **Orphaned Downstream Severing at Max Reach (`scripts/flow/flow-kinetic.lua`):** Removed the `existing_down_id` blocking check in `truncate_reticle`, ensuring obstacles placed across stationary or max-range beams reliably detach the downstream portion into an autonomous orphaned reticle.
3. **Contiguous Grid Adjacency Bridging (`scripts/flow/flow-kinetic.lua`):** Expanded the entity boundary merge tolerance from 0.05 tiles to 0.75 tiles in `get_obstacle_chain_bounds` and `find_obstacle_chain_exit`, allowing adjacent 1x1 structures on the tile grid to bridge physical collision box gaps and fuse into a single contiguous matter footprint.
4. **Zero-Tick Frame-Slice Obstruction Queue (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.queue_reticle_obstacle` and `flow_kinetic.flush_pending_reticle_obstacles` to buffer all obstruction events occurring within the same tick; hooked flush passes into step cycles so multi-entity placements resolve in a single pass with zero tick latency and zero short-lived intermediate slices.
5. **Decoupled Wake-Reeling Visibility Threshold (`scripts/utils/viewport-bvh.lua`):** Gated static trail dot suppression in `attach_static_render` directly behind `reticle.retreat_tick` rather than requiring `status == "retreating"`, allowing severed in-flight heads to render uninhibited while trailing wakes reel in.


### Revision: Deferred Receiver Docking and Impact-Gated Cyan Reticle Head
**Date:** 2026-09-16 14:41 EDT
**Context:** Prospective reticle collision scans were turning advancing probe heads cyan while still in mid-air traveling toward opposing projectors. Parent projectors also required an accurate link to their receiving counterpart without premature association before beam arrival. This session decoupled prospective collision detection from visual reticle state, preserved standard coral head styling throughout transit, and gated cyan head transitions and parent receiver linkage strictly upon physical arrival at the receiver collision face.
**Key Changes:**
1. **Deferred Pending Receiver Tracking (`scripts/flow/flow-kinetic.lua`):** Introduced `pending_receiver` on reticle state across `on_muzzle_want_emission` and `update_reticle_horizon`, capturing prospective opposing projectors without pre-committing `reticle.hit_receiver` or linking receiver units prematurely.
2. **In-Flight Head Styling Preservation (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Enforced `DEFAULT_HEAD_SPEC` (coral) across all active in-flight probe steps, ensuring the flying head never changes color while traversing open air.
3. **Impact-Gated Receiver Docking (`scripts/capsules/capsule-ballistics.lua`):** Updated `handle_projector_scope_arrival` terminal arrival to verify `pending_receiver`, committing `reticle.hit_receiver`, assigning `leaf.static_render_spec = RECEIVER_HEAD_SPEC` (cyan), and storing `receiver_unit` on the parent projector's scope record.
4. **Immediate Truncation Receiver Alignment (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` to immediately commit `RECEIVER_HEAD_SPEC` and link `receiver_unit` when an obstacle placed directly at or behind the head is an active receiver projector.
5. **Obstacle Clearance & Regrowth Reset (`scripts/flow/flow-kinetic.lua`):** Cleared `pending_receiver`, `hit_receiver`, and `storage.projector_scope[proj_unit].receiver_unit` across `resume_reticle_probing` and `handle_reticle_obstacle_cleared`, smoothly restoring default styling when obstructions clear.


### Revision: Multi-Segment Reticle Receiver Docking and Boundary Impact Resolution
**Date:** 2026-09-16 15:02 EDT
**Context:** Projector reticles were failing to turn cyan when impacting another projector across multi-segment corridors (>16 tiles), when regrowing after an intermediate obstacle cleared, or when an opposing projector's collision box landed directly on a 16-tile segment boundary face. This session hardened flight record metadata preservation across chained hops, added receiver detection to corridor regrowth probing, and relaxed boundary face distance thresholds in leaf collision scans.
**Key Changes:**
1. **Chained Flight Metadata Preservation (`scripts/capsules/capsule-ballistics.lua`):** Forwarded `projector_unit`, `reticle_id`, and `q_level` into timed motion flight records in `launch_timed_flight`, added fallback resolution to `reticle.projector_unit` in `handle_projector_scope_arrival`, and preserved ownership metadata across chained hops to prevent multi-segment beams from evaluating `flight.projector_unit ~= nil` as false.
2. **Corridor Regrowth Receiver Docking (`scripts/flow/flow-kinetic.lua`):** Added opposing projector receiver detection and `reticle.pending_receiver` assignment to `resume_reticle_probing` when scanning forward after clearing an obstacle.
3. **Boundary Face Collision Scanning (`scripts/flow/flow-kinetic.lua`):** Initialized `closest_dist = step_dist + 0.05` and updated on-axis distance comparisons to `d <= closest_dist` in `scan_leaf_rect`, ensuring opposing projector collision boxes touching the exact boundary face register without being clipped by strict `<` inequalities.
4. **In-Flight Horizon Metadata Sync (`scripts/flow/flow-kinetic.lua`):** Synchronized `projector_unit` and `reticle_id` directly onto active flight records during `update_reticle_horizon`.
5. **Terminal Arrival Receiver Fallback (`scripts/capsules/capsule-ballistics.lua`):** Updated terminal arrival evaluation in `handle_projector_scope_arrival` to verify both `pending_receiver` and pre-committed `hit_receiver` before finalizing cyan reticle head styling and scope receiver linkage.


### Revision: Narrow-Phase Chassis Bounding-Box Edge Docking and Orphaned Reticle Demotion
**Date:** 2026-09-16 17:08 EDT
**Context:** Beams reaching maximum distance were failing to dock with opposing projectors resting directly on the boundary due to Factorio's 0.30-tile physical collision box inset relative to the tile grid footprint, while broadphase query margins and pneumatic socket offset math introduced artificial spatial distortion. Additionally, orphaned beams and severed downstream wakes could retain or display cyan receiver reticle indicators. This session decoupled kinetic reception from pneumatic socket concepts, replaced broadphase query blankets with a focused 0.5-tile narrow-phase native bounding-box hit test across terminal arrivals and entity placement, and enforced universal coral demotion for orphaned reticles.
**Key Changes:**
1. **Orphaned & Decaying Reticle Color Demotion (`scripts/flow/flow-kinetic.lua`):** Reset `head_render_spec = DEFAULT_HEAD_SPEC` (coral), wiped `hit_receiver` and `pending_receiver`, and updated terminal static leaves in `motion_tree` via `viewport_bvh.on_leaf_static_changed` across `orphan_reticle`, ensuring decaying or retreating wakes never display false cyan receiver styling.
2. **Severed Downstream Reticle Head Sanitization (`scripts/flow/flow-kinetic.lua`):** Initialized severed downstream reticles (`down_id`) and trailing terminal leaves with `DEFAULT_HEAD_SPEC`, preventing wakes severed mid-beam from inheriting receiver head specs from cut points.
3. **Receiver Deconstruction Reference Scrubbing (`scripts/flow/flow-kinetic.lua`):** Extended `flow_kinetic.clear_receiver_references` to iterate over active projector reticles, resetting docked reticles and static terminal leaves back to coral and unlinking `storage.projector_scope` receiver units upon receiver mining or destruction.
4. **Terminal Reach Narrow-Phase Chassis Docking (`scripts/capsules/capsule-ballistics.lua`):** Implemented a native terminal arrival edge check in `handle_projector_scope_arrival` testing physical `cand.bounding_box` within a 0.5-tile narrow-phase tolerance, spanning Factorio's 0.30-tile collision box inset to connect opposing projector chassis faces at maximum reach without pneumatic socket offsets.
5. **Projector Placement In-Place Docking Hook (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.dock_incoming_reticles_at_projector` using a 0.5-tile tolerance around native bounding boxes, querying intersecting motion BVH leaves on placement or rotation to immediately dock stationary beam endpoints as cyan receivers on the exact tick of construction.


### Revision: Parented Reticle Split Candidacy, Tail Jump-Back Suppression, and Autonomous Probing Resumption
**Date:** 2026-09-17 08:21 EDT
**Context:** Orphaned reticles (severed downstream slices or wakes detached from deconstructed/rotated projectors) were previously treated as split candidates during obstacle collision, causing cascading child wakes when placing contiguous structures. Furthermore, obstacles placed along an orphaned beam's tail caused the reticle head to jump backward from its current position to the obstacle face, while stopped orphaned beams were barred from resuming flight upon obstacle clearance due to missing parent projector entities. This session isolated reticle splitting and tail jump-backs strictly to parented beams while restoring autonomous probing resumption for cleared orphaned reticles.
**Key Changes:**
1. **Split Candidacy Guard (`scripts/flow/flow-kinetic.lua`):** Gated downstream wake generation (`downstream_dist > 0.2`) in `flow_kinetic.truncate_reticle` behind `is_split_candidate = (reticle.projector_unit ~= nil)`, permanently preventing orphaned and severed reticles from spawning child slices.
2. **Parented-Only Tail Truncation (`scripts/flow/flow-kinetic.lua`):** Restricted tail-obstruction truncation in `flow_kinetic.flush_pending_reticle_obstacles` strictly to parented reticles (`ret.projector_unit ~= nil`), ensuring orphaned reticle heads never jump backward when obstacles intersect their trailing wake.
3. **Autonomous Probing Resumption (`scripts/flow/flow-kinetic.lua`):** Decoupled `flow_kinetic.resume_reticle_probing` from mandatory parent projector validation via `if proj_unit then`, allowing stationary orphaned reticles stopped by obstacles to resume forward probing to `max_reach` upon obstacle removal.


### Revision: Spatiotemporal Head-Gated Obstacle Collision and Dynamic Horizon Expansion
**Date:** 2026-09-17 08:35 EDT
**Context:** When an obstacle (such as a character) walked away from an advancing projector reticle and then turned back toward it, the character evacuation pipeline erroneously compared the obstacle position against the prospective flight path endpoint (`ret.total_dist`) rather than the real-time spatiotemporal head position. This caused the simulation to misclassify the movement as an upstream cut and trigger `truncate_reticle`, instantly teleporting the reticle head forward to the obstacle's position and cheating time. This session decoupled forward obstacle adjustments from physical head truncations, guarded `truncate_reticle` against forward snaps, and enabled segment-bounded horizon expansion.
**Key Changes:**
1. **Spatiotemporal Head Resolution (`scripts/flow/flow-kinetic.lua`):** Updated `step_character_colliders` to calculate interpolated head distance via `timed_motion.get_interpolated_position`. Obstacles moving closer while remaining in front of the advancing head (`o_dist > cur_head_dist + 0.05`) now route to `update_reticle_horizon` to reschedule flight arrival at constant velocity instead of jumping the reticle head.
2. **Truncation Forward Guard (`scripts/flow/flow-kinetic.lua`):** Added a defensive guard in `truncate_reticle` that automatically delegates to `update_reticle_horizon` if `entry_dist > cur_h_dist + 0.05`, guaranteeing that growing reticles never destroy flights or render static hazard reticles at forward coordinates.
3. **Segment-Bounded Horizon Expansion (`scripts/flow/flow-kinetic.lua`):** Replaced static `flight_end_dist` clamping in `update_reticle_horizon` with canonical segment boundaries (`seg_max_dist = seg_idx * 16`), allowing in-flight targets and arrival timers to expand smoothly when forward obstacles step away within the active segment.
4. **Duplicate Flush Scrubbing (`scripts/flow/flow-kinetic.lua`):** Cleaned up a redundant consecutive call to `flow_kinetic.flush_pending_reticle_obstacles` at the top of `step_character_colliders`.


### Revision: Purge Duplicate Obstacle Queue Functions and Spec Tables
**Date:** 2026-09-17 08:59 EDT
**Context:** Incomplete undo operations from earlier patch sessions had left lingering duplicate blocks inside `flow-kinetic.lua`, causing repeated definitions of head visual specs and a redundant second copy of the frame-slice obstruction queue functions. This caused ambiguous matches during diff application and redundant function execution. This session permanently excised all duplicate definitions from the script.
**Key Changes:**
1. **Duplicate Visual Spec Cleanup (`scripts/flow/flow-kinetic.lua`):** Removed the redundant second assignment block for `DEFAULT_HEAD_SPEC` and `RECEIVER_HEAD_SPEC` at the module header.
2. **Obstacle Queue Deduplication (`scripts/flow/flow-kinetic.lua`):** Deleted the redundant 96-line second definition of `flow_kinetic.queue_reticle_obstacle` and `flow_kinetic.flush_pending_reticle_obstacles` preceding `handle_obstacle_changed_v2`, leaving a single authoritative obstruction queue implementation and eliminating patch collision hazards.


### Revision: Projector Want Emission Cooldown and Rapid Reticle Spam Suppression
**Date:** 2026-09-17 09:38 EDT
**Context:** Rapidly rotating electromagnetic projectors or oscillating circuit/power conditions allowed players to trigger multiple simultaneous kinetic beam emissions, creating overlapping reticle flights and spamming the trajectory BVH. This session established a 1-second (60-tick) post-emission cooldown per projector managed by an indexed binary min-heap, preserving immediate beam emission on initial placement or isolated rotation while deferring rapid follow-up requests until the cooldown elapses.
**Key Changes:**
1. **Cooldown Constant Specification (`scripts/projectors/projector-settings.lua`):** Added `WANT_EMISSION_COOLDOWN_TICKS = 60` defining the 1-second threshold between positive beam emissions.
2. **Binary Heap Storage & Maintenance Lifecycle (`control.lua`):** Initialized `storage.projector_cooldown_heap` as an indexed binary min-heap alongside `storage.projector_cooldown_until` in `setup_storage`, and hooked the heap into `script.on_nth_tick(120)` for amortized buffer decay (`binary_heap.step_decay`).
3. **Emission-Gated Cooldown Activation (`scripts/flow/flow-kinetic.lua`):** Gated `flow_kinetic.on_muzzle_want_emission` behind the active cooldown timestamp (`storage.projector_cooldown_until[owner_id]`). Once a beam successfully emits, the 1-second cooldown begins; any subsequent emission requests arriving within the 1-second window are scheduled onto `storage.projector_cooldown_heap` without duplicate beam creation.
4. **Per-Tick Cooldown Heap Dispatcher (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.step_cooldown_heap` and wired it into the per-tick collider loop (`step_character_colliders`), popping expired timers in $O(1)$ amortized time to launch queued beam flights strictly in the projector's latest orientation.
5. **Lifecycle Teardown & Purge Hook (`scripts/flow/flow-kinetic.lua`, `scripts/projectors/projector-manager.lua`):** Implemented `flow_kinetic.clear_cooldown` to remove pending cooldown entries from both the binary heap and storage when projectors are deconstructed or unregistered.


### Revision: Arrival-Time Receiver Verification, Docking Soft-Registration, and Unconditional Clearance Coral Reset
**Date:** 2026-09-17 10:02 EDT  
**Context:** Projector reticles previously retained cyan receiver styling when target projectors were mined at maximum reach or when machines were unpowered, and prospective collisions could turn cyan upon arrival even if the target was deconstructed while the probe was in flight. Furthermore, in-place docking on entity placement omitted obstacle soft-registration, preventing mined receivers from waking beams. This session gated cyan head styling behind active entity validation at physical arrival, soft-registered docked projectors, and guaranteed that reticle heads unconditionally revert to coral upon obstacle clearance.  
**Key Changes:**
1. **Arrival-Time Obstacle Validation (`scripts/capsules/capsule-ballistics.lua`):** Verified `storage.active_projectors[hit_receiver_unit].valid` at the exact arrival tick in `handle_projector_scope_arrival` before applying `RECEIVER_HEAD_SPEC`, cleanly falling back to coral `DEFAULT_HEAD_SPEC` if the opposing projector cleared while the probe was in transit.
2. **Terminal Impact Soft-Registration (`scripts/capsules/capsule-ballistics.lua`):** Soft-registered confirmed receiver entities into `storage.blocked_reticles` via `flow_kinetic.register_reticle_obstacle` upon physical arrival so removal events reliably alert and wake docked reticles.
3. **Unconditional Clearance Demotion (`scripts/flow/flow-kinetic.lua`):** Positioned visual head demotion at the top of `flow_kinetic.resume_reticle_probing` to reset `reticle.head_render_spec`, clear scope receiver linkages, and broadcast coral `DEFAULT_HEAD_SPEC` on active motion BVH leaves even when range limits (`cur_dist >= max_reach`) or unpowered states halt forward probing.
4. **In-Place Placement Soft-Registration (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.register_reticle_obstacle` inside `flow_kinetic.dock_incoming_reticles_at_projector` so machines built directly onto stationary endpoints wake reticles when deconstructed.
5. **Universal Static Specification Scrubbing (`scripts/flow/flow-kinetic.lua`):** Broadened leaf static render updates in `flow_kinetic.clear_receiver_references` to reset any active static head specification back to coral and notify viewport subscribers.


### Revision: Decouple Ballistic Flight Mechanics from Reticle Invariants and Restore Evacuation Clearing
**Date:** 2026-09-17 11:35 EDT  
**Context:** The introduction of the projector reticle system severely compromised the existing, hard-won ballistic capsule flight mechanics because the reticle's ephemeral sighting probe was destructively cross-wired into the foundational ballistics engine instead of being architected as an independent, decoupled sensory layer from the beginning. By forcing physical cargo containers to share corridor dismantling, horizon truncation, and collision events with a prospective laser line, in-flight capsules suffered instant time-travel explosions upon obstacle entry and dropped rendering BVH leaves mid-transit. This session enforces the strict architectural separation that should have existed from day one: the reticle operates purely as an independent targeting probe communicating solely via target-lock notifications, while physical capsule ballistics retains its continuous flight model, forward-looking arrival math, and persistent corridor viewports.
**Key Changes:**
1. **Forward-Looking Arrival Rescheduling (`scripts/utils/timed-motion.lua`):** Corrected `timed_motion.shift_horizon` to calculate remaining arrival time forward from `current_tick` based on real-time elapsed distance (`current_tick + rem_ticks`) rather than back-calculating from `record.start_tick` in the past, completely eliminating instantaneous time-travel explosions and spurious ground spillage when obstacles appear ahead of flying capsules.
2. **Corridor Leaf Preservation & Zero Geometry Churn (`scripts/utils/timed-motion.lua`):** Excised destructive `remove_corridor` and `ensure_corridor` calls from `shift_horizon`, ensuring communal capsule corridor segments remain pinned in `storage.motion_bvh` and active player viewports so traveling payloads never lose their render handles mid-air.
3. **Discrete Grid-Tile Evacuation Bounding Box (`scripts/flow/flow-kinetic.lua`):** Corrected `step_character_colliders` to pass the spatial bounding box of the evacuated beam tile (`evac_bb`) rather than the character's updated off-axis body position, allowing `handle_motion_obstacle_changed` to recognize that the beam was cleared, restore `bf.terminal_pos` to the receiver dock, revert the arrival reticle to green, and let the capsule fly through without ghost crashes.
4. **Architectural Boundary Enforcement (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Confined transient laser probe steps, wake reeling, and visual head specs strictly to reticle domain ownership, establishing a single-point target lock hook (`notify_projector_receiver_docked`) that allows projectors to fire physical ballistic capsules down communal flight corridors without cross-subsystem interference.


### Revision: Event-Driven Decaying Flight Corridors on Reticle Orphaning and Receiver Unlinking
**Date:** 2026-09-17 12:05 EDT  
**Context:** When a projector's reticle was orphaned or unlinked from a receiver (due to rotation, machine deconstruction, power loss, obstacle truncation, or probing regrowth), paired ballistic capsule flight corridors either lingered indefinitely or risked premature deletion while payloads were still in transit. This session implemented an event-driven lifecycle that immediately tears down unoccupied flight corridors upon disconnection while preserving occupied corridors in a decaying state until the last in-transit capsule arrives or crashes, with zero periodic tick scanning.
**Key Changes:**
1. **Decoupled Receiver Unlinking & Capsule Count Queries (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.count_in_flight_capsules` for $O(1)$ in-transit payload checks and `flow_kinetic.unlink_projector_receiver` to coordinate corridor teardown upon receiver loss across `resume_reticle_probing`, `truncate_reticle`, `update_reticle_horizon`, `handle_reticle_obstacle_cleared`, and `clear_receiver_references`.
2. **Orphaned Corridor Decoupling & Decaying Tagging (`scripts/flow/flow-kinetic.lua`):** Updated `flow_kinetic.orphan_reticle` and `unlink_projector_receiver` to destroy paired corridors immediately when empty, or register active corridors into `storage.decaying_corridors` when capsules remain in flight.
3. **Arrival-Bundled Decaying Corridor Teardown (`scripts/capsules/capsule-ballistics.lua`, `scripts/utils/timed-motion.lua`):** Bundled decaying corridor cleanup directly into `remove_flight` across terminal heap arrivals and obstacle impact spills, unpinning active machine guards and removing decaying corridors from motion and trajectory BVH trees the exact tick the capsule count reaches zero without background tick polling.
4. **Docking Geometry Rebuild Clearance (`scripts/capsules/capsule-ballistics.lua`, `scripts/utils/timed-motion.lua`):** Enhanced `ensure_capsule_corridor` and `timed_motion.ensure_corridor` to purge stale decaying corridors before inserting fresh corridor segments when newly docked receivers connect at different distances.



### Revision: Grid-Aligned 1x1 Tile Character Colliders and Boundary Escape Gating
**Date:** 2026-09-17 13:35 EDT  
**Context:** Continuous sub-pixel coordinate polling previously caused redundant collider churn and micro-recalculations for reticles and ballistic flight corridors whenever a character moved slightly or rotated within a single tile. This session established a grid-aligned 1x1 tile bounding box for characters, gating reticle adjustments and motion BVH collider updates strictly to moments when the player escapes their current tile square.  
**Key Changes:**
1. **Grid-Aligned Bounding Box Resolution (`scripts/flow/flow-kinetic.lua`):** Implemented `get_entity_bounding_box` to resolve character bounding boxes to integer-aligned 1x1 tile squares (`[tx, tx + 1] x [ty, ty + 1]`) across leaf collision scans, obstacle chain calculations, pending reticle queues, and motion BVH queries.
2. **Discrete Boundary Escape Gating (`scripts/flow/flow-kinetic.lua`):** Stored active coordinates in `storage.character_tiles` within `step_character_colliders`, bypassing all simulation steps when a player remains inside their current tile box to eliminate intra-tile collider jitter.
3. **Tile-Aligned Evacuation & Entry Dispatch (`scripts/flow/flow-kinetic.lua`):** Gated motion BVH corridor clearance, legacy beam wakeups, and reticle horizon updates strictly to tile boundary transitions, passing explicit 1x1 tile bounding boxes for both evacuated and newly occupied positions.
4. **Character Lifecycle & Disconnect Teardown (`scripts/flow/flow-kinetic.lua`):** Extended disconnect and character death cleanup to iterate over `storage.character_tiles`, unregistering evacuated tile colliders from motion BVH trees and waking blocked reticles.


### Revision: Projector Muzzle Aperture Overlap and Reticle Collision Alignment
**Date:** 2026-09-17 14:01 EDT  
**Context:** Because the projector's launch muzzle sits at the perimeter boundary (`±1.5`) while its physical collision box is inset to `±1.2`, characters standing against the machine's front lip had their collision boxes touch or slightly overlap the launch origin. Distance calculations evaluated this gap as zero or negative, causing reticle sweeps and reactive obstacle queues to discard the player as behind the emitter. This created a deceptive visual path where reticles shot through players who were subsequently impacted by launching capsules. This session extended the aperture scan area backward and clamped muzzle-overlap contacts to distance 0.1 across all reticle and ballistics checks.  
**Key Changes:**
1. **Pre-Launch Clearance Centering (`scripts/capsules/capsule-ballistics.lua`):** Shifted pre-launch player collision probing from 1.0 tile downstream to half a tile forward (`muzzle_node.pos + dir * 0.5`), directly inspecting the clearance tile touching the projector face.
2. **Aperture Reverse Sweep (`scripts/flow/flow-kinetic.lua`):** Expanded the spatial query rectangle in `scan_leaf_rect` by 0.5 tiles backward along the launch vector, ensuring entities standing within the chassis inset are captured by `find_entities_filtered` while preserving emitter self-collision shielding.
3. **Muzzle Overlap Collision Clamping (`scripts/flow/flow-kinetic.lua`):** Updated cardinal distance calculations across `scan_leaf_rect`, `handle_obstacle_changed_v2`, `_legacy_handle_obstacle_changed`, `flush_pending_reticle_obstacles`, and `step_grid_character_colliders` to classify any obstacle touching or overlapping the muzzle face (within 0.5 tiles) as an immediate collision at distance `0.1`.
4. **Visual & Ballistic Trajectory Parity (`scripts/flow/flow-kinetic.lua`):** Aligned reticle truncation squarely with physical capsule ballistics, guaranteeing that stepping into the chassis lip immediately collapses the reticle to a 0.1-distance coral hazard ring at the muzzle.


### Revision: Restore Projector Ballistic Velocity to Production Baseline
**Date:** 2026-09-17 14:15 EDT  
**Context:** Projector ballistic transit and reticle propagation had been dialed down to a 10× slow-mo cadence (`TICKS_PER_HOP = 60`) for visual validation of wake severing, multi-segment boundary handoffs, and aperture collision checks. With spatial boundary conditions and 1×1 tile colliders hardened, this session restores the hop interval to its baseline production velocity.  
**Key Changes:**
1. **Velocity Constant Restoration (`scripts/capsules/capsule-ballistics.lua`):** Restored `TICKS_PER_HOP` from `60` to `6`, returning projectile transit speed to 50 tiles per second (1.2 ticks per tile).
2. **Unified System Acceleration (`scripts/capsules/capsule-ballistics.lua`):** Propagated the 1.2 ticks/tile cadence across `trajectory_bvh.TICKS_PER_TILE`, automatically scaling timed arrival scheduling, in-flight dot progression, and anti-reticle wake reeling to full operational speed.


### Revision: O(1) Table-Driven Obstacle Destruction and BVH Query Elimination
**Date:** 2026-09-17 14:52 EDT  
**Context:** When entities were mined or destroyed (e.g., grenading 25 trees), the removal handler was executing redundant spatial AABB box queries against multiple BVH trees to ask if the dying entity touched any corridors, followed by an obsolete 50-tile flow node waking loop. Because reticles already index their active blocking entities in `storage.blocked_reticles`, querying spatial trees on destruction was completely backwards and caused severe frame cycle spikes. This session routed entity removal directly to $O(1)$ table lookups, bypassed spatial trees entirely on death, and excised the legacy fallback loop.  
**Key Changes:**
1. **Zero-BVH Entity Removal Fast-Path (`scripts/flow/flow-kinetic.lua`):** Short-circuited `flow_kinetic.handle_obstacle_changed` on `is_removal == true` to directly dispatch `handle_reticle_obstacle_cleared(entity)` and return immediately, completely bypassing spatial AABB tree queries on entity death or mining.
2. **O(1) Blocker Wakeup Resolution (`scripts/flow/flow-kinetic.lua`):** Bound destruction notifications strictly to direct hash lookups in `storage.blocked_reticles[unit_number]`, allowing non-blocking entities (trees, rocks, biters) to early-exit in sub-microsecond time with zero spatial math.
3. **Legacy Duplicate Obstacle Loop Severed (`scripts/flow/flow-kinetic.lua`):** Excised `_legacy_handle_obstacle_changed` from the tail of `handle_obstacle_changed_v2`, permanently eliminating redundant `motion_bvh` and `surface_bvh` queries along with obsolete 50-tile iterative port waking passes.
4. **Destruction Frame Spike Elimination (`scripts/flow/flow-kinetic.lua`):** Eliminated the multi-millisecond frame cycle spikes associated with mass entity clearing (grenades, artillery strikes, cliff explosives).


### Revision: Full-Spectrum Event Profiling and Dedicated BVH Spatial Diagnostics
**Date:** 2026-09-17 15:26 EDT  
**Context:** Lag spikes during character movement and mass entity destruction (e.g. tree clearing) were previously unmeasurable because the profiler only sampled `on_tick` and lacked event-specific call counters, causing non-tick handlers to be omitted and dividing discrete event spikes across the 60-tick window. This session instrumented all mod-registered game events with per-call execution timers, call frequency counters, and live real-time console alerts, while adding dedicated instrumentation across the Trajectory BVH and Player Viewport spatial subsystems.  
**Key Changes:**
1. **Universal Event Dispatch Profiling (`scripts/events.lua`, `scripts/utils/profiler.lua`):** Expanded `events.on_event` to time all registered Factorio game events whenever profiling is active, recording discrete call counts, total execution time, and per-call duration averages for each subsystem listener.
2. **Real-Time Event & Shell Breach Console Logging (`scripts/events.lua`, `scripts/utils/profiler.lua`, `scripts/utils/viewport-bvh.lua`):** Added `profiler.is_event_log_active()` to stream immediate chat timestamps with execution durations whenever non-tick events or 16-tile viewport hysteresis shell breaches occur.
3. **Dedicated BVH Subsystem Instrumentation (`scripts/utils/profiler.lua`, `scripts/utils/viewport-bvh.lua`, `scripts/utils/trajectory-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Instrumented `update_all_players` ("Viewport"), `sync_player_visibility` ("Visibility Sync"), `query_box` ("Query Box"), `insert`/`remove`/`update` ("Tree Mutate"), and `dispatch_player_renders` ("Render Dispatch").
4. **Interactive Diagnostics & Control Panel GUI Integration (`scripts/debug-manager.lua`):** Added `/profile-bvh`, `/profile-events`, and `/toggle-event-log` console commands alongside dedicated "BVH Report" buttons, live event logging toggles, and dedicated BVH performance rows in the Pneumatic Control Panel table.


### Revision: Quiescent Render Dispatch Dormancy, Stationary Viewport Fast-Path, and Profiler Average Alignment
**Date:** 2026-09-17 16:30 EDT  
**Context:** The diagnostic panel showed continuous execution time for render dispatch, arrival stepping, and viewport BVH even when standing far from tube infrastructure or looking at static, unoccupied corridors. Furthermore, BVH spatial diagnostics displayed an alarming 1.63 ms duration beside a 0.12 ms total mod script time due to an aggregation mismatch in the debug UI. This session established true dormancy for render dispatch and arrival stepping during idle conditions, cached player viewport state for stationary cameras, enforced viewport frustum culling on arrival dots, preserved instantaneous Alt-mode toggling, and corrected debug panel metrics to display consistent per-tick averages.  
**Key Changes:**
1. **Quiescent Render Dispatch Dormancy (`scripts/capsules/capsule-renderer.lua`):** Evaluated visible corridors in `dispatch_player_renders` to detect when zero active flights or wake retreats exist on-screen. When all visible segments are static or `v_set` is empty, the dispatcher early-exits before starting native `LuaProfiler` timers, eliminating background profiler noise.
2. **Instant Alt-Mode Toggle Preservation (`scripts/capsules/capsule-renderer.lua`):** Retained connected-player evaluation in `update_timed_capsules` to ensure `alt_mode ~= prev_alt` transitions execute on the exact frame of the keystroke while standing stationary, attaching or detaching static primitives without requiring camera motion.
3. **Stationary Viewport Fast-Path (`scripts/utils/viewport-bvh.lua`):** Cached `last_player_x`, `last_player_y`, and `last_zoom` directly on player viewport entries in `update_player`. When a player is stationary and camera zoom is unchanged, all frustum half-dimension, display scale, and padding calculations are bypassed in sub-microsecond time.
4. **Timed Arrival Heap Dormancy (`scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-ballistics.lua`, `scripts/utils/timed-motion.lua`):** Guarded `step_timed_arrivals` behind `heap and heap.size > 0` in the runner loop and ballistics engine, preventing per-tick callback closure allocations and moving zero-size checks ahead of `binary_heap.attach` in `timed_motion.step_arrivals`.
5. **Frustum-Culled Arrival Reticles (`scripts/capsules/capsule-renderer.lua`):** Added surface and screen bounding-box tests to `render_arrival_dot_for_player`, destroying handles and skipping `render_pool` leasing when arrival endpoints lie off-screen or on other planetary surfaces.
6. **Diagnostic Table Metric Alignment (`scripts/debug-manager.lua`):** Replaced `.total` with `.avg` across all BVH rows (`lbl_time_bvh_vp`, `lbl_time_bvh_q`, `lbl_time_bvh_rd`) in the Pneumatic Control Panel, aligning spatial subsystem metrics with the 60-tick average displayed across all other rows and eliminating the 60-frame cumulative sum inflation.
7. **Module Scope Upvalue Hoisting (`scripts/capsules/capsule-renderer.lua`):** Hoisted `previous_arrival_capsules` declaration to the top-level module scratch block, resolving a runtime `nil` upvalue exception in `update_timed_capsules`.


### Revision: Collective Observation Governor, Amortized Pre-Calculation Buffer, and Lockstep Ballistics Rendering
**Date:** 2026-09-17 19:50 EDT  
**Context:** Visual updates for in-flight capsules and projector targeting reticles previously calculated interpolation on the render frame with per-player staggered modulo cadences. In multiplayer, this caused sawtooth CPU spikes when multiple players observed large volumes of capsules and produced visual accordion stretching where capsules in a line appeared to take turns moving. This session implemented a communal observation governor, pre-calculated coordinate buffering with amortized maintenance decay, quiet-tick math slicing, lockstep render flushing, and event-driven cache invalidation.  
**Key Changes:**
1. **Collective Observation Governor (`scripts/capsules/capsule-renderer.lua`):** Implemented `update_governor` in `prepare_frame()` to aggregate unique observed in-flight capsules across all connected players with Alt-Mode active in non-chart viewports, sleeping with 0.00 ms CPU time when idle.
2. **Schmitt-Trigger Hysteresis & Emergency Override (`scripts/capsules/capsule-renderer.lua`):** Governed visual refresh rate with smoothed hysteresis thresholds (60 FPS $\rightarrow$ 30 FPS at 30 capsules, 30 FPS $\rightarrow$ 60 FPS at 18; 30 FPS $\rightarrow$ 20 FPS at 75, 20 FPS $\rightarrow$ 30 FPS at 50) and an emergency fast-drop trigger on sudden queue surges ($\ge 120$ count or $\Delta \ge 40$).
3. **Pre-Allocated High-Water Coordinate Buffer (`control.lua`, `scripts/capsules/capsule-renderer.lua`):** Initialized `storage.render_precalc_buffer` with in-place vector mutation (`x, y`), high-water watermark tracking, and an amortized tail-pruning decay routine (`step_buffer_decay`) hooked into `script.on_nth_tick(120)`.
4. **Time-Sliced Quiet-Tick Math Amortization (`scripts/capsules/capsule-renderer.lua`):** Implemented `step_precalculations` to compute closed-form forward coordinates during quiet ticks (100% on tick - 1 for 30 FPS; sliced 50/50 across tick - 2 and tick - 1 for 20 FPS), flattening frame-time spikes before render ticks arrive.
5. **Lockstep Render Flushing (`scripts/capsules/capsule-renderer.lua`):** Replaced per-player staggered modulo with global lockstep render gating (`current_tick % cadence == 0`) and direct coordinate piping (`get_flight_position`), ensuring all capsules advance in unison with rigid relative spacing.
6. **Event-Driven & Auto-Invalidation Pipeline (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-renderer.lua`):** Wired reactive cache dirtying on projectile collisions, horizon shifts, and reticle deconstruction, paired with zero-allocation discrepancy detection in `get_flight_position` and localized acyclic helpers in `flow-kinetic.lua`.
7. **Automated Verification Suite (`scripts/capsules/capsule-renderer.lua`):** Added Test 6 and Test 7 to `/test-render-dispatcher`, validating governor idle state, isolated buffer decay, and obstacle truncation invalidation.


### Revision: Capsule Motion Sub-Profiler Breakdown, Static Corridor Early-Skip, and Test Fixture Isolation
**Date:** 2026-09-17 20:25 EDT  
**Context:** Following the collective governor and pre-calculation buffer overhaul, `Capsule Motion` remained a monolithic profiler block that masked the distribution between internal tube hops and ballistic flights. Additionally, viewports with hundreds of static finished beam segments were causing unnecessary table iterations every frame, and a circular require loop was identified between kinetic and debug modules on script reload. This session broke down the motion profiler into dedicated sub-systems, added active-owner static corridor filtering to cut render dispatch time by ~40%, decoupled kinetic invalidation helpers, and isolated the automated test fixtures.  
**Key Changes:**
1. **Capsule Motion Profiler Breakdown (`scripts/utils/profiler.lua`, `scripts/debug-manager.lua`, `scripts/capsules/capsule-runner.lua`):** Sub-divided `Capsule Motion` into three discrete profiler timers: `Tube Traversal` (6t discrete hops), `Ballistics & Heap` (arrival heap popping and projectile simulation), and `Frame Sync` (governor aggregation and viewport sets), exposing live counts for tube capsules, in-flight projectiles, heap entries, and active FPS cadence.
2. **Static Corridor Early-Skip Filtering (`scripts/capsules/capsule-renderer.lua`):** Implemented a zero-allocation `scratch_active_owners` filter in `update_governor` and `dispatch_player_renders`, allowing hundreds of static finished beam segments to bypass inner simulation checks on line 1 and reducing `Render Dispatch` time from 0.295 ms to 0.179 ms across 272 visible corridors.
3. **Acyclic Invalidation Helpers (`scripts/flow/flow-kinetic.lua`):** Stripped `require("scripts.capsules.capsule-renderer")` from `flow-kinetic.lua` to break an indirect circular dependency chain (`capsule-renderer -> debug-manager -> flow-engine -> flow-kinetic`), replacing external calls with localized, zero-allocation storage buffer dirtying helpers.
4. **Test Fixture Isolation & Assertion Parity (`scripts/capsules/capsule-renderer.lua`):** Updated `step_buffer_decay` to accept an optional test buffer fixture to prevent Test 6 from colliding with live factory entries, and adjusted Test 7 to assert against physical obstacle horizon truncation rather than constant-velocity intermediate positions.

### Revision: Clean Prepare Frame & Active Debug Player Caching
**Date:** 2026-09-17 21:23 EDT
**Context:** Refactors the per-tick frame preparation routine in the capsule renderer to streamline player viewport evaluation and active debug state collection.
**Key Changes:**
1. **Frame Preparation (`scripts/capsules/capsule-renderer.lua`):** Implemented `clean_prepare_frame` to evaluate Alt Mode eligibility, resolve hover peek unit numbers, and manage pooled `active_debug_players` allocations.
2. **Legacy Transition (`scripts/capsules/capsule-renderer.lua`):** Routed `capsule_renderer.prepare_frame` directly to `clean_prepare_frame` while retaining the previous implementation as `_legacy_prepare_frame`.


### Revision: Reticle Wake Peeling Governor Dormancy Fix
**Date:** 2026-09-18 14:36 EDT
**Context:** When projector reticles were decaying or retreating, the observation governor was incorrectly classifying the simulation as completely idle because anti-reticle flights were filtered out of visual observation counts. This caused `update_timed_capsules` to early-exit, entirely skipping the per-tick dot-clearing loop in `dispatch_player_renders` until the 16-tile segment arrival popped the entire BVH leaf at once. This session registered visible wake retreats as active work in the governor, locked the cadence to 60 FPS during retreats, and restored smooth tick-by-tick dot peeling.
**Key Changes:**
1. **Governor Dormancy Awakening (`scripts/capsules/capsule-renderer.lua`):** Evaluated active `retreat_tick` entries in `update_governor` alongside active flights, ensuring visible retreating corridors prevent the governor from entering an idle sleep state.
2. **60 FPS Cadence Lock for Wake Peeling (`scripts/capsules/capsule-renderer.lua`):** Bypassed cadence throttling in `dispatch_player_renders` whenever a visible reticle is actively retreating, ensuring dot clearance executes on every single tick.
3. **Decoupled Render Pass Evaluation (`scripts/capsules/capsule-renderer.lua`):** Removed the outer `has_flights` guard from the `needs_render_pass` check, allowing visible retreating reticles to trigger render dispatch independently of active projectile flights.


### Revision: Modular Subprotocol Architecture and Render Substrate Decoupling
**Date:** 2026-09-18 21:51 EDT
**Context:** Flight and motion mechanics were previously coupled across five monolithic files, hardcoding open-air optical reticles and exploding cargo projectiles directly into the rendering, culling, and ballistics engines. This session established a composable subprotocol architecture separating flight mechanics into independent facets (heads, trails, disruptions, arrivals, and static overlays), resolved a signature argument mismatch causing a LuaPlayer userdata crash during wake peeling, and validated the substrate with an automated verification suite while preserving 100% runtime simulation and rendering performance. Path clearance and corridor topology remain targeted for subsequent separation.
**Key Changes:**
1. **Modular Subprotocol Registry (`scripts/utils/motion-protocols.lua`):** Created the central facet registry supporting modular heads (`capsule_head`, `hazard_reticle`, `custom_flight`, `none`), trails (`reticle_dots`, `wake_peeling`, `none`), disruptions (`ballistic_crash`, `reticle_slice`, `peaceful_spill`, `silent_halt`, `none`), arrivals (`capsule_terminal`, `scope_step`, `anti_reticle_step`), and static Alt-mode renders (`reticle_static`). Pre-configured templates for `tube_wave` and `tube_transit`.
2. **Renderer Loop Decoupling (`scripts/capsules/capsule-renderer.lua`):** Extracted inline beam dot leasing and wake dot peeling into reusable subprotocol delegates, replaced hardcoded `is_scope`/`is_anti` timing branches with `motion_protocols.get_progression_window`, and dispatched in-flight visuals via protocol delegates.
3. **Observer Static Presentation Decoupling (`scripts/utils/viewport-bvh.lua`):** Extracted 115 lines of reticle beam and endpoint drawing logic from `attach_static_render` into the `"reticle_static"` subprotocol delegate, keeping the spatial observer tree engine agnostic of visual archetypes.
4. **Arrival & Disruption Subprotocol Routing (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Routed terminal arrival handling through `motion_protocols.get_subprotocol(..., "arrival")` and obstacle disruption through `motion_protocols.get_subprotocol(..., "disruption")`. Added support for peaceful ground spillage and silent propagation halts during obstacle cuts, while registering `"reticle_slice"` from kinetic flow.
5. **Argument Position Bugfix (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/motion-protocols.lua`):** Reclassified `anti_reticle` flights to `trail = "none"` to prevent segment-stepping timer flights from triggering in-flight dot loops, and wrapped `"wake_peeling"` with an adapter mapping the 9-argument trail call to eliminate an argument shift that passed `LuaPlayer` userdata into tick arithmetic.
6. **Automated Subprotocol Verification Suite (`scripts/utils/motion-protocols.lua`):** Added `/test-motion-protocols` validating base registry fallbacks, overlapping mixin composition, progression window math, alternative disruption flags, and facet independence.


### Revision: Flight Clearance Protocolization and Directional Disruption Bifurcation
**Date:** 2026-09-18 22:15 EDT
**Context:** Path clearance and obstacle interception were previously hardcoded in separate 60-line cardinal projection loops inside flow-kinetic.lua and capsule-ballistics.lua, coupling spatial detection to specific entity types and preventing reuse across different motion mediums. This session decoupled clearance into two orthogonal subprotocols—disruption detection (what is an obstacle) and clearance policies (how forward vs. backward disruptions are handled)—while restoring reticle tail-severing mechanics and eliminating runtime require() violations.
**Key Changes:**
1. **Detector & Clearance Policy Subprotocols (`scripts/utils/motion-protocols.lua`):** Added `detectors` (`open_air_solids`, `tube_connectivity`) and `clearance_policies` (`optical_ray`, `discrete_projectile`, `peaceful_transit`, `silent_wave`). Implemented `motion_protocols.calculate_axis_distance` to eliminate redundant cardinal bounding box projection boilerplate across the codebase.
2. **Directional Clearance Dispatching (`scripts/utils/motion-protocols.lua`):** Implemented `dispatch_clearance_policy` to calculate relative spatial displacement ($\Delta d = d_{\text{obst}} - d_{\text{current}}$), cleanly routing forward obstacles ($d_{\text{obst}} > d_{\text{current}}$) to horizon clamping and backward obstacles ($d_{\text{obst}} \le d_{\text{current}}$) to tail severing or projectile pass-through.
3. **Kinetic Obstacle Interception Decoupling (`scripts/flow/flow-kinetic.lua`):** Refactored `flush_pending_reticle_obstacles` and `handle_obstacle_changed_v2` to delegate through `dispatch_clearance_policy` and `calculate_axis_distance`. Replaced `scan_leaf_rect` with a facade delegation to `motion_protocols.scan_open_air_leaf`.
4. **Reticle Identity Tagging & Structural Inference (`scripts/flow/flow-kinetic.lua`, `scripts/utils/motion-protocols.lua`):** Explicitly tagged `protocol = "projector_scope"` and `clearance_policy = "optical_ray"` on reticle records in `on_muzzle_want_emission` and `truncate_reticle`. Added structural state fallback in `get_protocol` to infer reticle identity from `projector_unit`, `head_flight_id`, and `retreat_tick`, restoring reticle tail-severing and stationary beam truncation.
5. **Runtime Require Elimination (`scripts/utils/motion-protocols.lua`, `scripts/flow/flow-kinetic.lua`):** Purged all runtime `require()` calls inside event handlers and disruption delegates, registering policies and passing module references at startup to comply with Factorio 2.0 runtime script restrictions.
6. **Automated Verification Expansion (`scripts/utils/motion-protocols.lua`):** Added Test 6 (detector filtering) and Test 7 (forward/backward clearance policy bifurcation) to `/test-motion-protocols`.


### Revision: Clearance Policy Generalization and Relative Bifurcation Fix
**Date:** 2026-09-18 22:24 EDT
**Context:** During automated verification of the clearance protocol engine, Test 7 failed because `dispatch_clearance_policy` had been coupled to the reticle's internal `status == "growing"` state, causing generic flights and non-reticle protocols to misroute forward obstacles into backward handlers. This session excised the reticle-specific status guard, restoring the pure mathematical relative distance contract ($d_{\text{obst}} > d_{\text{current}} + 0.05 \implies \text{forward}$, $d_{\text{obst}} \le d_{\text{current}} + 0.05 \implies \text{backward}$) across all flight domains and passing all 7 test suites.
**Key Changes:**
1. **Generic Clearance Policy Dispatching (`scripts/utils/motion-protocols.lua`):** Removed the `is_growing` reticle state requirement from `dispatch_clearance_policy`, ensuring forward obstacles ahead of any advancing flight evaluate to `on_forward` regardless of protocol identity.
2. **Automated Verification Validation (`scripts/utils/motion-protocols.lua`):** Confirmed live in-game green passes across all 7 automated test suites in `/test-motion-protocols` (base registry, overlapping composition, progression windows, alternative disruptions, facet independence, detectors, and directional clearance policies).