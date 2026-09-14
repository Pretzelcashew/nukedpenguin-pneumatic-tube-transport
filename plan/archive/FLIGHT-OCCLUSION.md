Here are the items categorized strictly around **your realizations** (what clicked about the architecture and the codebase) and **your potential plans** (the architectural ideas and paths forward you proposed):

---

### Category A: Your Architectural Realizations

* **The Erroneous Coupling Realization:**  
  You realized that linking in-flight capsule updates to the firing projector's live flow nodes was an architectural mistake you had been trudging with—recognizing that the projector’s beam is only meant to establish the initial valid endpoint at launch, not dictate the capsule once it is in the air.
* **The "Flight as an Independent Traversal" Realization:**  
  You realized that *"a flight is a flight"*—fundamentally an independent, time-sliced traversal from Point A to Point B (a delayed teleportation until rendered or observed), rather than an object bound to the emitter's live state.
* **The Origin of the AI's Raycast:**  
  You recognized why that hidden raycaster was written in the first place: the AI couldn't reconcile your Spatial BVH with the projector's flow nodes, so it invented a third, brute-force geometry loop over all active projectors.
* **The Bypassed Flow-Node Premise:**  
  You realized that the mechanism you believed was acting as the state-change detector for obstacle entry and exit (interrupting the kinetic flow nodes) was being completely bypassed by that secret raycast.
* **The Regressed Timestamp Awareness:**  
  You realized that the occluder used to be timestamp-aware and functional in an earlier version of your mod, but was degraded or stripped out during subsequent revisions without your awareness.
* **The Uniformity of Occluders Constraint:**  
  You determined that static buildings and moving characters cannot be split into separate categories, because a player can quick-mine and rebuild a wall just as fast as someone walking into and out of a tile.

---

### Category B: Architectural Dilemmas & Trade-offs You Identified

* **Option A vs. Option B Conflict:**  
  You weighed the two approaches and identified the flaws in both:
  * *Option B (Just-In-Time impact checking)* eliminates twitching dots, but is flawed because it fails to catch new obstacles placed directly in the path during flight.
  * *Option A (Live corridor updating)* catches new obstacles, but causes the arrival dot to constantly morph and jitter prematurely if someone walks back and forth through the beam.
* **Need for Active Occlusion vs. Dot Stability:**  
  You realized that even if Option B sounded cleaner, you still genuinely need active in-flight occlusion detection so capsules don't ghost through newly placed obstructions.
* **BVH Node Overlap Concern:**  
  You questioned how the system would reconcile having potentially multiple BVH nodes spawned at the same physical coordinates if capsule flights were separated from the projector.

---

### Category C: Your Potential Plans & Alternative Approaches

* **Plan 1: Immediate Removal of the Brute-Force Raycast:**  
  You identified that the global projector loop and slope math in `handle_obstacle_changed` must be completely ripped out.
* **Plan 2: A Secondary, Static Trajectory Flow Strip:**  
  You proposed creating an immutable secondary flow strip specifically for the projectile's flight path that remains locked and doesn't change when the projector changes.
* **Plan 3: Using the Spatial BVH for Occlusion Detection:**  
  You proposed repurposing the rendering BVH to double as the spatial collision/occlusion detector, hit-testing obstacles against the BVH instead of relying on the projector's flow nodes.
* **Plan 4: Projector Pre-Building the BVH Corridor:**  
  You proposed having the firing projector prepare and maintain the BVH corridor ahead of time so launched capsules can enter it immediately without launch stutter or on-the-fly tree construction.