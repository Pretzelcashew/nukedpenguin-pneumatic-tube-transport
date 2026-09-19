# ARCH-DEVICES-CIRCUITS.md - Devices, Triple-Proxy & Circuit Interfacing
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Subsystem Domain:** Unified Active Scanner, Polymorphic Domain Managers, Triple-Proxy Architecture, Copy-Paste & Blueprints, Declarative GUI Components, Subsystem Profiler & Device Controllers (Diverter, Pump, Counter, Projector)

---

## 1. Module Directory

| File | Sub-Path | Purpose & Role | Key Exports / Functions | Connected Modules |
| :--- | :--- | :--- | :--- | :--- |
| `events.lua` | `scripts/` | Centralized event dispatching wrapper around Factorio's `script.on_event`. Allows multiple listeners per event ID. Instruments all registered game events with execution timers, call frequency counters, and per-call averages via `debug.getinfo` when `profiler.ENABLED` is active. Streams real-time chat alerts for non-tick event spikes when event logging is active. | `events.on_event(event_id, handler)` | System-wide event listeners, `profiler.lua` |
| `debug-manager.lua` | `scripts/` | Centralized per-player debug state manager (`storage.debug[player_index]`) and Pneumatic Control Panel Lua GUI controller (`open_panel`, `close_panel`, `toggle_panel`, `refresh_panel`). Manages console log prefix filtering, v2 Alt-Mode flow overlay toggles, sensing range wavefront overlay toggles, kinetic beam overlay reconstruction, shortcut syncing, and console commands (`/pneumatic-panel`, `/toggle-debug`, `/toggle-prints`, `/toggle-flow`, `/toggle-counter-range`, `/toggle-capsules`, `/toggle-capsule-peek`, `/toggle-arrival-dots`, `/toggle-bvh`, `/toggle-viewport-bvh`, `/profile-bvh`, `/profile-events`, `/toggle-event-log`, `/clear-renders`, `/pt-clear-renders`, `/set-render-cadence`). Embeds an in-frame 3-column performance table dynamically refreshing live subsystem execution times (using 60-tick averages `.avg` to eliminate cumulative inflation), entity workloads, discrete BVH spatial rows, tripartite motion timers (`Tube Traversal`, `Ballistics & Heap`, `Frame Sync`), live FPS cadences, and active heap depths every second. Exposes `register_clear_hook` to eliminate circular require cycles between rendering and debug subsystems. | `debug_print(...)`, `is_debug_active(...)`, `open_panel()`, `close_panel()`, `toggle_panel()`, `sync_shortcuts()`, `register_clear_hook(hook)` | System-wide, `profiler.lua`, `capsule-renderer.lua`, `flow-renderer.lua` |
| `event-logger.lua` | `scripts/` | Debug utility logging fired game events to chat console using `debug_print` wrapper with whitelist/blacklist modes. | Dynamic debug event listeners. | `scripts/events.lua`, `debug-manager.lua` |
| `profiler.lua` | `scripts/utils/` | High-precision native subsystem performance profiler using Factorio 2.0 `LuaProfiler` timers. Features defensive single-argument method wrappers (`safe_add`, `safe_divide`, `safe_stop`), sub-routine timers, 60-tick window averaging, chunked snapshot formatting staying strictly below the 20-parameter `LocalisedString` limit, and an explicit master release switch (`profiler.ENABLED`). Instruments universal event dispatching (tracking discrete invocation counts, cumulative execution duration, and per-call averages), dedicated spatial BVH timers (`Viewport`, `Visibility Sync`, `Query Box`, `Tree Mutate`, `Render Dispatch`), and tripartite capsule motion profiling. Exposes real-time event stream logging (`profiler.is_event_log_active()`). Held in script runtime memory (non-serialized). | `profiler.create()`, `profiler.start(name)`, `profiler.stop(name)`, `profiler.record(name, duration)`, `profiler.record_event(event_name, duration)`, `profiler.get_averages()`, `profiler.get_event_averages()`, `profiler.format_snapshot()`, `profiler.is_event_log_active()`, `profiler.ENABLED` | `events.lua`, `active-device-scanner.lua`, `debug-manager.lua`, `viewport-bvh.lua`, `trajectory-bvh.lua`, `capsule-renderer.lua` |
| `gui-filter-spec.lua` | `scripts/utils/gui/` | Filter Display & Specification Engine. Encapsulates Factorio 2.0 native filter display rules (`get_filter_display_spec`, `get_active_filters`), quality sprite path resolution, rich text color formatters, comparator indexing, and native item/quality slot selection state mutations across GUI buttons and world overlays. | `gui_filter_spec.get_filter_display_spec(slot_data)`, `gui_filter_spec.get_active_filters(port_setting)`, `gui_filter_spec.get_quality_color(qual_name)`, `gui_filter_spec.clear_filter_slot(slot_data)` | `gui-components.lua`, `diverter-renderer.lua`, `diverter-slot-modal.lua` |
| `gui-quality-bar.lua` | `scripts/utils/gui/` | Quality Control Bar Controller. Encapsulates the 5-tier quality radio button layout builder (`add_quality_control_bar`), selection highlight style application, comparator dropdown synchronization, and native tier click event handlers across modal dialogs. | `gui_quality_bar.add_quality_control_bar(...)`, `gui_quality_bar.update_selection(...)`, `gui_quality_bar.handle_click(...)` | `gui-components.lua`, `diverter-slot-modal.lua` |
| `gui-components.lua` | `scripts/utils/` | Centralized declarative UI widget builder library and public layout facade. Constructs relative window frames (`create_relative_window`), draggable headers (`add_header` with `drag_target = parent_frame`), card frames, wire channel toggles, circuit condition panels (55px dropdown width), 40x40 overlay slot buttons, and 3x3 spatial arrow selectors. Exposes backwards-compatible aliases delegating to `gui-filter-spec` and `gui-quality-bar`. | `create_relative_window()`, `add_header()`, `add_card_frame()`, `add_wire_channel_toggles()`, `add_circuit_condition_panel()`, `create_overlay_slot_button()`, `update_overlay_slot_button()`, `add_quality_control_bar()`, `add_spatial_arrow_selector()`, `clear_filter_slot()`, `handle_filter_item_change()`, `get_filter_display_spec()` | Device GUIs (`pump-gui`, `diverter-gui`, `hub-gui`, `counter-gui`) |
| `proxy-manager.lua` | `scripts/` | Centralized Proxy Linkage, Multi-Proxy Lifecycle & Object Destruction Engine (`storage.object_destruction_map`). Supports main terminal proxies and sub-proxy schemas (`pneumatic-capsule-counter-red-proxy`, `pneumatic-capsule-counter-green-proxy`, `pneumatic-projector-circuit-proxy`). Spawns, teleports, and connects internal Red/Green wire bridges between channel proxies and terminal proxy on build/rotate events, and purges proxies upon entity removal (`destroy_all_proxies_at`). Implements radius-based host entity discovery (`radius = 0.5`) in `find_main_at` and `on_object_destroyed`, preventing ghost cleanup sweeps from falsely destroying active circuit proxies when physical 2x2 diverters replace ghosts, and corrects Y-axis offset calculations. Registers main entities with `script.register_on_object_destroyed`. Enforces spatial selection precedence (`selection_priority = 60`, `proxy.operable = true`, `proxy.teleport`), additive wire merging (`transfer_wire_connections`), orphan proxy/ghost auto-destruction, and surface-wide orphan purging (`purge_orphans`). | `proxy_manager.register_pair()`, `proxy_manager.register_events()`, `proxy_manager.purge_orphans()`, `proxy_manager.get_registered_proxies()`, `proxy_manager.get_registered_mains()`, `proxy_manager.destroy_all_proxies_at()`, `proxy_manager.find_main_at(surface, pos)` | `control.lua`, `device-settings-copier`, `active-device-scanner`, `blueprint-sync` |
| `blueprint-sync.lua` | `scripts/utils/` | Blueprint Synchronization & Proxy Serialization Engine. Encapsulates blueprint entity tag packing and extraction (`pneumatic_settings`), 4-element circuit wire tuple serialization (`[entity_from, wire_from, entity_to, wire_to]`) across hidden channel and terminal proxies, zero-tick built wire target resolution (`process_entity_built_wire_tags`), and blueprint book orphan proxy scrubbing (`clean_blueprint_orphans`). | `blueprint_sync.serialize_wire_connections(entity)`, `blueprint_sync.apply_wire_tags(entity, tags)`, `blueprint_sync.clean_blueprint_orphans(player)`, `blueprint_sync.process_entity_built_wire_tags(entity, tags)` | `device-settings-copier.lua`, `proxy-manager.lua` |
| `device-settings-copier.lua` | `scripts/` | Live Device Settings Copier and Player Copy-Paste Controller (~183 lines). Manages player copy buffers (`storage.player_copy_buffer`), hotkey handlers (`pneumatic-copy-settings`, `pneumatic-paste-settings`), relative orientation deltas across rotations, and live GUI refreshes. Resolves spatial device IDs on ghost targets, serializing active settings directly into `destination.tags` across pumps, diverters, counters, projectors, and hubs. Exposes backwards-compatible facade aliases delegating blueprint serialization to `blueprint-sync.lua`. | `device_settings_copier.register_events()`, `device_settings_copier.clean_blueprint_orphans()`, `device_settings_copier.process_entity_built_wire_tags()` | `control.lua`, `proxy-manager`, `active-device-scanner`, `blueprint-sync`, `counter-gui`, `pump-gui`, `diverter-gui` |
| `active-device-scanner.lua` | `scripts/` | Unified 15-tick background scanner coordinator (~470 lines). Replaced hardcoded entity-type branching ladders with a standardized polymorphic `spec` registration contract (`copy_settings`, `clear_settings`, `get_settings`, `is_direction_compatible`, `on_rotate_delta`, `on_settings_changed`). Delegates machine-specific simulation to dedicated domain managers (`pump-manager`, `diverter-manager`, `counter-manager`, `projector-manager`). Corrected event hook to `defines.events.script_raised_destroy` to guarantee script and sandbox deconstructions orphan projector reticles. Instrumented with dedicated sub-profilers isolating tick execution durations. Tracks active ghosts in `storage.ghost_devices` and `storage.ghost_by_pos`. Handles native `on_blueprint_settings_pasted`, inspects `entity.tags` alongside `event.tags` on ghost builds, executes fast-replacement co-existence queries, destruction-phase settings transfer, tick-scoped positional fallback caching (`storage.fast_replace_cache`, 60-tick expiry), and dispatches centralized change notifications (`notify_settings_changed`). | `register_device_type(type_name, spec)`, `register_events()`, `notify_settings_changed(entity)`, `find_existing_real_at_pos(...)`, `on_settings_changed` subscriber | `proxy-manager`, `diverter-renderer`, `flow-engine`, `counter-logic`, `capsule-runner`, `counter-manager`, `projector-manager`, `pump-manager`, `diverter-manager`, `profiler` |
| `diverter-renderer.lua` | `scripts/diverters/` | Native-style Alt-Mode Diverter Port Filter Overlay Renderer. Queries topological port offsets via `port_defs.get_ports(entity)` and applies directional inward offsets (`PORT_INWARD_OFFSET = 0.55`) to shift filter clusters away from port flow dots. Consumes `gui_components.get_filter_display_spec` to display up to 4 filter item icons per port in adaptive 2x2 grids. Draws 1.3x scaled black silhouette outlines and drop shadows on `render_layer = "entity-info-icon"` and full-color icons, bottom-left quality badges, non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`), standalone quality filters, and per-slot prominent blacklist symbols (`scale * 0.88`) on `render_layer = "entity-info-icon-above"`. Whitelist empty ports render centered "no" symbol; empty blacklist ports suppress overlays. | `diverter_renderer.update_render(entity)`, `diverter_renderer.clear_render(unit_number)` | `control.lua`, `active-device-scanner`, `diverter-manager` |
| `projector-settings.lua` | `scripts/projectors/` | Electromagnetic Projector device state persistence table (`storage.projector_settings[unit_number]`). Tracks launch muzzle orientation (`muzzle_dir`), enable status, wire channels, and circuit network enable conditions. Defines `MINIMUM_ENERGY_JOULES = 3000000` (3 MW baseline idle power), `LAUNCH_ENERGY_JOULES = 9000000` (9 MJ buffer capacity required for dispatch), `RECHARGE_GRACE_TICKS = 180` (recharge grace period maintaining kinetic beam and Alt-Mode overlays while buffer refills from 0 to 3 MW baseline), `WANT_EMISSION_COOLDOWN_TICKS = 60` (1-second emission rate limiting), `PROJECTILE_DAMAGE = 250` baseline impact damage rating, and `MAX_ENDPOINT_CAPSULES = 2` endpoint congestion capacity threshold. Provides `can_fire(entity)`, `is_powered(entity)`, `get_launch_energy()`, `get_device_id()`, `copy()`, and `apply_blueprint_settings()`. | `projector_settings.get()`, `projector_settings.can_fire()`, `projector_settings.is_powered()`, `projector_settings.get_device_id()`, `projector_settings.copy()`, `projector_settings.apply_blueprint_settings()` | `active-device-scanner`, `projector-manager`, `flow-engine`, `capsule-runner`, `pump-gui`, `device-settings-copier` |
| `projector-manager.lua` | `scripts/projectors/` | Dedicated domain manager for Electromagnetic Projectors registered with `active-device-scanner`. Implements polymorphic `spec` methods: power/enable evaluation (3 MW idle baseline, circuit network conditions), 9 MJ buffer recharge readiness monitoring (`storage.projector_ready_states`), muzzle orientation delta tracking (`on_rotate_delta`), Alt-Mode render triggers, port enqueuing, and emission cooldown teardown (`flow_kinetic.clear_cooldown`). | Polymorphic `spec` implementation, registration | `active-device-scanner`, `projector-settings`, `flow-engine`, `capsule-runner`, `flow-kinetic` |
| `counter-settings.lua` | `scripts/counters/` | Capsule Counter state persistence table (`storage.counter_settings[dev_id]`). Default schema (`vessels_target = "green"`, `cargo_target = "red"`, `total_target = "green"`, `total_signal = nil`). Supports spatial device ID resolution (`get_device_id`), terminal proxy lookup (`get_proxy`), channel proxies lookup (`get_channel_proxies`), deep-copy cloning (`copy`), and blueprint deserialization (`apply_blueprint_settings`). Preserves selected virtual signal quality levels without hardcoded fallbacks. | `counter_settings.get()`, `counter_settings.get_device_id()`, `counter_settings.get_proxy()`, `counter_settings.get_channel_proxies()`, `counter_settings.copy()`, `counter_settings.apply_blueprint_settings()` | `counter-gui`, `counter-logic`, `counter-manager`, `active-device-scanner` |
| `counter-manager.lua` | `scripts/counters/` | Dedicated domain manager for Capsule Counters registered with `active-device-scanner`. Implements polymorphic `spec` methods: power evaluation (30 kW), signal update triggers (`counter_logic.update_signals`), settings copying, and Alt-Mode range overlay updates. | Polymorphic `spec` implementation, registration | `active-device-scanner`, `counter-settings`, `counter-logic`, `counter-range` |
| `counter-gui.lua` | `scripts/counters/` | Interactive relative configuration GUI (`counter_configuration_frame`) anchored to counter entities/proxies, built via `gui-components.lua`. Features dual-wire "Red Wire" and "Green Wire" checkbox channel routing controls for Capsule Vessels, Cargo Contents, and Total Capsule Count, converting checkbox states to/from `"off"`, `"red"`, `"green"`, `"both"`. Includes virtual signal `choose-elem-button` for Total Capsule Count with quality preservation and clear persistence. Includes fallback tag restoration on GUI open to guarantee pasted ghost settings display prior to placement, and auto-refreshes open windows on paste events. Fires scanner notifications on edits. | `counter_gui.open()`, `counter_gui.close()`, GUI event handlers | `counter-settings.lua`, `counter-logic.lua`, `gui-components.lua`, `active-device-scanner.lua` |
| `counter-logic.lua` | `scripts/counters/` | Capsule Counter Logic & Zero-Polling Circuit Signal Emission Engine. Streams pre-aggregated stable signal summaries directly from `storage.counter_stable_summary[counter_unit]` into proxy filter tables in memory, completely eliminating Factorio C++ entity and inventory queries for static cargo networks. Scopes slot iteration strictly to active dynamic/virtual capsules in `counter_range.get_territory_capsules(counter_unit)`. Implements Triple-Proxy Channel Isolation: writes Red-target signals strictly to the hidden Red channel proxy and Green-target signals strictly to the hidden Green channel proxy while keeping main terminal proxy filters empty, eliminating cross-network signal bleed. Clears signals when unpowered (`entity.energy == 0`) or unconfigured. | `counter_logic.update_signals(counter_entity)` | `counter-settings.lua`, `counter-range.lua`, `counter-manager.lua`, `active-device-scanner.lua` |
| `diverter-settings.lua` | `scripts/diverters/` | Diverter state persistence table (`storage.diverter_settings`). Tracks cardinal port modes (`input`/`output`), whitelist/blacklist filter modes, 5 filter slots per port with explicit quality tracking (`item`, `comparator`, `quality`, `quality_comparator`, `explicit_quality`), `DEFAULT_CAPACITY = 2`, modulo port rotation (`rotate_ports`, `rotate_ports_by_steps`) & axis flipping (`flip_ports`), per-port copy-paste API (`copy_port`, `paste_port`), cardinal direction index normalization (`get_cardinal_index`), spatial identity resolution (`get_device_id`), memoized filter compilation (`_compiled`), circuit proxy signal querying, `.copy()` deep-copy helper, stored setting sanitization on load, and `apply_blueprint_settings()` tag deserialization API. | `diverter_settings.get()`, `diverter_settings.get_capacity()`, `diverter_settings.is_port_enabled()`, `diverter_settings.evaluate_circuit_condition()`, `diverter_settings.rotate_ports()`, `diverter_settings.flip_ports()`, `diverter_settings.copy_port()`, `diverter_settings.paste_port()`, `diverter_settings.get_cardinal_index()`, `diverter_settings.get_device_id()`, `diverter_settings.copy()` | `diverter-gui`, `diverter-slot-modal`, `diverter-manager`, `active-device-scanner`, `capsule-runner`, `device-settings-copier` |
| `diverter-slot-modal.lua` | `scripts/diverters/` | Diverter Slot Configuration Modal Subsystem. Encapsulates the popup filter configuration frame (`filter_slot_config_frame`), draft filter state buffers (`draft_filters`), tick confirmation tracking (`confirm_ticks`), quality control bar event handlers, item choose-element changes, and confirm (`E` / ✓) and cancel (`Esc` / X) commit lifecycles. | `diverter_slot_modal.open(...)`, `diverter_slot_modal.close(...)`, `diverter_slot_modal.handle_confirm(...)`, `diverter_slot_modal.handle_cancel(...)` | `diverter-gui.lua`, `diverter-settings.lua`, `gui-components.lua`, `gui-quality-bar.lua` |
| `diverter-gui.lua` | `scripts/diverters/` | Interactive configuration GUI for Pneumatic Diverters, constructed via `gui-components.lua`. Focuses strictly on the 4-direction port overview, 3x3 direction arrow selector (North ▲, East ▶, South ▼, West ◀, All), and per-port clipboard tools (`port_copy_button`, `port_paste_button`) using `storage.port_clipboard[player_index]` with floating cursor feedback. Includes fallback tag restoration on GUI open to guarantee pasted ghost settings display prior to placement. Subscribes to `active_device_scanner.on_settings_changed` to auto-refresh open GUIs on rotation or copy-paste. Delegates modal slot configuration to `diverter-slot-modal.lua` while exposing backwards-compatible public API facade aliases. | `diverter_gui.open()`, `diverter_gui.close()`, `diverter_gui.refresh_if_open()`, GUI event handlers | `diverter-settings.lua`, `diverter-slot-modal.lua`, `diverter-manager`, `active-device-scanner.lua`, `gui-components.lua` |
| `diverter-manager.lua` | `scripts/diverters/` | Dedicated domain manager for Pneumatic Diverters registered with `active-device-scanner`. Implements polymorphic `spec` methods: power and circuit enable evaluation, port state tracking (`storage.diverter_port_states`), relative port rotation (`diverter_settings.rotate_ports`), Alt-Mode overlay updates (`diverter_renderer.update_render`), and filter clearing. | Polymorphic `spec` implementation, registration | `active-device-scanner`, `diverter-settings`, `diverter-gui`, `diverter-renderer` |
| `pump-settings.lua` | `scripts/pumps/` | Pump state persistence table (`storage.pump_settings`). Tracks manual enable state (`enabled`), circuit enable toggles, comparator conditions, wire channel toggles, spatial identity resolution (`get_device_id`), `.copy()` deep-copy helper, and `apply_blueprint_settings()` tag deserialization API. | `pump_settings.get()`, `pump_settings.is_pump_enabled()`, `pump_settings.evaluate_circuit_condition()`, `pump_settings.get_device_id()`, `pump_settings.apply_blueprint_settings()`, `pump_settings.copy()` | `pump-gui.lua`, `pump-manager.lua`, `active-device-scanner.lua` |
| `pump-gui.lua` | `scripts/pumps/` | Dual-Device UI Controller managing configuration frames for both Pneumatic Pumps (`pump_configuration_frame`) and Electromagnetic Projectors (`projector_configuration_frame`), consuming `gui-components.lua`. Dynamically renders title headers ("Electromagnetic Projector Configuration"), manual enable toggles ("Enable Projector"), Red/Green wire channel toggles, and circuit condition panels based on entity identity. Resolves ghost entities and circuit proxies, restores ghost fallback tags on open, persists edits to `storage.pump_settings` or `storage.projector_settings`, auto-refreshes on settings pasted, and invokes `active_device_scanner.notify_settings_changed(entity)` on edits. Exports convenience aliases `pump_gui.open_projector` and `pump_gui.close_projector`. | `pump_gui.open()`, `pump_gui.close()`, `pump_gui.open_projector()`, `pump_gui.close_projector()`, GUI event handlers | `pump-settings.lua`, `projector-settings.lua`, `pump-manager.lua`, `active-device-scanner.lua`, `gui-components.lua` |
| `pump-manager.lua` | `scripts/pumps/` | Dedicated domain manager for Pneumatic Pumps registered with `active-device-scanner`. Implements polymorphic `spec` methods: power evaluation, circuit condition evaluation (`pump_settings.evaluate_circuit_condition`), enable state caching (`storage.pump_enabled_states`), settings copying, and flow engine port enqueuing. | Polymorphic `spec` implementation, registration | `active-device-scanner`, `pump-settings`, `pump-gui`, `flow-engine` |

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
    ["101:1"] = 15 -- Sensing wavefront distance level (15 scaled by quality down to 1)
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
  counter_capsules = {
    [105] = { [capsule_id] = true } -- Event-driven resident capsule IDs inside counter territory
  },
  counter_stable_summary = {
    [105] = { ["iron-plate::normal"] = 400 } -- Memoized pre-aggregated circuit signals (zero C++ polling)
  },
  counter_stable_capsules = {
    [105] = { [capsule_id] = { ["iron-plate::normal"] = 100 } }
  },
  counter_dynamic_capsules = {
    [105] = { [capsule_id] = true } -- Dynamic/virtual capsules requiring slot iteration
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

  -- Electromagnetic Projector Facility State Tracking & Cooldown
  active_projectors = { [unit_number] = LuaEntity },
  projector_power_states = { [unit_number] = true },
  projector_enabled_states = { [unit_number] = true },
  projector_muzzle_states = { [unit_number] = defines.direction.north },
  projector_ready_states = { [unit_number] = true },
  projector_last_fired = { [unit_number] = 123456 },
  projector_cooldown_heap = {
    data = { { id = unit_number, priority = 123456, data = { ... } } },
    indices = { [unit_number] = 1 },
    size = 1
  },
  projector_cooldown_until = {
    [unit_number] = 123456 -- Tick timestamp when projector can emit next positive beam
  },
  projector_settings = {
    [unit_number] = {
      muzzle_dir = defines.direction.north, enabled = true, use_circuit_enable = false,
      enable_condition = { first_signal = nil, comparator = "=", constant = 0 },
      read_red = true, read_green = true
    }
  },

  -- Per-Player Debug Overlays & Diagnostics
  debug = {
    [player_index] = {
      master = true,
      prints = false,
      counter_range = true,
      capsules = true,
      peek = false,
      arrival_dots = true,
      bvh = false,
      viewport_bvh = false,
      filter = "string"
    }
  }
```

---

## 3. Core Algorithms & Operational Mechanics

### 5.6 Native Quality-Aware Diverter Filtering & Overlay Specification
1. **Strict Factorio 2.0 Quality Rank Engine:** Maps quality tiers cleanly from `Normal` (rank 1) through `Legendary` (rank 5). Supports explicit quality rank comparisons, wildcard quality matching (`"Any Quality"`), standalone quality filtering, and comparator math (`Any`, `>`, `<`, `=`, `≥`, `≤`, `≠`) in `matches_filter_item`.
2. **Centralized Filter Display Specification:** `gui_filter_spec.get_filter_display_spec` centralizes Factorio 2.0 native filter display rules across slot buttons and Alt-Mode world overlays.
3. **Inward Topological Shift & High-Contrast Backing Frame:** `diverter-renderer.lua` applies `PORT_INWARD_OFFSET = 0.55` inward directional vectors to shift filter clusters away from port flow dots. Renders 1.3x scaled pitch-black silhouette outlines on `render_layer = "entity-info-icon"` and full-color icons, quality badges, comparators, and blacklist symbols on `"entity-info-icon-above"`.
4. **Native Inserter Parity:** Whitelist empty ports render a standalone centered "no" symbol. Blacklist configured ports render prominent "no" symbols centered over individual item icons. Empty blacklist ports suppress overlays.
5. **Recursive Downstream Lookahead Validation:** `is_hop_valid()` inspects downstream external hops when evaluating internal machine transfers, preventing entry into ports leading to full or filter-disqualified tube lines.
6. **Memoized Filter Compilation:** Filter slots and blacklist modes are compiled onto `port_setting._compiled`, enabling early-exit evaluation on whitelist matches.
7. **Targeted Diverter Capacity Expansion:** Multi-port diverters support `DEFAULT_CAPACITY = 2`, allowing up to 2 capsules to transit through internal diverter ports simultaneously.

### 5.11 Triple-Proxy Architecture, Selection Z-Indexing & Zero Signal Bleed
1. **Triple-Proxy Registry Architecture:** Registers a primary terminal proxy (`pneumatic-capsule-counter-circuit-proxy`, `selection_priority = 60`, `operable = true`) alongside hidden channel proxies (`pneumatic-capsule-counter-red-proxy` and `pneumatic-capsule-counter-green-proxy`, `selection_priority = 0`, `operable = false`). Spawns, teleports, and connects internal Red/Green wire bridges (`connect_sub_proxies`) on build/rotate events.
2. **Channel-Isolated Signal Dispatch:** `counter_logic.update_signals` writes Red-target signals strictly to the Red channel proxy and Green-target signals strictly to the Green channel proxy while keeping terminal proxy filters empty, eliminating cross-network signal bleed.
3. **Spatial Selection Priority Stack Z-Indexing:** Configures terminal proxy prototypes with `selection_priority = 60` (higher than main machines at `50`). Invokes `proxy.teleport(pos)` on build/rotate events to re-insert proxies at the top of Factorio's spatial selection stack.
4. **Radius-Based Host Entity Discovery:** `proxy_manager.find_main_at` and `on_object_destroyed` utilize a radius query (`radius = 0.5`) with corrected Y-axis offset calculations. This prevents ghost cleanup routines from falsely destroying active circuit proxies when physical 2x2 diverters or 1x2 counters replace ghosts.
5. **Additive Proxy Wire Merging:** `transfer_wire_connections` iterates over source `LuaWireConnector` ports and copies wire connections onto surviving real proxies via `connect_to()`, preserving pre-existing circuit networks.
6. **Orphan Auto-Destruction & Multi-Proxy Pruning:** `proxy_manager.destroy_all_proxies_at` purges all associated proxies upon entity removal.

### 5.12 Unified Active Device Background Scanner & Polymorphic Subsystems
1. **Consolidated 15-Tick Background Loop:** Coordinates 15-tick cadence monitoring across physical and ghost machines (`pneumatic-pump`, `pneumatic-diverter`, `pneumatic-capsule-counter`, and `pneumatic-projector`).
2. **Polymorphic Device Specification Contract:** Replaces hardcoded entity-type branching ladders across ghost adoption, fast replacement, blueprint pasting, and deconstruction with a standardized `spec` contract:
   - `copy_settings(source_entity, dest_entity)`
   - `clear_settings(entity)`
   - `get_settings(entity)`
   - `is_direction_compatible(dir_a, dir_b)`
   - `on_rotate_delta(entity, delta_steps)`
   - `on_settings_changed(entity)`
3. **Dedicated Domain Managers:** Machine-specific logic is isolated into `pump-manager.lua`, `diverter-manager.lua`, `counter-manager.lua`, and `projector-manager.lua`.
4. **Subsystem Profiler Instrumentation:** Scanner iterations are instrumented with sub-profilers isolating tick durations for counters, diverters, pumps, projectors, and fast-replace cache pruning.
5. **Centralized Notification API:** Exposes `notify_settings_changed(entity)` to re-evaluate enable states, clear filter caches, trigger counter logic, enqueue ports into `flow_engine`, wake parked capsules, and update Alt-Mode overlays.
6. **Script-Raised Destruction Hook:** Bound destruction handlers explicitly to `defines.events.script_raised_destroy`, ensuring mod-script destructions, sandbox wipes, and map editor tools orphan projector reticles reliably.

### 5.13 Live Entity Settings Copy-Paste, Ghost Parity & Blueprint Synchronization
1. **Live Entity Source Tracking:** Stores live `LuaEntity` handles in `storage.player_copy_buffer` during copy operations, dynamically evaluating settings and relative directions at paste execution.
2. **Live Ghost Settings Serialization:** Resolves spatial device IDs on ghost targets during live copy-paste and Shift+Right-Click, serializing active settings directly into `destination.tags` across pumps, diverters, counters, projectors, and hubs.
3. **Ghost Blueprint Tag Extraction:** Construction hooks inspect `entity.tags` alongside `event.tags` on ghost placement, applying blueprint settings immediately rather than overwriting ghosts with blank configs.
4. **Blueprint Synchronization Engine (`blueprint-sync.lua`):** Deep-copies settings into `pneumatic_settings` tags on `on_player_setup_blueprint`. Serializes proxy wire connections via 4-element tuples `[entity_from, wire_type_from, entity_to, wire_type_to]` and invariant blueprint indices. Executes instant zero-tick spatial wire target resolution on the build tick (`process_entity_built_wire_tags`).
5. **Blueprint Book Orphan Scrubbing:** `clean_blueprint_orphans` scans active blueprint handles and books to purge orphaned circuit proxy records when main machines are deselected in the blueprint window.
6. **Live GUI Auto-Refresh on Paste:** Registers `on_settings_changed` subscribers across `diverter-gui`, `pump-gui`, and `counter-gui` to dynamically re-draw open frames when settings are pasted.

### 5.14 Declarative UI Widget Component Library, Draft Lifecycle & Quality Engine
1. **Declarative UI Widget Library:** Standardizes window construction (`create_relative_window`), draggable headers (`add_header` with `drag_target = parent_frame`), card frames, wire channel toggles, circuit condition panels (55px dropdowns), 40x40 overlay slot buttons, and 3x3 spatial arrow selectors.
2. **Modular Quality Control Bar (`gui-quality-bar.lua`):** Renders quality comparator dropdowns, 5-tier quality sprite radio buttons, checkmark confirm buttons, and selection highlight styles.
3. **Modular Diverter Slot Modal (`diverter-slot-modal.lua`):** Popup modal `filter_slot_config_frame` isolates draft edits inside `draft_filters`. Confirm (✓ or `E` key via `pneumatic-confirm-gui` tick tracking) commits settings; Cancel (X or `Esc` key) cleanly discards drafts without mutating machine state.
4. **Ghost GUI Tag Fallback Restoration:** Opening a GUI on a ghost entity automatically falls back to inspecting `entity.tags` if live runtime records are uninitialized, guaranteeing pasted configurations display prior to placement.
5. **Per-Port Copy-Paste & Native Tool Buttons:** Port card headers include native tool buttons copying isolated port configuration tables into `storage.port_clipboard[player_index]` with floating cursor feedback.

### 5.16 Event-Driven Capsule Counter Territory Indexing & Zero-Polling Circuit Emission
1. **Event-Driven Territory Membership:** Capsule Counter territory membership is indexed directly in `storage.counter_capsules[counter_unit]`. Transitions occur in $O(1)$ time in lockstep with 6-tick capsule motion (`update_capsule_occupancy`, `remove_capsule`) and wavefront boundary changes (`counter_range.handle_port_owner_changed`).
2. **Stable Cargo Signal Memoization:** Standard cargo and invariant shells compute immutable circuit signal footprints upon packing (`storage.active_capsules[capsule_id].signal_data`). Contributions are aggregated into `storage.counter_stable_summary[counter_unit]`.
3. **Zero C++ Polling Signal Dispatch:** `counter_logic.update_signals` streams pre-aggregated stable summaries directly from Lua memory into proxy filter tables. Factorio C++ entity and inventory slot queries are completely eliminated for static cargo networks, reducing counter scan times from ~1.83 ms to sub-microsecond levels.
4. **Scoped Dynamic/Virtual Slot Iteration:** Slot polling is strictly confined to dynamic capsules (refrigerated, unit-producing, and player transit) tracked in `storage.counter_dynamic_capsules[counter_unit]`.
5. **Channel-Isolated Proxy Emission:** Writes Red-target signals strictly to `pneumatic-capsule-counter-red-proxy` and Green-target signals strictly to `pneumatic-capsule-counter-green-proxy` while preserving selected signal quality levels. Clears output signals when unpowered (`energy == 0`) or unconfigured.

### 5.19 Fast-Replace Settings Inheritance & Positional Fallback Cache
1. **Co-Existence Spatial Resolution:** `find_existing_real_at_pos` and `find_existing_real_hub_at_pos` query and discover replacement entities co-existing on the exact tile during Factorio's fast-replace transition window.
2. **Proactive Destruction-Phase Settings Transfer:** Destruction listeners identify replacement entities in-place and execute a direct deep-copy transfer (`pump_settings.copy`, `diverter_settings.copy`, `counter_settings.copy`, `projector_settings.copy`, `hub_settings.copy`) before wiping the old unit number from storage.
3. **Tick-Scoped Positional Fallback Cache:** Deep-copied settings are cached in `storage.fast_replace_cache` or `storage.hub_fast_replace_cache` keyed by spatial coordinate strings, adopted upon placement, and automatically pruned after 60 ticks.

### 5.24 Projector Capacitor Discharge Mechanics, Backpressure Throttling & Alt-Mode Rendering
1. **9 MJ Buffer Discharge & Recharge Grace Period:** Ballistic dispatch requires a fully charged 9 MJ electrical buffer (`LAUNCH_ENERGY_JOULES = 9000000`, evaluated via `can_fire` with 10 kJ tolerance). Deducts 9 MJ from `proj_entity.energy` upon hop commitment or point-blank player collision, logging the dispatch tick to `storage.projector_last_fired`. Grants a 180-tick (`RECHARGE_GRACE_TICKS`) grace period maintaining kinetic beam and Alt-Mode overlays while buffer refills from 0 to 3 MW baseline.
2. **60-Tick Want Emission Cooldown:** Enforces `WANT_EMISSION_COOLDOWN_TICKS = 60` post-emission rate limiting managed via `storage.projector_cooldown_heap` to suppress beam spam from rapid machine rotation or power oscillating.
3. **Endpoint Congestion Throttling & Backpressure Wakeups:** `count_endpoint_capsules` evaluates ballistic paths and aggregates capsules parked at beam endpoints, receiver chassis ports, and active in-flight beam payloads against `MAX_ENDPOINT_CAPSULES = 2`. When capacity is reached, incoming capsules park safely at the sending intake dock. Freeing tube capacity at the receiver dispatches immediate backpressure wakeups to the sender's ports (`beam_owner`) to resume launches in lockstep.
4. **Per-Player Kinetic Render Isolation:** `storage.kinetic_renders` is indexed by player (`storage.kinetic_renders[player_index]`) and keyed by port key `pkey`. Intersecting or opposing beams occupying the same physical air tiles maintain isolated render handles, preventing a receding beam from erasing another's visuals.
5. **Discrete Per-Tile Visuals & Quality Scaling:** Subtle discrete markers: 0.08-radius filled dots on minor nodes, 0.16-radius charged markers every 5th hop, and contextual target rings (cyan for aligned receivers, coral hazard indicators for severed or open-air paths).
6. **Passive Intake Port Overlay Rendering:** Detects zero-flow non-muzzle ports belonging to active `pneumatic-projector` units, rendering a 0.12-radius filled cyan dot (`PROJECTOR_INTAKE_COLOR`) in Alt-Mode to clearly mark attachment sockets while preserving normal pressure displays when lines become pressurized.

### 5.35 Live Subsystem Performance Profiler & Pneumatic Control Panel Diagnostic Table
1. **Factorio 2.0 Native Profiler Integration:** `profiler.lua` leverages native `LuaProfiler` timers to isolate per-tick execution times across individual machines and simulation loops without chat console spam.
2. **Defensive Wrapper & Chunked Snapshot Formatting:** Employs defensive wrappers (`safe_add`, `safe_divide`, `safe_stop`) guarding against engine assertion faults. Snapshots are chunked to strictly adhere to the 20-parameter limit on `LocalisedString` tables.
3. **Universal Event Dispatch Profiling:** `events.on_event` times all registered Factorio game events whenever profiling is active, recording discrete invocation counts, cumulative execution durations, and per-call duration averages for each subsystem listener. Exposes `/profile-events` and real-time chat alerts (`/toggle-event-log`) for non-tick event spikes and 16-tile viewport hysteresis shell breaches.
4. **Dedicated Spatial BVH Subsystem Instrumentation:** Profiles discrete spatial subsystems: Viewport (`update_all_players`), Visibility Sync (`sync_player_visibility`), Spatial Queries (`query_box`), Tree Mutations (`insert`/`remove`/`update`), and Render Dispatch (`dispatch_player_renders`), exposed via `/profile-bvh`.
5. **Metric Average Alignment & 60-Tick Normalization:** Uses 60-tick rolling averages (`.avg`) across all spatial BVH and subsystem rows in the Pneumatic Control Panel table, eliminating cumulative sum distortion and accurately reflecting sub-millisecond execution times.
6. **Capsule Motion Tripartite Breakdown:** Subdivides motion profiling into three discrete timers:
   - `Tube Traversal`: Discrete 6t hops and diverter routing.
   - `Ballistics & Heap`: Arrival heap stepping and projectile physics.
   - `Frame Sync`: Governor aggregation, pre-calculations, and viewport sets.
   Displays live counts for tube capsules, in-flight projectiles, heap entries, and active visual FPS cadences.
7. **Production Master Switch:** Master switch `profiler.ENABLED` completely deactivates profiling timers and GUI polling overhead in production builds.

### 5.36 Polymorphic Device Contract & Domain Manager Lifecycle Architecture
1. **Elimination of Hardcoded Entity Branching:** Standardized polymorphic `spec` registry replaces hardcoded entity-type branching ladders across active scanner, copy-paste, blueprinting, and teardown routines.
2. **Encapsulated Domain Managers:** Device lifecycle handlers, settings validation, rotation deltas, and Alt-Mode render updates are encapsulated in dedicated modules:
   - `pump-manager.lua`: Manages `pneumatic-pump` power states and flow enqueuing.
   - `diverter-manager.lua`: Manages `pneumatic-diverter` port mode rotations, quality filtering, and Alt-Mode overlay syncing.
   - `counter-manager.lua`: Manages `pneumatic-capsule-counter` power evaluation, signal recalculations, and sensing range sync.
   - `projector-manager.lua`: Manages `pneumatic-projector` 3 MW idle consumption, 9 MJ capacitor buffer readiness, launch muzzle orientation, and emission cooldown clearance (`flow_kinetic.clear_cooldown`).
3. **Centralized Registration API:** Modules register their contracts via `active_device_scanner.register_device_type(type_name, spec)`, supporting clean mod extensibility.

---

## 4. Visual Render Layer & Spatial Selection Priority Specifications

### 4.1 Diverter Alt-Mode Render Layers (`rendering.draw_*`)

| Render Layer Name | Module Source | Object Type | API Method | Alt-Mode Only? | Description & Target |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `"entity-info-icon"` | `scripts/diverters/diverter-renderer.lua` | Sprite | `rendering.draw_sprite` | **Yes** | Renders pitch-black 1.3x scaled centered outline sprite and drop shadow backing frames for port filter overlays. |
| `"entity-info-icon-above"` | `scripts/diverters/diverter-renderer.lua` | Sprite / Text | `rendering.draw_sprite` / `rendering.draw_text` | **Yes** | Renders full-color filter item icons, bottom-left quality badges, non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`), standalone quality badges, and per-slot prominent blacklist symbols (`scale * 0.88`). |

### 4.2 Spatial Selection Priority & Z-Index Stack

| Selection Priority | Entity Name / Spec | Source File | Z-Index & Interaction Behavior |
| :---: | :--- | :--- | :--- |
| **60** | `pneumatic-pump-circuit-proxy`<br>`pneumatic-diverter-circuit-proxy`<br>`pneumatic-capsule-counter-circuit-proxy`<br>`pneumatic-projector-circuit-proxy` | `proxy-manager.lua`<br>`prototypes/entities/pneumatic-projector.lua` | Top selection stack priority. Re-inserted via `proxy.teleport(pos)` on build/rotate events to guarantee Red/Green wire tool and Wire Cutter targeting above base entities. Clicks open device configuration GUIs. |
| **50** | `pneumatic-pump`<br>`pneumatic-diverter`<br>`pneumatic-capsule-counter`<br>`pneumatic-projector`<br>`capsule-hub-horizontal`<br>`capsule-hub-vertical`<br>`pneumatic-tube`<br>`junction`<br>`crossflow-junction` | `prototypes/entity.lua`<br>`prototypes/entities/pneumatic-diverter.lua`<br>`prototypes/entities/pneumatic-capsule-counter.lua`<br>`prototypes/entities/pneumatic-projector.lua` | Standard physical machine and structure selection priority. `pneumatic-pump`, `pneumatic-capsule-counter`, and `pneumatic-projector` prototypes include `gui_mode = "all"` to support native entity interaction dispatching (`on_gui_opened`). |
| **Vanilla Priority** | `stone-wall`<br>`gate` | Base Game | Standard defensive structures participating in pneumatic routing via `pneumatic-fence-gate-interoperability`. |
| **0** | `pneumatic-capsule-counter-red-proxy`<br>`pneumatic-capsule-counter-green-proxy` | `prototypes/entities/pneumatic-capsule-counter.lua` | Hidden channel proxy prototypes with `operable = false` and `draw_selection_box = false` for isolated internal channel signal wiring. |