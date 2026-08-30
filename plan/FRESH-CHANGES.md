### Revision: Dynamic Liminal Holder Inventory Capacity & Prototype Expansion
**Date:** 2026-08-29 14:52 (EDT)
**Context:** Expand liminal surface container cargohold limits and implement dynamic runtime inventory bar bounds to accommodate high-capacity or quality-scaled transit capsules without cargo truncation or container slot overflow.
**Key Changes:**
1. **Holder Prototype Capacity Expansion (`prototypes/entity.lua`):** Increased `inventory_size` from 10 to 255 for both `invisible-capsule-holder` and `visible-capsule-holder` container prototypes, establishing sufficient prototype storage headroom for quality scaling and high-tier specialized capsules.
2. **Dynamic Inventory Bar Sizing (`scripts/hubs/hub-packing.lua`):** Implemented runtime inventory bar setting (`dest_inv.set_bar(...)`) during holder entity instantiation on `liminal_surface`. Dynamically clamps active holder slots to `math.max(total_capacity, self_slot_cost)` for each capsule instance, locking unused slots and scoping primary shell slot allocation searches to active slots (`get_bar() - 1`).
3. **Bounded Unpacking Traversals (`scripts/hubs/hub-unpacking.lua`):** Refactored payload space evaluation (`can_insert_all`) and item capture (`capture`) routines to restrict holder inventory loops to active slots bounded by `get_bar() - 1`, optimizing unpacking performance and preventing unnecessary slot scans across empty container indices.


### Revision: Spilled Capsule Container Capacity & Anti-Exploit Bar Enforcement
**Date:** 2026-08-29 16:50 (EDT)
**Context:** Enable spilled capsule containers to hold variable-sized cargo payloads without truncation while preventing players from exploiting spilled container entities as free large-capacity storage chests.
**Key Changes:**
1. **Container Prototype Bar Support (`prototypes/entity.lua`):** Updated `inventory_type` from `"with_filters"` to `"with_bar"` on the `visible-capsule-holder` prototype, activating engine-level inventory limiter bar controls (`LuaInventory.supports_bar() == true`) across its 255-slot inventory size.
2. **0-Tick Anti-Exploit Bar Enforcement (`scripts/hubs/hub-spill.lua`):** Implemented a 60Hz `on_tick` scanner and instant GUI listeners (`on_gui_opened`, `on_gui_closed`) tracking `storage.spilled_containers`. Immediately re-enforces `set_bar(1)` on the exact tick if a player attempts to drag open the inventory bar limit, red-locking all slots against item insertion while permitting item extraction.
3. **Automatic Empty Container Cleanup (`scripts/hubs/hub-spill.lua`):** Configured instant container self-destruction (`entity.destroy()`) the exact tick all spilled items are extracted (`container_inv.is_empty()`), preventing empty holder entities from lingering on the surface.


### Revision: Grid-Spaced Liminal Surface Spawning & Position Recycling
**Date:** 2026-08-29 19:13 (EDT)
**Context:** Implement an 8-tile grid position allocation engine with slot recycling on `liminal_surface` and synchronous chunk generation to eliminate container spawn failures during rapid dispatches and enable unambiguous proximity detection for units spawned from spoiled items.
**Key Changes:**
1. **Grid Allocation & Recycling Engine (`scripts/surfaces/liminal-surface.lua`):** Implemented `allocate_position()` and `release_position()` managing `storage.liminal_grid` free slot stacks (`free_slots`). Configured 8-tile spacing (`GRID_SPACING = 8`) to isolate container cells for spoilage proximity queries (`find_holder_near`, radius `3.5`) while compactly fitting 16 cells per chunk.
2. **Synchronous Chunk Generation (`scripts/surfaces/liminal-surface.lua` & `scripts/hubs/hub-packing.lua`):** Introduced `ensure_chunk_at()`, calling `request_to_generate_chunks` and `force_generate_chunk_requests()` prior to `create_entity()` to guarantee target chunks exist on the current tick. Updated `map_gen_settings` (`width = 0, height = 0`) for unconstrained grid terrain expansion.
3. **Centralized Position Lifecycle & Storage Sync (`scripts/capsules/capsule-manager.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/capsules/capsule-runner.lua`, `control.lua`):** Stored `position` metadata in `storage.active_capsules` and funneled holder removals through `capsule_manager.remove()` to automatically recycle grid positions. Initialized grid storage in `control.lua` (`setup_storage`) and enforced top-level module imports.


### Revision: Liminal Holder Debug Selectability & Spoiled Unit Cross-Surface Re-instantiation
**Date:** 2026-08-29 20:10 (EDT)
**Context:** Enable container selectability of liminal holders for in-game debugging and implement cross-surface unit re-instantiation for items spoiling inside transit capsules to mirror their location while preserving Quality and Health decay.
**Key Changes:**
1. **Liminal Holder Debug Selectability (`prototypes/entity.lua`):** Removed `"not-selectable-in-game"` flag, set `operable = true`, and assigned `selection_box = {{-0.5, -0.5}, {0.5, 0.5}}` on the `invisible-capsule-holder` container prototype, enabling debug selection and inventory inspection.
2. **Transit Capsule Location Resolver (`scripts/capsules/capsule-runner.lua`):** Implemented `capsule_runner.get_capsule_location(capsule_id)` to dynamically calculate the physical surface coordinates and surface handles of in-transit or parked capsules.
3. **Spoiled Unit Cross-Surface Re-instantiation (`scripts/capsules/capsule-runner.lua`):** Implemented `handle_liminal_entity_spawn()` and a 60-tick periodic scanner intercepting entities created on `liminal_surface`. Resolves parent container cells (`find_holder_near`, radius `3.5`) and checks primary capsule unit permissions (`spill_contents.units ~= false`). Bypasses Factorio engine cross-surface teleport limits by re-instantiating units on the physical target surface—preserving Factorio 2.0 `quality` and decayed `health`—before destroying the liminal unit entity.
4. **Cyclic Dependency Elimination (`scripts/surfaces/liminal-surface.lua` & `scripts/capsules/capsule-runner.lua`):** Decoupled startup initialization between `liminal-surface.lua` and `capsule-manager.lua` by consolidating spoilage event handling directly into `capsule-runner.lua`, preventing load-time dependency cycles.


### Revision: Parked Capsule Simulation Throttling, Instant Wakeup & Pathfinding Regex Elimination
**Date:** 2026-08-29 21:00 (EDT)
**Context:** Eliminate 60Hz simulation and pathfinding loops for parked transit capsules waiting on full hub inventories or constrained network segments, reducing CPU overhead during backpressure bottlenecks while preserving instant transit dispatches.
**Key Changes:**
1. **Parked Capsule Retry Throttling (`scripts/capsules/capsule-runner.lua`):** Implemented a 10-tick retry interval (`PARKED_RETRY_INTERVAL = 10`) for stationary capsules (`to_port_key == nil`), deferring heavy inventory insertion simulations (`can_insert_all`) and outbound hop searches (`select_next_target`) while maintaining 60Hz passenger positioning, spoilage lifecycle updates, and visual overlays.
2. **Instant Event-Driven Wakeup Engine (`scripts/capsules/capsule-runner.lua`):** Implemented `capsule_runner.wake_parked_capsules()` to clear `next_retry_tick` across parked capsules upon item disembarkation, capsule injection, removal, or mid-transit rupture events, guaranteeing instant queue advancement when downstream space opens.
3. **Pattern Matching & Regex Elimination (`scripts/capsules/capsule-motion.lua`):** Replaced regex pattern splitting (`:match("^(%d+):(%d+)$")` and `:match("^(%d+)")`) with `get_unit_number()`, leveraging pre-cached flow map node metadata (`unit_number`, `port_index`) and plain substring slicing (`string.find`/`string.sub`) to eliminate tick-by-tick allocation overhead.
4. **Fast-Path Inventory Space Evaluation (`scripts/hubs/hub-unpacking.lua`):** Added an O(1) empty container evaluation path in `can_insert_all()`, comparing total required item stacks directly against usable chest capacity for filterless hub containers to bypass slot-by-slot inventory iterations.