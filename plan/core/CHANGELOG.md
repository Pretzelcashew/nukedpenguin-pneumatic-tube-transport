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

#### 0.3.1

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


### Revision: Stage 4 v1 Engine Removal — v2 Runner Consolidation & Query Decoupling
**Date:** 2026-09-03 11:00 (EDT)
**Context:** Complete Stage 4 of the v1 engine removal plan by consolidating the v2 capsule runner implementation directly into `scripts/capsules/capsule-runner.lua`, purging obsolete `FLOW_VERSION` gating checks across the v2 suite, decoupling `capsule-queries.lua` from legacy network/port definitions, deleting redundant script layers, and updating top-level entry point bindings.
**Key Changes:**
1. **Runner Implementation Consolidation (`scripts/capsules/capsule-runner.lua`):** Transferred the complete v2 motion runner engine, spatial parked index management, zero-allocation pathfinding scratch buffers, and event handlers into `scripts/capsules/capsule-runner.lua`, and deleted the obsolete `scripts/flow/capsule-runner.lua`.
2. **Occupancy Query & Topology Decoupling (`scripts/capsules/capsule-queries.lua`):** Removed legacy `scripts.networks` and `scripts.ports.port-definitions` imports. Refactored `get_port_group()` and `get_port_descriptor()` to query v2 spatial `storage.flow_nodes` topology directly.
3. **Legacy Flow Version Gating Purge (`scripts/capsules/capsule-runner.lua`, `scripts/flow/flow-engine.lua`):** Purged stale `FLOW_VERSION` gating checks (`FLOW_VERSION ~= "v2"`) across stepper functions, renderers, and event registrations to establish v2 as the sole execution path.
4. **Control Entry Point Alignment (`control.lua`):** Updated top-level imports in `control.lua` to require `scripts.capsules.capsule-runner` directly and register its event listeners alongside `flow_engine.register_events()`.


### Revision: Spillage Restoration, Passenger Safety & Dependency Cycle Resolution
**Date:** 2026-09-03 11:29 (EDT)
**Context:** Restore cargo spillage, passenger disembarkation, and parked traffic wakeups across all pneumatic network structures upon entity mining or destruction, while resolving circular `require` dependency loops between runner, lifecycle, flow, and spillage modules.
**Key Changes:**
1. **Leaf Query Unparking & Traffic Wakeups (`scripts/capsules/capsule-queries.lua`):** Expanded `capsule_queries.remove_capsule` to unpark capsules from `storage.parked_by_port`, clear visual debug renders, unregister occupancy tracking, and wake upstream parked capsules waiting at the freed port key.
2. **Acyclic Removal Event Dispatching (`scripts/hubs/hub-spill.lua`):** Registered entity removal event listeners (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`, `on_space_platform_mined_entity`) directly inside `hub-spill.lua`. Purged the top-level `capsule-runner` import to break the `capsule-runner` → `capsule-lifecycle` → `hub-spill` → `capsule-runner` module load recursion loop.
3. **Flow Engine & Hub Manager Decoupling (`scripts/flow/flow-engine.lua` & `scripts/hubs/hub-manager.lua`):** Removed top-level `hub-spill` imports from `flow-engine.lua`, allowing `flow-engine.disconnect_entity` to manage spatial flow topology while `hub-spill` independently handles entity destruction spillage. Streamlined `hub-manager.lua` to avoid duplicate spillage execution passes.


### Revision: Centralized Proxy Linkage Engine (Stage 1 Refactor)
**Date:** 2026-09-03 12:10 (EDT)
**Context:** Modularize proxy entity lifecycle management, orientation sync, spatial destruction, space platform building, and GUI opening handlers to eliminate duplicated prototype event listeners.
**Key Changes:**
1. **Centralized Proxy Engine (`scripts/proxy-manager.lua`):** Created a registry-based engine (`proxy_manager.register_pair`) that centrally listens to build, destruction, rotation, flip, cloning, and GUI opening events, managing hidden circuit proxies dynamically.
2. **Device Registration (`scripts/proxy-manager.lua`):** Registered default circuit proxy specifications for `pneumatic-pump` and `pneumatic-diverter`, delegating GUI opening directly to `pump_gui.open` and `diverter_gui.open`.
3. **Control Entry Point Cleanup (`control.lua`):** Deprecated individual linkage script imports (`pneumatic-diverter-proxy-linkage.lua` and `pneumatic-pump-proxy-linkage.lua`) and initialized the central engine via `proxy_manager.register_events()`.


### Revision: Unified Active Device Scanner Engine (Stage 2 Refactor)
**Date:** 2026-09-03 12:26 (EDT)
**Context:** Consolidate background 15-tick power and circuit scanning for active machines into a unified registry-based scanner engine (`scripts/active-device-scanner.lua`), eliminating duplicate event loops and state evaluation code across individual machine managers.
**Key Changes:**
1. **Centralized Active Device Scanner (`scripts/active-device-scanner.lua`):** Created a unified 15-tick background scanner supporting extensible device specification registration (`register_device_type`). Handles entity lifecycle hooks (build, destroy, rotate, flip, space platform, cloned) and exposes a centralized `notify_settings_changed(entity)` notification API.
2. **Pump & Diverter Specifications (`scripts/active-device-scanner.lua`):** Registered default device state evaluators for `pneumatic-pump` and `pneumatic-diverter` to monitor power and circuit enable states, clear compiled filter caches, enqueue unit ports into `flow_engine`, and wake parked capsules.
3. **Control Entry Point & Manager Deprecation (`control.lua`, `scripts/pump-manager.lua`, `scripts/diverter-manager.lua`):** Replaced individual `pump-manager` and `diverter-manager` imports in `control.lua` with `active_device_scanner.register_events()`. Replaced legacy manager scripts with lightweight backward-compatible stubs that forward GUI notifications directly to `active_device_scanner`.
4. **GUI Callback Integration (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`):** Updated Pump and Diverter configuration GUIs to trigger immediate state re-evaluations and queue wakeups via `active_device_scanner.notify_settings_changed(entity)`.


### Revision: Reusable GUI Component Builder (Stage 3 Refactor)
**Date:** 2026-09-03 12:32 (EDT)
**Context:** Standardize Lua GUI creation, relative/screen window anchoring, title headers, circuit condition panels, item filter slots, and mode switches into a declarative Factorio 2.1 UI widget library (`scripts/utils/gui-components.lua`) to eliminate duplicate layout boilerplate across device configuration interfaces.
**Key Changes:**
1. **Reusable Widget Builder Library (`scripts/utils/gui-components.lua`):** Created a centralized component module exporting UI construction functions (`create_relative_window`, `add_header`, `add_card_frame`, `add_wire_channel_toggles`, `add_circuit_condition_panel`, `add_filter_slot`, `add_labeled_switch`).
2. **Standardized Comparators & Formatting (`scripts/utils/gui-components.lua`):** Exported canonical comparator lists (`=`, `≥`, `≤`, `>`, `<`, `≠`), index lookup helpers, active/inactive color constants (`COLOR_ACTIVE`, `COLOR_INACTIVE`), and label state update helpers (`format_active_label`, `update_switch_labels`).
3. **Condition State Serialization (`scripts/utils/gui-components.lua`):** Implemented utility functions (`parse_condition`, `update_condition_signal`, `update_condition_comparator`, `update_condition_constant`) to serialize and mutate circuit condition state structures cleanly.


### Revision: Standardized Device GUI Refactoring (Stage 4 Refactor)
**Date:** 2026-09-03 12:38 (EDT)
**Context:** Refactor Pneumatic Pump and Diverter configuration interfaces to consume the centralized UI widget library (`scripts/utils/gui-components.lua`), standardizing element layout construction, event routing, and settings synchronization across active devices.
**Key Changes:**
1. **Pneumatic Pump GUI Refactoring (`scripts/pump-gui.lua`):** Streamlined interface construction using declarative `gui_components` helpers (`create_relative_window`, `add_header`, `add_wire_channel_toggles`, `add_card_frame`, `add_circuit_condition_panel`), routing configuration edits directly to `active_device_scanner.notify_settings_changed(entity)`.
2. **Pneumatic Diverter GUI Refactoring (`scripts/diverter-gui.lua`):** Standardized titlebar headers, wire channel switches, circuit condition panels, directional mode switches (`add_labeled_switch`), and 5-slot item filter selectors (`add_filter_slot`) using `gui_components` helpers while preserving the 2x2 directional port card layout.
3. **Unified Notification Routing (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`):** Updated all GUI event listeners (checkbox, dropdown, textfield, element selection, switch toggle) to trigger immediate port state re-evaluations and wake parked capsules via `active_device_scanner`.


### Revision: Factorio 2.1 Read-Only Proxy Minable Fix
**Date:** 2026-09-03 13:00 (EDT)
**Context:** Resolve runtime crash (`LuaEntity::minable is read only`) occurring during entity build events when initializing hidden circuit proxies for pneumatic pumps and diverters.
**Key Changes:**
1. **Runtime Property Assignment Fix (`scripts/proxy-manager.lua`):** Removed `proxy.minable = false` property assignment in `on_created`. In Factorio 2.0+, `LuaEntity.minable` is read-only at runtime; proxy unminability is governed at the prototype stage via flags (`"not-minable"`).


### Revision: Modular Hub GUI Refactoring (Stage 5 Refactor)
**Date:** 2026-09-03 14:15 (EDT)
**Context:** Refactor Pneumatic Hub configuration interface (`scripts/hubs/hub-gui.lua`) to consume the centralized UI widget library (`scripts/utils/gui-components.lua`), standardizing relative container window anchoring, wire channel toggles, and circuit condition selectors across active devices.
**Key Changes:**
1. **Container Window Support & Panel Flexibility (`scripts/utils/gui-components.lua`):** Updated `create_relative_window` to assign window titles on relative container frames and made `add_circuit_condition_panel` checkbox parameters optional for compound enable/circuit layout rows.
2. **Declarative Hub GUI Refactoring (`scripts/hubs/hub-gui.lua`):** Streamlined Hub interface construction using `gui_components` helpers (`create_relative_window`, `add_wire_channel_toggles`, `add_card_frame`, `add_circuit_condition_panel`), replacing local operator tables with canonical comparator helpers (`gui_components.COMPARATORS`).
3. **Unified Event Routing & State Mutation (`scripts/hubs/hub-gui.lua`):** Refactored event listeners across checkboxes, signal choosers, operator dropdowns, and constant textfields to mutate settings via `gui_components` helpers while preserving mutual exclusivity rules and triggering immediate wakeups via `hub_manager.notify_settings_changed(entity)`.


### Revision: Compact Modal Diverter Filters, Overlay Badges & Strict Quality Engine
**Date:** 2026-09-03 17:07 (EDT)
**Context:** Overhaul the Pneumatic Diverter GUI layout by removing inline dropdown clutter in favor of 40x40 square slot buttons with corner badge overlays, fixing child modal window focus lifecycle, and implementing strict Factorio 2.0 quality tier rank evaluations.
**Key Changes:**
1. **Modal Overlay GUI Builder (`scripts/utils/gui-components.lua`):** Created `create_overlay_slot_button` and `update_overlay_slot_button` to render 40x40 slot buttons with top-left active comparator badges (`=`, `≥`, `≤`, `>`, `<`, `≠`) and bottom-right quality badges. Added `get_item_name_and_quality` to parse both string item names and Factorio 2.0 `item-with-quality` table structures.
2. **Diverter GUI Overhaul & Window Focus Fix (`scripts/diverter-gui.lua`):** Eliminated all 20 inline comparator dropdowns from the main window, replacing filter rows with 5 square slot buttons per port card. Added a `filter_slot_config_frame` modal pop-up for editing filters. Maintained `player.opened` focus on the primary frame so pop-up modals and native item pickers open without triggering `on_gui_closed` window destruction.
3. **Strict Quality Rank Engine (`scripts/capsules/capsule-runner.lua`):** Mapped Factorio 2.0 quality ranks (`Normal` = 1 through `Legendary` = 5) and implemented strict comparator math in `matches_filter_item`. Filter slots set to `Normal` with `=` strictly require Tier 1 `Normal` quality, while `≥` enables threshold filtering (e.g., `≥ Normal` matches Normal and higher). Propagated `payload_quality` through all pathfinding and lookahead checks.
4. **Payload Quality Tracking (`scripts/hubs/hub-packing.lua`, `scripts/capsules/capsule-manager.lua`):** Updated hub cargo packing to record `dominant_cargo_quality` and capsule registration to persist `dominant_quality` in `storage.active_capsules` from the exact tick cargo is packed.


### Revision: Factorio 2.0 Native Quality Filter Engine & UI Control Bar Overhaul
**Date:** 2026-09-03 21:46 (EDT)
**Context:** Overhaul pneumatic diverter filtering to support native Factorio 2.0 quality comparisons, wildcard quality matching, itemless quality filtering, and interactive quality selector controls within filter configuration pop-up windows.
**Key Changes:**
1. **Wildcard Quality Sprite Prototype (`data.lua`):** Registered the `pneumatic_any_quality_badge` sprite prototype mapping to core `any-quality.png` for wildcard quality badge rendering.
2. **Quality-Aware Filter Evaluation Engine (`scripts/capsules/capsule-runner.lua`, `scripts/diverter-settings.lua`):** Updated default slot initialization in `diverter_settings` to default to `"Any Quality"` comparators and `"normal"` tiers. Refactored `matches_filter_item` and `evaluates_port_filter` in `capsule_runner` to support quality tier rank comparisons (`normal` through `legendary`), comparator evaluation (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`), and standalone quality filtering when item slots are unassigned.
3. **Quality Control Bar Widget Component (`scripts/utils/gui-components.lua`):** Expanded `gui_components` with `add_quality_control_bar` rendering quality comparator dropdowns, 5-tier quality sprite radio buttons, checkmark confirm buttons, and slot button active selection highlight styles (`flib_selected_slot_button`). Added sprite fallback helpers for quality badges (`get_quality_sprite`).
4. **Diverter GUI Modal Quality Selector Integration (`scripts/diverter-gui.lua`):** Overhauled `filter_slot_config_frame` modal windows to combine item choosers with `add_quality_control_bar`. Added event listeners for quality tier radio buttons and comparator dropdowns, while tracking active slot button highlights during configuration.


### Revision: Quality Filter GUI Scaling, Dropdown Width & Overlay Badge Alignment
**Date:** 2026-09-03 22:15 (EDT)
**Context:** Resolve dropdown clipping, oversized quality icons, and misplaced overlay badges across item filter slots by standardizing texture scaling, dropdown widths, and bottom-left badge alignment in the centralized UI widget library.
**Key Changes:**
1. **Dropdown Width & Rich-Text Sizing (`scripts/utils/gui-components.lua`):** Expanded `quality_comparator_dropdown` width from `54` to `68` in `add_quality_control_bar` to prevent rich text wildcard badge (`[img=pneumatic_any_quality_badge]`) and dropdown selection arrow clipping.
2. **Overlay Badge Texture Scaling (`scripts/utils/gui-components.lua`):** Enabled `stretch_image_to_widget_size = true` on overlay sprite elements in `update_overlay_slot_button`, scaling 64x64 wildcard badges and 32x32 quality tier icons down into clean 12x12 corner overlays.
3. **Bottom-Left Corner Alignment & Padding (`scripts/utils/gui-components.lua`):** Constrained slot button inner layout flows to `34x34`, set `horizontal_align = "left"`, and applied baseline label offsets (`top_margin = -3`) to keep comparator operators and quality badges positioned neatly inside the bottom-left corner of the 40x40 slot box.
4. **Encapsulated Quality Selection API (`scripts/utils/gui-components.lua`, `scripts/diverter-gui.lua`):** Added `gui_components.update_quality_tier_selection` to encapsulate radio button active selection styling, fully decoupling quality control bar state updates from machine GUI implementations.


### Revision: Native Quality Comparator Selector Component Refactoring
**Date:** 2026-09-03 22:27 (EDT)
**Context:** Standardize and fully encapsulate native Factorio quality comparator and quality tier selector interaction rules inside the reusable UI widget library, eliminating machine-specific quality state orchestration in diverter GUIs.
**Key Changes:**
1. **Encapsulated Quality Control Bar Engine (`scripts/utils/gui-components.lua`):** Updated `add_quality_control_bar` to keep quality tier radio buttons unselected/grayed-out when initialized in `"Any Quality"` mode. Added `update_quality_control_bar`, `handle_quality_tier_click`, and `handle_quality_comparator_change` to manage control bar state transitions, dropdown synchronization, and button highlight styles centrally.
2. **Native Quality Selector Rules (`scripts/utils/gui-components.lua`):** Implemented native Factorio quality selector behavior: selecting `"Any Quality"` on the dropdown grays out/unselects all quality tier selection buttons; clicking any quality tier radio button while on `"Any Quality"` automatically converts the comparator mode to `=` and selects the clicked tier.
3. **Decoupled Diverter GUI Event Delegation (`scripts/diverter-gui.lua`):** Streamlined quality dropdown (`on_gui_selection_state_changed`) and quality tier click (`on_gui_click`) event listeners to delegate state transitions directly to `gui_components.handle_quality_comparator_change` and `gui_components.handle_quality_tier_click`.


### Revision: Encapsulated Reusable Filter Slot Component, Right-Click Clearing & Native Quality Rules
**Date:** 2026-09-03 23:16 (EDT)
**Context:** Encapsulate item filter slot lifecycle interactions, right-click filter clearing, native Factorio quality default rules, explicit quality preservation, "Any Quality" memory resetting, and high-contrast overlay badge formatting directly inside the reusable UI widget library (`scripts/utils/gui-components.lua`).
**Key Changes:**
1. **Reusable Right-Click Filter Clearing (`scripts/utils/gui-components.lua`, `scripts/diverter-gui.lua`):** Configured `mouse_button_filter = { "left", "right" }` on overlay slot buttons and created `gui_components.clear_filter_slot` and `gui_components.handle_overlay_slot_click` to reset slots back to unassigned default states on right-click.
2. **Explicit Quality Tracking & Native Default Engine (`scripts/utils/gui-components.lua`, `scripts/diverter-gui.lua`, `diverter-settings.lua`):** Created `gui_components.handle_filter_item_change` backed by an `explicit_quality` state flag. Selecting an item on an unconfigured slot defaults to `=` comparator and `normal` quality, while deliberate quality choices (dropdown or quality tier selections) are strictly preserved across item swaps and GUI reopens. Selecting "Any Quality" clears specific quality tier memory back to `normal` and clears the explicit quality flag so subsequent comparator switches or item choices re-trigger native `=` + `normal` quality defaults.
3. **Native Overlay Symbol Omission & White Text Contrast (`scripts/utils/gui-components.lua`):** Updated `update_overlay_slot_button` to omit the `=` comparator symbol on item slot overlays to mirror native Factorio filter UI conventions. Added `COLOR_WHITE` and `gui_components.format_white_label` to render non-equal comparator badges (`>`, `<`, `≥`, `≤`, `≠`) in high-contrast white text over item icons.


### Revision: Diverter GUI Directional Arrow Indicators & Color Constants
**Date:** 2026-09-04 08:00 (EDT)
**Context:** Enhance Diverter configuration interface usability by introducing blue directional triangle arrows alongside cardinal direction labels across port card headers and filter configuration modal windows for at-a-glance spatial orientation.
**Key Changes:**
1. **Centralized UI Color Constants (`scripts/utils/gui-components.lua`):** Exported `COLOR_BLUE` (`"[color=100,200,255]"`) in the reusable UI widget library to standardize blue rich-text formatting across device configuration interfaces.
2. **Diverter Port Direction Indicators (`scripts/diverter-gui.lua`):** Updated `PORT_DIRECTIONS` mapping to pair cardinal direction labels (`North`, `East`, `South`, `West`) with vibrant blue directional arrows (`▲`, `▶`, `▼`, `◀`), rendering clear spatial indicators on 2x2 port card headers and filter slot configuration modal titlebars.


### Revision: Reusable Spatial Arrow Selector Widget Component
**Date:** 2026-09-04 08:15 (EDT)
**Context:** Introduce a modular 3x3 spatial `+` shape arrow selector widget component to the UI widget library (`scripts/utils/gui-components.lua`) to support directional device layout configuration interfaces with flexible part subscription.
**Key Changes:**
1. **Spatial Arrow Selector Builder (`scripts/utils/gui-components.lua`):** Implemented `gui_components.add_spatial_arrow_selector` rendering a 3x3 table grid with North (▲), West (◀), Center, East (▶), and South (▼) button positions aligned around empty spacer cells.
2. **Flexible Part Subscription & Styling (`scripts/utils/gui-components.lua`):** Configured flexible part specifications supporting selective enabling/disabling of individual directions, custom button sizes, custom captions/sprites/tooltips, style overrides, selection highlights (`flib_selected_slot_button`), and tag merging.
3. **Dynamic Widget Button Updates (`scripts/utils/gui-components.lua`):** Added `gui_components.update_spatial_arrow_button` to dynamically update captions, sprites, tooltips, interaction states, and active selection highlights on existing spatial selector buttons.


### Revision: Directional Spatial Arrow Selector & Default Single-Port Diverter GUI
**Date:** 2026-09-04 08:30 (EDT)
**Context:** Overhaul Pneumatic Diverter GUI layout to incorporate the 3x3 spatial arrow selector widget alongside port configuration cards, enabling single-direction filtering to declutter the interface, center-button resetting to all 4 ports, and defaulting to North view upon window initialization.
**Key Changes:**
1. **Spatial Arrow Selector Integration (`scripts/diverter-gui.lua`):** Embedded a left-hand directional view card inside `render_content_layout` using `gui_components.add_spatial_arrow_selector`, mapping North (▲, Port 1), East (▶, Port 2), South (▼, Port 3), West (◀, Port 4), and Center ("All") selector buttons with active highlight styling.
2. **Default North Direction View (`scripts/diverter-gui.lua`):** Configured `diverter_gui.open` to default `initial_view` to Port 1 (North), presenting a single clean port configuration card when opening the interface to eliminate multi-card cognitive overload.
3. **Dynamic Port Container Rendering (`scripts/diverter-gui.lua`):** Refactored `render_content_layout` to dynamically switch between a single card layout (`column_count = 1`) for individual cardinal directions and a 2x2 grid (`column_count = 2`) when viewing all direction ports simultaneously.
4. **View Switching Event Delegation (`scripts/diverter-gui.lua`):** Added `view_port` tag event routing inside `on_gui_click` to handle direction view toggling while cleanly dismissing open modal filter slot configuration windows before re-rendering the layout.


### Revision: Circuit Condition Dropdown Width Expansion
**Date:** 2026-09-04 08:57 (EDT)
**Context:** Resolve operator symbol clipping and selection arrow truncation inside circuit condition dropdown widgets across device configuration interfaces by expanding the default dropdown width in the UI component builder library.
**Key Changes:**
1. **Circuit Condition Panel Dropdown Width (`scripts/utils/gui-components.lua`):** Increased `comparator_width` default fallback from `40` to `55` pixels in `gui_components.add_circuit_condition_panel`, ensuring ample padding for all comparator symbols (`=`, `≥`, `≤`, `>`, `<`, `≠`) and dropdown arrows across Pneumatic Pump, Diverter, and Hub GUIs.


### Revision: Reusable Device Settings Copy-Paste Engine & Custom Input Integration
**Date:** 2026-09-04 09:42 (EDT)
**Context:** Enable copying and pasting device configuration settings across Pneumatic Pumps, Diverters, and Hubs using native Factorio copy/paste controls (Shift + Right-Click / Left-Click), bypassing C++ engine restrictions on non-container prototypes.
**Key Changes:**
1. **Custom Input Control Bindings (`prototypes/custom-input.lua`):** Registered `pneumatic-copy-settings` and `pneumatic-paste-settings` custom inputs linked directly to native `copy-entity-settings` and `paste-entity-settings` controls to reliably capture copy/paste intent on `electric-energy-interface` prototypes.
2. **Prototype Pastable Entity Registration (`prototypes/entity.lua`, `prototypes/pneumatic-diverter.lua`):** Configured `additional_pastable_entities` across `pneumatic-pump`, `pneumatic-diverter`, and `capsule-hub` prototypes to enable native cursor selection.
3. **Centralized Settings Copier Engine (`scripts/device-settings-copier.lua`, `control.lua`):** Created `device-settings-copier.lua` listening to custom input and native `on_entity_settings_pasted` events. Copies settings between matching device types, notifies `active_device_scanner` or `hub_manager` for immediate state/flow re-evaluation, and refreshes open destination GUIs.
4. **Deep-Copy Settings Persistence Helpers (`scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Added `.copy()` helpers backed by `util.table.deepcopy` to duplicate configuration data cleanly in `storage`, clearing compiled filter caches on destination diverter entities.


### Revision: Blueprint Settings Serialization, Metadata Tags & Lifecycle Restoration
**Date:** 2026-09-04 10:36 (EDT)
**Context:** Enable full blueprint and copy-paste metadata support across Pneumatic Pumps, Diverters, and Hubs, serializing circuit enable conditions, wire toggles, directional port modes, whitelist/blacklist filter modes, and quality rules into blueprint entity tags upon setup, and restoring settings during build and clone events.
**Key Changes:**
1. **Blueprint Tag Serialization (`scripts/device-settings-copier.lua`):** Subscribed to `defines.events.on_player_setup_blueprint`, safely unwrapping `event.mapping` via `.get()` (`LuaCustomTable` userdata) and serializing deep-copied machine settings into blueprint stacks/records (`event.stack` / `event.record`) using `set_blueprint_entity_tag`, while stripping transient runtime caches (`_compiled`).
2. **Deserialization API (`scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Added `apply_blueprint_settings(unit_number, blueprint_settings)` across device settings modules to safely deserialize blueprint tag metadata into persistent `storage` state.
3. **Build & Clone Lifecycle Integration (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Expanded build event handlers (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive`, `on_space_platform_built_entity`, `on_entity_cloned`) to apply `event.tags.pneumatic_settings` or copy from `event.source` prior to default initialization, immediately enqueuing unit ports into `flow_engine` and waking parked capsules.


### Revision: Blueprint Proxy Wire Serialization & Ghost Wire Linking Engine
**Date:** 2026-09-04 13:16 (EDT)
**Context:** Implement full circuit wire serialization and ghost-level wire reconstruction across pneumatic pumps, diverters, and connected circuit networks in blueprints using Factorio 2.0 invariant blueprint entity indices and `LuaWireConnector` APIs.
**Key Changes:**
1. **Blueprint Proxy Wire Serialization (`scripts/device-settings-copier.lua`):** Subscribed to `on_player_setup_blueprint` using `LuaEntity.get_wire_connectors(false)` to iterate over circuit proxy connectors. Serializes target entity wire connector IDs and invariant blueprint indices (`bp_index`) into `pneumatic_settings.wire_connections` and `pneumatic_bp_index` tags, ensuring 100% rotation and flip immunity without spatial coordinate offsets.
2. **Ghost Entity Proxy Spawning (`scripts/proxy-manager.lua`):** Updated `proxy_manager` event listeners (`on_created`, `on_removed`, `on_rotated`) to inspect `entity.ghost_name` when `entity.name == "entity-ghost"`. Spawns hidden circuit proxies at ghost entity coordinates as soon as a blueprint is stamped on the map.
3. **Deferred Ghost & Entity Wire Reconstruction (`scripts/device-settings-copier.lua`):** Implemented `process_entity_built_wire_tags` and hooked build/revive/clone event handlers. Automatically resolves wire targets between ghosts or built entities via `storage.bp_wire_cache` and `storage.pending_bp_wires`, connecting wire connectors immediately upon placement via `LuaWireConnector.connect_to()`.


### Revision: Native Proxy Blueprint Wire Previews, Wire Operability & Spatial Z-Indexing
**Date:** 2026-09-04 16:34 (EDT)
**Context:** Enable native blueprint wire previews, interactive wire placement/cutting tools, and spatial Z-index layering for proxy-based entities (`pneumatic-pump` and `pneumatic-diverter`), resolving C++ blueprint validation errors, wire property tree schema mismatches, and post-placement selection layering.
**Key Changes:**
1. **Proxy Prototype Blueprintability & Operability (`prototypes/pneumatic-pump-proxy.lua`, `prototypes/pneumatic-diverter.lua`):** Added `"player-creation"` flag, assigned `placeable_by` to main machine items with `count = 0`, and elevated `selection_priority` to `60` (higher than main machine priority `50`). Satisfies C++ `is_blueprintable` validation while ensuring circuit terminals take selection precedence for Red/Green wire items and Wire Cutters.
2. **Atomic Blueprint Wire Serialization & 4-Tuple Schema Alignment (`scripts/device-settings-copier.lua`):** Overhauled `on_player_setup_blueprint` to dynamically inject proxy entity records into `blueprint.get_blueprint_entities()` and serialize wire connections using Factorio 2.0 4-element connection tuples (`{ src_conn_id, src_conn_id, target_bp_index, tgt_conn_id }`), resolving C++ property tree schema parsing errors (`ROOT[0].wires[1]`) and committing entities, positions, tags, and wires atomically.
3. **Runtime Operability & Spatial Selection Re-Indexing (`scripts/proxy-manager.lua`):** Preserved `proxy.operable = true` so wire tools can connect/disconnect signals, and integrated `proxy.teleport(pos)` inside `on_created` and `on_rotated` build handlers to re-insert the proxy at the top of Factorio's spatial selection stack above newly placed ghosts and built machines.


### Revision: Blueprint Proxy Wire Merging, Orphan Auto-Destruction & Surface Purge Engine
**Date:** 2026-09-04 17:10 (EDT)
**Context:** Eliminate orphaned proxy entities and ghost proxies during blueprint placement over removed devices, right-click ghost cancellations, or partial builds, while implementing additive wire merging to preserve pre-existing and blueprint wire connections on active devices.
**Key Changes:**
1. **Additive Proxy Wire Merging (`scripts/proxy-manager.lua`):** Implemented `transfer_wire_connections` to iterate over source proxy/ghost `LuaWireConnector` ports and copy wire connections onto surviving real proxies via `connect_to()` prior to source entity destruction, preventing wire severing when stamping blueprints over existing machines.
2. **Orphan Proxy & Ghost Auto-Destruction (`scripts/proxy-manager.lua`):** Subscribed proxy entity names to `on_created` and `on_removed` lifecycle events. Unanchored proxies or ghost proxies lacking a valid host machine or ghost host at their coordinates are recognized as orphans and destroyed immediately (`entity.destroy()`).
3. **Multi-Proxy Deduplication & Direction Sync (`scripts/proxy-manager.lua`):** Updated `on_created` to transfer wires from extra duplicate real/ghost proxies onto the primary real proxy (`existing[1]`) before pruning duplicates, enforcing strictly one real proxy per machine with synced direction and selection stack order.
4. **Bidirectional Deconstruction Clean-up (`scripts/proxy-manager.lua`):** Updated `on_removed` to destroy both real proxy entities and ghost proxies when a host machine or host ghost is mined, deconstructed, killed, or script-destroyed.
5. **Surface-Wide Orphan Purge Engine (`scripts/proxy-manager.lua`, `control.lua`):** Added `proxy_manager.purge_orphans()` scanning all surfaces for unanchored real/ghost proxies, hooking it into `setup_storage()` in `control.lua` to clean up legacy map orphans during `on_init` and `on_configuration_changed`.


### Revision: Blueprint Orphan Proxy Purge & UI Lifecycle Integration
**Date:** 2026-09-04 18:48 (EDT)
**Context:** Automatically sanitize blueprints and blueprint books upon saving, setup, or GUI window teardown, purging orphan circuit proxies left behind when main devices (pumps or diverters) are deleted in the blueprint manager window.
**Key Changes:**
1. **Proxy Specification Registry Export (`scripts/proxy-manager.lua`):** Exposed `proxy_manager.get_registered_proxies()` and `proxy_manager.get_registered_mains()` to allow blueprint utility functions to query registered proxy names and positional offsets dynamically.
2. **Blueprint Event Lifecycle & Handle Resolution (`scripts/device-settings-copier.lua`):** Subscribed to `defines.events.on_player_configured_blueprint` and `defines.events.on_gui_closed`. Implemented `get_blueprints_from_event_and_player` to target active blueprint handles across `event` payloads, `player.cursor_stack`, and `player.opened` frame references.
3. **Orphan Proxy Purging & Re-Indexing Engine (`scripts/device-settings-copier.lua`):** Implemented `clean_blueprint_orphans` to inspect `bp_entities`, identify proxy entities lacking a corresponding main machine within a 0.05 tile radius, purge orphan records, re-index entity numbers (1 to N), and sanitize wire connections and metadata tags.
4. **Type-Safe Object & Blueprint Book Traversal (`scripts/device-settings-copier.lua`):** Implemented `clean_container_or_blueprint` using `bp.object_name` guards to safely differentiate `LuaItemStack` and `LuaRecord` userdata, enabling recursive blueprint book traversal (`defines.inventory.item_main` and `record.contents`) while guarding against C++ `__index` exceptions.


### Revision: Alt-Mode Diverter Port Filter Overlay Renderer
**Date:** 2026-09-04 20:45 (EDT)
**Context:** Implement native-style Alt-Mode visible filter item overlays over Pneumatic Diverter ports, dynamically rendering configured port filters in adaptive 2x2 grids anchored directly to topological port offsets.
**Key Changes:**
1. **Diverter Port Overlay Renderer (`scripts/diverter-renderer.lua`):** Created `diverter_renderer` utilizing Factorio 2.0 `rendering.draw_sprite` APIs. Queries topological port coordinates directly from `port_defs.get_ports(entity)` to display up to 4 filter item icons per port in a clean 2x2 grid (`scale = 0.42`, `offset = 0.22`) with `only_in_alt_mode = true` on `render_layer = "entity-info-icon"`.
2. **Scanner Lifecycle & Settings Integration (`scripts/active-device-scanner.lua`):** Integrated `diverter_renderer.update_render(entity)` triggers into `notify_settings_changed(entity)` and built event handlers (player build, robot build, script raised, revive, space platform, cloned). Added `diverter_renderer.clear_render(unit_number)` cleanup to device unregistration upon entity mining or destruction.
3. **Control Initialization & Storage Sync (`control.lua`):** Required `diverter-renderer` at script top level and hooked an active diverter refresh scan into `setup_storage()`, ensuring filter overlays are automatically restored across world loading (`on_init`) and configuration migrations.


### Revision: Alt-Mode Diverter Filter Overlay Inward Shift & Solid Black Shadow Rendering
**Date:** 2026-09-04 22:39 (EDT)
**Context:** Prevent Alt-Mode diverter port filter item icons from overlapping port flow indicator dots while enhancing icon contrast and readability against machine entity visuals.
**Key Changes:**
1. **Topological Inward Shift (`scripts/diverter-renderer.lua`):** Implemented a directional vector offset calculation (`PORT_INWARD_OFFSET = 0.55`) that shifts port filter overlay clusters inward toward the entity center `(0,0)`, eliminating visual collision with port flow dots.
2. **Pitch-Black Silhouette & Drop Shadow (`scripts/diverter-renderer.lua`):** Added a 1.3x scaled centered outline (`OUTLINE_SCALE_MULTIPLIER = 1.3`) and a 1.3x scaled down-right offset drop shadow (`SHADOW_SCALE_MULTIPLIER = 1.3`, offset `0.04`) rendered with full-opacity black tint (`BLACK_TINT = {r=0, g=0, b=0, a=1.0}`) to form a high-contrast backing frame.
3. **Render Layer Z-Ordering (`scripts/diverter-renderer.lua`):** Structured rendering passes across explicit layers by drawing black outline and shadow elements on `render_layer = "entity-info-icon"` while rendering full-color item icons directly on top via `render_layer = "entity-info-icon-above"`.


### Revision: Diverter Settings Orientation Sync, Directional Copy-Paste & Decoupled Scanner Observer
**Date:** 2026-09-05 09:34 (EDT)
**Context:** Automatically rotate and flip Pneumatic Diverter port settings in sync with physical entity orientation changes, align filter settings when copy-pasting between differently oriented diverters, and eliminate a circular script require loop between active device scanning and GUI controllers.
**Key Changes:**
1. **Modulo Port Rotation & Axis Flipping (`scripts/diverter-settings.lua`):** Implemented `rotate_ports`, `rotate_ports_by_steps`, and `flip_ports` using cardinal index mapping (`North = 1` through `West = 4`) and modulo arithmetic (`(p - 1 + steps) % 4 + 1`) to shift port filter configurations in lockstep with entity rotation (`R`, `Shift+R`) and flipping (`F`, `Shift+F`).
2. **Direction-Aware Copy-Paste Alignment (`scripts/diverter-settings.lua` & `scripts/device-settings-copier.lua`):** Enhanced `diverter_settings.copy` and `device-settings-copier` to track source and destination entity directions, applying relative step rotations when pasting or cloning settings between diverters facing different directions.
3. **Decoupled Scanner Observer & UI Refresh (`scripts/active-device-scanner.lua` & `scripts/diverter-gui.lua`):** Added `active_device_scanner.on_settings_changed` subscriber callback registration to invoke `diverter_gui.refresh_if_open`, breaking a top-level circular `require` dependency loop while guaranteeing live UI frame re-renders when open diverter entities are rotated or modified.


### Revision: Diverter Alt-Mode Filter Overlay Quality Badges, Comparators & Text Alignment Fix
**Date:** 2026-09-05 09:58 (EDT)
**Context:** Achieve visual parity between Diverter Alt-Mode filter overlays and native Factorio 2.0 inserter filter overlays by rendering bottom-left quality badges and non-equal comparator symbols while resolving a rendering API parameter crash.
**Key Changes:**
1. **Bottom-Left Overlay Alignment (`scripts/diverter-renderer.lua`):** Repositioned quality badges and comparator symbols to the bottom-left corner of item filter overlay icons (`cx - scale * 0.28, cy + scale * 0.28`), supporting side-by-side rendering when both a comparator and quality tier are present.
2. **Wildcard & Tier Quality Badge Integration (`scripts/diverter-renderer.lua`):** Integrated `gui_components.get_quality_sprite` to draw the registered wildcard `pneumatic_any_quality_badge` for "Any Quality" filters and native quality tier icons (`quality/uncommon`, `quality/rare`, `quality/epic`, `quality/legendary`) with black outline backings.
3. **Non-Equal Comparator Text Overlay (`scripts/diverter-renderer.lua`):** Added dual-pass high-contrast white text rendering with black drop shadows for non-equal quality comparators (`>`, `<`, `≥`, `≤`, `≠`), omitting the default `=` symbol.
4. **Vertical Text Alignment Crash Fix (`scripts/diverter-renderer.lua`):** Updated `vertical_alignment` parameters in `rendering.draw_text` from invalid `"center"` to `"middle"`, eliminating non-recoverable Factorio C++ engine runtime exceptions.


### Revision: Diverter Alt-Mode Blacklist Filter Overlay & Native Filter Parity
**Date:** 2026-09-05 10:44 (EDT)
**Context:** Resolve 101x101 filter-blacklist sprite cropping and align Alt-Mode diverter filter overlay indicators with native Factorio 2.0 inserter filter conventions.
**Key Changes:**
1. **Blacklist Sprite Prototype Registration (`data.lua`):** Registered `pneumatic_filter_blacklist` sprite prototype using the exact 101x101 frame dimensions (`width = 101`, `height = 101`) for `__core__/graphics/filter-blacklist.png`, eliminating sprite clipping and giant red arc distortion.
2. **Resolution-Aware Scale Adjustment (`scripts/diverter-renderer.lua`):** Added `get_blacklist_sprite` helper with fallback to `utility/filter_blacklist`, adjusting render scale (`0.33` standalone, `scale * 0.41` overlaid) to match 64x64 item icon tile proportions.
3. **Native Inserter Filter Parity (`scripts/diverter-renderer.lua`):** Aligned filter overlay behavior with Factorio 2.0 inserter rules: renders a standalone centered "no" symbol when `use_filters` is enabled on empty whitelist ports (`item_count == 0` - blocking all flow), overlays a single top-right "no" symbol over configured blacklist item clusters (`item_count > 0`), and suppresses overlays on empty blacklist ports.


### Revision: Native Inserter Parity for Diverter Filter Overlays & Standalone Quality Badges
**Date:** 2026-09-05 13:37 (EDT)
**Context:** Achieve 1:1 visual parity with Factorio 2.0 native inserter filter overlays for Diverter Alt-Mode rendering and UI slot buttons, supporting standalone quality filters, non-equal comparator target quality badges, and per-slot blacklist indicators.
**Key Changes:**
1. **Standalone Quality Filter Layout (`scripts/diverter-renderer.lua` & `scripts/utils/gui-components.lua`):** Supported filter slots configured with quality criteria but no specific item (`item == nil`), rendering quality tier sprites (`quality/rare`, `quality/legendary`, etc.) in horizontal side-by-side alignment with comparator symbols (`[ Comparator ] [ Quality Badge ]`).
2. **Target Quality Badge Preservation for Non-Equal Comparators (`scripts/diverter-renderer.lua` & `scripts/utils/gui-components.lua`):** Corrected overlay logic so non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`) always render the target quality tier badge—including `quality/normal` (grey dot)—explicitly displaying the comparison target.
3. **Per-Slot Prominent Blacklist Symbol Overlay (`scripts/diverter-renderer.lua`):** Moved blacklist "no" symbol rendering inside the per-slot filter loop, scaling indicators to `bl_scale = scale * 0.88` centered over each individual filter icon (`cx + scale * 0.05, cy - scale * 0.05`) rather than drawing a single miniature port-wide symbol.


### Revision: Diverter Alt-Mode Overlay Alignment Fix & Consolidated Filter Display Specification
**Date:** 2026-09-05 14:31 (EDT)
**Context:** Unify filter display specification rules across GUI slot buttons and Alt-Mode world overlays while resolving comparator text collision over quality badge dots in world rendering.
**Key Changes:**
1. **Unified Filter Display Specification (`scripts/utils/gui-components.lua`):** Implemented `gui_components.get_filter_display_spec` and `gui_components.get_active_filters` to centralize native Factorio 2.0 filter display rules (item sprites, comparator visibility, target quality badges, and standalone quality filters) across both GUI slot buttons and world overlays.
2. **GUI Slot Button Simplification (`scripts/utils/gui-components.lua`):** Refactored `gui_components.update_overlay_slot_button` to consume `get_filter_display_spec`, ensuring 100% rule parity with Alt-Mode overlays while maintaining GUI widget styling and bottom-flow badge layouts.
3. **Alt-Mode Badge & Comparator Offset Alignment (`scripts/diverter-renderer.lua`):** Corrected Alt-Mode rendering offset coordinates and text alignment for multi-badge configurations (`badge_x = cx - scale * 0.18`, `comp_x = cx - scale * 0.38`, `alignment = "right"`), placing comparator symbols cleanly to the left of quality badge dots to achieve 1:1 visual parity with native Factorio 2.0 inserters.
4. **World Rendering Pass Consolidation (`scripts/diverter-renderer.lua`):** Added `draw_text_with_shadow` and `draw_sprite_with_outline_and_shadow` helpers to consolidate multi-pass rendering objects (black outlines, drop shadows, and main sprites) across item filters, standalone quality badges, and blacklist indicators.


### Revision: Revert Diverter GUI Default View to 'All' Mode
**Date:** 2026-09-05 15:09 (EDT)
**Context:** Default the Pneumatic Diverter configuration GUI to display all four directional port cards simultaneously ("All" mode) upon opening, rather than focusing single-port North view by default.
**Key Changes:**
1. **Default View State (`scripts/diverter-gui.lua`):** Updated `diverter_gui.open` and `diverter_gui.refresh_if_open` to default `current_view` to `"all"` instead of `1` (North port), rendering the full 4-port grid when opening the diverter interface without an explicit initial view parameter.


### Revision: Filter Slot Draft State, Quality Preservation & Draggable Modal GUI
**Date:** 2026-09-05 16:00 (EDT)
**Context:** Achieve native Factorio 2.0 filter configuration behavior by preserving existing quality/comparator rules on item swaps, isolating modal editing inside a draft working state, and making filter configuration pop-ups fully draggable.
**Key Changes:**
1. **Comparator & Quality Preservation (`scripts/utils/gui-components.lua`):** Refactored `gui_components.handle_filter_item_change` so selecting an item defaults to `=` and `normal` quality only if the slot is currently blank (`"Any Quality"`). Pre-configured comparators and quality tiers are preserved intact when changing item selections.
2. **Isolated Draft Filter State & Confirm Lifecycle (`scripts/diverter-gui.lua`):** Implemented a `draft_filters` working table in `diverter_gui.open_slot_config`. Interacting with items, quality radio buttons, or comparator dropdowns inside the modal updates only the draft without mutating persistent `diverter_settings` or leaking live updates to the machine. Drafts commit to the entity strictly upon clicking Confirm (✓) or pressing `E`/`Esc`, while clicking Cancel (X) discards unconfirmed changes.
3. **Window Focus & Draggable Header Integration (`scripts/diverter-gui.lua` & `scripts/utils/gui-components.lua`):** Removed `player.opened` re-assignment inside `open_slot_config` to prevent Factorio's engine from triggering `on_gui_closed` on the main frame and destroying the modal pop-up on spawn. Enhanced `gui_components.add_header` with `drag_target = parent_frame` across header title flows and drag spacers, making modal filter windows fully draggable across the viewport.


### Revision: Diverter GUI Per-Port Copy-Paste & Native Tool Buttons
**Date:** 2026-09-05 16:15 (EDT)
**Context:** Enable players to quickly duplicate filter rules, circuit conditions, and directional flow settings between individual diverter ports via native tool buttons and player-scoped clipboard storage.
**Key Changes:**
1. **Port Settings Copy-Paste API (`scripts/diverter-settings.lua`):** Added `diverter_settings.copy_port` and `diverter_settings.paste_port` to produce isolated deep-copies of port configurations and apply them to target ports while invalidating compiled filter caches (`_compiled = nil`).
2. **Native Tool Button Header Integration (`scripts/diverter-gui.lua`):** Added `port_copy_button` and `port_paste_button` using Factorio 2.0 `tool_button` sprite styles (`utility/copy` and `utility/paste`) to each port card header. Dynamically disabled paste buttons when `storage.port_clipboard[player_index]` is empty.
3. **Cursor Flying Text Feedback & Live Refresh (`scripts/diverter-gui.lua`):** Wired `on_gui_click` handlers to populate player clipboard storage, trigger `notify_change()` to update world overlays and active device scanners, refresh open GUIs, and display cursor floating text feedback (`create_at_cursor = true`).


### Revision: Blueprint Proxy Wire Tuple Fix & Instant Zero-State Reconstruction
**Date:** 2026-09-05 16:42 (EDT)
**Context:** Resolve a critical blueprint proxy wire corruption bug where stamped blueprint entities generated a web of erroneous circuit wire connections to the top-left entity (Entity #1) and leaked wire memory across unrelated blueprint placements.
**Key Changes:**
1. **Blueprint Wire Tuple Format Fix (`scripts/device-settings-copier.lua`):** Corrected `add_bp_wire` tuple array formatting to insert `proxy_bp_entity.entity_number` as the first element (`[entity_from, wire_type_from, entity_to, wire_type_to]`) instead of `src_conn_id`. Passing `1` (red wire connector ID) in position 1 previously caused Factorio's C++ blueprint parser to decode Entity #1 as the source for every wire in the blueprint, producing spiderweb cross-links to the top-left machine.
2. **Purged Persistent Pending Wire Queue (`scripts/device-settings-copier.lua`):** Removed `storage.bp_wire_cache` and `storage.pending_bp_wires` multi-tick storage buffers. Refactored `process_entity_built_wire_tags` to perform zero-state, instant spatial wire target resolution strictly on the build tick via `surface.find_entities_filtered` and relative distance matching (`is_valid_wire_target`), completely preventing cross-linking across separate blueprint stamps placed over time.
3. **Strict Target Entity Validity Guards (`scripts/device-settings-copier.lua`):** Added explicit `unit_number` and `.valid` checks across target entity lookups and table index accesses, preventing C++ `__newindex` metamethod runtime exceptions when destroyed ghost proxies are processed during blueprint placement events.


### Revision: Pneumatic Pump GUI Interaction Parity & Entity GUI Mode Fix
**Date:** 2026-09-05 17:08 (EDT)
**Context:** Resolve an issue where left-clicking physical `pneumatic-pump` entities failed to open the pump configuration GUI, requiring players to click its hidden circuit proxy.
**Key Changes:**
1. **Entity GUI Mode Activation (`prototypes/entity.lua`):** Added `gui_mode = "all"` to the `pneumatic-pump` `electric-energy-interface` prototype definition. This enables native entity interaction event dispatching (`on_gui_opened`) when left-clicked, allowing `proxy-manager.lua` to intercept interactions and launch `pump-gui` in 1:1 functional parity with `pneumatic-diverter`.


### Revision: Native Confirm GUI Event Linking & Esc Modal Cancellation
**Date:** 2026-09-05 17:32 (EDT)
**Context:** Differentiate between pressing `E` (Confirm) and `Esc` (Cancel) when leaving the Diverter filter slot configuration modal, achieving 1:1 parity with native Factorio 2.0 GUI draft lifecycle conventions.
**Key Changes:**
1. **Confirm GUI Custom Input Registration (`prototypes/custom-input.lua`):** Registered `pneumatic-confirm-gui` linked to Factorio's native `confirm-gui` control sequence (`linked_game_control = "confirm-gui"`) with `consuming = "none"`.
2. **Tick-Based Confirm Event Tracking (`scripts/diverter-gui.lua`):** Subscribed to the `pneumatic-confirm-gui` custom input event to record the exact execution tick (`confirm_ticks[player_index] = event.tick`) when a player triggers the GUI confirmation key.
3. **Confirm vs. Cancel Dismissal Logic (`scripts/diverter-gui.lua`):** Updated `on_gui_closed` to evaluate whether `confirm_ticks[event.player_index] == event.tick`. Pressing `E` (or clicking the checkmark) passes `should_apply = true` to commit draft filter settings, whereas pressing `Esc` (or closing without confirming) passes `should_apply = false` to discard draft changes without mutating entity settings.


### Revision: Diverter Filter Draft Quality Synchronization & Standalone Quality Preservation
**Date:** 2026-09-05 17:53 (EDT)
**Context:** Prevent diverter slot configuration modals from silently holding ghost quality settings when clearing item selections, while maintaining full GUI and draft parity for standalone quality filters.
**Key Changes:**
1. **Item Clear Quality Preservation (`scripts/utils/gui-components.lua`):** Refactored `gui_components.handle_filter_item_change` so clearing an item selection preserves configured comparator and quality settings (updating GUI quality bar controls accordingly), while resetting quality to `"normal"` only if the comparator is set to `"Any Quality"`.
2. **Draft & Modal Synchronization (`scripts/diverter-gui.lua`):** Updated `diverter_gui.open_slot_config` and `close_slot_config` to guarantee 1:1 synchronization between GUI widgets and draft state tables (`draft_filters`), ensuring submitted configurations strictly match the visual state of the modal window.
3. **Stored Setting Normalization (`scripts/diverter-settings.lua`):** Enhanced `diverter_settings.get` to sanitize stored filter settings on load, enforcing `quality = "normal"` and clearing `explicit_quality` whenever a slot uses `"Any Quality"` without an item.


### Revision: Refrigerated Capsule Recharge Recipe Subgroup & English Localization
**Date:** 2026-09-05 19:53 (EDT)
**Context:** Organize the `recharge-refrigerated-capsule` recipe into the dedicated Pneumatic Transport crafting tab and provide localized recipe name display in the English locale configuration.
**Key Changes:**
1. **Recipe Subgroup & Tab Order (`prototypes/recipe.lua`):** Configured `subgroup = "pneumatic-capsules"` and `order = "c[refrigerated]-b[recharge]"` on `recharge-refrigerated-capsule`, moving the recipe out of the fallback "other/misc" subgroup and positioning it directly adjacent to the main refrigerated capsule recipe in the Pneumatic Transport crafting tab.
2. **English Recipe Localization (`config.cfg`):** Added `recharge-refrigerated-capsule=Recharge Refrigerated Capsule` under `[recipe-name]` in the English locale file.


### Revision: Spatial Junction Flow Overlay Consolidation & Z-Ordering Fix
**Date:** 2026-09-05 20:01 (EDT)
**Context:** Resolve duplicate overlapping overlay circles, garbled text z-index fighting, and placement-order visual inconsistencies at connected flow junctions.
**Key Changes:**
1. **Spatial Position-Based Rendering (`scripts/flow/flow-engine.lua`):** Refactored Alt-Mode flow level visual overlays from individual port tracking (`pkey`) to unified spatial junction tracking (`pos_key`). `update_pos_render` guarantees exactly one circle and text object is rendered per physical tile coordinate, eliminating duplicate circle stacking and placement-order sensitivity.
2. **Dominant Flow Level Selection (`scripts/flow/flow-engine.lua`):** Implemented `get_dominant_port_at_pos` to evaluate all overlapping ports at a tile location and display the dominant magnitude flow level (`math.abs(level)`), resolving ties in favor of positive pressure and active machine emitters.
3. **Zero-Length Vector Suppression (`scripts/flow/flow-engine.lua`):** Updated `update_edge_render` to automatically discard zero-length vector line renders between co-located ports sharing the same `pos_key`.


### Revision: Concise Capsule Item & Factoriopedia Descriptions & Maintenance Correction
**Date:** 2026-09-05 20:27 (EDT)
**Context:** Provide concise Factoriopedia and tooltip descriptions for all pneumatic transport capsule items, detailing capacity scaling, quality rules, spoilage mechanics, and correct maintenance crafting facilities.
**Key Changes:**
1. **Concise Capsule Locale Descriptions (`config.cfg`):** Updated `[item-description]` entries for all six capsule variants (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`) with punchy multiline specs covering slot capacity scaling, quality rules, organic slot cost discounts, 90% cryo spoilage reduction, dissolution/rupture risks, and emergency player ejection controls (`__CONTROL__capsule-emergency-exit__`).
2. **Assembling Machine Recharge Correction (`config.cfg`):** Corrected `refrigerated-capsule` and `spent-refrigerated-capsule` maintenance documentation to specify that coolant recharging with cold fluoroketone occurs at assembling machines.
3. **Prototype Description Cleanup (`prototypes/item.lua`):** Removed unused `factoriopedia_description` properties from `ItemPrototype` and `ToolPrototype` definitions, ensuring Factoriopedia and item tooltips cleanly render the localized multiline descriptions directly from `[item-description]`.


### Revision: Pneumatic Hub Binary Nest Capsules Configuration Toggle
**Date:** 2026-09-05 20:43 (EDT)
**Context:** Enable players to configure Pneumatic Hubs to either exclusively nest capsule vessel items inside outgoing capsules or restrict packing strictly to non-capsule cargo items.
**Key Changes:**
1. **Hub Settings State & Blueprint Sync (`scripts/hubs/hub-settings.lua`):** Added `nest_capsules = true` default setting to `hub_settings.get()`, ensuring property preservation across entity copy-paste (`hub_settings.copy`) and blueprint tag deserialization (`hub_settings.apply_blueprint_settings`).
2. **Operational Mode GUI Checkbox (`scripts/hubs/hub-gui.lua`):** Added a "Nest capsules" checkbox to the Hub relative settings window, wiring `on_gui_checked_state_changed` to update `settings.nest_capsules` and invoke `hub_manager.notify_settings_changed()` to wake active scanners.
3. **Inventory Packing Filter Pipeline (`scripts/hubs/hub-packing.lua`):** Updated `evaluate_inventory()` to filter candidate cargo stacks based on `nest_capsules`: restricting cargo choices strictly to registered capsule variants (`capsule_defs.types`) when enabled, or excluding capsule items when disabled.


### Revision: Native-Style Live Source Entity Copy-Paste & Ghost Settings Parity
**Date:** 2026-09-06 10:02 (EDT)
**Context:** Align entity settings copy-paste mechanisms with Factorio 2.0 native behavior by tracking live source entities instead of static snapshots, requiring live source existence, and bringing 1:1 settings copy, rotate, and revival parity to ghost entities.
**Key Changes:**
1. **Live Entity Source Tracking (`scripts/device-settings-copier.lua`):** Updated `on_copy_settings` to store live `LuaEntity` references in `storage.player_copy_buffer`, evaluating live settings and relative entity directions dynamically at the tick of paste execution (`apply_live_settings_copy`).
2. **Source Validity Guard (`scripts/device-settings-copier.lua`):** Added strict `source and source.valid` checks across custom hotkey and native `on_entity_settings_pasted` events, preventing paste operations if the source machine or ghost was destroyed or mined.
3. **Ghost Proxy Target Resolution (`scripts/device-settings-copier.lua`):** Enhanced `resolve_target_entity` to inspect `ghost_name` when targeting ghost entities or clicking proxy circuit terminals overlaying unbuilt ghost structures.
4. **Ghost Entity Settings Lifecycle (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Refactored build, destroy, and rotate event listeners to resolve ghost entity names (`is_ghost and entity.ghost_name or entity.name`), enabling blueprint tag deserialization, orientation rotation, revival transfer (`event.source`), and storage cleanup for ghost pumps, diverters, and hubs.


### Revision: Pneumatic Ghost Entity GUI Evoking, Live Settings & Copy-Paste Parity
**Date:** 2026-09-06 10:34 (EDT)
**Context:** Achieve 1:1 parity with native Factorio 2.0 ghost interactions by enabling configuration GUI opening, live setting updates, rotation sync, and copy-paste handling across ghost pumps, diverters, and hubs.
**Key Changes:**
1. **Ghost Entity Search & Proxy Resolution (`scripts/proxy-manager.lua` & `scripts/hubs/hub-gui.lua`):** Updated `on_gui_opened` to resolve `entity.ghost_name` and locate ghost main entities when clicking circuit proxies, allowing players to open configuration windows on unbuilt ghost entities.
2. **O(1) Ghost Entity Tracking (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Added `storage.ghost_devices` and `storage.ghost_hubs` tables to record active ghost entities by `unit_number`, enabling instant entity resolution during GUI change events.
3. **Ghost Live GUI Updates & Observer Sync (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`, `scripts/hubs/hub-gui.lua`):** Refactored `notify_change` to resolve ghost entities, triggering scanner notifications and live UI frame re-renders (`refresh_if_open`) whenever ghost settings are modified.
4. **Ghost Rotation & Copy-Paste Parity (`scripts/active-device-scanner.lua` & `scripts/device-settings-copier.lua`):** Triggered setting updates on ghost rotation/flip events and un-guarded `apply_live_settings_copy` to notify observers and refresh open GUIs when pasting settings to ghost destinations.


### Revision: Ghost Entity Configuration Parity, Alt-Mode Overlays & Build Settings Adoption
**Date:** 2026-09-06 18:56 (EDT)
**Context:** Achieve 1:1 functional parity for ghost Diverters, Pumps, and Cargo Hubs by supporting full GUI interaction, world Alt-Mode filter overlay rendering, and automatic settings inheritance when building physical entities over ghosts.
**Key Changes:**
1. **Spatial Ghost Location Registry (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Implemented `storage.ghost_by_pos` mapping tile coordinates (`surface@x,y`) to ghost unit numbers. When a physical entity replaces a ghost (via inventory build, robot construction, or revive script), the newly created entity retrieves the ghost unit number and copies settings (`pump_settings.copy`, `diverter_settings.copy`, `hub_settings.copy`) even after the ghost object is consumed by the engine.
2. **Ghost GUI Registration & Live Observer Sync (`scripts/diverter-gui.lua`, `scripts/pump-gui.lua`, `scripts/hubs/hub-gui.lua`):** Registered open ghost entities directly into `storage.ghost_devices` and `storage.ghost_hubs`. Allows `notify_change()` to resolve ghost entity handles, triggering live scanner updates, world Alt-Mode overlay renders, and instant GUI frame re-renders when checkboxes, switches, or circuit conditions are modified.
3. **Decoupled Ghost Port Resolution & Circuit Isolation (`scripts/flow/port-defs.lua`, `scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Updated `port_defs.get_ports()` to resolve `ghost_name` transparently for world overlays while bypassing active circuit signal reads (`get_signal`) and proxy queries on ghost entities, isolating ghost settings storage from runtime simulation loops.
4. **Proxy Lifecycle Replacement Guard (`scripts/proxy-manager.lua`):** Updated `on_removed` to inspect tile coordinates for remaining main or ghost entities before destroying circuit proxies, preventing proxy wire disruption when physical entities replace ghosts.


### Revision: Ghost Entity Configuration Parity, Circuit Proxy Isolation & GUI Tag Resolution
**Date:** 2026-09-06 20:10 (EDT)
**Context:** Resolve ghost diverter GUI checkbox reset instability, prevent circuit proxy lifecycle events from wiping ghost settings storage, and ensure physical entities inherit and correctly rotate ghost configurations upon build/revive.
**Key Changes:**
1. **Ghost Device Position-Based Identity Resolution (`scripts/diverter-settings.lua`, `scripts/pump-settings.lua`, `scripts/hubs/hub-settings.lua`):** Implemented `get_device_id()` to produce stable spatial position keys (`ghost@name@surface@x,y`) for hand-placed and blueprint ghost entities that do not possess native `unit_number` properties in Factorio 2.0.
2. **Circuit Proxy Blacklist & Spatial Key Namespacing (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Blacklisted circuit proxy entities from build/destroy/rotate handlers and namespaced spatial position keys (`real_name@surface@x,y`), preventing circuit proxy spawns from falsely matching and erasing ghost device settings in `storage`.
3. **Recursive Parent GUI Tag Resolution (`scripts/diverter-gui.lua`):** Implemented `get_element_tags()` to traverse up the widget hierarchy (`element.parent`), enabling nested checkboxes, switches, and dropdowns to reliably retrieve device IDs attached to parent card frames.
4. **Suppressed Local GUI Re-Entrant Destructions (`scripts/diverter-gui.lua`):** Added a local GUI edit flag guarding `refresh_if_open`, preventing local user checkbox toggles from clearing `inner_frame` mid-click while preserving live UI re-renders for external rotation and copy-paste events.
5. **Ghost Settings Migration & Rotation Inheritance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Recorded `storage.ghost_directions` on placement/rotation and updated build event handlers (`on_built_entity`, `script_raised_revive`, etc.) to copy settings from ghost sources (`event.consumed_ghost`, `event.source`, or spatial lookup) and apply relative direction rotations.


### Revision: Ghost Spatial Identity, Directional Indexing & Rotation/Flip Build Inheritance
**Date:** 2026-09-06 20:46 (EDT)
**Context:** Ensure ghost pumps, diverters, and cargo hubs maintain and adapt configured settings across rotation, flipping, ghost-on-ghost replacement, and physical placement over ghosts regardless of orientation changes.
**Key Changes:**
1. **Spatial Device Identity Export (`scripts/pump-settings.lua` & `scripts/hubs/hub-settings.lua`):** Exported `get_device_id` across `pump_settings` and `hub_settings` matching `diverter_settings`, establishing a unified spatial identity schema (`ghost@name@surface@x,y` or `unit_number`) across all device storage layers.
2. **Cardinal Direction Enum Normalization (`scripts/diverter-settings.lua`):** Implemented `get_cardinal_index` to map Factorio 2.0 16-way, 8-way, and 4-way direction enum values (`0`, `4`, `8`, `12`) cleanly to cardinal indices (North=1 through West=4), ensuring relative step rotations are accurately calculated during settings copying.
3. **Pre-Registration Ghost Proximity Search (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Added `find_ghost_id_at_pos` spatial search (1.2 tile radius) to resolve preceding ghost settings prior to updating `storage.ghost_by_pos`, preventing newly placed entities from overwriting spatial lookup keys before reading settings.
4. **Ghost-on-Ghost & Flip Settings Inheritance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Removed `not is_ghost` guards from build event copy logic, allowing replacement ghosts spawned when flipping (`F`) or rotating (`R`) existing ghosts to inherit and adapt settings from preceding ghosts at the same tile coordinate.
5. **Deferred Ghost Settings Purge (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Deferred ghost settings deletion during ghost destruction events, preserving configuration tables in `storage` across engine entity replacement ticks.


### Revision: Object Destruction Tracking & Circuit Proxy Cleanup for Super Force Building
**Date:** 2026-09-06 20:56 (EDT)
**Context:** Resolve lingering orphan circuit proxy entities left behind when built or ghost diverters and pumps are mined, destroyed, or super force built over.
**Key Changes:**
1. **Self-Exclusion Removal Guard (`scripts/proxy-manager.lua`):** Updated `on_removed` to filter out `m ~= entity` and `g ~= entity` when evaluating remaining main or ghost entities at machine tile coordinates, preventing active destruction targets from falsely suppressing proxy removal.
2. **Object Destruction Registration (`scripts/proxy-manager.lua`):** Registered main built and ghost entities with `script.register_on_object_destroyed` inside `on_created`, tracking registration IDs in `storage.proxy_destruction_map` alongside surface, spatial position, and proxy specification metadata.
3. **Engine-Level Object Destroyed Callback (`scripts/proxy-manager.lua`):** Subscribed to `defines.events.on_object_destroyed` to catch C++ engine-level entity removals (such as super force building, fast replacement, and ghost cancellation). The callback evaluates remaining spatial main entities post-destruction and purges orphaned real and ghost circuit proxies when no host machine remains.


### Revision: Complete English Locale Recipe Description Coverage
**Date:** 2026-09-06 22:05 (EDT)
**Context:** Achieve 100% English locale coverage for all pneumatic transport crafting recipes, ensuring detailed localized descriptions render cleanly in Factoriopedia and crafting menu tooltips.
**Key Changes:**
1. **Localized Recipe Description Section (`config.cfg`):** Added a dedicated `[recipe-description]` section to the English locale configuration file.
2. **Comprehensive Recipe Description Entries (`config.cfg`):** Populated concise localized description strings for all 13 mod recipes (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `recharge-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, and `pneumatic-diverter`), detailing operational roles, capsule behaviors, and thermal byproduct discharges.


### Revision: Strict Ghost Settings Adoption, Spatial Bounding Box & Orientation Overlap
**Date:** 2026-09-06 23:01 (EDT)
**Context:** Prevent improper settings inheritance when placing physical entities or ghosts over ghosts with different bounding box shapes, orientation axes, or spatial offsets.
**Key Changes:**
1. **Strict Spatial Position Tolerance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Tightened ghost spatial lookup distance matching from 1.2 tiles down to `< 0.1` tiles (`dx < 0.1, dy < 0.1`), preventing entities placed offset or 1 tile away from falsely adopting adjacent ghost configurations.
2. **Orientation Axis Alignment Guard (`scripts/active-device-scanner.lua` & `scripts/diverter-settings.lua`):** Exported `diverter_settings.get_cardinal_index` to enforce orientation axis checks (`(g_idx % 2) == (e_idx % 2)`), ensuring 1x2 and 2x1 pumps only inherit settings when placed along matching orientation axes (blocking adoption when placing horizontal pumps over vertical ghost pumps).
3. **Prototype Real-Name Compatibility (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Enforced exact prototype real-name equality (`g_real_name == real_name`) across ghost entity handles (`event.consumed_ghost`, `event.source`, or spatial lookup) prior to copying settings, preventing cross-prototype adoption between locked orientation hub variants (`capsule-hub-horizontal` vs `capsule-hub-vertical`).


### Revision: Blueprint Settings Overwrite Parity & Factorio 2.0 Engine Event Integration
**Date:** 2026-09-06 23:21 (EDT)
**Context:** Resolve an issue where stamping blueprints or pasting blueprint settings over existing built diverters, pumps, or cargo hubs failed to update entity configurations, preserving pre-existing machine settings.
**Key Changes:**
1. **Factorio 2.0 Blueprint Settings Pasted Event (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua` & `scripts/device-settings-copier.lua`):** Subscribed to native Factorio 2.0 `defines.events.on_blueprint_settings_pasted` across active device scanners, hub managers, and wire linkers to capture blueprint tags (`event.tags.pneumatic_settings`) and relative directional changes (`event.previous_direction`) when stamping blueprints over built entities.
2. **Existing Spatial Entity Overwrite (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Implemented `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` spatial lookups (< 0.1 tile tolerance). When a ghost is placed over an existing physical machine, settings and rotations apply directly to the physical entity, Alt-Mode overlays and scanners are woken, and redundant ghost entities are purged.
3. **Blueprint Item & Record Paste Parity (`scripts/device-settings-copier.lua`):** Implemented `extract_settings_from_blueprint_source` inside `apply_live_settings_copy` to inspect `LuaItemStack` and `LuaRecord` handles during `on_entity_settings_pasted`, enabling direct Shift+Left-Click settings transfers from blueprint items onto built entities.


### Revision: Pneumatic Capsule Counter Data Stage & Prototype Declarations
**Date:** 2026-09-07 10:21 (EDT)
**Context:** Implement Task 1 of the Capsule Counter plan, registering entity, item, recipe, technology, and hidden circuit proxy prototypes ahead of runtime range propagation and logic engine integration.
**Key Changes:**
1. **Capsule Counter Entity & Proxy (`prototypes/pneumatic-capsule-counter.lua`):** Registered the main physical entity `pneumatic-capsule-counter` (`electric-energy-interface`, 1x2 footprint, 30 kW energy usage, `selection_priority = 50`) configured with `gui_mode = "all"`. Registered its companion `pneumatic-capsule-counter-circuit-proxy` (`constant-combinator`, `selection_priority = 60`, `operable = true`, `placeable_by` main item, `"player-creation"` flag).
2. **Tinted Decider Sprite Graphics (`prototypes/pneumatic-capsule-counter.lua`):** Deepcopied 4-way directional sprites from `data.raw["decider-combinator"]["decider-combinator"]` and applied a distinct teal tint (`r = 0.30, g = 0.85, b = 0.70`), visually differentiating the counter structure from pumps and hubs.
3. **Item & Recipe Declarations (`prototypes/item.lua` & `prototypes/recipe.lua`):** Registered `pneumatic-capsule-counter` item under subgroup `pneumatic-transport` (order `h[counter]`, stack size 20) with a matching teal icon tint, and added its crafting recipe requiring tubes, advanced circuits, and arithmetic combinators.
4. **Technology Unlock & Data Registration (`prototypes/technology.lua` & `data.lua`):** Linked the counter recipe unlock effect directly to the baseline `pneumatic-transport` technology research node and required `prototypes.pneumatic-capsule-counter` in `data.lua`.


### Revision: Pneumatic Capsule Counter Circuit Proxy Pair Lifecycle Integration
**Date:** 2026-09-07 10:29 (EDT)
**Context:** Implement Task 2 of the Capsule Counter plan, linking the physical counter entity with its hidden circuit proxy pair in `proxy-manager.lua` to enable proxy creation, wire retention, selection Z-indexing, and orphan cleanup.
**Key Changes:**
1. **Proxy Pair Registration (`scripts/proxy-manager.lua`):** Registered the `pneumatic-capsule-counter` and `pneumatic-capsule-counter-circuit-proxy` pair via `proxy_manager.register_pair` with a forward-compatible `on_open_gui` stub handler delegating to `counter_gui.open`.
2. **Lifecycle & Selection Z-Indexing Integration (`scripts/proxy-manager.lua`):** Bound the counter proxy pair into the centralized proxy manager lifecycle, automatically enabling proxy creation on build/ghost placement, `selection_priority = 60` teleportation on rotation, additive wire connection migrations (`transfer_wire_connections`), orphan proxy destruction on main entity removal, and sandbox wipe cleanup (`storage.proxy_destruction_map`).


### Revision: Pneumatic Capsule Counter Sensing Port Alignment
**Date:** 2026-09-07 11:02 (EDT)
**Context:** Implement Task 3 of the Capsule Counter plan, registering directional sensing ports for the physical and ghost counter entities in port-defs.lua to enable topological node registration and range wavefront propagation.
**Key Changes:**
1. **Counter Port Registry Alignment (`scripts/flow/port-defs.lua`):** Registered `pneumatic-capsule-counter` port definitions across all four cardinal directions (`north`, `south`, `east`, `west`), assigning six spatial sensing connection offsets per orientation matching hub footprint layouts.
2. **Sensing Power & Isolation Configuration (`scripts/flow/port-defs.lua`):** Configured sensing ports with a `sense = 15` range seed rating while specifying `transmit = false`, `cross_transit = false`, and omitting gas `flow` pressure emission to ensure counter structures sense adjacent tube networks without acting as transit conduits or gas emitters.


### Revision: Pneumatic Capsule Counter Wavefront Range Engine
**Date:** 2026-09-07 13:34 (EDT)
**Context:** Implement Task 4 of the Capsule Counter plan, creating the delta wavefront propagation and boundary collision engine in `counter-range.lua` to partition tube networks into non-overlapping owned segment territories.
**Key Changes:**
1. **Wavefront Range Engine (`scripts/counters/counter-range.lua`):** Created `counter-range.lua` maintaining `storage.counter_levels`, `storage.counter_owners`, `storage.counter_queue`, and `storage.counter_owned_nodes`. Range seeds (15) decay by 1 level per hop down to 1 along tube nodes, with equal-level rival collisions resolving neutrally to eliminate double-counting. Implemented $O(1)$ segment territory lookups (`counter_range.get_owned_nodes`), defensive lazy storage initialization, and a `/check-counters` status debug command.
2. **Sensing Node Attribute Preservation (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to record `port.sense` attributes on `storage.flow_nodes`, allowing physical counter sensing ports to act as range emitters during graph traversal.
3. **Background Scanner Integration (`scripts/active-device-scanner.lua`):** Registered `pneumatic-capsule-counter` in the 15-tick background scanner. Energy state changes (`entity.energy > 0`) automatically trigger unit port enqueuing for immediate range expansion or recession.
4. **Runtime Lifecycle & Surface Hydration (`control.lua`):** Integrated `counter_range` storage initialization and event listeners into `control.lua`, scanning surfaces on load and initialization to register existing counters cleanly.


### Revision: Pneumatic Capsule Counter Wavefront Overlay & Flow Engine Unification
**Date:** 2026-09-07 14:26 (EDT)
**Context:** Implement Task 5 of the Capsule Counter plan, unifying sensing range wavefront propagation directly into `flow-engine.lua` for single-pipeline execution, adding Alt-Mode visual range overlays, deterministic midpoint tie-breaking, and symmetric recession/cleanup handling.
**Key Changes:**
1. **Flow Engine Wavefront Unification (`scripts/flow/flow-engine.lua`):** Refactored counter sensing range propagation directly into `flow_engine.step`, sharing the primary topological graph, queue, time-sliced batcher, and event listeners with pressure flow.
2. **Deterministic Territory Tie-Breaking (`scripts/flow/flow-engine.lua`):** Implemented deterministic `unit_number` tie-breaking for equal-distance midpoint collisions (`cand_level == max_cand_level`), eliminating neutral gap tiles and guaranteeing contiguous counter territory splits.
3. **Sensing Overlay Rendering & Alt-Mode Toggle (`scripts/flow/flow-engine.lua` & `scripts/debug-manager.lua`):** Implemented `update_counter_pos_render` rendering range level integers and owner color dots on tube nodes in Alt Mode. Added `/toggle-counter-range` (`/pt-toggle-counter-range`) command, shortcut, and Control Panel checkbox operating independently from pressure flow overlays.
4. **Natural Recession Waves & Disconnection Cleanup (`scripts/flow/flow-engine.lua` & `scripts/counters/counter-range.lua`):** Refactored `counter-range.lua` into a lightweight query API delegating queueing to `flow-engine.lua`. Updated entity removal and unpowering to enqueue root ports without pre-wiping levels, enabling 1-tile-per-tick recession waves for surviving counter takeover while instantly purging unconnected emission port renders on frame 0.


### Revision: Pneumatic Capsule Counter State Persistence Module
**Date:** 2026-09-07 14:33 (EDT)
**Context:** Implement Task 6 of the Capsule Counter plan, creating `counter-settings.lua` to manage counter configuration storage, spatial device ID resolution, copy-paste cloning, blueprint serialization, and proxy resolution.
**Key Changes:**
1. **State Persistence Module (`scripts/counters/counter-settings.lua`):** Created `counter-settings.lua` maintaining `storage.counter_settings[dev_id]` with default schema (`vessels_target = "green"`, `cargo_target = "red"`, `total_target = "green"`, `total_signal = { type = "virtual", name = "signal-C" }`).
2. **Spatial Identification & Proxy Resolution (`scripts/counters/counter-settings.lua`):** Implemented `counter_settings.get_device_id` supporting real unit numbers and ghost string formats (`ghost@...`), and `counter_settings.get_proxy` to locate the associated `pneumatic-capsule-counter-circuit-proxy`.
3. **Copy-Paste & Blueprint Deserialization (`scripts/counters/counter-settings.lua`):** Implemented `counter_settings.copy` for deep-copying settings between entities/ghosts and `counter_settings.apply_blueprint_settings` for restoring configuration tables from blueprint tags.


### Revision: Pneumatic Capsule Counter Copy-Paste & Blueprint Serialization
**Date:** 2026-09-07 14:52 (EDT)
**Context:** Implement Task 7 of the Capsule Counter plan, integrating pneumatic capsule counter entities into active device scanning, live copy-paste workflows, ghost settings adoption, and blueprint tag serialization.
**Key Changes:**
1. **Target Registration & Live Copy-Paste (`scripts/device-settings-copier.lua`):** Added `pneumatic-capsule-counter` to `TARGET_NAMES`, mapped `pneumatic-capsule-counter-circuit-proxy` target resolution to the main entity, implemented live entity copy-paste handling, and added top-level safe loading for `counter-gui`.
2. **Blueprint Serialization & Wire Target Resolution (`scripts/device-settings-copier.lua`):** Updated `on_player_setup_blueprint` to serialize counter settings tags (`pneumatic_settings`), append proxy entities, and record 4-tuple wire connections. Updated `process_entity_built_wire_tags` to restore proxy circuit wire links upon blueprint placement.
3. **Active Scanner Hooks & Ghost Settings Adoption (`scripts/active-device-scanner.lua`):** Added `init_settings` and `apply_blueprint_settings` hooks to the `pneumatic-capsule-counter` scanner spec, enabled device ID resolution, and integrated ghost-to-real settings adoption, blueprint pasting, and storage cleanup on entity removal or rotation.


### Revision: Pneumatic Capsule Counter Logic Engine & Circuit Signal Emitter
**Date:** 2026-09-07 15:01 (EDT)
**Context:** Implement Task 8 of the Capsule Counter plan, creating counter-logic.lua to calculate capsule vessel counts, cargo item inventories, and total capsule counts within owned tube territories, writing signal filters directly to the circuit proxy combinator on active scanner ticks.
**Key Changes:**
1. **Counter Logic Module (`scripts/counters/counter-logic.lua`):** Created `counter-logic.lua` providing `counter_logic.update_signals(counter_entity)`. Resolves owned segment nodes (`counter_range.get_owned_nodes`), queries active capsules without double-counting, extracts vessel item/quality breakdowns, cargo contents, and total capsule count (virtual signal C), and writes accumulated signals to the circuit proxy control behavior (`section.filters`). Automatically clears output signals when unpowered (`entity.energy == 0`) or unconfigured.
2. **Active Scanner Hooks & Reactive Triggers (`scripts/active-device-scanner.lua`):** Required `counter_logic` in `active-device-scanner.lua`. Added an `on_scan` hook to the `pneumatic-capsule-counter` scanner spec for 15-tick periodic signal updates, and wired immediate signal recalculations upon power state toggles (`check_and_update_state`) and settings change notifications (`notify_settings_changed`).


### Revision: Explicit Port Transmission Schema & Sensing Boundary Isolation
**Date:** 2026-09-07 15:40 (EDT)
**Context:** Refactor overloaded port transmission properties into domain-specific flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) to prevent counter range wavefronts from leaking across active machine boundaries while guaranteeing smooth capsule transit through pumps and diverters.
**Key Changes:**
1. **Explicit Port Transmission Registry (`scripts/flow/port-defs.lua`):** Replaced single `transmit` property with domain-specific booleans (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) across all registered entity port definitions. Explicitly disabled `sense_transmit` and `pressure_transmit` on machines (`pneumatic-pump`, `pneumatic-diverter`, `capsule-hub`, `pneumatic-capsule-counter`) while retaining `capsule_transmit = true` on transit machines.
2. **Flow & Sensing Wavefront Engine Alignment (`scripts/flow/flow-engine.lua`):** Recorded explicit transmission flags during node registration (`connect_entity`). Refactored passive gas pressure checks to require `pressure_transmit`, counter range wavefront propagation to require `sense_transmit`, and internal step queueing to evaluate domain-specific changes independently.
3. **Capsule Movement Target Validation (`scripts/capsules/capsule-runner.lua`):** Updated candidate hop generation, target hop validity checks (`is_hop_valid`), and hub outbound port selection to inspect `capsule_transmit` and `cross_transit`. Completely prevents capsules from targeting pure sensing ports while guaranteeing uninhibited capsule motion through pumps and diverters.


### Revision: Pneumatic Capsule Counter Relative Configuration GUI
**Date:** 2026-09-07 15:50 (EDT)
**Context:** Implement Task 9 of the Capsule Counter plan, creating `counter-gui.lua` to provide an interactive configuration window for capsule counter entities and proxies, featuring dual-wire checkbox channel routing for vessels, cargo, and total capsule counts alongside virtual signal selection.
**Key Changes:**
1. **Relative Configuration Frame (`scripts/counters/counter-gui.lua`):** Created `counter-gui.lua` providing `open` and `close` functions to build and anchor `counter_configuration_frame` using `gui_components.create_relative_window` with header controls and card layout.
2. **Dual-Wire Channel Routing Controls (`scripts/counters/counter-gui.lua`):** Implemented dual "Red Wire" and "Green Wire" checkbox options across three configuration sections (Capsule Vessels, Cargo Contents, Total Capsule Count), seamlessly converting UI checkbox states to and from underlying setting schema targets (`"off"`, `"red"`, `"green"`, `"both"`).
3. **Signal Selection & Reactive Event Handling (`scripts/counters/counter-gui.lua`):** Integrated a `choose-elem-button` for Total Capsule Count virtual signal selection and registered event listeners (`on_gui_opened`, `on_gui_closed`, `on_gui_click`, `on_gui_checked_state_changed`, `on_gui_elem_changed`) to update `storage.counter_settings` and dispatch scanner setting notifications.


### Revision: Pneumatic Capsule Counter Triple-Proxy Channel Isolation & Full Integration
**Date:** 2026-09-07 16:17 (EDT)
**Context:** Implement Task 10 of the Capsule Counter plan, introducing a triple-proxy architecture (selectable terminal proxy plus hidden Red and Green channel proxies) to guarantee zero cross-channel signal bleed across circuit networks, while adding English locale definitions and control script initialization.
**Key Changes:**
1. **Triple-Proxy Prototypes (`prototypes/pneumatic-capsule-counter.lua`):** Registered `pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy` (`selection_priority = 0`, `operable = false`) alongside the main `pneumatic-capsule-counter-circuit-proxy` terminal (`selection_priority = 60`, `operable = true`).
2. **Sub-Proxy Lifecycle & Internal Wiring (`scripts/proxy-manager.lua`):** Extended `proxy_manager.register_pair` to support sub-proxy schemas. Automatically spawns, teleports, and connects internal Red and Green wire bridges (`connect_sub_proxies`) between channel proxies and the main terminal proxy on build/rotate events, and purges all three proxies upon entity deconstruction (`destroy_all_proxies_at`).
3. **Channel-Isolated Signal Dispatch (`scripts/counters/counter-logic.lua` & `scripts/counters/counter-settings.lua`):** Added `counter_settings.get_channel_proxies` and updated `counter_logic.update_signals` to write Red-target signals strictly to the Red channel proxy and Green-target signals strictly to the Green channel proxy while keeping the main terminal proxy filters empty, eliminating cross-network signal bleed.
4. **Active Scanner & Target Resolution (`scripts/active-device-scanner.lua` & `scripts/device-settings-copier.lua`):** Added sub-proxy names to `PROXY_NAMES` to bypass scanner tracking and updated `resolve_target_entity` to resolve sub-proxy handles back to the physical counter entity.
5. **Locale Definitions & Top-Level Require Registration (`locale/en/config.cfg` & `control.lua`):** Added English entity, item, recipe, and technology captions and descriptions. Registered `counter-settings`, `counter-gui`, and `counter-logic` as top-level `require` statements in `control.lua`.


### Revision: Hub Pressure Differential Enforcement & Cross-Transit Flow Isolation
**Date:** 2026-09-07 18:03 (EDT)
**Context:** Enforce strict positive pressure differential requirements for hub outbound capsule dispatch and cross-transit motion, preventing hubs from dumping capsules onto unpressurized or opposing-pressure target ports.
**Key Changes:**
1. **Per-Port Outbound Pressure Evaluation (`scripts/capsules/capsule-runner.lua`):** Refactored `find_best_hub_outbound_port` to measure pressure drops (`touching_level - target_level`) per individual touching port rather than applying a global hub entity maximum. Initialized `max_drop = 0` to require target ports to have strictly lower pressure than the hub's touching exit port.
2. **Strict Outbound Injection Guard (`scripts/capsules/capsule-runner.lua`):** Updated `inject_from_hub` to abort and return `false` if no valid outbound port with a positive pressure drop is found, eliminating fallback dispatches onto unpressurized or opposing flow lines.
3. **Cross-Transit Exit Port Isolation (`scripts/capsules/capsule-runner.lua`):** Updated `select_next_target` for `cross_transit` entities to calculate candidate pressure drops directly against the touching exit port (`level_exit - level_cand > 0`), preventing transiting capsules from exiting hubs into zero or negative pressure differential nodes.
4. **Hub Packing Early Exit Guard (`scripts/hubs/hub-packing.lua`):** Added an early outbound port validation check to `hub_packing.evaluate_inventory`, aborting cargo extraction and liminal holder creation whenever no valid lower-pressure outbound route is available.


### Revision: Pneumatic Capsule Counter Signal Picker Clearing & Quality Preservation
**Date:** 2026-09-07 18:24 (EDT)
**Context:** Fix an issue where clearing the total count signal picker in the Capsule Counter GUI instantly reverted to default signal-C, and ensure selected signal quality is preserved on circuit proxy output filters.
**Key Changes:**
1. **Signal Clear Persistence & Fallback Removal (`scripts/counters/counter-settings.lua` & `scripts/counters/counter-logic.lua`):** Removed hardcoded fallback initializations (`signal-C`) from existing settings retrieval (`counter_settings.get`), blueprint settings application, and logic signal evaluation. Clearing the choose-elem-button in `counter-gui.lua` now persists `total_signal = nil` without being overwritten on GUI refresh or tick scans.
2. **Quality-Aware Circuit Signal Emission (`scripts/counters/counter-logic.lua`):** Updated `counter_logic.update_signals` to extract `total_signal.quality` dynamically rather than hardcoding `"normal"` quality during channel signal aggregation, correctly reflecting chosen signal quality levels on output circuit proxy filters.


### Revision: Independent Flow & Counter Overlay Render Lifecycle
**Date:** 2026-09-07 20:55 (EDT)
**Context:** Fix issue where toggling pressure flow overlays off wiped active counter range overlays by decoupling render destruction and drawing logic in flow-engine.lua and debug-manager.lua.
**Key Changes:**
1. **Domain-Specific Render Management (`scripts/flow/flow-engine.lua`):** Created `flow_engine.clear_flow_renders` and `flow_engine.draw_flow` to manipulate pressure flow circles, text labels, and vector lines independently from counter sensing range overlays.
2. **Per-Player Overlay Destruction Bounds (`scripts/flow/flow-engine.lua`):** Refactored `destroy_pos_renders`, `destroy_counter_renders`, and `destroy_edge_render` to support optional `player_index` targeting, preventing single-player overlay clears from destroying rendering objects for other players in multiplayer.
3. **Decoupled Debug Command & GUI Toggles (`scripts/debug-manager.lua`):** Refactored `toggle_new_flow`, `toggle_counter_range`, `toggle_master`, and GUI event handlers to call domain-specific draw/clear methods rather than blanket `clear_all_renders`, preserving counter range overlays when flow overlays are disabled.


### Revision: Hub Capsule Nesting Default Off & Setting Encapsulation
**Date:** 2026-09-07 22:02 (EDT)
**Context:** Change the hub capsule nesting default state to disabled (`false`) and encapsulate status checks behind a centralized settings helper function, ensuring newly placed hubs immediately transport standard cargo and eliminating duplicated fallback logic.
**Key Changes:**
1. **Default State & Helper Registration (`scripts/hubs/hub-settings.lua`):** Updated the default `nest_capsules` property to `false` across storage initialization, copy-paste cloning, and blueprint tag deserialization routines. Registered `hub_settings.is_nesting_enabled` helper function to centralize truth evaluation.
2. **Packing Engine Integration (`scripts/hubs/hub-packing.lua`):** Refactored `evaluate_inventory` to inspect nesting permissions via `hub_settings.is_nesting_enabled`, allowing hubs to default to standard item cargo packing upon placement without requiring manual GUI intervention.
3. **GUI State Alignment (`scripts/hubs/hub-gui.lua`):** Updated relative container GUI initialization to set the "Nest capsules" checkbox state directly from `hub_settings.is_nesting_enabled`.


### Revision: Bio Capsule Shell Lifecycle & Net Cargo Capacity Tooltips
**Date:** 2026-09-07 22:42 (EDT)
**Context:** Refactor single-use capsule lifecycle so biological primary capsule shells travel in-transit with cargo, dissolve strictly upon destination unpacking or spills, and accurately report net cargo stack capacities in locale tooltips.
**Key Changes:**
1. **Primary Shell Packing Priority (`scripts/hubs/hub-packing.lua`):** Swapped holder inventory insertion order to transfer primary capsule shells (`include_self`) into slot 1 before cargo extractions, preventing bio capsule shells from being displaced or destroyed at the origin hub during packing.
2. **Single-Use Dissolution & Unpacking (`scripts/hubs/hub-unpacking.lua`):** Updated `can_insert_all` to ignore primary shell slots for `destroy_self` capsules when checking destination chest capacity, clearing the shell (`holder_inv[ignore_slot].clear()`) upon arrival prior to cargo stack transfers.
3. **In-Transit Spill Dissolution (`scripts/hubs/hub-spill.lua`):** Updated `spill_capsule` to inspect `capsule_def.destroy_self` and clear primary shell slots prior to spilling cargo onto the ground or into spill containers, dissolving bio capsule shells cleanly during mid-transit ruptures or entity destructions.
4. **Net Cargo Stack Locale Tooltips (`locale/en/config.cfg`):** Updated item descriptions for `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, and `reinforced-capsule` to report net usable cargo stack counts (1, 1, 2, 2, 5) matching actual cargohold limits.


### Revision: Explicit Net Cargo Capacity Schema & Liminal Bar Limit Refactor
**Date:** 2026-09-07 23:20 (EDT)
**Context:** Standardize capsule capacity declarations around explicit net usable cargo slots (`cargo_capacity`) and adjust liminal holder inventory bar limits in `hub-packing.lua` to dynamically accommodate fractional-cost items.
**Key Changes:**
1. **Explicit Net Cargo Capacity Schema (`scripts/capsules/capsule-definitions.lua`):** Replaced total-container offset properties (`base_capacity` with `include_self = true`) across all capsule prototypes with explicit net usable cargo capacities (`cargo_capacity`), declaring that normal bio and standard item capsules hold 1 net cargo slot, refrigerated capsules hold 2, reinforced capsules hold 5, and player transit capsules hold 0.
2. **Fractional Slot Cost Bar Limit Calculation (`scripts/hubs/hub-packing.lua`):** Fixed a bug where `dest_inv.set_bar()` derived physical container slot limits directly from total capacity rather than dividing by `min_slot_cost`. Calculating physical holder slots via `math.floor(max_cargo_slots / min_slot_cost)` unlocks the necessary container slots (e.g., 3 physical slots for 1 primary shell + 2 bio items at 0.5 cost) without payload truncation.


### Revision: Bio-Capsule Rupture Risk Deprecation & Tech Tree Streamlining
**Date:** 2026-09-08 08:23 (EDT)
**Context:** Deprecate punitive mid-transit rupture mechanics and research upgrade tiers for biodegradable capsules, while adding missing technology locale definitions to resolve UI errors.
**Key Changes:**
1. **Bio-Capsule Definition & Lifecycle Refactor (`scripts/capsules/capsule-definitions.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Removed `spill_risk` property from `biodegradable-capsule` and purged research tier calculations (`bio_integrity_levels`) and event listeners from `capsule-lifecycle.lua`, while preserving the generic `spill_risk` evaluation framework for extensible capsule support.
2. **Technology Tree Streamlining (`prototypes/technology.lua`):** Removed the four `bio-capsule-integrity-1` through `4` upgrade technology nodes, retaining strictly the baseline `biodegradable-capsule` research unlock node.
3. **Locale Completion & Rupture Text Purge (`locale/en/config.cfg`):** Removed all item and technology locale descriptions referencing transit rupture risks and integrity upgrades. Added missing localized technology captions and descriptions for `biodegradable-capsule`, `reinforced-capsule`, and `refrigerated-capsule` to eliminate "Unknown key" UI rendering errors.
4. **Storage Cleanup (`control.lua`):** Deprecated `storage.bio_integrity_levels` persistent tracking table across runtime initialization and configuration change handlers.


### Revision: Capsule Counter Dedicated Technology & Legacy Engine Purge
**Date:** 2026-09-08 08:36 (EDT)
**Context:** Introduce a dedicated research node for the Pneumatic Capsule Counter requiring Circuit Network technology, while purging residual legacy v1 flow engine references from settings, locale, and runtime comments.
**Key Changes:**
1. **Capsule Counter Dedicated Research (`prototypes/technology.lua` & `locale/en/config.cfg`):** Created the `capsule-counter` technology node (prerequisites: `pneumatic-transport`, `circuit-network`; 100 cycles @ 30s) unlocking the `pneumatic-capsule-counter` recipe. Unlinked the counter unlock from baseline `pneumatic-transport` technology. Added localized English title and description while updating `pneumatic-transport` locale text to reflect the decoupled research tree.
2. **Legacy v1 Flow Engine Cleanup (`locale/en/config.cfg`, `settings.lua` & `control.lua`):** Removed obsolete `pneumatic-flow-version` mod setting locale keys from `config.cfg`. Purged lingering comments referencing legacy v1 flow network graph/builder settings across `settings.lua` and `control.lua`.


### Revision: Reinforced Capsule Bulk Enforcement & Electromagnetic Capsule Fulgora Integration
**Date:** 2026-09-08 09:14 (EDT)
**Context:** Enforce strict single-type full-capacity bulk transport for reinforced capsules and implement the Fulgora electromagnetic capsule allowing unrestricted mixed-cargo transit.
**Key Changes:**
1. **Reinforced Capsule Bulk Constraint Enforcement (`scripts/capsules/capsule-definitions.lua` & `locale/en/config.cfg`):** Refactored `reinforced-capsule` properties (`mixed_cargo = false`, `mixed_quality = "strict"`, `minimum_cargo = "ceil"`, `full_stacks = true`) to enforce strict bulk transport, requiring all cargo slots to be completely filled with a single item type of uniform quality before packing.
2. **Electromagnetic Capsule Definition (`scripts/capsules/capsule-definitions.lua`):** Registered `electromagnetic-capsule` with 2 net usable cargo slots (+1 per quality tier), configured with `mixed_cargo = true`, `mixed_quality = "any"`, `minimum_cargo = 1`, and `full_stacks = false` to enable unrestricted mixing of item types, partial stack quantities, and qualities.
3. **Prototype & Recipe Declarations (`prototypes/item.lua` & `prototypes/recipe.lua`):** Registered `electromagnetic-capsule` item prototype (stack size 1, subgroup `pneumatic-capsules`, order `f[electromagnetic]`) with a Holmium pink-magenta tint, and added its crafting recipe requiring 5 superconductors, 2 low-density structures, and 10 scrap.
4. **Technology Research Node (`prototypes/technology.lua`):** Created the `electromagnetic-capsule` research node (prerequisites: `electromagnetic-science-pack`, `pneumatic-transport`, `electromagnetic-plant`; 250 cycles @ 45s) unlocking the electromagnetic capsule recipe, featuring the superconductor icon with Holmium pink-magenta tinting.
5. **Locale Definitions (`locale/en/config.cfg`):** Added English localized names and descriptions for the electromagnetic capsule item, recipe, and technology while updating reinforced capsule descriptions to reflect the strict full-capacity bulk transport rule.


### Revision: Stack-Proportional Fractional Capacity & Smart Post-Packing Inventory Bar Clamping
**Date:** 2026-09-08 09:42 (EDT)
**Context:** Implement the `mixed_quantity` capacity accounting flag for electromagnetic capsules to scale slot costs by item stack size, and replace static upfront inventory bar clamping guesswork on liminal holders with dynamic post-packing clamping.
**Key Changes:**
1. **Electromagnetic Capsule Fractional Capacity Schema (`scripts/capsules/capsule-definitions.lua`):** Added `mixed_quantity = true` to `electromagnetic-capsule` prototype definition and explicitly set `mixed_quantity = false` across all other capsule prototypes.
2. **Fractional Slot Cost Planning Engine (`scripts/hubs/packing/cargo-planner.lua`):** Updated `plan_single_type_cargo` in `cargo-planner.lua` to calculate per-item unit slot costs (`base_slot_cost / stack_size`) when `mixed_quantity` is enabled, enabling partial item stacks to consume fractional capsule volume proportional to their item count.
3. **Smart Dynamic Post-Packing Inventory Bar Clamping (`scripts/hubs/hub-packing.lua`):** Replaced static upfront inventory bar clamping math on the hidden liminal holder with dynamic post-packing clamping. Transfers primary shell and cargo extractions using full inventory depth (`max_search = #dest_inv`), evaluates the highest occupied slot index (`last_occupied_slot`), and sets `dest_inv.set_bar(last_occupied_slot + 1)` to lock trailing empty slots cleanly.


### Revision: Standard Capsule Quality-Clamped Multi-Cargo Schema & Locale Refactor
**Date:** 2026-09-08 10:11 (EDT)
**Context:** Refactor the Standard Pneumatic Capsule into a quality-clamped multi-stack logistics backbone, allowing mixed item types and qualities up to the capsule's quality tier without overlapping with strict bulk or partial-stack container roles.
**Key Changes:**
1. **Quality-Clamped Multi-Cargo Schema (`scripts/capsules/capsule-definitions.lua`):** Configured `item-capsule` with `mixed_cargo = true`, `mixed_quality = "any"`, `quality_filter = "ceil"`, `minimum_cargo = 2`, and `full_stacks = true`. Enables multi-item and multi-quality transport clamped to the capsule's quality tier while requiring full item stacks and dispatching as soon as 1 full stack is loaded.
2. **Locale Description Alignment (`locale/en/config.cfg`):** Updated localized English item description for `item-capsule` to explicitly communicate its full-stack, quality-clamped mixed cargo capacity rules.


### Revision: Biological Capsule Restrictions & Normalized Base Cargo Capacity
**Date:** 2026-09-08 11:33 (EDT)
**Context:** Restrict refrigerated capsules strictly to biological cargo and normalize baseline stack capacities across all capsule variants to establish a clear quality scaling progression and eliminate capacity power spikes.
**Key Changes:**
1. **Refrigerated Biological Restriction & Schema Alignment (`scripts/capsules/capsule-definitions.lua` & `scripts/hubs/hub-packing.lua`):** Configured `bio_only = true` on `refrigerated-capsule` and `spent-refrigerated-capsule` prototypes and added a `bio_only` validation check (`not capsule_def.bio_only or capsule_defs.is_bio_item(item_name)`) to the item candidate loop in `hub-packing.lua` to exclude non-biological items from loading into refrigerated shells.
2. **Normalized Base Capacity & Quality Scaling Schema (`scripts/capsules/capsule-definitions.lua`):** Standardized base cargo capacities across all capsule prototypes: set Standard, Biodegradable, Refrigerated, Spent Refrigerated, and Electromagnetic capsules to base capacity 1 stack (`cargo_capacity = 1`, `quality_affected_capacity = 1`), and Reinforced capsules to base capacity 2 stacks (`cargo_capacity = 2`, `quality_affected_capacity = 2`).
3. **Locale Description Updates (`locale/en/config.cfg`):** Updated English localized descriptions for `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, and `electromagnetic-capsule` to clearly communicate biological cargo restrictions and updated stack capacity scaling rules.


### Revision: Vacuum Capsule Data Prototypes, Tech Tree & Locale Registration
**Date:** 2026-09-08 11:57 (EDT)
**Context:** Implement Task 1 of the Vacuum Capsule plan, registering item, tool, recipe, technology research node, English locale, and capsule definition schemas for the vacuum capsule and spent shell ahead of transport belt siphoning engine integration.
**Key Changes:**
1. **Item & Tool Declarations (`prototypes/item.lua`):** Registered `vacuum-capsule` as a tool prototype (durability 100, order `g[vacuum]`) with a deep vacuum blue icon tint, and registered `spent-vacuum-capsule` item (stack size 1, order `h[spent-vacuum]`) under the `pneumatic-capsules` subgroup.
2. **Crafting & Recharge Recipes (`prototypes/recipe.lua`):** Added crafting recipe for `vacuum-capsule` requiring processing units, low-density structures, and accumulators, and added `recharge-vacuum-capsule` recipe requiring a spent capsule shell and 2 batteries under subgroup `pneumatic-capsules`.
3. **Space Science Technology Node (`prototypes/technology.lua`):** Created the `vacuum-capsule` research node (prerequisites: `space-science-pack`, `pneumatic-transport`; 250 cycles @ 45s) unlocking the vacuum capsule crafting and assembly recharging recipes.
4. **Capsule Definition Registry (`scripts/capsules/capsule-definitions.lua`):** Registered `vacuum-capsule` and `spent-vacuum-capsule` schemas configured with 1 net usable cargo slot (+1 per quality tier), full stack enforcement, quality-clamped cargo rules (`quality_filter = "ceil"`), `spent_capsule_item` transition link, and distinct RGBA debug overlay colors.
5. **English Locale Definitions (`locale/en/config.cfg`):** Added localized names, tooltips, and descriptions for `vacuum-capsule` and `spent-vacuum-capsule` items, recipes, and technology research nodes.


### Revision: Transport Belt Siphon Engine & Vacuum Capsule Hub Siphoning
**Date:** 2026-09-08 12:37 (EDT)
**Context:** Implement Task 2 of the Vacuum Capsule plan, creating the transport belt siphoning engine in `belt-siphon.lua` and integrating automated belt extraction into `hub-packing.lua`.
**Key Changes:**
1. **Vacuum Capsule Schema Property (`scripts/capsules/capsule-definitions.lua`):** Configured `siphon_belts = true` on the `vacuum-capsule` prototype definition schema.
2. **Dumb Belt Siphon Helper Module (`scripts/hubs/packing/belt-siphon.lua`):** Created `belt-siphon.lua` to locate adjacent transport belts, underground belt hoods, splitters, and linked belts touching a Hub entity's bounding box. Scanned Factorio 2.0 `LuaTransportLine.get_contents()` item arrays and extracted available items using `line.remove_item()` while respecting Hub inventory slot filters (`inventory.is_filtered()`).
3. **Hub Chest Loading & Packing Integration (`scripts/hubs/hub-packing.lua`):** Integrated `belt_siphon.siphon_to_chest` into `hub_packing.evaluate_inventory` to pull cargo directly off touching belts into the Hub container when a `vacuum-capsule` is present, enabling inserter-free belt unloading while maintaining standard full-stack cargo packing rules.
4. **Real-Time Diagnostic Logging (`scripts/hubs/packing/belt-siphon.lua` & `scripts/hubs/hub-packing.lua`):** Added real-time chat log prints (`[BeltSiphon]` and `[HubPacking]`) tracking Hub evaluation, touching belt counts, transport line item contents, and extraction results.


### Revision: Vacuum Capsule Per-Item Durability Drain & In-Chest Spent Conversion
**Date:** 2026-09-08 12:59 (EDT)
**Context:** Implement Task 3 of the Vacuum Capsule plan, enforcing per-item durability drain during belt siphoning, immediate in-chest conversion to spent capsule shells upon charge depletion, and native C++ inventory filter checks.
**Key Changes:**
1. **Per-Item Charge Consumption & Durability Drain (`scripts/hubs/packing/belt-siphon.lua`):** Refactored `siphon_to_chest` in `belt-siphon.lua` to cap belt extractions by remaining tool durability (`max_take = math.min(item_count, stack_size, math.floor(cur_dur))`). Updated durability tracking to deduct exactly 1 durability point per individual siphoned item rather than per batch extraction.
2. **In-Chest Spent Capsule Conversion (`scripts/hubs/packing/belt-siphon.lua` & `scripts/hubs/hub-packing.lua`):** Implemented instant spent shell conversion (`spent-vacuum-capsule`) directly inside the hub chest inventory when a vacuum capsule's durability hits 0, preserving quality tiers and equipment grids. Updated `hub-packing.lua` to adopt converted spent capsule handles seamlessly during packing evaluations.
3. **Native Filter & Slot Selection Alignment (`scripts/hubs/packing/belt-siphon.lua`):** Removed the `passes_hub_filters` helper function which blocked siphoning on partially filtered chests, delegating slot filter, red bar slider, and slot availability validation directly to Factorio's native `chest_inv.can_insert()` C++ API.


### Revision: Item Health Charge System & Belt Siphoning Bug Fixes
**Date:** 2026-09-08 14:49 (EDT)
**Context:** Resolve non-recoverable Lua API errors (`Item is not tool`, `LuaItemPrototype doesn't contain key durability`), fix stuck vacuum capsule durability depletion, and prevent Factorio's native tool durability merge engine from destroying capsule items during hand or inventory transfers.
**Key Changes:**
1. **Item Prototype & Hand-Merge Prevention (`prototypes/item.lua`):** Converted `vacuum-capsule` and `refrigerated-capsule` from `type = "tool"` to standard `type = "item"` with `stack_size = 1`. This prevents Factorio's native C++ tool durability merging algorithm from combining damaged tool stacks and deleting capsule items when clicked or moved by hand.
2. **Health-Based Charge Tracking (`scripts/hubs/packing/belt-siphon.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Refactored charge tracking for vacuum and refrigerated capsules to use `stack.health` (0.0 to 1.0) instead of `stack.durability`. Eliminates invalid prototype/itemstack property index crashes while rendering a native charge health bar on capsule icons.
3. **Lua Item Transfer Guard (`scripts/utils/item-transfer-handler.lua`):** Fixed boolean operator evaluation (`and` instead of `or`) when inspecting tool properties on `LuaItemStack` during `transfer_stack()`, preventing C++ exceptions on standard non-tool cargo items.
4. **Dumb Siphon & Spent Conversion Engine (`scripts/hubs/packing/belt-siphon.lua`):** Updated belt siphoning charge calculations to use `math.ceil` so fractional charges extract final items down to zero, automatically converting depleted capsules to `spent-vacuum-capsule` shells while respecting native hub container filters and red-bar slot limits.


### Revision: Belt Siphon Decoupling & Independent Hub Siphoning Lifecycle
**Date:** 2026-09-08 15:15 (EDT)
**Context:** Decouple transport belt siphoning from the capsule packing and dispatch pipeline, elevating belt siphoning to an independent top-level Hub process in `hub-manager.lua` to run as a dumb inserter regardless of primary capsule selection or send/receive settings.
**Key Changes:**
1. **Top-Level Hub Siphon Lifecycle (`scripts/hubs/hub-manager.lua`):** Registered `belt_siphon` as a top-level require in `hub-manager.lua` and integrated `belt_siphon.siphon_to_chest(entity)` into the 10-tick background scan loop (`on_tick`) and `notify_settings_changed`, executing belt extractions unconditionally on active hubs containing a charged vacuum capsule.
2. **Packing Pipeline Clean Decoupling (`scripts/hubs/hub-packing.lua`):** Removed all belt siphoning calls and `belt-siphon` module imports from `hub-packing.lua`, eliminating the artificial restriction where vacuum capsules were blocked from siphoning unless selected as the first capsule for immediate dispatch.
3. **Primary Stack Insertion Fix (`scripts/hubs/hub-packing.lua`):** Fixed a syntax error on line 303 in `hub-packing.lua` by removing an extraneous token inside the primary capsule holder stack transfer loop.


### Revision: Quality-Scaled Capsule Charges & Health Drain Integration
**Context:** Restore quality-scaled charges (durability/health) for `vacuum-capsule` and `refrigerated-capsule` following their transition from tool prototypes to standard items with health percentage.
**Key Changes:**
1. **Dynamic Quality Charge Scaling Helper (`scripts/capsules/capsule-definitions.lua`):** Added `capsule_definitions.get_max_charges(def_or_name, quality_arg)` implementing standard Factorio quality scaling (`base * (1 + 0.3 * quality_level)`), yielding 100 charges at Normal, 130 at Uncommon, 160 at Rare, 190 at Epic, and 250 at Legendary. Added explicit `durability = 100` base charges to the `refrigerated-capsule` definition.
2. **Quality-Aware Belt Siphoning Engine (`scripts/hubs/packing/belt-siphon.lua`):** Updated `belt_siphon.siphon_to_chest` to evaluate max charges via `capsule_defs.get_max_charges(capsule_def, capsule_stack.quality)`, enabling higher-quality vacuum capsules to siphon proportionally more items off transport lines before depleting into spent shells.
3. **Refrigerated Spoilage Charge Scaling (`scripts/capsules/capsule-lifecycle.lua`):** Updated `capsule_lifecycle.update` to scale active cooling capacity against quality tier using `capsule_defs.get_max_charges(caps_def, stack.quality)`, extending active refrigeration duration proportionally with capsule quality tier.


### Revision: Pressure-Driven Belt Depositing, Near-Lane Sideloading & Gleba Stacking Integration
**Date:** 2026-09-08 19:12 (EDT)
**Context:** Transform the vacuum capsule belt interface from an agnostic siphon into a bidirectional, pressure-governed pneumatic system supporting automated belt depositing, strict orthogonal footprint checks, near-lane parallel sideloading, Space Age Gleba belt stacking, and tiered cargo ejection.
**Key Changes:**
1. **Pressure-Driven Siphon & Exhaust Engine (`scripts/hubs/packing/belt-siphon.lua`):** Added `get_hub_net_pressure` to evaluate net pneumatic pressure across Hub ports. Negative net pressure ($P_{\text{net}} < 0$) initiates vacuum siphoning off belts, positive net pressure ($P_{\text{net}} > 0$) triggers pneumatic exhaust depositing from chest onto belts, and neutral pressure ($P_{\text{net}} = 0$) keeps the hub idle to preserve charges.
2. **Strict Orthogonal Adjacency Guard (`scripts/hubs/packing/belt-siphon.lua`):** Implemented `is_strictly_adjacent` using axis-aligned bounding box projection. Rejects diagonal corners and belts extending beyond container bounds (such as belts flanking attached pneumatic tubes), restricting belt interaction strictly to tiles directly facing container walls.
3. **Near-Lane Parallel Sideloading (`scripts/hubs/packing/belt-siphon.lua`):** Implemented `get_deposit_line_indices` to determine active transport lines based on belt orientation and Hub contact wall. Parallel passing belts strictly sideload onto the near transport line touching the Hub (leaving the far lane open for independent logistics), while outbound head-on belts access all available lines.
4. **Gleba Belt Stacking Support (`scripts/hubs/packing/belt-siphon.lua`):** Integrated `force.belt_stack_size_bonus` into `deposit_to_belts` to calculate `max_belt_stack` (1 base, up to 4 with Space Age research). Deposits vertical item stacks up to the researched limit in a single drop via `line.insert_at_back(spec, allowed_stack)`, deducting 1 health charge point per individual item placed.
5. **Two-Tier Cargo Ejection & Self-Protection (`scripts/hubs/packing/belt-siphon.lua`):** Implemented `find_deposit_candidate_slot` to enforce cargo priority during belt ejection. The active working capsule cannot eject itself from the chest; Tier 1 prioritizes regular cargo items and inert spent shells (`spent-vacuum-capsule`), and Tier 2 only ejects surplus charged vacuum capsules once all Tier 1 items have been cleared.


### Revision: Capsule Recipe Economics, Recharge Loops & Durability Rebalance
**Date:** 2026-09-08 19:57 (EDT)
**Context:** Eliminate prohibitive operational resource drains on vacuum capsule belt siphoning, expand refrigerated capsule active cooling lifespan to prevent rapid expiration during logistics backpressure, and rebalance single-use biodegradable capsule crafting into an accessible organic packaging loop.
**Key Changes:**
1. **Vacuum Siphon Durability & Electric Repressurization (`prototypes/recipe.lua`, `scripts/capsules/capsule-definitions.lua`):** Raised `vacuum-capsule` base durability from 100 to 500 charges (scaling to 1,250 charges at Legendary). Overhauled `recharge-vacuum-capsule` to remove the 2-battery raw-resource tax in favor of closed-loop electric repressurization requiring only `spent-vacuum-capsule = 1` (`energy_required = 2.0`), and added `allow_productivity = false` to prevent duplication exploits.
2. **Refrigerated Cooling Lifespan Expansion (`scripts/capsules/capsule-definitions.lua`, `prototypes/recipe.lua`):** Increased `refrigerated-capsule` base durability from 100 to 600 charges, expanding active refrigeration from 1.6 minutes to 10 minutes at Normal quality (scaling up to 25 minutes at Legendary). This prevents single-trip deadheading and protects perishable cargo against queue backpressure. Added `allow_productivity = false` to `recharge-refrigerated-capsule`.
3. **Biodegradable Capsule Yield & Organic Repackaging (`prototypes/recipe.lua`, `prototypes/technology.lua`):** Replaced high-tier `carbon-fiber` and `sulfuric-acid` inputs on `biodegradable-capsule` with foundational Gleba staples (`1 yumako-mash`, `1 jelly`, `2 spoilage`) and raised output yield from 4 to 10 capsules (yielding 15 in Biochambers). Removed `carbon-fiber` and `sulfur-processing` technology prerequisites, gating the unlock directly on `agricultural-science-pack` and `pneumatic-transport`.


### Revision: Pneumatic Fence Gate Interoperability, Wall Axis Locking & Wavefront Discovery
**Date:** 2026-09-09 10:30 (EDT)
**Context:** Enable vanilla walls and fence gates to interface directly with the pneumatic logistics network without creating duplicate prototypes, implementing research gating, orthogonal exclusive-axis crossflow on walls, natural open/close wavefront cutoff on gates, and reactive grid-touch lazy discovery.
**Key Changes:**
1. **Interoperability Research Technology (`prototypes/technology.lua`):** Added the `pneumatic-fence-gate-interoperability` research node (prerequisites: `pneumatic-transport` and `gate`, 150 cycles @ 30s) authorizing the flow engine to link vanilla `stone-wall` and `gate` entities into pneumatic routing.
2. **Vanilla Wall & Gate Port Definitions (`scripts/flow/port-defs.lua`):** Added port definitions for `stone-wall` (4 boundary ports split into isolated dual-channel groups: Group 1 North/South, Group 2 West/East) and `gate` (2 directional inline boundary ports per orientation). Added explicit cardinal normal vectors (`dir = {x, y}`) to all port definitions on counters, walls, and gates, eliminating diagonal projection errors during boundary discovery off multi-tile 2x1 entities. Restricted `port_defs.registered_names` strictly to dedicated pneumatic structures to prevent global surface scans on startup from registering map perimeter walls.
3. **Reactive Grid-Touch & Queue-Driven Discovery (`scripts/flow/flow-engine.lua`):** Implemented `is_touching_pneumatic_grid` in `build_events` to immediately connect standard entities placed directly touching active ports (`storage.flow_grid`) and enqueue neighbors in O(1) time without registering unlinked perimeter defense walls. Configured open boundary wavefront propagation in `step()` to lazily discover and connect single adjacent entities tile-by-tile within the flow queue without recursive BFS flood-fills.
4. **Wall Single-Axis Lock & Depressurization Crossflow Wakeup (`scripts/flow/flow-engine.lua`):** Implemented exclusive directional axis locking on `stone-wall` (`storage.wall_locked_group`) triggered by either pressure flow ($P \ne 0$) or sensing range ($S > 0$), disabling transmission on the idle orthogonal pair. Complete depressurization ($P=0, S=0$) clears the lock, restores all transmission flags to `true`, and enqueues ports while calling `wake_port_parked` to wake queued crossflow capsules.
5. **Terminator Gate State Cutoff & Regrowth (`scripts/flow/flow-engine.lua`):** Implemented `is_gate_terminator` to identify boundary gate endpoints in O(1) time. Opening a gate disables transmission flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) strictly on outer terminator gates while leaving interior gates active as standard pass-through tubes, allowing downstream pressure to naturally recede tile-by-tile through `flow_queue`. Closing any gate restores all transmission flags to `true` and enqueues ports to step pressure forward through the crossing.
6. **Sensing Flow Wavefront & Counter Parity (`scripts/flow/flow-engine.lua`):** Added dynamic counter registration into `storage.active_counters` and power tracking in `connect_entity`, ensuring sensing range wavefronts ($15$ decaying down to $1$) participate in the exact same boundary discovery, wall-axis locking, and queue advancement schemes as pressure flow.


### Revision: Fence Gate Sensing Persistence & Throttled Interop Activation Queue
**Date:** 2026-09-09 10:52 (EDT)
**Context:** Maintain continuous Capsule Counter sensing across open fence gate thresholds while physically containing cargo and gas pressure, and introduce a lightweight, rate-limited soft-registration and activation queue for standard defensive walls and gates placed adjacent to active flow ports prior to completing interoperability research.
**Key Changes:**
1. **Gate Crossing Sensing Continuity (`scripts/flow/flow-engine.lua`):** Updated terminator gate transition logic in `flow_engine.step` to strictly disable `capsule_transmit = false` and `pressure_transmit = false` upon opening while leaving `sense_transmit = true` intact. This prevents Capsule Counters from dropping territorial ownership or zeroing cargo signals when gates open for passing trains, vehicles, or players.
2. **Immediate Boundary Soft-Registry (`scripts/flow/flow-engine.lua`):** Added `flow_engine.is_touching_active_flow` and `storage.soft_interop_registry` to pre-emptively index unresearched `stone-wall` and `gate` entities built immediately facing ports with active pressure ($P \ne 0$), sensing range ($S > 0$), or active pump/diverter emitters. Extended lazy discovery in `discover_adjacent_standard_entity` to register boundary walls when active flow reaches them, enforcing strict single-tile non-chaining to protect map perimeter walls from premature registration.
3. **Throttled Multi-Tick Research Activation (`scripts/flow/flow-engine.lua`):** Added `on_research_finished` listener for `pneumatic-fence-gate-interoperability`, migrating force-matching soft-registered entities into `storage.interop_activation_queue` in O(1) time without synchronous entity connections. Configured `flow_engine.step` to drain a rate-limited batch (`INTEROP_BATCH_SIZE = 10`) each tick, connecting boundary nodes, waking parked capsules, and feeding downstream wall runs smoothly into `storage.flow_queue` without single-frame lag spikes.


### Revision: Blueprint Ghost Gate Crash Fix & Active State Decoupling
**Date:** 2026-09-09 12:33 (EDT)
**Context:** Resolve non-recoverable `Entity is not gate` runtime crash triggered when stamping blueprints containing gate entities, establishing clean separation between blueprint ghost spatial topology and physical runtime simulation polling.
**Key Changes:**
1. **Physical Entity Filter for Dynamic Polling (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to register entities into active state tables (`storage.active_gates` and `storage.active_counters`) strictly when `entity.name == "gate"` or `entity.name == "pneumatic-capsule-counter"`. Blueprint ghosts (`entity-ghost`) bypass open/closed state tracking while still cleanly registering spatial port nodes into `storage.flow_nodes` and `storage.flow_grid` for connection continuity.
2. **Elimination of Ghost C++ Method Assertions (`scripts/flow/flow-engine.lua`):** Prevented calling gate-specific C++ member function `entity.is_closed()` on ghost entities during blueprint stamping and background `step()` ticks. Physical gates are seamlessly promoted into active state polling when built/revived by construction robots without requiring redundant defensive guards across pumps and diverters.


### Revision: Blueprint Ghost Simulation Exclusion & Pure Visual Parity
**Date:** 2026-09-09 12:39 (EDT)
**Context:** Prevent unbuilt blueprint ghost entities (`entity-ghost`) from participating in runtime pneumatic flow, sensing wavefront propagation, and pre-emptive soft-registration prior to physical construction by robots.
**Key Changes:**
1. **Flow Grid Ghost Exclusion Guard (`scripts/flow/flow-engine.lua`):** Added an early-exit guard (`if entity.name == "entity-ghost" then return end`) at the entry of `flow_engine.connect_entity`. Blueprint ghost tubes, walls, gates, and counters no longer create physical port nodes, channel pressure, or display phantom Alt-Mode sensing overlays before being physically built.
2. **Ghost Suppression in Build Listeners (`scripts/flow/flow-engine.lua`):** Added an immediate ghost check to the top-level `build_events` listener, preventing unbuilt ghost walls and gates from entering `storage.soft_interop_registry` prematurely. Construction robot builds and revives (`on_robot_built_entity`, `script_raised_revive`) naturally pass physical entities through to connection and registration the exact tick they become physical matter.


### Revision: Space Age Machine Categories, Rocket Payload Capacity & Locale Sync
**Date:** 2026-09-09 14:38 (EDT)
**Context:** Align specialized Space Age capsule recipes with their planetary signature production facilities, eliminate the 1-capsule-per-rocket shipping bottleneck on single-stack items, and synchronize the English locale to remove stale tooltips and add missing research and proxy entries.
**Key Changes:**
1. **Planetary Super Machine Crafting Categories (`prototypes/recipe.lua`):** Standardized recipe `categories` tables across specialized capsules to leverage planetary machine bonuses: set `reinforced-capsule` to `{"metallurgy"}` (Foundry, +50% productivity), `electromagnetic-capsule` to `{"electromagnetics"}` (Electromagnetic Plant, +50% productivity), `refrigerated-capsule` and `recharge-refrigerated-capsule` to `{"cryogenics"}` (Cryogenic Plant), and `vacuum-capsule` and `recharge-vacuum-capsule` to explicit `{"crafting"}` (Assembling Machine).
2. **Capsule Rocket Capacity & Weight Scaling (`prototypes/item.lua`):** Configured explicit `weight = 50 * kg` across all nine active and spent capsule prototypes (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, `electromagnetic-capsule`, `vacuum-capsule`, `spent-vacuum-capsule`, and `player-transit-capsule`). This overrides the default 1,000 kg fallback calculation ($1000\text{ kg} / \text{stack\_size}$), establishing a clean 20-capsule rocket capacity per launch ($1000\text{ kg} / 50\text{ kg} = 20$) for both initial deployments and returning spent shell logistics.
3. **Fence Gate Interoperability & Proxy Localization (`locale/en/config.cfg`):** Added missing localized names and descriptions for the `pneumatic-fence-gate-interoperability` research node. Added entity names for hidden channel proxies (`pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy`) to ensure full engine parity.
4. **Recharging Loop & Tech Description Corrections (`locale/en/config.cfg`):** Replaced outdated assembling machine recharging descriptions on `refrigerated-capsule` and `spent-refrigerated-capsule` with Cryogenic Plant instructions; updated `recharge-vacuum-capsule` description to reflect closed-loop electric repressurization instead of obsolete battery consumption; and corrected `specialized-pneumatic-capsules` tech description to accurately list diverters, crossflow junctions, and player transit capsules instead of planet-bound variants.
5. **Custom Input & UI Control Strings (`locale/en/config.cfg`):** Added localization entries for custom inputs (`pneumatic-copy-settings`, `pneumatic-paste-settings`, `pneumatic-confirm-gui`) and registered shortcut and debug panel toggles for Capsule Counter range overlays (`pt-toggle-counter-range`, `toggle-counter-range`).


### Revision: Fence Gate Interop Reversal, Boundary Cutoff & Zero-Level Soft Demotion
**Date:** 2026-09-09 15:07 (EDT)
**Context:** Ensure graceful, non-destructive flow recession and full lifecycle idempotence when `pneumatic-fence-gate-interoperability` research is reversed (via Map Editor, console `/reset-technologies`, or tech overhaul mods), avoiding abrupt node deletions, stranding in-flight capsules, or leaving orphaned wall nodes in persistent storage.
**Key Changes:**
1. **Research Reversal Event Listener (`scripts/flow/flow-engine.lua`):** Registered a listener for `defines.events.on_research_reversed` filtering for `pneumatic-fence-gate-interoperability`, routing directly to `flow_engine.handle_interop_research_reversed` to initiate orderly network unlinking.
2. **Direct Entity Reference Storage (`scripts/flow/flow-engine.lua`):** Upgraded `storage.active_walls[unit_number]` from a boolean `true` flag to store the live `LuaEntity` reference, bringing it to parity with `active_gates` and enabling instant O(1) force-matching checks without redundant surface queries.
3. **Boundary Cutoff & Interface Queue Injection (`scripts/flow/flow-engine.lua`):** Implemented `handle_interop_research_reversed` to systematically identify and sever only the boundary connection edges where registered pneumatic infrastructure interfaces with walls and gates. Destroys Alt-Mode boundary vector lines, enqueues both the pneumatic and wall interface ports into `storage.flow_queue`, wakes parked capsules (`wake_port_parked`), and returns queued activation entities back to `storage.soft_interop_registry`.
4. **Zero-Equilibrium Soft Demotion (`scripts/flow/flow-engine.lua`):** Extended `flow_engine.step` to monitor depressurizing walls and gates. When an unresearched wall or gate reaches absolute equilibrium (P = 0, S = 0) across all port channels, it calls `flow_engine.disconnect_entity()` and transitions the structure into `storage.soft_interop_registry`, ensuring complete lifecycle reversibility without memory leaks or stranded capsules.


### Revision: Fast-Replace & Quality Upgrade Settings Inheritance
**Date:** 2026-09-09 16:46 (EDT)
**Context:** Prevent loss of custom port configurations, circuit conditions, filters, and container nesting rules when fast-replacing or upgrading pneumatic machines in-place from player inventory or via construction robots.
**Key Changes:**
1. **Fast-Replace Co-Existence Spatial Query (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Extended `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` with an `exclude_entity` parameter, enabling reliable discovery of co-existing real machines occupying the exact tile coordinate during the engine's fast-replace transition window.
2. **Destruction-Phase Proactive Settings Transfer (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Updated entity removal listeners (`destroy_events`, `on_hub_removed`) to detect active replacement entities on the surface and execute direct deep-copy settings migration (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `hub_settings.copy`) prior to wiping the decommissioned unit number's runtime records.
3. **Tick-Scoped Positional Fallback Cache (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Added `storage.fast_replace_cache` and `storage.hub_fast_replace_cache` to preserve deep-copied settings keyed by spatial coordinates on the destruction tick. This guarantees `on_built_entity` and `on_hub_built` adopt predecessor configurations even if event dispatch order completes entity removal before build registration, suppressing default resets and pruning stale cache records after 60 ticks.


### Revision: Gate Reorientation Lifecycle, Terminator Cutoff Sync & Connection Wakeups
**Date:** 2026-09-09 17:08 (EDT)
**Context:** Fix pneumatic flow failure and stalled queues caused by rotating misaligned gates and walls after placement, eliminate stale cutoff flags on open boundary gates when neighbors are added or removed, and ensure instantaneous queue waking on spatial edge formation.
**Key Changes:**
1. **Reactive Reorientation Lifecycle (`scripts/flow/flow-engine.lua`):** Replaced restrictive registered-port checks in `on_player_rotated_entity` and `on_player_flipped_entity` with a unified `handle_entity_reorientation` handler. Re-evaluates `is_touching_pneumatic_grid` whenever standard entities (`gate`, `stone-wall`) are rotated or flipped, connecting newly aligned structures and enqueuing flow without requiring players to mine and rebuild them. Cleanly disconnects structures rotated away from the network.
2. **Dynamic Terminator Boundary Sync (`scripts/flow/flow-engine.lua`):** Added `storage.gate_cutoff_states` alongside `gate_open_states` in `flow_engine.step` to monitor `is_term = (is_open and is_gate_terminator(unit_number))`. Automatically lifts or applies pressure and capsule cutoffs when adjacent gates are built, rotated, or deconstructed, updating transmission flags and waking ports without waiting for gates to cycle closed and open.
3. **Connection Idempotency & Edge-Formation Wakeups (`scripts/flow/flow-engine.lua`):** Added pre-emptive disconnection in `connect_entity` to ensure atomic node rebuilds during rapid rotation cycles. Invoked `wake_port_parked` on both ends of newly linked edges in `storage.flow_connections`, waking parked capsules and advancing queued traffic on the exact tick a path opens.

#### 0.3.2

### Revision: Continuous Belt Siphon Throughput & 60Hz Cadence Optimization
**Date:** 2026-09-09 18:53 (EDT)
**Context:** Eliminate choppy, spaced item bursts on transport lines by decoupling belt siphoning/depositing from the 10-tick interleaved hub packing loop and implementing fast-path early exit filtering.
**Key Changes:**
1. **1-Tick Belt Interface Cadence (`scripts/hubs/hub-manager.lua`):** Decoupled `belt_siphon.process_belts(entity)` from the interleaved `(unit_number + current_tick) % 10 == 0` scan loop, executing belt evaluations on every tick for active hubs while preserving 10-tick pacing for `hub_packing.evaluate_inventory`. This allows adjacent transport lines to accept items/stacks as soon as belt movement clears space, eliminating gaps and achieving 100% belt compression.
2. **Pressure & Inventory Fast-Path Early Exits (`scripts/hubs/packing/belt-siphon.lua`):** Reordered checks in `process_belts` to evaluate `get_hub_net_pressure` first, skipping neutral and unpressurized hubs with zero entity/inventory overhead. Added `chest_inv.is_empty()` checks alongside native C++ `chest_inv.find_item_stack("vacuum-capsule")` lookups to eliminate full 48-slot Lua iterations across non-siphon hubs.
3. **Engine-Filtered Adjacent Belt Querying (`scripts/hubs/packing/belt-siphon.lua`):** Updated `find_adjacent_belts` to pass `type = BELT_SEARCH_TYPES` (`transport-belt`, `underground-belt`, `splitter`, `linked-belt`) directly to `surface.find_entities_filtered`, allowing the C++ engine to filter out adjacent non-belt structures (electric poles, inserters, pneumatic tubes) before allocating Lua entity arrays.


### Revision: Cargo-First Belt Ejection & Spent Hull Packing Priority
**Date:** 2026-09-09 20:47 (EDT)
**Context:** Prevent spent capsule shells from cutting in front of bulk cargo during belt depositing, and prioritize spent hulls over working unloader engines during outbound hub packing to preserve outpost belt operations.
**Key Changes:**
1. **Cargo-First Deposit Priority Hierarchy (`scripts/hubs/packing/belt-siphon.lua`):** Refactored `find_deposit_candidate_slot` into a 3-tier candidate selector (Pure Cargo > Spent Capsules > Secondary Charged Capsules). Bulk cargo now empties onto transport lines before dead shells, eliminating cargo belt contamination and giving chest-mounted filter inserters ample swing time to extract spent capsules directly into recycling lines.
2. **Spent Hull Outbound Packing Priority (`scripts/hubs/packing/hub-packing.lua`):** Replaced the first-match slot scan in `hub_packing.evaluate_inventory` with a tiered candidate evaluator targeting spent hulls (`SPENT_CAPSULES`) first, standard cargo capsules second, and lowest-health charged capsules last. Outbound shipments now draft empty shells to transport return freight home to base recharge infrastructure while preserving working, full-durability vacuum capsules in the outpost hub chest to keep belt unloaders active.



#### 0.3.21

### Revision: Electromagnetic Projector Prototypes, Fulgora Tech Tree & Economics
**Date:** 2026-09-10 09:49 (EDT)
**Context:** Register data-stage prototypes, scaled entity visuals, circuit proxy, Fulgora-tier electromagnetic recipe, and technology unlocks for the Electromagnetic Projector facility ahead of kinetic flow simulation.
**Key Changes:**
1. **Electromagnetic Projector Entity & Circuit Proxy (`prototypes/pneumatic-projector.lua`):** Implemented `pneumatic-projector` as a 3x3 `electric-energy-interface` with centered collision/selection boxes (`selection_priority = 50`), configured for a 3 MW passive idle drain, 9 MJ buffer capacity, and 9 MW input flow limit. Composited a 0.75x scaled, magenta-tinted visual animation derived from the Space Age electromagnetic plant chassis. Created the companion `pneumatic-projector-circuit-proxy` (`constant-combinator`, `selection_priority = 60`, `operable = true`, `placeable_by = {item = "pneumatic-projector", count = 0}`) to support wire attachments and circuit automation.
2. **Infrastructure Line Item (`prototypes/item.lua`):** Registered the `pneumatic-projector` item in `subgroup = "pneumatic-transport"` (`order = "i[projector]"`) with a stack size of 10 and standardized payload weight of `50 * kg`.
3. **Fulgora Planetary Crafting Recipe (`prototypes/recipe.lua`):** Added the `pneumatic-projector` recipe with `categories = {"electromagnetics"}`, preventing hand-crafting and restricting production to Fulgora Electromagnetic Plants using 25 holmium plates, 10 supercapacitors, 10 processing units, 20 steel plates, and 10 pneumatic tubes.
4. **Research Tree Expansion (`prototypes/technology.lua`):** Added the `pneumatic-projector` research node (350 units @ 45s) gated behind `electromagnetic-science-pack`, `pneumatic-transport`, and `electromagnetic-capsule` prerequisites.
5. **Data Pipeline & Locale Registration (`data.lua`, `locale/en/config.cfg`):** Wired `prototypes.pneumatic-projector` into the root prototype loader and populated complete English locale mappings for entity, item, recipe, and technology entries.


### Revision: Electromagnetic Projector Device State, Proxy Linkage & Scanner Integration
**Date:** 2026-09-10 10:30 (EDT)
**Context:** Implement device state persistence, circuit proxy lifecycle, active power/enable scanning, muzzle orientation controls, and blueprint copy-paste serialization for the Electromagnetic Projector facility ahead of ballistic simulation.
**Key Changes:**
1. **Projector Settings & 3 MW Baseline Power Logic (`scripts/projector-settings.lua`):** Created `storage.projector_settings` schema tracking launch muzzle orientation (`muzzle_dir`), enable status, wire channels, and circuit network enable conditions. Enforced a 3 MW electrical baseline requirement (`MINIMUM_ENERGY_JOULES = 3000000`, 3 MJ buffer threshold) to suppress emission during power cutoffs or brownouts.
2. **Circuit Proxy Registration & Storage Bootstrap (`scripts/proxy-manager.lua`, `control.lua`):** Registered the `pneumatic-projector` and `pneumatic-projector-circuit-proxy` pair with `proxy_manager`, ensuring automatic wire bridging, additive wire merging on replacement, and object destruction cleanup. Initialized projector storage collections (`active_projectors`, `projector_settings`, `projector_power_states`, `projector_enabled_states`, and `projector_muzzle_states`) within `setup_storage()`.
3. **15-Tick Scanner & Dynamic Port Re-Enqueuing (`scripts/active-device-scanner.lua`):** Integrated `pneumatic-projector` into the background scanner loop. Monitored power states, circuit enable evaluations, and muzzle orientations, triggering `flow_engine.enqueue_unit_ports` and `capsule_runner.wake_parked_capsules` upon state transitions to collapse or restore kinetic beams immediately. Added ghost settings inheritance and 60-tick fast-replacement fallback caching.
4. **Dynamic Muzzle Routing (`scripts/flow/port-defs.lua`):** Enhanced `port_defs.get_ports` to look up configured muzzle orientations dynamically across built and ghost entity IDs, allowing machines to route designated launch muzzles and passive intake ports across cardinal directions.
5. **Blueprint Tag Serialization & Live Copy-Paste (`scripts/device-settings-copier.lua`):** Added `pneumatic-projector` and proxy resolution to `device_settings_copier`. Implemented relative muzzle direction adjustments during live Shift+Left-Click copy-paste and blueprint stamping, with atomic wire connector serialization via `pneumatic_settings` tags.


### Revision: Ballistic Motion Runner, Receiver Catchment & Terminal Crash Mechanics
**Date:** 2026-09-10 10:47 (EDT)
**Context:** Implement accelerated kinetic trajectory simulation, strict electromagnetic payload gatekeeping, receiving facility catchment, obstacle severance crash handling, and projector dock occupancy decoupling for the Electromagnetic Projector facility.
**Key Changes:**
1. **Ballistic Motion Engine & EM Gatekeeping (`scripts/capsules/capsule-runner.lua`):** Enforced payload identity checks (`is_electromagnetic_capsule`) across `is_hop_valid` and `select_next_target`, rejecting non-electromagnetic capsules from entering projector intake ports or launch muzzles. Overrode the default 6-tick hop stagger for `is_beam_node` capsules, advancing active payloads at 1 hop per tick (5 tiles/tick) sequentially down the projector beam's trajectory.
2. **Receiver Catchment & Tube Network Injection (`scripts/capsules/capsule-runner.lua`):** Implemented `catch_in_receiver` within `handle_arrival` to capture capsules arriving at endpoint hops contacting a receiving `pneumatic-projector` footprint. Dynamically queries non-muzzle receiver ports for connected external pneumatic lines, validates tube capacity and downstream pressure gradients, and injects payloads directly into outbound logistics tubes while parking arrivals safely if lines are saturated.
3. **Terminal Crash Spillage & Mid-Flight Severance (`scripts/capsules/capsule-runner.lua`, `scripts/hubs/hub-spill.lua`):** Routed unaligned beam terminations, cliff dead-ends, or destroyed receivers into `hub_spill.spill_capsule` at the endpoint position, spawning an explosion and deploying red-locked (`set_bar(1)`), deconstructable `visible-capsule-holder` spill containers. Tracked tick-by-tick `last_pos` coordinates so capsules whose beam nodes are severed mid-flight safely crash at the obstacle tile. Updated `hub_spill.handle_entity_destruction` to exclude `is_beam_node` capsules during machine deconstruction, allowing mid-air payloads to finish trajectories.
4. **Collision Raycast Optimization & Beam Dock Decoupling (`scripts/flow/flow-engine.lua`, `scripts/capsules/capsule-queries.lua`):** Replaced Lua pattern matching (`cand_name:find("%-proxy$")`) in line-of-sight raycasting with an exact $O(1)$ set lookup (`PROXY_NAMES`). Standardized beam port keys to integer indices (`100 + hop_index`) and updated `get_capsule_count_at_entity` to exclude in-flight beam payloads from physical projector chassis occupancy, enabling continuous high-throughput launching.


### Revision: Alt-Mode Kinetic Overlays, Particle FX & Ballistic Mid-Air Edge Hardening
**Date:** 2026-09-10 11:06 (EDT)
**Context:** Implement Alt-Mode kinetic beam trajectory rendering with quality-tier visual scaling, high-energy electrical sound and particle effects, resilient in-flight momentum preservation against machine mining, and resolve premature capsule spillage at intake ports.
**Key Changes:**
1. **Alt-Mode Beam Overlays & Quality Scaling (`scripts/flow/flow-engine.lua`):** Integrated `storage.beam_renders` tracking kinetic beam trajectories in Alt-Mode. Rendered core trajectory lines between launch muzzles and terminal targets, directional hop markers at 5-tile intervals, and contextual endpoint indicators (cyan/green target rings for aligned receivers, coral hazard indicators for severed or open-air paths). Implemented `QUALITY_BEAM_PALETTE` scaling beam thickness (4.0px to 6.0px) and shifting color from holmium magenta to radiant white-magenta across quality tiers. Wired beam cleanup into `draw_flow`, `clear_flow_renders`, `update_projector_beam`, and `disconnect_entity`.
2. **Launch, Flight & Capture Audio-Visual FX (`scripts/capsules/capsule-runner.lua`):** Added electrical audio and particle triggers across kinetic trajectories: dispatch spark bursts and wire-connect audio at launch muzzles (`play_dispatch_effects`), travel spark particles at each hop node (`play_flight_effects`), and magnetic catchment sound effects upon receiver entry (`play_catchment_effects`), all safely isolated within `pcall` guards.
3. **Ballistic Momentum & Mid-Air Machine Deconstruction Hardening (`scripts/capsules/capsule-runner.lua`):** Created `init_capsule_beam_flight` to persist projected hop coordinates (`hop_positions`), directional vectors, and target receiver IDs onto `capsule.beam_flight` upon launch. If a sender projector is mined or destroyed mid-transit, in-flight capsules advance along cached ballistic hop coordinates tick-by-tick at 5 tiles/tick, safely reaching downstream receivers or triggering crash spillage at the terminal tile without nil reference errors.
4. **Intake False-Crash & Endpoint Arrival Rectification (`scripts/capsules/capsule-runner.lua`):** Eliminated an overly broad mid-hop AABB collision scan that falsely flagged connected intake tubes as blocking obstacles. Rectified `handle_arrival` endpoint evaluation so terminal landing logic is strictly constrained to `node.is_beam_node and node.is_endpoint` or dead-sender flights, preventing newly intook capsules from prematurely triggering crash landings before exiting the facility. Guarded receiver catchment against launch muzzles using `kinetic_transmit` checks.
5. **Sandbox Cleanup Commands & Overlay Toggle Sync (`scripts/debug-manager.lua`):** Added `/clear-renders` (and alias `/pt-clear-renders`) console commands to wipe and reconstruct all active Alt-Mode pressure, counter, and kinetic beam overlays during sandbox testing. Updated the debug panel checkbox caption and feedback messages to reflect combined gas flow and kinetic beam rendering.


### Revision: Passive Projector Port Geometry & Hub Interface Parity
**Date:** 2026-09-10 11:25 (EDT)
**Context:** Reconfigure the Electromagnetic Projector's pneumatic interface to operate strictly as a passive hub-style endpoint, eliminating vacuum pressure generation and isolating the pneumatic network from kinetic launch ports.
**Key Changes:**
1. **Passive Tube Intake Parity (`scripts/flow/port-defs.lua`):** Stripped the legacy `flow = -10` vacuum emission across all three intake ports in all four cardinal directions, standardizing them with `flow = 0`, `emitter = 0`, `pressure_transmit = false`, and `sense_transmit = false`. Connected tube networks retain independent ambient pressure, requiring external pumps or pressurized lines to push capsules into the projector without artificial vacuum draw.
2. **Isolated Kinetic Muzzle Configuration (`scripts/flow/port-defs.lua`):** Configured the directional launch muzzle strictly for kinetic routing (`kinetic_transmit = true`, `is_muzzle = true`) with complete pneumatic and sensing isolation (`flow = 0`, `emitter = 0`, `pressure_transmit = false`, `sense_transmit = false`), preventing pneumatic pressure leaks onto kinetic trajectories.
3. **Machine State & Device Scanner Audit (`scripts/projector-settings.lua`, `scripts/active-device-scanner.lua`):** Audited background scanner routines and machine setting handlers to ensure dynamic muzzle rotations and 15-tick power evaluations enqueue zero-emission ports into the flow engine without balancing or pushing gas levels.


### Revision: Queue-Driven Kinetic Wavefront & Dual-Tier Node Topology
**Date:** 2026-09-10 11:32 (EDT)
**Context:** Eliminate synchronous 50-tile raycasts by implementing an incremental, queue-driven kinetic wavefront engine in flow-engine.lua, establishing dual-tier minor and prominent kinetic node topology, and enabling 1-tile-per-tick beam growth and recession with 0-tick idle queue sleep.
**Key Changes:**
1. **Queue-Driven Incremental Wavefront Engine (`scripts/flow/flow-engine.lua`):** Replaced synchronous 50-tile line-of-sight raycasting loops in `update_projector_beam` with `storage.kinetic_queue` processed directly within `flow_engine.step`, advancing or receding active kinetic beams at 1 tile per tick. The queue automatically returns on line 1 during steady-state equilibrium or idle power states, enforcing 0-tick idle sleep with zero allocations.
2. **Dual-Tier Kinetic Node Topology (`scripts/flow/flow-engine.lua`):** Segmented kinetic beam trajectories into distinct minor and prominent node classifications. Intermediate 1-tile nodes are registered in `storage.flow_nodes` and `storage.flow_grid` with `is_minor_kinetic = true` and `capsule_transmit = false` for continuous building occlusion detection and tile footprint mapping (`storage.kinetic_beam_tiles`). Every 5th tile and terminal endpoints are flagged with `is_prominent_kinetic = true`, `is_beam_node = true`, and `capsule_transmit = true`, forming the sequential ballistic hop chain in `storage.flow_connections`.
3. **Obstacle Occlusion Interception & Queue-Driven Recession (`scripts/flow/flow-engine.lua`):** Updated entity build and removal hooks to enqueue affected projectors via `get_entity_affected_projectors` into `storage.kinetic_queue`. Beams obstructed mid-trajectory recede step-by-step at 1 tile per tick back to the obstacle tile, re-anchoring endpoint status and waking parked capsules, while unpowered or circuit-disabled machines drain cleanly to zero without instant deletion spikes. Deconstructed or destroyed facilities preserve instant purge lifecycle guarantees.


### Revision: Unified Kinetic Wavefront Propagation & Discrete Alt-Mode Overlays
**Date:** 2026-09-10 12:25 (EDT)
**Context:** Align kinetic beam propagation with core flow engine mechanics by replacing parallel custom beam sub-systems with standard delta wavefront queue processing, eliminating line/donut visual clutter in favor of clean discrete dots, and enabling natural 1-tile-per-tick queue-driven recession on rotation, unpowering, and entity removal.
**Key Changes:**
1. **Unified Flow Wavefront Integration (`scripts/flow/flow-engine.lua`):** Stripped out parallel beam management subroutines (`storage.projector_beams`, `storage.receding_beams`, `step_kinetic_beams`) in favor of direct delta wavefront queue processing (`storage.flow_queue`, `compute_port_kinetic_level`). Kinetic flow now propagates, balances, and drains identically to gas pressure and counter sensing range, advancing and receding tile-by-tile at 1 tile per tick with 0-tick idle queue sleep.
2. **Direction-Scoped Node Topology (`scripts/flow/flow-engine.lua`):** Replaced ambiguous unit-distance port keys with direction-scoped identifiers (`kinetic:unit:dx,dy:dist`). This prevents port key collisions during entity rotation, allowing previous trajectories to smoothly drain and recede out of existence while new directions advance without graph corruption or orphaned nodes.
3. **Discrete Per-Tile Visuals & Userdata Lifecycle Purge (`scripts/flow/flow-engine.lua`):** Completely removed continuous solid laser lines (`rendering.draw_line`) and concentric unfilled circle clutter. Implemented a 1:1 tile-mapped rendering registry (`storage.kinetic_renders[pos_key]`) displaying subtle 0.08-radius filled dots on minor nodes, 0.16-radius charged markers every 5th hop, and a single target circle strictly at actual terminal endpoints. Fixed Factorio `userdata` render object deletion checks so rendered dots reliably destroy when tiles recede, entities rotate, or machines are mined.
4. **Device Scanner Unregistration Cleanup (`scripts/active-device-scanner.lua`):** Removed obsolete custom beam purge calls (`flow_engine.clear_projector_beam`) from `on_unregister`, aligning projector removal semantics with standard pumps and diverters and delegating flow drainage cleanly to standard engine event listeners.


### Revision: Ballistic Prominent Hops, Mid-Air Occlusion & Passive Projector Intake Parity
**Date:** 2026-09-10 13:25 (EDT)
**Context:** Synchronize the ballistic motion runner with dual-tier 5-tile prominent kinetic nodes, resolve intake port rejection by establishing hub-style passive dock parity, and implement mid-air obstacle crash spillage and receiver catchment.
**Key Changes:**
1. **Ballistic 5-Tile Prominent Hops & Occlusion Cutoff (`scripts/capsules/capsule-runner.lua`):** Refactored `select_next_target` to navigate kinetic trajectories strictly along prominent nodes (`dist % 5 == 0` or endpoints) at 5 tiles/tick, bypassing intermediate minor nodes for hops. Implemented mid-air line-of-sight obstacle interception scanning upcoming tiles; payloads obstructed by newly placed buildings or severed lines immediately crash-land at the obstacle coordinate via `hub_spill.spill_capsule` with explosion FX and red-locked spill container deployment. Extended intermediate obstacle raycasting to dead-sender ballistic flights (`capsule.beam_flight`).
2. **Passive Hub-Style Intake Parity & Emitter Bugfix (`scripts/flow/port-defs.lua`, `scripts/capsules/capsule-runner.lua`):** Stripped `flow = 0, emitter = 0` from projector intake ports in `port-defs.lua` to match `capsule-hub` passive container ports. Fixed a critical evaluation bug in `is_hop_valid` where `target_node.emitter = 0` was falsely evaluated as an unpowered active pump, which had caused 100% of incoming capsule hops to fail. Removed artificial dock gatekeeping so incoming capsules from connected pneumatic tubes enter the projector dock freely.
3. **Direction-Scoped Port Resolution & Dock Decoupling (`scripts/capsules/capsule-queries.lua`, `scripts/capsules/capsule-manager.lua`):** Updated `capsule_queries.get_port_info` with direct `storage.flow_nodes` lookups and native parser support for `"kinetic:<unit>:<dx>,<dy>:<dist>"` port keys (`port_index = 100 + dist`), resolving broken capacity queries along kinetic trajectories. Updated `capsule_manager.register` to record `capsule_type = capsule_item_name` on active capsule storage. Excluded both `node.is_beam_node` and `node.is_kinetic` nodes from physical chassis occupancy counts.
4. **Dynamic Occlusion Interception & Destruction Purge (`scripts/flow/flow-engine.lua`):** Promoted `flow_engine.check_tile_obstruction` to a shared public line-of-sight API. Added bounding-box intersection scans across `build_events` and `removal_events` so placing structures over active beams initiates queue-driven recession back to the obstacle, while mining obstructions clears terminal tags and automatically re-propagates the beam. Enforced immediate Alt-Mode render and node purges during projector deconstruction in `flow_engine.disconnect_entity`.
5. **Receiver Catchment Integration (`scripts/capsules/capsule-runner.lua`):** Updated `catch_in_receiver` to inspect receiving projector non-muzzle ports for connected external lines, validate tube capacity, and enforce downstream air pressure gradients (`drop = -ext_level >= 0`, rejecting opposing positive back-pressure). Arriving payloads inject cleanly into outbound logistics tubes or park safely at the receiver dock if lines are saturated.


### Revision: Natural Queue-Driven Beam Recession on Rotation & Projector Dock Parity
**Date:** 2026-09-10 13:35 (EDT)
**Context:** Restore 1-tile-per-tick queue-driven kinetic beam recession on projector rotation by scoping synchronous purges strictly to entity destruction, eliminate false unpowered emitter evaluation on zero-flow ports, and establish hub-style passive dock admission.
**Key Changes:**
1. **Rotation-Driven Queue Recession Restoration (`scripts/flow/flow-engine.lua`):** Removed the synchronous beam wipe loop from `flow_engine.disconnect_entity`. Rotating or flipping a projector now cleanly unlinks the predecessor muzzle from Tile 1 and enqueues Tile 1 into `storage.flow_queue`, allowing the old beam to recede step-by-step at 1 tile per tick through the established delta queue while the new muzzle vector advances forward at 1 tile per tick. Scoped instant visual render and node purges strictly to true entity destruction events in `flow_engine.handle_object_destroyed`.
2. **Emitter Truthiness & Zero-Flow Sanitization (`scripts/flow/flow-engine.lua`, `scripts/flow/port-defs.lua`):** Sanitized port node generation in `connect_entity` to ensure `node.emitter` is `nil` whenever `port.flow` is zero or unassigned. Added explicit `node.emitter ~= 0` guards across `get_node_emitter_level` and `compute_port_flow_level`, preventing passive hub-style intake ports from being treated as unpowered active pump emitters.
3. **Capsule Identity Persistence (`scripts/capsules/capsule-manager.lua`):** Updated `capsule_manager.register` to record `capsule_type = capsule_item_name` directly onto `storage.active_capsules[capsule_id]`. This provides an immutable string identifier for capsule variants across query and motion modules without modifying `capsule-definitions.lua`.
4. **Passive Intake Dock Admission (`scripts/capsules/capsule-runner.lua`):** Decoupled projector intake ports from active kinetic beam gatekeeping in `is_hop_valid`. Incoming capsules traveling along pressurized tube lines now enter the projector intake dock freely like a hub, parking safely if the facility is unpowered and dispatching across the kinetic beam once energized.


### Revision: Kinetic Flow Waking Parity, Line-of-Sight Ray Interception & Dynamic Beam Regrowth
**Date:** 2026-09-10 14:59 (EDT)
**Context:** Eliminate beam stalls, stalled intake docks, and phantom endpoint states by decoupling kinetic advance checks from delta level changes, replacing tile-coordinate searches with line-of-sight ray-box intersection, and implementing complete wakeup parity across receiver catchment and beam hops.
**Key Changes:**
1. **Decoupled Kinetic Tip Advance & Endpoint Resolution (`scripts/flow/flow-engine.lua`):** Moved downstream continuity and obstacle raycasting out of the `if kinetic_changed` delta check. Active beam tips lacking downstream neighbors now continuously evaluate forward line-of-sight; clear paths immediately advance and spawn subsequent hop tiles, while blocked paths dynamically render catchment or hazard endpoint rings without requiring upstream level flux.
2. **Ray-Box Line-of-Sight Interception (`scripts/flow/flow-engine.lua`):** Replaced the integer-snapped tile search in build/removal handlers with an exact cardinal ray-box intersection helper (`notify_beam_obstruction_changed`). Placing any obstacle or receiver across an active beam now accurately resolves fractional half-tile coordinates, enqueues affected beam segments, and instantly truncates the trajectory, while removing an obstruction clears terminal tags and allows the beam to regrow to maximum reach.
3. **Hop-to-Hop Queue Wakeup Fix (`scripts/capsules/capsule-runner.lua`):** Corrected a target port neighbor bypass in `wake_parked_capsules` where non-nil unit numbers caused the runner to skip querying `flow_connections` on port key strings. Upstream kinetic hops behind departing capsules are now reliably woken, establishing 0-tick lockstep queue advancement across 5-tile ballistic intervals.
4. **Receiver Catchment Wakeup Hooks (`scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-queries.lua`):** Wired targeted wakeup scans across `storage.parked_by_port` matching `hit_receiver` and `beam_owner`. When outbound tube capacity frees at a receiver, capsules parked at incoming beam endpoints are woken immediately to resume transit. Expanded `remove_capsule` to wake neighbor connections, sister chassis ports, and incoming ballistic trajectories.
5. **Live Muzzle Re-linking & Ghost Resolution (`scripts/active-device-scanner.lua`, `scripts/flow/port-defs.lua`):** Updated `check_and_update_state` to trigger `disconnect_entity` and `connect_entity` whenever `current_muzzle ~= last_muzzle`, ensuring GUI, copy-paste, and blueprint directional adjustments instantly rebuild flow topology. Added `storage.ghost_by_pos` fallback lookups in `port_defs.get_ports` for reliable ghost orientation resolution.


### Revision: Kinetic Render Isolation, Power-State Truthiness & Reorientation Waking
**Date:** 2026-09-10 16:47 (EDT)
**Context:** Prevent opposing beams from erasing each other's visual dots, ensure the Active Device Scanner's unpowered state cleanly initiates queue-driven recession without residual buffer fallback, and wake blocked beam endpoints when a target projector rotates away.
**Key Changes:**
1. **Port-Key Render Registry Isolation (`scripts/flow/flow-engine.lua`):** Re-keyed `storage.kinetic_renders` from spatial coordinate strings (`pos_key`) to unique port identifiers (`pkey`). Opposing or intersecting beams occupying the same physical air tiles now maintain isolated render handles, preventing a receding trajectory from deleting or overwriting the visual dots of an active counter-beam.
2. **Scanner Power-State Ternary Evaluation Fix (`scripts/flow/flow-engine.lua`):** Corrected a Lua ternary evaluation trap in `get_node_kinetic_emitter` where `(power_state ~= nil) and power_state or (entity.energy > 0)` evaluated to residual buffer energy when `power_state` was `false`. Implemented explicit boolean branching so ADS power cutoffs immediately drop the muzzle kinetic level to zero, triggering natural 1-tile-per-tick queue recession across the beam.
3. **Reorientation Receiver Waking (`scripts/flow/flow-engine.lua`, `scripts/active-device-scanner.lua`):** Updated `handle_entity_reorientation` and scanner state handlers to scan `storage.flow_nodes` for incoming beam endpoints locked onto the reoriented projector (`fn.hit_receiver == entity.unit_number`). Rotating a machine away now unsets `is_endpoint` and enqueues the stalled beam tip, allowing it to re-evaluate line-of-sight and resume queue-driven advance across newly opened space.
4. **Upstream Owner Beam Scoping (`scripts/flow/flow-engine.lua`):** Enforced strict `n_node.beam_owner == node.beam_owner` identity guards in `compute_port_kinetic_level`. Upstream neighbor distance checks now strictly reference the owning facility's kinetic hop chain, preventing bidirectional or overlapping beams from interfering with each other's kinetic level calculations.


### Revision: Kinetic Endpoint Demotion & Minor Node Restoration on Beam Advance
**Date:** 2026-09-10 17:04 (EDT)
**Context:** Ensure temporary endpoint nodes along active kinetic beams that were elevated to major status by obstacles or receivers are cleanly demoted back to minor nodes when the obstruction is removed and the beam advances.
**Key Changes:**
1. **Dynamic Node Prominence Demotion on Advance (`scripts/flow/flow-engine.lua`):** Updated the beam propagation advance branch in `flow_engine.step` to evaluate natural hop interval status (`(dist % HOP_DISTANCE == 0)`). Explicitly cleared `is_endpoint` and `hit_receiver`, demoting `is_prominent_kinetic`, `is_beam_node`, and `capsule_transmit` back to false for non-interval tiles before spawning downstream nodes.
2. **Alt-Mode Overlay Refresh Parity (`scripts/flow/flow-engine.lua`):** Passed the demoted prominence flag to `update_kinetic_pos_render` during beam advancement, destroying the 0.16-radius major circle and target ring in favor of the standard 0.08-radius minor dot.
3. **Downstream Sanitization & Removal Synchronization (`scripts/flow/flow-engine.lua`):** Added defensive prominence correction for active nodes possessing downstream neighbors (`has_downstream == true`), and synchronized natural prominence demotion across `notify_beam_obstruction_changed`, `handle_entity_reorientation`, `handle_object_destroyed`, and entity removal event hooks.


### Revision: Electromagnetic Projector Configuration GUI & Circuit Automation
**Date:** 2026-09-10 17:50 (EDT)
**Context:** Provide an interactive configuration GUI for the Electromagnetic Projector when clicking the facility chassis or circuit proxy, exposing manual enable toggles and circuit network condition controls matching the pneumatic pump scheme.
**Key Changes:**
1. **Proxy Linkage & GUI Dispatch (`scripts/proxy-manager.lua`):** Wired `on_open_gui = pump_gui.open` into the `pneumatic-projector` registration pair, resolving clicks on physical structures, circuit proxies, and ghost entities to display the configuration frame.
2. **Dual-Device UI Controller (`scripts/pump-gui.lua`):** Expanded the frame window manager to support both `pump_configuration_frame` and `projector_configuration_frame`. Dynamically rendered title headers ("Electromagnetic Projector Configuration"), manual enable checkboxes ("Enable Projector"), Red/Green wire channel toggles, and circuit condition panels (`gui_components.add_circuit_condition_panel`) based on target device identity.
3. **State Persistence & Scanner Synchronization (`scripts/pump-gui.lua`):** Wired checkbox, signal-selector, comparator, and textfield change handlers to persist modifications directly into `storage.projector_settings`. Invoked `active_device_scanner.notify_settings_changed(entity)` on edits to re-evaluate enable states, enqueuing unit ports into the flow engine and waking parked capsules immediately upon circuit state transitions.
4. **Convenience API Aliasing (`scripts/pump-gui.lua`):** Exported `pump_gui.open_projector` and `pump_gui.close_projector` alongside `open` and `close` for direct programmatic access.


### Revision: Projector Endpoint Congestion Throttling & Backpressure Propagation
**Date:** 2026-09-10 18:23 (EDT)
**Context:** Prevent Electromagnetic Projectors from continuously firing capsules when the target receiver or terminal endpoint is saturated by enforcing a strict capacity threshold and propagating lockstep wakeups back to the launch dock.
**Key Changes:**
1. **Endpoint Capacity Configuration (`scripts/projector-settings.lua`):** Added `projector_settings.MAX_ENDPOINT_CAPSULES = 2`, establishing a standardized congestion threshold that caps parked and in-flight payloads per trajectory.
2. **Endpoint Discovery & Payload Accounting (`scripts/capsules/capsule-runner.lua`):** Implemented `get_beam_endpoint` and `count_endpoint_capsules` to trace ballistic paths and aggregate capsules parked at beam endpoints, receiver chassis ports, and active in-flight beam payloads.
3. **Launch Muzzle Dispatch Gatekeeping (`scripts/capsules/capsule-runner.lua`):** Added pre-flight capacity evaluation in `select_next_target`, keeping incoming capsules safely parked in the projector intake dock whenever the endpoint reaches capacity or before an active endpoint node is established.
4. **Bidirectional Backpressure Wakeup Propagation (`scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-queries.lua`):** Extended `catch_in_receiver`, `wake_parked_capsules`, and `remove_capsule` to dispatch immediate targeted wakeups back to the sending facility's ports (`beam_owner`) whenever destination tube capacity frees up.


### Revision: Kinetic Beam Obstruction Filtering & Resource Passthrough
**Date:** 2026-09-10 18:45 (EDT)
**Context:** Prevent Electromagnetic Projector beams and in-flight capsules from falsely terminating on non-blocking world entities such as ore deposits, corpses, and ambient creatures.
**Key Changes:**
1. **Ignorable Obstruction Entity Set (`scripts/flow/flow-engine.lua`):** Registered `IGNORABLE_TYPES` covering ground resources (`resource`), organic remains (`corpse`, `character-corpse`), mobile creatures (`unit`, `fish`), combat drones (`combat-robot`), munitions (`land-mine`), and transient visual proxies. Replaced the inline boolean evaluation in `flow_engine.check_tile_obstruction` with an exact $O(1)$ set lookup, allowing kinetic trajectories to pass freely across ore patches without collision or crash spillage.
2. **Raycast Event Fast-Path Filtering (`scripts/flow/flow-engine.lua`):** Added `IGNORABLE_TYPES` and `PROXY_NAMES` early-exit checks to `notify_beam_obstruction_changed`, skipping ray-box intersection scans and avoiding queue wakeups when non-blocking world entities are created, depleted, or removed.
3. **Automatic Live Endpoint Recovery (`scripts/flow/flow-engine.lua`):** Added a one-time migration sweep in `flow_engine.step` alongside startup scans in `flow_engine.init_storage` to re-enqueue all active kinetic endpoint nodes, immediately advancing existing savegame beams that were previously blocked by ore deposits.


### Revision: Kinetic Beam Overlay Restoration & Per-Player Render Isolation
**Date:** 2026-09-10 19:05 (EDT)
**Context:** Prevent kinetic beam dots and terminal endpoint rings from disappearing permanently when toggling Alt-Mode flow rendering in the debug panel, and isolate kinetic overlay lifecycles per player to eliminate cross-client visual wiping.
**Key Changes:**
1. **Per-Player Kinetic Render Isolation (`scripts/flow/flow-engine.lua`):** Refactored `storage.kinetic_renders` from a global flat table into a player-indexed hierarchy (`storage.kinetic_renders[player_index]`), binding rendering circles to target players via `players = { player }` so one player toggling or clearing debug overlays never destroys visuals for other clients. Included legacy string-key migration in `init_storage` and global fallback sweeps.
2. **Kinetic Overlay Re-Draw Integration (`scripts/flow/flow-engine.lua`):** Added an $O(K)$ iteration over active `storage.kinetic_levels` into `flow_engine.draw_flow`, automatically reconstructing all minor trajectory dots, prominent hop circles, and receiver/hazard endpoint rings whenever flow rendering is toggled on or rebuilt.
3. **Cached Render State & Zero-Allocation Early Exits (`scripts/flow/flow-engine.lua`):** Encapsulated node property resolution directly inside `update_kinetic_pos_render(pkey, player_index)` using `storage.flow_nodes[pkey]`, added property equality checks to reuse valid existing render objects without redrawing steady-state beams, and enforced an $O(1)$ early exit when no connected players have debug flow active.


### Revision: Kinetic Projectile Player Collision Detection, Impact Damage & Spill Mechanics
**Date:** 2026-09-10 20:50 (EDT)
**Context:** Make electromagnetic projector kinetic projectiles hazardous to players by performantly detecting character and vehicle collisions along ballistic trajectories, dealing quality-scaled impact damage, and triggering immediate explosion and spillage.
**Key Changes:**
1. **Projectile Damage Constant (`scripts/projector-settings.lua`):** Registered `projector_settings.PROJECTILE_DAMAGE = 250`, establishing a standardized baseline impact damage rating for kinetic projectiles.
2. **Zero-Allocation Player Target Caching (`scripts/capsules/capsule-runner.lua`):** Implemented `prepare_player_targets` and module-level scratch buffers (`scratch_player_targets`) to snapshot bounding boxes of connected players' characters and vehicles once per frame, enabling pure coordinate comparisons without repeated Lua API entity allocations or global spatial scans.
3. **Trajectory Player Interception & Collision Interception (`scripts/capsules/capsule-runner.lua`):** Integrated `check_player_collision` across standard kinetic hops, launch muzzle dispatches, dead-sender ballistic flights, and terminal landing positions, arresting projectile motion upon player contact.
4. **Quality-Scaled Impact Damage & Crash Spillage (`scripts/capsules/capsule-runner.lua`):** Applied native `impact` damage scaled by machine quality (`1 + 0.3 * q_level`) to characters or vehicles on contact, spawning an explosion and spilling cargo into red-locked spill containers via `hub_spill.spill_capsule`.

### Revision: Projector Capacitor Discharge Mechanics & Recharge Firing Cadence
**Date:** 2026-09-10 21:06 (EDT)
**Context:** Eliminate rapid-fire electromagnetic projector exploits by gating ballistic dispatch on a fully charged 9 MJ capacitor, draining stored energy on launch to enforce recharge pacing, and preserving kinetic beam stability while recharging.
**Key Changes:**
1. **9 MJ Buffer Discharge & Beam Grace Logic (`scripts/projector-settings.lua`):** Configured `LAUNCH_ENERGY_JOULES = 9000000` alongside `get_launch_energy` and `can_fire` (with 10 kJ precision tolerance) to require a fully charged electrical buffer before launching. Updated `is_powered` to verify electric network presence (`entity.electric_network_id ~= nil`) and grant a 180-tick (`RECHARGE_GRACE_TICKS`) grace period following launch, preventing the kinetic guide beam and Alt-Mode overlays from collapsing while stored energy replenishes from 0 to 3 MW baseline.
2. **Capacitor Discharge & Dock Throttling (`scripts/capsules/capsule-runner.lua`):** Added pre-dispatch `can_fire` checks in `select_next_target`, keeping incoming payloads parked safely at projector intake docks during recharge cycles. Deducted launch energy from `proj_entity.energy` upon hop commitment and point-blank player collision, logging the dispatch tick to `storage.projector_last_fired` and clearing `storage.projector_ready_states`.
3. **Recharge Scanner & Dock Wakeup Synchronization (`scripts/active-device-scanner.lua`):** Integrated `storage.projector_ready_states` into the 15-tick device scanner loop to track `can_fire` transitions, automatically enqueuing unit ports and triggering `capsule_runner.wake_parked_capsules` the instant the capacitor completes recharging.
4. **Storage Bootstrap & Destruction Cleanup (`scripts/flow/flow-engine.lua`):** Initialized `storage.projector_ready_states` and `storage.projector_last_fired` in `flow_engine.init_storage`, and wired complete state cleanup into `flow_engine.disconnect_entity` and `flow_engine.handle_object_destroyed`.


### Revision: Spilled Container Script Destruction & Kinetic Obstruction Wakeups
**Date:** 2026-09-10 21:39 (EDT)
**Context:** Restore kinetic beam advance and launch dock wakeups when spilled capsule containers are emptied and auto-cleaned by scripts rather than mined by players.
**Key Changes:**
1. **Script Destruction Raising & Event Fix (`scripts/hubs/hub-spill.lua`):** Passed `{ raise_destroy = true }` to `entity.destroy` calls across empty container cleanup and early-purge branches, and corrected the removal event listener from the nil constant `defines.script_raised_destroy` to `defines.events.script_raised_destroy`.
2. **Script-Raised Obstruction Handling & Dock Wakeups (`scripts/flow/flow-engine.lua`):** Updated `removal_events` to listen to `defines.events.script_raised_destroy`, enabling ray-box intersection processing during programmatic container destruction, and added explicit projector intake port wakeups in `notify_beam_obstruction_changed` so queued capsules dispatch immediately once cleared.


### Revision: Planetary Capsule Surface Conditions & Closed-Loop Refrigeration
**Date:** 2026-09-10 22:45 (EDT)
**Context:** Enforce planetary environment constraints across Space Age specialized capsules and the electromagnetic projector while establishing a net-zero fluoroketone thermal exchange for cryogenic manufacturing.
**Key Changes:**
1. **Planetary Surface Conditions (`prototypes/recipe.lua`):** Gated specialized capsule manufacturing by environmental properties: restricted `vacuum-capsule` to 0 pressure (space platforms), `reinforced-capsule` to 4000 hPa (Vulcanus), `refrigerated-capsule` to 300 hPa (Aquilo), and both `electromagnetic-capsule` and `pneumatic-projector` to at least 99% magnetic field (Fulgora). Preserved unrestricted crafting for single-use `biodegradable-capsule` and all capsule recharging recipes across all surfaces.
2. **Closed-Loop Cryogenic Recipe & Cadence (`prototypes/recipe.lua`):** Increased `refrigerated-capsule` fabrication time from 3.0s to 10.0s (`energy_required = 10.0`), assigned explicit `main_product = "refrigerated-capsule"`, and balanced fluid throughput to consume 100 cold fluoroketone while returning 100 hot fluoroketone as a byproduct, eliminating net coolant loss during fabrication.


### Revision: Projector Beam Endpoint Horizon Expansion & Legendary Launch Fix
**Date:** 2026-09-10 22:56 (EDT)
**Context:** Resolve launch dispatch stalls on high-quality Electromagnetic Projectors where hardcoded 100-tile iteration limits prevented endpoint resolution and ballistic flight initialization along beams reaching beyond 100 tiles.
**Key Changes:**
1. **Dynamic Beam Scan Horizon (`scripts/capsules/capsule-runner.lua`):** Registered `MAX_BEAM_DISTANCE = 500` to supersede legacy 100-tile scan bounds, providing ample headroom for Legendary (110+ tiles) and high-quality kinetic guide beams.
2. **Endpoint Discovery & Trajectory Initialization (`scripts/capsules/capsule-runner.lua`):** Updated `get_beam_endpoint` and `init_capsule_beam_flight` loops to scan up to `MAX_BEAM_DISTANCE`, allowing Legendary launch docks to detect active endpoints and compile complete hop chains for uninterrupted dispatch.
3. **Motion Runner Variable Hygiene (`scripts/capsules/capsule-runner.lua`):** Removed an extraneous duplicate local declaration of `next_prominent_key` in the kinetic path evaluation block of `select_next_target`.


### Revision: Subtle Electromagnetic Projector Port Location Overlays & Zero-Flow Rendering
**Date:** 2026-09-10 23:25 (EDT)
**Context:** Provide clear visual feedback for Electromagnetic Projector logistics interfaces in Alt-Mode by rendering subtle port indicators at zero-pressure intake sockets where tubes can attach.
**Key Changes:**
1. **Passive Intake Port Overlay Rendering (`scripts/flow/flow-engine.lua`):** Enhanced `update_pos_render` to detect zero-flow non-muzzle ports belonging to active `pneumatic-projector` units, rendering a 0.12-radius filled cyan dot (`PROJECTOR_INTAKE_COLOR`) in Alt-Mode to distinctly mark connection sockets while preserving normal pressure and vacuum displays when lines become pressurized.
2. **1-Tick Active Projector Initialization Sweep (`scripts/flow/flow-engine.lua`):** Added a one-time startup sweep in `flow_engine.step` (`storage.projector_ports_initialized`) enqueuing unit ports across all registered `active_projectors`, immediately restoring and displaying intake port overlays across existing savegame facilities on tick 1 without requiring mining or rebuilding.


### Revision: Projector Ballistic Velocity Normalization & 6-Tick Prominent Hop Cadence
**Date:** 2026-09-11 00:13 (EDT)
**Context:** Normalize Electromagnetic Projector projectile travel speeds by replacing the 1-tick per-frame override with the standard 6-tick staggered hop cadence, advancing payloads across exactly one 5-tile prominent node per step.
**Key Changes:**
1. **Standard 6-Tick Ballistic Cadence (`scripts/capsules/capsule-runner.lua`):** Removed the 1-tick per-frame hop override (`current_tick + 1`) across active beam trajectories and dead-sender ballistic flights (`beam_flight`), synchronizing in-flight kinetic payloads with the engine's standard `STAGGER_TICKS = 6` cadence (`(current_tick + id) % 6 == 0`).
2. **Prominent Node Multi-Hop Boundary (`scripts/capsules/capsule-runner.lua`):** Added an early-exit break in the `update_capsules` multi-hop traversal loop upon entering or traversing prominent kinetic nodes, preventing multiple prominent hops from executing in a single frame and fixing velocity at 5 tiles per 6 ticks (~50 tiles/sec).
3. **Dead-Sender Flight Pacing Synchronization (`scripts/capsules/capsule-runner.lua`):** Gated unanchored ballistic trajectories (`not node` with `beam_flight`) behind `is_woken or is_stagger_tick` with `current_tick + STAGGER_TICKS` rescheduling, ensuring consistent visual pacing and collision handling when sender projectors are deconstructed mid-flight.


#### next ver

#### next ver

#### next ver

