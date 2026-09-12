# ARCHITECTURE.md - Project Blueprint & Structural Overview
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1  
**Author / Maintainer:** Collaborator / Nukedpenguin  
**Description:** Architectural manifest, module map, event lifecycle table, global storage schema, algorithmic specification, and rendering/z-index matrix for AI context and developer quick-reference.

---

## 1. System Architecture & Core Data Flow

```
+-----------------------------------------------------------------------------------+
|                                 FACTORIO ENGINE                                   |
+-----------------------------------------------------------------------------------+
   | Build / Rotate / Flip / Mine / Object Destroyed / Custom Input / GUI / Research
   v                                                                        v Motion on_tick
+------------------------------------+      +---------------------------------------+
|  RUNTIME SIMULATION LAYER          |      |  FLOW v2 ENGINE, COUNTER & KINETICS   |
|  - hub-manager (Interleaved Scan,  |      |  - flow-engine (`scripts/flow/`)      |
|    60Hz 1t Continuous Belt Cadence,|      |    (Event-Driven Delta Wavefront      |
|    Spent Hull Outbound Priority,   |      |    Engine, 0-Tick Idle Queue Sleep,   |
|    Fast-Replace Position Cache)    |      |    Spatial Grid Topology surface@x,y, |
|  - active-device-scanner (Unified  |      |    Unified Sensing & Kinetic Waves,   |
|    15-Tick Scanner for Pumps,      |      |    Direction-Scoped Kinetic Nodes,    |
|    Diverters, Counters & Projector |      |    Ray-Box Line-of-Sight Occlusion,   |
|    Capacitor/Power State Machine)  |      |    Deterministic Territory Split,     |
|  - proxy-manager (Triple-Proxy &   |      |    Natural Recession Waves, Object    |
|    Projector Proxy Architecture,   |      |    Destruction Purge Engine)          |
|    Selection Z-Index, Linkage,     |      |  - port-defs (`scripts/flow/`)        |
|    Wire Merge & Destroyed Cleanup) |      |    (Domain Transmission Flags:        |
|  - device-settings-copier (Live    |      |    capsule/pressure/sense/kinetic,    |
|    Source Copy-Paste, Blueprint    |      |    Passive Hub Parity Intake Ports)   |
|    Wire Sync, Projector Muzzle     |      |  - fence-gate-interop (`scripts/flow/`|
|    Rotation & Tag Deserialization) |      |    Vanilla Wall Axis Locking, Boundary|
|  - diverter-renderer (Alt-Mode 2x2 |      |    Cutoffs, Throttled Activation,     |
|    Port Filter Icon Overlay Engine)|      |    Wavefront Discovery & Demotion)    |
|  - gui-components (Declarative UI  |      |  - counter-range & counter-logic      |
|    Library, Quality Bar & Windows) |      |    (Channel-Isolated Proxy Signal     |
|  - hub-packing / unpacking / spill |      |    Emission for Red & Green Proxies)  |
|  - belt-siphon (Pressure-Governed  |      |  - capsule-runner (`scripts/capsules/`|
|    Bidirectional Siphon/Exhaust,   |      |    Granular 6t Hop Motion Engine,     |
|    1-Tick Cadence, Engine-Filtered |      |    Ballistic 5-Tile Prominent Hops,   |
|    Belts, Cargo-First 3-Tier Line  |      |    Zero-Alloc Player Target Scratch,  |
|    Ejection, Gleba Stacking)       |      |    Quality-Scaled Impact Collisions,  |
|  - projector-settings (3 MW Idle,  |      |    Receiver Catchment & In-Flight     |
|    9 MJ Buffer, 180t Grace Period, |      |    Momentum Preservation, Strict EM   |
|    2-Cap Congestion Throttling)    |      |    Gatekeeping, O(1) Spatial Parked)  |
|  - liminal-surface (Dual-Tier Grid)|      |                                       |
+------------------------------------+      +---------------------------------------+
                   |                                            |
                   | Delegates Operations                       |
                   +------------------------------------------->|
                                                                v
+-----------------------------------------------------------------------------------+
|  PERSISTENT STORAGE (`storage`) & ZERO-ALLOCATION DEBUG OVERLAYS                  |
|  - storage.flow_nodes / storage.flow_grid / storage.flow_connections              |
|  - storage.flow_queue / storage.flow_levels / storage.flow_unit_ports             |
|  - storage.kinetic_levels / storage.kinetic_beam_tiles / storage.kinetic_renders  |
|  - storage.counter_levels / storage.counter_owners / storage.counter_owned_nodes  |
|  - storage.counter_queue / storage.counter_settings                              |
|  - storage.active_walls / storage.active_gates / storage.wall_locked_group        |
|  - storage.gate_open_states / storage.gate_cutoff_states                          |
|  - storage.soft_interop_registry / storage.interop_activation_queue               |
|  - storage.fast_replace_cache / storage.hub_fast_replace_cache                    |
|  - storage.parked_by_port ([port_key][capsule_id] O(1) Spatial Parked Index)      |
|  - storage.object_destruction_map ([reg_id] = { type, unit_number | id })        |
|  - storage.occupancy ([unit_number][net_id][group] O(1) Spatial Buckets)          |
|  - storage.liminal_grid (Dual-tier Wide y>=0 / Tight y<=-100 coordinate domains)  |
|  - storage.spilled_containers (Fast-looting containers with set_bar(1) clamping)  |
|  - storage.ghost_devices / storage.ghost_hubs / storage.ghost_by_pos              |
|  - storage.ghost_directions ([ghost_id] = direction_enum)                         |
|  - storage.player_copy_buffer / storage.port_clipboard                            |
|  - storage.active_capsules (Dominant item & quality) / active_hubs / receive_locks|
|  - storage.active_pumps / storage.pump_power_states / pump_enabled_states         |
|  - storage.active_diverters / storage.diverter_power_states / diverter_settings   |
|  - storage.active_projectors / storage.projector_settings / projector_power_states|
|  - storage.projector_enabled_states / projector_muzzle_states                     |
|  - storage.projector_ready_states / storage.projector_last_fired                 |
|  - storage.debug[player_index] (Master debug, overlays, filter, control panel)    |
|  - debug-manager / flow overlays / kinetic renders / counter / capsule renders    |
+-----------------------------------------------------------------------------------+
```

---

## 2. All-Encompassing Module Directory

### 2.1 Root & Prototype Stage Files

| File | Sub-Path | Purpose & Role | Key Exports / Prototypes | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `info.json` | `/` | Mod metadata manifest. | Defines mod ID (`nukedpenguin-pneumatic-tube-transport`), version (`0.3.21`), title, Factorio version (`base >= 2.1.0`), expansion dependencies (`space-age >= 2.1.0`), optional (`? quality`). | Factorio Engine |
| `data.lua` | `/` | Prototype stage entry point. Loads item, recipe, entity, technology, custom input, shortcut, diverter, pump, capsule counter, electromagnetic projector, wildcard quality badge sprite, and blacklist filter sprite prototypes. | Loads prototype files via strict top-level `require`. Registers `pneumatic_any_quality_badge` and `pneumatic_filter_blacklist` (101x101) sprite prototypes. | Data Stage |
| `settings.lua` | `/` | Mod startup settings registration. Obsolete `pneumatic-flow-version` setting removed; execution is locked strictly to the v2 flow engine. | Data stage settings registration. | Data Stage |
| `control.lua` | `/` | Runtime script entry point. Imports top-level script modules (`proxy_manager`, `active_device_scanner`, `device_settings_copier`, `diverter_renderer`, `flow_engine`, `counter_range`, `counter_settings`, `counter_gui`, `counter_logic`, `projector_settings`, `pump_gui`, `capsule_runner`, `hub_manager`), executes storage setup migrations, initializes v2 flow and kinetic schemas, purges map orphan proxies (`proxy_manager.purge_orphans()`), refreshes Alt-Mode overlays, and registers event listeners unconditionally. | Hooks `script.on_init`, `script.on_configuration_changed`, requires active logic scripts at top level. | Script Stage |
| `custom-input.lua` | `prototypes/` | Custom input hotkey definitions. | Defines `capsule-emergency-exit` (`SHIFT + E`), `pneumatic-copy-settings` (linked to `copy-entity-settings`), `pneumatic-paste-settings` (linked to `paste-entity-settings`), and `pneumatic-confirm-gui` (linked to `confirm-gui`). | `data.lua` |
| `entity.lua` | `prototypes/` | Registers mod entities in Factorio data stage. Configures expanded `inventory_size = 255` for `invisible-capsule-holder` and `visible-capsule-holder`. Configured `inventory_type = "with_filters_and_bar"` on `capsule-hub-horizontal` and `capsule-hub-vertical`. Registers `gui_mode = "all"` on `pneumatic-pump` and `pneumatic-capsule-counter` (`electric-energy-interface`) for native interaction event dispatching. Registers `additional_pastable_entities`. | Defines `capsule-hub-horizontal`, `capsule-hub-vertical`, `invisible-capsule-holder`, `visible-capsule-holder`, `pneumatic-tube`, `pneumatic-pump`, `pneumatic-capsule-counter`, `junction`, `crossflow-junction`. Tinted visuals. | `data.lua` |
| `item.lua` | `prototypes/` | Prototype item, tool, custom item-group, and subgroup definitions for placeable structures and transport capsules. Standardized items with `stack_size = 1` for single-unit capsules (`vacuum-capsule`, `refrigerated-capsule`). Standardized payload weight of `50 * kg` across all 9 active and spent capsule prototypes and infrastructure items (`pneumatic-projector` stack size 10, weight `50 * kg`). Tooltip and Factoriopedia descriptions driven cleanly from localized locale strings. | Registers `pneumatics` item group, `pneumatic-transport` & `pneumatic-capsules` subgroups. Defines items: `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, `electromagnetic-capsule`, `vacuum-capsule`, `spent-vacuum-capsule`, `player-transit-capsule`, `pneumatic-projector`, structures. | `data.lua` |
| `pneumatic-projector.lua` | `prototypes/` | Physical Electromagnetic Projector facility prototype (`electric-energy-interface`, 3x3 footprint, 3 MW idle consumption, 9 MJ buffer capacity, 9 MW input flow limit, `selection_priority = 50`, centered collision/selection boxes, 0.75x scaled magenta-tinted visual animation derived from Space Age electromagnetic plant chassis) and companion circuit proxy (`pneumatic-projector-circuit-proxy`, `constant-combinator`, `selection_priority = 60`, `operable = true`, `placeable_by = {item = "pneumatic-projector", count = 0}`). | Defines `pneumatic-projector` and `pneumatic-projector-circuit-proxy`. | `data.lua` |
| `pneumatic-capsule-counter.lua` | `prototypes/` | Physical pneumatic capsule counter prototype (`electric-energy-interface`, 1x2 footprint, 30 kW energy usage, `selection_priority = 50`, teal decider combinator sprite tint `{r=0.30, g=0.85, b=0.70}`) and triple-proxy architecture definitions (`pneumatic-capsule-counter-circuit-proxy` terminal proxy with `selection_priority = 60`, `operable = true`, `placeable_by` main item, alongside hidden `pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy` channel proxies with `selection_priority = 0`, `operable = false`). | Defines `pneumatic-capsule-counter`, `pneumatic-capsule-counter-circuit-proxy`, `pneumatic-capsule-counter-red-proxy`, `pneumatic-capsule-counter-green-proxy`. | `data.lua` |
| `pneumatic-diverter.lua` | `prototypes/` | Physical diverter machine prototype and invisible circuit proxy definition. Configured `placeable_by = { item = "pneumatic-diverter", count = 0 }`, `"player-creation"` flag, elevated selection priority (`selection_priority = 60`), `operable = true`, compact footprint, and `additional_pastable_entities`. | Defines `pneumatic-diverter` and `pneumatic-diverter-circuit-proxy`. | `data.lua` |
| `pneumatic-pump-proxy.lua` | `prototypes/` | Circuit proxy prototype definition for pneumatic pumps. Configured `placeable_by = { item = "pneumatic-pump", count = 0 }`, `"player-creation"` flag, elevated selection priority (`selection_priority = 60`), and `operable = true`. | Defines `pneumatic-pump-circuit-proxy`. | `data.lua` |
| `recipe.lua` | `prototypes/` | Crafting recipes with Space Age environmental constraints: `vacuum-capsule` restricted to 0 pressure (space platforms); `reinforced-capsule` restricted to 4000 hPa (Vulcanus, `categories = {"metallurgy"}`); `refrigerated-capsule` restricted to 300 hPa (Aquilo, `categories = {"cryogenics"}`, 10.0s craft consuming 100 cold fluoroketone and returning 100 hot fluoroketone net-zero closed loop); `electromagnetic-capsule` and `pneumatic-projector` restricted to >= 99% magnetic field (Fulgora, `categories = {"electromagnetics"}`). `pneumatic-projector` recipe costs 25 holmium plates, 10 supercapacitors, 10 processing units, 20 steel plates, 10 pneumatic tubes. `biodegradable-capsule` and recharge recipes remain craftable across all surfaces. Closed-loop repressurization for vacuum capsules (`spent-vacuum-capsule = 1`, `energy_required = 2.0`, `allow_productivity = false`). 500 base charges on `vacuum-capsule`, 600 base charges on `refrigerated-capsule`. | Defines recipes with `enabled = false` for technology unlock gating and explicit `surface_conditions`. | `data.lua` |
| `shortcut.lua` | `prototypes/` | Shortcut bar prototype registration (`pt-debug-panel`) with localized tooltip headers and `toggleable = true` support. | Defines master hotbar debug shortcut prototype. | `data.lua` |
| `technology.lua` | `prototypes/` | Research tree prototype nodes incorporating Space Age science packs (`space-science-pack`, `electromagnetic-science-pack`, `agricultural-science-pack`, `cryogenic-science-pack`). Includes `pneumatic-projector` research node (350 units @ 45s, prereqs: `electromagnetic-science-pack`, `pneumatic-transport`, `electromagnetic-capsule`), `pneumatic-fence-gate-interoperability`, `capsule-counter`, specialized planetary capsule unlocks (`vacuum-capsule`, `reinforced-capsule`, `refrigerated-capsule`, `biodegradable-capsule`, `electromagnetic-capsule`). | Defines technology progression nodes and dedicated capsule/facility research trees. | `data.lua` |

---

### 2.2 System Framework & Surface Management

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. | `events.on_event(event_id, handler)` | System-wide event listeners |
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`) and Pneumatic Control Panel Lua GUI controller (`open_panel`, `close_panel`, `toggle_panel`, `refresh_panel`). Manages console log prefix filtering, v2 Alt-Mode flow overlay toggles, sensing range wavefront overlay toggles, kinetic beam overlay reconstruction, shortcut syncing, and console commands (`/pneumatic-panel`, `/toggle-debug`, `/toggle-prints`, `/toggle-flow`, `/toggle-counter-range`, `/toggle-capsules`, `/toggle-capsule-peek`, `/clear-renders`, `/pt-clear-renders`). Decouples flow and kinetic beam overlay drawing/clearing from counter overlays. | `debug_print(...)`, `is_debug_active(...)`, `open_panel()`, `close_panel()`, `toggle_panel()`, `sync_shortcuts()` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `liminal-surface.lua` | `scripts/surfaces/` | Dual-Tier Spatial Grid allocation engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Distributes standard non-spoilable cargo into Tight slots (2-tile spacing, $y \le -100$) and spoilable/unit cargo into Wide cells (8-tile spacing, $y \ge 0$). Manages separate recycling stacks (`wide_free_slots`, `tight_free_slots`). Synchronous chunk generation (`ensure_chunk_at`). | `liminal_surface.get()`, `allocate_position(is_wide)`, `release_position(index, is_wide)`, `ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua` |
| `item-transfer-handler.lua` | `scripts/utils/` | Centralized item metadata preservation & stack transfer engine. Preserves 100% of Factorio 2.0 item metadata: equipment grids (`stack.grid`), installed modules, shield/energy states, quality, spoilage, durability, health, ammo, and custom tags. Guards against tool property evaluation errors on non-tool items. | `copy_equipment_grid(src, dest)`<br>`build_stack_spec(stack)`<br>`transfer_stack(src, dest_inv)`<br>`transfer_inventory(src_inv, dest_inv)`<br>`spill_stack(surface, pos, stack)` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-spill.lua`, `capsule-lifecycle.lua`, `belt-siphon.lua` |
| `gui-components.lua` | `scripts/utils/` | Centralized declarative UI widget builder library & quality control bar engine. Centralizes Factorio 2.0 native filter display rules (`get_filter_display_spec`, `get_active_filters`) across GUI slot buttons and world overlays. Renders relative window frames, draggable headers (`drag_target = parent_frame`), titles, wire channel toggles, circuit condition panels (55px dropdown width), 40x40 overlay slot buttons, quality control bar widgets, and 3x3 spatial arrow selectors. | `create_relative_window()`, `add_header()`, `add_card_frame()`, `add_wire_channel_toggles()`, `add_circuit_condition_panel()`, `create_overlay_slot_button()`, `update_overlay_slot_button()`, `add_quality_control_bar()`, `add_spatial_arrow_selector()`, `clear_filter_slot()`, `handle_filter_item_change()`, `get_filter_display_spec()` | Device GUIs (`pump-gui`, `diverter-gui`, `hub-gui`, `counter-gui`) |
| `proxy-manager.lua` | `scripts/` | Centralized Proxy Linkage, Multi-Proxy Lifecycle & Object Destruction Engine (`storage.object_destruction_map`). Supports main terminal proxies and sub-proxy schemas (`pneumatic-capsule-counter-red-proxy`, `pneumatic-capsule-counter-green-proxy`, `pneumatic-projector-circuit-proxy`). Spawns, teleports, and connects internal Red/Green wire bridges between channel proxies and terminal proxy on build/rotate events, and purges proxies upon entity removal (`destroy_all_proxies_at`). Registers main entities with `script.register_on_object_destroyed` to catch C++ engine-level removals (super force building, fast replacement, ghost cancellation). Manages spatial selection precedence (`selection_priority = 60`, `proxy.operable = true`, `proxy.teleport`), additive wire merging (`transfer_wire_connections`), orphan proxy/ghost auto-destruction, and surface-wide orphan purging (`purge_orphans`). Exposes `get_registered_proxies()` and `get_registered_mains()`. | `proxy_manager.register_pair()`, `proxy_manager.register_events()`, `proxy_manager.purge_orphans()`, `proxy_manager.get_registered_proxies()`, `proxy_manager.get_registered_mains()`, `proxy_manager.destroy_all_proxies_at()` | `control.lua`, `device-settings-copier`, `active-device-scanner` |
| `device-settings-copier.lua` | `scripts/` | Centralized Device Settings Copier, Blueprint Serialization, Ghost Wire Linking & Blueprint Sanitization Engine. Supports `pneumatic-capsule-counter`, `pneumatic-diverter`, `pneumatic-pump`, and `pneumatic-projector` target resolution and proxy mapping. Adjusts relative projector launch muzzle directions during live Shift+Left-Click copy-paste and blueprint stamping. Stores live entity source handles in `storage.player_copy_buffer` with source validity guards. Handles `on_player_setup_blueprint` (4-tuple wire schema `[entity_from, wire_type_from, entity_to, wire_type_to]`, metadata tag serialization via `pneumatic_settings`), `clean_blueprint_orphans`, and executes instant zero-state spatial wire target resolution on the build tick (`process_entity_built_wire_tags`). | `device_settings_copier.register_events()`, `clean_blueprint_orphans()`, `process_entity_built_wire_tags()` | `control.lua`, `proxy-manager`, `active-device-scanner`, `counter-gui`, `pump-gui` |

---

### 2.3 Active Machine State Managers & Overlays

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `active-device-scanner.lua` | `scripts/` | Unified 15-tick background scanner monitoring active physical and ghost machine entities (`pneumatic-pump`, `pneumatic-diverter`, `pneumatic-capsule-counter`, and `pneumatic-projector`). For projectors: evaluates 3 MW idle baseline power (`MINIMUM_ENERGY_JOULES = 3000000`), circuit conditions, muzzle orientation changes, and capacitor recharge transitions (`storage.projector_ready_states`), triggering `flow_engine.enqueue_unit_ports` and `capsule_runner.wake_parked_capsules` on state changes. Calls `counter_logic.update_signals` on active counter ticks. Tracks active ghosts in `storage.ghost_devices` and `storage.ghost_by_pos`. Handles native `on_blueprint_settings_pasted`, enforces strict spatial ghost settings adoption, fast-replacement co-existence queries, proactive destruction-phase settings transfer (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `projector_settings.copy`), tick-scoped positional fallback caching (`storage.fast_replace_cache`, 60-tick expiry), flow engine unit port enqueuing, parked capsule wakeups (`notify_settings_changed`), Alt-Mode overlay updates, and subscriber registration (`on_settings_changed`). | `register_device_type()`, `register_events()`, `notify_settings_changed()`, `find_existing_real_at_pos()`, `on_settings_changed` subscriber | `proxy-manager`, `diverter-renderer`, `flow-engine`, `counter-logic`, `capsule-runner`, `diverter-gui`, `counter-gui`, `pump-gui` |
| `diverter-renderer.lua` | `scripts/` | Native-style Alt-Mode Diverter Port Filter Overlay Renderer. Queries topological port offsets via `port_defs.get_ports(entity)` and applies directional inward offsets (`PORT_INWARD_OFFSET = 0.55`) to shift filter clusters away from port flow dots. Consumes `gui_components.get_filter_display_spec` to display up to 4 filter item icons per port in adaptive 2x2 grids. Draws 1.3x scaled black silhouette outlines and drop shadows on `render_layer = "entity-info-icon"` and full-color icons, bottom-left quality badges, non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`), standalone quality filters, and per-slot prominent blacklist symbols (`scale * 0.88`) on `render_layer = "entity-info-icon-above"`. Whitelist empty ports render centered "no" symbol; empty blacklist ports suppress overlays. | `diverter_renderer.update_render(entity)`, `diverter_renderer.clear_render(unit_number)` | `control.lua`, `active-device-scanner` |

---

### 2.4 Hub System & Cargo Packing / Unpacking

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), tracking binary capsule nesting toggle (`nest_capsules = false` default) encapsulated via `hub_settings.is_nesting_enabled()`, providing circuit condition evaluation, `.copy()` deep-copy helper, `get_device_id` spatial identity export, and `apply_blueprint_settings()` tag deserialization. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.is_nesting_enabled()`, `hub_settings.apply_blueprint_settings()`, `hub_settings.get_device_id()`, `hub_settings.copy()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`), consuming `gui-components.lua`. Features a "Nest capsules" checkbox to toggle binary capsule vessel packing based on `hub_settings.is_nesting_enabled()`. Resolves ghost entity handles and fires `hub_manager.notify_settings_changed(entity)` on edits to wake disembarking capsules and active scanners. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, etc.) | `hub-settings.lua`, `hub-manager.lua`, `gui-components.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Lifecycle listener, settings notification (`notify_settings_changed`), blueprint tag restoration (`pneumatic_settings`), native `on_blueprint_settings_pasted` handling, fast-replace co-existence queries, destruction-phase proactive settings transfer (`hub_settings.copy`), tick-scoped positional fallback cache (`storage.hub_fast_replace_cache`, 60-tick expiry), O(1) ghost hub tracking, strict spatial ghost settings adoption, interleaved 10-tick background scan for `hub_packing.evaluate_inventory`, and decoupled 1-tick continuous 60Hz execution of bidirectional belt siphoning/depositing via `belt_siphon.process_belts(entity)` for 100% belt compression. | Interleaved hub packing scan, 1-tick continuous belt siphon execution, `notify_settings_changed()`, `find_existing_real_hub_at_pos()`, build/mine event listeners. | `hub-packing`, `belt-siphon`, `hub-gui`, `events` |
| `belt-siphon.lua` | `scripts/hubs/packing/` | Independent, pressure-governed bidirectional transport belt interface operating at continuous 1-tick cadence. Fast-path early exits evaluate `get_hub_net_pressure` first (skipping neutral/unpressurized hubs) and check `chest_inv.is_empty()` and C++ `chest_inv.find_item_stack("vacuum-capsule")` before iterating inventory slots. Engine-filtered adjacent belt queries pass `BELT_SEARCH_TYPES` (`transport-belt`, `underground-belt`, `splitter`, `linked-belt`) to `surface.find_entities_filtered`. Enforces 3-tier cargo-first deposit priority (`Pure Cargo > Spent Capsules > Secondary Charged Capsules`) in `find_deposit_candidate_slot`. Enforces strict orthogonal adjacency (`is_strictly_adjacent`) via AABB projection, near transport line restrictions for parallel passing belts (`get_deposit_line_indices`), and Space Age Gleba belt stacking (`force.belt_stack_size_bonus`) via `line.insert_at_back(spec, allowed_stack)`. Deducts 1 health charge point per item placed or siphoned, converting depleted capsules instantly to `spent-vacuum-capsule` shells. | `belt_siphon.process_belts(hub_entity)`, `belt_siphon.siphon_to_chest(hub_entity)`, `belt_siphon.deposit_to_belts(hub_entity, chest_inv)`, `belt_siphon.get_hub_net_pressure(hub_entity)` | `hub-manager.lua`, `item-transfer-handler.lua`, `capsule-definitions.lua` |
| `hub-packing.lua` | `scripts/hubs/packing/` | Main hub packing pipeline running on 10-tick interleaved cadence: Send check (`can_send`), early outbound route validation checking for positive pressure drop target ports (`find_best_hub_outbound_port`), lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius), full `#inventory` scanning. Outbound packing candidate priority targets spent hulls (`SPENT_CAPSULES`) first, standard cargo capsules second, and lowest-health charged capsules last to draft empty shells home while preserving unloader capsules at outposts. Biological cargo restriction checks (`bio_only`), cargo filtering based on `nest_capsules`, dynamic dominant item selection, Dual-Tier Spatial Grid allocation (`liminal_surface.allocate_position(is_wide)`), liminal holder spawning, cargo transfer via `item_transfer_handler`, dynamic post-packing inventory bar clamping (`dest_inv.set_bar(last_occupied_slot + 1)`), and injection via `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `item-transfer-handler`, `cargo-planner`, `capsule-runner` |
| `hub-unpacking.lua` | `scripts/hubs/packing/` | Main hub unpacking pipeline: Receive check (`can_receive`), $O(1)$ failure state guard (`last_failed_hub`), passenger disembarkation onto safe tiles, single-use primary shell dissolution (`destroy_self` cleared prior to cargo transfer), all-or-nothing cargo unpacking via `can_insert_all()` ignoring primary shell slot for single-use capsules using zero-allocation flat scratch arrays, slot loops bounded to `get_bar() - 1`, stack migrations via `item_transfer_handler`, liminal holder cleanup with dual slot recycling (`release_position`), and mechanical receive latch engagement. | `hub_unpacking.capture(capsule_tracker, hub_entity)`<br>`can_insert_all(...)` | `capsule-manager`, `liminal-surface`, `item-transfer-handler`, `hub-settings` |
| `hub-spill.lua` | `scripts/hubs/packing/` | Listens to entity mining and destruction events (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `defines.events.script_raised_destroy`, `on_space_platform_mined_entity`). Passes `{ raise_destroy = true }` during cleanup to wake raycast listeners. Inspects `destroy_self` and clears primary shell slots prior to spilling cargo onto ground or into fast-looting spill containers (`visible-capsule-holder`, `operable = true`, `set_bar(1)` red-locking upon creation). Excludes `is_beam_node` capsules from machine deconstruction spillage. Instant GUI dismissal, `"no-copy-paste"` settings protection, 60Hz throttled container cleanup scan (`process_spilled_containers`), and metadata-safe spills via `item_transfer_handler`. | `hub_spill.spill_capsule(...)`<br>`hub_spill.handle_entity_destruction(entity)` | `capsule-queries`, `capsule-manager`, `item-transfer-handler` |
| `quality-filter.lua` | `scripts/hubs/packing/` | Evaluates item quality against capsule vessel rules (`ceil`, comparators, whitelists, blacklists). | `quality_filter.is_quality_allowed(...)` | `hub-packing.lua` |
| `cargo-planner.lua` | `scripts/hubs/packing/` | Calculates stack extraction and insertion plans. Calculates fractional slot costs (`base_slot_cost / stack_size`) when `mixed_quantity = true` (electromagnetic capsules). Delegating `get_item_slot_cost()` to `capsule_defs.is_bio_item()` backed by a strict $O(1)$ bio item matrix (`capsule_definitions.bio_items`). | `cargo_planner.get_item_slot_cost(...)`<br>`cargo_planner.build_packing_plan(...)` | `capsule-definitions.lua`, `hub-packing.lua` |

---

### 2.5 Capsule System, Counter Controls, Diverter, Pump & Projector Controls

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `projector-settings.lua` | `scripts/` | Electromagnetic Projector device state persistence table (`storage.projector_settings[unit_number]`). Tracks launch muzzle orientation (`muzzle_dir`), enable status, wire channels, and circuit network enable conditions. Defines `MINIMUM_ENERGY_JOULES = 3000000` (3 MW baseline idle power), `LAUNCH_ENERGY_JOULES = 9000000` (9 MJ buffer capacity required for dispatch), `RECHARGE_GRACE_TICKS = 180` (recharge grace period maintaining kinetic beam and Alt-Mode overlays while buffer refills from 0 to 3 MW baseline), `PROJECTILE_DAMAGE = 250` baseline impact damage rating, and `MAX_ENDPOINT_CAPSULES = 2` endpoint congestion capacity threshold. Provides `can_fire(entity)`, `is_powered(entity)`, `get_launch_energy()`, `get_device_id()`, `copy()`, and `apply_blueprint_settings()`. | `projector_settings.get()`, `projector_settings.can_fire()`, `projector_settings.is_powered()`, `projector_settings.get_device_id()`, `projector_settings.copy()`, `projector_settings.apply_blueprint_settings()` | `active-device-scanner`, `flow-engine`, `capsule-runner`, `pump-gui`, `device-settings-copier` |
| `counter-settings.lua` | `scripts/counters/` | Capsule Counter state persistence table (`storage.counter_settings[dev_id]`). Default schema (`vessels_target = "green"`, `cargo_target = "red"`, `total_target = "green"`, `total_signal = nil`). Supports spatial device ID resolution (`get_device_id`), terminal proxy lookup (`get_proxy`), channel proxies lookup (`get_channel_proxies`), deep-copy cloning (`copy`), and blueprint deserialization (`apply_blueprint_settings`). Preserves selected virtual signal quality levels without hardcoded fallbacks. | `counter_settings.get()`, `counter_settings.get_device_id()`, `counter_settings.get_proxy()`, `counter_settings.get_channel_proxies()`, `counter_settings.copy()`, `counter_settings.apply_blueprint_settings()` | `counter-gui`, `counter-logic`, `active-device-scanner` |
| `counter-gui.lua` | `scripts/counters/` | Interactive relative configuration GUI (`counter_configuration_frame`) anchored to counter entities/proxies, built via `gui-components.lua`. Features dual-wire "Red Wire" and "Green Wire" checkbox channel routing controls for Capsule Vessels, Cargo Contents, and Total Capsule Count, converting checkbox states to/from `"off"`, `"red"`, `"green"`, `"both"`. Includes virtual signal `choose-elem-button` for Total Capsule Count with quality preservation and clear persistence. Fires scanner notifications on edits. | `counter_gui.open()`, `counter_gui.close()`, GUI event handlers | `counter-settings.lua`, `counter-logic.lua`, `gui-components.lua` |
| `counter-logic.lua` | `scripts/counters/` | Capsule Counter Logic & Signal Calculation Engine (`counter_logic.update_signals(counter_entity)`). Queries owned segment nodes (`counter_range.get_owned_nodes`), inspects active capsules in territory without double-counting, extracts vessel item/quality breakdowns, cargo contents, and total capsule count. Implements Triple-Proxy Channel Isolation: writes Red-target signals strictly to the hidden Red channel proxy and Green-target signals strictly to the hidden Green channel proxy while keeping main terminal proxy filters empty, eliminating cross-network signal bleed. Clears signals when unpowered (`entity.energy == 0`) or unconfigured. | `counter_logic.update_signals(counter_entity)` | `counter-settings.lua`, `counter-range.lua`, `active-device-scanner.lua` |
| `diverter-settings.lua` | `scripts/` | Diverter state persistence table (`storage.diverter_settings`). Tracks cardinal port modes (`input`/`output`), whitelist/blacklist filter modes, 5 filter slots per port with explicit quality tracking (`item`, `comparator`, `quality`, `quality_comparator`, `explicit_quality`), `DEFAULT_CAPACITY = 2`, modulo port rotation (`rotate_ports`, `rotate_ports_by_steps`) & axis flipping (`flip_ports`), per-port copy-paste API (`copy_port`, `paste_port`), cardinal direction index normalization (`get_cardinal_index`), spatial identity resolution (`get_device_id`), memoized filter compilation (`_compiled`), circuit proxy signal querying, `.copy()` deep-copy helper, stored setting sanitization on load, and `apply_blueprint_settings()` tag deserialization API. | `diverter_settings.get()`, `diverter_settings.get_capacity()`, `diverter_settings.is_port_enabled()`, `diverter_settings.evaluate_circuit_condition()`, `diverter_settings.rotate_ports()`, `diverter_settings.flip_ports()`, `diverter_settings.copy_port()`, `diverter_settings.paste_port()`, `diverter_settings.get_cardinal_index()`, `diverter_settings.get_device_id()`, `diverter_settings.copy()` | `diverter-gui`, `active-device-scanner`, `capsule-runner`, `device-settings-copier` |
| `diverter-gui.lua` | `scripts/` | Interactive configuration GUI for Pneumatic Diverters, constructed via `gui-components.lua`. Features a 3x3 spatial arrow selector (North ▲, East ▶, South ▼, West ◀, All) defaulting to `"all"` (4-port grid view), native per-port copy/paste tool buttons (`port_copy_button`, `port_paste_button`) using `storage.port_clipboard[player_index]` with floating cursor feedback, 40x40 square overlay slot buttons with corner badges, right-click filter clearing, and draggable `filter_slot_config_frame` modal pop-up (`drag_target = parent_frame`). Uses isolated `draft_filters` working table with explicit confirm (`pneumatic-confirm-gui` tick tracking, `E` key or ✓ button) and cancel (`Esc` key or X button) lifecycle. Resolves parent tags recursively (`get_element_tags`) and guards against re-entrant destruction during local edits. Subscribes to `active_device_scanner.on_settings_changed` to auto-refresh open GUIs on rotation or copy-paste. | `diverter_gui.open()`, `diverter_gui.close()`, `diverter_gui.refresh_if_open()`, GUI event handlers | `diverter-settings.lua`, `active-device-scanner.lua`, `gui-components.lua` |
| `pump-settings.lua` | `scripts/` | Pump state persistence table (`storage.pump_settings`). Tracks manual enable state (`enabled`), circuit enable toggles, comparator conditions, wire channel toggles, spatial identity resolution (`get_device_id`), `.copy()` deep-copy helper, and `apply_blueprint_settings()` tag deserialization API. | `pump_settings.get()`, `pump_settings.is_pump_enabled()`, `pump_settings.evaluate_circuit_condition()`, `pump_settings.get_device_id()`, `pump_settings.apply_blueprint_settings()`, `pump_settings.copy()` | `pump-gui.lua`, `active-device-scanner.lua` |
| `pump-gui.lua` | `scripts/` | Dual-Device UI Controller managing configuration frames for both Pneumatic Pumps (`pump_configuration_frame`) and Electromagnetic Projectors (`projector_configuration_frame`), consuming `gui-components.lua`. Dynamically renders title headers ("Electromagnetic Projector Configuration"), manual enable toggles ("Enable Projector"), Red/Green wire channel toggles, and circuit condition panels based on entity identity. Resolves ghost entities and circuit proxies, persists edits to `storage.pump_settings` or `storage.projector_settings`, and invokes `active_device_scanner.notify_settings_changed(entity)` on edits. Exports convenience aliases `pump_gui.open_projector` and `pump_gui.close_projector`. | `pump_gui.open()`, `pump_gui.close()`, `pump_gui.open_projector()`, `pump_gui.close_projector()`, GUI event handlers | `pump-settings.lua`, `projector-settings.lua`, `active-device-scanner.lua`, `gui-components.lua` |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: explicit net usable cargo capacities (`cargo_capacity`), dynamic quality charge scaling helper `capsule_definitions.get_max_charges(def_or_name, quality_arg)` implementing `base * (1 + 0.3 * quality_level)` (500 base charges for `vacuum-capsule` scaling to 1,250 at Legendary; 600 base charges for `refrigerated-capsule` scaling to 1,500 at Legendary), biological restrictions (`bio_only = true`), bulk enforcement (`full_stacks`, `minimum_cargo`), fractional slot scaling (`mixed_quantity = true` for `electromagnetic-capsule`), belt siphoning permissions (`siphon_belts = true`), bio item matrix (`bio_items`), distinct RGBA debug overlay colors per capsule variant (`get_debug_color()`), spoilage modifiers, single-use shell dissolution (`destroy_self`), and spent item transitions (`spent_capsule_item`). | Registry `capsule_definitions.types`, `capsule_defs.bio_items`, `capsule_defs.get_debug_color()`, `capsule_defs.get_max_charges()` | `hub-packing`, `capsule-manager`, `capsule-runner`, `capsule-renderer`, `cargo-planner`, `belt-siphon`, `capsule-lifecycle` |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities (`storage.active_capsules`). Registers liminal holders with `script.register_on_object_destroyed` as `{ type = "capsule", id = capsule_id }`. Tracks primary capsule slot, allocated coordinates, `is_wide` classification, cached `dominant_item` string, `dominant_quality` string, `capsule_type = capsule_item_name` immutable identity string, and `has_spoilable_items` flag. Recycles positions back to `wide_free_slots` or `tight_free_slots` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions`, `liminal-surface`, `storage`, `flow-engine` |
| `capsule-queries.lua` | `scripts/capsules/` | $O(1)$ Spatial Occupancy Index (`storage.occupancy` key `[unit_number][net_id][group]`), memoized port descriptors queried directly from `storage.flow_nodes`, target-based blocking occupancy model (`_occ_block_key`), native parser support for `"kinetic:<unit>:<dx>,<dy>:<dist>"` port keys (`port_index = 100 + dist`), excluding both `is_beam_node` and `is_kinetic` nodes from physical machine chassis occupancy counts. Occupancy tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`), and `remove_capsule` expanded to clean occupancy, unpark waiting capsules, clear visual debug renders, and wake upstream queued traffic. | `get_port_info()`, `get_port_group()`, `get_port_descriptor()`, `update_capsule_occupancy()`, `unregister_capsule_occupancy()`, `remove_capsule()` | `storage`, `capsule-runner`, `flow-engine` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Lifecycle processor managing passenger position sync, 60-tick refrigerated spoilage reduction ($0.10$) bounded to active inventory slots, stack rebuilds via `item_transfer_handler`, tool durability drain, health-based charge tracking (`stack.health`), dynamic quality-scaled cooling capacity via `capsule_defs.get_max_charges(caps_def, stack.quality)` extending active refrigeration up to 25 minutes at Legendary, and spent tool conversion (`spent-refrigerated-capsule`). | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager`, `item-transfer-handler`, `hub-spill`, `capsule-definitions` |
| `capsule-renderer.lua` | `scripts/capsules/` | System-level viewport preparation (`prepare_frame()`) invoked once per tick across `game.players`, allocation-free scratch tables (`scratch_debug_players`, `scratch_debug_keys`), memoized numeric hover peeking (`get_port_info()`), distinct RGBA debug overlay colors per capsule variant, official C++ RenderLayers (`"entity-info-icon-above"`, `"light-effect"`), and dynamic spoilage expiration tracking. | `prepare_frame()`, `render()`, `get_dominant_item()` | `capsule-manager`, `capsule-queries`, `debug-manager` |
| `capsule-runner.lua` | `scripts/capsules/` | Granular Node Hop Motion Engine in v2 mode and Ballistic Kinetic Trajectory Runner for Electromagnetic Projectors. Advances discrete node hops every 6 ticks (staggered per capsule ID via `(current_tick + id) % 6 == 0`, `STAGGER_TICKS = 6`). Multi-hop traversal loop breaks upon entering or traversing prominent kinetic nodes, fixing velocity at exactly 1 prominent hop (5 tiles) per 6 ticks (~50 tiles/sec). Enforces payload identity gatekeeping (`is_electromagnetic_capsule`), rejecting non-EM capsules from entering projector intake ports or launch muzzles. Launch gatekept behind `can_fire(proj_entity)` requiring fully charged 9 MJ buffer (`LAUNCH_ENERGY_JOULES = 9000000`) and endpoint capacity ceiling (`count_endpoint_capsules < MAX_ENDPOINT_CAPSULES`). Deducts 9 MJ upon firing, records launch tick to `storage.projector_last_fired`, and plays audio-visual launch FX. Executes receiver catchment (`catch_in_receiver`) at endpoint hops contacting a receiving `pneumatic-projector` footprint, querying non-muzzle receiver ports for connected external lines, verifying downstream pressure drops (`drop = -ext_level >= 0`), and injecting into logistics tubes or parking at the receiver dock if saturated. Mid-air momentum preservation: `init_capsule_beam_flight` persists projected hop positions (`hop_positions`), direction, and target receiver ID on `capsule.beam_flight`; mid-flight payloads survive sender deconstruction, completing ballistic trajectories at 5 tiles/6 ticks. Player interception: `prepare_player_targets` snapshots character and vehicle bounding boxes once per frame in zero-allocation scratch tables; player contact arrests projectile motion, deals quality-scaled impact damage (`250 * (1 + 0.3 * q_level)`), spawns explosion FX, and spills cargo into red-locked `visible-capsule-holder` spill containers via `hub_spill.spill_capsule`. Terminal crash spillage handles unaligned terminations, cliff dead-ends, or destroyed receivers at the obstacle tile. Features Strict Quality Rank Engine (`Normal` = 1 through `Legendary` = 5), zero-allocation scratch buffers, and $O(1)$ spatial parked index (`storage.parked_by_port`) for targeted neighbor, sister port, and backpressure dock wakeups. Scan horizon registered at `MAX_BEAM_DISTANCE = 500`. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `remove_capsule()`, `matches_filter_item()`, `on_tick` handler | `flow-engine`, `capsule-manager`, `capsule-lifecycle`, `capsule-renderer`, `capsule-queries`, `hub-unpacking`, `hub-spill`, `liminal-surface`, `projector-settings` |

---

### 2.6 Flow v2 Topology, Sensing Wavefront & Counter Range Suite

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-defs.lua` | `scripts/flow/` | Flow port definition registry. Resolves `ghost_name` transparently for ghost entities while bypassing active circuit signal reads. Explicitly replaces overloaded `transmit` with domain-specific transmission flags (`capsule_transmit`, `pressure_transmit`, `sense_transmit`, `kinetic_transmit`). Registers `pneumatic-projector` port definitions: cardinal launch muzzle configured strictly for kinetic routing (`kinetic_transmit = true`, `is_muzzle = true`) with complete pneumatic/sensing isolation (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`); three passive hub-style intake ports (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`). Supports dynamic launch muzzle orientation lookups across built and ghost entities (`storage.ghost_by_pos`). Registers `pneumatic-capsule-counter` sensing ports (`sense = 15`, `sense_transmit = false`, `pressure_transmit = false`, `capsule_transmit = false`). Registers vanilla defensive ports for `stone-wall` (Group 1 North/South, Group 2 West/East) and `gate`. Restricts `port_defs.registered_names` strictly to dedicated structures. | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `flow-engine.lua`, `capsule-runner.lua`, `diverter-renderer.lua`, `counter-range.lua`, `active-device-scanner.lua` |
| `flow-engine.lua` | `scripts/flow/` | Consolidated Event-Driven Wavefront Engine, Spatial Grid Topology Manager, Kinetic Trajectory Engine & Fence Gate Interoperability Controller. Maintains $O(1)$ spatial coordinate lookup (`flow_grid`, `flow_nodes`, `flow_connections`) keyed by `surface@x,y`. Supresses blueprint ghost simulation (`entity-ghost`). Unified delta wavefront queue (`storage.flow_queue`, `storage.counter_queue`, `BATCH_SIZE = 50`) propagating gas pressure flow levels (+10 to +1, -10 to -1), counter sensing range levels (15 decaying to 1), and kinetic beam levels (seed 100 decaying to 0) with 0-tick idle queue sleep. Kinetic trajectories utilize direction-scoped port keys (`"kinetic:<unit>:<dx>,<dy>:<dist>"`). Dual-tier kinetic topology: minor intermediate nodes (`dist % 5 ~= 0`, `is_minor_kinetic = true`, `capsule_transmit = false`) for continuous tile footprint mapping (`storage.kinetic_beam_tiles`) and occlusion interception; prominent nodes (`dist % 5 == 0` or endpoints, `is_prominent_kinetic = true`, `is_beam_node = true`, `capsule_transmit = true`) forming the 5-tile ballistic hop chain. Demotes temporary endpoints back to minor status when obstructions are removed and beams regrow up to `MAX_BEAM_DISTANCE = 500`. Ray-box line-of-sight intersection (`notify_beam_obstruction_changed`, `flow_engine.check_tile_obstruction`) ignores non-blocking entities via `IGNORABLE_TYPES` (resources, corpses, units, combat robots, landmines, proxies). Rotations and power cuts enqueue muzzle tiles to trigger natural 1-tile/tick queue-driven recession; deconstruction triggers instant node purges (`handle_object_destroyed`). Alt-Mode rendering: per-player isolated registries (`storage.kinetic_renders[player_index]`) displaying 0.08r minor dots, 0.16r prominent markers, endpoint target/hazard rings scaled by quality, and 0.12r cyan dots at active projector zero-pressure intake sockets. Handles wall single-axis locking (`storage.wall_locked_group`), terminator gate cutoffs (`storage.gate_cutoff_states`), soft-registry discovery, throttled research activation, research reversal, reactive reorientation, and script-raised entity destruction (`defines.events.script_raised_destroy`). | `flow_engine.register_events()`<br>`flow_engine.init_storage()`<br>`flow_engine.connect_entity(entity)`<br>`flow_engine.disconnect_entity(entity)`<br>`flow_engine.step(tick)`<br>`flow_engine.enqueue_unit_ports(unit)`<br>`flow_engine.draw_flow(...)`<br>`flow_engine.clear_flow_renders(...)`<br>`flow_engine.handle_object_destroyed(...)`<br>`flow_engine.handle_capsule_destroyed(...)`<br>`flow_engine.handle_interop_research_reversed()`<br>`flow_engine.handle_entity_reorientation()`<br>`flow_engine.check_tile_obstruction()`<br>`flow_engine.notify_beam_obstruction_changed()` | `port-defs`, `debug-manager`, `counter-range`, `control.lua`, `capsule-runner`, `active-device-scanner` |
| `counter-range.lua` | `scripts/counters/` | Lightweight Query API & Territory Partitioning Manager for Capsule Counters delegating queueing and propagation to `flow-engine.lua`. Maintains `storage.counter_levels`, `storage.counter_owners`, `storage.counter_queue`, and `storage.counter_owned_nodes`. Provides $O(1)$ segment territory lookups (`counter_range.get_owned_nodes(counter_unit)`), defensive lazy storage initialization, and status debug command (`/check-counters`). | `counter_range.init_storage()`, `counter_range.get_owned_nodes(counter_unit)`, `counter_range.get_owner(port_key)`, `counter_range.get_level(port_key)` | `flow-engine.lua`, `counter-logic.lua`, `debug-manager.lua` |

---

## 3. Event Hook & Lifecycle Matrix

```
+-----------------------------------+------------------------------------+------------------------------------------+
| Factorio Engine Event             | Custom Dispatcher / Handler Module | Actions Triggered                        |
+-----------------------------------+------------------------------------+------------------------------------------+
| script.on_init                    | control.lua -> setup_storage()     | Initializes storage schema (liminal grid,|
| script.on_configuration_changed   | flow_engine.lua                    | occupancy index, counter settings/levels,|
|                                   | proxy-manager.lua                  | projector state tables, kinetic renders, |
|                                   | diverter-renderer.lua              | v2 flow grid/queue, soft registry, fast- |
|                                   | counter-range.lua                  | replace caches, object destruction map); |
|                                   |                                    | purges map orphan proxies via            |
|                                   |                                    | proxy_manager.purge_orphans(); refreshes |
|                                   |                                    | diverter Alt-Mode port filter overlays.  |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_built_entity    | proxy-manager.lua                  | Blueprint ghost exclusion suppresses flow|
| defines.events.on_robot_built_... | active-device-scanner.lua          | node creation. Physical machines inherit |
| defines.events.script_raised_...  | hub-manager.lua                    | ghost settings (<0.1 tile tolerance, axis|
| defines.events.on_space_platform..| device-settings-copier.lua         | alignment guard) or fast-replace cache.  |
| defines.events.on_entity_cloned   | diverter-renderer.lua              | Creates real and ghost circuit proxies,  |
|                                   | flow-engine.lua                    | links sub-proxies (triple-proxy and      |
|                                   |                                    | projector schemas), syncs direction,     |
|                                   |                                    | enforces Z-indexing (selection_priority  |
|                                   |                                    | = 60), merges wires. Grid-touch connects |
|                                   |                                    | physical gates/walls or indexes soft     |
|                                   |                                    | interop. Ray-box checks trigger kinetic  |
|                                   |                                    | truncation or demotion. Wakes ports.     |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_mined... | active-device-scanner.lua          | Fast-replace co-existence scan transfers |
| defines.events.on_robot_mined_... | hub-manager.lua                    | settings proactively and seeds fallback  |
| defines.events.on_entity_died     | proxy-manager.lua                  | cache (60t expiry). Destroys proxies via |
| defines.events.script_raised_...  | flow-engine.lua                    | destroy_all_proxies_at; severs spatial   |
| defines.events.on_space_platform..| hub-spill.lua                      | links, enqueuing drain and recession     |
|                                   | diverter-renderer.lua              | waves; hub-spill handles payload spill   |
|                                   | counter-range.lua                  | excluding mid-flight beam payloads;      |
|                                   |                                    | clearing obstacles clears terminal tags, |
|                                   |                                    | allowing kinetic beams to regrow.        |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_rotated  | proxy-manager.lua                  | Syncs proxy orientation & selection      |
| defines.events.on_player_flipped  | flow-engine.lua                    | Z-indexing; executes modulo port         |
|                                   | active-device-scanner.lua          | rotation (rotate_ports) and flipping     |
|                                   | diverter-settings.lua              | (flip_ports) on diverters. Projectors    |
|                                   | projector-settings.lua             | update muzzle_dir; old muzzle unlinks    |
|                                   |                                    | and recedes 1 tile/t while new vector    |
|                                   |                                    | advances. Re-indexes spatial nodes,      |
|                                   |                                    | updates cutoff states, and enqueues ports|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_research_...    | flow-engine.lua                    | on_research_finished: Migrates matching  |
| (on_research_finished,            |                                    | soft_interop_registry walls/gates into   |
|  on_research_reversed)            |                                    | interop_activation_queue (drained 10/t). |
|                                   |                                    | on_research_reversed: Triggers orderly   |
|                                   |                                    | boundary severing, port enqueuing, and   |
|                                   |                                    | zero-equilibrium soft demotion.          |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_setup_...| device-settings-copier.lua         | Deep-copies settings into blueprint tags |
| (on_player_setup_blueprint)       |                                    | (pneumatic_settings), serializes wire    |
|                                   |                                    | connections via 4-element tuples         |
|                                   |                                    | [entity_from, wire_from, entity_to, ...] |
|                                   |                                    | and invariant bp indices, serializing    |
|                                   |                                    | projector muzzle direction atomically.   |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_blueprint_...  | active-device-scanner.lua          | Stamping blueprints or pasting settings  |
| (on_blueprint_settings_pasted)    | hub-manager.lua                    | updates built/ghost entities in-place    |
|                                   | device-settings-copier.lua         | using pneumatic_settings tags and        |
|                                   |                                    | previous_direction delta rotations.      |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_...      | device-settings-copier.lua         | Scans active blueprint handles & books   |
| (on_player_configured_blueprint)  |                                    | via clean_blueprint_orphans to purge     |
| defines.events.on_gui_closed      |                                    | orphan circuit proxy entity records when |
|                                   |                                    | main devices are removed in blueprint UI.|
+-----------------------------------+------------------------------------+------------------------------------------+
| Custom Input / Pasted Event       | device-settings-copier.lua         | Tracks live entity source in copy buffer |
| (pneumatic-copy-settings,         | active-device-scanner.lua          | (storage.player_copy_buffer), applies    |
|  pneumatic-paste-settings,        | hub-manager.lua                    | relative step rotations on paste, works  |
|  on_entity_settings_pasted)       |                                    | across ghosts/blueprint items/records,   |
|                                   |                                    | and refreshes open destination GUIs.     |
+-----------------------------------+------------------------------------+------------------------------------------+
| custom-input                      | diverter-gui.lua                   | Records confirm_ticks[player_index] to   |
| (pneumatic-confirm-gui)           |                                    | differentiate E (Confirm, apply draft)   |
|                                   |                                    | from Esc (Cancel, discard draft) on      |
|                                   |                                    | modal slot config window closing.        |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_object_destroyed| proxy-manager.lua                  | Auto-destroys unanchored orphan proxies/ |
|                                   | flow-engine.lua                    | ghosts on super force build or fast      |
|                                   |                                    | replacement; maps registration ID,       |
|                                   |                                    | purges destroyed structures or liminal   |
|                                   |                                    | holders, teleports passengers, wakes     |
|                                   |                                    | parked capsules, severs boundary edges,  |
|                                   |                                    | purges projector render objects instantly|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_gui_opened      | pump-gui.lua / diverter-gui.lua    | Diverter, Pump, Counter, Projector & Hub |
| defines.events.on_gui_closed      | hub-gui.lua / counter-gui.lua      | proxies: opens configuration GUI for main|
| defines.events.on_gui_checked_... | hub-spill.lua / gui-components.lua | entity. Spilled containers: dismisses    |
| defines.events.on_gui_switch_...  | debug-manager.lua                  | GUI to permit fast Ctrl+Click looting.   |
| defines.events.on_gui_elem_...    |                                    | Declarative UI component handlers mutate |
| defines.events.on_gui_click       |                                    | settings and trigger notify_settings_... |
|                                   |                                    | to wake parked capsules & sync flow.     |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_lua_shortcut    | debug-manager.lua                  | Master hotbar shortcut (pt-debug-panel): |
|                                   |                                    | Toggles Pneumatic Control Panel GUI.     |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_custom_input    | capsule-inputs.lua ->              | Triggers capsule_runner.emergency_eject  |
| (capsule-emergency-exit / Shift+E)| capsule-runner.lua                 | for passenger disembarkation, holder     |
|                                   |                                    | destruction, and tracking unregistration.|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_tick            | active-device-scanner.lua          | 15t scanner loop (Pumps/Diverters/Counter|
|                                   |                                    | signal recalculations & power states;    |
|                                   |                                    | Projector 3 MW baseline power & 9 MJ     |
|                                   |                                    | capacitor recharge readiness); prunes    |
|                                   |                                    | fast_replace_cache records (>60t).       |
|                                   | hub-manager.lua                    | Decoupled 1t continuous belt siphon and  |
|                                   |                                    | deposit; interleaved 10t hub packing     |
|                                   |                                    | scan; receive lock reset; prunes         |
|                                   |                                    | hub_fast_replace_cache (>60t).           |
|                                   | hub-spill.lua                      | 60t spilled empty container cleanup.     |
|                                   | flow-engine.lua                    | Wavefront step (pressure, sensing, and   |
|                                   |                                    | kinetic propagation at 1 tile/t); drains |
|                                   |                                    | interop queue; monitors cutoff states.   |
|                                   | capsule-runner.lua                 | Granular 6t staggered node hops;         |
|                                   |                                    | ballistic 5-tile prominent hops; player  |
|                                   |                                    | collision damage; receiver catchment;    |
|                                   |                                    | 60t liminal refrigeration charge decay.  |
+-----------------------------------+------------------------------------+------------------------------------------+
```

---

## 4. Persistent Storage Schema (`storage`)

All persistent runtime state is preserved in Factorio's `storage` table:

```lua
storage = {
  -- Dual-Tier Off-Grid Liminal Surface Cell Allocation Engine
  liminal_grid = {
    next_wide_index = 0,
    next_tight_index = 0,
    wide_free_slots = {}, -- Stack of recycled slot indices for Wide 8-tile domain (y >= 0)
    tight_free_slots = {} -- Stack of recycled slot indices for Tight 2-tile domain (y <= -100)
  },

  -- O(1) Spatial Occupancy Index ([unit_number][net_id][group] = capsule_count)
  occupancy = {
    [101] = {
      [1] = {
        [1] = 1 -- 1 capsule occupying unit 101, network 1, port group 1
      }
    }
  },

  -- Flow v2 Engine Spatial Topology & Propagation Engine Schemas
  flow_grid = {
    ["nauvis@10.5,20.5"] = {
      ["101:1"] = true -- Set of port key strings overlapping spatial coordinate string
    }
  },
  flow_nodes = {
    ["101:1"] = {
      key = "101:1",
      unit_number = 101,
      port_index = 1,
      group = 1,                 -- Port group ID for internal flow isolation
      capsule_transmit = true,   -- Permission for capsule motion across entity
      pressure_transmit = true,  -- Permission for gas pressure flow propagation
      sense_transmit = false,    -- Permission for counter sensing range propagation
      kinetic_transmit = false,  -- Permission for kinetic trajectory propagation
      cross_transit = true,      -- Permission for capsule motion across machine
      emitter = 10,              -- Active flow emission level (+10 output, -10 intake, nil neutral)
      sense = 15,                -- Active sensing range seed level (0 or 15)
      pos = { x = 10.5, y = 20.5 },
      surface = "nauvis",
      entity = LuaEntity,
      -- Kinetic Field Annotations (for direction-scoped kinetic ports)
      is_minor_kinetic = false,      -- Intermediate 1-tile node for occlusion mapping
      is_prominent_kinetic = false,  -- 5-tile ballistic hop node
      is_beam_node = false,          -- Registered node in kinetic ballistic trajectory
      is_endpoint = false,           -- Terminal hop indicator
      hit_receiver = nil,            -- Unit number of aligned receiving projector
      beam_owner = nil               -- Unit number of sending projector
    }
  },
  flow_connections = {
    ["101:1"] = {
      ["102:2"] = true -- Set of active external spatial port connections
    }
  },
  flow_queue = {
    ["101:1"] = true -- FIFO/Set queue of port keys requiring pressure or kinetic evaluation
  },
  flow_levels = {
    ["101:1"] = 10 -- Dynamic calculated flow level integer (-10 .. +10)
  },
  flow_unit_ports = {
    [101] = { "101:1", "101:2" } -- Recorded port keys associated with entity unit number
  },

  -- Kinetic Trajectory Propagation & Alt-Mode Rendering Overlays
  kinetic_levels = {
    ["kinetic:101:0,-1:5"] = 100 -- Distance-decayed kinetic guide level (100 down to 0)
  },
  kinetic_beam_tiles = {
    ["nauvis@10.5,15.5"] = {
      ["kinetic:101:0,-1:5"] = true -- Map of spatial coordinates to active kinetic port keys
    }
  },
  kinetic_renders = {
    [player_index] = {
      ["kinetic:101:0,-1:5"] = {
        circle = LuaRenderObject, -- 0.08r minor dot, 0.16r prominent marker, or endpoint ring
        target_ring = LuaRenderObject
      }
    }
  },

  -- Defensive Structures Interoperability & Dynamic Boundary State
  active_walls = { [unit_number] = LuaEntity },              -- Physical stone-wall entities linked to network
  active_gates = { [unit_number] = LuaEntity },              -- Physical gate entities linked to network
  gate_open_states = { [unit_number] = true },               -- Open/closed polling cache for terminator gates
  gate_cutoff_states = { [unit_number] = true },             -- Outer boundary terminator cutoff state tracking
  wall_locked_group = { [unit_number] = 1 },                 -- Active locked port group ID (1 = N/S, 2 = W/E)
  soft_interop_registry = { [unit_number] = LuaEntity },     -- Pre-research touching boundary walls/gates
  interop_activation_queue = { [unit_number] = LuaEntity },  -- Rate-limited activation queue (10/tick)

  -- Fast-Replace & Upgrade Positional Settings Fallback Caches
  fast_replace_cache = {
    ["nauvis@10.5,20.5"] = {
      settings = { ... },                                    -- Deep-copied pump, diverter, counter, or projector settings
      tick = 123456                                          -- Destruction tick timestamp (pruned after 60 ticks)
    }
  },
  hub_fast_replace_cache = {
    ["nauvis@10.5,20.5"] = {
      settings = { ... },                                    -- Deep-copied hub_settings
      tick = 123456                                          -- Destruction tick timestamp (pruned after 60 ticks)
    }
  },

  -- Capsule Counter Wavefront Territory & Persistence Schemas
  counter_levels = {
    ["101:1"] = 15 -- Sensing wavefront distance level (15 down to 1)
  },
  counter_owners = {
    ["101:1"] = 105 -- Unit number of owning physical capsule counter entity
  },
  counter_owned_nodes = {
    [105] = { ["101:1"] = true, ["102:2"] = true } -- Map of node keys owned by counter unit
  },
  counter_queue = {
    ["101:1"] = true -- Set of port keys requiring sensing wavefront evaluation
  },
  counter_settings = {
    [dev_id] = {
      vessels_target = "green", -- Target wire channel: "off", "red", "green", "both"
      cargo_target = "red",
      total_target = "green",
      total_signal = { type = "virtual", name = "signal-C", quality = "normal" }
    }
  },

  -- O(1) Spatial Parked Capsule Index
  parked_by_port = {
    ["101:1"] = {
      [capsule_id] = true -- Set of capsule IDs parked waiting at port key
    }
  },

  -- Ghost Entity Registry & Spatial Location Map
  ghost_devices = { [unit_number] = LuaEntity },
  ghost_hubs = { [unit_number] = LuaEntity },
  ghost_by_pos = { ["nauvis@10.5,20.5"] = unit_number_or_spatial_id },
  ghost_directions = { ["ghost@pneumatic-diverter@nauvis@10.5,20.5"] = 4 },

  -- Player Copy-Paste Live Source Buffer & Port Clipboard
  player_copy_buffer = {
    [player_index] = { source = LuaEntity, direction = 0 }
  },
  port_clipboard = {
    [player_index] = { filter_enabled = true, filter_mode = "whitelist", slots = { ... } }
  },

  -- Object Destruction Registration Mapping
  object_destruction_map = {
    [registration_id] = { type = "entity", unit_number = 101 },
    [registration_id_2] = { type = "capsule", id = 5 }
  },

  -- Spilled Capsule Container Tracking (Fast Looting with set_bar(1) clamping)
  spilled_containers = {
    [unit_number] = LuaEntity
  },

  -- Hub Container Registry, Operational Settings & Mechanical Latches
  active_hubs = { [unit_number] = LuaEntity },
  hub_settings = {
    [unit_number] = {
      can_send = true, use_circuit_send = false, nest_capsules = false,
      send_condition = { first_signal = { type = "item", name = "iron-plate" }, comparator = "<", constant = 100 },
      can_receive = true, use_circuit_receive = false,
      receive_condition = { first_signal = nil, comparator = "<", constant = 0 },
      use_receive_lock = true, read_red = true, read_green = true
    }
  },
  hub_receive_locks = { [unit_number] = true },

  -- Pump Management & Power/Enable State Tracking
  active_pumps = { [unit_number] = LuaEntity },
  pump_power_states = { [unit_number] = true },
  pump_enabled_states = { [unit_number] = true },
  pump_settings = {
    [unit_number] = {
      enabled = true, use_circuit_enable = false,
      enable_condition = { first_signal = { type = "virtual", name = "signal-everything" }, comparator = ">", constant = 0 },
      read_red = true, read_green = true
    }
  },

  -- Pneumatic Diverter System Tracking & Port Configuration
  active_diverters = { [unit_number] = LuaEntity },
  diverter_power_states = { [unit_number] = true },
  diverter_port_states = { [unit_number] = { North = true, East = true, South = true, West = true } },
  diverter_settings = {
    [unit_number] = {
      ports = {
        North = {
          enabled = true, mode = "output", filter_enabled = false, filter_mode = "whitelist",
          slots = {
            { item = "iron-plate", comparator = "=", quality = "normal", quality_comparator = "=", explicit_quality = false },
            ...
          },
          _compiled = { active = true, is_blacklist = false, slots = { ... } },
          use_circuit_enable = false, enable_condition = { first_signal = nil, comparator = "=", constant = 0 }
        },
        East = { ... }, South = { ... }, West = { ... }
      },
      read_red = true, read_green = true
    }
  },

  -- Electromagnetic Projector Facility State Tracking
  active_projectors = { [unit_number] = LuaEntity },
  projector_power_states = { [unit_number] = true },
  projector_enabled_states = { [unit_number] = true },
  projector_muzzle_states = { [unit_number] = defines.direction.north },
  projector_ready_states = { [unit_number] = true },
  projector_last_fired = { [unit_number] = 123456 },
  projector_settings = {
    [unit_number] = {
      muzzle_dir = defines.direction.north, enabled = true, use_circuit_enable = false,
      enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
      read_red = true, read_green = true
    }
  },

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity, type = "capsule", capsule_type = "electromagnetic-capsule",
      primary_slot = 1, position = { x = 0, y = -100 },
      grid_index = 5, is_wide = false, dominant_item = "iron-plate", dominant_quality = "normal",
      has_spoilable_items = false, definition = { ... }
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1, capsule_id = capsule_id, source_hub = 101, from_port_key = "101:1", to_port_key = "102:2",
      _occ_block_key = "102:2", progress = 0.45, passenger = LuaPlayer, slot_spoil_percents = { [1] = 0.12 },
      last_failed_hub = 102, last_failed_hub_count = 15, last_failed_hub_bar = 10, last_failed_cap_count = 1,
      beam_flight = {
        hop_positions = { { x = 10.5, y = 15.5 }, ... },
        current_hop_idx = 1, dir = { x = 0, y = -1 }, target_receiver = 105
      }
    }
  },

  -- Per-Player Debug System State
  debug = {
    [player_index] = {
      master = true, capsules = true, peek = false, flow = true, prints = false,
      new_flow = true,      -- Pressure Flow v2 & kinetic beam rendering overlay toggle
      counter_range = true, -- Capsule Counter sensing range overlay toggle
      filter = "string"     -- Console debug print prefix filter string
    }
  }
}
```

---

## 5. Core Algorithms & Operational Mechanics

### 5.1 Flow v2 Wavefront Engine, Domain Isolation & Sensing Unification (`scripts/flow/flow-engine.lua`)
1. **$O(1)$ Spatial Grid Topology:** Entities register port nodes onto `storage.flow_nodes` and key tile positions into `storage.flow_grid` via formatted coordinate keys (`surface@x,y`). Adjacent matching ports form bidirectional edges in `storage.flow_connections`. Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent structures without global graph scans.
2. **Explicit Domain Transmission Isolation:** Port definitions specify explicit domain booleans (`capsule_transmit`, `pressure_transmit`, `sense_transmit`, `kinetic_transmit`). Active machines explicitly set flags to isolate gas pressure and sensing ranges while permitting mechanical capsule or kinetic flight.
3. **Unified Pressure, Sensing & Kinetic Wavefront Step:** Replaces global graph sweeps with a multi-domain 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue` (pressure & kinetic levels) and `storage.counter_queue` (sensing range levels). Kinetic trajectories advance and recede through this queue identically to gas pressure.
4. **Deterministic Territory Tie-Breaking:** Equal-distance sensing wavefront collisions (`cand_level == max_cand_level`) resolve deterministically using lowest entity `unit_number` tie-breaking, guaranteeing contiguous counter territory splits across shared tube networks.
5. **0-Tick Queue Sleep:** When no flow, sensing, or kinetic levels change, queues empty. On subsequent ticks, `flow_engine.step()` returns on line 1 in 0.00 ms CPU time with zero Lua GC allocations.
6. **Natural 1-Tile-per-Tick Recession Waves:** Disconnecting, rotating, or unpowering machines enqueues root ports without pre-wiping downstream levels, triggering frame-by-frame 1-tile-per-tick recession waves.
7. **Decoupled Overlay Rendering:** Alt-Mode pressure flow overlays (`draw_flow`, `clear_flow_renders`), kinetic beam overlays, and counter range overlays operate independently.

### 5.2 $O(1)$ Spatial Occupancy Index & Target-Based Blocking Model (`capsule-queries.lua`)
1. **Constant-Time Spatial Lookup Matrix:** `storage.occupancy` maintains multi-level spatial buckets indexed by `[unit_number][net_id][group]`. Occupancy queries execute in $O(1)$ constant time.
2. **Topology Direct Querying:** `get_port_group()` and `get_port_descriptor()` query v2 spatial topology in `storage.flow_nodes` directly. Parsers natively recognize direction-scoped kinetic keys (`"kinetic:<unit>:<dx>,<dy>:<dist>"` with `port_index = 100 + dist`).
3. **Projector Chassis Occupancy Decoupling:** In-flight kinetic nodes (`is_beam_node` and `is_kinetic`) are excluded from physical machine chassis occupancy counts, enabling continuous projectile launches without blocking the sending projector dock.
4. **Target-Based Blocking Occupancy:** Moving capsules track a target blocking key (`_occ_block_key = to_port_key`). Committing to a destination target segment blocks capacity at the destination node while immediately freeing the origin node capacity (`from_port_key`) for upstream capsules.
5. **Unparking & Cleanup Dispatch:** `remove_capsule` cleans occupancy buckets, unparks waiting capsules from `storage.parked_by_port`, clears visual debug renders, and wakes upstream queued traffic waiting at the freed port key.

### 5.3 Granular Node Hop Motion Engine & Positive Pressure Drops (`scripts/capsules/capsule-runner.lua`)
1. **Granular Node Hop Motion:** Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop capability (`MAX_NODE_HOPS_PER_STEP = 3`) for instantaneous internal machine transitions.
2. **Strict Positive Pressure Gradient Target Selection:** `select_next_target` evaluates candidate outbound hops, requiring `capsule_transmit = true` and a strictly positive pressure drop (`touching_level - target_level > 0`) or intake vacuum pull.
3. **Strict Outbound Hub Pressure Differential Enforcement:** Outbound hub dispatch (`inject_from_hub` and `find_best_hub_outbound_port`) evaluates pressure drops (`touching_level - target_level`) per individual touching port with `max_drop = 0` initialization.
4. **Metadata Emitter Traversal:** Uses node metadata (`node.emitter`) rather than entity name matching to handle pump push (`emitter < 0` to `emitter > 0` with `drop = math.huge`). Passive hub and projector ports have `emitter = nil` to avoid false unpowered emitter evaluation.
5. **Zero-Allocation Persistent Scratch Buffers:** Module-level persistent scratch tables eliminate table allocations (`{}`) during path evaluation, candidate scoring, and neighbor wakeups.

### 5.4 0-Tick Lockstep Queue Advancement & Edge-Formation Wakeups (`scripts/capsules/capsule-runner.lua` / `flow-engine.lua`)
1. **0-Tick Lockstep Queue Advancement:** The exact tick a parked capsule transitions to moving or arrives, `update_capsules()` invokes `wake_parked_capsules(prev_from)`, triggering instant queue advancement for upstream queued capsules on the same tick.
2. **Targeted Network-Scoped Wakeup Engine:** `wake_parked_capsules(target)` uses `storage.parked_by_port`, sister unit ports, and connected edges to wake strictly the parked capsules affected by a freed route or entity state change.
3. **Edge-Formation Wakeup Synchrony:** When new connection edges form in `storage.flow_connections`, `flow_engine.connect_entity` invokes `wake_port_parked` on both ends of the edge, advancing queued traffic on the exact tick an edge opens.
4. **Stale Motion State Reset:** Stale origin port memory (`capsule.last_port_key`) is cleared whenever a capsule enters a parked state or receives a target wakeup.

### 5.5 Multi-Item Unpacking Failure Guard & Zero-Allocation Space Simulation (`hub-unpacking.lua`)
1. **$O(1)$ Destination Failure State Guard:** Capsules parked at full/blocked hub destinations track failure state parameters (`last_failed_hub`, `last_failed_hub_count`, `last_failed_hub_bar`, `last_failed_cap_count`). If container inventory has not freed up, full space simulation (`can_insert_all`) is short-circuited in constant time.
2. **Zero-Allocation Space Simulation:** `can_insert_all()` utilizes flat module-level scratch arrays to simulate multi-item inventory insertion across active chest slots (`get_bar() - 1`), ignoring primary shell slots for single-use capsules (`destroy_self`).
3. **Targeted Failure Cache Invalidation:** When a route opens or network state changes, `wake_parked_capsules()` clears `capsule.last_failed_hub = nil`, triggering immediate unpacking re-evaluation.

### 5.6 Native Quality-Aware Diverter Filtering & Overlay Specification (`scripts/capsules/capsule-runner.lua` / `diverter-renderer.lua` / `gui-components.lua`)
1. **Strict Factorio 2.0 Quality Rank Engine:** Maps quality tiers cleanly from `Normal` (rank 1) through `Legendary` (rank 5). Supports explicit quality rank comparisons, wildcard quality matching (`"Any Quality"`), standalone quality filtering, and comparator math (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`) in `matches_filter_item`.
2. **Centralized Filter Display Specification:** `gui_components.get_filter_display_spec` centralizes Factorio 2.0 native filter display rules across slot buttons and Alt-Mode world overlays.
3. **Inward Topological Shift & High-Contrast Backing Frame:** `diverter-renderer.lua` applies `PORT_INWARD_OFFSET = 0.55` inward directional vectors to shift filter clusters away from port flow dots. Renders 1.3x scaled pitch-black silhouette outlines on `render_layer = "entity-info-icon"` and full-color icons, quality badges, comparators, and blacklist symbols on `"entity-info-icon-above"`.
4. **Native Inserter Parity:** Whitelist empty ports render a standalone centered "no" symbol. Blacklist configured ports render prominent "no" symbols centered over individual item icons. Empty blacklist ports suppress overlays.
5. **Recursive Downstream Lookahead Validation:** `is_hop_valid()` inspects downstream external hops when evaluating internal machine transfers, preventing entry into ports leading to full or filter-disqualified tube lines.
6. **Memoized Filter Compilation:** Filter slots and blacklist modes are compiled onto `port_setting._compiled`, enabling early-exit evaluation on whitelist matches.
7. **Targeted Diverter Capacity Expansion:** Multi-port diverters support `DEFAULT_CAPACITY = 2`, allowing up to 2 capsules to transit through internal diverter ports simultaneously.

### 5.7 Centralized Metadata Engine & Equipment Grid Transfer (`item-transfer-handler.lua`)
1. **Centralized Metadata Preservation:** Item stack migrations attempt native `dest_slot.transfer_stack(src_stack)` calls first, preserving 100% of equipment grids (`stack.grid`), installed modules, shield/energy levels, spoilage, health, durability, ammo, and quality.
2. **$O(1)$ Equipment Grid Copying & Restoration:** Fallback stack extractions execute `copy_equipment_grid()` to clone equipment grids (`create_grid()`) and transfer installed equipment (`name`, `position`, `quality`, `energy`, `shield`).
3. **`item-with-tags` API Guard:** `build_stack_spec()` extracts stack attributes while strictly guarding `tags` and `custom_description` access behind `is_item_with_tags` checks.

### 5.8 Dynamic Spoilage Expiration & Zero-Overhead Render Polling (`capsule-renderer.lua` / `hub-packing.lua`)
1. **Spoilability Detection at Packing:** `is_stack_spoilable()` computes a `has_spoilable_items` flag persisted in `storage.active_capsules`.
2. **Dynamic Spoilage Expiration Guard:** In `capsule-renderer.lua`, `get_dominant_item()` inspects active container slots. If cargo spoils mid-flight, it updates `cap_data.dominant_item` to the spoiled product and flips `has_spoilable_items` to `false` once zero spoilable stacks remain.
3. **0-Tick Scan Suppression:** Once `has_spoilable_items` transitions to `false`, 60-tick periodic inventory re-scans are permanently suppressed, serving cached dominant item icons directly from memory in $O(1)$ time.
4. **Valid Render Layer Hierarchy & Distinct Color Overlay:** Debug rings and payload icons render on official C++ RenderLayers (`"entity-info-icon-above"` for rings/icons, `"light-effect"` for HUD text). Each capsule variant displays a distinct RGBA debug border ring.

### 5.9 Fast-Looting Spilled Containers & Single-Use Bio Shell Dissolution (`hub-spill.lua` / `hub-unpacking.lua`)
1. **Single-Use Bio Shell Dissolution:** Biological primary capsule shells (`destroy_self = true`) dissolve cleanly upon arrival or spillage; primary shell slots are purged before transferring or spilling cargo.
2. **Fast-Looting Operability:** Spilled container entities (`visible-capsule-holder`) use `operable = true` to allow native Ctrl+Click fast-looting transfers.
3. **Instant GUI Dismissal:** An `on_gui_opened` listener sets `player.opened = nil` on the exact tick a spilled container is clicked, hiding the container GUI window.
4. **0-Tick Red-Locking Clamping:** Container creation applies `set_bar(1)`, red-locking all slots against manual item insertion while permitting item extraction.
5. **Throttled Cleanup Scan:** A 60-tick periodic scanner (`process_spilled_containers`) evaluates empty spilled containers, destroying empty entities with `{ raise_destroy = true }`.

### 5.10 Silent Object Destruction & Sandbox Purge Engine (`defines.events.on_object_destroyed`)
1. **Typed Object Destruction Registry:** Valid pneumatic structures, circuit proxies, and liminal capsule holder entities register with Factorio's `script.register_on_object_destroyed`. Registration handles map into `storage.object_destruction_map`.
2. **Silent Sandbox Purge Fallback:** Bulk entity wipes via Sandbox mode, super force building, chunk deletions, or script destructions dispatch to structured handlers (`handle_object_destroyed` and `handle_capsule_destroyed`).
3. **Silent Cargo & Surface Cleanup:** Destroyed capsule holders on `liminal_surface` are removed cleanly without spilling items. Riding passengers are safely teleported back to valid ground positions.
4. **Network Topology & Flow Queue Unlinking:** Entity destructions trigger spatial disconnection (`disconnect_entity`), clearing port nodes, severing spatial connection edges, and waking queued traffic.

### 5.11 Triple-Proxy Architecture, Selection Z-Indexing & Zero Signal Bleed (`scripts/proxy-manager.lua` / `counter-logic.lua`)
1. **Triple-Proxy Registry Architecture:** Registers a primary terminal proxy (`pneumatic-capsule-counter-circuit-proxy`, `selection_priority = 60`, `operable = true`) alongside hidden channel proxies (`pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy`, `selection_priority = 0`, `operable = false`). Spawns, teleports, and connects internal Red/Green wire bridges (`connect_sub_proxies`) on build/rotate events.
2. **Channel-Isolated Signal Dispatch:** `counter_logic.update_signals` writes Red-target signals strictly to the Red channel proxy and Green-target signals strictly to the Green channel proxy while keeping terminal proxy filters empty, eliminating cross-channel signal bleed.
3. **Spatial Selection Priority Stack Z-Indexing:** Configures terminal proxy prototypes with `selection_priority = 60` (higher than main machines at `50`). Invokes `proxy.teleport(pos)` on build/rotate events to re-insert proxies at the top of Factorio's spatial selection stack.
4. **Additive Proxy Wire Merging:** `transfer_wire_connections` iterates over source `LuaWireConnector` ports and copies wire connections onto surviving real proxies via `connect_to()`, preserving pre-existing circuit networks.
5. **Orphan Auto-Destruction & Multi-Proxy Pruning:** `proxy_manager.destroy_all_proxies_at` purges all associated proxies upon entity removal.

### 5.12 Unified Active Device Background Scanner (`scripts/active-device-scanner.lua`)
1. **Consolidated 15-Tick Background Loop:** Unifies background 15-tick power, circuit, signal recalculation, and capacitor recharge monitoring for physical and ghost machines (`pneumatic-pump`, `pneumatic-diverter`, `pneumatic-capsule-counter`, and `pneumatic-projector`).
2. **Extensible Device Type Registration:** Supports device specification registration (`register_device_type`) handling lifecycle hooks and evaluating power/circuit enable states in constant time.
3. **Projector State & Capacitor Monitoring:** Evaluates projector 3 MW baseline power (`MINIMUM_ENERGY_JOULES = 3000000`), circuit conditions, muzzle orientation changes, and 9 MJ buffer readiness (`can_fire`), triggering port enqueuing and wakeups immediately when ready.
4. **Centralized Notification API:** Exposes `notify_settings_changed(entity)` to re-evaluate enable states, clear filter caches, trigger counter logic, enqueue ports into `flow_engine`, wake parked capsules, and update Alt-Mode overlays.

### 5.13 Live Entity Settings Copy-Paste, Ghost Parity & Blueprint Serialization (`scripts/device-settings-copier.lua` / `active-device-scanner.lua` / `hub-manager.lua`)
1. **Live Entity Source Tracking:** Stores live `LuaEntity` handles in `storage.player_copy_buffer` during copy operations, dynamically evaluating settings and relative directions at paste execution.
2. **Projector Directional Serialization:** Computes relative muzzle direction deltas during live Shift+Left-Click copy-paste and blueprint stamping, preserving configured launch muzzles across orientations.
3. **Native Factorio 2.0 Blueprint Settings Pasted Event:** Subscribes to `defines.events.on_blueprint_settings_pasted` to capture blueprint tags (`pneumatic_settings`) and relative directional changes (`previous_direction`).
4. **Atomic 4-Tuple Blueprint Wire Serialization:** Iterates over proxy circuit connectors and serializes wire connections into 4-element tuples (`[entity_from, wire_type_from, entity_to, wire_type_to]`). Performs instant zero-state spatial wire target resolution on the build tick (`process_entity_built_wire_tags`).
5. **Strict Ghost Settings Adoption & Blueprint Orphan Purging:** Physical entities replacing ghosts inherit configurations when matching spatial tolerance (<0.1 tiles), orientation axis alignment, and prototype real names. Purges orphan proxy records from blueprint books (`clean_blueprint_orphans`).

### 5.14 Declarative UI Widget Component Library, Draft Lifecycle & Quality Engine (`scripts/utils/gui-components.lua` / `diverter-gui.lua` / `counter-gui.lua` / `pump-gui.lua`)
1. **Declarative UI Widget Library:** Standardizes window construction (`create_relative_window`), headers with dragging support (`add_header` with `drag_target = parent_frame`), card frames, wire channel toggles, circuit condition panels (55px dropdowns), 40x40 overlay slot buttons, and 3x3 spatial arrow selectors.
2. **Dual-Device UI Controller:** `pump-gui.lua` manages both `pump_configuration_frame` and `projector_configuration_frame`, dynamically rendering titles, manual enable toggles, wire toggles, and circuit condition panels.
3. **Quality Control Bar Engine:** Renders quality comparator dropdowns, 5-tier quality sprite radio buttons, checkmark confirm buttons, and selection highlight styles.
4. **Isolated Draft Working State & Confirm/Cancel Lifecycle:** Modal pop-ups isolate edits inside `draft_filters`. Confirm (✓ or `E`) commits settings; Cancel (X or `Esc`) discards changes without mutating machine state.
5. **Per-Port Copy-Paste & Native Tool Buttons:** Port card headers include native tool buttons copying isolated port configuration tables into `storage.port_clipboard[player_index]` with cursor feedback.

### 5.15 Hub Binary Nesting, Smart Dynamic Bar Clamping & Fractional Cargo (`hub-settings.lua` / `hub-packing.lua` / `cargo-planner.lua`)
1. **Binary Nesting State Persistence:** `hub_settings` includes a `nest_capsules = false` default property preserved across copy-paste and blueprint deserialization.
2. **Spent Hull Outbound Packing Priority:** `hub_packing.evaluate_inventory` evaluates candidate capsules using a tiered priority hierarchy targeting spent hulls (`SPENT_CAPSULES`) first, standard cargo capsules second, and lowest-health charged capsules last. Outbound freight drafts empty shells home to base recharge infrastructure while preserving working unloader capsules in outpost hubs.
3. **Fractional Cargo Capacity Accounting:** `cargo-planner.lua` evaluates item slot costs using `mixed_quantity = true` for electromagnetic capsules, scaling slot volume consumed proportionally by item stack sizes (`base_slot_cost / stack_size`).
4. **Smart Dynamic Post-Packing Inventory Bar Clamping:** Packing extractions transfer items using full inventory depth, evaluate `last_occupied_slot`, and invoke `dest_inv.set_bar(last_occupied_slot + 1)` to lock trailing empty slots cleanly.

### 5.16 Capsule Counter Segment Territorial Logic & Channel-Isolated Emission (`scripts/counters/counter-logic.lua`)
1. **Segment Territory Resolution:** Resolves owned tube segment nodes (`counter_range.get_owned_nodes`) bounded by sensing range boundaries and rival counter wavefront splits.
2. **Payload Aggregation:** Queries active capsules in territory without double-counting, breaking down capsule vessel items/qualities, cargo contents, and total capsule counts.
3. **Channel-Isolated Proxy Signal Emission:** Dispatches Red-target signals strictly to `pneumatic-capsule-counter-red-proxy` and Green-target signals strictly to `pneumatic-capsule-counter-green-proxy` while preserving selected signal quality levels. Clears output signals when unpowered or unconfigured.

### 5.17 Pressure-Driven Bidirectional Belt Interface, Continuous 60Hz Cadence, Engine-Filtered Querying & Cargo-First Ejection (`scripts/hubs/packing/belt-siphon.lua` / `hub-manager.lua`)
1. **1-Tick Continuous 60Hz Belt Interface Cadence:** Decoupled `belt_siphon.process_belts(entity)` from the 10-tick interleaved hub packing scan. Belt siphon and exhaust routines execute on every tick for active hubs, allowing transport lines to accept items/stacks the instant space clears, eliminating gaps and achieving 100% belt compression.
2. **Pressure & Inventory Fast-Path Early Exits:** Reordered checks in `process_belts` to evaluate `get_hub_net_pressure` first, skipping neutral and unpressurized hubs with zero entity/inventory overhead. Added `chest_inv.is_empty()` checks and native C++ `chest_inv.find_item_stack("vacuum-capsule")` lookups to eliminate full 48-slot Lua iterations across non-siphon hubs.
3. **Engine-Filtered Adjacent Belt Querying:** `find_adjacent_belts` passes `type = BELT_SEARCH_TYPES` (`transport-belt`, `underground-belt`, `splitter`, `linked-belt`) directly to `surface.find_entities_filtered`, allowing the C++ engine to filter out non-belt structures before allocating Lua entity arrays.
4. **3-Tier Cargo-First Deposit Priority Hierarchy:** Refactored `find_deposit_candidate_slot` into a 3-tier candidate selector (`Pure Cargo > Spent Capsules > Secondary Charged Capsules`). Bulk cargo empties onto transport lines before dead shells, preventing belt contamination and allowing chest-mounted filter inserters to extract spent capsules directly into recycling lines.
5. **Near-Lane Parallel Sideloading & Gleba Stacking:** Outbound belts access all transport lines; parallel passing belts strictly sideload onto the near transport line touching the hub wall. Evaluates `force.belt_stack_size_bonus` to deposit vertical item stacks in a single action via `line.insert_at_back(spec, allowed_stack)`.
6. **Quality-Scaled Durability & Depletion:** Base durability of 500 charges on `vacuum-capsule` scales via `capsule_defs.get_max_charges(def, quality)` up to 1,250 charges at Legendary. Belt operations deduct 1 health charge point per individual item transferred. Depleted capsules convert instantly into `spent-vacuum-capsule` shells inside the hub chest, preserving quality and equipment grids.

### 5.18 Pneumatic Fence Gate & Wall Interoperability, Wavefront Discovery & Dynamic Terminator Cutoff (`scripts/flow/flow-engine.lua` / `port-defs.lua`)
1. **Vanilla Defensive Interoperability Research:** Researching `pneumatic-fence-gate-interoperability` authorizes the flow engine to incorporate vanilla `stone-wall` and `gate` entities into pneumatic routing without modifying base entity prototypes.
2. **Dual-Channel Wall Ports & Axis Locking:** Walls feature 4 boundary ports split into two isolated orthogonal groups. Applying pressure flow ($P \ne 0$) or counter sensing ($S > 0$) engages an exclusive directional axis lock (`storage.wall_locked_group[unit_number] = group_id`), disabling transmission on the idle pair. Depressurization clears the lock, restores transmission flags, and wakes queued capsules.
3. **Terminator Gate State Cutoff & Sensing Persistence:** When an outer boundary terminator gate opens, `capsule_transmit` and `pressure_transmit` flags are disabled to contain cargo and gas while leaving `sense_transmit = true` intact, preserving Capsule Counter territorial ownership and signal emission. Closing any gate restores all transmission flags.
4. **Dynamic Terminator Boundary Sync:** `storage.gate_cutoff_states` monitors `(is_open and is_gate_terminator)` during background steps. Placing, rotating, or deconstructing adjacent gates dynamically applies or lifts terminator cutoffs.
5. **Reactive Grid-Touch & Lazy Discovery:** Built defensive structures touching registered ports connect immediately. Open boundary wavefront propagation discovers and connects adjacent walls tile-by-tile within the queue without recursive flood-fills.
6. **Boundary Soft-Registry & Throttled Activation:** Defensive structures placed adjacent to flow prior to research are indexed into `storage.soft_interop_registry`. Completing research migrates entities into `storage.interop_activation_queue` (drained at 10/tick).
7. **Research Reversal & Reactive Reorientation:** Reversing research cleanly severs boundary edges and demotes depressurized walls/gates to soft storage. Rotating or flipping gates and walls reconnects aligned structures and disconnects misaligned ones dynamically.

### 5.19 Fast-Replace Settings Inheritance & Positional Fallback Cache (`scripts/active-device-scanner.lua` / `scripts/hubs/hub-manager.lua`)
1. **Co-Existence Spatial Resolution:** `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` query and discover replacement entities co-existing on the exact tile during Factorio's fast-replace transition window.
2. **Proactive Destruction-Phase Settings Transfer:** Destruction listeners identify replacement entities in-place and execute a direct deep-copy transfer (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `projector_settings.copy`, `hub_settings.copy`) before wiping the old unit number from storage.
3. **Tick-Scoped Positional Fallback Cache:** Deep-copied settings are cached in `storage.fast_replace_cache` or `storage.hub_fast_replace_cache` keyed by spatial coordinate strings, adopted upon placement, and automatically pruned after 60 ticks.

### 5.20 Blueprint Ghost Simulation Exclusion & Physical Entity State Decoupling (`scripts/flow/flow-engine.lua`)
1. **Flow Grid Ghost Exclusion:** `flow_engine.connect_entity` early-exits if `entity.name == "entity-ghost"`. Blueprint ghost tubes, walls, gates, counters, and projectors do not create port nodes, channel pressure, or display phantom overlays.
2. **Decoupled C++ State Polling:** Ghost gates, counters, and projectors bypass runtime polling tables (`storage.active_gates`, `storage.active_counters`, `storage.active_projectors`), preventing C++ method assertion crashes.

### 5.21 Specialized Space Age Capsule Economics, Crafting Categories & Standardized Rocket Payload (`prototypes/recipe.lua` / `prototypes/item.lua` / `scripts/capsules/capsule-definitions.lua`)
1. **Planetary Environmental Conditions & Crafting Categories:** Specialized capsule recipes enforce planetary environment constraints:
   - `vacuum-capsule`: restricted to 0 pressure (space platforms, `{"crafting"}`).
   - `reinforced-capsule`: restricted to 4000 hPa (Vulcanus, `{"metallurgy"}`, Foundry +50% prod).
   - `refrigerated-capsule`: restricted to 300 hPa (Aquilo, `{"cryogenics"}`, Cryogenic Plant, 10.0s craft time, `main_product = "refrigerated-capsule"`). Closed-loop thermal exchange consumes 100 cold fluoroketone and returns 100 hot fluoroketone with net-zero coolant loss.
   - `electromagnetic-capsule` & `pneumatic-projector`: restricted to >= 99% magnetic field (Fulgora, `{"electromagnetics"}`, Electromagnetic Plant +50% prod).
   - `biodegradable-capsule` & all capsule recharge recipes remain unrestricted across surfaces.
2. **Standardized 50 kg Rocket Payload Capacity:** Explicit `weight = 50 * kg` across all 9 active and spent capsule prototypes and infrastructure items (`pneumatic-projector`), establishing a consistent 20-unit rocket launch payload capacity ($1000\text{ kg} / 50\text{ kg} = 20$).
3. **Closed-Loop Vacuum Repressurization:** `recharge-vacuum-capsule` removes battery costs in favor of closed-loop electric repressurization (`spent-vacuum-capsule = 1`, `energy_required = 2.0`, `allow_productivity = false`).
4. **Refrigerated Cooling Lifespan Expansion:** Base durability is set to 600 charges on `refrigerated-capsule`, extending active refrigeration to 10 minutes at Normal quality and up to 25 minutes at Legendary quality (`allow_productivity = false` on recharge).
5. **Gleba Organic Repackaging Loop:** `biodegradable-capsule` crafts from Gleba staples (`1 yumako-mash`, `1 jelly`, `2 spoilage`), yielding 10 capsules per craft (15 in Biochambers).

### 5.22 Electromagnetic Projector: Unified Kinetic Wavefront Propagation & Dual-Tier Node Topology (`scripts/flow/flow-engine.lua` / `scripts/flow/port-defs.lua`)
1. **Unified Flow Wavefront Integration:** Kinetic beam propagation is integrated directly into the core delta wavefront queue (`storage.flow_queue`, `flow_engine.step`), advancing and receding tile-by-tile at 1 tile per tick with 0-tick idle queue sleep.
2. **Direction-Scoped Node Topology:** Port keys use direction-scoped identifiers (`"kinetic:<unit>:<dx>,<dy>:<dist>"` with `port_index = 100 + dist`). This prevents key collisions during entity rotation, allowing obsolete trajectories to smoothly drain and recede while new directions advance without orphaned nodes.
3. **Dual-Tier Kinetic Node Classification:**
   - **Minor Nodes (`dist % 5 ~= 0`):** Registered with `is_minor_kinetic = true`, `capsule_transmit = false`. Indexed in `storage.flow_nodes`, `storage.flow_grid`, and `storage.kinetic_beam_tiles` for continuous building occlusion detection and footprint mapping.
   - **Prominent Nodes (`dist % 5 == 0` or endpoints):** Registered with `is_prominent_kinetic = true`, `is_beam_node = true`, `capsule_transmit = true`. Form the sequential 5-tile ballistic hop chain in `storage.flow_connections`.
4. **Dynamic Endpoint Demotion on Advance:** When obstructions are removed and the beam advances, former temporary endpoints that do not align with natural hop intervals (`dist % 5 ~= 0`) have `is_endpoint` and `hit_receiver` cleared, cleanly demoting `is_prominent_kinetic`, `is_beam_node`, and `capsule_transmit` back to false.
5. **Ray-Box Line-of-Sight & Obstacle Interception:** `flow_engine.check_tile_obstruction` and `notify_beam_obstruction_changed` perform cardinal ray-box intersection scans against placed structures. Building over an active beam initiates queue-driven recession back to the obstacle; removing an obstruction clears terminal tags and re-propagates the beam up to `MAX_BEAM_DISTANCE = 500`.
6. **Ignorable Obstruction Filtering:** `IGNORABLE_TYPES` (`resource`, `corpse`, `character-corpse`, `unit`, `fish`, `combat-robot`, `land-mine`, and circuit proxies) are evaluated via exact $O(1)$ set lookups, allowing kinetic trajectories to pass freely across ore patches, corpses, and ambient creatures without collision or crash spillage. Listens to `defines.events.script_raised_destroy` for programmatic container cleanups.
7. **Queue-Driven Recession on Rotation & Brownouts:** Rotating or unpowering a projector unlinks the muzzle from Tile 1 and enqueues Tile 1 into `storage.flow_queue`, receding the old beam at 1 tile per tick while the new muzzle vector advances forward. Synchronous instant purges are strictly scoped to entity destruction in `handle_object_destroyed`.
8. **Passive Intake Port Parity & Isolation:** Launch muzzles operate with strict kinetic routing (`kinetic_transmit = true`, `is_muzzle = true`) and pneumatic/sensing isolation (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`). Intake ports operate with hub-style passive dock parity (`flow = 0`, `emitter = nil`, `pressure_transmit = false`, `sense_transmit = false`), entering incoming capsules freely without vacuum draw or false emitter evaluation.

### 5.23 Ballistic Motion Runner: 6-Tick Prominent Hops, Receiver Catchment & Terminal Crash Mechanics (`scripts/capsules/capsule-runner.lua`)
1. **Standard 6-Tick Ballistic Cadence & Prominent Hops:** Kinetic trajectories advance along prominent nodes (`dist % 5 == 0` or endpoints) at standard `STAGGER_TICKS = 6` cadence (`(current_tick + id) % 6 == 0`), bypassing intermediate minor nodes. An early-exit break in the multi-hop traversal loop upon traversing prominent kinetic nodes fixes velocity at exactly 5 tiles per 6 ticks (~50 tiles/sec).
2. **Electromagnetic Payload Identity Gatekeeping:** Enforces `is_electromagnetic_capsule` identity checks across `is_hop_valid` and `select_next_target`, rejecting non-electromagnetic capsules from entering projector intake ports or launch muzzles. Incoming capsules from tubes park safely in the intake dock.
3. **Receiver Catchment & Tube Network Injection:** `catch_in_receiver` captures capsules arriving at endpoint hops contacting a receiving `pneumatic-projector` footprint. Dynamically queries non-muzzle receiver ports for connected external pneumatic lines, validates tube capacity, enforces downstream pressure drops (`drop = -ext_level >= 0`, rejecting positive back-pressure), and injects payloads into outbound logistics tubes or parks them safely at the receiver dock if lines are saturated.
4. **Terminal Crash Spillage & Mid-Flight Severance:** Unaligned beam terminations, cliff dead-ends, or destroyed receivers route into `hub_spill.spill_capsule` at the endpoint coordinate, spawning an explosion and deploying red-locked `visible-capsule-holder` spill containers (`set_bar(1)`). If a beam is obstructed mid-flight, line-of-sight raycasting detects the obstacle and crashes the payload at the obstacle tile.
5. **Ballistic Momentum Preservation Across Sender Deconstruction:** `init_capsule_beam_flight` snapshots projected hop coordinates (`hop_positions`), direction, and target receiver ID on `capsule.beam_flight` upon launch. If the sending projector is mined or destroyed mid-transit, in-flight capsules continue advancing along cached ballistic hops at 5 tiles/6 ticks, reaching downstream receivers or triggering crash spillage at the terminal tile without nil errors. Mid-flight beam payloads are excluded from sender deconstruction spillage.
6. **Zero-Allocation Player Interception & Quality-Scaled Impact Damage:** `prepare_player_targets` snapshots character and vehicle bounding boxes across connected players once per frame using module-level scratch tables (`scratch_player_targets`). Trajectory player interception halts projectile motion on contact, applies native `impact` damage scaled by machine quality (`250 * (1 + 0.3 * q_level)`), spawns an explosion, and spills cargo into red-locked spill containers via `hub_spill.spill_capsule`.

### 5.24 Projector Capacitor Discharge Mechanics, Backpressure Throttling & Alt-Mode Rendering (`scripts/projector-settings.lua` / `scripts/flow/flow-engine.lua` / `scripts/capsules/capsule-runner.lua`)
1. **9 MJ Buffer Discharge & Recharge Grace Period:** Ballistic dispatch requires a fully charged 9 MJ electrical buffer (`LAUNCH_ENERGY_JOULES = 9000000`, evaluated via `can_fire` with 10 kJ tolerance). Deducts 9 MJ from `proj_entity.energy` upon hop commitment or point-blank player collision, logging the dispatch tick to `storage.projector_last_fired`. Grants a 180-tick (`RECHARGE_GRACE_TICKS`) grace period following launch, preventing the kinetic guide beam and Alt-Mode overlays from collapsing while stored energy replenishes from 0 to 3 MW baseline.
2. **Endpoint Congestion Throttling & Backpressure Wakeups:** `count_endpoint_capsules` evaluates ballistic paths and aggregates capsules parked at beam endpoints, receiver chassis ports, and active in-flight beam payloads against `MAX_ENDPOINT_CAPSULES = 2`. When capacity is reached, incoming capsules park safely at the sending intake dock. Freeing tube capacity at the receiver dispatches immediate backpressure wakeups to the sender's ports (`beam_owner`) to resume launches in lockstep.
3. **Per-Player Kinetic Render Isolation:** `storage.kinetic_renders` is indexed by player (`storage.kinetic_renders[player_index]`) and keyed by port key `pkey`. Intersecting or opposing beams occupying the same physical air tiles maintain isolated render handles, preventing a receding beam from erasing another's visuals.
4. **Discrete Per-Tile Visuals & Quality Scaling:** Replaces continuous laser lines with subtle discrete markers: 0.08-radius filled dots on minor nodes, 0.16-radius charged markers every 5th hop, and contextual target rings (cyan/green for aligned receivers, coral hazard indicators for severed or open-air paths). `QUALITY_BEAM_PALETTE` scales thickness (4.0px to 6.0px) and shifts color from holmium magenta to radiant white-magenta across quality tiers.
5. **Passive Intake Port Overlay Rendering:** Detects zero-flow non-muzzle ports belonging to active `pneumatic-projector` units, rendering a 0.12-radius filled cyan dot (`PROJECTOR_INTAKE_COLOR`) in Alt-Mode to clearly mark attachment sockets while preserving normal pressure displays when lines become pressurized.

---

## 6. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/pneumatic-panel` | Opens or toggles the master Pneumatic Control Panel Lua GUI frame (`debug_manager.toggle_panel()`). Alias: `/debug-panel`. | `scripts/debug-manager.lua` |
| `/debug-filter <text>` | Sets the debug chat message prefix filter string in player storage (`storage.debug[player_index].filter`), suppressing console prints that do not match the specified prefix string. | `scripts/debug-manager.lua` |
| `/debug-filter-reset` | Clears the debug chat message prefix filter string, allowing all active debug prints to display in console. | `scripts/debug-manager.lua` |
| `/toggle-debug` | Toggles master debug mode on/off for the executing player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging output for the executing player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles v2 visual flow vectors, pressure numbers, spatial connection overlays, and kinetic beam trajectories in Alt Mode for the executing player (`storage.debug[player_index].new_flow`). Alias: `/pt-toggle-flow`. | `scripts/debug-manager.lua` |
| `/toggle-counter-range` | Toggles Capsule Counter sensing range wavefront overlays and owner color dots in Alt Mode for the executing player (`storage.debug[player_index].counter_range`). Alias: `/pt-toggle-counter-range`. | `scripts/debug-manager.lua` |
| `/check-counters` | Displays debug status, total registered counter entities, queue lengths, and owned territory node counts across all active counters in chat console. | `scripts/counters/counter-range.lua` |
| `/toggle-capsules` | Toggles visual rendering overlay for active capsule positions and dominant payload item icons (`storage.debug[player_index].capsules`). Mutually exclusive with `/toggle-capsule-peek`. | `scripts/debug-manager.lua` |
| `/toggle-capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering item icons strictly for capsules occupying targeted pneumatic structures. Alias: `/capsule-peek`. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |
| `/clear-renders` | Destroys and reconstructs all active Alt-Mode pressure, counter range, and kinetic beam rendering overlays during sandbox testing (`debug_manager.clear_all_renders()`). Alias: `/pt-clear-renders`. | `scripts/debug-manager.lua` |

---

## 7. Render Layers, Selection Priorities & Visual Overlay Specification

### 7.1 Runtime Script Render Layers (`rendering.draw_*`)

> **Engine Note on Primitive vs. Sprite Rendering:**  
> In Factorio's Lua API, explicit `render_layer` parameters are accepted by sprite/animation methods (`rendering.draw_sprite`, `rendering.draw_animation`, `rendering.draw_light`). Primitive vector shapes (`rendering.draw_circle`, `rendering.draw_line`, `rendering.draw_text`) are dispatched directly to Factorio's dedicated script rendering overlay pass (controlled vertically via `draw_on_ground = true/false`).

| Render Layer Name / Target Pass | Module Source | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `"light-effect"` | `capsule-runner.lua` | Text | `rendering.draw_text` | No | Renders `" [Shift + E] Emergency Eject "` HUD text centered above riding passenger capsules (`scale = 0.9`, offset `y + 0.8`). |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders cyan passenger ring (`radius = 0.45`, `width = 3`) around player-occupied capsules. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders capsule variant debug border ring (`radius = 0.35`, `width = 2`) using capsule RGBA debug colors. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Sprite | `rendering.draw_sprite` | No (Debug) | Renders dominant payload item icon (`"item/" .. item_name`, `scale = 0.55`) inside capsule debug ring. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders filled color dot (`radius = 0.25`) for empty or unknown cargo capsules. |
| `"entity-info-icon"` | `diverter-renderer.lua` | Sprite | `rendering.draw_sprite` | **Yes** | Renders pitch-black 1.3x scaled centered outline sprite and drop shadow backing frames for port filter overlays. |
| `"entity-info-icon-above"` | `diverter-renderer.lua` | Sprite / Text | `rendering.draw_sprite` / `rendering.draw_text` | **Yes** | Renders full-color filter item icons, bottom-left quality badges, non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`), standalone quality badges, and per-slot prominent blacklist symbols (`scale * 0.88`). |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Kinetic minor node dot: renders subtle filled dot (`radius = 0.08`, holmium magenta scaled by quality tier) on intermediate 1-tile trajectory steps. |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Kinetic prominent hop marker: renders charged circle (`radius = 0.16`, `width = 2`, quality-scaled color) every 5 tiles along active beams. |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Kinetic endpoint indicator: renders target ring (`radius = 0.35`, cyan/green for aligned receivers, coral hazard for open-air or severed terminations). |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Projector passive intake overlay: renders filled cyan dot (`radius = 0.12`, `PROJECTOR_INTAKE_COLOR`) on zero-pressure non-muzzle intake sockets. |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Counter sensing range overlay: renders filled owner color dot (`radius = 0.12`) on owned tube nodes. |
| *Default Script Layer* | `flow-engine.lua` | Text | `rendering.draw_text` | **Yes** | Counter sensing range overlay: renders sensing range level integer (`15` down to `1`, white text, `scale = 0.65`) centered above tube nodes. |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Spatial junction pressure overlay (`pos_key`): renders exactly 1 pressure marker circle per tile (radius = 0.15, cyan/blue for positive pressure, orange/red for intake vacuum) using dominant pressure magnitude (`math.abs(level)`). |
| *Default Script Layer* | `flow-engine.lua` | Text | `rendering.draw_text` | **Yes** | Spatial junction pressure overlay (`pos_key`): renders exactly 1 pressure integer level text (`-10` to `+10`, white text, `scale = 0.7`) above junction circles. |
| *Default Script Layer* | `flow-engine.lua` | Line | `rendering.draw_line` | **Yes** | Renders flow vector connection lines (`width = 3`, cyan/orange) between adjacent connected tube ports (suppressing zero-length vector lines). |

---

### 7.2 Spatial Selection Priority & Z-Index Stack

| Selection Priority | Entity Name / Spec | Source File | Z-Index & Interaction Behavior |
| :---: | :--- | :--- | :--- |
| **60** | `pneumatic-pump-circuit-proxy`<br>`pneumatic-diverter-circuit-proxy`<br>`pneumatic-capsule-counter-circuit-proxy`<br>`pneumatic-projector-circuit-proxy` | `proxy-manager.lua`<br>`pneumatic-projector.lua` | Top selection stack priority. Re-inserted via `proxy.teleport(pos)` on build/rotate events to guarantee Red/Green wire tool and Wire Cutter targeting above base entities. Clicks open device configuration GUIs. |
| **50** | `pneumatic-pump`<br>`pneumatic-diverter`<br>`pneumatic-capsule-counter`<br>`pneumatic-projector`<br>`capsule-hub-horizontal`<br>`capsule-hub-vertical`<br>`pneumatic-tube`<br>`junction`<br>`crossflow-junction` | `entity.lua`<br>`pneumatic-diverter.lua`<br>`pneumatic-capsule-counter.lua`<br>`pneumatic-projector.lua` | Standard physical machine and structure selection priority. `pneumatic-pump`, `pneumatic-capsule-counter`, and `pneumatic-projector` prototypes include `gui_mode = "all"` to support native entity interaction dispatching (`on_gui_opened`). |
| **Vanilla Priority** | `stone-wall`<br>`gate` | Base Game | Standard defensive structures participating in pneumatic routing via `pneumatic-fence-gate-interoperability`. |
| **0** | `pneumatic-capsule-counter-red-proxy`<br>`pneumatic-capsule-counter-green-proxy` | `pneumatic-capsule-counter.lua` | Hidden channel proxy prototypes with `operable = false` and `draw_selection_box = false` for isolated internal channel signal wiring. |

---

### 7.3 Prototype Sprite Priorities & Layer Composite Specs

| Entity Prototype | Property Path | Priority Value | Scale & Tint Details |
| :--- | :--- | :---: | :--- |
| `pneumatic-tube` | `picture.north/east/south/west.layers[].priority` | `"extra-high"` | Scale `0.5`, green tint (`{r=0.5, g=0.9, b=0.5}`). |
| `pneumatic-pump` | `pictures.north/east/south/west.priority` | `"high"` | Scale `0.5`, orange tint (`{r=1.0, g=0.7, b=0.3}`). |
| `pneumatic-capsule-counter` | `picture.north/east/south/west.layers[].priority` | `"high"` | Scale `0.5`, decider combinator sprite composite with distinct teal tint (`{r=0.30, g=0.85, b=0.70}`). |
| `pneumatic-projector` | `animation.layers[].priority` | `"high"` | Centered 3x3 footprint, scale `0.75`, electromagnetic plant chassis animation with magenta tint (`{r=0.9, g=0.2, b=0.8}`). |
| `capsule-hub-horizontal` | `picture.layers[]` | Default | Dual steel chest composite, scale `0.5`, blue-grey tint (`{r=0.6, g=0.8, b=1.0}`). |
| `capsule-hub-vertical` | `picture.layers[]` | Default | Dual steel chest composite, scale `0.5`, cyan-grey tint (`{r=0.4, g=0.9, b=0.9}`). |
| `visible-capsule-holder` | `picture.layers[]` | Default | Iron chest composite, scale `0.25`. |
| `junction` | `picture.layers[]` | Default | Iron chest composite, yellow tint (`{r=1.0, g=0.9, b=0.3}`). |
| `crossflow-junction` | `picture.layers[]` | Default | Iron chest composite, purple tint (`{r=0.8, g=0.4, b=0.9}`). |
| `pneumatic-diverter` | `animation.layers[]` | Default | Assembling machine 2 animation composite, emerald tint (`{r=0.25, g=0.80, b=0.60}`). |

---

### 7.4 Capsule Variant Debug Overlay Color Registry

| Capsule Variant | Localized / Description | RGBA Color Code | Rendering Usage |
| :--- | :--- | :--- | :--- |
| `item-capsule` | Metallic Gold | `{ r = 1.0, g = 0.84, b = 0.0, a = 0.9 }` | Standard cargo capsule border ring/dot overlay. |
| `biodegradable-capsule` | Emerald Green | `{ r = 0.2, g = 0.90, b = 0.2, a = 0.9 }` | Biodegradable capsule border ring/dot overlay. |
| `refrigerated-capsule` | Frost Cyan | `{ r = 0.2, g = 0.85, b = 1.0, a = 0.9 }` | Cold biological capsule border ring/dot overlay. |
| `spent-refrigerated-capsule` | Slate Grey | `{ r = 0.6, g = 0.65, b = 0.7, a = 0.9 }` | Spent refrigerated capsule border ring/dot overlay. |
| `reinforced-capsule` | Violet Purple | `{ r = 0.8, g = 0.30, b = 1.0, a = 0.9 }` | Reinforced bulk cargo capsule border ring/dot overlay. |
| `electromagnetic-capsule` | Holmium Magenta | `{ r = 0.9, g = 0.20, b = 0.7, a = 0.9 }` | Electromagnetic mixed cargo capsule border ring/dot overlay. |
| `vacuum-capsule` | Deep Vacuum Blue | `{ r = 0.1, g = 0.40, b = 0.9, a = 0.9 }` | Vacuum belt siphon capsule border ring/dot overlay. |
| `spent-vacuum-capsule` | Muted Steel Grey | `{ r = 0.5, g = 0.55, b = 0.6, a = 0.9 }` | Spent vacuum capsule border ring/dot overlay. |
| `player-transit-capsule` | Crimson Orange | `{ r = 1.0, g = 0.40, b = 0.1, a = 0.9 }` | Passenger transit capsule border ring/dot overlay. |