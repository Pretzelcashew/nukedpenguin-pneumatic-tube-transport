Here is the master refactoring plan. It is structured into **4 sequential, self-contained stages**. 

When assigning work, paste this **entire document** into the target Gemini instance, then add a final directive at the end: 
> *"You are the Actioner AI. Read the entire master plan for context, but execute **ONLY STAGE X**. Provide the complete, drop-in Lua code for all files created or modified in this stage."*

---

# MASTER REFACTORING PLAN: Modular Device Architecture
**Mod:** `nukedpenguin-pneumatic-tube-transport` (Factorio 2.1)  
**Goal:** Modularize proxy linkages, background device management, and Lua GUI creation to drastically lower friction when adding new active devices (pumps, diverters, valves, sensors, boosters).

---

## Architecture Overview & Dependency Pipeline

```
  STAGE 1: Proxy Lifecycle Engine
  [Create scripts/proxy-manager.lua]
  (Replaces duplicate proxy linkage event listeners)
              │
              ▼
  STAGE 2: Unified Active Device Scanner
  [Create scripts/active-device-scanner.lua]
  (Replaces pump-manager.lua & diverter-manager.lua 15t loops)
              │
              ▼
  STAGE 3: Reusable GUI Widget Library
  [Create scripts/utils/gui-components.lua]
  (Adds declarative GUI builders for headers, circuit panels, filters)
              │
              ▼
  STAGE 4: Device GUI Refactoring & Blueprint Sync
  [Refactor pump-gui.lua, diverter-gui.lua; Update ARCHITECTURE.md]
  (Connects GUIs to Component Builder and updates blueprint documentation)
```

---

## STAGE 1: Centralized Proxy Linkage Engine

### Objective
Eliminate duplicated event code for proxy entities (Space platform events, build, mine, destroy, rotate, flip, clone, and GUI deferrals) by creating a data-driven `proxy-manager.lua`.

### Files Involved
* **Create:** `scripts/proxy-manager.lua`
* **Delete / Deprecate:** `prototypes/pneumatic-diverter-proxy-linkage.lua`, `prototypes/pneumatic-pump-proxy-linkage.lua`
* **Modify:** `control.lua` (require `proxy-manager.lua` instead of individual linkage files)

### Instructions for Actioner AI
1. **Create `scripts/proxy-manager.lua`**:
   * Implement a registry table `proxy_manager.register_pair(spec)`.
   * The specification must accept:
     * `main_entity_name` (string)
     * `proxy_entity_name` (string)
     * `on_open_gui` (function `(player, main_entity)`)
   * Centrally listen to the following events via `scripts/events.lua`:
     * `on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `on_space_platform_built_entity`, `on_entity_cloned`
     * `on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`, `on_space_platform_mined_entity`
     * `on_player_rotated`, `on_player_flipped`
     * `on_gui_opened` (When player opens `proxy_entity_name`, close proxy GUI and invoke `on_open_gui(player, main_entity)`).
2. **Handle Proxy Creation & Cleanup**:
   * On build/clone: Spawn `proxy_entity_name` matching `main_entity` position, surface, force, and direction. Vector-offset proxy to center if needed. Set proxy `destructible = false`, `minable = false`. Store association if needed or query spatial overlapping.
   * On mine/destroy: Automatically destroy attached proxy entity.
   * On rotate/flip: Sync proxy direction with main entity.
3. **Register Existing Entities**:
   * Register `pneumatic-pump` $\rightarrow$ `pneumatic-pump-circuit-proxy` (opening `pump_gui.open`).
   * Register `pneumatic-diverter` $\rightarrow$ `pneumatic-diverter-circuit-proxy` (opening `diverter_gui.open`).
4. **Update `control.lua`**:
   * Remove references to `prototypes/pneumatic-diverter-proxy-linkage.lua` and `prototypes/pneumatic-pump-proxy-linkage.lua`.
   * Require `scripts/proxy-manager.lua` and call `proxy_manager.register_events()`.

### Acceptance Criteria
* Placing, rotating, mining, or destroying a Pump or Diverter cleanly creates and cleans up its hidden circuit proxy without errors.
* Opening a Pump or Diverter opens its custom GUI.
* `pneumatic-diverter-proxy-linkage.lua` and `pneumatic-pump-proxy-linkage.lua` are completely removed.

---

## STAGE 2: Unified Active Device Scanner

### Objective
Consolidate background 15-tick power/circuit scanning for active machines into a single registry-based `active-device-scanner.lua`, replacing `pump-manager.lua` and `diverter-manager.lua`.

### Files Involved
* **Create:** `scripts/active-device-scanner.lua`
* **Delete / Deprecate:** `scripts/pump-manager.lua`, `scripts/diverter-manager.lua`
* **Modify:** `control.lua`, `scripts/diverter-gui.lua`, `scripts/pump-gui.lua`

### Instructions for Actioner AI
1. **Create `scripts/active-device-scanner.lua`**:
   * Create a centralized scanner running on `on_tick` (15-tick modulo offset).
   * Implement a device registration interface:
     ```lua
     active_device_scanner.register_device_type({
         storage_key = "active_pumps", -- or function returning active table
         check_state = function(unit_number, entity) ... end,
         on_settings_changed = function(entity) ... end
     })
     ```
2. **Unified State Evaluation Engine**:
   * Implement standard state evaluation logic:
     * Check if entity is valid. If invalid, purge from active storage.
     * Evaluate energy state (`entity.energy > 0`).
     * Evaluate circuit condition via settings module (`evaluate_circuit_condition`).
     * If power or enabled state changed, invoke `flow_engine.enqueue_unit_ports(unit_number)` and `capsule_runner.wake_parked_capsules(unit_number)`.
3. **Unified Notification API**:
   * Expose `active_device_scanner.notify_settings_changed(entity)`.
   * Automatically detect entity type, re-evaluate power/circuit states immediately, push port updates to `flow_engine`, and wake parked capsules.
4. **Refactor Call Sites & Control Entry Point**:
   * Update `pump-gui.lua` and `diverter-gui.lua` to call `active_device_scanner.notify_settings_changed(entity)` on GUI edits.
   * Update `control.lua` to load `active-device-scanner.lua` and register `active_pumps` and `active_diverters`. Remove loads for `pump-manager.lua` and `diverter-manager.lua`.

### Acceptance Criteria
* Unpowering or disabling circuit conditions on Pumps or Diverters updates tube flow levels within 15 ticks.
* Editing Pump or Diverter GUI settings immediately triggers port flow updates and wakes parked capsules.
* `pump-manager.lua` and `diverter-manager.lua` are completely removed.

---

## STAGE 3: Reusable GUI Component Builder

### Objective
Create a Factorio 2.1 UI widget library (`gui-components.lua`) that standardizes Lua GUI creation, relative window anchoring, headers, and circuit condition panels.

### Files Involved
* **Create:** `scripts/utils/gui-components.lua`
* **Modify:** None (Library addition only; existing GUIs remain untouched in this stage to guarantee zero regressions).

### Instructions for Actioner AI
1. **Create `scripts/utils/gui-components.lua`**:
   * Build helper functions for common Factorio 2.1 Lua GUI elements using official Factorio GUI styles (`frame`, `flow`, `button`, `sprite-button`, `drop-down`, `choose-elem-button`).
2. **Implement Core Component Builders**:
   * `gui_components.create_relative_window(player, anchor_spec, frame_name, title)`
     * Handles `player.gui.relative.add{...}` with proper `anchor` bindings (`defines.relative_gui_type.container_gui` or proxy entity bindings).
   * `gui_components.add_header(parent_frame, title_text, close_button_name)`
     * Renders standard top bar with title label, drag handle, and close button.
   * `gui_components.add_circuit_condition_panel(parent, config)`
     * Renders standard circuit enable toggle, wire channel switches (Red/Green), standard comparator dropdown (`=`, `>`, `<`, `≥`, `≤`, `≠`), and signal selection slots (`first_signal`, `second_signal` / `constant`).
   * `gui_components.add_filter_slot(parent, config)`
     * Renders standard item selector slot with comparator and filter mode toggles.
3. **Event Helpers & Storage Helpers**:
   * Add utility functions to serialize/deserialize circuit condition GUI states directly to/from `storage` structures.

### Acceptance Criteria
* `scripts/utils/gui-components.lua` exists, loads cleanly without syntax or missing dependency errors, and exports a robust GUI widget API.
* No existing game logic or runtime GUIs are altered yet.

---

## STAGE 4: Device GUI Refactoring & Blueprint Documentation Sync

### Objective
Refactor `pump-gui.lua` and `diverter-gui.lua` to use `gui-components.lua`. Update `ARCHITECTURE.md` to reflect all architectural changes made across Stages 1–4.

### Files Involved
* **Modify:** `scripts/pump-gui.lua`, `scripts/diverter-gui.lua`, `ARCHITECTURE.md`

### Instructions for Actioner AI
1. **Refactor `pump-gui.lua`**:
   * Rewrite GUI creation logic to use `gui_components.create_relative_window`, `gui_components.add_header`, and `gui_components.add_circuit_condition_panel`.
   * Verify event routing triggers `active_device_scanner.notify_settings_changed(entity)`.
2. **Refactor `diverter-gui.lua`**:
   * Rewrite top frame, circuit control panel, and filter slots using `gui-components.lua`.
   * Retain unique 2x2 directional port map layout, but streamline element construction with component helpers.
3. **Update `ARCHITECTURE.md`**:
   * Update **Section 1 (System Architecture Diagram)** to reflect `proxy-manager`, `active-device-scanner`, and `gui-components`.
   * Update **Section 2 (All-Encompassing Module Directory)**:
     * Add `proxy-manager.lua`, `active-device-scanner.lua`, `gui-components.lua`.
     * Remove `pneumatic-diverter-proxy-linkage.lua`, `pneumatic-pump-proxy-linkage.lua`, `diverter-manager.lua`, `pump-manager.lua`.
   * Update **Section 3 (Event Matrix)** and **Section 4 (Storage Schema)** to match modified manager function calls and active scanner references.

### Acceptance Criteria
* Both Pump and Diverter GUIs open, display options correctly, save settings to `storage`, and close properly.
* Code size in `pump-gui.lua` and `diverter-gui.lua` is reduced significantly.
* `ARCHITECTURE.md` perfectly reflects the updated codebase with zero leftover references to deleted files.

---

## Safety & Compatibility Rules for All Actioner AIs
1. **Target Engine Version:** Factorio 2.1 (Space Age). Use `storage` (not legacy `global`).
2. **Event Registration:** Always use `scripts/events.lua` for event listener registration.
3. **Zero Allocation / Performance:** Maintain $O(1)$ lookups and avoid unnecessary table allocations in tick handlers.
4. **Scope Control:** Do NOT modify files or systems outside your assigned stage.