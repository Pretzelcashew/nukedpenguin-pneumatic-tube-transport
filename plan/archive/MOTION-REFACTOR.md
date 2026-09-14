# Spatial BVH Observer & Timed Arrival Architecture Roadmap
**Scope:** Reusable Generic BVH, Binary Heap & BVH Pool Deflation, Native LuaRenderObject Pooling, Viewport Spatial Culling, Per-Player Render Cadence, and Unified Timed Arrival Motion.

---

### Architectural Data Flow & Pipeline

```text
Foundations ──────────► Observer Spatial Culling ──────────► Per-Player Execution ──► Concrete Motion Domains
1. Generic BVH         3. Viewport BVH (Fat AABB)             5. Sliding-Scale Cadence    6. Timed Arrival Core
1.5 Dual Pool Decay    4. Entry/Exit Intersection Engine         Render Dispatcher       7. Kinetic Beam Virtualization
   (Heap & BVH)           (Populates Player Visible Sets)       (Iterates Visible Set)   8. Pressure Straight Corridors
2. Render Object Pool
```

---

### Phase Roadmap

#### Phase 1: Reusable Generic BVH & High-Water Node Recycling Pool
* **Core Objective:** Refactor `scripts/utils/trajectory-bvh.lua` from a singleton module into an instantiable, procedural tree engine to guarantee 100% Factorio `storage` serialization safety without metatables.
* **Key Architecture:**
  * **Procedural Data Schema:** `trajectory_bvh.new_tree()` returns a pure data table:
    ```lua
    {
        root = nil,
        size = 0,
        free_nodes = {},     -- High-water recycling free list
        free_count = 0,
        leaves_by_key = {}   -- O(1) leaf tracking
    }
    ```
  * **Explicit Tree Parameterization:** All module functions take `tree` as their first argument (`trajectory_bvh.insert(tree, leaf)`, `trajectory_bvh.remove(tree, leaf)`, `trajectory_bvh.query_box(tree, aabb, out_results)`). Storing pure data tables in `storage.viewport_bvh[surface_index]` and `storage.motion_bvh[surface_index]` prevents save/load deserialization crashes.
  * **High-Water Mark Pool:** Mirror the zero-allocation pooling pattern from `scripts/utils/binary-heap.lua`. On node detachment or leaf deletion, push tables into `tree.free_nodes` rather than dropping them to Lua garbage collection. Lease recycled nodes on insertion before allocating new tables.

---

#### Phase 1.5: Unified High-Water Pool Deflation, Amortized Trickle Decay & Savefile Compaction (BVH & Binary Heap)
* **Core Objective:** Prevent permanent memory retention ("RAM prison") and save-file serialization bloat across both high-water pooling structures—the **Spatial Trajectory BVH** (`free_nodes`) and the **Indexed Binary Heap** (`heap.nodes` sliding buffer)—after mass deconstruction spikes or cargo arrival waves, without triggering garbage collection pause spikes.
* **Key Architecture:**
  * **1. Spatial Trajectory BVH Pool Deflation (`trajectory-bvh.lua`):**
    * **Working-Set Proportional Gating:** In `recycle_node`, gate retained free nodes relative to the active working set:
      $$\text{max\_free} = \max(64, \text{tree.size} \times 2)$$
      Nodes recycled when `tree.free_count >= max_free` are dropped to Lua GC on the spot rather than retained indefinitely.
    * **Amortized Trickle Decay:** Provide `trajectory_bvh.step_decay(tree, max_evictions)` callable on a low-frequency cadence (e.g., 60-tick or 120-tick maintenance cycle). When `tree.free_count > max(64, tree.size * 2)`, pop a fixed micro-batch (e.g., 4 to 8 nodes per decay step) into `nil`, bleeding down surplus memory smoothly over 10–30 seconds after large deconstructions.
  * **2. Indexed Binary Heap Buffer Deflation (`binary-heap.lua`):**
    * **Sliding Buffer Tail Compaction:** The heap's capacity `#heap.nodes` expands during peak volume spikes (e.g., thousands of simultaneous spoil timers or projectile arrivals). When the virtual line contracts (`heap.size \ll #heap.nodes`), idle allocated slots beyond the active working set must not remain hoarded forever.
    * **Amortized Buffer Decay:** Provide `binary_heap.step_decay(heap, max_evictions)` invoked alongside the BVH decay loop. When `#heap.nodes > max(64, heap.size * 2)`, truncate tail slots (`heap.nodes[#heap.nodes] = nil`) in small, fixed increments (e.g., 8 slots per step) until the buffer stabilizes at its proportional working-set target.
    * **Explicit Heap Compaction:** Provide `binary_heap.compact(heap)` to immediately truncate idle slots beyond `heap.size` (`for i = heap.size + 1, #heap.nodes do heap.nodes[i] = nil end`).
  * **Dual-Watermark Hysteresis (Both Structures):**
    * Enforce a wide gap between trigger ceiling ($\text{capacity} > \text{size} \times 3 + 128$) and retention floor ($\text{size} \times 1.5 + 64$) to eliminate allocation/deallocation thrashing during ordinary working set oscillations.
  * **Save-File Boundary Compaction:**
    * Factorio serializes all tables in `storage` directly into save game zips. On mod initialization and migration (`on_configuration_changed`), clamp cold BVH `free_nodes` and heap `nodes` arrays down to active sizes plus a modest safety buffer (e.g., 64 items), guaranteeing that deconstructed megabases or settled spikes never permanently inflate save file sizes or autosave durations.

---

#### Phase 2: Native Factorio 2.0 LuaRenderObject Cache & Recycler
* **Core Objective:** Establish a high-throughput, pre-allocated pool of native `LuaRenderObject` instances to completely eliminate visual allocation and destruction churn.
* **Key Architecture:**
  * Build a centralized render object cache organized by visual archetype (circles, lines, text, sprite billboards).
  * Completely ban calling `LuaRenderObject::destroy()` and `rendering.draw_*` during runtime flight and visual tracking.
  * **Factorio 2.0 Direct Property Mutation:** Mutate leased `LuaRenderObject` handles in-place:
    * `render_obj.target = new_position`
    * `render_obj.visible = true / false`
    * `render_obj.color = new_color`
  * When a visual indicator exits an observer's screen, set `render_obj.visible = false` and return the object reference to that player's free list in `storage.render_pool[player_index]`.

---

#### Phase 3: Player Viewport Spatial BVH & Hysteresis Caching
* **Core Objective:** Provide an indexed spatial observer tree tracking all active player screens per surface without per-tick engine polling.
* **Key Architecture:**
  * Maintain `storage.viewport_bvh[surface_index]` storing active screen bounds for each connected player on that surface.
  * **Concentric Hysteresis Bounds:** Each player viewport is bounded by three concentric boxes:
    1. *Inner Shrunk AABB:* Camera zoom-in threshold. If the active camera frustum shrinks completely inside this box, trigger a containment contraction and recenter.
    2. *Padded Viewport AABB:* The active culling boundary, inflated slightly beyond visible screen tiles to prevent pop-in during high-speed transit.
    3. *Outer Fat AABB (Hysteresis Shell):* An expanded boundary shell. Camera movement within this shell causes **zero** BVH re-insertions. Only when the padded viewport breaches the outer fat boundary is the fat AABB recentered and re-indexed in the tree via `trajectory_bvh.update(tree, player_leaf)`.

---

#### Phase 4: Observer Intersection Engine & Active Visibility Sets
* **Core Objective:** Construct an event-driven notification bridge connecting player viewports to motion corridors and spatial entities.
* **Key Architecture:**
  * Eliminate global polling loops over players, capsules, and structures.
  * **Event-Driven Subscriptions:**
    * When a player viewport breaches its outer fat AABB, query `storage.motion_bvh[surface_index]` using the updated bounds.
    * When a motion corridor or entity is registered or updated, query `storage.viewport_bvh[surface_index]`.
    * Nodes entering a player's fat AABB are added to that player's **Active Visible Set** (`storage.player_visible_set[player_index]`) and lease visual handles from the Phase 2 render pool (`render_obj.visible = true`).
    * Nodes leaving a player's fat AABB set `render_obj.visible = false`, return their render handles to the pool, and are evicted from `player_visible_set[player_index]`.

---

#### Phase 5: Per-Player Sliding-Scale Render Dispatcher
* **Core Objective:** Execute local on-screen interpolation and rendering decoupled per player, respecting individual display settings and hardware constraints.
* **Key Architecture:**
  1. **Zero Map/BVH Traversal:** The render dispatcher **never** touches a BVH, scans active capsules, or polls map-wide entities. It iterates strictly over the compact flat table: `storage.player_visible_set[player_index]` (typically 0 to 40 items).
  2. **Per-Player Cadence Governor:**
     * Configurable refresh rate per player: $C \in \{1, 2, 3, 6, \infty\}$ ticks.
     * $C = 1$: True 60 FPS sub-tile continuous interpolation.
     * $C = 6$: Power-saving mode (synchronized with 6-tick discrete motion hops).
     * $C = \infty$ (Early Exit): Alt-Mode toggled off, capsule overlays disabled in mod settings, or player in map view/chart mode. Incurs 0.00 ms script execution time.
  3. **Staggered Interleaving:**
     * Multi-tick cadences enforce phase offsets: `(game.tick + player_index) % cadence == 0`.
     * Distributes frame workloads evenly across ticks to eliminate multiplayer stutter spikes.
  4. **Closed-Form Vector Interpolation:**
     * Computes continuous coordinates along origin $\vec{A} \to \text{destination } \vec{B}$:
       $$P = \vec{A} + \hat{v} \cdot \min(t_{\text{elapsed}} \times \text{speed}, \text{dist})$$
     * Updates leased render primitives in-place: `render_obj.target = P`.

---

#### Phase 6: Unified A-to-B Timed Arrival Substrate & Trajectory BVH Corridors
* **Core Objective:** Establish a reusable, abstract linear motion engine decoupled from entity-specific logic.
* **Key Architecture:**
  * Define linear motion state records: $(t_{\text{start}}, t_{\text{end}}, \vec{A}, \vec{B}, \vec{v})$.
  * Partition trajectories into discrete 16-tile static AABB leaves registered into the surface motion BVH strictly for observer culling—**not** for collision detection.
  * Arrival events are managed strictly via an indexed binary min-heap (`storage.timed_arrival_heap`).
  * Dynamic disruption protocols (upstream path cut, tube deconstruction, pressure loss, or receiver destruction) recalculate terminal coordinates and shift heap arrival horizons without touching the BVH unless segment geometry changes.

---

#### Phase 7: Kinetic Beam Dot Virtualization
* **Core Objective:** Overhaul electromagnetic projector beam rendering to eliminate persistent map-wide visual tracking.
* **Key Architecture:**
  * Purge all persistent kinetic dot tables and map-wide entity dot records.
  * Projector beams register static, cardinal corridor segments into `storage.motion_bvh[surface_index]`.
  * Kinetic dots exist exclusively as leased render objects in the Phase 2 cache, instantiated and refreshed by the Phase 5 dispatcher only while intersecting an active player's viewport.

---

#### Phase 8: Straight Pressure Corridors & Hybrid Motion Handoff
* **Core Objective:** Accelerate pneumatic tube networks by converting unbranched straight pipelines into timed arrival expressways.
* **Key Architecture:**
  * Identify unbranched, collinear pipe runs between junctions, diverters, corners, and hubs.
  * **Hybrid Handoff Protocol:**
    * Capsules entering a straight run bypass granular 6-tick node hopping entirely, converting to Phase 6 Timed Arrival. They traverse the run in a single scheduled arrival horizon while relying on Phase 4 BVH culling for visual rendering when observed.
    * Upon arriving at a junction, curve, diverter, or unpressurized section, the capsule seamlessly hands back off to the Flow v2 discrete hop runner (`capsule-runner.lua`) for graph navigation and quality filtering.

---

### Zero Brute-Force Architecture Clause

> **Mandate on Algorithmic Complexity, Cadence Decoupling & Allocation Ceilings:**  
> 1. **Zero Linear Map / Capsule Scans:** No operation may scale with total map size, total active capsule count ($O(N_{\text{capsules}})$), or total network size. Lookups must execute in $O(1)$ spatial hash time, $O(\log N)$ BVH/heap time, or bounded localized radius.
> 2. **Zero Render-Tick BVH Queries:** Traversal of BVH trees is restricted strictly to viewport boundary breaches and corridor geometry mutations. The per-player render loop must iterate exclusively over pre-filtered, localized active sets (`player_visible_set[player_index]`), achieving strictly $O(N_{\text{visible\_on\_screen}})$ complexity.
> 3. **Decoupled Local Cadence:** Render tick execution must scale independently per connected player. Inactive players (Alt-Mode off, overlays disabled, or off-surface) must incur 0.00 ms script execution time. Multi-tick cadences must be phase-staggered (`(tick + player_index) % C == 0`) to eliminate frame spikes.
> 4. **Zero Runtime Garbage Churn & Bounded Pool Retention:** Hot-path simulation and render interpolation code must operate under a strict high-water mark allocation policy. Creating temporary vector tables, coordinate tuples, bounding boxes, or allocating and destroying `LuaRenderObject` instances during flight or panning is strictly forbidden. All objects must be leased from pre-allocated pools and mutated in-place. Idle pools across both Indexed Binary Heaps and Spatial Trajectory BVHs must implement proportional working-set gating and amortized trickle decay to prevent memory hoarding and save-file serialization bloat.