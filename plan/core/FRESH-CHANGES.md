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


#### 0.3.23

### Revision: Universal Broadphase Motion Leaves, Port-Bounded Frustum Culling & Graph Wakeup Restoration
**Date:** 2026-09-21 19:25 EDT
**Context:** Implements Task 1 of the Dynamic Node Collapse architecture by migrating pneumatic entities into the unified spatial broadphase tree (`storage.motion_bvh`). Eradicates experimental colinear flow gating and open-port suppression that previously stalled straight tube transmission and caused tip entities to drop flow dots. Replaces monolithic map-wide persistent `LuaRenderObject` creation with on-demand frustum-culled leasing from an isolated `"flow"` render pool channel. Computes leaf bounding boxes dynamically from physical port boundaries rather than hardcoded 1x1 assumptions, guaranteeing strict 1.0-tile thickness along corridor centerlines. Hooks broadphase tree inspection directly into `/toggle-bvh`.

**Key Changes:**
1. **Graph Flow & Wakeup Restoration (`scripts/flow/flow-common.lua`, `scripts/flow/flow-engine.lua`):** Stripped `USE_PRESSURE_CORRIDORS` and eliminated `is_colinear_straight_internal` and `has_external` gating from `compute_port_flow_level` and `flow_engine.step`. Tip entities now receive internal pressure and render flow dots normally. Expanded `existing_has_flow` in `connect_entity` to scan all ports on adjacent entities, guaranteeing placing new tubes reliably wakes the network.
2. **Port-Bounded Universal BVH Leaves (`scripts/flow/flow-engine.lua`):** Implemented `flow_engine.register_entity_motion_leaf` calculating spatial AABB bounds directly from `port_defs.get_ports(entity)` (`min_px`, `max_px`, `min_py`, `max_py`) with an enforced 1.0-tile thickness on flat axes. Machine footprints register as `owner_id:machine` (`machine_static`), and tube corridors register as `owner_id:base` (`flow_dot_static`) in `storage.motion_bvh[surface_index]`. Added automatic migration for pre-existing save entities.
3. **Channel-Segregated Render Leasing (`scripts/utils/render-pool.lua`, `scripts/utils/motion-protocols.lua`):** Added the `"flow"` channel to `render-pool.lua` (retention floor 64) and `motion_protocols.CHANNELS.FLOW`. Completely isolates pneumatic flow dots and connection lines from projector reticle dots and capsule payloads.
4. **Modular Frustum-Culled Static Overlays (`scripts/flow/flow-renderer.lua`, `scripts/diverters/diverter-renderer.lua`, `scripts/utils/viewport-bvh.lua`):** Implemented `flow_dot_static` (leasing pressure dots, counter indicators, and inter-port lines) and `machine_static` (leasing Diverter filter icon grids, drop shadows, quality badges, and blacklist marks). Retired map-wide persistent render loops in `flow-renderer.lua` in favor of `notify_pos_changed` -> `viewport_bvh.on_leaf_static_changed`. Off-screen entities cost 0 persistent render handles.
5. **Universal Broadphase Debug Visualization (`scripts/utils/trajectory-bvh.lua`, `scripts/utils/viewport-bvh.lua`):** Extended `trajectory_bvh.draw_for_player` to inspect and render `storage.motion_bvh` with color-coded AABBs (cyan for tubes, amber for machines, green for reticle beams). Connected live overlay refreshes to `viewport_bvh.on_segment_registered` and `on_segment_removed`.


#### 0.3.23

### Revision: Terminal Dead-End Traversal, Colinear Junction Routing & Dynamic Unparking
**Date:** 2026-09-23 08:37 EDT
**Context:** Resolves multiple persistent capsule traversal bottlenecks at the ends of tube runs and multi-port junctions. Eliminates the legacy copout requiring internal hops to have valid external exits, which previously forced capsules to park at entry sockets instead of traversing to the end of terminal tubes. Prevents internal ping-ponging and allows capsules parked at dead ends to dynamically wake and route down newly connected branches when topology changes. Fixes colinear junction preference when no exits exist and ensures capsules completing a $1 \rightarrow 0$ pressure transition cleanly traverse drag-built zero-pressure segments.

**Key Changes:**
1. **Mutual Dead-End Hop Gating (`scripts/capsules/capsule-runner.lua`):** Updated `is_hop_valid` to allow internal hops into terminal ports lacking external connections while blocking mutual dead-end bouncing (`not target_has_ext and not from_has_ext`). Capsules parked at dead ends can now cleanly route into any internal port that acquires a valid external downstream exit.
2. **Entry Port Tracking & Backward Hop Suppression (`scripts/capsules/capsule-runner.lua`):** Added `capsule.entry_port_key` assigned on external entity transitions in `update_capsules` and `inject_from_hub`. Gated candidate selection in `select_next_target` to skip `cand_key == capsule.entry_port_key`, preventing capsules from reversing into their entry sockets unless pulled backward by negative vacuum pressure.
3. **Inter-Port Axial Colinear Alignment (`scripts/capsules/capsule-runner.lua`):** Replaced previous-node displacement vector dot-product checks (which collapsed to zero due to overlapping boundary coordinates) with direct axial alignment testing (`dx < 0.01` for vertical straight, `dy < 0.01` for horizontal straight) and `flow_engine.is_colinear_straight_internal`. Opposing colinear dead-end ports receive priority score `0.002` over side turn ports (`0.001`), eliminating random 90-degree turns into dead-end junction arms.
4. **Zero-Pressure & Drag-Build Traversal (`scripts/capsules/capsule-runner.lua`):** Restricted downstream lookahead acceptance to strictly positive pressure drops (`best_downstream > 0`), and allowed terminal entity advancement when `level_exit >= 0` and `from_port_key == entry_port_key`. Guarantees capsules entering zero-pressure segments via a $1 \rightarrow 0$ drop advance all the way across the tube, eliminating stalling caused by multi-segment drag-building.


#### 0.3.23

### Revision: Vacuum Reverse Evacuation Restoration
**Date:** 2026-09-23 08:43 EDT
**Context:** Restores the ability for negative vacuum pressure to evacuate capsules parked in dead-end tube runs and junction branches. The previous `is_entry_reverse` candidate filter unconditionally suppressed hops back to `entry_port_key`, inadvertently preventing vacuum pumps from pulling capsules backward out of dead-end branches despite valid positive pressure drops ($(-21) - (-22) = +1$).

**Key Changes:**
1. **Vacuum Candidate Filter Clearance (`scripts/capsules/capsule-runner.lua`):** Removed `is_entry_reverse` gating from candidate iteration in `select_next_target`. Negative vacuum pressure gradients can now pull capsules backward through their entry sockets, while forward dead-end bouncing remains fully prevented by `best_downstream > 0` and `is_from_entry`.


#### 0.3.23

### Revision: Lookahead Excision & Pure Local Gradient Evaluation
**Date:** 2026-09-23 08:59 EDT
**Context:** Excises recursive graph lookahead ladders and nested candidate query loops from the capsule motion coordinator. Previously, deciding an internal hop across a 1-tile entity invoked recursive calls up to 3 hops deep to pre-validate downstream exits, causing remote unpressurized segments to artificially stall capsules several tiles upstream. Replaces nested scans with pure local gradient checks and immediate external connection inspection.

**Key Changes:**
1. **Recursive Depth Ladder Purge (`scripts/capsules/capsule-runner.lua`):** Stripped the `depth` parameter and recursion limit (`depth > 3`) from `is_hop_valid`. Excised the downstream `get_candidate_hops(target_port_key, 3)` loop, restricting internal hop validation strictly to immediate local machine rules (mutual dead-end suppression, emitter direction checks, and entity permissions).
2. **Direct External Connection Inspection (`scripts/capsules/capsule-runner.lua`):** Replaced the secondary `get_candidate_hops(cand_key, 2)` scan in `select_next_target` with direct, zero-allocation iteration over `storage.flow_connections[cand_key]`. Downstream capacity is verified directly via `capsule_runner.has_capacity(cand_key, exit_key)` without recursive function calls.
3. **Consistent Multi-Segment Motion (`scripts/capsules/capsule-runner.lua`):** Eradicates drag-building stalls where unpressurized tube runs returned $0 - 0 = 0$ lookaheads that halted motion on upstream tiles. Capsules now advance reliably hop-by-hop based on local pressure differentials and colinear momentum.


### Revision: Remove Hardcoded Render Layer from Capsule Renderer and Pool
**Date:** 2026-09-23 12:45 (EDT)
**Context:** The rendering logic previously forced all capsule and flight indicators to use the `entity-info-icon-above` render layer. Removing this allows the objects to default to their proper or engine-standard layers without manual overrides.
**Key Changes:**
1. **Capsule Renderer (`scripts/capsules/capsule-renderer.lua`):** Removed `render_layer = "entity-info-icon-above"` from multiple circle, dot, and flight rendering functions.
2. **Render Pool (`scripts/utils/render-pool.lua`):** Removed the option assignment handling for `render_layer` in `render_pool.lease_circle`.


### Revision: BVH Leaf Domain Isolation, Reticle Lifecycle Decoupling & Endpoint Head Restoration
**Date:** 2026-09-23 14:30 EDT
**Context:** Resolves cross-subsystem collisions where projectile flight progression and wake peeling treated physical machines as laser beams, un-scoped corridor teardowns wiped entity leaves sharing numerical IDs, debug overlays leaked un-clearable render handles, and reticle head endpoint rings were dropped on arrival.
**Key Changes:**
1. **Leaf Archetype Disambiguation (`scripts/utils/timed-motion.lua`, `scripts/flow/flow-engine.lua`, `scripts/capsules/capsule-ballistics.lua`):** Explicitly tagged corridor leaves with `is_corridor = true`, `reticle_id`, and explicit `static_render_spec = "reticle_static"`, while tagging entity leaves with `is_entity = true, is_corridor = false` to eliminate ambiguous numeric `owner_id` collisions.
2. **Explicit Static Render Dispatch & Head Retention (`scripts/utils/viewport-bvh.lua`):** Routed corridor leaves directly to `reticle_static` in `attach_static_render` and entity leaves to their declared string spec, guaranteeing raw table head configs (`DEFAULT_HEAD_SPEC`, `RECEIVER_HEAD_SPEC`) are never dropped while completely removing unprincipled fallback guessing.
3. **Corridor Teardown Scoping (`scripts/utils/viewport-bvh.lua`):** Filtered prefix-based deletions in `on_segment_removed` strictly to corridor leaves, preventing expired reticle beams from wiping physical machine and tube leaves sharing the same numerical ID.
4. **Motion Loop & Wake Peeling Isolation (`scripts/capsules/capsule-renderer.lua`):** Hoisted `v_set` initialization in `dispatch_player_renders` and restricted wake peeling, progression window checks, and governor observation strictly to corridor leaves, protecting Diverter filter icons and flow dots from being recycled as laser trail dots.
5. **Corridor Lifecycle & Rotation Teardown (`scripts/utils/timed-motion.lua`, `scripts/flow/flow-engine.lua`):** Removed `storage.active_projectors` from the `is_pinned` guard in `remove_flight` so inactive corridors can unregister cleanly, and wired `flow_kinetic.handle_projector_rotated` on entity reorientation.
6. **Debug Render Reference Leak (`scripts/utils/trajectory-bvh.lua`):** Removed the redundant `storage.bvh_renders` table re-initialization in `draw_for_player` that previously orphaned `motion_bvh` debug boxes and made them impervious to `/clear-renders` and `/toggle-bvh`.


### Revision: Foreground Text Z-Ordering & Boundary Dot Deduplication
**Date:** 2026-09-23 14:48 EDT
**Context:** Resolves Z-ordering conflicts on Factorio's foreground overlay pass where recycled filled circles were drawn on top of pressure numbers, and eliminates duplicate circle and text leasing at touching port boundaries.
**Key Changes:**
1. **Text Draw Order Elevation (`scripts/utils/render-pool.lua`):** Added `obj.bring_to_front()` to `render_pool.lease_text` on both handle reuse and fresh instantiation, ensuring text is always reordered to the front of foreground circles and lines.
2. **Shared Boundary Port Deduplication (`scripts/flow/flow-renderer.lua`):** Gated pressure dot and counter dot leasing behind reference identity checks (`node == best_node` and `node == c_node`) in `render_flow_dot_static`, preventing adjacent touching entities (such as tubes and corner junctions) from stacking duplicate circles that occlude numbers.