# CHANGELOG.md - Architecture Revisions & Historical Log

## Revisions & Historical Log

### Revision: Hub Packing to Motion Runner Handoff `[INCORPORATED IN TABLE]`
**Context:** Bridge static cargo packing directly to the dynamic motion engine.
**Key Changes:**
1. **Deprecation of `storage.hub_compartments`:** Hubs no longer track internal packed capsules via isolated storage tables.
2. **Dynamic Occupancy via Runner:** Hub occupancy is calculated dynamically by `capsule-runner.lua` via `get_capsule_count_at_entity()`.
3. **Direct Injection Handoff:** Finished liminal holders trigger `capsule_runner.inject_from_hub()`.
4. **Network Disconnect Fallback:** Reverses packing if target entity is not bound to a network.

### Revision: Smarter Hub Injection & Internal Isolation `[INCORPORATED IN TABLE]`
**Context:** Prevent capsules from leaking into hubs due to isolated internal ports.
**Key Changes:**
1. **Flow Map Peeking:** Evaluates `flow_map` metadata of connected ports.
2. **Optimal Gradient Injection:** Spawns capsule on port with highest outbound pressure drop ($\Delta P = P_{\text{from}} - P_{\text{to}}$).
3. **Dormant Fallback:** Default injection onto port while awaiting flow establishment.

### Revision: Hub Capture, Unpacking & Mechanical Latch `[INCORPORATED IN TABLE]`
**Context:** Implemented destination unpacking and anti-infinite-loop latches.
**Key Changes:**
1. **Short-Term Capsule Memory:** Capsules track `source_hub` (`unit_number`) until stepping off origin entity.
2. **Hub Capture & Unpacking (`hub-unpacking.lua`):** Arriving at a new hub triggers inventory unloading and liminal holder destruction.
3. **Mechanical Latch (`storage.hub_receive_locks`):** Destination hubs lock on receipt and refuse to pack until chest is completely empty.

### Revision: All-or-Nothing Virtual Unpacking & Stationary Re-evaluation `[INCORPORATED IN TABLE]`
**Context:** Prevent hubs from partially skimming items out of capsules mid-transit and fix dormant/sleeping capsule states at full hubs.
**Key Changes:**
1. **All-or-Nothing Virtual Unpacking (`hub-unpacking.lua`):** Added `can_insert_all()` pre-check using `LuaInventory.get_insertable_count()` to aggregate all liminal holder contents (cargo + item-capsule vessel). Aborts transfer entirely if the destination hub chest cannot fit 100% of the payload in a single swoop.
2. **Single Source Payload Tracking (`hub-unpacking.lua`):** Treats the liminal holder inventory as the single source of truth for both cargo and vessel items to eliminate duplicate item generation.
3. **Continuous Arrival Polling (`capsule-runner.lua`):** Updated `update_capsules()` so stationary capsules (`to_port_key == nil`) re-trigger `handle_arrival()` on every tick while parked at a hub port. Parked capsules immediately resume unpacking the moment space is cleared in the hub chest.

### Revision: Continuous Stationary Polling & Occupancy Lockout Fix `[INCORPORATED IN TABLE]`
**Context:** Fixes a bug where stationary capsules parked at full hubs would fall asleep indefinitely and only wake up when network flow changed.
**Key Changes:**
1. **Stationary Arrival Polling (`capsule-runner.lua`):** Modified `update_capsules()` to invoke `handle_arrival()` at the start of the tick loop for stationary capsules (`to_port_key == nil`). Parked capsules now continuously poll the destination hub inventory on every tick.
2. **Removal of Occupancy Lockout (`capsule-runner.lua`):** Removed the artificial `occupancy <= capsule_capacity` pre-check inside `handle_arrival()`. Eliminates deadlocks where trailing queued capsules artificially inflated total entity occupancy and locked both out. Unpacking safety is now governed strictly by virtual item insertion capacity in `hub-unpacking.lua`.

### Revision: Priority Lock Clearing & Order-of-Operations Fix `[INCORPORATED IN TABLE]`
**Context:** Fixed a bug where hubs remained stuck in `storage.hub_receive_locks` even after being completely emptied, preventing future capsule packing when reloaded.
**Key Changes:**
1. **Mechanical Latch Re-ordering (`hub-packing.lua`):** Shifted the mechanical latch and lock evaluation block to the very top of `evaluate_inventory()`, executing *before* the capsule capacity guard.
2. **Unconditional Lock Removal on Empty (`hub-packing.lua`):** Ensures that whenever a hub chest is completely emptied (`inventory.is_empty()`), the lock is released immediately without being blocked or bypassed by parked capsule occupancy counts.

### Revision: Multi-Item Slot Simulation Unpacking `[INCORPORATED IN TABLE]`
**Context:** Resolved an item skimming issue where capsules partially unloaded cargo because `LuaInventory.get_insertable_count()` evaluated multi-item payload capacities independently.
**Key Changes:**
1. **Multi-Item Slot Simulation (`hub-unpacking.lua`):** Upgraded `can_insert_all()` to simulate combined inventory space across all payload item types (cargo + capsule vessel shell). It maps partial stack space and allocates empty slots sequentially to prevent multiple distinct items from claiming identical empty chest slots prior to unpacking.

### Revision: Inventory Slot Filter Awareness in Unpacking `[INCORPORATED IN TABLE]`
**Context:** Fixed an issue where `can_insert_all()` treated empty slots configured with item filters as open space for any item type, leading to partial unloading at hubs.
**Key Changes:**
1. **Slot Filter Evaluation (`hub-unpacking.lua`):** Updated `can_insert_all()` to query `hub_inv.get_filter(i)`. Empty slots with active filters are now categorized separately and are only counted as available space if the incoming item matches the configured filter prototype.

### Revision: Centralized Debug Toggle System & Master Control Architecture `[INCORPORATED IN TABLE]`
**Context:** Consolidated all scattered debug console commands, chat prints, and rendering overlays into a centralized debug manager with `master = false` and feature sub-flags default-enabled (`true`) so toggling master instantly activates all overlays across the mod.
**Key Changes:**
1. **Central Debug Manager (`scripts/debug-manager.lua`):** Implemented a self-initializing debug manager maintaining unified `storage.debug` state (`master = false`, `ports = true`, `flow = true`, `capsules = true`, `prints = true`), exposing the global `debug_print(msg)` wrapper and `is_debug_active(feature)` evaluator.
2. **Master & Feature Console Commands (`scripts/debug-manager.lua`):** Consolidated toggle commands under `debug-manager.lua` (`/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules`) and removed duplicate command registrations across sub-modules to eliminate runtime collisions.
3. **Overlay Renderer API Export (`port-renderer.lua` & `networks-flow.lua`):** Exported explicit `draw_all()` and `clear_all()` lifecycle methods on module return tables, resolving runtime `nil` function call crashes when toggling overlays via console commands.
4. **Global Print Wrapper (`debug_print`):** Replaced hardcoded `game.print` calls across network graph scripts (`network-form-internals`, `network-join`, `network-merge`, `network-unjoin`, `network-unmerge`, `network-validate`, `networks-store`, `event-logger`) with `debug_print`, gating console text output behind both master and print flags.
5. **Capsule Runner Sync (`capsule-runner.lua`):** Deprecated legacy `storage.show_capsules` flag and removed duplicate `/toggle-capsule` command. Synchronized tick motion circle rendering with `is_debug_active("capsules")` while retaining `/spawn-capsule` and `/clear-capsules` utility action commands.

### Revision: Removal of Capsule Testing Commands `[INCORPORATED IN TABLE]`
**Context:** Cleaned up temporary development commands in `capsule-runner.lua` to prevent accidental state corruption or cheating in release builds.
**Key Changes:**
1. **Dev Command Removal (`capsule-runner.lua`):** Completely removed `/spawn-capsule` and `/clear-capsules` console commands, locking capsule instantiation and cleanup exclusively to normal mod runtime logic.

### Revision: Default Debug Configuration Adjustment `[INCORPORATED IN TABLE]`
**Context:** Refined default debug manager initialization settings to enable master debug out of the box while keeping default visual output focused solely on capsule tracking.
**Key Changes:**
1. **Default State Configuration (`debug-manager.lua`):** Initialized `master = true` and `capsules = true` by default, while setting `ports`, `flow`, and `prints` to `false` so only capsule rendering is active on initial load.

### Revision: Slot Filter Normalization & Quality-Aware Unpacking Fix `[INCORPORATED IN TABLE]`
**Context:** Fixed a virtual inventory evaluation bug in `hub-unpacking.lua` where hubs with valid item filters falsely reported insufficient space and rejected incoming payload capsules.
**Key Changes:**
1. **Filter Extraction Normalization (`hub-unpacking.lua`):** Updated `can_insert_all()` to parse Factorio 2.0+ filter structures returned by `get_filter(i)`, extracting clean string values (`filter_name` and `filter_quality`) instead of indexing unique table references.
2. **Quality-Aware Filter Matching (`hub-unpacking.lua`):** Enhanced slot space evaluation to allocate items against specific quality filters (e.g., `iron-ore|uncommon`) before falling back to generic item prototype filters and unfiltered empty slots.

### Revision: Documentation Restructuring & File Extension Standardization `[INCORPORATED IN TABLE]`
**Context:** Standardized file naming conventions and split historical revision logs out of the main architectural manifest to optimize developer workflow and LLM context limits.
**Key Changes:**
1. **Markdown Extension Migration:** Transitioned documentation files from plain `.txt` extensions to native `.md` format to enable rich Markdown parsing and native editor/VS Code icon theme integration.
2. **Roadmap Standardization:** Renamed `roadmap.txt` to `ROADMAP.md`.
3. **Architecture & Changelog Decoupling:** Split the unified table document into two dedicated files: `ARCHITECTURE.md` for active system blueprints and `CHANGELOG.md` for historical revision tracking.

### Revision: Entity Destruction & Capsule Spill Safety
**Context:** Prevent liminal holder entity leaks, orphaned storage state tables, and lost items when network components (tubes, junctions, pumps) hosting active in-transit or parked capsules are mined or destroyed.
**Key Changes:**
1. **Generalized Network Spill Pipeline (`hub-spill.lua`):** Expanded spill routines beyond hub entities into `handle_entity_destruction()`, allowing tubes, pumps, and junctions to spill capsule payloads (cargo + vessel items) directly onto the ground or into container entities upon destruction.
2. **In-Transit Capsule Query & Removal (`capsule-runner.lua`):** Implemented `find_capsules_at_entity()` and `remove_capsule()` to locate active or parked capsules bound to an entity's ports, unregistering them from runner tracking and destroying visual rendering objects.
3. **Disconnect Hook Interception (`network-disconnect.lua`):** Integrated payload spill handling directly into entity removal event listeners (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`), guaranteeing payload spilling and liminal holder cleanup execute before network graph invalidation.

### Revision: Decoupled Capsule Queries & Circular Dependency Resolution
**Context:** Resolve a runtime circular dependency crash between `hub-spill.lua` and `capsule-runner.lua` triggered during entity destruction events, while strictly maintaining file-scope `require` directives across all modules.
**Key Changes:**
1. **Extracted Capsule Query Module (`capsule-queries.lua`):** Created a standalone module to house active capsule queries (`find_capsules_at_entity`, `get_capsule_count_at_entity`) and tracking cleanup (`remove_capsule`).
2. **Decoupled Destruction Spill Pipeline (`hub-spill.lua`):** Swapped module dependency from `capsule-runner` to `capsule-queries`, allowing entity removal and payload spilling to execute without referencing the motion runner.
3. **API Aliasing & Legacy Deletion (`capsule-runner.lua`):** Required `capsule-queries` at file scope and aliased query/cleanup functions back onto `capsule_runner` for API compatibility. Deleted unneeded dev functions `capsule_runner.spawn` and `capsule_runner.clear_all`.

### Revision: Per-Entity Network Capsule Capacity & In-Line Backpressure
**Context:** Prevent capsules from bunching up at line ends or saturating merged networks by enforcing a configurable per-entity, per-network capsule capacity limit across traversal hops.
**Key Changes:**
1. **Entity-Network Capacity Queries (`capsule-queries.lua`):** Implemented `get_capsule_count_at_entity_network(unit_number, net_id)` to count active or in-transit capsules bound to a specific entity's internal or external network segment, allowing multi-network entities to track capacities independently.
2. **Backpressure Traversal Guard (`capsule-runner.lua`):** Added `has_entity_network_capacity()` and a top-level configurable `MAX_CAPSULES_PER_ENTITY_NETWORK` constant (default `2`). Integrated capacity checks into `select_next_target()`, forcing capsules to park and queue naturally upstream along tube lines when downstream network ports reach capacity.
3. **API Aliasing (`capsule-runner.lua`):** Required and exposed `get_capsule_count_at_entity_network` on the `capsule_runner` module interface for system-wide query compatibility.

### Revision: Electric Energy Interface Fix & Instant Power-State Sensitivity
**Context:** Resolve 0 W power consumption display and false unpowered network recalculations caused by energy buffer depletion mid-frame during entity destruction events.
**Key Changes:**
1. **Energy Source Buffer Tuning (`prototypes/entity.lua`):** Configured `buffer_capacity` to `3kJ` and `input_flow_limit` to `60kW` on the `pneumatic-pump` prototype[cite: 2]. This provides necessary headroom so `entity.energy` remains above zero during mid-frame event checks while maintaining sub-0.1s network shutdown response times upon true grid disconnection[cite: 3].
2. **Sprite Table Correction (`prototypes/entity.lua`):** Updated `pneumatic-pump` prototype definition to use the plural `pictures` table required by `electric-energy-interface` entities[cite: 2].
3. **Power-State Polling & Invalidation (`scripts/networks/pump-manager.lua`):** Implemented a periodic `on_tick` scanner (15-tick interval) tracking `active_pumps` and `pump_power_states`[cite: 1, 6]. Power toggles automatically trigger `networks_flow.build(net_id)` to re-evaluate pressure and flow vectors across connected subgraphs[cite: 1, 5].