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
   | Build / Rotate / Flip / Mine / Object Destroyed / Custom Input / GUI Events
   v                                                                        v Motion on_tick
+------------------------------------+      +---------------------------------------+
|  RUNTIME SIMULATION LAYER          |      |  FLOW v2 ENGINE SUITE                 |
|  - hub-manager (Interleaved Scan)  |      |  - flow-engine (`scripts/flow/`)      |
|  - active-device-scanner (Unified  |      |    (Event-Driven Delta Wavefront      |
|    15-Tick Scanner for Pumps/Div)  |      |    Engine, 0-Tick Idle Queue Sleep,   |
|  - proxy-manager (Centralized Proxy|      |    Spatial Grid Topology surface@x,y, |
|    Lifecycle, Z-Index & Wire Merge)|      |    Object Destruction Purge Engine)   |
|  - device-settings-copier (Copy-   |      |  - port-defs (`scripts/flow/`)        |
|    Paste, Blueprint Wire Sync &    |      |  - capsule-runner (`scripts/capsules/`|
|    Blueprint Orphan Sanitization)  |      |    Granular 6t Hop Motion Engine,     |
|  - diverter-renderer (Alt-Mode 2x2 |      |    Strict Quality Rank Engine,        |
|    Port Filter Icon Overlay Engine)|      |    Zero-Alloc Scratch Buffers,        |
|  - gui-components (Declarative UI  |      |    O(1) Spatial Parked Index,         |
|    Library & Quality Widget Bar)   |      |    Targeted Neighbor Wakeups)         |
|  - hub-packing / unpacking / spill |      +---------------------------------------+
|  - liminal-surface (Dual-Tier Grid)|                          |
+------------------------------------+                          |
                   |                                            |
                   | Delegates Operations                       |
                   +------------------------------------------->|
                                                                v
+-----------------------------------------------------------------------------------+
|  PERSISTENT STORAGE (`storage`) & ZERO-ALLOCATION DEBUG OVERLAYS                  |
|  - storage.flow_nodes / storage.flow_grid / storage.flow_connections              |
|  - storage.flow_queue / storage.flow_levels / storage.flow_unit_ports             |
|  - storage.parked_by_port ([port_key][capsule_id] O(1) Spatial Parked Index)      |
|  - storage.object_destruction_map ([reg_id] = { type, unit_number | id })        |
|  - storage.occupancy ([unit_number][net_id][group] O(1) Spatial Buckets)          |
|  - storage.liminal_grid (Dual-tier Wide y>=0 / Tight y<=-100 coordinate domains)  |
|  - storage.spilled_containers (Fast-looting containers with set_bar(1) clamping)  |
|  - storage.bp_wire_cache / storage.pending_bp_wires (Blueprint wire buffers)     |
|  - storage.bio_integrity_levels (Per-force research tier cache)                   |
|  - storage.active_capsules (Dominant item & quality) / active_hubs / receive_locks|
|  - storage.active_pumps / storage.pump_power_states / pump_enabled_states         |
|  - storage.active_diverters / storage.diverter_power_states / diverter_settings   |
|  - storage.debug[player_index] (Master debug, overlays, filter, control panel)    |
|  - debug-manager / flow-engine overlays / capsule-renderer                        |
+-----------------------------------------------------------------------------------+
```

---

## 2. All-Encompassing Module Directory

### 2.1 Root & Prototype Stage Files

| File | Sub-Path | Purpose & Role | Key Exports / Prototypes | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| `info.json` | `/` | Mod metadata manifest. | Defines mod ID (`nukedpenguin-pneumatic-tube-transport`), version (`0.1.0`), title, Factorio version (`base >= 2.1.0`), expansion dependencies (`space-age >= 2.1.0`), optional (`? quality`). | Factorio Engine |
| `data.lua` | `/` | Prototype stage entry point. Loads item, recipe, entity, technology, custom input, shortcut, diverter, pump circuit proxy, and wildcard quality badge sprite prototypes. | Loads prototype files via strict top-level `require`. Registers `pneumatic_any_quality_badge` sprite. | Data Stage |
| `settings.lua` | `/` | Mod startup settings registration. Obsolete `pneumatic-flow-version` setting removed; execution is locked strictly to the v2 flow engine. | Data stage settings registration. | Data Stage |
| `control.lua` | `/` | Runtime script entry point. Imports top-level script modules (`proxy_manager`, `active_device_scanner`, `device_settings_copier`, `diverter_renderer`, `flow_engine`, `capsule_runner`, `hub_manager`), executes storage setup migrations, initializes v2 flow schemas, purges map orphan proxies (`proxy_manager.purge_orphans()`), refreshes Alt-Mode overlays, and registers event listeners unconditionally. | Hooks `script.on_init`, `script.on_configuration_changed`, requires active logic scripts at top level. | Script Stage |
| `custom-input.lua` | `prototypes/` | Custom input hotkey definitions. | Defines `capsule-emergency-exit` (`SHIFT + E`), `pneumatic-copy-settings` (linked to `copy-entity-settings`), and `pneumatic-paste-settings` (linked to `paste-entity-settings`). | `data.lua` |
| `entity.lua` | `prototypes/` | Registers mod entities in Factorio data stage. Configures expanded `inventory_size = 255` for `invisible-capsule-holder` and `visible-capsule-holder`. Configured `inventory_type = "with_filters_and_bar"` on `capsule-hub-horizontal` and `capsule-hub-vertical`. Registers `additional_pastable_entities` across `pneumatic-pump`, `pneumatic-diverter`, and `capsule-hub`. | Defines `capsule-hub-horizontal`, `capsule-hub-vertical`, `invisible-capsule-holder`, `visible-capsule-holder`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`. Tinted visuals. | `data.lua` |
| `item.lua` | `prototypes/` | Prototype item, tool, custom item-group, and subgroup definitions for placeable structures and transport capsules. | Registers `pneumatics` item group, `pneumatic-transport` & `pneumatic-capsules` subgroups. Defines items: `item-capsule`, `biodegradable-capsule`, `refrigerated-capsule` (tool, 100 durability), `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, structures. | `data.lua` |
| `pneumatic-diverter.lua` | `prototypes/` | Physical diverter machine prototype and invisible circuit proxy definition. Configured `placeable_by = { item = "pneumatic-diverter", count = 0 }`, `"player-creation"` flag, elevated selection priority (`selection_priority = 60`), `operable = true`, compact footprint, and `additional_pastable_entities`. | Defines `pneumatic-diverter` and `pneumatic-diverter-circuit-proxy`. | `data.lua` |
| `pneumatic-pump-proxy.lua` | `prototypes/` | Circuit proxy prototype definition for pneumatic pumps. Configured `placeable_by = { item = "pneumatic-pump", count = 0 }`, `"player-creation"` flag, elevated selection priority (`selection_priority = 60`), and `operable = true`. | Defines `pneumatic-pump-circuit-proxy`. | `data.lua` |
| `pneumatic-diverter-proxy-linkage.lua` | `prototypes/` | *Deprecated.* Proxy linkage lifecycle consolidated into `scripts/proxy-manager.lua`. | Legacy stub. | `proxy-manager.lua` |
| `pneumatic-pump-proxy-linkage.lua` | `prototypes/` | *Deprecated.* Proxy linkage lifecycle consolidated into `scripts/proxy-manager.lua`. | Legacy stub. | `proxy-manager.lua` |
| `recipe.lua` | `prototypes/` | Crafting recipes for all mod items, structures, junctions, diverters, and specialized capsule variants. Standardized for Factorio 2.1 via `categories = { "category-name" }` array tables. Adds `recharge-refrigerated-capsule` recipe restoring `spent-refrigerated-capsule` using 125 units cold fluoroketone while yielding 100 units hot fluoroketone byproduct. | Defines recipes with `enabled = false` for technology unlock gating and explicit `energy_required` craft times. | `data.lua` |
| `shortcut.lua` | `prototypes/` | Shortcut bar prototype registration (`pt-debug-panel`) with localized tooltip headers and `toggleable = true` support. | Defines master hotbar debug shortcut prototype. | `data.lua` |
| `technology.lua` | `prototypes/` | Research tree prototype nodes incorporating Space Age science packs (`agricultural-science-pack`, `cryogenic-science-pack`). Structured into science and planet progression tiers: Red/Green (`pneumatic-transport`), Blue (`specialized-pneumatic-capsules`), Gleba (`biodegradable-capsule`), Vulcanus (`reinforced-capsule`), and Aquilo (`refrigerated-capsule`). Binds explicit prerequisite tech nodes for ingredient chains. Roots `bio-capsule-integrity-1` through `4` at `biodegradable-capsule`. | Defines technology progression nodes and upgrade research tiers. | `data.lua` |

---

### 2.2 System Framework & Surface Management

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. | `events.on_event(event_id, handler)` | System-wide event listeners |
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`) and Pneumatic Control Panel Lua GUI controller (`open_panel`, `close_panel`, `toggle_panel`, `refresh_panel`). Manages console log prefix filtering, v2 Alt Mode flow overlay toggles, shortcut syncing, and console commands (`/pneumatic-panel`, `/toggle-debug`, `/toggle-prints`, `/toggle-flow`, `/toggle-capsules`, `/toggle-capsule-peek`). | `debug_print(...)`, `is_debug_active(...)`, `open_panel()`, `close_panel()`, `toggle_panel()`, `sync_shortcuts()` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `liminal-surface.lua` | `scripts/surfaces/` | Dual-Tier Spatial Grid allocation engine (`allocate_position`, `release_position`, `storage.liminal_grid`). Distributes standard non-spoilable cargo into Tight slots (2-tile spacing, $y \le -100$) and spoilable/unit cargo into Wide cells (8-tile spacing, $y \ge 0$). Manages separate recycling stacks (`wide_free_slots`, `tight_free_slots`). Synchronous chunk generation (`ensure_chunk_at`). | `liminal_surface.get()`, `allocate_position(is_wide)`, `release_position(index, is_wide)`, `ensure_chunk_at()` | `hub-packing.lua`, `hub-unpacking.lua`, `capsule-manager.lua` |
| `item-transfer-handler.lua` | `scripts/utils/` | Centralized item metadata preservation & stack transfer engine. Preserves 100% of Factorio 2.0 item metadata: equipment grids (`stack.grid`), installed modules, shield/energy states, quality, spoilage, durability, health, ammo, and custom tags. | `copy_equipment_grid(src, dest)`<br>`build_stack_spec(stack)`<br>`transfer_stack(src, dest_inv)`<br>`transfer_inventory(src_inv, dest_inv)`<br>`spill_stack(surface, pos, stack)` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-spill.lua`, `capsule-lifecycle.lua` |
| `gui-components.lua` | `scripts/utils/` | Centralized declarative UI widget builder library & quality control bar engine. Renders relative window frames, titles, wire channel toggles, circuit condition panels (55px dropdown width), 40x40 overlay slot buttons, quality control bar widgets, and 3x3 spatial arrow selectors. Manages right-click slot clearing, explicit quality tracking, native Factorio quality default rules, and high-contrast white text label formatting. | `create_relative_window()`, `add_header()`, `add_card_frame()`, `add_wire_channel_toggles()`, `add_circuit_condition_panel()`, `create_overlay_slot_button()`, `add_quality_control_bar()`, `add_spatial_arrow_selector()`, `clear_filter_slot()`, `handle_filter_item_change()` | Device GUIs (`pump-gui`, `diverter-gui`, `hub-gui`) |
| `proxy-manager.lua` | `scripts/` | Centralized Proxy Linkage & Lifecycle Engine (`storage.object_destruction_map`). Manages hidden real and ghost circuit proxies across build, destroy, rotate, flip, clone, and GUI opening events. Enforces spatial selection precedence (`selection_priority = 60`, `proxy.operable = true`, `proxy.teleport`), additive wire merging (`transfer_wire_connections`), orphan proxy/ghost auto-destruction, deduplication, and surface-wide orphan purging (`purge_orphans`). Exposes `get_registered_proxies()` and `get_registered_mains()`. | `proxy_manager.register_pair()`, `proxy_manager.register_events()`, `proxy_manager.purge_orphans()`, `proxy_manager.get_registered_proxies()`, `proxy_manager.get_registered_mains()` | `control.lua`, `device-settings-copier`, `active-device-scanner` |
| `device-settings-copier.lua` | `scripts/` | Centralized Device Settings Copier, Blueprint Serialization, Ghost Wire Linking & Blueprint Sanitization Engine. Listens to custom input copy/paste commands and `on_entity_settings_pasted`. Handles `on_player_setup_blueprint` (4-tuple wire schema, metadata tag serialization), `on_player_configured_blueprint` / `on_gui_closed` (purges orphan proxies from blueprints/books via `clean_blueprint_orphans`), and restores blueprint wire connections on built and ghost entities (`process_entity_built_wire_tags`). | `device_settings_copier.register_events()`, `clean_blueprint_orphans()`, `process_entity_built_wire_tags()` | `control.lua`, `proxy-manager`, `active-device-scanner` |

---

### 2.3 Active Machine State Managers & Overlays

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `active-device-scanner.lua` | `scripts/` | Unified 15-tick background scanner monitoring active machine entities (`pneumatic-pump` and `pneumatic-diverter`). Manages power and circuit enable state monitoring, filter cache clearing, flow engine unit port enqueuing, parked capsule wakeups (`notify_settings_changed`), Alt-Mode overlay updates, and build/clone settings tag restoration (`pneumatic_settings`). | `register_device_type()`, `register_events()`, `notify_settings_changed()` | `proxy-manager`, `diverter-renderer`, `flow-engine`, `capsule-runner` |
| `diverter-renderer.lua` | `scripts/` | Alt-Mode Diverter Port Filter Overlay Renderer. Queries topological port offsets via `port_defs.get_ports(entity)` to display up to 4 configured filter item icons per port in adaptive 2x2 grids using Factorio 2.0 `rendering.draw_sprite` (`only_in_alt_mode = true`, `render_layer = "entity-info-icon"`). Managed by `active_device_scanner` notifications, build handlers, and surface load scans. | `diverter_renderer.update_render(entity)`, `diverter_renderer.clear_render(unit_number)` | `control.lua`, `active-device-scanner` |
| `diverter-manager.lua` | `scripts/` | *Deprecated stub.* Replaced by `active-device-scanner.lua`. Forwards GUI notifications directly to `active_device_scanner.notify_settings_changed(entity)`. | Lightweight backward-compatible stub. | `active-device-scanner.lua` |
| `pump-manager.lua` | `scripts/` | *Deprecated stub.* Replaced by `active-device-scanner.lua`. Forwards GUI notifications directly to `active_device_scanner.notify_settings_changed(entity)`. | Lightweight backward-compatible stub. | `active-device-scanner.lua` |

---

### 2.4 Hub System & Cargo Packing / Unpacking

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `hub-definitions.lua` | `scripts/hubs/` | Configuration registry for hub entity container capacities. | Registry `hub_definitions.types` | `hub-manager.lua`, `hub-packing.lua` |
| `hub-settings.lua` | `scripts/hubs/` | Hub state storage and operational mode evaluator (`can_send`, `can_receive`, `use_receive_lock`), providing circuit condition evaluation, `.copy()` deep-copy helper, and `apply_blueprint_settings()` tag deserialization. | `hub_settings.get()`, `hub_settings.can_send()`, `hub_settings.can_receive()`, `hub_settings.apply_blueprint_settings()` | `hub-packing.lua`, `hub-unpacking.lua`, `hub-gui.lua` |
| `hub-gui.lua` | `scripts/hubs/` | Custom relative GUI interface anchored to container windows (`defines.relative_gui_type.container_gui`), refactored to consume `gui-components.lua`. Fires `hub_manager.notify_settings_changed(entity)` on edits to wake disembarking capsules. | GUI event handlers (`on_gui_opened`, `on_gui_closed`, etc.) | `hub-settings.lua`, `hub-manager.lua`, `gui-components.lua` |
| `hub-manager.lua` | `scripts/hubs/` | Lifecycle listener, settings notification (`notify_settings_changed`), blueprint tag restoration (`pneumatic_settings`), and interleaved background tick scanner evaluating hub packing logic. | Interleaved background scanner, `notify_settings_changed()`, build/mine event listeners. | `hub-packing`, `hub-gui`, `events` |
| `hub-packing.lua` | `scripts/hubs/` | Main hub packing pipeline: Send check (`can_send`), lock release on empty inventory, pre-packing lock evaluation (`use_receive_lock`), runner occupancy check, player proximity scanner (2.5 tile radius), cargo planning (`cargo-planner.lua`), full `#inventory` scanning, dynamic dominant item selection, spoilability inspection, recording `dominant_cargo_quality`, Dual-Tier Spatial Grid allocation (`liminal_surface.allocate_position(is_wide)`), liminal holder spawning, cargo transfer via `item_transfer_handler`, and injection via `capsule_runner.inject_from_hub()`. | `hub_packing.evaluate_inventory(entity)` | `liminal-surface`, `capsule-manager`, `item-transfer-handler`, `cargo-planner`, `capsule-runner` |
| `hub-unpacking.lua` | `scripts/hubs/` | Main hub unpacking pipeline: Receive check (`can_receive`), $O(1)$ failure state guard (`last_failed_hub`), passenger disembarkation onto safe tiles, all-or-nothing cargo unpacking via `can_insert_all()` using zero-allocation flat scratch arrays, slot loops bounded to `get_bar() - 1`, stack migrations via `item_transfer_handler`, liminal holder cleanup with dual slot recycling (`release_position`), and mechanical receive latch engagement. | `hub_unpacking.capture(capsule_tracker, hub_entity)`<br>`can_insert_all(...)` | `capsule-manager`, `liminal-surface`, `item-transfer-handler`, `hub-settings` |
| `hub-spill.lua` | `scripts/hubs/` | Listens directly to entity mining and destruction events (`on_player_mined_entity`, `on_robot_mined_entity`, `on_entity_died`, `script_raised_destroy`, `on_space_platform_mined_entity`). Fast-looting container operability (`operable = true`, `set_bar(1)` red-locking upon creation), instant GUI dismissal (`on_gui_opened` sets `player.opened = nil`), `"no-copy-paste"` settings protection (`on_entity_settings_pasted`), 60Hz throttled container cleanup scan (`process_spilled_containers`), and metadata-safe spills via `item_transfer_handler`. | `hub_spill.spill_capsule(...)`<br>`hub_spill.handle_entity_destruction(entity)` | `capsule-queries`, `capsule-manager`, `item-transfer-handler` |
| `quality-filter.lua` | `scripts/hubs/packing/` | Evaluates item quality against capsule vessel rules (`ceil`, comparators, whitelists, blacklists). | `quality_filter.is_quality_allowed(...)` | `hub-packing.lua` |
| `cargo-planner.lua` | `scripts/hubs/packing/` | Calculates stack extraction and insertion plans, delegating `get_item_slot_cost()` to `capsule_defs.is_bio_item()` backed by a strict $O(1)$ bio item matrix (`capsule_definitions.bio_items`). | `cargo_planner.get_item_slot_cost(...)`<br>`cargo_planner.build_packing_plan(...)` | `capsule-definitions.lua`, `hub-packing.lua` |

---

### 2.5 Capsule System, Diverter & Pump Controls

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `diverter-settings.lua` | `scripts/` | Diverter state persistence table (`storage.diverter_settings`). Tracks cardinal port modes (`input`/`output`), whitelist/blacklist filter modes, 5 filter slots per port with explicit quality tracking (`item`, `comparator`, `quality`, `quality_comparator`, `explicit_quality`), `DEFAULT_CAPACITY = 2`, memoized filter compilation (`_compiled`), circuit proxy signal querying, `.copy()` deep-copy helper, and `apply_blueprint_settings()` tag deserialization API. | `diverter_settings.get()`, `diverter_settings.get_capacity()`, `diverter_settings.is_port_enabled()`, `diverter_settings.evaluate_circuit_condition()`, `diverter_settings.apply_blueprint_settings()` | `diverter-gui`, `active-device-scanner`, `capsule-runner` |
| `diverter-gui.lua` | `scripts/` | Interactive configuration GUI for Pneumatic Diverters, constructed via `gui-components.lua`. Features a 3x3 spatial arrow selector (North ▲, East ▶, South ▼, West ◀, All) defaulting to Port 1 (North) single-card view, 40x40 square overlay slot buttons with corner badges, right-click filter clearing, and `filter_slot_config_frame` modal pop-up combining item choosers with `add_quality_control_bar`. Delegates event updates to `gui_components` and `active_device_scanner.notify_settings_changed(entity)`. | `diverter_gui.open()`, `diverter_gui.close()`, GUI event handlers | `diverter-settings.lua`, `active-device-scanner.lua`, `gui-components.lua` |
| `pump-settings.lua` | `scripts/` | Pump state persistence table (`storage.pump_settings`). Tracks manual enable state (`enabled`), circuit enable toggles, comparator conditions, wire channel toggles, `.copy()` deep-copy helper, and `apply_blueprint_settings()` tag deserialization API. | `pump_settings.get()`, `pump_settings.is_pump_enabled()`, `pump_settings.evaluate_circuit_condition()`, `pump_settings.apply_blueprint_settings()` | `pump-gui.lua`, `active-device-scanner.lua` |
| `pump-gui.lua` | `scripts/` | Configuration GUI overlay (`pump_configuration_frame`) for Pneumatic Pumps, refactored to consume `gui-components.lua`. Fires `active_device_scanner.notify_settings_changed(entity)` on edits to sync ports and wake parked capsules. | `pump_gui.open()`, `pump_gui.close()`, GUI event handlers | `pump-settings.lua`, `active-device-scanner.lua`, `gui-components.lua` |
| `capsule-definitions.lua` | `scripts/capsules/` | Configuration specification for capsule items: base slot capacities, quality scaling, bio item matrix (`bio_items`), distinct RGBA debug overlay colors per capsule variant (`get_debug_color()`), spoilage modifiers, spill risks, self-dissolve rules, and spent item transitions (`spent_capsule_item`). | Registry `capsule_definitions.types`, `capsule_defs.bio_items`, `capsule_defs.get_debug_color()` | `hub-packing`, `capsule-manager`, `capsule-runner`, `capsule-renderer` |
| `capsule-inputs.lua` | `scripts/capsules/` | Event listener binding custom input `capsule-emergency-exit` (`SHIFT + E`) to `capsule_runner.emergency_eject(player)`. | Custom input listener. | `events.lua`, `capsule-runner.lua` |
| `capsule-manager.lua` | `scripts/capsules/` | CRUD tracking registry for active capsule holder entities (`storage.active_capsules`). Registers liminal holders with `script.register_on_object_destroyed` as `{ type = "capsule", id = capsule_id }`. Tracks primary capsule slot, allocated coordinates, `is_wide` classification, cached `dominant_item` string, `dominant_quality` string, and `has_spoilable_items` flag. Recycles positions back to `wide_free_slots` or `tight_free_slots` upon removal. | `register()`, `get()`, `remove()`, `get_primary_stack()` | `capsule-definitions`, `liminal-surface`, `storage`, `flow-engine` |
| `capsule-queries.lua` | `scripts/capsules/` | $O(1)$ Spatial Occupancy Index (`storage.occupancy` key `[unit_number][net_id][group]`), memoized port descriptors queried directly from `storage.flow_nodes`, target-based blocking occupancy model (`_occ_block_key`), occupancy tracking utilities (`update_capsule_occupancy`, `unregister_capsule_occupancy`), and `remove_capsule` expanded to clean occupancy, unpark waiting capsules from `storage.parked_by_port`, clear visual debug renders, and wake upstream queued traffic. | `get_port_info()`, `get_port_group()`, `get_port_descriptor()`, `update_capsule_occupancy()`, `unregister_capsule_occupancy()`, `remove_capsule()` | `storage`, `capsule-runner`, `flow-engine` |
| `capsule-lifecycle.lua` | `scripts/capsules/` | Lifecycle processor managing passenger position sync, per-force bio integrity research tier caching (`storage.bio_integrity_levels[force.index]`), 10-tick fragile spill evaluation with exact compounding, 60-tick refrigerated spoilage reduction ($0.10$) bounded to active inventory slots, stack rebuilds via `item_transfer_handler`, tool durability drain, and spent tool conversion (`spent-refrigerated-capsule`). | `capsule_lifecycle.update(capsule, id, curr_pos, surface)` | `capsule-manager`, `item-transfer-handler`, `hub-spill` |
| `capsule-renderer.lua` | `scripts/capsules/` | System-level viewport preparation (`prepare_frame()`) invoked once per tick across `game.players`, allocation-free scratch tables (`scratch_debug_players`, `scratch_debug_keys`), memoized numeric hover peeking (`get_port_info()`), distinct RGBA debug overlay colors per capsule variant, official C++ RenderLayers (`"entity-info-icon-above"`, `"light-effect"`), and dynamic spoilage expiration tracking. | `prepare_frame()`, `render()`, `get_dominant_item()` | `capsule-manager`, `capsule-queries`, `debug-manager` |
| `capsule-runner.lua` | `scripts/capsules/` | Granular Node Hop Motion Engine in v2 mode. Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop processing (`MAX_NODE_HOPS_PER_STEP = 3`). Features Strict Quality Rank Engine (`Normal` = 1 through `Legendary` = 5) supporting quality tier rank comparisons, wildcard quality matching (`"Any Quality"`), standalone quality filtering when item slots are unassigned, and comparator evaluation (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`). Propagates `payload_quality` through pathfinding and lookahead checks. Evaluates candidate hops via `select_next_target` enforcing positive pressure drops (`drop > 0`). Uses persistent zero-allocation scratch buffers and $O(1)$ spatial parked index (`storage.parked_by_port`) for targeted neighbor wakeups. | `inject_from_hub()`, `wake_parked_capsules()`, `get_capsule_location()`, `emergency_eject()`, `remove_capsule()`, `matches_filter_item()`, `on_tick` handler | `flow-engine`, `capsule-manager`, `capsule-lifecycle`, `capsule-renderer`, `capsule-queries`, `hub-unpacking`, `liminal-surface` |

---

### 2.6 Flow v2 Topology & Propagation Suite (`scripts/flow/`)

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `port-defs.lua` | `scripts/flow/` | Standalone flow port definition registry. Defines cardinal tile offsets, port groups (`group = 1` vs split crossflow groups), transmission permissions (`transmit = false` for hubs to block internal gas flow bridging), cross-transit permissions (`cross_transit = true` for hubs to allow capsule motion), and directional flow values (`flow = -10` for pump intake, `flow = 10` for pump output). Exposes `registered_names` and `get_ports(entity)`. | `port_defs.get_ports(entity)`<br>`port_defs.registered_names` | `flow-engine.lua`, `capsule-runner.lua`, `diverter-renderer.lua` |
| `flow-engine.lua` | `scripts/flow/` | Consolidated Event-Driven Wavefront Propagation Engine & Spatial Grid Topology Manager. Maintains $O(1)$ spatial coordinate lookup (`flow_grid`, `flow_nodes`, `flow_connections`) keyed by `surface@x,y`. Manages delta wavefront queue (`storage.flow_queue`, `BATCH_SIZE = 50`) propagating levels from active emitters (pumps/diverters, +10 down to +1, -10 up to -1) with 0-tick idle queue sleep. Evaluates active machine power (`energy > 0`) and circuit states. Renders color-coded Alt Mode overlays (`new_flow`). Listens to `defines.events.on_object_destroyed` via `storage.object_destruction_map` for silent sandbox purges. | `flow_engine.register_events()`<br>`flow_engine.init_storage()`<br>`flow_engine.connect_entity(entity)`<br>`flow_engine.disconnect_entity(entity)`<br>`flow_engine.step(tick)`<br>`flow_engine.enqueue_unit_ports(unit)`<br>`flow_engine.handle_object_destroyed(...)`<br>`flow_engine.handle_capsule_destroyed(...)` | `port-defs`, `debug-manager`, `control.lua`, `capsule-runner` |

---

## 3. Event Hook & Lifecycle Matrix

```
+-----------------------------------+------------------------------------+------------------------------------------+
| Factorio Engine Event             | Custom Dispatcher / Handler Module | Actions Triggered                        |
+-----------------------------------+------------------------------------+------------------------------------------+
| script.on_init                    | control.lua -> setup_storage()     | Initializes storage schema (liminal grid,|
| script.on_configuration_changed   | flow_engine.lua                    | occupancy index, bio integrity cache,    |
|                                   | proxy-manager.lua                  | v2 flow grid/queue, object destruction   |
|                                   | diverter-renderer.lua              | map); performs nil-clearing migrations;   |
|                                   |                                    | purges map orphan proxies via            |
|                                   |                                    | proxy_manager.purge_orphans(); refreshes |
|                                   |                                    | diverter Alt-Mode port filter overlays.  |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_built_entity    | proxy-manager.lua                  | Creates real and ghost circuit proxies,  |
| defines.events.on_robot_built_... | active-device-scanner.lua          | syncs direction, enforces Z-indexing     |
| defines.events.script_raised_...  | hub-manager.lua                    | (selection_priority=60), merges wires,   |
| defines.events.on_space_platform..| device-settings-copier.lua         | deduplicates proxies. Restores blueprint |
| defines.events.on_entity_cloned   | diverter-renderer.lua              | settings tags (pneumatic_settings), connects|
|                                   | flow-engine.lua                    | blueprint wires, enqueues flow unit      |
|                                   |                                    | ports, and updates Alt-Mode overlays.    |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_mined... | proxy-manager.lua                  | Destroys real/ghost circuit proxies,     |
| defines.events.on_robot_mined_... | active-device-scanner.lua          | handles bidirectional deconstruction;    |
| defines.events.on_entity_died     | flow-engine.lua                    | severs spatial links and enqueues drain  |
| defines.events.script_raised_...  | hub-spill.lua                      | waves; hub-spill independently handles    |
| defines.events.on_space_platform..| diverter-renderer.lua              | payload spillage and disembarkation;     |
|                                   |                                    | clears Alt-Mode overlays (clear_render). |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_rotated  | proxy-manager.lua                  | Syncs proxy orientation & selection      |
| defines.events.on_player_flipped  | flow-engine.lua                    | Z-indexing; re-indexes spatial nodes,    |
|                                   | active-device-scanner.lua          | updates port alignments, severs severed  |
|                                   |                                    | links, and enqueues ports for flow sync. |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_setup_...| device-settings-copier.lua         | Deep-copies settings into blueprint tags |
| (on_player_setup_blueprint)       |                                    | (pneumatic_settings), serializes wire    |
|                                   |                                    | connections via 4-element tuples and     |
|                                   |                                    | invariant blueprint indices (bp_index),   |
|                                   |                                    | injects proxy entities atomically.       |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_player_...      | device-settings-copier.lua         | Scans active blueprint handles & books   |
| (on_player_configured_blueprint)  |                                    | via clean_blueprint_orphans to purge     |
| defines.events.on_gui_closed      |                                    | orphan circuit proxy entity records when |
|                                   |                                    | main devices are removed in blueprint UI.|
+-----------------------------------+------------------------------------+------------------------------------------+
| Custom Input / Pasted Event       | device-settings-copier.lua         | Copies deep-copied machine settings      |
| (pneumatic-copy-settings,         |                                    | between matching device types, notifies  |
|  pneumatic-paste-settings,        |                                    | active_device_scanner / hub_manager, and |
|  on_entity_settings_pasted)       |                                    | refreshes open destination GUIs.         |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_object_destroyed| proxy-manager.lua                  | Auto-destroys unanchored orphan proxies/ |
|                                   | flow-engine.lua                    | ghosts; maps registration ID, silently   |
|                                   |                                    | purges destroyed structures or liminal   |
|                                   |                                    | holders, teleports passengers, wakes queue.|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_research_...    | capsule-lifecycle.lua              | Synchronizes cached bio-capsule integrity|
| defines.events.on_technology_...  |                                    | research tiers across forces.            |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_gui_opened      | pump-gui.lua / diverter-gui.lua    | Diverter & Pump proxies: Defers GUI.     |
| defines.events.on_gui_closed      | hub-gui.lua / hub-spill.lua        | Spilled containers: Dismisses GUI to     |
| defines.events.on_gui_checked_... | gui-components.lua                 | permit fast Ctrl+Click looting.          |
| defines.events.on_gui_switch_...  | debug-manager.lua                  | Declarative UI component handlers mutate |
| defines.events.on_gui_elem_...    |                                    | settings and trigger notify_settings_... |
| defines.events.on_gui_click       |                                    | to wake parked capsules & sync flow ports.|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_lua_shortcut    | debug-manager.lua                  | Master hotbar shortcut (pt-debug-panel): |
|                                   |                                    | Toggles Pneumatic Control Panel GUI.     |
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_custom_input    | capsule-inputs.lua ->              | Triggers capsule_runner.emergency_eject  |
| (capsule-emergency-exit / Shift+E)| capsule-runner.lua                 | for passenger disembarkation, holder     |
|                                   |                                    | destruction, and tracking unregistration.|
+-----------------------------------+------------------------------------+------------------------------------------+
| defines.events.on_tick            | active-device-scanner.lua          | Unified 15t power/circuit scanner loop   |
|                                   | hub-manager.lua                    | Interleaved hub scanner & lock reset     |
|                                   | hub-spill.lua                      | 60t spilled empty container cleanup      |
|                                   | flow-engine.lua                    | Event-driven delta wavefront step        |
|                                   | capsule-runner.lua                 | Granular 6t staggered node hops,         |
|                                   |                                    | targeted neighbor wakeups, 60t liminal   |
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
      group = 1,               -- Port group ID for internal flow isolation
      transmit = true,         -- Permission for internal flow level propagation
      cross_transit = true,    -- Permission for capsule motion across entity
      emitter = 10,            -- Active flow emission level (+10 output, -10 intake, 0 neutral)
      pos = { x = 10.5, y = 20.5 },
      surface = "nauvis",
      entity = LuaEntity
    }
  },
  flow_connections = {
    ["101:1"] = {
      ["102:2"] = true -- Set of active external spatial port connections
    }
  },
  flow_queue = {
    ["101:1"] = true -- FIFO/Set queue of port keys requiring wavefront level evaluation
  },
  flow_levels = {
    ["101:1"] = 10 -- Dynamic calculated flow level integer (-10 .. +10)
  },
  flow_unit_ports = {
    [101] = { "101:1", "101:2" } -- Recorded port keys associated with entity unit number
  },

  -- O(1) Spatial Parked Capsule Index
  parked_by_port = {
    ["101:1"] = {
      [capsule_id] = true -- Set of capsule IDs parked waiting at port key
    }
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

  -- Deferred Blueprint Wire Reconstruction Cache
  bp_wire_cache = { ... },
  pending_bp_wires = { ... },

  -- Cached Research Tech Tiers Per Force
  bio_integrity_levels = {
    [force_index] = 2
  },

  -- Hub Container Registry, Operational Settings & Mechanical Latches
  active_hubs = { [unit_number] = LuaEntity },
  hub_settings = {
    [unit_number] = {
      can_send = true, use_circuit_send = false,
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

  -- Capsule System & Motion Engine
  active_capsules = {
    [capsule_id] = {
      holder = LuaEntity, type = "capsule", primary_slot = 1, position = { x = 0, y = -100 },
      grid_index = 5, is_wide = false, dominant_item = "iron-plate", dominant_quality = "normal",
      has_spoilable_items = false, definition = { ... }
    }
  },
  capsules = {
    [capsule_runner_id] = {
      id = 1, capsule_id = capsule_id, source_hub = 101, from_port_key = "101:1", to_port_key = "102:2",
      _occ_block_key = "102:2", progress = 0.45, passenger = LuaPlayer, slot_spoil_percents = { [1] = 0.12 },
      last_failed_hub = 102, last_failed_hub_count = 15, last_failed_hub_bar = 10, last_failed_cap_count = 1
    }
  },

  -- Per-Player Debug System State
  debug = {
    [player_index] = {
      master = true, capsules = true, peek = false, flow = true, prints = false,
      new_flow = true,      -- Flow v2 rendering overlay toggle
      filter = "string"     -- Console debug print prefix filter string
    }
  }
}
```

---

## 5. Core Algorithms & Operational Mechanics

### 5.1 Flow v2 Event-Driven Delta Wavefront Engine & Spatial Grid Topology (`scripts/flow/flow-engine.lua`)
1. **$O(1)$ Spatial Grid Topology:** Entities register port nodes onto `storage.flow_nodes` and key tile positions into `storage.flow_grid` via formatted coordinate keys (`surface@x,y`). Adjacent matching ports form bidirectional edges in `storage.flow_connections`. Entity build, mine, rotate, and flip events automatically connect or disconnect matching overlapping ports across adjacent structures without global graph scans.
2. **Event-Driven Delta Wavefront Propagation:** Replaces global graph sweeps with a 1-hop-per-tick delta wavefront step handler (`flow_engine.step`) backed by `storage.flow_queue`. Active emitters (`pneumatic-pump` and `pneumatic-diverter`) start at maximum output strength (+10) or intake pull (-10). Flow propagates outward decaying by 1 level per hop down to 0 at 60 tiles/second.
3. **0-Tick Queue Sleep:** When no flow levels change or the network reaches steady-state equilibrium, `storage.flow_queue` empties. On subsequent ticks, `flow_engine.step()` returns on line 1 in 0.00 ms CPU time with zero Lua GC allocations.
4. **Time-Sliced Batching:** Queue processing is capped at `BATCH_SIZE = 50` steps per tick, spreading processing across frames during large entity placement or destruction events.
5. **Drain Wavefront & Severing:** Disconnecting an entity or breaking a tube connection enqueues downstream ports into `storage.flow_queue`, triggering a frame-by-frame drain wave (`compute_port_flow_level`) that clears cut-off flow values to zero before returning the engine to sleep.
6. **Dynamic Power & Circuit State Sensitivity:** Evaluates machine energy (`entity.energy > 0`), circuit enable conditions, and port modes in constant time. Unpowered or circuit-disabled ports drop emission to 0, triggering automatic downstream flow updates and queue wakeups via `enqueue_unit_ports`.
7. **Granular Fast-Path Rendering Pipeline:** Bypasses full map redraws with targeted single-port (`update_port_render`) and single-edge (`update_edge_render`) rendering object mutations. Renders color-coded flow vectors (Cyan/Blue for positive pressure, Orange/Red for intake vacuum) directly on Factorio's script overlay pass with `only_in_alt_mode = true`.

### 5.2 $O(1)$ Spatial Occupancy Index & Target-Based Blocking Model (`capsule-queries.lua`)
1. **Constant-Time Spatial Lookup Matrix:** `storage.occupancy` maintains multi-level spatial buckets indexed by `[unit_number][net_id][group]`. `get_capsule_count_at_entity_network`, `get_capsule_count_at_entity`, and `find_capsules_at_entity` execute in $O(1)$ constant time without linear scans over active capsules.
2. **Topology Direct Querying:** `get_port_group()` and `get_port_descriptor()` query v2 spatial topology in `storage.flow_nodes` directly without legacy network wrapper layers.
3. **Target-Based Blocking Occupancy:** Moving capsules track a target blocking key (`_occ_block_key = to_port_key`). The instant a capsule commits to a destination target segment (`to_port_key`), it blocks capacity at its destination node while immediately freeing its origin node capacity (`from_port_key`) for upstream capsules while in mid-transit.
4. **Unparking & Cleanup Dispatch:** `remove_capsule` cleans occupancy buckets, unparks waiting capsules from `storage.parked_by_port`, clears visual debug renders, and wakes upstream queued traffic waiting at the freed port key.

### 5.3 Granular Node Hop Motion Engine & Pathfinding (`scripts/capsules/capsule-runner.lua`)
1. **Granular Node Hop Motion:** Executes discrete node-to-node hop movement every 6 ticks (staggered per capsule ID) with multi-hop capability (`MAX_NODE_HOPS_PER_STEP = 3`) for instantaneous internal machine transitions.
2. **Strict Pressure Gradient Target Selection:** `select_next_target` evaluates candidate outbound hops, requiring a strictly positive flow drop (`level_from - level_cand > 0`) or intake vacuum pull. Eliminates capsule oscillation in zero-gradient zones, dead ends, or unpowered networks by parking capsules cleanly (`return nil`).
3. **Metadata Emitter Traversal:** Uses node metadata (`node.emitter`) rather than entity name matching to handle pump push (`emitter < 0` to `emitter > 0` with `drop = math.huge`) and evaluate downstream diverter output lookahead.
4. **Data-Driven Decoupled Hub Cross-Transit:** Evaluates `node.cross_transit` on hub port definitions (`cross_transit = true`), allowing capsules to cross through hub structures along outbound pressure gradients while keeping internal gas flow transmission isolated (`transmit = false`).
5. **Zero-Allocation Persistent Scratch Buffers:** Module-level persistent scratch tables (`scratch_cand_keys`, `scratch_cand_vias`, `scratch_best_keys`, `scratch_ports_to_wake`, etc.) eliminate table allocations (`{}`) during path evaluation, candidate scoring, and neighbor wakeups.

### 5.4 0-Tick Lockstep Queue Advancement & Targeted Wakeup Engine (`scripts/capsules/capsule-runner.lua`)
1. **0-Tick Lockstep Queue Advancement:** The exact tick a parked capsule transitions to moving (`to_port_key ~= nil`) or completes a segment arrival (`to_port_key = nil`), `update_capsules()` invokes `wake_parked_capsules(prev_from)`, triggering instant queue advancement for upstream queued capsules on the same tick.
2. **Targeted Network-Scoped Wakeup Engine:** `wake_parked_capsules(target)` accepts an optional target parameter (`port_key`, `unit_number`, or `net_id`). Using `storage.parked_by_port`, sister unit ports (`storage.flow_unit_ports`), and connected edges (`storage.flow_connections`), it wakes strictly the parked capsules affected by a freed route or entity state change.
3. **Stale Motion State Reset:** Stale origin port memory (`capsule.last_port_key`) is cleared whenever a capsule enters a parked state or receives a target wakeup, allowing newly reversed flow drops (`drop > 0`) to be selected cleanly.

### 5.5 Multi-Item Unpacking Failure Guard & Zero-Allocation Space Simulation (`hub-unpacking.lua`)
1. **$O(1)$ Destination Failure State Guard:** Capsules parked at or polling full/blocked hub destinations track failure state parameters (`last_failed_hub`, `last_failed_hub_count`, `last_failed_hub_bar`, `last_failed_cap_count`) inside `hub_unpacking.capture`. If hub item counts have not decreased, container bars have not expanded, and payload counts have not dropped, full container space simulation (`can_insert_all`) is short-circuited in constant time.
2. **Zero-Allocation Space Simulation:** `can_insert_all()` utilizes flat module-level scratch arrays (`scratch_req_names`, `scratch_req_counts`, `scratch_partial`, `scratch_filtered`) to simulate multi-item inventory insertion across active chest slots (`get_bar() - 1`), eliminating garbage collection overhead.
3. **Targeted Failure Cache Invalidation:** When a route opens or network state changes, `wake_parked_capsules()` clears `capsule.last_failed_hub = nil`, triggering immediate unpacking re-evaluation.

### 5.6 Native Quality-Aware Diverter Filtering & Lookahead Validation (`scripts/capsules/capsule-runner.lua` / `diverter-settings.lua`)
1. **Strict Factorio 2.0 Quality Rank Engine:** Maps quality tiers cleanly from `Normal` (rank 1) through `Legendary` (rank 5). Supports explicit quality rank comparisons, wildcard quality matching (`"Any Quality"`), standalone quality filtering when item slots are unassigned, and comparator math (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`) in `matches_filter_item`.
2. **Recursive Downstream Lookahead Path Validation:** `is_hop_valid()` inspects downstream external hops when evaluating internal machine transfers (e.g., diverter input-to-output ports), ensuring exit ports leading to full or filter-disqualified tube lines are rejected before a capsule enters the internal port.
3. **$O(1)$ Non-Diverter Filter Short-Circuiting:** `check_diverter_port_filter()` uses `get_port_info()` to extract integer unit numbers and port indices, short-circuiting non-diverter entities in 2 table lookups.
4. **Memoized Filter Compilation:** Filter slots and blacklist modes are compiled onto `port_setting._compiled`, bypassing unconfigured slots and enabling early-exit evaluation on whitelist matches.
5. **Targeted Diverter Capacity Expansion:** Multi-port diverters support `DEFAULT_CAPACITY = 2` (`diverter_settings.get_capacity(unit_number)`), allowing up to 2 capsules to queue/transit through diverter internal ports simultaneously while maintaining single-capsule spacing across standard tubes and pumps.

### 5.7 Centralized Metadata Engine & Equipment Grid Transfer (`item-transfer-handler.lua`)
1. **Centralized Metadata Preservation:** Hub packing, unpacking, spilling, and refrigerated decay workflows delegate stack extractions and migrations to `item_transfer_handler`.
2. **Native C++ `transfer_stack()` Integration:** Item stack migrations attempt native `dest_slot.transfer_stack(src_stack)` calls first, preserving 100% of equipment grids (`stack.grid`), installed modules, shield/energy levels, spoilage, health, durability, ammo, and quality.
3. **$O(1)$ Equipment Grid Copying & Restoration:** Fallback stack extractions execute `copy_equipment_grid()` to clone equipment grids (`create_grid()`) and transfer installed equipment (`name`, `position`, `quality`, `energy`, `shield`).
4. **`item-with-tags` API Guard:** `build_stack_spec()` extracts stack attributes while strictly guarding `tags` and `custom_description` access behind `is_item_with_tags` checks to prevent Factorio `__index` crashes on standard items.

### 5.8 Dynamic Spoilage Expiration & Zero-Overhead Render Polling (`capsule-renderer.lua` / `hub-packing.lua`)
1. **Spoilability Detection at Packing:** During hub packing (`hub-packing.lua`), `is_stack_spoilable()` computes a `has_spoilable_items` flag persisted in `storage.active_capsules`.
2. **Dynamic Spoilage Expiration Guard:** In `capsule-renderer.lua`, `get_dominant_item()` inspects active container slots using `is_stack_spoilable()`. If cargo spoils mid-flight, it updates `cap_data.dominant_item` to the spoiled product and flips `has_spoilable_items` to `false` once zero spoilable stacks remain.
3. **0-Tick Scan Suppression:** Once `has_spoilable_items` transitions to `false`, 60-tick periodic inventory re-scans are permanently suppressed, serving cached dominant item icons directly from memory in $O(1)$ time.
4. **Valid Render Layer Hierarchy & Distinct Color Overlay:** Debug rings and payload icons render on official C++ RenderLayers (`"entity-info-icon-above"` for rings/icons, `"light-effect"` for HUD text). Each capsule variant displays a distinct RGBA debug border ring (`capsule_defs.get_debug_color()`), updating dynamically if a refrigerated capsule expires into a spent capsule mid-flight.

### 5.9 Fast-Looting Spilled Containers & 0-Tick Bar Enforcement (`hub-spill.lua`)
1. **Fast-Looting Operability:** Spilled container entities (`visible-capsule-holder`) use `operable = true` to allow native Ctrl+Click fast-looting transfers.
2. **Instant GUI Dismissal:** An `on_gui_opened` listener sets `player.opened = nil` on the exact tick a spilled container is clicked, hiding the container GUI window and red bar slider.
3. **0-Tick Red-Locking Clamping:** Container creation applies `set_bar(1)`, red-locking all slots against manual item insertion while permitting item extraction. `"no-copy-paste"` flags and `on_entity_settings_pasted` listeners prevent setting overrides.
4. **Throttled Cleanup Scan:** A 60-tick periodic scanner (`process_spilled_containers`) evaluates empty spilled containers (`container_inv.is_empty()`), destroying empty entities in batch.

### 5.10 Silent Object Destruction & Sandbox Purge Engine (`defines.events.on_object_destroyed`)
1. **Typed Object Destruction Registry:** Valid pneumatic structures and liminal capsule holder entities register with Factorio's `script.register_on_object_destroyed` during build, spawning, and surface setup scans. Registration handles map into `storage.object_destruction_map` as structured entries: `{ type = "entity", unit_number = N }` or `{ type = "capsule", id = C }`.
2. **Silent Sandbox Purge Fallback:** When entities are wiped in bulk via Sandbox mode ("remove all entities"), chunk deletions, or script destructions (bypassing standard player/robot mining events), `defines.events.on_object_destroyed` dispatches to structured handler routines (`handle_object_destroyed` and `handle_capsule_destroyed`).
3. **Silent Cargo & Surface Cleanup:** Destroyed capsule holders on `liminal_surface` are removed cleanly via `capsule_manager.remove` without spilling item stacks onto the ground. Any riding player passengers (`cap.passenger`) are safely teleported back to a valid ground position.
4. **Network Topology & Flow Queue Unlinking:** Entity destructions trigger spatial disconnection (`disconnect_entity`), clearing port nodes, severing spatial connection edges, purging recorded unit ports, unparking waiting capsules, and enqueuing upstream neighbor ports to wake queued traffic and prevent tube lockups.

### 5.11 Centralized Proxy Lifecycle, Selection Z-Indexing & Additive Wire Merging Engine (`scripts/proxy-manager.lua`)
1. **Centralized Registry Architecture:** Centralizes circuit proxy lifecycle management across pumps and diverters into `proxy_manager.register_pair`. Centrally listens to build, destroy, rotate, flip, cloning, space platform, and GUI opening events.
2. **Spatial Selection Priority Stack Z-Indexing:** Configures proxy prototypes with `selection_priority = 60` (higher than main machines at `50`), `placeable_by` main item (`count = 0`), `"player-creation"` flag, and `proxy.operable = true`. Invokes `proxy.teleport(pos)` on build/rotate events to re-insert proxies at the top of Factorio's spatial selection stack, allowing Red/Green wire tools and Wire Cutters to target circuit terminals reliably.
3. **Additive Proxy Wire Merging:** Prior to source entity destruction during blueprint stamping or machine placement over existing proxies, `transfer_wire_connections` iterates over source `LuaWireConnector` ports and copies wire connections onto surviving real proxies via `connect_to()`, preserving pre-existing circuit networks without wire severing.
4. **Orphan Auto-Destruction & Multi-Proxy Deduplication:** Unanchored real proxies or ghost proxies lacking a valid host machine or host ghost at their coordinates are destroyed immediately. Multi-proxy placement events transfer wires from extra duplicates onto the primary proxy before pruning duplicates.
5. **Surface-Wide Orphan Purge Engine:** `proxy_manager.purge_orphans()` scans all map surfaces for unanchored real or ghost circuit proxies, purging legacy map orphans during `on_init` and `on_configuration_changed`.

### 5.12 Unified Active Device Background Scanner (`scripts/active-device-scanner.lua`)
1. **Consolidated 15-Tick Background Loop:** Unifies background 15-tick power and circuit scanning for active machines (`pneumatic-pump` and `pneumatic-diverter`) into `active_device_scanner.register_events()`, eliminating duplicate loops across individual machine managers.
2. **Extensible Device Type Registration:** Supports device specification registration (`register_device_type`) handling lifecycle hooks (build, destroy, rotate, flip, space platform, cloned) and evaluating power/circuit enable states in constant time.
3. **Centralized Notification API:** Exposes `notify_settings_changed(entity)`. Re-evaluates machine enable states, clears compiled filter caches, enqueues unit ports into `flow_engine`, wakes parked capsules, and triggers Alt-Mode overlay updates (`diverter_renderer`).

### 5.13 Blueprint Tag Serialization, 4-Tuple Wire Reconstruction & Blueprint Orphan Purging Engine (`scripts/device-settings-copier.lua`)
1. **Deep-Copy Settings Serialization:** Subscribes to `on_player_setup_blueprint`. Deep-copies device settings into blueprint entity tags (`pneumatic_settings`), stripping transient runtime caches (`_compiled`).
2. **Atomic Blueprint Wire Serialization (4-Tuple Schema):** Iterates over proxy circuit connectors using `LuaEntity.get_wire_connectors(false)` and serializes wire connections into 4-element connection tuples (`{ src_conn_id, src_conn_id, target_bp_index, tgt_conn_id }`) with Factorio 2.0 invariant blueprint indices (`bp_index`), achieving 100% rotation and flip immunity.
3. **Deferred Ghost & Entity Wire Reconstruction:** Listens to build and revive events (`process_entity_built_wire_tags`). Resolves wire targets between ghosts or built entities via `storage.bp_wire_cache` and `storage.pending_bp_wires`, connecting wire connectors immediately upon placement via `LuaWireConnector.connect_to()`.
4. **Blueprint & Book Orphan Proxy Purging:** Subscribes to `on_player_configured_blueprint` and `on_gui_closed`. Inspects active blueprint handles, records, and books (`clean_blueprint_orphans` / `clean_container_or_blueprint`), purges orphan circuit proxy records left behind when main devices are deleted in the blueprint manager window, and re-indexes blueprint entity numbers.

### 5.14 Declarative UI Widget Component Library & Quality Control Bar Engine (`scripts/utils/gui-components.lua`)
1. **Declarative UI Widget Library:** Standardizes window construction (`create_relative_window`), headers (`add_header`), card frames (`add_card_frame`), wire channel toggles (`add_wire_channel_toggles`), circuit condition panels (`add_circuit_condition_panel` with expanded 55px dropdowns), 40x40 overlay slot buttons (`create_overlay_slot_button`, `update_overlay_slot_button`), and 3x3 spatial arrow selectors (`add_spatial_arrow_selector`).
2. **Quality Control Bar Engine:** Renders quality comparator dropdowns (68px width), 5-tier quality sprite radio buttons, checkmark confirm buttons, and selection highlight styles (`flib_selected_slot_button`). Encapsulates native Factorio quality selector interaction rules (`add_quality_control_bar`, `handle_quality_tier_click`, `handle_quality_comparator_change`).
3. **Native Quality Defaults & Explicit Quality Preservation:** Selecting an item on an unconfigured slot defaults to `=` comparator and `normal` quality (`handle_filter_item_change`). Deliberate quality choices are explicitly preserved across item swaps (`explicit_quality`). Selecting "Any Quality" resets specific quality tier memory back to `normal`.
4. **Overlay Formatting & Contrast:** Omits the `=` comparator symbol on item slot overlays to mirror native Factorio UI conventions. Renders non-equal operators (`>`, `<`, `≥`, `≤`, `≠`) in high-contrast white text (`COLOR_WHITE`, `format_white_label`) and provides right-click slot clearing (`clear_filter_slot`).

### 5.15 Alt-Mode Diverter Port Filter Overlay Renderer (`scripts/diverter-renderer.lua`)
1. **Native-Style Alt-Mode Overlay Renderer:** Renders configured port filter item icons directly over physical diverter ports in Alt-Mode using Factorio 2.0 `rendering.draw_sprite` APIs (`only_in_alt_mode = true`, `render_layer = "entity-info-icon"`).
2. **Topological Port Offset Anchoring:** Queries topological port coordinates directly from `port_defs.get_ports(entity)` to display up to 4 filter item icons per port in adaptive 2x2 grids (`scale = 0.42`, `offset = 0.22`).
3. **Lifecycle Synchronization:** Integrated into `active_device_scanner.notify_settings_changed(entity)` and build/clone handlers (`update_render`). Clears rendering objects via `clear_render` upon entity mining or destruction. Automatically restored across world loading (`on_init`, `on_configuration_changed`) via `setup_storage()` surface scans.

---

## 6. In-Game Console Debug Commands

| Command | Description | Module Source |
| :--- | :--- | :--- |
| `/pneumatic-panel` | Opens or toggles the master Pneumatic Control Panel Lua GUI frame (`debug_manager.toggle_panel()`). Alias: `/debug-panel`. | `scripts/debug-manager.lua` |
| `/debug-filter <text>` | Sets the debug chat message prefix filter string in player storage (`storage.debug[player_index].filter`), suppressing console prints that do not match the specified prefix string. | `scripts/debug-manager.lua` |
| `/debug-filter-reset` | Clears the debug chat message prefix filter string, allowing all active debug prints to display in console. | `scripts/debug-manager.lua` |
| `/toggle-debug` | Toggles master debug mode on/off for the executing player (`storage.debug[player_index].master`). | `scripts/debug-manager.lua` |
| `/toggle-prints` | Toggles console debug print logging output for the executing player (`storage.debug[player_index].prints`). | `scripts/debug-manager.lua` |
| `/toggle-flow` | Toggles v2 visual flow vectors, pressure numbers, and spatial connection overlays in Alt Mode for the executing player (`storage.debug[player_index].new_flow`). Alias: `/pt-toggle-flow`. | `scripts/debug-manager.lua` |
| `/toggle-capsules` | Toggles visual rendering overlay for active capsule positions and dominant payload item icons (`storage.debug[player_index].capsules`). Mutually exclusive with `/toggle-capsule-peek`. | `scripts/debug-manager.lua` |
| `/toggle-capsule-peek` | Toggles entity-hover capsule peeking overlay in Alt Mode (`storage.debug[player_index].peek`), rendering item icons strictly for capsules occupying targeted pneumatic structures. Alias: `/capsule-peek`. Mutually exclusive with `/toggle-capsules`. | `scripts/debug-manager.lua` |

---

## 7. Render Layers, Selection Priorities & Visual Overlay Specification

### 7.1 Runtime Script Render Layers (`rendering.draw_*`)

> **Engine Note on Primitive vs. Sprite Rendering:**  
> In Factorio's Lua API, explicit `render_layer` parameters are accepted by sprite/animation methods (`rendering.draw_sprite`, `rendering.draw_animation`, `rendering.draw_light`). Primitive vector shapes (`rendering.draw_circle`, `rendering.draw_line`, `rendering.draw_text`) are dispatched directly to Factorio's dedicated script rendering overlay pass (controlled vertically via `draw_on_ground = true/false`).

| Render Layer Name / Target Pass | Module Source | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `"light-effect"` | `capsule-renderer.lua` | Text | `rendering.draw_text` | No | Renders `" [Shift + E] Emergency Eject "` HUD text centered above riding passenger capsules (`scale = 0.9`, offset `y + 0.8`). |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders cyan passenger ring (`radius = 0.45`, `width = 3`) around player-occupied capsules. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders capsule variant debug border ring (`radius = 0.35`, `width = 2`) using capsule RGBA debug colors. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Sprite | `rendering.draw_sprite` | No (Debug) | Renders dominant payload item icon (`"item/" .. item_name`, `scale = 0.55`) inside capsule debug ring. |
| `"entity-info-icon-above"` | `capsule-renderer.lua` | Circle | `rendering.draw_circle` | No (Debug) | Renders filled color dot (`radius = 0.25`) for empty or unknown cargo capsules. |
| `"entity-info-icon"` | `diverter-renderer.lua` | Sprite | `rendering.draw_sprite` | **Yes** | Renders up to 4 configured filter item icons per port in adaptive 2x2 grids (`scale = 0.42..0.52`). |
| *Default Script Layer* | `flow-engine.lua` | Circle | `rendering.draw_circle` | **Yes** | Renders pressure marker circle (`radius = 0.15`, cyan/blue for positive pressure, orange/red for intake vacuum). |
| *Default Script Layer* | `flow-engine.lua` | Text | `rendering.draw_text` | **Yes** | Renders pressure integer level text (`-10` to `+10`, white text, `scale = 0.7`) above flow node circles. |
| *Default Script Layer* | `flow-engine.lua` | Line | `rendering.draw_line` | **Yes** | Renders flow vector connection lines (`width = 3`, cyan/orange) between adjacent connected tube ports. |

---

### 7.2 Spatial Selection Priority & Z-Index Stack

| Selection Priority | Entity Name / Spec | Source File | Z-Index & Interaction Behavior |
| :---: | :--- | :--- | :--- |
| **60** | `pneumatic-pump-circuit-proxy`<br>`pneumatic-diverter-circuit-proxy` | `proxy-manager.lua` | Top selection stack priority. Re-inserted via `proxy.teleport(pos)` on build/rotate events to guarantee Red/Green wire tool and Wire Cutter targeting above base entities. |
| **50** | `pneumatic-pump`<br>`pneumatic-diverter`<br>`capsule-hub-horizontal`<br>`capsule-hub-vertical`<br>`pneumatic-tube`<br>`junction`<br>`crossflow-junction` | `entity.lua`<br>`pneumatic-diverter.lua` | Standard physical machine and structure selection priority. |
| **0** | `pneumatic-pump-circuit-proxy` (Raw proto)<br>`pneumatic-diverter-circuit-proxy` (Raw proto) | `pneumatic-pump-proxy.lua`<br>`pneumatic-diverter.lua` | Fallback prototype priority with `draw_selection_box = false` so invisible proxy boxes do not render. |

---

### 7.3 Prototype Sprite Priorities & Layer Composite Specs

| Entity Prototype | Property Path | Priority Value | Scale & Tint Details |
| :--- | :--- | :---: | :--- |
| `pneumatic-tube` | `picture.north/east/south/west.layers[].priority` | `"extra-high"` | Scale `0.5`, green tint (`{r=0.5, g=0.9, b=0.5}`). |
| `pneumatic-pump` | `pictures.north/east/south/west.priority` | `"high"` | Scale `0.5`, orange tint (`{r=1.0, g=0.7, b=0.3}`). |
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
| `item-capsule` | Metallic Gold | `{ r = 1.0, g = 0.84, b = 0.0, a = 0.9 }` | Cargo capsule border ring/dot overlay. |
| `biodegradable-capsule` | Emerald Green | `{ r = 0.2, g = 0.90, b = 0.2, a = 0.9 }` | Biodegradable capsule border ring/dot overlay. |
| `refrigerated-capsule` | Frost Cyan | `{ r = 0.2, g = 0.85, b = 1.0, a = 0.9 }` | Cold capsule border ring/dot overlay. |
| `spent-refrigerated-capsule` | Slate Grey | `{ r = 0.6, g = 0.65, b = 0.7, a = 0.9 }` | Spent refrigerated capsule border ring/dot overlay. |
| `reinforced-capsule` | Violet Purple | `{ r = 0.8, g = 0.30, b = 1.0, a = 0.9 }` | Reinforced capsule border ring/dot overlay. |
| `player-transit-capsule` | Crimson Orange | `{ r = 1.0, g = 0.40, b = 0.1, a = 0.9 }` | Passenger transit capsule border ring/dot overlay. |