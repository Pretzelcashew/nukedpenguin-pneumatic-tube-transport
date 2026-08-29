# Full Content: `CHANGELOG.md`

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

### Revision: Entity Destruction & Capsule Spill Safety `[INCORPORATED IN TABLE]`
**Context:** Prevent liminal holder entity leaks, orphaned storage state tables, and lost items when network components (tubes, junctions, pumps) hosting active in-transit or parked capsules are mined or destroyed.
**Key Changes:**
1. **Generalized Network Spill Pipeline (`hub-spill.lua`):** Expanded spill routines beyond hub entities into `handle_entity_destruction()`, allowing tubes, pumps, and junctions to spill capsule payloads (cargo + vessel items) directly onto the ground or into container entities upon destruction.
2. **In-Transit Capsule Query & Removal (`capsule-runner.lua`):** Implemented `find_capsules_at_entity()` and `remove_capsule()` to locate active or parked capsules bound to an entity's ports, unregistering them from runner tracking and destroying visual rendering objects.
3. **Disconnect Hook Interception (`network-disconnect.lua`):** Integrated payload spill handling directly into entity removal event listeners (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`), guaranteeing payload spilling and liminal holder cleanup execute before network graph invalidation.

### Revision: Decoupled Capsule Queries & Circular Dependency Resolution `[INCORPORATED IN TABLE]`
**Context:** Resolve a runtime circular dependency crash between `hub-spill.lua` and `capsule-runner.lua` triggered during entity destruction events, while strictly maintaining file-scope `require` directives across all modules.
**Key Changes:**
1. **Extracted Capsule Query Module (`capsule-queries.lua`):** Created a standalone module to house active capsule queries (`find_capsules_at_entity`, `get_capsule_count_at_entity`) and tracking cleanup (`remove_capsule`).
2. **Decoupled Destruction Spill Pipeline (`hub-spill.lua`):** Swapped module dependency from `capsule-runner` to `capsule-queries`, allowing entity removal and payload spilling to execute without referencing the motion runner.
3. **API Aliasing & Legacy Deletion (`capsule-runner.lua`):** Required `capsule-queries` at file scope and aliased query/cleanup functions back onto `capsule_runner` for API compatibility. Deleted unneeded dev functions `capsule_runner.spawn` and `capsule_runner.clear_all`.

### Revision: Per-Entity Network Capsule Capacity & In-Line Backpressure `[INCORPORATED IN TABLE]`
**Context:** Prevent capsules from bunching up at line ends or saturating merged networks by enforcing a configurable per-entity, per-network capsule capacity limit across traversal hops.
**Key Changes:**
1. **Entity-Network Capacity Queries (`capsule-queries.lua`):** Implemented `get_capsule_count_at_entity_network(unit_number, net_id)` to count active or in-transit capsules bound to a specific entity's internal or external network segment, allowing multi-network entities to track capacities independently.
2. **Backpressure Traversal Guard (`capsule-runner.lua`):** Added `has_entity_network_capacity()` and a top-level configurable `MAX_CAPSULES_PER_ENTITY_NETWORK` constant (default `2`). Integrated capacity checks into `select_next_target()`, forcing capsules to park and queue naturally upstream along tube lines when downstream network ports reach capacity.
3. **API Aliasing (`capsule-runner.lua`):** Required and exposed `get_capsule_count_at_entity_network` on the `capsule_runner` module interface for system-wide query compatibility.

### Revision: Electric Energy Interface Fix & Instant Power-State Sensitivity `[INCORPORATED IN TABLE]`
**Context:** Resolve 0 W power consumption display and false unpowered network recalculations caused by energy buffer depletion mid-frame during entity destruction events.
**Key Changes:**
1. **Energy Source Buffer Tuning (`prototypes/entity.lua`):** Configured `buffer_capacity` to `3kJ` and `input_flow_limit` to `60kW` on the `pneumatic-pump` prototype. This provides necessary headroom so `entity.energy` remains above zero during mid-frame event checks while maintaining sub-0.1s network shutdown response times upon true grid disconnection.
2. **Sprite Table Correction (`prototypes/entity.lua`):** Updated `pneumatic-pump` prototype definition to use the plural `pictures` table required by `electric-energy-interface` entities.
3. **Power-State Polling & Invalidation (`scripts/networks/pump-manager.lua`):** Implemented a periodic `on_tick` scanner (15-tick interval) tracking `active_pumps` and `pump_power_states`. Power toggles automatically trigger `networks_flow.build(net_id)` to re-evaluate pressure and flow vectors across connected subgraphs.

### Revision: Hub Operational Mode Toggles (`can_send` / `can_receive`) & Relative GUI Integration `[INCORPORATED IN TABLE]`
**Context:** Add configurable operational mode toggles to Hub GUIs, allowing players to restrict hubs to send-only (dispatch), receive-only (arrival), or bidirectional operation without altering physical pressure or network flow vectors.
**Key Changes:**
1. **Persistent Hub Settings Storage (`control.lua`, `hub-manager.lua`):** Initialized `storage.hub_settings` schema to store per-entity boolean toggles (`can_send`, `can_receive` defaulting to `true`). Added automatic entry provisioning on build (`on_hub_built`) and cleanup on entity destruction (`on_hub_removed`).
2. **Relative GUI Anchor & Event Synchronization (`hub-manager.lua`):** Integrated a custom UI panel anchored relative to open hub chest windows using `defines.relative_gui_type.container_gui` and `defines.relative_gui_position.right`. Registered event listeners for `on_gui_opened`, `on_gui_closed`, and `on_gui_checked_state_changed` to dynamically instantiate UI elements and sync toggle state changes.
3. **Dispatch Permission Gating (`hub-packing.lua`):** Integrated an early evaluation guard in `hub_packing.evaluate_inventory()` checking `storage.hub_settings[unit_number].can_send`. If `false`, inventory packing and runner injection are aborted before container item extraction.
4. **Arrival Permission Gating (`hub-unpacking.lua`):** Integrated a capture guard in `hub_unpacking.capture()` checking `storage.hub_settings[unit_number].can_receive`. If `false`, capsule capture and liminal holder inventory transfer are rejected, leaving incoming capsules safely parked upstream on destination entity ports.

### Revision: Dynamic Dominant Capsule Content Visual Indicators `[INCORPORATED IN TABLE]`
**Context:** Enhance dynamic visual feedback for in-flight transit capsules by inspecting liminal container inventories and rendering the dominant payload item icon directly over active capsule objects during movement ticks.
**Key Changes:**
1. **Multi-Layer Render Cleanup (`scripts/capsules/capsule-queries.lua`):** Refactored `clear_capsule_render()` to accept both standalone render IDs and array tables of `LuaRenderObject` handles, ensuring leak-free cleanup of multi-part visual objects on tick updates, arrival, and destruction events.
2. **Payload Inventory Inspection (`scripts/capsules/capsule-runner.lua`):** Added `get_dominant_item()` helper to inspect active liminal holder container inventories, prioritizing internal cargo stacks by highest item count over the vessel capsule shell.
3. **Dynamic Render Overlay & Sprite Framing (`scripts/capsules/capsule-runner.lua`):** Updated the tick rendering pipeline in `update_capsules()` to draw a gold ring border (`radius = 0.35`, `width = 2`) framing a scaled item sprite (`x_scale = 0.55`, `y_scale = 0.55`) of the dominant payload item, with fallback rendering for empty capsules when `is_debug_active("capsules")` is enabled.

### Revision: Pneumatic Technology Tree & Recipe Progression `[INCORPORATED IN TABLE]`
**Context:** Establish early-to-mid-game technology progression and rebalance crafting recipes for pneumatic transport infrastructure. Lock core mod items behind a dedicated research node and introduce explicit base craft times (`energy_required`).
**Key Changes:**
1. **Technology Prototype Definition (`prototypes/technology.lua`):** Created the `pneumatic-transport` research node at the Chemical (Blue) Science tier (350 cycles @ 45s), requiring `advanced-circuit`, `fluid-handling`, and `logistics-2`. Added recipe unlock effects for tubes, junctions, pumps, hubs, and transport capsules.
2. **Recipe Rebalancing & Research Gating (`prototypes/recipe.lua`):** Set `enabled = false` across all base mod recipes to mandate technology unlock gating. Rebalanced material costs (steel, plastic, engines, circuits) and assigned explicit `energy_required` values (1.0s to 3.5s) to eliminate default instant crafting.
3. **Data Lifecycle Integration (`data.lua`):** Required `prototypes/technology.lua` strictly within the prototype data stage in `data.lua`, preventing runtime `data` global table indexing errors in `control.lua`.

### Revision: Dynamic Pressure Drop-Off & Gradient-Scaled Capsule Velocity `[INCORPORATED IN TABLE]`
**Context:** Replace flat edge pressure loss and constant capsule travel velocity with dynamic pressure decay and pressure-gradient-proportional movement speed across the network graph.
**Key Changes:**
1. **Dynamic Pressure Decay Calculation (`scripts/networks/networks-pressure.lua`):** Replaced the static `PRESSURE_DROPOFF` constant with `calculate_dropoff()`, scaling resistive pressure loss at 10% of local line pressure per edge hop (with a floor minimum of 1). Integrated local drop-off calculation directly into step 2 of the multi-source BFS traversal.
2. **Pressure-Proportional Velocity Scaling (`scripts/capsules/capsule-runner.lua`):** Replaced fixed constant `SPEED_TILES_PER_SEC` with `calculate_segment_speed()`. Capsule travel velocity now scales non-linearly relative to the square root of the local pressure gradient ($\Delta P = |P_{\text{from}} - P_{\text{to}}|$), clamped safely within a 4 to 60 tiles/second envelope (baseline 15 tiles/sec).
3. **Mid-Tick Distance Recalibration (`scripts/capsules/capsule-runner.lua`):** Refactored `update_capsules()` movement execution to dynamically scale remaining per-tick distance (`tiles_this_tick`) whenever a capsule acquires a new destination node mid-tick, ensuring smooth speed transitions across varying pressure regions.

### Revision: Hub Settings Architecture, Circuit Signal Fixes & Receive Latch Toggle `[INCORPORATED IN TABLE]`
**Context:** Refactor circuit evaluation into `hub-settings.lua` to eliminate circular dependencies, fix `get_signal` API crashes when wire channels are disabled, enforce symmetrical GUI toggle synchronization, and expose a configurable receive lock toggle.
**Key Changes:**
1. **Settings Modularization & Signal Safeguards (`scripts/hubs/hub-settings.lua`):** Extracted state storage and permission evaluation (`can_send`, `can_receive`) out of `hub-manager.lua`. Updated `evaluate_circuit_condition` to safely validate active `defines.wire_connector_id` channels before calling `entity.get_signal()`, preventing nil parameter crashes when wire channels are toggled off.
2. **GUI Toggle State Synchronization (`scripts/hubs/hub-gui.lua`):** Implemented bidirectional state synchronization between manual enable switches and circuit network toggles. Enabling circuit control automatically checks the operational enable toggle, while disabling operation automatically turns off circuit mode.
3. **Receive Latch Toggle Integration (`scripts/hubs/hub-settings.lua`, `scripts/hubs/hub-gui.lua`, `scripts/hubs/hub-packing.lua`):** Added `use_receive_lock` (default `true`) to settings storage and introduced a dedicated GUI checkbox ("Lock send after receiving until empty"). Updated `evaluate_inventory()` in `hub-packing.lua` to check `use_receive_lock` before enforcing the dispatch lock on un-emptied hub inventories.

### Revision: Unpowered Pump Flow Culling & Vector Gating `[INCORPORATED IN TABLE]`
**Context:** Prevent unpowered pumps from acting as passive flow sinks that trap moving capsules on dead-end inlet paths or adjacent multi-port entity branches when pump power is disconnected.
**Key Changes:**
1. **Power State Evaluation (`scripts/networks/networks-flow.lua`):** Implemented an `is_pump_powered()` validation helper to check `storage.pump_power_states` for `pneumatic-pump` entities prior to hop construction.
2. **Internal Transfer Gating (`scripts/networks/networks-flow.lua`):** Restricted internal machine transfer hop generation across pump ports so unpowered pumps suppress internal transfers between inlet and outlet ports.
3. **External Vector Flow Gating (`scripts/networks/networks-flow.lua`):** Enforced power state validation on both source and destination entities during outbound hop calculation, preventing pressure-gradient vector creation into unpowered pump inlets.
4. **Dead-End Pruning Integration (`scripts/networks/networks-flow.lua`):** Suppressing unpowered pump hops allows `flow-cull.lua` to naturally identify and prune dead-end internal junction paths leading toward unpowered inlets.

### Revision: Specialized Transit Capsule Prototypes & Tech Tree Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-26 21:25 (EDT)
**Context:** Register item prototypes, crafting recipes, and technology research nodes for specialized transit capsule variants (biodegradable, refrigerated, reinforced, and player transit) ahead of runtime mechanics integration.
**Key Changes:**
1. **Capsule Variant Items (`prototypes/item.lua`):** Registered item prototypes for `biodegradable-capsule`, `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule` with stack size 1 and distinct order sub-keys (`a[capsule]-b[...]` through `e[...]`) under the `intermediate-product` subgroup.
2. **Variant Crafting Recipes (`prototypes/recipe.lua`):** Added recipe definitions for all four new capsule variants with `enabled = false` for tech unlock gating, establishing crafting times (1.0s to 5.0s) and ingredients matching tier progression.
3. **Technology Unlocks & Tree Expansion (`prototypes/technology.lua`):** Added `biodegradable-capsule` unlock directly to the baseline `pneumatic-transport` technology. Created the `specialized-pneumatic-capsules` technology node (prerequisite: `pneumatic-transport`, 250 cycles @ 30s) to unlock `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule`.

### Revision: Capsule Variant Mechanics, Player Transit & Emergency Ejection System `[INCORPORATED IN TABLE]`
**Date:** 2026-08-26 23:10 (EDT)
**Context:** Expand the pneumatic transport framework to support distinct capsule types (biodegradable, refrigerated, reinforced, player-transit), real-time passenger synchronization, emergency disembarkation, mid-transit structural failures, prototype bugfixes, and stub out non-functional refrigerated spoilage handling.
**Key Changes:**
1. **Capsule Definitions & Blueprint Expansion (`scripts/capsules/capsule-definitions.lua`):** Defined specs for `biodegradable-capsule`, `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule` specifying unique base capacities, stack rules, quality filters, spoilage modifiers, and spill risks.
2. **Player Transit & Arrival Disembarkation (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`):** Configured player transit dispatch to scan for nearby character entities (2.5 radius) prior to packing. Updated `hub-unpacking.lua` to safely disembark arriving passengers onto nearby non-colliding tiles (`find_non_colliding_position`).
3. **Custom Input Ejection System (`prototypes/custom-input.lua`, `scripts/capsules/capsule-inputs.lua`):** Added the `capsule-emergency-exit` prototype (`SHIFT + E`) in the data stage. Created a standalone input script registered through `events.on_event` to trigger ejection cleanly without placing logic directly in `control.lua`.
4. **Emergency Eject API & Module Export (`scripts/capsules/capsule-runner.lua`):** Added `capsule_runner.emergency_eject(player)` to ground passengers, destroy underlying liminal holder entities, remove visual tracking overlays, and unhook tracking state from `storage.capsules`. Exported `emergency_eject` in the module return table.
5. **Capsule Lifecycle Mechanics & Spoilage Stub (`scripts/capsules/capsule-runner.lua`, `scripts/hubs/hub-packing.lua`):** Added `update_capsule_lifecycle()` with active mid-flight spill evaluations (`spill_risk = 0.0008`) on biodegradable cargo, while stubbing out `spoilage_modifier` logic to prevent Factorio 2.0 engine queue conflicts. Configured `hub-packing.lua` to dissolve biodegradable capsule shells upon packing (`destroy_self = true`).
6. **Entity Prototype Crash Fix (`scripts/capsules/capsule-runner.lua`):** Replaced non-existent `"small-explosion"` entity strings with standard base-game `"explosion"` prototypes across emergency ejection and biodegradable structural failure handlers to resolve fatal runtime crashes.

### Revision: Refrigerated Capsule Spoilage Mitigation & Type-Safe Stack Refresh `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 07:58 (EDT)
**Context:** Implement engine-compatible spoilage mitigation for cargo inside refrigerated capsules by tracking real-time spoilage deltas and re-instantiating liminal holder item stacks without triggering Factorio C++ prototype indexing exceptions.
**Key Changes:**
1. **Delta Spoilage Tracking (`scripts/capsules/capsule-runner.lua`):** Added a 60-tick interleaved scanner in `update_capsule_lifecycle()` using `(game.tick + id) % 60 == 0`. Tracks per-slot previous spoil percentages in `capsule.slot_spoil_percents` to measure engine-applied spoilage ($\Delta s$) and apply scaled target freshness based on `def.spoilage_modifier`.
2. **Type-Guarded Stack Re-instantiation (`scripts/capsules/capsule-runner.lua`):** Resolved non-recoverable C++ engine errors (`"Item is not tool"`, `"Item is not ammo"`, `"Item is not item-with-tags"`) when rebuilding stacks via `set_stack()` by explicitly checking `stack.is_tool`, `stack.is_ammo`, and `stack.is_item_with_tags` before querying `.durability`, `.ammo`, `.custom_description`, or `.tags`.
3. **Metadata Preservation (`scripts/capsules/capsule-runner.lua`):** Guaranteed 100% state preservation across quality, stack size, health, durability, ammo, custom descriptions, and tags during liminal inventory slot refreshes.

### Revision: Pump Placement Flow Initialization & Multi-Port Power Broadcast Fix `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 08:41 (EDT)
**Context:** Fix delayed flow map updates on newly placed pumps and ensure power state toggles broadcast across both inlet and outlet networks over internal pump join boundaries.
**Key Changes:**
1. **Direct Energy Evaluation (`scripts/networks/networks-flow.lua`):** Updated `is_pump_powered()` to evaluate `entity.energy > 0` directly during flow vector hop generation, eliminating reliance on uninitialized or delayed `storage.pump_power_states` during initial placement validation.
2. **Multi-Port Power State Broadcast (`scripts/networks/pump-manager.lua`):** Refactored `check_pump_power_states()` to iterate over all registered entity ports via `port_defs.get_ports()` rather than querying hardcoded port index 1. This guarantees `networks_flow.build()` is invoked across both inlet and outlet sub-networks when pump power state toggles.

### Revision: Refrigerated Capsule Durability & Spent State Lifecycle `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 09:11 (EDT)
**Context:** Convert the refrigerated capsule to function as a durable tool item that consumes durability while actively preserving spoilable cargo and degrades into a spent capsule once depleted.
**Key Changes:**
1. **Capsule Tool Prototypes (`prototypes/item.lua` & `scripts/capsules/capsule-definitions.lua`):** Converted `refrigerated-capsule` from a standard item to a tool prototype with 1000 durability. Registered the `spent-refrigerated-capsule` prototype and definition (`spoilage_modifier = 1.0`, `spent_capsule_item`) to handle depleted container transitions.
2. **Spoilage Reduction & Durability Drain (`scripts/capsules/capsule-runner.lua`):** Implemented periodic spoilage mitigation in `update_capsule_lifecycle` for active cargo. Added tick-based durability reduction for cooling tools when preserving items, automatically replacing depleted tools with their spent variants in-place.

### Revision: Primary Capsule Slot Tracking & Refrigerated Spoilage Fix `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 09:40 (EDT)
**Context:** Eliminate cargo refrigerated capsule durability exploits, fix visual overlay item misclassifications, and establish explicit primary slot tracking within liminal holder inventories.
**Key Changes:**
1. **Primary Slot Registration & Helpers (`scripts/capsules/capsule-manager.lua`):** Updated `capsule_manager.register()` to store `primary_slot` within `storage.active_capsules[id]`. Implemented `get_primary_stack(capsule_id)` helper to safely retrieve the primary vessel stack and slot index from holder entity inventories.
2. **Primary Shell Placement & Packing (`scripts/hubs/hub-packing.lua`):** Adjusted packing logic to populate cargo items first and assign the primary capsule shell to a designated, tracked slot (`primary_holder_slot`) while preserving durability, ammo, quality, and custom tags.
3. **Targeted Durability Drain & Overlay Classification (`scripts/capsules/capsule-runner.lua`):** Refactored `update_capsule_lifecycle()` to deduct durability strictly from `phys_capsule.primary_slot`, preventing cargo capsules from being drained as secondary coolant sources. Updated `get_dominant_item()` to evaluate `i == cap_data.primary_slot` rather than item prototype definitions to reliably differentiate cargo items from outer vessel shells.

### Revision: Capsule Runner Modularization & Subsystem Decoupling `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 10:02 (EDT)  
**Context:** Refactor `capsule-runner.lua` into smaller, single-responsibility sub-modules to reduce single-file complexity (~550 lines) and streamline context bounds while preserving strict top-level `require` loading rules.
**Key Changes:**
1. **Capsule Motion Subsystem (`scripts/capsules/capsule-motion.lua`):** Extracted network graph node lookup, spatial position resolution (`get_port_world_pos`), segment speed calculations (`calculate_segment_speed`), entity-network capacity verification (`has_entity_network_capacity`), pressure-driven target selection (`select_next_target`), and hub arrival handling (`handle_arrival`).
2. **Capsule Lifecycle Engine (`scripts/capsules/capsule-lifecycle.lua`):** Isolated per-tick passenger teleportation syncing (`passenger.teleport`), 60-tick refrigerated spoilage modifier calculation (`spoilage_modifier`), and primary capsule shell durability consumption / spent variant conversion (`spent-refrigerated-capsule`).
3. **Capsule Debug Renderer (`scripts/capsules/capsule-renderer.lua`):** Separated dominant payload item evaluation (`get_dominant_item`) and visual debug overlay rendering (`render`) into a dedicated rendering module.
4. **Runner Orchestrator & Public API (`scripts/capsules/capsule-runner.lua`):** Streamlined the central module down to `on_tick` loop orchestration, hub injection (`inject_from_hub`), emergency passenger ejection (`emergency_eject`), and public query delegation while preserving top-level `require` dependencies.

### Revision: Mid-Transit Biodegradable Capsule Failure Evaluation `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 10:43 (EDT)  
**Context:** Resolve issue where biodegradable capsules never ruptured en-route by restoring the missing `spill_risk` evaluation in `capsule-lifecycle.lua`.
**Key Changes:**
1. **Mid-Transit Failure Roll (`scripts/capsules/capsule-lifecycle.lua`):** Restored the missing `def.spill_risk` probability roll inside `capsule_lifecycle.update()`, returning `true` upon structural failure to allow `capsule-runner.lua` to process the mid-transit rupture.
2. **Rupture & State Cleanup (`scripts/capsules/capsule-lifecycle.lua`):** Added top-level `require` for `capsule-queries` to destroy the liminal holder entity, clear visual render overlays, and unregister active capsule tracking state upon failure.

### Revision: Centralized Liminal Capsule Spilling & Ground Item Deconstruction `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 11:03 (EDT)
**Context:** Unify capsule payload spilling into a single master API hook across entity destruction and mid-transit structural failures, while resolving missing deconstruction orders on items spilled directly onto the ground.
**Key Changes:**
1. **Master Spill Hook & Force Resolution (`scripts/hubs/hub-spill.lua`):** Centralized liminal holder eviction, motion runner unregistration (`capsule_queries.remove_capsule`), render overlay cleanup, and explosion effects into `hub_spill.spill_capsule()`. Added fallback force evaluation (`force or holder.force or "player"`) to ensure mid-transit ruptures retain force ownership.
2. **Ground Item Deconstruction Marking (`scripts/hubs/hub-spill.lua`):** Implemented `spill_and_mark_stack` helper to iterate over `item-on-ground` entities returned by `surface.spill_item_stack` and explicitly invoke `order_deconstruction(force)` when `mark_for_deconstruction = true` is configured in `capsule-definitions.lua`.
3. **Mid-Transit Failure Decoupling (`scripts/capsules/capsule-lifecycle.lua`):** Removed duplicate inline item spilling logic (`execute_spill`) in favor of direct calls to `hub_spill.spill_capsule()`, preserving strict top-level module `require` loading rules.

### Revision: Passenger Emergency Eject Visual Overlay & Spatial Alignment `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 11:51 (EDT)
**Context:** Add a player-exclusive visual prompt for passenger transit capsules to inform active riders of the emergency eject keybind (`[Shift + E]`) without displaying to non-passengers or overlapping the capsule ring overlay.
**Key Changes:**
1. **Passenger-Exclusive Text Overlay (`scripts/capsules/capsule-renderer.lua`):** Added a `rendering.draw_text` render call inside `capsule_renderer.render` targeting `players = { capsule.passenger }` so the `"[Shift + E] Emergency Eject"` text is strictly rendered for the active rider.
2. **Static Target Coordinate Offsetting (`scripts/capsules/capsule-renderer.lua`):** Explicitly offset the target position table (`{ curr_pos.x, curr_pos.y + 0.8 }`) to bypass Factorio's rendering API limitation where `target_offset` is ignored on static map coordinates, positioning the prompt cleanly below the passenger capsule ring.

### Revision: Crossflow Junction Prototype & Visual Entity Tinting `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 12:15 (EDT)
**Context:** Implemented isolated two-way crossflow pipe routing via dual port grouping and applied distinct visual RGBA tints across all pneumatic network entity prototypes.
**Key Changes:**
1. **Entity Prototypes & Visual Tints (`prototypes/entity.lua`):** Applied RGBA layer tints to `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, and `junction` for entity distinction. Registered the `crossflow-junction` simple-entity prototype.
2. **Item & Recipe Registrations (`prototypes/item.lua`, `prototypes/recipe.lua`):** Created the `crossflow-junction` item prototype under the `storage` subgroup and added its recipe (4x pneumatic-tube, 4x steel-plate, 2x advanced-circuit).
3. **Tech Tree Integration (`prototypes/technology.lua`):** Added the `crossflow-junction` recipe unlock effect to the baseline `pneumatic-transport` technology.
4. **Dual-Group Port Definitions (`scripts/ports/port-definitions.lua`):** Configured `crossflow-junction` port topology with split group assignments (`group = 1` for vertical ports, `group = 2` for horizontal ports), ensuring automatic sub-network isolation across perpendicular directions.

### Revision: Crossflow Junction Port Evaluator & Multi-Group Flow Culling Fix `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 14:28 (EDT)  
**Context:** Resolve issue where crossflow junction horizontal ports failed to transmit pressure or build network merge links, while ensuring flow vector overlays on disconnected arms are properly pruned.
**Key Changes:**
1. **Cross-Entity Port Group Compatibility (`scripts/ports/port-evaluator.lua`):** Removed the `port_a.group ~= port_b.group` restriction from `port_evaluator.are_compatible()`. Group IDs represent entity-internal port set boundaries rather than external connection constraints, allowing secondary entity groups (`group = 2`) on crossflow junctions to merge cleanly with standard network tubes (`group = 1`).
2. **Multi-Group Entity Flow Culling (`scripts/networks/flow-cull.lua`):** Updated multi-port entity checks to evaluate total physical entity ports via `port_defs.get_ports(node.entity)` instead of counting local `flow_map` nodes. This ensures sub-network culling passes correctly identify dual-group 4-port entities, pruning dead-end outbound vector hops and clearing orphaned visual flow overlays.

### Revision: Gleba Bio-Capsule System, Integrity Tech Tree & Factorio 2.0 Compatibility `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 17:56 (EDT)
**Context:** Complete implementation of Gleba-tier biodegradable capsules, including weighted item slot capacities, researchable integrity upgrades for transit spill mitigation, tech tree relocation, and Factorio 2.0 schema compatibility fixes.
**Key Changes:**
1. **Recipe Schema & Gleba Crafting (`prototypes/recipe.lua`):** Configured `biodegradable-capsule` recipe output (1 Carbon Fiber + 2 Jelly + 4 Sulfuric Acid -> 4 Capsules @ 1.0s). Migrated to the Factorio 2.0 schema by replacing the deprecated single-string `category` with `categories = {"organic", "crafting-with-fluid"}`, enabling crafting in both Bio-Chambers and fluid-handling Assembling Machines.
2. **Bio-Capsule Integrity Research Tree (`prototypes/technology.lua`):** Removed `biodegradable-capsule` from baseline `pneumatic-transport` and placed it under `bio-capsule-integrity-1` (requiring `agricultural-science-pack`). Expanded the tree with 4 exponential research tiers (`bio-capsule-integrity-1` through `4`) scaling science counts at 250, 1,000, 4,000, and 16,000 units.
3. **Dynamic Cargo Weight & Slot Density (`scripts/capsules/capsule-definitions.lua` & `scripts/hubs/packing/cargo-planner.lua`):** Introduced `slot_costs` (`bio_item = 0.5`, `inorganic = 1.0`) on bio-capsules. Added a biological item registry (`BIO_ITEMS`) and slot cost evaluator in `cargo-planner.lua`, allowing bio-capsules to hold twice as many biological item stacks compared to inorganic metals.
4. **Tech-Gated Mid-Transit Spill Mitigation (`scripts/capsules/capsule-lifecycle.lua`):** Updated lifecycle updates to inspect force research progress. Mid-transit structural failure risk (baseline 0.0008) is dynamically reduced by 25% per researched integrity level (100% risk at L0 down to 0% total failure immunity at L4).

### Revision: Sub-Network Port Group Capacity Isolation `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 19:20 (EDT)
**Context:** Resolve capsule flow blocking across multi-group entities (such as crossflow junctions) caused by capacity queries evaluating occupancy purely by unit number and network ID rather than isolated internal port groups.
**Key Changes:**
1. **Port Group Lookup (`scripts/capsules/capsule-queries.lua`):** Implemented `capsule_queries.get_port_group(port_key)` to retrieve entity port group definitions (`group = 1` vs `group = 2`) from network metadata and `port-definitions.lua`.
2. **Group-Aware Occupancy Queries (`scripts/capsules/capsule-queries.lua`):** Refactored `get_capsule_count_at_entity_network` to accept a target port key or group ID, filtering `is_at_from` and `is_at_to` matches against the specific port group.
3. **Capacity Check Routing (`scripts/capsules/capsule-motion.lua`):** Updated `has_entity_network_capacity` to pass the target port key to `get_capsule_count_at_entity_network`, ensuring capacity checks independently evaluate orthogonal internal segments.

### Revision: Pneumatic Diverter Entity, Recipe & 4-Port Topology Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 19:54 (EDT)
**Context:** Implement the 3x3 Pneumatic Diverter prototype, item registration, crafting recipe, tech unlock, and 4-port definition to enable multi-directional capsule routing across pneumatic transport networks.
**Key Changes:**
1. **Diverter Entity Prototype (`prototypes/entity.lua`):** Added the 3x3 `pneumatic-diverter` prototype using an `electric-energy-interface` base with tinted assembling machine graphics, 50kW continuous power draw, and a 10kJ energy buffer.
2. **Item Prototype (`prototypes/item.lua`):** Registered the `pneumatic-diverter` item in the `storage` subgroup with stack size 10 and standard `place_result`.
3. **Crafting Recipe (`prototypes/recipe.lua`):** Added the crafting recipe for `pneumatic-diverter` (1x junction, 6x steel plate, 4x advanced circuit, 2x electric engine unit; 3.0s crafting time) set to `enabled = false`.
4. **Technology Unlock (`prototypes/technology.lua`):** Added the `pneumatic-diverter` unlock effect directly to the baseline `pneumatic-transport` technology node.
5. **4-Port Connection Definitions (`scripts/ports/port-definitions.lua`):** Configured 4-port cardinal routing entries for `pneumatic-diverter` with merge connections centered along entity boundaries (offset 1.5 tiles from origin).

### Revision: Composite Diverter Entity Architecture & Synchronous GUI Interception `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 22:45 (EDT)  
**Context:** Establish an operable physical energy entity paired with a hidden circuit network proxy for the pneumatic diverter, enabling circuit terminal capability and synchronous left-click UI hijacking while suppressing vanilla energy interface window rendering.
**Key Changes:**
1. **Composite Entity Prototype (`prototypes/pneumatic-diverter.lua`):** Cloned `constant-combinator` to construct the `pneumatic-diverter-circuit-proxy` prototype configured with `"not-selectable-in-game"`, `"not-deconstructable"`, `"hide-alt-info"`, and `minable = nil`. Defined the main `pneumatic-diverter` physical entity as an `electric-energy-interface` (50kW usage, 10kJ buffer) using assembling-machine-2 visual assets and `gui_mode = "all"` to capture player open interactions.
2. **Proxy Lifecycle & GUI Interception (`prototypes/pneumatic-diverter-proxy-linkage.lua`):** Implemented lifecycle event listeners (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive`) to automatically spawn non-operable, indestructible circuit proxies paired to diverter positions, as well as removal listeners (`on_player_mined_entity`, `on_entity_died`, etc.) for proxy cleanup. Added `on_gui_opened` handler to synchronously set `player.opened = nil`, suppressing the native energy interface GUI on the exact tick it is clicked to prepare for custom Lua frame rendering.

### Revision: Pneumatic Diverter Proxy Lifecycle & GUI Event Wiring Parity `[INCORPORATED IN TABLE]`
**Date:** 2026-08-27 23:05 (EDT)
**Context:** Resolve game UI interference, proxy lifecycle desync, and event dispatch collisions on the Pneumatic Diverter by standardizing event registration loops, adding GUI type isolation guards, and syncing proxy orientation.
**Key Changes:**
1. **Event Registration Loop Parity (`prototypes/pneumatic-diverter-proxy-linkage.lua`):** Refactored build, destruction, and rotation hooks to iterate over event ID tables via explicit `for _, id in ipairs(...)` loops, matching subsystem dispatcher patterns in `pump-manager.lua` and `hub-manager.lua` to prevent lookup collisions in `events.lua`.
2. **Defensive Entity & GUI Type Isolation (`prototypes/pneumatic-diverter-proxy-linkage.lua`):** Implemented defensive `if not (entity and entity.valid)` checks across all listener callbacks and gated `on_gui_opened` strictly behind `event.gui_type == defines.gui_type.entity`, preventing `player.opened = nil` from closing unrelated player inventory screens or custom UI frames.
3. **Proxy Creation Deduplication & Rotation Sync (`prototypes/pneumatic-diverter-proxy-linkage.lua`):** Added `#existing == 0` spatial filter check on creation to prevent duplicate proxy stacking, enforced `proxy.valid` verification prior to destruction, and registered `on_player_rotated_entity` / `on_player_flipped_entity` listeners to sync proxy direction with the parent diverter structure.

### Revision: Pneumatic Diverter GUI, Settings Storage & Control Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 10:10 (EDT)
**Context:** Add initial implementation for Pneumatic Diverter port configuration by creating dedicated settings management, a 2x2 grid UI with vanilla-style switch labeling and item filter selection, and requiring both new modules in `control.lua`.
**Key Changes:**
1. **Diverter State Persistence (`scripts/diverter-settings.lua`):** Added new module creating unit-indexed `storage.diverter_settings` to track per-port enabled states, flow modes (`input`/`output`), filter toggles, filter modes (`whitelist`/`blacklist`), and 5 item filter slots per directional port (North, East, South, West).
2. **Configuration GUI & Switch Formatting (`scripts/diverter-gui.lua`):** Created new overlay frame featuring a 2x2 grid of port control cards. Implemented vanilla-styled toggle switches with rich-text active color highlighting (`Pull (Input)` vs `Push (Output)` and `Whitelist` vs `Blacklist`), dynamic caption state updates on toggle, and 5 item picker buttons (`elem_type = "item"`) paired with micro-comparator dropdowns (`=`, `≥`, `≤`, `>`, `<`, `≠`).
3. **Control Integration (`control.lua`):** Updated main script to `require` both `scripts/diverter-settings` and `scripts/diverter-gui` modules, wiring diverter settings management and GUI lifecycle event handlers into the mod runtime.

### Revision: Pneumatic Diverter Baseline Manager & Static Port Definitions `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 11:23 (EDT)
**Context:** Lay the groundwork for dynamic diverter settings integration by creating a dedicated runtime diverter manager and establishing static 4-port pump-style baseline definitions to test network isolation and power sensitivity.
**Key Changes:**
1. **Diverter Runtime State Tracking (`scripts/networks/diverter-manager.lua`):** Created a dedicated manager module monitoring active diverter entity power states (`storage.active_diverters` and `storage.diverter_power_states`) via a 15-tick periodic scanner. Added `notify_settings_changed` API to trigger targeted flow map rebuilds (`networks_flow.build`) when runtime settings update.
2. **Main Script Wiring & Storage Initialization (`control.lua`):** Added top-level require for `scripts/networks/diverter-manager` and initialized `storage.active_diverters` and `storage.diverter_power_states` inside `setup_storage()`.
3. **Baseline Diverter Port Definitions (`scripts/ports/port-definitions.lua`):** Updated `pneumatic-diverter` port definitions across all cardinal orientations to use `join` connection types with static baseline pressure levels (-100 for inflows, +100 for outflows), enabling 4-way pressure boundary isolation and power reactivity testing.

### Revision: Diverter GUI Persistence & Immediate Network Flow Rebuild Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 11:40 (EDT)
**Context:** Connect diverter GUI control elements directly to persistent runtime storage (`storage.diverter_settings`) and trigger instant network flow map recalculations whenever port states, flow directions, or filter settings are modified.
**Key Changes:**
1. **Settings Schema Alignment (`scripts/diverter-settings.lua`):** Standardized default filter slot structure keys to `item` (matching the `choose-elem-button` item element picker format).
2. **UI State Persistence (`scripts/diverter-gui.lua`):** Connected all GUI interaction listeners (`on_gui_checked_state_changed`, `on_gui_switch_state_changed`, `on_gui_elem_changed`, and `on_gui_selection_state_changed`) to update persistent port state configurations in `storage.diverter_settings`.
3. **Runtime Network Rebuild Trigger (`scripts/diverter-gui.lua`):** Added `notify_change()` helper to GUI event callbacks to invoke `diverter_manager.notify_settings_changed(entity)`. This immediately triggers `networks_flow.build(net_id)` for all connected pipe networks to update directional flow vectors upon UI configuration changes.

### Revision: Dynamic Diverter Settings & Port Evaluation Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 12:00 (EDT)
**Context:** Bridge persistent diverter settings (`storage.diverter_settings`) into runtime port evaluation and network flow calculations, allowing port toggles (enabled/disabled state) and directional modes (Pull vs Push) to dynamically control pressure network topology and flow vectors.
**Key Changes:**
1. **Dynamic Diverter Port Resolution (`scripts/ports/port-definitions.lua`):** Updated `get_ports()` to read `storage.diverter_settings` for `pneumatic-diverter` entities at runtime, dynamically assigning port enabled states (`enabled`), flow directions (`"in"` vs `"out"` vs `"none"`), and pressure deltas (`-100` vs `+100`).
2. **Disabled Port Invalidation (`scripts/ports/port-evaluator.lua`):** Added explicit enable state checks to `port_evaluator.are_compatible()`, treating toggled-off ports (`enabled = false`) as closed/inactive to block network connections.
3. **Flow Engine & Power Sensitivity (`scripts/networks/networks-flow.lua`):** Expanded `is_powered()` check to include `pneumatic-diverter` entities (`entity.energy > 0`) and guarded outbound vector hop creation with port `enabled` checks to prune inactive ports from flow maps.

### Revision: Diverter Port Filter Evaluation & Hop Selection `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 12:15 (EDT)
**Context:** Enforce diverter port whitelist and blacklist filter rules during runtime capsule motion, preventing non-matching payload items from routing through restricted outbound ports.
**Key Changes:**
1. **Diverter Filter Storage Standardization (`scripts/diverter-settings.lua`):** Updated default filter slot configuration keys from `signal` to `item` inside `diverter_settings.get()` to align storage structure with GUI item picker element keys.
2. **Filter Logic & Operator Evaluation (`scripts/capsules/capsule-motion.lua`):** Implemented port filter evaluation functions (`evaluate_filter_slot`, `evaluates_port_filter`, `check_diverter_port_filter`, `is_hop_allowed_by_diverter_filters`) that inspect payload contents via `capsule_renderer.get_dominant_item` and evaluate comparison operators across whitelist and blacklist modes.
3. **Outbound Hop Selection Pruning (`scripts/capsules/capsule-motion.lua`):** Integrated filter checks directly into `select_next_target`, preventing capsules from selecting candidate or backtrack outbound hops if either the origin or destination diverter port filters reject the payload item.

### Revision: Ag Science Progression & Entity-Item Tint Harmonization `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 13:05 (EDT)
**Context:** Update bio-capsule technology progression to incorporate Space Age science packs while resolving invalid icon file references and harmonizing inventory icon tints 1:1 with world entity graphics.
**Key Changes:**
1. **Technology Tree Progression (`prototypes/technology.lua`):** Integrated `agricultural-science-pack` into `bio-capsule-integrity-2` and `bio-capsule-integrity-3`, and `cryogenic-science-pack` into `bio-capsule-integrity-4`, updating prerequisite dependencies accordingly.
2. **Item Icon Restoration & Multi-Layer Tinting (`prototypes/item.lua`):** Fixed invalid icon paths by restoring base game and Space Age fallback sprite assets (`iron-plate`, `wood`, `ice`, `steel-plate`, `car`, `steel-chest`, `pipe`, `pump`, `iron-chest`, `assembling-machine-2`). Converted single `icon` paths to tinted `icons` layer tables while preserving original stack sizes, subgroups, order keys, and tool durability.
3. **Entity and Inventory Color Synchronization (`prototypes/item.lua`):** Matched item icon palette tints directly to the entity RGB values used across horizontal/vertical hubs, tubes, pumps, junctions, crossflow junctions, and diverters.
4. **Diverter Entity Graphics Tinting (`prototypes/pneumatic-diverter.lua`):** Deepcopied the cloned `assembling-machine-2` animation layers for `pneumatic-diverter` and applied the emerald tint (`{r = 0.25, g = 0.80, b = 0.60, a = 1.0}`) exclusively to non-shadow layers (`not layer.draw_as_shadow`).

### Revision: Complete Mod Localization & Factoriopedia Coverage `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 13:10 (EDT)
**Context:** Implement complete English localization strings across all items, entities, transit capsule variants, and research technologies within the pneumatic transport ecosystem.
**Key Changes:**
1. **Infrastructure Entities & Items (`locale/en/config.cfg`):** Registered display names and descriptive tooltips under `[entity-name]`, `[entity-description]`, `[item-name]`, and `[item-description]` for `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, and `pneumatic-diverter`.
2. **Transit Capsule Variants (`locale/en/config.cfg`):** Added localizations covering the full capsule lineup (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule`), ensuring proper Factoriopedia and inventory display.
3. **Technology Tree Localizations (`locale/en/config.cfg`):** Created `[technology-name]` and `[technology-description]` entries for `pneumatic-transport`, `specialized-pneumatic-capsules`, and `bio-capsule-integrity-1` through `4`.

### Revision: Release Packaging, Version Graduation & Space Age Dependency `[INCORPORATED IN TABLE]`
**Date:** 2026-08-28 13:11 (EDT)
**Context:** Prepare mod archive for public release on the Factorio Mod Portal by graduating project versioning to 0.1.0, establishing required expansion dependencies, and adding engine release artifacts.
**Key Changes:**
1. **Mod Metadata Manifest (`info.json`):** Graduated mod version from `0.0.1` to `0.1.0`. Updated engine requirements to `base >= 2.1.0`, set a hard dependency for `space-age >= 2.1.0` to enforce expansion feature requirements, and retained `? quality` as an optional integration.
2. **Engine Changelog (`changelog.txt`):** Created standard Factorio-formatted release log detailing initial public testing feature set for version 0.1.0.

### Revision: Dedicated Inventory Group & Technology Localization Fixes `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 10:27 (EDT)
**Context:** Added a dedicated inventory tab for pneumatic infrastructure and capsules to clear GUI clutter, and resolved tech tree localization rendering issues for multi-tier bio-capsule research nodes.
**Key Changes:**
1. **Custom Inventory Tab & Subgroups (`prototypes/item.lua`):** Registered a new `item-group` (`pneumatics`) alongside two `item-subgroup` rows (`pneumatic-transport` and `pneumatic-capsules`). Reassigned all structure entities and capsule vessel items to these subgroups, moving pneumatic content out of vanilla Logistics/Intermediates into its own dedicated UI tab.
2. **Item Group Localization (`locale/en/config.cfg`):** Added `[item-group-name]` category containing `pneumatics=Pneumatic Transport` to properly render the tab tooltip name in player inventories.
3. **Technology Level Localization Fix (`locale/en/config.cfg`):** Resolved the `Unknown key` error and literal `__1__` formatting bugs by standardizing `bio-capsule-integrity` as the base key under `[technology-name]`. This allows Factorio's locale engine to handle dynamic level appending automatically while rendering the matching `[technology-description]` string across all four tiers.

### Revision: Alt Mode Visual Overlay for Flow Maps `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 10:41 (EDT)
**Context:** Integrate pneumatic network flow vectors and pressure text displays directly into Factorio's native Alt Mode toggle (`only_in_alt_mode = true`), enabling flow map visibility by default without requiring manual console command invocation.
**Key Changes:**
1. **Alt Mode Rendering Flags (`scripts/networks/networks-flow-renderer.lua`):** Applied `only_in_alt_mode = true` to both `rendering.draw_text` (pressure labels) and `rendering.draw_line` (directional flow vectors), allowing the game engine to automatically toggle flow map overlays when the player toggles Alt Mode.
2. **Default Flow State (`scripts/debug-manager.lua`):** Updated default state for `storage.debug.flow` from `false` to `true` so flow visualization is active by default in Alt Mode. Updated `/toggle-flow` console command descriptions and chat messages to reflect Alt Mode overlay functionality.
3. **Main Script Wiring (`control.lua`):** Required `scripts/networks/networks-flow` at top level and added `networks_flow.draw_all()` call inside `setup_storage()` to render existing flow maps across subgraphs on world initialization or mod configuration changes.

### Revision: Per-Player Debug State & Visual Overlay Isolation `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 10:57 (EDT)
**Context:** Refactor centralized debug commands and visual rendering overlays to operate on a per-player basis, ensuring debug states, prints, and visual indicators (port markers, flow vectors, and capsule sprites) are scoped to individual players without cross-contaminating multiplayer sessions.
**Key Changes:**
1. **Per-Player Storage Schema (`scripts/debug-manager.lua`):** Restructured `storage.debug` to index feature flags (`master`, `ports`, `flow`, `capsules`, `prints`) by `player_index`. Updated `/toggle-*` console commands to target the executing player (`command.player_index`) and adapted `is_debug_active()` and `debug_print()` to accept optional target player arguments.
2. **Scoped Port Overlay Renderer (`scripts/ports/port-renderer.lua`):** Updated `storage.port_render_objects` to track circle render handles per `player_index`. Applied `players = { player }` filtering to `rendering.draw_circle` calls and updated `draw_all()` / `clear_all()` handlers to clear and redraw per player.
3. **Scoped Network Flow Overlay Renderer (`scripts/networks/networks-flow-renderer.lua`):** Updated storage handle table to `storage.flow_render_ids[player_index][net_id]`. Added `players = { player }` scope targeting to pressure text and flow vector line render calls, allowing Alt Mode overlays to render strictly for players with active debug flags.
4. **Scoped Capsule Overlay Renderer (`scripts/capsules/capsule-renderer.lua`):** Updated `capsule_renderer.render()` to iterate active game players, evaluating per-player debug feature checks and appending `players = { player }` constraints to gold ring borders, item sprites, and position dots.

### Revision: Dynamic Pneumatic Diverter Circuit Control Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 11:21 (EDT)
**Context:** Implement circuit network signal evaluation for pneumatic diverter ports via paired proxy constant combinators, updating port flow vectors dynamically and adding circuit condition controls to the diverter GUI.
**Key Changes:**
1. **Circuit Signal Evaluation (`scripts/diverter-settings.lua`):** Implemented signal querying against `pneumatic-diverter-circuit-proxy` entities across configurable red/green wire connectors. Added logic to evaluate comparison operators (`=`, `≥`, `≤`, `>`, `<`, `≠`) against target signal values to resolve dynamic port enable/disable states.
2. **Dynamic Port Flow & Pressure Allocation (`scripts/ports/port-definitions.lua`):** Refactored `port_defs.get_ports()` for diverter entities to resolve runtime settings. Dynamically sets port flow (`in`/`out`/`none`) and applies pressure modifiers (-100 for input, 100 for output) based on circuit conditions and manual overrides.
3. **State Change Detection & Polling (`scripts/networks/diverter-manager.lua`):** Added a 15-tick periodic scanner tracking active diverters. Caches per-port enable states and power conditions, triggering `networks_flow.build()` rebuilds whenever circuit condition thresholds or entity power states toggle.
4. **GUI Circuit Integration (`scripts/diverter-gui.lua`):** Updated the existing configuration GUI and event handlers to expose circuit settings—adding red/green wire channel toggles, signal selectors, comparator dropdowns, constant text fields, and real-time settings synchronization.

### Revision: Dynamic Hub Port Rerouting & Internal Hop Filtering `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 12:06 (EDT)
**Context:** Resolve hub port trapping and internal movement loops by dynamically re-evaluating hub exit ports upon flow reinstatement and excluding internal hub ports from candidate motion targets.
**Key Changes:**
1. **Hub Exit Port Resolution (`scripts/capsules/capsule-motion.lua`):** Implemented `find_best_hub_outbound_port()` to dynamically scan all ports of a hub entity for active outbound flow vectors, downstream capacity (`has_entity_network_capacity`), diverter filter compliance (`is_hop_allowed_by_diverter_filters`), and pressure drops.
2. **Parked Capsule Rerouting (`scripts/capsules/capsule-motion.lua`):** Updated `select_next_target()` for stationary capsules (`to_port_key == nil`) parked at hub entities, automatically updating `from_port_key` to whichever port acquires active flow when network state updates.
3. **Internal Hub Hop Exclusion & Pump Pressure Fix (`scripts/capsules/capsule-motion.lua`):** Filtered out internal ports of the same hub entity (`target_unit == entity.unit_number`) from candidate target selection to prevent internal hub bouncing. Restricted the `drop = math.huge` internal hop pressure override strictly to `pneumatic-pump` entities.
4. **Unified Dispatch Port Selection (`scripts/capsules/capsule-runner.lua`):** Refactored `inject_from_hub()` to utilize `find_best_hub_outbound_port()`, ensuring newly packed capsules select capacity-cleared and filter-valid exit ports at injection time.

### Revision: Pneumatic Pump Circuit Proxy & Lifecycle Linkage Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 12:24 (EDT)
**Context:** Add circuit network proxy constant combinators to pneumatic pumps to enable circuit wire attachment and lifecycle tracking, mirroring the pneumatic diverter proxy architecture.
**Key Changes:**
1. **Pump Circuit Proxy Prototype (`prototypes/pneumatic-pump-proxy.lua`):** Registered `pneumatic-pump-circuit-proxy` cloned from `constant-combinator` with matching pump icon, 0 collision/selection boxes, and hidden, non-selectable entity flags.
2. **Proxy Lifecycle Linkage (`prototypes/pneumatic-pump-proxy-linkage.lua`):** Implemented lifecycle event listeners for build, rotation, and destruction of `pneumatic-pump` entities to automatically spawn, align orientation, and clean up proxy entities.
3. **Data & Runtime Wiring (`data.lua` & `control.lua`):** Required `prototypes.pneumatic-pump-proxy` in `data.lua` and `prototypes.pneumatic-pump-proxy-linkage` in `control.lua` at top-level to integrate pump circuit proxies into mod startup and runtime execution.

### Revision: Pneumatic Pump GUI, Settings Storage & Control Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 13:37 (EDT)
**Context:** Add initial implementation for Pneumatic Pump configuration by creating dedicated settings storage, an interactive configuration overlay GUI with manual toggles and circuit condition rules, and hooking entity GUI opening events.
**Key Changes:**
1. **Pump Settings Storage (`scripts/pump-settings.lua`):** Created dedicated settings module creating unit-indexed `storage.pump_settings` to track manual enable states (`enabled`), circuit enable toggles (`use_circuit_enable`), comparator conditions (`enable_condition`), circuit signal evaluations (`evaluate_circuit_condition`), and red/green wire channel toggles (`read_red`, `read_green`).
2. **Configuration GUI (`scripts/pump-gui.lua`):** Created configuration overlay frame (`pump_configuration_frame`) featuring global wire channel checkboxes, master enable toggle, circuit enable toggle, signal picker button (`elem_type = "signal"`), operator dropdown (`=`, `≥`, `≤`, `>`, `<`, `≠`), and numeric constant textfield. Connected all GUI interaction handlers to update persistent `storage.pump_settings` in real time.
3. **Proxy Open Event Linkage (`prototypes/pneumatic-pump-proxy-linkage.lua`):** Added `defines.events.on_gui_opened` listener for `pneumatic-pump` entities to launch `pump_gui.open(player, entity)` when players open a pump.
4. **Control Integration & Storage Initialization (`control.lua`):** Required `scripts/pump-settings` and `scripts/pump-gui` at top level and initialized `storage.pump_settings` inside `setup_storage()`.

### Revision: Pneumatic Pump Circuit & GUI Dynamic Flow Rebuild Integration `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 13:57 (EDT)
**Context:** Harmonize pneumatic pump runtime updates with pneumatic diverter behavior by linking manual GUI settings and circuit condition evaluations directly to dynamic port resolutions and immediate network flow map recalculations.
**Key Changes:**
1. **Dynamic Pump Port Resolution (`scripts/ports/port-definitions.lua`):** Updated `port_defs.get_ports()` for `pneumatic-pump` entities to dynamically evaluate `pump_settings.is_pump_enabled(entity)` at runtime, assigning port enabled states (`enabled`), directional flows (`"in"`/`"out"` vs `"none"`), and pressure levels (`-100`/`100` vs `nil`).
2. **Pump Manager State Scanner & Rebuild API (`scripts/networks/pump-manager.lua`):** Implemented `pump_manager.notify_settings_changed(entity)` to trigger targeted flow map recalculations (`networks_flow.build`). Expanded the 15-tick scanner to poll both power availability (`storage.pump_power_states`) and circuit/manual enable states (`storage.pump_enabled_states`).
3. **GUI Real-Time Flow Synchronization (`scripts/pump-gui.lua`):** Wired `pump_manager.notify_settings_changed()` into all configuration GUI event handlers (`on_gui_checked_state_changed`, `on_gui_elem_changed`, `on_gui_selection_state_changed`, `on_gui_text_changed`) via a `notify_change()` helper to trigger immediate network flow updates upon user interaction.