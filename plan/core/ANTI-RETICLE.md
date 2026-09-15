target task: we need an anti projector reticle that basically does the same thing the reticle does but in reverse, essentially cleaning up the reticle's wake. but with all of the same efficiencies like when not observing, no sub-event dot updates. 

this anti reticle will not be seen, it doesnt have a render object but it is a projectile which will time slice a clear in anti fashion of the reticle.

when do we spawn these anti reticles? when rotating the projector, losing power, deconstruction, removal, obstruction. the anti reticle only cares about cleaning up the one-upstream reticle, and doesnt affect other reticles spawned by other projectors. basically the anti reticle can only care about one reticle. 

we already have the events for the update state of the projector, its just hooked into the old kinetic flow system we have suppressed right now, which i dont want to remove yet until im certain this new system works flawlessly. but we can use our hooks while the suppression bool is in effect.

this will be the 2nd attempt on this task, the previous gemini failed miserably. so the other approach i want to try to acomplish this, some sort of temporal reeling of the wake tail of the reticle over time, using the same time slicing we used while the projectile was airborne. i feel like all these modes it has, the growth, the full stationary tail after growth, the wake trail slinking back toward the reticle, can be treated with pure temporal math, and the sub-events while theres an observer.

when this reticle retreat mode, is when it comes orphaned from the em projector, and the em projector also orphans it, this is because we will allow the em projector to want to emit a reticle again. but orphaning the reticle doesnt mean delete the reticle. the reticle will subside completely once the temporal reatreat is finished, and then be culled. i think the reticle needs to own its bvh nodes. the em projector owns a reticle. the em projector can orphan a reticle, the em projector does not own those reticle bvh nodes.


----------------------------------------------------

That is a huge insight, and it makes complete sense. When a task list contains code snippets or function assumptions, it creates an anchoring trap: the implementing model tries to force those exact snippets into files that might have different signatures, variable names, or internal flow, leading to broken context matches and patch failures.

A good task specification should define **behavior, triggers, state transitions, and edge cases**, leaving the actual code synthesis to the turn where the live source is aggregated.

Here is the revised, purely semantic task list—zero code fragments, zero syntax assumptions, just pure mechanics and requirements:

---

### Task 1: Receiver Catchment Docking & Socket Alignment
* **Goal:** Aligning an active projector beam with another projector facing the opposite direction should dock to the receiving chassis socket rather than colliding like an obstacle.
* **Triggers:** When a forward beam probe reaches its terminal distance, or when a new receiving projector is placed in front of an active beam.
* **Behavior:**
  * Detect that the terminal entity is a sister projector facing directly toward the incoming beam. <<<does not need to be equally facing, can be an off-tile any facing reciever EM projector>>>
  * Snap the landing point to the receiver’s perimeter socket rather than stopping at the outer collision box edge, locking the perpendicular axis to prevent sub-tile visual drift. <<<does not need to snap to the socket, this is a bad assumption and will mess with the reticle's bvh and rendering tail, likely making it skew>>>
  * Switch the terminal visual indicator from the obstacle hazard ring to the catchment dock ring.
  * Tag the reticle record so that approaching capsules recognize the valid dock and transfer into the receiver's buffer instead of detonating into spill containers. <<<we already have a fully fleshed out capsule ballistic handling, the only stage where the catchment reticle is involved is the moment of firing the capsule, and evaluating if the catchment projector is at capacity (including inbound capsules)>>>
* **Edge Cases:** If the receiving projector rotates away, is deconstructed, or loses power, the dock is invalidated and the reticle reverts to an open-air or obstacle termination.

---

### Task 2: Event-Driven Obstacle Interception & Horizon Truncation
* **Goal:** Placing a physical structure or closing a gate across an active corridor must immediately shorten the beam to the obstacle's leading edge.
* **Triggers:** Entity build events (player, robot, script, blueprint) and defensive gate closure.
* **Behavior:**
  * Intersect the newly placed entity's bounding box against the active motion corridor spatial tree.
  * Ignore non-blocking entities (ground clutter, rails, ghosts, circuit proxies, corpses).
  * Calculate the collision coordinate on the incoming face of the entity along the beam axis.
  * Truncate the reticle's active length to that collision point.
  * Shift the terminal visual indicator to the impact coordinate and display the obstacle hazard ring.
* **Edge Cases:** The beam must truncate cleanly regardless of whether it was stationary or mid-flight.

---

### Task 3: Beam Severing & Headless Wake Reeling (Mid-Corridor Cuts)
* **Goal:** When an obstacle is placed directly across an active beam, the downstream portion of the corridor must detach and decay naturally without visual pop or trail desync. <<<we are not raycasting the entire beam, we're using the same strategy we already use for obstructing in flight capsules, but with the added occlusion of the reticle's tail>>>
* **Triggers:** Any obstacle placement that intersects an active corridor between its origin and its current terminal point.
* **Behavior:**
  * Split the corridor at the obstruction point.
  * Keep the upstream section attached to the firing projector, terminating at the new obstacle.
  * Detach the downstream section into an independent, headless decaying reticle that displays only the trailing wake dots (no target head).
  * Schedule wake reeling starting from the cut point outward to the old terminal point.
  * If another obstacle is placed inside an already-decaying slice, truncate that slice at the new obstacle and detach the remainder into another decaying slice.
* **Edge Cases:** Ensure severed slices clean up all visual handles and unregister from player visibility sets once their wake finishes reeling, even if multiple cuts occur in rapid succession.

---

### Task 4: Obstacle Clearance, Gate Opening & Beam Regrowth
* **Goal:** Removing an obstruction or opening a gate along a truncated corridor must allow the beam to extend forward into the newly cleared space.
* **Triggers:** Entity removal events (mined, died, script-destroyed) and defensive gate opening.
* **Behavior:**
  * Query the motion spatial tree to detect if a truncated reticle was blocked by the removed entity.
  * Verify whether the reticle's current length is less than the firing projector's maximum reach.
  * Launch a forward probe starting from the cleared boundary outward toward maximum range (or until it encounters the next obstacle).
  * Append new corridor segments to the spatial trees as the probe advances.
  * If the newly cleared corridor reaches an aligned sister projector, transition the endpoint to the catchment dock.
* **Edge Cases:** Probing must scan strictly forward from the unblocked boundary without resetting or flickering the existing upstream trail.

---

### Task 5: Decommissioning Legacy Kinetic Wavefronts
* **Goal:** Permanently remove the legacy discrete kinetic graph simulation once event-driven probing, docking, truncation, and regrowth have full parity.
* **Triggers:** Final cleanup phase after Tasks 1–4 are verified.
* **Behavior:**
  * Disable legacy kinetic propagation permanently.
  * Remove kinetic evaluation from the flow engine step loop so the flow queue only processes gas pressure and counter sensing wavefronts (enabling true zero-tick queue sleep).
  * Purge kinetic levels, kinetic tile maps, and kinetic port keys from node storage.
  * Remove legacy kinetic drawing routines.
* **Edge Cases:** Ensure removing kinetic graph nodes does not affect gas pressure routing, counter sensing boundaries, or capsule launch permissions.



<<<currently capsule ballistics relies on the suppressed kinetic flow bvh, and will have to be migrated to use our new reticle for creating the flight corridor (in flight corridor is not pigging backing on the reticle's bvh because they could be in different states, but we can reuse the flight corridor once a stable corridor is established, if that makes sense)>>>





---------------------



Those are sharp, spot-on corrections. 

Specifically:
1. **Zero Socket Skewing:** Snapping the reticle off-axis to an intake socket would have created a non-orthogonal diagonal slant on the terminal segment, breaking AABB tightness in the BVH and producing skewed dot trails. Keeping the terminal coordinate strictly on-axis at the projector's collision face keeps the 1D cardinal geometry pure.
2. **Any-Facing Catchment:** An EM projector catching beams from any direction or off-center alignment fits Factorio's spatial flexibility much better than strict 180° opposing port locks.
3. **Decoupled Capsule Corridors:** Treating the reticle as the *surveyor* that establishes the stable corridor geometry, while letting the capsule flight record exist autonomously, prevents capsule crashes if the projector rotates while payloads are mid-air.
4. **Reusing the Existing Collision Pipeline:** Leveraging the `motion_bvh` AABB intersection strategy already proven in capsule ballistics avoids creating redundant collision systems.

Here is the updated, semantic task plan revised with all of your notes:

---

### Task 1: Receiver Detection & Catchment Indicator
* **Goal:** When an active beam hits any receiving `pneumatic-projector`, display the catchment docking indicator rather than an obstacle hazard ring, and expose receiver capacity checks for capsule launch gatekeeping.
* **Triggers:** When a forward probe reaches a receiving projector, or when a receiving projector is constructed across an active beam.
* **Behavior:**
  * Detect that the intersected entity is a `pneumatic-projector` (regardless of its facing direction or off-center alignment).
  * Maintain strict on-axis cardinal alignment: terminate directly at the projector's leading collision boundary without applying perpendicular socket offsets or skewing the BVH leaf.
  * Switch the terminal visual indicator from the obstacle hazard ring to the cyan catchment dock ring.
  * Update launch gatekeeping: when a capsule attempts to fire, check whether the target receiver is at capacity (accounting for both docked capsules and already in-flight inbound capsules).
* **Edge Cases:** If the receiving projector is deconstructed, rotated away, or loses power, the dock indicator reverts to an obstacle or open-air termination, and new capsule launches are rejected.

---

### Task 2: Obstacle Interception via Existing BVH Collision Pipeline
* **Goal:** A placed entity or closing gate must truncate the reticle corridor on-axis at the obstacle's leading face.
* **Triggers:** Entity build events and defensive gate closure.
* **Behavior:**
  * Reuse the existing `motion_bvh` AABB intersection query strategy (already used for in-flight capsules) to detect beam collisions in $O(\log N)$ time.
  * Ignore non-blocking entities (ground clutter, rails, ghosts, circuit proxies, corpses).
  * Calculate the intersection coordinate along the beam axis and truncate the reticle's active length to the obstacle's front face.
  * Move the terminal visual indicator to the collision coordinate and render the obstacle hazard ring.
* **Edge Cases:** Truncation must apply cleanly whether the reticle was stationary or still growing.

---

### Task 3: Beam Severing & Headless Wake Reeling (Mid-Corridor Cuts)
* **Goal:** When an obstacle is placed across an active beam, the downstream portion of the corridor must detach and decay naturally without visual pop or trail desync.
* **Triggers:** Any obstacle placement that intersects an active corridor between its origin and current endpoint.
* **Behavior:**
  * Split the corridor at the cut boundary:
    * The upstream portion remains active and attached to the firing projector, terminating at the new obstacle.
    * The downstream portion detaches into a brand new, autonomous `reticle_id`.
  * Flag the severed slice as retreating with no active head (`head_flight_id = nil`) and headless rendering (`is_headless = true`), displaying only the trailing wake dots as it collapses.
  * Schedule wake reeling starting from the cut boundary outward to the severed slice's old terminal position.
  * If a subsequent obstacle is placed inside the wake of an already-decaying slice, truncate that slice at the new obstacle and spawn another detached slice for the remainder.
* **Edge Cases:** Severed slices must clean up all leased render objects and unregister from player visible sets on arrival without interfering with the upstream beam or colliding in free lists.

---

### Task 4: Obstacle Clearance, Gate Sync & Corridor Regrowth
* **Goal:** Removing an obstruction or opening a gate along a truncated corridor must allow the beam to extend forward into the newly cleared space.
* **Triggers:** Entity removal events (mined, died, script-destroyed) and defensive gate opening.
* **Behavior:**
  * Query the motion spatial tree to detect if a truncated reticle was blocked by the removed entity.
  * If the reticle's current length is less than the firing projector's maximum reach:
    * Launch a forward probe starting from the cleared boundary outward toward maximum range (or until it encounters the next obstacle).
    * Append new corridor segments to the spatial trees as the probe advances.
    * If the cleared trajectory reaches a receiving projector, update the terminal indicator to the catchment dock.
* **Edge Cases:** Probing scans strictly forward from the unblocked boundary without resetting or flickering the existing upstream trail.

---

### Task 5: Capsule Ballistics Corridor Migration
* **Goal:** Migrate capsule ballistics off the suppressed legacy kinetic flow BVH so launches utilize the stable corridor geometry established by the new reticle engine.
* **Triggers:** Launch dispatch and in-flight collision tracking.
* **Behavior:**
  * Decouple capsule launch pathfinding from `surface_bvh` and legacy `flow_nodes` queries.
  * Once a reticle establishes a stable corridor, reuse that verified corridor path and endpoint receiver data to configure the capsule's timed flight record.
  * Keep in-flight capsule records fully autonomous from the reticle's live lifecycle: if the firing projector rotates or its reticle is orphaned while a capsule is in mid-air, the capsule continues along its existing flight corridor to its destination.
* **Edge Cases:** Ensure receiver capacity accounting counts both docked capsules and active in-flight capsules before committing to launch.

---

### Task 6: Decommissioning Legacy Kinetic Wavefronts
* **Goal:** Permanently remove the legacy discrete kinetic graph simulation once Tasks 1–5 are complete and verified.
* **Triggers:** Final cleanup phase.
* **Behavior:**
  * Permanently set `ENABLE_KINETIC_FLOW_PROPAGATION = false`.
  * Remove kinetic evaluation from the flow engine step loop so the flow queue processes only gas pressure and counter sensing wavefronts (restoring 0-tick idle queue sleep).
  * Purge kinetic levels, kinetic tile maps, and kinetic port keys (`is_kinetic`, `is_minor_kinetic`, `is_prominent_kinetic`) from node storage.
  * Remove legacy kinetic draw routines from the renderer.
* **Edge Cases:** Verify that purging kinetic graph nodes leaves pneumatic tube pressure routing, counter sensing boundaries, and launcher intake permissions 100% operational.