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


### Revision: Compact Modal Diverter Filters, Overlay Badges & Strict Quality Engine
**Date:** 2026-09-03 17:07 (EDT)
**Context:** Overhaul the Pneumatic Diverter GUI layout by removing inline dropdown clutter in favor of 40x40 square slot buttons with corner badge overlays, fixing child modal window focus lifecycle, and implementing strict Factorio 2.0 quality tier rank evaluations.
**Key Changes:**
1. **Modal Overlay GUI Builder (`scripts/utils/gui-components.lua`):** Created `create_overlay_slot_button` and `update_overlay_slot_button` to render 40x40 slot buttons with top-left active comparator badges (`=`, `≥`, `≤`, `>`, `<`, `≠`) and bottom-right quality badges. Added `get_item_name_and_quality` to parse both string item names and Factorio 2.0 `item-with-quality` table structures.
2. **Diverter GUI Overhaul & Window Focus Fix (`scripts/diverter-gui.lua`):** Eliminated all 20 inline comparator dropdowns from the main window, replacing filter rows with 5 square slot buttons per port card. Added a `filter_slot_config_frame` modal pop-up for editing filters. Maintained `player.opened` focus on the primary frame so pop-up modals and native item pickers open without triggering `on_gui_closed` window destruction.
3. **Strict Quality Rank Engine (`scripts/capsules/capsule-runner.lua`):** Mapped Factorio 2.0 quality ranks (`Normal` = 1 through `Legendary` = 5) and implemented strict comparator math in `matches_filter_item`. Filter slots set to `Normal` with `=` strictly require Tier 1 `Normal` quality, while `≥` enables threshold filtering (e.g., `≥ Normal` matches Normal and higher). Propagated `payload_quality` through all pathfinding and lookahead checks.
4. **Payload Quality Tracking (`scripts/hubs/hub-packing.lua`, `scripts/capsules/capsule-manager.lua`):** Updated hub cargo packing to record `dominant_cargo_quality` and capsule registration to persist `dominant_quality` in `storage.active_capsules` from the exact tick cargo is packed.


### Revision: Factorio 2.0 Native Quality Filter Engine & UI Control Bar Overhaul
**Date:** 2026-09-03 21:46 (EDT)
**Context:** Overhaul pneumatic diverter filtering to support native Factorio 2.0 quality comparisons, wildcard quality matching, itemless quality filtering, and interactive quality selector controls within filter configuration pop-up windows.
**Key Changes:**
1. **Wildcard Quality Sprite Prototype (`data.lua`):** Registered the `pneumatic_any_quality_badge` sprite prototype mapping to core `any-quality.png` for wildcard quality badge rendering.
2. **Quality-Aware Filter Evaluation Engine (`scripts/capsules/capsule-runner.lua`, `scripts/diverter-settings.lua`):** Updated default slot initialization in `diverter_settings` to default to `"Any Quality"` comparators and `"normal"` tiers. Refactored `matches_filter_item` and `evaluates_port_filter` in `capsule_runner` to support quality tier rank comparisons (`normal` through `legendary`), comparator evaluation (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`), and standalone quality filtering when item slots are unassigned.
3. **Quality Control Bar Widget Component (`scripts/utils/gui-components.lua`):** Expanded `gui_components` with `add_quality_control_bar` rendering quality comparator dropdowns, 5-tier quality sprite radio buttons, checkmark confirm buttons, and slot button active selection highlight styles (`flib_selected_slot_button`). Added sprite fallback helpers for quality badges (`get_quality_sprite`).
4. **Diverter GUI Modal Quality Selector Integration (`scripts/diverter-gui.lua`):** Overhauled `filter_slot_config_frame` modal windows to combine item choosers with `add_quality_control_bar`. Added event listeners for quality tier radio buttons and comparator dropdowns, while tracking active slot button highlights during configuration.


### Revision: Quality Filter GUI Scaling, Dropdown Width & Overlay Badge Alignment
**Date:** 2026-09-03 22:15 (EDT)
**Context:** Resolve dropdown clipping, oversized quality icons, and misplaced overlay badges across item filter slots by standardizing texture scaling, dropdown widths, and bottom-left badge alignment in the centralized UI widget library.
**Key Changes:**
1. **Dropdown Width & Rich-Text Sizing (`scripts/utils/gui-components.lua`):** Expanded `quality_comparator_dropdown` width from `54` to `68` in `add_quality_control_bar` to prevent rich text wildcard badge (`[img=pneumatic_any_quality_badge]`) and dropdown selection arrow clipping.
2. **Overlay Badge Texture Scaling (`scripts/utils/gui-components.lua`):** Enabled `stretch_image_to_widget_size = true` on overlay sprite elements in `update_overlay_slot_button`, scaling 64x64 wildcard badges and 32x32 quality tier icons down into clean 12x12 corner overlays.
3. **Bottom-Left Corner Alignment & Padding (`scripts/utils/gui-components.lua`):** Constrained slot button inner layout flows to `34x34`, set `horizontal_align = "left"`, and applied baseline label offsets (`top_margin = -3`) to keep comparator operators and quality badges positioned neatly inside the bottom-left corner of the 40x40 slot box.
4. **Encapsulated Quality Selection API (`scripts/utils/gui-components.lua`, `scripts/diverter-gui.lua`):** Added `gui_components.update_quality_tier_selection` to encapsulate radio button active selection styling, fully decoupling quality control bar state updates from machine GUI implementations.


### Revision: Native Quality Comparator Selector Component Refactoring
**Date:** 2026-09-03 22:27 (EDT)
**Context:** Standardize and fully encapsulate native Factorio quality comparator and quality tier selector interaction rules inside the reusable UI widget library, eliminating machine-specific quality state orchestration in diverter GUIs.
**Key Changes:**
1. **Encapsulated Quality Control Bar Engine (`scripts/utils/gui-components.lua`):** Updated `add_quality_control_bar` to keep quality tier radio buttons unselected/grayed-out when initialized in `"Any Quality"` mode. Added `update_quality_control_bar`, `handle_quality_tier_click`, and `handle_quality_comparator_change` to manage control bar state transitions, dropdown synchronization, and button highlight styles centrally.
2. **Native Quality Selector Rules (`scripts/utils/gui-components.lua`):** Implemented native Factorio quality selector behavior: selecting `"Any Quality"` on the dropdown grays out/unselects all quality tier selection buttons; clicking any quality tier radio button while on `"Any Quality"` automatically converts the comparator mode to `=` and selects the clicked tier.
3. **Decoupled Diverter GUI Event Delegation (`scripts/diverter-gui.lua`):** Streamlined quality dropdown (`on_gui_selection_state_changed`) and quality tier click (`on_gui_click`) event listeners to delegate state transitions directly to `gui_components.handle_quality_comparator_change` and `gui_components.handle_quality_tier_click`.


### Revision: Encapsulated Reusable Filter Slot Component, Right-Click Clearing & Native Quality Rules
**Date:** 2026-09-03 23:16 (EDT)
**Context:** Encapsulate item filter slot lifecycle interactions, right-click filter clearing, native Factorio quality default rules, explicit quality preservation, "Any Quality" memory resetting, and high-contrast overlay badge formatting directly inside the reusable UI widget library (`scripts/utils/gui-components.lua`).
**Key Changes:**
1. **Reusable Right-Click Filter Clearing (`scripts/utils/gui-components.lua`, `scripts/diverter-gui.lua`):** Configured `mouse_button_filter = { "left", "right" }` on overlay slot buttons and created `gui_components.clear_filter_slot` and `gui_components.handle_overlay_slot_click` to reset slots back to unassigned default states on right-click.
2. **Explicit Quality Tracking & Native Default Engine (`scripts/utils/gui-components.lua`, `scripts/diverter-gui.lua`, `diverter-settings.lua`):** Created `gui_components.handle_filter_item_change` backed by an `explicit_quality` state flag. Selecting an item on an unconfigured slot defaults to `=` comparator and `normal` quality, while deliberate quality choices (dropdown or quality tier selections) are strictly preserved across item swaps and GUI reopens. Selecting "Any Quality" clears specific quality tier memory back to `normal` and clears the explicit quality flag so subsequent comparator switches or item choices re-trigger native `=` + `normal` quality defaults.
3. **Native Overlay Symbol Omission & White Text Contrast (`scripts/utils/gui-components.lua`):** Updated `update_overlay_slot_button` to omit the `=` comparator symbol on item slot overlays to mirror native Factorio filter UI conventions. Added `COLOR_WHITE` and `gui_components.format_white_label` to render non-equal comparator badges (`>`, `<`, `≥`, `≤`, `≠`) in high-contrast white text over item icons.


### Revision: Diverter GUI Directional Arrow Indicators & Color Constants
**Date:** 2026-09-04 08:00 (EDT)
**Context:** Enhance Diverter configuration interface usability by introducing blue directional triangle arrows alongside cardinal direction labels across port card headers and filter configuration modal windows for at-a-glance spatial orientation.
**Key Changes:**
1. **Centralized UI Color Constants (`scripts/utils/gui-components.lua`):** Exported `COLOR_BLUE` (`"[color=100,200,255]"`) in the reusable UI widget library to standardize blue rich-text formatting across device configuration interfaces.
2. **Diverter Port Direction Indicators (`scripts/diverter-gui.lua`):** Updated `PORT_DIRECTIONS` mapping to pair cardinal direction labels (`North`, `East`, `South`, `West`) with vibrant blue directional arrows (`▲`, `▶`, `▼`, `◀`), rendering clear spatial indicators on 2x2 port card headers and filter slot configuration modal titlebars.


### Revision: Reusable Spatial Arrow Selector Widget Component
**Date:** 2026-09-04 08:15 (EDT)
**Context:** Introduce a modular 3x3 spatial `+` shape arrow selector widget component to the UI widget library (`scripts/utils/gui-components.lua`) to support directional device layout configuration interfaces with flexible part subscription.
**Key Changes:**
1. **Spatial Arrow Selector Builder (`scripts/utils/gui-components.lua`):** Implemented `gui_components.add_spatial_arrow_selector` rendering a 3x3 table grid with North (▲), West (◀), Center, East (▶), and South (▼) button positions aligned around empty spacer cells.
2. **Flexible Part Subscription & Styling (`scripts/utils/gui-components.lua`):** Configured flexible part specifications supporting selective enabling/disabling of individual directions, custom button sizes, custom captions/sprites/tooltips, style overrides, selection highlights (`flib_selected_slot_button`), and tag merging.
3. **Dynamic Widget Button Updates (`scripts/utils/gui-components.lua`):** Added `gui_components.update_spatial_arrow_button` to dynamically update captions, sprites, tooltips, interaction states, and active selection highlights on existing spatial selector buttons.


### Revision: Directional Spatial Arrow Selector & Default Single-Port Diverter GUI
**Date:** 2026-09-04 08:30 (EDT)
**Context:** Overhaul Pneumatic Diverter GUI layout to incorporate the 3x3 spatial arrow selector widget alongside port configuration cards, enabling single-direction filtering to declutter the interface, center-button resetting to all 4 ports, and defaulting to North view upon window initialization.
**Key Changes:**
1. **Spatial Arrow Selector Integration (`scripts/diverter-gui.lua`):** Embedded a left-hand directional view card inside `render_content_layout` using `gui_components.add_spatial_arrow_selector`, mapping North (▲, Port 1), East (▶, Port 2), South (▼, Port 3), West (◀, Port 4), and Center ("All") selector buttons with active highlight styling.
2. **Default North Direction View (`scripts/diverter-gui.lua`):** Configured `diverter_gui.open` to default `initial_view` to Port 1 (North), presenting a single clean port configuration card when opening the interface to eliminate multi-card cognitive overload.
3. **Dynamic Port Container Rendering (`scripts/diverter-gui.lua`):** Refactored `render_content_layout` to dynamically switch between a single card layout (`column_count = 1`) for individual cardinal directions and a 2x2 grid (`column_count = 2`) when viewing all direction ports simultaneously.
4. **View Switching Event Delegation (`scripts/diverter-gui.lua`):** Added `view_port` tag event routing inside `on_gui_click` to handle direction view toggling while cleanly dismissing open modal filter slot configuration windows before re-rendering the layout.


### Revision: Circuit Condition Dropdown Width Expansion
**Date:** 2026-09-04 08:57 (EDT)
**Context:** Resolve operator symbol clipping and selection arrow truncation inside circuit condition dropdown widgets across device configuration interfaces by expanding the default dropdown width in the UI component builder library.
**Key Changes:**
1. **Circuit Condition Panel Dropdown Width (`scripts/utils/gui-components.lua`):** Increased `comparator_width` default fallback from `40` to `55` pixels in `gui_components.add_circuit_condition_panel`, ensuring ample padding for all comparator symbols (`=`, `≥`, `≤`, `>`, `<`, `≠`) and dropdown arrows across Pneumatic Pump, Diverter, and Hub GUIs.


### Revision: Reusable Device Settings Copy-Paste Engine & Custom Input Integration
**Date:** 2026-09-04 09:42 (EDT)
**Context:** Enable copying and pasting device configuration settings across Pneumatic Pumps, Diverters, and Hubs using native Factorio copy/paste controls (Shift + Right-Click / Left-Click), bypassing C++ engine restrictions on non-container prototypes.
**Key Changes:**
1. **Custom Input Control Bindings (`prototypes/custom-input.lua`):** Registered `pneumatic-copy-settings` and `pneumatic-paste-settings` custom inputs linked directly to native `copy-entity-settings` and `paste-entity-settings` controls to reliably capture copy/paste intent on `electric-energy-interface` prototypes.
2. **Prototype Pastable Entity Registration (`prototypes/entity.lua`, `prototypes/pneumatic-diverter.lua`):** Configured `additional_pastable_entities` across `pneumatic-pump`, `pneumatic-diverter`, and `capsule-hub` prototypes to enable native cursor selection.
3. **Centralized Settings Copier Engine (`scripts/device-settings-copier.lua`, `control.lua`):** Created `device-settings-copier.lua` listening to custom input and native `on_entity_settings_pasted` events. Copies settings between matching device types, notifies `active_device_scanner` or `hub_manager` for immediate state/flow re-evaluation, and refreshes open destination GUIs.
4. **Deep-Copy Settings Persistence Helpers (`scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Added `.copy()` helpers backed by `util.table.deepcopy` to duplicate configuration data cleanly in `storage`, clearing compiled filter caches on destination diverter entities.


### Revision: Blueprint Settings Serialization, Metadata Tags & Lifecycle Restoration
**Date:** 2026-09-04 10:36 (EDT)
**Context:** Enable full blueprint and copy-paste metadata support across Pneumatic Pumps, Diverters, and Hubs, serializing circuit enable conditions, wire toggles, directional port modes, whitelist/blacklist filter modes, and quality rules into blueprint entity tags upon setup, and restoring settings during build and clone events.
**Key Changes:**
1. **Blueprint Tag Serialization (`scripts/device-settings-copier.lua`):** Subscribed to `defines.events.on_player_setup_blueprint`, safely unwrapping `event.mapping` via `.get()` (`LuaCustomTable` userdata) and serializing deep-copied machine settings into blueprint stacks/records (`event.stack` / `event.record`) using `set_blueprint_entity_tag`, while stripping transient runtime caches (`_compiled`).
2. **Deserialization API (`scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Added `apply_blueprint_settings(unit_number, blueprint_settings)` across device settings modules to safely deserialize blueprint tag metadata into persistent `storage` state.
3. **Build & Clone Lifecycle Integration (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Expanded build event handlers (`on_built_entity`, `on_robot_built_entity`, `script_raised_built`, `script_raised_revive`, `on_space_platform_built_entity`, `on_entity_cloned`) to apply `event.tags.pneumatic_settings` or copy from `event.source` prior to default initialization, immediately enqueuing unit ports into `flow_engine` and waking parked capsules.


### Revision: Blueprint Proxy Wire Serialization & Ghost Wire Linking Engine
**Date:** 2026-09-04 13:16 (EDT)
**Context:** Implement full circuit wire serialization and ghost-level wire reconstruction across pneumatic pumps, diverters, and connected circuit networks in blueprints using Factorio 2.0 invariant blueprint entity indices and `LuaWireConnector` APIs.
**Key Changes:**
1. **Blueprint Proxy Wire Serialization (`scripts/device-settings-copier.lua`):** Subscribed to `on_player_setup_blueprint` using `LuaEntity.get_wire_connectors(false)` to iterate over circuit proxy connectors. Serializes target entity wire connector IDs and invariant blueprint indices (`bp_index`) into `pneumatic_settings.wire_connections` and `pneumatic_bp_index` tags, ensuring 100% rotation and flip immunity without spatial coordinate offsets.
2. **Ghost Entity Proxy Spawning (`scripts/proxy-manager.lua`):** Updated `proxy_manager` event listeners (`on_created`, `on_removed`, `on_rotated`) to inspect `entity.ghost_name` when `entity.name == "entity-ghost"`. Spawns hidden circuit proxies at ghost entity coordinates as soon as a blueprint is stamped on the map.
3. **Deferred Ghost & Entity Wire Reconstruction (`scripts/device-settings-copier.lua`):** Implemented `process_entity_built_wire_tags` and hooked build/revive/clone event handlers. Automatically resolves wire targets between ghosts or built entities via `storage.bp_wire_cache` and `storage.pending_bp_wires`, connecting wire connectors immediately upon placement via `LuaWireConnector.connect_to()`.