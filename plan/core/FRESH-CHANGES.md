#### 0.3.23

### Revision: Pressure Corridor Colinear Gating & Open-Port Suppression
**Date:** 2026-09-19 10:06 EDT
**Context:** Lays the architectural foundation for spatial BVH pressure corridors by decoupling hop-by-hop pressure propagation from straight-line pneumatic runs. Suppresses internal pressure bleeding onto unconnected open-air ports and cuts off straight transmission across unbranched members so the flow engine reaches immediate quiescence.
**Key Changes:**
1. **Colinear Straight Evaluator Primitive (`scripts/flow/flow-common.lua`):** Implemented and exported `flow_common.is_colinear_straight_internal` with polymorphic argument handling, evaluating opposing port vectors, axial alignment, and checking if unused side ports reduce multi-port junctions to unbranched straight corridors.
2. **Event-Driven Topology Wakeups (`scripts/flow/flow-common.lua`):** Updated `destroy_node` to enqueue all unit ports of adjacent entities when an edge is severed under `USE_PRESSURE_CORRIDORS`, enabling surviving junctions to detect when branch removals return them to colinear straight status without periodic polling.
3. **Open-Port & Colinear Flow Gating (`scripts/flow/flow-engine.lua`):** Gated internal pressure transmission in `compute_port_flow_level` and `flow_engine.step` to require external connections on target ports and cut off transmission through colinear straight internal pairs, preventing pressure bleed onto empty dirt tiles.
4. **Connection Awakening & Engine Facade (`scripts/flow/flow-engine.lua`):** Added mutual unit port enqueuing in `connect_entity` upon edge formation under `USE_PRESSURE_CORRIDORS`, and exposed facade delegation `flow_engine.is_colinear_straight_internal = flow_common.is_colinear_straight_internal` for backwards-compatible cross-system access.


### Revision: Timed Pressure Corridor Wavefront Engine & Anti-Pressure Decay
**Date:** 2026-09-19 13:53 EDT
**Context:** Implements the foundation for expanding capsule flight to straight pneumatic runs via pressure corridors. Bridges the quiescent colinear flow gating with a timed 16-tile BVH spatial substrate, polarity-aware pneumatic dot rendering, and an event-driven anti-pressure retreat wave.
**Key Changes:**
1. **Pneumatic Corridor Protocols (`scripts/flow/flow-engine.lua`):** Registered `"pressure_corridor"` and `"pressure_static"` render subprotocols via `motion_protocols`. Renders polarity-aware pneumatic trail dots (cyan for positive pressure, orange for vacuum) on `entity-info-icon-above` without rendering an intrusive head ring.
2. **Colinear Graph Reach Scanner (`scripts/flow/flow-engine.lua`):** Implemented `scan_pneumatic_colinear_reach` to traverse contiguous straight pneumatic tube entities via `storage.flow_connections`, linking the originating pressure source (`source_unit`, `source_pkey`), detecting terminal branches for classic hops handoff, and anchoring 16-tile segments into `motion_tree` and `trajectory_bvh`.
3. **Gradual Wavefront & Source Decay Monitor (`scripts/flow/flow-engine.lua`):** Added `step_pressure_corridors` executed on every tick with viewport observer synchronization. Animates gradual forward dot expansion ($tpt = 2$), detects when the feeding pressure source drops to 0 or is disconnected, and drives the anti-pressure peeling wave (`status = "receding"`) before cleanly unpinning BVH leaves.
4. **Lifecycle & Destruction Decoupling (`scripts/flow/flow-engine.lua`):** Updated `disconnect_entity` to initiate gradual anti-pressure decay when the pressure source entity (pump) or any tube along the line is mined, avoiding abrupt single-tick purges while ensuring zero orphan corridors.


### Revision: Pressure Source Ingress Gating & Anti-Reseed Suppression
**Date:** 2026-09-19 14:22 EDT
**Context:** Resolves an issue where removing a pressure source (pump) immediately triggered a new forward pressure seed corridor from the severed open-air tube port while the previous corridor was receding. Enforces strict incoming connection and emitter gating on corridor entry ports so severed edges immediately decay without re-evaluating as new sources.
**Key Changes:**
1. **Corridor Ingress Gating (`scripts/flow/flow-engine.lua`):** Gated straight colinear corridor transmission in `flow_engine.step` to require an active incoming external connection or internal emitter (`has_in`), routing severed open-air ports directly to `on_pressure_stop_transmit`.
2. **Source Validation & Self-Emitter Resolution (`scripts/flow/flow-engine.lua`):** Hardened `flow_engine.on_pressure_begin_transmit` to reject orphan entry ports lacking external connections or active emitters, correctly resolving `source_unit` and `source_pkey` across both self-emitting machines and connected neighbors.
3. **Orphan Corridor Source Liveness (`scripts/flow/flow-engine.lua`):** Updated `step_pressure_corridors` to mark corridors lacking a valid `source_pkey` as inactive (`src_alive = false`), ensuring disconnected or unlinked corridors begin anti-pressure recession immediately.
4. **Deconstruction Scope Coverage (`scripts/flow/flow-engine.lua`):** Added `corr.unit_number == unit_number` checks to `disconnect_entity` to guarantee that corridors anchored directly to a mined or destroyed unit begin receding without delay.


### Revision: Pressure Corridor Terminal Handoff & Proportional Reach Scaling
**Date:** 2026-09-19 15:16 EDT
**Context:** Connects pressure corridor endpoints to downstream non-colinear networks with continuous stable pressure handoffs while scaling reach dynamically to input pressure instead of an arbitrary 64-tile ceiling. Resolves phantom reverse corridor seeding and peeling wave inversion by isolating tip emissions from intermediate tube flow level records.
**Key Changes:**
1. **Dynamic Reach Scaling & Terminal Port Resolution (`scripts/flow/flow-engine.lua`):** Scaled `max_reach` in `scan_pneumatic_colinear_reach` to `math.abs(flow_level) * 2` tiles, bounding traversal strictly to input pressure, and returned `curr_out` as `last_out_pkey` to identify the corridor's egress interface.
2. **Dedicated Tip Emission Substrate (`scripts/flow/flow-engine.lua`):** Established `storage.corridor_tip_flows` to provide persistent remaining pressure (`src_flow - hops`) at `last_out_pkey` without populating `storage.flow_levels` on straight tube nodes, preventing straight members from re-evaluating as reverse emitters and preserving forward anti-pressure wake peeling.
3. **Downstream Wavefront Handoff (`scripts/flow/flow-engine.lua`):** Updated `compute_port_flow_level` to read `storage.corridor_tip_flows[n_key]` across external neighbor queries, enabling junctions, diverters, corners, and hubs to seamlessly adopt and propagate remaining corridor pressure.
4. **Ingress Scope Gating & Teardown Cleanup (`scripts/flow/flow-engine.lua`):** Scoped flow evaluation in `flow_engine.step` directly from `storage.flow_levels[pkey]` to eliminate out-of-scope nil values in `on_pressure_begin_transmit`, and added automated tip flow purging and neighbor wakeups to `unseed_pressure_corridor`.


### Revision: Pressure Corridor Visual Parity, Observer Pipeline & Equalization Decay
**Date:** 2026-09-19 16:23 EDT
**Context:** Deprecates optical reticle artifacts (prominent markers, shrinking radii, spatial tail peeling) from pneumatic corridors in favor of true flow dots visual parity and monotonic volume depressurization. Decouples macro simulation state from presentation to guarantee sub-microsecond unobserved execution while driving 60 FPS in-place updates for active observers via the Viewport BVH pipeline.
**Key Changes:**
1. **Flow Dots Visual Specification (`scripts/capsules/capsule-renderer.lua`):** Replaced reticle trail styling with 0.15-radius filled circles and centered integer level text (`y - 0.25`), matching color ratios directly from `level / MAX_FLOW` without prominent dots or radius distortion.
2. **Monotonic Equalization Decay (`scripts/capsules/capsule-renderer.lua`):** Implemented continuous spatial interpolation between collapsing head pressure and the sustained tip ($P_{\text{head}}(\tau) \cdot (1 - f) + P_{\text{tip}}(\tau) \cdot f$), eliminating mathematical sawtooth oscillations and rapid flickering across trailing nodes.
3. **Observer-Driven Render Dispatch (`scripts/capsules/capsule-renderer.lua`):** Hooked active and receding corridors directly into `render_governor` and `dispatch_player_renders` visible sets, enabling in-place `.color` and `.text` mutations exclusively for viewing players while keeping unobserved corridors dormant.
4. **Decoupled Macro Simulation & Tip Flow (`scripts/flow/flow-engine.lua`):** Purged per-tick render notifications and tile iterations from `step_pressure_corridors`, stepping macro decay duration and downstream tip flow (`storage.corridor_tip_flows`) in single-operation arithmetic before unseeding.
5. **Reach Normalization & Boundary Precision (`scripts/flow/flow-engine.lua`):** Normalized corridor reach to $\text{source\_pressure} - 1$ and applied half-up integer rounding to port delta coordinates, preventing floating-point truncation and ensuring corridors terminate strictly at dot `1` across all quality tiers without phantom `0`-pressure boundary boxes.


### Revision: Pressure Corridor Counter Stepping & Overlay Z-Order Alignment
**Date:** 2026-09-19 17:51 EDT
**Context:** Resolves inverted pressure corridor indicator counts by preserving input pressure flow levels across corridor lifecycles and downstream tip handoffs rather than forcing initial flow to physical corridor distance. Enforces proper visual Z-ordering so numeric labels consistently render on top of filled circle dots without prototype property assertion crashes.
**Key Changes:**
1. **Flow Magnitude Preservation & Reach Scaling (`scripts/flow/flow-engine.lua`):** Retained incoming signed `flow_level` and magnitude `flow_mag = math.abs(flow_level)` in `on_pressure_begin_transmit` instead of overwriting flow fields with `total_dist`, and simplified `scan_pneumatic_colinear_reach` to bound traversal reach directly to input pressure magnitude.
2. **Downstream Tip Pressure Handoff (`scripts/flow/flow-engine.lua`):** Updated terminal branch handoffs in `step_pressure_corridors` to compute `tip_mag = math.max(0, init_mag - (corr.total_dist - 1))`, feeding the exact remaining pressure to downstream junctions, corners, and hubs via `storage.corridor_tip_flows`.
3. **Monotonic Counter Progression (`scripts/capsules/capsule-renderer.lua`):** Preserved `corr.current_reach` during corridor rendering, stepping rendered numbers down progressively from the current pressure level at distance 1 rather than counting up from 1 at the corridor tip.
4. **Native Z-Order Reordering (`scripts/capsules/capsule-renderer.lua`, `scripts/flow/flow-renderer.lua`):** Replaced unsupported `render_layer` assignments on geometric shapes and text with Factorio's native `bring_to_front()` method across pressure corridor, junction flow, and counter range overlays, guaranteeing numbers are drawn strictly in front of circles regardless of object recycling or creation order.


### Revision: Incremental Pressure Corridor BVH Leaf Registration
**Date:** 2026-09-19 17:59 EDT
**Context:** Aligns pressure corridor spatial tree lifecycles with the gradual expansion model used by optical projector reticles. Deprecates instant pre-allocation of downstream 16-tile segments in favor of wavefront-driven, progressive BVH leaf insertion as pressure advances.
**Key Changes:**
1. **Segment-1 Initial Registration (`scripts/flow/flow-engine.lua`):** Scoped initial corridor registration in `on_pressure_begin_transmit` strictly to segment 1 ($s = 1$, $0 \le d \le \min(16, \text{total\_dist})$) and initialized `registered_segs = 1`, preventing downstream 16-tile segments from spawning before the pressure wavefront reaches them.
2. **Progressive Spatial Tree Expansion (`scripts/flow/flow-engine.lua`):** Activated dynamic leaf insertion in `step_pressure_corridors`, registering segments 2+ into `motion_tree`, `traj_tree`, and observer viewports only when `cur_seg_target > corr.registered_segs`.
3. **Teardown Scope Clamping (`scripts/flow/flow-engine.lua`):** Updated `unseed_pressure_corridor` to bound segment removal loops to `corr.registered_segs or corr.max_seg_idx or 1`, avoiding queries for downstream segments that were never allocated.


### Revision: Pressure Corridor Tip Handoff, Dead-End Gating & Echo Suppression
**Date:** 2026-09-19 18:38 EDT
**Context:** Resolves downstream pressure handoffs at non-colinear interfaces (corners, junctions, diverters, hubs), activates pressure corridors on 1-tile open dead-ends, eliminates phantom reverse corridor seeding and residual "1" pressure traps, and prevents invalid render layer property writes on pooled geometric primitives.
**Key Changes:**
1. **Shared Interface Max-Flow Resolution (`scripts/flow/flow-renderer.lua`):** Updated `flow_renderer.get_dominant_port_at_pos` to inspect `storage.corridor_tip_flows`, allowing shared boundary port coordinates (`pos_key`) between corridor tips and downstream non-colinear ports to accurately resolve and render dominant pressure levels without number discordance.
2. **Event-Driven Terminal Branch Binding (`scripts/flow/flow-engine.lua`):** Bound downstream terminal branch discovery and teardown strictly to game events in `connect_entity` and `disconnect_entity`, maintaining 0-tick idle sleep for active corridors without per-tick continuous topology polling.
3. **Open-Air Dead-End Transmission (`scripts/flow/flow-engine.lua`):** Removed the restrictive `has_external` check on straight colinear corridor transmission in `flow_engine.step`, allowing 1-tile straight tube runs with incoming pressure to launch corridors to their open ends without unpressurized dead-ends.
4. **Echo Corridor & Feedback Loop Suppression (`scripts/flow/flow-engine.lua`):** Gated `compute_port_flow_level` to return 0 for corridor exit tips (`storage.corridor_tip_flows[pkey]`) and non-ingress corridor entities (`corr.corridor_entities[unit_number]`), eliminating reverse corridor seeding that previously produced inverted `1, 2... 9` progressions and residual "1" pressure freezes upon pump voiding.
5. **Render Pool Primitive Property Safety (`scripts/utils/render-pool.lua`):** Removed `.render_layer` property assignments from recycled `lease_circle`, `lease_text`, and `lease_line` branches in `render-pool.lua`, preventing Factorio 2.0 engine `__newindex` crashes on non-sprite render userdata during pump rotation and capsule inspections.


### Revision: Smart Mid-Segment Pressure Corridor Severing & Boundary Clipping
**Date:** 2026-09-19 19:12 EDT
**Context:** Eliminates whole-line pressure collapses and phantom flow dots when intermediate pneumatic tubes are mined or destroyed. Replaces monolithic corridor teardowns with intelligent mid-segment severing that truncates the surviving upstream run at the break face while detaching downstream members into an autonomous receding wake.
**Key Changes:**
1. **Mid-Corridor Splitting Substrate (`scripts/flow/flow-engine.lua`):** Implemented `flow_engine.split_pressure_corridor`, intercepting deconstruction events in `disconnect_entity` to partition active corridor members into surviving upstream and downstream sets rather than collapsing the entire line to zero.
2. **Upstream Physical Boundary Clamping (`scripts/flow/flow-engine.lua`):** Truncated the upstream corridor strictly to the physical exit port coordinates of the last surviving upstream entity (`exact_up_dist`), updating registered BVH leaves and eliminating the "one too many" trailing dot on the vacated dirt tile.
3. **Downstream Breakoff Colinear Scanning (`scripts/flow/flow-engine.lua`):** Wired `scan_pneumatic_colinear_reach` into the generation of the downstream detached corridor, scanning forward directly from the entrance flange of the first surviving downstream tube (`down_in_pkey`, `down_out_pkey`) to completely eliminate backwards BVH leaf overhang and phantom dots at the breakoff point.
4. **Autonomous Decaying Wake & Downstream Tip Handoff (`scripts/flow/flow-engine.lua`):** Initialized detached downstream corridors with `status = "receding"` and scaled initial flow, preserving continuous pressure tip handoffs (`storage.corridor_tip_flows`) to downstream junctions while the orphaned wake equalizes smoothly to zero.


### Revision: Dynamic Pressure Corridor Elongation & Persistent Tip Flow Delivery
**Date:** 2026-09-19 21:05 EDT
**Context:** Resolves the "one-shunt" issue where placing tubes onto an active corridor only appended a single tube or failed to recognize downstream lines placed across empty gaps. Bridges the event-driven corridor lifecycle with dynamic tip waking and multi-pass connection wiring, ensuring contiguous colinear pneumatic runs seamlessly elongate and deliver persistent pressure to downstream networks placed after corridor creation.
**Key Changes:**
1. **Dynamic Colinear Corridor Tip Waking (`scripts/flow/flow-engine.lua`):** Implemented `flow_engine.wake_corridor_tip`, scanning directly from `corr.last_out_pkey` along the corridor axis to traverse contiguous colinear-compatible entities (tubes, inline unbranched junctions, defensive walls, inline counters) in a single continuous scan rather than halting at the first boundary.
2. **Multi-Pass Connection Pipeline (`scripts/flow/flow-engine.lua`):** Restructured `flow_engine.connect_entity` into decoupled registration and connection phases, linking all opposing port pairs in `storage.flow_connections` before corridor evaluation so newly placed bridging tubes have both entrance and exit flanges wired prior to elongation scans.
3. **Persistent Open-Air Tip Flow Delivery (`scripts/flow/flow-engine.lua`):** Decoupled `storage.corridor_tip_flows[corr.last_out_pkey]` initialization in `step_pressure_corridors` from `terminal_branch_pkey`, guaranteeing open-air dead ends maintain persistent remaining flow and eliminating tip flow wipes on downstream branch deconstruction in `disconnect_entity`.
4. **Spatial BVH Leaf Expansion & Wavefront Resumption (`scripts/flow/flow-engine.lua`):** Updated `motion_tree`, `trajectory_bvh`, and `viewport_bvh` segment leaf bounds to dynamically expand to the new reach, resetting `status = "growing"` with synchronized `start_tick` so the visual pressure wavefront advances smoothly through all newly attached tubes.


### Revision: Near-Source Pressure Corridor Severing & Interface Unseeding
**Date:** 2026-09-20 09:14 EDT
**Context:** Resolves an issue where removing the very first pneumatic tube touching a pressure source (such as a pump) triggered monolithic line-wide decay rather than severing the corridor. Brings near-source deconstruction into full functional parity with mid-segment cutting.
**Key Changes:**
1. **Corridor Member Deconstruction Prioritization (`scripts/flow/flow-engine.lua`):** Restructured deconstruction triage in `disconnect_entity` to test `touches_entity` before `touches_source`, preventing `corr.unit_number == unit_number` from falsely treating the first tube of a corridor as the pressure source entity itself.
2. **Downstream Detached Wake Preservation (`scripts/flow/flow-engine.lua`):** Removed the premature `exact_up_dist < 1` return guard in `split_pressure_corridor`, allowing downstream severed wake generation (`down_cid`) and spatial tree registration to proceed when zero upstream tubes survive between the source and the break face.
3. **Clean Near-Source Interface Unseeding (`scripts/flow/flow-engine.lua`):** Added post-sever unseeding for corridors with `exact_up_dist < 1` via `flow_engine.unseed_pressure_corridor(cid, true)`, clearing obsolete upstream tip references to safeguard `down_corr`'s tip flow while immediately purging vacated near-source BVH leaves and dirt-tile trail dots.


### Revision: Dynamic Gate State Transitions & Mid-Section Corridor Severing
**Date:** 2026-09-20 10:44 EDT
**Context:** Bridges vanilla defensive gate state transitions (open and close events) with the pressure corridor engine. Treats opening gates along active pressure runs as dynamic mid-section severing events that cleanly truncate upstream pressure at the incoming gate face and purge orphaned tip flows, while restoring continuity and waking the corridor tip when gates close without hardcoded gate height assumptions.
**Key Changes:**
1. **Dynamic Gate State Evaluator (`scripts/flow/flow-engine.lua`):** Implemented `is_gate_open` inspecting native Factorio `gate.is_opened()` and `gate.is_opening()` states, allowing closed gates to conduct straight pressure runs while cleanly identifying opening/open gates as non-transmitting boundaries.
2. **Colinear Reach Boundary Gating (`scripts/flow/flow-engine.lua`):** Updated `scan_pneumatic_colinear_reach` and `on_pressure_begin_transmit` to halt straight corridor progression at open gate boundaries, preventing pressure from penetrating through open gates into disconnected downstream networks.
3. **Variable-Span Mid-Section Severing (`scripts/flow/flow-engine.lua`):** Extended `split_pressure_corridor` to exclude open gate entities (`not is_gate_open(u)`) from surviving downstream candidates, ensuring multi-tile gate wall openings cleanly truncate upstream runs at the gate entrance and only attach downstream receding wakes to actual surviving tubes beyond the gate.
4. **Near-Source & Severed Tip Flow Cleanup (`scripts/flow/flow-engine.lua`):** Hardened `split_pressure_corridor` to unconditionally purge `orig_last_out` from `storage.corridor_tip_flows` on near-source (`exact_up_dist < 1`) and truncated corridor splits, permanently eliminating stranded phantom tip numbers on vacated gate faces.
5. **Continuous Breach Monitoring & Continuity Waking (`scripts/flow/flow-engine.lua`):** Integrated open-gate detection into `step_pressure_corridors` to sever breached corridors on the exact tick a gate opens, and added tip connection scanning to trigger `wake_corridor_tip` when a gate closes, smoothly re-pressurizing downstream networks.


### Revision: Gate Closure Neighbor Awakening, Discovery Deadlock Clearance & Quiescent Corridor Seeding
**Date:** 2026-09-20 11:32 EDT
**Context:** Resolves an issue where closing an inline gate left adjacent feeding entities and junctions dormant without emitting new pressure corridor seeds. Eliminates a circular deadlock between lazy entity discovery and internal port flow gating, brings gate state transitions into graph queue parity with entity connection/destruction events, and ensures downstream corridors seeded from tip handoffs survive and advance smoothly.
**Key Changes:**
1. **Gate Closure Neighbor Awakening (`scripts/flow/flow-gate-interop.lua`):** Updated `step_gates` on gate closure to enqueue both port keys (`flow_common.enqueue_port`) and owning unit ports (`flow_common.enqueue_unit_ports`) of adjacent neighbor entities, bringing gate state transitions into full symmetry with entity placement and deconstruction events.
2. **Proactive Defensive Entity Discovery on Placement (`scripts/flow/flow-engine.lua`):** Integrated `discover_adjacent_standard_entity` into `flow_engine.connect_entity` for all registered ports on the build tick, eliminating the circular deadlock where dormant ports waited for flow before discovering gates while gates waited for connections before transmitting flow.
3. **Corridor Tip Flow Source Liveness (`scripts/flow/flow-engine.lua`):** Updated `step_pressure_corridors` source liveness evaluation to inspect `storage.corridor_tip_flows` alongside `storage.flow_levels`, allowing downstream straight runs launched from boundary handoffs to survive and advance rather than being killed on tick 1.
4. **Quiescent Source Re-evaluation & Corridor Seeding (`scripts/flow/flow-engine.lua`):** Added re-evaluation for pressurized quiescent sources in `flow_engine.step`, checking unseeded colinear straight exit paths when awakened and invoking `on_pressure_begin_transmit` to immediately push flow seeds into newly unblocked connections.
5. **Terminal Branch Downstream Wakeup (`scripts/flow/flow-engine.lua`):** Extended terminal branch arrival and tip waking routines in `step_pressure_corridors` and `wake_corridor_tip` to enqueue all unit ports of reached entities (`flow_common.enqueue_unit_ports`), ensuring downstream junctions immediately compute internal flow and wake classic flow overlays.


### Revision: Render Pool Property Sanitization, Release Symmetry & Reticle Fallback Elimination
**Date:** 2026-09-20 11:53 EDT
**Context:** Resolves an issue where recycled circle primitives leased from the render pool retained optical projector reticle state (holmium magenta tint, 0.08 radius) and rendered as rogue trail dots along pneumatic tubes. Eliminates an invalid static render fallback in the viewport BVH, enforces strict property re-initialization on lease and neutral resets on recycle, and guarantees complete segment cleanup and handle recycling upon corridor unseeding without modifying the observation governor or simulation flow.
**Key Changes:**
1. **Pooled Primitive Property Sanitization (`scripts/utils/render-pool.lua`):** Unconditionally initialized all geometric and styling properties (`color`, `radius`, `filled`, `width`, `only_in_alt_mode`, `players`) in `lease_circle`, and added neutral property resets on recycling (`recycle`) to prevent cross-contamination between projectile reticles and pneumatic corridors.
2. **Symmetric Release API (`scripts/utils/render-pool.lua`):** Exposed `render_pool.release`, `render_pool.release_circle`, `render_pool.release_sprite`, `render_pool.release_text`, `render_pool.release_line`, and `render_pool.release_many` aliases to guarantee clean lease-release symmetry across callers.
3. **Corridor Protocol Resolution (`scripts/utils/motion-protocols.lua`):** Updated `get_protocol` to explicitly recognize `"corridor:"` string prefixes, table instances containing `flow_level` or `in_pkey`, and records in `storage.pressure_corridors`, preventing pneumatic runs from falling back to default protocols across save/load cycles.
4. **Reticle Static Fallback Elimination (`scripts/utils/viewport-bvh.lua`):** Removed the legacy `or motion_protocols.static_renders["reticle_static"]` fallback in `attach_static_render` so unmapped or non-static protocols never execute optical beam routines, and updated detachment and removal hooks to recycle both `item.render_objects` and `item.objects`.
5. **In-Place Attribute Enforcement & Depressurization Recycling (`scripts/capsules/capsule-renderer.lua`):** Explicitly enforced circle radius (0.15), Alt-Mode visibility, and text offsets during in-place pressure corridor updates, recycled all objects via `pairs(objects)` upon full decay (`tau >= 1.0`), and pruned out-of-bounds keys beyond active segment lengths.
6. **Corridor Teardown Segment Bounds Clamping (`scripts/flow/flow-engine.lua`):** Clamped segment teardown loops in `unseed_pressure_corridor` and `split_pressure_corridor` to `math.max(corr.registered_segs, corr.max_seg_idx)` and dispatched blanket removals (`seg_key = nil`) to ensure zero orphaned handles remain in player visible sets.