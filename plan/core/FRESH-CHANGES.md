#### 0.3.23


### Revision: Purge Non-Serializable Lua Functions from Persistent Storage
**Date:** 2026-09-14 22:36 EDT
**Context:** Factorio autosaves were failing with an engine-level `on_save()` non-recoverable error caused by Lua function references stored directly in persistent `storage` tables. This session neutralized legacy heap comparator closures and enforced string-only callback identifiers across all timed motion flight records.
**Key Changes:**
1. **Storage Setup Migration (`control.lua`):** Stripped legacy `comparator` functions from active binary heaps (`spoil_heap`, `timed_arrival_heap`, `kinetic_arrival_heap`) and cleared function callbacks from `timed_flight_records` during `setup_storage()`.
2. **Heap Attachment Sanitization (`scripts/utils/binary-heap.lua`):** Added explicit `heap.comparator = nil` inside `binary_heap.attach` to neutralize lingering legacy comparator functions upon deserialization with zero runtime overhead.
3. **Flight Record Hardening (`scripts/utils/timed-motion.lua`):** Enforced string-only typing on `on_arrival` specifications in `timed_motion.create_record`, permanently preventing function closures from entering `storage.timed_flight_records`.
4. **Arrival Dispatch Resolution (`scripts/capsules/capsule-ballistics.lua`):** Updated `handle_timed_arrival` to resolve string `on_arrival` keys through the registered arrival handler table.


### Revision: Decouple Viewport BVH Culling from Coordinate Polling and Bound Hysteresis Margins
**Date:** 2026-09-14 23:44 EDT
**Context:** Periodic flight debug logging was spamming the chat console, and a redundant coordinate bounding check in the render loop was forcing per-tick flight polling while prematurely clipping coarse 16-tile BVH leaves. Additionally, the observer hysteresis shell expanded into a massive 128-tile off-screen void at far zoom levels due to a percentage-based margin multiplier.
**Key Changes:**
1. **Render Loop Hardening & Polling Purge (`scripts/capsules/capsule-renderer.lua`):** Purged 60-tick periodic console debug prints and eliminated redundant per-tick coordinate checks (`is_on_screen`), restoring event-driven coarse-grained leaf culling so projectiles render across the full length of any subscribed 16-tile BVH segment without coordinate polling.
2. **Fixed-Leaf Hysteresis Bounding (`scripts/utils/viewport-bvh.lua`):** Replaced the percentage-based shell multiplier with a fixed 16-tile margin (`SHELL_TILES = 16`), ensuring the hysteresis buffer equals exactly one static BVH leaf in every direction and capping the maximum trailing buffer to 32 tiles at any camera zoom level.
3. **Frustum Calculation & Dynamic Contraction (`scripts/utils/viewport-bvh.lua`):** Removed the 150-tile clamping ceiling and UI scale divisor from screen frustum calculations, replaced static world-space shrunk boxes with a 25% zoom-in contraction trigger (`SHRINK_THRESHOLD = 0.75`), and disabled debug test rendering in production.


### Revision: Multi-Segment Projector Scope Probing & Viewport Static Trail Rendering
**Date:** 2026-09-15 01:01 EDT
**Context:** Replaces recursive 16-tile muzzle probes with a chained multi-segment projector scope flight pipeline that populates corridor trajectories and binds static trail markers and endpoint indicators to viewport BVH leaves during Alt-mode.
**Key Changes:**
1. **Scope Arrival & Segment Chaining (`scripts/capsules/capsule-ballistics.lua`, `scripts/utils/timed-motion.lua`):** Implemented `handle_projector_scope_arrival` to step through successive 16-tile corridor segments until remaining range reaches zero, registering motion leaves and anchoring endpoint data in `storage.projector_scope`.
2. **Kinetic Probe Launch & Lifecycle (`scripts/flow/flow-kinetic.lua`, `scripts/projectors/projector-manager.lua`):** Converted muzzle emission to initiate tracked `projector_scope` flights bound to total emitter reach, with state cleanup on beam cessation and projector deconstruction.
3. **Incremental Dot Trail Rendering (`scripts/capsules/capsule-renderer.lua`):** Added leaf-relative segment matching for scope flights alongside incremental dot trail generation using quality-tiered beam color palettes.
4. **Static Leaf Attachments & Alt-Mode Sync (`scripts/utils/viewport-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Added static render leasing and recycling for persistent beam trails and endpoint reticles in viewport leaves, synchronizing visibility against player Alt-mode toggles.


### Revision: Decoupled Reticle Corridors, Anti-Reticle Temporal Wake Reeling, and Isolated Viewport Indexing
**Date:** 2026-09-15 09:07 EDT
**Context:** Projector beam corridors were previously coupled to physical entity unit numbers, causing key collisions, corrupted orientation math, and an inability to smoothly clean up wake trails upon machine rotation or power loss. This session decoupled reticle BVH ownership from physical projector entities, implemented an invisible anti-reticle arrival pipeline for tandem temporal wake reeling, and hardened viewport visible set namespacing against dot hijacking.
**Key Changes:**
1. **Decoupled Reticle Corridors & Orphaning (`scripts/flow/flow-kinetic.lua`, `scripts/projectors/projector-manager.lua`):** Assigned unique `reticle_id` identifiers to each emitted scope flight and corridor, allowing projectors to orphan active beams on rotation, power loss, or deconstruction and fire new beams immediately without BVH leaf collisions.
2. **Anti-Reticle Flight & Arrival Cleanup (`scripts/capsules/capsule-ballistics.lua`, `scripts/flow/flow-kinetic.lua`):** Scheduled invisible `anti_reticle` flights on the binary arrival heap to time-slice wake cleanup in 16-tile hops behind advancing reticles, unpinning `storage.pinned_corridors` and culling BVH segments upon reaching terminal endpoints.
3. **Tandem Flight & Temporal Wake Reeling (`scripts/capsules/capsule-renderer.lua`, `scripts/capsules/capsule-ballistics.lua`):** Enabled reticles and anti-reticles to advance concurrently in tandem, using closed-form temporal math (`dist_cleared`) to reel in wake dots for observers while suppressing sub-event dot updates when off-screen.
4. **Orthogonal Direction Derivation (`scripts/utils/viewport-bvh.lua`, `scripts/capsules/capsule-renderer.lua`):** Replaced short-circuiting ternary direction lookups with explicit coordinate delta comparisons against segment `start_pos` and `end_pos`, eliminating 45-degree diagonal slants on cardinal beams.
5. **Viewport Visible Set Namespacing & Double-Free Guard (`scripts/utils/viewport-bvh.lua`, `scripts/utils/render-pool.lua`):** Enforced `owner_id:seg_key` namespacing across `v_set` entries to prevent concurrent beams from hijacking shared render arrays, and added an early-exit visibility guard to `render_pool.recycle` to prevent duplicate free-list insertions.
6. **Obstruction Decoupling (`scripts/flow/flow-kinetic.lua`):** Stubbed out premature obstacle-based reticle orphaning in `flow_kinetic.handle_obstacle_changed` to ensure building adjacent machines does not trigger false anti-reticle retreats.


### Revision: Hardened Tandem Flight Indexing, Wake-Boundary Suppression, and Viewport Lifecycle Pruning
**Date:** 2026-09-15 09:32 EDT
**Context:** Rapid projector rotation and multi-instance firing revealed visual artifacts during tandem flight, including chunked dot respawning, array index hole collisions under Lua's length operator, and orphaned handles lingering in player visible sets. This session stabilized concurrent reticle and anti-reticle flight by enforcing direct slot indexing, gating dot generation behind the trailing wake boundary, isolating endpoint visual handles from numeric step arrays, and connecting segment-level arrival hooks directly to the observer viewport tree.
**Key Changes:**
1. **Direct-Slot Dot Indexing (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Replaced `#item.render_objects + 1` with explicit slot indexing (`item.render_objects[step_i] = dot_obj` and `objects[i] = dot_obj`), permanently eliminating Lua `#` array hole collapse when trailing anti-reticles recycle early slots to `nil`.
2. **Wake-Boundary Dot Suppression (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Gated runtime and static dot spawning behind `min_allowed` (`dist_cleared`), preventing advancing heads and static changed hooks from resurrecting dots behind the retreating wake.
3. **Endpoint Primitive Namespacing (`scripts/utils/viewport-bvh.lua`):** Migrated static endpoint sprites, rings, and circles from numeric indices to dedicated string keys (`"endpoint_ring"`, `"endpoint_circ"`, `"endpoint_sprite"`), shielding endpoint indicators from the numeric dot clearing loop.
4. **Observer Viewport Segment Pruning (`scripts/capsules/capsule-ballistics.lua`):** Connected `viewport_bvh.on_segment_removed` to both intermediate 16-tile hops and terminal arrivals in `handle_anti_reticle_arrival`, immediately pruning dead corridor segments from `storage.player_visible_set`.


### Revision: Deconstruction & Script-Raised Destruction Projector Reticle Orphaning
**Date:** 2026-09-15 09:42 EDT
**Context:** In sandbox and map editor modes, deconstructing or instant-deleting projectors failed to orphan their reticles because `script_raised_destroy` was improperly referenced in `active-device-scanner.lua` and the engine's generic `on_object_destroyed` handler omitted projector destruction notifications. This session corrected the event reference and wired projector destruction hooks across both object destruction and removal pipelines.
**Key Changes:**
1. **Event Reference Correction (`scripts/active-device-scanner.lua`):** Corrected `defines.script_raised_destroy` to `defines.events.script_raised_destroy`, ensuring script, editor, and sandbox deconstruction events register properly.
2. **Object Destruction Lifecycle Hook (`scripts/flow/flow-engine.lua`):** Invoked `flow_kinetic.handle_projector_destroyed(unit_number)` inside `flow_engine.handle_object_destroyed`, guaranteeing instant deconstructions orphan active reticles.
3. **Entity Removal Dispatch (`scripts/flow/flow-engine.lua`):** Added projector destruction notifications inside the `removal_events` handler so robot deconstruction and entity mining reliably trigger reticle wake reeling.


### Revision: Leaf-Scoped Spatial Obstacle Interception and Reticle Corridor Truncation
**Date:** 2026-09-15 16:14 EDT
**Context:** Implemented the foundational spatial collision pipeline for Projector Refactor Task 1, replacing global raycasts with single-pass 16-tile leaf-scoped area queries timed with probe arrivals and enabling logarithmic corridor truncation on entity placement, gate closure, and character movement.
**Key Changes:**
1. **Observer Viewport Attachment (`scripts/flow/flow-kinetic.lua`):** Imported `viewport_bvh` at the top level to resolve nil global runtime exceptions during reticle segment removal and static leaf synchronization.
2. **Leaf-Scoped Spatial Hit Detection (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.scan_leaf_rect` to execute a single spatial query bounded strictly to each 16-tile BVH leaf rectangle during generation, calculating on-axis leading face distances and shielding the emitter chassis from self-collision.
3. **Spatiotemporal Probe Sweep Gating (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Integrated leaf rect obstacle checks into `on_muzzle_want_emission` for segment 1 and `handle_projector_scope_arrival` for segments 2+, clamping forward probe flights to the collision face and suppressing downstream leaf creation.
4. **On-Axis Reticle Corridor Truncation (`scripts/flow/flow-kinetic.lua`):** Created `flow_kinetic.truncate_reticle` to clamp live corridors and decaying wakes squarely at collision faces, updating terminal segment bounds, conditionally attaching obstacle hazard rings on live emitters, and recycling downstream leaf visuals via `viewport_bvh.on_segment_removed`.
5. **Logarithmic Reactive Interception (`scripts/flow/flow-kinetic.lua`):** Wired entity placement, defensive gate transitions, and character steps to query `motion_bvh` in $O(\log N)$ time, reclassified physical characters and vehicles as blocking obstacles in `IGNORABLE_TYPES`, and dispatched instant cardinal truncation.


### Revision: Pass Player Index to Viewport Render Pool Recycling
**Date:** 2026-09-15 16:30 EDT
**Context:** Intra-leaf trail dots and endpoint visual indicators were being orphaned in Factorio's native rendering engine upon corridor truncation because render_pool.recycle was invoked without the required player_index parameter, silently failing to return handles to the player free list.
**Key Changes:**
1. **Trail Dot Recycling Signature (`scripts/utils/viewport-bvh.lua`):** Passed `player_index` into `render_pool.recycle(player_index, objects[i])` during intra-leaf dot pruning, ensuring culled dots beyond the obstacle face properly hide and return to the player render pool.
2. **Endpoint Indicator Recycling Signature (`scripts/utils/viewport-bvh.lua`):** Added `player_index` to all `render_pool.recycle` invocations for `endpoint_sprite`, `endpoint_ring`, and `endpoint_circ`, preventing orphaned endpoint indicators during corridor truncation and position relocation.


### Revision: Dynamic Horizon Rescheduling and Forward Reticle Snap Suppression
**Date:** 2026-09-15 19:10 EDT
**Context:** Placing an entity or moving an obstacle into an advancing projector corridor was previously executing an unconditional `truncate_reticle` pass. While correct for cuts behind or directly at the advancing head, obstacles placed forward along the probe's remaining path caused the visual reticle to instantly teleport forward to the collision face ahead of schedule. This session decoupled forward obstacle detection from backward truncation, preserving backward cutoffs while updating flight records and rescheduling the binary arrival heap for smooth in-flight termination.
**Key Changes:**
1. **Real-Time Head Interpolation (`scripts/flow/flow-kinetic.lua`):** Integrated `timed_motion.get_interpolated_position` into `flow_kinetic.handle_obstacle_changed` to compute the advancing probe head's exact real-time cardinal distance (`cur_head_dist`) from the launch muzzle.
2. **Directional Interception Partitioning (`scripts/flow/flow-kinetic.lua`):** Gated `flow_kinetic.truncate_reticle` strictly to obstacles appearing at or behind the current head (`o_dist <= cur_head_dist + 0.05`), ensuring corridors snap backward immediately on upstream cuts.
3. **Dynamic Flight Horizon Rescheduling (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.update_reticle_horizon` for forward obstacles (`o_dist > cur_head_dist`), clamping `terminal_pos`, resizing active BVH leaf bounds in-place, recalculating arrival ticks at constant velocity, and rebalancing the binary arrival heap without visual pop.
4. **Scope Arrival Total Distance Synchronization (`scripts/capsules/capsule-ballistics.lua`):** Synchronized `reticle.total_dist` to the exact endpoint distance upon terminal arrival in `handle_projector_scope_arrival`.


### Revision: Obstacle Clearance, Canonical Corridor Regrowth, and Viewport Dot Recycling
**Date:** 2026-09-15 20:37 EDT
**Context:** Implemented Projector Refactor Task 3 to wake up truncated reticles upon obstacle removal (mined entities, opened gates, or combat destructions) and resume forward probing to maximum reach without resetting upstream trail dots or producing downstream ghost handles.
**Key Changes:**
1. **$O(1)$ Obstacle Soft-Registration (`scripts/flow/flow-kinetic.lua`, `scripts/flow/flow-engine.lua`):** Added soft-registration tables (`storage.blocked_reticles`, `storage.blocked_reticles_by_reg`, `storage.reticle_blocked_by`) linking blocking entity unit numbers and native `script.register_on_object_destroyed` registration IDs directly to blocked reticles. Removal events and `on_object_destroyed` callbacks wake registered reticles in $O(1)$ time without map-wide scans.
2. **Canonical Segment Boundary Regrowth (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.resume_reticle_probing` to compute distance to the current segment's canonical 16-tile boundary (`(cur_seg_idx * 16) - cur_dist`) and launch forward probe flights from the unblocked collision face, preserving full projector `max_reach` and updating both motion and trajectory BVH trees without coordinate drift.
3. **Independent BVH Recycler Pruning (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` and `update_reticle_horizon` to independently scan and prune downstream segments across both `motion_tree` and `traj_tree`, ensuring culled nodes cleanly return to `bvh.free_nodes` and `/toggle-bvh` debug boxes stay contiguous.
4. **Offset-Aware Flight Dot Progression (`scripts/capsules/capsule-renderer.lua`):** Updated `dispatch_player_renders` to compute in-flight dot progress relative to `flight_start_dist` (`start_offset + math.floor(elapsed_t / tpt)`), ensuring resumed flights starting mid-segment spawn dots immediately from the collision face rather than lagging at segment origin.
5. **Cumulative Leaf Trail Sync (`scripts/capsules/capsule-ballistics.lua`):** Updated `handle_projector_scope_arrival` to compute `leaf.trail_count` cumulatively from canonical segment origins (`total_leaf_dist`), synchronize `reticle.total_dist` across segment chains, and soft-register newly encountered downstream obstacles.
6. **Unconditional Viewport Dot Recycling (`scripts/utils/viewport-bvh.lua`):** Enhanced `attach_static_render` to unconditionally prune and recycle all numeric dot handles $> \text{count}$ back into the player render pool, and updated `on_leaf_static_changed` to broadcast truncation updates across all active subscribers in `storage.player_visible_set`, permanently eliminating lingering ghost dots downstream of obstructions.


### Revision: Projector Scope Stepping and Dynamic Reticle Obstacle Clearance
**Date:** 2026-09-15 21:14 (EDT)
**Context:** Resolves trajectory misalignment and boundary errors during mid-segment projector scope propagation, and ensures growing reticles correctly adjust distances when encountering or clearing obstacles mid-flight.
**Key Changes:**
1. **Scope Step & Trajectory Segmentation (`scripts/capsules/capsule-ballistics.lua`):** Added mid-segment boundary detection to preserve segment indexing and start offsets during sub-segment steps, clamped remaining distance to zero on obstacle impact, and bypassed premature trail finalization on partial chunks.
2. **Dynamic Obstacle Clearance & Reach Checks (`scripts/flow/flow-kinetic.lua`):** Enabled in-flight reticles to dynamically restore remaining flight distance when obstacles clear during growth, and updated obstacle collision scanning to check against full potential reach rather than truncated intermediate distances.


### Revision: Multi-Layer Obstacle Clearance and Reticle Jump Mitigation
**Date:** 2026-09-15 21:35 EDT
**Context:** Clearing a downstream obstacle while an upstream obstacle remained in front of an active projector caused the reticle to wake prematurely, ignore the adjacent blocking structure, and jump through obstacles to maximum reach. This session hardened obstacle registration with single-blocker unregistration, verified active ownership during entity clearance, added on-axis overlap hit detection, and clamped terminal segment bounds upon in-flight collisions.
**Key Changes:**
1. **Single-Owner Obstacle Registration (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.unregister_reticle_obstacle` at the start of `register_reticle_obstacle` to ensure reticles track only the closest active obstacle and purge obsolete downstream waking references in $O(1)$ time.
2. **Obstacle Clearance Ownership Verification (`scripts/flow/flow-kinetic.lua`):** Gated reticle waking in `handle_reticle_obstacle_cleared` behind explicit verification against `storage.reticle_blocked_by[rid]`, permanently preventing deconstructed or mined downstream entities from waking upstream-blocked beams.
3. **On-Axis Overlap Hit Detection (`scripts/flow/flow-kinetic.lua`):** Enhanced `scan_leaf_rect` to detect entities overlapping or touching the probe origin on-axis (`cbb.left_top.x <= start_pos.x + 0.05`), preventing resumed probes from bypassing structures standing directly at `start_pos`.
4. **Scope Arrival Boundary Clamping (`scripts/capsules/capsule-ballistics.lua`):** Recalculated `d_end` immediately upon collision in `handle_projector_scope_arrival`, ensuring trajectory BVH, motion BVH, and reticle total distance clamp accurately to the obstacle face.