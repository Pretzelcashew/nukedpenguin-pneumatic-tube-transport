Understood. My responsibility here is strictly the **Master Architecture & Task Specification**, creating the exact briefing packet you can paste into fresh instances, with each task stage having clear boundaries, acceptance criteria, and specific file requests for that instance to ask for.

Here is the complete multi-agent implementation plan.

---

# Electromagnetic Projector: Master Feature Specification

## High Concept & Invariants
- **Role:** A high-tier Fulgora planetary facility (3x3 footprint) that accelerates and launches `electromagnetic-capsule` payloads through open air along an unobstructed line-of-sight beam.
- **Energy Profile:** Heavy electrical demand fitting Fulgora’s lightning economy (3 MW passive idle drain, 9 MW active draw/recharge during projection).
- **Core Invariant 1 (Strict Payload Identity):** Only `electromagnetic-capsule` payloads may enter or traverse the projector beam.
- **Core Invariant 2 (Kinetic Domain Isolation):** Uses a distinct `kinetic_transmit` / kinetic pressure domain. It does not interact with, dilute, or balance against standard pneumatic air pressure ($P$) or counter sensing wavefronts ($S$). Cross-cutting kinetic beams from different projectors pass through each other without interference.
- **Core Invariant 3 (Physical Line of Sight):** Kinetic flow travels in open space across terrain. Any placed structure, obstacle, or cliff immediately severs the beam at the collision tile.
- **Core Invariant 4 (Terminal Outcomes):**
  - If the kinetic beam endpoint contacts *any* part of a receiving EM Projector’s 3x3 footprint, the capsule is safely caught and injected into that receiver's local pneumatic tube network.
  - If the beam terminates in open air (or is severed mid-flight by an obstruction), the payload crash-lands at the end of the line, spilling items via standard spill mechanics.
- **Core Invariant 5 (Quality Scaling):** Higher machine quality increases kinetic pressure and beam projection distance (base 50 tiles up to higher tiers).

---

## Multi-Agent Delegation Stages

```
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: Prototypes, Visuals & Fulgora Economics                       │
│ (Instance 1: Entity graphics scaling, proxy prototype, recipe & tech)  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: Kinetic Flow Domain & Line-of-Sight Simulation                │
│ (Instance 2: Port definitions, kinetic wavefront, building blockage)   │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: Device State, Port Topology & Background Scanner Hooks        │
│ (Instance 3: Power validation, muzzle selection, proxy linkage)        │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: Ballistic Runner, Receiver Capture & Crash Spillage           │
│ (Instance 4: EM restriction, multi-hop flight, receiver catch & spill) │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 5: Alt-Mode Beam Overlays, Audio-Visuals & Edge Cases            │
│ (Instance 5: Trajectory rendering, particles, deconstruction guards)   │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Task Stage 1: Prototypes, Fulgora Tech Tree & Economics
*Assign to: Instance 1*

- **Objective:** Register all data-stage prototypes required for the Electromagnetic Projector and its circuit proxy.
- **Scope & What to Deliver:**
  - Prototype definition for `pneumatic-projector` (or `electromagnetic-projector`) based on `electric-energy-interface` with a 3x3 tile footprint.
  - Tinted and scaled visual composite borrowing the Space Age Electromagnetic Plant aesthetic (scaled from 4x4 down to 3x3).
  - Energy configuration: 3 MW passive idle drain, 9 MW buffer/active launch recharge.
  - Associated circuit proxy prototype (`selection_priority = 60`, `operable = true`, `placeable_by` projector item) matching the mod's proxy conventions.
  - Item prototype (`stack_size = 10`, standardized weight = `50 * kg`, subgroup `pneumatic-transport`).
  - Recipe prototype: requires Fulgora technology tier, crafts in the `electromagnetics` category, using Fulgora components (e.g., holmium plates, supercapacitors, processing units).
  - Technology tree unlock node placed after electromagnetic science and base pneumatic transport prerequisites.
- **Acceptance Criteria:**
  - Machine places cleanly on a 3x3 footprint with centered selection/collision boxes.
  - Proxy places atop the structure with proper selection priority.
  - Recipe cannot be hand-crafted and respects planetary crafting restrictions.
- **Suggested File Request for Instance 1:**
  ```text
  filename:"pneumatic-diverter.lua" OR filename:"pneumatic-capsule-counter.lua" OR filename:"recipe.lua" OR filename:"technology.lua" OR filename:"item.lua"
  ```

---

### Task Stage 2: Kinetic Flow Domain & Line-of-Sight Simulation
*Assign to: Instance 2*

- **Objective:** Add the open-air "Kinetic Flow" transmission domain to the flow engine.
- **Scope & What to Deliver:**
  - Define the `kinetic_transmit` / kinetic pressure domain within `port-defs.lua` and `flow-engine.lua`.
  - Port offset definitions: 4 cardinal edges for the projector (matching diverter connection geometry), distinguishing between standard intake ports and the active kinetic muzzle port.
  - Straight-line ray propagation emanating from the active muzzle port out to a maximum range (base 50 tiles, scaling upward with entity quality).
  - Rapid $O(1)$ line-of-sight validation: evaluate tiles along the beam trajectory; if a physical building or impassable structure blocks a tile, stop beam propagation at that coordinate.
  - Crossing beam isolation: ensure overlapping kinetic beams from multiple projectors coexist at the same spatial coordinates without blending or corrupting each other's flow levels.
  - Generation of discrete traversal hop points (e.g., primary 5-tile hops) along with intermediate collision-check points along the ray.
- **Acceptance Criteria:**
  - Kinetic pressure decays strictly along the projected line.
  - Placing a structure in the beam path dynamically truncates the beam to that point.
  - Intersecting kinetic beams pass through one another seamlessly.
  - Zero interference with standard pneumatic tube pressure or counter sensing levels.
- **Suggested File Request for Instance 2:**
  ```text
  filename:"port-defs.lua" OR filename:"flow-engine.lua"
  ```

---

### Task Stage 3: Device State, Port Topology & Background Scanner Hooks
*Assign to: Instance 3*

- **Objective:** Implement projector state persistence, proxy linkage, muzzle orientation handling, and active scanning integration.
- **Scope & What to Deliver:**
  - Storage schema for projector settings (`storage.projector_settings[unit_number]`): tracks active launch direction, enabled status, power status, and circuit network enable conditions.
  - Proxy manager registration: ensure triple-proxy or single-proxy linkage, wire merging on replacement, and object-destruction cleanup.
  - Scanner integration: hook into `active-device-scanner.lua` (15-tick loop) to verify that the projector has sufficient electrical energy (>3 MW passive baseline). If unpowered or brownout occurs, suppress kinetic beam emission.
  - Port direction controls: allow selecting/rotating the designated launch muzzle (North, East, South, West) while the remaining 3 ports remain passive tube intakes.
  - Support settings copy-paste, blueprint tag serialization (`pneumatic_settings`), and fast-replace state inheritance.
- **Acceptance Criteria:**
  - Cutting power immediately collapses the kinetic beam. Restoring power restores the beam.
  - Rotating the machine or toggling muzzle direction cleanly moves the kinetic emitter and re-routes intake ports.
  - Blueprints preserve active launch direction and circuit settings.
- **Suggested File Request for Instance 3:**
  ```text
  filename:"active-device-scanner.lua" OR filename:"proxy-manager.lua" OR filename:"diverter-settings.lua" OR filename:"pump-settings.lua"
  ```

---

### Task Stage 4: Ballistic Runner, Receiver Capture & Crash Spillage
*Assign to: Instance 4*

- **Objective:** Build the capsule movement, intake restrictions, endpoint catchment, and crash mechanics.
- **Scope & What to Deliver:**
  - Launch gatekeeping: ensure the projector *only* accepts and launches `electromagnetic-capsule` payloads. All other capsule types arriving at intake ports must be rejected or held.
  - Ballistic motion engine: move active capsules along the kinetic beam's hop nodes at accelerated travel speed toward the endpoint.
  - Receiver endpoint catchment: check if the final tile of the beam contacts any part of a receiving EM Projector’s 3x3 footprint. If matched, cleanly catch the capsule and inject it into the receiving machine's connected pneumatic tube lines.
  - Terminal crash landing: if the beam does not terminate on a receiving projector (open ground, cliff, or newly built obstacle blocking flight), trigger the capsule spillage pipeline at the terminal tile, deploying a fast-looting container or dropping contents via `item_transfer_handler`.
  - Mid-flight severance handling: if an obstacle is placed in front of an in-flight capsule before it reaches its destination, the capsule must crash at the point of obstruction rather than phasing through.
- **Acceptance Criteria:**
  - Non-EM capsules cannot enter the launch muzzle.
  - Aligned projectors transfer capsules seamlessly without spilling.
  - Unaligned beams or dead-ends crash-land capsules safely without data corruption or lost items.
- **Suggested File Request for Instance 4:**
  ```text
  filename:"capsule-runner.lua" OR filename:"capsule-definitions.lua" OR filename:"hub-spill.lua" OR filename:"item-transfer-handler.lua"
  ```

---

### Task Stage 5: Alt-Mode Beam Overlays, Visual Effects & Edge Cases
*Assign to: Instance 5*

- **Objective:** Add in-world Alt-Mode visuals, beam rendering, sound/particle triggers, and life-cycle edge-case hardening.
- **Scope & What to Deliver:**
  - Alt-Mode rendering: draw the kinetic beam trajectory (directional flow dots, beam line, and terminal endpoint indicator) using Factorio’s rendering API on appropriate script layers.
  - Quality visual reflection: tint or brighten beam rendering based on the projector’s quality tier.
  - Audio and particle effects: trigger high-energy electrical sound effects and beam particles on capsule dispatch and receiver capture.
  - Edge-case hardening:
    - Sender projector mined/destroyed while capsule is mid-air (capsule continues along projected path and finishes flight or crashes).
    - Receiver projector mined/destroyed while capsule is mid-air (capsule crashes at the coordinates where the receiver used to be).
    - Sandbox cleanup and `/toggle-flow` overlay toggle compatibility in `debug-manager.lua`.
- **Acceptance Criteria:**
  - Alt-Mode displays a crisp, readable beam trajectory without visual clutter or rendering memory leaks.
  - Mining either projector mid-flight never causes nil entity reference errors or game crashes.
- **Suggested File Request for Instance 5:**
  ```text
  filename:"capsule-renderer.lua" OR filename:"diverter-renderer.lua" OR filename:"debug-manager.lua" OR filename:"flow-engine.lua"
  ```

---

### Instructions for Next Step
When you are ready to implement:
1. Start a fresh session.
2. Paste this entire document for architectural context.
3. Specify: *"Execute Task Stage 1 (Prototypes, Fulgora Tech Tree & Economics)"* (or whichever stage you choose).
4. Feed that instance its recommended File Request search string when prompted.