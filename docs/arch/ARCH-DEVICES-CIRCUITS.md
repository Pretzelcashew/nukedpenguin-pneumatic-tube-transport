# ARCH-DEVICES-CIRCUITS.md - Devices, Triple-Proxy & Circuit Interfacing
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Unified Active Scanner, Triple-Proxy Architecture, Copy-Paste & Blueprints, Declarative GUI Components, Device Controllers (Diverter, Pump, Counter, Projector)

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. | `events.on_event(event_id, handler)` | System-wide event listeners |
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`) and Pneumatic Control Panel Lua GUI controller (`open_panel`, `close_panel`, `toggle_panel`, `refresh_panel`). Manages console log prefix filtering, v2 Alt-Mode flow overlay toggles, sensing range wavefront overlay toggles, kinetic beam overlay reconstruction, shortcut syncing, and console commands (`/pneumatic-panel`, `/toggle-debug`, `/toggle-prints`, `/toggle-flow`, `/toggle-counter-range`, `/toggle-capsules`, `/toggle-capsule-peek`, `/clear-renders`, `/pt-clear-renders`). Decouples flow and kinetic beam overlay drawing/clearing from counter overlays. | `debug_print(...)`, `is_debug_active(...)`, `open_panel()`, `close_panel()`, `toggle_panel()`, `sync_shortcuts()` | System-wide |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `gui-components.lua` | `scripts/utils/` | Centralized declarative UI widget builder library & quality control bar engine. Centralizes Factorio 2.0 native filter display rules (`get_filter_display_spec`, `get_active_filters`) across GUI slot buttons and world overlays. Renders relative window frames, draggable headers (`drag_target = parent_frame`), titles, wire channel toggles, circuit condition panels (55px dropdown width), 40x40 overlay slot buttons, quality control bar widgets, and 3x3 spatial arrow selectors. | `create_relative_window()`, `add_header()`, `add_card_frame()`, `add_wire_channel_toggles()`, `add_circuit_condition_panel()`, `create_overlay_slot_button()`, `update_overlay_slot_button()`, `add_quality_control_bar()`, `add_spatial_arrow_selector()`, `clear_filter_slot()`, `handle_filter_item_change()`, `get_filter_display_spec()` | Device GUIs (`pump-gui`, `diverter-gui`, `hub-gui`, `counter-gui`) |
| `proxy-manager.lua` | `scripts/` | Centralized Proxy Linkage, Multi-Proxy Lifecycle & Object Destruction Engine (`storage.object_destruction_map`). Supports main terminal proxies and sub-proxy schemas (`pneumatic-capsule-counter-red-proxy`, `pneumatic-capsule-counter-green-proxy`, `pneumatic-projector-circuit-proxy`). Spawns, teleports, and connects internal Red/Green wire bridges between channel proxies and terminal proxy on build/rotate events, and purges proxies upon entity removal (`destroy_all_proxies_at`). Registers main entities with `script.register_on_object_destroyed` to catch C++ engine-level removals (super force building, fast replacement, ghost cancellation). Manages spatial selection precedence (`selection_priority = 60`, `proxy.operable = true`, `proxy.teleport`), additive wire merging (`transfer_wire_connections`), orphan proxy/ghost auto-destruction, and surface-wide orphan purging (`purge_orphans`). Exposes `get_registered_proxies()` and `get_registered_mains()`. | `proxy_manager.register_pair()`, `proxy_manager.register_events()`, `proxy_manager.purge_orphans()`, `proxy_manager.get_registered_proxies()`, `proxy_manager.get_registered_mains()`, `proxy_manager.destroy_all_proxies_at()` | `control.lua`, `device-settings-copier`, `active-device-scanner` |
| `device-settings-copier.lua` | `scripts/` | Centralized Device Settings Copier, Blueprint Serialization, Ghost Wire Linking & Blueprint Sanitization Engine. Supports `pneumatic-capsule-counter`, `pneumatic-diverter`, `pneumatic-pump`, and `pneumatic-projector` target resolution and proxy mapping. Adjusts relative projector launch muzzle directions during live Shift+Left-Click copy-paste and blueprint stamping. Stores live entity source handles in `storage.player_copy_buffer` with source validity guards. Handles `on_player_setup_blueprint` (4-tuple wire schema `[entity_from, wire_type_from, entity_to, wire_type_to]`, metadata tag serialization via `pneumatic_settings`), `clean_blueprint_orphans`, and executes instant zero-state spatial wire target resolution on the build tick (`process_entity_built_wire_tags`). | `device_settings_copier.register_events()`, `clean_blueprint_orphans()`, `process_entity_built_wire_tags()` | `control.lua`, `proxy-manager`, `active-device-scanner`, `counter-gui`, `pump-gui` |
| `active-device-scanner.lua` | `scripts/` | Unified 15-tick background scanner monitoring active physical and ghost machine entities (`pneumatic-pump`, `pneumatic-diverter`, `pneumatic-capsule-counter`, and `pneumatic-projector`). For projectors: evaluates 3 MW idle baseline power (`MINIMUM_ENERGY_JOULES = 3000000`), circuit conditions, muzzle orientation changes, and capacitor recharge transitions (`storage.projector_ready_states`), triggering `flow_engine.enqueue_unit_ports` and `capsule_runner.wake_parked_capsules` on state changes. Calls `counter_logic.update_signals` on active counter ticks. Tracks active ghosts in `storage.ghost_devices` and `storage.ghost_by_pos`. Handles native `on_blueprint_settings_pasted`, enforces strict spatial ghost settings adoption, fast-replacement co-existence queries, proactive destruction-phase settings transfer (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `projector_settings.copy`), tick-scoped positional fallback caching (`storage.fast_replace_cache`, 60-tick expiry), flow engine unit port enqueuing, parked capsule wakeups (`notify_settings_changed`), Alt-Mode overlay updates, and subscriber registration (`on_settings_changed`). | `register_device_type()`, `register_events()`, `notify_settings_changed()`, `find_existing_real_at_pos()`, `on_settings_changed` subscriber | `proxy-manager`, `diverter-renderer`, `flow-engine`, `counter-logic`, `capsule-runner`, `diverter-gui`, `counter-gui`, `pump-gui` |
| `diverter-renderer.lua` | `scripts/` | Native-style Alt-Mode Diverter Port Filter Overlay Renderer. Queries topological port offsets via `port_defs.get_ports(entity)` and applies directional inward offsets (`PORT_INWARD_OFFSET = 0.55`) to shift filter clusters away from port flow dots. Consumes `gui_components.get_filter_display_spec` to display up to 4 filter item icons per port in adaptive 2x2 grids. Draws 1.3x scaled black silhouette outlines and drop shadows on `render_layer = "entity-info-icon"` and full-color icons, bottom-left quality badges, non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`), standalone quality filters, and per-slot prominent blacklist symbols (`scale * 0.88`) on `render_layer = "entity-info-icon-above"`. Whitelist empty ports render centered "no" symbol; empty blacklist ports suppress overlays. | `diverter_renderer.update_render(entity)`, `diverter_renderer.clear_render(unit_number)` | `control.lua`, `active-device-scanner` |
| `projector-settings.lua` | `scripts/` | Electromagnetic Projector device state persistence table (`storage.projector_settings[unit_number]`). Tracks launch muzzle orientation (`muzzle_dir`), enable status, wire channels, and circuit network enable conditions. Defines `MINIMUM_ENERGY_JOULES = 3000000` (3 MW baseline idle power), `LAUNCH_ENERGY_JOULES = 9000000` (9 MJ buffer capacity required for dispatch), `RECHARGE_GRACE_TICKS = 180` (recharge grace period maintaining kinetic beam and Alt-Mode overlays while buffer refills from 0 to 3 MW baseline), `PROJECTILE_DAMAGE = 250` baseline impact damage rating, and `MAX_ENDPOINT_CAPSULES = 2` endpoint congestion capacity threshold. Provides `can_fire(entity)`, `is_powered(entity)`, `get_launch_energy()`, `get_device_id()`, `copy()`, and `apply_blueprint_settings()`. | `projector_settings.get()`, `projector_settings.can_fire()`, `projector_settings.is_powered()`, `projector_settings.get_device_id()`, `projector_settings.copy()`, `projector_settings.apply_blueprint_settings()` | `active-device-scanner`, `flow-engine`, `capsule-runner`, `pump-gui`, `device-settings-copier` |
| `counter-settings.lua` | `scripts/counters/` | Capsule Counter state persistence table (`storage.counter_settings[dev_id]`). Default schema (`vessels_target = "green"`, `cargo_target = "red"`, `total_target = "green"`, `total_signal = nil`). Supports spatial device ID resolution (`get_device_id`), terminal proxy lookup (`get_proxy`), channel proxies lookup (`get_channel_proxies`), deep-copy cloning (`copy`), and blueprint deserialization (`apply_blueprint_settings`). Preserves selected virtual signal quality levels without hardcoded fallbacks. | `counter_settings.get()`, `counter_settings.get_device_id()`, `counter_settings.get_proxy()`, `counter_settings.get_channel_proxies()`, `counter_settings.copy()`, `counter_settings.apply_blueprint_settings()` | `counter-gui`, `counter-logic`, `active-device-scanner` |
| `counter-gui.lua` | `scripts/counters/` | Interactive relative configuration GUI (`counter_configuration_frame`) anchored to counter entities/proxies, built via `gui-components.lua`. Features dual-wire "Red Wire" and "Green Wire" checkbox channel routing controls for Capsule Vessels, Cargo Contents, and Total Capsule Count, converting checkbox states to/from `"off"`, `"red"`, `"green"`, `"both"`. Includes virtual signal `choose-elem-button` for Total Capsule Count with quality preservation and clear persistence. Fires scanner notifications on edits. | `counter_gui.open()`, `counter_gui.close()`, GUI event handlers | `counter-settings.lua`, `counter-logic.lua`, `gui-components.lua` |
| `counter-logic.lua` | `scripts/counters/` | Capsule Counter Logic & Signal Calculation Engine (`counter_logic.update_signals(counter_entity)`). Queries owned segment nodes (`counter_range.get_owned_nodes`), inspects active capsules in territory without double-counting, extracts vessel item/quality breakdowns, cargo contents, and total capsule count. Implements Triple-Proxy Channel Isolation: writes Red-target signals strictly to the hidden Red channel proxy and Green-target signals strictly to the hidden Green channel proxy while keeping main terminal proxy filters empty, eliminating cross-network signal bleed. Clears signals when unpowered (`entity.energy == 0`) or unconfigured. | `counter_logic.update_signals(counter_entity)` | `counter-settings.lua`, `counter-range.lua`, `active-device-scanner.lua` |
| `diverter-settings.lua` | `scripts/` | Diverter state persistence table (`storage.diverter_settings`). Tracks cardinal port modes (`input`/`output`), whitelist/blacklist filter modes, 5 filter slots per port with explicit quality tracking (`item`, `comparator`, `quality`, `quality_comparator`, `explicit_quality`), `DEFAULT_CAPACITY = 2`, modulo port rotation (`rotate_ports`, `rotate_ports_by_steps`) & axis flipping (`flip_ports`), per-port copy-paste API (`copy_port`, `paste_port`), cardinal direction index normalization (`get_cardinal_index`), spatial identity resolution (`get_device_id`), memoized filter compilation (`_compiled`), circuit proxy signal querying, `.copy()` deep-copy helper, stored setting sanitization on load, and `apply_blueprint_settings()` tag deserialization API. | `diverter_settings.get()`, `diverter_settings.get_capacity()`, `diverter_settings.is_port_enabled()`, `diverter_settings.evaluate_circuit_condition()`, `diverter_settings.rotate_ports()`, `diverter_settings.flip_ports()`, `diverter_settings.copy_port()`, `diverter_settings.paste_port()`, `diverter_settings.get_cardinal_index()`, `diverter_settings.get_device_id()`, `diverter_settings.copy()` | `diverter-gui`, `active-device-scanner`, `capsule-runner`, `device-settings-copier` |
| `diverter-gui.lua` | `scripts/` | Interactive configuration GUI for Pneumatic Diverters, constructed via `gui-components.lua`. Features a 3x3 spatial arrow selector (North ▲, East ▶, South ▼, West ◀, All) defaulting to `"all"` (4-port grid view), native per-port copy/paste tool buttons (`port_copy_button`, `port_paste_button`) using `storage.port_clipboard[player_index]` with floating cursor feedback, 40x40 square overlay slot buttons with corner badges, right-click filter clearing, and draggable `filter_slot_config_frame` modal pop-up (`drag_target = parent_frame`). Uses isolated `draft_filters` working table with explicit confirm (`pneumatic-confirm-gui` tick tracking, `E` key or ✓ button) and cancel (`Esc` key or X button) lifecycle. Resolves parent tags recursively (`get_element_tags`) and guards against re-entrant destruction during local edits. Subscribes to `active_device_scanner.on_settings_changed` to auto-refresh open GUIs on rotation or copy-paste. | `diverter_gui.open()`, `diverter_gui.close()`, `diverter_gui.refresh_if_open()`, GUI event handlers | `diverter-settings.lua`, `active-device-scanner.lua`, `gui-components.lua` |
| `pump-settings.lua` | `scripts/` | Pump state persistence table (`storage.pump_settings`). Tracks manual enable state (`enabled`), circuit enable toggles, comparator conditions, wire channel toggles, spatial identity resolution (`get_device_id`), `.copy()` deep-copy helper, and `apply_blueprint_settings()` tag deserialization API. | `pump_settings.get()`, `pump_settings.is_pump_enabled()`, `pump_settings.evaluate_circuit_condition()`, `pump_settings.get_device_id()`, `pump_settings.apply_blueprint_settings()`, `pump_settings.copy()` | `pump-gui.lua`, `active-device-scanner.lua` |
| `pump-gui.lua` | `scripts/` | Dual-Device UI Controller managing configuration frames for both Pneumatic Pumps (`pump_configuration_frame`) and Electromagnetic Projectors (`projector_configuration_frame`), consuming `gui-components.lua`. Dynamically renders title headers ("Electromagnetic Projector Configuration"), manual enable toggles ("Enable Projector"), Red/Green wire channel toggles, and circuit condition panels based on entity identity. Resolves ghost entities and circuit proxies, persists edits to `storage.pump_settings` or `storage.projector_settings`, and invokes `active_device_scanner.notify_settings_changed(entity)` on edits. Exports convenience aliases `pump_gui.open_projector` and `pump_gui.close_projector`. | `pump_gui.open()`, `pump_gui.close()`, `pump_gui.open_projector()`, `pump_gui.close_projector()`, GUI event handlers | `pump-settings.lua`, `projector-settings.lua`, `active-device-scanner.lua`, `gui-components.lua` |

---

## 2. Persistent Storage Schema (`storage`)

```lua
  -- Fast-Replace Settings Fallback Caches
  fast_replace_cache = {
    ["nauvis@10.5,20.5"] = {
      settings = { ... },                                    -- Deep-copied pump, diverter, counter, or projector settings
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

  -- Per-Player Debug Overlays
  debug = {
    [player_index] = {
      master = true,
      prints = false,
      counter_range = true,
      filter = "string"
    }
  }
```

---

## 3. Core Algorithms & Operational Mechanics

### 5.6 Native Quality-Aware Diverter Filtering & Overlay Specification
1. **Strict Factorio 2.0 Quality Rank Engine:** Maps quality tiers cleanly from `Normal` (rank 1) through `Legendary` (rank 5). Supports explicit quality rank comparisons, wildcard quality matching (`"Any Quality"`), standalone quality filtering, and comparator math (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`) in `matches_filter_item`.
2. **Centralized Filter Display Specification:** `gui_components.get_filter_display_spec` centralizes Factorio 2.0 native filter display rules across slot buttons and Alt-Mode world overlays.
3. **Inward Topological Shift & High-Contrast Backing Frame:** `diverter-renderer.lua` applies `PORT_INWARD_OFFSET = 0.55` inward directional vectors to shift filter clusters away from port flow dots. Renders 1.3x scaled pitch-black silhouette outlines on `render_layer = "entity-info-icon"` and full-color icons, quality badges, comparators, and blacklist symbols on `"entity-info-icon-above"`.
4. **Native Inserter Parity:** Whitelist empty ports render a standalone centered "no" symbol. Blacklist configured ports render prominent "no" symbols centered over individual item icons. Empty blacklist ports suppress overlays.
5. **Recursive Downstream Lookahead Validation:** `is_hop_valid()` inspects downstream external hops when evaluating internal machine transfers, preventing entry into ports leading to full or filter-disqualified tube lines.
6. **Memoized Filter Compilation:** Filter slots and blacklist modes are compiled onto `port_setting._compiled`, enabling early-exit evaluation on whitelist matches.
7. **Targeted Diverter Capacity Expansion:** Multi-port diverters support `DEFAULT_CAPACITY = 2`, allowing up to 2 capsules to transit through internal diverter ports simultaneously.

### 5.11 Triple-Proxy Architecture, Selection Z-Indexing & Zero Signal Bleed
1. **Triple-Proxy Registry Architecture:** Registers a primary terminal proxy (`pneumatic-capsule-counter-circuit-proxy`, `selection_priority = 60`, `operable = true`) alongside hidden channel proxies (`pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy`, `selection_priority = 0`, `operable = false`). Spawns, teleports, and connects internal Red/Green wire bridges (`connect_sub_proxies`) on build/rotate events.
2. **Channel-Isolated Signal Dispatch:** `counter_logic.update_signals` writes Red-target signals strictly to the Red channel proxy and Green-target signals strictly to the Green channel proxy while keeping terminal proxy filters empty, eliminating cross-channel signal bleed.
3. **Spatial Selection Priority Stack Z-Indexing:** Configures terminal proxy prototypes with `selection_priority = 60` (higher than main machines at `50`). Invokes `proxy.teleport(pos)` on build/rotate events to re-insert proxies at the top of Factorio's spatial selection stack.
4. **Additive Proxy Wire Merging:** `transfer_wire_connections` iterates over source `LuaWireConnector` ports and copies wire connections onto surviving real proxies via `connect_to()`, preserving pre-existing circuit networks.
5. **Orphan Auto-Destruction & Multi-Proxy Pruning:** `proxy_manager.destroy_all_proxies_at` purges all associated proxies upon entity removal.

### 5.12 Unified Active Device Background Scanner
1. **Consolidated 15-Tick Background Loop:** Unifies background 15-tick power, circuit, signal recalculation, and capacitor recharge monitoring for physical and ghost machines (`pneumatic-pump`, `pneumatic-diverter`, `pneumatic-capsule-counter`, and `pneumatic-projector`).
2. **Extensible Device Type Registration:** Supports device specification registration (`register_device_type`) handling lifecycle hooks and evaluating power/circuit enable states in constant time.
3. **Projector State & Capacitor Monitoring:** Evaluates projector 3 MW baseline power (`MINIMUM_ENERGY_JOULES = 3000000`), circuit conditions, muzzle orientation changes, and 9 MJ buffer readiness (`can_fire`), triggering port enqueuing and wakeups immediately when ready.
4. **Centralized Notification API:** Exposes `notify_settings_changed(entity)` to re-evaluate enable states, clear filter caches, trigger counter logic, enqueue ports into `flow_engine`, wake parked capsules, and update Alt-Mode overlays.

### 5.13 Live Entity Settings Copy-Paste, Ghost Parity & Blueprint Serialization
1. **Live Entity Source Tracking:** Stores live `LuaEntity` handles in `storage.player_copy_buffer` during copy operations, dynamically evaluating settings and relative directions at paste execution.
2. **Projector Directional Serialization:** Computes relative muzzle direction deltas during live Shift+Left-Click copy-paste and blueprint stamping, preserving configured launch muzzles across orientations.
3. **Native Factorio 2.0 Blueprint Settings Pasted Event:** Subscribes to `defines.events.on_blueprint_settings_pasted` to capture blueprint tags (`pneumatic_settings`) and relative directional changes (`previous_direction`).
4. **Atomic 4-Tuple Blueprint Wire Serialization:** Iterates over proxy circuit connectors and serializes wire connections into 4-element tuples (`[entity_from, wire_type_from, entity_to, wire_type_to]`). Performs instant zero-state spatial wire target resolution on the build tick (`process_entity_built_wire_tags`).
5. **Strict Ghost Settings Adoption & Blueprint Orphan Purging:** Physical entities replacing ghosts inherit configurations when matching spatial tolerance (<0.1 tiles), orientation axis alignment, and prototype real names. Purges orphan proxy records from blueprint books (`clean_blueprint_orphans`).

### 5.14 Declarative UI Widget Component Library, Draft Lifecycle & Quality Engine
1. **Declarative UI Widget Library:** Standardizes window construction (`create_relative_window`), headers with dragging support (`add_header` with `drag_target = parent_frame`), card frames, wire channel toggles, circuit condition panels (55px dropdowns), 40x40 overlay slot buttons, and 3x3 spatial arrow selectors.
2. **Dual-Device UI Controller:** `pump-gui.lua` manages both `pump_configuration_frame` and `projector_configuration_frame`, dynamically rendering titles, manual enable toggles, wire toggles, and circuit condition panels.
3. **Quality Control Bar Engine:** Renders quality comparator dropdowns, 5-tier quality sprite radio buttons, checkmark confirm buttons, and selection highlight styles.
4. **Isolated Draft Working State & Confirm/Cancel Lifecycle:** Modal pop-ups isolate edits inside `draft_filters`. Confirm (✓ or `E`) commits settings; Cancel (X or `Esc`) discards changes without mutating machine state.
5. **Per-Port Copy-Paste & Native Tool Buttons:** Port card headers include native tool buttons copying isolated port configuration tables into `storage.port_clipboard[player_index]` with cursor feedback.

### 5.16 Capsule Counter Segment Territorial Logic & Channel-Isolated Emission
1. **Segment Territory Resolution:** Resolves owned tube segment nodes (`counter_range.get_owned_nodes`) bounded by sensing range boundaries and rival counter wavefront splits.
2. **Payload Aggregation:** Queries active capsules in territory without double-counting, breaking down capsule vessel items/qualities, cargo contents, and total capsule counts.
3. **Channel-Isolated Proxy Signal Emission:** Dispatches Red-target signals strictly to `pneumatic-capsule-counter-red-proxy` and Green-target signals strictly to `pneumatic-capsule-counter-green-proxy` while preserving selected signal quality levels. Clears output signals when unpowered or unconfigured.

### 5.19 Fast-Replace Settings Inheritance & Positional Fallback Cache
1. **Co-Existence Spatial Resolution:** `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` query and discover replacement entities co-existing on the exact tile during Factorio's fast-replace transition window.
2. **Proactive Destruction-Phase Settings Transfer:** Destruction listeners identify replacement entities in-place and execute a direct deep-copy transfer (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `projector_settings.copy`, `hub_settings.copy`) before wiping the old unit number from storage.
3. **Tick-Scoped Positional Fallback Cache:** Deep-copied settings are cached in `storage.fast_replace_cache` or `storage.hub_fast_replace_cache` keyed by spatial coordinate strings, adopted upon placement, and automatically pruned after 60 ticks.

### 5.24 Projector Capacitor Discharge Mechanics, Backpressure Throttling & Alt-Mode Rendering
1. **9 MJ Buffer Discharge & Recharge Grace Period:** Ballistic dispatch requires a fully charged 9 MJ electrical buffer (`LAUNCH_ENERGY_JOULES = 9000000`, evaluated via `can_fire` with 10 kJ tolerance). Deducts 9 MJ from `proj_entity.energy` upon hop commitment or point-blank player collision, logging the dispatch tick to `storage.projector_last_fired`. Grants a 180-tick (`RECHARGE_GRACE_TICKS`) grace period following launch, preventing the kinetic guide beam and Alt-Mode overlays from collapsing while stored energy replenishes from 0 to 3 MW baseline.
2. **Endpoint Congestion Throttling & Backpressure Wakeups:** `count_endpoint_capsules` evaluates ballistic paths and aggregates capsules parked at beam endpoints, receiver chassis ports, and active in-flight beam payloads against `MAX_ENDPOINT_CAPSULES = 2`. When capacity is reached, incoming capsules park safely at the sending intake dock. Freeing tube capacity at the receiver dispatches immediate backpressure wakeups to the sender's ports (`beam_owner`) to resume launches in lockstep.
3. **Per-Player Kinetic Render Isolation:** `storage.kinetic_renders` is indexed by player (`storage.kinetic_renders[player_index]`) and keyed by port key `pkey`. Intersecting or opposing beams occupying the same physical air tiles maintain isolated render handles, preventing a receding beam from erasing another's visuals.
4. **Discrete Per-Tile Visuals & Quality Scaling:** Replaces continuous laser lines with subtle discrete markers: 0.08-radius filled dots on minor nodes, 0.16-radius charged markers every 5th hop, and contextual target rings (cyan/green for aligned receivers, coral hazard indicators for severed or open-air paths). `QUALITY_BEAM_PALETTE` scales thickness (4.0px to 6.0px) and shifts color from holmium magenta to radiant white-magenta across quality tiers.
5. **Passive Intake Port Overlay Rendering:** Detects zero-flow non-muzzle ports belonging to active `pneumatic-projector` units, rendering a 0.12-radius filled cyan dot (`PROJECTOR_INTAKE_COLOR`) in Alt-Mode to clearly mark attachment sockets while preserving normal pressure displays when lines become pressurized.

---

## 4. Visual Render Layer & Spatial Selection Priority Specifications

### 4.1 Diverter Alt-Mode Render Layers (`rendering.draw_*`)

| Render Layer Name | Module Source | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `"entity-info-icon"` | `diverter-renderer.lua` | Sprite | `rendering.draw_sprite` | **Yes** | Renders pitch-black 1.3x scaled centered outline sprite and drop shadow backing frames for port filter overlays. |
| `"entity-info-icon-above"` | `diverter-renderer.lua` | Sprite / Text | `rendering.draw_sprite` / `rendering.draw_text` | **Yes** | Renders full-color filter item icons, bottom-left quality badges, non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`), standalone quality badges, and per-slot prominent blacklist symbols (`scale * 0.88`). |

### 4.2 Spatial Selection Priority & Z-Index Stack

| Selection Priority | Entity Name / Spec | Source File | Z-Index & Interaction Behavior |
| :---: | :--- | :--- | :--- |
| **60** | `pneumatic-pump-circuit-proxy`<br>`pneumatic-diverter-circuit-proxy`<br>`pneumatic-capsule-counter-circuit-proxy`<br>`pneumatic-projector-circuit-proxy` | `proxy-manager.lua`<br>`pneumatic-projector.lua` | Top selection stack priority. Re-inserted via `proxy.teleport(pos)` on build/rotate events to guarantee Red/Green wire tool and Wire Cutter targeting above base entities. Clicks open device configuration GUIs. |
| **50** | `pneumatic-pump`<br>`pneumatic-diverter`<br>`pneumatic-capsule-counter`<br>`pneumatic-projector`<br>`capsule-hub-horizontal`<br>`capsule-hub-vertical`<br>`pneumatic-tube`<br>`junction`<br>`crossflow-junction` | `entity.lua`<br>`pneumatic-diverter.lua`<br>`pneumatic-capsule-counter.lua`<br>`pneumatic-projector.lua` | Standard physical machine and structure selection priority. `pneumatic-pump`, `pneumatic-capsule-counter`, and `pneumatic-projector` prototypes include `gui_mode = "all"` to support native entity interaction dispatching (`on_gui_opened`). |
| **Vanilla Priority** | `stone-wall`<br>`gate` | Base Game | Standard defensive structures participating in pneumatic routing via `pneumatic-fence-gate-interoperability`. |
| **0** | `pneumatic-capsule-counter-red-proxy`<br>`pneumatic-capsule-counter-green-proxy` | `pneumatic-capsule-counter.lua` | Hidden channel proxy prototypes with `operable = false` and `draw_selection_box = false` for isolated internal channel signal wiring. |