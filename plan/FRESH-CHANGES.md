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


### Revision: Persistent Render Object Caching & In-Place Position Updates
**Date:** 2026-08-29 21:29 (EDT)
**Context:** Eliminate 60Hz C++ LuaRenderObject frame-by-frame destruction and recreation overhead for active and parked transit capsules, eliminating Lua-to-C++ bridge thrashing and UPS lockup during stalled backpressure bottlenecks while preserving real-time visual accuracy.
**Key Changes:**
1. **Render Object Caching Engine (`scripts/capsules/capsule-renderer.lua`):** Implemented a 3-state render evaluation state machine (`render_cache`) tracking `surface_index`, position coordinates (`pos_x`, `pos_y`), `passenger_index`, active debug player flags (`debug_key`), `dominant_item`, and render target offsets.
2. **Stationary Capsule NO-OP & In-Place Vector Updates (`scripts/capsules/capsule-renderer.lua`):** Configured immediate early-return (NO-OP) execution for stationary/parked capsules when position and state remain unchanged frame-to-frame. Implemented in-place `render_obj.target` vector updates for moving capsules to reuse existing C++ render handles without object destruction or re-allocation.
3. **Lazy Dominant Item Evaluation & Unified Cache Lifetime (`scripts/capsules/capsule-renderer.lua`, `scripts/capsules/capsule-queries.lua`, `scripts/capsules/capsule-runner.lua`):** Deferred holder inventory scanning (`get_dominant_item`) to execute only when capsule debug overlays are active without a passenger. Updated `clear_capsule_render()` to purge `render_cache = nil` upon entity capture, removal, eject, or spill events.


### Revision: Inventory Bar Slot Bounding & Periodic Spoilage Render Refresh
**Date:** 2026-08-29 22:13 (EDT)
**Context:** Eliminate unnecessary C++ `LuaItemStack` userdata allocations on red-locked inventory slots during lifecycle and rendering iterations, purge stale spoilage tracking data, and update parked capsule debug overlays when stored cargo spoils naturally.
**Key Changes:**
1. **Active Inventory Slot Bounding (`scripts/capsules/capsule-lifecycle.lua` & `scripts/capsules/capsule-renderer.lua`):** Integrated `supports_bar()` and `get_bar()` bounds checking (`max_slot`) across spoilage processing and dominant item queries. Restricts inventory iteration strictly to unlocked chest slots, preventing expensive engine allocations on locked slots.
2. **Stale Spoilage Tracking Cleanup (`scripts/capsules/capsule-lifecycle.lua`):** Added a post-loop purge clearing `capsule.slot_spoil_percents` tracking entries for slot indices greater than `max_slot` to prevent stale memory state when inventory bar boundaries shift.
3. **Parked Capsule Spoilage Sprite Refresh (`scripts/capsules/capsule-renderer.lua`):** Added a 60-tick periodic re-evaluation (`((game.tick + tick_offset) % 60 == 0)`) to render cache validation. Forces stationary or parked capsules to re-query their dominant item so visual debug overlays update dynamically as cargo spoils.


### Revision: Alt Mode Capsule Peeking Overlay & Debug Flag Mutual Exclusion
**Date:** 2026-08-29 22:34 (EDT)
**Context:** Implement entity-hover capsule peeking (`/capsule-peek`) in Alt Mode to visually inspect capsules occupying targeted pneumatic entities without enabling global capsule overlays, while enforcing mutual exclusion between capsule debug modes.
**Key Changes:**
1. **Capsule Peeking Console Command (`scripts/debug-manager.lua`):** Registered `/capsule-peek` command to toggle `storage.debug[player_index].peek`. Enforced mutual exclusion between `peek` and `capsules` debug toggles so enabling one automatically disables the other while allowing both to be turned off.
2. **Alt Mode & Hover Occupancy Filtering (`scripts/capsules/capsule-renderer.lua`):** Updated visual overlay evaluation to require active Alt Mode (`player.game_view_settings.show_entity_info`). Implemented entity unit number matching (`player.selected.unit_number`) against capsule port keys (`from_port_key` / `to_port_key`) when peeking, isolating rendered overlay sprites strictly to capsules occupying the hovered structure.
3. **Render Cache Dynamic Player Keying (`scripts/capsules/capsule-renderer.lua`):** Integrated `wants_peek` state into `debug_key` render cache validation, seamlessly updating visual overlay objects on mouse movement across entities without breaking frame-by-frame stationary capsule caching optimizations.


### Revision: Short-Circuited O(1) Network Capacity Queries & Node Group Caching
**Date:** 2026-08-29 23:13 (EDT)
**Context:** Eliminate $O(N^2)$ entity-network capacity query overhead during segment pathfinding and backpressure bottlenecks by implementing early-exit threshold limits, deferred origin group evaluation, pre-resolved parameter passing, and flow map node group caching.
**Key Changes:**
1. **Early-Exit Capacity Threshold (`scripts/capsules/capsule-queries.lua`):** Added an optional `max_threshold` parameter to `get_capsule_count_at_entity_network()`. Iteration over `storage.capsules` early-returns immediately once `count >= max_threshold`, converting $O(N)$ table scans into $O(1)$ early exits on occupied target segments.
2. **Pre-Resolved Group Passing & Deferred Evaluation (`scripts/capsules/capsule-motion.lua`):** Refactored `has_entity_network_capacity()` to pre-calculate `target_group` once and pass it directly as a parameter to `get_capsule_count_at_entity_network()`. Deferred `current_group` query (`get_port_group(from_port_key)`) to execute strictly during same-entity/same-network hops.
3. **Flow Map Node Group Caching (`scripts/capsules/capsule-queries.lua`):** Updated `get_port_group()` to cache resolved port group IDs directly on flow map nodes (`node.group = group or false`), ensuring subsequent group checks complete in $O(1)$ time without re-querying entity prototype port definitions.


### Revision: Per-Force Bio-Integrity Tech Caching & Staggered Fragile Spill Evaluation
**Date:** 2026-08-29 23:37 (EDT)
**Context:** Eliminate per-tick `force.technologies` string indexing overhead and 60Hz `math.random()` RNG execution on fragile transit capsules by implementing event-driven technology level caching and staggered interval risk scaling.
**Key Changes:**
1. **Per-Force Technology Level Caching (`scripts/capsules/capsule-lifecycle.lua` & `control.lua`):** Replaced per-tick `force.technologies` string table lookups with an O(1) cached research tier lookup (`storage.bio_integrity_levels[force.index]`). Initialized `storage.bio_integrity_levels` in `control.lua` (`setup_storage`).
2. **Event-Driven Research Sync (`scripts/capsules/capsule-lifecycle.lua`):** Registered event listeners for `on_research_finished`, `on_research_reversed`, and `on_technology_effects_reset` to automatically update cached `bio-capsule-integrity` research tiers upon technology state changes.
3. **Staggered 10-Tick Spill Evaluation & Risk Compounding (`scripts/capsules/capsule-lifecycle.lua`):** Throttled fragile container spill risk checks to evaluate every 10 ticks (`(game.tick + id) % 10 == 0`), applying exact probability compounding ($R_{10} = 1 - (1 - r)^{10}$) to reduce RNG rolls by 90% while preserving mathematically exact failure rates.


### Revision: Pump & Hub Operational State Sensitivity, Flow Listener Decoupling & Cyclic Require Fix
**Date:** 2026-08-30 09:45 (EDT)
**Context:** Resolve flow map vector generation ignoring pump enable toggles, eliminate a 5-file load-time circular dependency loop between network and capsule modules, and instantly wake parked capsules on hub/pump operational state changes.
**Key Changes:**
1. **Pump Enable State Verification (`scripts/networks/networks-flow.lua` & `scripts/networks/pump-manager.lua`):** Updated `is_powered()` to evaluate `(entity.energy > 0) and pump_settings.is_pump_enabled(entity)` for pneumatic pumps, correctly closing flow vectors when pumps are disabled. Synchronized `pump_enabled_states` and `pump_power_states` arrays immediately inside `pump_manager.notify_settings_changed()`.
2. **Decoupled Flow Listener Subscription (`scripts/networks/networks-flow.lua` & `scripts/capsules/capsule-runner.lua`):** Replaced direct module `require` in `networks-flow.lua` with a listener subscription pattern (`networks_flow.register_listener`). Subscribed `capsule_runner.wake_parked_capsules` to flow updates, eliminating a 5-file load-time circular require loop (`networks-flow` -> `capsule-runner` -> `capsule-motion` -> `capsule-renderer` -> `debug-manager` -> `networks-flow`) while guaranteeing instant wakeup of parked capsules when flow maps rebuild.
3. **Event-Driven Hub GUI Notification Engine (`scripts/hubs/hub-manager.lua` & `scripts/hubs/hub-gui.lua`):** Added `hub_manager.notify_settings_changed(entity)` and hooked all `hub-gui.lua` interaction callbacks (`on_gui_checked_state_changed`, `on_gui_elem_changed`, `on_gui_selection_state_changed`, `on_gui_text_changed`) to fire it. Instantly wakes parked disembarking capsules and triggers immediate inventory packing checks when send/receive permissions flip.


### Revision: Diverter Operational State Sensitivity & Flow Rebuild Deduplication
**Date:** 2026-08-30 10:09 (EDT)
**Context:** Synchronize diverter power and port state caches immediately during GUI settings updates to instantly wake parked capsules while eliminating duplicate flow map rebuild calls across multi-port diverter networks.
**Key Changes:**
1. **Synchronous Diverter State Cache Sync (`scripts/networks/diverter-manager.lua`):** Updated `diverter_manager.notify_settings_changed()` to immediately synchronize `storage.diverter_power_states` and `storage.diverter_port_states` arrays upon GUI configuration events. This guarantees instant flow map updates and listener execution (`capsule_runner.wake_parked_capsules`) while preventing the 15-tick background scanner (`check_diverter_states`) from detecting stale mismatches and triggering duplicate flow rebuilds.
2. **Network Rebuild Deduplication (`scripts/networks/diverter-manager.lua`):** Refactored `rebuild_diverter_networks()` to utilize a `visited` network ID lookup table across all 4 diverter ports, ensuring `networks_flow.build(net_id)` is executed at most once per connected network per update.


### Revision: Topology-State Decoupling, Port Evaluator Cleanup & Orientation State Sync
**Date:** 2026-08-30 10:28 (EDT)
**Context:** Resolve stale flow map vectors on pneumatic pumps and diverters when rotated or flipped while disabled, and ensure enable/disable GUI toggles reliably update flow map state across orientation changes.
**Key Changes:**
1. **Physical Topology & Operational State Decoupling (`scripts/ports/port-evaluator.lua` & `scripts/ports/port-definitions.lua`):** Removed `enabled == false` connection rejection in `port_evaluator.are_compatible()`, allowing spatial graph topology (`storage.port_connections`) to form permanently based on physical directional compatibility (`"in"`, `"out"`, `"any"`). Dynamic pressure (`nil`) and flow vector suppression (`enabled = false`) remain active when disabled without corrupting graph links.
2. **Synchronous Orientation Cache & Flow Rebuild (`scripts/networks/network-rotate.lua`, `scripts/networks/pump-manager.lua`, `scripts/networks/diverter-manager.lua`):** Hooked `on_player_rotated_entity` and `on_player_flipped_entity` across pump and diverter managers to immediately update power and port state caches upon rotation/flipping.
3. **Pump Network Rebuild Deduplication (`scripts/networks/pump-manager.lua`):** Integrated a `visited` network ID lookup table into `rebuild_pump_networks()` to eliminate duplicate `networks_flow.build()` calls across multi-port pump sub-networks.