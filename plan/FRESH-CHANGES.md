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