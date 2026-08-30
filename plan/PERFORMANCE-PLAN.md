# Pneumatic Tube Transport — Stalled Capsule Performance Diagnostic Findings

## Overview
When transit capsules stall or park (`capsule.to_port_key == nil`) waiting for destination hub inventory space or downstream network capacity, game performance (FPS/UPS) degrades rapidly even with low capsule counts. Investigation has identified five distinct structural and algorithmic bottlenecks in the capsule simulation pipeline.

---

## Issue 1: 60Hz Pathfinding & Unpacking Simulation Loop for Parked Capsules

* **Affected Files & Functions**:
  * `scripts/capsules/capsule-runner.lua` $\rightarrow$ `update_capsules()`
  * `scripts/hubs/hub-unpacking.lua` $\rightarrow$ `capture()`, `can_insert_all()`
  * `scripts/capsules/capsule-motion.lua` $\rightarrow$ `handle_arrival()`, `select_next_target()`, `find_best_hub_outbound_port()`
* **Diagnostic Summary**:
  When a capsule cannot proceed (`to_port_key == nil`), `update_capsules()` continuously attempts arrival unpacking and outbound pathfinding on **every single game tick (60Hz)**.
* **Technical Flow**:
  1. `handle_arrival()` is called every frame, invoking `can_insert_all()`. This performs full multi-slot inventory space simulations across the holder container and the target hub entity, checking item prototypes, stack sizes, quality strings, and slot filters.
  2. If unpacking fails (e.g., target chest full), `select_next_target()` is called immediately to search for alternative outbound hops.
  3. `select_next_target()` scans all entity exit ports, line capacities via `has_entity_network_capacity()`, and diverter port filters via regex string splits (`^(%d+):(%d+)$`).
  4. If no path or space is available, `to_port_key` remains `nil`. On the next frame (1/60s later), the exact same simulation and pathfinding loops execute again.
* **Performance Impact**:
  Generates continuous table allocations, `LuaInventory` slot checks, string parsing, and graph walks 60 times per second for stationary entities whose state has not changed.

---

## Issue 2: Unconditional Every-Frame Destruction & Re-creation of Render Objects

* **Affected Files & Functions**:
  * `scripts/capsules/capsule-renderer.lua` $\rightarrow$ `render()`
  * `scripts/capsules/capsule-queries.lua` $\rightarrow$ `clear_capsule_render()`
* **Diagnostic Summary**:
  `capsule_renderer.render()` executes at the end of every tick in `update_capsules()` for all active capsules. It unconditionally destroys all existing render objects and recreates them, even when the capsule is completely stationary.
* **Technical Flow**:
  1. `clear_capsule_render()` iterates over `capsule.render_id` and invokes `.destroy()` on all active C++ rendering handles (`LuaRenderObject`).
  2. `render()` evaluates player debug flags and calls `rendering.draw_circle` and `rendering.draw_sprite` to generate new render objects at `curr_pos`.
  3. For a stalled capsule, `curr_pos` does not change frame-to-frame.
* **Performance Impact**:
  Destroying and recreating C++ `LuaRenderObject` handles 60 times a second per capsule creates high C++ wrapper allocation overhead, Lua-to-C++ bridge thrashing, and rendering engine lockup.

---

## Issue 3: Unbounded 255-Slot Inventory Iteration in Display & Spoilage Routines

* **Affected Files & Functions**:
  * `scripts/capsules/capsule-renderer.lua` $\rightarrow$ `get_dominant_item()`
  * `scripts/capsules/capsule-lifecycle.lua` $\rightarrow$ `update()`
* **Diagnostic Summary**:
  Capsule holder container prototypes (`invisible-capsule-holder`) have an `inventory_size` of 255. Active slots are clamped at runtime via engine limiter bars (`inventory.set_bar(...)`). However, `get_dominant_item()` and `capsule_lifecycle.update()` iterate `for i = 1, #inventory do` (1 to 255) instead of respecting `inventory.get_bar() - 1`.
* **Technical Flow**:
  1. `get_dominant_item()` reads `inventory[i]` from index 1 through 255 to find cargo/vessel stack names.
  2. Indexing `inventory[i]` on 230+ red-locked empty slots forces Factorio to instantiate C++ `LuaItemStack` userdata wrappers for every locked slot.
  3. Because `get_dominant_item()` is called up to 3 times per tick per capsule (during pathfinding and rendering), a single parked capsule performs 765+ stack allocations per frame.
  4. A similar unbounded `#inv` loop executes in `capsule-lifecycle.lua` during 60-tick refrigerated spoilage checks.
* **Performance Impact**:
  Generates massive amounts of redundant C++ userdata object wrapper allocations on red-locked empty container slots.

---

## Issue 4: Un-short-circuited $O(N^2)$ Entity-Network Capacity Queries

* **Affected Files & Functions**:
  * `scripts/capsules/capsule-queries.lua` $\rightarrow$ `get_capsule_count_at_entity_network()`
  * `scripts/capsules/capsule-motion.lua` $\rightarrow$ `has_entity_network_capacity()`
* **Diagnostic Summary**:
  During candidate hop selection in `select_next_target()`, `has_entity_network_capacity()` queries how many capsules occupy a target segment via `get_capsule_count_at_entity_network()`. This query evaluates expensive graph metadata before filtering by entity unit number.
* **Technical Flow**:
  1. `get_capsule_count_at_entity_network()` iterates over all active capsules in `storage.capsules`.
  2. For every capsule in `storage.capsules`, it evaluates `capsule_queries.get_port_group()` on `cap.from_port_key` and `cap.to_port_key`.
  3. `get_port_group()` parses network metadata `flow_map` tables and queries entity port definitions (`port_defs.get_ports()`).
  4. These metadata graph queries are performed **before** checking if the capsule's port key string matches the target entity `unit_number` prefix.
* **Performance Impact**:
  Multiplies pathfinding complexity to $O(H \cdot N^2)$, executing thousands of graph metadata lookups across unrelated capsules on unrelated entities/networks every frame.

---

## Issue 5: Per-Tick Technology Table Indexing for Fragile Containers

* **Affected Files & Functions**:
  * `scripts/capsules/capsule-lifecycle.lua` $\rightarrow$ `update()`
* **Diagnostic Summary**:
  Fragile and biodegradable capsules evaluate mid-transit structural failure risk (`spill_risk`) on every frame.
* **Technical Flow**:
  1. On every tick, `capsule_lifecycle.update()` accesses `force.technologies["bio-capsule-integrity-X"]` via 4 sequential string index queries to determine the current research tier level.
* **Performance Impact**:
  Adds unnecessary per-tick table indexing overhead on every frame for fragile capsules regardless of motion state.