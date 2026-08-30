Here are the complete, updated contents of `ARCHITECTURE.md` and `CHANGELOG.md` with all fresh changes fully synchronized and marked as incorporated.

***

# Full Content: `ARCHITECTURE.md`

```markdown
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
   | Build / Rotate / Flip / Mine / Custom Input Events  | Interleaved & Motion on_tick
   v                                                    v
+----------------------------------+       +---------------------------------------+
|  NETWORK TOPOLOGY LAYER          |       |  RUNTIME SIMULATION LAYER             |
|  - network-connect / disconnect  |       |  - hub-manager (Scanner & Lock Reset) |
|  - network-rotate / flip sync    |       |  - pump-manager (Power & Enable Sync) |
|  - network-validate / invalidate |       |  - diverter-manager (Power & GUI Sync)|
|  - network-merge / join / split  |       |  - hub-packing (Dynamic Bar & Spawning)|
|  - port-evaluator (State-Decoupled)|     |  - capsule-runner (10t Throttled Park)|
|  - hub / diverter / pump GUIs    |       |  - capsule-inputs (SHIFT+E Exit)      |
|  - diverter & pump proxy linkage |       |  - hub-unpacking (O(1) Space & Capture)|
+----------------------------------+       |  - hub-spill (0-Tick Anti-Exploit Bar)|
   | Spatial & Graph Updates               +---------------------------------------+
   v                                                    | Inject / Motion / Poll / Unpack
+---------------------------------------------------+   v
|  NETWORK PRESSURE & FLOW ENGINE                   |
|  - networks-pressure (Dynamic 10% decay BFS drop) |
|  - networks-flow (Gradient vectors, pump gating,  |
|    decoupled listener subscriptions)              |
|  - flow-cull (Internal dead-end path pruning)     |
+---------------------------------------------------+
   | Outputs Metadata & Listener Events
   v
+-----------------------------------------------------------------------------------+
|  PERSISTENT STORAGE (`storage`) & DEBUG OVERLAYS                                  |
|  - storage.networks / storage.port_connections / storage.port_pressures          |
|  - storage.liminal_grid (8-tile cell allocation & slot recycling stack)           |
|  - storage.spilled_containers (0-tick anti-exploit bar red-locking tracker)       |
|  - storage.bio_integrity_levels (Per-force research tier cache)                   |
|  - storage.active_capsules / storage.active_hubs / storage.hub_receive_locks     |
|  - storage.active_pumps / storage.pump_power_states / storage.pump_enabled_states|
|  - storage.active_diverters / storage.diverter_power_states / diverter_settings   |
|  - storage.debug[player_index] (Master, capsules, peek, ports, flow, prints)      |
|  - debug-manager / networks-flow-renderer / port-renderer / capsule-renderer      |
+-----------------------------------------------------------------------------------+
```

---

## 2. All-Encompassing Module Directory

### 2.1 Root & Prototype Stage Files

| File | Sub-Path | Purpose & Role | Key Exports / Prototypes | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `info.json` | `/` | Mod metadata manifest. | Defines mod ID (`nukedpenguin-pneumatic-tube-transport`), version (`0.1.0`), title, Factorio version (`base >= 2.1.0`), expansion dependencies (`space-age >= 2.1.0`), optional (`? quality`). | Factorio Engine |
| `data.lua` | `/` | Prototype stage entry point. Loads item, recipe, entity, technology, custom input, diverter, and pump proxy prototypes. | Loads prototype files via `require`. | Data Stage |
| `control.lua` | `/` | Runtime script entry point. Initializes global `storage` structure (including `storage.liminal_grid` and `storage.bio_integrity_levels`) and loads all systems. Renders initial flow maps via `networks_flow.draw_all()`. | Hooks `script.on_init`, `script.on_configuration_changed`, requires all logic scripts. | Script Stage |
| `custom-input.lua` | `prototypes/` | Custom input hotkey definitions. | Defines `on-player-rotate` (unused) and `capsule-emergency-exit` (`SHIFT + E`) custom inputs. | `data.lua` |
| `entity.lua` | `prototypes/` | Registers mod entities in Factorio data stage. Expanded `inventory_size` to 255 for `invisible-capsule-holder` and `visible-capsule-holder`. Updated `inventory_type` to `"with_bar"` on `visible-capsule-holder`. Configured debug selectability (`operable = true`, `selection_box = {{-0.5, -0.5}, {0.5, 0.5}}`) on `invisible-capsule-holder`. | Defines `capsule-hub-horizontal`, `capsule-hub-vertical`, `invisible-capsule-holder`, `visible-capsule-holder`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`. Color-tinted visuals. | `data.lua` |
| `item.lua` | `prototypes/` | Prototype item, tool, custom item-group, and subgroup definitions for placeable structures and transport capsules. | Registers `pneumatics` item group, `pneumatic-transport` & `pneumatic-capsules` subgroups. Multi-layer icon table tinting matching entity RGBA values. Defines items: `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule` (tool, 100 durability), `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, structures. | `data.lua` |
| `pneumatic-diverter.lua` | `prototypes/` | Physical machine prototype and cloned hidden constant-combinator proxy definition. Emerald tinting applied to non-shadow visual layers. | Defines `pneumatic-diverter` (electric-energy-interface) and `pneumatic-diverter-circuit-proxy` (constant-combinator). | `data.lua` |
| `pneumatic-diverter-proxy-linkage.lua` | `prototypes/` | Lifecycle script managing hidden circuit proxy creation, removal, orientation sync, and GUI suppression for diverters. | Hooks entity build, destroy, rotate, flip, and GUI events for `pneumatic-diverter`. | `events.lua` |
| `pneumatic-pump-proxy.lua` | `prototypes/` | Cloned constant-combinator proxy prototype definition for pneumatic pumps. | Defines `pneumatic-pump-circuit-proxy` (constant-combinator). | `data.lua` |
| `pneumatic-pump-proxy-linkage.lua` | `prototypes/` | Lifecycle script managing hidden circuit proxy creation, removal, orientation sync, and GUI launch for pumps. | Hooks build, rotate, mine, and GUI events for `pneumatic-pump`, launching `pump_gui.open()`. | `events.lua`, `pump-gui.lua` |
| `recipe.lua` | `prototypes/` | Crafting recipes for all mod items, structures, junctions, diverters, and specialized capsule variants. | Defines recipes with `enabled = false` for technology unlock gating and explicit `energy_required` craft times. Factorio 2.0 `categories` compatibility. | `data.lua` |
| `technology.lua` | `prototypes/` | Research tree prototype nodes incorporating Space Age science packs (`agricultural-science-pack`, `cryogenic-science-pack`). | Defines `pneumatic-transport`, `specialized-pneumatic-capsules`, and `bio-capsule-integrity-1` through `4` research tiers. | `data.lua` |

---

### 2.2 System Framework & Surface Management

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. | `events.on_event(event_id, handler)` | System-wide event listeners |
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`), exposing `debug_print`, feature checks (`is_debug_active`), and master/sub-flag debug console commands. Registers `/capsule-peek` to toggle Alt Mode entity hover peeking, enforcing mutual exclusion with `/toggle-capsules`. Default `flow = true` in Alt Mode. | `debug_print(msg, player_index)`<br>`is_debug_active(feature, player_index)`<br>Commands:<br>`/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules`, `/capsule-peek` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `liminal-surface.lua` | `scripts/surfaces/` | Manages dedicated off-grid surface (`liminal_surface`) with an 8-tile grid position allocation and recycling engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Synchronous chunk generation (`ensure_chunk_at`). Decoupled load-time initialization from capsule management modules. | `liminal_surface.get()`, `liminal_surface.allocate_position()`, `liminal_surface.release_position()`, `liminal_surface.ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua`, Factorio Engine |

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
| `port-renderer.lua` | `scripts/ports/` | Scoped per-player visual debug overlay rendering green circle markers (`players = { player }`) on active entity ports. | `draw_ports_for_entity()`, `draw_all()`, `clear_all()` | `debug-manager.lua`, Factorio Rendering API |

---

### 2.4 Network Topology, Pressure & Flow Engine

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `networks.lua` | `scripts/networks/` | Main API facade unifying network data storage, graph building, and metadata tracking. | Unified proxy for store and graph operations. | Used mod-wide |
| `networks-store.lua` | `scripts/networks/` | Low-level state storage manager for network IDs in `storage.networks.list`, member arrays, metadata extraction, and recycling IDs. | `create()`, `delete()`, `merge()`, `purge_port()`, `set_metadata()`, `get_metadata()`, `extract_metadata()` | `networks.lua` |
| `networks-graph.lua` | `scripts/networks/` | Spatial graph manager maintaining adjacency dictionaries in `storage.port_connections` and binding internal entity groups. | `record_connection()`, `remove_connection()`, `bind_group_to_network()` | `networks-store`, `port-definitions` |
| `network-connect.lua` | `scripts/networks/` | Hooks entity placement events and passes newly built entities to spatial validation. | Event listeners (`on_built_entity`, `script_raised_built`, etc.). | `network-validate.lua` |
| `network-disconnect.lua` | `scripts/networks/` | Hooks entity mining and destruction events, triggering payload spilling (`hub-spill.lua`) and passing removed entities to invalidation workflows. | Event listeners (`on_player_mined_entity`, `on_entity_died`, etc.). | `network-invalidate.lua`, `hub-spill.lua` |
| `network-rotate.lua` | `scripts/networks/` | Hooks rotation (`on_player_rotated_entity`) and flip (`on_player_flipped_entity`) events across pumps, diverters, and tubes. Instantly updates power/port state caches and validates new orientation connections. | Event listeners (`on_player_rotated_entity`, `on_player_flipped_entity`). | `network-invalidate`, `network-validate`, `pump-manager`, `diverter-manager` |
| `network-validate.lua` | `scripts/networks/` | Main spatial validation workflow: provisions internal networks, queries spatial neighbors via `port-finder`, tests via `port-evaluator`, invokes connection handlers, rebuilds flow overlays. | `network_validate.execute(entity)` | `port-finder`, `port-evaluator`, `networks-flow`, `network-form-internals` |
| `network-invalidate.lua` | `scripts/networks/` | Main invalidation workflow: identifies external edges, runs unjoin/unmerge handlers, purges port entries, triggers flow map rebuilds on surviving subgraphs. | `network_invalidate.execute(entity)` | `port-connection-definitions`, `networks`, `networks-flow` |
| `network-form-internals.lua` | `scripts/networks/` | Provisions default standalone internal network IDs for an entity's internal port groups upon build/rotate. | `network_form_internals.execute(entity)` | `networks.lua`, `port-definitions.lua` |
| `network-join.lua` | `scripts/networks/` | Registers a boundary edge between separate networks ("join"), leaving their network IDs independent. | `network_join.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-merge.lua` | `scripts/networks/` | Combines two subgraphs or entity internal groups into a single network ID ("merge"). | `network_merge.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-unjoin.lua` | `scripts/networks/` | Severs boundary edges between independent networks without recalculating network split topologies. | `network_unjoin.execute(port_key, neighbor_key)` | `networks.lua` |
| `network-unmerge.lua` | `scripts/networks/` | Uses `port-walk` graph traversal to evaluate if severing a merge edge breaks a network into disconnected subgraphs, provisioning new network IDs as required. | `network_unmerge.execute(port_key, neighbor_key)` | `port-walk.lua`, `networks.lua` |
| `diverter-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-diverter` entities (`storage.active_diverters`). Exposes `notify_settings_changed(entity)` to immediately sync `diverter_power_states` and `diverter_port_states`, wake parked capsules, and trigger deduplicated flow map rebuilds (`rebuild_diverter_networks` using `visited` table). | `register_diverter()`, `unregister_diverter()`, `notify_settings_changed()`, `check_diverter_states()` | `networks-flow.lua`, `diverter-settings.lua`, `events.lua` |
| `pump-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-pump` power and circuit states. Exposes `notify_settings_changed(entity)` to sync `pump_power_states` and `pump_enabled_states`, waking parked capsules and triggering deduplicated flow rebuilds (`rebuild_pump_networks` using `visited` table). | `register_pump()`, `unregister_pump()`, `notify_settings_changed()`, `check_pump_power_states()` | `networks-flow.lua`, `pump-settings.lua`, `events.lua`, `port-definitions.lua` |
| `networks-pressure.lua` | `scripts/networks/` | Multi-source BFS pressure propagation engine calculating dynamic 10% pressure decay (`calculate_dropoff()`, floor min 1) across network edges starting from fixed active pressure sources (e.g. pumps, diverters). | `networks_pressure.process(net_id)` | `port-definitions.lua` |
| `networks-flow.lua` | `scripts/networks/` | Rebuilds directional vector maps, evaluates power and pump enable states via `is_powered()` (`entity.energy > 0 and pump_settings.is_pump_enabled(entity)`), gates unpowered/disabled hops, checks flow rules and pressure deltas, invokes path culling (`flow-cull`), updates network metadata, fires listener callbacks (`register_listener`), updates player-scoped visual overlays (`draw_all`, `clear_all`) with lazy map generation. | `networks_flow.build(net_id)`<br>`networks_flow.register_listener(callback)`<br>`is_powered(entity)`<br>`draw_all(player_index)`, `clear_all(player_index)` | `networks-pressure`, `flow-cull`, `networks-flow-renderer`, `debug-manager` |
| `networks-flow-renderer.lua` | `scripts/networks/` | Native Alt Mode visual overlay renderer (`only_in_alt_mode = true`), displaying player-scoped cyan directional vectors and pressure text (`P: X`) per player (`storage.flow_render_ids[player_index][net_id]`). | `draw(net_id, player_index)`, `clear(net_id, player_index)` | Factorio Rendering API |
| `flow-cull.lua` | `scripts/networks/` | Iterative dead-end path pruner clearing non-viable outbound hops on multi-port entities (e.g., junctions, diverters, unpowered pumps). | `flow_cull.process(flow_map)` | `networks-flow.lua` |

---

### 2.5 Hub System & Cargo Packing / Unpacking

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), providing safe circuit condition evaluation (`evaluate_circuit_condition`) checking wire connectors before signal queries. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.evaluate_circuit_condition()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`, right position). Manages UI switches, conditions, wire channels, and receive latches. Fires `hub_manager.notify_settings_changed(entity)` on edits to wake disembarking capsules and trigger packing checks. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, `on_gui_checked_state_changed`, `on_gui_elem_changed`, `on_gui_selection_state_changed`, `on_gui_text_changed`) | `hub-settings.lua`, `hub-manager.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Event listener for hub lifecycle, operational settings notification (`notify_settings_changed`), and interleaved background tick scanner (`on_tick`) evaluating hub packing logic. | Interleaved background scanner, `notify_settings_changed()`, entity build/mining event listeners. | `hub-packing`, `hub-spill`, `hub-gui`, `events` |
| `hub-packing.lua` | `scripts/hubs/` | Main hub packing pipeline: Operational send check (`can_send`), Priority lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius for `player-transit-capsule`), cargo planning, dynamic holder inventory bar clamping (`dest_inv.set_bar`), primary capsule shell allocation (`primary_holder_slot`) bounded to active slots, biodegradable self-dissolve evaluation (`destroy_self`), synchronous chunk generation (`ensure_chunk_at`), liminal holder spawning via `liminal_surface.allocate_position()`, and injection via `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `quality-filter`, `cargo-planner`, `capsule-runner`, `hub-settings` |
| `hub-unpacking.lua` | `scripts/hubs/` | Main hub arrival & unpacking pipeline: Operational receive permission check (`can_receive`), passenger disembarkation onto nearby non-colliding positions (`find_non_colliding_position`), all-or-nothing cargo + vessel unpacking using O(1) empty container fast-path and multi-item slot space simulation (`can_insert_all()`) with Factorio 2.0+ quality-aware inventory slot filter parsing, slot loops bounded to `get_bar() - 1`, liminal holder cleanup with position recycling (`release_position`), and mechanical receive latch engagement. | `hub_unpacking.capture(capsule_tracker, hub_entity)`<br>`can_insert_all(...)` | `capsule-manager.lua`, `liminal-surface.lua`, `capsule-runner.lua`, `hub-settings.lua` |
| `hub-spill.lua` | `scripts/hubs/` | Handles safety unloading/spilling of capsule contents into chests or floor item stacks with ground deconstruction marking (`spill_and_mark_stack`) when entities are mined/destroyed or bio capsules rupture. Manages `storage.spilled_containers` on physical surfaces with 0-tick anti-exploit inventory bar enforcement (`set_bar(1)` red-locking) via 60Hz scanner and GUI listeners (`on_gui_opened`, `on_gui_closed`), destroying empty spill containers instantly (`entity.destroy()`). | `hub_spill.spill_capsule(...)`<br>`hub_spill.handle_entity_destruction(entity)` | `capsule-queries.lua`, `capsule-manager.lua` |
| `quality-filter.lua` | `scripts/hubs/packing/` | Evaluates item quality against capsule vessel rules (`ceil`, comparators, whitelists, blacklists). | `quality_filter.is_quality_allowed(...)` | `hub-packing.lua` |
| `cargo-planner.lua` | `scripts/hubs/packing/` | Calculates exact stack extraction and insertion plans for single or mixed cargo types, handling biological item slot costs (`bio_item = 0.5`), full-stack rules, and consolidation. | `cargo_planner.get_item_slot_cost(...)`<br>`cargo_planner.build_packing_plan(...)` | `hub-packing.lua` |

---

### 2.6 Capsule System, Diverter & Pump Controls

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `diverter-settings.lua` | `scripts/` | Diverter state persistence module maintaining `storage.diverter_settings`. Tracks cardinal port enabled states, flow direction modes (`input`/`output`), whitelist/blacklist filter modes, 5 item slots with comparator operators (`=`, `≥`, `≤`, `>`, `<`, `≠`), and circuit proxy signal querying. | `diverter_settings.get()`, `diverter_settings.is_port_enabled()`, `diverter_settings.evaluate_circuit_condition()` | `diverter-gui.lua`, `diverter-manager.lua`, `port-definitions.lua` |
| `diverter-gui.lua` | `scripts/` | Interactive 2x2 grid configuration GUI for Pneumatic Diverters. Renders port cards, direction switches, item filter selectors, comparator dropdowns, and circuit control panels. Triggers `diverter_manager.notify_settings_changed(entity)` to update caches, wake parked capsules, and rebuild flow maps. | `diverter_gui.open()`, `diverter_gui.close()`, GUI event handlers | `diverter-settings.lua`, `diverter-manager.lua` |
| `pump-settings.lua` | `scripts/` | Pump state persistence module maintaining `storage.pump_settings`. Tracks manual enable state (`enabled`), circuit enable toggles (`use_circuit_enable`), comparator conditions, circuit signal evaluations (`evaluate_circuit_condition`), and red/green wire channel toggles. | `pump_settings.get()`, `pump_settings.is_pump_enabled()`, `pump_settings.evaluate_circuit_condition()` | `pump-gui.lua`, `pump-manager.lua`, `port-definitions.lua` |
| `pump-gui.lua` | `scripts/` | Configuration GUI overlay (`pump_configuration_frame`) for Pneumatic Pumps. Fires `pump_manager.notify_settings_changed(entity)` on edits to update power/enabled state caches, wake parked capsules, and trigger deduplicated flow updates. | `pump_gui.open()`, `pump_gui.close()`, GUI event handlers | `pump-settings.lua`, `pump-manager.lua` |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: base slot capacities, quality scaling, mixed cargo/quality rules, stack consolidation rules, holder types, spill behaviors, spoilage modifiers (`spoilage_modifier`), spill risks (`spill_risk`), self-dissolve rules (`destroy_self`), and spent item transitions (`spent_capsule_item`). | Registry `capsule_definitions.types` | `hub-packing.lua`, `capsule-manager.lua`, `capsule-runner.lua`, `capsule-lifecycle.lua` |
| `capsule-definitions-guide.md` | `scripts/capsules/` | Technical reference document detailing all configuration parameters in `capsule-definitions.lua`. | Specification document. | Reference |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities stored in `storage.active_capsules`. Tracks primary capsule shell inventory slot (`primary_slot`), allocated `position` coordinates, and `grid_index` on `liminal_surface`. Recycles grid positions via `liminal_surface.release_position()` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions.lua`, `liminal-surface.lua`, `storage` |
| `capsule-queries.lua` | `scripts/capsules/` | Query & cleanup engine for active capsule holder lookup, port group isolation (`get_port_group`) with flow map node group caching (`node.group`), entity-network capacity evaluation (`get_capsule_count_at_entity_network`) with short-circuited O(1) `max_threshold` early exits, and multi-layer render cleanup (`clear_capsule_render`) purging render cache (`render_cache = nil`). | `get_port_group()`, `find_capsules_at_entity()`, `get_capsule_count_at_entity()`, `get_capsule_count_at_entity_network()`, `remove_capsule()`, `clear_capsule_render()` | `storage`, `hub-spill.lua`, `capsule-runner.lua` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Lifecycle processor managing passenger position sync, per-force bio integrity research tier caching (`storage.bio_integrity_levels[force.index]`) with event-driven research sync, staggered 10-tick fragile spill evaluation with exact compounding ($R_{10} = 1 - (1 - r)^{10}$), refrigerated spoilage reduction ($0.10$) bounded to active inventory slots (`supports_bar()` / `get_bar()`), stale spoilage tracking cleanup (`slot_spoil_percents`), and dynamic prototype tool durability drain (`stack.prototype.durability`) with protective arithmetic guards. | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager.lua`, `capsule-definitions.lua`, `hub-spill.lua` |
| `capsule-motion.lua` | `scripts/capsules/` | Pathfinding hop selection, pressure drop evaluation, short-circuited network capacity validation (`has_entity_network_capacity`), segment speed calculation, port filter evaluation (`is_hop_allowed_by_diverter_filters`), dynamic hub exit port resolution (`find_best_hub_outbound_port`), regex-free string/unit number parsing (`get_unit_number()`), parked capsule rerouting (`to_port_key == nil`), and internal hub hop exclusion. | `calculate_segment_speed()`, `has_entity_network_capacity()`, `is_hop_allowed_by_diverter_filters()`, `find_best_hub_outbound_port()`, `select_next_target()`, `handle_arrival()` | `networks.lua`, `hub-definitions.lua`, `hub-unpacking.lua`, `capsule-queries.lua`, `capsule-renderer.lua` |
| `capsule-renderer.lua` | `scripts/capsules/` | Scoped visual rendering engine featuring a 3-state render object caching state machine (`render_cache`) with stationary capsule NO-OPs and in-place vector updates (`render_obj.target`). Supports Alt Mode hover peeking (`/capsule-peek`, `player.selected.unit_number`), passenger eject text HUD, active inventory slot bounding (`supports_bar()`/`get_bar()`), lazy dominant item evaluation (`get_dominant_item`), and periodic 60-tick spoilage sprite refresh for parked capsules. | `render()`, `get_dominant_item()` | `capsule-manager.lua`, `capsule-queries.lua`, `debug-manager.lua` |
| `capsule-runner.lua` | `scripts/capsules/` | Main tick-based motion runner (`on_tick`). Manages `inject_from_hub()`, continuous movement interpolation, parked capsule 10-tick retry throttling (`PARKED_RETRY_INTERVAL = 10`), instant event-driven wakeup engine (`wake_parked_capsules()`) subscribed to flow map updates and entity events, spoiled unit cross-surface re-instantiation (`handle_liminal_entity_spawn`) preserving quality/health, transit location resolver (`get_capsule_location`), emergency eject, and sub-module orchestration. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `on_tick` handler | `networks.lua`, `port-definitions.lua`, `events.lua`, `capsule-motion.lua`, `capsule-lifecycle.lua`, `capsule-renderer.lua`, `capsule-queries.lua`, `liminal-surface.lua` |

---

## 3. Event Hook & Lifecycle Matrix

```
+-----------------------------------+------------------------------------+------------------------------------------+
| Factorio Engine Event             | Custom Dispatcher / Handler Module | Actions Triggered                        |
+-----------------------------------+------------------------------------+------------------------------------------+
| script.on_init                    | control.lua -> setup_storage()     | Initializes storage schema (liminal grid,|
| script.on_configuration_changed   | control.lua -> setup_storage()     | spilled containers, bio integrity cache) |
|                                   |                                    | and draws initial Alt Mode flow vectors  |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_built_entity    | network-connect.lua                | Runs network_validate.execute()          |
| defines.events.on_robot_built_... | hub-manager.lua / hub-settings.lua | Registers active hubs, pumps & diverters;|
| defines.events.script_raised_...  | pump-manager.lua / diverter-manager| provisions hub/pump/diverter settings,   |
| defines.events.script_raised_...  | diverter & pump proxy linkages     | instantiates hidden combinator proxies for|
|                                   | port-renderer.lua                  | diverters & pumps, draws port debug      |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_mined... | network-disconnect.lua             | Spills payloads (hub-spill.lua) & runs   |
| defines.events.on_robot_mined_... | hub-manager.lua / hub-settings.lua | network_invalidate.execute(), destroys   |
| defines.events.on_entity_died     | pump-manager.lua / diverter-manager| hidden combinator proxies, clears graph  |
| defines.events.script_raised_...  | diverter & pump proxy linkages     | connections, subgraphs, active entities, |
|                                   |                                    | settings, locks & power/enable states    |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_rotated  | network-rotate.lua                 | Synchronizes power/port state caches     |
| defines.events.on_player_flipped  | pump-manager.lua / diverter-manager| immediately, runs network_invalidate     |
|                                   | diverter & pump proxy linkages     | followed by network_validate, rotates    |
|                                   |                                    | hidden proxies, triggers flow rebuilds   |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_research_...    | capsule-lifecycle.lua              | Synchronizes cached bio-capsule integrity|
| defines.events.on_research_...    |                                    | research tiers (storage.bio_integrity)   |
| defines.events.on_technology_...  |                                    | across forces on research state changes  |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_gui_opened      | hub-gui.lua / hub-manager.lua      | Hub/Diverter/Pump: Launches UI overlays  |
| defines.events.on_gui_closed      | diverter-gui.lua / pump-gui.lua    | and syncs operational toggles.           |
| defines.events.on_gui_checked_... | hub-spill.lua                      | Hub-Spill: 0-tick anti-exploit enforcement|
| defines.events.on_gui_switch_...  | diverter & pump proxy linkages     | re-applying set_bar(1) red-locking.      |
| defines.events.on_gui_elem_...    |                                    | GUI state edits fire notify_settings_... |
| defines.events.on_gui_selection_..|                                    | to wake parked disembarking capsules and |
| defines.events.on_gui_text_...    |                                    | trigger deduplicated flow rebuilds       |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_custom_input    | capsule-inputs.lua ->              | Triggers capsule_runner.emergency_eject  |
| (capsule-emergency-exit / Shift+E)| capsule-runner.lua                 | for passenger disembarkation, holder     |
|                                   |                                    | destruction, and tracking unregistration |
+-----------------------------------+------------------------------------+------------------------------------------+
| Custom Input Command              | debug-manager.lua ->               | Toggles Alt Mode entity hover peeking    |
| (/capsule-peek)                   | capsule-renderer.lua               | mode, enforcing mutual exclusion with    |
|                                   |                                    | global capsule debug overlay (/toggle-..) |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_tick            | hub-manager.lua                    | Interleaved hub scanner & lock reset     |
|                                   | pump-manager.lua                   | 15-tick scanner for pump power/circuit   |
|                                   | diverter-manager.lua               | 15-tick scanner for diverter state       |
|                                   | hub-spill.lua                      | 60Hz spilled container bar red-locking   |
|                                   | capsule-runner.lua                 | 10t parked capsule retry throttling &    |
|                                   |                                    | continuous motion interpolation; 60t     |
|                                   |                                    | liminal surface spoiled unit scanner;    |
|                                   |                                    | 10t staggered compounded bio spill risk  |
+-----------------------------------+------------------------------------+------------------------------------------+
```

---

## 4. Persistent Storage Schema (`storage`)

All persistent runtime state is preserved in Factorio's `storage` table:

```lua
storage = {
  -- Off-Grid Liminal Surface Cell Allocation Engine
  liminal_grid = {
    next_index = 0,
    free_slots = {} -- Stack of recycled grid slot indices for coordinate reuse
  },

  -- Spilled Capsule Container Tracking & 0-Tick Anti-Exploit Bar Enforcement
  spilled_containers = {
    [unit_number] = LuaEntity -- Spilled containers on physical surface monitored for set_bar(1) and auto-cleanup
  },

  -- Cached Research Tech Tiers Per Force
  bio_integrity_levels = {
    [force_index] = 2 -- Cached bio-capsule-integrity research tier (0..4) per force
  },

  -- Network Management System
  networks = {
    next_id = 1,
    recycled_ids = {}, -- Stack of recycled network IDs available for reuse
    list = {
      [net_id] = {
        id = 1,
        members = {
          { unit_number = 101, port_index = 1, entity = LuaEntity }
        },
        metadata = {
          flow_map = { -- Flow vector topology metadata table
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
    [unit_number] = LuaEntity -- Registered active hub entities
  },
  hub_settings = {
    [unit_number] = {
      can_send = true,           -- Manual toggle permission: allow inventory packing & injection
      use_circuit_send = false,  -- Circuit override for dispatching
      send_condition = {
        first_signal = { type = "item", name = "iron-plate" },
        comparator = "<",
        constant = 100
      },
      can_receive = true,        -- Manual toggle permission: allow capsule capture & unpacking
      use_circuit_receive = false, -- Circuit override for receiving
      receive_condition = {
        first_signal = nil,
        comparator = "<",
        constant = 0
      },
      use_receive_lock = true,   -- Toggle: lock dispatch after receiving until inventory is empty
      read_red = true,           -- Read signals from red wire channel
      read_green = true          -- Read signals from green wire channel
    }
  },
  hub_receive_locks = {
    [unit_number] = true -- Mechanical receive latch engaged on unpack; cleared immediately when hub chest is empty
  },

  -- Pump Management & Power/Enable State Tracking
  active_pumps = {
    [unit_number] = LuaEntity -- Registered active pump entities
  },
  pump_power_states = {
    [unit_number] = true -- Power state tracking (true = powered, false = unpowered)
  },
  pump_enabled_states = {
    [unit_number] = true -- Manual & circuit enable state evaluation result
  },
  pump_settings = {
    [unit_number] = {
      enabled = true,            -- Manual master toggle state
      use_circuit_enable = false,-- Circuit condition enable toggle
      enable_condition = {
        first_signal = { type = "virtual", name = "signal-everything" },
        comparator = ">",
        constant = 0
      },
      read_red = true,
      read_green = true
    }
  },

  -- Pneumatic Diverter System Tracking & Port Configuration
  active_diverters = {
    [unit_number] = LuaEntity -- Registered active diverter entities
  },
  diverter_power_states = {
    [unit_number] = true -- Power state tracking
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
          filter_mode = "whitelist", -- "whitelist" vs "blacklist"
          slots = {
            { item = "iron-plate", comparator = "=" },
            { item = nil, comparator = "=" },
            { item = nil, comparator = "=" },
            { item = nil, comparator = "=" },
            { item = nil, comparator = "=" }
          },
          use_circuit_enable = false,
          enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        },
        East = { ... },
        South = { ... },
        West = { ... }
      },
      read_red = true,
      read_green = true
    }
  },

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity, -- Reference to invisible holder on liminal_surface
      type = "capsule",   -- Variant type ("capsule", "biodegradable-capsule", etc.)
      primary_slot = 1,   -- Primary vessel shell inventory slot index inside holder
      position = { x = 0, y = 0 }, -- Allocated 8-tile grid coordinates on liminal_surface
      grid_index = 5,     -- Allocated grid slot index for position recycling
      definition = { ... } -- Dynamic reference to capsule-definitions.lua
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1,
      capsule_id = capsule_id, -- Link to active_capsules entry
      source_hub = 101, -- Origin hub unit number (cleared when capsule exits origin entity)
      from_port_key = "101:1",
      to_port_key = nil, -- Set to nil when parked/stationary
      next_retry_tick = 120, -- Scheduled tick for parked retry (10-tick interval throttling)
      last_port_key = "100:1",
      progress = 0.45, -- Traversal progress across current segment (0.0 to 1.0)
      passenger = LuaPlayer, -- Active character player handle during passenger transit, or nil
      slot_spoil_percents = { -- Tracked spoil percentages per active slot (bounded by get_bar())
        [1] = 0.12
      },
      render_cache = { -- Persistent render handle cache state machine
        surface_index = 1,
        pos_x = 10.5,
        pos_y = 20.5,
        passenger_index = nil,
        debug_key = "1:true:false:iron-plate",
        dominant_item = { name = "iron-plate", quality = "normal" },
        render_objs = { ... } -- Array of active LuaRenderObject handles
      }
    }
  },

  -- Per-Player Debug System State
  debug = {
    [player_index] = {
      master = true,     -- Master debug system toggle (default: true)
      capsules = true,   -- Capsule visual rendering overlay flag (default: true)
      peek = false,      -- Alt Mode entity hover capsule peeking flag (mutually exclusive with capsules)
      ports = false,     -- Port marker visual overlay flag (default: false)
      flow = true,       -- Alt Mode flow vector visual overlay flag (default: true)
      prints = false     -- Console debug print logging flag (default: false)
    }
  },

  -- Per-Player Visual Rendering Overhead Storage
  flow_render_ids = {
    [player_index] = {
      [net_id] = { LuaRenderObject, ... }
    }
  },
  port_render_objects = {
    [player_index] = { LuaRenderObject, ... }
  }
}
```

---

## 5. Core Algorithms & Operational Mechanics

### 5.1 Spatial Validation & Internal Provisioning (`network-validate.lua` / `port-evaluator.lua`)
1. Provisions default internal networks for entity port groups via `network-form-internals`.
2. Searches for neighboring entities using spatial bounding boxes derived from `port-definitions`.
3. Verifies connection compatibility against rule matrices using `port-evaluator`. Connection compatibility in `are_compatible()` is calculated strictly from physical directional compatibility (`in`, `out`, `any`), ensuring spatial topology (`storage.port_connections`) remains intact regardless of dynamic entity enable/disable states.
4. Executes specific edge handlers based on connection outcomes:
   * **`merge`**: Combines subgraphs into a unified Network ID (`network-merge`).
   * **`join`**: Establishes a cross-network boundary link while maintaining separate Network IDs (`network-join`).
5. Rebuilds flow topology overlays and pressure values for affected networks (`networks-flow`), using a `visited` network ID lookup table to eliminate duplicate flow builds across multi-port pumps and diverters.

### 5.2 Split Detection Graph Walking (`network-unmerge.lua` / `port-walk.lua`)
1. Removes the target connection edge from `storage.port_connections`.
2. Executes a Breadth-First Search (`port-walk`) starting from the severed neighbor port.
3. Compares reachable node counts against total remaining network members:
   * **No Split:** Preserves current Network ID and updates member list.
   * **Split Detected:** Provisions a new Network ID for the disconnected subgraph and updates `port_to_network` references.

### 5.3 Multi-Source Pressure Calculation & Power/Circuit State Monitoring (`networks-pressure.lua` / `pump-manager.lua` / `diverter-manager.lua`)
1. Periodic pump manager (`pump-manager.lua`) and diverter manager (`diverter-manager.lua`) scan active entities every 15 ticks to monitor power and circuit state changes. Immediate updates are fired via `notify_settings_changed(entity)` on GUI interaction or entity rotation/flip events, synchronizing `pump_power_states`, `pump_enabled_states`, `diverter_power_states`, and `diverter_port_states`.
2. Operational state changes trigger `networks_flow.build(net_id)` across connected networks, which notifies registered listeners (`networks_flow.register_listener`) to instantly wake parked capsules (`capsule_runner.wake_parked_capsules()`).
3. Executes multi-source BFS pressure propagation starting from active pressure sources:
   * Dynamic Pressure Decay: Calculates step-wise resistive pressure loss via `calculate_dropoff()`, scaling loss at 10% of local line pressure per edge hop (floor min 1).
   * Evaluates port direction compatibility (`in`, `out`, `any`) and dynamic port enable states.
   * Commits output pressure values into `storage.port_pressures`.

### 5.4 Flow Map Generation, Path Culling & Alt Mode Overlay (`networks-flow.lua` / `flow-cull.lua` / `networks-flow-renderer.lua`)
1. Assembles flow nodes for local network members and cross-boundary neighbor ports. Flow map nodes pre-cache port group metadata (`node.group`) for $O(1)$ group evaluation.
2. Dynamically evaluates pump and diverter settings (`pump_settings.is_pump_enabled`, `diverter_settings.is_port_enabled`) and power availability directly via `is_powered(entity)` (`(entity.energy > 0) and pump_settings.is_pump_enabled(entity)`).
3. Restricts internal machine transfer hops across pump/diverter ports and suppresses external pressure-gradient vector creation into inactive or unpowered inlets.
4. Constructs outbound vector hops between ports if pressure gradients exist ($P_{\text{from}} > P_{\text{to}}$) or if internal mechanical pass-throughs allow it.
5. Invokes `flow-cull.lua` to remove dead-end internal hops on multi-port entities (such as 4-way junctions, crossflow junctions, diverters, or paths leading to disabled/unpowered inlets).
6. Stores completed flow maps in network metadata and updates native Alt Mode visual overlays (`only_in_alt_mode = true`, scoped per player in `storage.flow_render_ids[player_index]`). Lazy flow map generation (`build_single_network`) is invoked if rendering overlays for a player before a full network rebuild.

### 5.5 Hub Cargo Evaluation, Dynamic Exit Selection & Injection (`hub-packing.lua` / `cargo-planner.lua` / `hub-settings.lua` / `liminal-surface.lua`)
1. Interleaved background scanner runs every 10 ticks per hub (`hub-manager.lua`).
2. **Operational Dispatch Guard:** Checks `hub_settings.can_send(entity)`. Evaluates manual toggle or circuit network conditions (`evaluate_circuit_condition`) checking red/green wire channels.
3. **Priority Lock Release:** Evaluates `evaluate_inventory()` at the top level. If `hub_inventory.is_empty()`, immediately clears `storage.hub_receive_locks[unit_number]`.
4. Checks `storage.hub_settings[unit_number].use_receive_lock`. If enabled and `storage.hub_receive_locks[unit_number]` is active, aborts packing to prevent immediate re-packing of freshly arrived items.
5. Queries `capsule_runner.get_capsule_count_at_entity(hub_entity)` to dynamically verify remaining hub capacity.
6. Checks hub inventory for primary vessel capsule items. If packing a `player-transit-capsule`, scans for nearby player character entities within a 2.5 tile radius and attaches the character to the capsule holder.
7. Calculates quality-scaled capacity bonuses (`base_capacity + quality_level * quality_affected_capacity`).
8. Filters container items against quality constraints (`quality-filter.lua`) and builds extraction plans via `cargo-planner.lua` applying biological item slot costs (`bio_item = 0.5`).
9. Synchronously guarantees chunk generation (`liminal_surface.ensure_chunk_at`) and allocates an 8-tile grid position (`liminal_surface.allocate_position()`) on `liminal_surface`. Spawns holder entity (`invisible-capsule-holder`), populates cargo items, and dynamically sets the inventory bar (`dest_inv.set_bar(...)`) to clamp active slots to `math.max(total_capacity, self_slot_cost)`, red-locking unused slots.
10. Primary vessel capsule shell is assigned to a slot (`primary_holder_slot`) bounded by `get_bar() - 1`. If the capsule definition mandates `destroy_self = true` (e.g., `biodegradable-capsule`), the vessel item shell is consumed upon packing.
11. Calls `capsule_runner.inject_from_hub(capsule_id, hub_entity, passenger)`:
    * Uses `capsule_motion.find_best_hub_outbound_port()` to dynamically scan all hub exit ports for active outbound vectors, downstream line capacity (`has_entity_network_capacity`), diverter filter compliance (`is_hop_allowed_by_diverter_filters`), and pressure drops.
    * Injects the capsule onto the exit port exhibiting the strongest outward pressure gradient ($\Delta P = P_{\text{from}} - P_{\text{to}}$).
    * If connected to a network with no active flow, places capsule on an exit port in a dormant state until flow starts.
    * If hub has no network connections, aborts injection, destroys holder, recycles grid position (`release_position`), and reverts items back into chest.

### 5.6 Capsule Traversal, Port Filtering & Motion Engine (`capsule-runner.lua` / `capsule-motion.lua` / `capsule-lifecycle.lua` / `capsule-renderer.lua`)
1. Executes on every game tick (`on_tick`).
2. **Parked Capsule Retry Throttling & Instant Wakeup:** Stationary/parked capsules (`to_port_key == nil`) defer heavy inventory space checks (`can_insert_all`) and outbound pathfinding searches (`select_next_target`) to evaluate at 10-tick retry intervals (`PARKED_RETRY_INTERVAL = 10`). An event-driven wakeup engine (`capsule_runner.wake_parked_capsules()`) clears `next_retry_tick` immediately upon disembarkation, capsule injection, removal, flow map updates, hub/diverter/pump GUI settings changes, or mid-transit rupture events, guaranteeing instant queue advancement when space opens.
3. **Capsule Lifecycle & Spoilage Mitigation (`capsule-lifecycle.lua`):**
   * **Passenger Positioning:** Synchronizes player character position to `curr_pos` via `teleport`.
   * **Cached Research Bio Spill Risk:** Evaluates mid-transit structural failures on fragile containers (`biodegradable-capsule`). Uses per-force cached research levels (`storage.bio_integrity_levels[force.index]`) updated via research event listeners. Spill risk checks evaluate every 10 ticks (`(game.tick + id) % 10 == 0`) with compounded risk ($R_{10} = 1 - (1 - r)^{10}$), reducing RNG rolls by 90% while preserving exact probability. Spills cargo with an `"explosion"` FX on failure and marks spilled items for deconstruction (`spill_and_mark_stack`).
   * **Refrigerated Decay & Dynamic Tool Durability:** Runs every 60 ticks bounded to active inventory slots (`supports_bar()` / `get_bar()`). Applies `spoilage_modifier` ($0.10$) scaling to reduce cargo spoilage inside `refrigerated-capsule` holders using type-guarded stack re-instantiation. Dynamically resolves tool durability against item prototype (`stack.prototype.durability`), with protective arithmetic guarding (`if current_durability then`), resolving C++ clamping reset loops. Replaces spent tools in-place with `spent-refrigerated-capsule`. Purges stale spoilage tracking entries (`slot_spoil_percents`) for slots beyond `max_slot`.
   * **Spoiled Unit Cross-Surface Re-instantiation:** A 60-tick periodic scanner (`handle_liminal_entity_spawn`) intercepts units created on `liminal_surface` from spoiled items. Resolves parent container coordinates (`find_holder_near`, radius `3.5`) and target physical surface handles (`get_capsule_location`), re-instantiating units directly on the target physical surface (preserving Factorio 2.0 quality and decayed health) before destroying the liminal unit entity.
4. **Emergency Passenger Ejection:** On custom input `capsule-emergency-exit` (`SHIFT + E`), `capsule_runner.emergency_eject(player)` grounds the passenger onto a nearby safe tile, spawns explosion FX, destroys the liminal holder, recycles grid position, clears render objects, and unregisters tracking state.
5. **Pressure-Scaled Speed & Fast Pathfinding (`capsule-motion.lua`):**
   * Travel velocity scales non-linearly with square root of local pressure drop ($\Delta P = |P_{\text{from}} - P_{\text{to}}|$), clamped between 4 and 60 tiles/second.
   * Pathfinding utilizes pre-cached flow map node metadata (`unit_number`, `port_index`, `node.group`) and plain substring parsing (`get_unit_number()`) to eliminate tick-by-tick regex allocation.
   * **Short-Circuited Network Capacity Guard:** `has_entity_network_capacity()` pre-resolves target group once and calls `get_capsule_count_at_entity_network()` with an optional `max_threshold` parameter for $O(1)$ early exit when target line capacity (`MAX_CAPSULES_PER_ENTITY_NETWORK`, default `1`) is reached.
   * **Diverter Port Filter Evaluation:** Evaluates candidate hops via `is_hop_allowed_by_diverter_filters()`. Extracts payload item (`get_dominant_item()`) and tests whitelist/blacklist filter slots using comparator operators (`=`, `≥`, `≤`, `>`, `<`, `≠`).
   * **Internal Hop & Anti-Backtracking Rules:** Excludes internal hops of origin hub entity and filters out `last_port_key` unless hitting dead ends.
6. **Persistent Render Object Caching & Alt Mode Peeking Overlay (`capsule-renderer.lua`):**
   * Employs a 3-state render evaluation state machine (`render_cache`) tracking surface, position, passenger, debug key, dynamic player keying (`wants_peek`), and dominant item.
   * Moving capsules update existing C++ render handles in-place (`render_obj.target`), while stationary/parked capsules perform immediate early-return NO-OPs when state is unchanged.
   * Bounds dominant item queries strictly to unlocked slots (`get_bar()`). Parked capsules re-evaluate dominant items every 60 ticks to refresh visual sprites when cargo spoils naturally.
   * Passenger active: Renders `[Shift + E] Emergency Eject` prompt targeting `players = { passenger }`.
   * Debug mode (`is_debug_active("capsules", player)`): Renders a gold border ring (`radius = 0.35`, `width = 2`) framing scaled item sprite of dominant payload item.
   * Hover Peeking (`is_debug_active("peek", player)`): When Alt Mode is active (`player.game_view_settings.show_entity_info`), matches hovered structure (`player.selected.unit_number`) against capsule port keys to dynamically render item overlays exclusively over hovered structures.

### 5.7 Hub Capture, Multi-Item Unpacking & Passenger Disembarkation (`hub-unpacking.lua` / `hub-settings.lua`)
1. When a capsule steps onto or polls a hub port:
   * **Operational Arrival Guard:** Evaluates `hub_settings.can_receive(hub_entity)`. If `false`, rejects capture and leaves capsule safely parked upstream.
   * Verifies hub unit number against capsule's `source_hub` memory (prevents origin hub from re-capturing its own capsule).
2. Invokes `hub_unpacking.can_insert_all(holder_inv, hub_inv)`:
   * **O(1) Fast-Path Space Evaluation:** For filterless hub containers, directly compares total required item stacks against usable chest capacity.
   * For filtered containers, performs multi-item slot space simulation across active holder slots (`get_bar() - 1`). Inspects slot filters via `hub_inv.get_filter(i)`, matching Factorio 2.0+ `filter_name` and `filter_quality` structures.
3. If `can_insert_all()` passes (All-or-Nothing Guarantee):
   * Safely disembarks passenger in `player-transit-capsule` onto nearby non-colliding tile (`surface.find_non_colliding_position`).
   * Transfers 100% of payload items from liminal holder into hub chest inventory.
   * Destroys liminal holder entity, recycles grid position (`liminal_surface.release_position()`), and unregisters capsule tracking state.
   * Sets `storage.hub_receive_locks[hub_unit_number] = true` (mechanical receive latch).
4. If `can_insert_all()` fails:
   * Capsule remains in liminal storage and parks on the hub port (`to_port_key = nil`).
   * Polling loop in `capsule-runner.lua` re-checks `can_insert_all()` at 10-tick retry intervals or instantly upon event-driven wakeup.

### 5.8 Spilled Container Bar Enforcement & Payload Spill Safety (`hub-spill.lua` / `network-disconnect.lua`)
1. When network structures are mined or destroyed, `network-disconnect.lua` intercepts the event before graph invalidation.
2. Invokes `hub_spill.handle_entity_destruction(entity)` to spill 100% of payload items onto physical surface coordinates or into adjacent containers, marking ground items for deconstruction (`spill_and_mark_stack`).
3. For spilled capsule containers created on physical surfaces (`storage.spilled_containers`):
   * Container prototype (`visible-capsule-holder`) uses `inventory_type = "with_bar"`.
   * **0-Tick Anti-Exploit Bar Enforcement:** A 60Hz scanner and instant GUI listeners (`on_gui_opened`, `on_gui_closed`) track `storage.spilled_containers`. Re-applies `set_bar(1)` on the exact tick if a player attempts to open the inventory bar limit, red-locking all slots against item insertion while permitting item extraction.
   * **Automatic Empty Container Cleanup:** Automatically destroys the spilled container entity (`entity.destroy()`) the exact tick all items are extracted (`container_inv.is_empty()`).

### 5.9 Dynamic Diverter & Pump GUI Configuration, Circuit Proxies & Filter Evaluation (`diverter-settings.lua` / `diverter-gui.lua` / `pump-settings.lua` / `pump-gui.lua` / `diverter-manager.lua` / `pump-manager.lua`)
1. **Composite Proxy Linkage:** Physical `pneumatic-diverter` and `pneumatic-pump` entities are automatically paired with hidden proxy constant combinators (`pneumatic-diverter-circuit-proxy` and `pneumatic-pump-circuit-proxy`) to accept circuit wire connections. Lifecycle scripts maintain 1:1 orientation, positioning, and cleanup across rotation and flip events.
2. **Synchronous GUI Hijacking:** Intercepts `on_gui_opened` on physical diverters (closing native UI via `player.opened = nil`) and launches `diverter_gui.open()`. Intercepts `on_gui_opened` on physical pumps to launch `pump_gui.open()`.
3. **Interactive Configuration Overlay GUIs:**
   * **Diverter GUI:** Displays a 2x2 grid of port control cards (North, East, South, West). Features rich-text mode switches (`Pull (Input)` vs `Push (Output)`), filter mode switches (`Whitelist` vs `Blacklist`), 5 item picker buttons (`elem_type = "item"`), operator dropdowns (`=`, `≥`, `≤`, `>`, `<`, `≠`), wire channel checkboxes, and signal conditions.
   * **Pump GUI:** Features master enable switch, circuit condition toggle, wire channel checkboxes, signal picker button, operator dropdown, and constant textfield.
4. **Real-Time Network Flow Rebuild & Wakeup Integration:** GUI interaction callbacks fire `diverter_manager.notify_settings_changed(entity)` and `pump_manager.notify_settings_changed(entity)`. These functions immediately synchronize power and port state caches (`storage.diverter_port_states`, `storage.pump_enabled_states`), wake parked capsules (`capsule_runner.wake_parked_capsules()`), and trigger deduplicated network flow rebuilds (`networks_flow.build`).

---

## 6. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/toggle-debug` | Toggles master debug mode on/off for the executing player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging output for the executing player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-ports` | Toggles green visual port marker circles on entities for the executing player (`storage.debug[player_index].ports`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles cyan flow vector lines and pressure numerical text in native Alt Mode for the executing player (`storage.debug[player_index].flow`). | `scripts/debug-manager.lua` |
| `/toggle-capsules` | Toggles visual rendering overlay for active capsule positions and dominant payload item icons for the executing player (`storage.debug[player_index].capsules`). Mutually exclusive with `/capsule-peek`. | `scripts/debug-manager.lua` |
| `/capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering item icons strictly for capsules occupying targeted pneumatic structures. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |