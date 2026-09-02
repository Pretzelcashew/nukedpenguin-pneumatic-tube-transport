Here is a staged execution plan designed to fix Flow v2 performance in discrete, self-contained steps. Each stage is isolated so you can hand it directly to an AI developer instance with clear boundaries and zero ambiguity.

---

# Flow v2 Performance Refactoring Master Plan

## Architecture Goal
Transform the v2 granular flow capsule engine from $O(N)$ linear map sweeps to **$O(1)$ constant-time spatial indexing**, eliminate **Lua Garbage Collection (GC) table churn**, and enforce **strict motion staggering** so the system can scale from ~120 capsules to **1,000+ active capsules at 60 UPS**.

---

### STAGE 1: $O(1)$ Spatial Parked Index & Targeted Neighbor Wakeups
**Primary Target File:** `scripts/flow/capsule-runner.lua`  
**Secondary Target File:** `control.lua` (storage schema initialization)

#### Objective:
Eliminate the $O(N)$ map-wide `pairs(storage.capsules)` sweep in `wake_parked_capsules` and restore the 6-tick motion staggering breakdown.

#### Key Implementation Steps:
1. **Initialize Storage Schema:** Add `storage.parked_by_port = {}` (mapping `port_key -> { [capsule_id] = true }`) in `flow_engine.init_storage()` or setup.
2. **Track Parked Lifecycle:**
   - When a capsule enters a parked state (`to_port_key == nil` and cannot find target), add it to `storage.parked_by_port[from_port_key][capsule_id] = true`.
   - When a capsule transitions to moving or is removed, remove it from `storage.parked_by_port`.
3. **Rewrite `wake_parked_capsules(target)`:**
   - If `target` is a `port_key` or `unit_number`, look up:
     a) Capsules parked directly at `target` (`storage.parked_by_port[target]`).
     b) Connected adjacent neighbor ports using `storage.flow_connections[target]`.
     c) Internal sister ports on the same entity using `storage.flow_unit_ports[unit_number]`.
   - Iterate **only** over the set of capsule IDs found in those specific index buckets.
4. **Enforce Parked-Only Wakeups:**
   - Only set `capsule.next_retry_tick = nil` if `capsule.to_port_key == nil` (the capsule is actually parked). Moving capsules **must** keep their current stagger tick timer so staggering works as designed.

#### Deliverable Checklist:
- [ ] No `pairs(storage.capsules)` iterations inside `wake_parked_capsules`.
- [ ] Waking a port only inspects local and adjacent neighbor buckets in $O(1)$ time.
- [ ] Active moving capsules do not have their stagger timers wiped by nearby hops.

---

### STAGE 2: Zero-Allocation Scratch Buffers in Pathfinding & Hop Evaluation
**Primary Target File:** `scripts/flow/capsule-runner.lua`

#### Objective:
Eliminate Lua Garbage Collection (GC) pressure caused by generating dozens of temporary tables (`{ key = ..., via_port = ... }`, `best_list = {}`) on every hop for every active capsule.

#### Key Implementation Steps:
1. **Define Module-Level Scratch Buffers:**
   Define persistent top-level tables at the top of `scripts/flow/capsule-runner.lua`:
   - `scratch_candidates = {}`
   - `scratch_best_list = {}`
   - `scratch_unit_ports = {}`
2. **Refactor `get_candidate_hops(from_port_key)`:**
   - Populate flat scratch arrays instead of returning newly allocated table objects.
   - Use integer index counters (e.g. `count = count + 1`) and clear old elements by setting array positions to `nil` or overwriting indices.
3. **Refactor `select_next_target(capsule)`:**
   - Use `scratch_candidates` and `scratch_best_list` directly.
   - Avoid instantiating temporary candidate wrappers during pressure-drop and lookahead comparisons.
4. **Refactor `find_best_hub_outbound_port`:**
   - Perform max-drop scanning without building candidate list objects.

#### Deliverable Checklist:
- [ ] Zero temporary table allocations (`{}`) inside `get_candidate_hops`, `select_next_target`, and `is_hop_valid`.
- [ ] All table allocations replaced with module-level scratch buffers.
- [ ] Verified via Lua GC pressure tracking (`collectgarbage("count")`).

---

### STAGE 3: Wavefront Flow Engine Idle Sleep & Rendering Guard Optimization
**Primary Target File:** `scripts/flow/flow-engine.lua`

#### Objective:
Ensure the v2 flow propagation engine drops to 0 CPU overhead when flow levels reach steady state and rendering overlays are turned off.

#### Key Implementation Steps:
1. **Fast-Path Debug Rendering Guard:**
   - Add a global/cached boolean check at the top of `update_port_render` and `update_edge_render`:
     If no active player has `new_flow` debug mode enabled, `return` immediately on line 1 before string formatting or render lookup calls.
2. **Queue Sleep Validation:**
   - In `flow_engine.step(tick)`, ensure `if not storage.flow_queue or next(storage.flow_queue) == nil then return end` executes as the first instruction.
3. **Internal Transmit Propagation Pruning:**
   - In `flow_engine.step`, when `target_level == current_level`, do **not** enqueue neighbor ports into `storage.flow_queue` to prevent infinite propagation loops on steady networks.

#### Deliverable Checklist:
- [ ] `update_port_render` and `update_edge_render` exit in $O(1)$ time when debug overlays are disabled.
- [ ] Steady-state networks produce 0 queue updates per tick.

---

### STAGE 4: Scalability Verification & Stress Benchmark
**Target Area:** Command Harness / Integration Testing

#### Objective:
Verify that Flow v2 maintains 60 UPS with 1,000+ moving capsules on a complex pneumatic network.

#### Key Implementation Steps:
1. Create a console command `/pt-benchmark-v2 [count]` to spawn $N$ capsules across connected hubs.
2. Measure:
   - **UPS:** Must maintain 60.0 UPS at 1,000 active capsules.
   - **Tick Time:** `capsule_runner_v2.update_capsules` execution time should remain $< 1.5\text{ ms}$ total.
   - **GC Pressure:** Allocation rate should remain flat during steady movement.

---

## Suggested Task Assignment Workflow

1. **Task AI Instance #1:** Run **STAGE 1** ($O(1)$ Spatial Parked Index & Targeted Neighbor Wakeups).
2. **Task AI Instance #2:** Run **STAGE 2** (Zero-Allocation Scratch Buffers) after Stage 1 is committed.
3. **Task AI Instance #3:** Run **STAGE 3** (Flow Engine Idle & Render Guards) independently or in parallel with Stage 2.