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