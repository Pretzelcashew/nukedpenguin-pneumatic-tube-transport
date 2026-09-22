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


### Revision: Render Pool Text Z-Ordering & Line Layer Deprioritization
**Date:** 2026-09-21 23:18 EDT
**Context:** Resolves visual dropouts where pressure flow numbers and counter range text sometimes rendered behind circular flow dots and connector lines. Native Factorio render object IDs determine default draw order within a render layer; when handles are recycled through free lists out of original creation order, circles could be drawn over numbers.

**Key Changes:**
1. **Text Z-Index Promotion (`scripts/utils/render-pool.lua`, `scripts/flow/flow-renderer.lua`):** Invoked `obj.bring_to_front()` across both fresh and recycled text handles in `render_pool.lease_text` and `render_flow_dot_static`, ensuring numbers always render on top of shapes. Added `vertical_alignment` mutation handling upon text lease.
2. **Vector Line Deprioritization (`scripts/utils/render-pool.lua`):** Invoked `obj.move_to_back()` on fresh and recycled line handles in `render_pool.lease_line`, keeping tube-to-tube directional vector lines behind pressure dots and labels.


### Revision: Dirty Static Render Batching, In-Place Property Mutation & O(1) Corridor Leaf Eviction
**Date:** 2026-09-21 23:25 EDT
**Context:** Eliminates performance drops during mass tube unmerging and pressure wave cascades caused by thousands of unbatched render object updates and full-tree leaf prefix scans. Replaces immediate mid-tick overlay rebuilds with end-of-tick dirty leaf flushing, mutates existing visual handles in place, and targets corridor slice removals by exact key.

**Key Changes:**
1. **Dirty Render Batching & Deduplicated Flush (`scripts/flow/flow-renderer.lua`, `scripts/flow/flow-engine.lua`):** Implemented `flow_renderer.mark_pos_dirty(pos_key)` and `flow_renderer.flush_dirty_renders()` tracking modified tiles across the tick. Deduplicates visited corridor leaves (`visited_leaves`) to dispatch `on_leaf_static_changed` at most once per 16-tile slice at the end of `flow_engine.step`, eliminating dozens of redundant redraws per tick as pressure drains down tube lines.
2. **In-Place Visual Property Mutation (`scripts/flow/flow-renderer.lua`):** Overhauled `render_flow_dot_static` to key `item.render_objects` by node sub-keys (`pos_key .. ":circ"`, `pos_key .. ":text"`, `line_key .. ":line"`). Updates `color` and `text` directly on existing valid handles in-place, eliminating wholesale `recycle_many` and re-leasing churn during pressure decay. Recycles only stale handles when pressure hits zero.
3. **O(1) Segment Key Leaf Eviction (`scripts/flow/flow-collapse.lua`):** Updated `evict_segment_leaf`, `divide_run`, and `handle_node_destroyed` to pass exact `leaf.seg_key` identifiers to `viewport_bvh.on_segment_removed` when iterating `run.leaves`. Bypasses full-table linear prefix scans across `leaves_by_key` and player visible sets in favor of instant $O(1)$ table lookups.


### Revision: Terminal Tube Traversal & Boundary Pressure Gradient Inheritance
**Date:** 2026-09-21 23:55 EDT
**Context:** Resolves an issue where capsules entering the final tube or dead-end conduit of a line stalled at the entrance seam and refused to step internally to the terminal cap. Eliminates false-rejection lookahead on non-diverters and carries incoming positive pressure through terminal conduits with zero local pressure.

**Key Changes:**
1. **Diverter-Scoped Exit Lookahead (`scripts/capsules/capsule-runner.lua`):** Restricted recursive `has_valid_exit` lookahead in `is_hop_valid` strictly to multi-port diverters (`is_diverter`), allowing standard tubes, junctions, and passive conduits to accept internal hops to terminal dead-end ports without requiring downstream exits.
2. **Incoming Pressure Gradient Inheritance (`scripts/capsules/capsule-runner.lua`):** Updated `select_next_target` to inspect `capsule.last_port_key` when an internal conduit port has zero local pressure (`level_exit == 0`). If the capsule was pushed in from a port with positive pressure ($\ge 1$), `level_exit` inherits the incoming pressure level, ensuring $1 \to 0$ drops evaluate as positive gradients ($\Delta P > 0$) to carry capsules across the tube to the terminal cap.


### Revision: BVH Sibling Nil-Guards, Anti-Double-Free Gating & Machine Leaf Wildcard Immunity
**Date:** 2026-09-22 00:16 EDT
**Context:** Resolves a crash in `trajectory-bvh.lua:267` (`attempt to index local 'sibling' (a nil value)`) when anti-reticle flights reel in trailing projector corridors. Eliminates an issue where Electromagnetic Projector machine footprint leaves (`unit_number:machine`) and Alt-Mode port dots were prematurely evicted from the spatial tree during beam and corridor lifecycle cleanups.

**Key Changes:**
1. **Defensive Sibling & Parent Linkage Guards (`scripts/utils/trajectory-bvh.lua`):** Added explicit `if sibling then` checks before re-parenting in `remove_leaf_node` and validated parent-child linkages, allowing single-child branches to collapse safely without engine crashes during segment peeling.
2. **Free-Pool Double-Free Protection (`scripts/utils/trajectory-bvh.lua`):** Added `node.is_recycled` re-entrancy guards in `recycle_node` (cleared on `lease_node`) to prevent recycled node tables from entering `free_nodes` multiple times and sharing memory tables.
3. **Machine Leaf Wildcard Immunity (`scripts/utils/viewport-bvh.lua`):** Updated `viewport_bvh.on_segment_removed` to strictly exempt `leaf.seg_key ~= "machine"` and `item.seg_key ~= "machine"` when processing wildcard prefix removals (`owner_id:*`). Guarantees that permanent physical machine footprints and their port dot overlays persist through all beam retractions, rotations, and unlinks without periodic polling loops.


### Revision: Lifecycle-Bound Timed Arrival Reticles & On-Demand Tube Transit Rendering
**Date:** 2026-09-22 10:05 EDT
**Context:** Resolves an issue where timed arrival reticle dots for pneumatic tube capsules failed to appear on demand, vanished immediately after rendering, or required manual toggle flickering. Fixes an uninitialized local variable scope error in the per-frame render pass, decouples arrival dot destruction from routine icon cache invalidations, directly inspects active timed hops on capsule records, and provides seamless in-place target coordinate updates across successive hops.

**Key Changes:**
1. **Variable Scope Rectification & Direct Hop Binding (`scripts/capsules/capsule-renderer.lua`):** Hoisted `local cap_id` resolution above `update_arrival_dots` in `capsule_renderer.render`, preventing `nil` arguments from aborting reticle evaluation. Updated `update_arrival_dots` and `render_arrival_dot_for_player` to inspect `capsule.timed_hop` directly in $O(1)$ time alongside ballistic flights and generic arrival heap records.
2. **Decoupled Arrival Lifecycles & Premature Recycle Elimination (`scripts/capsules/capsule-renderer.lua`):** Removed `destroy_arrival_dot` from `recycle_capsule_render`, preventing internal dominant item and spoilage cache invalidations from prematurely reclaiming target dots from the render pool. Bound reticle teardown strictly to flight parking (`handle_tube_hop_arrival`), entity removal (`remove_capsule`), and unpressurized stoppage.
3. **Pneumatic Tube Reticle Styling & In-Place Target Snapping (`scripts/capsules/capsule-renderer.lua`):** Added a dedicated amber visual style for tube hops (`color = {r=1.0, g=0.75, b=0.2, a=0.8}`, `radius = 0.14` dot, `radius = 0.28` ring). Mutates existing leased primitive targets in place across contiguous hops, eliminating visual flicker and redundant object allocations.
4. **Lifecycle Teardown Synchronization (`scripts/capsules/capsule-runner.lua`):** Added explicit `capsule_renderer.destroy_arrival_dot` cleanup calls upon capsule destruction in `remove_capsule` and upon hop termination when incoming capsules park due to downstream congestion.
5. **Zero-Polling Debug Notification Hook (`scripts/debug-manager.lua`, `scripts/capsules/capsule-renderer.lua`):** Implemented `debug_manager.register_arrival_hook` to dispatch instant `destroy_player_arrival_dots` and visible reticle synchronization upon toggling `/toggle-arrival-dots` or clicking the control panel checkbox without introducing circular require loops.


### Revision: Continuous A-to-B Flights Across Merged Corridors (Task 4)
**Date:** 2026-09-22 11:00 EDT
**Context:** Completes Task 4 of the motion refactor roadmap by enabling capsules entering pairwise collapsed tube corridors to bypass all intermediate 1-tile hops and launch directly on unbroken, full-distance flights from entrance to exit. Resolves an issue where 0-distance junction flange seams bypassed corridor checks, evaluates pressure gradients across outer segment spans to ensure integer pressure plateaus merge completely, and binds in-flight capsule visibility to the observer frustum with zero off-screen rendering overhead.

**Key Changes:**
1. **Memorized Endpoint Corridor Traversal (`scripts/capsules/capsule-runner.lua`):** Implemented `try_advance_corridor` in the capsule movement pipeline. When a capsule is at any port belonging to an active merged corridor (`storage.run_by_port[cur_pkey]`), it looks up the pre-baked exit endpoint (`run.end_pkey`) and launches a single continuous flight for the full multi-tile distance ($L \times \text{STAGGER\_TICKS}$) on the binary arrival heap, reducing simulation overhead by over 90% across long lines.
2. **0-Distance Seam Bypass Resolution (`scripts/capsules/capsule-runner.lua`):** Relocated corridor evaluation inside the `while hops < MAX_NODE_HOPS_PER_STEP do` multi-hop advancement loop. Eliminates an issue where 0-distance internal transfers across junction flanges (`dist < 0.05`) bypassed corridor detection and caused the motion engine to fall back to discrete 1-tile hops.
3. **Outer-Span Gradient Evaluation (`scripts/flow/flow-collapse.lua`):** Implemented `get_outer_port` to evaluate pressure gradients across the outer ends of candidate merged segments rather than between touching connection ports at the flange. Resolves an issue where equal local connection pressures ($P_1 = P_2 = 5$) falsely evaluated to $\Delta P = 0$, allowing contiguous straight tubes sharing the same flow vector to fold into unified runs from source to sink.
4. **Spatiotemporal Viewport Frustum Culling (`scripts/capsules/capsule-runner.lua`):** Gated in-flight capsule rendering behind `capsule_renderer.is_in_any_viewport`. When capsules travel through unobserved sections of a long pneumatic corridor, they bypass visual drawing and immediately recycle existing render pool handles, preventing ghost sprites from lingering at entrance boundaries.


#### 0.3.23

### Revision: Spatiotemporal Tube Severance, Re-Anchored Horizon Kinematics & Breach Containment
**Date:** 2026-09-22 15:10 EDT
**Context:** Eliminates mid-flight rubber-band teleportation, slingshotting, and false arrival spillage when pneumatic tube corridors are severed. Replaces compressed timeline interpolation with continuous floating-point re-anchoring, corrects entrance boundary spatial thresholds, clamps truncation targets ahead of the capsule, and guarantees safe in-tube parking at the surviving breach face.

**Key Changes:**
1. **Continuous Origin Re-Anchoring (`scripts/utils/timed-motion.lua`):** Overhauled `timed_motion.shift_horizon` to sample `get_interpolated_position` and re-anchor `record.start_pos` and `record.start_tick` to `cur_pos` and `current_tick`. Eliminates timeline compression distortions where shortening destinations mid-flight against a stale historical origin caused linear interpolation fractions to jump and slingshot capsules past the truncation point.
2. **Spatiotemporal Removal Interval Partitioning (`scripts/capsules/capsule-runner.lua`):** Replaced the tautological $|d_{\text{obst}} - d_{\text{cur}}| \le 0.5$ check with exact physical thresholds based on bounding-box entrance boundaries. Partitions motion cleanly into downstream pass-through ($d_{\text{cur}} > d_{\text{obst}} + 1.0$), loss-of-containment breach spills ($d_{\text{cur}} \in [d_{\text{obst}} - 0.05, d_{\text{obst}} + 1.0]$), and upstream truncation ($d_{\text{cur}} < d_{\text{obst}} - 0.05$).
3. **Forward-Clamped Truncation Horizons (`scripts/capsules/capsule-runner.lua`):** Clamped truncation distance to $\max(d_{\text{cur}}, d_{\text{obst}} - 0.5)$, preventing inverted target vectors and negative-distance calculation errors when capsules are already past the center of the preceding tube.
4. **Severed Arrival Lockout & Safe In-Tube Parking (`scripts/capsules/capsule-runner.lua`):** Flagged truncated flights with `flight.severed`. Interrupted arrivals bypass `try_advance_capsule` and corridor re-launches, dynamically query `storage.flow_nodes` for the surviving tube port at `term_pos`, and cleanly park the capsule inside the surviving tube with zero cargo spillage.
5. **Watchdog Node Recovery & Motion Contract Alignment (`scripts/capsules/capsule-runner.lua`, `scripts/utils/motion-protocols.lua`):** Added surviving node recovery to the line 915 nil-node watchdog in `update_capsules` before falling back to spills. Updated `schedule_hop` and `try_advance_corridor` with complete `dir`, `dx`, `dy`, and `ticks_per_tile = STAGGER_TICKS` motion contracts, and registered `"tube_severance"` in `motion-protocols.lua`.




