Target Task: Fix in-flight kinetic capsule obstacle tracking, restore timestamp awareness, and eliminate brute-force raycasting.

Context: 
We are working on Factorio mod `nukedpenguin-pneumatic-tube-transport`. 
Relevant architecture: `ARCH-FLOW-KINETICS.md` and `ARCH-CAPSULES-MOTION.md`.
Key files: `scripts/flow/flow-kinetic.lua` and `scripts/capsules/capsule-ballistics.lua`.

---

### Diagnosed Root Causes to Address
1. Backwards Sucking Crash:
   In `capsule-ballistics.lua`, `update_projector_flights` was querying `get_beam_endpoint()`, which hardcoded its search from distance 1 (the cannon muzzle). When a player walked behind or near the launcher muzzle, the search returned distance 3 as the new endpoint, clamped arrival to "now", and sucked the flying capsule backward across the map to explode at the player's feet.
   In-flight capsules MUST be timestamp-aware: calculate current distance traveled from elapsed flight time (1.2 ticks/tile) and ONLY inspect tiles ahead of the capsule (dist > cur_dist). Anything at or behind cur_dist must be completely ignored.

2. Brute-Force Projector Loop:
   In `flow-kinetic.lua`, `handle_obstacle_changed()` contains a legacy loop: `for unit_number, proj in pairs(storage.active_projectors) do` that performs floating-point line-box slope math on EVERY entity built/mined anywhere on the surface. This brute-force scan must be eliminated. Obstacle detection must query existing spatial data structures (the Spatial Trajectory BVH `tree:query()` or `storage.flow_grid` tile lookups) in O(1) or O(log N) without iterating unrelated projectors.

3. Module Linkage:
   `flow-kinetic.lua` and `capsule-ballistics.lua` must communicate directly. Do NOT use brittle `package.loaded[...]` lookups (which evaluate to nil in Factorio's loader). Since `capsule-ballistics` already imports `flow-kinetic`, have it register its updater directly (`flow_kinetic.update_projector_flights = capsule_ballistics.update_projector_flights`).

---

### Strict Performance & Architectural Invariants (Negative Constraints)
- DO NOT loop through `storage.active_projectors` on build, mine, or entity events. Lookups must be spatially driven by the entity's footprint.
- DO NOT poll entities, raycast, or loop in `on_tick` during flight. Flight motion is closed-form math resolved on launch and arrival via `storage.kinetic_arrival_heap`.
- DO NOT update in-flight arrival targets on intermediate advancing beam tiles during flow queue regrowth. Flight rescheduling must only trigger when an endpoint state actually finalizes (blocked or confirmed cleared).
- Parity: Characters, buildings, and gates must be treated identically as physical occluders (blocked is blocked, clear is clear).

Please review the architecture and request the necessary files to implement this fix cleanly.


