# Electromagnetic Projector: Polishing Pass & Architectural Alignment Specification

## High Concept & Invariants
- **Role:** Align the Electromagnetic Projector facility with core mod invariants, stripping away pump/diverter emulation, replacing synchronous raycasts with queue-driven incremental wavefront propagation, replacing the overt solid laser beam with dual-tier discrete node rendering, and eliminating Alt-Mode visual render leaks on deconstruction.
- **Core Invariant 1 (Hub-Style Passive Pneumatic Interface):** Projectors have zero pneumatic air pressure generation ($P = 0$). Intake ports behave identically to `capsule-hub` ports (`pressure_transmit = false`, `sense_transmit = false`, `emitter = 0`, `capsule_transmit = true`). They interface with external tubes purely as passive endpoints without stealing the role of pumps or diverters.
- **Core Invariant 2 (Flow-Queue Incremental Wavefront):** Kinetic beam trajectories are **never** evaluated in a single instant synchronous loop. Beam growth and recession advance step-by-step through the established `flow_engine` delta wavefront queue at 1 tile per tick, entering 0-tick idle queue sleep once steady-state equilibrium is achieved.
- **Core Invariant 3 (Dual-Tier Kinetic Node Topology):**
  - **Minor Kinetic Nodes (Every 1 tile):** 1-tile spatial nodes along the trajectory used strictly for building collision/occlusion detection and step-by-step wavefront propagation.
  - **Prominent Kinetic Nodes (Every 5th tile: 5, 10, 15, etc.):** Flagged as major hop destinations for ballistic capsule flight in `capsule-runner.lua`.
- **Core Invariant 4 (Discrete Node Overlays, No Overt Solid Laser):** Alt-Mode rendering displays subtle, small kinetic dots at minor 1-tile nodes and prominent charged markers at every 5th hop node, preserving visual clarity instead of rendering an overt solid beam across the landscape.
- **Core Invariant 5 (Absolute Destruction Lifecycle Purge):** Deconstructing, mining, killing, or sandbox-wiping a projector immediately destroys all associated Alt-Mode render objects via `rendering.destroy()` and cleanly recedes/unregisters kinetic nodes.

---

## Multi-Agent Delegation Stages

```
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: Passive Port Geometry & Hub Interface Parity                  │
│ (Instance 1: Strip air pressure emission, passive tube intakes)        │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: Flow-Queue Kinetic Wavefront & Dual-Tier Node Topology        │
│ (Instance 2: 1t/tick incremental growth, minor vs prominent nodes)     │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: Discrete Alt-Mode Visuals & Deconstruction Lifecycle Purge    │
│ (Instance 3: Minor dots + 5th-node markers, deconstruct render cleanup)│
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: Ballistic Runner Prominent Hops & Occlusion Interception      │
│ (Instance 4: 5-tile prominent hops, minor node cutoffs, catch parity)  │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Task Stage 1: Passive Port Geometry & Hub Interface Parity
*Assign to: Instance 1*

- **Objective:** Reconfigure the Electromagnetic Projector’s pneumatic tube interface to be strictly passive like a `capsule-hub`, eliminating any air pressure emission or propagation.
- **Scope & What to Deliver:**
  - Audit `port-defs.lua`: Strip any air pressure emission (`emitter = 0`) and disable pressure bridging (`pressure_transmit = false`, `sense_transmit = false`) on all intake ports.
  - Ensure the 3 passive intake ports match `capsule-hub` container port definitions (`capsule_transmit = true`, `pressure_transmit = false`, `sense_transmit = false`, `emitter = 0`).
  - Active muzzle port: Configured strictly for kinetic flow (`kinetic_transmit = true`), with complete isolation from air pressure (`pressure_transmit = false`, `sense_transmit = false`, pneumatic `emitter = 0`).
  - Audit `projector-settings.lua` and `active-device-scanner.lua`: Verify the projector does not push or balance pneumatic air levels ($P$) into adjoining tube networks. Capsules must be pushed into the projector by external pressurized tubes or siphon lines, exactly as they enter a capsule hub.
- **Acceptance Criteria:**
  - Connecting a tube to a projector does not increase or decrease tube air pressure ($P = 0$ emitted).
  - Alt-Mode flow vectors and pressure numbers on adjacent tubes reflect purely the surrounding network's pressure.
  - Projector functions purely as a passive intake and kinetic launch muzzle.
- **Suggested File Request for Instance 1:**
  ```text
  filename:"port-defs.lua" OR filename:"projector-settings.lua" OR filename:"active-device-scanner.lua" OR filename:"pneumatic-projector.lua"
  ```

---

### Task Stage 2: Flow-Queue Kinetic Wavefront & Dual-Tier Node Topology
*Assign to: Instance 2*

- **Objective:** Eliminate the synchronous 50-tile raycast. Implement incremental, queue-driven kinetic wavefront propagation and dual-tier kinetic node topology in `flow-engine.lua`.
- **Scope & What to Deliver:**
  - Remove synchronous instant raycasting loops from `update_projector_beam`.
  - Integrate kinetic beam propagation directly into the established `flow_engine` delta wavefront engine (`storage.kinetic_queue` or unified wavefront queue in `flow_engine.step`).
  - Incremental 1-tile-per-tick growth: When powered and enabled, the muzzle enqueues the first node. Each step tick evaluates the next tile in line of sight for physical obstacles/buildings:
    - **Minor Kinetic Nodes (Every 1 tile):** Registered in `storage.flow_nodes` and `storage.flow_grid` with `is_kinetic = true`, `is_minor_kinetic = true`. Used for continuous building occlusion detection and wavefront propagation.
    - **Prominent Kinetic Nodes (Every 5th tile: 5, 10, 15...):** Flagged with `is_prominent_kinetic = true`. These nodes serve as discrete hop targets for capsule movement.
  - Max distance termination: Propagation halts upon reaching max range (base 50 tiles, scaled by machine quality) or when an impassable structure is encountered.
  - Queue-driven recession: When unpowered, disabled by circuit condition, or obstructed, the beam recedes step-by-step through queue drainage rather than instant deletion.
- **Acceptance Criteria:**
  - Beam grows tile-by-tile across successive ticks rather than in a single heavy frame spike.
  - Nodes at intermediate tiles are tagged as minor; every 5th node is explicitly flagged as prominent.
  - Placing an obstacle in an active beam halts propagation at that exact minor node and triggers recession for downstream nodes.
- **Suggested File Request for Instance 2:**
  ```text
  filename:"flow-engine.lua" OR filename:"port-defs.lua"
  ```

---

### Task Stage 3: Discrete Alt-Mode Visuals & Deconstruction Lifecycle Purge
*Assign to: Instance 3*

- **Objective:** Replace the overt continuous solid laser beam with discrete node visuals, and resolve the render object leak when deconstructing projectors.
- **Scope & What to Deliver:**
  - Alt-Mode visual redesign in `flow-engine.lua`:
    - Render subtle, small kinetic dots (`radius = 0.08`, holmium magenta) on **minor kinetic nodes** (1-tile spacing).
    - Render distinct, charged prominent markers (`radius = 0.22`, glowing border, quality-tinted) on **prominent kinetic nodes** (every 5th tile).
    - Draw lightweight directional connection segments strictly between prominent hop nodes, removing the heavy solid laser line over minor nodes.
  - Render tracking and deconstruction lifecycle fix:
    - Index all kinetic render IDs under `storage.beam_renders[projector_unit_number]`.
    - Hook into all entity destruction pathways (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`, `on_space_platform_mined_entity`, and `defines.events.on_object_destroyed`).
    - When a projector is deconstructed, marked for deconstruction, mined, killed, or sandbox-wiped, immediately iterate through and destroy all associated visual render objects via `rendering.destroy()` and purge `storage.beam_renders[unit_number]`.
- **Acceptance Criteria:**
  - Alt-Mode displays small kinetic dots on minor nodes and prominent charged markers every 5 tiles, without an overt solid laser beam.
  - Deconstructing or mining a projector immediately wipes all trajectory dots, hop markers, and endpoint indicators with zero lingering renders.
  - Sandbox deletion wipes all kinetic rendering objects instantly without orphaned IDs.
- **Suggested File Request for Instance 3:**
  ```text
  filename:"flow-engine.lua" OR filename:"debug-manager.lua" OR filename:"proxy-manager.lua"
  ```

---

### Task Stage 4: Ballistic Runner Prominent Hops & Occlusion Interception
*Assign to: Instance 4*

- **Objective:** Synchronize `capsule-runner.lua` with 5-tile prominent hop nodes, integrate minor node obstacle cutoffs, and ensure receiver catchment functions with passive tube ports.
- **Scope & What to Deliver:**
  - Hop synchronization: Update ballistic flight logic in `capsule-runner.lua` to hop strictly between **prominent kinetic nodes** (`node.is_prominent_kinetic`), preserving accelerated flight speeds without checking minor nodes for hops.
  - Occlusion cutoff handling: If an intermediate minor node is severed by a newly placed structure mid-flight, update the in-flight capsule's path to terminate at the last valid prominent node or crash-land at the obstacle coordinate via `hub_spill.spill_capsule`.
  - Receiver catchment integration: Ensure captured capsules entering a receiving projector disembark into outbound passive tube lines using standard hub capture semantics, respecting external tube air pressure gradients.
  - Endpoint crash verification: Confirm unaligned endpoints, open-air terminations, and severed lines deploy spill containers safely without orphan tracking states.
- **Acceptance Criteria:**
  - Capsules hop exclusively along prominent 5-tile nodes during beam flight.
  - Building a wall or assembler in the path of an in-flight capsule causes it to crash at the obstruction point rather than phasing through.
  - Successfully captured capsules enter the receiving facility and transition cleanly into passive outbound tubes.
- **Suggested File Request for Instance 4:**
  ```text
  filename:"capsule-runner.lua" OR filename:"capsule-queries.lua" OR filename:"hub-spill.lua"
  ```

---

### Instructions for Next Step
When you are ready to execute:
1. Start a fresh session.
2. Provide this entire document for architectural context.
3. Specify: *"Execute Task Stage 1 (Passive Port Geometry & Hub Interface Parity)"* (or whichever stage you choose to start with).
4. Feed that instance its recommended File Request search string when prompted.