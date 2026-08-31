Here is the performance optimization specification formatted for a multi-instance AI workflow. Each task defines **what problem to eliminate and what outcome to achieve**, without prescribing specific implementation details, code structures, or algorithms.

---

# Master Task Suite: Capsule Movement UPS Optimization

> **Context for Executing AI Instances:**  
> You are executing **1 of 7 targeted performance optimization segments** for a Factorio 2.1 mod (`nukedpenguin-pneumatic-tube-transport`). The goal of this 7-part series is to restore UPS performance during high capsule traffic (~150+ active capsules). Your focus is strictly on resolving the specific bottleneck assigned to your segment while preserving all existing functional mechanics and edge-case behaviors.

---

### Segment 1 of 7: Path Lookahead & Line Capacity Queries
* **Target Scope:** `scripts/capsules/capsule-queries.lua` & `scripts/capsules/capsule-motion.lua`
* **Focus Objective:** Eliminate linear iteration over the active capsule registry and string key allocations occurring inside path lookahead capacity checks (`get_capsule_count_at_entity_network`, `is_hop_valid`).
* **Target Outcome:** Line capacity and segment occupancy checks must evaluate instantly regardless of the total number of active capsules on the map, eliminating $O(N)$ growth during recursive path validation.

---

### Segment 2 of 7: Queue Wakeup Engine & Retry Throttling
* **Target Scope:** `scripts/capsules/capsule-runner.lua`
* **Focus Objective:** Eliminate global, map-wide capsule scans (`wake_parked_capsules()`) triggered during individual capsule segment movement steps and arrivals.
* **Target Outcome:** Queue advancement and path retries must only target capsules affected by a freed route or port state change. Parked capsules must respect retry intervals without being blanket-woken by unrelated capsule movements across the map.

---

### Segment 3 of 7: Per-Frame Renderer Overhead & Player Viewport State
* **Target Scope:** `scripts/capsules/capsule-renderer.lua`
* **Focus Objective:** Eliminate per-capsule player environment queries, game view setting reads, string key joins, and temporary table allocations occurring inside the per-tick render loop (`capsule_renderer.render`).
* **Target Outcome:** Player viewport eligibility and debug state must be determined at a system level rather than repeatedly queried per capsule instance, eliminating baseline C++ engine bridge overhead during render ticks.

---

### Segment 4 of 7: Mid-Segment Traversal Calculations
* **Target Scope:** `scripts/capsules/capsule-runner.lua` & `scripts/capsules/capsule-motion.lua`
* **Focus Objective:** Eliminate repetitive mid-segment node lookups, physical entity coordinate queries, and speed math calculations (`calculate_segment_speed`, `get_port_world_pos`) executed every tick for capsules currently in mid-transit.
* **Target Outcome:** Interpolating position mid-segment should only perform essential movement updates, bypassing redundant spatial and speed queries while transit parameters remain unchanged.

---

### Segment 5 of 7: Physical Inventory Queries During Motion Pathfinding
* **Target Scope:** `scripts/capsules/capsule-motion.lua` & `scripts/capsules/capsule-renderer.lua`
* **Focus Objective:** Eliminate physical container item stack inspections on the liminal surface (`get_dominant_item`) during directional path selection and hub exit evaluation (`select_next_target`, `find_best_hub_outbound_port`).
* **Target Outcome:** Target selection and filter checks must evaluate payload characteristics without querying physical C++ container inventories during motion execution.

---

### Segment 6 of 7: Diverter Filter Validation & Key Parsing
* **Target Scope:** `scripts/capsules/capsule-motion.lua`
* **Focus Objective:** Eliminate redundant string key parsing and setting table lookups executed repeatedly during diverter filter validation (`check_diverter_port_filter`, `is_hop_allowed_by_diverter_filters`).
* **Target Outcome:** Filter evaluation across outbound hops and lookahead checks must validate hop permissions efficiently without recurring string manipulation or deep settings traversal.

---

### Segment 7 of 7: Hub Arrival Unpacking Simulation Thrashing
* **Target Scope:** `scripts/hubs/hub-unpacking.lua` & `scripts/capsules/capsule-motion.lua`
* **Focus Objective:** Eliminate redundant full-container slot space simulations (`can_insert_all`) performed by capsules parked at or repeatedly polling blocked/full hub destinations.
* **Target Outcome:** Hub space validation and unpacking attempts must only execute when destination container states or arriving capsule contents actually warrant re-evaluation.