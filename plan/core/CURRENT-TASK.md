# CURRENT-TASK.md - Dynamic Pairwise Node Collapse & BVH-Culled Capsule Motion
**Mod Name:** `nukedpenguin-pneumatic-tube-transport` (Factorio 2.1)  
**Domain:** Graph-Level Edge Contraction, Delta-P Pressure Gradient Evaluator, Timed Arrival Unification, and Spatial Viewport Frustum Culling  
**Status:** In Progress (Phase 1 Ready)

---

## 1. Universal Broadphase & Core Architectural Primitives

### 1.1. Single Universal Broadphase Tree (`storage.motion_bvh`)
Do **NOT** create a separate tree for pneumatic entities (e.g. `storage.flow_bvh`). All entities—Electromagnetic Projector beams, static machines, and dynamic tube corridors—share the exact same spatial broadphase tree per surface: `storage.motion_bvh[surface_index]`.

**Why this is mandatory:**
1. **Zero New Camera Loops:** Piggybacks directly on `viewport_bvh.sync_player_visibility`, which already runs concentric hysteresis culling and camera tracking across `storage.motion_bvh`.
2. **Single $O(\log N)$ Query:** Camera movement triggers exactly one broadphase query, returning visible machines, tube runs, and in-flight capsules in a single pass.
3. **Mostly Static Broadphase:** Machines and tubes do not move every tick. Tree mutations occur only on build/mine or during the gradual merge queue.

### 1.2. Complete Namespace Isolation in `player_visible_set`
Visible items in `viewport-bvh.lua` are keyed by:
$$\text{key} = \text{tostring}(\text{leaf.owner\_id}) \mathbin{:} \text{tostring}(\text{leaf.seg\_key})$$

Three disjoint namespaces exist simultaneously in `storage.motion_bvh` with **zero collision risk**:
- **Projector Reticles:** `owner_id = reticle_id`, `seg_key = "dx,dy:seg"` $\implies$ e.g. `"5:0,-1:1"`
- **Static Machine Leaves:** `owner_id = entity.unit_number`, `seg_key = "machine"` $\implies$ e.g. `"102:machine"`
- **Dynamic Tube Corridors:** `owner_id = run_id` (synthetic integer), `seg_key = seg_idx` $\implies$ e.g. `"1000001:1"`

### 1.3. Subprotocol Static Render Dispatch (`motion-protocols.lua`)
When `viewport_bvh` detects a leaf entering a player's screen frustum, it delegates rendering via `motion_protocols.get_subprotocol(item.owner_id, "static_render")`:
- **Reticle Beams:** Dispatches to `reticle_static` (leases kinetic laser trail dots and hazard rings).
- **Tube Corridors:** Dispatches to `flow_dot_static` (leases flow circles matching pressure levels from `render_pool`).
- **Static Machines:** Dispatches to `machine_static` (renders Diverter port filter icons in `diverter-renderer.lua` and machine overlays).

### 1.4. Two Leaf Categories & The 1.0-Tile Width Guarantee
A tube corridor must **never** balloon into a 2- or 3-tile wide bounding box just because a Diverter (2x2), Pump (1x2), or Projector (3x3) sits at the start:
1. **Static Machine Leaves (100% Static, Zero Merge Math):**
   - Created on build, destroyed on mine. They **never** fold, merge, or divide.
   - Sits squarely on the machine's physical footprint ($2\times 2$ for diverter, $1\times 2$ for pump, $3\times 3$ for projector).
   - Sole purpose: culling native machine Alt-Mode overlays (filter badges, status lights).
2. **Dynamic Corridor Leaves (Tubes Only, Strictly 1.0 Tile Thin):**
   - Starts at the machine's boundary port and runs along the tube line.
   - Vertical runs: width strictly **$1.0$ tile** ($X \in [x - 0.5, x + 0.5]$).
   - Horizontal runs: height strictly **$1.0$ tile** ($Y \in [y - 0.5, y + 0.5]$).
   - Hugs the centerline with zero width bleed from attached machines.

### 1.5. Axis-Scoped (Port-Pair) Merging
- Merging is **port-pair scoped**, not entity-scoped.
- Multi-axis entities like `crossflow-junction` (North/South and East/West) participate in **two independent 1-tile-thin perpendicular corridors** crossing like an overpass. They never merge into a square blob.
- Bends (90° turns) have perpendicular port vectors ($dir_A \cdot dir_B = 0$). `flow_common.is_colinear_straight_internal` rejects them immediately. Bends never fold.

### 1.6. The Physical Law of Pneumatics: $\Delta P \ne 0$
$$\text{Absolute Pressure } (P) \ne \text{Fluid Flow}$$
$$\text{Pressure Gradient } (\Delta P = P_{\text{in}} - P_{\text{out}}) = \text{Fluid Flow \& Motion Vector}$$

- A dead-end pipe capped by a wall pressurizes to $P = 10$, but $\Delta P = 10 - 10 = 0$. Air is stagnant. **Pairing is strictly forbidden.**
- Opposing pumps meeting at $+8$ on both sides have $\Delta P = 0$. Air stagnates; pairing across the seam is impossible.
- Vacuum pull ($-6 \to -8$, $\Delta P = +2$) defines an active vector toward the intake. Pairs fold toward vacuum.
- Unpressurized lines have $\Delta P = 0$. They stay at baseline $1\times 1$ dormant nodes with zero CPU overhead.

---

## 2. The Modular 4-Task Roadmap

---

### TASK 1: Static Machine Leaves, Baseline Tube Leaves & Frustum-Culled Flow Dots
**Role for AI:** Universal Broadphase Registration & Rendering Cleanup  
**Dependency:** None (Clean start)

#### Scope & Target Files
- `scripts/flow/flow-common.lua`
- `scripts/flow/flow-engine.lua`
- `scripts/flow/flow-renderer.lua`
- `scripts/utils/viewport-bvh.lua`
- `scripts/utils/motion-protocols.lua`
- `scripts/utils/render-pool.lua`

#### Objectives
1. **Clean Legacy Blockers:** 
   - Remove `USE_PRESSURE_CORRIDORS` completely from `flow-common.lua` and `flow-engine.lua`.
   - Remove `is_colinear_straight_internal` from blocking internal flow in `compute_port_flow_level` and `flow_engine.step`.
   - Keep open-port suppression (`if not has_external then can_transmit_internally = false end`).
2. **Register Universal Leaves into `storage.motion_bvh`:**
   - **Static Machine Leaves:** In `connect_entity`, machines (`diverter` 2x2, `pump` 1x2, `counter` 1x2, `hub`, `projector`) register static AABBs.
     - Identity: `leaf.owner_id = entity.unit_number`, `leaf.seg_key = "machine"`, `leaf.static_render_spec = "machine_static"`.
     - Remove on mine in `disconnect_entity` via `viewport_bvh.on_segment_removed(s_idx, entity.unit_number, "machine")`.
   - **Baseline Tube Leaves:** Each tube registers its own $1\times 2$ (or $2\times 1$) leaf.
     - Identity: `leaf.owner_id = entity.unit_number`, `leaf.seg_key = "base"`, `leaf.static_render_spec = "flow_dot_static"`.
     - Remove on mine via `viewport_bvh.on_segment_removed(s_idx, entity.unit_number, "base")`.
3. **Modular Static Render Protocols (`motion-protocols.lua`):**
   - Register `motion_protocols.register_static_render("flow_dot_static", handler)` to lease flow circles/text from `render_pool` (`channel = "flow"` or `"default"`). Do NOT poach `"reticle"`.
   - Register `motion_protocols.register_static_render("machine_static", handler)` to lease Diverter filter icons (`diverter-renderer.lua`) and machine badges.
   - When a leaf enters the viewport, lease render objects. When scrolling away, `render_pool.recycle_many` reclaims them.
   - Retire the old map-wide persistent `LuaRenderObject` creation in `flow-renderer.lua`.

#### Strict Negative Constraints
- DO NOT touch capsule movement or `capsule-runner.lua`.
- DO NOT implement pairwise merging or edge contraction yet.
- All hops remain standard 1-tile connections.
- DO NOT create a secondary BVH tree. All leaves go into `storage.motion_bvh`.

#### Verification (Commit Gate)
- Straight tubes transmit pressure normally (no dying at tile 2).
- Alt-Mode flow dots and Diverter filter icons appear on screen when viewing them; vanish when scrolling away.
- Save file contains 0 persistent flow render objects off-screen.

---

### TASK 2: Unified Motion Substrate (1-Tile Hops via Timed Arrival Heap)
**Role for AI:** Motion Engine Migration  
**Dependency:** Task 1 complete & verified

#### Scope & Target Files
- `scripts/capsules/capsule-runner.lua`
- `scripts/capsules/capsule-transit.lua`
- `scripts/capsules/capsule-renderer.lua`
- `scripts/utils/motion-protocols.lua`

#### Objectives
1. **Schedule 1-Tile Hops on the Arrival Heap:**
   - When a capsule at Port A is ready to advance to Port B:
   - Schedule a 1-tile flight on the Binary Arrival Heap (`timed_motion.schedule_flight`):
     `id = capsule_id, owner_id = capsule_id, kind = "tube_hop", start_pos = pos_a, terminal_pos = pos_b, start_tick = tick, arrival_tick = tick + 6, duration = 6`.
2. **Modular Arrival Handler (`motion-protocols.lua`):**
   - Register the arrival callback via `motion_protocols.register_arrival("tube_hop", handler)`:
   - When popped at `arrival_tick`: perform port transfer, update occupancy, and evaluate next hop (or park).
   - Do NOT modify the core heap stepper in `timed-motion.lua`!
3. **Spatiotemporal 60 FPS Gliding & Frustum Culling:**
   - In `capsule-renderer.lua`: calculate `timed_motion.get_interpolated_position(flight, tick)` for smooth sub-tile gliding.
   - If the capsule's position is outside all players' viewports in `storage.motion_bvh`, skip rendering entirely.

#### Strict Negative Constraints
- DO NOT change hop distance: all hops remain strictly 1 tile (duration = 6 ticks).
- DO NOT implement node merging.
- DO NOT modify Capsule Counter territory logic.

#### Verification (Commit Gate)
- Capsules in tubes glide continuously at 60 FPS across their 1-tile hops (no tile-snapping).
- Off-screen capsules cost 0 rendering calls.
- Hubs, diverters, and parking sleep/wake normally.

---

### TASK 3: The Delta-P Gradient Evaluator & Pairwise Merge/Unmerge Queue
**Role for AI:** Topology Contraction Layer  
**Dependency:** Tasks 1 & 2 complete & verified

#### Scope & Target Files
- `scripts/flow/flow-common.lua`
- `scripts/flow/flow-collapse.lua` (New module)
- `scripts/flow/flow-engine.lua`

#### Objectives
1. **Delta-P Gradient Evaluator (`flow-common.lua`):**
   - Implement `flow_common.get_colinear_gradient(pkey_in, pkey_out)`.
   - Strictly evaluate $\Delta P = P_{\text{in}} - P_{\text{out}}$.
   - Enforce: If $\Delta P == 0$ (dead-ends, opposing pumps, unpressurized), return `0, nil`. Pairing is strictly forbidden without an active gradient.
   - If $\Delta P \ne 0$, return magnitude and directional vector (`forward` vs `backward`/vacuum).
2. **Pairwise Merge Queue (`flow-collapse.lua`):**
   - Initialize `storage.collapse_queue` with baseline `BATCH_SIZE = 50`.
   - Implement atomic pairwise fold ($merge(A, B) \to AB$): merges adjacent colinear straight tubes along the $\Delta P$ vector, accumulating edge length.
   - Corridor leaf width is strictly **$1.0$ tile** (never inflated by attached machines).
   - Assign synthetic `run_id` to merged runs (`leaf.owner_id = run_id`, `leaf.seg_key = seg_idx`).
3. **Pairwise Division (Unmerging):**
   - When $\Delta P \to 0$, enqueue for pairwise unmerging ($AB \to A + B$) at 50 ops/tick.
   - State serialization: New merges on a segment wait until any active division on that segment completes.
4. **Physical Midsegment Removal Exception:**
   - In `destroy_node`: if a mined entity is inside a collapsed edge, sever the physical connection immediately in $O(1)$, and enqueue remaining halves into the division queue.
5. **Console Diagnostic:**
   - Add `/check-collapsed-edges` displaying active collapsed edges, `run_id`s, and lengths.

#### Strict Negative Constraints
- DO NOT touch capsule flight duration yet (capsules still take 1-tile hops).
- Focus strictly on the graph topology zipping and unzipping correctly in the background.

#### Verification (Commit Gate)
- Place straight tubes. Run `/check-collapsed-edges` to see edges zip ($1 \to 2 \to 4 \dots$) over 2–3 ticks.
- Capped dead-ends and opposing pumps stay unmerged ($\Delta P = 0$).
- Mine a middle tube; verify the line divides cleanly in the background without lag spikes.

---

### TASK 4: Continuous A-to-B Flights Across Merged Runs + 16-Tile Frustum Slicing
**Role for AI:** Motion Unification & Leaf Slicing  
**Dependency:** Tasks 1, 2, & 3 complete & verified

#### Scope & Target Files
- `scripts/flow/flow-collapse.lua`
- `scripts/capsules/capsule-runner.lua`
- `scripts/utils/viewport-bvh.lua`

#### Objectives
1. **Continuous A-to-B Flights:**
   - When a capsule enters a collapsed edge at boundary A with destination B, schedule **one flight** on the arrival heap for the full distance ($L$ tiles, duration = $L \times \text{tpt}$).
   - Zero intermediate stops at 16-tile boundaries.
2. **16-Tile BVH Leaf Slicing:**
   - Slices any collapsed edge longer than 16 tiles into $\le 16$-tile spatial leaves in `storage.motion_bvh` for frustum culling.
   - Render flow dots in 16-tile chunks when observed.
3. **Headway Spacing & Dynamic Pressure Changes:**
   - Enforce a minimum entry headway timer at boundary A to prevent capsule stacking.
   - If source pressure drops: if gradient persists, edge stays merged and updates speed; if reach shortens, tail unmerges while head contracts.

#### Verification (Commit Gate)
- Capsules take single unbroken, continuous high-speed flights across long straight tube lines.
- Alt-Mode dot trails render cleanly in 16-tile chunks.
- Pasting mega-blueprints or mass deconstructing causes zero frame drops.