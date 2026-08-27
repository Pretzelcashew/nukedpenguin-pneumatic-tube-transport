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