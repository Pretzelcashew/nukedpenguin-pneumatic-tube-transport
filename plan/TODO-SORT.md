

---

### Group 1: Localization & Text Strings *(Simplest)*
> Pure string key additions in `locale/en/*.cfg`. Zero runtime risk.

* **Add `en` locale for pump circuit proxy**
* **Add `en` locale for the new hotbar toggles**

---

### Group 2: Bio Item Data & Bonus Tuning *(Very Simple)*
> Data array updates to ensure consistent prototype coverage.

* **Ensure all bio items are included in the bonus capacity list for bio capsules**
  * Audit item prototypes and expand the bio item lookup matrix in `capsule-definitions.lua` / `cargo-planner.lua`.

---

### Group 3: Circuit Proxy Prototype & Collision Fixes *(Simple)*
> Prototype flag modifications to fix build-over / fast-replace behavior.

* **Make circuit proxies no longer block building**
  * Adjust collision masks, selection boxes, or flags (`not-on-map`, `placeable-off-grid`, layer masks) on `pneumatic-pump-circuit-proxy` and `pneumatic-diverter-circuit-proxy` so fast-replace upgrades and building overlays function seamlessly.

---

### Group 4: Debug & UI Panel Consolidation *(Simple to Medium)*
> GUI layout refactoring for player debug/toggle management.

* **Consolidate individual toggles into a single master Pneumatic Control UI panel**
  * Replace separate hotbar toggle windows with a unified custom Lua GUI frame opened via hotbar/command to manage all visual debug toggles (ports, flow, capsules, peek, prints) in one clean window.

---

### Group 5: Entity Capacity & Inventory Controls *(Medium)*
> Machine operational adjustments and inventory clamping logic.

* **Add inventory bar clamping support to Hubs**
  * Implement `set_bar()` clamping on hub container inventories to allow players or scripts to restrict active container slots.
* **Increase Diverter internal capsule capacity slightly**
  * Adjust diverter internal port/network capacity limits in `diverter-settings.lua` / `capsule-motion.lua` to allow smoother queuing and eliminate single-capsule bottlenecks.

---

### Group 6: Render Polling & Spoilage Performance Optimization *(Medium)*
> Dynamic state tracking updates within the tick-based motion and render loops.

* **Disable periodic spoilage/dominant item render polling when spoilables expire**
  * Update `capsule-renderer.lua` and `capsule-lifecycle.lua` so that once a capsule's spoilable items have completely spoiled/decayed, `has_spoilable_items` flips to `false`, disabling the remaining 60-tick container re-scan overhead.

---

### Group 7: Liminal Surface Allocation & Entity Isolation *(Medium to High)*
> Off-grid spatial management, chunk tile painting, and entity boundary safety.

* **Selectively space out liminal capsules only for spoilables that turn into physical units**
  * Optimize `liminal-surface.lua` and `hub-packing.lua` to use tight 1-tile grid slots for non-spoilable/non-unit cargo, reserving wide 8-tile allocated cells exclusively for cargo capable of spoiling into physical biters/units.
* **Add moat/water perimeters around liminal capsule grid cells**
  * Modify `liminal-surface.lua` chunk generation to place water or void moat tiles around allocated grid cells, preventing units created by spoiled items from wandering across cell boundaries into adjacent capsule holders.

---

### Group 8: Staged / Time-Sliced Network Rebuild Engine *(Most Complex)*
> Deep graph topology refactoring to eliminate tick spikes during large network edits.

* **Implement a progressive, time-sliced rebuild for pneumatic network removal/deconstruction**
  * Refactor `network-disconnect.lua` and `network-unmerge.lua` so that deconstructing or splitting large merge-type pipe/diverter networks yields a background queued job (spread across multiple ticks) rather than executing a single synchronous BFS graph traversal.