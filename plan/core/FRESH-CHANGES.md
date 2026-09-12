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