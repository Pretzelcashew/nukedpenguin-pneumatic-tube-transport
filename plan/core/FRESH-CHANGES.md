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


### Revision: Dynamic Gate State Sync, Head-Bound Dot Trailing, and Trail Flicker Suppression
**Date:** 2026-09-16 08:32 EDT
**Context:** Projector corridors encountering dynamic obstacles like vanilla gates required decoupled state-transition monitoring to allow beams to grow through opened gates and truncate when gates close shut. Additionally, resumed flights starting mid-segment exhibited visual jumps due to unanchored dot offsets, fallback dot inflation in viewport leaf attachments, and a 1-frame trail flicker caused by full-segment detachment upon clearing static hazard rings. This session integrated an autonomous reticle gate registry, anchored in-flight dots strictly to physical head coordinates, and isolated endpoint indicator recycling from preserved segment trail dots.
**Key Changes:**
1. **Autonomous Reticle Gate Registry (`scripts/flow/flow-kinetic.lua`, `scripts/flow/flow-engine.lua`):** Added `storage.reticle_gates[reticle_id][gate_unit]` to monitor dynamic gate obstacles along active corridors independently of parent projector entities, resuming forward probing on gate open and invoking `truncate_reticle` on gate close.
2. **Physical Head-Bound Dot Progression (`scripts/capsules/capsule-renderer.lua`):** Replaced independent tick-based progress estimation with direct clamping against physical interpolated head coordinates (`math.floor(head_dist - d_start)`), permanently preventing dots from jumping ahead of the advancing reticle.
3. **Canonical Segment Origin Dot Anchoring (`scripts/capsules/capsule-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Anchored dot coordinate placement strictly to canonical segment origins (`reticle.start_pos + dir * d_start`), eliminating offset double-addition on mid-segment resumed flights.
4. **Static Trail Fallback Hardening (`scripts/utils/viewport-bvh.lua`):** Gated full-segment dot fallbacks in `attach_static_render` behind explicit `leaf.has_trail == true` checks, preventing active in-flight leaves from prematurely spawning full-length trails.
5. **Selective Endpoint Pruning & Flicker Suppression (`scripts/utils/viewport-bvh.lua`):** Removed full-segment dot detachment when clearing `leaf.static_render_spec`, preserving valid upstream dots across obstacle waking and recycling only endpoint hazard indicators.


### Revision: Discrete Character Tile Evacuation and Downstream Beam Tracking
**Date:** 2026-09-16 08:48 EDT
**Context:** While characters obstructed beams reliably on entry, moving out of the beam or walking downstream failed to notify or clear the truncated reticles because the tile evacuation loop omitted reticle waking hooks. This session wired the reticle obstacle clearance and upstream/downstream adjustment directly into the existing discrete grid-tile evacuation pipeline in `step_character_colliders`.
**Key Changes:**
1. **Discrete Tile Evacuation Hook (`scripts/flow/flow-kinetic.lua`):** Flagged `evacuated_any` during discrete tile departures in `step_character_colliders` to gate reticle evaluation strictly to grid-tile boundary transitions without sub-pixel polling.
2. **On-Axis Directional Motion Resolution (`scripts/flow/flow-kinetic.lua`):** Evaluated character position changes against registered reticles upon tile evacuation: waking and regrowing beams when the player steps off-axis or walks downstream, and immediately applying `truncate_reticle` when the player steps upstream closer to the emitter.
3. **Character Disconnect & Death Lifecycle Clearing (`scripts/flow/flow-kinetic.lua`):** Connected the dead/disconnected character cleanup pass in `step_character_colliders` to `handle_reticle_obstacle_cleared`, ensuring abandoned beams resume forward probing automatically.


### Revision: Mid-Corridor Beam Severing and Autonomous Downstream Wake Reeling
**Date:** 2026-09-16 09:36 EDT
**Context:** Truncating an active or decaying projector corridor previously wiped all downstream segments instantly, causing harsh visual popping and leaving the truncated end feeling abrupt. This session implemented the core corridor severing pipeline for Projector Refactor Task 2, preserving the downstream beam as an autonomous retreating wake that reels away smoothly from the cut point.
**Key Changes:**
1. **Autonomous Downstream Slice Generation (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` to calculate downstream remaining distance (`old_total_dist - obst_dist`) and instantiate a new autonomous reticle ID (`down_id`) carrying over the original trail dots, total distance, and static endpoint indicator.
2. **Pre-Calibrated Wake Reeling (`scripts/flow/flow-kinetic.lua`):** Initialized the downstream slice with `status = "retreating"` and a back-calculated `retreat_tick` matching the obstacle distance, allowing observer viewport culling to hide upstream dots while preserving downstream dots.
3. **Discrete Anti-Reticle Flight Launch (`scripts/flow/flow-kinetic.lua`):** Scheduled an `anti_reticle` flight starting squarely at the collision boundary (`collision_pos`) to hop through downstream 16-tile segments, progressively reeling in dots and recycling BVH leaves upon reaching the old endpoint.
4. **Trailing Wake Boundary Guard (`scripts/flow/flow-kinetic.lua`):** Added `is_behind_wake` filtering to `handle_obstacle_changed`, preventing obstacles built behind an already-retreating wake from triggering redundant or out-of-order truncations.


### Revision: Obstacle Exit-Boundary Scanning and Solid Footprint Wake Suppression
**Date:** 2026-09-16 09:49 EDT
**Context:** When placing long structures (such as elevated rail ramps) or contiguous rows of obstacles across an active beam, the downstream wake previously retained dots rendered directly on top of the solid obstacle footprint, with the anti-reticle awkwardly traversing through the building chassis. This session implemented an obstacle exit-boundary scanner to identify the far collision face, immediately wiping all dots within the physical footprint and launching the retreating anti-reticle cleanly from the open-air exit boundary.
**Key Changes:**
1. **Contiguous Obstacle Exit Scanner (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.find_obstacle_chain_exit` to compute the far exit boundary (`exit_dist`) along the beam axis, iteratively extending through contiguous or overlapping obstacles (supporting single large entities like rail ramps, multi-building blueprints, and defensive walls).
2. **Solid Footprint Wake Suppression (`scripts/flow/flow-kinetic.lua`):** Calibrated the downstream reticle's `retreat_tick` directly to `game.tick - math.floor(exit_dist * tpt)`, preventing trail dots within the solid obstacle body ($d \le \text{exit\_dist}$) from ever spawning into observer viewports.
3. **Eclipsed Segment Culling (`scripts/flow/flow-kinetic.lua`):** Filtered out BVH leaf segments that lie entirely within the obstacle footprint ($s_{\text{end}} \le \text{exit\_dist}$), inserting only surviving open-air segments into `motion_tree` and `traj_tree`.
4. **Exit-Face Anti-Reticle Spawning (`scripts/flow/flow-kinetic.lua`):** Repositioned the downstream `anti_reticle` flight origin directly to the obstacle's exit boundary (`sp + dir * exit_dist`), cleanly reeling in only the surviving open-air wake toward the original terminal endpoint.


### Revision: Severed Reticle Head Preservation, Cadence Sync, and Chain Bounds
**Date:** 2026-09-16 10:19 EDT
**Context:** Placing multi-tile structures across an active beam previously created fragmented slices, stripped the front reticle head leaving headless tails, and caused trail dots to freeze before popping away in one frame due to a time-per-tile constant mismatch during slow-mo testing. This session stabilized the corridor severing pipeline by preserving the reticle head on severed wakes, synchronizing time-to-tile speeds across renderers, and resolving contiguous obstacle chains in a single spatial pass.
**Key Changes:**
1. **Reticle Head & Formed Tail Preservation (`scripts/flow/flow-kinetic.lua`):** Tracked `head_render_spec` across reticle lifecycles and attached the visual head indicator to the downstream slice's terminal leaf, ensuring severed wakes retain their full projectile identity with a visible head and trailing dots.
2. **Slow-Mo Cadence Synchronization (`scripts/flow/flow-kinetic.lua`):** Anchored `tpt` directly to `trajectory_bvh.TICKS_PER_TILE` across wake creation and horizon calculation, eliminating the 10x timing mismatch with `capsule-renderer.lua` and restoring smooth tick-by-tick progressive dot reeling.
3. **Contiguous Obstacle Chain Bounds (`scripts/flow/flow-kinetic.lua`):** Added `flow_kinetic.get_obstacle_chain_bounds` to compute the full entry and exit boundaries (`entry_dist`, `exit_dist`) across adjacent blocking entities, clamping the live beam at the near face while clearing matter footprints in one pass.
4. **Decaying Wake Child & Hazard Suppression (`scripts/flow/flow-kinetic.lua`):** Enforced that decaying wakes clamp at obstacles without active machine hazard rings and never spawn child reticles, preventing visual ring stacking when placing lines of entities.


### Revision: Severed Reticle Flight Path Adoption and Incremental Wake Reeling
**Date:** 2026-09-16 12:14 EDT
**Context:** Severing an active beam mid-corridor previously froze the forward head in mid-air due to premature flight destruction, while trailing wakes popped away in sudden 16-tile chunks because the per-tick dot-clearing loop was only checking item.render_objects instead of static leaf item.objects. This session enabled severed downstream slices to adopt active head flights and restored progressive tick-by-tick dot recycling across all wake types.
**Key Changes:**
1. **Progressive Wake Dot Recycling (`scripts/capsules/capsule-renderer.lua`):** Added `item.objects` fallback to `item.render_objects` in `dispatch_player_renders`, allowing the incremental wake-reeling loop to recycle dots from static BVH leaves tick-by-tick and eliminating 16-tile visual chunk pops.
2. **Concurrent Wake Reeling Gating (`scripts/capsules/capsule-renderer.lua`):** Gated wake dot clearance and suppression behind `reticle.retreat_tick` instead of requiring `status == "retreating"`, enabling tandem wake reeling behind advancing severed heads.
3. **Autonomous Severed Flight Adoption (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` to detect when a severed beam's head is still in flight (`head_was_severed`), re-homing the active `cur_flight` onto the downstream orphan (`down_id`) so the head continues traveling forward to full reach without freezing in mid-air.
4. **Stationary Severed State Retention (`scripts/flow/flow-kinetic.lua`):** Ensured beams that were already stopped at maximum reach or obstacles remain stationary when sliced, preserving static endpoints and launching tail-only anti-reticle reeling.


### Revision: Zero-Tick Obstacle Queuing, Adjacency Bridging, and Universal Reticle Head Retention
**Date:** 2026-09-16 12:42 EDT
**Context:** When placing a contiguous row of obstacles (such as drag-building defensive walls), beams were generating multiple short-lived 1-tile reticle fragments because adjacent Factorio collision boxes have a 0.4-tile gap that failed to merge under the previous 0.05-tile threshold, while an earlier duplicate-blocking guard was preventing downstream orphaned reticle creation once a beam reached maximum reach. Furthermore, previous severing logic was stripping endpoint indicators from retreating wakes under the assumption of "headless" reticles. This session introduced a zero-tick frame-slice obstruction queue, broadened obstacle adjacency merging, guaranteed downstream reticle severance at any range, and enforced that every reticle retains a visible head across its entire lifecycle.
**Key Changes:**
1. **Universal Reticle Head Retention (`scripts/flow/flow-kinetic.lua`):** Permanently purged headless wake concepts across truncation and wake-reeling routines; removed the retreating wake early-return and head-stripping assignments (`leaf.static_pos = nil`, `leaf.static_render_spec = nil`), ensuring both upstream collision faces and downstream severed endpoints retain valid `head_render_spec` structures and visual indicators.
2. **Orphaned Downstream Severing at Max Reach (`scripts/flow/flow-kinetic.lua`):** Removed the `existing_down_id` blocking check in `truncate_reticle`, ensuring obstacles placed across stationary or max-range beams reliably detach the downstream portion into an autonomous orphaned reticle.
3. **Contiguous Grid Adjacency Bridging (`scripts/flow/flow-kinetic.lua`):** Expanded the entity boundary merge tolerance from 0.05 tiles to 0.75 tiles in `get_obstacle_chain_bounds` and `find_obstacle_chain_exit`, allowing adjacent 1x1 structures on the tile grid to bridge physical collision box gaps and fuse into a single contiguous matter footprint.
4. **Zero-Tick Frame-Slice Obstruction Queue (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.queue_reticle_obstacle` and `flow_kinetic.flush_pending_reticle_obstacles` to buffer all obstruction events occurring within the same tick; hooked flush passes into step cycles so multi-entity placements resolve in a single pass with zero tick latency and zero short-lived intermediate slices.
5. **Decoupled Wake-Reeling Visibility Threshold (`scripts/utils/viewport-bvh.lua`):** Gated static trail dot suppression in `attach_static_render` directly behind `reticle.retreat_tick` rather than requiring `status == "retreating"`, allowing severed in-flight heads to render uninhibited while trailing wakes reel in.


### Revision: Deferred Receiver Docking and Impact-Gated Cyan Reticle Head
**Date:** 2026-09-16 14:41 EDT
**Context:** Prospective reticle collision scans were turning advancing probe heads cyan while still in mid-air traveling toward opposing projectors. Parent projectors also required an accurate link to their receiving counterpart without premature association before beam arrival. This session decoupled prospective collision detection from visual reticle state, preserved standard coral head styling throughout transit, and gated cyan head transitions and parent receiver linkage strictly upon physical arrival at the receiver collision face.
**Key Changes:**
1. **Deferred Pending Receiver Tracking (`scripts/flow/flow-kinetic.lua`):** Introduced `pending_receiver` on reticle state across `on_muzzle_want_emission` and `update_reticle_horizon`, capturing prospective opposing projectors without pre-committing `reticle.hit_receiver` or linking receiver units prematurely.
2. **In-Flight Head Styling Preservation (`scripts/flow/flow-kinetic.lua`, `scripts/capsules/capsule-ballistics.lua`):** Enforced `DEFAULT_HEAD_SPEC` (coral) across all active in-flight probe steps, ensuring the flying head never changes color while traversing open air.
3. **Impact-Gated Receiver Docking (`scripts/capsules/capsule-ballistics.lua`):** Updated `handle_projector_scope_arrival` terminal arrival to verify `pending_receiver`, committing `reticle.hit_receiver`, assigning `leaf.static_render_spec = RECEIVER_HEAD_SPEC` (cyan), and storing `receiver_unit` on the parent projector's scope record.
4. **Immediate Truncation Receiver Alignment (`scripts/flow/flow-kinetic.lua`):** Updated `truncate_reticle` to immediately commit `RECEIVER_HEAD_SPEC` and link `receiver_unit` when an obstacle placed directly at or behind the head is an active receiver projector.
5. **Obstacle Clearance & Regrowth Reset (`scripts/flow/flow-kinetic.lua`):** Cleared `pending_receiver`, `hit_receiver`, and `storage.projector_scope[proj_unit].receiver_unit` across `resume_reticle_probing` and `handle_reticle_obstacle_cleared`, smoothly restoring default styling when obstructions clear.


### Revision: Multi-Segment Reticle Receiver Docking and Boundary Impact Resolution
**Date:** 2026-09-16 15:02 EDT
**Context:** Projector reticles were failing to turn cyan when impacting another projector across multi-segment corridors (>16 tiles), when regrowing after an intermediate obstacle cleared, or when an opposing projector's collision box landed directly on a 16-tile segment boundary face. This session hardened flight record metadata preservation across chained hops, added receiver detection to corridor regrowth probing, and relaxed boundary face distance thresholds in leaf collision scans.
**Key Changes:**
1. **Chained Flight Metadata Preservation (`scripts/capsules/capsule-ballistics.lua`):** Forwarded `projector_unit`, `reticle_id`, and `q_level` into timed motion flight records in `launch_timed_flight`, added fallback resolution to `reticle.projector_unit` in `handle_projector_scope_arrival`, and preserved ownership metadata across chained hops to prevent multi-segment beams from evaluating `flight.projector_unit ~= nil` as false.
2. **Corridor Regrowth Receiver Docking (`scripts/flow/flow-kinetic.lua`):** Added opposing projector receiver detection and `reticle.pending_receiver` assignment to `resume_reticle_probing` when scanning forward after clearing an obstacle.
3. **Boundary Face Collision Scanning (`scripts/flow/flow-kinetic.lua`):** Initialized `closest_dist = step_dist + 0.05` and updated on-axis distance comparisons to `d <= closest_dist` in `scan_leaf_rect`, ensuring opposing projector collision boxes touching the exact boundary face register without being clipped by strict `<` inequalities.
4. **In-Flight Horizon Metadata Sync (`scripts/flow/flow-kinetic.lua`):** Synchronized `projector_unit` and `reticle_id` directly onto active flight records during `update_reticle_horizon`.
5. **Terminal Arrival Receiver Fallback (`scripts/capsules/capsule-ballistics.lua`):** Updated terminal arrival evaluation in `handle_projector_scope_arrival` to verify both `pending_receiver` and pre-committed `hit_receiver` before finalizing cyan reticle head styling and scope receiver linkage.


### Revision: Narrow-Phase Chassis Bounding-Box Edge Docking and Orphaned Reticle Demotion
**Date:** 2026-09-16 17:08 EDT
**Context:** Beams reaching maximum distance were failing to dock with opposing projectors resting directly on the boundary due to Factorio's 0.30-tile physical collision box inset relative to the tile grid footprint, while broadphase query margins and pneumatic socket offset math introduced artificial spatial distortion. Additionally, orphaned beams and severed downstream wakes could retain or display cyan receiver reticle indicators. This session decoupled kinetic reception from pneumatic socket concepts, replaced broadphase query blankets with a focused 0.5-tile narrow-phase native bounding-box hit test across terminal arrivals and entity placement, and enforced universal coral demotion for orphaned reticles.
**Key Changes:**
1. **Orphaned & Decaying Reticle Color Demotion (`scripts/flow/flow-kinetic.lua`):** Reset `head_render_spec = DEFAULT_HEAD_SPEC` (coral), wiped `hit_receiver` and `pending_receiver`, and updated terminal static leaves in `motion_tree` via `viewport_bvh.on_leaf_static_changed` across `orphan_reticle`, ensuring decaying or retreating wakes never display false cyan receiver styling.
2. **Severed Downstream Reticle Head Sanitization (`scripts/flow/flow-kinetic.lua`):** Initialized severed downstream reticles (`down_id`) and trailing terminal leaves with `DEFAULT_HEAD_SPEC`, preventing wakes severed mid-beam from inheriting receiver head specs from cut points.
3. **Receiver Deconstruction Reference Scrubbing (`scripts/flow/flow-kinetic.lua`):** Extended `flow_kinetic.clear_receiver_references` to iterate over active projector reticles, resetting docked reticles and static terminal leaves back to coral and unlinking `storage.projector_scope` receiver units upon receiver mining or destruction.
4. **Terminal Reach Narrow-Phase Chassis Docking (`scripts/capsules/capsule-ballistics.lua`):** Implemented a native terminal arrival edge check in `handle_projector_scope_arrival` testing physical `cand.bounding_box` within a 0.5-tile narrow-phase tolerance, spanning Factorio's 0.30-tile collision box inset to connect opposing projector chassis faces at maximum reach without pneumatic socket offsets.
5. **Projector Placement In-Place Docking Hook (`scripts/flow/flow-kinetic.lua`):** Implemented `flow_kinetic.dock_incoming_reticles_at_projector` using a 0.5-tile tolerance around native bounding boxes, querying intersecting motion BVH leaves on placement or rotation to immediately dock stationary beam endpoints as cyan receivers on the exact tick of construction.


### Revision: Stationary Reticle Corridor Migration and Inbound Receiver Capacity Accounting
**Date:** 2026-09-16 17:35 EDT
**Context:** Implemented Projector Refactor Task 5, migrating projector capsule launch pathfinding off legacy kinetic flow node scans and the old surface BVH. Launches now configure autonomous timed flight records directly from verified stationary reticle geometry and enforce aggregated receiver capacity checks before committing launches.
**Key Changes:**
1. **Stationary Reticle Launch Pathfinding (`scripts/capsules/capsule-ballistics.lua`):** Replaced legacy 500-tile `flow_nodes` endpoint scans with direct reads from `storage.projector_scope` and `storage.projector_reticles`, ensuring capsules launch strictly after a stable corridor reaches stationary status.
2. **Aggregated Receiver Capacity Gatekeeping (`scripts/capsules/capsule-ballistics.lua`):** Implemented `capsule_ballistics.count_receiver_capsules` to sum physically docked capsules occupying the receiver chassis alongside all active inbound capsules targeting that receiver, blocking new launches once `MAX_ENDPOINT_CAPSULES` is reached.
3. **Autonomous In-Flight Corridor Retention (`scripts/capsules/capsule-ballistics.lua`):** Initialized `capsule.beam_flight` with self-contained trajectory geometry, terminal arrival coordinates, and target receiver references, allowing in-flight capsules to continue to their destination unimpeded even if the firing projector rotates or orphans its reticle wake.
4. **Dual-Key Flight Corridor Resolution (`scripts/capsules/capsule-ballistics.lua`):** Enhanced `handle_motion_obstacle_changed` to resolve active flight records by either `reticle_id` or parent `projector_unit`, ensuring dynamic obstacle placement and removal adjust in-flight projectile arrival horizons seamlessly.


### Revision: Communal Flight Corridor BVH Leaf Preservation and Crash Latch
**Date:** 2026-09-16 18:18 EDT  
**Context:** Capsules on crashing flight paths were intermittently disappearing right before impact due to dropped terminal BVH leaves in communal flight corridors and premature render exit tick clipping. Additionally, initial capsule impacts produced an engine-level hitch caused by redundant audio sound path resolution during impact processing. This session restored per-segment corridor leaf generation, latched terminal viewport rendering to actual arrival ticks, and streamlined crash detonation calls.  
**Key Changes:**
1. **Per-Segment Corridor Leaf Ensuring (`scripts/utils/timed-motion.lua`):** Replaced the all-or-nothing corridor check in `timed_motion.ensure_corridor` with per-segment validation, ensuring missing or truncated leaves along communal flight corridors generate dynamically up to `terminal_pos` without dropping terminal impact segments.
2. **Non-Destructive Flight Horizon Shifting (`scripts/utils/timed-motion.lua`):** Removed full-corridor teardown (`timed_motion.remove_corridor`) in `timed_motion.shift_horizon`, ensuring dynamic obstacle cutoffs preserve shared communal trajectory leaves for concurrent or queued flights.
3. **Terminal Crash Render Latching (`scripts/capsules/capsule-renderer.lua`):** Latched `t_exit` on terminal trajectory segments ($d_{\text{end}} \ge d_{\text{total}} - 0.05$) to `flight.arrival_tick`, ensuring projectiles remain rendered in player viewports until the exact tick of impact.
4. **Crash Detonation Cleanup (`scripts/capsules/capsule-ballistics.lua`):** Removed redundant `surface.play_sound` for `"utility/explosion"` inside `apply_crash_damage`, relying on native explosion entity prototypes and eliminating the first-impact audio engine lookup spike.