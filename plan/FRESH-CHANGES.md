### Revision: Pneumatic Diverter GUI, Settings Storage & Control Integration
**Date:** 2026-08-28 10:10 (EDT)
**Context:** Add initial implementation for Pneumatic Diverter port configuration by creating dedicated settings management, a 2x2 grid UI with vanilla-style switch labeling and item filter selection, and requiring both new modules in `control.lua`.
**Key Changes:**
1. **Diverter State Persistence (`scripts/diverter-settings.lua`):** Added new module creating unit-indexed `storage.diverter_settings` to track per-port enabled states, flow modes (`input`/`output`), filter toggles, filter modes (`whitelist`/`blacklist`), and 5 item filter slots per directional port (North, East, South, West).
2. **Configuration GUI & Switch Formatting (`scripts/diverter-gui.lua`):** Created new overlay frame featuring a 2x2 grid of port control cards. Implemented vanilla-styled toggle switches with rich-text active color highlighting (`Pull (Input)` vs `Push (Output)` and `Whitelist` vs `Blacklist`), dynamic caption state updates on toggle, and 5 item picker buttons (`elem_type = "item"`) paired with micro-comparator dropdowns (`=`, `≥`, `≤`, `>`, `<`, `≠`).
3. **Control Integration (`control.lua`):** Updated main script to `require` both `scripts/diverter-settings` and `scripts/diverter-gui` modules, wiring diverter settings management and GUI lifecycle event handlers into the mod runtime.


### Revision: Pneumatic Diverter Baseline Manager & Static Port Definitions
**Date:** 2026-08-28 11:23 (EDT)
**Context:** Lay the groundwork for dynamic diverter settings integration by creating a dedicated runtime diverter manager and establishing static 4-port pump-style baseline definitions to test network isolation and power sensitivity.
**Key Changes:**
1. **Diverter Runtime State Tracking (`scripts/networks/diverter-manager.lua`):** Created a dedicated manager module monitoring active diverter entity power states (`storage.active_diverters` and `storage.diverter_power_states`) via a 15-tick periodic scanner. Added `notify_settings_changed` API to trigger targeted flow map rebuilds (`networks_flow.build`) when runtime settings update.
2. **Main Script Wiring & Storage Initialization (`control.lua`):** Added top-level require for `scripts/networks/diverter-manager` and initialized `storage.active_diverters` and `storage.diverter_power_states` inside `setup_storage()`.
3. **Baseline Diverter Port Definitions (`scripts/ports/port-definitions.lua`):** Updated `pneumatic-diverter` port definitions across all cardinal orientations to use `join` connection types with static baseline pressure levels (-100 for inflows, +100 for outflows), enabling 4-way pressure boundary isolation and power reactivity testing.


### Revision: Diverter GUI Persistence & Immediate Network Flow Rebuild Integration
**Date:** 2026-08-28 11:40 (EDT)
**Context:** Connect diverter GUI control elements directly to persistent runtime storage (`storage.diverter_settings`) and trigger instant network flow map recalculations whenever port states, flow directions, or filter settings are modified.
**Key Changes:**
1. **Settings Schema Alignment (`scripts/diverter-settings.lua`):** Standardized default filter slot structure keys to `item` (matching the `choose-elem-button` item element picker format).
2. **UI State Persistence (`scripts/diverter-gui.lua`):** Connected all GUI interaction listeners (`on_gui_checked_state_changed`, `on_gui_switch_state_changed`, `on_gui_elem_changed`, and `on_gui_selection_state_changed`) to update persistent port state configurations in `storage.diverter_settings`.
3. **Runtime Network Rebuild Trigger (`scripts/diverter-gui.lua`):** Added `notify_change()` helper to GUI event callbacks to invoke `diverter_manager.notify_settings_changed(entity)`. This immediately triggers `networks_flow.build(net_id)` for all connected pipe networks to update directional flow vectors upon UI configuration changes.