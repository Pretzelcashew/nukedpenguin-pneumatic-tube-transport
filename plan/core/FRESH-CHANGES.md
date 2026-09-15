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