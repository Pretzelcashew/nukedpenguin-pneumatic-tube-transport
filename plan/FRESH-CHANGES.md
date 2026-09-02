### Revision: Flow Engine Entity Creation Listener
**Date:** 2026-09-01 13:27 (EDT)
**Context:** Add an entity placement listener for the new flow propagation system with integrated debug logging.
**Key Changes:**
1. **Entity Placement Listener (`scripts/flow/entity-listener.lua`):** Added event listener covering all entity creation triggers (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive`, `on_space_platform_built_entity`, `on_entity_cloned`). Filters for pneumatic structures using `port_defs.registered_names`.
2. **Debug Output (`scripts/flow/entity-listener.lua`):** Connected creation events to `debug_print` to print placement info (name, unit number, coordinates, surface) to chat when debug prints are active.
3. **Control Entrypoint (`control.lua`):** Registered `scripts.flow.entity-listener` at top level.


### Revision: Standardized Flow Engine Entity Lifecycle Listeners
**Date:** 2026-09-01 15:07 (EDT)
**Context:** Standardize and expand the new flow propagation system's entity lifecycle listeners into a symmetrical tri-module suite (`creation-listener`, `removal-listener`, and `state-listener`) inside `scripts/flow/`.
**Key Changes:**
1. **Creation Listener Rename & Standardization (`scripts/flow/creation-listener.lua`):** Renamed `entity-listener.lua` to `creation-listener.lua` for consistent naming across flow modules while keeping entity placement hook logic and debug logging intact.
2. **Removal Event Listener (`scripts/flow/removal-listener.lua`):** Created dedicated removal event listener covering player/robot mining, entity destruction, script destruction, and space platform entity mining (`on_space_platform_mined_entity`) for registered pneumatic entities with debug print output.
3. **State Change Event Listener (`scripts/flow/state-listener.lua`):** Created dedicated state change listener tracking orientation and flipping events (`on_player_rotated_entity`, `on_player_flipped_entity`) for registered pneumatic entities with debug print output.
4. **Control Entrypoint Registration (`control.lua`):** Updated top-level `require` declarations to import `creation-listener`, `removal-listener`, and `state-listener`.


### Revision: Flow Engine Port Definitions & Spatial Connection Manager
**Date:** 2026-09-01 15:32 (EDT)
**Context:** Add simplified port definitions and an event-driven connection manager to the new decoupled flow engine system (`scripts/flow/`), establishing direct port-to-port spatial linkage without legacy network BFS graph execution.
**Key Changes:**
1. **Lightweight Flow Port Definitions (`scripts/flow/port-defs.lua`):** Created standalone port definition registry containing cardinal tile offsets for all pneumatic structure variants (`capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, `pneumatic-diverter`) and exposed `registered_names` alongside `get_ports(entity)`.
2. **Spatial Connection Manager (`scripts/flow/connection-manager.lua`):** Implemented connection manager tracking active spatial port edges in `storage.flow_port_connections`. Listens to creation, removal, and state change listeners to dynamically record bidirectional links between adjacent matching ports, sever removed edges, and sync rotation/flip state transitions with integrated debug logging.
3. **Decoupled Lifecycle Listeners (`scripts/flow/creation-listener.lua`, `scripts/flow/removal-listener.lua`, `scripts/flow/state-listener.lua`):** Updated flow lifecycle event listeners to import `scripts/flow/port-defs` directly, isolating the new flow suite from legacy port definition dependencies.
4. **Control Entrypoint Registration (`control.lua`):** Registered `scripts.flow.port-defs` and `scripts.flow.connection-manager` at top level and initialized `storage.flow_port_connections` in `setup_storage()`.


### Revision: Console Debug Message Prefix Filter Commands
**Date:** 2026-09-01 15:46 (EDT)
**Context:** Add console commands to filter debug chat messages by prefix string, allowing developers to isolate log outputs for specific subsystems during testing.
**Key Changes:**
1. **Debug State & Filtering (`scripts/debug-manager.lua`):** Extended per-player debug storage schema with a `filter` field. Updated `debug_print` to validate incoming message strings against `dbg.filter` via prefix checking (`msg:sub(1, #dbg.filter) == dbg.filter`).
2. **Filter Management Commands (`scripts/debug-manager.lua`):** Registered `/debug-filter <text>` and `/debug-filter-reset` console commands with parameter quote-trimming logic and player chat status feedback.


### Revision: Water-Like Flow Propagation Engine & Overlay Debug System
**Date:** 2026-09-01 16:29 (EDT)
**Context:** Implement a rudimentary water-like BFS flow propagation engine through connected ports, add visual debug rendering overlays with Pneumatic Control Panel UI toggles, and resolve cyclic module dependency stack overflows.
**Key Changes:**
1. **Water-Like Flow Propagation Engine (`scripts/flow/flow-engine.lua`):** Created a BFS propagation module treating `pneumatic-pump` and `pneumatic-diverter` entities as flow emitters starting at maximum strength (10). Propagates flow across internal entity ports and external connected port edges (`storage.flow_port_connections`), decaying by 1 per hop down to 0, and maintaining runtime state in `storage.flow_levels`.
2. **Flow Debug Overlay & Control Panel Toggle (`scripts/debug-manager.lua` & `scripts/flow/flow-engine.lua`):** Integrated cyan circle markers, numerical flow level text, and connection lines drawn on official rendering layers. Added `new_flow` debug state toggles, console commands (`/toggle-new-flow`, `/pt-toggle-new-flow`), hotbar shortcut sync, and a `"New Flow Engine (Alt Mode)"` checkbox in the Pneumatic Control Panel GUI.
3. **Surface Registration & Entrypoint Integration (`control.lua`):** Registered `scripts.flow.flow-engine` at top level, added schema initialization for `flow_entities`, `flow_emitters`, `flow_levels`, and `new_flow_render_objects`, and added surface entity scanning on `on_init` / `on_configuration_changed`.
4. **Cyclic Require Stack Overflow Fix (`scripts/flow/*`):** Removed redundant `require("scripts.debug-manager")` statements from `creation-listener.lua`, `removal-listener.lua`, `state-listener.lua`, `connection-manager.lua`, and `flow-engine.lua`. Leveraged global `debug_print` access to break cyclic require loops during top-level module loading.


### Revision: Event-Driven Delta Flow Engine & Spatial Port Registry
**Date:** 2026-09-01 18:47 (EDT)
**Context:** Replace instant global BFS graph sweeps with an event-driven delta wavefront flow propagation engine and an O(1) multi-port spatial coordinate registry.
**Key Changes:**
1. **Multi-Port Spatial Registry (`scripts/flow/connection-manager.lua`):** Replaced `surface.find_entities_filtered` queries with O(1) spatial coordinate string lookups (`storage.flow_port_registry`). Converted port storage at tile coordinates into a multi-port dictionary (`{ [port_key] = port_data }`) so co-located ports do not overwrite each other during placement or rotation, ensuring clean connection severing upon entity removal.
2. **Event-Driven Delta Wavefront Engine (`scripts/flow/flow-engine.lua`):** Replaced synchronous global BFS sweeps with a 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue`. Flow propagates outward from active emitters (`MAX_FLOW = 10`) at 60 tiles/second until reaching steady-state equilibrium. When no levels change or the network is idle, `storage.flow_queue` empties, allowing `step()` to return on line 1 for 0-UPS idle performance.
3. **Drain Wavefront & Removal Handling (`scripts/flow/flow-engine.lua` & `scripts/flow/connection-manager.lua`):** Entity creation, removal, and rotation events enqueue affected local ports into `storage.flow_queue`. Severed tube connections trigger a tile-by-tile downstream drain wave (`compute_entity_flow_level()`), cleanly clearing cut-off flow values to zero frame-by-frame before returning the engine to sleep.
4. **GUI Display Crash Prevention (`scripts/flow/flow-engine.lua`):** Added `get_player_object_and_index` parameter resolution in `draw_for_player` and `clear_all` to safely handle both integer player indices and `LuaPlayer` object handles passed from Pneumatic Control Panel GUI check events (`on_gui_checked_state_changed`).


### Revision: Flow Propagation Batching, Negative Pressure & Spatial Disconnection Updates
**Date:** 2026-09-01 19:34 (EDT)
**Context:** Add time-sliced batching to the flow queue, introduce negative flow values for pump intake ports, throttle visual overlay updates, and revise entity disconnection handling for rotated and flipped structures.
**Key Changes:**
1. **Flow Queue Batching (`scripts/flow/flow-engine.lua`):** Added a per-tick execution limit (`BATCH_SIZE = 50`) to `flow_engine.step()`, spreading queue processing across ticks during large placement events.
2. **Negative Flow & Emitter Levels (`scripts/flow/port-defs.lua` & `scripts/flow/flow-engine.lua`):** Assigned directional `flow = -10` (intake) and `flow = 10` (output) attributes to `pneumatic-pump` ports in `port-defs.lua`. Updated `compute_port_flow_level` to calculate negative flow levels (-10 up to -1) alongside positive pressure (+10 down to +1) and resolve opposing magnitudes.
3. **Throttled Overlay Redraws (`scripts/flow/flow-engine.lua`):** Added `flow_render_dirty` tracking to throttle full overlay redraws (`flow_engine.redraw_all()`) to 15-tick intervals during active sweeps or when the queue empties. Color-coded positive levels (Blue/Cyan) and negative levels (Orange/Red).
4. **Unit Port Coordinate Tracking (`scripts/flow/connection-manager.lua` & `control.lua`):** Added `storage.flow_unit_ports` to record tile coordinates upon connection. Updated `disconnect_entity` to clean up registered ports, severed connections, and port levels using recorded tile coordinates during entity removal, rotation, and flip events.


### Revision: Flow Engine Consolidation & Granular Spatial Topology Management
**Date:** 2026-09-01 21:30 (EDT)
**Context:** Consolidate the distributed flow simulation system into a unified, high-performance engine (`scripts/flow/flow-engine.lua`), removing redundant listener/manager modules and replacing full visual redraw sweeps with targeted O(1) render updates.
**Key Changes:**
1. **Module Consolidation & File Cleanup (`scripts/flow/`):** Removed `connection-manager.lua`, `creation-listener.lua`, `removal-listener.lua`, and `state-listener.lua`. Consolidated entity lifecycle handling, connection graph tracking, and port wavefront propagation directly inside `scripts/flow/flow-engine.lua`.
2. **Spatial Grid Topology (`scripts/flow/flow-engine.lua`):** Implemented a coordinate-indexed spatial lookup (`flow_grid`, `flow_nodes`, `flow_connections`) using formatted string position keys (`surface@x,y`). Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent entities.
3. **Granular Rendering Pipeline (`scripts/flow/flow-engine.lua`):** Replaced bulk visual redraws with direct O(1) single-port and single-edge object mutations (`update_port_render`, `update_edge_render`, `destroy_port_renders`, `destroy_edge_render`). Render circles, flow level text, and link lines update dynamically on state change per player index rather than triggering map-wide sweeps.
4. **Mod Lifecycle Cleanup (`control.lua`):** Simplified mod initialization and configuration change hooks (`setup_storage`). Removed legacy sub-table initialization and storage keys (`flow_port_registry`, `flow_entities`, `flow_emitters`), delegating entity registration directly to `flow_engine.connect_entity(entity)`.


### Revision: Flow Engine Entity Flavor & Structural Port Group Architecture
**Date:** 2026-09-01 22:05 (EDT)
**Context:** Restore original port group structure across pneumatic entities, implement explicit non-transmitting hub behavior, and update wavefront propagation logic to respect internal group transmission boundaries without legacy graph overhead.
**Key Changes:**
1. **Port Group & Transmission Definitions (`scripts/flow/port-defs.lua`):** Assigned `group = 1` across all port definitions for hubs, tubes, pumps, junctions, and diverters. Restored split internal groups (`group = 1` for vertical, `group = 2` for horizontal) on `crossflow-junction`. Added `transmit = false` attribute to hub port definitions to block internal flow bridging across hub ports.
2. **Node Metadata & Group Transmission (`scripts/flow/flow-engine.lua`):** Updated `connect_entity` to cache `node.group` and `node.transmit`. Updated `compute_port_flow_level` to permit internal port sampling only when both ports are transmitting and share matching non-nil group IDs (`can_transmit_internally`), while allowing non-transmitting hub ports to sample their own direct external connections (`is_self`).
3. **Targeted Wavefront Queueing (`scripts/flow/flow-engine.lua`):** Refined `flow_engine.step` so that state changes on a port only enqueue sister internal ports if both ports are transmitting and share the same internal group ID, suppressing unnecessary queue ticks for non-transmitting hubs and isolated crossflow pairs.


### Revision: Startup Flow Version Setting & Debug Panel Version Guards
**Date:** 2026-09-01 22:58 (EDT)
**Context:** Add a startup mod setting to toggle between legacy (v1) and event-driven wavefront (v2) flow engines, implementing modular event registration and updating the Pneumatic Control Panel to safely adapt UI toggles per engine version.
**Key Changes:**
1. **Startup Mod Setting (`settings.lua` & `locale/en/config.cfg`):** Created `settings.lua` registering the `pneumatic-flow-version` startup string setting (`v1` vs `v2`, default `v1`). Added corresponding localized titles and descriptions under `[mod-setting-name]` and `[mod-setting-description]` in `locale/en/config.cfg`.
2. **Modular Event Registration (`scripts/flow/flow-engine.lua` & `control.lua`):** Encapsulated v2 tick and spatial topology event listeners into `flow_engine.register_events()`. Updated `control.lua` to only invoke `register_events()`, `flow_engine.init_storage()`, and surface spatial scans when `pneumatic-flow-version` is set to `v2`.
3. **Debug Panel Version Guards & Method Correction (`scripts/debug-manager.lua`):** Corrected `flow_engine.clear_all` calls to `flow_engine.clear_all_renders`. Guarded v2 overlay render commands behind `FLOW_VERSION == "v2"` and hid the "New Flow Engine" checkbox in the Pneumatic Control Panel when running in `v1` mode, preventing runtime GUI crashes.


### Revision: Symmetrical Flow Engine Event Gating & v1 Lifecycle Isolation
**Date:** 2026-09-01 23:34 (EDT)
**Context:** Isolate legacy (v1) network topology construction, background graph rebuilding, and capsule movement loops when running in v2 flow mode, establishing symmetrical internal version guards across both engines.
**Key Changes:**
1. **v1 Network Topology Event Gating (`scripts/networks/network-connect.lua`, `scripts/networks/network-disconnect.lua`, `scripts/networks/network-rotate.lua`):** Guarded network connect, disconnect, and rotation event listeners behind `FLOW_VERSION == "v1"`. Disables v1 graph validation and edge invalidation on placement/mining/rotation when running in `v2` mode while preserving hub cargo spilling and pump/diverter orientation notifications.
2. **Staged Rebuild Engine Gating (`scripts/networks/network-rebuild-engine.lua`):** Guarded the time-sliced background graph rebuild `on_tick` processor (`network_rebuild_engine.step`) behind `FLOW_VERSION == "v1"`, preventing graph split checks and v1 flow map updates during `v2` operation.
3. **v1 Capsule Motion Runner Gating (`scripts/capsules/capsule-runner.lua`):** Guarded v1 tick updates (`update_capsules`), liminal surface spawn listeners, and `networks_flow` listener registrations behind `FLOW_VERSION == "v1"`. Silences v1 capsule movement and segment interpolation during `v2` mode while keeping module helper functions exported.
4. **v2 Flow Engine Internal Self-Guarding (`scripts/flow/flow-engine.lua` & `control.lua`):** Added internal `FLOW_VERSION == "v2"` guards inside `flow_engine.register_events()`, `init_storage()`, `connect_entity()`, `disconnect_entity()`, and `draw_all()`, making `flow-engine.lua` self-contained and symmetrical with v1 modules. Guarded legacy `networks_flow.draw_all()` call in `control.lua` behind `FLOW_VERSION == "v1"`.


### Revision: v2 Flow Engine Capsule Runner & Hub Packing Integration
**Date:** 2026-09-02 08:45 (EDT)
**Context:** Implement the foundational v2 flow engine capsule runner module and integrate hub packing delegation across v1 and v2 flow engines with debug logging.
**Key Changes:**
1. **v2 Capsule Runner Module (`scripts/flow/capsule-runner.lua`):** Created dedicated v2 capsule runner handling outbound hub port resolution (`find_best_hub_outbound_port`), capsule injection (`inject_from_hub`), parked capsule wakeup, tick frame rendering updates, and event registration. Evaluates active port flow levels while defaulting fallback to internal hub port 1 (`unit_number .. ":1"`), allowing disconnected hubs to pack capsules onto internal nodes. Includes `debug_print` output logging successful packaging onto the v2 flow engine.
2. **Capsule Runner Facade Delegation (`scripts/capsules/capsule-runner.lua`):** Added `FLOW_VERSION == "v2"` version routing inside `inject_from_hub` and `wake_parked_capsules` to forward calls to `scripts/flow/capsule-runner.lua` when running in v2 mode while keeping v1 runtime logic fully intact.
3. **v2 Event Registration & Top-Level Require (`control.lua`):** Required `scripts/flow/capsule-runner.lua` at top level and registered `v2_capsule_runner.register_events()` when startup setting `pneumatic-flow-version` is set to `v2`.


### Revision: v2 Flow Engine Granular Capsule Runner & Facade Synchronization
**Date:** 2026-09-02 09:17 (EDT)
**Context:** Implement discrete node-to-node capsule movement for the v2 flow engine with pressure gradient target selection, diverter filter lookahead, O(1) hub arrival capture, and facade routing synchronization.
**Key Changes:**
1. **v2 Granular Node Hop Runner (`scripts/flow/capsule-runner.lua`):** Implemented discrete node-to-node hop movement executing every 6 ticks (staggered per capsule ID) with multi-hop processing (`MAX_NODE_HOPS_PER_STEP = 3`) for internal entity transitions, continuous passenger position synchronization, and unused progress schema preservation.
2. **Flow Gradient Target Selection & Filter Lookahead (`scripts/flow/capsule-runner.lua`):** Created candidate target selector (`select_next_target`) evaluating positive pressure drop (`level_from - level_cand`), intake vacuum pull, compiled diverter filters, and downstream path validation (`is_hop_valid`) to prevent capsules from entering machines without open exits.
3. **O(1) Hub Arrival & Capture Engine (`scripts/flow/capsule-runner.lua`):** Integrated O(1) hub entity lookup via `storage.active_hubs` in `handle_arrival` for capsule capture/unpacking, liminal unit spoilage re-instantiation, and player passenger emergency eject (`emergency_eject`).
4. **Facade Router Delegation (`scripts/capsules/capsule-runner.lua`):** Updated facade module functions `get_capsule_location`, `emergency_eject`, and `remove_capsule` to delegate to `scripts/flow/capsule-runner.lua` when running in `v2` mode.


### Revision: v2 Flow Engine Gradient-Driven Motion & Emitter Traversal
**Date:** 2026-09-02 09:51 (EDT)
**Context:** Eliminate capsule oscillation ("dancing") in zero-gradient flow zones, unpowered networks, and dead ends under the v2 flow engine by enforcing strict positive pressure drop requirements and metadata-based emitter traversal.
**Key Changes:**
1. **Strict Pressure Gradient Filtering (`scripts/flow/capsule-runner.lua`):** Updated `select_next_target` to require a strictly positive flow drop (`drop > 0`) for candidate target selection, preventing capsules from endlessly wandering across flat-level or unpowered tube networks.
2. **Dead-End & Unpowered Motion Suppression (`scripts/flow/capsule-runner.lua`):** Removed unconditional fallback backtracking and allowed capsules to park cleanly (`return nil`) when no outbound hop offers an active positive flow drop.
3. **Metadata-Based Emitter & Diverter Traversal (`scripts/flow/capsule-runner.lua`):** Leveraged `node.emitter` metadata attributes rather than entity name matching to handle internal pump push (`emitter < 0` to `emitter > 0` with `drop = math.huge`) and evaluate downstream diverter output lookahead (`effective_from = cand_node.emitter`), routing capsules smoothly through active output branches.