### Revision: Unpowered Pump Flow Culling & Vector Gating
**Context:** Prevent unpowered pumps from acting as passive flow sinks that trap moving capsules on dead-end inlet paths or adjacent multi-port entity branches when pump power is disconnected.
**Key Changes:**
1. **Power State Evaluation (`scripts/networks/networks-flow.lua`):** Implemented an `is_pump_powered()` validation helper to check `storage.pump_power_states` for `pneumatic-pump` entities prior to hop construction.
2. **Internal Transfer Gating (`scripts/networks/networks-flow.lua`):** Restricted internal machine transfer hop generation across pump ports so unpowered pumps suppress internal transfers between inlet and outlet ports.
3. **External Vector Flow Gating (`scripts/networks/networks-flow.lua`):** Enforced power state validation on both source and destination entities during outbound hop calculation, preventing pressure-gradient vector creation into unpowered pump inlets.
4. **Dead-End Pruning Integration (`scripts/networks/networks-flow.lua`):** Suppressing unpowered pump hops allows `flow-cull.lua` to naturally identify and prune dead-end internal junction paths leading toward unpowered inlets.

### Revision: Specialized Transit Capsule Prototypes & Tech Tree Integration
**Date:** 2026-08-26 21:25 (EDT)
**Context:** Register item prototypes, crafting recipes, and technology research nodes for specialized transit capsule variants (biodegradable, refrigerated, reinforced, and player transit) ahead of runtime mechanics integration.
**Key Changes:**
1. **Capsule Variant Items (`prototypes/item.lua`):** Registered item prototypes for `biodegradable-capsule`, `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule` with stack size 1 and distinct order sub-keys (`a[capsule]-b[...]` through `e[...]`) under the `intermediate-product` subgroup.
2. **Variant Crafting Recipes (`prototypes/recipe.lua`):** Added recipe definitions for all four new capsule variants with `enabled = false` for tech unlock gating, establishing crafting times (1.0s to 5.0s) and ingredients matching tier progression.
3. **Technology Unlocks & Tree Expansion (`prototypes/technology.lua`):** Added `biodegradable-capsule` unlock directly to the baseline `pneumatic-transport` technology. Created the `specialized-pneumatic-capsules` technology node (prerequisite: `pneumatic-transport`, 250 cycles @ 30s) to unlock `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule`.


### Revision: Capsule Variant Mechanics, Player Transit & Emergency Ejection System
**Date:** 2026-08-26 23:10 (EDT)
**Context:** Expand the pneumatic transport framework to support distinct capsule types (biodegradable, refrigerated, reinforced, player-transit), real-time passenger synchronization, emergency disembarkation, mid-transit structural failures, prototype bugfixes, and stub out non-functional refrigerated spoilage handling.

**Key Changes:**
1. **Capsule Definitions & Blueprint Expansion (`scripts/capsules/capsule-definitions.lua`):** Defined specs for `biodegradable-capsule`, `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule` specifying unique base capacities, stack rules, quality filters, spoilage modifiers, and spill risks.
2. **Player Transit & Arrival Disembarkation (`scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`):** Configured player transit dispatch to scan for nearby character entities (2.5 radius) prior to packing. Updated `hub-unpacking.lua` to safely disembark arriving passengers onto nearby non-colliding tiles (`find_non_colliding_position`).
3. **Custom Input Ejection System (`prototypes/custom-input.lua`, `scripts/capsules/capsule-inputs.lua`):** Added the `capsule-emergency-exit` prototype (`SHIFT + E`) in the data stage. Created a standalone input script registered through `events.on_event` to trigger ejection cleanly without placing logic directly in `control.lua`.
4. **Emergency Eject API & Module Export (`scripts/capsules/capsule-runner.lua`):** Added `capsule_runner.emergency_eject(player)` to ground passengers, destroy underlying liminal holder entities, remove visual tracking overlays, and unhook tracking state from `storage.capsules`. Exported `emergency_eject` in the module return table.
5. **Capsule Lifecycle Mechanics & Spoilage Stub (`scripts/capsules/capsule-runner.lua`, `scripts/hubs/hub-packing.lua`):** Added `update_capsule_lifecycle()` with active mid-flight spill evaluations (`spill_risk = 0.0008`) on biodegradable cargo, while stubbing out `spoilage_modifier` logic to prevent Factorio 2.0 engine queue conflicts. Configured `hub-packing.lua` to dissolve biodegradable capsule shells upon packing (`destroy_self = true`).
6. **Entity Prototype Crash Fix (`scripts/capsules/capsule-runner.lua`):** Replaced non-existent `"small-explosion"` entity strings with standard base-game `"explosion"` prototypes across emergency ejection and biodegradable structural failure handlers to resolve fatal runtime crashes.

### Revision: Refrigerated Capsule Spoilage Mitigation & Type-Safe Stack Refresh
**Date:** 2026-08-27 07:58 (EDT)
**Context:** Implement engine-compatible spoilage mitigation for cargo inside refrigerated capsules by tracking real-time spoilage deltas and re-instantiating liminal holder item stacks without triggering Factorio C++ prototype indexing exceptions.
**Key Changes:**
1. **Delta Spoilage Tracking (`scripts/capsules/capsule-runner.lua`):** Added a 60-tick interleaved scanner in `update_capsule_lifecycle()` using `(game.tick + id) % 60 == 0`. Tracks per-slot previous spoil percentages in `capsule.slot_spoil_percents` to measure engine-applied spoilage ($\Delta s$) and apply scaled target freshness based on `def.spoilage_modifier`.
2. **Type-Guarded Stack Re-instantiation (`scripts/capsules/capsule-runner.lua`):** Resolved non-recoverable C++ engine errors (`"Item is not tool"`, `"Item is not ammo"`, `"Item is not item-with-tags"`) when rebuilding stacks via `set_stack()` by explicitly checking `stack.is_tool`, `stack.is_ammo`, and `stack.is_item_with_tags` before querying `.durability`, `.ammo`, `.custom_description`, or `.tags`.
3. **Metadata Preservation (`scripts/capsules/capsule-runner.lua`):** Guaranteed 100% state preservation across quality, stack size, health, durability, ammo, custom descriptions, and tags during liminal inventory slot refreshes.

### Revision: Pump Placement Flow Initialization & Multi-Port Power Broadcast Fix
**Date:** 2026-08-27 08:41 (EDT)
**Context:** Fix delayed flow map updates on newly placed pumps and ensure power state toggles broadcast across both inlet and outlet networks over internal pump join boundaries.
**Key Changes:**
1. **Direct Energy Evaluation (`scripts/networks/networks-flow.lua`):** Updated `is_pump_powered()` to evaluate `entity.energy > 0` directly during flow vector hop generation, eliminating reliance on uninitialized or delayed `storage.pump_power_states` during initial placement validation.
2. **Multi-Port Power State Broadcast (`scripts/networks/pump-manager.lua`):** Refactored `check_pump_power_states()` to iterate over all registered entity ports via `port_defs.get_ports()` rather than querying hardcoded port index 1. This guarantees `networks_flow.build()` is invoked across both inlet and outlet sub-networks when pump power state toggles.

### Revision: Refrigerated Capsule Durability & Spent State Lifecycle
**Date:** 2026-08-27 09:11 (EDT)
**Context:** Convert the refrigerated capsule to function as a durable tool item that consumes durability while actively preserving spoilable cargo and degrades into a spent capsule once depleted.
**Key Changes:**
1. **Capsule Tool Prototypes (`prototypes/item.lua` & `scripts/capsules/capsule-definitions.lua`):** Converted `refrigerated-capsule` from a standard item to a tool prototype with 1000 durability. Registered the `spent-refrigerated-capsule` prototype and definition (`spoilage_modifier = 1.0`, `spent_capsule_item`) to handle depleted container transitions.
2. **Spoilage Reduction & Durability Drain (`scripts/capsules/capsule-runner.lua`):** Implemented periodic spoilage mitigation in `update_capsule_lifecycle` for active cargo. Added tick-based durability reduction for cooling tools when preserving items, automatically replacing depleted tools with their spent variants in-place.

### Revision: Primary Capsule Slot Tracking & Refrigerated Spoilage Fix
**Date:** 2026-08-27 09:40 (EDT)
**Context:** Eliminate cargo refrigerated capsule durability exploits, fix visual overlay item misclassifications, and establish explicit primary slot tracking within liminal holder inventories.
**Key Changes:**
1. **Primary Slot Registration & Helpers (`scripts/capsules/capsule-manager.lua`):** Updated `capsule_manager.register()` to store `primary_slot` within `storage.active_capsules[id]`. Implemented `get_primary_stack(capsule_id)` helper to safely retrieve the primary vessel stack and slot index from holder entity inventories.
2. **Primary Shell Placement & Packing (`scripts/hubs/hub-packing.lua`):** Adjusted packing logic to populate cargo items first and assign the primary capsule shell to a designated, tracked slot (`primary_holder_slot`) while preserving durability, ammo, quality, and custom tags.
3. **Targeted Durability Drain & Overlay Classification (`scripts/capsules/capsule-runner.lua`):** Refactored `update_capsule_lifecycle()` to deduct durability strictly from `phys_capsule.primary_slot`, preventing cargo capsules from being drained as secondary coolant sources. Updated `get_dominant_item()` to evaluate `i == cap_data.primary_slot` rather than item prototype definitions to reliably differentiate cargo items from outer vessel shells.