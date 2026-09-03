### Revision: Refined Tech Tree Progression, Ingredient-Tech Prerequisite Mapping & Recipe Overhaul
**Date:** 2026-09-03 09:31 (EDT)
**Context:** Align item recipes and technology unlocks with refined progression specifications (`TECH-TREE-REFINED.md` and `RECIPES-REFINED.md`), enforce explicit technology prerequisites for all gated recipe ingredients, and update recipe syntax for Factorio 2.1 compatibility.
**Key Changes:**
1. **Recipe Cost Overhaul & Recharge Mechanics (`prototypes/recipe.lua`):**
   - Rebalanced crafting ingredient requirements across all infrastructure items, junctions, hubs, diverters, and capsule variants to match refined target recipes.
   - Added the `recharge-refrigerated-capsule` recipe allowing players to restore `spent-refrigerated-capsule` items using 125 units of cold fluoroketone while producing 100 units of hot fluoroketone as a byproduct.
   - Updated recipe definitions to Factorio 2.1 specifications by replacing deprecated single `category` string fields with `categories = { "category-name" }` array tables.
2. **Tiered Technology Progression Restructuring (`prototypes/technology.lua`):**
   - Distributed unlocks into distinct science and planet progression tiers: Red/Green science (`pneumatic-transport`), Blue science (`specialized-pneumatic-capsules`), Gleba (`biodegradable-capsule`), Vulcanus (`reinforced-capsule`), and Aquilo (`refrigerated-capsule`).
   - Re-linked `bio-capsule-integrity-1` through `4` upgrade research tiers to require the `biodegradable-capsule` technology node as their prerequisite root.
3. **Explicit Ingredient Technology Prerequisite Mapping (`prototypes/technology.lua`):**
   - Audited all 13 recipe ingredient chains and bound exact prerequisite technologies (`engine`, `advanced-circuit`, `low-density-structure`, `carbon-fiber`, `sulfur-processing`, `tungsten-carbide`, `cryogenic-plant`, `lithium-processing`, and `electromagnetic-plant`) into corresponding research nodes to ensure valid technology graph progression and prevent uncraftable recipe unlocks.


### Revision: Stage 1 v1 Engine Removal — Decouple Configuration, Entry Points & Debug
**Date:** 2026-09-03 10:30 (EDT)
**Context:** Execute Stage 1 of the v1 deprecation plan, establishing the v2 flow engine as the sole execution path by removing `FLOW_VERSION` startup gating, v1 imports in `control.lua`, legacy motion calculation code, and obsolete debug overlays.
**Key Changes:**
1. **Startup Setting Purge (`settings.lua`):** Removed `pneumatic-flow-version` startup setting definition, locking execution path strictly to the v2 flow engine.
2. **Unconditional v2 Entry Point Registration (`control.lua`):** Removed legacy v1 module imports (`networks`, `networks-flow`, `port-renderer`, `port-finder`, `network-connect`, `network-disconnect`, `network-rotate`). Updated lifecycle hooks to unconditionally initialize v2 `flow_engine` and `v2_capsule_runner` event listeners and storage structures.
3. **Capsule Runner Facade Alias (`scripts/capsules/capsule-runner.lua`):** Purged over 500 lines of legacy v1 motion calculation loops, pressure queries, and event handlers; converted script into a zero-allocation direct passthrough returning `require("scripts.flow.capsule-runner")`.
4. **Debug Interface & Command Consolidation (`scripts/debug-manager.lua`):** Purged legacy v1 UI checkboxes (`pneumatic_debug_chk_flow`, `pneumatic_debug_chk_ports`) and commands (`/toggle-ports`). Re-mapped `/toggle-flow` and `/pt-toggle-flow` directly to control the v2 Alt Mode flow engine vector overlay.


### Revision: Stage 2 v1 Engine Removal — Decouple Machine Managers & Lifecycle Hooks
**Date:** 2026-09-03 10:40 (EDT)
**Context:** Execute Stage 2 of the v1 deprecation plan by disconnecting legacy network graph rebuilding (`network-rebuild-engine`, `port-definitions`) and `FLOW_VERSION` gating from machine state managers and entity lifecycle event handlers.
**Key Changes:**
1. **Pump & Diverter State Managers (`scripts/networks/pump-manager.lua`, `scripts/networks/diverter-manager.lua`):** Removed top-level requires for `network-rebuild-engine` and `port-definitions`. Simplified `rebuild_pump_networks` and `rebuild_diverter_networks` to unconditionally route machine power and state updates directly to `flow_engine.enqueue_unit_ports` and `capsule_runner.wake_parked_capsules`.
2. **Placement & Removal Hooks (`scripts/networks/network-connect.lua`, `scripts/networks/network-disconnect.lua`):** Removed legacy `network_validate` and `network_invalidate` execution calls on entity placement and destruction. Retained `hub_spill.handle_entity_destruction` in `network-disconnect.lua` to preserve cargo spillage on structure destruction.
3. **Orientation Event Handler (`scripts/networks/network-rotate.lua`):** Purged v1 network invalidation and re-validation calls from `on_player_rotated_entity` and `on_player_flipped_entity` event listeners while preserving proxy linkage settings notifications (`notify_settings_changed`) for pumps and diverters.


### Revision: Stage 3 v1 Engine Removal — Obsolete File Purge, Manager Relocation & Storage Migration
**Date:** 2026-09-03 10:45 (EDT)
**Context:** Execute Stage 3 of the v1 deprecation plan by deleting obsolete v1 network graph, port topology, and legacy motion files, relocating active machine state managers out of `scripts/networks/`, and implementing save-game storage cleanup.
**Key Changes:**
1. **Obsolete File Purge (`scripts/networks/`, `scripts/ports/`, `scripts/capsules/`):** Deleted 25 legacy v1 source files including network graph rebuild engines, port evaluators, flow/pressure calculators, edge handlers, and the obsolete `capsule-motion.lua` script.
2. **Machine Manager Relocation (`scripts/pump-manager.lua`, `scripts/diverter-manager.lua`):** Moved active `pump-manager.lua` and `diverter-manager.lua` scripts out of `scripts/networks/` into `scripts/`. Updated all top-level `require` paths across `control.lua`, `pump-gui.lua`, and `diverter-gui.lua`.
3. **Storage Migration & Save Cleanup (`control.lua`):** Added explicit `nil`-clearing migration logic in `script.on_configuration_changed` for legacy v1 storage tables (`storage.networks`, `storage.port_connections`, `storage.port_pressures`, `storage.network_rebuild_queue`, `storage.port_to_network`) to free save-game memory.


### Revision: Stage 4 v1 Engine Removal — v2 Runner Consolidation & Architecture Finalization
**Date:** 2026-09-03 10:55 (EDT)
**Context:** Complete Stage 4 of the v1 engine removal plan by consolidating the v2 capsule runner implementation directly into `scripts/capsules/capsule-runner.lua`, purging obsolete `FLOW_VERSION` gating checks across the v2 suite, deleting redundant script layers, and updating top-level entry point bindings.
**Key Changes:**
1. **Runner Implementation Consolidation (`scripts/capsules/capsule-runner.lua`):** Transferred the complete v2 motion runner engine, spatial parked index management, zero-allocation pathfinding scratch buffers, and event handlers into `scripts/capsules/capsule-runner.lua`, and deleted the obsolete `scripts/flow/capsule-runner.lua`.
2. **Legacy Flow Version Gating Purge (`scripts/capsules/capsule-runner.lua`, `scripts/flow/flow-engine.lua`):** Purged stale `FLOW_VERSION` gating checks (`FLOW_VERSION ~= "v2"`) across stepper functions, renderers, and event registrations to establish v2 as the sole execution path.
3. **Control Entry Point Alignment (`control.lua`):** Updated top-level imports in `control.lua` to require `scripts.capsules.capsule-runner` directly and register its event listeners alongside `flow_engine.register_events()`.