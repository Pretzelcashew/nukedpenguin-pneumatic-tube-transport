# ARCHITECTURE.md - Project Blueprint & Structural Overview
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1  
**Author / Maintainer:** Collaborator / Nukedpenguin  
**Description:** Architectural manifest, module map, event lifecycle table, global storage schema, and algorithmic specification for AI context and developer quick-reference.

---

## 1. System Architecture & Core Data Flow


+-----------------------------------------------------------------------------------+
|                                 FACTORIO ENGINE                                   |
+-----------------------------------------------------------------------------------+
   | Build / Rotate / Flip / Mine / Custom Input Events  | Interleaved & Motion on_tick
   v                                                    v
+----------------------------------+       +---------------------------------------+
|  NETWORK TOPOLOGY LAYER          |       |  RUNTIME SIMULATION LAYER             |
|  - network-connect / disconnect  |       |  - hub-manager (Scanner & Lock Reset) |
|  - network-rotate / flip sync    |       |  - pump-manager (Power & Enable Sync) |
|  - network-validate (Deferred)   |       |  - diverter-manager (Power & GUI Sync)|
|  - network-rebuild-engine (Staged|       |  - hub-packing (Dynamic Bar & Spawning)|
|    350 node/tick BFS queue)      |       |  - capsule-runner (0-Tick Lockstep &  |
|  - network-merge / join / split  |       |    10t Throttled Parked Queue)        |
|  - port-evaluator (State-Decoupled)|     |  - capsule-inputs (SHIFT+E Exit)      |
|  - hub / diverter / pump GUIs    |       |  - hub-unpacking (O(1) Space Guard &  |
|  - diverter & pump proxy linkage |       |    Capture Engine)                    |
|  - Pneumatic Control Panel GUI   |       |  - hub-spill (Fast Loot & 0-Tick Bar) |
+----------------------------------+       +---------------------------------------+
   | Deferred Spatial & Graph Edges                     | Inject / Motion / Poll / Unpack
   v                                                    v
+-----------------------------------------------------------------------------------+
|  NETWORK PRESSURE & FLOW ENGINE & SPATIAL OCCUPANCY                               |
|  - networks-pressure (Dynamic 10% decay BFS drop)                                 |
|  - networks-flow (Gradient vectors, pump gating, decoupled listeners,             |
|    batched flow updates via build_batch)                                          |
|  - flow-cull (Internal dead-end path pruning)                                     |
|  - capsule-queries (O(1) Spatial Occupancy Index & memoized port parsing)         |
|  - item-transfer-handler (Centralized native transfer_stack & metadata engine)    |
+-----------------------------------------------------------------------------------+
   | Outputs Metadata & Listener Events
   v
+-----------------------------------------------------------------------------------+
|  PERSISTENT STORAGE (`storage`) & ZERO-ALLOCATION DEBUG OVERLAYS                  |
|  - storage.networks / storage.port_connections / storage.port_pressures          |
|  - storage.occupancy ([unit_number][net_id][group] O(1) Spatial Buckets)          |
|  - storage.network_rebuild_queue (Staged time-sliced rebuild job processor queue) |
|  - storage.liminal_grid (Dual-tier Wide y>=0 / Tight y<=-100 coordinate domains)  |
|  - storage.spilled_containers (Fast-looting containers with set_bar(1) clamping)  |
|  - storage.bio_integrity_levels (Per-force research tier cache)                   |
|  - storage.active_capsules / storage.active_hubs / storage.hub_receive_locks     |
|  - storage.active_pumps / storage.pump_power_states / storage.pump_enabled_states|
|  - storage.active_diverters / storage.diverter_power_states / diverter_settings   |
|  - storage.debug[player_index] (Master debug, overlays, peek mode, control panel) |
|  - debug-manager / networks-flow-renderer / port-renderer / capsule-renderer      |
+-----------------------------------------------------------------------------------+


---

## 2. All-Encompassing Module Directory

### 2.1 Root & Prototype Stage Files

| File | Sub-Path | Purpose & Role | Key Exports / Prototypes | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `info.json` | `/` | Mod metadata manifest. | Defines mod ID (`nukedpenguin-pneumatic-tube-transport`), version (`0.1.0`), title, Factorio version (`base >= 2.1.0`), expansion dependencies (`space-age >= 2.1.0`), optional (`? quality`). | Factorio Engine |
| `data.lua` | `/` | Prototype stage entry point. Loads item, recipe, entity, technology, custom input, shortcut, diverter, and pump proxy prototypes. | Loads prototype files via strict top-level `require`. | Data Stage |
| `control.lua` | `/` | Runtime script entry point. Enforces top-level module imports, initializes global `storage` structure (including `storage.liminal_grid`, `storage.occupancy`, `storage.network_rebuild_queue`, and `storage.bio_integrity_levels`), and triggers initial flow rendering via `networks_flow.draw_all()`. | Hooks `script.on_init`, `script.on_configuration_changed`, requires all logic scripts at top level. | Script Stage |
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
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`) and Pneumatic Control Panel Lua GUI controller (`open_panel`, `close_panel`, `toggle_panel`, `refresh_panel`). Coordinates bidirectional hotbar shortcut synchronization (`sync_shortcuts`). Registers commands `/pneumatic-panel`, `/debug-panel`, `/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules`, `/toggle-capsule-peek` (with `/capsule-peek` alias). Enforces mutual exclusion between active capsule overlays and hover peeking. | `debug_print(...)`, `is_debug_active(...)`, `open_panel()`, `close_panel()`, `toggle_panel()`, `sync_shortcuts()` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `liminal-surface.lua` | `scripts/surfaces/` | Dual-Tier Spatial Grid allocation engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Distributes standard non-spoilable cargo into Tight slots (2-tile spacing, $y \le -100$, shrinking footprint by ~75%) and spoilable/unit cargo into Wide cells (8-tile spacing, $y \ge 0$). Wide cells feature a centered 3x3 `lab-dark-1` platform surrounded by a symmetrical 2-tile water moat with `+0.5` tile coordinate centering offsets. Manages separate recycling stacks (`wide_free_slots`, `tight_free_slots`). Synchronous chunk generation (`ensure_chunk_at`). | `liminal_surface.get()`, `allocate_position(is_wide)`, `release_position(index, is_wide)`, `ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua` |
| `item-transfer-handler.lua` | `scripts/utils/` | Centralized item metadata preservation & stack transfer engine. Preserves 100% of Factorio 2.0 item metadata: equipment grids (`stack.grid`), installed modules, shield/energy states, quality, spoilage, durability, health, ammo, and custom tags. | `copy_equipment_grid(src, dest)`<br>`build_stack_spec(stack)`<br>`transfer_stack(src, dest_inv)`<br>`transfer_inventory(src_inv, dest_inv)`<br>`spill_stack(surface, pos, stack)` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-spill.lua`, `capsule-lifecycle.lua` |

---

### 2.3 Port Topology & Compatibility Layer

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-definitions.lua` | `scripts/ports/` | Dynamic entity offset and property registry: cardinal offsets, flow directions (`in`, `out`, `any`, `none`), baseline and dynamic pressure levels (-100, +100), port groups (e.g., crossflow junction group 1 & 2), and connection modes (`join`, `merge`). Reads runtime settings from `storage.diverter_settings` and `storage.pump_settings`. | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `diverter-settings`, `pump-settings`, `port-finder`, `network-validate`, `networks-flow` |
| `port-finder.lua` | `scripts/ports/` | Spatial query engine using `find_entities_filtered` to locate nearby compatible entity ports on the surface based on position and offset. | `port_finder.find_connections(entity)` | `network-validate.lua` |
| `port-evaluator.lua` | `scripts/ports/` | Dynamic topology-state decoupled evaluator testing connection compatibility between candidate port pairs. Evaluates spatial graph topology based on physical directional compatibility (`in`, `out`, `any`), keeping structural graph links intact across operational enable/disable state transitions. | `port_evaluator.are_compatible(ent_a, port_a, ent_b, port_b)` | `port-compatibility-definitions`, `network-validate` |
| `port-compatibility-definitions.lua` | `scripts/ports/` | Configuration matrices detailing allowed flow pairs (`in`+`out`, `any`+`any`) and physical connection outcomes (`merge`+`merge` $\rightarrow$ `merge`, `join`+`merge` $\rightarrow$ `join`). | Matrices `flows` and `connections`. | `port-evaluator.lua` |
| `port-connection-definitions.lua` | `scripts/ports/` | Handler map binding outcome keys (`join`, `merge`, `unjoin`, `unmerge`) to script modules. | Maps `connection_defs.types` and `connection_defs.inverses`. | `network-join`, `network-merge`, `network-unjoin`, `network-unmerge` |
| `port-walk.lua` | `scripts/ports/` | Graph traversal engine (BFS) walking connected port edges matching specific edge types. | `port_walk.traverse(start_port_key, match_conn_type)` | `network-unmerge.lua` |
| `port-renderer.lua` | `scripts/ports/` | Scoped per-player visual debug overlay rendering green circle markers (`players = { player }`) on active entity ports on official C++ RenderLayer `"wires-above"`. | `draw_ports_for_entity()`, `draw_all()`, `clear_all()` | `debug-manager.lua`, Factorio Rendering API |

---

### 2.4 Network Topology, Pressure, Flow Engine & Staged Rebuilder

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `networks.lua` | `scripts/networks/` | Main API facade unifying network data storage, graph building, and metadata tracking. | Unified proxy for store and graph operations. | Used mod-wide |
| `networks-store.lua` | `scripts/networks/` | Low-level state storage manager for network IDs in `storage.networks.list`, member arrays, metadata extraction, and recycling IDs. | `create()`, `delete()`, `merge()`, `purge_port()`, `set_metadata()`, `get_metadata()`, `extract_metadata()` | `networks.lua` |
| `networks-graph.lua` | `scripts/networks/` | Spatial graph manager maintaining adjacency dictionaries in `storage.port_connections` and binding internal entity groups. | `record_connection()`, `remove_connection()`, `bind_group_to_network()` | `networks-store`, `port-definitions` |
| `network-connect.lua` | `scripts/networks/` | Hooks entity placement events and passes newly built entities to spatial validation. | Event listeners (`on_built_entity`, `script_raised_built`, etc.). | `network-validate.lua` |
| `network-disconnect.lua` | `scripts/networks/` | Hooks entity mining and destruction events. Performs $O(1)$ physical edge severing in `storage.port_connections`, purges port definitions, triggers payload spilling (`hub-spill.lua`), and passes severed networks to `network-rebuild-engine`. | Event listeners (`on_player_mined_entity`, `on_entity_died`, etc.). | `network-rebuild-engine.lua`, `hub-spill.lua` |
| `network-rotate.lua` | `scripts/networks/` | Hooks rotation (`on_player_rotated_entity`) and flip (`on_player_flipped_entity`) events across pumps, diverters, and tubes. Synchronizes caches immediately and marks affected networks dirty in `network-rebuild-engine`. | Event listeners (`on_player_rotated_entity`, `on_player_flipped_entity`). | `network-rebuild-engine`, `pump-manager`, `diverter-manager` |
| `network-validate.lua` | `scripts/networks/` | Spatial validation workflow: provisions internal networks, queries spatial neighbors via `port-finder`, tests via `port-evaluator`, executes spatial graph linking ($O(1)$ edge recording), and tags dirty network IDs for background processing via `network_rebuild_engine.mark_dirty(net_id)`. | `network_validate.execute(entity)` | `port-finder`, `port-evaluator`, `network-rebuild-engine`, `network-form-internals` |
| `network-invalidate.lua` | `scripts/networks/` | Invalidation workflow: identifies external edges, severs connections in constant time, purges port entries, and delegates split topology checks to `network-rebuild-engine`. | `network_invalidate.execute(entity)` | `network-rebuild-engine`, `networks` |
| `network-form-internals.lua` | `scripts/networks/` | Provisions default standalone internal network IDs for an entity's internal port groups upon build/rotate. | `network_form_internals.execute(entity)` | `networks.lua`, `port-definitions.lua` |
| `network-join.lua` | `scripts/networks/` | Registers a boundary edge between separate networks ("join"), leaving their network IDs independent. | `network_join.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-merge.lua` | `scripts/networks/` | Combines two subgraphs or entity internal groups into a single network ID ("merge"). | `network_merge.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-unjoin.lua` | `scripts/networks/` | Severs boundary edges between independent networks without recalculating network split topologies. | `network_unjoin.execute(port_key, neighbor_key)` | `networks.lua` |
| `network-unmerge.lua` | `scripts/networks/` | Severs merge edge in $O(1)$ time and enqueues graph split evaluation into `network-rebuild-engine`. | `network_unmerge.execute(port_key, neighbor_key)` | `network-rebuild-engine.lua`, `networks.lua` |
| `network-rebuild-engine.lua` | `scripts/networks/` | Staged time-sliced background rebuild engine managing `storage.network_rebuild_queue`. Executes graph split checks incrementally under a per-tick node budget (350 nodes/tick), coalescing network graph updates across ticks via `networks_flow.build_batch()`. | `network_rebuild_engine.mark_dirty(net_id)`<br>`network_rebuild_engine.process_queue()` | `networks-flow.lua`, `capsule-queries.lua` |
| `diverter-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-diverter` entities (`storage.active_diverters`). Exposes `notify_settings_changed(entity)` to immediately sync state caches, clear compiled filter caches (`_compiled`), wake parked capsules, and mark affected networks dirty in `network-rebuild-engine`. | `register_diverter()`, `unregister_diverter()`, `notify_settings_changed()`, `check_diverter_states()` | `network-rebuild-engine.lua`, `diverter-settings.lua`, `events.lua` |
| `pump-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-pump` power and circuit states. Exposes `notify_settings_changed(entity)` to sync state caches, wake parked capsules, and mark affected networks dirty in `network-rebuild-engine`. | `register_pump()`, `unregister_pump()`, `notify_settings_changed()`, `check_pump_power_states()` | `network-rebuild-engine.lua`, `pump-settings.lua`, `events.lua` |
| `networks-pressure.lua` | `scripts/networks/` | Multi-source BFS pressure propagation engine calculating dynamic 10% pressure decay (`calculate_dropoff()`, floor min 1) across network edges starting from active pressure sources. | `networks_pressure.process(net_id)` | `port-definitions.lua` |
| `networks-flow.lua` | `scripts/networks/` | Assembles vector flow maps, gates unpowered/disabled hops via `is_powered()`, invokes `flow-cull`, updates metadata, notifies registered listeners (`wake_parked_capsules`), updates visual overlays on RenderLayer `"lower-object-above-shadow"`, rebuilds `storage.occupancy` via `capsule_queries.rebuild_occupancy_index()`, and provides `networks_flow.build_batch()` for coalesced multi-network updates. | `networks_flow.build(net_id)`<br>`networks_flow.build_batch(net_ids)`<br>`networks_flow.register_listener(callback)` | `networks-pressure`, `flow-cull`, `networks-flow-renderer`, `capsule-queries` |
| `networks-flow-renderer.lua` | `scripts/networks/` | Native Alt Mode visual overlay renderer displaying cyan vector arrows and pressure text (`P: X`) per player on RenderLayer `"lower-object-above-shadow"`. | `draw(net_id, player_index)`, `clear(net_id, player_index)` | Factorio Rendering API |
| `flow-cull.lua` | `scripts/networks/` | Iterative dead-end path pruner clearing non-viable outbound hops on multi-port entities. | `flow_cull.process(flow_map)` | `networks-flow.lua` |

---

### 2.5 Hub System & Cargo Packing / Unpacking

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), providing circuit condition evaluation (`evaluate_circuit_condition`) checking wire connectors before signal queries. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.evaluate_circuit_condition()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`). Manages UI switches, conditions, wire channels, and receive latches. Fires `hub_manager.notify_settings_changed(entity)` on edits to wake disembarking capsules. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, etc.) | `hub-settings.lua`, `hub-manager.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Lifecycle listener, settings notification (`notify_settings_changed`), and interleaved background tick scanner evaluating hub packing logic. | Interleaved background scanner, `notify_settings_changed()`, build/mine event listeners. | `hub-packing`, `hub-spill`, `hub-gui`, `events` |
| `hub-packing.lua` | `scripts/hubs/` | Main hub packing pipeline: Send check (`can_send`), lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius), cargo planning (`cargo-planner.lua`), full `#inventory` scanning (extracting items present in red-locked slots), dynamic dominant item selection, spoilability inspection (`is_stack_spoilable()`), zero-fuzzy spoilable unit detection (`is_unit_spoilable()`), Dual-Tier Spatial Grid allocation (`liminal_surface.allocate_position(is_wide)`), liminal holder spawning, cargo transfer via `item_transfer_handler`, and injection via `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `item-transfer-handler`, `cargo-planner`, `capsule-runner` |
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
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities (`storage.active_capsules`). Tracks primary capsule slot, allocated coordinates, `is_wide` spatial classification, cached `dominant_item` string, and `has_spoilable_items` flag. Recycles positions back to `wide_free_slots` or `tight_free_slots` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions`, `liminal-surface`, `storage` |
| `capsule-queries.lua` | `scripts/capsules/` | $O(1)$ Spatial Occupancy Index (`storage.occupancy` key `[unit_number][net_id][group]`), memoized port key descriptors (`get_port_info()`), target-based blocking occupancy model (`_occ_block_key`), occupancy tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`, `rebuild_occupancy_index`), and short-circuited network capacity checks (`get_capsule_count_at_entity_network`). | `get_port_info()`, `update_capsule_occupancy()`, `unregister_capsule_occupancy()`, `rebuild_occupancy_index()`, `get_capsule_count_at_entity_network()` | `storage`, `capsule-runner`, `capsule-motion` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Lifecycle processor managing passenger position sync, per-force bio integrity research tier caching (`storage.bio_integrity_levels[force.index]`), 10-tick fragile spill evaluation with exact compounding ($R_{10} = 1 - (1 - r)^{10}$), 60-tick refrigerated spoilage reduction ($0.10$) bounded to active inventory slots, stack rebuilds via `item_transfer_handler`, tool durability drain with protective arithmetic guards, and spent tool conversion (`spent-refrigerated-capsule`). | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager`, `item-transfer-handler`, `hub-spill` |
| `capsule-motion.lua` | `scripts/capsules/` | Traversal parameter caching (`setup_segment()`), recursive downstream lookahead path validation (`is_hop_valid()`), pressure-drop scoring across available downstream paths (`best_downstream`), $O(1)$ memory payload read (`capsule.dominant_item`), $O(1)$ non-diverter filter short-circuiting (`check_diverter_port_filter()`), compiled diverter filter evaluation (`_compiled`), dynamic diverter capacity resolution (`diverter_settings.get_capacity(unit_number)`), dynamic hub exit port resolution (`find_best_hub_outbound_port()`), and short-circuited capacity validation (`has_entity_network_capacity()`). | `setup_segment()`, `calculate_segment_speed()`, `has_entity_network_capacity()`, `is_hop_allowed_by_diverter_filters()`, `find_best_hub_outbound_port()`, `select_next_target()`, `handle_arrival()` | `networks`, `diverter-settings`, `capsule-queries`, `capsule-renderer` |
| `capsule-renderer.lua` | `scripts/capsules/` | System-level viewport preparation (`prepare_frame()`) invoked once per tick across `game.players`, allocation-free scratch tables (`scratch_debug_players`, `scratch_debug_keys`), memoized numeric hover peeking (`get_port_info()`), distinct RGBA debug overlay colors per capsule variant, official C++ RenderLayers (`"entity-info-icon-above"`, `"light-effect"`), and dynamic spoilage expiration tracking (serves cached dominant item icon, flips `has_spoilable_items` to `false` when no spoilable stacks remain, permanently suppressing 60-tick periodic inventory scans). | `prepare_frame()`, `render()`, `get_dominant_item()` | `capsule-manager`, `capsule-queries`, `debug-manager` |
| `capsule-runner.lua` | `scripts/capsules/` | Main tick-based motion runner (`on_tick`). Interpolates mid-segment movement directly from cached primitive parameters (`setup_segment`) in $O(1)$ time, manages 0-tick lockstep queue advancement (`wake_parked_capsules(prev_from)`), targeted network-scoped wakeup engine (`wake_parked_capsules(target)`), 10-tick retry throttling for unaffected parked capsules (`PARKED_RETRY_INTERVAL = 10`), destination failure state cache clearing (`last_failed_hub = nil`), liminal spoiled unit cross-surface re-instantiation (`handle_liminal_entity_spawn`), location resolver (`get_capsule_location`), emergency eject, and sub-module orchestration. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `on_tick` handler | `networks`, `capsule-motion`, `capsule-lifecycle`, `capsule-renderer`, `capsule-queries` |

---

## 3. Event Hook & Lifecycle Matrix


+-----------------------------------+------------------------------------+------------------------------------------+
| Factorio Engine Event             | Custom Dispatcher / Handler Module | Actions Triggered                        |
+-----------------------------------+------------------------------------+------------------------------------------+
| script.on_init                    | control.lua -> setup_storage()     | Initializes storage schema (liminal grid,|
| script.on_configuration_changed   | control.lua -> setup_storage()     | occupancy index, rebuild queue, bio      |
|                                   |                                    | integrity cache) and draws flow vectors  |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_built_entity    | network-connect.lua                | Runs network_validate.execute(); links   |
| defines.events.on_robot_built_... | hub-manager.lua / hub-settings.lua | spatial edges in O(1) time and tags net  |
| defines.events.script_raised_...  | pump-manager.lua / diverter-manager| IDs dirty in network_rebuild_engine for  |
| defines.events.on_space_platform..| diverter & pump proxy linkages     | staged time-sliced background processing |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_mined... | network-disconnect.lua             | Spills payloads (hub-spill.lua), severs  |
| defines.events.on_robot_mined_... | hub-manager.lua / hub-settings.lua | physical graph edges in O(1) time,       |
| defines.events.on_entity_died     | pump-manager.lua / diverter-manager| destroys circuit proxies, and enqueues   |
| defines.events.script_raised_...  | diverter & pump proxy linkages     | split checks into network_rebuild_engine |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_rotated  | network-rotate.lua                 | Synchronizes power/port state caches     |
| defines.events.on_player_flipped  | pump-manager.lua / diverter-manager| immediately, rotates hidden proxies, and |
|                                   | diverter & pump proxy linkages     | marks net IDs dirty in rebuild engine    |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_research_...    | capsule-lifecycle.lua              | Synchronizes cached bio-capsule integrity|
| defines.events.on_technology_...  |                                    | research tiers across forces             |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_gui_opened      | hub-gui.lua / hub-manager.lua      | Diverter & Pump proxies: Defers GUI to   |
| defines.events.on_gui_closed      | diverter-gui.lua / pump-gui.lua    | physical structure.                      |
| defines.events.on_gui_checked_... | hub-spill.lua                      | Spilled containers: Dismisses GUI        |
| defines.events.on_gui_switch_...  | debug-manager.lua                  | (player.opened = nil) to permit fast     |
| defines.events.on_gui_elem_...    |                                    | Ctrl+Click looting without slider window.|
| defines.events.on_entity_settings.|                                    | Settings edits fire notify_settings_...  |
|                                   |                                    | to wake parked capsules & mark dirty nets|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_lua_shortcut    | debug-manager.lua                  | Master hotbar shortcut (pt-debug-panel): |
|                                   |                                    | Toggles Pneumatic Control Panel GUI      |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_custom_input    | capsule-inputs.lua ->              | Triggers capsule_runner.emergency_eject  |
| (capsule-emergency-exit / Shift+E)| capsule-runner.lua                 | for passenger disembarkation, holder     |
|                                   |                                    | destruction, and tracking unregistration |
+-----------------------------------+------------------------------------+------------------------------------------+
| Custom Input Commands             | debug-manager.lua                  | Launches Pneumatic Control Panel GUI     |
| (/pneumatic-panel, /debug-panel,  |                                    | frame or toggles specific visual/print   |
| /toggle-capsule-peek, etc.)       |                                    | overlays, maintaining 1:1 state sync     |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_tick            | hub-manager.lua                    | Interleaved hub scanner & lock reset     |
|                                   | pump-manager.lua / diverter-manager| 15t background power/circuit scanners    |
|                                   | hub-spill.lua                      | 60t spilled empty container cleanup      |
|                                   | network-rebuild-engine.lua         | Staged network rebuild processor (350    |
|                                   |                                    | nodes/tick budget graph split checks)    |
|                                   | capsule-runner.lua                 | O(1) motion interpolation, 0-tick        |
|                                   |                                    | queue advancement, 10t parked retry      |
|                                   |                                    | throttling, 60t liminal unit re-inst...  |
+-----------------------------------+------------------------------------+------------------------------------------+


---

## 4. Persistent Storage Schema (`storage`)

All persistent runtime state is preserved in Factorio's `storage` table:

lua
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

  -- Staged Time-Sliced Network Rebuild Job Queue
  network_rebuild_queue = {
    dirty_networks = { [1] = true }, -- Set of dirty network IDs requiring flow rebuild
    pending_splits = {               -- Queue of graph split evaluation jobs
      { net_id = 1, port_key = "101:1", neighbor_key = "102:2" }
    }
  },

  -- Spilled Capsule Container Tracking (Fast Looting with set_bar(1) clamping)
  spilled_containers = {
    [unit_number] = LuaEntity -- Spilled containers on physical surface monitored for 60Hz auto-cleanup
  },

  -- Cached Research Tech Tiers Per Force
  bio_integrity_levels = {
    [force_index] = 2 -- Cached bio-capsule-integrity research tier (0..4) per force
  },

  -- Network Management System
  networks = {
    next_id = 1,
    recycled_ids = {},
    list = {
      [net_id] = {
        id = 1,
        members = {
          { unit_number = 101, port_index = 1, entity = LuaEntity }
        },
        metadata = {
          flow_map = {
            ["101:1"] = {
              key = "101:1",
              unit_number = 101,
              port_index = 1,
              group = 1, -- Flow map node port group ID cached for O(1) group checks
              entity = LuaEntity,
              offset = { x = 0, y = -1.0 },
              pos = { x = 10.5, y = 20.5, surface = "nauvis" },
              pressure = 100,
              flow_dir = "out",
              outbound_hops = { "102:2" }
            }
          }
        }
      }
    },
    port_to_network = {
      ["101:1"] = net_id -- Port key string ("unit_number:port_index") mapped to Network ID
    }
  },

  -- Adjacency & Pressure Graphs
  port_connections = {
    ["101:1"] = {
      ["102:2"] = "merge" -- Dictionary mapping neighbor port keys to edge types ("merge" | "join")
    }
  },
  port_pressures = {
    ["101:1"] = 100 -- Map of port keys to calculated numerical pressure values
  },

  -- Hub Container Registry, Operational Settings & Mechanical Latches
  active_hubs = {
    [unit_number] = LuaEntity
  },
  hub_settings = {
    [unit_number] = {
      can_send = true,
      use_circuit_send = false,
      send_condition = { first_signal = { type = "item", name = "iron-plate" }, comparator = "<", constant = 100 },
      can_receive = true,
      use_circuit_receive = false,
      receive_condition = { first_signal = nil, comparator = "<", constant = 0 },
      use_receive_lock = true,
      read_red = true,
      read_green = true
    }
  },
  hub_receive_locks = {
    [unit_number] = true -- Mechanical receive latch engaged on unpack; cleared when hub chest is empty
  },

  -- Pump Management & Power/Enable State Tracking
  active_pumps = {
    [unit_number] = LuaEntity
  },
  pump_power_states = {
    [unit_number] = true
  },
  pump_enabled_states = {
    [unit_number] = true
  },
  pump_settings = {
    [unit_number] = {
      enabled = true,
      use_circuit_enable = false,
      enable_condition = { first_signal = { type = "virtual", name = "signal-everything" }, comparator = ">", constant = 0 },
      read_red = true,
      read_green = true
    }
  },

  -- Pneumatic Diverter System Tracking & Port Configuration
  active_diverters = {
    [unit_number] = LuaEntity
  },
  diverter_power_states = {
    [unit_number] = true
  },
  diverter_port_states = {
    [unit_number] = { North = true, East = true, South = true, West = true }
  },
  diverter_settings = {
    [unit_number] = {
      ports = {
        North = {
          enabled = true,
          mode = "output", -- "input" (Pull / -100) vs "output" (Push / +100)
          filter_enabled = false,
          filter_mode = "whitelist",
          slots = {
            { item = "iron-plate", comparator = "=" },
            { item = nil, comparator = "=" },
            { item = nil, comparator = "=" },
            { item = nil, comparator = "=" },
            { item = nil, comparator = "=" }
          },
          _compiled = { -- Lazily compiled filter evaluation cache
            active = true,
            is_blacklist = false,
            slots = { { item = "iron-plate", comparator = "=" } }
          },
          use_circuit_enable = false,
          enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        },
        East = { ... }, South = { ... }, West = { ... }
      },
      read_red = true, read_green = true
    }
  },

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity,
      type = "capsule",
      primary_slot = 1,
      position = { x = 0, y = -100 },
      grid_index = 5,
      is_wide = false,               -- Dual-tier domain classification (true = Wide y>=0, false = Tight y<=-100)
      dominant_item = "iron-plate",  -- Cached dominant payload item string
      has_spoilable_items = false,   -- Spoilability tracking flag for renderer polling suppression
      definition = { ... }
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1,
      capsule_id = capsule_id,
      source_hub = 101,
      from_port_key = "101:1",
      to_port_key = "102:2",
      _occ_block_key = "102:2",      -- Target-based blocking occupancy node key
      -- Cached segment parameters (setup_segment):
      seg_from_x = 10.0, seg_from_y = 20.0, seg_to_x = 10.0, seg_to_y = 30.0,
      seg_dx = 0.0, seg_dy = 10.0, seg_dist = 10.0, seg_speed = 0.5,
      surface = LuaSurface, entity_from = LuaEntity, entity_to = LuaEntity,
      progress = 0.45,
      passenger = LuaPlayer,
      slot_spoil_percents = { [1] = 0.12 },
      -- Failure state guard for unpack retry short-circuiting:
      last_failed_hub = 102, last_failed_hub_count = 15, last_failed_hub_bar = 10, last_failed_cap_count = 1,
      render_cache = {
        surface_index = 1, pos_x = 10.5, pos_y = 20.5, debug_key = 1,
        dominant_item = "iron-plate", ring_color = { r = 1, g = 0.84, b = 0, a = 1 },
        render_objs = { ... }
      }
    }
  },

  -- Per-Player Debug System State
  debug = {
    [player_index] = {
      master = true,     -- Master debug system toggle
      capsules = true,   -- Capsule visual rendering overlay flag
      peek = false,      -- Alt Mode hover capsule peeking flag (mutually exclusive with capsules)
      ports = false,     -- Port marker visual overlay flag
      flow = true,       -- Alt Mode flow vector visual overlay flag
      prints = false     -- Console debug print logging flag
    }
  },

  -- Visual Rendering Handle Caches Scoped Per Player
  flow_render_ids = { [player_index] = { [net_id] = { LuaRenderObject, ... } } },
  port_render_objects = { [player_index] = { LuaRenderObject, ... } }
}


---

## 5. Core Algorithms & Operational Mechanics

### 5.1 Staged Time-Sliced Network Rebuilding & Deferred Validation (`network-validate.lua` / `network-rebuild-engine.lua` / `networks-flow.lua`)
1. **Deferred Validation Rebuilds:** When entities are built, rotated, or configured, `network_validate.execute()` performs instant spatial neighbor queries (`port-finder.lua`), directional compatibility checks (`port-evaluator.lua`), and physical edge recording in `storage.port_connections`. Instead of running synchronous BFS graph rebuilds on every placement, it tags affected Network IDs as dirty in constant time via `network_rebuild_engine.mark_dirty(net_id)`.
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

---

## 6. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/pneumatic-panel` | Opens or toggles the master Pneumatic Control Panel Lua GUI frame (`debug_manager.toggle_panel()`). Alias: `/debug-panel`. | `scripts/debug-manager.lua` |
| `/toggle-debug` | Toggles master debug mode on/off for the executing player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging output for the executing player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-ports` | Toggles green visual port marker circles on entities for the executing player (`storage.debug[player_index].ports`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles cyan flow vector lines and pressure numerical text in native Alt Mode for the executing player (`storage.debug[player_index].flow`). | `scripts/debug-manager.lua` |
| `/toggle-capsules` | Toggles visual rendering overlay for active capsule positions and dominant payload item icons (`storage.debug[player_index].capsules`). Mutually exclusive with `/toggle-capsule-peek`. | `scripts/debug-manager.lua` |
| `/toggle-capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering item icons strictly for capsules occupying targeted pneumatic structures. Alias: `/capsule-peek`. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |