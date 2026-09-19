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