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