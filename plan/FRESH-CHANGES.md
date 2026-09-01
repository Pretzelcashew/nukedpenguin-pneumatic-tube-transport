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