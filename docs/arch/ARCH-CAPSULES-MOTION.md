# ARCH-CAPSULES-MOTION.md - Capsule System, Motion Engine & Projectiles
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Granular 6t Hop Motion, Ballistic Projectiles, Spoilage Lifecycles, Liminal Storage & Occupancy

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `liminal-surface.lua` | `scripts/surfaces/` | Dual-Tier Spatial Grid allocation engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Distributes standard non-spoilable cargo into Tight slots (2-tile spacing, $y \le -100$) and spoilable/unit cargo into Wide cells (8-tile spacing, $y \ge 0$). Manages separate recycling stacks (`wide_free_slots`, `tight_free_slots`). Synchronous chunk generation (`ensure_chunk_at`). | `liminal_surface.get()`, `allocate_position(is_wide)`, `release_position(index, is_wide)`, `ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua` |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: explicit net usable cargo capacities (`cargo_capacity`), dynamic quality charge scaling helper `capsule_definitions.get_max_charges(def_or_name, quality_arg)` implementing `base * (1 + 0.3 * quality_level)` (500 base charges for `vacuum-capsule` scaling to 1,250 at Legendary; 600 base charges for `refrigerated-capsule` scaling to 1,500 at Legendary), biological restrictions (`bio_only = true`), bulk enforcement (`full_stacks`, `minimum_cargo`), fractional slot scaling (`mixed_quantity = true` for `electromagnetic-capsule`), belt siphoning permissions (`siphon_belts = true`), bio item matrix (`bio_items`), distinct RGBA debug overlay colors per capsule variant (`get_debug_color()`), spoilage modifiers, single-use shell dissolution (`destroy_self`), and spent item transitions (`spent_capsule_item`). | Registry `capsule_definitions.types`, `capsule_defs.bio_items`, `capsule_defs.get_debug_color()`, `capsule_defs.get_max_charges()` | `hub-packing`, `capsule-manager`, `capsule-runner`, `capsule-renderer`, `cargo-planner`, `belt-siphon`, `capsule-lifecycle` |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities (`storage.active_capsules`). Registers liminal holders with `script.register_on_object_destroyed` as `{ type = "capsule", id = capsule_id }`. Tracks primary capsule slot, allocated coordinates, `is_wide` classification, cached `dominant_item` string, `dominant_quality` string, `capsule_type = capsule_item_name` immutable identity string, and `has_spoilable_items` flag. Recycles positions back to `wide_free_slots` or `tight_free_slots` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions`, `liminal-surface`, `storage`, `flow-engine` |
| `capsule-queries.lua` | `scripts/capsules/` | $O(1)$ Spatial Occupancy Index (`storage.occupancy` key `[unit_number][net_id][group]`), memoized port descriptors queried directly from `storage.flow_nodes`, target-based blocking occupancy model (`_occ_block_key`), native parser support for `"kinetic:<unit>:<dx>,<dy>:<dist>"` port keys (`port_index = 100 + dist`), excluding both `is_beam_node` and `is_kinetic` nodes from physical machine chassis occupancy counts. Occupancy tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`), and `remove_capsule` expanded to clean occupancy, unpark waiting capsules, clear visual debug renders, and wake upstream queued traffic. | `get_port_info()`, `get_port_group()`, `get_port_descriptor()`, `update_capsule_occupancy()`, `unregister_capsule_occupancy()`, `remove_capsule()` | `storage`, `capsule-runner`, `flow-engine` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Lifecycle processor managing passenger position sync, 60-tick refrigerated spoilage reduction ($0.10$) bounded to active inventory slots, stack rebuilds via `item_transfer_handler`, tool durability drain, health-based charge tracking (`stack.health`), dynamic quality-scaled cooling capacity via `capsule_defs.get_max_charges(caps_def, stack.quality)` extending active refrigeration up to 25 minutes at Legendary, and spent tool conversion (`spent-refrigerated-capsule`). | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager`, `item-transfer-handler`, `hub-spill`, `capsule-definitions` |
| `capsule-renderer.lua` | `scripts/capsules/` | System-level viewport preparation (`prepare_frame()`) invoked once per tick across `game.players`, allocation-free scratch tables (`scratch_debug_players`, `scratch_debug_keys`), memoized numeric hover peeking (`get_port_info()`), distinct RGBA debug overlay colors per capsule variant, official C++ RenderLayers (`"entity-info-icon-above"`, `"light-effect"`), and dynamic spoilage expiration tracking. | `prepare_frame()`, `render()`, `get_dominant_item()` | `capsule-manager`, `capsule-queries`, `debug-manager` |
| `capsule-runner.lua` | `scripts/capsules/` | Granular Node Hop Motion Engine in v2 mode and Ballistic Kinetic Trajectory Runner for Electromagnetic Projectors. Advances discrete node hops every 6 ticks (staggered per capsule ID via `(current_tick + id) % 6 == 0`, `STAGGER_TICKS = 6`). Multi-hop traversal loop breaks upon entering or traversing prominent kinetic nodes, fixing velocity at exactly 1 prominent hop (5 tiles) per 6 ticks (~50 tiles/sec). Enforces payload identity gatekeeping (`is_electromagnetic_capsule`), rejecting non-EM capsules from entering projector intake ports or launch muzzles. Launch gatekept behind `can_fire(proj_entity)` requiring fully charged 9 MJ buffer (`LAUNCH_ENERGY_JOULES = 9000000`) and endpoint capacity ceiling (`count_endpoint_capsules < MAX_ENDPOINT_CAPSULES`). Deducts 9 MJ upon firing, records launch tick to `storage.projector_last_fired`, and plays audio-visual launch FX. Executes receiver catchment (`catch_in_receiver`) at endpoint hops contacting a receiving `pneumatic-projector` footprint, querying non-muzzle receiver ports for connected external lines, verifying downstream pressure drops (`drop = -ext_level >= 0`), and injecting into logistics tubes or parking at the receiver dock if saturated. Mid-air momentum preservation: `init_capsule_beam_flight` persists projected hop positions (`hop_positions`), direction, and target receiver ID on `capsule.beam_flight`; mid-flight payloads survive sender deconstruction, completing ballistic trajectories at 5 tiles/6 ticks. Player interception: `prepare_player_targets` snapshots character and vehicle bounding boxes once per frame in zero-allocation scratch tables; player contact arrests projectile motion, deals quality-scaled impact damage (`250 * (1 + 0.3 * q_level)`), spawns explosion FX, and spills cargo into red-locked `visible-capsule-holder` spill containers via `hub_spill.spill_capsule`. Terminal crash spillage handles unaligned terminations, cliff dead-ends, or destroyed receivers at the obstacle tile. Features Strict Quality Rank Engine (`Normal` = 1 through `Legendary` = 5), zero-allocation scratch buffers, and $O(1)$ spatial parked index (`storage.parked_by_port`) for targeted neighbor, sister port, and backpressure dock wakeups. Scan horizon registered at `MAX_BEAM_DISTANCE = 500`. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `remove_capsule()`, `matches_filter_item()`, `on_tick` handler | `flow-engine`, `capsule-manager`, `capsule-lifecycle`, `capsule-renderer`, `capsule-queries`, `hub-unpacking`, `hub-spill`, `liminal-surface`, `projector-settings` |

---

## 2. Persistent Storage Schema (`storage`)

```lua
  -- Dual-Tier Off-Grid Liminal Surface Cell Allocation Engine
  liminal_grid = {
    next_wide_index = 0,
    next_tight_index = 0,
    wide_free_slots = {}, -- Stack of recycled slot indices for Wide 8-tile domain (y >= 0)
    tight_free_slots = {} -- Stack of recycled slot indices for Tight 2-tile domain (y <= -100)
  },

  -- O(1) Spatial Occupancy Index ([unit_number][net_id][group] = capsule_count)
  occupancy = {
    [101] = {
      [1] = {
        [1] = 1 -- 1 capsule occupying unit 101, network 1, port group 1
      }
    }
  },

  -- O(1) Spatial Parked Capsule Index
  parked_by_port = {
    ["101:1"] = {
      [capsule_id] = true -- Set of capsule IDs parked waiting at port key
    }
  },

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity, type = "capsule", capsule_type = "electromagnetic-capsule",
      primary_slot = 1, position = { x = 0, y = -100 },
      grid_index = 5, is_wide = false, dominant_item = "iron-plate", dominant_quality = "normal",
      has_spoilable_items = false, definition = { ... }
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1, capsule_id = capsule_id, source_hub = 101, from_port_key = "101:1", to_port_key = "102:2",
      _occ_block_key = "102:2", progress = 0.45, passenger = LuaPlayer, slot_spoil_percents = { [1] = 0.12 },
      last_failed_hub = 102, last_failed_hub_count = 15, last_failed_hub_bar = 10, last_failed_cap_count = 1,
      beam_flight = {
        hop_positions = { { x = 10.5, y = 15.5 }, ... },
        current_hop_idx = 1, dir = { x = 0, y = -1 }, target_receiver = 105
      }
    }
  },

  -- Per-Player Debug Overlays
  debug = {
    [player_index] = {
      capsules = true,
      peek = false
    }
  }
```

---

## 3. Core Algorithms & Operational Mechanics

### 5.2 O(1) Spatial Occupancy Index & Target-Based Blocking Model
1. **Constant-Time Spatial Lookup Matrix:** `storage.occupancy` maintains multi-level spatial buckets indexed by `[unit_number][net_id][group]`. Occupancy queries execute in $O(1)$ constant time.
2. **Topology Direct Querying:** `get_port_group()` and `get_port_descriptor()` query v2 spatial topology in `storage.flow_nodes` directly. Parsers natively recognize direction-scoped kinetic keys (`"kinetic:<unit>:<dx>,<dy>:<dist>"` with `port_index = 100 + dist`).
3. **Projector Chassis Occupancy Decoupling:** In-flight kinetic nodes (`is_beam_node` and `is_kinetic`) are excluded from physical machine chassis occupancy counts, enabling continuous projectile launches without blocking the sending projector dock.
4. **Target-Based Blocking Occupancy:** Moving capsules track a target blocking key (`_occ_block_key = to_port_key`). Committing to a destination target segment blocks capacity at the destination node while immediately freeing the origin node capacity (`from_port_key`) for upstream capsules.
5. **Unparking & Cleanup Dispatch:** `remove_capsule` cleans occupancy buckets, unparks waiting capsules from `storage.parked_by_port`, clears visual debug renders, and wakes upstream queued traffic waiting at the freed port key.

### 5.3 Granular Node Hop Motion Engine & Positive Pressure Drops
1. **Granular Node Hop Motion:** Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop capability (`MAX_NODE_HOPS_PER_STEP = 3`) for instantaneous internal machine transitions.
2. **Strict Positive Pressure Gradient Target Selection:** `select_next_target` evaluates candidate outbound hops, requiring `capsule_transmit = true` and a strictly positive pressure drop (`touching_level - target_level > 0`) or intake vacuum pull.
3. **Strict Outbound Hub Pressure Differential Enforcement:** Outbound hub dispatch (`inject_from_hub` and `find_best_hub_outbound_port`) evaluates pressure drops (`touching_level - target_level`) per individual touching port with `max_drop = 0` initialization.
4. **Metadata Emitter Traversal:** Uses node metadata (`node.emitter`) rather than entity name matching to handle pump push (`emitter < 0` to `emitter > 0` with `drop = math.huge`). Passive hub and projector ports have `emitter = nil` to avoid false unpowered emitter evaluation.
5. **Zero-Allocation Persistent Scratch Buffers:** Module-level persistent scratch tables eliminate table allocations (`{}`) during path evaluation, candidate scoring, and neighbor wakeups.

### 5.4 0-Tick Lockstep Queue Advancement & Edge-Formation Wakeups
1. **0-Tick Lockstep Queue Advancement:** The exact tick a parked capsule transitions to moving or arrives, `update_capsules()` invokes `wake_parked_capsules(prev_from)`, triggering instant queue advancement for upstream queued capsules on the same tick.
2. **Targeted Network-Scoped Wakeup Engine:** `wake_parked_capsules(target)` uses `storage.parked_by_port`, sister unit ports, and connected edges to wake strictly the parked capsules affected by a freed route or entity state change.
3. **Edge-Formation Wakeup Synchrony:** When new connection edges form in `storage.flow_connections`, `flow_engine.connect_entity` invokes `wake_port_parked` on both ends of the edge, advancing queued traffic on the exact tick an edge opens.
4. **Stale Motion State Reset:** Stale origin port memory (`capsule.last_port_key`) is cleared whenever a capsule enters a parked state or receives a target wakeup.

### 5.8 Dynamic Spoilage Expiration & Zero-Overhead Render Polling
1. **Spoilability Detection at Packing:** `is_stack_spoilable()` computes a `has_spoilable_items` flag persisted in `storage.active_capsules`.
2. **Dynamic Spoilage Expiration Guard:** In `capsule-renderer.lua`, `get_dominant_item()` inspects active container slots. If cargo spoils mid-flight, it updates `cap_data.dominant_item` to the spoiled product and flips `has_spoilable_items` to `false` once zero spoilable stacks remain.
3. **0-Tick Scan Suppression:** Once `has_spoilable_items` transitions to `false`, 60-tick periodic inventory re-scans are permanently suppressed, serving cached dominant item icons directly from memory in $O(1)$ time.
4. **Valid Render Layer Hierarchy & Distinct Color Overlay:** Debug rings and payload icons render on official C++ RenderLayers (`"entity-info-icon-above"` for rings/icons, `"light-effect"` for HUD text). Each capsule variant displays a distinct RGBA debug border ring.

### 5.23 Ballistic Motion Runner: 6-Tick Prominent Hops, Receiver Catchment & Terminal Crash Mechanics
1. **Standard 6-Tick Ballistic Cadence & Prominent Hops:** Kinetic trajectories advance along prominent nodes (`dist % 5 == 0` or endpoints) at standard `STAGGER_TICKS = 6` cadence (`(current_tick + id) % 6 == 0`), bypassing intermediate minor nodes. An early-exit break in the multi-hop traversal loop upon traversing prominent kinetic nodes fixes velocity at exactly 5 tiles per 6 ticks (~50 tiles/sec).
2. **Electromagnetic Payload Identity Gatekeeping:** Enforces `is_electromagnetic_capsule` identity checks across `is_hop_valid` and `select_next_target`, rejecting non-electromagnetic capsules from entering projector intake ports or launch muzzles. Incoming capsules from tubes park safely in the intake dock.
3. **Receiver Catchment & Tube Network Injection:** `catch_in_receiver` captures capsules arriving at endpoint hops contacting a receiving `pneumatic-projector` footprint. Dynamically queries non-muzzle receiver ports for connected external pneumatic lines, validates tube capacity, enforces downstream pressure drops (`drop = -ext_level >= 0`, rejecting positive back-pressure), and injects payloads into outbound logistics tubes or parks them safely at the receiver dock if lines are saturated.
4. **Terminal Crash Spillage & Mid-Flight Severance:** Unaligned beam terminations, cliff dead-ends, or destroyed receivers route into `hub_spill.spill_capsule` at the endpoint coordinate, spawning an explosion and deploying red-locked `visible-capsule-holder` spill containers (`set_bar(1)`). If a beam is obstructed mid-flight, line-of-sight raycasting detects the obstacle and crashes the payload at the obstacle tile.
5. **Ballistic Momentum Preservation Across Sender Deconstruction:** `init_capsule_beam_flight` snapshots projected hop coordinates (`hop_positions`), direction, and target receiver ID on `capsule.beam_flight` upon launch. If the sending projector is mined or destroyed mid-transit, in-flight capsules continue advancing along cached ballistic hops at 5 tiles/6 ticks, reaching downstream receivers or triggering crash spillage at the terminal tile without nil errors. Mid-flight beam payloads are excluded from sender deconstruction spillage.
6. **Zero-Allocation Player Interception & Quality-Scaled Impact Damage:** `prepare_player_targets` snapshots character and vehicle bounding boxes across connected players once per frame using module-level scratch tables (`scratch_player_targets`). Trajectory player interception halts projectile motion on contact, applies native `impact` damage scaled by machine quality (`250 * (1 + 0.3 * q_level)`), spawns an explosion, and spills cargo into red-locked spill containers via `hub_spill.spill_capsule`.

---

## 4. Visual Overlay Specifications & Color Registry

### 4.1 Runtime Script Render Layers (`rendering.draw_*`)

| Render Layer Name / Target Pass | Module Source | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `"light-effect"` | `capsule-runner.lua` | Text | `rendering.draw_text` | No | Renders `" [Shift + E] Emergency Eject "` HUD text centered above riding passenger capsules (`scale = 0.9`, offset `y + 0.8`). |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders cyan passenger ring (`radius = 0.45`, `width = 3`) around player-occupied capsules. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders capsule variant debug border ring (`radius = 0.35`, `width = 2`) using capsule RGBA debug colors. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Sprite | `rendering.draw_sprite` | No (Debug) | Renders dominant payload item icon (`"item/" .. item_name`, `scale = 0.55`) inside capsule debug ring. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders filled color dot (`radius = 0.25`) for empty or unknown cargo capsules. |

### 4.2 Capsule Variant Debug Overlay Color Registry

| Capsule Variant | Localized / Description | RGBA Color Code | Rendering Usage |
| :--- | :--- | :--- | :--- |
| `item-capsule` | Metallic Gold | `{ r = 1.0, g = 0.84, b = 0.0, a = 0.9 }` | Standard cargo capsule border ring/dot overlay. |
| `biodegradable-capsule` | Emerald Green | `{ r = 0.2, g = 0.90, b = 0.2, a = 0.9 }` | Biodegradable capsule border ring/dot overlay. |
| `refrigerated-capsule` | Frost Cyan | `{ r = 0.2, g = 0.85, b = 1.0, a = 0.9 }` | Cold biological capsule border ring/dot overlay. |
| `spent-refrigerated-capsule` | Slate Grey | `{ r = 0.6, g = 0.65, b = 0.7, a = 0.9 }` | Spent refrigerated capsule border ring/dot overlay. |
| `reinforced-capsule` | Violet Purple | `{ r = 0.8, g = 0.30, b = 1.0, a = 0.9 }` | Reinforced bulk cargo capsule border ring/dot overlay. |
| `electromagnetic-capsule` | Holmium Magenta | `{ r = 0.9, g = 0.20, b = 0.7, a = 0.9 }` | Electromagnetic mixed cargo capsule border ring/dot overlay. |
| `vacuum-capsule` | Deep Vacuum Blue | `{ r = 0.1, g = 0.40, b = 0.9, a = 0.9 }` | Vacuum belt siphon capsule border ring/dot overlay. |
| `spent-vacuum-capsule` | Muted Steel Grey | `{ r = 0.5, g = 0.55, b = 0.6, a = 0.9 }` | Spent vacuum capsule border ring/dot overlay. |
| `player-transit-capsule` | Crimson Orange | `{ r = 1.0, g = 0.40, b = 0.1, a = 0.9 }` | Passenger transit capsule border ring/dot overlay. |