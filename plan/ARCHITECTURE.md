# ARCHITECTURE.md - Project Blueprint & Structural Overview
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1  
**Author / Maintainer:** Collaborator / Nukedpenguin  
**Description:** Architectural manifest, module map, event lifecycle table, global storage schema, and algorithmic specification for AI context and developer quick-reference.

---

## 1. System Architecture & Core Data Flow

```
+-----------------------------------------------------------------------------------+
|                                 FACTORIO ENGINE                                   |
+-----------------------------------------------------------------------------------+
   | Build / Rotate / Flip / Mine / Object Destroyed / Custom Input Events  | Motion on_tick
   v                                                                        v
+------------------------------------+      +---------------------------------------+
|  ENGINE SELECTION & GATING LAYER   |      |  RUNTIME SIMULATION LAYER             |
|  - settings.lua                    |      |  - hub-manager (Scanner & Lock Reset) |
|    ("pneumatic-flow-version" v1/v2)|      |  - pump-manager (Power & Enable Sync) |
+------------------------------------+      |  - diverter-manager (Power & GUI Sync)|
   |                                 |      |  - hub-packing (Dynamic Bar & Spawning)|
   | (FLOW_VERSION == "v1")          |      |  - hub-unpacking (O(1) Space Guard &  |
   v                                 |      |    Capture Engine)                    |
+----------------------------------+ |      |  - hub-spill (Fast Loot & 0-Tick Bar) |
|  LEGACY NETWORK TOPOLOGY LAYER   | |      +---------------------------------------+
|  - network-connect / disconnect  | |                        |
|  - network-rotate / flip sync    | |                        | Delegates in v2 Mode
|  - network-rebuild-engine        | |                        v
|  - networks-pressure & flow      | |      +---------------------------------------+
|  - capsule-runner (v1 Engine)    | |      |  FLOW v2 ENGINE SUITE (`scripts/flow/`)|
+----------------------------------+ |      |  - flow-engine (Event-Driven Delta    |
   |                                 |      |    Wavefront Engine, 0-Tick Idle Sleep|
   +---------------------------------+      |    Spatial Grid Topology surface@x,y, |
   | (FLOW_VERSION == "v2")                 |    Object Destruction Purge Engine)   |
   v                                        |  - port-defs (Group, Transmit,        |
+----------------------------------+        |    Cross-Transit, Directional Flow)   |
|  FLOW v2 TOPOLOGY & PROPAGATION  |        |  - capsule-runner (Granular 6t Hop    |
|  - O(1) Spatial Grid Topology    |------->|    Runner, Zero-Alloc Scratch Buffers,|
|    (flow_grid, flow_nodes,       |        |    O(1) Spatial Parked Index,         |
|     flow_connections)            |        |    Targeted Neighbor Wakeups)         |
|  - Delta Wavefront Flow Engine   |        +---------------------------------------+
|    (flow_queue, BATCH_SIZE = 50) |                            |
+----------------------------------+                            |
   | Metadata, Wavefront State & Spatial Index                  |
   v                                                            v
+-----------------------------------------------------------------------------------+
|  PERSISTENT STORAGE (`storage`) & ZERO-ALLOCATION DEBUG OVERLAYS                  |
|  - storage.networks / storage.port_connections / storage.port_pressures (v1)     |
|  - storage.flow_nodes / storage.flow_grid / storage.flow_connections (v2)        |
|  - storage.flow_queue / storage.flow_levels / storage.flow_unit_ports (v2)        |
|  - storage.parked_by_port ([port_key][capsule_id] O(1) Spatial Parked Index)      |
|  - storage.object_destruction_map ([reg_id] = { type, unit_number | id })        |
|  - storage.occupancy ([unit_number][net_id][group] O(1) Spatial Buckets)          |
|  - storage.liminal_grid (Dual-tier Wide y>=0 / Tight y<=-100 coordinate domains)  |
|  - storage.spilled_containers (Fast-looting containers with set_bar(1) clamping)  |
|  - storage.bio_integrity_levels (Per-force research tier cache)                   |
|  - storage.active_capsules / storage.active_hubs / storage.hub_receive_locks     |
|  - storage.active_pumps / storage.pump_power_states / storage.pump_enabled_states|
|  - storage.active_diverters / storage.diverter_power_states / diverter_settings   |
|  - storage.debug[player_index] (Master debug, overlays, filter, control panel)    |
|  - debug-manager / flow-engine overlays / port-renderer / capsule-renderer        |
+-----------------------------------------------------------------------------------+
```

---

## 2. All-Encompassing Module Directory

### 2.1 Root & Prototype Stage Files

| File | Sub-Path | Purpose & Role | Key Exports / Prototypes | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `info.json` | `/` | Mod metadata manifest. | Defines mod ID (`nukedpenguin-pneumatic-tube-transport`), version (`0.1.0`), title, Factorio version (`base >= 2.1.0`), expansion dependencies (`space-age >= 2.1.0`), optional (`? quality`). | Factorio Engine |
| `data.lua` | `/` | Prototype stage entry point. Loads item, recipe, entity, technology, custom input, shortcut, diverter, and pump proxy prototypes. | Loads prototype files via strict top-level `require`. | Data Stage |
| `settings.lua` | `/` | Startup mod settings registration. Defines `pneumatic-flow-version` string setting (`v1` vs `v2`, default `"v2"`). | Startup setting `pneumatic-flow-version`. | Data Stage |
| `control.lua` | `/` | Runtime script entry point. Enforces top-level module imports, initializes startup setting `FLOW_VERSION`, initializes global `storage` structure (including v2 schemas `flow_grid`, `flow_nodes`, `flow_connections`, `flow_queue`, `flow_levels`, `flow_unit_ports`, `parked_by_port`, `object_destruction_map`), and registers version-specific event processors. | Hooks `script.on_init`, `script.on_configuration_changed`, requires all logic scripts at top level. | Script Stage |
| `custom-input.lua` | `prototypes/` | Custom input hotkey definitions. | Defines `capsule-emergency-exit` (`SHIFT + E`) custom input. | `data.lua` |
| `entity.lua` | `prototypes/` | Registers mod entities in Factorio data stage. Configures expanded `inventory_size = 255` for `invisible-capsule-holder` and `visible-capsule-holder`. Configured `inventory_type = "with_filters_and_bar"` on `capsule-hub-horizontal` and `capsule-hub-vertical`. Configured `operable = true`, `"no-copy-paste"` flag, and `inventory_type = "with_bar"` on `visible-capsule-holder`. | Defines `capsule-hub-horizontal`, `capsule-hub-vertical`, `invisible-capsule-holder`, `visible-capsule-holder`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`. Tinted visuals. | `data.lua` |
| `item.lua` | `prototypes/` | Prototype item, tool, custom item-group, and subgroup definitions for placeable structures and transport capsules. | Registers `pneumatics` item group, `pneumatic-transport` & `pneumatic-capsules` subgroups. Defines items: `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule` (tool, 100 durability), `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, structures. | `data.lua` |
| `pneumatic-diverter.lua` | `prototypes/` | Physical diverter machine prototype and invisible circuit proxy definition. Configured `collision_mask = {layers = {}}`, `draw_selection_box = false`, `selection_priority = 0`, compact selection footprint `{{-0.3, -0.3}, {0.3, 0.3}}`, and `util.empty_sprite()` sprites on proxy entity. | Defines `pneumatic-diverter` and `pneumatic-diverter-circuit-proxy`. | `data.lua` |
| `pneumatic-diverter-proxy-linkage.lua` | `prototypes/` | Lifecycle script managing hidden circuit proxy creation, removal, orientation sync, space platform events (`on_space_platform_built_entity`, `on_space_platform_mined_entity`), and proxy GUI deferral (`on_gui_opened` launches `diverter_gui`). | Hooks build, destroy, script_raised_destroy, rotate, flip, and GUI events for `pneumatic-diverter`. | `events.lua` |
| `pneumatic-pump-proxy.lua` | `prototypes/` | Cloned circuit proxy prototype definition for pneumatic pumps. Configured `collision_mask = {layers = {}}`, `draw_selection_box = false`, `selection_priority = 0`, compact selection footprint `{{-0.3, -0.3}, {0.3, 0.3}}`, and `util.empty_sprite()` sprites. | Defines `pneumatic-pump-circuit-proxy`. | `data.lua` |
| `pneumatic-pump-proxy-linkage.lua` | `prototypes/` | Lifecycle script managing hidden circuit proxy creation, removal, orientation sync, space platform events, and proxy GUI deferral (`on_gui_opened` launches `pump_gui`). | Hooks build, destroy, script_raised_destroy, rotate, mine, and GUI events for `pneumatic-pump`. | `events.lua`, `pump-gui.lua` |
| `recipe.lua` | `prototypes/` | Crafting recipes for all mod items, structures, junctions, diverters, and specialized capsule variants. | Defines recipes with `enabled = false` for technology unlock gating and explicit `energy_required` craft times. Factorio 2.0 `categories` compatibility. | `data.lua` |
| `shortcut.lua` | `prototypes/` | Shortcut bar prototype registration (`pt-debug-panel`) with localized tooltip headers and `toggleable = true` support. | Defines master hotbar debug shortcut prototype. | `data.lua` |
| `technology.lua` | `prototypes/` | Research tree prototype nodes incorporating Space Age science packs (`agricultural-science-pack`, `cryogenic-science-pack`). | Defines `pneumatic-transport`, `specialized-pneumatic-capsules`, and `bio-capsule-integrity-1` through `4` research tiers. | `data.lua` |

---

### 2.2 System Framework & Surface Management

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. | `events.on_event(event_id, handler)` | System-wide event listeners |
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`) and Pneumatic Control Panel Lua GUI controller (`open_panel`, `close_panel`, `toggle_panel`, `refresh_panel`). Manages console log prefix filtering (`filter` field, `/debug-filter`, `/debug-filter-reset`), v2 flow overlay toggles (`new_flow` field, `/toggle-new-flow`, `/pt-toggle-new-flow`), version-guarded UI controls (omits v1 flow/port controls in v2 mode), shortcut syncing (`sync_shortcuts`), and commands (`/pneumatic-panel`, `/debug-panel`, `/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules`, `/toggle-capsule-peek`). | `debug_print(...)`, `is_debug_active(...)`, `open_panel()`, `close_panel()`, `toggle_panel()`, `sync_shortcuts()` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `liminal-surface.lua` | `scripts/surfaces/` | Dual-Tier Spatial Grid allocation engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Distributes standard non-spoilable cargo into Tight slots (2-tile spacing, $y \le -100$, shrinking footprint by ~75%) and spoilable/unit cargo into Wide cells (8-tile spacing, $y \ge 0$). Wide cells feature a centered 3x3 `lab-dark-1` platform surrounded by a symmetrical 2-tile water moat with `+0.5` tile coordinate centering offsets. Manages separate recycling stacks (`wide_free_slots`, `tight_free_slots`). Synchronous chunk generation (`ensure_chunk_at`). | `liminal_surface.get()`, `allocate_position(is_wide)`, `release_position(index, is_wide)`, `ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua` |
| `item-transfer-handler.lua` | `scripts/utils/` | Centralized item metadata preservation & stack transfer engine. Preserves 100% of Factorio 2.0 item metadata: equipment grids (`stack.grid`), installed modules, shield/energy states, quality, spoilage, durability, health, ammo, and custom tags. | `copy_equipment_grid(src, dest)`<br>`build_stack_spec(stack)`<br>`transfer_stack(src, dest_inv)`<br>`transfer_inventory(src_inv, dest_inv)`<br>`spill_stack(surface, pos, stack)` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-spill.lua`, `capsule-lifecycle.lua` |

---

### 2.3 Port Topology & Compatibility Layer

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-definitions.lua` | `scripts/ports/` | Legacy v1 dynamic entity offset and property registry: cardinal offsets, flow directions (`in`, `out`, `any`, `none`), baseline and dynamic pressure levels (-100, +100), port groups (e.g., crossflow junction group 1 & 2), and connection modes (`join`, `merge`). Reads runtime settings from `storage.diverter_settings` and `storage.pump_settings`. | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `diverter-settings`, `pump-settings`, `port-finder`, `network-validate`, `networks-flow` |
| `port-finder.lua` | `scripts/ports/` | Spatial query engine using `find_entities_filtered` to locate nearby compatible entity ports on the surface based on position and offset. | `port_finder.find_connections(entity)` | `network-validate.lua` |
| `port-evaluator.lua` | `scripts/ports/` | Dynamic topology-state decoupled evaluator testing connection compatibility between candidate port pairs. Evaluates spatial graph topology based on physical directional compatibility (`in`, `out`, `any`), keeping structural graph links intact across operational enable/disable state transitions. | `port_evaluator.are_compatible(ent_a, port_a, ent_b, port_b)` | `port-compatibility-definitions`, `network-validate` |
| `port-compatibility-definitions.lua` | `scripts/ports/` | Configuration matrices detailing allowed flow pairs (`in`+`out`, `any`+`any`) and physical connection outcomes (`merge`+`merge` $\rightarrow$ `merge`, `join`+`merge` $\rightarrow$ `join`). | Matrices `flows` and `connections`. | `port-evaluator.lua` |
| `port-connection-definitions.lua` | `scripts/ports/` | Handler map binding outcome keys (`join`, `merge`, `unjoin`, `unmerge`) to script modules. | Maps `connection_defs.types` and `connection_defs.inverses`. | `network-join`, `network-merge`, `network-unjoin`, `network-unmerge` |
| `port-walk.lua` | `scripts/ports/` | Graph traversal engine (BFS) walking connected port edges matching specific edge types. | `port_walk.traverse(start_port_key, match_conn_type)` | `network-unmerge.lua` |
| `port-renderer.lua` | `scripts/ports/` | Scoped per-player visual debug overlay rendering green circle markers (`players = { player }`) on active entity ports on official C++ RenderLayer `"wires-above"`. | `draw_ports_for_entity()`, `draw_all()`, `clear_all()` | `debug-manager.lua`, Factorio Rendering API |

---

### 2.4 Legacy Network Topology, Pressure & Staged Rebuilder (v1 Mode)

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `networks.lua` | `scripts/networks/` | Main API facade unifying network data storage, graph building, and metadata tracking for v1 mode. | Unified proxy for store and graph operations. | Used mod-wide |
| `networks-store.lua` | `scripts/networks/` | Low-level state storage manager for network IDs in `storage.networks.list`, member arrays, metadata extraction, and recycling IDs. | `create()`, `delete()`, `merge()`, `purge_port()`, `set_metadata()`, `get_metadata()`, `extract_metadata()` | `networks.lua` |
| `networks-graph.lua` | `scripts/networks/` | Spatial graph manager maintaining adjacency dictionaries in `storage.port_connections` and binding internal entity groups. | `record_connection()`, `remove_connection()`, `bind_group_to_network()` | `networks-store`, `port-definitions` |
| `network-connect.lua` | `scripts/networks/` | Hooks entity placement events in v1 mode (`FLOW_VERSION == "v1"`) and passes newly built entities to spatial validation. | Event listeners (`on_built_entity`, `script_raised_built`, etc.). | `network-validate.lua` |
| `network-disconnect.lua` | `scripts/networks/` | Hooks entity mining and destruction events in v1 mode (`FLOW_VERSION == "v1"`). Performs $O(1)$ physical edge severing in `storage.port_connections`, purges port definitions, triggers payload spilling (`hub-spill.lua`), and passes severed networks to `network-rebuild-engine`. | Event listeners (`on_player_mined_entity`, `on_entity_died`, etc.). | `network-rebuild-engine.lua`, `hub-spill.lua` |
| `network-rotate.lua` | `scripts/networks/` | Hooks rotation (`on_player_rotated_entity`) and flip (`on_player_flipped_entity`) events in v1 mode (`FLOW_VERSION == "v1"`). Synchronizes caches immediately and marks affected networks dirty in `network-rebuild-engine`. | Event listeners (`on_player_rotated_entity`, `on_player_flipped_entity`). | `network-rebuild-engine`, `pump-manager`, `diverter-manager` |
| `network-validate.lua` | `scripts/networks/` | Spatial validation workflow: provisions internal networks, queries spatial neighbors via `port-finder`, tests via `port-evaluator`, executes spatial graph linking ($O(1)$ edge recording), and tags dirty network IDs for background processing via `network_rebuild_engine.mark_dirty(net_id)`. | `network_validate.execute(entity)` | `port-finder`, `port-evaluator`, `network-rebuild-engine`, `network-form-internals` |
| `network-invalidate.lua` | `scripts/networks/` | Invalidation workflow: identifies external edges, severs connections in constant time, purges port entries, and delegates split topology checks to `network-rebuild-engine`. | `network_invalidate.execute(entity)` | `network-rebuild-engine`, `networks` |
| `network-form-internals.lua` | `scripts/networks/` | Provisions default standalone internal network IDs for an entity's internal port groups upon build/rotate. | `network_form_internals.execute(entity)` | `networks.lua`, `port-definitions.lua` |
| `network-join.lua` | `scripts/networks/` | Registers a boundary edge between separate networks ("join"), leaving their network IDs independent. | `network_join.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-merge.lua` | `scripts/networks/` | Combines two subgraphs or entity internal groups into a single network ID ("merge"). | `network_merge.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-unjoin.lua` | `scripts/networks/` | Severs boundary edges between independent networks without recalculating network split topologies. | `network_unjoin.execute(port_key, neighbor_key)` | `networks.lua` |
| `network-unmerge.lua` | `scripts/networks/` | Severs merge edge in $O(1)$ time and enqueues graph split evaluation into `network-rebuild-engine`. | `network_unmerge.execute(port_key, neighbor_key)` | `network-rebuild-engine.lua`, `networks.lua` |
| `network-rebuild-engine.lua` | `scripts/networks/` | Staged time-sliced background rebuild engine managing `storage.network_rebuild_queue` in v1 mode (`FLOW_VERSION == "v1"`). Executes graph split checks incrementally under a per-tick node budget (350 nodes/tick), coalescing network graph updates across ticks via `networks_flow.build_batch()`. | `network_rebuild_engine.mark_dirty(net_id)`<br>`network_rebuild_engine.process_queue()` | `networks-flow.lua`, `capsule-queries.lua` |
| `diverter-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-diverter` entities (`storage.active_diverters`). Exposes `notify_settings_changed(entity)`. Branches on `FLOW_VERSION`: in v2 mode forwards state changes to `flow_engine.enqueue_unit_ports` and wakes parked capsules; in v1 mode marks networks dirty in `network-rebuild-engine`. | `register_diverter()`, `unregister_diverter()`, `notify_settings_changed()`, `check_diverter_states()` | `network-rebuild-engine.lua`, `diverter-settings.lua`, `events.lua`, `flow-engine.lua` |
| `pump-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-pump` power and circuit states. Exposes `notify_settings_changed(entity)`. Branches on `FLOW_VERSION`: in v2 mode forwards power/circuit updates to `flow_engine.enqueue_unit_ports` and wakes parked capsules; in v1 mode marks networks dirty in `network-rebuild-engine`. | `register_pump()`, `unregister_pump()`, `notify_settings_changed()`, `check_pump_power_states()` | `network-rebuild-engine.lua`, `pump-settings.lua`, `events.lua`, `flow-engine.lua` |
| `networks-pressure.lua` | `scripts/networks/` | Multi-source BFS pressure propagation engine in v1 mode calculating dynamic 10% pressure decay (`calculate_dropoff()`, floor min 1) across network edges starting from active pressure sources. | `networks_pressure.process(net_id)` | `port-definitions.lua` |
| `networks-flow.lua` | `scripts/networks/` | Assembles vector flow maps in v1 mode, gates unpowered/disabled hops via `is_powered()`, invokes `flow-cull`, updates metadata, notifies registered listeners (`wake_parked_capsules`), updates visual overlays on RenderLayer `"lower-object-above-shadow"`, rebuilds `storage.occupancy` via `capsule_queries.rebuild_occupancy_index()`, and provides `networks_flow.build_batch()` for coalesced multi-network updates. | `networks_flow.build(net_id)`<br>`networks_flow.build_batch(net_ids)`<br>`networks_flow.register_listener(callback)` | `networks-pressure`, `flow-cull`, `networks-flow-renderer`, `capsule-queries` |
| `networks-flow-renderer.lua` | `scripts/networks/` | Native Alt Mode visual overlay renderer in v1 mode displaying cyan vector arrows and pressure text (`P: X`) per player on RenderLayer `"lower-object-above-shadow"`. | `draw(net_id, player_index)`, `clear(net_id, player_index)` | Factorio Rendering API |
| `flow-cull.lua` | `scripts/networks/` | Iterative dead-end path pruner clearing non-viable outbound hops on multi-port entities in v1 mode. | `flow_cull.process(flow_map)` | `networks-flow.lua` |

---

### 2.5 Hub System & Cargo Packing / Unpacking

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), providing circuit condition evaluation (`evaluate_circuit_condition`) checking wire connectors before signal queries. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.evaluate_circuit_condition()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`). Manages UI switches, conditions, wire channels, and receive latches. Fires `hub_manager.notify_settings_changed(entity)` on edits to wake disembarking capsules. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, etc.) | `hub-settings.lua`, `hub-manager.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Lifecycle listener, settings notification (`notify_settings_changed`), and interleaved background tick scanner evaluating hub packing logic. | Interleaved background scanner, `notify_settings_changed()`, build/mine event listeners. | `hub-packing`, `hub-spill`, `hub-gui`, `events` |
| `hub-packing.lua` | `scripts/hubs/` | Main hub packing pipeline: Send check (`can_send`), lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius), cargo planning (`cargo-planner.lua`), full `#inventory` scanning (extracting items present in red-locked slots), dynamic dominant item selection, spoilability inspection (`is_stack_spoilable()`), zero-fuzzy spoilable unit detection (`is_unit_spoilable()`), Dual-Tier Spatial Grid allocation (`liminal_surface.allocate_position(is_wide)`), liminal holder spawning, cargo transfer via `item_transfer_handler`, and injection via facade `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `item-transfer-handler`, `cargo-planner`, `capsule-runner` |
| `hub-unpacking.lua` | `scripts/hubs/` | Main hub unpacking pipeline: Receive check (`can_receive`), $O(1)$ failure state guard (`last_failed_hub`), passenger disembarkation onto safe tiles, all-or-nothing cargo unpacking via `can_insert_all()` using zero-allocation flat scratch arrays, slot loops bounded to `get_bar() - 1`, stack migrations via `item_transfer_handler`, liminal holder cleanup with dual slot recycling (`release_position`), and mechanical receive latch engagement. | `hub_unpacking.capture(capsule_tracker, hub_entity)`<br>`can_insert_all(...)` | `capsule-manager`, `liminal-surface`, `item-transfer-handler`, `hub-settings` |
| `hub-spill.lua` | `scripts/hubs/` | Fast-looting container operability (`operable = true`, `set_bar(1)` red-locking upon creation), instant GUI dismissal (`on_gui_opened` sets `player.opened = nil`), `"no-copy-paste"` settings protection (`on_entity_settings_pasted`), 60Hz throttled container cleanup scan (`process_spilled_containers`), and metadata-safe spills via `item_transfer_handler`. | `hub_spill.spill_capsule(...)`<br>`hub_spill.handle_entity_destruction(entity)` | `capsule-queries`, `capsule-manager`, `item-transfer-handler` |
| `quality-filter.lua` | `scripts/hubs/packing/` | Evaluates item quality against capsule vessel rules (`ceil`, comparators, whitelists, blacklists). | `quality_filter.is_quality_allowed(...)` | `hub-packing.lua` |
| `cargo-planner.lua` | `scripts/hubs/packing/` | Calculates stack extraction and insertion plans, delegating `get_item_slot_cost()` to `capsule_defs.is_bio_item()` backed by a strict $O(1)$ bio item matrix (`capsule_definitions.bio_items`). | `cargo_planner.get_item_slot_cost(...)`<br>`cargo_planner.build_packing_plan(...)` | `capsule-definitions.lua`, `hub-packing.lua` |

---

### 2.6 Capsule System, Diverter & Pump Controls

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `diverter-settings.lua` | `scripts/` | Diverter state persistence table (`storage.diverter_settings`). Tracks cardinal port modes (`input`/`output`), whitelist/blacklist filter modes, 5 filter slots with comparators (`=`, `≥`, `≤`, `>`, `<`, `≠`), `DEFAULT_CAPACITY = 2` (`get_capacity(unit_number)`), memoized filter slot compilation (`_compiled`), and circuit proxy signal querying. | `diverter_settings.get()`, `diverter_settings.get_capacity()`, `diverter_settings.is_port_enabled()`, `diverter_settings.evaluate_circuit_condition()` | `diverter-gui`, `diverter-manager`, `capsule-motion` |
| `diverter-gui.lua` | `scripts/` | Interactive 2x2 grid configuration GUI for Pneumatic Diverters. Renders port cards, direction switches, item filter selectors, operator dropdowns, and circuit control panels. Triggers `diverter_manager.notify_settings_changed(entity)` on edits to update caches, wake parked capsules, and mark networks dirty. | `diverter_gui.open()`, `diverter_gui.close()`, GUI event handlers | `diverter-settings.lua`, `diverter-manager.lua` |
| `pump-settings.lua` | `scripts/` | Pump state persistence table (`storage.pump_settings`). Tracks manual enable state (`enabled`), circuit enable toggles, comparator conditions, and wire channel toggles. | `pump_settings.get()`, `pump_settings.is_pump_enabled()`, `pump_settings.evaluate_circuit_condition()` | `pump-gui.lua`, `pump-manager.lua` |
| `pump-gui.lua` | `scripts/` | Configuration GUI overlay (`pump_configuration_frame`) for Pneumatic Pumps. Fires `pump_manager.notify_settings_changed(entity)` on edits to update caches, wake parked capsules, and mark networks dirty. | `pump_gui.open()`, `pump_gui.close()`, GUI event handlers | `pump-settings.lua`, `pump-manager.lua` |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: base slot capacities, quality scaling, bio item matrix (`bio_items`), distinct RGBA debug overlay colors per capsule variant (`get_debug_color()`), spoilage modifiers, spill risks, self-dissolve rules, and spent item transitions (`spent_capsule_item`). | Registry `capsule_definitions.types`, `capsule_defs.bio_items`, `capsule_defs.get_debug_color()` | `hub-packing`, `capsule-manager`, `capsule-runner`, `capsule-renderer` |
| `capsule-definitions-guide.md` | `scripts/capsules/` | Technical reference document detailing all configuration parameters in `capsule-definitions.lua`. | Specification document. | Reference |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities (`storage.active_capsules`). Registers liminal holders with `script.register_on_object_destroyed` as `{ type = "capsule", id = capsule_id }`. Tracks primary capsule slot, allocated coordinates, `is_wide` spatial classification, cached `dominant_item` string, and `has_spoilable_items` flag. Recycles positions back to `wide_free_slots` or `tight_free_slots` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions`, `liminal-surface`, `storage`, `flow-engine` |
| `capsule-queries.lua` | `scripts/capsules/` | $O(1)$ Spatial Occupancy Index (`storage.occupancy` key `[unit_number][net_id][group]`), memoized port key descriptors (`get_port_info()`), target-based blocking occupancy model (`_occ_block_key`), occupancy tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`, `rebuild_occupancy_index`), and short-circuited network capacity checks (`get_capsule_count_at_entity_network`). | `get_port_info()`, `update_capsule_occupancy()`, `unregister_capsule_occupancy()`, `rebuild_occupancy_index()`, `get_capsule_count_at_entity_network()` | `storage`, `capsule-runner`, `capsule-motion` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Lifecycle processor managing passenger position sync, per-force bio integrity research tier caching (`storage.bio_integrity_levels[force.index]`), 10-tick fragile spill evaluation with exact compounding ($R_{10} = 1 - (1 - r)^{10}$), 60-tick refrigerated spoilage reduction ($0.10$) bounded to active inventory slots, stack rebuilds via `item_transfer_handler`, tool durability drain with protective arithmetic guards, and spent tool conversion (`spent-refrigerated-capsule`). | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager`, `item-transfer-handler`, `hub-spill` |
| `capsule-motion.lua` | `scripts/capsules/` | Legacy v1 traversal parameter caching (`setup_segment()`), recursive downstream lookahead path validation (`is_hop_valid()`), pressure-drop scoring across available downstream paths (`best_downstream`), $O(1)$ memory payload read (`capsule.dominant_item`), $O(1)$ non-diverter filter short-circuiting (`check_diverter_port_filter()`), compiled diverter filter evaluation (`_compiled`), dynamic diverter capacity resolution (`diverter_settings.get_capacity(unit_number)`), dynamic hub exit port resolution (`find_best_hub_outbound_port()`), and short-circuited capacity validation (`has_entity_network_capacity()`). | `setup_segment()`, `calculate_segment_speed()`, `has_entity_network_capacity()`, `is_hop_allowed_by_diverter_filters()`, `find_best_hub_outbound_port()`, `select_next_target()`, `handle_arrival()` | `networks`, `diverter-settings`, `capsule-queries`, `capsule-renderer` |
| `capsule-renderer.lua` | `scripts/capsules/` | System-level viewport preparation (`prepare_frame()`) invoked once per tick across `game.players`, allocation-free scratch tables (`scratch_debug_players`, `scratch_debug_keys`), memoized numeric hover peeking (`get_port_info()`), distinct RGBA debug overlay colors per capsule variant, official C++ RenderLayers (`"entity-info-icon-above"`, `"light-effect"`), and dynamic spoilage expiration tracking (serves cached dominant item icon, flips `has_spoilable_items` to `false` when no spoilable stacks remain, permanently suppressing 60-tick periodic inventory scans). | `prepare_frame()`, `render()`, `get_dominant_item()` | `capsule-manager`, `capsule-queries`, `debug-manager` |
| `capsule-runner.lua` | `scripts/capsules/` | Facade runner routing calls based on `FLOW_VERSION`. In v1 mode executes legacy tick-based motion runner (`on_tick`). In v2 mode delegates `inject_from_hub`, `wake_parked_capsules`, `get_capsule_location`, `emergency_eject`, and `remove_capsule` directly to `scripts/flow/capsule-runner.lua`. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `on_tick` handler | `networks`, `capsule-motion`, `capsule-lifecycle`, `capsule-renderer`, `capsule-queries`, `scripts/flow/capsule-runner` |

---

### 2.7 Flow v2 Engine Suite (`scripts/flow/`)

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-defs.lua` | `scripts/flow/` | Standalone flow port definition registry for v2 mode. Defines cardinal tile offsets, port groups (`group = 1` vs split crossflow groups), transmission permissions (`transmit = false` for hubs to block internal gas flow bridging), cross-transit permissions (`cross_transit = true` for hubs to allow capsule motion), and directional flow values (`flow = -10` for pump intake, `flow = 10` for pump output). Exposes `registered_names` and `get_ports(entity)`. | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `flow-engine.lua`, `capsule-runner.lua` |
| `flow-engine.lua` | `scripts/flow/` | Consolidated Event-Driven Wavefront Propagation Engine & Spatial Grid Topology Manager. Maintains $O(1)$ spatial coordinate lookup (`flow_grid`, `flow_nodes`, `flow_connections`) keyed by `surface@x,y`. Manages delta wavefront queue (`storage.flow_queue`, `BATCH_SIZE = 50`) propagating levels from active emitters (pumps/diverters, +10 down to +1, -10 up to -1) with 0-tick idle queue sleep. Evaluates active machine power (`energy > 0`) and circuit states. Renders cyan/blue (positive) and orange/red (negative) Alt Mode overlays with `only_in_alt_mode = true`. Listens to `defines.events.on_object_destroyed` via `storage.object_destruction_map` for silent sandbox purges. | `flow_engine.register_events()`<br>`flow_engine.init_storage()`<br>`flow_engine.connect_entity(entity)`<br>`flow_engine.disconnect_entity(entity)`<br>`flow_engine.step(tick)`<br>`flow_engine.enqueue_unit_ports(unit)`<br>`flow_engine.handle_object_destroyed(...)`<br>`flow_engine.handle_capsule_destroyed(...)` | `port-defs`, `debug-manager`, `control.lua`, `capsule-runner` |
| `capsule-runner.lua` | `scripts/flow/` | Granular Node Hop Motion Engine for v2 mode. Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop processing (`MAX_NODE_HOPS_PER_STEP = 3`). Evaluates candidate hops via `select_next_target` enforcing strictly positive pressure drops (`drop > 0`) and metadata emitter traversal (`node.emitter`). Uses persistent zero-allocation scratch buffers (`scratch_cand_keys`, etc.) and $O(1)$ spatial parked index (`storage.parked_by_port`) for targeted neighbor wakeups without map sweeps. | `v2_capsule_runner.register_events()`<br>`v2_capsule_runner.inject_from_hub()`<br>`v2_capsule_runner.wake_parked_capsules(target)`<br>`v2_capsule_runner.get_capsule_location(...)`<br>`v2_capsule_runner.emergency_eject(...)` | `flow-engine`, `capsule-manager`, `hub-unpacking`, `liminal-surface` |

---

## 3. Event Hook & Lifecycle Matrix

```
+-----------------------------------+------------------------------------+------------------------------------------+
| Factorio Engine Event             | Custom Dispatcher / Handler Module | Actions Triggered                        |
+-----------------------------------+------------------------------------+------------------------------------------+
| script.on_init                    | control.lua -> setup_storage()     | Initializes storage schema (liminal grid,|
| script.on_configuration_changed   | control.lua -> setup_storage()     | occupancy index, rebuild queue, bio      |
|                                   | flow_engine.lua (v2 mode)          | integrity cache, v2 flow grid/queue,     |
|                                   |                                    | object destruction map); scans surface   |
|                                   |                                    | entities for v2 flow engine registration |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_built_entity    | network-connect.lua (v1 mode)      | v1: Runs network_validate.execute();     |
| defines.events.on_robot_built_... | flow-engine.lua (v2 mode)          | links spatial edges in O(1) time and tags|
| defines.events.script_raised_...  | hub-manager.lua / hub-settings.lua | net IDs dirty in network_rebuild_engine. |
| defines.events.on_space_platform..| pump-manager.lua / diverter-manager| v2: Invokes flow_engine.connect_entity  |
| defines.events.on_entity_cloned   | diverter & pump proxy linkages     | to index spatial nodes and enqueue ports |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_mined... | network-disconnect.lua (v1 mode)   | v1: Spills payload, severs physical graph|
| defines.events.on_robot_mined_... | flow-engine.lua (v2 mode)          | edges, enqueues split checks in rebuild. |
| defines.events.on_entity_died     | hub-manager.lua / hub-settings.lua | v2: Invokes flow_engine.disconnect_entity|
| defines.events.script_raised_...  | pump-manager.lua / diverter-manager| to sever spatial links, enqueue drain    |
|                                   | diverter & pump proxy linkages     | waves, and purge registered ports        |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_rotated  | network-rotate.lua (v1 mode)       | v1: Rotates hidden proxies & marks dirty.|
| defines.events.on_player_flipped  | flow-engine.lua (v2 mode)          | v2: Re-indexes spatial nodes, updates    |
|                                   | pump-manager.lua / diverter-manager| port alignments, severs severed links,   |
|                                   | diverter & pump proxy linkages     | and enqueues local ports for flow sync   |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_object_destroyed| flow-engine.lua                    | Maps registration ID in object_destruc_  |
|                                   |                                    | tion_map. Purges destroyed structures or |
|                                   |                                    | liminal holders silently without spilling|
|                                   |                                    | cargo, teleports passengers, wakes queue |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_research_...    | capsule-lifecycle.lua              | Synchronizes cached bio-capsule integrity|
| defines.events.on_technology_...  |                                    | research tiers across forces             |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_gui_opened      | hub-gui.lua / hub-manager.lua      | Diverter & Pump proxies: Defers GUI.     |
| defines.events.on_gui_closed      | diverter-gui.lua / pump-gui.lua    | Spilled containers: Dismisses GUI to     |
| defines.events.on_gui_checked_... | hub-spill.lua                      | permit fast Ctrl+Click looting.          |
| defines.events.on_gui_switch_...  | debug-manager.lua                  | Settings edits fire notify_settings_...  |
| defines.events.on_gui_elem_...    |                                    | to wake parked capsules & sync flow ports|
| defines.events.on_entity_settings.|                                    |                                          |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_lua_shortcut    | debug-manager.lua                  | Master hotbar shortcut (pt-debug-panel): |
|                                   |                                    | Toggles Pneumatic Control Panel GUI      |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_custom_input    | capsule-inputs.lua ->              | Triggers capsule_runner.emergency_eject  |
| (capsule-emergency-exit / Shift+E)| capsule-runner.lua                 | for passenger disembarkation, holder     |
|                                   |                                    | destruction, and tracking unregistration |
+-----------------------------------+------------------------------------+------------------------------------------+
| Custom Input Commands             | debug-manager.lua                  | Launches Pneumatic Control Panel GUI or  |
| (/pneumatic-panel, /debug-panel,  |                                    | toggles visual/print overlays.           |
| /debug-filter, /toggle-new-flow)  |                                    | Configures log prefix filtering.         |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_tick            | hub-manager.lua                    | Interleaved hub scanner & lock reset     |
|                                   | pump-manager.lua / diverter-manager| 15t background power/circuit scanners    |
|                                   | hub-spill.lua                      | 60t spilled empty container cleanup      |
|                                   | network-rebuild-engine.lua (v1)    | v1: Staged network rebuild processor     |
|                                   | flow-engine.lua (v2)               | v2: Event-driven delta wavefront step    |
|                                   | capsule-runner.lua                 | O(1) motion runner, 6t staggered hops,   |
|                                   |                                    | targeted neighbor wakeups, 60t liminal   |
+-----------------------------------+------------------------------------+------------------------------------------+
```

---

## 4. Persistent Storage Schema (`storage`)

All persistent runtime state is preserved in Factorio's `storage` table:

```lua
storage = {
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
      group = 1,               -- Port group ID for internal flow isolation
      transmit = true,         -- Permission for internal flow level propagation
      cross_transit = true,    -- Permission for capsule motion across entity
      emitter = 10,            -- Active flow emission level (+10 output, -10 intake, 0 neutral)
      pos = { x = 10.5, y = 20.5 },
      surface = "nauvis",
      entity = LuaEntity
    }
  },
  flow_connections = {
    ["101:1"] = {
      ["102:2"] = true -- Set of active external spatial port connections
    }
  },
  flow_queue = {
    ["101:1"] = true -- FIFO/Set queue of port keys requiring wavefront level evaluation
  },
  flow_levels = {
    ["101:1"] = 10 -- Dynamic calculated flow level integer (-10 .. +10)
  },
  flow_unit_ports = {
    [101] = { "101:1", "101:2" } -- Recorded port keys associated with entity unit number
  },

  -- O(1) Spatial Parked Capsule Index (v2 Mode)
  parked_by_port = {
    ["101:1"] = {
      [capsule_id] = true -- Set of capsule IDs parked waiting at port key
    }
  },

  -- Object Destruction Registration Mapping
  object_destruction_map = {
    [registration_id] = { type = "entity", unit_number = 101 },
    [registration_id_2] = { type = "capsule", id = 5 }
  },

  -- Staged Time-Sliced Network Rebuild Job Queue (v1 Mode)
  network_rebuild_queue = {
    dirty_networks = { [1] = true },
    pending_splits = { { net_id = 1, port_key = "101:1", neighbor_key = "102:2" } }
  },

  -- Spilled Capsule Container Tracking (Fast Looting with set_bar(1) clamping)
  spilled_containers = {
    [unit_number] = LuaEntity
  },

  -- Cached Research Tech Tiers Per Force
  bio_integrity_levels = {
    [force_index] = 2
  },

  -- Network Management System (v1 Mode)
  networks = {
    next_id = 1,
    recycled_ids = {},
    list = {
      [net_id] = {
        id = 1,
        members = { { unit_number = 101, port_index = 1, entity = LuaEntity } },
        metadata = { flow_map = { ... } }
      }
    },
    port_to_network = { ["101:1"] = net_id }
  },

  -- Adjacency & Pressure Graphs (v1 Mode)
  port_connections = { ["101:1"] = { ["102:2"] = "merge" } },
  port_pressures = { ["101:1"] = 100 },

  -- Hub Container Registry, Operational Settings & Mechanical Latches
  active_hubs = { [unit_number] = LuaEntity },
  hub_settings = {
    [unit_number] = {
      can_send = true, use_circuit_send = false,
      send_condition = { first_signal = { type = "item", name = "iron-plate" }, comparator = "<", constant = 100 },
      can_receive = true, use_circuit_receive = false,
      receive_condition = { first_signal = nil, comparator = "<", constant = 0 },
      use_receive_lock = true, read_red = true, read_green = true
    }
  },
  hub_receive_locks = { [unit_number] = true },

  -- Pump Management & Power/Enable State Tracking
  active_pumps = { [unit_number] = LuaEntity },
  pump_power_states = { [unit_number] = true },
  pump_enabled_states = { [unit_number] = true },
  pump_settings = {
    [unit_number] = {
      enabled = true, use_circuit_enable = false,
      enable_condition = { first_signal = { type = "virtual", name = "signal-everything" }, comparator = ">", constant = 0 },
      read_red = true, read_green = true
    }
  },

  -- Pneumatic Diverter System Tracking & Port Configuration
  active_diverters = { [unit_number] = LuaEntity },
  diverter_power_states = { [unit_number] = true },
  diverter_port_states = { [unit_number] = { North = true, East = true, South = true, West = true } },
  diverter_settings = {
    [unit_number] = {
      ports = {
        North = {
          enabled = true, mode = "output", filter_enabled = false, filter_mode = "whitelist",
          slots = { { item = "iron-plate", comparator = "=" }, ... },
          _compiled = { active = true, is_blacklist = false, slots = { ... } },
          use_circuit_enable = false, enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        },
        East = { ... }, South = { ... }, West = { ... }
      },
      read_red = true, read_green = true
    }
  },

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity, type = "capsule", primary_slot = 1, position = { x = 0, y = -100 },
      grid_index = 5, is_wide = false, dominant_item = "iron-plate", has_spoilable_items = false,
      definition = { ... }
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1, capsule_id = capsule_id, source_hub = 101, from_port_key = "101:1", to_port_key = "102:2",
      _occ_block_key = "102:2", progress = 0.45, passenger = LuaPlayer, slot_spoil_percents = { [1] = 0.12 },
      last_failed_hub = 102, last_failed_hub_count = 15, last_failed_hub_bar = 10, last_failed_cap_count = 1
    }
  },

  -- Per-Player Debug System State
  debug = {
    [player_index] = {
      master = true, capsules = true, peek = false, ports = false, flow = true, prints = false,
      new_flow = true,      -- Flow v2 rendering overlay toggle
      filter = "string"     -- Console debug print prefix filter string
    }
  },

  -- Visual Rendering Handle Caches Scoped Per Player
  flow_render_ids = { [player_index] = { [net_id] = { LuaRenderObject, ... } } },
  port_render_objects = { [player_index] = { LuaRenderObject, ... } }
}
```

---

## 5. Core Algorithms & Operational Mechanics

### 5.1 Staged Time-Sliced Network Rebuilding & Deferred Validation (`network-validate.lua` / `network-rebuild-engine.lua` / `networks-flow.lua`)
1. **Deferred Validation Rebuilds:** When entities are built, rotated, or configured in v1 mode, `network_validate.execute()` performs instant spatial neighbor queries (`port-finder.lua`), directional compatibility checks (`port-evaluator.lua`), and physical edge recording in `storage.port_connections`. Instead of running synchronous BFS graph rebuilds on every placement, it tags affected Network IDs as dirty in constant time via `network_rebuild_engine.mark_dirty(net_id)`.
2. **Instant $O(1)$ Edge Severing:** Entity mining and unmerge events sever physical graph edges in `storage.port_connections` and purge port entries in $O(1)$ time, enqueuing potential network split jobs into `storage.network_rebuild_queue`.
3. **Staged Time-Sliced Job Processor (`network-rebuild-engine.lua`):** On every tick, the rebuild engine executes graph split BFS checks incrementally under a strict budget of **350 nodes/tick**.
4. **Coalesced Batched Flow Rebuilding (`networks_flow.build_batch`):** Once graph split processing completes, dirty networks are processed in a single consolidated pass. `networks_flow.build_batch()` executes multi-source pressure BFS (`networks_pressure.process`), flow vector calculations (`build_single_network`), and spatial occupancy index rebuilds (`capsule_queries.rebuild_occupancy_index()`) across all modified subgraphs simultaneously.

### 5.2 $O(1)$ Spatial Occupancy Index & Target-Based Blocking Model (`capsule-queries.lua`)
1. **Constant-Time Spatial Lookup Matrix:** `storage.occupancy` maintains multi-level spatial buckets indexed by `[unit_number][net_id][group]`. `get_capsule_count_at_entity_network`, `get_capsule_count_at_entity`, and `find_capsules_at_entity` execute in $O(1)$ constant time without linear scans over active capsules.
2. **Target-Based Blocking Occupancy:** Moving capsules track a target blocking key (`_occ_block_key = to_port_key`). The instant a capsule commits to a destination target segment (`to_port_key`), it blocks capacity at its destination node while immediately freeing its origin node capacity (`from_port_key`) for upstream capsules while in mid-transit.
3. **Memoized Port Key Parsing (`get_port_info`):** Port key descriptors (`unit_number`, `port_index`) are cached upon creation, eliminating `string.sub` slicing and string concatenation allocations inside high-frequency motion and filter evaluation loops.

### 5.3 Mid-Segment Traversal Caching & $O(1)$ Motion Interpolation (`capsule-motion.lua` / `capsule-runner.lua`)
1. **Traversal Parameter Caching (`setup_segment`):** Upon target selection, `setup_segment()` pre-calculates and caches segment start/end world coordinates (`seg_from_x`, `seg_from_y`, `seg_to_x`, `seg_to_y`), vector deltas (`seg_dx`, `seg_dy`), total segment distance (`seg_dist`), target surface, entity handles (`entity_from`, `entity_to`), and travel speed (`seg_speed`) directly on the capsule runner object.
2. **$O(1)$ Motion Interpolation Loop:** During tick updates (`update_capsules`), capsule positions are interpolated directly from cached primitive parameters using a module-level scratch position table (`scratch_pos`), bypassing C++ entity queries and speed math calculations.
3. **Location Query Resolution:** `get_capsule_location()` resolves real-world physical coordinates directly from cached segment parameters in $O(1)$ time during passenger updates, emergency ejects, and spoilage unit handling.

### 5.4 0-Tick Lockstep Queue Advancement & Targeted Wakeup Engine (`capsule-runner.lua`)
1. **0-Tick Lockstep Queue Advancement:** The exact tick a parked capsule transitions to moving (`to_port_key ~= nil`) or completes a segment arrival (`to_port_key = nil`), `update_capsules()` invokes `wake_parked_capsules(prev_from)`, triggering instant queue advancement for upstream queued capsules on the same tick.
2. **Targeted Network-Scoped Wakeup Engine:** `wake_parked_capsules(target)` accepts an optional target parameter (`port_key`, `unit_number`, or `net_id`). Using `storage.occupancy` and network topology metadata, it wakes strictly the parked capsules affected by a freed route or entity state change.
3. **Restored Retry Throttling:** Unaffected parked capsules on separate surfaces or distant network subgraphs remain asleep for their full 10-tick retry interval (`PARKED_RETRY_INTERVAL = 10`), eliminating map-wide pathfinding scans.

### 5.5 Multi-Item Unpacking Failure Guard & Zero-Allocation Space Simulation (`hub-unpacking.lua`)
1. **$O(1)$ Destination Failure State Guard:** Capsules parked at or polling full/blocked hub destinations track failure state parameters (`last_failed_hub`, `last_failed_hub_count`, `last_failed_hub_bar`, `last_failed_cap_count`) inside `hub_unpacking.capture`. If hub item counts have not decreased, container bars have not expanded, and payload counts have not dropped, full container space simulation (`can_insert_all`) is short-circuited in constant time.
2. **Zero-Allocation Space Simulation:** `can_insert_all()` utilizes flat module-level scratch arrays (`scratch_req_names`, `scratch_req_counts`, `scratch_partial`, `scratch_filtered`) to simulate multi-item inventory insertion across active chest slots (`get_bar() - 1`), eliminating garbage collection overhead.
3. **Targeted Failure Cache Invalidation:** When a route opens or network state changes, `wake_parked_capsules()` clears `capsule.last_failed_hub = nil`, triggering immediate unpacking re-evaluation.

### 5.6 Diverter Filter Validation & Path Lookahead (`capsule-motion.lua` / `diverter-settings.lua`)
1. **Recursive Downstream Lookahead Path Validation:** `is_hop_valid()` inspects downstream external hops when evaluating internal machine transfers (e.g., diverter input-to-output ports), ensuring exit ports leading to full or filter-disqualified tube lines are rejected before a capsule enters the internal port.
2. **$O(1)$ Non-Diverter Filter Short-Circuiting:** `check_diverter_port_filter()` uses `get_port_info()` to extract integer unit numbers and port indices, short-circuiting non-diverter entities in 2 table lookups.
3. **Memoized Filter Compilation:** Filter slots and blacklist modes are compiled onto `port_setting._compiled`, bypassing unconfigured slots and enabling early-exit evaluation on whitelist matches.
4. **Targeted Diverter Capacity Expansion:** Multi-port diverters support `DEFAULT_CAPACITY = 2` (`diverter_settings.get_capacity(unit_number)`), allowing up to 2 capsules to queue/transit through diverter internal ports simultaneously while maintaining single-capsule spacing across standard tubes and pumps.

### 5.7 Centralized Metadata Engine & Equipment Grid Transfer (`item-transfer-handler.lua`)
1. **Centralized Metadata Preservation:** Hub packing, unpacking, spilling, and refrigerated decay workflows delegate stack extractions and migrations to `item_transfer_handler`.
2. **Native C++ `transfer_stack()` Integration:** Item stack migrations attempt native `dest_slot.transfer_stack(src_stack)` calls first, preserving 100% of equipment grids (`stack.grid`), installed modules, shield/energy levels, spoilage, health, durability, ammo, and quality.
3. **$O(1)$ Equipment Grid Copying & Restoration:** Fallback stack extractions execute `copy_equipment_grid()` to clone equipment grids (`create_grid()`) and transfer installed equipment (`name`, `position`, `quality`, `energy`, `shield`).
4. **`item-with-tags` API Guard:** `build_stack_spec()` extracts stack attributes while strictly guarding `tags` and `custom_description` access behind `is_item_with_tags` checks to prevent Factorio `__index` crashes on standard items.

### 5.8 Dynamic Spoilage Expiration & Zero-Overhead Render Polling (`capsule-renderer.lua` / `hub-packing.lua`)
1. **Spoilability Detection at Packing:** During hub packing (`hub-packing.lua`), `is_stack_spoilable()` computes a `has_spoilable_items` flag persisted in `storage.active_capsules`.
2. **Dynamic Spoilage Expiration Guard:** In `capsule-renderer.lua`, `get_dominant_item()` inspects active container slots using `is_stack_spoilable()`. If cargo spoils mid-flight, it updates `cap_data.dominant_item` to the spoiled product and flips `has_spoilable_items` to `false` once zero spoilable stacks remain.
3. **0-Tick Scan Suppression:** Once `has_spoilable_items` transitions to `false`, 60-tick periodic inventory re-scans are permanently suppressed, serving cached dominant item icons directly from memory in $O(1)$ time.
4. **Valid Render Layer Hierarchy & Distinct Color Overlay:** Debug rings and payload icons render on official C++ RenderLayers (`"entity-info-icon-above"` for rings/icons, `"wires-above"` for port markers, `"lower-object-above-shadow"` for flow vectors, `"light-effect"` for HUD text). Each capsule variant displays a distinct RGBA debug border ring (`capsule_defs.get_debug_color()`), updating dynamically if a refrigerated capsule expires into a spent capsule mid-flight.

### 5.9 Fast-Looting Spilled Containers & 0-Tick Bar Enforcement (`hub-spill.lua`)
1. **Fast-Looting Operability:** Spilled container entities (`visible-capsule-holder`) use `operable = true` to allow native Ctrl+Click fast-looting transfers.
2. **Instant GUI Dismissal:** An `on_gui_opened` listener sets `player.opened = nil` on the exact tick a spilled container is clicked, hiding the container GUI window and red bar slider.
3. **0-Tick Red-Locking Clamping:** Container creation applies `set_bar(1)`, red-locking all slots against manual item insertion while permitting item extraction. `"no-copy-paste"` flags and `on_entity_settings_pasted` listeners prevent setting overrides.
4. **Throttled Cleanup Scan:** A 60-tick periodic scanner (`process_spilled_containers`) evaluates empty spilled containers (`container_inv.is_empty()`), destroying empty entities in batch.

### 5.10 Flow v2 Event-Driven Delta Wavefront Engine & Spatial Grid Topology (`scripts/flow/flow-engine.lua`)
1. **$O(1)$ Spatial Grid Topology:** Entities register port nodes onto `storage.flow_nodes` and key tile positions into `storage.flow_grid` via formatted coordinate keys (`surface@x,y`). Adjacent matching ports form bidirectional edges in `storage.flow_connections`. Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent structures without global graph scans.
2. **Event-Driven Delta Wavefront Propagation:** Replaces global BFS graph sweeps with a 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue`. Active emitters (`pneumatic-pump` and `pneumatic-diverter`) start at maximum output strength (+10) or intake pull (-10). Flow propagates outward decaying by 1 level per hop down to 0 at 60 tiles/second.
3. **0-Tick Queue Sleep:** When no flow levels change or the network reaches steady-state equilibrium, `storage.flow_queue` empties. On subsequent ticks, `flow_engine.step()` returns on line 1 in 0.00 ms CPU time with zero Lua GC allocations.
4. **Time-Sliced Batching:** Queue processing is capped at `BATCH_SIZE = 50` steps per tick, spreading processing across frames during large entity placement or destruction events.
5. **Drain Wavefront & Severing:** Disconnecting an entity or breaking a tube connection enqueues downstream ports into `storage.flow_queue`, triggering a frame-by-frame drain wave (`compute_port_flow_level`) that clears cut-off flow values to zero before returning the engine to sleep.
6. **Dynamic Power & Circuit State Sensitivity:** Evaluates machine energy (`entity.energy > 0`), circuit enable conditions, and port modes in constant time. Unpowered or circuit-disabled ports drop emission to 0, triggering automatic downstream flow updates and queue wakeups.
7. **Granular Fast-Path Rendering Pipeline:** Bypasses full map redraws with targeted single-port (`update_port_render`) and single-edge (`update_edge_render`) rendering object mutations. Renders color-coded flow vectors (Cyan/Blue for positive pressure, Orange/Red for intake vacuum) directly on official rendering layers with `only_in_alt_mode = true` and line-1 short-circuit debug guards.

### 5.11 Flow v2 Granular Motion Engine, Zero-Allocation Pathfinding & Spatial Parked Index (`scripts/flow/capsule-runner.lua`)
1. **Granular Node Hop Motion:** Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop capability (`MAX_NODE_HOPS_PER_STEP = 3`) for instantaneous internal machine transitions.
2. **Strict Pressure Gradient Target Selection:** `select_next_target` evaluates candidate outbound hops, requiring a strictly positive flow drop (`level_from - level_cand > 0`) or intake vacuum pull. Eliminates capsule "dancing" or oscillation in zero-gradient zones, dead ends, or unpowered networks by parking capsules cleanly (`return nil`).
3. **Metadata Emitter Traversal:** Uses node metadata (`node.emitter`) rather than entity name matching to handle pump push (`emitter < 0` to `emitter > 0` with `drop = math.huge`) and evaluate downstream diverter output lookahead.
4. **Data-Driven Decoupled Hub Cross-Transit:** Evaluates `node.cross_transit` on hub port definitions (`cross_transit = true`), allowing capsules to cross through hub structures along outbound pressure gradients while keeping internal gas flow transmission isolated (`transmit = false`).
5. **Zero-Allocation Persistent Scratch Buffers:** Module-level persistent scratch tables (`scratch_cand_keys`, `scratch_cand_vias`, `scratch_best_keys`, `scratch_ports_to_wake`, etc.) eliminate table allocations (`{}`) during path evaluation, candidate scoring, and neighbor wakeups.
6. **$O(1)$ Spatial Parked Index & Targeted Wakeups:** Parked capsules register in `storage.parked_by_port[port_key][capsule_id]`. When a route opens, flow changes, or an entity updates, `wake_parked_capsules(target)` inspects strictly the target port, sister unit ports (`storage.flow_unit_ports`), and connected edges (`storage.flow_connections`), waking affected capsules in constant time without map-wide sweeps.
7. **Stale Motion State Reset:** Stale origin port memory (`capsule.last_port_key`) is cleared whenever a capsule enters a parked state or receives a target wakeup, allowing newly reversed flow drops (`drop > 0`) to be selected cleanly.

### 5.12 Silent Object Destruction & Sandbox Purge Engine (`defines.events.on_object_destroyed`)
1. **Typed Object Destruction Registry:** Valid pneumatic structures and liminal capsule holder entities register with Factorio's `script.register_on_object_destroyed` during build, spawning, and surface setup scans. Registration handles map into `storage.object_destruction_map` as structured entries: `{ type = "entity", unit_number = N }` or `{ type = "capsule", id = C }`.
2. **Silent Sandbox Purge Fallback:** When entities are wiped in bulk via Sandbox mode ("remove all entities"), chunk deletions, or script destructions (bypassing standard player/robot mining events), `defines.events.on_object_destroyed` dispatches to structured handler routines (`handle_object_destroyed` and `handle_capsule_destroyed`).
3. **Silent Cargo & Surface Cleanup:** Destroyed capsule holders on `liminal_surface` are removed cleanly via `capsule_manager.remove` without spilling item stacks onto the ground. Any riding player passengers (`cap.passenger`) are safely teleported back to a valid ground position.
4. **Network Topology & Flow Queue Unlinking:** Entity destructions trigger spatial disconnection (`disconnect_entity`), clearing port nodes, severing spatial connection edges, purging recorded unit ports, unparking waiting capsules, and enqueuing upstream neighbor ports to wake queued traffic and prevent tube lockups.

---

## 6. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/pneumatic-panel` | Opens or toggles the master Pneumatic Control Panel Lua GUI frame (`debug_manager.toggle_panel()`). Alias: `/debug-panel`. | `scripts/debug-manager.lua` |
| `/debug-filter <text>` | Sets the debug chat message prefix filter string in player storage (`storage.debug[player_index].filter`), suppressing console prints that do not match the specified prefix string. | `scripts/debug-manager.lua` |
| `/debug-filter-reset` | Clears the debug chat message prefix filter string, allowing all active debug prints to display in console. | `scripts/debug-manager.lua` |
| `/toggle-debug` | Toggles master debug mode on/off for the executing player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging output for the executing player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-ports` | Toggles green visual port marker circles on entities for the executing player (`storage.debug[player_index].ports`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles v1 visual flow vectors and pressure text in Alt Mode for the executing player (`storage.debug[player_index].flow`). | `scripts/debug-manager.lua` |
| `/toggle-new-flow` | Toggles v2 visual flow vectors, pressure numbers, and connection link overlays in Alt Mode for the executing player (`storage.debug[player_index].new_flow`). Alias: `/pt-toggle-new-flow`. | `scripts/debug-manager.lua` |
| `/toggle-capsules` | Toggles visual rendering overlay for active capsule positions and dominant payload item icons (`storage.debug[player_index].capsules`). Mutually exclusive with `/toggle-capsule-peek`. | `scripts/debug-manager.lua` |
| `/toggle-capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering item icons strictly for capsules occupying targeted pneumatic structures. Alias: `/capsule-peek`. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |