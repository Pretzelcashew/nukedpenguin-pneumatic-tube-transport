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
   | Build / Rotate / Mine / Custom Input Events        | Interleaved & Motion on_tick
   v                                                    v
+----------------------------------+       +---------------------------------------+
|  NETWORK TOPOLOGY LAYER          |       |  RUNTIME SIMULATION LAYER             |
|  - network-connect / disconnect  |       |  - hub-manager (Scanner & Lock Reset) |
|  - network-validate / invalidate |       |  - pump-manager (15t Power Scanner)   |
|  - network-merge / join / split  |       |  - hub-packing (Priority Lock Release)|
|  - hub-settings / hub-gui        |       |  - capsule-runner (Motion & Dynamic)  |
|  - diverter-proxy-linkage        |       |  - capsule-inputs (SHIFT+E Exit)      |
|                                  |       |  - hub-unpacking (Simulated Unloader) |
+----------------------------------+       +---------------------------------------+
   | Spatial & Graph Updates                            | Inject / Motion / Poll / Unpack
   v                                                    v
+-----------------------------------------------------------------------------------+
|  NETWORK PRESSURE & FLOW ENGINE                                                   |
|  - networks-pressure (Dynamic 10% decay BFS pressure propagation from sources)    |
|  - networks-flow (Calculates pressure gradients, outbound vectors & pump gating)  |
|  - flow-cull (Internal dead-end path pruning for multi-port entities)             |
+-----------------------------------------------------------------------------------+
   | Outputs Metadata
   v
+-----------------------------------------------------------------------------------+
|  PERSISTENT STORAGE (`storage`) & DEBUG OVERLAYS                                  |
|  - storage.networks / storage.port_connections / storage.port_pressures          |
|  - storage.active_capsules / storage.active_hubs / storage.hub_receive_locks     |
|  - storage.active_pumps / storage.pump_power_states / storage.hub_settings       |
|  - storage.debug (Centralized master & feature toggle state)                      |
|  - debug-manager / networks-flow-renderer / port-renderer / capsule-renderer     |
+-----------------------------------------------------------------------------------+
```

---

## 2. All-Encompassing Module Directory

### 2.1 Root & Prototype Stage Files

| File | Sub-Path | Purpose & Role | Key Exports / Prototypes | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `info.json` | `/` | Mod metadata manifest. | Defines mod ID (`nukedpenguin-pneumatic-tube-transport`), version (`0.0.1`), title, Factorio version (`2.1`), dependencies (`base`). | Factorio Engine |
| `data.lua` | `/` | Prototype stage entry point. Loads item, recipe, entity, technology, custom input, and diverter prototypes. | Loads prototype files via `require`. | Data Stage |
| `control.lua` | `/` | Runtime script entry point. Initializes global `storage` structure and loads all systems. | Hooks `script.on_init`, `script.on_configuration_changed`, requires all logic scripts. | Script Stage |
| `custom-input.lua` | `prototypes/` | Custom input hotkey definitions. | Defines `on-player-rotate` (unused) and `capsule-emergency-exit` (`SHIFT + E`) custom inputs. | `data.lua` |
| `entity.lua` | `prototypes/` | Registers mod entities in Factorio data stage. | Defines `capsule-hub-horizontal`, `capsule-hub-vertical`, `invisible-capsule-holder`, `visible-capsule-holder`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`. | `data.lua` |
| `item.lua` | `prototypes/` | Prototype item and tool definitions for placeable structures and transport capsules. | Defines items/tools: `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule` (tool, 100 durability), `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, `capsule-hub-horizontal/vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, `pneumatic-diverter`. | `data.lua` |
| `pneumatic-diverter.lua` | `prototypes/` | Physical machine prototype and cloned hidden constant-combinator proxy definition. | Defines `pneumatic-diverter` (electric-energy-interface) and `pneumatic-diverter-circuit-proxy` (constant-combinator). | `data.lua` |
| `pneumatic-diverter-proxy-linkage.lua` | `prototypes/` | Lifecycle script managing hidden circuit proxy creation, removal, orientation sync, and GUI suppression for diverters. | Hooks entity build, destroy, rotate, and GUI events for `pneumatic-diverter`. | `events.lua` |
| `recipe.lua` | `prototypes/` | Crafting recipes for all mod items, structures, junctions, diverters, and specialized capsule variants. | Defines recipes with `enabled = false` for technology unlock gating and explicit `energy_required` craft times. | `data.lua` |
| `technology.lua` | `prototypes/` | Research tree prototype nodes. | Defines `pneumatic-transport`, `specialized-pneumatic-capsules`, and `bio-capsule-integrity-1` through `4` research tiers. | `data.lua` |

---

### 2.2 System Framework & Surface Management

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. | `events.on_event(event_id, handler)` | System-wide event listeners |
| `debug-manager.lua` | `scripts/` | Centralized debug state manager (`storage.debug`), exposing global `debug_print`, feature checks (`is_debug_active`), and master/sub-flag debug console commands. | `debug_print(msg)`<br>`is_debug_active(feature)`<br>Commands:<br>`/toggle-debug`, `/toggle-prints`, `/toggle-ports`, `/toggle-flow`, `/toggle-capsules` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `liminal-surface.lua` | `scripts/surfaces/` | Manages a dedicated 1x1 off-grid surface (`liminal_surface`) holding invisible capsule containers out of the playable map. | `liminal_surface.get()` | `hub-packing.lua`, `hub-unpacking.lua`, Factorio Engine |

---

### 2.3 Port Topology & Compatibility Layer

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-definitions.lua` | `scripts/ports/` | Static entity offset and property registry: directional spatial offsets, flow directions (`in`, `out`, `any`), pressure levels, port groups (e.g., crossflow junction group 1 & 2), and connection modes (`join`, `merge`). | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `port-finder`, `network-validate`, `networks-flow` |
| `port-finder.lua` | `scripts/ports/` | Spatial query engine using `find_entities_filtered` to locate nearby compatible entity ports on the surface based on position and offset. | `port_finder.find_connections(entity)` | `network-validate.lua` |
| `port-evaluator.lua` | `scripts/ports/` | Evaluates flow and connection compatibility between candidate port pairs against rule matrices. | `port_evaluator.are_compatible(ent_a, port_a, ent_b, port_b)` | `port-compatibility-definitions`, `network-validate` |
| `port-compatibility-definitions.lua` | `scripts/ports/` | Configuration matrices detailing allowed flow pairs (`in`+`out`, `any`+`any`) and physical connection outcomes (`merge`+`merge` $\rightarrow$ `merge`, `join`+`merge` $\rightarrow$ `join`). | Matrices `flows` and `connections`. | `port-evaluator.lua` |
| `port-connection-definitions.lua` | `scripts/ports/` | Handler map binding outcome keys (`join`, `merge`, `unjoin`, `unmerge`) to script modules. | Maps `connection_defs.types` and `connection_defs.inverses`. | `network-join`, `network-merge`, `network-unjoin`, `network-unmerge` |
| `port-walk.lua` | `scripts/ports/` | Graph traversal engine (BFS) walking connected port edges matching specific edge types. | `port_walk.traverse(start_port_key, match_conn_type)` | `network-unmerge.lua` |
| `port-renderer.lua` | `scripts/ports/` | Visual debug overlay rendering green circle markers on active entity ports. | `draw_ports_for_entity()`, `draw_all()`, `clear_all()` | `debug-manager.lua`, Factorio Rendering API |

---

### 2.4 Network Topology, Pressure & Flow Engine

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `networks.lua` | `scripts/networks/` | Main API facade unifying network data storage, graph building, and metadata tracking. | Unified proxy for store and graph operations. | Used mod-wide |
| `networks-store.lua` | `scripts/networks/` | Low-level state storage manager for network IDs in `storage.networks.list`, member arrays, metadata extraction, and recycling IDs. | `create()`, `delete()`, `merge()`, `purge_port()`, `set_metadata()`, `get_metadata()`, `extract_metadata()` | `networks.lua` |
| `networks-graph.lua` | `scripts/networks/` | Spatial graph manager maintaining adjacency dictionaries in `storage.port_connections` and binding internal entity groups. | `record_connection()`, `remove_connection()`, `bind_group_to_network()` | `networks-store`, `port-definitions` |
| `network-connect.lua` | `scripts/networks/` | Hooks entity placement events and passes newly built entities to spatial validation. | Event listeners (`on_built_entity`, `script_raised_built`, etc.). | `network-validate.lua` |
| `network-disconnect.lua` | `scripts/networks/` | Hooks entity mining and destruction events, triggering payload spilling (`hub-spill.lua`) and passing removed entities to invalidation workflows. | Event listeners (`on_player_mined_entity`, `on_entity_died`, etc.). | `network-invalidate.lua`, `hub-spill.lua` |
| `network-rotate.lua` | `scripts/networks/` | Hooks orientation-change events, severing old spatial graph links and validating new orientation connections. | Event listeners (`on_player_rotated_entity`, `on_player_flipped_entity`). | `network-invalidate`, `network-validate` |
| `network-validate.lua` | `scripts/networks/` | Main spatial validation workflow: provisions internal networks, queries spatial neighbors via `port-finder`, tests via `port-evaluator`, invokes connection handlers, rebuilds flow overlays. | `network_validate.execute(entity)` | `port-finder`, `port-evaluator`, `networks-flow`, `network-form-internals` |
| `network-invalidate.lua` | `scripts/networks/` | Main invalidation workflow: identifies external edges, runs unjoin/unmerge handlers, purges port entries, triggers flow map rebuilds on surviving subgraphs. | `network_invalidate.execute(entity)` | `port-connection-definitions`, `networks`, `networks-flow` |
| `network-form-internals.lua` | `scripts/networks/` | Provisions default standalone internal network IDs for an entity's internal port groups upon build/rotate. | `network_form_internals.execute(entity)` | `networks.lua`, `port-definitions.lua` |
| `network-join.lua` | `scripts/networks/` | Registers a boundary edge between separate networks ("join"), leaving their network IDs independent. | `network_join.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-merge.lua` | `scripts/networks/` | Combines two subgraphs or entity internal groups into a single network ID ("merge"). | `network_merge.execute(ent_a, p_a, ent_b, p_b)` | `networks.lua` |
| `network-unjoin.lua` | `scripts/networks/` | Severs boundary edges between independent networks without recalculating network split topologies. | `network_unjoin.execute(port_key, neighbor_key)` | `networks.lua` |
| `network-unmerge.lua` | `scripts/networks/` | Uses `port-walk` graph traversal to evaluate if severing a merge edge breaks a network into disconnected subgraphs, provisioning new network IDs as required. | `network_unmerge.execute(port_key, neighbor_key)` | `port-walk.lua`, `networks.lua` |
| `pump-manager.lua` | `scripts/networks/` | Periodic 15-tick background scanner monitoring `pneumatic-pump` power states, broadcasting state toggles across all registered inlet/outlet ports via `port_defs.get_ports()` to trigger flow map rebuilds (`networks_flow.build`). | `register_pump()`, `unregister_pump()`, `check_pump_power_states()` | `networks-flow.lua`, `events.lua`, `port-definitions.lua` |
| `networks-pressure.lua` | `scripts/networks/` | Multi-source BFS pressure propagation engine calculating dynamic 10% pressure decay (`calculate_dropoff()`, floor min 1) across network edges starting from fixed active pressure sources (e.g. pumps). | `networks_pressure.process(net_id)` | `port-definitions.lua` |
| `networks-flow.lua` | `scripts/networks/` | Rebuilds directional vector maps, evaluates pump power via `is_pump_powered()` (`entity.energy > 0`), gates internal/external unpowered pump hops, checks flow rules and pressure deltas, invokes path culling (`flow-cull`), updates network metadata, triggers visual debug renderers. | `networks_flow.build(net_id)`<br>`is_pump_powered(entity)`<br>`draw_all()`, `clear_all()` | `networks-pressure`, `flow-cull`, `networks-flow-renderer`, `debug-manager` |
| `networks-flow-renderer.lua` | `scripts/networks/` | Visual debug renderer displaying cyan directional vectors and pressure labels (`P: X`) on entities. | `draw(net_id)`, `clear(net_id)` | Factorio Rendering API |
| `flow-cull.lua` | `scripts/networks/` | Iterative dead-end path pruner clearing non-viable outbound hops on multi-port entities (e.g., junctions and unpowered pump inlet paths). | `flow_cull.process(flow_map)` | `networks-flow.lua` |

---

### 2.5 Hub System & Cargo Packing / Unpacking

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), providing safe circuit condition evaluation (`evaluate_circuit_condition`) checking wire connectors before signal queries. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.evaluate_circuit_condition()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`, right position). Manages UI switches, conditions, wire channels, and receive latches. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, `on_gui_checked_state_changed`, `on_gui_elem_changed`, `on_gui_selection_state_changed`, `on_gui_text_changed`) | `hub-settings.lua`, `hub-manager.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Event listener for hub lifecycle and interleaved background tick scanner (`on_tick`) evaluating hub packing logic. | Interleaved background scanner, entity build/mining event listeners. | `hub-packing`, `hub-spill`, `hub-gui`, `events` |
| `hub-packing.lua` | `scripts/hubs/` | Main hub packing pipeline: Operational send check (`can_send`), Priority lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius for `player-transit-capsule`), cargo planning, primary capsule shell allocation (`primary_holder_slot`), biodegradable self-dissolve evaluation (`destroy_self`), liminal holder spawning, and injection via `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `quality-filter`, `cargo-planner`, `capsule-runner`, `hub-settings` |
| `hub-unpacking.lua` | `scripts/hubs/` | Main hub arrival & unpacking pipeline: Operational receive permission check (`can_receive`), passenger disembarkation onto nearby non-colliding positions (`find_non_colliding_position`), all-or-nothing cargo + vessel unpacking using multi-item slot space simulation (`can_insert_all()`) with Factorio 2.0+ quality-aware inventory slot filter parsing, liminal holder cleanup, and mechanical receive latch engagement. | `hub_unpacking.capture(capsule_tracker, hub_entity)`<br>`can_insert_all(...)` | `capsule-manager.lua`, `liminal-surface.lua`, `capsule-runner.lua`, `hub-settings.lua` |
| `hub-spill.lua` | `scripts/hubs/` | Handles safety unloading/spilling of capsule contents into chests or floor item stacks when hubs, tubes, junctions, or pumps are mined or destroyed. | `hub_spill.spill_capsule(...)`<br>`hub_spill.handle_entity_destruction(entity)` | `capsule-queries.lua`, `capsule-manager.lua` |
| `quality-filter.lua` | `scripts/hubs/packing/` | Evaluates item quality against capsule vessel rules (`ceil`, comparators, whitelists, blacklists). | `quality_filter.is_quality_allowed(...)` | `hub-packing.lua` |
| `cargo-planner.lua` | `scripts/hubs/packing/` | Calculates exact stack extraction and insertion plans for single or mixed cargo types, handling bio item slot costs, full-stack rules, and consolidation. | `cargo_planner.get_item_slot_cost(...)`<br>`cargo_planner.build_packing_plan(...)` | `hub-packing.lua` |

---

### 2.6 Capsule System & Traversal Engine

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: base slot capacities, quality scaling, mixed cargo/quality rules, stack consolidation rules, holder types, spill behaviors, spoilage modifiers (`spoilage_modifier`), spill risks (`spill_risk`), self-dissolve rules (`destroy_self`), and spent item transitions (`spent_capsule_item`). Covers baseline, biodegradable, refrigerated, spent refrigerated, reinforced, and player transit capsules. | Registry `capsule_definitions.types` | `hub-packing.lua`, `capsule-manager.lua`, `capsule-runner.lua`, `capsule-lifecycle.lua` |
| `capsule-definitions-guide.md` | `scripts/capsules/` | Technical reference document detailing all configuration parameters in `capsule-definitions.lua`. | Specification document. | Reference |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities stored in `storage.active_capsules`. Tracks primary capsule shell inventory slot (`primary_slot`). | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions.lua`, `storage` |
| `capsule-queries.lua` | `scripts/capsules/` | Standalone query & cleanup engine for active capsule holder lookup and unregistration. Supports multi-layer render cleanup (`clear_capsule_render`) across arrays of render objects. | `get_port_group()`, `find_capsules_at_entity()`, `get_capsule_count_at_entity()`, `get_capsule_count_at_entity_network()`, `remove_capsule()`, `clear_capsule_render()` | `storage`, `hub-spill.lua`, `capsule-runner.lua` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Per-tick lifecycle processor managing passenger teleportation, bio capsule spill risk scaling with research tech (`bio-capsule-integrity-1`..`4`), refrigerated spoilage reduction ($0.10$), and tool durability drain on primary shell. | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager.lua`, `capsule-definitions.lua`, `hub-spill.lua` |
| `capsule-motion.lua` | `scripts/capsules/` | Pathfinding hop selection, pressure drop evaluation, line capacity validation (`has_entity_network_capacity`), segment speed calculation, and arrival capture triggers. | `calculate_segment_speed()`, `has_entity_network_capacity()`, `select_next_target()`, `handle_arrival()` | `networks.lua`, `hub-definitions.lua`, `hub-unpacking.lua`, `capsule-queries.lua` |
| `capsule-renderer.lua` | `scripts/capsules/` | Visual rendering engine displaying emergency eject HUD text for passengers, debug circle indicators, and dominant payload item sprite icons. | `render()`, `get_dominant_item()` | `capsule-manager.lua`, `capsule-queries.lua`, `debug-manager.lua` |
| `capsule-runner.lua` | `scripts/capsules/` | Main tick-based motion runner (`on_tick`). Handles `inject_from_hub()`, continuous movement interpolation, mid-tick distance recalibration, backpressure limits, emergency passenger eject, and invocation of motion, lifecycle, and rendering sub-modules. | `inject_from_hub()`, `emergency_eject()`, `on_tick` handler | `networks.lua`, `port-definitions.lua`, `events.lua`, `capsule-motion.lua`, `capsule-lifecycle.lua`, `capsule-renderer.lua`, `capsule-queries.lua` |

---

## 3. Event Hook & Lifecycle Matrix

```
+-----------------------------------+------------------------------------+------------------------------------------+
| Factorio Engine Event             | Custom Dispatcher / Handler Module | Actions Triggered                        |
+-----------------------------------+------------------------------------+------------------------------------------+
| script.on_init                    | control.lua -> setup_storage()     | Initializes global storage schema        |
| script.on_configuration_changed   | control.lua -> setup_storage()     | Re-initializes global storage tables     |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_built_entity    | network-connect.lua                | Runs network_validate.execute()          |
| defines.events.on_robot_built_... | hub-manager.lua / hub-settings.lua | Registers active hubs & provisions       |
| defines.events.script_raised_...  | pump-manager.lua                   | hub_settings entries, registers pumps,   |
| defines.events.script_raised_...  | pneumatic-diverter-proxy-linkage   | instantiates hidden combinator proxy for |
|                                   | port-renderer.lua                  | diverters, draws port debug markers      |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_mined... | network-disconnect.lua             | Spills payloads (hub-spill.lua) & runs   |
| defines.events.on_robot_mined_... | hub-manager.lua / hub-settings.lua | network_invalidate.execute(), destroys   |
| defines.events.on_entity_died     | pump-manager.lua                   | hidden combinator proxies, clears graph  |
| defines.events.script_raised_...  | pneumatic-diverter-proxy-linkage   | connections, subgraphs, active hubs,     |
|                                   |                                    | hub settings, locks & pump power         |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_rotated  | network-rotate.lua                 | Runs network_invalidate.execute()        |
| defines.events.on_player_flipped  | pneumatic-diverter-proxy-linkage   | followed by network_validate.execute(),  |
|                                   |                                    | rotates hidden diverter circuit proxy    |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_gui_opened      | hub-gui.lua / hub-manager.lua      | Instantiates custom relative GUI panel   |
| defines.events.on_gui_closed      | pneumatic-diverter-proxy-linkage   | attached to chest window; suppresses     |
| defines.events.on_gui_checked_... |                                    | physical diverter GUI (player.opened=nil)|
| defines.events.on_gui_elem_...    |                                    | Syncs operational toggles & circuit rules|
| defines.events.on_gui_selection_..|                                    | Updates send/receive signals & constants |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_custom_input    | capsule-inputs.lua ->              | Triggers capsule_runner.emergency_eject  |
| (capsule-emergency-exit / Shift+E)| capsule-runner.lua                 | for passenger disembarkation, holder     |
|                                   |                                    | destruction, and tracking unregistration |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_tick            | hub-manager.lua                    | Interleaved hub scanner & lock reset check|
|                                   | pump-manager.lua                   | 15-tick periodic pump power-state scanner|
|                                   | capsule-runner.lua                 | Motion, continuous segment interpolation, |
|                                   |                                    | mid-transit lifecycle/spoil updates,     |
|                                   |                                    | bio spill risk & visual sprite rendering |
+-----------------------------------+------------------------------------+------------------------------------------+
```

---

## 4. Persistent Storage Schema (`storage`)

All persistent runtime state is preserved in Factorio's `storage` table:

```lua
storage = {
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

  -- Pump Management & Power State Tracking
  active_pumps = {
    [unit_number] = LuaEntity -- Registered active pump entities
  },
  pump_power_states = {
    [unit_number] = true -- Power state tracking (true = powered, false = unpowered)
  },

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity, -- Reference to invisible holder on liminal_surface
      type = "capsule", -- Variant type ("capsule", "biodegradable-capsule", "refrigerated-capsule", etc.)
      primary_slot = 1, -- Primary vessel shell inventory slot index inside liminal holder
      definition = { ... } -- Dynamic reference to capsule-definitions.lua
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1,
      capsule_id = capsule_id, -- Link to active_capsules entry
      source_hub = 101, -- Origin hub unit number (cleared when capsule exits origin entity)
      from_port_key = "101:1",
      to_port_key = nil, -- Set to nil when parked/stationary, continuously polling arrival
      last_port_key = "100:1",
      progress = 0.45, -- Traversal progress across current segment (0.0 to 1.0)
      passenger = LuaPlayer, -- Active character player handle during passenger transit, or nil
      slot_spoil_percents = { -- Tracked spoil percentages per slot for delta spoilage calculation
        [1] = 0.12
      },
      render_id = { LuaRenderObject, ... } -- Array of active rendering handles (HUD prompt, border ring + item sprite)
    }
  },

  -- Centralized Debug System State
  debug = {
    master = true,     -- Master debug system toggle (default: true)
    capsules = true,   -- Capsule visual rendering overlay flag (default: true)
    ports = false,     -- Port marker visual overlay flag (default: false)
    flow = false,      -- Flow vector visual overlay flag (default: false)
    prints = false     -- Console debug print logging flag (default: false)
  },

  -- Visual Rendering Overhead Storage
  flow_render_ids = {
    [net_id] = { LuaRenderObject, ... }
  }
}
```

---

## 5. Core Algorithms & Operational Mechanics

### 5.1 Spatial Validation & Internal Provisioning (`network-validate.lua`)
1. Provisions default internal networks for entity port groups via `network-form-internals`.
2. Searches for neighboring entities using spatial bounding boxes derived from `port-definitions`.
3. Verifies direction and connection compatibility against rule matrices using `port-evaluator`.
4. Executes specific edge handlers based on connection outcomes:
   * **`merge`**: Combines subgraphs into a unified Network ID (`network-merge`).
   * **`join`**: Establishes a cross-network boundary link while maintaining separate Network IDs (`network-join`).
5. Rebuilds flow topology overlays and pressure values for all affected networks (`networks-flow`).

### 5.2 Split Detection Graph Walking (`network-unmerge.lua` / `port-walk.lua`)
1. Removes the target connection edge from `storage.port_connections`.
2. Executes a Breadth-First Search (`port-walk`) starting from the severed neighbor port.
3. Compares reachable node counts against total remaining network members:
   * **No Split:** Preserves current Network ID and updates member list.
   * **Split Detected:** Provisions a new Network ID for the disconnected subgraph and updates `port_to_network` references.

### 5.3 Multi-Source Pressure Calculation & Power State Monitoring (`networks-pressure.lua` / `pump-manager.lua`)
1. Periodic pump manager (`pump-manager.lua`) scans `storage.active_pumps` every 15 ticks to evaluate power availability (`entity.energy > 0`). It iterates over all registered entity ports via `port_defs.get_ports()` so power state toggles update `storage.pump_power_states` and trigger `networks_flow.build(net_id)` across both inlet and outlet sub-networks over internal join boundaries.
2. Traverses connected networks via graph edges, halting at internal `"join"` boundaries (e.g. pumps, hubs).
3. Identifies fixed active pressure source nodes (e.g., active powered pumps configured with positive or negative pressure).
4. Executes multi-source BFS propagation:
   * Dynamic Pressure Decay: Calculates step-wise resistive pressure loss via `calculate_dropoff()`, scaling loss at 10% of local line pressure per edge hop (with a floor minimum of 1).
   * Evaluates port direction compatibility (`in`, `out`, `any`).
   * Commits output pressure values into `storage.port_pressures`.

### 5.4 Flow Map Generation & Path Culling (`networks-flow.lua` / `flow-cull.lua`)
1. Assembles flow nodes for local network members and cross-boundary neighbor ports.
2. Evaluates pump power availability directly via `is_pump_powered(entity)` (`entity.energy > 0`), ensuring initial placement validation and real-time state changes act instantaneously.
3. Restricts internal machine transfer hops across pump ports and suppresses external pressure-gradient vector creation into unpowered pump inlets.
4. Constructs outbound vector hops between ports if pressure gradients exist ($P_{\text{from}} > P_{\text{to}}$) or if internal mechanical pass-throughs allow it.
5. Invokes `flow-cull.lua` to remove dead-end internal hops on multi-port entities (such as 4-way junctions, crossflow junctions, or paths leading to unpowered pump inlets).
6. Stores completed flow maps in network metadata and updates visualization overlays.

### 5.5 Hub Cargo Evaluation, Consolidation & Injection (`hub-packing.lua` / `cargo-planner.lua` / `hub-settings.lua`)
1. Interleaved background scanner runs every 10 ticks per hub (`hub-manager.lua`).
2. **Operational Dispatch Guard:** Checks `hub_settings.can_send(entity)`. Evaluates manual toggle or circuit network conditions (`evaluate_circuit_condition`) checking red/green wire channels.
3. **Priority Lock Release:** Evaluates `evaluate_inventory()` at the top level. If `hub_inventory.is_empty()`, immediately clears `storage.hub_receive_locks[unit_number]`.
4. Checks `storage.hub_settings[unit_number].use_receive_lock`. If enabled and `storage.hub_receive_locks[unit_number]` is active, aborts packing to prevent immediate re-packing of freshly arrived items.
5. Queries `capsule_runner.get_capsule_count_at_entity(hub_entity)` to dynamically verify remaining hub capacity.
6. Checks hub inventory for primary vessel capsule items. If packing a `player-transit-capsule`, scans for nearby player character entities within a 2.5 tile radius and attaches the character to the capsule holder.
7. Calculates quality-scaled capacity bonuses (`base_capacity + quality_level * quality_affected_capacity`).
8. Filters container items against quality constraints (`quality-filter.lua`) and builds extraction plans via `cargo-planner.lua`.
9. Spawns an `invisible-capsule-holder` on `liminal_surface`, populates cargo items first, and assigns the primary capsule shell to a tracked slot index (`primary_holder_slot`).
10. If the capsule definition mandates `destroy_self = true` (e.g., `biodegradable-capsule`), the vessel item shell is consumed upon packing.
11. Calls `capsule_runner.inject_from_hub(capsule_id, hub_entity, passenger)`:
    * Peeks the flow map metadata across all connected ports.
    * Injects the capsule onto the port exhibiting the strongest outward pressure gradient ($\Delta P = P_{\text{from}} - P_{\text{to}}$).
    * If connected to a network with no active flow, places capsule on a connected port in a dormant state until flow starts.
    * If hub has no network connections, aborts injection, destroys holder, and reverts items back into chest.

### 5.6 Capsule Traversal, Lifecycle Mechanics & Motion Engine (`capsule-runner.lua` / `capsule-motion.lua` / `capsule-lifecycle.lua`)
1. Executes on every game tick (`on_tick`).
2. **Stationary Arrival Polling:** Before executing distance motion, evaluates any stationary/parked capsules (`to_port_key == nil`). Re-triggers `handle_arrival()` every tick so parked capsules unpack the instant space frees up in a destination hub chest.
3. **Capsule Lifecycle & Spoilage Mitigation (`capsule-lifecycle.lua`):**
   * **Passenger Positioning:** Synchronizes player character position to `curr_pos` via `teleport`.
   * **Bio Spill Risk:** Evaluates mid-transit structural failures on fragile containers (`biodegradable-capsule` with `spill_risk = 0.0008`). Reduces baseline spill risk by 25% per tier based on force research (`bio-capsule-integrity-1` through `4`, reaching 0% risk at L4). Spills cargo with an `"explosion"` FX on failure.
   * **Refrigerated Decay & Tool Durability:** Runs every 60 ticks. Applies `spoilage_modifier` ($0.10$) scaling to reduce cargo spoilage inside `refrigerated-capsule` holders using type-guarded stack re-instantiation. Consumes durability strictly on `phys_capsule.primary_slot` tool items. When durability drops to 0, replaces the tool stack in-place with a `spent-refrigerated-capsule`.
4. **Emergency Passenger Ejection:** On custom input `capsule-emergency-exit` (`SHIFT + E`), `capsule_runner.emergency_eject(player)` grounds the passenger onto a nearby safe tile, spawns explosion FX, destroys the liminal holder, clears render objects, and unregisters tracking state.
5. **Pressure-Scaled Speed Calculation:** Evaluates travel velocity via `calculate_segment_speed()`. Velocity scales non-linearly with the square root of local pressure drop ($\Delta P = |P_{\text{from}} - P_{\text{to}}|$), clamped safely within a 4 to 60 tiles/second envelope (baseline 15 tiles/sec).
6. Evaluates trajectory using flow map outbound vectors:
   * **Memory Tracking:** Retains `source_hub` (`unit_number`) on spawn/injection. Wipes memory once capsule steps off origin entity.
   * **Anti-Backtracking:** Filters out `last_port_key` unless hitting a dead end.
   * **In-Line Backpressure Guard:** Evaluates target entity-network capacity via `capsule_queries.get_capsule_count_at_entity_network(unit_number, net_id)`. If target segment meets or exceeds `MAX_CAPSULES_PER_ENTITY_NETWORK` (default `1`), target hop selection halts, forcing capsule to park upstream until downstream capacity clears.
   * **Pressure Drop Scoring:** Prioritizes movement toward ports with lower pressure levels ($\Delta P = P_{\text{current}} - P_{\text{target}}$).
   * **Randomized Tie-Breaking:** Randomly selects among equal top-scoring target hops.
7. Consumes motion distance (`tiles_this_tick`), executing mid-tick distance recalibration when acquiring new target segments mid-tick.
8. **Dynamic Render Overlay (`capsule-renderer.lua`):** When passenger is active, renders `[Shift + E] Emergency Eject` prompt. When `is_debug_active("capsules")` is enabled, inspects `phys_capsule.primary_slot` via `get_dominant_item()`. Renders a gold ring border (`radius = 0.35`, `width = 2`) framing a scaled item sprite (`x_scale = 0.55`, `y_scale = 0.55`) of the dominant payload item directly over the capsule's surface location.

### 5.7 Hub Capture, Multi-Item Unpacking & Passenger Disembarkation (`hub-unpacking.lua` / `hub-settings.lua`)
1. When a capsule steps onto or polls a hub port:
   * **Operational Arrival Guard:** Evaluates `hub_settings.can_receive(hub_entity)`. If `false`, rejects capture and leaves capsule safely parked upstream on origin entity ports.
   * Verifies hub unit number against capsule's `source_hub` memory (prevents origin hub from re-capturing its own capsule).
2. Invokes `hub_unpacking.can_insert_all(holder_inv, hub_inv)`:
   * Performs multi-item slot space simulation across all payload items (cargo + vessel capsule shell).
   * Inspects slot filters via `hub_inv.get_filter(i)`, extracting Factorio 2.0+ filter structure attributes (`filter_name` and `filter_quality`). Empty slots with active filters are categorized separately and matched against incoming items (`item|quality` before falling back to generic item prototype filters and unfiltered slots).
   * Allocates empty chest slots sequentially across distinct item types to prevent partial stack collision errors.
3. If `can_insert_all()` passes (All-or-Nothing Guarantee):
   * Safely disembarks any passenger in a `player-transit-capsule` onto a nearby non-colliding tile (`surface.find_non_colliding_position`).
   * Transfers 100% of payload items from liminal holder into hub chest inventory.
   * Destroys liminal holder entity and unregisters capsule from tracking systems.
   * Sets `storage.hub_receive_locks[hub_unit_number] = true` (mechanical receive latch).
4. If `can_insert_all()` fails:
   * Capsule remains in liminal storage and parks on the hub port (`to_port_key = nil`).
   * Polling loop in `capsule-runner.lua` continues re-checking `can_insert_all()` on subsequent ticks until hub inventory space clears.

### 5.8 Generalized Entity Destruction & Capsule Payload Spill Safety (`hub-spill.lua` / `network-disconnect.lua` / `capsule-queries.lua`)
1. When any network structure (hub, tube, junction, pump, diverter) is mined or destroyed, `network-disconnect.lua` intercepts the event before graph invalidation occurs.
2. Invokes `hub_spill.handle_entity_destruction(entity)`.
3. Queries `capsule_queries.find_capsules_at_entity(entity)` to locate all active or parked capsules bound to the entity's ports or network segments.
4. Spills 100% of payload items (cargo + `item-capsule` vessel shell) onto the surface at entity coordinates or into adjacent containers.
5. Invokes `hub_spill.spill_capsule()` to unregister tracking state, destroy visual render objects (border ring, text prompts, and item sprites), and clean up liminal holder entities on `liminal_surface`.

### 5.9 Hub Relative GUI, Circuit Integration & Diverter Proxy Linkage (`hub-gui.lua` / `hub-settings.lua` / `pneumatic-diverter-proxy-linkage.lua`)
1. **Relative Window Attachment:** When a player opens a capsule hub chest, `hub-gui.lua` anchors a custom UI panel (`hub_operational_mode_frame`) to the right side of the container window (`defines.relative_gui_type.container_gui`, `defines.relative_gui_position.right`).
2. **Operational Toggles:** Exposes interactive checkboxes for `hub_wire_red`/`green` wire channel reading, `can_send` / `use_circuit_send`, `can_receive` / `use_circuit_receive`, signal selector buttons (`choose-elem-button`), operator drop-downs (`<`, `>`, `=`, `≥`, `≤`, `≠`), constant text fields, and `use_receive_lock`.
3. **Safe Circuit Evaluation:** Evaluates circuit signal rules via `hub_settings.evaluate_circuit_condition()`, explicitly verifying active `defines.wire_connector_id` connections before calling `entity.get_signal()` to eliminate nil parameter runtime crashes when wire channels are toggled off.
4. **Pneumatic Diverter Proxy Management (`pneumatic-diverter-proxy-linkage.lua`):**
   * Automatically pairs each physical `pneumatic-diverter` (electric-energy-interface) with a hidden `pneumatic-diverter-circuit-proxy` (constant-combinator) at the same position.
   * Synchronizes proxy direction on entity placement, rotation (`on_player_rotated_entity`, `on_player_flipped_entity`), and destruction.
   * Intercepts `on_gui_opened` on the physical diverter entity and immediately closes player GUI (`player.opened = nil`), forcing circuit wire interaction to route through the constant combinator proxy.

---

## 6. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/toggle-debug` | Toggles master debug mode on/off (`storage.debug.master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging output (`storage.debug.prints`). | `scripts/debug-manager.lua` |
| `/toggle-ports` | Toggles green visual port marker circles on entities (`storage.debug.ports`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles cyan flow vector lines and pressure numerical text (`storage.debug.flow`). | `scripts/debug-manager.lua` |
| `/toggle-capsules` | Toggles visual rendering overlay for active capsule positions and dominant payload item icons (`storage.debug.capsules`). | `scripts/debug-manager.lua` |