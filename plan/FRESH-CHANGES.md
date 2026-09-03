### Revision: Centralized Proxy Linkage Engine (Stage 1 Refactor)
**Date:** 2026-09-03 12:10 (EDT)
**Context:** Modularize proxy entity lifecycle management, orientation sync, spatial destruction, space platform building, and GUI opening handlers to eliminate duplicated prototype event listeners.
**Key Changes:**
1. **Centralized Proxy Engine (`scripts/proxy-manager.lua`):** Created a registry-based engine (`proxy_manager.register_pair`) that centrally listens to build, destruction, rotation, flip, cloning, and GUI opening events, managing hidden circuit proxies dynamically.
2. **Device Registration (`scripts/proxy-manager.lua`):** Registered default circuit proxy specifications for `pneumatic-pump` and `pneumatic-diverter`, delegating GUI opening directly to `pump_gui.open` and `diverter_gui.open`.
3. **Control Entry Point Cleanup (`control.lua`):** Deprecated individual linkage script imports (`pneumatic-diverter-proxy-linkage.lua` and `pneumatic-pump-proxy-linkage.lua`) and initialized the central engine via `proxy_manager.register_events()`.


### Revision: Unified Active Device Scanner Engine (Stage 2 Refactor)
**Date:** 2026-09-03 12:26 (EDT)
**Context:** Consolidate background 15-tick power and circuit scanning for active machines into a unified registry-based scanner engine (`scripts/active-device-scanner.lua`), eliminating duplicate event loops and state evaluation code across individual machine managers.
**Key Changes:**
1. **Centralized Active Device Scanner (`scripts/active-device-scanner.lua`):** Created a unified 15-tick background scanner supporting extensible device specification registration (`register_device_type`). Handles entity lifecycle hooks (build, destroy, rotate, flip, space platform, cloned) and exposes a centralized `notify_settings_changed(entity)` notification API.
2. **Pump & Diverter Specifications (`scripts/active-device-scanner.lua`):** Registered default device state evaluators for `pneumatic-pump` and `pneumatic-diverter` to monitor power and circuit enable states, clear compiled filter caches, enqueue unit ports into `flow_engine`, and wake parked capsules.
3. **Control Entry Point & Manager Deprecation (`control.lua`, `scripts/pump-manager.lua`, `scripts/diverter-manager.lua`):** Replaced individual `pump-manager` and `diverter-manager` imports in `control.lua` with `active_device_scanner.register_events()`. Replaced legacy manager scripts with lightweight backward-compatible stubs that forward GUI notifications directly to `active_device_scanner`.
4. **GUI Callback Integration (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`):** Updated Pump and Diverter configuration GUIs to trigger immediate state re-evaluations and queue wakeups via `active_device_scanner.notify_settings_changed(entity)`.


### Revision: Reusable GUI Component Builder (Stage 3 Refactor)
**Date:** 2026-09-03 12:32 (EDT)
**Context:** Standardize Lua GUI creation, relative/screen window anchoring, title headers, circuit condition panels, item filter slots, and mode switches into a declarative Factorio 2.1 UI widget library (`scripts/utils/gui-components.lua`) to eliminate duplicate layout boilerplate across device configuration interfaces.
**Key Changes:**
1. **Reusable Widget Builder Library (`scripts/utils/gui-components.lua`):** Created a centralized component module exporting UI construction functions (`create_relative_window`, `add_header`, `add_card_frame`, `add_wire_channel_toggles`, `add_circuit_condition_panel`, `add_filter_slot`, `add_labeled_switch`).
2. **Standardized Comparators & Formatting (`scripts/utils/gui-components.lua`):** Exported canonical comparator lists (`=`, `≥`, `≤`, `>`, `<`, `≠`), index lookup helpers, active/inactive color constants (`COLOR_ACTIVE`, `COLOR_INACTIVE`), and label state update helpers (`format_active_label`, `update_switch_labels`).
3. **Condition State Serialization (`scripts/utils/gui-components.lua`):** Implemented utility functions (`parse_condition`, `update_condition_signal`, `update_condition_comparator`, `update_condition_constant`) to serialize and mutate circuit condition state structures cleanly.


### Revision: Standardized Device GUI Refactoring (Stage 4 Refactor)
**Date:** 2026-09-03 12:38 (EDT)
**Context:** Refactor Pneumatic Pump and Diverter configuration interfaces to consume the centralized UI widget library (`scripts/utils/gui-components.lua`), standardizing element layout construction, event routing, and settings synchronization across active devices.
**Key Changes:**
1. **Pneumatic Pump GUI Refactoring (`scripts/pump-gui.lua`):** Streamlined interface construction using declarative `gui_components` helpers (`create_relative_window`, `add_header`, `add_wire_channel_toggles`, `add_card_frame`, `add_circuit_condition_panel`), routing configuration edits directly to `active_device_scanner.notify_settings_changed(entity)`.
2. **Pneumatic Diverter GUI Refactoring (`scripts/diverter-gui.lua`):** Standardized titlebar headers, wire channel switches, circuit condition panels, directional mode switches (`add_labeled_switch`), and 5-slot item filter selectors (`add_filter_slot`) using `gui_components` helpers while preserving the 2x2 directional port card layout.
3. **Unified Notification Routing (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`):** Updated all GUI event listeners (checkbox, dropdown, textfield, element selection, switch toggle) to trigger immediate port state re-evaluations and wake parked capsules via `active_device_scanner`.


### Revision: Factorio 2.1 Read-Only Proxy Minable Fix
**Date:** 2026-09-03 13:00 (EDT)
**Context:** Resolve runtime crash (`LuaEntity::minable is read only`) occurring during entity build events when initializing hidden circuit proxies for pneumatic pumps and diverters.
**Key Changes:**
1. **Runtime Property Assignment Fix (`scripts/proxy-manager.lua`):** Removed `proxy.minable = false` property assignment in `on_created`. In Factorio 2.0+, `LuaEntity.minable` is read-only at runtime; proxy unminability is governed at the prototype stage via flags (`"not-minable"`).


### Revision: Modular Hub GUI Refactoring (Stage 5 Refactor)
**Date:** 2026-09-03 14:15 (EDT)
**Context:** Refactor Pneumatic Hub configuration interface (`scripts/hubs/hub-gui.lua`) to consume the centralized UI widget library (`scripts/utils/gui-components.lua`), standardizing relative container window anchoring, wire channel toggles, and circuit condition selectors across active devices.
**Key Changes:**
1. **Container Window Support & Panel Flexibility (`scripts/utils/gui-components.lua`):** Updated `create_relative_window` to assign window titles on relative container frames and made `add_circuit_condition_panel` checkbox parameters optional for compound enable/circuit layout rows.
2. **Declarative Hub GUI Refactoring (`scripts/hubs/hub-gui.lua`):** Streamlined Hub interface construction using `gui_components` helpers (`create_relative_window`, `add_wire_channel_toggles`, `add_card_frame`, `add_circuit_condition_panel`), replacing local operator tables with canonical comparator helpers (`gui_components.COMPARATORS`).
3. **Unified Event Routing & State Mutation (`scripts/hubs/hub-gui.lua`):** Refactored event listeners across checkboxes, signal choosers, operator dropdowns, and constant textfields to mutate settings via `gui_components` helpers while preserving mutual exclusivity rules and triggering immediate wakeups via `hub_manager.notify_settings_changed(entity)`.