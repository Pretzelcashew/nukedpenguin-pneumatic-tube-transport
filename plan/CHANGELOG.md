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





#### 0.1.4 outgoing

### Revision: Dynamic Liminal Holder Inventory Capacity & Prototype Expansion `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 14:52 (EDT)
**Context:** Expand liminal surface container cargohold limits and implement dynamic runtime inventory bar bounds to accommodate high-capacity or quality-scaled transit capsules without cargo truncation or container slot overflow.
**Key Changes:**
1. **Holder Prototype Capacity Expansion (`prototypes/entity.lua`):** Increased `inventory_size` from 10 to 255 for both `invisible-capsule-holder` and `visible-capsule-holder` container prototypes, establishing sufficient prototype storage headroom for quality scaling and high-tier specialized capsules.
2. **Dynamic Inventory Bar Sizing (`scripts/hubs/hub-packing.lua`):** Implemented runtime inventory bar setting (`dest_inv.set_bar(...)`) during holder entity instantiation on `liminal_surface`. Dynamically clamps active holder slots to `math.max(total_capacity, self_slot_cost)` for each capsule instance, locking unused slots and scoping primary shell slot allocation searches to active slots (`get_bar() - 1`).
3. **Bounded Unpacking Traversals (`scripts/hubs/hub-unpacking.lua`):** Refactored payload space evaluation (`can_insert_all`) and item capture (`capture`) routines to restrict holder inventory loops to active slots bounded by `get_bar() - 1`, optimizing unpacking performance and preventing unnecessary slot scans across empty container indices.


### Revision: Spilled Capsule Container Capacity & Anti-Exploit Bar Enforcement `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 16:50 (EDT)
**Context:** Enable spilled capsule containers to hold variable-sized cargo payloads without truncation while preventing players from exploiting spilled container entities as free large-capacity storage chests.
**Key Changes:**
1. **Container Prototype Bar Support (`prototypes/entity.lua`):** Updated `inventory_type` from `"with_filters"` to `"with_bar"` on the `visible-capsule-holder` prototype, activating engine-level inventory limiter bar controls (`LuaInventory.supports_bar() == true`) across its 255-slot inventory size.
2. **0-Tick Anti-Exploit Bar Enforcement (`scripts/hubs/hub-spill.lua`):** Implemented a 60Hz `on_tick` scanner and instant GUI listeners (`on_gui_opened`, `on_gui_closed`) tracking `storage.spilled_containers`. Immediately re-enforces `set_bar(1)` on the exact tick if a player attempts to drag open the inventory bar limit, red-locking all slots against item insertion while permitting item extraction.
3. **Automatic Empty Container Cleanup (`scripts/hubs/hub-spill.lua`):** Configured instant container self-destruction (`entity.destroy()`) the exact tick all spilled items are extracted (`container_inv.is_empty()`), preventing empty holder entities from lingering on the surface.


### Revision: Grid-Spaced Liminal Surface Spawning & Position Recycling `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 19:13 (EDT)
**Context:** Implement an 8-tile grid position allocation engine with slot recycling on `liminal_surface` and synchronous chunk generation to eliminate container spawn failures during rapid dispatches and enable unambiguous proximity detection for units spawned from spoiled items.
**Key Changes:**
1. **Grid Allocation & Recycling Engine (`scripts/surfaces/liminal-surface.lua`):** Implemented `allocate_position()` and `release_position()` managing `storage.liminal_grid` free slot stacks (`free_slots`). Configured 8-tile spacing (`GRID_SPACING = 8`) to isolate container cells for spoilage proximity queries (`find_holder_near`, radius `3.5`) while compactly fitting 16 cells per chunk.
2. **Synchronous Chunk Generation (`scripts/surfaces/liminal-surface.lua` & `scripts/hubs/hub-packing.lua`):** Introduced `ensure_chunk_at()`, calling `request_to_generate_chunks` and `force_generate_chunk_requests()` prior to `create_entity()` to guarantee target chunks exist on the current tick. Updated `map_gen_settings` (`width = 0, height = 0`) for unconstrained grid terrain expansion.
3. **Centralized Position Lifecycle & Storage Sync (`scripts/capsules/capsule-manager.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/capsules/capsule-runner.lua`, `control.lua`):** Stored `position` metadata in `storage.active_capsules` and funneled holder removals through `capsule_manager.remove()` to automatically recycle grid positions. Initialized grid storage in `control.lua` (`setup_storage`) and enforced top-level module imports.


### Revision: Liminal Holder Debug Selectability & Spoiled Unit Cross-Surface Re-instantiation `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 20:10 (EDT)
**Context:** Enable container selectability of liminal holders for in-game debugging and implement cross-surface unit re-instantiation for items spoiling inside transit capsules to mirror their location while preserving Quality and Health decay.
**Key Changes:**
1. **Liminal Holder Debug Selectability (`prototypes/entity.lua`):** Removed `"not-selectable-in-game"` flag, set `operable = true`, and assigned `selection_box = {{-0.5, -0.5}, {0.5, 0.5}}` on the `invisible-capsule-holder` container prototype, enabling debug selection and inventory inspection.
2. **Transit Capsule Location Resolver (`scripts/capsules/capsule-runner.lua`):** Implemented `capsule_runner.get_capsule_location(capsule_id)` to dynamically calculate the physical surface coordinates and surface handles of in-transit or parked capsules.
3. **Spoiled Unit Cross-Surface Re-instantiation (`scripts/capsules/capsule-runner.lua`):** Implemented `handle_liminal_entity_spawn()` and a 60-tick periodic scanner intercepting entities created on `liminal_surface`. Resolves parent container cells (`find_holder_near`, radius `3.5`) and checks primary capsule unit permissions (`spill_contents.units ~= false`). Bypasses Factorio engine cross-surface teleport limits by re-instantiating units on the physical target surface—preserving Factorio 2.0 `quality` and decayed `health`—before destroying the liminal unit entity.
4. **Cyclic Dependency Elimination (`scripts/surfaces/liminal-surface.lua` & `scripts/capsules/capsule-runner.lua`):** Decoupled startup initialization between `liminal-surface.lua` and `capsule-manager.lua` by consolidating spoilage event handling directly into `capsule-runner.lua`, preventing load-time dependency cycles.


### Revision: Parked Capsule Simulation Throttling, Instant Wakeup & Pathfinding Regex Elimination `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 21:00 (EDT)
**Context:** Eliminate 60Hz simulation and pathfinding loops for parked transit capsules waiting on full hub inventories or constrained network segments, reducing CPU overhead during backpressure bottlenecks while preserving instant transit dispatches.
**Key Changes:**
1. **Parked Capsule Retry Throttling (`scripts/capsules/capsule-runner.lua`):** Implemented a 10-tick retry interval (`PARKED_RETRY_INTERVAL = 10`) for stationary capsules (`to_port_key == nil`), deferring heavy inventory insertion simulations (`can_insert_all`) and outbound hop searches (`select_next_target`) while maintaining 60Hz passenger positioning, spoilage lifecycle updates, and visual overlays.
2. **Instant Event-Driven Wakeup Engine (`scripts/capsules/capsule-runner.lua`):** Implemented `capsule_runner.wake_parked_capsules()` to clear `next_retry_tick` across parked capsules upon item disembarkation, capsule injection, removal, or mid-transit rupture events, guaranteeing instant queue advancement when downstream space opens.
3. **Pattern Matching & Regex Elimination (`scripts/capsules/capsule-motion.lua`):** Replaced regex pattern splitting (`:match("^(%d+):(%d+)$")` and `:match("^(%d+)")`) with `get_unit_number()`, leveraging pre-cached flow map node metadata (`unit_number`, `port_index`) and plain substring slicing (`string.find`/`string.sub`) to eliminate tick-by-tick allocation overhead.
4. **Fast-Path Inventory Space Evaluation (`scripts/hubs/hub-unpacking.lua`):** Added an O(1) empty container evaluation path in `can_insert_all()`, comparing total required item stacks directly against usable chest capacity for filterless hub containers to bypass slot-by-slot inventory iterations.


### Revision: Persistent Render Object Caching & In-Place Position Updates `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 21:29 (EDT)
**Context:** Eliminate 60Hz C++ LuaRenderObject frame-by-frame destruction and recreation overhead for active and parked transit capsules, eliminating Lua-to-C++ bridge thrashing and UPS lockup during stalled backpressure bottlenecks while preserving real-time visual accuracy.
**Key Changes:**
1. **Render Object Caching Engine (`scripts/capsules/capsule-renderer.lua`):** Implemented a 3-state render evaluation state machine (`render_cache`) tracking `surface_index`, position coordinates (`pos_x`, `pos_y`), `passenger_index`, active debug player flags (`debug_key`), `dominant_item`, and render target offsets.
2. **Stationary Capsule NO-OP & In-Place Vector Updates (`scripts/capsules/capsule-renderer.lua`):** Configured immediate early-return (NO-OP) execution for stationary/parked capsules when position and state remain unchanged frame-to-frame. Implemented in-place `render_obj.target` vector updates for moving capsules to reuse existing C++ render handles without object destruction or re-allocation.
3. **Lazy Dominant Item Evaluation & Unified Cache Lifetime (`scripts/capsules/capsule-renderer.lua`, `scripts/capsules/capsule-queries.lua`, `scripts/capsules/capsule-runner.lua`):** Deferred holder inventory scanning (`get_dominant_item`) to execute only when capsule debug overlays are active without a passenger. Updated `clear_capsule_render()` to purge `render_cache = nil` upon entity capture, removal, eject, or spill events.


### Revision: Inventory Bar Slot Bounding & Periodic Spoilage Render Refresh `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 22:13 (EDT)
**Context:** Eliminate unnecessary C++ `LuaItemStack` userdata allocations on red-locked inventory slots during lifecycle and rendering iterations, purge stale spoilage tracking data, and update parked capsule debug overlays when stored cargo spoils naturally.
**Key Changes:**
1. **Active Inventory Slot Bounding (`scripts/capsules/capsule-lifecycle.lua` & `scripts/capsules/capsule-renderer.lua`):** Integrated `supports_bar()` and `get_bar()` bounds checking (`max_slot`) across spoilage processing and dominant item queries. Restricts inventory iteration strictly to unlocked chest slots, preventing expensive engine allocations on locked slots.
2. **Stale Spoilage Tracking Cleanup (`scripts/capsules/capsule-lifecycle.lua`):** Added a post-loop purge clearing `capsule.slot_spoil_percents` tracking entries for slot indices greater than `max_slot` to prevent stale memory state when inventory bar boundaries shift.
3. **Parked Capsule Spoilage Sprite Refresh (`scripts/capsules/capsule-renderer.lua`):** Added a 60-tick periodic re-evaluation (`((game.tick + tick_offset) % 60 == 0)`) to render cache validation. Forces stationary or parked capsules to re-query their dominant item so visual debug overlays update dynamically as cargo spoils.


### Revision: Alt Mode Capsule Peeking Overlay & Debug Flag Mutual Exclusion `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 22:34 (EDT)
**Context:** Implement entity-hover capsule peeking (`/capsule-peek`) in Alt Mode to visually inspect capsules occupying targeted pneumatic entities without enabling global capsule overlays, while enforcing mutual exclusion between capsule debug modes.
**Key Changes:**
1. **Capsule Peeking Console Command (`scripts/debug-manager.lua`):** Registered `/capsule-peek` command to toggle `storage.debug[player_index].peek`. Enforced mutual exclusion between `peek` and `capsules` debug toggles so enabling one automatically disables the other while allowing both to be turned off.
2. **Alt Mode & Hover Occupancy Filtering (`scripts/capsules/capsule-renderer.lua`):** Updated visual overlay evaluation to require active Alt Mode (`player.game_view_settings.show_entity_info`). Implemented entity unit number matching (`player.selected.unit_number`) against capsule port keys (`from_port_key` / `to_port_key`) when peeking, isolating rendered overlay sprites strictly to capsules occupying the hovered structure.
3. **Render Cache Dynamic Player Keying (`scripts/capsules/capsule-renderer.lua`):** Integrated `wants_peek` state into `debug_key` render cache validation, seamlessly updating visual overlay objects on mouse movement across entities without breaking frame-by-frame stationary capsule caching optimizations.


### Revision: Short-Circuited O(1) Network Capacity Queries & Node Group Caching `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 23:13 (EDT)
**Context:** Eliminate $O(N^2)$ entity-network capacity query overhead during segment pathfinding and backpressure bottlenecks by implementing early-exit threshold limits, deferred origin group evaluation, pre-resolved parameter passing, and flow map node group caching.
**Key Changes:**
1. **Early-Exit Capacity Threshold (`scripts/capsules/capsule-queries.lua`):** Added an optional `max_threshold` parameter to `get_capsule_count_at_entity_network()`. Iteration over `storage.capsules` early-returns immediately once `count >= max_threshold`, converting $O(N)$ table scans into $O(1)$ early exits on occupied target segments.
2. **Pre-Resolved Group Passing & Deferred Evaluation (`scripts/capsules/capsule-motion.lua`):** Refactored `has_entity_network_capacity()` to pre-calculate `target_group` once and pass it directly as a parameter to `get_capsule_count_at_entity_network()`. Deferred `current_group` query (`get_port_group(from_port_key)`) to execute strictly during same-entity/same-network hops.
3. **Flow Map Node Group Caching (`scripts/capsules/capsule-queries.lua`):** Updated `get_port_group()` to cache resolved port group IDs directly on flow map nodes (`node.group = group or false`), ensuring subsequent group checks complete in $O(1)$ time without re-querying entity prototype port definitions.


### Revision: Per-Force Bio-Integrity Tech Caching & Staggered Fragile Spill Evaluation `[INCORPORATED IN TABLE]`
**Date:** 2026-08-29 23:37 (EDT)
**Context:** Eliminate per-tick `force.technologies` string indexing overhead and 60Hz `math.random()` RNG execution on fragile transit capsules by implementing event-driven technology level caching and staggered interval risk scaling.
**Key Changes:**
1. **Per-Force Technology Level Caching (`scripts/capsules/capsule-lifecycle.lua` & `control.lua`):** Replaced per-tick `force.technologies` string table lookups with an O(1) cached research tier lookup (`storage.bio_integrity_levels[force.index]`). Initialized `storage.bio_integrity_levels` in `control.lua` (`setup_storage`).
2. **Event-Driven Research Sync (`scripts/capsules/capsule-lifecycle.lua`):** Registered event listeners for `on_research_finished`, `on_research_reversed`, and `on_technology_effects_reset` to automatically update cached `bio-capsule-integrity` research tiers upon technology state changes.
3. **Staggered 10-Tick Spill Evaluation & Risk Compounding (`scripts/capsules/capsule-lifecycle.lua`):** Throttled fragile container spill risk checks to evaluate every 10 ticks (`(game.tick + id) % 10 == 0`), applying exact probability compounding ($R_{10} = 1 - (1 - r)^{10}$) to reduce RNG rolls by 90% while preserving mathematically exact failure rates.


### Revision: Pump & Hub Operational State Sensitivity, Flow Listener Decoupling & Cyclic Require Fix `[INCORPORATED IN TABLE]`
**Date:** 2026-08-30 09:45 (EDT)
**Context:** Resolve flow map vector generation ignoring pump enable toggles, eliminate a 5-file load-time circular dependency loop between network and capsule modules, and instantly wake parked capsules on hub/pump operational state changes.
**Key Changes:**
1. **Pump Enable State Verification (`scripts/networks/networks-flow.lua` & `scripts/networks/pump-manager.lua`):** Updated `is_powered()` to evaluate `(entity.energy > 0) and pump_settings.is_pump_enabled(entity)` for pneumatic pumps, correctly closing flow vectors when pumps are disabled. Synchronized `pump_enabled_states` and `pump_power_states` arrays immediately inside `pump_manager.notify_settings_changed()`.
2. **Decoupled Flow Listener Subscription (`scripts/networks/networks-flow.lua` & `scripts/capsules/capsule-runner.lua`):** Replaced direct module `require` in `networks-flow.lua` with a listener subscription pattern (`networks_flow.register_listener`). Subscribed `capsule_runner.wake_parked_capsules` to flow updates, eliminating a 5-file load-time circular require loop (`networks-flow` -> `capsule-runner` -> `capsule-motion` -> `capsule-renderer` -> `debug-manager` -> `networks-flow`) while guaranteeing instant wakeup of parked capsules when flow maps rebuild.
3. **Event-Driven Hub GUI Notification Engine (`scripts/hubs/hub-manager.lua` & `scripts/hubs/hub-gui.lua`):** Added `hub_manager.notify_settings_changed(entity)` and hooked all `hub-gui.lua` interaction callbacks (`on_gui_checked_state_changed`, `on_gui_elem_changed`, `on_gui_selection_state_changed`, `on_gui_text_changed`) to fire it. Instantly wakes parked disembarking capsules and triggers immediate inventory packing checks when send/receive permissions flip.


### Revision: Diverter Operational State Sensitivity & Flow Rebuild Deduplication `[INCORPORATED IN TABLE]`
**Date:** 2026-08-30 10:09 (EDT)
**Context:** Synchronize diverter power and port state caches immediately during GUI settings updates to instantly wake parked capsules while eliminating duplicate flow map rebuild calls across multi-port diverter networks.
**Key Changes:**
1. **Synchronous Diverter State Cache Sync (`scripts/networks/diverter-manager.lua`):** Updated `diverter_manager.notify_settings_changed()` to immediately synchronize `storage.diverter_power_states` and `storage.diverter_port_states` arrays upon GUI configuration events. This guarantees instant flow map updates and listener execution (`capsule_runner.wake_parked_capsules`) while preventing the 15-tick background scanner (`check_diverter_states`) from detecting stale mismatches and triggering duplicate flow rebuilds.
2. **Network Rebuild Deduplication (`scripts/networks/diverter-manager.lua`):** Refactored `rebuild_diverter_networks()` to utilize a `visited` network ID lookup table across all 4 diverter ports, ensuring `networks_flow.build(net_id)` is executed at most once per connected network per update.


### Revision: Topology-State Decoupling, Port Evaluator Cleanup & Orientation State Sync `[INCORPORATED IN TABLE]`
**Date:** 2026-08-30 10:28 (EDT)
**Context:** Resolve stale flow map vectors on pneumatic pumps and diverters when rotated or flipped while disabled, and ensure enable/disable GUI toggles reliably update flow map state across orientation changes.
**Key Changes:**
1. **Physical Topology & Operational State Decoupling (`scripts/ports/port-evaluator.lua` & `scripts/ports/port-definitions.lua`):** Removed `enabled == false` connection rejection in `port_evaluator.are_compatible()`, allowing spatial graph topology (`storage.port_connections`) to form permanently based on physical directional compatibility (`"in"`, `"out"`, `"any"`). Dynamic pressure (`nil`) and flow vector suppression (`enabled = false`) remain active when disabled without corrupting graph links.
2. **Synchronous Orientation Cache & Flow Rebuild (`scripts/networks/network-rotate.lua`, `scripts/networks/pump-manager.lua`, `scripts/networks/diverter-manager.lua`):** Hooked `on_player_rotated_entity` and `on_player_flipped_entity` across pump and diverter managers to immediately update power and port state caches upon rotation/flipping.
3. **Pump Network Rebuild Deduplication (`scripts/networks/pump-manager.lua`):** Integrated a `visited` network ID lookup table into `rebuild_pump_networks()` to eliminate duplicate `networks_flow.build()` calls across multi-port pump sub-networks.


### Revision: Player-Scoped Flow Overlay Command Refresh & Render Handle Cleanup `[INCORPORATED IN TABLE]`
**Date:** 2026-08-30 12:15 (EDT)
**Context:** Resolve `/toggle-flow` debug overlay state failing to refresh or clear immediately upon command execution by fixing top-level render storage key resolution and implementing lazy flow map generation.
**Key Changes:**
1. **Player-Scoped Flow Render Handle Cleanup (`scripts/networks/networks-flow.lua`):** Refactored `networks_flow.clear_all(player_index)` to properly unpack network entries under `storage.flow_render_ids[player_index]` keyed by player index, ensuring instant destruction of C++ line and text overlay handles upon command toggle without leaking objects.
2. **Player-Scoped & Lazy Flow Map Rendering (`scripts/networks/networks-flow.lua`):** Updated `networks_flow.draw_all(player_index)` to accept an optional target player handle and lazily generate missing `flow_map` metadata via `build_single_network(net_id)`, guaranteeing immediate vector overlay drawing when `/toggle-flow` or `/toggle-debug` is executed without requiring physical network interaction.


### Revision: Tool Durability Dynamic Prototype Resolution & Lifespan Engine Clamping Fix `[INCORPORATED IN TABLE]`
**Date:** 2026-08-30 12:27 (EDT)
**Context:** Eliminate hardcoded numerical fallbacks during refrigerated capsule durability evaluation, resolving engine clamping reset loops and preventing artificial 10x refrigeration lifespan extensions while ensuring dynamic prototype compatibility across custom items and quality tiers.
**Key Changes:**
1. **Dynamic Prototype Durability Resolution (`scripts/capsules/capsule-lifecycle.lua`):** Replaced hardcoded `1000` fallback in `current_durability` calculation with dynamic fallback to `stack.prototype.durability`. Ensures exact alignment with item prototype definitions (`durability = 100` on `refrigerated-capsule`) without script-level magic numbers.
2. **Engine Clamping & Lifespan Reset Elimination (`scripts/capsules/capsule-lifecycle.lua`):** Fixed C++ `LuaItemStack.durability` clamping behavior where uninitialized tool stacks assigned values above prototype max (e.g. 999 > 100) were clamped back to 100.0 every tick, which previously stuck durability at maximum and artificially inflated refrigeration lifespan by 10x.
3. **Arithmetic Guarding & Exception Prevention (`scripts/capsules/capsule-lifecycle.lua`):** Wrapped durability decrement routines in a protective `if current_durability then` check, preventing Lua arithmetic runtime errors on non-tool or durability-less item stacks.


#### 0.2.0

### Revision: Diverter Downstream Lookahead Path Validation & Instant Queue Advancement
**Date:** 2026-08-30 18:28 (EDT)
**Context:** Resolve diverters backing up and blocking open routes by validating downstream capacity before committing capsules into internal machine hops, and eliminating queue latency on segment arrivals.
**Key Changes:**
1. **Recursive Downstream Lookahead Validation (`scripts/capsules/capsule-motion.lua`):** Implemented `is_hop_valid()` to inspect downstream external hops when evaluating internal machine transfers (e.g. diverter input-to-output ports). Ensures exit ports leading to full or filter-disqualified tube lines are rejected before a capsule enters the internal port.
2. **Pressure-Drop Scoring Filtering (`scripts/capsules/capsule-motion.lua`):** Updated `best_downstream` calculations in `select_next_target()` to evaluate pressure drop gradients exclusively across open downstream paths with available network capacity.
3. **0-Tick Queue Advancement (`scripts/capsules/capsule-runner.lua`):** Configured `update_capsules()` to fire `capsule_runner.wake_parked_capsules()` whenever any capsule completes a segment traversal (`to_port_key = nil`), allowing waiting capsules to re-evaluate pathing instantly on the same tick when space opens up.


### Revision: O(1) Spatial Occupancy Index & Zero-Allocation Path Lookahead Optimization
**Date:** 2026-08-30 20:25 (EDT)
**Context:** Restore UPS performance during high capsule traffic (~150+ active capsules) by eliminating O(N) linear iteration over active capsules and string garbage allocations occurring during recursive path lookahead capacity checks (`is_hop_valid`, `get_capsule_count_at_entity_network`).
**Key Changes:**
1. **$O(1)$ Spatial Occupancy Index (`scripts/capsules/capsule-queries.lua`):** Implemented `storage.occupancy` to track multi-level spatial buckets (`[unit_number][net_id][group]`), converting `get_capsule_count_at_entity_network`, `get_capsule_count_at_entity`, and `find_capsules_at_entity` into constant-time lookups. Added tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`, `rebuild_occupancy_index`).
2. **Memoized Port Key Parsing (`scripts/capsules/capsule-queries.lua` & `scripts/capsules/capsule-motion.lua`):** Added `get_port_info()` to cache parsed port key descriptors (`unit_number`, `port_index`), eliminating string slicing (`string.sub`) and string concatenation garbage inside high-frequency `get_unit_number()` and diverter filter evaluations.
3. **Occupancy Lifecycle Integration (`scripts/capsules/capsule-runner.lua` & `scripts/capsules/capsule-motion.lua`):** Synchronized occupancy tracking updates across capsule injection (`inject_from_hub`), segment transitions, target selection (`select_next_target`), hub capture disembarkation, emergency ejection, and entity removals.


### Revision: Targeted Network-Scoped Queue Wakeup Engine & Retry Throttling
**Date:** 2026-08-30 20:56 (EDT)
**Context:** Eliminate global map-wide capsule scans triggered during individual segment movements and arrivals, restoring UPS performance and parked retry throttling during high capsule traffic.
**Key Changes:**
1. **Targeted Wakeup Engine (`scripts/capsules/capsule-runner.lua`):** Refactored `capsule_runner.wake_parked_capsules` to accept an optional target (`port_key`, `unit_number`, or `net_id`), utilizing `storage.occupancy` and network topology metadata to wake strictly the parked capsules affected by a freed route or entity state change.
2. **Network-Scoped Movement Hooks (`scripts/capsules/capsule-runner.lua`):** Updated segment movement completions, hub disembarkations, capsule removals, and emergency ejects to pass the exact vacated `port_key` to `wake_parked_capsules`, eliminating blanket map scans on individual movement steps.
3. **Restored Retry Throttling (`scripts/capsules/capsule-runner.lua`):** Ensured parked capsules on unaffected tube lines or separate surfaces remain asleep for their full 10-tick interval (`PARKED_RETRY_INTERVAL = 10`), preventing tick-by-tick pathfinding and filter re-evaluations across the map.


### Revision: System-Level Viewport Caching & Zero-Allocation Render Loop
**Date:** 2026-08-30 21:13 (EDT)
**Context:** Eliminate per-capsule player environment queries, game view setting reads, string key joins, and temporary table allocations occurring inside the per-tick render loop (`capsule_renderer.render`) to restore UPS performance during high capsule traffic.
**Key Changes:**
1. **System-Level Per-Frame Viewport Preparation (`scripts/capsules/capsule-renderer.lua` & `scripts/capsules/capsule-runner.lua`):** Implemented `capsule_renderer.prepare_frame()` invoked at the start of `update_capsules()`, pre-evaluating player viewport eligibility, Alt Mode states, and active debug flags once per tick across `game.players` instead of $N_{\text{capsules}} \times N_{\text{players}}$ times per frame.
2. **Memoized Numeric Hover Peeking (`scripts/capsules/capsule-renderer.lua`):** Replaced string formatting (`tostring(unit_number) .. ":"`) and string slicing (`string.sub`) during hover peeking (`/capsule-peek`) with memoized $O(1)$ unit number lookup via `capsule_queries.get_port_info()`, enabling fast integer equality comparisons (`u_from == hovered_unit`).
3. **Allocation-Free Scratch Tables & Fast Numeric Debug Keys (`scripts/capsules/capsule-renderer.lua`):** Replaced per-capsule temporary table allocations (`debug_players`, `debug_key_tbl`) and string joins (`table.concat`) with pre-allocated module-level scratch arrays (`scratch_debug_players`, `scratch_debug_keys`) and numeric primitive cache keys (`0` or `player.index` for 0/1 viewers).


### Revision: Mid-Segment Traversal Parameter Caching & O(1) Motion Interpolation Loop
**Date:** 2026-08-30 21:59 (EDT)
**Context:** Eliminate repetitive mid-segment node lookups, physical entity coordinate queries, and speed math calculations (`calculate_segment_speed`, `get_port_world_pos`) executed every tick for capsules currently in mid-transit, restoring UPS performance during high capsule traffic (~150+ active capsules).
**Key Changes:**
1. **Segment Traversal Parameter Caching (`scripts/capsules/capsule-motion.lua`):** Implemented `setup_segment()` to pre-calculate and cache segment start/end world coordinates (`seg_from_x`, `seg_from_y`, `seg_to_x`, `seg_to_y`), vector deltas (`seg_dx`, `seg_dy`), total segment distance (`seg_dist`), surface (`surface`), entity handles (`entity_from`, `entity_to`), and travel speed (`seg_speed`) directly on capsule objects upon target selection and segment transitions.
2. **$O(1)$ Mid-Segment Motion Loop (`scripts/capsules/capsule-runner.lua`):** Updated `update_capsules()` to interpolate mid-segment movement directly from cached primitive parameters, bypassing per-tick `calculate_segment_speed()`, `get_port_world_pos()`, and `get_node()` queries. Replaced per-tick `{ x = ..., y = ... }` position table allocations with a module-level scratch position table (`scratch_pos`) and fast C++ property checks (`entity_from.valid`, `entity_to.valid`).
3. **Cached Location Queries (`scripts/capsules/capsule-runner.lua`):** Refactored `get_capsule_location()` to return real-world coordinates directly from cached segment parameters in $O(1)$ time, eliminating network topology node queries during passenger position updates, emergency ejects, and spoilage unit handling.


### Revision: Target-Based Spatial Occupancy & 0-Tick Pipeline Queue Advancement
**Date:** 2026-08-30 22:22 (EDT)
**Context:** Eliminate network queue stalling, 1-by-1 segment traversal delays, and stale spatial occupancy indexes following network rebuilds, segment additions, or flow updates.
**Key Changes:**
1. **Target-Based Blocking Occupancy Model (`scripts/capsules/capsule-queries.lua`):** Refactored `update_capsule_occupancy` to track a single node blocking key (`_occ_block_key`). Moving capsules block their destination target (`to_port_key`), immediately freeing origin node capacity (`from_port_key`) for upstream capsules while in mid-transit.
2. **0-Tick Lockstep Queue Advancement (`scripts/capsules/capsule-runner.lua`):** Configured `update_capsules()` to invoke `wake_parked_capsules(prev_from)` the exact tick a parked capsule transitions to moving (`to_port_key ~= nil`), triggering instant pipeline wakeups for upstream queued capsules without 10-tick retry delays or segment arrival latency.
3. **Synchronized Occupancy Resync & Listener Propagation (`scripts/networks/networks-flow.lua` & `scripts/capsules/capsule-runner.lua`):** Configured `networks_flow.build()` to invoke `capsule_queries.rebuild_occupancy_index()` on graph edits, and updated `notify_listeners` and `wake_parked_capsules` to process network ID tables, instantly waking sleeping capsules across modified or rebuilt subgraphs.


### Revision: Zero-Allocation Payload Metadata Caching & Motion Inventory Bypass
**Date:** 2026-08-30 22:38 (EDT)
**Context:** Eliminate physical container item stack inspections on the liminal surface (`get_dominant_item`) during directional path selection, diverter filter evaluations, and hub exit checks (`select_next_target`, `find_best_hub_outbound_port`) to restore UPS performance during high capsule traffic (~150+ active capsules).
**Key Changes:**
1. **Payload Metadata Caching at Packing (`scripts/hubs/hub-packing.lua` & `scripts/capsules/capsule-manager.lua`):** Updated hub packing logic to compute the dominant payload item during extraction plan generation and pass it directly to `capsule_manager.register()`, persisting it in `storage.active_capsules[capsule_id].dominant_item`.
2. **$O(1)$ Motion Pathfinding & Filter Evaluation (`scripts/capsules/capsule-motion.lua` & `scripts/capsules/capsule-runner.lua`):** Refactored `select_next_target()` and `find_best_hub_outbound_port()` to read `capsule.dominant_item` directly from memory in constant time, bypassing C++ container inventory queries on `liminal_surface` during tick-by-tick motion execution and diverter filter evaluations.
3. **Guarded Renderer Inventory Scans (`scripts/capsules/capsule-renderer.lua`):** Updated `capsule_renderer.get_dominant_item(capsule_id, force_refresh)` to return cached payload strings instantly, restricting physical container inventory scans to explicit force-refresh calls (e.g., 60-tick spoilage re-checks for active Alt Mode debug overlays).


### Revision: Diverter Filter Validation & O(1) Key Parsing Optimization
**Date:** 2026-08-30 22:54 (EDT)
**Context:** Eliminate redundant string key parsing, deep network graph flow-map lookups, and uncompiled settings table traversals during tick-by-tick diverter filter evaluation and recursive lookahead pathfinding.
**Key Changes:**
1. **$O(1)$ Non-Diverter Filter Short-Circuiting (`scripts/capsules/capsule-motion.lua`):** Refactored `check_diverter_port_filter()` to query `capsule_queries.get_port_info()` directly, extracting integer unit numbers and port indices without flow-map metadata traversals or string allocations, instantly short-circuiting non-diverter entities in 2 table lookups.
2. **Memoized Filter Compilation & Active Slot Traversal (`scripts/capsules/capsule-motion.lua`):** Implemented `get_compiled_filter()` to lazily compile active filter slots and blacklist modes onto `port_setting._compiled`, bypassing unconfigured slots (slots 2..5) and enabling instant early-exit evaluation on whitelist matches.
3. **Graph-Free Unit Key Parsing & Filter Cache Invalidation (`scripts/capsules/capsule-motion.lua` & `scripts/networks/diverter-manager.lua`):** Refactored `get_unit_number()` to delegate directly to memoized port info lookups, and updated `diverter_manager` (`notify_settings_changed`, `check_diverter_states`) to clear `_compiled` caches on modified diverter ports when settings, orientation, or power states change.


### Revision: O(1) Hub Unpacking Failure Guard & Zero-Allocation Space Simulation
**Date:** 2026-08-30 23:32 (EDT)
**Context:** Eliminate redundant full-container slot space simulations (`can_insert_all`) performed by capsules parked at or repeatedly polling full or blocked hub destinations, restoring UPS performance during high capsule traffic (~150+ active capsules).
**Key Changes:**
1. **$O(1)$ Destination Failure State Guard (`scripts/hubs/hub-unpacking.lua`):** Implemented failure state tracking (`last_failed_hub`, `last_failed_hub_count`, `last_failed_hub_bar`, `last_failed_cap_count`) on capsule tracker objects inside `hub_unpacking.capture`. Instantly short-circuits slot space inspections in constant time if destination container item counts have not decreased, container bars have not expanded, and payload item counts have not dropped.
2. **Zero-Allocation Scratch Arrays (`scripts/hubs/hub-unpacking.lua`):** Replaced temporary table allocations inside `can_insert_all` with module-level flat scratch arrays (`scratch_req_names`, `scratch_req_counts`, `scratch_partial`, `scratch_filtered`), eliminating Lua garbage collection overhead during space checks. Bypassed string key concatenation for normal-quality items.
3. **Targeted Failure Cache Invalidation (`scripts/capsules/capsule-runner.lua`):** Configured `capsule_runner.wake_parked_capsules()` to clear `capsule.last_failed_hub = nil` when waking parked capsules on network edits or entity state changes, ensuring immediate unpacking re-evaluation when route space opens up.


### Revision: Circuit Proxy Lifecycle Event Fix & Visual Suppression
**Date:** 2026-08-31 08:04 (EDT)
**Context:** Fix orphaned circuit proxy constant combinators remaining after sandbox deconstruction tool usage or scripted removal, and render circuit proxy sprites invisible to eliminate visual overlap with physical entity structures.
**Key Changes:**
1. **Scripted Destruction Event Registration (`prototypes/pneumatic-pump-proxy-linkage.lua` & `prototypes/pneumatic-diverter-proxy-linkage.lua`):** Corrected `destroy_events` indexing from `defines.script_raised_destroy` to `defines.events.script_raised_destroy` in pump proxy linkage, resolving orphaned proxies during sandbox/editor instant deconstruction and scripted removals. Added Factorio 2.0 space platform build and mine event handlers (`on_space_platform_built_entity`, `on_space_platform_mined_entity`).
2. **Proxy Sprite Suppression (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Configured `sprites` and `activity_led_sprites` across all four cardinal orientations to `util.empty_sprite()` on `pneumatic-pump-circuit-proxy` and `pneumatic-diverter-circuit-proxy`, rendering proxy constant combinators visually invisible while retaining full circuit wire connection and logic functionality.


### Revision: Non-Spoilable Render Polling Optimization & Factorio 2.0 Spoil API Guard
**Date:** 2026-08-31 08:23 (EDT)
**Context:** Eliminate redundant 60-tick physical container inventory scans during render overlay execution for capsules transporting non-spoilable cargo, and fix a Factorio 2.0 `LuaItemPrototype` property indexing crash during hub packing.
**Key Changes:**
1. **Spoilability Detection at Hub Packing (`scripts/hubs/hub-packing.lua`):** Implemented `is_stack_spoilable()` to safely inspect item prototypes and stacks via `get_spoil_ticks()`, `spoil_tick`, and `spoil_percent`. Evaluates cargo extractions and primary vessel stacks during packing to compute a `has_spoilable_items` flag passed to `capsule_manager.register()`.
2. **Active Capsule Spoilability Tracking (`scripts/capsules/capsule-manager.lua`):** Updated `capsule_manager.register()` to persist `has_spoilable_items` on active capsule tracker objects within `storage.active_capsules`.
3. **Guarded Render Polling & Inventory Scan Short-Circuiting (`scripts/capsules/capsule-renderer.lua`):** Refactored `render()` to suppress 60-tick periodic spoilage re-checks for non-spoilable capsules (`has_spoilable_items == false`). Updated `get_dominant_item()` to short-circuit and instantly serve cached dominant item strings without opening liminal container inventories.


### Revision: Standardized Command Naming, Shortcut Bar Toggles & Top-Level Module Loading
**Date:** 2026-08-31 08:47 (EDT)
**Context:** Clean up debug command naming consistency, add interactive toggle buttons to Factorio's shortcut bar (vertical ellipsis menu), establish bidirectional shortcut state synchronization, and enforce top-level require loading across all script modules.
**Key Changes:**
1. **Shortcut Bar Prototype Registration (`prototypes/shortcut.lua` & `data.lua`):** Registered toggleable `shortcut` prototypes (`pt-toggle-flow`, `pt-toggle-capsules`, `pt-toggle-capsule-peek`, `pt-toggle-ports`, `pt-toggle-debug`) with icon bindings and `toggleable = true` support for Factorio's shortcut bar.
2. **Standardized Command Naming & Aliases (`scripts/debug-manager.lua`):** Renamed `/capsule-peek` to `/toggle-capsule-peek` for naming alignment across all debug toggles (`/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules`). Retained `/capsule-peek` as a backward-compatible alias alongside `pt-toggle-*` command aliases.
3. **Bidirectional Shortcut Sync & Event Handler (`scripts/debug-manager.lua` & `control.lua`):** Bound `defines.events.on_lua_shortcut` to toggle debug overlays dynamically on hotbar shortcut clicks. Implemented `debug_manager.sync_shortcuts()` with guarded `player.set_shortcut_toggled()` calls to maintain 1:1 state synchronization across GUI clicks, chat commands, and player initialization.
4. **Top-Level Module Loading Enforcement (`control.lua`):** Standardized module imports strictly to file top-levels, ensuring `debug_manager` and dependent scripts load cleanly without dynamic inline `require` calls during tick handlers or events.


### Revision: Inoperable Spilled Containers & Zero-Overhead Cleanup Engine
**Date:** 2026-08-31 09:33 (EDT)
**Context:** Prevent players from manually placing items back into spilled capsule containers by hand, eliminate tick-by-tick inventory bar enforcement loops, and restore UPS performance during network deconstructions and container spills.
**Key Changes:**
1. **Inoperable Spilled Container Prototype (`prototypes/entity.lua`):** Configured `operable = false` on the `visible-capsule-holder` prototype definition, preventing players from opening container GUIs to enforce a strict one-way spill retrieval model.
2. **Spilled Entity Lifecycle Enforcement (`scripts/hubs/hub-spill.lua`):** Updated `hub_spill.spill_capsule` to explicitly set `container_entity.operable = false` upon creation, guaranteeing non-operability across all physical surface container spills.
3. **GUI Event & Bar Scan Elimination (`scripts/hubs/hub-spill.lua`):** Removed `on_gui_opened` and `on_gui_closed` event listeners and purged tick-by-tick `set_bar(1)` GUI fighting loops. Throttled `process_spilled_containers` to evaluate empty container cleanup at a 60-tick (1-second) interval, eliminating per-tick UPS churn.


### Revision: Circuit Proxy & Shortcut Bar Toggle English Localization
**Date:** 2026-08-31 10:07 (EDT)
**Context:** Complete missing English (`en`) locale definitions for hidden constant-combinator pump circuit proxies and hotbar debug shortcuts to eliminate raw locale key fallbacks across tooltips, entity inspectors, and shortcut bar toggles.
**Key Changes:**
1. **Circuit Proxy Entity Localization (`locale/en/config.cfg`):** Added `pneumatic-pump-circuit-proxy` entry under `[entity-name]` matching `pneumatic-diverter-circuit-proxy` to ensure pump proxy combinators display clean localized entity names.
2. **Shortcut Bar Toggle Localization (`locale/en/config.cfg`):** Added `[shortcut-name]` section registering localized display names for all five hotbar toggle shortcuts (`pt-toggle-flow`, `pt-toggle-capsules`, `pt-toggle-capsule-peek`, `pt-toggle-ports`, `pt-toggle-debug`).


### Revision: Exact O(1) Biological Item Lookup Matrix & Top-Level Require Enforcement
**Date:** 2026-08-31 10:21 (EDT)
**Context:** Expand biological item support for bio capsules across all Factorio 2.0 / Space Age organic items, eliminate fuzzy string matching risks, and enforce top-level script require loading.
**Key Changes:**
1. **Strict $O(1)$ Bio Item Matrix (`scripts/capsules/capsule-definitions.lua`):** Replaced fuzzy string pattern searches (`string.find`) with an explicit lookup table (`capsule_definitions.bio_items`) containing all vanilla and Space Age organic items (`yumako`, `jellynut`, seeds, slumps, bioflux, spoilage, nutrients, eggs, bacteria, fish, wood) and the `biodegradable-capsule` item shell.
2. **Bio Slot Cost Planner Integration (`scripts/hubs/packing/cargo-planner.lua`):** Updated `cargo_planner.get_item_slot_cost()` to delegate directly to `capsule_defs.is_bio_item()`, ensuring all biological items reliably receive the `0.5` slot cost factor (2× stack capacity bonus) inside biodegradable capsules.
3. **Top-Level Module Loading Standard (`scripts/hubs/packing/cargo-planner.lua` & `scripts/hubs/hub-packing.lua`):** Enforced top-level scope for `require("scripts.capsules.capsule-definitions")` and verified strict top-level import compliance across capsule packing modules.


### Revision: Zero-Collision Circuit Proxies & Wire Selection Fix
**Date:** 2026-08-31 11:02 (EDT)
**Context:** Resolve fast-replace upgrades and building placement overlays being blocked by circuit proxy entities while preserving circuit wire network connectivity.
**Key Changes:**
1. **Empty Collision Mask (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Configured `collision_mask = {layers = {}}` on proxy prototypes to eliminate all spatial collision layers, allowing fast-replace upgrades and building placement overlays to function seamlessly without proxy collision interference.
2. **Wire Selection & Flag Tuning (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Removed `"not-selectable-in-game"` from `flags`, added `"no-copy-paste"`, set `selection_priority = 0`, and mapped `selection_box` to host structures, restoring red/green circuit network wire targeting.
3. **Top-Level Require Compliance (`prototypes/pneumatic-pump-proxy-linkage.lua` & `prototypes/pneumatic-diverter-proxy-linkage.lua`):** Verified strict top-level module import standards across proxy lifecycle linkage scripts.


### Revision: Zero-Overhead Circuit Proxy Selection Deferral & Visual Suppression
**Date:** 2026-08-31 11:18 (EDT)
**Context:** Prevent circuit proxy constant combinators from overriding hover selection and double-rendering selection outlines over host units (`pneumatic-pump` and `pneumatic-diverter`), while deferring GUI opening and wire targeting cleanly to the linked physical entity.
**Key Changes:**
1. **Selection Box Visual Suppression (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Configured `draw_selection_box = false` on proxy prototypes to eliminate secondary green selection box outlines when mousing over host structures.
2. **Compact Selection Footprint & Priority Tuning (`prototypes/pneumatic-pump-proxy.lua` & `prototypes/pneumatic-diverter.lua`):** Reduced proxy `selection_box` to `{{-0.3, -0.3}, {0.3, 0.3}}` with `selection_priority = 0`, ensuring hovering over 90%+ of the building footprint highlights the physical unit while preserving wire connection targeting near the center.
3. **Seamless Proxy GUI Deferral (`prototypes/pneumatic-pump-proxy-linkage.lua` & `prototypes/pneumatic-diverter-proxy-linkage.lua`):** Refactored `on_gui_opened` event handlers to intercept proxy entity selection and resolve linked host entities via `surface.find_entity()`, launching host configuration GUIs (`pump_gui` / `diverter_gui`) without disruption.


### Revision: Pneumatic Control Panel GUI & Hotbar Debug Consolidation
**Date:** 2026-08-31 11:34 (EDT)
**Context:** Consolidate individual hotbar debug shortcut toggles into a unified master Pneumatic Control Panel Lua GUI frame to eliminate hotbar clutter and provide a centralized debugging interface.
**Key Changes:**
1. **Unified Control Panel GUI (`scripts/debug-manager.lua`):** Implemented `debug_manager.open_panel()`, `close_panel()`, `toggle_panel()`, and `refresh_panel()`, creating a centered, draggable frame featuring a master debug toggle, visual overlay switches (flow vectors, active capsules, hover peek, port markers), and console print toggles. Maintained mutual exclusion between active capsule rendering and hover peeking modes.
2. **Consolidated Shortcut Bar Prototype (`prototypes/shortcut.lua`):** Replaced individual shortcut bar entries with a single toggleable `pt-debug-panel` shortcut prototype, binding hotbar clicks directly to opening/closing the unified control panel.
3. **Command & GUI Event Synchronization (`scripts/debug-manager.lua` & `control.lua`):** Added `/pneumatic-panel` and `/debug-panel` console commands, updated toggle command aliases to update panel checkbox states dynamically if open, bound `on_gui_click`, `on_gui_closed`, and `on_gui_checked_state_changed` events, and enforced top-level `require` loading.
4. **Locale Expansion (`locale/en/config.cfg`):** Added `[gui-debug]` localization headers, checkbox labels, and localized name strings for the `pt-debug-panel` shortcut tooltips.


### Revision: Dynamic Spoilage Expiration Tracking & Zero-Overhead Render Polling
**Date:** 2026-08-31 12:03 (EDT)
**Context:** Dynamically update active capsule spoilability tracking when spoilable cargo completely spoils or decays during transit, eliminating perpetual 60-tick container inventory re-scans while ensuring dominant item visual icons correctly update to spoiled products.
**Key Changes:**
1. **Post-Update Spoilage Expiration Guard (`scripts/capsules/capsule-renderer.lua`):** Refactored `get_dominant_item()` to inspect active container slots using `is_stack_spoilable()`, update `cap_data.dominant_item` to the newly spoiled product (e.g. `copper-ore` or `spoilage`) first, and then flip `has_spoilable_items` to `false` only if zero spoilable stacks remain across all active slots.
2. **0-Tick Scan Suppression (`scripts/capsules/capsule-renderer.lua`):** Configured `render()` to permanently suppress 60-tick periodic inventory re-scans once `has_spoilable_items` transitions to `false`, serving cached dominant item icons directly from Lua memory in $O(1)$ time.
3. **Decoupled Lifecycle State Cleanliness (`scripts/capsules/capsule-lifecycle.lua`):** Restricted `capsule-lifecycle.lua` from performing premature state mutation on `has_spoilable_items`, preserving strict single-responsibility ownership in `capsule-renderer.lua` to prevent stale icon caching during mid-flight spoilage transitions.


### Revision: Full Item Metadata Preservation, Equipment Grid Transfer & API Guard
**Date:** 2026-08-31 14:26 (EDT)
**Context:** Resolve loss of item metadata (spoil_percent, health, durability, ammo, tags) and equipment grids (stack.grid) during capsule packing, unpacking, spilling, and refrigerated updates, and eliminate `Item is not item-with-tags` C++ runtime exceptions.
**Key Changes:**
1. **Native C++ `transfer_stack()` Engine Integration (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`):** Updated hub extractions, disembarkation captures, and spilled container transfers to execute native `dest_slot.transfer_stack(src_stack)` calls, preserving 100% of equipment grids (`stack.grid`), installed modules, shield/energy states, spoilage, health, durability, ammo, and quality directly inside the Factorio engine.
2. **$O(1)$ Equipment Grid Copying & Restoration (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-lifecycle.lua`):** Implemented `copy_equipment_grid()` to clone equipment grids (`create_grid()`) and transfer all installed equipment (`name`, `position`, `quality`, `energy`, `shield`) during fallback stack extractions and periodic 60-tick refrigerated spoilage updates.
3. **Safe Metadata Extraction & `item-with-tags` API Guard (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-lifecycle.lua`):** Implemented `build_stack_spec()` to extract `spoil_percent`, `health`, `durability`, and `ammo`, strictly guarding `tags` and `custom_description` access behind `is_item_with_tags` checks to prevent Factorio `__index` crashes on standard items.


### Revision: Hub Inventory Bar Support & Targeted Diverter Capacity Expansion
**Date:** 2026-08-31 15:01 (EDT)
**Context:** Enable visual container inventory bar clamping on Pneumatic Hubs for inserter deposition control and expand internal diverter capsule capacity to eliminate single-capsule queuing bottlenecks across junctions.
**Key Changes:**
1. **Hub Prototype Inventory Bar Slider (`prototypes/entity.lua`):** Updated `inventory_type` from `"with_filters"` to `"with_filters_and_bar"` on `capsule-hub-horizontal` and `capsule-hub-vertical` prototypes, enabling the red inventory bar slider in container GUIs for inserter deposition control while retaining item slot filtering.
2. **Inserter-Independent Cargo Packing (`scripts/hubs/hub-packing.lua`):** Maintained full-container slot scanning (`#inventory`) during hub packing evaluation, ensuring pneumatic capsule extractions process any items present in red-locked slots while inserters natively respect the bar limit for item insertion into the chest.
3. **Targeted Diverter Capacity Expansion (`scripts/diverter-settings.lua` & `scripts/capsules/capsule-motion.lua`):** Added `DEFAULT_CAPACITY = 2` and `get_capacity(unit_number)` to `diverter_settings`. Updated `has_entity_network_capacity()` in `capsule-motion.lua` to dynamically query diverter capacity limits via `storage.active_diverters`, allowing up to 2 capsules to queue/transit through multi-port diverters simultaneously while preserving strict single-capsule spacing across standard tubes, pumps, and hubs.


### Revision: Dual-Tier Spatial Grid Allocation, Zero-Fuzzy Unit Detection & Water Moat Isolation
**Date:** 2026-08-31 16:02 (EDT)
**Context:** Optimize off-grid surface chunk footprint for standard cargo, isolate unit-spoilable cargo within water moat island perimeters, eliminate fuzzy string matching risks, and align container entities dead-center on tile grids.
**Key Changes:**
1. **Dual-Tier Spatial Grid Engine (`scripts/surfaces/liminal-surface.lua` & `scripts/hubs/hub-packing.lua`):** Implemented separate wide (8-tile cell spacing, $y \ge 0$) and tight (2-tile slot spacing, $y \le -100$) coordinate domains. Standard non-spoilable/non-unit cargo packs into tight slots to shrink off-grid chunk footprint by ~75%, separated from wide unit cells by a 100-tile safety buffer zone.
2. **Centered 3×3 Island Platform & Symmetrical Moat (`scripts/surfaces/liminal-surface.lua`):** Configured `paint_cell_tiles()` to construct wide cells with a spacious 3×3 `lab-dark-1` island platform surrounded by a symmetrical 2-tile thick `water` moat. Applied `+0.5` tile coordinate offsets to align container entity centers dead-center on tile grids.
3. **Zero-Fuzzy Spoilable-Unit Inspection (`scripts/hubs/hub-packing.lua`):** Implemented `is_unit_spoilable()` using Factorio 2.0 C++ prototype property checks (`proto.spoil_to_trigger_result`) and explicit table lookups (`capsule_defs.is_unit_spoilable`), completely eliminating fuzzy string searching (`string.find`).
4. **Synchronized Dual-Pool Slot Recycling (`scripts/capsules/capsule-manager.lua` & `scripts/surfaces/liminal-surface.lua`):** Persisted `is_wide` spatial domain classification on capsule tracker objects, ensuring `capsule_manager.remove()` returns freed coordinates to their respective `wide_free_slots` or `tight_free_slots` pools.


### Revision: Distinct Capsule Type Color Overlay & Valid Render Layer Z-Ordering
**Date:** 2026-08-31 16:44 (EDT)
**Context:** Resolve invalid render layer crashes during debug rendering and implement distinct color rings for each capsule prototype variant to improve network visual diagnostics.
**Key Changes:**
1. **Distinct Capsule Type Colors (`scripts/capsules/capsule-definitions.lua` & `scripts/capsules/capsule-renderer.lua`):** Configured distinct RGBA debug overlay colors for each capsule variant (`item-capsule` = Gold, `biodegradable-capsule` = Emerald Green, `refrigerated-capsule` = Frost Cyan, `spent-refrigerated-capsule` = Slate Grey, `reinforced-capsule` = Violet Purple, `player-transit-capsule` = Crimson Orange). Added `capsule_defs.get_debug_color()` with fallback protections.
2. **Valid Engine Layer Hierarchy (`scripts/networks/networks-flow-renderer.lua`, `scripts/ports/port-renderer.lua`, `scripts/capsules/capsule-renderer.lua`):** Replaced non-existent layer strings with official Factorio C++ `RenderLayer` union names (`"lower-object-above-shadow"` for flow vectors & text, `"wires-above"` for port markers, `"entity-info-icon-above"` for capsule rings/icons, and `"light-effect"` for HUD text), resolving `Unknown layer name: overlay` crashes and ensuring capsules render in front of flow maps.
3. **Dynamic Spent State Color Invalidation (`scripts/capsules/capsule-renderer.lua`):** Bound `ring_color` into `cache` equality checks in `render()`, triggering instant visual color ring updates when a refrigerated capsule expires into a spent capsule mid-flight.


### Revision: Centralized Item Transfer Handler & Full Factorio 2.0 Metadata Engine
**Date:** 2026-08-31 17:03 (EDT)
**Context:** Consolidate redundant stack extractions, fallback inventory insertions, ground spills, equipment grid copies, and metadata specification builders across hub packing, unpacking, spilling, and lifecycle modules into a centralized utility handler, guaranteeing 100% preservation of vanilla Factorio 2.0 item metadata, equipment grids (`stack.grid`), quality, spoilage, durability, health, ammo, and custom tags.
**Key Changes:**
1. **Centralized Utility Handler (`scripts/utils/item-transfer-handler.lua`):** Implemented `item_transfer_handler` exporting `copy_equipment_grid()` (clones installed equipment, positions, quality, energy, and shield levels), `build_stack_spec()` (safely extracts Factorio 2.0 stack attributes guarded behind `is_item_with_tags`), `transfer_stack()` (executes native C++ `dest_slot.transfer_stack()` first, falling back to metadata specs and grid restoration), `transfer_inventory()` (performs batched bar-bounded inventory migrations), and `spill_stack()` (handles metadata-safe ground spills with deconstruction orders).
2. **Cargo Packing & Unpacking Refactoring (`scripts/hubs/hub-packing.lua` & `scripts/hubs/hub-unpacking.lua`):** Replaced duplicated internal grid copying, stack specs, and multi-slot loops with top-level `item_transfer_handler` calls. Maintained full `#inventory` scanning during hub packing to extract cargo sitting in red-locked slots, while enforcing container insertion bar limits (`get_bar() - 1`) during hub capture unpacking.
3. **Spill Engine & Refrigerated Lifecycle Standardization (`scripts/hubs/hub-spill.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Refactored container unloading and ground spills in `hub_spill` to delegate to `transfer_stack` and `spill_stack`. Standardized 60-tick refrigerated spoilage decay stack rebuilds and spent-tool conversions in `capsule_lifecycle` to utilize `build_stack_spec` and `copy_equipment_grid`.


### Revision: Fast-Looting Container Operability, Inventory Bar Clamping & GUI Suppression
**Date:** 2026-08-31 18:46 (EDT)
**Context:** Restore player Ctrl+Click fast-looting capabilities on spilled capsule containers while maintaining a strict one-way cargo retrieval model and zero-overhead periodic container cleanup.
**Key Changes:**
1. **Fast-Looting Operability & Bar Clamping (`prototypes/entity.lua` & `scripts/hubs/hub-spill.lua`):** Re-enabled `operable = true` on `visible-capsule-holder` to permit native Ctrl+Click fast entity transfer. Applied `container_inv.set_bar(1)` upon container creation, red-locking all inventory slots against manual item insertion while permitting native engine item extraction.
2. **Instant GUI Dismissal (`scripts/hubs/hub-spill.lua`):** Registered an `on_gui_opened` listener that sets `player.opened = nil` on the exact tick a spilled container is clicked, preventing access to the inventory GUI window and hiding the red bar slider.
3. **Copy-Paste & Pipette Setting Protection (`prototypes/entity.lua` & `scripts/hubs/hub-spill.lua`):** Added `"no-copy-paste"` to `visible-capsule-holder` prototype flags and registered an `on_entity_settings_pasted` listener to re-enforce `set_bar(1)` if chest settings are pasted onto a spilled container.


### Revision: Staged Time-Sliced Network Rebuild Engine & Batched Flow Updates
**Date:** 2026-08-31 19:09 (EDT)
**Context:** Eliminate tick spikes and frame drops during large network deconstructions and entity mining by replacing synchronous BFS graph traversals and immediate flow/pressure recalculations with a staged, time-sliced background rebuild engine.
**Key Changes:**
1. **Staged Rebuild Engine (`scripts/networks/network-rebuild-engine.lua`):** Created a background job processor managing `storage.network_rebuild_queue`, executing graph split checks incrementally under a per-tick node budget (350 nodes/tick) and coalescing network updates across ticks.
2. **Instant $O(1)$ Edge Severing (`scripts/networks/network-unmerge.lua` & `scripts/networks/network-invalidate.lua`):** Refactored entity removal and unmerge workflows to sever physical graph edges (`storage.port_connections`) and purge port definitions in constant time, delegating split checks to the rebuild engine queue.
3. **Coalesced Batched Rebuild Engine (`scripts/networks/networks-flow.lua`):** Added `networks_flow.build_batch()` to run multi-source pressure BFS calculations (`networks_pressure.process`), flow map updates (`build_single_network`), and spatial occupancy index updates (`capsule_queries.rebuild_occupancy_index()`) in a single consolidated pass across dirty networks.


### Revision: Batched Blueprint Placement Validation & Manager Rebuild Coalescing
**Date:** 2026-08-31 20:03 (EDT)
**Context:** Eliminate FPS/UPS drops and tick spikes during mass entity and blueprint placement by routing entity build validation and pump/diverter state updates into the batched network rebuild engine.
**Key Changes:**
1. **Deferred Validation Rebuilds (`scripts/networks/network-validate.lua`):** Refactored `network_validate.execute()` to replace synchronous per-entity `networks_flow.build()` invocations with $O(1)$ `network_rebuild_engine.mark_dirty(net_id)` tagging. Preserves instant spatial graph edge linking and network ID merges while deferring graph calculations.
2. **Coalesced State Sensitivity (`scripts/networks/pump-manager.lua` & `scripts/networks/diverter-manager.lua`):** Updated `rebuild_pump_networks` and `rebuild_diverter_networks` to route power, state, and port setting updates through `network_rebuild_engine.mark_dirty()`, eliminating repeated synchronous BFS sweeps on multi-port structures.

#### 0.3.0

### Revision: Flow Engine Entity Creation Listener
**Date:** 2026-09-01 13:27 (EDT)
**Context:** Add an entity placement listener for the new flow propagation system with integrated debug logging.
**Key Changes:**
1. **Entity Placement Listener (`scripts/flow/entity-listener.lua`):** Added event listener covering all entity creation triggers (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive`, `on_space_platform_built_entity`, `on_entity_cloned`). Filters for pneumatic structures using `port_defs.registered_names`.
2. **Debug Output (`scripts/flow/entity-listener.lua`):** Connected creation events to `debug_print` to print placement info (name, unit number, coordinates, surface) to chat when debug prints are active.
3. **Control Entrypoint (`control.lua`):** Registered `scripts.flow.entity-listener` at top level.


### Revision: Standardized Flow Engine Entity Lifecycle Listeners
**Date:** 2026-09-01 15:07 (EDT)
**Context:** Standardize and expand the new flow propagation system's entity lifecycle listeners into a symmetrical tri-module suite (`creation-listener`, `removal-listener`, and `state-listener`) inside `scripts/flow/`.
**Key Changes:**
1. **Creation Listener Rename & Standardization (`scripts/flow/creation-listener.lua`):** Renamed `entity-listener.lua` to `creation-listener.lua` for consistent naming across flow modules while keeping entity placement hook logic and debug logging intact.
2. **Removal Event Listener (`scripts/flow/removal-listener.lua`):** Created dedicated removal event listener covering player/robot mining, entity destruction, script destruction, and space platform entity mining (`on_space_platform_mined_entity`) for registered pneumatic entities with debug print output.
3. **State Change Event Listener (`scripts/flow/state-listener.lua`):** Created dedicated state change listener tracking orientation and flipping events (`on_player_rotated_entity`, `on_player_flipped_entity`) for registered pneumatic entities with debug print output.
4. **Control Entrypoint Registration (`control.lua`):** Updated top-level `require` declarations to import `creation-listener`, `removal-listener`, and `state-listener`.


### Revision: Flow Engine Port Definitions & Spatial Connection Manager
**Date:** 2026-09-01 15:32 (EDT)
**Context:** Add simplified port definitions and an event-driven connection manager to the new decoupled flow engine system (`scripts/flow/`), establishing direct port-to-port spatial linkage without legacy network BFS graph execution.
**Key Changes:**
1. **Lightweight Flow Port Definitions (`scripts/flow/port-defs.lua`):** Created standalone port definition registry containing cardinal tile offsets for all pneumatic structure variants (`capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, `pneumatic-diverter`) and exposed `registered_names` alongside `get_ports(entity)`.
2. **Spatial Connection Manager (`scripts/flow/connection-manager.lua`):** Implemented connection manager tracking active spatial port edges in `storage.flow_port_connections`. Listens to creation, removal, and state change listeners to dynamically record bidirectional links between adjacent matching ports, sever removed edges, and sync rotation/flip state transitions with integrated debug logging.
3. **Decoupled Lifecycle Listeners (`scripts/flow/creation-listener.lua`, `scripts/flow/removal-listener.lua`, `scripts/flow/state-listener.lua`):** Updated flow lifecycle event listeners to import `scripts/flow/port-defs` directly, isolating the new flow suite from legacy port definition dependencies.
4. **Control Entrypoint Registration (`control.lua`):** Registered `scripts.flow.port-defs` and `scripts.flow.connection-manager` at top level and initialized `storage.flow_port_connections` in `setup_storage()`.


### Revision: Console Debug Message Prefix Filter Commands
**Date:** 2026-09-01 15:46 (EDT)
**Context:** Add console commands to filter debug chat messages by prefix string, allowing developers to isolate log outputs for specific subsystems during testing.
**Key Changes:**
1. **Debug State & Filtering (`scripts/debug-manager.lua`):** Extended per-player debug storage schema with a `filter` field. Updated `debug_print` to validate incoming message strings against `dbg.filter` via prefix checking (`msg:sub(1, #dbg.filter) == dbg.filter`).
2. **Filter Management Commands (`scripts/debug-manager.lua`):** Registered `/debug-filter <text>` and `/debug-filter-reset` console commands with parameter quote-trimming logic and player chat status feedback.


### Revision: Water-Like Flow Propagation Engine & Overlay Debug System
**Date:** 2026-09-01 16:29 (EDT)
**Context:** Implement a rudimentary water-like BFS flow propagation engine through connected ports, add visual debug rendering overlays with Pneumatic Control Panel UI toggles, and resolve cyclic module dependency stack overflows.
**Key Changes:**
1. **Water-Like Flow Propagation Engine (`scripts/flow/flow-engine.lua`):** Created a BFS propagation module treating `pneumatic-pump` and `pneumatic-diverter` entities as flow emitters starting at maximum strength (10). Propagates flow across internal entity ports and external connected port edges (`storage.flow_port_connections`), decaying by 1 per hop down to 0, and maintaining runtime state in `storage.flow_levels`.
2. **Flow Debug Overlay & Control Panel Toggle (`scripts/debug-manager.lua` & `scripts/flow/flow-engine.lua`):** Integrated cyan circle markers, numerical flow level text, and connection lines drawn on official rendering layers. Added `new_flow` debug state toggles, console commands (`/toggle-new-flow`, `/pt-toggle-new-flow`), hotbar shortcut sync, and a `"New Flow Engine (Alt Mode)"` checkbox in the Pneumatic Control Panel GUI.
3. **Surface Registration & Entrypoint Integration (`control.lua`):** Registered `scripts.flow.flow-engine` at top level, added schema initialization for `flow_entities`, `flow_emitters`, `flow_levels`, and `new_flow_render_objects`, and added surface entity scanning on `on_init` / `on_configuration_changed`.
4. **Cyclic Require Stack Overflow Fix (`scripts/flow/*`):** Removed redundant `require("scripts.debug-manager")` statements from `creation-listener.lua`, `removal-listener.lua`, `state-listener.lua`, `connection-manager.lua`, and `flow-engine.lua`. Leveraged global `debug_print` access to break cyclic require loops during top-level module loading.


### Revision: Event-Driven Delta Flow Engine & Spatial Port Registry
**Date:** 2026-09-01 18:47 (EDT)
**Context:** Replace instant global BFS graph sweeps with an event-driven delta wavefront flow propagation engine and an O(1) multi-port spatial coordinate registry.
**Key Changes:**
1. **Multi-Port Spatial Registry (`scripts/flow/connection-manager.lua`):** Replaced `surface.find_entities_filtered` queries with O(1) spatial coordinate string lookups (`storage.flow_port_registry`). Converted port storage at tile coordinates into a multi-port dictionary (`{ [port_key] = port_data }`) so co-located ports do not overwrite each other during placement or rotation, ensuring clean connection severing upon entity removal.
2. **Event-Driven Delta Wavefront Engine (`scripts/flow/flow-engine.lua`):** Replaced synchronous global BFS sweeps with a 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue`. Flow propagates outward from active emitters (`MAX_FLOW = 10`) at 60 tiles/second until reaching steady-state equilibrium. When no levels change or the network is idle, `storage.flow_queue` empties, allowing `step()` to return on line 1 for 0-UPS idle performance.
3. **Drain Wavefront & Removal Handling (`scripts/flow/flow-engine.lua` & `scripts/flow/connection-manager.lua`):** Entity creation, removal, and rotation events enqueue affected local ports into `storage.flow_queue`. Severed tube connections trigger a tile-by-tile downstream drain wave (`compute_entity_flow_level()`), cleanly clearing cut-off flow values to zero frame-by-frame before returning the engine to sleep.
4. **GUI Display Crash Prevention (`scripts/flow/flow-engine.lua`):** Added `get_player_object_and_index` parameter resolution in `draw_for_player` and `clear_all` to safely handle both integer player indices and `LuaPlayer` object handles passed from Pneumatic Control Panel GUI check events (`on_gui_checked_state_changed`).


### Revision: Flow Propagation Batching, Negative Pressure & Spatial Disconnection Updates
**Date:** 2026-09-01 19:34 (EDT)
**Context:** Add time-sliced batching to the flow queue, introduce negative flow values for pump intake ports, throttle visual overlay updates, and revise entity disconnection handling for rotated and flipped structures.
**Key Changes:**
1. **Flow Queue Batching (`scripts/flow/flow-engine.lua`):** Added a per-tick execution limit (`BATCH_SIZE = 50`) to `flow_engine.step()`, spreading queue processing across ticks during large placement events.
2. **Negative Flow & Emitter Levels (`scripts/flow/port-defs.lua` & `scripts/flow/flow-engine.lua`):** Assigned directional `flow = -10` (intake) and `flow = 10` (output) attributes to `pneumatic-pump` ports in `port-defs.lua`. Updated `compute_port_flow_level` to calculate negative flow levels (-10 up to -1) alongside positive pressure (+10 down to +1) and resolve opposing magnitudes.
3. **Throttled Overlay Redraws (`scripts/flow/flow-engine.lua`):** Added `flow_render_dirty` tracking to throttle full overlay redraws (`flow_engine.redraw_all()`) to 15-tick intervals during active sweeps or when the queue empties. Color-coded positive levels (Blue/Cyan) and negative levels (Orange/Red).
4. **Unit Port Coordinate Tracking (`scripts/flow/connection-manager.lua` & `control.lua`):** Added `storage.flow_unit_ports` to record tile coordinates upon connection. Updated `disconnect_entity` to clean up registered ports, severed connections, and port levels using recorded tile coordinates during entity removal, rotation, and flip events.


### Revision: Flow Engine Consolidation & Granular Spatial Topology Management
**Date:** 2026-09-01 21:30 (EDT)
**Context:** Consolidate the distributed flow simulation system into a unified, high-performance engine (`scripts/flow/flow-engine.lua`), removing redundant listener/manager modules and replacing full visual redraw sweeps with targeted O(1) render updates.
**Key Changes:**
1. **Module Consolidation & File Cleanup (`scripts/flow/`):** Removed `connection-manager.lua`, `creation-listener.lua`, `removal-listener.lua`, and `state-listener.lua`. Consolidated entity lifecycle handling, connection graph tracking, and port wavefront propagation directly inside `scripts/flow/flow-engine.lua`.
2. **Spatial Grid Topology (`scripts/flow/flow-engine.lua`):** Implemented a coordinate-indexed spatial lookup (`flow_grid`, `flow_nodes`, `flow_connections`) using formatted string position keys (`surface@x,y`). Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent entities.
3. **Granular Rendering Pipeline (`scripts/flow/flow-engine.lua`):** Replaced bulk visual redraws with direct O(1) single-port and single-edge object mutations (`update_port_render`, `update_edge_render`, `destroy_port_renders`, `destroy_edge_render`). Render circles, flow level text, and link lines update dynamically on state change per player index rather than triggering map-wide sweeps.
4. **Mod Lifecycle Cleanup (`control.lua`):** Simplified mod initialization and configuration change hooks (`setup_storage`). Removed legacy sub-table initialization and storage keys (`flow_port_registry`, `flow_entities`, `flow_emitters`), delegating entity registration directly to `flow_engine.connect_entity(entity)`.


### Revision: Flow Engine Entity Flavor & Structural Port Group Architecture
**Date:** 2026-09-01 22:05 (EDT)
**Context:** Restore original port group structure across pneumatic entities, implement explicit non-transmitting hub behavior, and update wavefront propagation logic to respect internal group transmission boundaries without legacy graph overhead.
**Key Changes:**
1. **Port Group & Transmission Definitions (`scripts/flow/port-defs.lua`):** Assigned `group = 1` across all port definitions for hubs, tubes, pumps, junctions, and diverters. Restored split internal groups (`group = 1` for vertical, `group = 2` for horizontal) on `crossflow-junction`. Added `transmit = false` attribute to hub port definitions to block internal flow bridging across hub ports.
2. **Node Metadata & Group Transmission (`scripts/flow/flow-engine.lua`):** Updated `connect_entity` to cache `node.group` and `node.transmit`. Updated `compute_port_flow_level` to permit internal port sampling only when both ports are transmitting and share matching non-nil group IDs (`can_transmit_internally`), while allowing non-transmitting hub ports to sample their own direct external connections (`is_self`).
3. **Targeted Wavefront Queueing (`scripts/flow/flow-engine.lua`):** Refined `flow_engine.step` so that state changes on a port only enqueue sister internal ports if both ports are transmitting and share the same internal group ID, suppressing unnecessary queue ticks for non-transmitting hubs and isolated crossflow pairs.


### Revision: Startup Flow Version Setting & Debug Panel Version Guards
**Date:** 2026-09-01 22:58 (EDT)
**Context:** Add a startup mod setting to toggle between legacy (v1) and event-driven wavefront (v2) flow engines, implementing modular event registration and updating the Pneumatic Control Panel to safely adapt UI toggles per engine version.
**Key Changes:**
1. **Startup Mod Setting (`settings.lua` & `locale/en/config.cfg`):** Created `settings.lua` registering the `pneumatic-flow-version` startup string setting (`v1` vs `v2`, default `v1`). Added corresponding localized titles and descriptions under `[mod-setting-name]` and `[mod-setting-description]` in `locale/en/config.cfg`.
2. **Modular Event Registration (`scripts/flow/flow-engine.lua` & `control.lua`):** Encapsulated v2 tick and spatial topology event listeners into `flow_engine.register_events()`. Updated `control.lua` to only invoke `register_events()`, `flow_engine.init_storage()`, and surface spatial scans when `pneumatic-flow-version` is set to `v2`.
3. **Debug Panel Version Guards & Method Correction (`scripts/debug-manager.lua`):** Corrected `flow_engine.clear_all` calls to `flow_engine.clear_all_renders`. Guarded v2 overlay render commands behind `FLOW_VERSION == "v2"` and hid the "New Flow Engine" checkbox in the Pneumatic Control Panel when running in `v1` mode, preventing runtime GUI crashes.


### Revision: Symmetrical Flow Engine Event Gating & v1 Lifecycle Isolation
**Date:** 2026-09-01 23:34 (EDT)
**Context:** Isolate legacy (v1) network topology construction, background graph rebuilding, and capsule movement loops when running in v2 flow mode, establishing symmetrical internal version guards across both engines.
**Key Changes:**
1. **v1 Network Topology Event Gating (`scripts/networks/network-connect.lua`, `scripts/networks/network-disconnect.lua`, `scripts/networks/network-rotate.lua`):** Guarded network connect, disconnect, and rotation event listeners behind `FLOW_VERSION == "v1"`. Disables v1 graph validation and edge invalidation on placement/mining/rotation when running in `v2` mode while preserving hub cargo spilling and pump/diverter orientation notifications.
2. **Staged Rebuild Engine Gating (`scripts/networks/network-rebuild-engine.lua`):** Guarded the time-sliced background graph rebuild `on_tick` processor (`network_rebuild_engine.step`) behind `FLOW_VERSION == "v1"`, preventing graph split checks and v1 flow map updates during `v2` operation.
3. **v1 Capsule Motion Runner Gating (`scripts/capsules/capsule-runner.lua`):** Guarded v1 tick updates (`update_capsules`), liminal surface spawn listeners, and `networks_flow` listener registrations behind `FLOW_VERSION == "v1"`. Silences v1 capsule movement and segment interpolation during `v2` mode while keeping module helper functions exported.
4. **v2 Flow Engine Internal Self-Guarding (`scripts/flow/flow-engine.lua` & `control.lua`):** Added internal `FLOW_VERSION == "v2"` guards inside `flow_engine.register_events()`, `init_storage()`, `connect_entity()`, `disconnect_entity()`, and `draw_all()`, making `flow-engine.lua` self-contained and symmetrical with v1 modules. Guarded legacy `networks_flow.draw_all()` call in `control.lua` behind `FLOW_VERSION == "v1"`.


### Revision: v2 Flow Engine Capsule Runner & Hub Packing Integration
**Date:** 2026-09-02 08:45 (EDT)
**Context:** Implement the foundational v2 flow engine capsule runner module and integrate hub packing delegation across v1 and v2 flow engines with debug logging.
**Key Changes:**
1. **v2 Capsule Runner Module (`scripts/flow/capsule-runner.lua`):** Created dedicated v2 capsule runner handling outbound hub port resolution (`find_best_hub_outbound_port`), capsule injection (`inject_from_hub`), parked capsule wakeup, tick frame rendering updates, and event registration. Evaluates active port flow levels while defaulting fallback to internal hub port 1 (`unit_number .. ":1"`), allowing disconnected hubs to pack capsules onto internal nodes. Includes `debug_print` output logging successful packaging onto the v2 flow engine.
2. **Capsule Runner Facade Delegation (`scripts/capsules/capsule-runner.lua`):** Added `FLOW_VERSION == "v2"` version routing inside `inject_from_hub` and `wake_parked_capsules` to forward calls to `scripts/flow/capsule-runner.lua` when running in v2 mode while keeping v1 runtime logic fully intact.
3. **v2 Event Registration & Top-Level Require (`control.lua`):** Required `scripts/flow/capsule-runner.lua` at top level and registered `v2_capsule_runner.register_events()` when startup setting `pneumatic-flow-version` is set to `v2`.


### Revision: v2 Flow Engine Granular Capsule Runner & Facade Synchronization
**Date:** 2026-09-02 09:17 (EDT)
**Context:** Implement discrete node-to-node capsule movement for the v2 flow engine with pressure gradient target selection, diverter filter lookahead, O(1) hub arrival capture, and facade routing synchronization.
**Key Changes:**
1. **v2 Granular Node Hop Runner (`scripts/flow/capsule-runner.lua`):** Implemented discrete node-to-node hop movement executing every 6 ticks (staggered per capsule ID) with multi-hop processing (`MAX_NODE_HOPS_PER_STEP = 3`) for internal entity transitions, continuous passenger position synchronization, and unused progress schema preservation.
2. **Flow Gradient Target Selection & Filter Lookahead (`scripts/flow/capsule-runner.lua`):** Created candidate target selector (`select_next_target`) evaluating positive pressure drop (`level_from - level_cand`), intake vacuum pull, compiled diverter filters, and downstream path validation (`is_hop_valid`) to prevent capsules from entering machines without open exits.
3. **O(1) Hub Arrival & Capture Engine (`scripts/flow/capsule-runner.lua`):** Integrated O(1) hub entity lookup via `storage.active_hubs` in `handle_arrival` for capsule capture/unpacking, liminal unit spoilage re-instantiation, and player passenger emergency eject (`emergency_eject`).
4. **Facade Router Delegation (`scripts/capsules/capsule-runner.lua`):** Updated facade module functions `get_capsule_location`, `emergency_eject`, and `remove_capsule` to delegate to `scripts/flow/capsule-runner.lua` when running in `v2` mode.


### Revision: v2 Flow Engine Gradient-Driven Motion & Emitter Traversal
**Date:** 2026-09-02 09:51 (EDT)
**Context:** Eliminate capsule oscillation ("dancing") in zero-gradient flow zones, unpowered networks, and dead ends under the v2 flow engine by enforcing strict positive pressure drop requirements and metadata-based emitter traversal.
**Key Changes:**
1. **Strict Pressure Gradient Filtering (`scripts/flow/capsule-runner.lua`):** Updated `select_next_target` to require a strictly positive flow drop (`drop > 0`) for candidate target selection, preventing capsules from endlessly wandering across flat-level or unpowered tube networks.
2. **Dead-End & Unpowered Motion Suppression (`scripts/flow/capsule-runner.lua`):** Removed unconditional fallback backtracking and allowed capsules to park cleanly (`return nil`) when no outbound hop offers an active positive flow drop.
3. **Metadata-Based Emitter & Diverter Traversal (`scripts/flow/capsule-runner.lua`):** Leveraged `node.emitter` metadata attributes rather than entity name matching to handle internal pump push (`emitter < 0` to `emitter > 0` with `drop = math.huge`) and evaluate downstream diverter output lookahead (`effective_from = cand_node.emitter`), routing capsules smoothly through active output branches.


### Revision: v2 Flow Engine Stale Motion Reset & Backtracking Cleanup
**Date:** 2026-09-02 10:28 (EDT)
**Context:** Resolve capsule lockups and stagnation when flow reverses or changes direction under the v2 flow engine by clearing stale origin port memory upon parking and target wakeups.
**Key Changes:**
1. **Wakeup Backtracking Reset (`scripts/flow/capsule-runner.lua`):** Updated `capsule_runner_v2.wake_parked_capsules` to reset `capsule.last_port_key = nil` alongside `next_retry_tick` and `last_failed_hub` whenever capsules are woken by flow updates, pump/diverter state edits, or network events.
2. **Parked State Backtracking Reset (`scripts/flow/capsule-runner.lua`):** Updated `update_capsules` to set `capsule.last_port_key = nil` when `select_next_target` returns `nil` and a capsule enters a parked state, ensuring newly reversed pressure drops (`drop > 0`) can be cleanly selected on subsequent step evaluations.


### Revision: Data-Driven Decoupled Hub Cross-Transit Architecture
**Date:** 2026-09-02 10:54 (EDT)
**Context:** Decouple gas flow transmission (`transmit = false`) from capsule motion (`cross_transit = true`), enabling data-driven hub pass-through traversal under the v2 flow engine without entity hardcoding.
**Key Changes:**
1. **Port Definition Cross-Transit Attribute (`scripts/flow/port-defs.lua`):** Added `cross_transit = true` attribute to `capsule-hub-horizontal` and `capsule-hub-vertical` port definitions, declaring capsule internal crossing permission independently from gas/flow level propagation.
2. **Spatial Node Property Caching (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to cache `cross_transit = (port.cross_transit == true)` directly onto `storage.flow_nodes` descriptors during entity registration.
3. **Data-Driven Candidate Resolution & Target Shifting (`scripts/flow/capsule-runner.lua`):** Refactored `get_candidate_hops`, `select_next_target`, and `find_best_hub_outbound_port` to evaluate `node.cross_transit` instead of hardcoded `is_hub` entity checks. Capsules at cross-transit nodes inspect all external exit ports, calculate baseline pressure drops against the entity's maximum flow level, and dynamically shift origin port keys to pass through the path offering the strongest outbound gradient.


### Revision: Stage 1 $O(1)$ Spatial Parked Index & Targeted Neighbor Wakeups
**Date:** 2026-09-02 11:27 (EDT)
**Context:** Eliminate map-wide O(N) capsule sweeps in wake_parked_capsules, restore 6-tick motion staggering breakdown, and introduce constant-time spatial parked capsule indexing to scale the v2 flow engine.
**Key Changes:**
1. **Spatial Parked Index Initialization (`scripts/flow/flow-engine.lua` & `control.lua`):** Initialized `storage.parked_by_port = {}` schema in `flow_engine.init_storage()` and `control.lua`. Added automatic re-indexing for existing parked v2 capsules during storage setup and savegame migration.
2. **Parked Lifecycle Tracking (`scripts/flow/capsule-runner.lua`):** Implemented `mark_capsule_parked` and `mark_capsule_unparked` helper functions. Registered capsules in `storage.parked_by_port` upon failed target selection or initial hub injection, and cleanly untracked them when moving, arriving at a destination, or being removed.
3. **Targeted O(1) Neighbor Wakeups (`scripts/flow/capsule-runner.lua`):** Rewrote `capsule_runner_v2.wake_parked_capsules(target)` to inspect strictly target port keys, sister unit ports (`storage.flow_unit_ports`), and adjacent flow connections (`storage.flow_connections`), completely eliminating `pairs(storage.capsules)` map sweeps.
4. **Stagger Timer Protection (`scripts/flow/capsule-runner.lua`):** Enforced parked-only retry timer resets (`to_port_key == nil`), preventing active moving capsules from having their 6-tick motion stagger timers wiped by nearby hops.


# Revision Entry
### Revision: Stage 2 Zero-Allocation Scratch Buffers in Pathfinding & Hop Evaluation
**Date:** 2026-09-02 11:43 (EDT)
**Context:** Eliminate Lua Garbage Collection (GC) table churn and memory allocations during active capsule pathfinding, downstream hop evaluation, and neighbor wakeups in the v2 flow engine.
**Key Changes:**
1. **Module-Level Persistent Scratch Buffers (`scripts/flow/capsule-runner.lua`):** Initialized persistent top-level scratch tables (`scratch_cand_keys`, `scratch_cand_vias`, `scratch_cand_is_ext`, `scratch_cand_counts`, `scratch_best_keys`, `scratch_best_vias`, `scratch_best_is_ext`, `scratch_best_count`, `scratch_ports_to_wake`) to eliminate temporary table object creation (`{}`) during runtime movement.
2. **Tier-Indexed Candidate Hop Resolution (`scripts/flow/capsule-runner.lua`):** Refactored `get_candidate_hops` to populate tiered scratch arrays by candidate evaluation depth (tiers 1–3), avoiding buffer overwrites during nested machine exit checks in `is_hop_valid` and `select_next_target`.
3. **Max-Drop Candidate Selection & Wakeup Optimization (`scripts/flow/capsule-runner.lua`):** Refactored `select_next_target`, `wake_parked_capsules`, and `find_best_hub_outbound_port` to score pressure drops, resolve neighbor wakeups, and fetch port keys directly from scratch buffers and `storage.flow_unit_ports`, removing GC allocations from runtime path evaluation.


### Revision: Flow v2 Wavefront Engine Idle Sleep & Fast-Path Debug Render Guards
**Date:** 2026-09-02 12:09 (EDT)
**Context:** Implement Stage 3 performance optimizations for the v2 flow engine, adding fast-path debug rendering short-circuits and validating 0-tick idle sleep behavior for steady-state networks.
**Key Changes:**
1. **Fast-Path Debug Overlay Guards (`scripts/flow/flow-engine.lua`):** Added `if not is_debug_active("new_flow") then return end` as a line-1 short-circuit in `update_port_render()` and `update_edge_render()`. Bypasses string key formatting (`make_edge_key`), spatial node table queries, and player loop iterations when debug overlays are disabled.
2. **0-Tick Queue Sleep Validation (`scripts/flow/flow-engine.lua`):** Validated line-2 queue emptiness checks (`if not storage.flow_queue or next(storage.flow_queue) == nil then return end`) in `flow_engine.step(tick)`, ensuring 0.00 ms CPU overhead and 0 Lua GC table allocations during steady-state ticks.
3. **Steady-State Propagation Convergence (`scripts/flow/flow-engine.lua`):** Confirmed `target_level ~= current_level` delta gating inside batch processing, ensuring unchanged port levels do not re-enqueue internal or external neighbor ports into `storage.flow_queue`.


### Revision: Flow v2 Engine Power & Circuit State Sensitivity Integration
**Date:** 2026-09-02 13:00 (EDT)
**Context:** Restore electrical power requirements and circuit network state sensitivity for pneumatic pumps and diverters under the Flow v2 wavefront propagation engine, maintaining zero-allocation performance and preserving legacy v1 behavior.
**Key Changes:**
1. **Dynamic Emitter Flow Evaluation (`scripts/flow/flow-engine.lua`):** Created `flow_engine.get_node_emitter_level(node)` and `flow_engine.enqueue_unit_ports(unit_number)`. Updated `compute_port_flow_level` to dynamically evaluate active machine power (`entity.energy > 0`), circuit enable toggles, and diverter port modes (`"input"` vs `"output"`) using O(1) storage cache lookups, returning 0 flow level for unpowered or disabled ports.
2. **v2 Event-Driven State Manager Delegation (`scripts/networks/pump-manager.lua` & `scripts/networks/diverter-manager.lua`):** Updated `rebuild_pump_networks` and `rebuild_diverter_networks` to branch on `FLOW_VERSION == "v2"`, forwarding power and circuit state changes to v2 port enqueues (`enqueue_unit_ports`) and targeted parked capsule wakeups (`wake_parked_capsules`).
3. **Motion Engine Power & Hop Gating (`scripts/flow/capsule-runner.lua`):** Updated `is_hop_valid` to reject movement into unpowered or disabled machine ports. Refactored `select_next_target` so internal pump push (`drop = math.huge`) and downstream diverter exit lookahead (`effective_from`) evaluate dynamic active emitter levels instead of static prototype definitions.


### Revision: Flow v2 Alt Mode Rendering Sensitivity & v1 Debug Panel Gating
**Date:** 2026-09-02 14:04 (EDT)
**Context:** Ensure Flow v2 visual debug overlays natively respect Factorio Alt Mode settings and remove legacy v1-specific debug controls from the Pneumatic Control Panel frame when operating in v2 flow mode.
**Key Changes:**
1. **Alt Mode Render Flags (`scripts/flow/flow-engine.lua`):** Added `only_in_alt_mode = true` parameter to `rendering.draw_circle`, `rendering.draw_text`, and `rendering.draw_line` calls in `update_port_render` and `update_edge_render`. Overlays now automatically hide when players toggle off Alt Mode.
2. **v1 Debug Panel Control Removal (`scripts/debug-manager.lua`):** Guarded `pneumatic_debug_chk_flow` (v1 Flow Overlay) and `pneumatic_debug_chk_ports` (v1 Port Markers) UI checkboxes behind `FLOW_VERSION == "v1"` in `open_panel` and `refresh_panel`. When v2 is selected, legacy v1 controls are omitted from the Pneumatic Control Panel.
3. **Symmetrical Shortcut & Command Event Gating (`scripts/debug-manager.lua`):** Updated `update_player_shortcuts`, `toggle_master`, `toggle_flow`, `toggle_ports`, and `on_gui_checked_state_changed` to condition v1 port and flow rendering triggers behind `FLOW_VERSION == "v1"`, isolating v1 and v2 debug overlay behavior.


### Revision: Default v2 Flow Engine & Debug Panel Overlay Standardization
**Date:** 2026-09-02 14:30 (EDT)
**Context:** Promote the event-driven v2 flow engine to the default startup setting, enable the flow vector overlay by default, and remove legacy "New" phrasing across debug panel UI captions and command feedback.
**Key Changes:**
1. **Default Startup Engine Setting (`settings.lua`):** Updated `pneumatic-flow-version` default setting value from `"v1"` to `"v2"`.
2. **Debug Panel UI Caption (`scripts/debug-manager.lua`):** Updated the v2 flow overlay checkbox label in `open_panel` from `"New Flow Engine (Alt Mode)"` to `"Flow Engine (Alt Mode)"`.
3. **Default Overlay Enabled (`scripts/debug-manager.lua`):** Updated `get_debug()` to default `new_flow = true` for new player debug storage initializations and missing schema fallbacks.
4. **Command & Chat Feedback Cleanups (`scripts/debug-manager.lua`):** Sanitized chat status print feedback and command descriptions for `/toggle-new-flow` and `/pt-toggle-new-flow` to standardize messaging.


### Revision: Flow v2 Entity Destruction Registration & Silent Sandbox Purge
**Date:** 2026-09-02 20:07 (EDT)
**Context:** Register pneumatic entities with script.register_on_object_destroyed to cleanly purge flows, capsules, and liminal item holders during bulk entity deletions (such as Sandbox mode "remove all entities", chunk deletions, or direct script destructions) without spilling cargo onto the ground.
**Key Changes:**
1. **Object Destruction Mapping (`scripts/flow/flow-engine.lua` & `control.lua`):** Initialized `storage.object_destruction_map` schema in `control.lua` and `flow-engine.lua`. Updated `flow_engine.connect_entity` to register valid pneumatic structures with `script.register_on_object_destroyed(entity)` during entity placement and surface setup scans, mapping registration IDs to entity unit numbers.
2. **Object Destruction Event Handler (`scripts/flow/flow-engine.lua`):** Registered `defines.events.on_object_destroyed` event listener. Implemented `flow_engine.handle_object_destroyed(unit_number)` to query active/parked capsules, safely destroy linked liminal item holders on `liminal_surface` (`capsule_manager.remove`) without spilling cargo, disconnect flow engine ports (`disconnect_entity`), and clear active machine tracking tables.
3. **Idempotent Deconstruction Fallback (`scripts/flow/flow-engine.lua`):** Preserved standard cargo spilling for routine player/robot mining and combat death events while utilizing `on_object_destroyed` as a silent fallback when entities are destroyed without standard mining events firing.


### Revision: Liminal Holder Destruction Registration & Silent v2 Flow Purge
**Date:** 2026-09-02 21:01 (EDT)
**Context:** Register liminal item holder entities with script.register_on_object_destroyed so that when liminal surface entities are wiped (e.g., via sandbox "remove all entities", chunk deletions, or script destructions), linked capsules, spatial occupancy, and passenger references are cleanly purged from the v2 flow engine without leaving orphan tracking data or stalling tube traffic.
**Key Changes:**
1. **Liminal Holder Object Destruction Registration (`scripts/capsules/capsule-manager.lua` & `control.lua`):** Updated `capsule_manager.register` to invoke `script.register_on_object_destroyed(holder_entity)` and record registration IDs in `storage.object_destruction_map` as `{ type = "capsule", id = capsule_id }`. Updated `setup_storage()` in `control.lua` to re-register active capsule holders during save game loads and configuration changes.
2. **Typed Destruction Mapping (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to store object destruction entries as `{ type = "entity", unit_number = unit_number }`, allowing `defines.events.on_object_destroyed` to distinguish between pneumatic structures and liminal capsule holders while preserving backwards compatibility for legacy numeric entries.
3. **Silent Capsule Destruction Handler (`scripts/flow/flow-engine.lua`):** Created `flow_engine.handle_capsule_destroyed(capsule_id)` to handle holder deletion events. Unparks the capsule from `storage.parked_by_port`, teleports riding passengers (`cap.passenger`) to a safe ground position, clears spatial occupancy (`capsule_queries.remove_capsule`), releases off-grid liminal positions (`capsule_manager.remove`), and automatically wakes upstream parked capsules waiting at the target port key to prevent network flow lockups.

#### next ver


