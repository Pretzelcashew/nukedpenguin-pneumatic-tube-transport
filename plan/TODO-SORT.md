Here is the complete list of TODO items sorted from **easiest / fastest** to **most complex / heaviest**, along with a codebase analysis and proposed implementation strategy for each:

---

### Sorted TODO Items by Ease of Implementation

#### 1. Move Recharge Spent Refrigerated Capsule Recipe to Pneumatic Transport Tab
* **Difficulty:** Very Easy (~5 minutes)
* **Affected Files:** `prototypes/recipe.lua`
* **Codebase Analysis:** 
  In `recipe.lua`, `recharge-refrigerated-capsule` currently defines `categories = {"crafting-with-fluid"}`, but lacks an explicit `subgroup = "pneumatic-capsules"`. Without a subgroup specified on the recipe, Factorio defaults recipe placement to the `other` / `misc` subgroup in the crafting window.
* **Implementation Plan:** 
  Add `subgroup = "pneumatic-capsules"` and `order = "c[refrigerated]-b[recharge]"` directly to the `recharge-refrigerated-capsule` recipe definition in `recipe.lua`.

---

#### 2. Fix Inconsistent Flow Level Overlay Z-Ordering / Rendering on Entity Rotation
* **Difficulty:** Easy (~15 minutes)
* **Affected Files:** `scripts/flow/flow-engine.lua`
* **Codebase Analysis:** 
  In `flow-engine.lua`, `flow_engine.draw_all()` renders flow pressure numbers by iterating over `storage.flow_levels` using Lua's built-in `pairs()` iterator. When an entity (like a pump emitting level 10 next to a tube at level 9) is rotated, `flow_engine.register_events()` executes `disconnect_entity()` followed by `connect_entity()`. This deletes and re-inserts port keys into `storage.flow_levels`, altering Lua's internal hash table key ordering. As a result, `pairs()` yields the keys in a different order after rotation, changing which text/circle sprite is drawn last and rendered on top.
* **Implementation Plan:** 
  In `flow_engine.draw_all()` (or `update_port_render`), extract and sort the active port keys deterministically (e.g., sorting by level magnitude or numerical port key order) prior to iterating, ensuring identical overlay Z-index rendering regardless of insertion history or entity rotation.

---

#### 3. Add Capsule Details to Factoriopedia
* **Difficulty:** Easy (~20 minutes)
* **Affected Files:** `prototypes/item.lua`, locale configs
* **Codebase Analysis:** 
  Factoriopedia automatically displays custom item metadata via the `factoriopedia_description` prototype property or localized description keys. Currently, capsule items in `item.lua` (such as `item-capsule`, `refrigerated-capsule`, `biodegradable-capsule`, etc.) rely on base item prototypes without explicit Factoriopedia guidance regarding payload rules, mixed cargo support, or spoilage mechanics.
* **Implementation Plan:** 
  Add `factoriopedia_description` attributes to all capsule prototypes in `item.lua` (and localized keys in `locale/en/config.cfg`), detailing cargo slot scaling, mixed cargo/quality support, and environmental decay rules.

---

#### 4. Add Binary "Nest Capsules" Toggle to Hubs
* **Difficulty:** Moderate (~30–45 minutes)
* **Affected Files:** `scripts/hubs/hub-settings.lua`, `scripts/hubs/hub-gui.lua`, `scripts/hubs/hub-packing.lua`
* **Codebase Analysis:** 
  Currently, `hub_packing.evaluate_inventory()` scans all available inventory items and packs whatever valid cargo fits into an available capsule vessel. 
* **Implementation Plan:**
  1. **Settings (`hub-settings.lua`):** Add `nest_capsules = true` (default `true`) to `hub_settings.get()` defaults, `.copy()`, and `.apply_blueprint_settings()`.
  2. **UI (`hub-gui.lua`):** Add a `"Nest capsules"` checkbox inside the hub operational mode relative window frame, updating `settings.nest_capsules`.
  3. **Packing Pipeline (`hub-packing.lua`):** In `evaluate_inventory()`, inspect item stacks during inventory grouping:
     * If `nest_capsules == true`: Only allow candidate item stacks where `capsule_defs.types[stack.name]` is present (hub packs *only* capsules inside capsules).
     * If `nest_capsules == false`: Exclude item stacks where `capsule_defs.types[stack.name]` is present (hub packs *only* non-capsule cargo).

---

#### 5. Native-Feeling Copy/Paste Settings with Outlines, Sound & Persistent Buffer
* **Difficulty:** Moderate-Hard (~45–60 minutes)
* **Affected Files:** `scripts/device-settings-copier.lua`
* **Codebase Analysis:** 
  `device_settings_copier.lua` currently handles `pneumatic-copy-settings` and `pneumatic-paste-settings` custom inputs by storing the source entity's `unit_number` in `storage.player_copy_buffer`. If the source machine is destroyed before pasting, the paste fails because the source `unit_number` is invalid. Additionally, custom hotkey execution lacks Factorio's native audio-visual cues (`utility/paste_settings` sound and entity selection box hover outlines).
* **Implementation Plan:**
  1. **Persistent Buffer:** Update `on_copy_settings` to deep-copy the full settings data structure into `storage.player_copy_buffer[player_index]` alongside entity name/direction so settings survive source entity destruction.
  2. **Native Cues:** Upon a successful paste in `on_paste_settings`, trigger `player.play_sound{ path = "utility/paste_settings" }` and render a temporary green selection highlight outline over the destination entity via `rendering.draw_selection_box`.

---

#### 6. Standardize Native vs. Custom Copy/Paste Events Across Pneumatic Entities
* **Difficulty:** Hard (~1–1.5 hours)
* **Affected Files:** `scripts/device-settings-copier.lua`, `scripts/proxy-manager.lua`, `prototypes/entity.lua`, `prototypes/pneumatic-diverter.lua`
* **Codebase Analysis:** 
  Hubs inherit native `container` prototypes and trigger `defines.events.on_entity_settings_pasted` directly. Pumps and Diverters are `electric-energy-interface` entities with overlaid `constant-combinator` circuit proxies (`selection_priority = 60`). Depending on whether a player targets the main machine or its circuit proxy with Shift+RightClick / Shift+LeftClick or custom input hotkeys (`pneumatic-copy-settings` / `pneumatic-paste-settings`), event dispatching can hit different handler paths.
* **Implementation Plan:** 
  Standardize `resolve_target_entity()` in `device-settings-copier.lua` to transparently map both proxies and main entities to a unified underlying machine representation, ensuring native paste events (`on_entity_settings_pasted`) and custom hotkey bindings invoke identical copy-paste workflows.

---

#### 7. Add Capsule Counter Entity (1x2 Structure, Circuit Proxy & Signal Emission)
* **Difficulty:** Hard (~2 hours)
* **Affected Files:** `prototypes/entity.lua`, `prototypes/item.lua`, `prototypes/recipe.lua`, `scripts/proxy-manager.lua`, `scripts/active-device-scanner.lua`, `scripts/capsules/capsule-queries.lua`
* **Codebase Analysis:** 
  Requires creating a new 1x2 structure that connects into the flow topology network, reads active capsules occupying its spatial node via `capsule_queries`, and outputs circuit signals.
* **Implementation Plan:**
  1. **Prototypes:** Add 1x2 placeable entity, item, recipe, and circuit proxy constant combinator prototypes.
  2. **Proxy Linkage:** Register main/proxy entity pairs in `proxy-manager.lua`.
  3. **Signal Output:** Integrate into `active-device-scanner.lua` to scan capsules in the target tube segment via `capsule_queries.find_capsules_at_entity()`, aggregating primary capsule types and quality ranks into signal parameters pushed to the circuit proxy's output wire connectors.

---

#### 8. Modular Refactoring of Large Monolithic Engine Files (`flow-engine.lua`)
* **Difficulty:** Very Hard / Architectural (~2–3 hours)
* **Affected Files:** `scripts/flow/flow-engine.lua`, `scripts/flow/flow-grid.lua`, `scripts/flow/flow-renderer.lua`, `scripts/flow/flow-stepper.lua`
* **Codebase Analysis:** 
  `flow-engine.lua` is a 650+ line core module managing spatial grid registration (`storage.flow_grid`), wavefront step propagation (`storage.flow_queue`), multi-player debug rendering (`storage.flow_renders`), and event listeners.
* **Implementation Plan:** 
  Decompose `flow-engine.lua` into sub-modules under `scripts/flow/`:
  * `flow-grid.lua`: Handles spatial node connections, disconnections, and grid lookups.
  * `flow-stepper.lua`: Executes queue batching, delta propagation, and level calculations.
  * `flow-renderer.lua`: Manages port/edge rendering object creation, updates, and destruction.
  * `flow-engine.lua`: Acts as a top-level facade facade binding event listeners and exposing the public API.