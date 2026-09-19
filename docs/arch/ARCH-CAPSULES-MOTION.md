# ARCH-CAPSULES-MOTION.md - Capsule System, Motion Engine & Projectiles
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Granular 6t Hop Motion, Timed Ballistic Projectiles, Spoilage Lifecycles, Modular Motion Subprotocols, Liminal Storage & Occupancy

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `liminal-surface.lua` | `scripts/surfaces/` | Off-Grid Liminal Surface Cell Allocation Engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Standardizes all liminal holder slots onto a single compact 2-tile lab tile grid (retiring legacy moat grids, water border painting, and wide-cell allocation branches). Manages an in-memory stack of recycled slot indices (`free_slots`). Synchronous chunk generation (`ensure_chunk_at`). | `liminal_surface.get()`, `allocate_position()`, `release_position(index)`, `ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua` |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: explicit net usable cargo capacities (`cargo_capacity`), dynamic quality charge scaling helper `capsule_definitions.get_max_charges(def_or_name, quality_arg)` implementing `base * (1 + 0.3 * quality_level)` (500 base charges for `vacuum-capsule` scaling to 1,250 at Legendary; 600 base charges for `refrigerated-capsule` scaling to 1,500 at Legendary), biological restrictions (`bio_only = true`), bulk enforcement (`full_stacks`, `minimum_cargo`), fractional slot scaling (`mixed_quantity = true` for `electromagnetic-capsule`), electromagnetic classification metadata (`is_electromagnetic = true`), belt siphoning permissions (`siphon_belts = true`), bio item matrix (`bio_items`), distinct RGBA debug overlay colors per capsule variant (`get_debug_color()`), spoilage modifiers, single-use shell dissolution (`destroy_self`), and spent item transitions (`spent_capsule_item`). Centralizes capsule spoilability predicates (`is_stack_spoilable`, `is_unit_spoilable`) and stability classifiers (`is_dynamic_capsule`, `is_stable_capsule`), classifying invariant shells and non-spoilable cargo (including vacuum capsules whose durability changes at hubs) as fully stable while scoping dynamic handling strictly to refrigerated, unit-producing, and player transit capsules. | Registry `capsule_definitions.types`, `capsule_defs.bio_items`, `capsule_defs.get_debug_color()`, `capsule_defs.get_max_charges()`, `capsule_defs.is_electromagnetic()`, `capsule_defs.is_stack_spoilable()`, `capsule_defs.is_unit_spoilable()`, `capsule_defs.is_dynamic_capsule()`, `capsule_defs.is_stable_capsule()` | `hub-packing`, `capsule-manager`, `capsule-runner`, `capsule-renderer`, `cargo-planner`, `belt-siphon`, `capsule-lifecycle`, `capsule-transit`, `counter-range` |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua`, `capsule-transit.lua` |
| `capsule-transit.lua` | `scripts/capsules/` | Player Transit & Suit Equipment Safety Controller. Encapsulates electromagnetic harness equipment energy inspection (`player_has_harness` requiring >100 kJ in armor equipment grid), capsule electromagnetic classification (`is_electromagnetic_capsule`), single-pass zero-allocation player bounding-box scratch caching (`prepare_player_targets`, `scratch_player_targets`), self-collision suppression (`check_player_collision` verifying player index and character entity against passenger), and passenger emergency ejection (`emergency_eject`). | `capsule_transit.player_has_harness(player)`, `capsule_transit.is_electromagnetic_capsule(capsule)`, `capsule_transit.prepare_player_targets()`, `capsule_transit.check_player_collision(pos, capsule)`, `capsule_transit.emergency_eject(player)` | `capsule-runner.lua`, `capsule-ballistics.lua`, `capsule-definitions.lua`, `hub-spill.lua` |
| `capsule-ballistics.lua` | `scripts/capsules/` | Electromagnetic Projector Ballistics, Timed Arrival Scheduler & Dynamic Collision Physics. Schedules projectile arrivals in `storage.kinetic_arrival_heap` with master toggle (`USE_TIMED_ARRIVAL`), immediately unparking launcher intake docks on dispatch. Scales flight duration directly to traveled distance (`flight_ticks = ceil(total_dist * TICKS_PER_TILE)`) with production velocity constants (`TICKS_PER_HOP = 6`, `TICKS_PER_TILE = 1.2`, transit speed: 50 tiles/sec). Handles chained 16-tile projector scope probe arrivals (`handle_projector_scope_arrival`), intermediate hops, and anti-reticle wake reeling arrivals (`handle_anti_reticle_arrival`). Resolves string-typed `on_arrival` callbacks without non-serializable function closures. Dynamically recalculates in-flight projectile crash sites and arrival horizons in `update_projector_flights` when corridor occlusions clear or shift, using forward-only horizon scanning ($d > cur\_dist$) to prevent backward teleportation crashes. Enforces pre-launch clearance checks 0.5 tiles forward (`muzzle_node.pos + dir * 0.5`). Executes colinear receiver docking with perimeter socket snapping and 0.5-tile native chassis bounding box tolerance, verifying receiver entity validity at the arrival tick before applying cyan head styling. Detects newly placed receiving projectors mid-flight via `handle_motion_obstacle_changed`, transitioning scheduled crash targets to green receiver rings. Clears `capsule.beam_flight = nil` upon receiver docking to enable peaceful cargo spilling on deconstruction. Executes `apply_crash_damage` with a 3.5-tile blast radius and quality-scaled impact damage (`250 * (1 + 0.3 * q_level)`), protecting `visible-capsule-holder` spill containers while damaging players and vehicles. Provides unified launch entry point `launch_timed_flight` forwarding reticle and projector metadata. Bundles decaying corridor teardown directly into `remove_flight`. | `capsule_ballistics.dispatch_timed_launch(...)`, `capsule_ballistics.launch_timed_flight(...)`, `capsule_ballistics.step_timed_arrivals(current_tick)`, `capsule_ballistics.update_projector_flights(...)`, `capsule_ballistics.get_beam_endpoint(...)`, `capsule_ballistics.finalize_timed_arrival(...)`, `capsule_ballistics.handle_projector_scope_arrival(...)`, `capsule_ballistics.handle_anti_reticle_arrival(...)`, `capsule_ballistics.handle_motion_obstacle_changed(...)`, `capsule_ballistics.register_arrival_handler(...)`, `capsule_ballistics.remove_flight(...)` | `capsule-runner.lua`, `capsule-transit.lua`, `flow-kinetic.lua`, `motion-protocols.lua`, `timed-motion.lua`, `trajectory-bvh.lua`, `binary-heap.lua`, `hub-spill.lua`, `capsule-renderer.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities (`storage.active_capsules`). Registers liminal holders with `script.register_on_object_destroyed` as `{ type = "capsule", id = capsule_id }`. Pre-computes and memoizes vessel and cargo circuit signals on `cap_data.signal_data` during registration (`extract_holder_signal_data`, `get_signal_data`, `is_stable`). Suspends perishable cargo in Lua virtual memory (`cap_data.virtual_cargo`) as stack specifications. Implements `collapse_virtual_cargo` to evaluate final dilated spoilage and coolant deductions upon delivery or destruction, materializing physical stacks into hub inventories or spill containers. Guards coolant depletion floor to 0.0001, converting shells to `spent-refrigerated-capsule` with quality tier inheritance (`qual_name`). Manages automatic stable demotion (`is_stable = true`) and heap eviction when zero perishables remain. Recycles liminal coordinates back to `free_slots` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()`, `is_electromagnetic()`, `extract_holder_signal_data()`, `get_signal_data()`, `collapse_virtual_cargo()`, `get_spoil_schedule()` | `capsule-definitions`, `liminal-surface`, `storage`, `flow-engine`, `hub-spill`, `counter-range` |
| `capsule-queries.lua` | `scripts/capsules/` | $O(1)$ Spatial Occupancy Index (`storage.occupancy` key `[unit_number][net_id][group]`), memoized port descriptors queried directly from `storage.flow_nodes`, target-based blocking occupancy model (`_occ_block_key`), native parser support for `"kinetic:<unit>:<dx>,<dy>:<dist>"` port keys (`port_index = 100 + dist`), excluding both `is_beam_node` and `is_kinetic` nodes from physical machine chassis occupancy counts. Integrates with `counter_range` to update Capsule Counter territory membership (`update_capsule_territory`, `unregister_capsule_territory`) in lockstep with discrete 6-tick capsule motion. Occupancy tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`), and `remove_capsule` expanded to clean occupancy, unpark waiting capsules, clear visual debug renders, and wake upstream queued traffic. | `get_port_info()`, `get_port_group()`, `get_port_descriptor()`, `update_capsule_occupancy()`, `unregister_capsule_occupancy()`, `remove_capsule()` | `storage`, `capsule-runner`, `flow-engine`, `counter-range` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Event-driven spoilage lifecycle scheduler backed by `storage.spoil_heap` processed via `capsule_lifecycle.step_spoil_heap`. Sanitizes legacy comparator closures from heaps on attachment. Replaced periodic 1-second scanning with true dilated dual-horizon scheduling waking strictly at $\min(t_{\text{coolant}}, t_{\text{spoil\_dilated}})$ via `schedule_dynamic_cargo`. Unifies latent scheduling across virtual memory and physical stacks. Evaluates C++ `spoil_to_trigger_result` prototype metadata to dynamically resolve spawn entities (`big-wriggler-pentapod-premature`, `big-biter`, `behemoth-biter`), scaling unit counts by `items_per_trigger` (`ceil(count / items_per_trigger)`) and inheriting egg quality tier. Spawns hatched enemies directly at real-world map coordinates along the active flight path (banning liminal surface fallbacks; legacy moat watchers removed). Converts depleted coolant shells to `spent-refrigerated-capsule`. | `capsule_lifecycle.step_spoil_heap(current_tick)`, `capsule_lifecycle.schedule_dynamic_cargo(...)`, `capsule_lifecycle.calculate_virtual_dilated_recheck(...)`, `capsule_lifecycle.spawn_spoiled_trigger_entity(...)` | `capsule-manager`, `binary-heap`, `counter-range`, `capsule-renderer`, `capsule-runner` |
| `capsule-renderer.lua` | `scripts/capsules/` | Communal Observer-Driven Viewport Renderer, Collective Observation Governor & Lockstep Pre-Calculation Buffer Engine. Features `clean_prepare_frame` evaluating Alt-Mode eligibility, resolving hover peek unit numbers, and managing pooled debug player allocations. Aggregates visible in-flight capsules across players via `update_governor`, switching render cadences (60 FPS $\leftrightarrow$ 30 FPS $\leftrightarrow$ 20 FPS) via smoothed Schmitt-trigger hysteresis with emergency surge drop overrides ($\ge 120$ count or $\Delta \ge 40$). Wakes governor dormancy and locks cadence strictly to 60 FPS during active reticle wake peeling (`retreat_tick`). Pre-calculates continuous forward coordinates in `storage.render_precalc_buffer` during quiet ticks (tick - 1 for 30 FPS; tick - 2 / tick - 1 for 20 FPS). Flushes renders in lockstep across all players (`current_tick % cadence == 0`) using `get_flight_position`, eliminating accordion stretching. Bypasses static corridors early using `scratch_active_owners` filtering. Dispatches in-flight visuals, dot trails, wake peeling, and static Alt-mode overlays via modular delegates in `motion-protocols.lua`. Renders frustum-culled arrival reticles (`render_arrival_dot_for_player`). Leases native `LuaRenderObject` instances from `render-pool.lua`. Evaluates `virtual_cargo` in `get_dominant_item` to display accurate perishable icons. Exports `clear_capsule_render` to purge static dock visuals upon projectile launch. Contains `/test-render-dispatcher` test suite. | `prepare_frame()`, `clean_prepare_frame()`, `update_governor()`, `step_precalculations()`, `dispatch_player_renders()`, `get_flight_position()`, `clear_capsule_render()`, `render_arrival_dot_for_player()`, `sync_all_arrival_dots()`, `render_custom_flight_for_player()`, `get_dominant_item()`, `step_buffer_decay()` | `capsule-manager`, `capsule-queries`, `motion-protocols`, `render-pool`, `viewport-bvh`, `timed-motion`, `debug-manager` |
| `capsule-runner.lua` | `scripts/capsules/` | Core Motion Coordinator, Sub-Profiler Aggregator & 6-Tick Discrete Hop Traversal Coordinator (~510 lines). Advances discrete node hops every 6 ticks (staggered per capsule ID via `(current_tick + id) % 6 == 0`, `STAGGER_TICKS = 6`). Subdivides motion profiling into three discrete timers: `Tube Traversal` (6t hops), `Ballistics & Heap` (arrival heap processing), and `Frame Sync` (governor and pre-calculation buffers). Traversal loop breaks upon entering prominent kinetic nodes. Hoists frame preparation (`prepare_frame`), timed arrival processing (`step_timed_arrivals` guarded by `heap and heap.size > 0`), and timed flight updates (`update_timed_capsules`) to the very top of `update_capsules` prior to `storage.capsules` emptiness guards. Enforces pressure-entry gatekeeping (`entered_via_pressure` transit flag) so kinetically received capsules cannot immediately re-fire from receiver docks. Implements reverse vacuum evacuation: clears `capsule.last_port_key` upon entering projector docks, unready launches fall through to candidate hop evaluation (`try_projector_launch` returns `nil`), and registers capsules in `storage.parked_by_port` so negative tube pressure siphons them back into logistics lines. Exposes backwards-compatible facade aliases. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `remove_capsule()`, `matches_filter_item()`, `update_capsules(current_tick)` | `capsule-transit.lua`, `capsule-ballistics.lua`, `flow-engine.lua`, `capsule-manager.lua`, `capsule-lifecycle.lua`, `capsule-renderer.lua`, `capsule-queries.lua`, `hub-unpacking.lua`, `hub-spill.lua`, `liminal-surface.lua`, `profiler.lua` |
| `motion-protocols.lua` | `scripts/utils/` | Central Motion & Flight Protocolization Registry (~380 lines). Modularizes flight simulation and presentation into composable subprotocols across 5 orthogonal facets: heads (`capsule_head`, `hazard_reticle`, `custom_flight`, `none`), trails (`reticle_dots`, `wake_peeling`, `none`), disruptions (`ballistic_crash`, `reticle_slice`, `peaceful_spill`, `silent_halt`, `none`), arrivals (`capsule_terminal`, `scope_step`, `anti_reticle_step`), and static Alt-mode overlays (`reticle_static`). Encapsulates spatial obstacle detectors (`open_air_solids`, `tube_connectivity`) and directional clearance policies (`optical_ray`, `discrete_projectile`, `peaceful_transit`, `silent_wave`). Implements mathematical axis displacement projection (`calculate_axis_distance`) and relative clearance bifurcation (`dispatch_clearance_policy` routing $d_{\text{obst}} > d_{\text{current}} + 0.05$ to `on_forward` and $d_{\text{obst}} \le d_{\text{current}} + 0.05$ to `on_backward`). Provides leaf collision scanning facade `scan_open_air_leaf`. Zero runtime `require()` calls inside event loops. Exposes 7-suite `/test-motion-protocols` automated test runner. | `motion_protocols.register_subprotocol(...)`, `motion_protocols.get_subprotocol(...)`, `motion_protocols.get_protocol(...)`, `motion_protocols.calculate_axis_distance(...)`, `motion_protocols.dispatch_clearance_policy(...)`, `motion_protocols.scan_open_air_leaf(...)`, `motion_protocols.get_progression_window(...)` | `capsule-renderer.lua`, `capsule-ballistics.lua`, `flow-kinetic.lua`, `viewport-bvh.lua`, `timed-motion.lua` |
| `binary-heap.lua` | `scripts/utils/` | Reusable indexed binary min-heap engine paired with an $O(1)$ reverse hash map (`indices[id] = pos`), sliding virtual line buffer boundary (`size`), zero-allocation table pooling, and stable FIFO tie-breaking. Neutralizes non-serializable function closures upon deserialization in `binary_heap.attach` (`heap.comparator = nil`). Implements dual-watermark hysteresis buffer deflation in `step_decay` (trigger ceiling `size * 3 + 128`, retention floor `size * 1.5 + 64`), truncating up to 8 idle tail slots per cycle into `nil`. Exposes `compact(safety_margin)` for boundary compaction on save/load cycles and `/test-heap`. | `binary_heap.new(comparator)`, `binary_heap.attach(table, comp_type)`, `heap:push(id, priority, data)`, `heap:pop()`, `heap:peek()`, `heap:update(id, priority, data)`, `heap:remove(id)`, `heap:step_decay()`, `heap:compact(margin)` | `capsule-lifecycle.lua`, `capsule-ballistics.lua`, `flow-kinetic.lua`, `control.lua` |
| `trajectory-bvh.lua` | `scripts/utils/` | Instantiable procedural spatial Bounding Volume Hierarchy (BVH) engine partitioning linear corridors into discrete 16-tile leaf segments. Operates on pure Factorio `storage` data tables without metatable serialization hazards (`new_tree`, `insert`, `remove`, `update`, `query_box`). Manages a high-water mark recycling pool (`lease_node`, `recycle_node`) with proportional gating (`free_count >= max(64, size * 2)`), amortized `step_decay`, and `compact(safety_margin)`. Defines baseline `TICKS_PER_TILE = 1.2`. Implements `has_flight_in_leaf` evaluating spatiotemporal departure ticks ($t_{\text{exit}} = t_{\text{start}} + \lceil d_{\text{end}} \times 1.2 \rceil$) to defer corridor unregistration while flights are in transit. Instrumented with dedicated profiler timers (`query_box`, `tree_mutate`). Exposes `/test-bvh`. | `trajectory_bvh.new_tree(surface_index)`, `trajectory_bvh.insert(tree, leaf)`, `trajectory_bvh.remove(tree, key)`, `trajectory_bvh.query_box(tree, box)`, `trajectory_bvh.has_flight_in_leaf(leaf, tick)`, `trajectory_bvh.step_decay(tree)`, `trajectory_bvh.compact(tree, margin)` | `flow-kinetic.lua`, `viewport-bvh.lua`, `timed-motion.lua`, `capsule-ballistics.lua`, `control.lua`, `profiler.lua` |
| `viewport-bvh.lua` | `scripts/utils/` | Player Viewport Spatial Tree Engine and Observer Intersection Bridge. Partitions player screens into surface trees in `storage.viewport_bvh[surface_index]`. Implements fixed 16-tile hysteresis boundary (`SHELL_TILES = 16`, max 32-tile trailing buffer) and 25% zoom-in contraction trigger (`SHRINK_THRESHOLD = 0.75`), removing arbitrary 150-tile clamping ceilings and UI scale divisors. Features stationary player fast-path caching (`last_player_x`, `last_player_y`, `last_zoom`) bypassing frustum math in sub-microsecond time. Namespaces active visible set entries (`storage.player_visible_set[player_index]`) as `owner_id:seg_key` to prevent shared render array collisions. Passes `player_index` to all `render_pool.recycle` invocations. Decouples static beam trail and endpoint rendering to the `"reticle_static"` subprotocol delegate. Synchronizes visibility on boundary breaches via differential spatial queries (`sync_player_visibility`). Replaces linear player scans with $O(\log N_{\text{players}})$ queries (`is_in_any_viewport`, `query_players_in_box`). Exposes `/test-viewport-bvh`, `/toggle-viewport-bvh`. | `viewport_bvh.init_storage()`, `viewport_bvh.update_player_viewport(...)`, `viewport_bvh.sync_player_visibility(...)`, `viewport_bvh.is_in_any_viewport(...)`, `viewport_bvh.query_players_in_box(...)`, `viewport_bvh.on_segment_removed(...)`, `viewport_bvh.on_leaf_static_changed(...)`, `viewport_bvh.attach_static_render(...)` | `capsule-renderer.lua`, `motion-protocols.lua`, `timed-motion.lua`, `render-pool.lua`, `control.lua`, `profiler.lua` |
| `timed-motion.lua` | `scripts/utils/` | Autonomous Flight Corridor Spatial Tree & Generic Timed Motion Registry. Formalizes `storage.motion_bvh[surface_index]` decoupled from beam occlusion trees, subdividing flight paths into 16-tile static leaves (`ensure_corridor`, `remove_corridor`) and notifying player viewports upon launch. Pins corridors in memory (`storage.pinned_corridors`) while flights or wake retreats remain active. Implements forward-looking arrival math in `shift_horizon` ($t_{\text{arrival}} = t_{\text{now}} + \lceil d_{\text{rem}} \times \text{tpt} \rceil$), preserving pinned BVH segments and active render handles without destructive geometry churn. Purges stale decaying corridors in `ensure_corridor`. Enforces string-only typed callbacks in `create_record`, eliminating non-serializable functions from `storage.timed_flight_records`. Steps timed arrival heap with zero-size dormancy guards (`heap and heap.size > 0`). Exposes `/test-timed-motion`. | `timed_motion.ensure_corridor(...)`, `timed_motion.remove_corridor(...)`, `timed_motion.create_record(...)`, `timed_motion.schedule_flight(...)`, `timed_motion.shift_horizon(...)`, `timed_motion.remove_flight(...)`, `timed_motion.get_interpolated_position(...)` | `capsule-ballistics.lua`, `capsule-renderer.lua`, `viewport-bvh.lua`, `motion-protocols.lua`, `control.lua` |
| `render-pool.lua` | `scripts/utils/` | High-Throughput Native `LuaRenderObject` Cache and Zero-Allocation Recycling Pool. Partitions object pools by player, surface, and visual archetype (`circle`, `sprite`, `text`, `line`). Leased handles mutate Factorio 2.0 properties in-place; recycled objects toggle `visible = false` into player free lists with a 128-object per-archetype high-water ceiling, eliminating C++ object churn. Implements early-exit visibility guard in `recycle` to prevent duplicate free-list insertions. Enforces explicit `player_index` signature across all recycling invocations. Supports polymorphic single-table and multi-argument leasing syntax (`lease_circle`, `lease_sprite`, `lease_text`, `lease_line`, `recycle`). Exposes `/test-render-pool`. | `render_pool.lease_circle(...)`, `render_pool.lease_sprite(...)`, `render_pool.lease_text(...)`, `render_pool.lease_line(...)`, `render_pool.recycle(player_index, obj)`, `render_pool.clear_player_pool(p_idx)` | `capsule-renderer.lua`, `viewport-bvh.lua`, `debug-manager.lua` |

---

## 2. Persistent Storage Schema (`storage`)

```lua
  -- Off-Grid Liminal Surface Cell Allocation Engine (Unified 2-Tile Lab Grid)
  liminal_grid = {
    next_index = 0,
    free_slots = {} -- Stack of recycled slot indices for 2-tile domain (all cargo types)
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
      grid_index = 5, dominant_item = "iron-plate", dominant_quality = "normal",
      has_spoilable_items = false, is_stable = true,
      virtual_cargo = { -- Suspended virtual memory cargo specifications (refrigerated/eggs)
        { name = "biter-egg", count = 50, quality = "legendary", spoil_percent = 0.12 }
      },
      signal_data = { -- Pre-computed memoized circuit signal contribution
        ["biter-egg::legendary"] = 50,
        ["refrigerated-capsule::normal"] = 1
      },
      definition = { ... }
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1, capsule_id = capsule_id, capsule_type = "electromagnetic-capsule",
      source_hub = 101, from_port_key = "101:1", to_port_key = "102:2",
      _occ_block_key = "102:2", progress = 0.45, passenger = LuaPlayer,
      entered_via_pressure = true, -- Strict gatekeeping flag for projector launch
      last_failed_hub = 102, last_failed_hub_count = 15, last_failed_hub_bar = 10, last_failed_cap_count = 1,
      beam_flight = { -- Ballistic flight state (cleared upon receiver docking)
        start_tick = 123450, total_dist = 45, flight_ticks = 54, arrival_tick = 123504,
        start_pos = { x = 10.5, y = 20.0 }, terminal_pos = { x = 55.5, y = 20.0 },
        dir = { x = 1, y = 0 }, target_receiver = 105, is_receiver_dock = true
      }
    }
  },

  -- Indexed Priority Queue Binary Min-Heaps (Serializable, Pooled & Compactable)
  spoil_heap = {
    data = { { id = capsule_id, priority = 123600, data = { ... } } },
    indices = { [capsule_id] = 1 },
    size = 1
    -- comparator closure purged: attached via binary_heap.attach
  },
  kinetic_arrival_heap = {
    data = { { id = flight_id, priority = 123504, data = { ... } } },
    indices = { [flight_id] = 1 },
    size = 1
    -- comparator closure purged: attached via binary_heap.attach
  },

  -- Autonomous Flight Corridor Spatial BVH Trees (In-Flight Ballistics)
  motion_bvh = {
    [surface_index] = {
      root = { ... }, size = 8, free_nodes = { ... }, free_count = 2, leaves_by_key = { ... }
    }
  },
  pinned_corridors = {
    ["corridor:10:rem:16"] = 1 -- Ref count pinning BVH segments during flight or wake reeling
  },
  decaying_corridors = {
    ["corridor:10:rem:16"] = { -- Corridors unlinked from receivers, decaying until payloads land
      surface_index = 1,
      reticle_id = 5,
      in_flight_count = 2
    }
  },

  -- Active Projector Flight Records & Generic Timed Flights
  projector_flights = {
    [flight_id] = {
      flight_id = 1, capsule_id = 10, runner_id = 1, surface_index = 1,
      start_tick = 123450, arrival_tick = 123504, start_dist = 0, total_dist = 45,
      start_pos = { x = 10.5, y = 20.0 }, terminal_pos = { x = 55.5, y = 20.0 },
      dir = { x = 1, y = 0 }, hit_receiver_unit = 105, is_receiver_dock = true
    }
  },
  timed_flight_records = {
    [flight_id] = {
      flight_id = 2, kind = "generic", metadata = { ... },
      render_spec = { sprite = "item/iron-plate", tint = { ... } },
      on_arrival = "string_identifier" -- Enforced string key, zero closures
    }
  },

  -- Pre-Allocated High-Water Coordinate Buffer (Time-Sliced Quiet-Tick Math)
  render_precalc_buffer = {
    watermark = 120,
    entries = {
      [flight_id] = { x = 15.5, y = 20.0, tick = 123456, valid = true }
    }
  },

  -- Player Viewport Spatial Index & Stationary Caching
  viewport_bvh = {
    [surface_index] = {
      root = { ... }, size = 2, free_nodes = { ... }, free_count = 0, leaves_by_key = { ... }
    }
  },
  player_viewports = {
    [player_index] = {
      surface_index = 1,
      center = { x = 20.0, y = 30.0 },
      last_player_x = 20.0,          -- Cached coordinates for stationary fast-path
      last_player_y = 30.0,
      last_zoom = 1.0,
      inner_box = { left_top = { x = 10, y = 20 }, right_bottom = { x = 30, y = 40 } },
      padded_box = { left_top = { x = -2, y = 8 }, right_bottom = { x = 42, y = 52 } },
      outer_shell = { left_top = { x = -14, y = -4 }, right_bottom = { x = 54, y = 64 } } -- Fixed 16-tile shell
    }
  },
  player_visible_set = {
    [player_index] = {
      ["10:corridor:10:rem:16"] = true -- Namespaced as "owner_id:seg_key"
    }
  },

  -- Native LuaRenderObject Recycling Cache
  render_pool = {
    [player_index] = {
      circle = { free = { LuaRenderObject, ... }, free_count = 12 },
      sprite = { free = { LuaRenderObject, ... }, free_count = 8 },
      text = { free = { LuaRenderObject, ... }, free_count = 2 },
      line = { free = { LuaRenderObject, ... }, free_count = 0 }
    }
  },

  -- Per-Player Debug Overlays
  debug = {
    [player_index] = {
      capsules = true,
      peek = false,
      arrival_dots = true,
      bvh = false,
      viewport_bvh = false
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
5. **Event-Driven Counter Territory Synchronization:** `update_capsule_occupancy` and `remove_capsule` invoke `counter_range.update_capsule_territory` and `counter_range.unregister_capsule_territory` in lockstep with 6-tick motion, updating counter territory membership instantly upon entering or leaving a sensor zone.
6. **Unparking & Cleanup Dispatch:** `remove_capsule` cleans occupancy buckets, unparks waiting capsules from `storage.parked_by_port`, clears visual debug renders, and wakes upstream queued traffic waiting at the freed port key.

### 5.3 Granular Node Hop Motion Engine & Positive Pressure Drops
1. **Granular Node Hop Motion:** Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop capability (`MAX_NODE_HOPS_PER_STEP = 3`) for instantaneous internal machine transitions.
2. **Strict Positive Pressure Gradient Target Selection:** `select_next_target` evaluates candidate outbound hops, requiring `capsule_transmit = true` and a strictly positive pressure drop (`touching_level - target_level > 0`) or intake vacuum pull.
3. **Strict Outbound Hub Pressure Differential Enforcement:** Outbound hub dispatch (`inject_from_hub` and `find_best_hub_outbound_port`) evaluates pressure drops (`touching_level - target_level`) per individual touching port with `max_drop = 0` initialization.
4. **Pressure-Entry Projector Gatekeeping:** Capsules set an `entered_via_pressure = true` flag strictly when entering a projector chassis across an external pneumatic tube edge under pressure gradients. Projector ballistic launch (`try_projector_launch`) is strictly gated behind this flag; received kinetic payloads cannot immediately fire from the receiver dock.
5. **Reverse Vacuum Evacuation from Projector Docks:** When an unpowered or unready projector cannot launch, `try_projector_launch` returns `nil`, allowing motion pathfinding to fall through to candidate hop evaluation. Stale origin memory (`capsule.last_port_key`) is cleared upon entering dock ports, and the capsule is indexed in `storage.parked_by_port`, allowing reverse vacuum pull to evacuate the capsule back into connected logistics lines.
6. **Zero-Allocation Persistent Scratch Buffers:** Module-level persistent scratch tables eliminate table allocations (`{}`) during path evaluation, candidate scoring, and neighbor wakeups.

### 5.4 0-Tick Lockstep Queue Advancement & Edge-Formation Wakeups
1. **0-Tick Lockstep Queue Advancement:** The exact tick a parked capsule transitions to moving or arrives, `update_capsules()` invokes `wake_parked_capsules(prev_from)`, triggering instant queue advancement for upstream queued capsules on the same tick.
2. **Targeted Network-Scoped Wakeup Engine:** `wake_parked_capsules(target)` uses `storage.parked_by_port`, sister unit ports, and connected edges to wake strictly the parked capsules affected by a freed route or entity state change.
3. **Edge-Formation Wakeup Synchrony:** When new connection edges form in `storage.flow_connections`, `flow_engine.connect_entity` invokes `wake_port_parked` on both ends of the edge, advancing queued traffic on the exact tick an edge opens.
4. **Stale Motion State Reset:** Stale origin port memory (`capsule.last_port_key`) is cleared whenever a capsule enters a parked state or receives a target wakeup.

### 5.8 Virtual Memory Cargo Suspension, Dilated Spoilage Scheduling & In-World Hatching
1. **Virtual Memory Cargo Extraction:** Perishable cargo in refrigerated capsules and all unit-producing cargo (`biter-egg`, `pentapod-egg`, `captive-biter-spawner`) are suspended inside `cap_data.virtual_cargo` as stack specifications rather than physical liminal container slots, completely shielding them from Factorio's engine-level 1.0 container decay.
2. **True Dilated Dual-Horizon Latent Scheduling:** Replaced periodic 1-second scanning with an event-driven indexed priority min-heap (`storage.spoil_heap`). The recheck horizon wakes strictly at:
   $$t_{\text{recheck}} = t_{\text{now}} + \min(t_{\text{coolant\_depletion}}, t_{\text{spoil\_dilated}})$$
   using closed-form elapsed time math. Idle tick execution cost is a single $O(1)$ heap peek comparison.
3. **Waveform Collapse on Delivery & Spillage:** Delivery at hubs (`hub-unpacking.lua`) or ground destruction (`hub-spill.lua`) executes `capsule_manager.collapse_virtual_cargo`, deducting dilated spoilage percentages and cooling charges before materializing exact physical stacks into containers or spill entities.
4. **Dynamic In-World Trigger Spawning:** Unit-producing cargo that reaches 100% spoilage mid-flight inspects Factorio prototype `spoil_to_trigger_result` metadata to determine entity types (`big-wriggler-pentapod-premature`, `big-biter`, `behemoth-biter`), scales unit count by `items_per_trigger` (`ceil(count / items_per_trigger)`), and inherits egg quality. Enemies spawn directly in-world at the capsule's real-world spatial coordinates along the flight corridor. Moat watchers and liminal surface fallbacks are retired.
5. **Coolant Depletion & Spent Shell Conversion:** Health clamp floor is set to 0.0001, allowing the final cooling charge to deplete cleanly to 0.0. Depleted shells convert into `spent-refrigerated-capsule`, inheriting parent quality tier (`qual_name`).
6. **Automatic Stable Demotion & Eviction:** When all perishable contents spoil or are removed, `schedule_dynamic_cargo` returns `nil`, evicting the capsule from `storage.spoil_heap` and setting `is_stable = true`.

### 5.23 Timed Ballistics Engine: Production Baseline, Dynamic Horizon Scanning & Impact Clearance
1. **Production Velocity Constant Synchronization:** Transit speed operates at baseline production velocity of 50 tiles per second, governed by synchronized constants:
   $$\text{TICKS\_PER\_HOP} = 6, \quad \text{TICKS\_PER\_TILE} = 1.2$$
   Departure and arrival horizons evaluate closed-form timing without interpolation drag.
2. **Timed Kinetic Arrival Scheduler:** Ballistic launches schedule arrivals in an indexed binary min-heap (`storage.kinetic_arrival_heap`) with arrival tick $t_{\text{arrival}} = t_{\text{start}} + \lceil \text{distance} \times 1.2 \rceil$. Intake docks unpark immediately on dispatch, eliminating backpressure stalls. Arrivals execute via string-identified callback handlers, permanently excluding function closures from serialization.
3. **Pre-Launch Aperture Clearance Sweep:** Launches evaluate a clearance probe centered 0.5 tiles forward (`muzzle_node.pos + dir * 0.5`) directly inspecting the chassis perimeter interface. Obstacles overlapping the aperture face trigger instant point-blank impact and capacitor discharge.
4. **Autonomous Flight Corridor Motion BVH:** Trajectories register into `storage.motion_bvh[surface_index]` via `timed_motion.ensure_corridor`, subdivided into 16-tile static leaves. Flight corridors remain pinned in `storage.pinned_corridors` during transit and wake reeling. Corridors belonging to active projector muzzles remain pinned to eliminate segment churn.
5. **Colinear Receiver Docking & Chassis Tolerance:** Receiver docking coordinates snap directly to perimeter edge sockets ($cx - dir.x \times 1.5, cy - dir.y \times 1.5$) with perpendicular coordinate locking. Native terminal arrival edge checks test physical `cand.bounding_box` within a 0.5-tile narrow-phase tolerance, spanning Factorio's 0.30-tile chassis inset. Docking clears `capsule.beam_flight = nil`, enabling peaceful deconstruction spilling.
6. **Quality-Scaled Splash Damage & Entity Immunity:** Terminal impacts execute `apply_crash_damage` with a 3.5-tile blast radius and falloff, dealing $250 \times (1 + 0.3 \times q_{\text{level}})$ impact damage to players, enemies, and vehicles while shielding `visible-capsule-holder` spill containers.

### 5.30 Indexed Binary Heap Priority Queue, Sanitization & Amortized Buffer Deflation
1. **Indexed Priority Min-Heap Schema:** `binary-heap.lua` maintains an array buffer paired with an $O(1)$ reverse lookup map (`indices[id] = pos`). Insertion, priority updates, and removals run in $O(\log N)$ time; peek runs in $O(1)$.
2. **Persistent Closure Purging & Attachment Sanitization:** Engine autosaves are protected by banning Lua function references in `storage`. `binary_heap.attach(table, comp_type)` explicitly sets `heap.comparator = nil` upon deserialization, binding comparison logic via registered string keys.
3. **Zero-Allocation Buffer Pooling:** Elements are popped by decrementing virtual size (`size = size - 1`), retaining table allocations in a sliding virtual buffer for subsequent pushes without Lua GC thrashing.
4. **Dual-Watermark Hysteresis Deflation:** `step_decay()` runs on 120-tick maintenance cycles (`control.lua`). If buffer capacity exceeds the trigger ceiling (`size * 3 + 128`), tail slots beyond the retention floor (`size * 1.5 + 64`) are truncated into `nil` (up to 8 slots per cycle).
5. **Save-File Compaction:** `compact(safety_margin)` clamps cold heap buffers to 64 safety items during `setup_storage` on save/load cycles.

### 5.31 Observer-Driven Viewport BVH, Fixed-Leaf Hysteresis & Active Visibility Sets
1. **Fixed-Leaf Viewport Hysteresis Boundary:** The observer hysteresis shell utilizes a fixed 16-tile margin (`SHELL_TILES = 16`), matching exactly one static BVH leaf in every direction. Maximum trailing buffers are capped to 32 tiles at any camera zoom level, eliminating massive off-screen voids.
2. **Dynamic Zoom-In Contraction Trigger:** Viewport contraction triggers when camera zoom changes by 25% (`SHRINK_THRESHOLD = 0.75`), removing arbitrary 150-tile clamping ceilings and UI scale divisors from screen frustum calculations.
3. **Stationary Player Fast-Path:** Viewports cache `last_player_x`, `last_player_y`, and `last_zoom`. Stationary cameras with unchanged zoom bypass frustum half-dimension and padding math in sub-microsecond time.
4. **Namespaced Active Visibility Sets:** `storage.player_visible_set[player_index]` indexes visible corridor leaves using composite `owner_id:seg_key` strings, preventing concurrent beams from colliding or hijacking shared render arrays.
5. **Logarithmic Viewport Queries & Segment Pruning:** Linear player scans are replaced with $O(\log N_{\text{players}})$ queries (`is_in_any_viewport`, `query_players_in_box`). Dead segments unregister across intermediate 16-tile hops and terminal arrivals via `viewport_bvh.on_segment_removed`.

### 5.32 High-Throughput LuaRenderObject Recycling Pool & Zero-Allocation Safety
1. **Centralized Render Pool Engine:** `render-pool.lua` maintains object caches partitioned by player, surface, and visual archetype (`circle`, `sprite`, `text`, `line`). Leased handles mutate native Factorio 2.0 properties in-place.
2. **Double-Free & Recycling Guard:** `render_pool.recycle` enforces an early-exit visibility guard (`if not obj.visible then return end`) preventing duplicate insertions into player free lists, and caps pools at a 128-object per-archetype high-water ceiling.
3. **Explicit Player Index Signature:** Recycling invocations require explicit `player_index` parameters (`render_pool.recycle(player_index, obj)`), ensuring culled primitives return strictly to the owning player's pool without handle leaking.

### 5.33 Electromagnetic Harness Suit Gatekeeping & Player Transit Collision Safety
1. **Armor Grid Energy Gatekeeping:** Player transit capsules require an active `electromagnetic-harness` equipment module in the passenger's armor grid with stored energy exceeding 100 kJ (`player_has_harness`). Capsules carrying unequipped or unpowered passengers are rejected from projector intake docks, falling through to tube pressure routing.
2. **Passenger Self-Collision Suppression:** `check_player_collision` verifies character entities and player indices against capsule passenger records, preventing flying projectiles from colliding with their own riders upon leaving muzzles or during flight.
3. **Emergency Ejection:** Custom input `capsule-emergency-exit` (`SHIFT + E`) dispatches `capsule_runner.emergency_eject`, disembarking passengers onto safe ground tiles, destroying holder entities, and unregistering motion records.

### 5.34 Generalized Timed Motion Trajectories & Decoupled Projector Muzzle Ballistics
1. **Generic Timed Motion Records:** `timed_motion.lua` supports non-capsule projectiles with custom `kind`, `render_spec`, `metadata`, and string-typed `on_arrival` callbacks registered in `storage.timed_flight_records`.
2. **Decoupled Projector Ballistics:** Unified launcher `capsule_ballistics.launch_timed_flight` allows projectors to fire generic directional projectiles and pin persistent 16-tile BVH corridors without requiring physical capsule containers.
3. **Custom Visual Pipeline:** `render_custom_flight_for_player` leases composite sprites and primitive circles from `render-pool.lua`, rendering custom projectiles in Alt-Mode without debug overrides.

### 5.44 Modular Motion Subprotocol Architecture & Flight Clearance Bifurcation
1. **Composable Facet Subprotocols (`motion-protocols.lua`):** Decouples flight simulation and rendering into 5 orthogonal, mixin-capable facets:
   - **Heads:** `capsule_head`, `hazard_reticle`, `custom_flight`, `none`.
   - **Trails:** `reticle_dots`, `wake_peeling`, `none`.
   - **Disruptions:** `ballistic_crash`, `reticle_slice`, `peaceful_spill`, `silent_halt`, `none`.
   - **Arrivals:** `capsule_terminal`, `scope_step`, `anti_reticle_step`.
   - **Static Overlays:** `reticle_static` (extracting beam dot leasing, endpoint rings, and static hazard markers out of `viewport-bvh.lua`).
2. **Universal Detector Registry:** Centralizes collision querying behind standardized detectors:
   - `open_air_solids`: Evaluates physical ground entities and dynamic gates using `motion_protocols.scan_open_air_leaf`.
   - `tube_connectivity`: Verifies pneumatic network continuity and pressure gradients.
3. **Directional Clearance Policies:** Coordinates obstacle response via standardized policies: `optical_ray`, `discrete_projectile`, `peaceful_transit`, `silent_wave`.
4. **Mathematical Relative Clearance Bifurcation:** `motion_protocols.dispatch_clearance_policy` computes relative axis displacement:
   $$\Delta d = d_{\text{obst}} - d_{\text{current}}$$
   Routing is strictly partitioned by relative distance:
   - **Forward Obstacle ($d_{\text{obst}} > d_{\text{current}} + 0.05$):** Dispatches to `on_forward` to reschedule arrival heap deadlines and clamp target horizons without visual snapping.
   - **Backward Obstacle ($d_{\text{obst}} \le d_{\text{current}} + 0.05$):** Dispatches to `on_backward` to execute tail severing, immediate corridor truncation, or projectile pass-through.
5. **Zero Runtime Require Violations:** All protocols, detectors, and policies register at initialization time, eliminating runtime `require()` calls inside Factorio event listeners.

### 5.45 Collective Observation Governor, Amortized Pre-Calculation Buffer & Lockstep Rendering
1. **Communal Observation Governor:** `update_governor` in `prepare_frame()` aggregates unique visible in-flight capsules across all connected players with Alt-Mode active in non-chart viewports. Returns in 0.00 ms CPU time when idle.
2. **Schmitt-Trigger Hysteresis & Emergency Surge Drop:** Modulates visual refresh rate with smoothed thresholds:
   - $60\text{ FPS} \rightarrow 30\text{ FPS}$ when visible capsules $\ge 30$; $30\text{ FPS} \rightarrow 60\text{ FPS}$ when $\le 18$.
   - $30\text{ FPS} \rightarrow 20\text{ FPS}$ when visible capsules $\ge 75$; $20\text{ FPS} \rightarrow 30\text{ FPS}$ when $\le 50$.
   - **Emergency Override:** Instantly drops to 20 FPS upon sudden surges ($\ge 120$ count or $\Delta \ge 40$).
3. **Wake Peeling Governor Awakening & 60 FPS Lock:** Visible retreating corridors (`reticle.retreat_tick`) register as active governor workload, preventing the renderer from entering idle sleep during wake retraction and locking cadence strictly to 60 FPS for smooth frame-by-frame dot peeling.
4. **Pre-Allocated Pre-Calculation Buffer (`storage.render_precalc_buffer`):** Employs an in-place mutating vector buffer with high-water watermark tracking. Amortized tail slots are truncated on 120-tick maintenance cycles (`step_buffer_decay`).
5. **Time-Sliced Quiet-Tick Math Slicing:** `step_precalculations` computes closed-form forward coordinates during quiet ticks preceding render frames:
   - **30 FPS:** 100% computed on `tick - 1`.
   - **20 FPS:** Sliced 50% on `tick - 2` and 50% on `tick - 1`.
   This flattens render frame-time spikes before visual updates execute.
6. **Global Lockstep Render Flushing:** Renders flush globally across players on synchronized ticks (`current_tick % cadence == 0`) using `get_flight_position`, eliminating multiplayer accordion stretching.
7. **Static Corridor Early-Skip Filtering:** Viewport rendering checks `scratch_active_owners` to skip hundreds of static, completed beam corridors on line 1, reducing render dispatch times by ~40%.
8. **Frustum-Culled Arrival Reticles:** Scheduled landing position and crash site reticles evaluate screen bounding boxes in `render_arrival_dot_for_player`, destroying handles and bypassing leasing when arrival points lie off-screen.

### 5.46 Forward-Looking Ballistic Arrival Rescheduling & Decaying Corridor Lifecycles
1. **Forward-Looking Arrival Horizon Math:** When dynamic obstacles clear or shift, `timed_motion.shift_horizon` recalculates remaining flight duration strictly forward from the current tick:
   $$t_{\text{arrival}} = t_{\text{current}} + \lceil (\text{record.total\_dist} - d_{\text{current}}) \times 1.2 \rceil$$
   Calculating forward eliminates backwards time calculation errors that previously triggered instantaneous mid-air explosions and false ground spillage.
2. **Corridor Leaf Preservation & Zero Geometry Churn:** `shift_horizon` updates flight records and binary arrival heap priorities in-place, eliminating destructive corridor teardowns and recreations (`remove_corridor` / `ensure_corridor`). Communal 16-tile BVH leaves remain pinned in `storage.motion_bvh` and player viewports throughout transit.
3. **Event-Driven Decaying Corridors:** Corridors unlinked from receivers while capsules remain in flight are indexed in `storage.decaying_corridors`. Corridors remain pinned in memory until the last payload arrives or impacts. Teardown executes directly inside `remove_flight` the exact tick in-flight count reaches zero, avoiding background polling loops.
4. **Motion Sub-Profiler Breakdown:** `capsule_runner.update_capsules` measures discrete performance across three isolated timers:
   - `Tube Traversal`: Discrete 6t hops and diverter routing.
   - `Ballistics & Heap`: Arrival heap stepping and projectile physics.
   - `Frame Sync`: Governor aggregation, pre-calculations, and viewport sets.

---

## 4. Visual Overlay Specifications & Color Registry

### 4.1 Runtime Script Render Layers (`render_pool` & `rendering.draw_*`)

| Render Layer Name / Target Pass | Module Source | Object Type | API Method / Pool | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `"light-effect"` | `capsule-transit.lua` | Text | `render_pool.lease_text` | No | Renders `" [Shift + E] Emergency Eject "` HUD text centered above riding passenger capsules (`scale = 0.9`, offset `y + 0.8`). |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `render_pool.lease_circle` | No (Debug) | Renders cyan passenger ring (`radius = 0.45`, `width = 3`) around player-occupied capsules. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `render_pool.lease_circle` | No (Debug) | Renders capsule variant debug border ring (`radius = 0.35`, `width = 2`) using capsule RGBA debug colors. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Sprite | `render_pool.lease_sprite` | No (Debug) | Renders dominant payload item icon (`"item/" .. item_name`, `scale = 0.55`) inside capsule debug ring. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `render_pool.lease_circle` | No (Debug) | Renders filled color dot (`radius = 0.25`) for empty or unknown cargo capsules. |
| *Default Script Layer* | `capsule-renderer.lua` | Circle | `render_pool.lease_circle` | **Yes** | Renders timed arrival reticle inner dot (`radius = 0.12`, capsule variant color) at scheduled landing or impact coordinates (frustum-culled). |
| *Default Script Layer* | `capsule-renderer.lua` | Circle | `render_pool.lease_circle` | **Yes** | Renders timed arrival reticle target ring (`radius = 0.35`, green for receiver catchment dock, orange-red for obstacle crash) (frustum-culled). |
| *Default Script Layer* | `motion-protocols.lua` | Circle | `render_pool.lease_circle` | **Yes** | Renders static reticle corridor trail dots (`radius = 0.08` minor, `radius = 0.16` prominent) leased to BVH leaves. |
| *Default Script Layer* | `capsule-renderer.lua` | Circle / Sprite | `render_pool.lease_*` | **Yes** | Renders generic timed ballistic projectile sprites and composite coral markers (`radius = 0.18`). |

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