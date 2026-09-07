We have updated the implementation plan so the counter range builder works identically to the flow engine's wavefront propagation system. Counter ranges now propagate step-by-step along tube nodes with decaying distance numbers that stop when they collide with other counters' ranges. This wave-based collision mechanism prevents multiple counters on the same loop from overlapping their segments and causing duplicate item counts.

---

# Pneumatic Capsule Counter: Granular Implementation Plan (Revised)

This plan breaks down the development of the Capsule Counter into 10 sequential, self-contained micro-tasks. Task 4 and Task 5 have been specifically updated to reflect exact structural parity with `flow-engine.lua`'s delta wavefront propagation, level decay, and boundary collision mechanics.

---

## Phase 1: Data Stage & Circuit Proxy Foundation

### **Task 1: Prototype Declarations & Data Stage Registration**
* **Goal:** Create the physical counter entity, item, recipe, technology, and hidden circuit proxy prototypes.
* **Target Files:**
  * `prototypes/entity.lua` (or new prototype file `prototypes/pneumatic-capsule-counter.lua` required in `data.lua`)
  * `prototypes/item.lua`
  * `prototypes/recipe.lua`
  * `prototypes/technology.lua`
* **Specification Requirements:**
  * **Main Entity (`pneumatic-capsule-counter`):**
    * Type: `electric-energy-interface` (1x2 footprint, rotatable, 30 kW energy usage, `selection_priority = 50`).
    * Configured with `gui_mode = "all"` and `additional_pastable_entities = {"pneumatic-capsule-counter"}`.
  * **Circuit Proxy (`pneumatic-capsule-counter-circuit-proxy`):**
    * Type: `constant-combinator` (1x1 or matching offset, `selection_priority = 60`, `draw_selection_box = false`, `operable = true`).
    * Configured with `placeable_by = { item = "pneumatic-capsule-counter", count = 0 }` and `"player-creation"` flag.
  * **Item & Recipe:**
    * Register item under subgroup `pneumatic-transport` in `prototypes/item.lua`.
    * Register recipe unlocked via technology in `recipe.lua` and `technology.lua`.
* **Testing / Verification:** Counter can be placed from quickbar/inventory, rotated, mined, unpowered, and eyedropped (`Q`).

---

### **Task 2: Circuit Proxy Lifecycle & Selection Z-Indexing Integration**
* **Goal:** Link the physical counter and circuit proxy lifecycle in `proxy-manager.lua`.
* **Target Files:**
  * `scripts/proxy-manager.lua`
* **Specification Requirements:**
  * Register proxy pair via `proxy_manager.register_pair`:
    ```lua
    proxy_manager.register_pair({
        main_entity_name = "pneumatic-capsule-counter",
        proxy_entity_name = "pneumatic-capsule-counter-circuit-proxy",
        on_open_gui = counter_gui.open -- (stub/forward declaration)
    })
    ```
  * Verify `selection_priority = 60` proxy teleportation on placement and rotation.
  * Ensure additive wire merging (`transfer_wire_connections`), orphan proxy destruction on main entity removal, and sandbox object destruction cleanup (`storage.proxy_destruction_map`) work out-of-the-box.
* **Testing / Verification:** Connect Red/Green wires to the counter. Blueprint, mine, fast-replace, or super-force build over it; verify wires persist and orphan proxies are cleaned up without leaking.

---

## Phase 2: Flow-Parity Wavefront Range Engine & Overlays

### **Task 3: Sensing Port Alignment**
* **Goal:** Register counter directional sensing port in the flow definition table.
* **Target Files:**
  * `scripts/flow/port-defs.lua`
* **Specification Requirements:**
  * Add `pneumatic-capsule-counter` entry to `port_defs`:
    * Defines 1 sensing port offset pointing exactly 1 tile forward according to `defines.direction` (e.g., North points to `{x = 0.0, y = -1.5}`, group = 1, `transmit = false`, `cross_transit = false`, `flow = 0`).
  * Ensure `port_defs.get_ports(entity)` handles ghost entities (`ghost_name`) transparently.
* **Testing / Verification:** Ensure counter registers its port coordinate cleanly into `storage.flow_nodes` without emitting gas pressure levels into connected tubes.

---

### **Task 4: Wavefront Range Propagation & Collision Engine (`counter-range.lua`)**
* **Goal:** Build a delta wavefront propagation engine mirroring `flow-engine.lua` that decays numbers step-by-step and collides with rival counter wavefronts to cleanly partition tube networks.
* **Target Files:**
  * `scripts/counters/counter-range.lua` (New File)
* **Specification Requirements:**
  * **Storage Schemas:** Maintains `storage.counter_levels[pkey]`, `storage.counter_owners[pkey]`, and delta wavefront queue `storage.counter_queue`.
  * **Emitter Emission:** Each active counter acts as a range emitter, injecting a maximum range seed (e.g., `+20` or `+60`) at its sensing port.
  * **Wavefront Propagation Step (`counter_range.step`):**
    1. Propagates hop-by-hop along connected tube nodes via `storage.flow_connections`.
    2. Decays by 1 level per hop down to 1.
    3. **Collision & Boundary Resolution:** When a range wavefront encounters a node that has already been reached by another counter's wavefront with an equal or higher range value, propagation halts at that midpoint tile boundary.
  * **Segment Territory Query (`counter_range.get_owned_nodes(counter_unit)`):**
    * $O(1)$ lookup returning only the specific tube nodes owned by that counter's non-overlapped wavefront territory.
* **Testing / Verification:** Place a single counter and observe range levels decaying along the line. Place a second counter on the same line; verify the two wavefronts collide at the midpoint, stop, and divide the tube line into two non-overlapping target segments.

---

### **Task 5: Counter Wavefront Visual Rendering & Alt-Mode Overlay (`counter-range.lua` & `debug-manager.lua`)**
* **Goal:** Render spatial junction range dots and numbers using exact visual architecture parity with `flow-engine.lua` under a dedicated overlay toggle.
* **Target Files:**
  * `scripts/counters/counter-range.lua`
  * `scripts/debug-manager.lua`
* **Specification Requirements:**
  * Add `counter_range` toggle in `debug-manager.lua`:
    * Field: `storage.debug[player_index].counter_range`
    * Command: `/toggle-counter-range` / `/pt-toggle-counter-range`
    * Shortcut / Control Panel checkbox.
  * Implement `counter_range.draw_all(player_index)` & `update_pos_render(pos_key)`:
    * Structurally identical to `flow_engine.update_pos_render`: consolidates overlapping ports to render exactly **one circle and integer text object per tile coordinate** (`pos_key`).
    * Displays range level integers and owner color dots on connected tube tiles in Alt Mode (`only_in_alt_mode = true`).
    * Kept completely independent from the flow pressure toggle (`new_flow`).
* **Testing / Verification:** Toggle `/toggle-counter-range` in console; verify range decay numbers and territory boundaries render on tube junctions in Alt Mode and disappear cleanly when toggled off.

---

## Phase 3: State Storage, Copy-Paste & Blueprint Serialization

### **Task 6: State Persistence Module (`counter-settings.lua`)**
* **Goal:** Create state management API for per-counter configuration parameters.
* **Target Files:**
  * `scripts/counters/counter-settings.lua` (New File)
* **Specification Requirements:**
  * Structure `storage.counter_settings[dev_id]` schema:
    ```lua
    {
      vessels_target = "green", -- "off" | "red" | "green" | "both"
      cargo_target = "red",     -- "off" | "red" | "green" | "both"
      total_target = "green",   -- "off" | "red" | "green" | "both"
      total_signal = { type = "virtual", name = "signal-C" }
    }
    ```
  * Implement standard API functions:
    * `counter_settings.get_device_id(entity_or_unit)`
    * `counter_settings.get(unit_number)`
    * `counter_settings.copy(src_id, dest_id)`
    * `counter_settings.apply_blueprint_settings(unit_number, blueprint_settings)`
    * `counter_settings.get_proxy(entity)`
* **Testing / Verification:** Verify default table creation, deep-copy cloning, and blueprint tag application in standalone unit checks.

---

### **Task 7: Copy-Paste, Blueprint Serialization & Settings Sync**
* **Goal:** Integrate counter entities with live copy-paste and blueprint settings serialization.
* **Target Files:**
  * `scripts/device-settings-copier.lua`
  * `scripts/active-device-scanner.lua`
* **Specification Requirements:**
  * Add `pneumatic-capsule-counter` to `TARGET_NAMES` in `device-settings-copier.lua`.
  * Support live entity copy-paste (`on_copy_settings` / `on_paste_settings` / `on_entity_settings_pasted`).
  * Support blueprint settings tag serialization (`pneumatic_settings`) on `on_player_setup_blueprint`.
  * Implement ghost settings adoption and orphan cleaning in `clean_blueprint_orphans`.
  * Register counter in `active_device_scanner.lua` for ghost-to-real configuration copy.
* **Testing / Verification:** Shift+Right-Click copy settings between counter entities and ghosts; stamp blueprints containing configured counters and verify settings/wires are restored intact.

---

## Phase 4: Logic Engine & Circuit Signal Emitter

### **Task 8: Background Scanner Integration & Signal Calculation**
* **Goal:** Scan active owned range territory and write Red/Green wire signals to the proxy combinator on the 15-tick loop.
* **Target Files:**
  * `scripts/active-device-scanner.lua`
  * `scripts/counters/counter-logic.lua` (New File)
* **Specification Requirements:**
  * Register `pneumatic-capsule-counter` in `active-device-scanner.lua`:
    * Storage key: `active_counters`.
    * 15-tick periodic scan evaluating power state (`entity.energy > 0`).
  * Implement `counter_logic.update_signals(counter_entity)`:
    1. If `entity.energy == 0`, clear proxy combinator signal outputs immediately.
    2. Query owned segment nodes via `counter_range.get_owned_nodes(counter.unit_number)`.
    3. Query active capsules inside owned nodes via $O(1)$ spatial occupancy (`storage.occupancy` / `capsule_queries.find_capsules_at_entity`).
    4. **Vessels Breakdown:** Scan capsule item types and quality tiers (e.g., `[Item Capsule, Rare] = 2`).
    5. **Cargo Breakdown:** Extract loaded item contents and quality tiers via `LuaInventory.get_contents()` (e.g., `[Iron Plate, Normal] = 400`).
    6. **Total Count Signal (`Signal C`):** Sum total physical capsule vessels in owned range (e.g., `[Signal C] = 2`).
    7. **Wire Channel Routing:** Route signals independently to Red wire, Green wire, or Both based on `counter_settings`.
    8. Write signals directly to the circuit proxy's `control_behavior` (`cb.sections`).
* **Testing / Verification:** Launch capsules filled with cargo into a tube segment shared by two counters. Verify each counter reads strictly the capsules within its own range territory without double-counting. Cut entity power and confirm signal output drops to 0.

---

## Phase 5: GUI Interface Stage

### **Task 9: Relative Configuration GUI (`counter-gui.lua`)**
* **Goal:** Build the interactive counter configuration window anchored to container/entity windows using `gui-components.lua`.
* **Target Files:**
  * `scripts/counters/counter-gui.lua` (New File)
* **Specification Requirements:**
  * Construct frame `counter_configuration_frame` using `gui_components.create_relative_window`.
  * Add header with drag handle and close button (`gui_components.add_header`).
  * Add card container with 3 wire target radio button rows (`Off`, `Red`, `Green`, `Both`):
    1. Capsule Vessels
    2. Cargo Contents
    3. Total Capsule Count
  * Add `choose-elem-button` for Total Count virtual signal choice (`elem_type = "signal"`).
  * Wire event handlers (`on_gui_click`, `on_gui_checked_state_changed`, `on_gui_elem_changed`, `on_gui_closed`) to mutate `storage.counter_settings` and trigger `active_device_scanner.notify_settings_changed(entity)`.
* **Testing / Verification:** Open GUI on built counter and ghost counter; toggle wire routing radio buttons and signal selection; verify open GUIs update dynamically upon copy-paste.

---

## Phase 6: Locale & System Verification

### **Task 10: Localization, Edge-Case Hardening & Final Integration**
* **Goal:** Add localized locale keys and perform full-system regression testing.
* **Target Files:**
  * `locale/en/config.cfg`
  * `control.lua` (Top-level script requires)
* **Specification Requirements:**
  * Add English locale strings:
    * Entity name & description for `pneumatic-capsule-counter`.
    * Item, recipe, and technology captions.
    * GUI headers, radio button labels, and tooltips.
  * Require new script modules (`counter-settings`, `counter-range`, `counter-logic`, `counter-gui`) cleanly at top level in `control.lua`.
  * Verify edge cases:
    * Wavefront range recalculation when a counter is built, mined, or rotated on a active loop.
    * Dissolving biodegradable capsules mid-flight.
    * Refrigerated spoilage mid-transit.
    * Multiple capsule qualities in transit.
    * Unpowering / re-powering counter structures.
    * Blueprinting across different surfaces/forces.
* **Testing / Verification:** Complete full end-to-end integration test run; verify zero console errors, zero Lua GC leaks, exact wavefront boundary collision, and zero duplicate item counts.