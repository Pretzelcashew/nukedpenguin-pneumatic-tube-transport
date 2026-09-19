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