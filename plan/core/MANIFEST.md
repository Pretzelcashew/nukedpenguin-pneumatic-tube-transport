# MANIFEST.md - Mod Architecture Router & Master Lifecycle
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1 | **Expansion:** Space Age  
**Author / Maintainer:** Collaborator / Nukedpenguin  

---

## 1. System Architecture & Core Data Flow

```text
+-----------------------------------------------------------------------------------+
|                                 FACTORIO ENGINE                                   |
+-----------------------------------------------------------------------------------+
   | Build / Rotate / Flip / Mine / Object Destroyed / Custom Input / GUI / Research
   v                                                                        v Motion on_tick
+------------------------------------+      +---------------------------------------+
|  RUNTIME SIMULATION LAYER          |      |  FLOW v2 ENGINE, COUNTER & KINETICS   |
|  - hub-manager (Interleaved Scan,  |      |  - flow-engine (`scripts/flow/`)      |
|    60Hz 1t Continuous Belt Cadence,|      |    (Event-Driven Delta Wavefront      |
|    Spent Hull Outbound Priority,   |      |    Engine, 0-Tick Idle Queue Sleep,   |
|    Fast-Replace Position Cache)    |      |    Spatial Grid Topology surface@x,y, |
|  - active-device-scanner (Unified  |      |    Unified Sensing & Kinetic Waves,   |
|    15-Tick Scanner for Pumps,      |      |    Direction-Scoped Kinetic Nodes,    |
|    Diverters, Counters & Projector |      |    Ray-Box Line-of-Sight Occlusion,   |
|    Capacitor/Power State Machine)  |      |    Deterministic Territory Split,     |
|  - proxy-manager (Triple-Proxy &   |      |    Natural Recession Waves, Object    |
|    Projector Proxy Architecture,   |      |    Destruction Purge Engine)          |
|    Selection Z-Index, Linkage,     |      |  - port-defs (`scripts/flow/`)        |
|    Wire Merge & Destroyed Cleanup) |      |    (Domain Transmission Flags:        |
|  - device-settings-copier (Live    |      |    capsule/pressure/sense/kinetic,    |
|    Source Copy-Paste, Blueprint    |      |    Passive Hub Parity Intake Ports)   |
|    Wire Sync, Projector Muzzle     |      |  - fence/gate interop (in flow-engine)|
|    Rotation & Tag Deserialization) |      |    Vanilla Wall Axis Locking, Boundary|
|  - diverter-renderer (Alt-Mode 2x2 |      |    Cutoffs, Throttled Activation,     |
|    Port Filter Icon Overlay Engine)|      |    Wavefront Discovery & Demotion)    |
|  - gui-components (Declarative UI  |      |  - counter-range & counter-logic      |
|    Library, Quality Bar & Windows) |      |    (Channel-Isolated Proxy Signal     |
|  - hub-packing / unpacking / spill |      |    Emission for Red & Green Proxies)  |
|  - belt-siphon (Pressure-Governed  |      |  - capsule-runner (`scripts/capsules/`|
|    Bidirectional Siphon/Exhaust,   |      |    Granular 6t Hop Motion Engine,     |
|    1-Tick Cadence, Engine-Filtered |      |    Ballistic 5-Tile Prominent Hops,   |
|    Belts, Cargo-First 3-Tier Line  |      |    Zero-Alloc Player Target Scratch,  |
|    Ejection, Gleba Stacking)       |      |    Quality-Scaled Impact Collisions,  |
|  - projector-settings (3 MW Idle,  |      |    Receiver Catchment & In-Flight     |
|    9 MJ Buffer, 180t Grace Period, |      |    Momentum Preservation, Strict EM   |
|    2-Cap Congestion Throttling)    |      |    Gatekeeping, O(1) Spatial Parked)  |
|  - liminal-surface (Dual-Tier Grid)|      |                                       |
+------------------------------------+      +---------------------------------------+
```

---

## 2. Subsystem Domain Directory

| Subsystem Document | Domain Coverage | Key Files | Key Storage Tables |
| :--- | :--- | :--- | :--- |
| **`docs/arch/ARCH-PROTOTYPES.md`** | Data stage prototypes, recipes, tech trees, items, entity definitions, sprite composite layers, Space Age planetary economics. | `data.lua`, `prototypes/entity.lua`, `prototypes/entities/*.lua`, `prototypes/item.lua`, `prototypes/recipe.lua`, `prototypes/technology.lua`, `prototypes/custom-input.lua`, `prototypes/shortcut.lua` | None (Data stage) |
| **`docs/arch/ARCH-FLOW-KINETICS.md`** | Flow v2 wavefront propagation, delta queues, direction-scoped kinetic trajectories, ray-box occlusion, wall/gate interop. | `scripts/flow/port-defs.lua`, `scripts/flow/flow-engine.lua` *(includes gate interop)*, `scripts/counters/counter-range.lua` | `flow_grid`, `flow_nodes`, `flow_connections`, `flow_queue`, `flow_levels`, `kinetic_*`, `active_walls`, `active_gates`, `gate_*`, `wall_locked_group`, `soft_interop_*` |
| **`docs/arch/ARCH-CAPSULES-MOTION.md`** | Capsule runner 6t hop engine, 5-tile ballistic trajectories, player collision, spoilage decay, liminal grid allocations, O(1) occupancy. | `scripts/capsules/capsule-definitions.lua`, `scripts/capsules/capsule-inputs.lua`, `scripts/capsules/capsule-lifecycle.lua`, `scripts/capsules/capsule-manager.lua`, `scripts/capsules/capsule-queries.lua`, `scripts/capsules/capsule-renderer.lua`, `scripts/capsules/capsule-runner.lua`, `scripts/surfaces/liminal-surface.lua` | `liminal_grid`, `occupancy`, `active_capsules`, `capsules`, `parked_by_port`, `debug[player_index]` |
| **`docs/arch/ARCH-HUBS-LOGISTICS.md`** | Hub packing & unpacking, 60Hz continuous belt siphoning/depositing, Gleba belt stacking, cargo planning, spill containers, container clamping. | `scripts/hubs/hub-definitions.lua`, `scripts/hubs/hub-gui.lua`, `scripts/hubs/hub-manager.lua`, `scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-settings.lua`, `scripts/hubs/hub-spill.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/hubs/packing/belt-siphon.lua`, `scripts/hubs/packing/cargo-planner.lua`, `scripts/hubs/packing/quality-filter.lua`, `scripts/utils/item-transfer-handler.lua` | `active_hubs`, `hub_settings`, `hub_receive_locks`, `spilled_containers`, `hub_fast_replace_cache` |
| **`docs/arch/ARCH-DEVICES-CIRCUITS.md`** | 15t active device scanner, Triple-Proxy channel isolation, copy-paste engine, blueprint tags, Diverter/Pump/Counter/Projector GUIs & Alt-Mode overlays. | `scripts/active-device-scanner.lua`, `scripts/proxy-manager.lua`, `scripts/device-settings-copier.lua`, `scripts/diverters/*.lua`, `scripts/pumps/*.lua`, `scripts/projectors/projector-settings.lua`, `scripts/counters/*.lua`, `scripts/utils/gui-components.lua` | `active_pumps`, `active_diverters`, `active_projectors`, `counter_*`, `diverter_*`, `pump_*`, `projector_*`, `fast_replace_cache`, `ghost_*`, `player_copy_buffer`, `port_clipboard`, `object_destruction_map` |

---

## 3. Master Event Hook & Lifecycle Matrix

| Factorio Engine Event | Custom Dispatcher / Handler Module | Actions Triggered |
| :--- | :--- | :--- |
| `script.on_init`<br>`script.on_configuration_changed` | `control.lua` -> `setup_storage()`<br>`scripts/flow/flow-engine.lua`<br>`scripts/proxy-manager.lua`<br>`scripts/diverters/diverter-renderer.lua`<br>`scripts/counters/counter-range.lua` | Initializes storage schema (liminal grid, occupancy index, counter settings/levels, projector state tables, kinetic renders, v2 flow grid/queue, soft registry, fast-replace caches, object destruction map); purges map orphan proxies via `proxy_manager.purge_orphans()`; refreshes diverter Alt-Mode port filter overlays. |
| `defines.events.on_built_entity`<br>`defines.events.on_robot_built_entity`<br>`defines.events.script_raised_built`<br>`defines.events.on_space_platform_built_entity`<br>`defines.events.on_entity_cloned` | `scripts/proxy-manager.lua`<br>`scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua`<br>`scripts/device-settings-copier.lua`<br>`scripts/diverters/diverter-renderer.lua`<br>`scripts/flow/flow-engine.lua` | Blueprint ghost exclusion suppresses flow node creation. Physical machines inherit ghost settings (<0.1 tile tolerance, axis alignment guard) or fast-replace cache. Creates real and ghost circuit proxies, links sub-proxies (triple-proxy and projector schemas), syncs direction, enforces Z-indexing (`selection_priority = 60`), merges wires. Grid-touch connects physical gates/walls or indexes soft interop. Ray-box checks trigger kinetic truncation or demotion. Wakes ports. |
| `defines.events.on_player_mined_entity`<br>`defines.events.on_robot_mined_entity`<br>`defines.events.on_entity_died`<br>`defines.events.script_raised_destroy`<br>`defines.events.on_space_platform_mined_entity` | `scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua`<br>`scripts/proxy-manager.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/hubs/hub-spill.lua`<br>`scripts/diverters/diverter-renderer.lua`<br>`scripts/counters/counter-range.lua` | Fast-replace co-existence scan transfers settings proactively and seeds fallback cache (60t expiry). Destroys proxies via `destroy_all_proxies_at`; severs spatial links, enqueuing drain and recession waves; hub-spill handles payload spill excluding mid-flight beam payloads; clearing obstacles clears terminal tags, allowing kinetic beams to regrow. |
| `defines.events.on_player_rotated_entity`<br>`defines.events.on_player_flipped_entity` | `scripts/proxy-manager.lua`<br>`scripts/flow/flow-engine.lua`<br>`scripts/active-device-scanner.lua`<br>`scripts/diverters/diverter-settings.lua`<br>`scripts/projectors/projector-settings.lua` | Syncs proxy orientation & selection Z-indexing; executes modulo port rotation (`rotate_ports`) and flipping (`flip_ports`) on diverters. Projectors update `muzzle_dir`; old muzzle unlinks and recedes 1 tile/t while new vector advances. Re-indexes spatial nodes, updates cutoff states, and enqueues ports. |
| `defines.events.on_research_finished`<br>`defines.events.on_research_reversed` | `scripts/flow/flow-engine.lua` | `on_research_finished`: Migrates matching `soft_interop_registry` walls/gates into `interop_activation_queue` (drained 10/t). `on_research_reversed`: Triggers boundary severing, port enqueuing, and zero-equilibrium soft demotion. |
| `defines.events.on_player_setup_blueprint` | `scripts/device-settings-copier.lua` | Deep-copies settings into blueprint tags (`pneumatic_settings`), serializes wire connections via 4-element tuples `[entity_from, wire_from, entity_to, wire_to]` and invariant bp indices, serializing projector muzzle direction atomically. |
| `defines.events.on_blueprint_settings_pasted` | `scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua`<br>`scripts/device-settings-copier.lua` | Stamping blueprints or pasting settings updates built/ghost entities in-place using `pneumatic_settings` tags and `previous_direction` delta rotations. |
| `defines.events.on_player_configured_blueprint`<br>`defines.events.on_gui_closed` | `scripts/device-settings-copier.lua` | Scans active blueprint handles & books via `clean_blueprint_orphans` to purge orphan circuit proxy records when main devices are removed in blueprint UI. |
| Custom Input / Pasted Event (`pneumatic-copy-settings`, `pneumatic-paste-settings`, `on_entity_settings_pasted`) | `scripts/device-settings-copier.lua`<br>`scripts/active-device-scanner.lua`<br>`scripts/hubs/hub-manager.lua` | Tracks live entity source in copy buffer (`storage.player_copy_buffer`), applies relative step rotations on paste, works across ghosts/blueprint items/records, and refreshes open destination GUIs. |
| Custom Input (`pneumatic-confirm-gui`) | `scripts/diverters/diverter-gui.lua` | Records `confirm_ticks[player_index]` to differentiate E (Confirm, apply draft) from Esc (Cancel, discard draft) on modal slot config window closing. |
| `defines.events.on_object_destroyed` | `scripts/proxy-manager.lua`<br>`scripts/flow/flow-engine.lua` | Auto-destroys unanchored orphan proxies/ghosts on super force build or fast replacement; maps registration ID, purges destroyed structures or liminal holders, teleports passengers, wakes parked capsules, severs boundary edges, purges projector render objects instantly. |
| `defines.events.on_gui_opened`<br>`defines.events.on_gui_closed`<br>`defines.events.on_gui_checked_state_changed`<br>`defines.events.on_gui_switch_state_changed`<br>`defines.events.on_gui_elem_changed`<br>`defines.events.on_gui_click` | `scripts/pumps/pump-gui.lua` / `scripts/diverters/diverter-gui.lua`<br>`scripts/hubs/hub-gui.lua` / `scripts/counters/counter-gui.lua`<br>`scripts/hubs/hub-spill.lua` / `scripts/utils/gui-components.lua`<br>`scripts/debug-manager.lua` | Diverter, Pump, Counter, Projector & Hub proxies: opens configuration GUI for main entity. Spilled containers: dismisses GUI to permit fast Ctrl+Click looting. Declarative UI component handlers mutate settings and trigger `notify_settings_changed` to wake parked capsules & sync flow. |
| `defines.events.on_lua_shortcut` | `scripts/debug-manager.lua` | Master hotbar shortcut (`pt-debug-panel`): Toggles Pneumatic Control Panel GUI. |
| Custom Input (`capsule-emergency-exit` / Shift+E) | `scripts/capsules/capsule-inputs.lua` -> `scripts/capsules/capsule-runner.lua` | Triggers `capsule_runner.emergency_eject` for passenger disembarkation, holder destruction, and tracking unregistration. |
| `defines.events.on_tick` | `scripts/active-device-scanner.lua`<br><br>`scripts/hubs/hub-manager.lua`<br><br>`scripts/hubs/hub-spill.lua`<br>`scripts/flow/flow-engine.lua`<br><br>`scripts/capsules/capsule-runner.lua` | **15t:** Scanner loop (Pumps/Diverters/Counter signal recalculations & power states; Projector 3 MW baseline & 9 MJ recharge readiness); prunes `fast_replace_cache` (>60t).<br>**1t continuous:** Belt siphon and deposit; **10t interleaved:** hub packing scan; receive lock reset; prunes `hub_fast_replace_cache` (>60t).<br>**60t:** Spilled empty container cleanup.<br>**1t:** Wavefront step (pressure, sensing, and kinetic propagation at 1 tile/t); drains interop queue; monitors cutoff states.<br>**6t staggered:** Granular node hops; ballistic 5-tile prominent hops; player collision damage; receiver catchment; **60t:** liminal refrigeration charge decay. |

---

## 4. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/pneumatic-panel` | Opens or toggles master Pneumatic Control Panel Lua GUI frame (`debug_manager.toggle_panel()`). Alias: `/debug-panel`. | `scripts/debug-manager.lua` |
| `/debug-filter <text>` | Sets debug chat prefix filter string (`storage.debug[player_index].filter`), suppressing non-matching console prints. | `scripts/debug-manager.lua` |
| `/debug-filter-reset` | Clears debug chat prefix filter, allowing all active prints to display. | `scripts/debug-manager.lua` |
| `/toggle-debug` | Toggles master debug mode on/off for player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging for player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles v2 visual flow vectors, pressure numbers, connections, and kinetic trajectories in Alt Mode (`storage.debug[player_index].new_flow`). Alias: `/pt-toggle-flow`. | `scripts/debug-manager.lua` |
| `/toggle-counter-range` | Toggles Capsule Counter sensing range overlays and owner dots in Alt Mode (`storage.debug[player_index].counter_range`). Alias: `/pt-toggle-counter-range`. | `scripts/debug-manager.lua` |
| `/check-counters` | Displays debug status, total registered counters, queue lengths, and owned territory node counts across all active counters. | `scripts/counters/counter-range.lua` |
| `/toggle-capsules` | Toggles visual overlay for active capsule positions and dominant payload item icons (`storage.debug[player_index].capsules`). Mutually exclusive with `/toggle-capsule-peek`. | `scripts/debug-manager.lua` |
| `/toggle-capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering icons strictly for targeted structures. Alias: `/capsule-peek`. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |
| `/clear-renders` | Destroys and reconstructs all active Alt-Mode pressure, counter range, and kinetic beam rendering overlays (`debug_manager.clear_all_renders()`). Alias: `/pt-clear-renders`. | `scripts/debug-manager.lua` |