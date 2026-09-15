### Task 1: Obstacle Interception via Spatial Collision Pipeline
* **Goal:** A placed entity, closing gate, moving character, or obstacle along a probe's path must truncate the corridor on-axis at the obstacle's leading face without diagonal drift, phantom indicators, or emitter self-collision.
* **Triggers:** Forward probe sweeps, entity placement, character movement across beams, and defensive gate closure.
* **Behavior:**
  * Use the spatial tree to detect corridor collisions in logarithmic time.
  * Filter out non-blocking entities like ground resources, ghosts, circuit proxies, corpses, elevated rail structures, and open gates.
  * Shield the emitter from its own beam: an advancing probe or active beam must explicitly ignore its own firing projector so a machine never collides with its own chassis.
  * Calculate the intersection strictly along the cardinal axis against the obstacle's front collision face, terminating squarely without applying perpendicular socket offsets or distorting the bounding box leaf.
  * Apply conditional endpoint visuals based on machine ownership:
    * If the truncated corridor is powered by a live machine, place the obstacle hazard ring at the collision point.
    * If the truncated corridor is an orphaned or decaying wake, clamp its decay boundary to the collision point without rendering an active hazard indicator, allowing it to fade naturally against the wall.
* **Edge Cases:** Truncation must apply cleanly whether the corridor is actively probing, stationary, or an already-decaying orphan wake.

---

### Task 2: Beam Severing & Headless Wake Reeling (Mid-Corridor Cuts)
* **Goal:** When an obstacle is placed across any beam corridor, split the corridor at the cut boundary into two autonomous slices so the downstream wake decays naturally without visual pop, trail desync, or orphaned graphic handles.
* **Triggers:** Any obstacle placement that intersects an active, orphaned, or retreating corridor between its start position and current endpoint.
* **Behavior:**
  * Treat all corridors as autonomous spatial entities where machine ownership is strictly optional. The severing logic must operate purely on corridor geometry and work identically whether a corridor is powered by a machine or is already an unanchored wake.
  * Split the corridor at the collision boundary into two distinct, simultaneous entities:
    * **The Upstream Slice:** Retains its existing identity and whatever ownership it already had. If powered by a live machine, it remains powered and terminates at the new obstacle. If it was already an orphaned wake, it remains orphaned and simply clamps its decay ceiling to the obstacle face.
    * **The Downstream Slice:** Detaches as a brand new, autonomous corridor that is completely unanchored from any machine. It begins at the obstacle cut point, extends to the old endpoint, and is flagged as a retreating headless wake.
  * Dispatch an anti-reticle flight for the downstream slice that starts at the cut boundary and advances outward toward the old endpoint in discrete hops, progressively reeling in wake dots.
  * When the downstream anti-reticle arrives at the old endpoint, it recycles all remaining visual primitives—including static endpoint rings and markers—and completely unregisters the severed slice from memory.
  * Support recursive slicing: if an obstacle drops across an already-severed or retreating wake, apply this exact same split so the wake stops at the obstacle and a new slice reels away the remainder.
* **Edge Cases:** Severed slices must never attempt to update machine scope tables or inspect projector power. Pruning must clean up both motion and visual trajectory trees in lockstep.

---

### Task 3: Obstacle Clearance, Gate Sync & Corridor Regrowth
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

### Task 4: Receiver Detection & Catchment Indicator
* **Goal:** When an active beam hits any receiving `pneumatic-projector`, display the catchment docking indicator rather than an obstacle hazard ring, and expose receiver capacity checks for capsule launch gatekeeping.
* **Triggers:** When a forward probe reaches a receiving projector, or when a receiving projector is constructed across an active beam.
* **Behavior:**
  * Detect that the intersected entity is a `pneumatic-projector` (regardless of its facing direction or off-center alignment).
  * Maintain strict on-axis cardinal alignment: terminate directly at the projector's leading collision boundary without applying perpendicular socket offsets or skewing the BVH leaf.
  * Switch the terminal visual indicator from the obstacle hazard ring to the cyan catchment dock ring.
  * Update launch gatekeeping: when a capsule attempts to fire, query the target receiver directly for clearance. The receiver maintains authority over its own capacity, tracking an internal record of physically docked capsules alongside an index of registered inbound flights from any sending projector. Dispatching a flight books an inbound slot directly with the target receiver; arrival, in-flight disruption, or sender orphaning releases the reservation, providing $O(1)$ gatekeeping without brute-force map scans.
* **Edge Cases:** If the receiving projector is deconstructed, rotated away, or loses power, the dock indicator reverts to an obstacle or open-air termination, all booked inbound reservations are cleared, and new capsule launches are rejected.

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