# ARCH-FLOW-KINETICS.md - Flow v2, Sensing Wavefront & Kinetic Beams
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Event-Driven Delta Wavefront Engine, Direction-Scoped Kinetic Trajectories, Autonomous Reticle Probing, Anti-Reticle Wake Reeling, Dynamic Occlusion & Fence/Gate Interoperability

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-defs.lua` | `scripts/flow/` | Flow port definition registry. Resolves `ghost_name` transparently for ghost entities while bypassing active circuit signal reads. Explicitly replaces overloaded `transmit` with domain-specific transmission flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`, `kinetic_transmit`). Registers `pneumatic-projector` port definitions: cardinal launch muzzle configured strictly for kinetic routing (`kinetic_transmit = true`, `is_muzzle = true`) with complete pneumatic/sensing isolation (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`); three passive hub-style intake ports (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`). Supports dynamic launch muzzle orientation lookups across built and ghost entities (`storage.ghost_by_pos`). Registers `pneumatic-capsule-counter` sensing ports (`sense = 15`, `sense_transmit = false`, `pressure_transmit = false`, `capsule_transmit = false`). Registers vanilla defensive ports for `stone-wall` (Group 1 North/South, Group 2 West/East) and `gate`. Implements dual-grid character port resolution (`get_character_port_pos`, `get_character_port`) dynamically snapping moving characters to North/South (half-x, int-y) and East/West (int-x, half-y) beam alignments with directional deadbands (0.15). Restricts character influence footprints (`get_character_influence_positions`) strictly to primary and secondary grid-aligned port coordinates. Restricts `port_defs.registered_names` strictly to dedicated structures. | `port_defs.get_ports(entity)`<br>`port_defs.get_character_port_pos(pos, dir)`<br>`port_defs.get_character_port(character)`<br>`port_defs.get_character_influence_positions(pos, dir)`<br>`port_defs.registered_names` | `flow-engine.lua`, `flow-kinetic.lua`, `flow-renderer.lua`, `capsule-runner.lua`, `diverter-renderer.lua`, `counter-range.lua`, `active-device-scanner.lua` |
| `flow-common.lua` | `scripts/flow/` | Shared low-level graph simulation foundation establishing the single source of truth for capsule waking (`wake_port_parked`), queue management (`enqueue_port`), spatial coordinate hashing (`make_pos_key`), and atomic graph mutations (`destroy_node`, `link_ports`, `sever_ports`) to prevent circular dependency hazards. Evicts destroyed nodes from `storage.flow_queue` immediately in `destroy_node`, and restricts neighbor enqueuing strictly to edges that carried active pressure or sensing while preserving 100% of neighbor capsule waking (`wake_port_parked`). | `flow_common.wake_port_parked(pkey)`<br>`flow_common.enqueue_port(pkey)`<br>`flow_common.destroy_node(pkey)`<br>`flow_common.link_ports(pkey1, pkey2)`<br>`flow_common.sever_ports(pkey1, pkey2)`<br>`flow_common.make_pos_key(surface_name, x, y)` | `flow-engine.lua`, `flow-kinetic.lua`, `capsule-runner.lua`, `capsule-queries.lua` |
| `flow-kinetic.lua` | `scripts/flow/` | Electromagnetic Projector optical reticle probing engine, anti-reticle wake reeling, spatial obstacle hit detection, mid-corridor beam severing, receiver edge catchment, and 5-tile ballistic hop chains delegating graph mutations to `flow-common`. Manages tracked `projector_scope` flights initiated via `on_muzzle_want_emission` and `on_muzzle_stop_emission` hooks, gated behind a 60-tick emission cooldown (`storage.projector_cooldown_heap`). Assigns unique `reticle_id` identifiers to isolate beam BVH leaves from physical projector units. Enqueues invisible `anti_reticle` flights on the binary arrival heap to reel in trail dots and unpin `storage.pinned_corridors` behind retreating wakes. Evaluates line-of-sight obstacle interception via `motion_protocols.scan_open_air_leaf` with 0.5-tile aperture reverse sweeps and muzzle overlap clamping ($d = 0.1$). Partitions directional collisions via `motion_protocols.dispatch_clearance_policy`: reschedules forward horizons via `update_reticle_horizon` and truncates upstream cuts via `truncate_reticle`. Slices mid-corridor cuts into autonomous downstream retreating wakes (`down_id`) with solid body dot suppression via contiguous chain exit scans (`find_obstacle_chain_exit`, `get_obstacle_chain_bounds` with 0.75-tile merge tolerance). Resolves same-tick multi-building placements in a single pass via `queue_reticle_obstacle` and `flush_pending_reticle_obstacles`, maintaining visible heads (`head_render_spec`) on all segments. Gates cyan receiver docking (`RECEIVER_HEAD_SPEC`) strictly upon physical terminal arrival with 0.5-tile narrow-phase native bounding box tolerance, falling back to coral (`DEFAULT_HEAD_SPEC`) on clearance or reticle orphaning. Routes entity mining and destruction (`is_removal == true`) directly to $O(1)$ hash lookups in `storage.blocked_reticles` and `storage.blocked_reticles_by_reg`, completely bypassing spatial BVH queries on entity death. Resumes forward probing on obstacle clearance via `resume_reticle_probing`. Monitors dynamic gate states via `storage.reticle_gates`. Tracks grid-aligned 1x1 character colliders (`storage.character_tiles`) in `step_character_colliders` with boundary escape gating. Coordinates event-driven decaying corridor lifecycles (`storage.decaying_corridors`, `unlink_projector_receiver`, `count_in_flight_capsules`). Exposes localized acyclic render buffer dirtying helpers. Binds acyclically onto `update_projector_flights`. | `flow_kinetic.step_port(pkey, node)`<br>`flow_kinetic.on_muzzle_want_emission(proj_unit, muzzle_dir)`<br>`flow_kinetic.on_muzzle_stop_emission(proj_unit)`<br>`flow_kinetic.handle_obstacle_changed(surface, box, is_removal, removed_entity)`<br>`flow_kinetic.handle_projector_destroyed(unit_number)`<br>`flow_kinetic.handle_reticle_obstacle_cleared(entity)`<br>`flow_kinetic.resume_reticle_probing(rid)`<br>`flow_kinetic.truncate_reticle(rid, obst_dist, obst_entity, collision_pos)`<br>`flow_kinetic.update_reticle_horizon(rid, obst_dist, obst_entity, collision_pos)`<br>`flow_kinetic.queue_reticle_obstacle(rid, obst_entity, entry_d, exit_d, hit_pos)`<br>`flow_kinetic.flush_pending_reticle_obstacles()`<br>`flow_kinetic.find_obstacle_chain_exit(surface, start_pos, dir, start_dist, max_dist)`<br>`flow_kinetic.get_obstacle_chain_bounds(surface, start_pos, dir, start_dist, max_dist)`<br>`flow_kinetic.orphan_reticle(proj_unit)`<br>`flow_kinetic.dock_incoming_reticles_at_projector(entity)`<br>`flow_kinetic.clear_receiver_references(unit_number)`<br>`flow_kinetic.unlink_projector_receiver(proj_unit)`<br>`flow_kinetic.count_in_flight_capsules(proj_unit)`<br>`flow_kinetic.step_character_colliders()`<br>`flow_kinetic.step_cooldown_heap(current_tick)`<br>`flow_kinetic.clear_cooldown(proj_unit)`<br>`flow_kinetic.wake_beam_pointing_at(surface_name, pos)`<br>`flow_kinetic.update_projector_flights` | `flow-engine.lua`, `flow-common.lua`, `flow-renderer.lua`, `motion-protocols.lua`, `trajectory-bvh.lua`, `viewport-bvh.lua`, `timed-motion.lua`, `binary-heap.lua`, `capsule-ballistics.lua`, `projector-settings.lua` |
| `flow-renderer.lua` | `scripts/flow/` | Isolated Alt-Mode visual overlay renderer extracting graphical drawing routines (`draw_circle`, `draw_line`, `draw_text`), color palettes, dominant pressure queries, and per-player render registries (`storage.flow_renders`, `storage.counter_renders`, `storage.kinetic_renders`, `storage.flow_edge_renders`). Clamps pressure level intensity ratios to `MAX_FLOW` using `math.min` to prevent Alt-Mode circle color component overflow when visualizing pressure levels exceeding 10. Filters dominant pressure port evaluations to ignore kinetic nodes, preventing open-air kinetic beam reach levels from rendering as gas pressure numbers or cyan circles. Renders 0.08r minor dots, 0.16r prominent markers, endpoint target/hazard rings scaled by quality, 0.12r cyan dots at active projector zero-pressure intake sockets, and 0.12r magenta dots (`PROJECTOR_MUZZLE_COLOR`) at idle/unpowered projector launch muzzles. Retired 60 Hz visual character feet dots while preserving underlying $O(1)$ physical grid colliders. | `flow_renderer.draw_flow(...)`<br>`flow_renderer.clear_flow_renders(...)`<br>`flow_renderer.update_pos_render(...)`<br>`flow_renderer.destroy_pos_renders(...)`<br>`flow_renderer.update_kinetic_pos_render(...)`<br>`flow_renderer.destroy_kinetic_pos_renders(...)`<br>`flow_renderer.clear_all_renders()` | `flow-engine.lua`, `flow-kinetic.lua`, `debug-manager.lua`, `render-pool.lua` |
| `flow-gate-interop.lua` | `scripts/flow/` | Encapsulated defensive structure interoperability engine. Manages vanilla `stone-wall` dual-channel orthogonal axis locking (`storage.wall_locked_group`), terminator `gate` state tracking and outer boundary containment cutoff sync (`storage.gate_cutoff_states`), pre-research soft-registry discovery (`storage.soft_interop_registry`), throttled research activation queue drainage (`storage.interop_activation_queue` at 10/tick), and zero-equilibrium research reversal demotions. | `flow_gate_interop.handle_wall_gate_connect(...)`<br>`flow_gate_interop.handle_wall_gate_disconnect(...)`<br>`flow_gate_interop.update_wall_locks(...)`<br>`flow_gate_interop.drain_activation_queue(batch_size)`<br>`flow_gate_interop.handle_research_reversed()` | `flow-engine.lua`, `flow-common.lua`, `port-defs.lua` |
| `flow-engine.lua` | `scripts/flow/` | Consolidated Event-Driven Wavefront Engine, Spatial Grid Topology Coordinator & Simulation Core (~720 lines). Maintains $O(1)$ spatial coordinate lookup (`flow_grid`, `flow_nodes`, `flow_connections`) keyed by `surface@x,y`. Suppresses blueprint ghost simulation (`entity-ghost`). Unified delta wavefront queue (`storage.flow_queue`, `storage.counter_queue`, `BATCH_SIZE = 50`) propagating gas pressure flow levels, counter sensing range levels, and kinetic beam levels with 0-tick idle queue sleep. Dynamically scales runtime flow emissions with quality tier (`math.floor(base * (1 + 0.3 * q_level))`) across pumps/diverters (base 10) and counters (base 15). Guards passive graph connection in `connect_entity` to enqueue ports strictly when active pressure, vacuum, sensing range, or emitters are present, keeping ambient unpressurized network time at 0.01 ms (60 UPS). Restricts receiver deconstruction scans strictly to `pneumatic-projector`. Dispatches projector destruction events directly to `flow_kinetic.handle_projector_destroyed` across `handle_object_destroyed` and entity removal listeners to initiate instant reticle wake reeling. Employs teardown deduplication (`is_tracked`) in `handle_object_destroyed` and skips render dictionary cleanup loops when overlays are disabled. Dynamically scales batch limits to 200 items/tick when queue depth exceeds 500. Registers queue inspection commands (`/check-queue`, `/check-flow`, `/clear-queue`). Steps character colliders and cooldown heaps before queue sleep checks. | `flow_engine.register_events()`<br>`flow_engine.init_storage()`<br>`flow_engine.connect_entity(entity)`<br>`flow_engine.disconnect_entity(entity)`<br>`flow_engine.step(tick)`<br>`flow_engine.enqueue_unit_ports(unit)`<br>`flow_engine.handle_object_destroyed(...)`<br>`flow_engine.handle_capsule_destroyed(...)`<br>`flow_engine.check_tile_obstruction()`<br>`flow_engine.notify_beam_obstruction_changed()` | `flow-common.lua`, `flow-kinetic.lua`, `flow-renderer.lua`, `flow-gate-interop.lua`, `port-defs.lua`, `counter-range.lua`, `capsule-runner.lua`, `active-device-scanner.lua`, `debug-manager.lua` |
| `counter-range.lua` | `scripts/counters/` | Territory Partitioning Manager and Event-Driven Territory Indexing API for Capsule Counters delegating queueing and propagation to `flow-engine.lua`. Tracks `storage.counter_levels`, `storage.counter_owners`, `storage.counter_queue`, and `storage.counter_owned_nodes`. Establishes `storage.counter_capsules` to track resident capsule IDs per counter with $O(1)$ transitions (`update_capsule_territory`, `unregister_capsule_territory`) and dynamic boundary synchronization (`handle_port_owner_changed`). Maintains incremental stable summaries (`storage.counter_stable_summary`, `storage.counter_stable_capsules`, `storage.counter_dynamic_capsules`), streaming pre-aggregated signals directly to circuit proxies without periodic C++ entity polling. Exposes `/check-counters`. | `counter_range.init_storage()`<br>`counter_range.get_owned_nodes(counter_unit)`<br>`counter_range.get_owner(port_key)`<br>`counter_range.get_level(port_key)`<br>`counter_range.update_capsule_territory(capsule_id, old_key, new_key)`<br>`counter_range.unregister_capsule_territory(capsule_id)`<br>`counter_range.handle_port_owner_changed(pkey, old_owner, new_owner)` | `flow-engine.lua`, `counter-logic.lua`, `capsule-queries.lua`, `debug-manager.lua` |

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
      emitter = 10,              -- Active flow emission level (+10 output, -10 intake, scaled by quality)
      sense = 15,                -- Active sensing range seed level (15 scaled by quality)
      pos = { x = 10.5, y = 20.5 },
      surface = "nauvis",
      entity = LuaEntity,
      -- Kinetic Field Annotations (for direction-scoped kinetic ports)
      is_minor_kinetic = false,      -- Intermediate 1-tile node for footprint mapping
      is_prominent_kinetic = false,  -- 5-tile ballistic hop node
      is_beam_node = false,          -- Registered node in kinetic ballistic trajectory
      is_endpoint = false,           -- Terminal hop indicator
      hit_receiver = nil,            -- Unit number of aligned receiving projector
      beam_owner = nil               -- Unit number of sending projector (muzzle only)
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
    ["101:1"] = 10 -- Dynamic calculated flow level integer (-MAX_FLOW .. +MAX_FLOW)
  },
  flow_unit_ports = {
    [101] = { "101:1", "101:2" } -- Recorded port keys associated with entity unit number
  },

  -- Surface Spatial Trajectory BVH Trees (Line-of-Sight Beam Occlusion)
  surface_bvh = {
    [surface_index] = {
      root = { ... },              -- Dynamic AABB tree root node
      size = 12,                   -- Total active internal and leaf nodes
      free_nodes = { ... },        -- High-water mark recycling pool stack
      free_count = 4,              -- Available recycled nodes in pool
      leaves_by_key = { ... }      -- Leaf lookup map keyed by "dx,dy:s" or "rem:dx,dy:s"
    }
  },

  -- Projector Scope Probing, Reticles & Autonomous Corridors
  projector_scope = {
    [unit_number] = {
      reticle_id = 1,              -- Unique active reticle identifier
      total_reach = 64,            -- Full emitter potential reach (scaled by quality)
      receiver_unit = 105,         -- Unit number of confirmed aligned receiver chassis
      muzzle_dir = 0,              -- Cardinal emission direction
      start_pos = { x = 10.5, y = 20.5 }
    }
  },
  blocked_reticles = {
    [unit_number] = {
      [reticle_id] = true          -- Map of blocking entity unit numbers to blocked reticle IDs
    }
  },
  blocked_reticles_by_reg = {
    [registration_id] = reticle_id -- Map of script.register_on_object_destroyed IDs to reticle IDs
  },
  reticle_blocked_by = {
    [reticle_id] = unit_number     -- Closest active blocking entity unit number per reticle
  },
  reticle_gates = {
    [reticle_id] = {
      [gate_unit] = LuaEntity      -- Monitored vanilla gate entities along active beam corridor
    }
  },
  pinned_corridors = {
    ["corridor:10:rem:16"] = 1     -- Reference count pinning BVH segments during active flight or wake reeling
  },
  decaying_corridors = {
    ["corridor:10:rem:16"] = {     -- Unlinked corridors decaying until in-transit payloads land/crash
      surface_index = 1,
      reticle_id = 5,
      in_flight_count = 2
    }
  },

  -- Projector Want-Emission Cooldown (60-Tick Rate Limiting)
  projector_cooldown_heap = {
    data = { { id = unit_number, priority = 123456, data = { ... } } },
    indices = { [unit_number] = 1 },
    size = 1
  },
  projector_cooldown_until = {
    [unit_number] = 123456         -- Tick timestamp when projector can emit next positive beam
  },

  -- Discrete 1x1 Grid-Aligned Character Colliders
  character_tiles = {
    [player_index] = {
      surface_name = "nauvis",
      x = 10,                      -- Integer-aligned tile X coordinate
      y = 20                       -- Integer-aligned tile Y coordinate
    }
  },
  character_colliders = {
    ["nauvis"] = {
      ["nauvis@10.5,20.0"] = 1     -- Map of spatial coordinates to colliding player index
    }
  },
  character_last_keys = {
    [player_index] = {
      ["nauvis@10.5,20.0"] = true  -- Set of active 1-node influence coordinate keys per player
    }
  },

  -- Alt-Mode Rendering Registries (flow-renderer.lua)
  flow_renders = {
    [player_index] = {
      ["nauvis@10.5,20.5"] = { circle = LuaRenderObject, text = LuaRenderObject }
    }
  },
  flow_edge_renders = {
    [player_index] = {
      ["101:1->102:2"] = LuaRenderObject -- Directional flow vector line
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
  counter_renders = {
    [player_index] = {
      ["101:1"] = { circle = LuaRenderObject, text = LuaRenderObject }
    }
  },

  -- Defensive Structures Interoperability & Dynamic Boundary State
  active_walls = { [unit_number] = LuaEntity },              -- Physical stone-wall entities linked to network
  active_gates = { [unit_number] = LuaEntity },              -- All physical gate entities monitored for state changes
  gate_open_states = { [unit_number] = true },               -- Open/closed polling cache for terminator gates
  gate_cutoff_states = { [unit_number] = true },             -- Outer boundary terminator cutoff state tracking
  wall_locked_group = { [unit_number] = 1 },                 -- Active locked port group ID (1 = N/S, 2 = W/E)
  soft_interop_registry = { [unit_number] = LuaEntity },     -- Pre-research touching boundary walls/gates
  interop_activation_queue = { [unit_number] = LuaEntity }   -- Rate-limited activation queue (10/tick)
```

---

## 3. Core Algorithms & Operational Mechanics

### 5.1 Flow v2 Wavefront Engine, Domain Isolation & Modular Graph Foundation
1. **$O(1)$ Spatial Grid Topology:** Entities register port nodes onto `storage.flow_nodes` and key tile positions into `storage.flow_grid` via formatted coordinate keys (`surface@x,y`). Adjacent matching ports form bidirectional edges in `storage.flow_connections`. Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent structures without global graph scans.
2. **Centralized Graph Primitives (`flow-common.lua`):** Low-level primitives (`make_pos_key`, `destroy_node`, `link_ports`, `sever_ports`, `enqueue_port`, `wake_port_parked`) are centralized in a shared foundation. Atomic node destruction immediately purges keys from `storage.flow_queue`, severing connected edges and restricting neighbor enqueuing strictly to edges carrying active pressure or sensing while waking 100% of parked capsules.
3. **Explicit Domain Transmission Isolation:** Port definitions specify explicit domain booleans (`capsule_transmit`, `pressure_transmit`, `sense_transmit`, `kinetic_transmit`). Active machines explicitly set flags to isolate gas pressure and sensing ranges while permitting mechanical capsule or kinetic flight.
4. **Unified Pressure, Sensing & Kinetic Wavefront Step:** Multi-domain 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue` (pressure & kinetic levels) and `storage.counter_queue` (sensing range levels).
5. **Deterministic Territory Tie-Breaking:** Equal-distance sensing wavefront collisions (`cand_level == max_cand_level`) resolve deterministically using lowest entity `unit_number` tie-breaking, guaranteeing contiguous counter territory splits across shared tube networks.
6. **0-Tick Queue Sleep:** When no flow, sensing, or kinetic levels change, queues empty. On subsequent ticks, `flow_engine.step()` returns on line 1 in 0.00 ms CPU time with zero Lua GC allocations.
7. **Natural 1-Tile-per-Tick Recession Waves:** Disconnecting, rotating, or unpowering machines enqueues root ports without pre-wiping downstream levels, triggering frame-by-frame 1-tile-per-tick recession waves.
8. **Decoupled Overlay Rendering (`flow-renderer.lua`):** Alt-Mode pressure flow overlays (`draw_flow`, `clear_flow_renders`), kinetic beam overlays, and counter range overlays operate independently via isolated player render registries.

### 5.18 Pneumatic Fence Gate & Wall Interoperability, Wavefront Discovery & Dynamic Terminator Cutoff
1. **Vanilla Defensive Interoperability Research:** Researching `pneumatic-fence-gate-interoperability` authorizes the flow engine to incorporate vanilla `stone-wall` and `gate` entities into pneumatic routing without modifying base entity prototypes. Delegated to `flow-gate-interop.lua`.
2. **Dual-Channel Wall Ports & Axis Locking:** Walls feature 4 boundary ports split into two isolated orthogonal groups. Applying pressure flow ($P \ne 0$) or counter sensing ($S > 0$) engages an exclusive directional axis lock (`storage.wall_locked_group[unit_number] = group_id`), disabling transmission on the idle pair. Depressurization clears the lock, restores transmission flags, and wakes queued capsules.
3. **Terminator Gate State Cutoff & Sensing Persistence:** When an outer boundary terminator gate opens, `capsule_transmit` and `pressure_transmit` flags are disabled to contain cargo and gas while leaving `sense_transmit = true` intact, preserving Capsule Counter territorial ownership and signal emission. Closing any gate restores all transmission flags.
4. **Dynamic Terminator Boundary Sync:** `storage.gate_cutoff_states` monitors `(is_open and is_gate_terminator)` during background steps. Placing, rotating, or deconstructing adjacent gates dynamically applies or lifts terminator cutoffs.
5. **Reactive Grid-Touch & Lazy Discovery:** Built defensive structures touching registered ports connect immediately. Open boundary wavefront propagation discovers and connects adjacent walls tile-by-tile within the queue without recursive flood-fills.
6. **Boundary Soft-Registry & Throttled Activation:** Defensive structures placed adjacent to flow prior to research are indexed into `storage.soft_interop_registry`. Completing research migrates entities into `storage.interop_activation_queue` (drained at 10/tick).
7. **Research Reversal & Reactive Reorientation:** Reversing research cleanly severs boundary edges and demotes depressurized walls/gates to soft storage. Rotating or flipping gates and walls reconnects aligned structures and disconnects misaligned ones dynamically.

### 5.20 Blueprint Ghost Simulation Exclusion & Physical Entity State Decoupling
1. **Flow Grid Ghost Exclusion:** `flow_engine.connect_entity` early-exits if `entity.name == "entity-ghost"`. Blueprint ghost tubes, walls, gates, counters, and projectors do not create port nodes, channel pressure, or display phantom overlays.
2. **Decoupled C++ State Polling:** Ghost gates, counters, and projectors bypass runtime polling tables (`storage.active_gates`, `storage.active_counters`, `storage.active_projectors`), preventing C++ method assertion crashes.

### 5.22 Electromagnetic Projector: Kinetic Beam Engine, Spatial BVH & Receiver Docking
1. **Unified Kinetic Propagation & Muzzle Hooks:** Kinetic beam propagation is coordinated in `flow-kinetic.lua`. Launches trigger `on_muzzle_want_emission` and `on_muzzle_stop_emission` hooks upon positive emission.
2. **Direction-Scoped Node Topology:** Port keys use direction-scoped identifiers (`"kinetic:<unit>:<dx>,<dy>:<dist>"` with `port_index = 100 + dist`). Obsolete trajectories cleanly drain and recede during rotation while new directions advance without orphaned node collisions.
3. **Dual-Tier Kinetic Node Classification:**
   - **Minor Nodes (`dist % 5 ~= 0`):** Registered with `is_minor_kinetic = true`, `capsule_transmit = false`. Indexed in `storage.flow_nodes`, `storage.flow_grid`, and `storage.kinetic_beam_tiles` for continuous building occlusion detection and footprint mapping.
   - **Prominent Nodes (`dist % 5 == 0` or endpoints):** Registered with `is_prominent_kinetic = true`, `is_beam_node = true`, `capsule_transmit = true`. Form the sequential 5-tile ballistic hop chain in `storage.flow_connections`.
4. **Spatial Trajectory BVH Obstacle Hit-Testing:** Placed, rotated, or deconstructed entities query the line-of-sight tree (`storage.surface_bvh[surface_index]:query_box`), replacing map-wide $O(N)$ projector scans with $O(\log N)$ spatial queries.
5. **Natural 1-Tile-per-Tick Queue Recession:** Rotating or deconstructing a projector unlinks the muzzle node and enqueues Tile 1 into `storage.flow_queue`, driving natural 1-tile/tick queue recession across the beam. Scoped `beam_owner` in `storage.flow_nodes` strictly to kinetic launch muzzles, preserving passive intake port coordinates during entity teardown so `flow_renderer.destroy_pos_renders` cleanly purges intake and muzzle dots.
6. **Ignorable Obstruction Filtering & Dynamic Gate Clearance:** `IGNORABLE_TYPES` (resources, corpses, combat robots, landmines, circuit proxies, cliffs, and overhead elevated rails) pass freely without occlusion. Physical ground obstructions strictly collide. Open gates (`cand.is_closed() == false`) are ignorable; gate open/closed state transitions dynamically alert intersecting beams via `flow_kinetic.wake_beam_pointing_at`.
7. **Idle Launch Muzzle Alt-Mode Overlay:** `flow_renderer.update_pos_render` renders a 0.12r magenta dot (`PROJECTOR_MUZZLE_COLOR`) at idle/unpowered launch muzzles when gas pressure and kinetic levels are zero, seamlessly hiding the dot when active beams ignite.

### 5.25 Quality-Scaled Flow & Sensing Emission Propagation
1. **Factorio 2.0 Quality Scaling Formula:** Runtime flow emissions and sensing reach scale dynamically using the standard formula:
   $$\text{emission} = \lfloor \text{base} \times (1 + 0.3 \times \text{quality\_level}) \rfloor$$
2. **Pumps & Diverters:** Base flow emission of 10 scales up to 22 at Legendary (`quality_level = 4`). Applied during entity node connection in `flow_engine.connect_entity` and synchronized across device scanner migrations.
3. **Capsule Counters:** Base sensing range seed of 15 scales up to 33 at Legendary, expanding the sensing radius and owned territory on shared tube networks.
4. **Visual Intensity Clamping:** `flow_renderer.lua` clamps pressure intensity ratios to `MAX_FLOW` using `math.min(1.0, math.abs(level) / 10)` to prevent Alt-Mode circle color component overflow when visualizing pressure levels exceeding 10.

### 5.26 Grid-Aligned Character Kinetic Interception, 1x1 Colliders & Aperture Scanning
1. **Grid-Aligned 1x1 Tile Character Colliders:** Character positions map to integer-aligned 1x1 tile bounding boxes (`[tx, tx + 1] x [ty, ty + 1]`) tracked in `storage.character_tiles`. Movement entirely within the current tile box incurs zero BVH collider updates or reticle recalibrations.
2. **Discrete Boundary Escape Gating:** Reticle adjustments and motion BVH collider updates trigger strictly when a player crosses a grid tile boundary. Passes explicit 1x1 tile bounding boxes for both the evacuated tile (`evac_bb`) and newly entered tile, enabling clean obstacle waking upon departure.
3. **Aperture Reverse Sweep & Muzzle Overlap Clamping:** Launch muzzle aperture scans expand 0.5 tiles backward into the projector chassis footprint, capturing players standing against the perimeter lip. Any obstacle touching or overlapping the launch origin (within 0.5 tiles) clamps to an immediate collision at distance `0.1` (`muzzle_node.pos + dir * 0.1`), rendering an instant coral hazard ring and eliminating deceptive visual shoot-throughs.
4. **Dual-Grid Character Port Resolution:** Moving characters dynamically snap to matching beam axes via `port_defs.get_character_port_pos` and `get_character_port`. Vertical beams evaluate distance against half-x, int-y coordinates; horizontal beams evaluate distance against int-x, half-y coordinates with a 0.15 directional deadband to prevent diagonal walking jitter.
5. **1-Node Influence Footprint:** `port_defs.get_character_influence_positions` restricts the character's collider footprint strictly to primary and secondary grid-aligned port coordinates, eliminating artificial padding that caused kinetic beams to terminate prematurely.
6. **Discrete $O(1)$ Colliders & Wakeups:** `flow_kinetic.check_tile_obstruction` evaluates `storage.character_colliders` in $O(1)$ time. `step_character_colliders` tracks active influence keys in `storage.character_last_keys`, executing 4-cardinal `wake_beam_pointing_at` lookups to intercept incoming beams and unblock preceding endpoints (`d_start - 1`) upon evacuation. Visual feet dots are retired.

### 5.27 Event-Driven Counter Territory Sync & Dynamic Ownership Indexing
1. **Dynamic Wavefront Boundary Synchronization:** `flow_engine.set_port_counter_ownership` dispatches port ownership changes directly to `counter_range.handle_port_owner_changed`.
2. **Territory Capsule Migration:** Expanding or receding wavefronts dynamically migrate resident capsule IDs in `storage.counter_capsules` between rival counters in $O(1)$ time without requiring periodic tube scans.
3. **Clean Teardown Purging:** Deconstructing a Capsule Counter unregisters its territory in `counter_range.lua`, clears owned nodes in `storage.counter_owned_nodes`, and purges memoized stable summaries.

### 5.28 Quiescent Flow Gating, Queue Eviction & Mass Deconstruction Optimization
1. **Passive Graph Connection Gating:** `connect_entity` verifies whether an entity possesses active pressure, vacuum, sensing range, or emitter properties before inserting ports into `storage.flow_queue`. Unpressurized tube grids bypass queue insertion, maintaining ambient script execution at 0.01 ms (60 UPS).
2. **Receiver Deconstruction Optimization:** Scans for downstream receiver references (`flow_kinetic.clear_receiver_references`) are strictly restricted to `pneumatic-projector` units, eliminating multi-million-iteration graph loops when mining tubes or junctions.
3. **Immediate Queue Eviction:** Destroyed nodes are evicted from `storage.flow_queue` on the exact tick of removal in `destroy_node`.
4. **Adaptive Batch Scaling:** If `storage.flow_queue` depth exceeds 500 items (e.g. during massive blueprint deconstruction or placement), `flow_engine.step` dynamically increases the processing limit from 50 to 200 items/tick, settling multi-thousand-node network adjustments within 2–3 seconds.
5. **In-Game Diagnostic Commands:** Registered console diagnostic inspection commands:
   - `/check-queue`: Prints active queue depth and batch processing metrics.
   - `/check-flow`: Displays flow nodes, registered connections, and emitter counts.
   - `/clear-queue`: Flushes the active flow queue in the event of artificial script stalls.

### 5.40 Decoupled Projector Reticle Scope Probing, Tandem Anti-Reticle Wake Reeling & Emission Cooldown
1. **Decoupled Reticle Corridors:** Projector muzzle emission initiates an autonomous `projector_scope` flight assigned a unique `reticle_id`. Reticle corridor ownership is decoupled from the physical projector unit, allowing machines to orphan active beams on rotation, power loss, or deconstruction and fire fresh beams immediately without BVH leaf key collisions.
2. **Chained 16-Tile Scope Probing:** Muzzle emission launches a timed probe flight traversing consecutive 16-tile corridor segments via `handle_projector_scope_arrival` until reaching full emitter reach or colliding with an obstacle. Each completed segment anchors static trail markers and registers leaves into `storage.motion_bvh` and observer viewports.
3. **Invisible Anti-Reticle Temporal Wake Reeling:** Ceasing beam emission or truncating upstream launches an invisible `anti_reticle` flight scheduled onto the binary arrival heap (`storage.kinetic_arrival_heap`). The anti-reticle steps through downstream 16-tile segments at constant speed ($1.2\text{ ticks/tile}$), unpinning `storage.pinned_corridors`, progressively peeling in static trail dots, and recycling BVH leaves via `viewport_bvh.on_segment_removed` upon reaching terminal endpoints.
4. **Tandem Flight & Progressive Dot Peeling:** Advancing reticle heads and trailing anti-reticles operate concurrently in tandem. Trail dots render strictly within the valid spatiotemporal window ($\text{dist\_cleared} \le d \le \text{head\_dist}$), eliminating visual chunk popping. Direct slot indexing (`objects[i] = dot_obj`) prevents Lua `#` array hole collapse when early wake slots are recycled.
5. **60-Tick Emission Cooldown:** A 1-second post-emission rate limiter (`WANT_EMISSION_COOLDOWN_TICKS = 60`) managed via `storage.projector_cooldown_heap` prevents rapid rotation or circuit oscillation from spamming overlapping probe flights. Requests during cooldown update `storage.projector_cooldown_until` and dispatch strictly in the latest machine orientation upon timer expiration in `step_cooldown_heap`. Deconstructing the machine clears pending entries via `clear_cooldown`.

### 5.41 Mid-Corridor Beam Severing, Solid Footprint Exit Scanning & Obstacle Adjacency Bridging
1. **Directional Interception Partitioning (`motion-protocols`):** When an obstacle intersects an active corridor, `motion_protocols.calculate_axis_distance` projects distance along the beam axis and delegates to `motion_protocols.dispatch_clearance_policy`. Obstacles appearing forward of the advancing probe head ($d_{\text{obst}} > d_{\text{current}} + 0.05$) route to `update_reticle_horizon` to reschedule arrival heap deadlines without jumping the reticle head; obstacles at or behind the head ($d_{\text{obst}} \le d_{\text{current}} + 0.05$) route to `truncate_reticle`.
2. **Mid-Corridor Downstream Slice Severing:** Placing an obstacle across an active or stationary beam splits the trajectory. Upstream segments truncate squarely at the near collision face. Downstream open-air segments are detached into an autonomous orphaned reticle (`down_id`) initialized with `status = "retreating"`, carrying over original trail dots and terminal indicators, and re-homing any active in-flight head flight so the severed payload continues forward smoothly.
3. **Contiguous Obstacle Exit Scanning & Solid Body Dot Suppression:** `find_obstacle_chain_exit` and `get_obstacle_chain_bounds` scan through adjacent blocking structures using a 0.75-tile merge tolerance, bridging standard 1x1 entity collision box gaps (0.4 tiles) into a contiguous footprint. Downstream reticles calibrate their `retreat_tick` to the far exit boundary:
   $$\text{retreat\_tick} = \text{game.tick} - \lfloor \text{exit\_dist} \times \text{tpt} \rfloor$$
   completely suppressing trail dot spawning within solid building bodies. The retreating anti-reticle flight spawns squarely at the exit boundary face to reel in the surviving open-air wake.
4. **Zero-Tick Frame-Slice Obstruction Queue:** Multiple obstacle events occurring within the same frame (e.g. dragging defensive walls or pasting multi-tile blueprints) buffer into `storage.pending_reticle_obstacles` via `queue_reticle_obstacle`. `flush_pending_reticle_obstacles` resolves the contiguous obstruction chain in a single pass before render dispatch, eliminating intermediate 1-tile reticle fragments.
5. **Universal Reticle Head Retention:** All reticles—parented, severed, or retreating—maintain a valid `head_render_spec` and visible head primitive across their entire lifecycle, eliminating headless wake artifacts.

### 5.42 Deferred Impact-Gated Receiver Docking, Narrow-Phase Chassis Edge Docking & Coral Demotion
1. **Deferred Pending Receiver Tracking:** Advancing probe flights identify aligned opposing projectors during spatial sweeps and record `pending_receiver` on reticle state without pre-committing docking. The in-flight head strictly retains coral `DEFAULT_HEAD_SPEC` while traveling through open air.
2. **Impact-Gated Cyan Receiver Docking:** Transition to cyan receiver styling (`RECEIVER_HEAD_SPEC`, `radius = 0.35`) and assignment of `storage.projector_scope[proj_unit].receiver_unit` occurs strictly upon physical terminal arrival at the receiver face in `handle_projector_scope_arrival`, verifying `storage.active_projectors[target].valid` at that exact tick.
3. **Narrow-Phase Native Bounding Box Docking:** Docking evaluates physical `cand.bounding_box` within a focused 0.5-tile narrow-phase tolerance, spanning Factorio's 0.30-tile chassis collision box inset relative to the tile grid footprint without requiring artificial pneumatic socket offsets.
4. **In-Place Construction Docking Hook:** Constructing or rotating a projector invokes `flow_kinetic.dock_incoming_reticles_at_projector`, querying intersecting motion BVH leaves within 0.5 tiles of its bounding box to immediately dock stationary endpoints as cyan receivers on the exact build tick.
5. **Universal Coral Demotion on Orphaning & Clearance:** Reticles orphaned by sender deconstruction, power loss, or rotation unconditionally revert to coral `DEFAULT_HEAD_SPEC`, clearing `receiver_unit` and broadcasting the update to viewport subscribers. Obstacle clearance resets pending/docked receiver state, returning heads to coral until forward probing rediscovers an opposing receiver.

### 5.43 O(1) Table-Driven Obstacle Destruction, Dynamic Gate Monitoring & Event-Driven Decaying Corridors
1. **$O(1)$ Table-Driven Obstacle Destruction:** Entities blocking reticles register into `storage.blocked_reticles[unit_number]`, `storage.blocked_reticles_by_reg[reg_id]`, and `storage.reticle_blocked_by[rid]`. When entities are mined or destroyed (`is_removal == true`), `handle_obstacle_changed` bypasses spatial BVH queries entirely and directly dispatches `handle_reticle_obstacle_cleared(entity)` in sub-microsecond time, eliminating multi-millisecond frame spikes during mass entity clearing (e.g. grenades, artillery, cliff explosives).
2. **Canonical Corridor Regrowth:** Clearing an obstacle verifies blocker ownership in `storage.reticle_blocked_by[rid]` before unblocking. `resume_reticle_probing` launches forward probe flights from the unblocked collision face to the canonical 16-tile segment boundary, smoothly expanding corridors back to maximum reach without resetting upstream trail dots.
3. **Autonomous Dynamic Gate Monitoring:** Gates intersecting reticle corridors are registered into `storage.reticle_gates[reticle_id][gate_unit]`. Gate open events resume forward probing through the opening; gate close events trigger immediate cardinal truncation at the closed gate face.
4. **Event-Driven Decaying Flight Corridors:** When a projector's reticle is orphaned or unlinked from a receiver, `unlink_projector_receiver` queries `count_in_flight_capsules`. Empty flight corridors are destroyed immediately; corridors with active in-transit payloads register into `storage.decaying_corridors`. Corridor teardown is bundled directly into payload arrival/crash handlers (`remove_flight`), removing decaying corridors from motion BVH trees the exact tick the payload count reaches zero without periodic background polling.
5. **Acyclic Render Invalidation Helpers:** `flow-kinetic.lua` utilizes localized, zero-allocation storage buffer dirtying helpers (`dirty_flight_cache`, `dirty_all_projector_flights`) to invalidate pre-calculated rendering caches on projectile collisions, horizon shifts, and deconstructions without requiring `capsule-renderer.lua`.

---

## 4. Visual Overlay Specifications (Alt-Mode & Scripts)

All overlays are drawn and managed via `scripts/flow/flow-renderer.lua` and modular subprotocols:

| Render Target Pass | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :---: | :--- |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Kinetic minor node dot: renders subtle filled dot (`radius = 0.08`, holmium magenta scaled by quality tier) on intermediate 1-tile trajectory steps. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Kinetic prominent hop marker: renders charged circle (`radius = 0.16`, `width = 2`, quality-scaled color) every 5 tiles along active beams. |
| *Default Script Layer* | Circle | `render_pool.lease_circle` | **Yes** | Kinetic scope probe in-flight head: renders coral filled inner dot (`radius = 0.12`) and outer circle (`radius = 0.35`) during transit. |
| *Default Script Layer* | Circle | `render_pool.lease_circle` | **Yes** | Aligned receiver indicator: renders cyan target ring (`radius = 0.35`, `RECEIVER_HEAD_SPEC`) snapped squarely to opposing receiver edge hull. |
| *Default Script Layer* | Circle | `render_pool.lease_circle` | **Yes** | Obstacle hazard / severed indicator: renders coral hazard ring (`radius = 0.35`, `DEFAULT_HEAD_SPEC`) at collision faces, closed gates, or open-air terminations. |
| *Default Script Layer* | Circle | `render_pool.lease_circle` | **Yes** | Static corridor trail dots: renders discrete quality-tinted trail dots leased to viewport BVH leaves, peeled tick-by-tick by anti-reticle flights. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Projector passive intake overlay: renders filled cyan dot (`radius = 0.12`, `PROJECTOR_INTAKE_COLOR`) on zero-pressure non-muzzle intake sockets. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Projector idle muzzle overlay: renders filled magenta dot (`radius = 0.12`, `PROJECTOR_MUZZLE_COLOR`) on projector launch muzzle coordinates when gas pressure and kinetic beam levels are both zero. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Counter sensing range overlay: renders filled owner color dot (`radius = 0.12`) on owned tube nodes. |
| *Default Script Layer* | Text | `rendering.draw_text` | **Yes** | Counter sensing range overlay: renders sensing range level integer (scaled by quality, white text, `scale = 0.65`) centered above tube nodes. |
| *Default Script Layer* | Circle | `rendering.draw_circle` | **Yes** | Spatial junction pressure overlay (`pos_key`): renders exactly 1 pressure marker circle per tile (radius = 0.15, cyan/blue for positive pressure, orange/red for intake vacuum) clamped to `MAX_FLOW`. Ignores kinetic beam nodes. |
| *Default Script Layer* | Text | `rendering.draw_text` | **Yes** | Spatial junction pressure overlay (`pos_key`): renders exactly 1 pressure integer level text (white text, `scale = 0.7`) above junction circles. |
| *Default Script Layer* | Line | `rendering.draw_line` | **Yes** | Renders flow vector connection lines (`width = 3`, cyan/orange) between adjacent connected tube ports (suppressing zero-length vector lines). |