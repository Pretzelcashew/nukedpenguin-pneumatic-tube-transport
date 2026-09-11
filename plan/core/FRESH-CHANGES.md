#### 0.3.22

### Revision: Alt-Mode EM Projector Muzzle Socket Overlay Parity
**Date:** 2026-09-11 09:24 EDT
**Context:** Unpowered, disabled, or idle Electromagnetic Projectors previously lacked an Alt-Mode visual indicator on their launch muzzle, obscuring machine orientation whenever the kinetic beam was inactive. This change introduces an idle muzzle overlay dot with parity to passive intake ports and hooks state transitions into the flow engine to toggle between idle dots and active kinetic beams.
**Key Changes:**
1. **Muzzle Socket Visual Overlay (`scripts/flow/flow-engine.lua`):** Defined `PROJECTOR_MUZZLE_COLOR` (0.12 radius, magenta) and updated `update_pos_render` to display a socket indicator at the projector launch muzzle whenever gas pressure and kinetic beam levels are zero.
2. **Kinetic Wavefront Transition Synchronization (`scripts/flow/flow-engine.lua`):** Enqueued position render updates in `flow_engine.step` when muzzle kinetic levels activate or recede, seamlessly hiding the idle socket dot in favor of the active kinetic guide beam and restoring it when unpowered or disabled.


### Revision: Electromagnetic Projector Payload Identity Gatekeeping & Intake Rejection
**Date:** 2026-09-11 11:49 EDT
**Context:** Electromagnetic Projectors previously allowed non-electromagnetic capsules to enter their intake ports, causing unlaunchable payloads to become permanently trapped at the intake dock because muzzle routing prevented pressure evacuation. This revision enforces strict electromagnetic payload gatekeeping at the intake threshold and allows non-electromagnetic vessels to fall through to pressure routing so reverse pressure can extract them.
**Key Changes:**
1. **Electromagnetic Classification Specification (`scripts/capsules/capsule-definitions.lua`):** Added explicit `is_electromagnetic = true` metadata to `electromagnetic-capsule` and implemented `capsule_definitions.is_electromagnetic` for prototype name and table queries.
2. **Active Capsule Identification (`scripts/capsules/capsule-manager.lua`):** Added `capsule_manager.is_electromagnetic` to evaluate active capsule storage records and fallback prototype specifications by capsule ID.
3. **Intake Threshold Gatekeeping (`scripts/capsules/capsule-runner.lua`):** Updated `is_hop_valid` to resolve target machine units via numeric flow descriptors and device settings tables, rejecting non-electromagnetic capsules from entering projector intake ports or kinetic trajectories.
4. **Launch Dispatch Fallthrough (`scripts/capsules/capsule-runner.lua`):** Inline-guarded the projector muzzle launch check behind `is_electromagnetic_capsule(capsule)`, allowing invalid capsules to bypass ballistic launch and naturally fall through to pressure routing so vacuum can pull them back into the tube network.
5. **Capsule Type Injection Tracking (`scripts/capsules/capsule-runner.lua`):** Populated `capsule_type` directly onto motion records during hub injection for instantaneous in-memory type validation.


### Revision: EM Projector Clearance for Cliffs and Elevated Rails
**Date:** 2026-09-11 13:05 EDT
**Context:** EM projector kinetic beams were previously obstructed by natural cliff terrain and overhead elevated rail spans. These changes exempt cliffs and elevated rail tracks from line-of-sight occlusion while preserving physical collision against ground-level rail pillars and ramps.
**Key Changes:**
1. **Ignorable Obstruction Filtering (`scripts/flow/flow-engine.lua`):** Registered `cliff`, `elevated-straight-rail`, `elevated-curved-rail-a`, `elevated-curved-rail-b`, and `elevated-half-diagonal-rail` into `IGNORABLE_TYPES`, preventing these entities from truncating beams or triggering queue-driven recession while leaving `rail-support` and `rail-ramp` active as physical obstacles.
2. **Active Trajectory Wake-up Guard (`scripts/flow/flow-engine.lua`):** Added a one-time migration flag (`storage.kinetic_rail_cliff_fixed`) in `flow_engine.step` that enqueues all existing kinetic endpoints into `storage.flow_queue`, immediately extending previously blocked projector beams across cliffs and elevated tracks.


### Revision: Dynamic Gate Occlusion and Wakeups for EM Kinetic Beams
**Date:** 2026-09-11 13:50 EDT
**Context:** Closed gates previously obstructed EM kinetic projector beams indefinitely with no mechanism to pass through when opened, and gate state changes did not alert intersecting trajectories. This update enables transparent kinetic routing through open gates and dynamically triggers advance or recession waves when gate doors open or shut.
**Key Changes:**
1. **Gate Obstruction Filtering (`scripts/flow/flow-engine.lua`):** Updated `check_tile_obstruction` to classify gate entities as ignorable non-blocking obstacles whenever `cand.is_closed()` is false, permitting kinetic trajectories to extend through open doorways.
2. **State Transition Wakeups (`scripts/flow/flow-engine.lua`):** Linked gate open/closed transition detection in `step()` to `notify_beam_obstruction_changed`, automatically queueing upstream nodes, clearing endpoints, and waking parked capsules when doors open or close.
3. **Active Gate Registration Lifecycle (`scripts/flow/flow-engine.lua`):** Extended `build_events` and `init_storage()` to index all standalone and perimeter gate entities into `storage.active_gates` so their state changes are continuously monitored regardless of direct pneumatic grid connection.