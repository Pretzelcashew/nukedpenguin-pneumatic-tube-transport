### Revision: Refined Tech Tree Progression, Ingredient-Tech Prerequisite Mapping & Recipe Overhaul
**Date:** 2026-09-03 09:31 (EDT)
**Context:** Align item recipes and technology unlocks with refined progression specifications (`TECH-TREE-REFINED.md` and `RECIPES-REFINED.md`), enforce explicit technology prerequisites for all gated recipe ingredients, and update recipe syntax for Factorio 2.1 compatibility.
**Key Changes:**
1. **Recipe Cost Overhaul & Recharge Mechanics (`prototypes/recipe.lua`):**
   - Rebalanced crafting ingredient requirements across all infrastructure items, junctions, hubs, diverters, and capsule variants to match refined target recipes.
   - Added the `recharge-refrigerated-capsule` recipe allowing players to restore `spent-refrigerated-capsule` items using 125 units of cold fluoroketone while producing 100 units of hot fluoroketone as a byproduct.
   - Updated recipe definitions to Factorio 2.1 specifications by replacing deprecated single `category` string fields with `categories = { "category-name" }` array tables.
2. **Tiered Technology Progression Restructuring (`prototypes/technology.lua`):**
   - Distributed unlocks into distinct science and planet progression tiers: Red/Green science (`pneumatic-transport`), Blue science (`specialized-pneumatic-capsules`), Gleba (`biodegradable-capsule`), Vulcanus (`reinforced-capsule`), and Aquilo (`refrigerated-capsule`).
   - Re-linked `bio-capsule-integrity-1` through `4` upgrade research tiers to require the `biodegradable-capsule` technology node as their prerequisite root.
3. **Explicit Ingredient Technology Prerequisite Mapping (`prototypes/technology.lua`):**
   - Audited all 13 recipe ingredient chains and bound exact prerequisite technologies (`engine`, `advanced-circuit`, `low-density-structure`, `carbon-fiber`, `sulfur-processing`, `tungsten-carbide`, `cryogenic-plant`, `lithium-processing`, and `electromagnetic-plant`) into corresponding research nodes to ensure valid technology graph progression and prevent uncraftable recipe unlocks.


### Revision: Stage 1 v1 Engine Removal — Decouple Configuration, Entry Points & Debug
**Date:** 2026-09-03 10:30 (EDT)
**Context:** Execute Stage 1 of the v1 deprecation plan, establishing the v2 flow engine as the sole execution path by removing `FLOW_VERSION` startup gating, v1 imports in `control.lua`, legacy motion calculation code, and obsolete debug overlays.
**Key Changes:**
1. **Startup Setting Purge (`settings.lua`):** Removed `pneumatic-flow-version` startup setting definition, locking execution path strictly to the v2 flow engine.
2. **Unconditional v2 Entry Point Registration (`control.lua`):** Removed legacy v1 module imports (`networks`, `networks-flow`, `port-renderer`, `port-finder`, `network-connect`, `network-disconnect`, `network-rotate`). Updated lifecycle hooks to unconditionally initialize v2 `flow_engine` and `v2_capsule_runner` event listeners and storage structures.
3. **Capsule Runner Facade Alias (`scripts/capsules/capsule-runner.lua`):** Purged over 500 lines of legacy v1 motion calculation loops, pressure queries, and event handlers; converted script into a zero-allocation direct passthrough returning `require("scripts.flow.capsule-runner")`.
4. **Debug Interface & Command Consolidation (`scripts/debug-manager.lua`):** Purged legacy v1 UI checkboxes (`pneumatic_debug_chk_flow`, `pneumatic_debug_chk_ports`) and commands (`/toggle-ports`). Re-mapped `/toggle-flow` and `/pt-toggle-flow` directly to control the v2 Alt Mode flow engine vector overlay.


### Revision: Stage 2 v1 Engine Removal — Decouple Machine Managers & Lifecycle Hooks
**Date:** 2026-09-03 10:40 (EDT)
**Context:** Execute Stage 2 of the v1 deprecation plan by disconnecting legacy network graph rebuilding (`network-rebuild-engine`, `port-definitions`) and `FLOW_VERSION` gating from machine state managers and entity lifecycle event handlers.
**Key Changes:**
1. **Pump & Diverter State Managers (`scripts/networks/pump-manager.lua`, `scripts/networks/diverter-manager.lua`):** Removed top-level requires for `network-rebuild-engine` and `port-definitions`. Simplified `rebuild_pump_networks` and `rebuild_diverter_networks` to unconditionally route machine power and state updates directly to `flow_engine.enqueue_unit_ports` and `capsule_runner.wake_parked_capsules`.
2. **Placement & Removal Hooks (`scripts/networks/network-connect.lua`, `scripts/networks/network-disconnect.lua`):** Removed legacy `network_validate` and `network_invalidate` execution calls on entity placement and destruction. Retained `hub_spill.handle_entity_destruction` in `network-disconnect.lua` to preserve cargo spillage on structure destruction.
3. **Orientation Event Handler (`scripts/networks/network-rotate.lua`):** Purged v1 network invalidation and re-validation calls from `on_player_rotated_entity` and `on_player_flipped_entity` event listeners while preserving proxy linkage settings notifications (`notify_settings_changed`) for pumps and diverters.


### Revision: Stage 3 v1 Engine Removal — Obsolete File Purge, Manager Relocation & Storage Migration
**Date:** 2026-09-03 10:45 (EDT)
**Context:** Execute Stage 3 of the v1 deprecation plan by deleting obsolete v1 network graph, port topology, and legacy motion files, relocating active machine state managers out of `scripts/networks/`, and implementing save-game storage cleanup.
**Key Changes:**
1. **Obsolete File Purge (`scripts/networks/`, `scripts/ports/`, `scripts/capsules/`):** Deleted 25 legacy v1 source files including network graph rebuild engines, port evaluators, flow/pressure calculators, edge handlers, and the obsolete `capsule-motion.lua` script.
2. **Machine Manager Relocation (`scripts/pump-manager.lua`, `scripts/diverter-manager.lua`):** Moved active `pump-manager.lua` and `diverter-manager.lua` scripts out of `scripts/networks/` into `scripts/`. Updated all top-level `require` paths across `control.lua`, `pump-gui.lua`, and `diverter-gui.lua`.
3. **Storage Migration & Save Cleanup (`control.lua`):** Added explicit `nil`-clearing migration logic in `script.on_configuration_changed` for legacy v1 storage tables (`storage.networks`, `storage.port_connections`, `storage.port_pressures`, `storage.network_rebuild_queue`, `storage.port_to_network`) to free save-game memory.


### Revision: Stage 4 v1 Engine Removal — v2 Runner Consolidation & Query Decoupling
**Date:** 2026-09-03 11:00 (EDT)
**Context:** Complete Stage 4 of the v1 engine removal plan by consolidating the v2 capsule runner implementation directly into `scripts/capsules/capsule-runner.lua`, purging obsolete `FLOW_VERSION` gating checks across the v2 suite, decoupling `capsule-queries.lua` from legacy network/port definitions, deleting redundant script layers, and updating top-level entry point bindings.
**Key Changes:**
1. **Runner Implementation Consolidation (`scripts/capsules/capsule-runner.lua`):** Transferred the complete v2 motion runner engine, spatial parked index management, zero-allocation pathfinding scratch buffers, and event handlers into `scripts/capsules/capsule-runner.lua`, and deleted the obsolete `scripts/flow/capsule-runner.lua`.
2. **Occupancy Query & Topology Decoupling (`scripts/capsules/capsule-queries.lua`):** Removed legacy `scripts.networks` and `scripts.ports.port-definitions` imports. Refactored `get_port_group()` and `get_port_descriptor()` to query v2 spatial `storage.flow_nodes` topology directly.
3. **Legacy Flow Version Gating Purge (`scripts/capsules/capsule-runner.lua`, `scripts/flow/flow-engine.lua`):** Purged stale `FLOW_VERSION` gating checks (`FLOW_VERSION ~= "v2"`) across stepper functions, renderers, and event registrations to establish v2 as the sole execution path.
4. **Control Entry Point Alignment (`control.lua`):** Updated top-level imports in `control.lua` to require `scripts.capsules.capsule-runner` directly and register its event listeners alongside `flow_engine.register_events()`.


### Revision: Spillage Restoration, Passenger Safety & Dependency Cycle Resolution
**Date:** 2026-09-03 11:29 (EDT)
**Context:** Restore cargo spillage, passenger disembarkation, and parked traffic wakeups across all pneumatic network structures upon entity mining or destruction, while resolving circular `require` dependency loops between runner, lifecycle, flow, and spillage modules.
**Key Changes:**
1. **Leaf Query Unparking & Traffic Wakeups (`scripts/capsules/capsule-queries.lua`):** Expanded `capsule_queries.remove_capsule` to unpark capsules from `storage.parked_by_port`, clear visual debug renders, unregister occupancy tracking, and wake upstream parked capsules waiting at the freed port key.
2. **Acyclic Removal Event Dispatching (`scripts/hubs/hub-spill.lua`):** Registered entity removal event listeners (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`, `on_space_platform_mined_entity`) directly inside `hub-spill.lua`. Purged the top-level `capsule-runner` import to break the `capsule-runner` → `capsule-lifecycle` → `hub-spill` → `capsule-runner` module load recursion loop.
3. **Flow Engine & Hub Manager Decoupling (`scripts/flow/flow-engine.lua` & `scripts/hubs/hub-manager.lua`):** Removed top-level `hub-spill` imports from `flow-engine.lua`, allowing `flow-engine.disconnect_entity` to manage spatial flow topology while `hub-spill` independently handles entity destruction spillage. Streamlined `hub-manager.lua` to avoid duplicate spillage execution passes.


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


### Revision: Native Proxy Blueprint Wire Previews, Wire Operability & Spatial Z-Indexing
**Date:** 2026-09-04 16:34 (EDT)
**Context:** Enable native blueprint wire previews, interactive wire placement/cutting tools, and spatial Z-index layering for proxy-based entities (`pneumatic-pump` and `pneumatic-diverter`), resolving C++ blueprint validation errors, wire property tree schema mismatches, and post-placement selection layering.
**Key Changes:**
1. **Proxy Prototype Blueprintability & Operability (`prototypes/pneumatic-pump-proxy.lua`, `prototypes/pneumatic-diverter.lua`):** Added `"player-creation"` flag, assigned `placeable_by` to main machine items with `count = 0`, and elevated `selection_priority` to `60` (higher than main machine priority `50`). Satisfies C++ `is_blueprintable` validation while ensuring circuit terminals take selection precedence for Red/Green wire items and Wire Cutters.
2. **Atomic Blueprint Wire Serialization & 4-Tuple Schema Alignment (`scripts/device-settings-copier.lua`):** Overhauled `on_player_setup_blueprint` to dynamically inject proxy entity records into `blueprint.get_blueprint_entities()` and serialize wire connections using Factorio 2.0 4-element connection tuples (`{ src_conn_id, src_conn_id, target_bp_index, tgt_conn_id }`), resolving C++ property tree schema parsing errors (`ROOT[0].wires[1]`) and committing entities, positions, tags, and wires atomically.
3. **Runtime Operability & Spatial Selection Re-Indexing (`scripts/proxy-manager.lua`):** Preserved `proxy.operable = true` so wire tools can connect/disconnect signals, and integrated `proxy.teleport(pos)` inside `on_created` and `on_rotated` build handlers to re-insert the proxy at the top of Factorio's spatial selection stack above newly placed ghosts and built machines.


### Revision: Blueprint Proxy Wire Merging, Orphan Auto-Destruction & Surface Purge Engine
**Date:** 2026-09-04 17:10 (EDT)
**Context:** Eliminate orphaned proxy entities and ghost proxies during blueprint placement over removed devices, right-click ghost cancellations, or partial builds, while implementing additive wire merging to preserve pre-existing and blueprint wire connections on active devices.
**Key Changes:**
1. **Additive Proxy Wire Merging (`scripts/proxy-manager.lua`):** Implemented `transfer_wire_connections` to iterate over source proxy/ghost `LuaWireConnector` ports and copy wire connections onto surviving real proxies via `connect_to()` prior to source entity destruction, preventing wire severing when stamping blueprints over existing machines.
2. **Orphan Proxy & Ghost Auto-Destruction (`scripts/proxy-manager.lua`):** Subscribed proxy entity names to `on_created` and `on_removed` lifecycle events. Unanchored proxies or ghost proxies lacking a valid host machine or ghost host at their coordinates are recognized as orphans and destroyed immediately (`entity.destroy()`).
3. **Multi-Proxy Deduplication & Direction Sync (`scripts/proxy-manager.lua`):** Updated `on_created` to transfer wires from extra duplicate real/ghost proxies onto the primary real proxy (`existing[1]`) before pruning duplicates, enforcing strictly one real proxy per machine with synced direction and selection stack order.
4. **Bidirectional Deconstruction Clean-up (`scripts/proxy-manager.lua`):** Updated `on_removed` to destroy both real proxy entities and ghost proxies when a host machine or host ghost is mined, deconstructed, killed, or script-destroyed.
5. **Surface-Wide Orphan Purge Engine (`scripts/proxy-manager.lua`, `control.lua`):** Added `proxy_manager.purge_orphans()` scanning all surfaces for unanchored real/ghost proxies, hooking it into `setup_storage()` in `control.lua` to clean up legacy map orphans during `on_init` and `on_configuration_changed`.


### Revision: Blueprint Orphan Proxy Purge & UI Lifecycle Integration
**Date:** 2026-09-04 18:48 (EDT)
**Context:** Automatically sanitize blueprints and blueprint books upon saving, setup, or GUI window teardown, purging orphan circuit proxies left behind when main devices (pumps or diverters) are deleted in the blueprint manager window.
**Key Changes:**
1. **Proxy Specification Registry Export (`scripts/proxy-manager.lua`):** Exposed `proxy_manager.get_registered_proxies()` and `proxy_manager.get_registered_mains()` to allow blueprint utility functions to query registered proxy names and positional offsets dynamically.
2. **Blueprint Event Lifecycle & Handle Resolution (`scripts/device-settings-copier.lua`):** Subscribed to `defines.events.on_player_configured_blueprint` and `defines.events.on_gui_closed`. Implemented `get_blueprints_from_event_and_player` to target active blueprint handles across `event` payloads, `player.cursor_stack`, and `player.opened` frame references.
3. **Orphan Proxy Purging & Re-Indexing Engine (`scripts/device-settings-copier.lua`):** Implemented `clean_blueprint_orphans` to inspect `bp_entities`, identify proxy entities lacking a corresponding main machine within a 0.05 tile radius, purge orphan records, re-index entity numbers (1 to N), and sanitize wire connections and metadata tags.
4. **Type-Safe Object & Blueprint Book Traversal (`scripts/device-settings-copier.lua`):** Implemented `clean_container_or_blueprint` using `bp.object_name` guards to safely differentiate `LuaItemStack` and `LuaRecord` userdata, enabling recursive blueprint book traversal (`defines.inventory.item_main` and `record.contents`) while guarding against C++ `__index` exceptions.


### Revision: Alt-Mode Diverter Port Filter Overlay Renderer
**Date:** 2026-09-04 20:45 (EDT)
**Context:** Implement native-style Alt-Mode visible filter item overlays over Pneumatic Diverter ports, dynamically rendering configured port filters in adaptive 2x2 grids anchored directly to topological port offsets.
**Key Changes:**
1. **Diverter Port Overlay Renderer (`scripts/diverter-renderer.lua`):** Created `diverter_renderer` utilizing Factorio 2.0 `rendering.draw_sprite` APIs. Queries topological port coordinates directly from `port_defs.get_ports(entity)` to display up to 4 filter item icons per port in a clean 2x2 grid (`scale = 0.42`, `offset = 0.22`) with `only_in_alt_mode = true` on `render_layer = "entity-info-icon"`.
2. **Scanner Lifecycle & Settings Integration (`scripts/active-device-scanner.lua`):** Integrated `diverter_renderer.update_render(entity)` triggers into `notify_settings_changed(entity)` and built event handlers (player build, robot build, script raised, revive, space platform, cloned). Added `diverter_renderer.clear_render(unit_number)` cleanup to device unregistration upon entity mining or destruction.
3. **Control Initialization & Storage Sync (`control.lua`):** Required `diverter-renderer` at script top level and hooked an active diverter refresh scan into `setup_storage()`, ensuring filter overlays are automatically restored across world loading (`on_init`) and configuration migrations.


### Revision: Alt-Mode Diverter Filter Overlay Inward Shift & Solid Black Shadow Rendering
**Date:** 2026-09-04 22:39 (EDT)
**Context:** Prevent Alt-Mode diverter port filter item icons from overlapping port flow indicator dots while enhancing icon contrast and readability against machine entity visuals.
**Key Changes:**
1. **Topological Inward Shift (`scripts/diverter-renderer.lua`):** Implemented a directional vector offset calculation (`PORT_INWARD_OFFSET = 0.55`) that shifts port filter overlay clusters inward toward the entity center `(0,0)`, eliminating visual collision with port flow dots.
2. **Pitch-Black Silhouette & Drop Shadow (`scripts/diverter-renderer.lua`):** Added a 1.3x scaled centered outline (`OUTLINE_SCALE_MULTIPLIER = 1.3`) and a 1.3x scaled down-right offset drop shadow (`SHADOW_SCALE_MULTIPLIER = 1.3`, offset `0.04`) rendered with full-opacity black tint (`BLACK_TINT = {r=0, g=0, b=0, a=1.0}`) to form a high-contrast backing frame.
3. **Render Layer Z-Ordering (`scripts/diverter-renderer.lua`):** Structured rendering passes across explicit layers by drawing black outline and shadow elements on `render_layer = "entity-info-icon"` while rendering full-color item icons directly on top via `render_layer = "entity-info-icon-above"`.


### Revision: Diverter Settings Orientation Sync, Directional Copy-Paste & Decoupled Scanner Observer
**Date:** 2026-09-05 09:34 (EDT)
**Context:** Automatically rotate and flip Pneumatic Diverter port settings in sync with physical entity orientation changes, align filter settings when copy-pasting between differently oriented diverters, and eliminate a circular script require loop between active device scanning and GUI controllers.
**Key Changes:**
1. **Modulo Port Rotation & Axis Flipping (`scripts/diverter-settings.lua`):** Implemented `rotate_ports`, `rotate_ports_by_steps`, and `flip_ports` using cardinal index mapping (`North = 1` through `West = 4`) and modulo arithmetic (`(p - 1 + steps) % 4 + 1`) to shift port filter configurations in lockstep with entity rotation (`R`, `Shift+R`) and flipping (`F`, `Shift+F`).
2. **Direction-Aware Copy-Paste Alignment (`scripts/diverter-settings.lua` & `scripts/device-settings-copier.lua`):** Enhanced `diverter_settings.copy` and `device-settings-copier` to track source and destination entity directions, applying relative step rotations when pasting or cloning settings between diverters facing different directions.
3. **Decoupled Scanner Observer & UI Refresh (`scripts/active-device-scanner.lua` & `scripts/diverter-gui.lua`):** Added `active_device_scanner.on_settings_changed` subscriber callback registration to invoke `diverter_gui.refresh_if_open`, breaking a top-level circular `require` dependency loop while guaranteeing live UI frame re-renders when open diverter entities are rotated or modified.


### Revision: Diverter Alt-Mode Filter Overlay Quality Badges, Comparators & Text Alignment Fix
**Date:** 2026-09-05 09:58 (EDT)
**Context:** Achieve visual parity between Diverter Alt-Mode filter overlays and native Factorio 2.0 inserter filter overlays by rendering bottom-left quality badges and non-equal comparator symbols while resolving a rendering API parameter crash.
**Key Changes:**
1. **Bottom-Left Overlay Alignment (`scripts/diverter-renderer.lua`):** Repositioned quality badges and comparator symbols to the bottom-left corner of item filter overlay icons (`cx - scale * 0.28, cy + scale * 0.28`), supporting side-by-side rendering when both a comparator and quality tier are present.
2. **Wildcard & Tier Quality Badge Integration (`scripts/diverter-renderer.lua`):** Integrated `gui_components.get_quality_sprite` to draw the registered wildcard `pneumatic_any_quality_badge` for "Any Quality" filters and native quality tier icons (`quality/uncommon`, `quality/rare`, `quality/epic`, `quality/legendary`) with black outline backings.
3. **Non-Equal Comparator Text Overlay (`scripts/diverter-renderer.lua`):** Added dual-pass high-contrast white text rendering with black drop shadows for non-equal quality comparators (`>`, `<`, `≥`, `≤`, `≠`), omitting the default `=` symbol.
4. **Vertical Text Alignment Crash Fix (`scripts/diverter-renderer.lua`):** Updated `vertical_alignment` parameters in `rendering.draw_text` from invalid `"center"` to `"middle"`, eliminating non-recoverable Factorio C++ engine runtime exceptions.


### Revision: Diverter Alt-Mode Blacklist Filter Overlay & Native Filter Parity
**Date:** 2026-09-05 10:44 (EDT)
**Context:** Resolve 101x101 filter-blacklist sprite cropping and align Alt-Mode diverter filter overlay indicators with native Factorio 2.0 inserter filter conventions.
**Key Changes:**
1. **Blacklist Sprite Prototype Registration (`data.lua`):** Registered `pneumatic_filter_blacklist` sprite prototype using the exact 101x101 frame dimensions (`width = 101`, `height = 101`) for `__core__/graphics/filter-blacklist.png`, eliminating sprite clipping and giant red arc distortion.
2. **Resolution-Aware Scale Adjustment (`scripts/diverter-renderer.lua`):** Added `get_blacklist_sprite` helper with fallback to `utility/filter_blacklist`, adjusting render scale (`0.33` standalone, `scale * 0.41` overlaid) to match 64x64 item icon tile proportions.
3. **Native Inserter Filter Parity (`scripts/diverter-renderer.lua`):** Aligned filter overlay behavior with Factorio 2.0 inserter rules: renders a standalone centered "no" symbol when `use_filters` is enabled on empty whitelist ports (`item_count == 0` - blocking all flow), overlays a single top-right "no" symbol over configured blacklist item clusters (`item_count > 0`), and suppresses overlays on empty blacklist ports.


### Revision: Native Inserter Parity for Diverter Filter Overlays & Standalone Quality Badges
**Date:** 2026-09-05 13:37 (EDT)
**Context:** Achieve 1:1 visual parity with Factorio 2.0 native inserter filter overlays for Diverter Alt-Mode rendering and UI slot buttons, supporting standalone quality filters, non-equal comparator target quality badges, and per-slot blacklist indicators.
**Key Changes:**
1. **Standalone Quality Filter Layout (`scripts/diverter-renderer.lua` & `scripts/utils/gui-components.lua`):** Supported filter slots configured with quality criteria but no specific item (`item == nil`), rendering quality tier sprites (`quality/rare`, `quality/legendary`, etc.) in horizontal side-by-side alignment with comparator symbols (`[ Comparator ] [ Quality Badge ]`).
2. **Target Quality Badge Preservation for Non-Equal Comparators (`scripts/diverter-renderer.lua` & `scripts/utils/gui-components.lua`):** Corrected overlay logic so non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`) always render the target quality tier badge—including `quality/normal` (grey dot)—explicitly displaying the comparison target.
3. **Per-Slot Prominent Blacklist Symbol Overlay (`scripts/diverter-renderer.lua`):** Moved blacklist "no" symbol rendering inside the per-slot filter loop, scaling indicators to `bl_scale = scale * 0.88` centered over each individual filter icon (`cx + scale * 0.05, cy - scale * 0.05`) rather than drawing a single miniature port-wide symbol.


### Revision: Diverter Alt-Mode Overlay Alignment Fix & Consolidated Filter Display Specification
**Date:** 2026-09-05 14:31 (EDT)
**Context:** Unify filter display specification rules across GUI slot buttons and Alt-Mode world overlays while resolving comparator text collision over quality badge dots in world rendering.
**Key Changes:**
1. **Unified Filter Display Specification (`scripts/utils/gui-components.lua`):** Implemented `gui_components.get_filter_display_spec` and `gui_components.get_active_filters` to centralize native Factorio 2.0 filter display rules (item sprites, comparator visibility, target quality badges, and standalone quality filters) across both GUI slot buttons and world overlays.
2. **GUI Slot Button Simplification (`scripts/utils/gui-components.lua`):** Refactored `gui_components.update_overlay_slot_button` to consume `get_filter_display_spec`, ensuring 100% rule parity with Alt-Mode overlays while maintaining GUI widget styling and bottom-flow badge layouts.
3. **Alt-Mode Badge & Comparator Offset Alignment (`scripts/diverter-renderer.lua`):** Corrected Alt-Mode rendering offset coordinates and text alignment for multi-badge configurations (`badge_x = cx - scale * 0.18`, `comp_x = cx - scale * 0.38`, `alignment = "right"`), placing comparator symbols cleanly to the left of quality badge dots to achieve 1:1 visual parity with native Factorio 2.0 inserters.
4. **World Rendering Pass Consolidation (`scripts/diverter-renderer.lua`):** Added `draw_text_with_shadow` and `draw_sprite_with_outline_and_shadow` helpers to consolidate multi-pass rendering objects (black outlines, drop shadows, and main sprites) across item filters, standalone quality badges, and blacklist indicators.


### Revision: Revert Diverter GUI Default View to 'All' Mode
**Date:** 2026-09-05 15:09 (EDT)
**Context:** Default the Pneumatic Diverter configuration GUI to display all four directional port cards simultaneously ("All" mode) upon opening, rather than focusing single-port North view by default.
**Key Changes:**
1. **Default View State (`scripts/diverter-gui.lua`):** Updated `diverter_gui.open` and `diverter_gui.refresh_if_open` to default `current_view` to `"all"` instead of `1` (North port), rendering the full 4-port grid when opening the diverter interface without an explicit initial view parameter.


### Revision: Filter Slot Draft State, Quality Preservation & Draggable Modal GUI
**Date:** 2026-09-05 16:00 (EDT)
**Context:** Achieve native Factorio 2.0 filter configuration behavior by preserving existing quality/comparator rules on item swaps, isolating modal editing inside a draft working state, and making filter configuration pop-ups fully draggable.
**Key Changes:**
1. **Comparator & Quality Preservation (`scripts/utils/gui-components.lua`):** Refactored `gui_components.handle_filter_item_change` so selecting an item defaults to `=` and `normal` quality only if the slot is currently blank (`"Any Quality"`). Pre-configured comparators and quality tiers are preserved intact when changing item selections.
2. **Isolated Draft Filter State & Confirm Lifecycle (`scripts/diverter-gui.lua`):** Implemented a `draft_filters` working table in `diverter_gui.open_slot_config`. Interacting with items, quality radio buttons, or comparator dropdowns inside the modal updates only the draft without mutating persistent `diverter_settings` or leaking live updates to the machine. Drafts commit to the entity strictly upon clicking Confirm (✓) or pressing `E`/`Esc`, while clicking Cancel (X) discards unconfirmed changes.
3. **Window Focus & Draggable Header Integration (`scripts/diverter-gui.lua` & `scripts/utils/gui-components.lua`):** Removed `player.opened` re-assignment inside `open_slot_config` to prevent Factorio's engine from triggering `on_gui_closed` on the main frame and destroying the modal pop-up on spawn. Enhanced `gui_components.add_header` with `drag_target = parent_frame` across header title flows and drag spacers, making modal filter windows fully draggable across the viewport.


### Revision: Diverter GUI Per-Port Copy-Paste & Native Tool Buttons
**Date:** 2026-09-05 16:15 (EDT)
**Context:** Enable players to quickly duplicate filter rules, circuit conditions, and directional flow settings between individual diverter ports via native tool buttons and player-scoped clipboard storage.
**Key Changes:**
1. **Port Settings Copy-Paste API (`scripts/diverter-settings.lua`):** Added `diverter_settings.copy_port` and `diverter_settings.paste_port` to produce isolated deep-copies of port configurations and apply them to target ports while invalidating compiled filter caches (`_compiled = nil`).
2. **Native Tool Button Header Integration (`scripts/diverter-gui.lua`):** Added `port_copy_button` and `port_paste_button` using Factorio 2.0 `tool_button` sprite styles (`utility/copy` and `utility/paste`) to each port card header. Dynamically disabled paste buttons when `storage.port_clipboard[player_index]` is empty.
3. **Cursor Flying Text Feedback & Live Refresh (`scripts/diverter-gui.lua`):** Wired `on_gui_click` handlers to populate player clipboard storage, trigger `notify_change()` to update world overlays and active device scanners, refresh open GUIs, and display cursor floating text feedback (`create_at_cursor = true`).


### Revision: Blueprint Proxy Wire Tuple Fix & Instant Zero-State Reconstruction
**Date:** 2026-09-05 16:42 (EDT)
**Context:** Resolve a critical blueprint proxy wire corruption bug where stamped blueprint entities generated a web of erroneous circuit wire connections to the top-left entity (Entity #1) and leaked wire memory across unrelated blueprint placements.
**Key Changes:**
1. **Blueprint Wire Tuple Format Fix (`scripts/device-settings-copier.lua`):** Corrected `add_bp_wire` tuple array formatting to insert `proxy_bp_entity.entity_number` as the first element (`[entity_from, wire_type_from, entity_to, wire_type_to]`) instead of `src_conn_id`. Passing `1` (red wire connector ID) in position 1 previously caused Factorio's C++ blueprint parser to decode Entity #1 as the source for every wire in the blueprint, producing spiderweb cross-links to the top-left machine.
2. **Purged Persistent Pending Wire Queue (`scripts/device-settings-copier.lua`):** Removed `storage.bp_wire_cache` and `storage.pending_bp_wires` multi-tick storage buffers. Refactored `process_entity_built_wire_tags` to perform zero-state, instant spatial wire target resolution strictly on the build tick via `surface.find_entities_filtered` and relative distance matching (`is_valid_wire_target`), completely preventing cross-linking across separate blueprint stamps placed over time.
3. **Strict Target Entity Validity Guards (`scripts/device-settings-copier.lua`):** Added explicit `unit_number` and `.valid` checks across target entity lookups and table index accesses, preventing C++ `__newindex` metamethod runtime exceptions when destroyed ghost proxies are processed during blueprint placement events.


### Revision: Pneumatic Pump GUI Interaction Parity & Entity GUI Mode Fix
**Date:** 2026-09-05 17:08 (EDT)
**Context:** Resolve an issue where left-clicking physical `pneumatic-pump` entities failed to open the pump configuration GUI, requiring players to click its hidden circuit proxy.
**Key Changes:**
1. **Entity GUI Mode Activation (`prototypes/entity.lua`):** Added `gui_mode = "all"` to the `pneumatic-pump` `electric-energy-interface` prototype definition. This enables native entity interaction event dispatching (`on_gui_opened`) when left-clicked, allowing `proxy-manager.lua` to intercept interactions and launch `pump-gui` in 1:1 functional parity with `pneumatic-diverter`.


### Revision: Native Confirm GUI Event Linking & Esc Modal Cancellation
**Date:** 2026-09-05 17:32 (EDT)
**Context:** Differentiate between pressing `E` (Confirm) and `Esc` (Cancel) when leaving the Diverter filter slot configuration modal, achieving 1:1 parity with native Factorio 2.0 GUI draft lifecycle conventions.
**Key Changes:**
1. **Confirm GUI Custom Input Registration (`prototypes/custom-input.lua`):** Registered `pneumatic-confirm-gui` linked to Factorio's native `confirm-gui` control sequence (`linked_game_control = "confirm-gui"`) with `consuming = "none"`.
2. **Tick-Based Confirm Event Tracking (`scripts/diverter-gui.lua`):** Subscribed to the `pneumatic-confirm-gui` custom input event to record the exact execution tick (`confirm_ticks[player_index] = event.tick`) when a player triggers the GUI confirmation key.
3. **Confirm vs. Cancel Dismissal Logic (`scripts/diverter-gui.lua`):** Updated `on_gui_closed` to evaluate whether `confirm_ticks[event.player_index] == event.tick`. Pressing `E` (or clicking the checkmark) passes `should_apply = true` to commit draft filter settings, whereas pressing `Esc` (or closing without confirming) passes `should_apply = false` to discard draft changes without mutating entity settings.


### Revision: Diverter Filter Draft Quality Synchronization & Standalone Quality Preservation
**Date:** 2026-09-05 17:53 (EDT)
**Context:** Prevent diverter slot configuration modals from silently holding ghost quality settings when clearing item selections, while maintaining full GUI and draft parity for standalone quality filters.
**Key Changes:**
1. **Item Clear Quality Preservation (`scripts/utils/gui-components.lua`):** Refactored `gui_components.handle_filter_item_change` so clearing an item selection preserves configured comparator and quality settings (updating GUI quality bar controls accordingly), while resetting quality to `"normal"` only if the comparator is set to `"Any Quality"`.
2. **Draft & Modal Synchronization (`scripts/diverter-gui.lua`):** Updated `diverter_gui.open_slot_config` and `close_slot_config` to guarantee 1:1 synchronization between GUI widgets and draft state tables (`draft_filters`), ensuring submitted configurations strictly match the visual state of the modal window.
3. **Stored Setting Normalization (`scripts/diverter-settings.lua`):** Enhanced `diverter_settings.get` to sanitize stored filter settings on load, enforcing `quality = "normal"` and clearing `explicit_quality` whenever a slot uses `"Any Quality"` without an item.


### Revision: Refrigerated Capsule Recharge Recipe Subgroup & English Localization
**Date:** 2026-09-05 19:53 (EDT)
**Context:** Organize the `recharge-refrigerated-capsule` recipe into the dedicated Pneumatic Transport crafting tab and provide localized recipe name display in the English locale configuration.
**Key Changes:**
1. **Recipe Subgroup & Tab Order (`prototypes/recipe.lua`):** Configured `subgroup = "pneumatic-capsules"` and `order = "c[refrigerated]-b[recharge]"` on `recharge-refrigerated-capsule`, moving the recipe out of the fallback "other/misc" subgroup and positioning it directly adjacent to the main refrigerated capsule recipe in the Pneumatic Transport crafting tab.
2. **English Recipe Localization (`config.cfg`):** Added `recharge-refrigerated-capsule=Recharge Refrigerated Capsule` under `[recipe-name]` in the English locale file.


### Revision: Spatial Junction Flow Overlay Consolidation & Z-Ordering Fix
**Date:** 2026-09-05 20:01 (EDT)
**Context:** Resolve duplicate overlapping overlay circles, garbled text z-index fighting, and placement-order visual inconsistencies at connected flow junctions.
**Key Changes:**
1. **Spatial Position-Based Rendering (`scripts/flow/flow-engine.lua`):** Refactored Alt-Mode flow level visual overlays from individual port tracking (`pkey`) to unified spatial junction tracking (`pos_key`). `update_pos_render` guarantees exactly one circle and text object is rendered per physical tile coordinate, eliminating duplicate circle stacking and placement-order sensitivity.
2. **Dominant Flow Level Selection (`scripts/flow/flow-engine.lua`):** Implemented `get_dominant_port_at_pos` to evaluate all overlapping ports at a tile location and display the dominant magnitude flow level (`math.abs(level)`), resolving ties in favor of positive pressure and active machine emitters.
3. **Zero-Length Vector Suppression (`scripts/flow/flow-engine.lua`):** Updated `update_edge_render` to automatically discard zero-length vector line renders between co-located ports sharing the same `pos_key`.


### Revision: Concise Capsule Item & Factoriopedia Descriptions & Maintenance Correction
**Date:** 2026-09-05 20:27 (EDT)
**Context:** Provide concise Factoriopedia and tooltip descriptions for all pneumatic transport capsule items, detailing capacity scaling, quality rules, spoilage mechanics, and correct maintenance crafting facilities.
**Key Changes:**
1. **Concise Capsule Locale Descriptions (`config.cfg`):** Updated `[item-description]` entries for all six capsule variants (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`) with punchy multiline specs covering slot capacity scaling, quality rules, organic slot cost discounts, 90% cryo spoilage reduction, dissolution/rupture risks, and emergency player ejection controls (`__CONTROL__capsule-emergency-exit__`).
2. **Assembling Machine Recharge Correction (`config.cfg`):** Corrected `refrigerated-capsule` and `spent-refrigerated-capsule` maintenance documentation to specify that coolant recharging with cold fluoroketone occurs at assembling machines.
3. **Prototype Description Cleanup (`prototypes/item.lua`):** Removed unused `factoriopedia_description` properties from `ItemPrototype` and `ToolPrototype` definitions, ensuring Factoriopedia and item tooltips cleanly render the localized multiline descriptions directly from `[item-description]`.


### Revision: Pneumatic Hub Binary Nest Capsules Configuration Toggle
**Date:** 2026-09-05 20:43 (EDT)
**Context:** Enable players to configure Pneumatic Hubs to either exclusively nest capsule vessel items inside outgoing capsules or restrict packing strictly to non-capsule cargo items.
**Key Changes:**
1. **Hub Settings State & Blueprint Sync (`scripts/hubs/hub-settings.lua`):** Added `nest_capsules = true` default setting to `hub_settings.get()`, ensuring property preservation across entity copy-paste (`hub_settings.copy`) and blueprint tag deserialization (`hub_settings.apply_blueprint_settings`).
2. **Operational Mode GUI Checkbox (`scripts/hubs/hub-gui.lua`):** Added a "Nest capsules" checkbox to the Hub relative settings window, wiring `on_gui_checked_state_changed` to update `settings.nest_capsules` and invoke `hub_manager.notify_settings_changed()` to wake active scanners.
3. **Inventory Packing Filter Pipeline (`scripts/hubs/hub-packing.lua`):** Updated `evaluate_inventory()` to filter candidate cargo stacks based on `nest_capsules`: restricting cargo choices strictly to registered capsule variants (`capsule_defs.types`) when enabled, or excluding capsule items when disabled.


### Revision: Native-Style Live Source Entity Copy-Paste & Ghost Settings Parity
**Date:** 2026-09-06 10:02 (EDT)
**Context:** Align entity settings copy-paste mechanisms with Factorio 2.0 native behavior by tracking live source entities instead of static snapshots, requiring live source existence, and bringing 1:1 settings copy, rotate, and revival parity to ghost entities.
**Key Changes:**
1. **Live Entity Source Tracking (`scripts/device-settings-copier.lua`):** Updated `on_copy_settings` to store live `LuaEntity` references in `storage.player_copy_buffer`, evaluating live settings and relative entity directions dynamically at the tick of paste execution (`apply_live_settings_copy`).
2. **Source Validity Guard (`scripts/device-settings-copier.lua`):** Added strict `source and source.valid` checks across custom hotkey and native `on_entity_settings_pasted` events, preventing paste operations if the source machine or ghost was destroyed or mined.
3. **Ghost Proxy Target Resolution (`scripts/device-settings-copier.lua`):** Enhanced `resolve_target_entity` to inspect `ghost_name` when targeting ghost entities or clicking proxy circuit terminals overlaying unbuilt ghost structures.
4. **Ghost Entity Settings Lifecycle (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Refactored build, destroy, and rotate event listeners to resolve ghost entity names (`is_ghost and entity.ghost_name or entity.name`), enabling blueprint tag deserialization, orientation rotation, revival transfer (`event.source`), and storage cleanup for ghost pumps, diverters, and hubs.


### Revision: Pneumatic Ghost Entity GUI Evoking, Live Settings & Copy-Paste Parity
**Date:** 2026-09-06 10:34 (EDT)
**Context:** Achieve 1:1 parity with native Factorio 2.0 ghost interactions by enabling configuration GUI opening, live setting updates, rotation sync, and copy-paste handling across ghost pumps, diverters, and hubs.
**Key Changes:**
1. **Ghost Entity Search & Proxy Resolution (`scripts/proxy-manager.lua` & `scripts/hubs/hub-gui.lua`):** Updated `on_gui_opened` to resolve `entity.ghost_name` and locate ghost main entities when clicking circuit proxies, allowing players to open configuration windows on unbuilt ghost entities.
2. **O(1) Ghost Entity Tracking (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Added `storage.ghost_devices` and `storage.ghost_hubs` tables to record active ghost entities by `unit_number`, enabling instant entity resolution during GUI change events.
3. **Ghost Live GUI Updates & Observer Sync (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`, `scripts/hubs/hub-gui.lua`):** Refactored `notify_change` to resolve ghost entities, triggering scanner notifications and live UI frame re-renders (`refresh_if_open`) whenever ghost settings are modified.
4. **Ghost Rotation & Copy-Paste Parity (`scripts/active-device-scanner.lua` & `scripts/device-settings-copier.lua`):** Triggered setting updates on ghost rotation/flip events and un-guarded `apply_live_settings_copy` to notify observers and refresh open GUIs when pasting settings to ghost destinations.


### Revision: Ghost Entity Configuration Parity, Alt-Mode Overlays & Build Settings Adoption
**Date:** 2026-09-06 18:56 (EDT)
**Context:** Achieve 1:1 functional parity for ghost Diverters, Pumps, and Cargo Hubs by supporting full GUI interaction, world Alt-Mode filter overlay rendering, and automatic settings inheritance when building physical entities over ghosts.
**Key Changes:**
1. **Spatial Ghost Location Registry (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Implemented `storage.ghost_by_pos` mapping tile coordinates (`surface@x,y`) to ghost unit numbers. When a physical entity replaces a ghost (via inventory build, robot construction, or revive script), the newly created entity retrieves the ghost unit number and copies settings (`pump_settings.copy`, `diverter_settings.copy`, `hub_settings.copy`) even after the ghost object is consumed by the engine.
2. **Ghost GUI Registration & Live Observer Sync (`scripts/diverter-gui.lua`, `scripts/pump-gui.lua`, `scripts/hubs/hub-gui.lua`):** Registered open ghost entities directly into `storage.ghost_devices` and `storage.ghost_hubs`. Allows `notify_change()` to resolve ghost entity handles, triggering live scanner updates, world Alt-Mode overlay renders, and instant GUI frame re-renders when checkboxes, switches, or circuit conditions are modified.
3. **Decoupled Ghost Port Resolution & Circuit Isolation (`scripts/flow/port-defs.lua`, `scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Updated `port_defs.get_ports()` to resolve `ghost_name` transparently for world overlays while bypassing active circuit signal reads (`get_signal`) and proxy queries on ghost entities, isolating ghost settings storage from runtime simulation loops.
4. **Proxy Lifecycle Replacement Guard (`scripts/proxy-manager.lua`):** Updated `on_removed` to inspect tile coordinates for remaining main or ghost entities before destroying circuit proxies, preventing proxy wire disruption when physical entities replace ghosts.


### Revision: Ghost Entity Configuration Parity, Circuit Proxy Isolation & GUI Tag Resolution
**Date:** 2026-09-06 20:10 (EDT)
**Context:** Resolve ghost diverter GUI checkbox reset instability, prevent circuit proxy lifecycle events from wiping ghost settings storage, and ensure physical entities inherit and correctly rotate ghost configurations upon build/revive.
**Key Changes:**
1. **Ghost Device Position-Based Identity Resolution (`scripts/diverter-settings.lua`, `scripts/pump-settings.lua`, `scripts/hubs/hub-settings.lua`):** Implemented `get_device_id()` to produce stable spatial position keys (`ghost@name@surface@x,y`) for hand-placed and blueprint ghost entities that do not possess native `unit_number` properties in Factorio 2.0.
2. **Circuit Proxy Blacklist & Spatial Key Namespacing (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Blacklisted circuit proxy entities from build/destroy/rotate handlers and namespaced spatial position keys (`real_name@surface@x,y`), preventing circuit proxy spawns from falsely matching and erasing ghost device settings in `storage`.
3. **Recursive Parent GUI Tag Resolution (`scripts/diverter-gui.lua`):** Implemented `get_element_tags()` to traverse up the widget hierarchy (`element.parent`), enabling nested checkboxes, switches, and dropdowns to reliably retrieve device IDs attached to parent card frames.
4. **Suppressed Local GUI Re-Entrant Destructions (`scripts/diverter-gui.lua`):** Added a local GUI edit flag guarding `refresh_if_open`, preventing local user checkbox toggles from clearing `inner_frame` mid-click while preserving live UI re-renders for external rotation and copy-paste events.
5. **Ghost Settings Migration & Rotation Inheritance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Recorded `storage.ghost_directions` on placement/rotation and updated build event handlers (`on_built_entity`, `script_raised_revive`, etc.) to copy settings from ghost sources (`event.consumed_ghost`, `event.source`, or spatial lookup) and apply relative direction rotations.


### Revision: Ghost Spatial Identity, Directional Indexing & Rotation/Flip Build Inheritance
**Date:** 2026-09-06 20:46 (EDT)
**Context:** Ensure ghost pumps, diverters, and cargo hubs maintain and adapt configured settings across rotation, flipping, ghost-on-ghost replacement, and physical placement over ghosts regardless of orientation changes.
**Key Changes:**
1. **Spatial Device Identity Export (`scripts/pump-settings.lua` & `scripts/hubs/hub-settings.lua`):** Exported `get_device_id` across `pump_settings` and `hub_settings` matching `diverter_settings`, establishing a unified spatial identity schema (`ghost@name@surface@x,y` or `unit_number`) across all device storage layers.
2. **Cardinal Direction Enum Normalization (`scripts/diverter-settings.lua`):** Implemented `get_cardinal_index` to map Factorio 2.0 16-way, 8-way, and 4-way direction enum values (`0`, `4`, `8`, `12`) cleanly to cardinal indices (North=1 through West=4), ensuring relative step rotations are accurately calculated during settings copying.
3. **Pre-Registration Ghost Proximity Search (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Added `find_ghost_id_at_pos` spatial search (1.2 tile radius) to resolve preceding ghost settings prior to updating `storage.ghost_by_pos`, preventing newly placed entities from overwriting spatial lookup keys before reading settings.
4. **Ghost-on-Ghost & Flip Settings Inheritance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Removed `not is_ghost` guards from build event copy logic, allowing replacement ghosts spawned when flipping (`F`) or rotating (`R`) existing ghosts to inherit and adapt settings from preceding ghosts at the same tile coordinate.
5. **Deferred Ghost Settings Purge (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Deferred ghost settings deletion during ghost destruction events, preserving configuration tables in `storage` across engine entity replacement ticks.


### Revision: Object Destruction Tracking & Circuit Proxy Cleanup for Super Force Building
**Date:** 2026-09-06 20:56 (EDT)
**Context:** Resolve lingering orphan circuit proxy entities left behind when built or ghost diverters and pumps are mined, destroyed, or super force built over.
**Key Changes:**
1. **Self-Exclusion Removal Guard (`scripts/proxy-manager.lua`):** Updated `on_removed` to filter out `m ~= entity` and `g ~= entity` when evaluating remaining main or ghost entities at machine tile coordinates, preventing active destruction targets from falsely suppressing proxy removal.
2. **Object Destruction Registration (`scripts/proxy-manager.lua`):** Registered main built and ghost entities with `script.register_on_object_destroyed` inside `on_created`, tracking registration IDs in `storage.proxy_destruction_map` alongside surface, spatial position, and proxy specification metadata.
3. **Engine-Level Object Destroyed Callback (`scripts/proxy-manager.lua`):** Subscribed to `defines.events.on_object_destroyed` to catch C++ engine-level entity removals (such as super force building, fast replacement, and ghost cancellation). The callback evaluates remaining spatial main entities post-destruction and purges orphaned real and ghost circuit proxies when no host machine remains.


### Revision: Complete English Locale Recipe Description Coverage
**Date:** 2026-09-06 22:05 (EDT)
**Context:** Achieve 100% English locale coverage for all pneumatic transport crafting recipes, ensuring detailed localized descriptions render cleanly in Factoriopedia and crafting menu tooltips.
**Key Changes:**
1. **Localized Recipe Description Section (`config.cfg`):** Added a dedicated `[recipe-description]` section to the English locale configuration file.
2. **Comprehensive Recipe Description Entries (`config.cfg`):** Populated concise localized description strings for all 13 mod recipes (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `recharge-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, and `pneumatic-diverter`), detailing operational roles, capsule behaviors, and thermal byproduct discharges.


### Revision: Strict Ghost Settings Adoption, Spatial Bounding Box & Orientation Overlap
**Date:** 2026-09-06 23:01 (EDT)
**Context:** Prevent improper settings inheritance when placing physical entities or ghosts over ghosts with different bounding box shapes, orientation axes, or spatial offsets.
**Key Changes:**
1. **Strict Spatial Position Tolerance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Tightened ghost spatial lookup distance matching from 1.2 tiles down to `< 0.1` tiles (`dx < 0.1, dy < 0.1`), preventing entities placed offset or 1 tile away from falsely adopting adjacent ghost configurations.
2. **Orientation Axis Alignment Guard (`scripts/active-device-scanner.lua` & `scripts/diverter-settings.lua`):** Exported `diverter_settings.get_cardinal_index` to enforce orientation axis checks (`(g_idx % 2) == (e_idx % 2)`), ensuring 1x2 and 2x1 pumps only inherit settings when placed along matching orientation axes (blocking adoption when placing horizontal pumps over vertical ghost pumps).
3. **Prototype Real-Name Compatibility (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Enforced exact prototype real-name equality (`g_real_name == real_name`) across ghost entity handles (`event.consumed_ghost`, `event.source`, or spatial lookup) prior to copying settings, preventing cross-prototype adoption between locked orientation hub variants (`capsule-hub-horizontal` vs `capsule-hub-vertical`).


### Revision: Blueprint Settings Overwrite Parity & Factorio 2.0 Engine Event Integration
**Date:** 2026-09-06 23:21 (EDT)
**Context:** Resolve an issue where stamping blueprints or pasting blueprint settings over existing built diverters, pumps, or cargo hubs failed to update entity configurations, preserving pre-existing machine settings.
**Key Changes:**
1. **Factorio 2.0 Blueprint Settings Pasted Event (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua` & `scripts/device-settings-copier.lua`):** Subscribed to native Factorio 2.0 `defines.events.on_blueprint_settings_pasted` across active device scanners, hub managers, and wire linkers to capture blueprint tags (`event.tags.pneumatic_settings`) and relative directional changes (`event.previous_direction`) when stamping blueprints over built entities.
2. **Existing Spatial Entity Overwrite (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Implemented `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` spatial lookups (< 0.1 tile tolerance). When a ghost is placed over an existing physical machine, settings and rotations apply directly to the physical entity, Alt-Mode overlays and scanners are woken, and redundant ghost entities are purged.
3. **Blueprint Item & Record Paste Parity (`scripts/device-settings-copier.lua`):** Implemented `extract_settings_from_blueprint_source` inside `apply_live_settings_copy` to inspect `LuaItemStack` and `LuaRecord` handles during `on_entity_settings_pasted`, enabling direct Shift+Left-Click settings transfers from blueprint items onto built entities.


### Revision: Pneumatic Capsule Counter Data Stage & Prototype Declarations
**Date:** 2026-09-07 10:21 (EDT)
**Context:** Implement Task 1 of the Capsule Counter plan, registering entity, item, recipe, technology, and hidden circuit proxy prototypes ahead of runtime range propagation and logic engine integration.
**Key Changes:**
1. **Capsule Counter Entity & Proxy (`prototypes/pneumatic-capsule-counter.lua`):** Registered the main physical entity `pneumatic-capsule-counter` (`electric-energy-interface`, 1x2 footprint, 30 kW energy usage, `selection_priority = 50`) configured with `gui_mode = "all"`. Registered its companion `pneumatic-capsule-counter-circuit-proxy` (`constant-combinator`, `selection_priority = 60`, `operable = true`, `placeable_by` main item, `"player-creation"` flag).
2. **Tinted Decider Sprite Graphics (`prototypes/pneumatic-capsule-counter.lua`):** Deepcopied 4-way directional sprites from `data.raw["decider-combinator"]["decider-combinator"]` and applied a distinct teal tint (`r = 0.30, g = 0.85, b = 0.70`), visually differentiating the counter structure from pumps and hubs.
3. **Item & Recipe Declarations (`prototypes/item.lua` & `prototypes/recipe.lua`):** Registered `pneumatic-capsule-counter` item under subgroup `pneumatic-transport` (order `h[counter]`, stack size 20) with a matching teal icon tint, and added its crafting recipe requiring tubes, advanced circuits, and arithmetic combinators.
4. **Technology Unlock & Data Registration (`prototypes/technology.lua` & `data.lua`):** Linked the counter recipe unlock effect directly to the baseline `pneumatic-transport` technology research node and required `prototypes.pneumatic-capsule-counter` in `data.lua`.


### Revision: Pneumatic Capsule Counter Circuit Proxy Pair Lifecycle Integration
**Date:** 2026-09-07 10:29 (EDT)
**Context:** Implement Task 2 of the Capsule Counter plan, linking the physical counter entity with its hidden circuit proxy pair in `proxy-manager.lua` to enable proxy creation, wire retention, selection Z-indexing, and orphan cleanup.
**Key Changes:**
1. **Proxy Pair Registration (`scripts/proxy-manager.lua`):** Registered the `pneumatic-capsule-counter` and `pneumatic-capsule-counter-circuit-proxy` pair via `proxy_manager.register_pair` with a forward-compatible `on_open_gui` stub handler delegating to `counter_gui.open`.
2. **Lifecycle & Selection Z-Indexing Integration (`scripts/proxy-manager.lua`):** Bound the counter proxy pair into the centralized proxy manager lifecycle, automatically enabling proxy creation on build/ghost placement, `selection_priority = 60` teleportation on rotation, additive wire connection migrations (`transfer_wire_connections`), orphan proxy destruction on main entity removal, and sandbox wipe cleanup (`storage.proxy_destruction_map`).


### Revision: Pneumatic Capsule Counter Sensing Port Alignment
**Date:** 2026-09-07 11:02 (EDT)
**Context:** Implement Task 3 of the Capsule Counter plan, registering directional sensing ports for the physical and ghost counter entities in port-defs.lua to enable topological node registration and range wavefront propagation.
**Key Changes:**
1. **Counter Port Registry Alignment (`scripts/flow/port-defs.lua`):** Registered `pneumatic-capsule-counter` port definitions across all four cardinal directions (`north`, `south`, `east`, `west`), assigning six spatial sensing connection offsets per orientation matching hub footprint layouts.
2. **Sensing Power & Isolation Configuration (`scripts/flow/port-defs.lua`):** Configured sensing ports with a `sense = 15` range seed rating while specifying `transmit = false`, `cross_transit = false`, and omitting gas `flow` pressure emission to ensure counter structures sense adjacent tube networks without acting as transit conduits or gas emitters.


### Revision: Pneumatic Capsule Counter Wavefront Range Engine
**Date:** 2026-09-07 13:34 (EDT)
**Context:** Implement Task 4 of the Capsule Counter plan, creating the delta wavefront propagation and boundary collision engine in `counter-range.lua` to partition tube networks into non-overlapping owned segment territories.
**Key Changes:**
1. **Wavefront Range Engine (`scripts/counters/counter-range.lua`):** Created `counter-range.lua` maintaining `storage.counter_levels`, `storage.counter_owners`, `storage.counter_queue`, and `storage.counter_owned_nodes`. Range seeds (15) decay by 1 level per hop down to 1 along tube nodes, with equal-level rival collisions resolving neutrally to eliminate double-counting. Implemented $O(1)$ segment territory lookups (`counter_range.get_owned_nodes`), defensive lazy storage initialization, and a `/check-counters` status debug command.
2. **Sensing Node Attribute Preservation (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to record `port.sense` attributes on `storage.flow_nodes`, allowing physical counter sensing ports to act as range emitters during graph traversal.
3. **Background Scanner Integration (`scripts/active-device-scanner.lua`):** Registered `pneumatic-capsule-counter` in the 15-tick background scanner. Energy state changes (`entity.energy > 0`) automatically trigger unit port enqueuing for immediate range expansion or recession.
4. **Runtime Lifecycle & Surface Hydration (`control.lua`):** Integrated `counter_range` storage initialization and event listeners into `control.lua`, scanning surfaces on load and initialization to register existing counters cleanly.


### Revision: Pneumatic Capsule Counter Wavefront Overlay & Flow Engine Unification
**Date:** 2026-09-07 14:26 (EDT)
**Context:** Implement Task 5 of the Capsule Counter plan, unifying sensing range wavefront propagation directly into `flow-engine.lua` for single-pipeline execution, adding Alt-Mode visual range overlays, deterministic midpoint tie-breaking, and symmetric recession/cleanup handling.
**Key Changes:**
1. **Flow Engine Wavefront Unification (`scripts/flow/flow-engine.lua`):** Refactored counter sensing range propagation directly into `flow_engine.step`, sharing the primary topological graph, queue, time-sliced batcher, and event listeners with pressure flow.
2. **Deterministic Territory Tie-Breaking (`scripts/flow/flow-engine.lua`):** Implemented deterministic `unit_number` tie-breaking for equal-distance midpoint collisions (`cand_level == max_cand_level`), eliminating neutral gap tiles and guaranteeing contiguous counter territory splits.
3. **Sensing Overlay Rendering & Alt-Mode Toggle (`scripts/flow/flow-engine.lua` & `scripts/debug-manager.lua`):** Implemented `update_counter_pos_render` rendering range level integers and owner color dots on tube nodes in Alt Mode. Added `/toggle-counter-range` (`/pt-toggle-counter-range`) command, shortcut, and Control Panel checkbox operating independently from pressure flow overlays.
4. **Natural Recession Waves & Disconnection Cleanup (`scripts/flow/flow-engine.lua` & `scripts/counters/counter-range.lua`):** Refactored `counter-range.lua` into a lightweight query API delegating queueing to `flow-engine.lua`. Updated entity removal and unpowering to enqueue root ports without pre-wiping levels, enabling 1-tile-per-tick recession waves for surviving counter takeover while instantly purging unconnected emission port renders on frame 0.


### Revision: Pneumatic Capsule Counter State Persistence Module
**Date:** 2026-09-07 14:33 (EDT)
**Context:** Implement Task 6 of the Capsule Counter plan, creating `counter-settings.lua` to manage counter configuration storage, spatial device ID resolution, copy-paste cloning, blueprint serialization, and proxy resolution.
**Key Changes:**
1. **State Persistence Module (`scripts/counters/counter-settings.lua`):** Created `counter-settings.lua` maintaining `storage.counter_settings[dev_id]` with default schema (`vessels_target = "green"`, `cargo_target = "red"`, `total_target = "green"`, `total_signal = { type = "virtual", name = "signal-C" }`).
2. **Spatial Identification & Proxy Resolution (`scripts/counters/counter-settings.lua`):** Implemented `counter_settings.get_device_id` supporting real unit numbers and ghost string formats (`ghost@...`), and `counter_settings.get_proxy` to locate the associated `pneumatic-capsule-counter-circuit-proxy`.
3. **Copy-Paste & Blueprint Deserialization (`scripts/counters/counter-settings.lua`):** Implemented `counter_settings.copy` for deep-copying settings between entities/ghosts and `counter_settings.apply_blueprint_settings` for restoring configuration tables from blueprint tags.


### Revision: Pneumatic Capsule Counter Copy-Paste & Blueprint Serialization
**Date:** 2026-09-07 14:52 (EDT)
**Context:** Implement Task 7 of the Capsule Counter plan, integrating pneumatic capsule counter entities into active device scanning, live copy-paste workflows, ghost settings adoption, and blueprint tag serialization.
**Key Changes:**
1. **Target Registration & Live Copy-Paste (`scripts/device-settings-copier.lua`):** Added `pneumatic-capsule-counter` to `TARGET_NAMES`, mapped `pneumatic-capsule-counter-circuit-proxy` target resolution to the main entity, implemented live entity copy-paste handling, and added top-level safe loading for `counter-gui`.
2. **Blueprint Serialization & Wire Target Resolution (`scripts/device-settings-copier.lua`):** Updated `on_player_setup_blueprint` to serialize counter settings tags (`pneumatic_settings`), append proxy entities, and record 4-tuple wire connections. Updated `process_entity_built_wire_tags` to restore proxy circuit wire links upon blueprint placement.
3. **Active Scanner Hooks & Ghost Settings Adoption (`scripts/active-device-scanner.lua`):** Added `init_settings` and `apply_blueprint_settings` hooks to the `pneumatic-capsule-counter` scanner spec, enabled device ID resolution, and integrated ghost-to-real settings adoption, blueprint pasting, and storage cleanup on entity removal or rotation.


### Revision: Pneumatic Capsule Counter Logic Engine & Circuit Signal Emitter
**Date:** 2026-09-07 15:01 (EDT)
**Context:** Implement Task 8 of the Capsule Counter plan, creating counter-logic.lua to calculate capsule vessel counts, cargo item inventories, and total capsule counts within owned tube territories, writing signal filters directly to the circuit proxy combinator on active scanner ticks.
**Key Changes:**
1. **Counter Logic Module (`scripts/counters/counter-logic.lua`):** Created `counter-logic.lua` providing `counter_logic.update_signals(counter_entity)`. Resolves owned segment nodes (`counter_range.get_owned_nodes`), queries active capsules without double-counting, extracts vessel item/quality breakdowns, cargo contents, and total capsule count (virtual signal C), and writes accumulated signals to the circuit proxy control behavior (`section.filters`). Automatically clears output signals when unpowered (`entity.energy == 0`) or unconfigured.
2. **Active Scanner Hooks & Reactive Triggers (`scripts/active-device-scanner.lua`):** Required `counter_logic` in `active-device-scanner.lua`. Added an `on_scan` hook to the `pneumatic-capsule-counter` scanner spec for 15-tick periodic signal updates, and wired immediate signal recalculations upon power state toggles (`check_and_update_state`) and settings change notifications (`notify_settings_changed`).


### Revision: Explicit Port Transmission Schema & Sensing Boundary Isolation
**Date:** 2026-09-07 15:40 (EDT)
**Context:** Refactor overloaded port transmission properties into domain-specific flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) to prevent counter range wavefronts from leaking across active machine boundaries while guaranteeing smooth capsule transit through pumps and diverters.
**Key Changes:**
1. **Explicit Port Transmission Registry (`scripts/flow/port-defs.lua`):** Replaced single `transmit` property with domain-specific booleans (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) across all registered entity port definitions. Explicitly disabled `sense_transmit` and `pressure_transmit` on machines (`pneumatic-pump`, `pneumatic-diverter`, `capsule-hub`, `pneumatic-capsule-counter`) while retaining `capsule_transmit = true` on transit machines.
2. **Flow & Sensing Wavefront Engine Alignment (`scripts/flow/flow-engine.lua`):** Recorded explicit transmission flags during node registration (`connect_entity`). Refactored passive gas pressure checks to require `pressure_transmit`, counter range wavefront propagation to require `sense_transmit`, and internal step queueing to evaluate domain-specific changes independently.
3. **Capsule Movement Target Validation (`scripts/capsules/capsule-runner.lua`):** Updated candidate hop generation, target hop validity checks (`is_hop_valid`), and hub outbound port selection to inspect `capsule_transmit` and `cross_transit`. Completely prevents capsules from targeting pure sensing ports while guaranteeing uninhibited capsule motion through pumps and diverters.


### Revision: Pneumatic Capsule Counter Relative Configuration GUI
**Date:** 2026-09-07 15:50 (EDT)
**Context:** Implement Task 9 of the Capsule Counter plan, creating `counter-gui.lua` to provide an interactive configuration window for capsule counter entities and proxies, featuring dual-wire checkbox channel routing for vessels, cargo, and total capsule counts alongside virtual signal selection.
**Key Changes:**
1. **Relative Configuration Frame (`scripts/counters/counter-gui.lua`):** Created `counter-gui.lua` providing `open` and `close` functions to build and anchor `counter_configuration_frame` using `gui_components.create_relative_window` with header controls and card layout.
2. **Dual-Wire Channel Routing Controls (`scripts/counters/counter-gui.lua`):** Implemented dual "Red Wire" and "Green Wire" checkbox options across three configuration sections (Capsule Vessels, Cargo Contents, Total Capsule Count), seamlessly converting UI checkbox states to and from underlying setting schema targets (`"off"`, `"red"`, `"green"`, `"both"`).
3. **Signal Selection & Reactive Event Handling (`scripts/counters/counter-gui.lua`):** Integrated a `choose-elem-button` for Total Capsule Count virtual signal selection and registered event listeners (`on_gui_opened`, `on_gui_closed`, `on_gui_click`, `on_gui_checked_state_changed`, `on_gui_elem_changed`) to update `storage.counter_settings` and dispatch scanner setting notifications.


### Revision: Pneumatic Capsule Counter Triple-Proxy Channel Isolation & Full Integration
**Date:** 2026-09-07 16:17 (EDT)
**Context:** Implement Task 10 of the Capsule Counter plan, introducing a triple-proxy architecture (selectable terminal proxy plus hidden Red and Green channel proxies) to guarantee zero cross-channel signal bleed across circuit networks, while adding English locale definitions and control script initialization.
**Key Changes:**
1. **Triple-Proxy Prototypes (`prototypes/pneumatic-capsule-counter.lua`):** Registered `pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy` (`selection_priority = 0`, `operable = false`) alongside the main `pneumatic-capsule-counter-circuit-proxy` terminal (`selection_priority = 60`, `operable = true`).
2. **Sub-Proxy Lifecycle & Internal Wiring (`scripts/proxy-manager.lua`):** Extended `proxy_manager.register_pair` to support sub-proxy schemas. Automatically spawns, teleports, and connects internal Red and Green wire bridges (`connect_sub_proxies`) between channel proxies and the main terminal proxy on build/rotate events, and purges all three proxies upon entity deconstruction (`destroy_all_proxies_at`).
3. **Channel-Isolated Signal Dispatch (`scripts/counters/counter-logic.lua` & `scripts/counters/counter-settings.lua`):** Added `counter_settings.get_channel_proxies` and updated `counter_logic.update_signals` to write Red-target signals strictly to the Red channel proxy and Green-target signals strictly to the Green channel proxy while keeping the main terminal proxy filters empty, eliminating cross-network signal bleed.
4. **Active Scanner & Target Resolution (`scripts/active-device-scanner.lua` & `scripts/device-settings-copier.lua`):** Added sub-proxy names to `PROXY_NAMES` to bypass scanner tracking and updated `resolve_target_entity` to resolve sub-proxy handles back to the physical counter entity.
5. **Locale Definitions & Top-Level Require Registration (`locale/en/config.cfg` & `control.lua`):** Added English entity, item, recipe, and technology captions and descriptions. Registered `counter-settings`, `counter-gui`, and `counter-logic` as top-level `require` statements in `control.lua`.


### Revision: Hub Pressure Differential Enforcement & Cross-Transit Flow Isolation
**Date:** 2026-09-07 18:03 (EDT)
**Context:** Enforce strict positive pressure differential requirements for hub outbound capsule dispatch and cross-transit motion, preventing hubs from dumping capsules onto unpressurized or opposing-pressure target ports.
**Key Changes:**
1. **Per-Port Outbound Pressure Evaluation (`scripts/capsules/capsule-runner.lua`):** Refactored `find_best_hub_outbound_port` to measure pressure drops (`touching_level - target_level`) per individual touching port rather than applying a global hub entity maximum. Initialized `max_drop = 0` to require target ports to have strictly lower pressure than the hub's touching exit port.
2. **Strict Outbound Injection Guard (`scripts/capsules/capsule-runner.lua`):** Updated `inject_from_hub` to abort and return `false` if no valid outbound port with a positive pressure drop is found, eliminating fallback dispatches onto unpressurized or opposing flow lines.
3. **Cross-Transit Exit Port Isolation (`scripts/capsules/capsule-runner.lua`):** Updated `select_next_target` for `cross_transit` entities to calculate candidate pressure drops directly against the touching exit port (`level_exit - level_cand > 0`), preventing transiting capsules from exiting hubs into zero or negative pressure differential nodes.
4. **Hub Packing Early Exit Guard (`scripts/hubs/hub-packing.lua`):** Added an early outbound port validation check to `hub_packing.evaluate_inventory`, aborting cargo extraction and liminal holder creation whenever no valid lower-pressure outbound route is available.


### Revision: Pneumatic Capsule Counter Signal Picker Clearing & Quality Preservation
**Date:** 2026-09-07 18:24 (EDT)
**Context:** Fix an issue where clearing the total count signal picker in the Capsule Counter GUI instantly reverted to default signal-C, and ensure selected signal quality is preserved on circuit proxy output filters.
**Key Changes:**
1. **Signal Clear Persistence & Fallback Removal (`scripts/counters/counter-settings.lua` & `scripts/counters/counter-logic.lua`):** Removed hardcoded fallback initializations (`signal-C`) from existing settings retrieval (`counter_settings.get`), blueprint settings application, and logic signal evaluation. Clearing the choose-elem-button in `counter-gui.lua` now persists `total_signal = nil` without being overwritten on GUI refresh or tick scans.
2. **Quality-Aware Circuit Signal Emission (`scripts/counters/counter-logic.lua`):** Updated `counter_logic.update_signals` to extract `total_signal.quality` dynamically rather than hardcoding `"normal"` quality during channel signal aggregation, correctly reflecting chosen signal quality levels on output circuit proxy filters.


### Revision: Independent Flow & Counter Overlay Render Lifecycle
**Date:** 2026-09-07 20:55 (EDT)
**Context:** Fix issue where toggling pressure flow overlays off wiped active counter range overlays by decoupling render destruction and drawing logic in flow-engine.lua and debug-manager.lua.
**Key Changes:**
1. **Domain-Specific Render Management (`scripts/flow/flow-engine.lua`):** Created `flow_engine.clear_flow_renders` and `flow_engine.draw_flow` to manipulate pressure flow circles, text labels, and vector lines independently from counter sensing range overlays.
2. **Per-Player Overlay Destruction Bounds (`scripts/flow/flow-engine.lua`):** Refactored `destroy_pos_renders`, `destroy_counter_renders`, and `destroy_edge_render` to support optional `player_index` targeting, preventing single-player overlay clears from destroying rendering objects for other players in multiplayer.
3. **Decoupled Debug Command & GUI Toggles (`scripts/debug-manager.lua`):** Refactored `toggle_new_flow`, `toggle_counter_range`, `toggle_master`, and GUI event handlers to call domain-specific draw/clear methods rather than blanket `clear_all_renders`, preserving counter range overlays when flow overlays are disabled.


### Revision: Hub Capsule Nesting Default Off & Setting Encapsulation
**Date:** 2026-09-07 22:02 (EDT)
**Context:** Change the hub capsule nesting default state to disabled (`false`) and encapsulate status checks behind a centralized settings helper function, ensuring newly placed hubs immediately transport standard cargo and eliminating duplicated fallback logic.
**Key Changes:**
1. **Default State & Helper Registration (`scripts/hubs/hub-settings.lua`):** Updated the default `nest_capsules` property to `false` across storage initialization, copy-paste cloning, and blueprint tag deserialization routines. Registered `hub_settings.is_nesting_enabled` helper function to centralize truth evaluation.
2. **Packing Engine Integration (`scripts/hubs/hub-packing.lua`):** Refactored `evaluate_inventory` to inspect nesting permissions via `hub_settings.is_nesting_enabled`, allowing hubs to default to standard item cargo packing upon placement without requiring manual GUI intervention.
3. **GUI State Alignment (`scripts/hubs/hub-gui.lua`):** Updated relative container GUI initialization to set the "Nest capsules" checkbox state directly from `hub_settings.is_nesting_enabled`.


### Revision: Bio Capsule Shell Lifecycle & Net Cargo Capacity Tooltips
**Date:** 2026-09-07 22:42 (EDT)
**Context:** Refactor single-use capsule lifecycle so biological primary capsule shells travel in-transit with cargo, dissolve strictly upon destination unpacking or spills, and accurately report net cargo stack capacities in locale tooltips.
**Key Changes:**
1. **Primary Shell Packing Priority (`scripts/hubs/hub-packing.lua`):** Swapped holder inventory insertion order to transfer primary capsule shells (`include_self`) into slot 1 before cargo extractions, preventing bio capsule shells from being displaced or destroyed at the origin hub during packing.
2. **Single-Use Dissolution & Unpacking (`scripts/hubs/hub-unpacking.lua`):** Updated `can_insert_all` to ignore primary shell slots for `destroy_self` capsules when checking destination chest capacity, clearing the shell (`holder_inv[ignore_slot].clear()`) upon arrival prior to cargo stack transfers.
3. **In-Transit Spill Dissolution (`scripts/hubs/hub-spill.lua`):** Updated `spill_capsule` to inspect `capsule_def.destroy_self` and clear primary shell slots prior to spilling cargo onto the ground or into spill containers, dissolving bio capsule shells cleanly during mid-transit ruptures or entity destructions.
4. **Net Cargo Stack Locale Tooltips (`locale/en/config.cfg`):** Updated item descriptions for `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, and `reinforced-capsule` to report net usable cargo stack counts (1, 1, 2, 2, 5) matching actual cargohold limits.


### Revision: Explicit Net Cargo Capacity Schema & Liminal Bar Limit Refactor
**Date:** 2026-09-07 23:20 (EDT)
**Context:** Standardize capsule capacity declarations around explicit net usable cargo slots (`cargo_capacity`) and adjust liminal holder inventory bar limits in `hub-packing.lua` to dynamically accommodate fractional-cost items.
**Key Changes:**
1. **Explicit Net Cargo Capacity Schema (`scripts/capsules/capsule-definitions.lua`):** Replaced total-container offset properties (`base_capacity` with `include_self = true`) across all capsule prototypes with explicit net usable cargo capacities (`cargo_capacity`), declaring that normal bio and standard item capsules hold 1 net cargo slot, refrigerated capsules hold 2, reinforced capsules hold 5, and player transit capsules hold 0.
2. **Fractional Slot Cost Bar Limit Calculation (`scripts/hubs/hub-packing.lua`):** Fixed a bug where `dest_inv.set_bar()` derived physical container slot limits directly from total capacity rather than dividing by `min_slot_cost`. Calculating physical holder slots via `math.floor(max_cargo_slots / min_slot_cost)` unlocks the necessary container slots (e.g., 3 physical slots for 1 primary shell + 2 bio items at 0.5 cost) without payload truncation.


### Revision: Bio-Capsule Rupture Risk Deprecation & Tech Tree Streamlining
**Date:** 2026-09-08 08:23 (EDT)
**Context:** Deprecate punitive mid-transit rupture mechanics and research upgrade tiers for biodegradable capsules, while adding missing technology locale definitions to resolve UI errors.
**Key Changes:**
1. **Bio-Capsule Definition & Lifecycle Refactor (`scripts/capsules/capsule-definitions.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Removed `spill_risk` property from `biodegradable-capsule` and purged research tier calculations (`bio_integrity_levels`) and event listeners from `capsule-lifecycle.lua`, while preserving the generic `spill_risk` evaluation framework for extensible capsule support.
2. **Technology Tree Streamlining (`prototypes/technology.lua`):** Removed the four `bio-capsule-integrity-1` through `4` upgrade technology nodes, retaining strictly the baseline `biodegradable-capsule` research unlock node.
3. **Locale Completion & Rupture Text Purge (`locale/en/config.cfg`):** Removed all item and technology locale descriptions referencing transit rupture risks and integrity upgrades. Added missing localized technology captions and descriptions for `biodegradable-capsule`, `reinforced-capsule`, and `refrigerated-capsule` to eliminate "Unknown key" UI rendering errors.
4. **Storage Cleanup (`control.lua`):** Deprecated `storage.bio_integrity_levels` persistent tracking table across runtime initialization and configuration change handlers.


### Revision: Capsule Counter Dedicated Technology & Legacy Engine Purge
**Date:** 2026-09-08 08:36 (EDT)
**Context:** Introduce a dedicated research node for the Pneumatic Capsule Counter requiring Circuit Network technology, while purging residual legacy v1 flow engine references from settings, locale, and runtime comments.
**Key Changes:**
1. **Capsule Counter Dedicated Research (`prototypes/technology.lua` & `locale/en/config.cfg`):** Created the `capsule-counter` technology node (prerequisites: `pneumatic-transport`, `circuit-network`; 100 cycles @ 30s) unlocking the `pneumatic-capsule-counter` recipe. Unlinked the counter unlock from baseline `pneumatic-transport` technology. Added localized English title and description while updating `pneumatic-transport` locale text to reflect the decoupled research tree.
2. **Legacy v1 Flow Engine Cleanup (`locale/en/config.cfg`, `settings.lua` & `control.lua`):** Removed obsolete `pneumatic-flow-version` mod setting locale keys from `config.cfg`. Purged lingering comments referencing legacy v1 flow network graph/builder settings across `settings.lua` and `control.lua`.


### Revision: Reinforced Capsule Bulk Enforcement & Electromagnetic Capsule Fulgora Integration
**Date:** 2026-09-08 09:14 (EDT)
**Context:** Enforce strict single-type full-capacity bulk transport for reinforced capsules and implement the Fulgora electromagnetic capsule allowing unrestricted mixed-cargo transit.
**Key Changes:**
1. **Reinforced Capsule Bulk Constraint Enforcement (`scripts/capsules/capsule-definitions.lua` & `locale/en/config.cfg`):** Refactored `reinforced-capsule` properties (`mixed_cargo = false`, `mixed_quality = "strict"`, `minimum_cargo = "ceil"`, `full_stacks = true`) to enforce strict bulk transport, requiring all cargo slots to be completely filled with a single item type of uniform quality before packing.
2. **Electromagnetic Capsule Definition (`scripts/capsules/capsule-definitions.lua`):** Registered `electromagnetic-capsule` with 2 net usable cargo slots (+1 per quality tier), configured with `mixed_cargo = true`, `mixed_quality = "any"`, `minimum_cargo = 1`, and `full_stacks = false` to enable unrestricted mixing of item types, partial stack quantities, and qualities.
3. **Prototype & Recipe Declarations (`prototypes/item.lua` & `prototypes/recipe.lua`):** Registered `electromagnetic-capsule` item prototype (stack size 1, subgroup `pneumatic-capsules`, order `f[electromagnetic]`) with a Holmium pink-magenta tint, and added its crafting recipe requiring 5 superconductors, 2 low-density structures, and 10 scrap.
4. **Technology Research Node (`prototypes/technology.lua`):** Created the `electromagnetic-capsule` research node (prerequisites: `electromagnetic-science-pack`, `pneumatic-transport`, `electromagnetic-plant`; 250 cycles @ 45s) unlocking the electromagnetic capsule recipe, featuring the superconductor icon with Holmium pink-magenta tinting.
5. **Locale Definitions (`locale/en/config.cfg`):** Added English localized names and descriptions for the electromagnetic capsule item, recipe, and technology while updating reinforced capsule descriptions to reflect the strict full-capacity bulk transport rule.


### Revision: Stack-Proportional Fractional Capacity & Smart Post-Packing Inventory Bar Clamping
**Date:** 2026-09-08 09:42 (EDT)
**Context:** Implement the `mixed_quantity` capacity accounting flag for electromagnetic capsules to scale slot costs by item stack size, and replace static upfront inventory bar clamping guesswork on liminal holders with dynamic post-packing clamping.
**Key Changes:**
1. **Electromagnetic Capsule Fractional Capacity Schema (`scripts/capsules/capsule-definitions.lua`):** Added `mixed_quantity = true` to `electromagnetic-capsule` prototype definition and explicitly set `mixed_quantity = false` across all other capsule prototypes.
2. **Fractional Slot Cost Planning Engine (`scripts/hubs/packing/cargo-planner.lua`):** Updated `plan_single_type_cargo` in `cargo-planner.lua` to calculate per-item unit slot costs (`base_slot_cost / stack_size`) when `mixed_quantity` is enabled, enabling partial item stacks to consume fractional capsule volume proportional to their item count.
3. **Smart Dynamic Post-Packing Inventory Bar Clamping (`scripts/hubs/hub-packing.lua`):** Replaced static upfront inventory bar clamping math on the hidden liminal holder with dynamic post-packing clamping. Transfers primary shell and cargo extractions using full inventory depth (`max_search = #dest_inv`), evaluates the highest occupied slot index (`last_occupied_slot`), and sets `dest_inv.set_bar(last_occupied_slot + 1)` to lock trailing empty slots cleanly.


### Revision: Standard Capsule Quality-Clamped Multi-Cargo Schema & Locale Refactor
**Date:** 2026-09-08 10:11 (EDT)
**Context:** Refactor the Standard Pneumatic Capsule into a quality-clamped multi-stack logistics backbone, allowing mixed item types and qualities up to the capsule's quality tier without overlapping with strict bulk or partial-stack container roles.
**Key Changes:**
1. **Quality-Clamped Multi-Cargo Schema (`scripts/capsules/capsule-definitions.lua`):** Configured `item-capsule` with `mixed_cargo = true`, `mixed_quality = "any"`, `quality_filter = "ceil"`, `minimum_cargo = 2`, and `full_stacks = true`. Enables multi-item and multi-quality transport clamped to the capsule's quality tier while requiring full item stacks and dispatching as soon as 1 full stack is loaded.
2. **Locale Description Alignment (`locale/en/config.cfg`):** Updated localized English item description for `item-capsule` to explicitly communicate its full-stack, quality-clamped mixed cargo capacity rules.


### Revision: Biological Capsule Restrictions & Normalized Base Cargo Capacity
**Date:** 2026-09-08 11:33 (EDT)
**Context:** Restrict refrigerated capsules strictly to biological cargo and normalize baseline stack capacities across all capsule variants to establish a clear quality scaling progression and eliminate capacity power spikes.
**Key Changes:**
1. **Refrigerated Biological Restriction & Schema Alignment (`scripts/capsules/capsule-definitions.lua` & `scripts/hubs/hub-packing.lua`):** Configured `bio_only = true` on `refrigerated-capsule` and `spent-refrigerated-capsule` prototypes and added a `bio_only` validation check (`not capsule_def.bio_only or capsule_defs.is_bio_item(item_name)`) to the item candidate loop in `hub-packing.lua` to exclude non-biological items from loading into refrigerated shells.
2. **Normalized Base Capacity & Quality Scaling Schema (`scripts/capsules/capsule-definitions.lua`):** Standardized base cargo capacities across all capsule prototypes: set Standard, Biodegradable, Refrigerated, Spent Refrigerated, and Electromagnetic capsules to base capacity 1 stack (`cargo_capacity = 1`, `quality_affected_capacity = 1`), and Reinforced capsules to base capacity 2 stacks (`cargo_capacity = 2`, `quality_affected_capacity = 2`).
3. **Locale Description Updates (`locale/en/config.cfg`):** Updated English localized descriptions for `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, and `electromagnetic-capsule` to clearly communicate biological cargo restrictions and updated stack capacity scaling rules.


### Revision: Vacuum Capsule Data Prototypes, Tech Tree & Locale Registration
**Date:** 2026-09-08 11:57 (EDT)
**Context:** Implement Task 1 of the Vacuum Capsule plan, registering item, tool, recipe, technology research node, English locale, and capsule definition schemas for the vacuum capsule and spent shell ahead of transport belt siphoning engine integration.
**Key Changes:**
1. **Item & Tool Declarations (`prototypes/item.lua`):** Registered `vacuum-capsule` as a tool prototype (durability 100, order `g[vacuum]`) with a deep vacuum blue icon tint, and registered `spent-vacuum-capsule` item (stack size 1, order `h[spent-vacuum]`) under the `pneumatic-capsules` subgroup.
2. **Crafting & Recharge Recipes (`prototypes/recipe.lua`):** Added crafting recipe for `vacuum-capsule` requiring processing units, low-density structures, and accumulators, and added `recharge-vacuum-capsule` recipe requiring a spent capsule shell and 2 batteries under subgroup `pneumatic-capsules`.
3. **Space Science Technology Node (`prototypes/technology.lua`):** Created the `vacuum-capsule` research node (prerequisites: `space-science-pack`, `pneumatic-transport`; 250 cycles @ 45s) unlocking the vacuum capsule crafting and assembly recharging recipes.
4. **Capsule Definition Registry (`scripts/capsules/capsule-definitions.lua`):** Registered `vacuum-capsule` and `spent-vacuum-capsule` schemas configured with 1 net usable cargo slot (+1 per quality tier), full stack enforcement, quality-clamped cargo rules (`quality_filter = "ceil"`), `spent_capsule_item` transition link, and distinct RGBA debug overlay colors.
5. **English Locale Definitions (`locale/en/config.cfg`):** Added localized names, tooltips, and descriptions for `vacuum-capsule` and `spent-vacuum-capsule` items, recipes, and technology research nodes.


### Revision: Transport Belt Siphon Engine & Vacuum Capsule Hub Siphoning
**Date:** 2026-09-08 12:37 (EDT)
**Context:** Implement Task 2 of the Vacuum Capsule plan, creating the transport belt siphoning engine in `belt-siphon.lua` and integrating automated belt extraction into `hub-packing.lua`.
**Key Changes:**
1. **Vacuum Capsule Schema Property (`scripts/capsules/capsule-definitions.lua`):** Configured `siphon_belts = true` on the `vacuum-capsule` prototype definition schema.
2. **Dumb Belt Siphon Helper Module (`scripts/hubs/packing/belt-siphon.lua`):** Created `belt-siphon.lua` to locate adjacent transport belts, underground belt hoods, splitters, and linked belts touching a Hub entity's bounding box. Scanned Factorio 2.0 `LuaTransportLine.get_contents()` item arrays and extracted available items using `line.remove_item()` while respecting Hub inventory slot filters (`inventory.is_filtered()`).
3. **Hub Chest Loading & Packing Integration (`scripts/hubs/hub-packing.lua`):** Integrated `belt_siphon.siphon_to_chest` into `hub_packing.evaluate_inventory` to pull cargo directly off touching belts into the Hub container when a `vacuum-capsule` is present, enabling inserter-free belt unloading while maintaining standard full-stack cargo packing rules.
4. **Real-Time Diagnostic Logging (`scripts/hubs/packing/belt-siphon.lua` & `scripts/hubs/hub-packing.lua`):** Added real-time chat log prints (`[BeltSiphon]` and `[HubPacking]`) tracking Hub evaluation, touching belt counts, transport line item contents, and extraction results.


### Revision: Vacuum Capsule Per-Item Durability Drain & In-Chest Spent Conversion
**Date:** 2026-09-08 12:59 (EDT)
**Context:** Implement Task 3 of the Vacuum Capsule plan, enforcing per-item durability drain during belt siphoning, immediate in-chest conversion to spent capsule shells upon charge depletion, and native C++ inventory filter checks.
**Key Changes:**
1. **Per-Item Charge Consumption & Durability Drain (`scripts/hubs/packing/belt-siphon.lua`):** Refactored `siphon_to_chest` in `belt-siphon.lua` to cap belt extractions by remaining tool durability (`max_take = math.min(item_count, stack_size, math.floor(cur_dur))`). Updated durability tracking to deduct exactly 1 durability point per individual siphoned item rather than per batch extraction.
2. **In-Chest Spent Capsule Conversion (`scripts/hubs/packing/belt-siphon.lua` & `scripts/hubs/hub-packing.lua`):** Implemented instant spent shell conversion (`spent-vacuum-capsule`) directly inside the hub chest inventory when a vacuum capsule's durability hits 0, preserving quality tiers and equipment grids. Updated `hub-packing.lua` to adopt converted spent capsule handles seamlessly during packing evaluations.
3. **Native Filter & Slot Selection Alignment (`scripts/hubs/packing/belt-siphon.lua`):** Removed the `passes_hub_filters` helper function which blocked siphoning on partially filtered chests, delegating slot filter, red bar slider, and slot availability validation directly to Factorio's native `chest_inv.can_insert()` C++ API.


### Revision: Item Health Charge System & Belt Siphoning Bug Fixes
**Date:** 2026-09-08 14:49 (EDT)
**Context:** Resolve non-recoverable Lua API errors (`Item is not tool`, `LuaItemPrototype doesn't contain key durability`), fix stuck vacuum capsule durability depletion, and prevent Factorio's native tool durability merge engine from destroying capsule items during hand or inventory transfers.
**Key Changes:**
1. **Item Prototype & Hand-Merge Prevention (`prototypes/item.lua`):** Converted `vacuum-capsule` and `refrigerated-capsule` from `type = "tool"` to standard `type = "item"` with `stack_size = 1`. This prevents Factorio's native C++ tool durability merging algorithm from combining damaged tool stacks and deleting capsule items when clicked or moved by hand.
2. **Health-Based Charge Tracking (`scripts/hubs/packing/belt-siphon.lua` & `scripts/capsules/capsule-lifecycle.lua`):** Refactored charge tracking for vacuum and refrigerated capsules to use `stack.health` (0.0 to 1.0) instead of `stack.durability`. Eliminates invalid prototype/itemstack property index crashes while rendering a native charge health bar on capsule icons.
3. **Lua Item Transfer Guard (`scripts/utils/item-transfer-handler.lua`):** Fixed boolean operator evaluation (`and` instead of `or`) when inspecting tool properties on `LuaItemStack` during `transfer_stack()`, preventing C++ exceptions on standard non-tool cargo items.
4. **Dumb Siphon & Spent Conversion Engine (`scripts/hubs/packing/belt-siphon.lua`):** Updated belt siphoning charge calculations to use `math.ceil` so fractional charges extract final items down to zero, automatically converting depleted capsules to `spent-vacuum-capsule` shells while respecting native hub container filters and red-bar slot limits.


### Revision: Belt Siphon Decoupling & Independent Hub Siphoning Lifecycle
**Date:** 2026-09-08 15:15 (EDT)
**Context:** Decouple transport belt siphoning from the capsule packing and dispatch pipeline, elevating belt siphoning to an independent top-level Hub process in `hub-manager.lua` to run as a dumb inserter regardless of primary capsule selection or send/receive settings.
**Key Changes:**
1. **Top-Level Hub Siphon Lifecycle (`scripts/hubs/hub-manager.lua`):** Registered `belt_siphon` as a top-level require in `hub-manager.lua` and integrated `belt_siphon.siphon_to_chest(entity)` into the 10-tick background scan loop (`on_tick`) and `notify_settings_changed`, executing belt extractions unconditionally on active hubs containing a charged vacuum capsule.
2. **Packing Pipeline Clean Decoupling (`scripts/hubs/hub-packing.lua`):** Removed all belt siphoning calls and `belt-siphon` module imports from `hub-packing.lua`, eliminating the artificial restriction where vacuum capsules were blocked from siphoning unless selected as the first capsule for immediate dispatch.
3. **Primary Stack Insertion Fix (`scripts/hubs/hub-packing.lua`):** Fixed a syntax error on line 303 in `hub-packing.lua` by removing an extraneous token inside the primary capsule holder stack transfer loop.


### Revision: Quality-Scaled Capsule Charges & Health Drain Integration
**Context:** Restore quality-scaled charges (durability/health) for `vacuum-capsule` and `refrigerated-capsule` following their transition from tool prototypes to standard items with health percentage.
**Key Changes:**
1. **Dynamic Quality Charge Scaling Helper (`scripts/capsules/capsule-definitions.lua`):** Added `capsule_definitions.get_max_charges(def_or_name, quality_arg)` implementing standard Factorio quality scaling (`base * (1 + 0.3 * quality_level)`), yielding 100 charges at Normal, 130 at Uncommon, 160 at Rare, 190 at Epic, and 250 at Legendary. Added explicit `durability = 100` base charges to the `refrigerated-capsule` definition.
2. **Quality-Aware Belt Siphoning Engine (`scripts/hubs/packing/belt-siphon.lua`):** Updated `belt_siphon.siphon_to_chest` to evaluate max charges via `capsule_defs.get_max_charges(capsule_def, capsule_stack.quality)`, enabling higher-quality vacuum capsules to siphon proportionally more items off transport lines before depleting into spent shells.
3. **Refrigerated Spoilage Charge Scaling (`scripts/capsules/capsule-lifecycle.lua`):** Updated `capsule_lifecycle.update` to scale active cooling capacity against quality tier using `capsule_defs.get_max_charges(caps_def, stack.quality)`, extending active refrigeration duration proportionally with capsule quality tier.


### Revision: Pressure-Driven Belt Depositing, Near-Lane Sideloading & Gleba Stacking Integration
**Date:** 2026-09-08 19:12 (EDT)
**Context:** Transform the vacuum capsule belt interface from an agnostic siphon into a bidirectional, pressure-governed pneumatic system supporting automated belt depositing, strict orthogonal footprint checks, near-lane parallel sideloading, Space Age Gleba belt stacking, and tiered cargo ejection.
**Key Changes:**
1. **Pressure-Driven Siphon & Exhaust Engine (`scripts/hubs/packing/belt-siphon.lua`):** Added `get_hub_net_pressure` to evaluate net pneumatic pressure across Hub ports. Negative net pressure ($P_{\text{net}} < 0$) initiates vacuum siphoning off belts, positive net pressure ($P_{\text{net}} > 0$) triggers pneumatic exhaust depositing from chest onto belts, and neutral pressure ($P_{\text{net}} = 0$) keeps the hub idle to preserve charges.
2. **Strict Orthogonal Adjacency Guard (`scripts/hubs/packing/belt-siphon.lua`):** Implemented `is_strictly_adjacent` using axis-aligned bounding box projection. Rejects diagonal corners and belts extending beyond container bounds (such as belts flanking attached pneumatic tubes), restricting belt interaction strictly to tiles directly facing container walls.
3. **Near-Lane Parallel Sideloading (`scripts/hubs/packing/belt-siphon.lua`):** Implemented `get_deposit_line_indices` to determine active transport lines based on belt orientation and Hub contact wall. Parallel passing belts strictly sideload onto the near transport line touching the Hub (leaving the far lane open for independent logistics), while outbound head-on belts access all available lines.
4. **Gleba Belt Stacking Support (`scripts/hubs/packing/belt-siphon.lua`):** Integrated `force.belt_stack_size_bonus` into `deposit_to_belts` to calculate `max_belt_stack` (1 base, up to 4 with Space Age research). Deposits vertical item stacks up to the researched limit in a single drop via `line.insert_at_back(spec, allowed_stack)`, deducting 1 health charge point per individual item placed.
5. **Two-Tier Cargo Ejection & Self-Protection (`scripts/hubs/packing/belt-siphon.lua`):** Implemented `find_deposit_candidate_slot` to enforce cargo priority during belt ejection. The active working capsule cannot eject itself from the chest; Tier 1 prioritizes regular cargo items and inert spent shells (`spent-vacuum-capsule`), and Tier 2 only ejects surplus charged vacuum capsules once all Tier 1 items have been cleared.


### Revision: Capsule Recipe Economics, Recharge Loops & Durability Rebalance
**Date:** 2026-09-08 19:57 (EDT)
**Context:** Eliminate prohibitive operational resource drains on vacuum capsule belt siphoning, expand refrigerated capsule active cooling lifespan to prevent rapid expiration during logistics backpressure, and rebalance single-use biodegradable capsule crafting into an accessible organic packaging loop.
**Key Changes:**
1. **Vacuum Siphon Durability & Electric Repressurization (`prototypes/recipe.lua`, `scripts/capsules/capsule-definitions.lua`):** Raised `vacuum-capsule` base durability from 100 to 500 charges (scaling to 1,250 charges at Legendary). Overhauled `recharge-vacuum-capsule` to remove the 2-battery raw-resource tax in favor of closed-loop electric repressurization requiring only `spent-vacuum-capsule = 1` (`energy_required = 2.0`), and added `allow_productivity = false` to prevent duplication exploits.
2. **Refrigerated Cooling Lifespan Expansion (`scripts/capsules/capsule-definitions.lua`, `prototypes/recipe.lua`):** Increased `refrigerated-capsule` base durability from 100 to 600 charges, expanding active refrigeration from 1.6 minutes to 10 minutes at Normal quality (scaling up to 25 minutes at Legendary). This prevents single-trip deadheading and protects perishable cargo against queue backpressure. Added `allow_productivity = false` to `recharge-refrigerated-capsule`.
3. **Biodegradable Capsule Yield & Organic Repackaging (`prototypes/recipe.lua`, `prototypes/technology.lua`):** Replaced high-tier `carbon-fiber` and `sulfuric-acid` inputs on `biodegradable-capsule` with foundational Gleba staples (`1 yumako-mash`, `1 jelly`, `2 spoilage`) and raised output yield from 4 to 10 capsules (yielding 15 in Biochambers). Removed `carbon-fiber` and `sulfur-processing` technology prerequisites, gating the unlock directly on `agricultural-science-pack` and `pneumatic-transport`.


### Revision: Pneumatic Fence Gate Interoperability, Wall Axis Locking & Wavefront Discovery
**Date:** 2026-09-09 10:30 (EDT)
**Context:** Enable vanilla walls and fence gates to interface directly with the pneumatic logistics network without creating duplicate prototypes, implementing research gating, orthogonal exclusive-axis crossflow on walls, natural open/close wavefront cutoff on gates, and reactive grid-touch lazy discovery.
**Key Changes:**
1. **Interoperability Research Technology (`prototypes/technology.lua`):** Added the `pneumatic-fence-gate-interoperability` research node (prerequisites: `pneumatic-transport` and `gate`, 150 cycles @ 30s) authorizing the flow engine to link vanilla `stone-wall` and `gate` entities into pneumatic routing.
2. **Vanilla Wall & Gate Port Definitions (`scripts/flow/port-defs.lua`):** Added port definitions for `stone-wall` (4 boundary ports split into isolated dual-channel groups: Group 1 North/South, Group 2 West/East) and `gate` (2 directional inline boundary ports per orientation). Added explicit cardinal normal vectors (`dir = {x, y}`) to all port definitions on counters, walls, and gates, eliminating diagonal projection errors during boundary discovery off multi-tile 2x1 entities. Restricted `port_defs.registered_names` strictly to dedicated pneumatic structures to prevent global surface scans on startup from registering map perimeter walls.
3. **Reactive Grid-Touch & Queue-Driven Discovery (`scripts/flow/flow-engine.lua`):** Implemented `is_touching_pneumatic_grid` in `build_events` to immediately connect standard entities placed directly touching active ports (`storage.flow_grid`) and enqueue neighbors in O(1) time without registering unlinked perimeter defense walls. Configured open boundary wavefront propagation in `step()` to lazily discover and connect single adjacent entities tile-by-tile within the flow queue without recursive BFS flood-fills.
4. **Wall Single-Axis Lock & Depressurization Crossflow Wakeup (`scripts/flow/flow-engine.lua`):** Implemented exclusive directional axis locking on `stone-wall` (`storage.wall_locked_group`) triggered by either pressure flow ($P \ne 0$) or sensing range ($S > 0$), disabling transmission on the idle orthogonal pair. Complete depressurization ($P=0, S=0$) clears the lock, restores all transmission flags to `true`, and enqueues ports while calling `wake_port_parked` to wake queued crossflow capsules.
5. **Terminator Gate State Cutoff & Regrowth (`scripts/flow/flow-engine.lua`):** Implemented `is_gate_terminator` to identify boundary gate endpoints in O(1) time. Opening a gate disables transmission flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`) strictly on outer terminator gates while leaving interior gates active as standard pass-through tubes, allowing downstream pressure to naturally recede tile-by-tile through `flow_queue`. Closing any gate restores all transmission flags to `true` and enqueues ports to step pressure forward through the crossing.
6. **Sensing Flow Wavefront & Counter Parity (`scripts/flow/flow-engine.lua`):** Added dynamic counter registration into `storage.active_counters` and power tracking in `connect_entity`, ensuring sensing range wavefronts ($15$ decaying down to $1$) participate in the exact same boundary discovery, wall-axis locking, and queue advancement schemes as pressure flow.


### Revision: Fence Gate Sensing Persistence & Throttled Interop Activation Queue
**Date:** 2026-09-09 10:52 (EDT)
**Context:** Maintain continuous Capsule Counter sensing across open fence gate thresholds while physically containing cargo and gas pressure, and introduce a lightweight, rate-limited soft-registration and activation queue for standard defensive walls and gates placed adjacent to active flow ports prior to completing interoperability research.
**Key Changes:**
1. **Gate Crossing Sensing Continuity (`scripts/flow/flow-engine.lua`):** Updated terminator gate transition logic in `flow_engine.step` to strictly disable `capsule_transmit = false` and `pressure_transmit = false` upon opening while leaving `sense_transmit = true` intact. This prevents Capsule Counters from dropping territorial ownership or zeroing cargo signals when gates open for passing trains, vehicles, or players.
2. **Immediate Boundary Soft-Registry (`scripts/flow/flow-engine.lua`):** Added `flow_engine.is_touching_active_flow` and `storage.soft_interop_registry` to pre-emptively index unresearched `stone-wall` and `gate` entities built immediately facing ports with active pressure ($P \ne 0$), sensing range ($S > 0$), or active pump/diverter emitters. Extended lazy discovery in `discover_adjacent_standard_entity` to register boundary walls when active flow reaches them, enforcing strict single-tile non-chaining to protect map perimeter walls from premature registration.
3. **Throttled Multi-Tick Research Activation (`scripts/flow/flow-engine.lua`):** Added `on_research_finished` listener for `pneumatic-fence-gate-interoperability`, migrating force-matching soft-registered entities into `storage.interop_activation_queue` in O(1) time without synchronous entity connections. Configured `flow_engine.step` to drain a rate-limited batch (`INTEROP_BATCH_SIZE = 10`) each tick, connecting boundary nodes, waking parked capsules, and feeding downstream wall runs smoothly into `storage.flow_queue` without single-frame lag spikes.


### Revision: Blueprint Ghost Gate Crash Fix & Active State Decoupling
**Date:** 2026-09-09 12:33 (EDT)
**Context:** Resolve non-recoverable `Entity is not gate` runtime crash triggered when stamping blueprints containing gate entities, establishing clean separation between blueprint ghost spatial topology and physical runtime simulation polling.
**Key Changes:**
1. **Physical Entity Filter for Dynamic Polling (`scripts/flow/flow-engine.lua`):** Updated `flow_engine.connect_entity` to register entities into active state tables (`storage.active_gates` and `storage.active_counters`) strictly when `entity.name == "gate"` or `entity.name == "pneumatic-capsule-counter"`. Blueprint ghosts (`entity-ghost`) bypass open/closed state tracking while still cleanly registering spatial port nodes into `storage.flow_nodes` and `storage.flow_grid` for connection continuity.
2. **Elimination of Ghost C++ Method Assertions (`scripts/flow/flow-engine.lua`):** Prevented calling gate-specific C++ member function `entity.is_closed()` on ghost entities during blueprint stamping and background `step()` ticks. Physical gates are seamlessly promoted into active state polling when built/revived by construction robots without requiring redundant defensive guards across pumps and diverters.


### Revision: Blueprint Ghost Simulation Exclusion & Pure Visual Parity
**Date:** 2026-09-09 12:39 (EDT)
**Context:** Prevent unbuilt blueprint ghost entities (`entity-ghost`) from participating in runtime pneumatic flow, sensing wavefront propagation, and pre-emptive soft-registration prior to physical construction by robots.
**Key Changes:**
1. **Flow Grid Ghost Exclusion Guard (`scripts/flow/flow-engine.lua`):** Added an early-exit guard (`if entity.name == "entity-ghost" then return end`) at the entry of `flow_engine.connect_entity`. Blueprint ghost tubes, walls, gates, and counters no longer create physical port nodes, channel pressure, or display phantom Alt-Mode sensing overlays before being physically built.
2. **Ghost Suppression in Build Listeners (`scripts/flow/flow-engine.lua`):** Added an immediate ghost check to the top-level `build_events` listener, preventing unbuilt ghost walls and gates from entering `storage.soft_interop_registry` prematurely. Construction robot builds and revives (`on_robot_built_entity`, `script_raised_revive`) naturally pass physical entities through to connection and registration the exact tick they become physical matter.


### Revision: Space Age Machine Categories, Rocket Payload Capacity & Locale Sync
**Date:** 2026-09-09 14:38 (EDT)
**Context:** Align specialized Space Age capsule recipes with their planetary signature production facilities, eliminate the 1-capsule-per-rocket shipping bottleneck on single-stack items, and synchronize the English locale to remove stale tooltips and add missing research and proxy entries.
**Key Changes:**
1. **Planetary Super Machine Crafting Categories (`prototypes/recipe.lua`):** Standardized recipe `categories` tables across specialized capsules to leverage planetary machine bonuses: set `reinforced-capsule` to `{"metallurgy"}` (Foundry, +50% productivity), `electromagnetic-capsule` to `{"electromagnetics"}` (Electromagnetic Plant, +50% productivity), `refrigerated-capsule` and `recharge-refrigerated-capsule` to `{"cryogenics"}` (Cryogenic Plant), and `vacuum-capsule` and `recharge-vacuum-capsule` to explicit `{"crafting"}` (Assembling Machine).
2. **Capsule Rocket Capacity & Weight Scaling (`prototypes/item.lua`):** Configured explicit `weight = 50 * kg` across all nine active and spent capsule prototypes (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, `electromagnetic-capsule`, `vacuum-capsule`, `spent-vacuum-capsule`, and `player-transit-capsule`). This overrides the default 1,000 kg fallback calculation ($1000\text{ kg} / \text{stack\_size}$), establishing a clean 20-capsule rocket capacity per launch ($1000\text{ kg} / 50\text{ kg} = 20$) for both initial deployments and returning spent shell logistics.
3. **Fence Gate Interoperability & Proxy Localization (`locale/en/config.cfg`):** Added missing localized names and descriptions for the `pneumatic-fence-gate-interoperability` research node. Added entity names for hidden channel proxies (`pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy`) to ensure full engine parity.
4. **Recharging Loop & Tech Description Corrections (`locale/en/config.cfg`):** Replaced outdated assembling machine recharging descriptions on `refrigerated-capsule` and `spent-refrigerated-capsule` with Cryogenic Plant instructions; updated `recharge-vacuum-capsule` description to reflect closed-loop electric repressurization instead of obsolete battery consumption; and corrected `specialized-pneumatic-capsules` tech description to accurately list diverters, crossflow junctions, and player transit capsules instead of planet-bound variants.
5. **Custom Input & UI Control Strings (`locale/en/config.cfg`):** Added localization entries for custom inputs (`pneumatic-copy-settings`, `pneumatic-paste-settings`, `pneumatic-confirm-gui`) and registered shortcut and debug panel toggles for Capsule Counter range overlays (`pt-toggle-counter-range`, `toggle-counter-range`).


### Revision: Fence Gate Interop Reversal, Boundary Cutoff & Zero-Level Soft Demotion
**Date:** 2026-09-09 15:07 (EDT)
**Context:** Ensure graceful, non-destructive flow recession and full lifecycle idempotence when `pneumatic-fence-gate-interoperability` research is reversed (via Map Editor, console `/reset-technologies`, or tech overhaul mods), avoiding abrupt node deletions, stranding in-flight capsules, or leaving orphaned wall nodes in persistent storage.
**Key Changes:**
1. **Research Reversal Event Listener (`scripts/flow/flow-engine.lua`):** Registered a listener for `defines.events.on_research_reversed` filtering for `pneumatic-fence-gate-interoperability`, routing directly to `flow_engine.handle_interop_research_reversed` to initiate orderly network unlinking.
2. **Direct Entity Reference Storage (`scripts/flow/flow-engine.lua`):** Upgraded `storage.active_walls[unit_number]` from a boolean `true` flag to store the live `LuaEntity` reference, bringing it to parity with `active_gates` and enabling instant O(1) force-matching checks without redundant surface queries.
3. **Boundary Cutoff & Interface Queue Injection (`scripts/flow/flow-engine.lua`):** Implemented `handle_interop_research_reversed` to systematically identify and sever only the boundary connection edges where registered pneumatic infrastructure interfaces with walls and gates. Destroys Alt-Mode boundary vector lines, enqueues both the pneumatic and wall interface ports into `storage.flow_queue`, wakes parked capsules (`wake_port_parked`), and returns queued activation entities back to `storage.soft_interop_registry`.
4. **Zero-Equilibrium Soft Demotion (`scripts/flow/flow-engine.lua`):** Extended `flow_engine.step` to monitor depressurizing walls and gates. When an unresearched wall or gate reaches absolute equilibrium (P = 0, S = 0) across all port channels, it calls `flow_engine.disconnect_entity()` and transitions the structure into `storage.soft_interop_registry`, ensuring complete lifecycle reversibility without memory leaks or stranded capsules.


### Revision: Fast-Replace & Quality Upgrade Settings Inheritance
**Date:** 2026-09-09 16:46 (EDT)
**Context:** Prevent loss of custom port configurations, circuit conditions, filters, and container nesting rules when fast-replacing or upgrading pneumatic machines in-place from player inventory or via construction robots.
**Key Changes:**
1. **Fast-Replace Co-Existence Spatial Query (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Extended `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` with an `exclude_entity` parameter, enabling reliable discovery of co-existing real machines occupying the exact tile coordinate during the engine's fast-replace transition window.
2. **Destruction-Phase Proactive Settings Transfer (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Updated entity removal listeners (`destroy_events`, `on_hub_removed`) to detect active replacement entities on the surface and execute direct deep-copy settings migration (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `hub_settings.copy`) prior to wiping the decommissioned unit number's runtime records.
3. **Tick-Scoped Positional Fallback Cache (`scripts/active-device-scanner.lua`, `scripts/hubs/hub-manager.lua`):** Added `storage.fast_replace_cache` and `storage.hub_fast_replace_cache` to preserve deep-copied settings keyed by spatial coordinates on the destruction tick. This guarantees `on_built_entity` and `on_hub_built` adopt predecessor configurations even if event dispatch order completes entity removal before build registration, suppressing default resets and pruning stale cache records after 60 ticks.


### Revision: Gate Reorientation Lifecycle, Terminator Cutoff Sync & Connection Wakeups
**Date:** 2026-09-09 17:08 (EDT)
**Context:** Fix pneumatic flow failure and stalled queues caused by rotating misaligned gates and walls after placement, eliminate stale cutoff flags on open boundary gates when neighbors are added or removed, and ensure instantaneous queue waking on spatial edge formation.
**Key Changes:**
1. **Reactive Reorientation Lifecycle (`scripts/flow/flow-engine.lua`):** Replaced restrictive registered-port checks in `on_player_rotated_entity` and `on_player_flipped_entity` with a unified `handle_entity_reorientation` handler. Re-evaluates `is_touching_pneumatic_grid` whenever standard entities (`gate`, `stone-wall`) are rotated or flipped, connecting newly aligned structures and enqueuing flow without requiring players to mine and rebuild them. Cleanly disconnects structures rotated away from the network.
2. **Dynamic Terminator Boundary Sync (`scripts/flow/flow-engine.lua`):** Added `storage.gate_cutoff_states` alongside `gate_open_states` in `flow_engine.step` to monitor `is_term = (is_open and is_gate_terminator(unit_number))`. Automatically lifts or applies pressure and capsule cutoffs when adjacent gates are built, rotated, or deconstructed, updating transmission flags and waking ports without waiting for gates to cycle closed and open.
3. **Connection Idempotency & Edge-Formation Wakeups (`scripts/flow/flow-engine.lua`):** Added pre-emptive disconnection in `connect_entity` to ensure atomic node rebuilds during rapid rotation cycles. Invoked `wake_port_parked` on both ends of newly linked edges in `storage.flow_connections`, waking parked capsules and advancing queued traffic on the exact tick a path opens.