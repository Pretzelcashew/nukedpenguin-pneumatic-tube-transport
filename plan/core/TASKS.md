# TASKS.md - Kinetic Ballistics, BVH Modularization & Dual Broadphase

This roadmap defines the semantic architecture, domain boundaries, and copy-paste prompt contracts for upcoming implementation sessions. Prompts are semantic rather than prescriptive, focusing on contracts, invariants, and outcomes rather than rigid code lines.

---

## Session 1: Impact Physics Alignment & Audio/Visual De-bloating

### Semantic Intent & Boundaries
1. **Impact Coordinate Alignment:** In `scripts/capsules/capsule-ballistics.lua`, kinetic crash damage currently evaluates at the terminal node ($d - 1$) rather than the physical obstacle tile ($d$), leaving characters and entities outside point-damage range. Damage checks must resolve against the actual obstacle entity and footprint at tile $d$ with an appropriate impact radius.
2. **Purge Unsolicited Audio/Visual Flair:** Remove unprompted AI-injected effects (`spark-explosion` entity allocations and `utility/wire_connect` sound triggers) from `play_dispatch_effects`, `play_flight_effects`, and `play_catchment_effects`. Decouple core ballistic motion from cosmetic overhead; eliminate in-flight ripple/wake loops or gate them strictly behind active capsule debug overlays.

### Invariants & Success Criteria
- Standing in an active beam path reliably applies impact damage upon capsule arrival.
- Standard hop motion, launch, and catchment are quiet and 0-overhead (no C++ entity allocations or sound triggers on routine logistics).
- Backward momentum preservation and receiver catchment remain 100% intact.

### 📋 Prompt for Gemini:
```text
Target Task: Fix kinetic impact collision damage alignment and purge unprompted cosmetic effects.

1. Impact Alignment: In scripts/capsules/capsule-ballistics.lua, ensure kinetic crash damage evaluates against the obstruction tile and entity footprint rather than the visual beam node before it (d - 1). Apply damage to intersecting colliders within a reliable impact radius at the obstacle location.
2. Flair Removal: Strip out the unprompted play_dispatch_effects, play_flight_effects, and play_catchment_effects (specifically the "spark-explosion" entity creation and "utility/wire_connect" sound playback), keeping ballistic dispatch and arrival lean, quiet, and 0-overhead. Ensure any in-flight ripple/wake rendering is either eliminated or strictly gated behind the active capsule debug overlay setting.
```

---

## Session 2: Decouple BVH into a Pure, Generic Data Structure

### Semantic Intent & Boundaries
1. **Pure Spatial Primitive:** Extract a generic, reusable Dynamic AABB Tree (`scripts/utils/bvh-tree.lua`) that operates strictly on abstract bounding boxes (`[min_x, min_y, max_x, max_y]`), integer/string object IDs, and generic userdata payloads.
2. **Domain Isolation:** Purge all pneumatic-specific knowledge (string keys like `:rem:%d`, time-slice formulas $1.2\text{ ticks/tile}$, and direct reads from `storage.projector_flights`) from the core tree algorithm.
3. **Adapter Layer:** Keep pneumatic corridor segmentation, remainder namespacing, and render queries in a dedicated adapter (`scripts/utils/trajectory-bvh.lua`) that wraps the generic tree, preserving 100% backwards-compatible APIs for existing callers.

### Invariants & Success Criteria
- The core tree module has zero imports or dependencies on mod-specific flow/capsule state.
- Standard tree operations (`insert`, `remove`, `update`, `query_aabb`, `query_tree`) are clean, self-contained, and reusable for any spatial domain.
- All existing trajectory rendering and flight queries continue functioning without regression.

### 📋 Prompt for Gemini:
```text
Target Task: Modularize the spatial BVH into a generic, reusable Dynamic AABB Tree.

Refactor scripts/utils/trajectory-bvh.lua to separate the core spatial indexing engine from mod-specific kinetic beam logic.
1. Core Tree Primitive: Extract a pure, reusable AABB tree data structure that operates strictly on bounding boxes [min_x, min_y, max_x, max_y], object IDs, and arbitrary userdata. It must have zero dependencies on pneumatic domain state, string keys, or flight duration formulas.
2. Adapter Layer: Keep pneumatic-specific beam corridor mapping, remainder keys, and time-slice flight tests in a dedicated adapter or wrapper so existing kinetic rendering callers retain complete backwards compatibility.
```

---

## Session 3: Scalable Dual-BVH Viewport Broadphase (Fat AABBs & Zoom Hysteresis)

### Semantic Intent & Boundaries
1. **Observer Eligibility Gating:** Only insert players into the surface's Viewport BVH if they actively have capsule overlay rendering enabled (`storage.debug[player_index].capsules`). Players without active overlays are completely omitted from spatial tracking.
2. **Unified Surface Viewport BVH:** Unconditionally maintain a surface-partitioned Viewport BVH indexing all eligible observers via their expanded "Fat AABB". When kinetic beam segments are created, modified, or cleared, query this Viewport BVH ($O(\log P)$) to alert strictly the overlapping viewports. A single code path guarantees deterministic behavior across single-player and massive multiplayer servers alike.
3. **$O(1)$ Fat AABB Containment:** On the player camera side, replace per-tick 60 Hz spatial tree queries with an $O(1)$ rectangle containment check (`fat_aabb:contains(screen_rect)`). While the camera stays within the Fat AABB, bypass all spatial tree traversals and render visible flights directly from the cached candidate set.
4. **Zoom Hysteresis:** Implement deadband hysteresis thresholds for camera zoom. Panning or zooming out past the Fat AABB triggers an immediate expansion and recenter. Zooming in only shrinks and updates the tree bounds when the screen rect contracts below an inner threshold (e.g. $<50\%$ of Fat AABB), eliminating camera zoom chatter.

### Invariants & Success Criteria
- Zero spatial tracking overhead for players who have capsule rendering turned off.
- Zero-cost spatial broadphase on ticks where eligible players stay within their Fat AABB.
- One unified, robust Viewport BVH code path with zero dual-mode switching complexity.
- Smooth 60 FPS viewport rendering with zero flicker during rapid camera panning or zooming.

### 📋 Prompt for Gemini:
```text
Target Task: Implement unified Dual-BVH viewport culling using Fat AABBs, zoom hysteresis, and observer eligibility gating.

In scripts/capsules/capsule-renderer.lua and spatial querying utilities, implement a dual-broadphase architecture using the generic BVH tree:

1. Surface Viewport BVH & Observer Gating:
   - Only register viewports in the spatial tree for players who actively have capsule rendering enabled (storage.debug[player_index].capsules).
   - Unconditionally maintain a surface-partitioned Viewport BVH indexing all active observers wrapped in an expanded boundary margin ("Fat AABB").
   - When a kinetic capsule segment or flight trajectory is created, modified, or removed, query this Viewport BVH (O(log P)) to notify and update strictly the overlapping player viewports.

2. Viewport Fat AABB & Zoom Hysteresis:
   - Avoid updating the Viewport BVH every frame. On each tick, perform an O(1) containment test checking if the player's live screen rect is fully inside their cached Fat AABB.
   - Only update the Viewport BVH node and re-query the Capsule BVH when the camera breaches the Fat AABB boundary.
   - Implement zoom deadband hysteresis: expand and recenter the Fat AABB on boundary breach when zooming out, but only contract/recenter when the screen shrinks below a significant inner threshold (e.g. <50% of Fat AABB) to prevent zoom chatter.
```