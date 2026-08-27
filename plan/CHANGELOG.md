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