Here is a modular, 4-stage execution plan designed so you can copy and paste each stage as an isolated task prompt to a Gemini instance.

---

### Stage 1: Decouple Configuration, Entry Points & Debug Interfaces

**Task Description for Gemini Instance:**
> **Goal:** Make the v2 flow engine the sole execution path by removing `FLOW_VERSION` gating from startup configuration, `control.lua`, `debug-manager.lua`, and the `capsule-runner.lua` facade script.
> 
> **Files to Modify:**
> 1. `settings.lua`
> 2. `control.lua`
> 3. `scripts/debug-manager.lua`
> 4. `scripts/capsules/capsule-runner.lua`
> 
> **Specific Instructions:**
> - **`settings.lua`**: Remove or comment out the `pneumatic-flow-version` startup setting definition.
> - **`control.lua`**:
>   - Remove top-level `require` statements for v1 modules: `scripts.networks.networks`, `scripts.networks.networks-flow`, `scripts.ports.port-renderer`, `scripts.ports.port-finder`, `scripts.networks.network-connect`, `scripts.networks.network-disconnect`, `scripts.networks.network-rotate`.
>   - Remove `FLOW_VERSION` string lookups. Always call `flow_engine.register_events()`, `v2_capsule_runner.register_events()`, and `flow_engine.init_storage()`.
>   - In `setup_storage()`, remove calls to `networks.init()` and `networks_flow.draw_all()`.
> - **`scripts/capsules/capsule-runner.lua`**:
>   - Remove all legacy v1 motion calculation code, `update_capsules` loops, `networks_flow` listeners, and `FLOW_VERSION == "v1"` event registrations.
>   - Convert `capsule-runner.lua` into a direct passthrough/alias delegating directly to `require("scripts.flow.capsule-runner")`.
> - **`scripts/debug-manager.lua`**:
>   - Remove `FLOW_VERSION` checks, v1 UI checkboxes (`pneumatic_debug_chk_flow`, `pneumatic_debug_chk_ports`), and v1 commands (`/toggle-flow`, `/toggle-ports`).
>   - Retain v2 flow overlays (`/toggle-new-flow` or alias as `/toggle-flow`) and capsule peeking features.
> - **Constraint:** Ensure all `require` statements remain strictly at the top level of each script.

---

### Stage 2: Decouple Machine Managers & Event Lifecycle Hooks

**Task Description for Gemini Instance:**
> **Goal:** Disconnect v1 network graph rebuilding (`network-rebuild-engine`, `port-definitions`) from machine state managers and entity lifecycle events.
> 
> **Files to Modify:**
> 1. `scripts/networks/pump-manager.lua`
> 2. `scripts/networks/diverter-manager.lua`
> 3. `scripts/networks/network-connect.lua`
> 4. `scripts/networks/network-disconnect.lua`
> 5. `scripts/networks/network-rotate.lua`
> 
> **Specific Instructions:**
> - **`scripts/networks/pump-manager.lua`**:
>   - Remove top-level requires for `scripts.networks.network-rebuild-engine` and `scripts.ports.port-definitions`.
>   - Simplify `rebuild_pump_networks(entity)` to unconditionally invoke:
>     ```lua
>     flow_engine.enqueue_unit_ports(entity.unit_number)
>     capsule_runner.wake_parked_capsules(entity.unit_number)
>     ```
> - **`scripts/networks/diverter-manager.lua`**:
>   - Remove top-level requires for `scripts.networks.network-rebuild-engine` and `scripts.ports.port-definitions`.
>   - Simplify `rebuild_diverter_networks(entity)` to unconditionally invoke:
>     ```lua
>     flow_engine.enqueue_unit_ports(entity.unit_number)
>     capsule_runner.wake_parked_capsules(entity.unit_number)
>     ```
> - **`scripts/networks/network-connect.lua`**, **`network-disconnect.lua`**, **`network-rotate.lua`**:
>   - Remove all v1 `network_validate` and `network_invalidate` execution calls.
>   - Keep `hub_spill.handle_entity_destruction(entity)` inside `network-disconnect.lua` and proxy linkage settings notifications inside `network-rotate.lua`.
> - **Constraint:** Ensure all `require` statements remain strictly at the top level of each script.

---

### Stage 3: Purge Obsolete v1 Files & Add Storage Migration Cleanup

**Task Description for Gemini Instance:**
> **Goal:** Delete all obsolete v1 network and port files, relocate active machine managers out of `scripts/networks/`, and add a storage cleanup routine in `control.lua`.
> 
> **Files/Directories to Relocate:**
> - Move `scripts/networks/pump-manager.lua` $\rightarrow$ `scripts/pump-manager.lua`.
> - Move `scripts/networks/diverter-manager.lua` $\rightarrow$ `scripts/diverter-manager.lua`.
> - Update top-level `require` paths in `control.lua`, `prototypes/pneumatic-pump-proxy-linkage.lua`, and `prototypes/pneumatic-diverter-proxy-linkage.lua`.
> 
> **Files to Delete:**
> - All files in `scripts/networks/` (`networks.lua`, `networks-store.lua`, `networks-graph.lua`, `networks-flow.lua`, `networks-pressure.lua`, `flow-cull.lua`, `network-validate.lua`, `network-invalidate.lua`, `network-form-internals.lua`, `network-join.lua`, `network-merge.lua`, `network-unjoin.lua`, `network-unmerge.lua`, `network-rebuild-engine.lua`, `network-connect.lua`, `network-disconnect.lua`, `network-rotate.lua`).
> - All files in `scripts/ports/` (`port-definitions.lua`, `port-evaluator.lua`, `port-finder.lua`, `port-renderer.lua`, `port-walk.lua`, `port-compatibility-definitions.lua`, `port-connection-definitions.lua`).
> - Obsolete capsule motion script `scripts/capsules/capsule-motion.lua`.
> 
> **Storage Cleanup (`control.lua`):**
> - In `script.on_configuration_changed`, add a nil-clearing block for legacy v1 storage tables to free save game memory:
>   ```lua
>   storage.networks = nil
>   storage.port_connections = nil
>   storage.port_pressures = nil
>   storage.network_rebuild_queue = nil
>   storage.port_to_network = nil
>   ```
> - **Constraint:** Ensure all `require` statements remain strictly at the top level of each script.

---

### Stage 4: Consolidate v2 Runner & Final Architecture Verification

**Task Description for Gemini Instance:**
> **Goal:** Consolidate the v2 motion runner into `scripts/capsules/capsule-runner.lua`, remove redundant `scripts/flow/` folder layers, and verify the final module dependency graph.
> 
> **Files to Modify:**
> 1. `scripts/flow/capsule-runner.lua` $\rightarrow$ Move contents directly into `scripts/capsules/capsule-runner.lua`.
> 2. `control.lua`, `scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`, `scripts/diverter-manager.lua`, `scripts/pump-manager.lua`.
> 
> **Specific Instructions:**
> - Move the full implementation of `scripts/flow/capsule-runner.lua` directly into `scripts/capsules/capsule-runner.lua`.
> - Remove `scripts/flow/capsule-runner.lua`.
> - Update `control.lua` to require `scripts.capsules.capsule-runner` directly.
> - Verify that all `require` statements across the entire mod remain at the top level of their respective files.
> - Ensure no unused imports or missing global dependencies remain.