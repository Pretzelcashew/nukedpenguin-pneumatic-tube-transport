### 0.3.2

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



### 0.3.21

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