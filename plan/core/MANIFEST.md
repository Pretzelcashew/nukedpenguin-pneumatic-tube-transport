# MANIFEST.md - Mod Architecture Router & Master Lifecycle
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1 | **Expansion:** Space Age  
**Author / Maintainer:** Collaborator / Nukedpenguin  

---

## 1. System Architecture & Core Data Flow

```text
+---------------------------------------------------------------------------------------------------+
|                                          FACTORIO ENGINE                                          |
+---------------------------------------------------------------------------------------------------+
   | Build / Rotate / Flip / Mine / Object Destroyed / Custom Input / GUI / Research / Maintenance
   v                                                                                v Motion on_tick
+--------------------------------------------+      +-----------------------------------------------+
|  RUNTIME SIMULATION LAYER                  |      |  FLOW v2, SENSING, BVH & BALLISTICS ENGINE    |
|  - hub-manager (Interleaved 10t Scan,      |      |  - flow-engine / flow-common / flow-kinetic   |
|    60Hz 1t Continuous Belt Cadence,        |      |    (Event-Driven Delta Wavefront Engine,      |
|    Spent Hull Outbound Priority,           |      |    0-Tick Idle Queue Sleep, Quiescent Flow    |
|    Fast-Replace Position Cache)            |      |    Gating, Adaptive Batch Scaling 200/t,      |
|  - active-device-scanner (Unified 15t      |      |    Spatial Grid Topology surface@x,y,         |
|    Polymorphic Scanner Coordinator with    |      |    Direction-Scoped Kinetic Nodes, Dynamic    |
|    Dedicated Domain Managers:              |      |    Emission Scaling with Machine Quality,     |
|    pump-manager, diverter-manager,         |      |    Discrete Dual-Grid Character Colliders,    |
|    counter-manager, projector-manager)     |      |    Colinear Perimeter Edge Socket Docking,    |
|  - profiler (`scripts/utils/profiler.lua`) |      |    Natural 1-Tile/t Queue Recession Waves)    |
|    (Native LuaProfiler Timers, Defensive   |      |  - trajectory-bvh (`scripts/utils/`)          |
|    Wrappers, 60t Snapshot Diagnostics)     |      |    (Instantiable Procedural Dynamic AABB      |
|  - proxy-manager (Triple-Proxy &           |      |    Trees, 16-Tile Leaf Segments, Spatial      |
|    Projector Proxy Architecture, Radius-   |      |    Obstacle Interception, High-Water Pool     |
|    Based Host Discovery r=0.5, Selection   |      |    Recycling, Deferred Leaf Unregistration,   |
|    Z-Index, Wire Merge & Destruction)      |      |    Dual-Watermark Amortized Buffer Decay)     |
|  - blueprint-sync (`scripts/utils/`)       |      |  - viewport-bvh & render-pool (`utils/`)      |
|    (4-Tuple Wire Serialization, Tag        |      |    (3-Tier Concentric Hysteresis Viewports,   |
|    Packing, Ghost Tag Zero-Tick Linking)   |      |    Active Player Visibility Sets, Native      |
|  - device-settings-copier (Live Source     |      |    LuaRenderObject Pooling & In-Place Mutate) |
|    Copy Buffer, Rotation Delta Paste,      |      |  - port-defs / flow-gate-interop              |
|    Live GUI Subscriber Auto-Refresh)       |      |    (Domain Transmission Flags: capsule,       |
|  - diverter-gui & diverter-slot-modal      |      |    pressure, sense, kinetic; Dual-Grid Axis   |
|    (4-Port Overview & Modal Dialogs)       |      |    Snapping; Wall Axis Locks & Gate Cutoffs)  |
|  - diverter-renderer & flow-renderer       |      |  - counter-range & counter-logic              |
|    (Alt-Mode Adaptive Filter Overlays,     |      |    (Event-Driven Territory Capsule Indexing,  |
|    Dominant Pressure & Kinetic Reticles)   |      |    Pre-Aggregated Stable Signal Memoization,  |
|  - gui-components, gui-filter-spec,        |      |    Zero C++ Polling, Triple-Proxy Channel     |
|    gui-quality-bar (Declarative Widgets)   |      |    Isolated Output Signal Emission)           |
|  - hub-packing / unpacking / spill         |      |  - capsule-runner & capsule-transit           |
|    (Selective Virtual Memory Cargo,        |      |    (Granular 6t Hop Motion Coordinator,       |
|    Dilated Spoilage Waveform Collapse,     |      |    EM Harness Equipment >100 kJ Gatekeeping,  |
|    Docked Peaceful Spilling Normalization) |      |    Zero-Alloc Scratch, Self-Collision Shield) |
|  - belt-siphon (Pressure-Governed          |      |  - capsule-ballistics & timed-motion          |
|    Bidirectional Siphon/Exhaust, 1-Tick    |      |    (Indexed Binary Min-Heap Timed Arrivals,   |
|    Continuous Cadence, Gleba Stacking)     |      |    Continuous Velocity Vector Interpolation,  |
|  - projector-settings (3 MW Baseline Idle, |      |    Distance-Synchronized Timing, In-Flight    |
|    9 MJ Buffer, 180t Grace Period)         |      |    Forward Horizon Scanning, Splash Damage)   |
|  - liminal-surface (Unified 2-Tile Grid)   |      |  - binary-heap & capsule-lifecycle            |
|                                            |      |    (Pooled Min-Heap Event-Driven Spoilage)    |
+--------------------------------------------+      +-----------------------------------------------+
```

---

## 2. Subsystem Domain Directory

| Subsystem Document | Domain Coverage | Key Files | Key Storage Tables |
| :--- | :--- | :--- | :--- |
| **`docs/arch/ARCH-PROTOTYPES.md`** | Data stage prototypes, recipes, tech trees, items, entity definitions, sprite composite layers, Space Age planetary economics, electromagnetic harness equipment module. | `data.lua`, `prototypes/entity.lua`, `prototypes/entities/*.lua`, `prototypes/item.lua`, `prototypes/recipe.lua`, `prototypes/technology.lua`, `prototypes/custom-input.lua`, `prototypes/shortcut.lua` | None (Data stage) |
| **`docs/arch/ARCH-FLOW-KINETICS.md`** | Flow v2 wavefront propagation, delta queues, direction-scoped kinetic trajectories, spatial Trajectory BVH obstacle interception, dual-grid character colliders, colinear receiver docking, wall/gate interop. | `scripts/flow/port-defs.lua`, `scripts/flow/flow-common.lua`, `scripts/flow/flow-engine.lua`, `scripts/flow/flow-kinetic.lua`, `scripts/flow/flow-renderer.lua`, `scripts/flow/flow-gate-interop.lua`, `scripts/counters/counter-range.lua` | `flow_grid`, `flow_nodes`, `flow_connections`, `flow_queue`, `flow_levels`, `surface_bvh`, `kinetic_levels`, `kinetic_beam_tiles`, `pending_bvh_segments`, `character_colliders`, `character_last_keys`, `flow_renders`, `flow_edge_renders`, `kinetic_renders`, `counter_renders`, `counter_levels`, `counter_owners`, `counter_owned_nodes`, `counter_queue`, `counter_capsules`, `counter_stable_summary`, `counter_stable_capsules`, `counter_dynamic_capsules`, `active_walls`, `active_gates`, `gate_cutoff_states`, `wall_locked_group`, `soft_interop_registry`, `interop_activation_queue` |
| **`docs/arch/ARCH-CAPSULES-MOTION.md`** | Granular 6t runner coordinator, timed ballistics min-heap, spatial corridor BVH, observer viewport BVH, native render pool, virtual memory cargo suspension, dilated spoilage heap, in-world enemy hatching, unified liminal grid. | `scripts/capsules/capsule-definitions.lua`, `scripts/capsules/capsule-inputs.lua`, `scripts/capsules/capsule-transit.lua`, `scripts/capsules/capsule-ballistics.lua`, `scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-manager.lua`, `scripts/capsules/capsule-queries.lua`, `scripts/capsules/capsule-renderer.lua`, `scripts/capsules/capsule-runner.lua`, `scripts/surfaces/liminal-surface.lua`, `scripts/utils/binary-heap.lua`, `scripts/utils/trajectory-bvh.lua`, `scripts/utils/viewport-bvh.lua`, `scripts/utils/timed-motion.lua`, `scripts/utils/render-pool.lua` | `liminal_grid`, `occupancy`, `active_capsules`, `capsules`, `parked_by_port`, `spoil_heap`, `kinetic_arrival_heap`, `motion_bvh`, `projector_flights`, `timed_flight_records`, `viewport_bvh`, `player_viewports`, `player_visible_set`, `render_pool`, `debug[player_index]` |
| **`docs/arch/ARCH-HUBS-LOGISTICS.md`** | Hub packing & unpacking, virtual memory cargo extraction & waveform collapse, 60Hz continuous belt siphoning/depositing, Gleba belt stacking, cargo planning, spill containers, container clamping, peaceful docked projector spilling. | `scripts/hubs/hub-definitions.lua`, `scripts/hubs/hub-gui.lua`, `scripts/hubs/hub-manager.lua`, `scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-settings.lua`, `scripts/hubs/hub-spill.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/packing/belt-siphon.lua`, `scripts/hubs/packing/cargo-planner.lua`, `scripts/hubs/packing/quality-filter.lua`, `scripts/utils/item-transfer-handler.lua` | `active_hubs`, `hub_settings`, `hub_receive_locks`, `spilled_containers`, `hub_fast_replace_cache` |
| **`docs/arch/ARCH-DEVICES-CIRCUITS.md`** | Unified 15t polymorphic scanner coordinator, dedicated domain managers, native profiler instrumentation, Triple-Proxy channel isolation, radius-based ghost proxy preservation, blueprint wire serialization, live settings copy buffer, modular GUI components & slot modals. | `scripts/active-device-scanner.lua`, `scripts/proxy-manager.lua`, `scripts/device-settings-copier.lua`, `scripts/utils/blueprint-sync.lua`, `scripts/utils/profiler.lua`, `scripts/utils/gui/gui-filter-spec.lua`, `scripts/utils/gui/gui-quality-bar.lua`, `scripts/utils/gui-components.lua`, `scripts/diverters/*.lua`, `scripts/pumps/*.lua`, `scripts/counters/*.lua`, `scripts/projectors/*.lua` | `active_pumps`, `active_diverters`, `active_projectors`, `counter_*`, `diverter_*`, `pump_*`, `projector_*`, `fast_replace_cache`, `ghost_*`, `player_copy_buffer`, `port_clipboard`, `object_destruction_map` |

---

## 3. Master Event Hook & Lifecycle Matrix

| Factorio Engine Event | Custom Dispatcher / Handler Module | Actions Triggered |
| :--- | :--- | :--- |
| `script.on_init`<br>`script.on_configuration_changed` | `control.lua` -> `setup_storage()`<br>`scripts/flow/flow-engine.lua`<br>`scripts/proxy-manager.lua`<br>`scripts/diverters/diverter-renderer.lua`<br>`scripts/counters/counter-range.lua`<br>`scripts/utils/trajectory-bvh.lua`<br>`scripts/utils/viewport-bvh.lua`<br>`scripts/utils/timed-motion.lua`<br>`scripts/utils/binary-heap.lua` | Initializes storage schema (unified liminal grid, occupancy index, counter settings/stable summaries, projector state tables, kinetic renders, v2 flow grid/queue, soft registry, fast-replace caches, object destruction map, spatial BVH trees, binary heaps, render pool); executes boundary compaction clamping cold heap/BVH buffers to 64 safety items; purges map orphan proxies via `proxy_manager.purge_orphans()`; refreshes Alt-Mode overlays. |
| `script.on_nth_tick(120)` | `control.lua` | Low-frequency maintenance cycle executing amortized free list decay and buffer deflation across `storage.spoil_heap`, `storage.kinetic_arrival_heap`, `storage.surface_bvh`, `storage.motion_bvh`, and `storage.viewport_bvh` to prevent save-file bloat. |
| `defines.events.on_built_entity`<br>`defines.events.on_robot_built_entity`<br>`defines.events.script_raised_built`<br>`defines.events.on_space_platform_built_entity`<br>`defines.events.on_entity_cloned` | `scripts/proxy-manager.lua`<br>`scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua`<br>`scripts/utils/blueprint-sync.lua`<br>`scripts/device-settings-copier.lua`<br>`scripts/diverters/diverter-renderer.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/flow/flow-kinetic.lua`<br>`scripts/capsules/capsule-ballistics.lua` | Blueprint ghost exclusion suppresses flow node creation. Inspects `entity.tags` alongside `event.tags` on ghost builds. Executes instant zero-state spatial wire target resolution (`process_entity_built_wire_tags`). Creates real and ghost circuit proxies with radius-based host entity discovery (`radius = 0.5`) to preserve proxies during 2x2 diverter builds, links sub-proxies, syncs direction, enforces Z-indexing (`selection_priority = 60`), merges wires. Dynamic Trajectory BVH queries (`query_box`) intercept kinetic corridors in $O(\log N)$ time, dynamically catching projectiles if placed entity is a receiving projector (`handle_motion_obstacle_changed`) or rescheduling arrival crash sites. Wakes ports. |
| `defines.events.on_player_mined_entity`<br>`defines.events.on_robot_mined_entity`<br>`defines.events.on_entity_died`<br>`defines.events.script_raised_destroy`<br>`defines.events.on_space_platform_mined_entity` | `scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua`<br>`scripts/proxy-manager.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/flow/flow-kinetic.lua`<br>`scripts/hubs/hub-spill.lua`<br>`scripts/diverters/diverter-renderer.lua`<br>`scripts/counters/counter-range.lua`<br>`scripts/capsules/capsule-ballistics.lua` | Fast-replace co-existence scan transfers settings proactively and seeds fallback cache (60t expiry). Destroys proxies via `destroy_all_proxies_at`; severs spatial links. Teardown deduplication (`is_tracked`) in `handle_object_destroyed` skips redundant teardown passes; receiver deconstruction scans strictly restricted to `pneumatic-projector`. Docked capsules inside mined receiving projectors execute peaceful ground spilling; in-flight ballistic projectiles are excluded from sender deconstruction spillage, continuing to downstream destinations. Clearing obstacles alerts trajectories via Trajectory BVH queries, regrowing kinetic beams. |
| `defines.events.on_player_rotated_entity`<br>`defines.events.on_player_flipped_entity` | `scripts/proxy-manager.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/flow/flow-kinetic.lua`<br>`scripts/active-device-scanner.lua`<br>`scripts/diverters/diverter-settings.lua`<br>`scripts/projectors/projector-settings.lua` | Syncs proxy orientation & selection Z-indexing; executes polymorphic `on_rotate_delta` across domain managers. Diverters execute modulo port rotation (`rotate_ports`) and flipping (`flip_ports`). Projectors update `muzzle_dir`; unlinking muzzle enqueues Tile 1 into `flow_queue`, driving natural 1-tile/t queue recession while the new vector advances. Re-indexes spatial nodes, updates cutoff states, and enqueues ports. |
| `defines.events.on_research_finished`<br>`defines.events.on_research_reversed` | `scripts/flow/flow-gate-interop.lua`<br>`scripts/flow/flow-engine.lua` | `on_research_finished`: Migrates matching `soft_interop_registry` walls/gates into `interop_activation_queue` (drained 10/t). `on_research_reversed`: Triggers boundary severing, port enqueuing, and zero-equilibrium soft demotion. |
| `defines.events.on_player_setup_blueprint` | `scripts/utils/blueprint-sync.lua`<br>`scripts/device-settings-copier.lua` | Deep-copies settings into blueprint tags (`pneumatic_settings`), serializes wire connections via 4-element tuples `[entity_from, wire_from, entity_to, wire_to]` and invariant bp indices, serializing projector muzzle direction atomically. |
| `defines.events.on_blueprint_settings_pasted` | `scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua`<br>`scripts/device-settings-copier.lua` | Stamping blueprints or pasting settings updates built/ghost entities in-place using `pneumatic_settings` tags and `previous_direction` delta rotations, auto-refreshing open GUIs via `on_settings_changed`. |
| `defines.events.on_player_configured_blueprint`<br>`defines.events.on_gui_closed` | `scripts/utils/blueprint-sync.lua`<br>`scripts/device-settings-copier.lua` | Scans active blueprint handles & books via `clean_blueprint_orphans` to purge orphan circuit proxy records when main devices are removed in blueprint UI. |
| Custom Input / Pasted Event (`pneumatic-copy-settings`, `pneumatic-paste-settings`, `on_entity_settings_pasted`) | `scripts/device-settings-copier.lua`<br>`scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua` | Tracks live entity source in copy buffer (`storage.player_copy_buffer`), applies relative step rotations on paste, writes settings into `destination.tags` on ghost targets, and auto-refreshes open destination GUIs. |
| Custom Input (`pneumatic-confirm-gui`) | `scripts/diverters/diverter-slot-modal.lua` | Records `confirm_ticks[player_index]` to differentiate E (Confirm, apply draft) from Esc (Cancel, discard draft) on modal slot config window closing. |
| `defines.events.on_object_destroyed` | `scripts/proxy-manager.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/capsules/capsule-manager.lua` | Auto-destroys unanchored orphan proxies/ghosts with radius-based discovery; maps registration ID, purges destroyed structures or liminal holders, teleports passengers, wakes parked capsules, severs boundary edges, and purges projector render objects instantly. |
| `defines.events.on_gui_opened`<br>`defines.events.on_gui_closed`<br>`defines.events.on_gui_checked_state_changed`<br>`defines.events.on_gui_switch_state_changed`<br>`defines.events.on_gui_elem_changed`<br>`defines.events.on_gui_click` | `scripts/pumps/pump-gui.lua` / `scripts/diverters/diverter-gui.lua`<br>`scripts/diverters/diverter-slot-modal.lua`<br>`scripts/hubs/hub-gui.lua` / `scripts/counters/counter-gui.lua`<br>`scripts/hubs/hub-spill.lua` / `scripts/utils/gui-components.lua`<br>`scripts/debug-manager.lua` | Restores fallback tags on ghost GUI open to guarantee pasted settings display prior to placement. Diverter, Pump, Counter, Projector & Hub proxies: opens configuration GUI for main entity. Spilled containers: dismisses GUI instantly to permit fast Ctrl+Click looting. Modal slot config frames isolate draft edits. Declarative UI component handlers mutate settings and trigger `notify_settings_changed` to wake parked capsules & sync flow. |
| `defines.events.on_lua_shortcut` | `scripts/debug-manager.lua` | Master hotbar shortcut (`pt-debug-panel`): Toggles Pneumatic Control Panel Lua GUI frame with live subsystem performance profiler table. |
| Custom Input (`capsule-emergency-exit` / Shift+E) | `scripts/capsules/capsule-inputs.lua` -> `scripts/capsules/capsule-transit.lua` | Triggers `capsule_transit.emergency_eject` for passenger disembarkation, holder destruction, and tracking unregistration. |
| `defines.events.on_tick` | `scripts/active-device-scanner.lua`<br><br>`scripts/hubs/hub-manager.lua`<br><br>`scripts/hubs/hub-spill.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/flow/flow-kinetic.lua`<br><br>`scripts/capsules/capsule-runner.lua`<br>`scripts/capsules/capsule-ballistics.lua`<br>`scripts/capsules/capsule-renderer.lua`<br>`scripts/capsules/capsule-lifecycle.lua` | **15t:** Unified scanner loop (dispatches polymorphic managers for Pumps/Diverters/Counters/Projectors; sub-profiler metrics; prunes `fast_replace_cache` >60t).<br>**1t continuous:** Belt siphon and deposit; **10t interleaved:** hub packing scan; receive lock reset; prunes `hub_fast_replace_cache` >60t.<br>**60t:** Spilled empty container cleanup.<br>**1t:** Wavefront step (quiescent connection gating, adaptive batching scaled to 200/t when queue > 500); steps discrete character colliders; compacts pending BVH segments; drains interop queue; monitors cutoff states; steps timed arrival heap and updates projector flights.<br>**6t staggered:** Granular node hops; receiver catchment; diverter quality filtering; sliding-scale viewport renders dispatched ($C \in \{1, 2, 3, 6\}$) over active visibility sets; continuous vector velocity interpolation.<br>**Event-driven:** `step_spoil_heap` peek and pop processing dynamic virtual cargo and dilated coolant lifecycles at exact expiration timestamps. |

---

## 4. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/pneumatic-panel` | Opens or toggles master Pneumatic Control Panel Lua GUI frame with live subsystem profiler table (`debug_manager.toggle_panel()`). Alias: `/debug-panel`. | `scripts/debug-manager.lua` |
| `/debug-filter <text>` | Sets debug chat prefix filter string (`storage.debug[player_index].filter`), suppressing non-matching console prints. | `scripts/debug-manager.lua` |
| `/debug-filter-reset` | Clears debug chat prefix filter, allowing all active prints to display. | `scripts/debug-manager.lua` |
| `/toggle-debug` | Toggles master debug mode on/off for player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging for player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles v2 visual flow vectors, pressure numbers, connections, and kinetic trajectories in Alt Mode (`storage.debug[player_index].new_flow`). Alias: `/pt-toggle-flow`. | `scripts/debug-manager.lua` |
| `/toggle-counter-range` | Toggles Capsule Counter sensing range overlays and owner dots in Alt Mode (`storage.debug[player_index].counter_range`). Alias: `/pt-toggle-counter-range`. | `scripts/debug-manager.lua` |
| `/check-counters` | Displays debug status, total registered counters, queue lengths, and owned territory node counts across all active counters. | `scripts/counters/counter-range.lua` |
| `/toggle-capsules` | Toggles visual overlay for active capsule positions and dominant payload item icons (`storage.debug[player_index].capsules`). Mutually exclusive with `/toggle-capsule-peek`. | `scripts/debug-manager.lua` |
| `/toggle-capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering icons strictly for targeted structures. Alias: `/capsule-peek`. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |
| `/toggle-arrival-dots` | Toggles scheduled landing position and crash site reticles for in-flight timed ballistic projectiles in Alt Mode (`storage.debug[player_index].arrival_dots`). | `scripts/debug-manager.lua` |
| `/toggle-bvh` | Toggles spatial Trajectory BVH corridor bounding box visualization (green 16-tile leaf segments with distance labels). Alias: `/pt-toggle-bvh`. | `scripts/debug-manager.lua` |
| `/toggle-viewport-bvh` | Toggles player viewport spatial tree bounding boxes (concentric gold/green/cyan hysteresis boxes in Alt Mode). | `scripts/debug-manager.lua` |
| `/set-render-cadence <1\|2\|3\|6>` | Configures individual player viewport render refresh cadence governor in ticks with phase-staggered interleaving. | `scripts/capsules/capsule-renderer.lua` |
| `/check-queue` | Inspects active flow queue depth, batch processing limits, and active emitters without modifying queue state. | `scripts/flow/flow-engine.lua` |
| `/check-flow` | Displays active flow nodes, registered port connections, and current flow level distributions. | `scripts/flow/flow-engine.lua` |
| `/clear-queue` | Flushes all pending items from `storage.flow_queue` to resolve artificial queue stalls. | `scripts/flow/flow-engine.lua` |
| `/check-spoil-heap` | Inspects active dynamic spoilage priority queue depth, buffer capacity, and next scheduled capsule without modifying heap state. Alias: `/pt-check-spoil-heap`. | `scripts/debug-manager.lua` |
| `/clear-renders` | Destroys and reconstructs all active Alt-Mode pressure, counter range, and kinetic beam rendering overlays, resetting player render pools (`debug_manager.clear_all_renders()`). Alias: `/pt-clear-renders`. | `scripts/debug-manager.lua` |
| `/test-heap` | Runs the 8-suite automated self-test runner for the pooled indexed binary min-heap engine (`binary-heap.lua`). | `scripts/utils/binary-heap.lua` |
| `/test-bvh` | Runs the 7-suite automated self-test runner for procedural spatial Trajectory BVH trees (`trajectory-bvh.lua`). | `scripts/utils/trajectory-bvh.lua` |
| `/test-render-pool` | Runs the 6-stage automated verification suite for native `LuaRenderObject` leasing, property mutation, and recycling (`render-pool.lua`). | `scripts/utils/render-pool.lua` |
| `/test-viewport-bvh` | Runs the 7-stage automated verification suite for player viewport trees, concentric hysteresis shells, and observer intersection (`viewport-bvh.lua`). | `scripts/utils/viewport-bvh.lua` |
| `/test-render-dispatcher` | Runs the 5-stage automated verification suite for sliding-scale render dispatching, vector math, and cadence interleaving (`capsule-renderer.lua`). | `scripts/capsules/capsule-renderer.lua` |
| `/test-timed-motion` | Runs the 5-stage automated verification suite for flight corridor partitioning, active flight pinning, and timed arrival dispatching (`timed-motion.lua`). | `scripts/utils/timed-motion.lua` |