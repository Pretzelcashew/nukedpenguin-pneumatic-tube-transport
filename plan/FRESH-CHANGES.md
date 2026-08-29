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


### Revision: Dynamic Diverter Settings & Port Evaluation Integration
**Date:** 2026-08-28 12:00 (EDT)
**Context:** Bridge persistent diverter settings (`storage.diverter_settings`) into runtime port evaluation and network flow calculations, allowing port toggles (enabled/disabled state) and directional modes (Pull vs Push) to dynamically control pressure network topology and flow vectors.
**Key Changes:**
1. **Dynamic Diverter Port Resolution (`scripts/ports/port-definitions.lua`):** Updated `get_ports()` to read `storage.diverter_settings` for `pneumatic-diverter` entities at runtime, dynamically assigning port enabled states (`enabled`), flow directions (`"in"` vs `"out"` vs `"none"`), and pressure deltas (`-100` vs `+100`).
2. **Disabled Port Invalidation (`scripts/ports/port-evaluator.lua`):** Added explicit enable state checks to `port_evaluator.are_compatible()`, treating toggled-off ports (`enabled = false`) as closed/inactive to block network connections.
3. **Flow Engine & Power Sensitivity (`scripts/networks/networks-flow.lua`):** Expanded `is_powered()` check to include `pneumatic-diverter` entities (`entity.energy > 0`) and guarded outbound vector hop creation with port `enabled` checks to prune inactive ports from flow maps.


### Revision: Diverter Port Filter Evaluation & Hop Selection
**Date:** 2026-08-28 12:15 (EDT)
**Context:** Enforce diverter port whitelist and blacklist filter rules during runtime capsule motion, preventing non-matching payload items from routing through restricted outbound ports.
**Key Changes:**
1. **Diverter Filter Storage Standardization (`scripts/diverter-settings.lua`):** Updated default filter slot configuration keys from `signal` to `item` inside `diverter_settings.get()` to align storage structure with GUI item picker element keys.
2. **Filter Logic & Operator Evaluation (`scripts/capsules/capsule-motion.lua`):** Implemented port filter evaluation functions (`evaluate_filter_slot`, `evaluates_port_filter`, `check_diverter_port_filter`, `is_hop_allowed_by_diverter_filters`) that inspect payload contents via `capsule_renderer.get_dominant_item` and evaluate comparison operators across whitelist and blacklist modes.
3. **Outbound Hop Selection Pruning (`scripts/capsules/capsule-motion.lua`):** Integrated filter checks directly into `select_next_target`, preventing capsules from selecting candidate or backtrack outbound hops if either the origin or destination diverter port filters reject the payload item.


### Revision: Ag Science Progression & Entity-Item Tint Harmonization
**Date:** 2026-08-28 13:05 (EDT)
**Context:** Update bio-capsule technology progression to incorporate Space Age science packs while resolving invalid icon file references and harmonizing inventory icon tints 1:1 with world entity graphics.

**Key Changes:**
1. **Technology Tree Progression (`prototypes/technology.lua`):** Integrated `agricultural-science-pack` into `bio-capsule-integrity-2` and `bio-capsule-integrity-3`, and `cryogenic-science-pack` into `bio-capsule-integrity-4`, updating prerequisite dependencies accordingly.
2. **Item Icon Restoration & Multi-Layer Tinting (`prototypes/item.lua`):** Fixed invalid icon paths by restoring base game and Space Age fallback sprite assets (`iron-plate`, `wood`, `ice`, `steel-plate`, `car`, `steel-chest`, `pipe`, `pump`, `iron-chest`, `assembling-machine-2`). Converted single `icon` paths to tinted `icons` layer tables while preserving original stack sizes, subgroups, order keys, and tool durability.
3. **Entity and Inventory Color Synchronization (`prototypes/item.lua`):** Matched item icon palette tints directly to the entity RGB values used across horizontal/vertical hubs, tubes, pumps, junctions, crossflow junctions, and diverters.
4. **Diverter Entity Graphics Tinting (`prototypes/pneumatic-diverter.lua`):** Deepcopied the cloned `assembling-machine-2` animation layers for `pneumatic-diverter` and applied the emerald tint (`{r = 0.25, g = 0.80, b = 0.60, a = 1.0}`) exclusively to non-shadow layers (`not layer.draw_as_shadow`).


### Revision: Complete Mod Localization & Factoriopedia Coverage
**Date:** 2026-08-28 13:10 (EDT)
**Context:** Implement complete English localization strings across all items, entities, transit capsule variants, and research technologies within the pneumatic transport ecosystem.

**Key Changes:**
1. **Infrastructure Entities & Items (`locale/en/config.cfg`):** Registered display names and descriptive tooltips under `[entity-name]`, `[entity-description]`, `[item-name]`, and `[item-description]` for `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, and `pneumatic-diverter`.
2. **Transit Capsule Variants (`locale/en/config.cfg`):** Added localizations covering the full capsule lineup (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule`), ensuring proper Factoriopedia and inventory display.
3. **Technology Tree Localizations (`locale/en/config.cfg`):** Created `[technology-name]` and `[technology-description]` entries for `pneumatic-transport`, `specialized-pneumatic-capsules`, and `bio-capsule-integrity-1` through `4`.


### Revision: Release Packaging, Version Graduation & Space Age Dependency
**Date:** 2026-08-28 13:11 (EDT)
**Context:** Prepare mod archive for public release on the Factorio Mod Portal by graduating project versioning to 0.1.0, establishing required expansion dependencies, and adding engine release artifacts.
**Key Changes:**
1. **Mod Metadata Manifest (`info.json`):** Graduated mod version from `0.0.1` to `0.1.0`. Updated engine requirements to `base >= 2.1.0`, set a hard dependency for `space-age >= 2.1.0` to enforce expansion feature requirements, and retained `? quality` as an optional integration.
2. **Engine Changelog (`changelog.txt`):** Created standard Factorio-formatted release log detailing initial public testing feature set for version 0.1.0.


### Revision: Dedicated Inventory Group & Technology Localization Fixes
**Date:** 2026-08-29 10:27 (EDT)
**Context:** Added a dedicated inventory tab for pneumatic infrastructure and capsules to clear GUI clutter, and resolved tech tree localization rendering issues for multi-tier bio-capsule research nodes.
**Key Changes:**
1. **Custom Inventory Tab & Subgroups (`prototypes/item.lua`):** Registered a new `item-group` (`pneumatics`) alongside two `item-subgroup` rows (`pneumatic-transport` and `pneumatic-capsules`). Reassigned all structure entities and capsule vessel items to these subgroups, moving pneumatic content out of vanilla Logistics/Intermediates into its own dedicated UI tab.
2. **Item Group Localization (`locale/en/config.cfg`):** Added `[item-group-name]` category containing `pneumatics=Pneumatic Transport` to properly render the tab tooltip name in player inventories.
3. **Technology Level Localization Fix (`locale/en/config.cfg`):** Resolved the `Unknown key` error and literal `__1__` formatting bugs by standardizing `bio-capsule-integrity` as the base key under `[technology-name]`. This allows Factorio's locale engine to handle dynamic level appending automatically while rendering the matching `[technology-description]` string across all four tiers.


### Revision: Alt Mode Visual Overlay for Flow Maps
**Date:** 2026-08-29 10:41 (EDT)
**Context:** Integrate pneumatic network flow vectors and pressure text displays directly into Factorio's native Alt Mode toggle (`only_in_alt_mode = true`), enabling flow map visibility by default without requiring manual console command invocation.
**Key Changes:**
1. **Alt Mode Rendering Flags (`scripts/networks/networks-flow-renderer.lua`):** Applied `only_in_alt_mode = true` to both `rendering.draw_text` (pressure labels) and `rendering.draw_line` (directional flow vectors), allowing the game engine to automatically toggle flow map overlays when the player toggles Alt Mode.
2. **Default Flow State (`scripts/debug-manager.lua`):** Updated default state for `storage.debug.flow` from `false` to `true` so flow visualization is active by default in Alt Mode. Updated `/toggle-flow` console command descriptions and chat messages to reflect Alt Mode overlay functionality.
3. **Main Script Wiring (`control.lua`):** Required `scripts/networks/networks-flow` at top level and added `networks_flow.draw_all()` call inside `setup_storage()` to render existing flow maps across subgraphs on world initialization or mod configuration changes.


### Revision: Per-Player Debug State & Visual Overlay Isolation
**Date:** 2026-08-29 10:57 (EDT)
**Context:** Refactor centralized debug commands and visual rendering overlays to operate on a per-player basis, ensuring debug states, prints, and visual indicators (port markers, flow vectors, and capsule sprites) are scoped to individual players without cross-contaminating multiplayer sessions.

**Key Changes:**
1. **Per-Player Storage Schema (`scripts/debug-manager.lua`):** Restructured `storage.debug` to index feature flags (`master`, `ports`, `flow`, `capsules`, `prints`) by `player_index`. Updated `/toggle-*` console commands to target the executing player (`command.player_index`) and adapted `is_debug_active()` and `debug_print()` to accept optional target player arguments.
2. **Scoped Port Overlay Renderer (`scripts/ports/port-renderer.lua`):** Updated `storage.port_render_objects` to track circle render handles per `player_index`. Applied `players = { player }` filtering to `rendering.draw_circle` calls and updated `draw_all()` / `clear_all()` handlers to clear and redraw per player.
3. **Scoped Network Flow Overlay Renderer (`scripts/networks/networks-flow-renderer.lua`):** Updated storage handle table to `storage.flow_render_ids[player_index][net_id]`. Added `players = { player }` scope targeting to pressure text and flow vector line render calls, allowing Alt Mode overlays to render strictly for players with active debug flags.
4. **Scoped Capsule Overlay Renderer (`scripts/capsules/capsule-renderer.lua`):** Updated `capsule_renderer.render()` to iterate active game players, evaluating per-player debug feature checks and appending `players = { player }` constraints to gold ring borders, item sprites, and position dots.


### Revision: Dynamic Pneumatic Diverter Circuit Control Integration
**Date:** 2026-08-29 11:21 (EDT)
**Context:** Implement circuit network signal evaluation for pneumatic diverter ports via paired proxy constant combinators, updating port flow vectors dynamically and adding circuit condition controls to the diverter GUI.
**Key Changes:**
1. **Circuit Signal Evaluation (`scripts/diverter-settings.lua`):** Implemented signal querying against `pneumatic-diverter-circuit-proxy` entities across configurable red/green wire connectors. Added logic to evaluate comparison operators (`=`, `≥`, `≤`, `>`, `<`, `≠`) against target signal values to resolve dynamic port enable/disable states.
2. **Dynamic Port Flow & Pressure Allocation (`scripts/ports/port-definitions.lua`):** Refactored `port_defs.get_ports()` for diverter entities to resolve runtime settings. Dynamically sets port flow (`in`/`out`/`none`) and applies pressure modifiers (-100 for input, 100 for output) based on circuit conditions and manual overrides.
3. **State Change Detection & Polling (`scripts/networks/diverter-manager.lua`):** Added a 15-tick periodic scanner tracking active diverters. Caches per-port enable states and power conditions, triggering `networks_flow.build()` rebuilds whenever circuit condition thresholds or entity power states toggle.
4. **GUI Circuit Integration (`scripts/diverter-gui.lua`):** Updated the existing configuration GUI and event handlers to expose circuit settings—adding red/green wire channel toggles, signal selectors, comparator dropdowns, constant text fields, and real-time settings synchronization.


### Revision: Dynamic Hub Port Rerouting & Internal Hop Filtering
**Date:** 2026-08-29 12:06 (EDT)
**Context:** Resolve hub port trapping and internal movement loops by dynamically re-evaluating hub exit ports upon flow reinstatement and excluding internal hub ports from candidate motion targets.
**Key Changes:**
1. **Hub Exit Port Resolution (`scripts/capsules/capsule-motion.lua`):** Implemented `find_best_hub_outbound_port()` to dynamically scan all ports of a hub entity for active outbound flow vectors, downstream capacity (`has_entity_network_capacity`), diverter filter compliance (`is_hop_allowed_by_diverter_filters`), and pressure drops.
2. **Parked Capsule Rerouting (`scripts/capsules/capsule-motion.lua`):** Updated `select_next_target()` for stationary capsules (`to_port_key == nil`) parked at hub entities, automatically updating `from_port_key` to whichever port acquires active flow when network state updates.
3. **Internal Hub Hop Exclusion & Pump Pressure Fix (`scripts/capsules/capsule-motion.lua`):** Filtered out internal ports of the same hub entity (`target_unit == entity.unit_number`) from candidate target selection to prevent internal hub bouncing. Restricted the `drop = math.huge` internal hop pressure override strictly to `pneumatic-pump` entities.
4. **Unified Dispatch Port Selection (`scripts/capsules/capsule-runner.lua`):** Refactored `inject_from_hub()` to utilize `find_best_hub_outbound_port()`, ensuring newly packed capsules select capacity-cleared and filter-valid exit ports at injection time.


### Revision: Pneumatic Pump Circuit Proxy & Lifecycle Linkage Integration
**Date:** 2026-08-29 12:24 (EDT)
**Context:** Add circuit network proxy constant combinators to pneumatic pumps to enable circuit wire attachment and lifecycle tracking, mirroring the pneumatic diverter proxy architecture.
**Key Changes:**
1. **Pump Circuit Proxy Prototype (`prototypes/pneumatic-pump-proxy.lua`):** Registered `pneumatic-pump-circuit-proxy` cloned from `constant-combinator` with matching pump icon, 0 collision/selection boxes, and hidden, non-selectable entity flags.
2. **Proxy Lifecycle Linkage (`prototypes/pneumatic-pump-proxy-linkage.lua`):** Implemented lifecycle event listeners for build, rotation, and destruction of `pneumatic-pump` entities to automatically spawn, align orientation, and clean up proxy entities.
3. **Data & Runtime Wiring (`data.lua` & `control.lua`):** Required `prototypes.pneumatic-pump-proxy` in `data.lua` and `prototypes.pneumatic-pump-proxy-linkage` in `control.lua` at top-level to integrate pump circuit proxies into mod startup and runtime execution.