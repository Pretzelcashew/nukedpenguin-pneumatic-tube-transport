Target Task: Modularize and refactor `scripts/flow/flow-engine.lua` (2,511 lines) into clean domain modules and unify kinetic flow into the standard flow graph.

### Architectural Objectives & Target Layout
Decompose the 2,511-line `flow-engine.lua` monolith into four focused modules (<700 lines each):
1. `scripts/flow/flow-renderer.lua`: Extract all Alt-Mode visualization (`draw_flow`, `clear_flow_renders`, pressure number text, vector lines, junction circles, socket dots).
2. `scripts/flow/flow-gate-interop.lua`: Extract wall orthogonal axis locking (`wall_locked_group`), terminator gate cutoff state sync (`gate_cutoff_states`), boundary soft-registry queue, and research callbacks.
3. `scripts/flow/flow-kinetic.lua`: Clean virtual node projection logic for electromagnetic projectors.
4. `scripts/flow/flow-engine.lua`: Retain strictly core graph coordination (`flow_nodes`, `flow_connections`), the 1-tile/tick delta wavefront queue step (`flow_queue`, `counter_queue`), and primary Factorio event hook dispatchers.

### Core Architectural Invariants & Negative Constraints
1. ZERO BESPOKE KINETIC WAKEUPS:
   - Do not maintain separate kinetic wakeup loops or custom notification dispatchers like `notify_beam_obstruction_changed`.
   - Kinetic virtual nodes must live directly in `storage.flow_nodes`, and their sequential edges must live in `storage.flow_connections` with `capsule_transmit = true`.
   - When an obstacle is placed, unplaced, or the projector rotates/loses power, sever/reconnect the edges in `flow_connections` and call the existing, battle-tested `wake_parked_capsules` engine.
2. DELETE PARALLEL STORAGE TABLES:
   - Eliminate `storage.kinetic_levels` and `storage.kinetic_beam_tiles`. Kinetic flow is just standard flow with a 1D straight-line vector.
   - Strip out over-engineered continuous ray-box AABB collision math; in Factorio, cardinal lines are discrete integer tile steps (`y = y - 1`).
3. PRESERVE ALL GAMEPLAY MECHANICS:
   - Prominent 5-tile ballistic nodes (`is_prominent = true` every 5th tile) for high-velocity hops.
   - Player/vehicle open-air impact damage and cargo spillage in `capsule-runner.lua`.
   - 3 MW idle baseline, 9 MJ discharge buffer, and receiver catchment.
4. STEP-BY-STEP EXECUTION FOR PATCH SAFETY:
   - Do not attempt a 2,000-line monolithic diff in a single turn. 
   - Perform pure structural extractions first (`flow-renderer.lua` and `flow-gate-interop.lua`) before mutating kinetic logic.

Please output Query 1 to begin Routine 1.