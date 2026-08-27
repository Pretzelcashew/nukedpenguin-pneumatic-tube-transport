### Revision: Capsule Runner Modularization & Subsystem Decoupling
**Date:** 2026-08-27 10:02 (EDT)  
**Context:** Refactor `capsule-runner.lua` into smaller, single-responsibility sub-modules to reduce single-file complexity (~550 lines) and streamline context bounds while preserving strict top-level `require` loading rules.

**Key Changes:**
1. **Capsule Motion Subsystem (`scripts/capsules/capsule-motion.lua`):** Extracted network graph node lookup, spatial position resolution (`get_port_world_pos`), segment speed calculations (`calculate_segment_speed`), entity-network capacity verification (`has_entity_network_capacity`), pressure-driven target selection (`select_next_target`), and hub arrival handling (`handle_arrival`).
2. **Capsule Lifecycle Engine (`scripts/capsules/capsule-lifecycle.lua`):** Isolated per-tick passenger teleportation syncing (`passenger.teleport`), 60-tick refrigerated spoilage modifier calculation (`spoilage_modifier`), and primary capsule shell durability consumption / spent variant conversion (`spent-refrigerated-capsule`).
3. **Capsule Debug Renderer (`scripts/capsules/capsule-renderer.lua`):** Separated dominant payload item evaluation (`get_dominant_item`) and visual debug overlay rendering (`render`) into a dedicated rendering module.
4. **Runner Orchestrator & Public API (`scripts/capsules/capsule-runner.lua`):** Streamlined the central module down to `on_tick` loop orchestration, hub injection (`inject_from_hub`), emergency passenger ejection (`emergency_eject`), and public query delegation while preserving top-level `require` dependencies.


### Revision: Mid-Transit Biodegradable Capsule Failure Evaluation
**Date:** 2026-08-27 10:43 (EDT)  
**Context:** Resolve issue where biodegradable capsules never ruptured en-route by restoring the missing `spill_risk` evaluation in `capsule-lifecycle.lua`.

**Key Changes:**
1. **Mid-Transit Failure Roll (`scripts/capsules/capsule-lifecycle.lua`):** Restored the missing `def.spill_risk` probability roll inside `capsule_lifecycle.update()`, returning `true` upon structural failure to allow `capsule-runner.lua` to process the mid-transit rupture.
2. **Rupture & State Cleanup (`scripts/capsules/capsule-lifecycle.lua`):** Added top-level `require` for `capsule-queries` to destroy the liminal holder entity, clear visual render overlays, and unregister active capsule tracking state upon failure.


### Revision: Centralized Liminal Capsule Spilling & Ground Item Deconstruction
**Date:** 2026-08-27 11:03 (EDT)
**Context:** Unify capsule payload spilling into a single master API hook across entity destruction and mid-transit structural failures, while resolving missing deconstruction orders on items spilled directly onto the ground.

**Key Changes:**
1. **Master Spill Hook & Force Resolution (`scripts/hubs/hub-spill.lua`):** Centralized liminal holder eviction, motion runner unregistration (`capsule_queries.remove_capsule`), render overlay cleanup, and explosion effects into `hub_spill.spill_capsule()`. Added fallback force evaluation (`force or holder.force or "player"`) to ensure mid-transit ruptures retain force ownership.
2. **Ground Item Deconstruction Marking (`scripts/hubs/hub-spill.lua`):** Implemented `spill_and_mark_stack` helper to iterate over `item-on-ground` entities returned by `surface.spill_item_stack` and explicitly invoke `order_deconstruction(force)` when `mark_for_deconstruction = true` is configured in `capsule-definitions.lua`.
3. **Mid-Transit Failure Decoupling (`scripts/capsules/capsule-lifecycle.lua`):** Removed duplicate inline item spilling logic (`execute_spill`) in favor of direct calls to `hub_spill.spill_capsule()`, preserving strict top-level module `require` loading rules.


### Revision: Passenger Emergency Eject Visual Overlay & Spatial Alignment
**Date:** 2026-08-27 11:51 (EDT)
**Context:** Add a player-exclusive visual prompt for passenger transit capsules to inform active riders of the emergency eject keybind (`[Shift + E]`) without displaying to non-passengers or overlapping the capsule ring overlay.

**Key Changes:**
1. **Passenger-Exclusive Text Overlay (`scripts/capsules/capsule-renderer.lua`):** Added a `rendering.draw_text` render call inside `capsule_renderer.render` targeting `players = { capsule.passenger }` so the `"[Shift + E] Emergency Eject"` text is strictly rendered for the active rider.
2. **Static Target Coordinate Offsetting (`scripts/capsules/capsule-renderer.lua`):** Explicitly offset the target position table (`{ curr_pos.x, curr_pos.y + 0.8 }`) to bypass Factorio's rendering API limitation where `target_offset` is ignored on static map coordinates, positioning the prompt cleanly below the passenger capsule ring.


### Revision: Crossflow Junction Prototype & Visual Entity Tinting
**Date:** 2026-08-27 12:15 (EDT)
**Context:** Implemented isolated two-way crossflow pipe routing via dual port grouping and applied distinct visual RGBA tints across all pneumatic network entity prototypes.
**Key Changes:**
1. **Entity Prototypes & Visual Tints (`prototypes/entity.lua`):** Applied RGBA layer tints to `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, and `junction` for entity distinction. Registered the `crossflow-junction` simple-entity prototype.
2. **Item & Recipe Registrations (`prototypes/item.lua`, `prototypes/recipe.lua`):** Created the `crossflow-junction` item prototype under the `storage` subgroup and added its recipe (4x pneumatic-tube, 4x steel-plate, 2x advanced-circuit).
3. **Tech Tree Integration (`prototypes/technology.lua`):** Added the `crossflow-junction` recipe unlock effect to the baseline `pneumatic-transport` technology.
4. **Dual-Group Port Definitions (`scripts/ports/port-definitions.lua`):** Configured `crossflow-junction` port topology with split group assignments (`group = 1` for vertical ports, `group = 2` for horizontal ports), ensuring automatic sub-network isolation across perpendicular directions.


### Revision: Crossflow Junction Port Evaluator & Multi-Group Flow Culling Fix
**Date:** 2026-08-27 14:28 (EDT)  
**Context:** Resolve issue where crossflow junction horizontal ports failed to transmit pressure or build network merge links, while ensuring flow vector overlays on disconnected arms are properly pruned.

**Key Changes:**
1. **Cross-Entity Port Group Compatibility (`scripts/ports/port-evaluator.lua`):** Removed the `port_a.group ~= port_b.group` restriction from `port_evaluator.are_compatible()`. Group IDs represent entity-internal port set boundaries rather than external connection constraints, allowing secondary entity groups (`group = 2`) on crossflow junctions to merge cleanly with standard network tubes (`group = 1`).
2. **Multi-Group Entity Flow Culling (`scripts/networks/flow-cull.lua`):** Updated multi-port entity checks to evaluate total physical entity ports via `port_defs.get_ports(node.entity)` instead of counting local `flow_map` nodes. This ensures sub-network culling passes correctly identify dual-group 4-port entities, pruning dead-end outbound vector hops and clearing orphaned visual flow overlays.