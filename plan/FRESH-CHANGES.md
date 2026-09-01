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