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