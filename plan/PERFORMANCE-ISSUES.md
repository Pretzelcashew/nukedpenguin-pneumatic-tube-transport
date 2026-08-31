Based on a detailed architectural audit of the provided source files, I have identified **7 critical performance bottlenecks** that cause severe UPS drops (down to 30 UPS) when handling ~150 moving capsules. 

---

### 1. `wake_parked_capsules()` Cascading $O(N)$ Scans & 0-Tick Thrashing
**Location:** `scripts/capsules/capsule-runner.lua` (`update_capsules`, `wake_parked_capsules`)

* **The Problem:** `wake_parked_capsules()` iterates over **all** entries in `storage.capsules` via `pairs()` to reset `next_retry_tick = nil`.
* **The Hot Path:** In `update_capsules()`, `wake_parked_capsules()` is invoked **whenever any capsule completes a segment hop or steps onto a port**.
* **Complexity Explosion:** With 150 capsules moving, multiple capsules reach port boundaries every tick. If 10 capsules step onto a port in one frame, `wake_parked_capsules()` iterates over all 150 capsules 10 times in that single frame ($1,500$ iterations/tick).
* **Thrashing:** Clearing `next_retry_tick` forces every parked capsule on the map to re-evaluate heavy pathfinding (`select_next_target`) and inventory space checks (`can_insert_all`) on the exact same tick, causing intense CPU spike cascades.

---

### 2. $O(N)$ Occupancy Scans with String Allocations in Path Validation
**Location:** `scripts/capsules/capsule-queries.lua` (`get_capsule_count_at_entity_network`) & `scripts/capsules/capsule-motion.lua` (`is_hop_valid`, `select_next_target`)

* **The Problem:** To check line capacity, `get_capsule_count_at_entity_network()` runs a linear scan over `storage.capsules`. Inside the loop, it performs `tostring(unit_number) .. ":"` string allocations and `string.sub()` slice comparisons for every capsule.
* **Recursive Escalation:** `is_hop_valid()` calls `has_entity_network_capacity()` **recursively up to depth 3** to inspect downstream diverter exits.
* **Impact:** A single pathfinding check for 1 capsule evaluates multiple outbound hops and downstream paths, triggering 10+ full scans of `storage.capsules`. For 150 capsules, this results in **over 200,000 table iterations and string allocations per tick**.

---

### 3. Redundant Per-Capsule Player & C++ Property Queries in Renderer
**Location:** `scripts/capsules/capsule-renderer.lua` (`capsule_renderer.render`)

* **The Problem:** `capsule_renderer.render()` iterates over `game.players` **for every single active capsule every frame**.
* **C++ Bridge Overhead:** Inside the per-capsule loop, it reads `player.game_view_settings` and `player.selected` (crossing the C++ Lua binding bridge), allocates temporary tables (`debug_players`, `debug_key_tbl`), performs string prefix matching, and executes `table.concat()`.
* **Impact:** 150 capsules $\times$ player count = hundreds of unnecessary C++ property accesses and Lua table allocations per tick, even when debug visual overlays are disabled or no player is hovering.

---

### 4. Mid-Segment Redundant C++ Position, Node & Speed Calculations
**Location:** `scripts/capsules/capsule-runner.lua` (`update_capsules`) & `scripts/capsules/capsule-motion.lua` (`calculate_segment_speed`, `get_port_world_pos`)

* **The Problem:** While a capsule is smoothly interpolating mid-segment between two ports, `update_capsules()` calls `calculate_segment_speed()` and `get_port_world_pos()` twice every tick.
* **Unnecessary Queries:** `get_node()` looks up metadata tables (`storage.networks.port_to_network`, `flow_map`), accesses C++ entity positions (`node.entity.position`), and computes `math.sqrt()` on every tick for every capsule, even though segment start/end world coordinates and speed remain static during segment traversal.

---

### 5. Physical Inventory Inspections During Pathfinding (`get_dominant_item`)
**Location:** `scripts/capsules/capsule-motion.lua` (`select_next_target`, `find_best_hub_outbound_port`) & `scripts/capsules/capsule-renderer.lua` (`get_dominant_item`)

* **The Problem:** When evaluating diverter filters or hub exit ports, `select_next_target()` calls `capsule_renderer.get_dominant_item()`.
* **Liminal Surface Queries:** `get_dominant_item()` fetches the holder entity's inventory on `liminal_surface` (`holder.get_inventory(defines.inventory.chest)`), instantiating C++ `LuaInventory` and `LuaItemStack` wrappers to find the dominant item name.
* **Impact:** Inspecting physical container item stacks during motion pathfinding creates high overhead.

---

### 6. Repetitive Diverter Filter Checks and String Parsing
**Location:** `scripts/capsules/capsule-motion.lua` (`check_diverter_port_filter`, `is_hop_allowed_by_diverter_filters`)

* **The Problem:** `is_hop_allowed_by_diverter_filters()` checks filters for both target and source ports. `check_diverter_port_filter()` resolves node data, splits port keys (`string.find`, `string.sub`), fetches `storage.diverter_settings`, and loops through 5 filter slots.
* **Impact:** Called repeatedly across recursive lookahead steps (`depth 1..3`), generating high string parsing and dictionary traversal overhead.

---

### 7. Unpacking Retry Thrashing (`can_insert_all`)
**Location:** `scripts/hubs/hub-unpacking.lua` (`can_insert_all`) & `scripts/capsules/capsule-motion.lua` (`handle_arrival`)

* **The Problem:** When a capsule reaches a full or locked hub, `can_insert_all()` iterates through all holder cargo stacks and target hub slots (building temporary tables like `required_items`, `partial_capacities`, and `filtered_empty_slots`).
* **Retry Overhead:** Because `wake_parked_capsules()` resets retry timers constantly, parked capsules at full hubs re-run full container slot simulation (`can_insert_all`) every tick instead of backing off.

---

### Primary Architectural Bottleneck Summary

| Bottleneck Component | Primary Cause | Algorithmic Complexity |
| :--- | :--- | :--- |
| **Queue Wakeup Engine** | Global `wake_parked_capsules()` on every segment step | $O(N \cdot (N_{moving} + N_{parked}))$ per tick |
| **Occupancy Validation** | Linear `storage.capsules` scan + string ops in `is_hop_valid` depth lookahead | $O(N_{capsules})$ per candidate hop ($200\text{k}+$ ops/tick) |
| **Renderer Overhead** | Per-capsule `game.players` & `player.selected` C++ property reads | $O(N_{capsules} \cdot N_{players})$ C++ bridge calls/tick |
| **Segment Traversal** | Re-calculating static world positions, nodes, and `math.sqrt` mid-segment | $O(N_{capsules})$ C++ position reads/tick |


REORGANIZED:


Yes, here is the breakdown re-organized strictly by **Priority of Performance Impact** (ranked from the absolute largest UPS drain to secondary overheads). 

---

### Tier 1: System-Collapsing $O(N^2)$ & Cascading Bottlenecks
*(Resolving these two will yield the most immediate, massive UPS recovery)*

#### **#1 (HIGHEST IMPACT) — $O(N)$ Occupancy Scans with String Allocations in Path Lookahead**
* **Location:** `scripts/capsules/capsule-queries.lua` (`get_capsule_count_at_entity_network`) & `scripts/capsules/capsule-motion.lua` (`is_hop_valid`, `select_next_target`)
* **Why it's #1:** `select_next_target()` calls `is_hop_valid()`, which runs **recursively up to depth 3**. At each step, `has_entity_network_capacity()` calls `get_capsule_count_at_entity_network()`, which iterates over **all active capsules in the game via `pairs()`** while allocating strings (`tostring(unit_number) .. ":"`) and running `string.sub()`.
* **Impact:** 150 capsules evaluating paths result in **200,000+ table iterations and string allocations per tick**. Replacing this with an $O(1)$ spatial occupancy counter table eliminates almost all pathfinding CPU time.

#### **#2 — `wake_parked_capsules()` Cascading Scans & 0-Tick Thrashing**
* **Location:** `scripts/capsules/capsule-runner.lua` (`update_capsules`, `wake_parked_capsules`)
* **Why it's #2:** `wake_parked_capsules()` scans the entire `storage.capsules` table to set `next_retry_tick = nil`. Because it's called **every time any capsule completes a segment step or steps onto a port**, it fires hundreds of times per second.
* **Impact:** It destroys the 10-tick parked capsule retry throttling. Every time 1 capsule moves, *all* parked capsules wake up on the exact same tick and re-run Bottlenecks #1, #5, and #7 simultaneously, creating huge CPU spikes.

---

### Tier 2: Heavy Per-Frame/Per-Capsule $O(N)$ Overhead
*(Runs 60 times a second for all 150 moving capsules)*

#### **#3 — Per-Capsule Renderer Operations & Player/C++ Bridge Queries**
* **Location:** `scripts/capsules/capsule-renderer.lua` (`capsule_renderer.render`)
* **Why it's #3:** Runs **every tick for every capsule (150 times/tick)**. Inside each call, it loops through `game.players`, reads `player.game_view_settings` and `player.selected` (crossing the Lua-to-C++ engine bridge), builds string keys, and allocates temporary Lua tables (`debug_players`, `debug_key_tbl`).
* **Impact:** Crosses the C++ boundary hundreds of times per frame and churns Lua garbage even when debug overlays are disabled. Evaluating player/debug state *once per tick globally* instead of 150 times per frame removes this baseline overhead.

#### **#4 — Mid-Segment Redundant C++ Position, Node & Speed Queries**
* **Location:** `scripts/capsules/capsule-runner.lua` (`update_capsules`) & `scripts/capsules/capsule-motion.lua` (`calculate_segment_speed`, `get_port_world_pos`)
* **Why it's #4:** For all 150 capsules every tick, `update_capsules()` fetches network flow metadata, reads C++ `node.entity.position`, and calculates `math.sqrt()` for segment speed.
* **Impact:** 95% of a capsule's lifespan is spent traversing mid-segment where start/end world positions and segment speeds are static. Re-querying C++ entity positions and re-computing math every frame for mid-transit capsules adds constant, unnecessary tick cost.

---

### Tier 3: Secondary Pathfinding & Container Inspection Costs
*(Localized to target selection & hub arrivals)*

#### **#5 — C++ Inventory Inspections During Pathfinding (`get_dominant_item`)**
* **Location:** `scripts/capsules/capsule-motion.lua` (`select_next_target`, `find_best_hub_outbound_port`) & `scripts/capsules/capsule-renderer.lua` (`get_dominant_item`)
* **Why it's #5:** During path choices and diverter filter evaluations, `get_dominant_item()` queries the holder entity's inventory on `liminal_surface` (`holder.get_inventory()`), instantiating C++ `LuaInventory` and `LuaItemStack` wrappers.
* **Impact:** Interrogating physical container item stacks during motion path choices is slow. Caching the payload item string directly on the `capsule` table upon injection/spawning avoids this entirely.

#### **#6 — Repetitive Diverter Filter Checks & String Parsing**
* **Location:** `scripts/capsules/capsule-motion.lua` (`check_diverter_port_filter`, `is_hop_allowed_by_diverter_filters`)
* **Why it's #6:** `is_hop_allowed_by_diverter_filters()` splits string keys (`string.find`, `string.sub`), fetches diverter settings, and loops through 5 filter slots multiple times per candidate hop across recursive lookahead steps.
* **Impact:** Adds localized string parsing and table lookup overhead during path selection.

#### **#7 — Unpacking Container Simulation Thrashing (`can_insert_all`)**
* **Location:** `scripts/hubs/hub-unpacking.lua` (`can_insert_all`) & `scripts/capsules/capsule-motion.lua` (`handle_arrival`)
* **Why it's #7:** When arriving at a hub, `can_insert_all()` simulates multi-item slot insertion across all container slots. 
* **Impact:** High complexity on its own, but its frequency is currently multiplied by Bottleneck #2 (the `wake_parked_capsules` thrashing). Once Bottleneck #2 is fixed so parked capsules respect 10-tick retry intervals, `can_insert_all()` only runs occasionally, dropping its impact significantly.