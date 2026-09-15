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