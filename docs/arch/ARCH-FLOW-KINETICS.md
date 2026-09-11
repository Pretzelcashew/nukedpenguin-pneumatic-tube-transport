# ARCH-FLOW-KINETICS.md - Flow v2, Sensing Wavefront & Kinetic Beams
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Event-Driven Delta Wavefront Engine, Direction-Scoped Kinetic Trajectories, Fence/Gate Interoperability

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-defs.lua` | `scripts/flow/` | Flow port definition registry. Resolves `ghost_name` transparently for ghost entities while bypassing active circuit signal reads. Explicitly replaces overloaded `transmit` with domain-specific transmission flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`, `kinetic_transmit`). Registers `pneumatic-projector` port definitions: cardinal launch muzzle configured strictly for kinetic routing (`kinetic_transmit = true`, `is_muzzle = true`) with complete pneumatic/sensing isolation (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`); three passive hub-style intake ports (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`). Supports dynamic launch muzzle orientation lookups across built and ghost entities (`storage.ghost_by_pos`). Registers `pneumatic-capsule-counter` sensing ports (`sense = 15`, `sense_transmit = false`, `pressure_transmit = false`, `capsule_transmit = false`). Registers vanilla defensive ports for `stone-wall` (Group 1 North/South, Group 2 West/East) and `gate`. Restricts `port_defs.registered_names` strictly to dedicated structures. | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `flow-engine.lua`, `capsule-runner.lua`, `diverter-renderer.lua`, `counter-range.lua`, `active-device-scanner.lua` |
| `flow-engine.lua` | `scripts/flow/` | Consolidated Event-Driven Wavefront Engine, Spatial Grid Topology Manager, Kinetic Trajectory Engine & Fence Gate Interoperability Controller. Maintains $O(1)$ spatial coordinate lookup (`flow_grid`, `flow_nodes`, `flow_connections`) keyed by `surface@x,y`. Supresses blueprint ghost simulation (`entity-ghost`). Unified delta wavefront queue (`storage.flow_queue`, `storage.counter_queue`, `BATCH_SIZE = 50`) propagating gas pressure flow levels (+10 to +1, -10 to -1), counter sensing range levels (15 decaying to 1), and kinetic beam levels (seed 100 decaying to 0) with 0-tick idle queue sleep. Kinetic trajectories utilize direction-scoped port keys (`"kinetic:<unit>:<dx>,<dy>:<dist>"`). Dual-tier kinetic topology: minor intermediate nodes (`dist % 5 ~= 0`, `is_minor_kinetic = true`, `capsule_transmit = false`) for continuous tile footprint mapping (`storage.kinetic_beam_tiles`) and occlusion interception; prominent nodes (`dist % 5 == 0` or endpoints, `is_prominent_kinetic = true`, `is_beam_node = true`, `capsule_transmit = true`) forming the 5-tile ballistic hop chain. Demotes temporary endpoints back to minor status when obstructions are removed and beams regrow up to `MAX_BEAM_DISTANCE = 500`. Ray-box line-of-sight intersection (`notify_beam_obstruction_changed`, `flow_engine.check_tile_obstruction`) ignores non-blocking entities via `IGNORABLE_TYPES` (resources, corpses, units, combat robots, landmines, proxies, cliffs, and overhead elevated rails while retaining collision against rail supports and ramps). Dynamically treats open gates (`cand.is_closed() == false`) as non-blocking and alerts intersecting trajectories upon door state transitions. Rotations and power cuts enqueue muzzle tiles to trigger natural 1-tile/tick queue-driven recession; deconstruction triggers instant node purges (`handle_object_destroyed`). Alt-Mode rendering: per-player isolated registries (`storage.kinetic_renders[player_index]`) displaying 0.08r minor dots, 0.16r prominent markers, endpoint target/hazard rings scaled by quality, 0.12r cyan dots at active projector zero-pressure intake sockets, and 0.12r magenta dots (`PROJECTOR_MUZZLE_COLOR`) at idle/unpowered projector launch muzzles synchronized to hide when active beams ignite. Handles wall single-axis locking (`storage.wall_locked_group`), terminator gate cutoffs (`storage.gate_cutoff_states`), soft-registry discovery, throttled research activation, research reversal, reactive reorientation, and script-raised entity destruction (`defines.events.script_raised_destroy`). | `flow_engine.register_events()`<br>`flow_engine.init_storage()`<br>`flow_engine.connect_entity(entity)`<br>`flow_engine.disconnect_entity(entity)`<br>`flow_engine.step(tick)`<br>`flow_engine.enqueue_unit_ports(unit)`<br>`flow_engine.draw_flow(...)`<br>`flow_engine.clear_flow_renders(...)`<br>`flow_engine.handle_object_destroyed(...)`<br>`flow_engine.handle_capsule_destroyed(...)`<br>`flow_engine.handle_interop_research_reversed()`<br>`flow_engine.handle_entity_reorientation()`<br>`flow_engine.check_tile_obstruction()`<br>`flow_engine.notify_beam_obstruction_changed()` | `port-defs`, `debug-manager`, `counter-range`, `control.lua`, `capsule-runner`, `active-device-scanner` |
| `counter-range.lua` | `scripts/counters/` | Lightweight Query API & Territory Partitioning Manager for Capsule Counters delegating queueing and propagation to `flow-engine.lua`. Maintains `storage.counter_levels`, `storage.counter_owners`, `storage.counter_queue`, and `storage.counter_owned_nodes`. Provides $O(1)$ segment territory lookups (`counter_range.get_owned_nodes(counter_unit)`), defensive lazy storage initialization, and status debug command (`/check-counters`). | `counter_range.init_storage()`, `counter_range.get_owned_nodes(counter_unit)`, `counter_range.get_owner(port_key)`, `counter_range.get_level(port_key)` | `flow-engine.lua`, `counter-logic.lua`, `debug-manager.lua` |

---

## 2. Persistent Storage Schema (`storage`)

```lua
  -- Flow v2 Engine Spatial Topology & Propagation Engine Schemas
  flow_grid = {
    ["nauvis@10.5,20.5"] = {
      ["101:1"] = true -- Set of port key strings overlapping spatial coordinate string
    }
  },
  flow_nodes = {
    ["101:1"] = {
      key = "101:1",
      unit_number = 101,
      port_index = 1,
      group = 1,                 -- Port group ID for internal flow isolation
      capsule_transmit = true,   -- Permission for capsule motion across entity
      pressure_transmit = true,  -- Permission for gas pressure flow propagation
      sense_transmit = false,    -- Permission for counter sensing range propagation
      kinetic_transmit = false,  -- Permission for kinetic trajectory propagation
      cross_transit = true,      -- Permission for capsule motion across machine
      emitter = 10,              -- Active flow emission level (+10 output, -10 intake, nil neutral)
      sense = 15,                -- Active sensing range seed level (0 or 15)
      pos = { x = 10.5, y = 20.5 },
      surface = "nauvis",
      entity = LuaEntity,
      -- Kinetic Field Annotations (for direction-scoped kinetic ports)
      is_minor_kinetic = false,      -- Intermediate 1-tile node for occlusion mapping
      is_prominent_kinetic = false,  -- 5-tile ballistic hop node
      is_beam_node = false,          -- Registered node in kinetic ballistic trajectory
      is_endpoint = false,           -- Terminal hop indicator
      hit_receiver = nil,            -- Unit number of aligned receiving projector
      beam_owner = nil               -- Unit number of sending projector
    }
  },
  flow_connections = {
    ["101:1"] = {
      ["102:2"] = true -- Set of active external spatial port connections
    }
  },
  flow_queue = {
    ["101:1"] = true -- FIFO/Set queue of port keys requiring pressure or kinetic evaluation
  },
  flow_levels = {
    ["101:1"] = 10 -- Dynamic calculated flow level integer (-10 .. +10)
  },
  flow_unit_ports = {
    [101] = { "101:1", "101:2" } -- Recorded port keys associated with entity unit number
  },

  -- Kinetic Trajectory Propagation & Alt-Mode Rendering Overlays
  kinetic_levels = {
    ["kinetic:101:0,-1:5"] = 100 -- Distance-decayed kinetic guide level (100 down to 0)
  },
  kinetic_beam_tiles = {
    ["nauvis@10.5,15.5"] = {
      ["kinetic:101:0,-1:5"] = true -- Map of spatial coordinates to active kinetic port keys
    }
  },
  kinetic_renders = {
    [player_index] = {
      ["kinetic:101:0,-1:5"] = {
        circle = LuaRenderObject, -- 0.08r minor dot, 0.16r prominent marker, or endpoint ring
        target_ring = LuaRenderObject
      }
    }
  },
  kinetic_rail_cliff_fixed = true, -- Migration flag: re-enqueued endpoints for cliff/elevated rail clearance

  -- Defensive Structures Interoperability & Dynamic Boundary State
  active_walls = { [unit_number] = LuaEntity },              -- Physical stone-wall entities linked to network
  active_gates = { [unit_number] = LuaEntity },              -- All physical gate entities monitored for state changes
  gate_open_states = { [unit_number] = true },               -- Open/closed polling cache for terminator gates
  gate_cutoff_states = { [unit_number] = true },             -- Outer boundary terminator cutoff state tracking
  wall_locked_group = { [unit_number] = 1 },                 -- Active locked port group ID (1 = N/S, 2 = W/E)
  soft_interop_registry = { [unit_number] = LuaEntity },     -- Pre-research touching boundary walls/gates
  interop_activation_queue = { [unit_number] = LuaEntity },  -- Rate-limited activation queue (10/tick)
```

---

## 3. Core Algorithms & Operational Mechanics

### 5.1 Flow v2 Wavefront Engine, Domain Isolation & Sensing Unification
1. **$O(1)$ Spatial Grid Topology:** Entities register port nodes onto `storage.flow_nodes` and key tile positions into `storage.flow_grid` via formatted coordinate keys (`surface@x,y`). Adjacent matching ports form bidirectional edges in `storage.flow_connections`. Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent structures without global graph scans.
2. **Explicit Domain Transmission Isolation:** Port definitions specify explicit domain booleans (`capsule_transmit`, `pressure_transmit`, `sense_transmit`, `kinetic_transmit`). Active machines explicitly set flags to isolate gas pressure and sensing ranges while permitting mechanical capsule or kinetic flight.
3. **Unified Pressure, Sensing & Kinetic Wavefront Step:** Replaces global graph sweeps with a multi-domain 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue` (pressure & kinetic levels) and `storage.counter_queue` (sensing range levels). Kinetic trajectories advance and recede through this queue identically to gas pressure.
4. **Deterministic Territory Tie-Breaking:** Equal-distance sensing wavefront collisions (`cand_level == max_cand_level`) resolve deterministically using lowest entity `unit_number` tie-breaking, guaranteeing contiguous counter territory splits across shared tube networks.
5. **0-Tick Queue Sleep:** When no flow, sensing, or kinetic levels change, queues empty. On subsequent ticks, `flow_engine.step()` returns on line 1 in 0.00 ms CPU time with zero Lua GC allocations.
6. **Natural 1-Tile-per-Tick Recession Waves:** Disconnecting, rotating, or unpowering machines enqueues root ports without pre-wiping downstream levels, triggering frame-by-frame 1-tile-per-tick recession waves.
7. **Decoupled Overlay Rendering:** Alt-Mode pressure flow overlays (`draw_flow`, `clear_flow_renders`), kinetic beam overlays, and counter range overlays operate independently.

### 5.18 Pneumatic Fence Gate & Wall Interoperability, Wavefront Discovery & Dynamic Terminator Cutoff
1. **Vanilla Defensive Interoperability Research:** Researching `pneumatic-fence-gate-interoperability` authorizes the flow engine to incorporate vanilla `stone-wall` and `gate` entities into pneumatic routing without modifying base entity prototypes.
2. **Dual-Channel Wall Ports & Axis Locking:** Walls feature 4 boundary ports split into two isolated orthogonal groups. Applying pressure flow ($P \ne 0$) or counter sensing ($S > 0$) engages an exclusive directional axis lock (`storage.wall_locked_group[unit_number] = group_id`), disabling transmission on the idle pair. Depressurization clears the lock, restores transmission flags, and wakes queued capsules.
3. **Terminator Gate State Cutoff & Sensing Persistence:** When an outer boundary terminator gate opens, `capsule_transmit` and `pressure_transmit` flags are disabled to contain cargo and gas while leaving `sense_transmit = true` intact, preserving Capsule Counter territorial ownership and signal emission. Closing any gate restores all transmission flags.
4. **Dynamic Terminator Boundary Sync:** `storage.gate_cutoff_states` monitors `(is_open and is_gate_terminator)` during background steps. Placing, rotating, or deconstructing adjacent gates dynamically applies or lifts terminator cutoffs.
5. **Reactive Grid-Touch & Lazy Discovery:** Built defensive structures touching registered ports connect immediately. Open boundary wavefront propagation discovers and connects adjacent walls tile-by-tile within the queue without recursive flood-fills.
6. **Boundary Soft-Registry & Throttled Activation:** Defensive structures placed adjacent to flow prior to research are indexed into `storage.soft_interop_registry`. Completing research migrates entities into `storage.interop_activation_queue` (drained at 10/tick).
7. **Research Reversal & Reactive Reorientation:** Reversing research cleanly severs boundary edges and demotes depressurized walls/gates to soft storage. Rotating or flipping gates and walls reconnects aligned structures and disconnects misaligned ones dynamically.

### 5.20 Blueprint Ghost Simulation Exclusion & Physical Entity State Decoupling
1. **Flow Grid Ghost Exclusion:** `flow_engine.connect_entity` early-exits if `entity.name == "entity-ghost"`. Blueprint ghost tubes, walls, gates, counters, and projectors do not create port nodes, channel pressure, or display phantom overlays.
2. **Decoupled C++ State Polling:** Ghost gates, counters, and projectors bypass runtime polling tables (`storage.active_gates`, `storage.active_counters`, `storage.active_projectors`), preventing C++ method assertion crashes.

### 5.22 Electromagnetic Projector: Unified Kinetic Wavefront Propagation & Dual-Tier Node Topology
1. **Unified Flow Wavefront Integration:** Kinetic beam propagation is integrated directly into the core delta wavefront queue (`storage.flow_queue`, `flow_engine.step`), advancing and receding tile-by-tile at 1 tile per tick with 0-tick idle queue sleep.
2. **Direction-Scoped Node Topology:** Port keys use direction-scoped identifiers (`"kinetic:<unit>:<dx>,<dy>:<dist>"` with `port_index = 100 + dist`). This prevents key collisions during entity rotation, allowing obsolete trajectories to smoothly drain and recede while new directions advance without orphaned nodes.
3. **Dual-Tier Kinetic Node Classification:**
   - **Minor Nodes (`dist % 5 ~= 0`):** Registered with `is_minor_kinetic = true`, `capsule_transmit = false`. Indexed in `storage.flow_nodes`, `storage.flow_grid`, and `storage.kinetic_beam_tiles` for continuous building occlusion detection and footprint mapping.
   - **Prominent Nodes (`dist % 5 == 0` or endpoints):** Registered with `is_prominent_kinetic = true`, `is_beam_node = true`, `capsule_transmit = true`. Form the sequential 5-tile ballistic hop chain in `storage.flow_connections`.
4. **Dynamic Endpoint Demotion on Advance:** When obstructions are removed and the beam advances, former temporary endpoints that do not align with natural hop intervals (`dist % 5 ~= 0`) have `is_endpoint` and `hit_receiver` cleared, cleanly demoting `is_prominent_kinetic`, `is_beam_node`, and `capsule_transmit` back to false.
5. **Ray-Box Line-of-Sight & Obstacle Interception:** `flow_engine.check_tile_obstruction` and `notify_beam_obstruction_changed` perform cardinal ray-box intersection scans against placed structures. Building over an active beam initiates queue-driven recession back to the obstacle; removing an obstruction clears terminal tags and re-propagates the beam up to `MAX_BEAM_DISTANCE = 500`.
6. **Ignorable Obstruction Filtering & Cliff/Elevated Rail Clearance:** `IGNORABLE_TYPES` (`resource`, `corpse`, `character-corpse`, `unit`, `fish`, `combat-robot`, `land-mine`, circuit proxies, `cliff`, `elevated-straight-rail`, `elevated-curved-rail-a`, `elevated-curved-rail-b`, and `elevated-half-diagonal-rail`) are evaluated via exact $O(1)$ set lookups, allowing kinetic trajectories to pass freely across ore patches, corpses, cliffs, and beneath overhead elevated rail lines without occlusion. Physical ground obstructions (`rail-support`, `rail-ramp`) strictly retain beam collision. Migration flag `storage.kinetic_rail_cliff_fixed` re-enqueues existing endpoints on boot to automatically extend previously blocked beams across cleared obstacles. Listens to `defines.events.script_raised_destroy` for programmatic container cleanups.
7. **Dynamic Gate Occlusion & Trajectory Alerting:** `flow_engine.check_tile_obstruction` queries intersecting gates; if `cand.is_closed() == false`, the gate is classified as ignorable, permitting kinetic trajectories to pass freely through open doorways. Monitored gates in `storage.active_gates` compare open/closed transitions in `flow_engine.step()`; changes immediately invoke `notify_beam_obstruction_changed`, enqueuing upstream nodes, clearing previous endpoints, waking parked capsules, and triggering dynamic advance or recession waves.
8. **Queue-Driven Recession on Rotation & Brownouts:** Rotating or unpowering a projector unlinks the muzzle from Tile 1 and enqueues Tile 1 into `storage.flow_queue`, receding the old beam at 1 tile per tick while the new muzzle vector advances forward. Synchronous instant purges are strictly scoped to entity destruction in `handle_object_destroyed`.
9. **Passive Intake Port Parity & Isolation:** Launch muzzles operate with strict kinetic routing (`kinetic_transmit = true`, `is_muzzle = true`) and pneumatic/sensing isolation (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`). Intake ports operate with hub-style passive dock parity (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`), entering incoming capsules freely without vacuum draw or false emitter evaluation.
10. **Idle Launch Muzzle Alt-Mode Overlay & Wavefront Sync:** Defined `PROJECTOR_MUZZLE_COLOR` (radius = 0.12, magenta). `update_pos_render` displays an idle socket dot at the projector launch muzzle position whenever gas pressure and kinetic guide levels are zero. State transitions in `flow_engine.step` enqueue position render updates when kinetic levels activate or recede, seamlessly hiding the idle socket dot in favor of the active kinetic guide beam and restoring it when unpowered, disabled, or rotated.

---

## 4. Visual Overlay Specifications (Alt-Mode & Scripts)

| Render Target Pass | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :---: | :--- |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Kinetic minor node dot: renders subtle filled dot (`radius = 0.08`, holmium magenta scaled by quality tier) on intermediate 1-tile trajectory steps. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Kinetic prominent hop marker: renders charged circle (`radius = 0.16`, `width = 2`, quality-scaled color) every 5 tiles along active beams. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Kinetic endpoint indicator: renders target ring (`radius = 0.35`, cyan/green for aligned receivers, coral hazard for open-air or severed terminations). |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Projector passive intake overlay: renders filled cyan dot (`radius = 0.12`, `PROJECTOR_INTAKE_COLOR`) on zero-pressure non-muzzle intake sockets. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Projector idle muzzle overlay: renders filled magenta dot (`radius = 0.12`, `PROJECTOR_MUZZLE_COLOR`) on projector launch muzzle coordinates when gas pressure and kinetic beam levels are both zero. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Counter sensing range overlay: renders filled owner color dot (`radius = 0.12`) on owned tube nodes. |
| *Default Script Layer* | Text | `rendering.draw_text` | **Yes** | Counter sensing range overlay: renders sensing range level integer (`15` down to `1`, white text, `scale = 0.65`) centered above tube nodes. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Spatial junction pressure overlay (`pos_key`): renders exactly 1 pressure marker circle per tile (radius = 0.15, cyan/blue for positive pressure, orange/red for intake vacuum) using dominant pressure magnitude (`math.abs(level)`). |
| *Default Script Layer* | Text | `rendering.draw_text` | **Yes** | Spatial junction pressure overlay (`pos_key`): renders exactly 1 pressure integer level text (`-10` to `+10`, white text, `scale = 0.7`) above junction circles. |
| *Default Script Layer* | Line | `rendering.draw_line` | **Yes** | Renders flow vector connection lines (`width = 3`, cyan/orange) between adjacent connected tube ports (suppressing zero-length vector lines). |