# ARCH-HUBS-LOGISTICS.md - Hub Logistics, Packing Pipelines & 60Hz Belts
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Hub Packing & Unpacking Pipelines, 60Hz Bidirectional Belt Interface, Dynamic Bar Clamping, Spillage Containers & Cargo Planning

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), tracking binary capsule nesting toggle (`nest_capsules = false` default) encapsulated via `hub_settings.is_nesting_enabled()`, providing circuit condition evaluation, `.copy()` deep-copy helper, `get_device_id` spatial identity export, and `apply_blueprint_settings()` tag deserialization. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.is_nesting_enabled()`, `hub_settings.apply_blueprint_settings()`, `hub_settings.get_device_id()`, `hub_settings.copy()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`), consuming `gui-components.lua`. Features a "Nest capsules" checkbox to toggle binary capsule vessel packing based on `hub_settings.is_nesting_enabled()`. Resolves ghost entity handles and fires `hub_manager.notify_settings_changed(entity)` on edits to wake disembarking capsules and active scanners. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, etc.) | `hub-settings.lua`, `hub-manager.lua`, `gui-components.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Lifecycle listener, settings notification (`notify_settings_changed`), blueprint tag restoration (`pneumatic_settings`), native `on_blueprint_settings_pasted` handling, fast-replace co-existence queries, destruction-phase proactive settings transfer (`hub_settings.copy`), tick-scoped positional fallback cache (`storage.hub_fast_replace_cache`, 60-tick expiry), O(1) ghost hub tracking, strict spatial ghost settings adoption, interleaved 10-tick background scan for `hub_packing.evaluate_inventory`, and decoupled 1-tick continuous 60Hz execution of bidirectional belt siphoning/depositing via `belt_siphon.process_belts(entity)` for 100% belt compression. | Interleaved hub packing scan, 1-tick continuous belt siphon execution, `notify_settings_changed()`, `find_existing_real_hub_at_pos()`, build/mine event listeners. | `hub-packing`, `belt-siphon`, `hub-gui`, `events` |
| `belt-siphon.lua` | `scripts/hubs/packing/` | Independent, pressure-governed bidirectional transport belt interface operating at continuous 1-tick cadence. Fast-path early exits evaluate `get_hub_net_pressure` first (skipping neutral/unpressurized hubs) and check `chest_inv.is_empty()` and C++ `chest_inv.find_item_stack("vacuum-capsule")` before iterating inventory slots. Engine-filtered adjacent belt queries pass `BELT_SEARCH_TYPES` (`transport-belt`, `underground-belt`, `splitter`, `linked-belt`) to `surface.find_entities_filtered`. Enforces 3-tier cargo-first deposit priority (`Pure Cargo > Spent Capsules > Secondary Charged Capsules`) in `find_deposit_candidate_slot`. Enforces strict orthogonal adjacency (`is_strictly_adjacent`) via AABB projection, near transport line restrictions for parallel passing belts (`get_deposit_line_indices`), and Space Age Gleba belt stacking (`force.belt_stack_size_bonus`) via `line.insert_at_back(spec, allowed_stack)`. Deducts 1 health charge point per item placed or siphoned, converting depleted capsules instantly to `spent-vacuum-capsule` shells. | `belt_siphon.process_belts(hub_entity)`, `belt_siphon.siphon_to_chest(hub_entity)`, `belt_siphon.deposit_to_belts(hub_entity, chest_inv)`, `belt_siphon.get_hub_net_pressure(hub_entity)` | `hub-manager.lua`, `item-transfer-handler.lua`, `capsule-definitions.lua` |
| `hub-packing.lua` | `scripts/hubs/` | Main hub packing pipeline running on 10-tick interleaved cadence: Send check (`can_send`), early outbound route validation checking for positive pressure drop target ports (`find_best_hub_outbound_port`), lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius), full `#inventory` scanning. Outbound packing candidate priority targets spent hulls (`SPENT_CAPSULES`) first, standard cargo capsules second, and lowest-health charged capsules last to draft empty shells home while preserving unloader capsules at outposts. Biological cargo restriction checks (`bio_only`), cargo filtering based on `nest_capsules`, dynamic dominant item selection, Dual-Tier Spatial Grid allocation (`liminal_surface.allocate_position(is_wide)`), liminal holder spawning, cargo transfer via `item_transfer_handler`, dynamic post-packing inventory bar clamping (`dest_inv.set_bar(last_occupied_slot + 1)`), and injection via `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `item-transfer-handler`, `cargo-planner`, `capsule-runner` |
| `hub-unpacking.lua` | `scripts/hubs/` | Main hub unpacking pipeline: Receive check (`can_receive`), $O(1)$ failure state guard (`last_failed_hub`), passenger disembarkation onto safe tiles, single-use primary shell dissolution (`destroy_self` cleared prior to cargo transfer), all-or-nothing cargo unpacking via `can_insert_all()` ignoring primary shell slot for single-use capsules using zero-allocation flat scratch arrays, slot loops bounded to `get_bar() - 1`, stack migrations via `item_transfer_handler`, liminal holder cleanup with dual slot recycling (`release_position`), and mechanical receive latch engagement. | `hub_unpacking.capture(capsule_tracker, hub_entity)`<br>`can_insert_all(...)` | `capsule-manager`, `liminal-surface`, `item-transfer-handler`, `hub-settings` |
| `hub-spill.lua` | `scripts/hubs/` | Listens to entity mining and destruction events (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `defines.events.script_raised_destroy`, `on_space_platform_mined_entity`). Passes `{ raise_destroy = true }` during cleanup to wake raycast listeners. Inspects `destroy_self` and clears primary shell slots prior to spilling cargo onto ground or into fast-looting spill containers (`visible-capsule-holder`, `operable = true`, `set_bar(1)` red-locking upon creation). Excludes `is_beam_node` capsules from machine deconstruction spillage. Instant GUI dismissal, `"no-copy-paste"` settings protection, 60Hz throttled container cleanup scan (`process_spilled_containers`), and metadata-safe spills via `item_transfer_handler`. | `hub_spill.spill_capsule(...)`<br>`hub_spill.handle_entity_destruction(entity)` | `capsule-queries`, `capsule-manager`, `item-transfer-handler` |
| `quality-filter.lua` | `scripts/hubs/packing/` | Evaluates item quality against capsule vessel rules (`ceil`, comparators, whitelists, blacklists). | `quality_filter.is_quality_allowed(...)` | `hub-packing.lua` |
| `cargo-planner.lua` | `scripts/hubs/packing/` | Calculates stack extraction and insertion plans. Calculates fractional slot costs (`base_slot_cost / stack_size`) when `mixed_quantity = true` (electromagnetic capsules). Delegating `get_item_slot_cost()` to `capsule_defs.is_bio_item()` backed by a strict $O(1)$ bio item matrix (`capsule_definitions.bio_items`). | `cargo_planner.get_item_slot_cost(...)`<br>`cargo_planner.build_packing_plan(...)` | `capsule-definitions.lua`, `hub-packing.lua` |
| `item-transfer-handler.lua` | `scripts/utils/` | Centralized item metadata preservation & stack transfer engine. Preserves 100% of Factorio 2.0 item metadata: equipment grids (`stack.grid`), installed modules, shield/energy states, quality, spoilage, durability, health, ammo, and custom tags. Guards against tool property evaluation errors on non-tool items. | `copy_equipment_grid(src, dest)`<br>`build_stack_spec(stack)`<br>`transfer_stack(src, dest_inv)`<br>`transfer_inventory(src_inv, dest_inv)`<br>`spill_stack(surface, pos, stack)` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-spill.lua`, `capsule-lifecycle.lua`, `belt-siphon.lua` |

---

## 2. Persistent Storage Schema (`storage`)

```lua
  -- Spilled Capsule Container Tracking (Fast Looting with set_bar(1) clamping)
  spilled_containers = {
    [unit_number] = LuaEntity
  },

  -- Hub Container Registry, Operational Settings & Mechanical Latches
  active_hubs = { [unit_number] = LuaEntity },
  hub_settings = {
    [unit_number] = {
      can_send = true, use_circuit_send = false, nest_capsules = false,
      send_condition = { first_signal = { type = "item", name = "iron-plate" }, comparator = "<", constant = 100 },
      can_receive = true, use_circuit_receive = false,
      receive_condition = { first_signal = nil, comparator = "<", constant = 0 },
      use_receive_lock = true, read_red = true, read_green = true
    }
  },
  hub_receive_locks = { [unit_number] = true },

  -- Fast-Replace Settings Fallback
  hub_fast_replace_cache = {
    ["nauvis@10.5,20.5"] = {
      settings = { ... },                                    -- Deep-copied hub_settings
      tick = 123456                                          -- Destruction tick timestamp (pruned after 60 ticks)
    }
  }
```

---

## 3. Core Algorithms & Operational Mechanics

### 5.5 Multi-Item Unpacking Failure Guard & Zero-Allocation Space Simulation
1. **$O(1)$ Destination Failure State Guard:** Capsules parked at full/blocked hub destinations track failure state parameters (`last_failed_hub`, `last_failed_hub_count`, `last_failed_hub_bar`, `last_failed_cap_count`). If container inventory has not freed up, full space simulation (`can_insert_all`) is short-circuited in constant time.
2. **Zero-Allocation Space Simulation:** `can_insert_all()` utilizes flat module-level scratch arrays to simulate multi-item inventory insertion across active chest slots (`get_bar() - 1`), ignoring primary shell slots for single-use capsules (`destroy_self`).
3. **Targeted Failure Cache Invalidation:** When a route opens or network state changes, `wake_parked_capsules()` clears `capsule.last_failed_hub = nil`, triggering immediate unpacking re-evaluation.

### 5.7 Centralized Metadata Engine & Equipment Grid Transfer
1. **Centralized Metadata Preservation:** Item stack migrations attempt native `dest_slot.transfer_stack(src_stack)` calls first, preserving 100% of equipment grids (`stack.grid`), installed modules, shield/energy levels, spoilage, health, durability, ammo, and quality.
2. **$O(1)$ Equipment Grid Copying & Restoration:** Fallback stack extractions execute `copy_equipment_grid()` to clone equipment grids (`create_grid()`) and transfer installed equipment (`name`, `position`, `quality`, `energy`, `shield`).
3. **`item-with-tags` API Guard:** `build_stack_spec()` extracts stack attributes while strictly guarding `tags` and `custom_description` access behind `is_item_with_tags` checks.

### 5.9 Fast-Looting Spilled Containers & Single-Use Bio Shell Dissolution
1. **Single-Use Bio Shell Dissolution:** Biological primary capsule shells (`destroy_self = true`) dissolve cleanly upon arrival or spillage; primary shell slots are purged before transferring or spilling cargo.
2. **Fast-Looting Operability:** Spilled container entities (`visible-capsule-holder`) use `operable = true` to allow native Ctrl+Click fast-looting transfers.
3. **Instant GUI Dismissal:** An `on_gui_opened` listener sets `player.opened = nil` on the exact tick a spilled container is clicked, hiding the container GUI window.
4. **0-Tick Red-Locking Clamping:** Container creation applies `set_bar(1)`, red-locking all slots against manual item insertion while permitting item extraction.
5. **Throttled Cleanup Scan:** A 60-tick periodic scanner (`process_spilled_containers`) evaluates empty spilled containers, destroying empty entities with `{ raise_destroy = true }`.

### 5.10 Silent Object Destruction & Sandbox Purge Engine
1. **Typed Object Destruction Registry:** Valid pneumatic structures, circuit proxies, and liminal capsule holder entities register with Factorio's `script.register_on_object_destroyed`. Registration handles map into `storage.object_destruction_map`.
2. **Silent Sandbox Purge Fallback:** Bulk entity wipes via Sandbox mode, super force building, chunk deletions, or script destructions dispatch to structured handlers (`handle_object_destroyed` and `handle_capsule_destroyed`).
3. **Silent Cargo & Surface Cleanup:** Destroyed capsule holders on `liminal_surface` are removed cleanly without spilling items. Riding passengers are safely teleported back to valid ground positions.
4. **Network Topology & Flow Queue Unlinking:** Entity destructions trigger spatial disconnection (`disconnect_entity`), clearing port nodes, severing spatial connection edges, and waking queued traffic.

### 5.15 Hub Binary Nesting, Smart Dynamic Bar Clamping & Fractional Cargo
1. **Binary Nesting State Persistence:** `hub_settings` includes a `nest_capsules = false` default property preserved across copy-paste and blueprint deserialization.
2. **Spent Hull Outbound Packing Priority:** `hub_packing.evaluate_inventory` evaluates candidate capsules using a tiered priority hierarchy targeting spent hulls (`SPENT_CAPSULES`) first, standard cargo capsules second, and lowest-health charged capsules last. Outbound freight drafts empty shells home to base recharge infrastructure while preserving working unloader capsules in outpost hubs.
3. **Fractional Cargo Capacity Accounting:** `cargo-planner.lua` evaluates item slot costs using `mixed_quantity = true` for electromagnetic capsules, scaling slot volume consumed proportionally by item stack sizes (`base_slot_cost / stack_size`).
4. **Smart Dynamic Post-Packing Inventory Bar Clamping:** Packing extractions transfer items using full inventory depth, evaluate `last_occupied_slot`, and invoke `dest_inv.set_bar(last_occupied_slot + 1)` to lock trailing empty slots cleanly.

### 5.17 Pressure-Driven Bidirectional Belt Interface, Continuous 60Hz Cadence, Engine-Filtered Querying & Cargo-First Ejection
1. **1-Tick Continuous 60Hz Belt Interface Cadence:** Decoupled `belt_siphon.process_belts(entity)` from the 10-tick interleaved hub packing scan. Belt siphon and exhaust routines execute on every tick for active hubs, allowing transport lines to accept items/stacks the instant space clears, eliminating gaps and achieving 100% belt compression.
2. **Pressure & Inventory Fast-Path Early Exits:** Reordered checks in `process_belts` to evaluate `get_hub_net_pressure` first, skipping neutral and unpressurized hubs with zero entity/inventory overhead. Added `chest_inv.is_empty()` checks and native C++ `chest_inv.find_item_stack("vacuum-capsule")` lookups to eliminate full 48-slot Lua iterations across non-siphon hubs.
3. **Engine-Filtered Adjacent Belt Querying:** `find_adjacent_belts` passes `type = BELT_SEARCH_TYPES` (`transport-belt`, `underground-belt`, `splitter`, `linked-belt`) directly to `surface.find_entities_filtered`, allowing the C++ engine to filter out non-belt structures before allocating Lua entity arrays.
4. **3-Tier Cargo-First Deposit Priority Hierarchy:** Refactored `find_deposit_candidate_slot` into a 3-tier candidate selector (`Pure Cargo > Spent Capsules > Secondary Charged Capsules`). Bulk cargo empties onto transport lines before dead shells, preventing belt contamination and allowing chest-mounted filter inserters to extract spent capsules directly into recycling lines.
5. **Near-Lane Parallel Sideloading & Gleba Stacking:** Outbound belts access all transport lines; parallel passing belts strictly sideload onto the near transport line touching the hub wall. Evaluates `force.belt_stack_size_bonus` to deposit vertical item stacks in a single action via `line.insert_at_back(spec, allowed_stack)`.
6. **Quality-Scaled Durability & Depletion:** Base durability of 500 charges on `vacuum-capsule` scales via `capsule_defs.get_max_charges(def, quality)` up to 1,250 charges at Legendary. Belt operations deduct 1 health charge point per individual item transferred. Depleted capsules convert instantly into `spent-vacuum-capsule` shells inside the hub chest, preserving quality and equipment grids.