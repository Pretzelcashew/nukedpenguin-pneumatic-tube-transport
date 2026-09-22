#### 0.3.23

### Revision: Pressure Corridor Colinear Gating & Open-Port Suppression
**Date:** 2026-09-19 10:06 EDT
**Context:** Lays the architectural foundation for spatial BVH pressure corridors by decoupling hop-by-hop pressure propagation from straight-line pneumatic runs. Suppresses internal pressure bleeding onto unconnected open-air ports and cuts off straight transmission across unbranched members so the flow engine reaches immediate quiescence.
**Key Changes:**
1. **Colinear Straight Evaluator Primitive (`scripts/flow/flow-common.lua`):** Implemented and exported `flow_common.is_colinear_straight_internal` with polymorphic argument handling, evaluating opposing port vectors, axial alignment, and checking if unused side ports reduce multi-port junctions to unbranched straight corridors.
2. **Event-Driven Topology Wakeups (`scripts/flow/flow-common.lua`):** Updated `destroy_node` to enqueue all unit ports of adjacent entities when an edge is severed under `USE_PRESSURE_CORRIDORS`, enabling surviving junctions to detect when branch removals return them to colinear straight status without periodic polling.
3. **Open-Port & Colinear Flow Gating (`scripts/flow/flow-engine.lua`):** Gated internal pressure transmission in `compute_port_flow_level` and `flow_engine.step` to require external connections on target ports and cut off transmission through colinear straight internal pairs, preventing pressure bleed onto empty dirt tiles.
4. **Connection Awakening & Engine Facade (`scripts/flow/flow-engine.lua`):** Added mutual unit port enqueuing in `connect_entity` upon edge formation under `USE_PRESSURE_CORRIDORS`, and exposed facade delegation `flow_engine.is_colinear_straight_internal = flow_common.is_colinear_straight_internal` for backwards-compatible cross-system access.


#### 0.3.23

### Revision: Render Pool Channel Segregation, Amortized Pool Decay & Unified Kinetic Overlay Visibility
**Date:** 2026-09-21 10:15 EDT
**Context:** Eliminates cross-subsystem render object poaching and property bleeding between projector reticle trail dots and capsule/arrival rings by introducing channel-partitioned pools. Replaces the obsolete static 128-object recycling ceiling with the mod's standard 120-tick amortized dual-watermark decay and storage compaction. Purges speculative `tube_wave` and `tube_transit` AI template cruft from `motion-protocols.lua`. Replaces fragmented, desynchronized visibility state checks across five files with a single authoritative predicate (`should_render_kinetic_overlays`) and a centralized $O(K)$ visible-set synchronizer (`sync_player_overlays`), ensuring the "Flow & Kinetic Beams" GUI toggle and Alt-Mode are strictly respected without brute-force polling or argument type errors.

**Key Changes:**
1. **Channel-Isolated Render Pool & Full Sanitization (`scripts/utils/render-pool.lua`):** Added a 4th dimension to free lists (`storage.render_pool[p_idx][s_idx][channel][archetype]`) isolating `"reticle"`, `"capsule"`, `"arrival"`, and `"default"`. Mapped native object handles in `storage.render_pool_channels[obj.id]` so generic recycling loops (`recycle_many`) automatically route objects back to their dedicated channel. Fully sanitizes `render_layer`, `draw_on_ground`, `width`, `filled`, `radius`, and `color` upon circle re-leasing.
2. **Amortized Allocation Decay & Compaction (`scripts/utils/render-pool.lua`, `control.lua`):** Replaced the hardcoded static `MAX_POOL_PER_ARCHETYPE = 128` ceiling in `recycle()` with `RUNAWAY_LEAK_CEILING = 2048` to absorb multi-projector launch bursts smoothly. Implemented `render_pool.step_decay(max_prune)` with channel-specific retention floors (reticle: 48, capsule: 32, arrival: 16) running on `script.on_nth_tick(120)` in `control.lua`, and `render_pool.compact(32)` running during `setup_storage` save migrations.
3. **AI Template Purge & Protocol Contract Alignment (`scripts/utils/motion-protocols.lua`):** Excised unasked-for `tube_wave` and `tube_transit` protocol registrations. Updated `test-motion-protocols` Test 5 to verify facet independence using legitimate core protocols (`anti_reticle` vs `capsule`). Removed circular runtime `require("scripts.flow.flow-kinetic")` calls.
4. **Single Source of Truth Visibility Predicate (`scripts/utils/viewport-bvh.lua`):** Implemented `viewport_bvh.should_render_kinetic_overlays(player_index)` evaluating Alt-Mode (`show_entity_info`), non-chart render modes, master debug status, and the "Flow & Kinetic Beams" setting (`new_flow`). Implemented `viewport_bvh.sync_player_overlays(player_index)` to attach or detach static corridor dots and endpoint rings strictly across the existing active visible set ($O(K)$) without tree churn.
5. **Leak Clearance Across BVH & Flight Dispatch (`scripts/utils/viewport-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Replaced five hardcoded `if alt_mode then attach_static_render` call-sites across `on_segment_registered`, `on_leaf_static_changed`, and `sync_player_visibility` with the unified predicate. Gated in-flight reticle trail dots and wake peeling in `dispatch_player_renders` behind `should_render_kinetic_overlays`.
6. **GUI Checkbox Synchronization & Strict Integer Contracts (`scripts/debug-manager.lua`, `control.lua`, `scripts/utils/viewport-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Wired `on_gui_checked_state_changed` (`pneumatic_debug_chk_new_flow`, `pneumatic_debug_chk_master`), `/toggle-flow`, and `/toggle-debug` to trigger `viewport_bvh.sync_player_overlays`. Bound `defines.events.on_player_toggled_alt_mode` in `control.lua`. Enforced strict integer `player_index` contracts across all sync handlers, completely eliminating defensive `player_or_index` type fallbacks and `userdata` crashes.


### Revision: Unified Motion Substrate & Arrival Heap 1-Tile Hops (Task 2)
**Date:** 2026-09-21 20:15 EDT
**Context:** Implements Task 2 of the motion refactor roadmap by migrating discrete 1-tile tube capsule movement onto the unified binary arrival heap (`timed_motion`), enabling continuous 60 FPS sub-tile gliding and viewport-culled rendering.

**Key Changes:**
1. **Tube Hop Arrival Protocol (`scripts/utils/motion-protocols.lua`):** Registered the `"tube_hop"` arrival callback. Handles port arrival transfers, occupancy updates, and next-hop evaluations on heap pop without altering the underlying stepper.
2. **Scheduled 1-Tile Flights (`scripts/capsules/capsule-transit.lua`, `scripts/capsules/capsule-runner.lua`):** Capsules advancing between adjacent ports schedule 6-tick flights on the arrival heap via `timed_motion.schedule_flight`.
3. **Broadphase BVH Churn Suppression (`scripts/utils/timed-motion.lua`):** Guarded `schedule_flight` to skip registering short 1-tile hops into `storage.surface_bvh`, preventing tree thrashing on standard tube traversal.
4. **Sub-Tile Gliding & Frustum Culling (`scripts/capsules/capsule-renderer.lua`):** Interpolates sub-tile positions via `timed_motion.get_interpolated_position`. Off-screen capsules in dormant viewports consume 0 rendering calls.
5. **Render Object Property Sanitization (`scripts/capsules/capsule-renderer.lua`):** Purged `render_layer` assignments on native circle render objects, resolving Factorio 2.0 assertion errors.


### Revision: Dynamic Pairwise Node Collapse & Delta-P Evaluator (Task 3)
**Date:** 2026-09-21 20:45 EDT
**Context:** Implements Task 3 of the node collapse roadmap, replacing individual 1-tile tube leaves in `storage.motion_bvh` with dynamically collapsed corridor runs along active pressure gradients. Enforces zero-gradient stagnation gating, provides atomic midsegment deconstruction handling, and fixes render-pool sprite tinting and runtime require crashes.

**Key Changes:**
1. **Delta-P Gradient Evaluator (`scripts/flow/flow-common.lua`):** Added `flow_common.get_colinear_gradient` evaluating pressure gradients ($\Delta P = P_{\text{in}} - P_{\text{out}}$). Returns `0, nil` to forbid pairing on unpressurized lines, dead-ends capped by walls, and opposing pump seams.
2. **Pairwise Merge & Division Queues (`scripts/flow/flow-collapse.lua`):** Implemented `flow-collapse.lua` processing atomic pairwise folds ($merge(A,B) \to AB$) and unmerges ($AB \to A+B$) at 50 ops/tick. Allocates synthetic `run_id`s (1,000,000+) and generates strictly 1.0-tile-thin corridor AABB leaves in `storage.motion_bvh`.
3. **O(1) Midsegment Removal (`scripts/flow/flow-common.lua`, `scripts/flow/flow-collapse.lua`):** Hooked `midsegment_removal_handler` into `flow_common.destroy_node`. Mining a tube inside an active collapsed edge evicts the corridor leaf from the BVH in $O(1)$, restores baseline leaves for surviving units, and enqueues surviving halves for re-folding.
4. **Engine Integration & Diagnostics (`scripts/flow/flow-engine.lua`):** Wired `flow_collapse.step` into the tick loop, enqueued ports on `flow_changed` and entity builds, and registered `/check-collapsed-edges` for console inspection.
5. **Render Object Tint & Top-Level Require Fixes (`scripts/utils/render-pool.lua`, `scripts/flow/flow-collapse.lua`, `scripts/flow/flow-engine.lua`):** Corrected `obj.tint` to `obj.color` on recycled sprite handles in `render-pool.lua` with white fallback. Bound `flow_collapse.set_engine` at top-level script load time in `flow-engine.lua`, purging inline runtime `require` calls during entity mining.


### Revision: Corridor 16-Tile BVH Slicing, Multi-Unit Dot Rendering & Merge Queue Throttling
**Date:** 2026-09-21 21:55 EDT
**Context:** Resolves visual dot dropouts and spatial bounding box gaps along collapsed tube runs while smoothing out background graph contraction. Partitions merged corridors into discrete $\le 16$-tile broadphase leaves for viewport culling, upgrades static flow rendering to iterate member units of collapsed runs with numbered pressure badges, fixes half-tile port AABB clipping, throttles pairwise merge batch sizes to prevent UPS drops, and disambiguates BVH branch nodes from leaf corridors in debug visualization.
**Key Changes:**
1. **Dual-Port AABB Rectification & 16-Tile Slicing (`scripts/flow/flow-collapse.lua`):** Implemented `flow_collapse.create_and_register_slices` partitioning collapsed corridors into $\le 16$-tile leaves in `storage.motion_bvh`. Updated spatial bounds evaluation to inspect all port offsets per tube unit and applied $\pm 0.5$ tile padding, eliminating the 1-tile AABB gap between contiguous leaves.
2. **Multi-Unit Static Flow Overlay Rendering (`scripts/flow/flow-renderer.lua`):** Expanded `render_flow_dot_static` to support `leaf.units` collections, rendering pressure circles, numbered flow text, and vector lines for all member tubes in a corridor chunk. Deduplicated rendering per tile and routed flow change notifications in `notify_pos_changed` to active corridor leaves.
3. **Pairwise Merge Batch Throttling (`scripts/flow/flow-collapse.lua`):** Throttled `BATCH_SIZE` from 50 to 8 operations per tick across merge and division queues, eliminating the momentary 3-UPS dip during multi-tile line builds and pairwise graph folding.
4. **BVH Debug Hierarchy Disambiguation (`scripts/utils/trajectory-bvh.lua`):** Re-styled internal BVH branch nodes as thin light purple (`width = 1`, low alpha) to visually separate spatial hierarchy clusters from physical tube corridors. Distinguished merged corridor leaves in vibrant teal (`width = 2`, `[Run #...]`) from baseline unmerged tubes (`[Base #...]`), and eliminated the duplicate render array overwrite in `surface_bvh`.


### Revision: Amortized Queue Pacing & Topology-Aware Junction Branching
**Date:** 2026-09-21 23:05 EDT
**Context:** Resolves momentary FPS/UPS drops during mass corridor unmerging (e.g. turning off pump flow across 60+ tubes) by amortizing merge and division queue processing. Makes pairwise collapsed corridors responsive to real-time graph topology changes, cleanly unmerging lines at junctions when perpendicular side branches are added and folding them back together when branches are removed.

**Key Changes:**
1. **Amortized Queue Batching & Sweep Pacing (`scripts/flow/flow-collapse.lua`):** Throttled pairwise division queue processing from `BATCH_SIZE = 8` down to `DIV_BATCH_SIZE = 1` operation per tick and merge processing to `MERGE_BATCH_SIZE = 2` operations per tick. Paced Phase B background edge sweeps to run on `tick % 15 == 0` instead of every tick, bounding spatial BVH mutations and leaf re-registrations to completely eliminate FPS drops.
2. **Topology-Aware Branch Invalidation (`scripts/flow/flow-collapse.lua`, `scripts/flow/flow-engine.lua`):** Implemented `flow_collapse.is_unit_colinear_straight(unit_number, expected_axis)` to evaluate whether an entity's internal straight ports remain unbranched. Wired `flow_engine.connect_entity` to dispatch `flow_collapse.handle_connection_added` upon edge creation, immediately flagging any collapsed run whose internal junction acquires an offshoot for division via `flow_collapse.invalidate_run`.
3. **Surviving Sub-Run Retention & Baseline Restoration (`scripts/flow/flow-collapse.lua`):** Refined `divide_run` to test `is_unit_colinear_straight` across child units, allowing straight corridor halves without the branch to remain merged while cleanly returning the branched junction to a baseline motion leaf in `storage.motion_bvh`. Corrected `storage.run_by_port` pointer re-assignment during child division stages to eliminate lookup race conditions.
4. **Edge Severing & Depressurization Hooks (`scripts/flow/flow-common.lua`, `scripts/flow/flow-engine.lua`):** Hooked `flow_common.on_edge_severed_handler` into `destroy_node` to trigger `flow_collapse.handle_connection_removed`, automatically re-enqueuing surviving junctions to fold back into straight runs when branches are mined. Wired `flow_engine.step` on `flow_changed` to immediately invalidate active runs when $\Delta P \to 0$.





