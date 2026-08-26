# ROADMAP.md - Project Development & Feature Hierarchy
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1  
**Author / Maintainer:** Collaborator / Nukedpenguin  
**Description:** Feature roadmap and priority queue outlining planned engineering milestones, mechanics expansion, performance optimizations, and visual polish.

---

## Priority 1: Core Systems & Usability Enhancements

* **Entity Destruction & Disconnect Capsule Spill Safety** [INCORPORATED IN MOD]
  * **Description:** Trigger payload spilling when any network component (tubes, junctions, pumps) hosting an active in-transit capsule is mined or destroyed.
  * **Details:** Expands `hub-spill.lua` beyond hub entities so that destroying an active pipe or junction ejects the capsule's payload (cargo + capsule vessel item) onto the ground or into surrounding inventories, preventing liminal holder entity leaks or orphaned state tables.
  * **Target File(s):** `scripts/networks/network-disconnect.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-runner.lua`

* **Network Capsule Capacity Limits** [INCORPORATED IN MOD]
  * **Description:** Enforce maximum simultaneous in-flight capsule capacity per individual network ID (`net_id`).
  * **Details:** Entities hosting multiple distinct internal networks track and enforce capsule limits independently per network instance.
  * **Target File(s):** `scripts/networks/networks-store.lua`, `scripts/capsules/capsule-runner.lua`

* **Pneumatic Pump Power Consumption** [INCORPORATED IN MOD]
  * **Description:** Integrate electric power requirements into pneumatic pump entity prototypes.
  * **Details:** Unpowered pumps (`entity.energy == 0`) halt pressure generation, disrupting BFS pressure propagation along connected tube graphs.
  * **Target File(s):** `prototypes/entity.lua`, `scripts/networks/networks-pressure.lua`

* **Hub Operational Mode Toggles (`can_send` / `can_receive`)** [INCORPORATED IN MOD]
  * **Description:** Add configurable transfer permission toggles to Hub GUIs.
  * **Details:** Allows players to restrict hub behavior to send-only (dispatch), receive-only (arrival), or bidirectional operation without altering physical pressure or flow vectors.
  * **Target File(s):** `scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua`

* **Dominant Capsule Content Visual Indicators** [INCORPORATED IN MOD]
  * **Description:** Dynamic rendering overlay reflecting the primary payload inside transit capsules.
  * **Details:** Inspects cargo payload to display the icon or color signature of the dominant item stack on active in-flight capsule render objects.
  * **Target File(s):** `scripts/capsules/capsule-runner.lua`

---

## Priority 2: Advanced Dynamic Mechanics, Progression & Automation

* **Pneumatic Technology Tree, Recipes & Item Progression** [INCORPORATED IN MOD]
  * **Description:** Define crafting recipes, machine requirements, and technology tree unlock nodes for all pneumatic transport items.
  * **Details:** Establishes early-to-late game tech progression, balancing material costs (plates, steel, engines, circuits, lubricants) across tubes, pumps, hubs, and capsule vessels.
  * **Target File(s):** `prototypes/recipe.lua`, `prototypes/technology.lua`, `prototypes/item.lua`

* **Pressure-Gradient Variable Capsule Velocity** [INCORPORATED IN MOD]
  * **Description:** Dynamically calculate capsule motion speed based on pressure differentials.
  * **Details:** Replaces static velocity ($30 \text{ tiles/sec}$) with dynamic scaling tied to local edge pressure drops ($\Delta P = P_{\text{from}} - P_{\text{to}}$).
  * **Target File(s):** `scripts/capsules/capsule-runner.lua`

* **Hub Operational Mode Circuit Network Integration** [INCORPORATED IN MOD]
  * **Description:** Expose hub operational toggles (`can_send`/`can_receive`) to circuit network condition evaluation.
  * **Details:** Enables dynamic dispatch and arrival gating based on connected red/green circuit network signal conditions using `evaluate_circuit_condition`.
  * **Target File(s):** `scripts/hubs/hub-settings.lua`, `scripts/hubs/hub-gui.lua`

* **Pump & Advanced Circuit Network Automation**
  * **Description:** Expose pumps and hub chest inventories to full red/green circuit network signals and controls.
  * **Details:** Enables dynamic pump enabling/disabling via circuit signals, target pressure manipulation based on network inputs, and hub container inventory signal outputs to connected wire networks.
  * **Target File(s):** `prototypes/entity.lua`, `scripts/hubs/hub-manager.lua`, `scripts/networks/networks-pressure.lua`, `scripts/networks/pump-manager.lua`

---

## Priority 3: Logistics Suite Expansion, Specialized Vessels & GUI Controls

* **Hub Receive Lock Bypass GUI Toggle** [INCORPORATED IN MOD]
  * **Description:** Add a GUI toggle option on Hubs to enable or disable the post-arrival empty-inventory requirement ("receive lock").
  * **Details:** Allows high-throughput hubs to immediately pack outgoing cargo without requiring the chest to be 100% emptied of incoming items first, stored in `storage.hub_settings[unit_number].use_receive_lock`.
  * **Target File(s):** `scripts/hubs/hub-settings.lua`, `scripts/hubs/hub-gui.lua`, `scripts/hubs/hub-packing.lua`

* **Pneumatic Diverter Entity (Tube Splitter)**
  * **Description:** Introduce a multi-port diverter structure acting as a physical splitter for pneumatic tube lines.
  * **Details:** Implements proportional or alternating flow-culling logic to evenly split pressure gradients or alternate capsule routing across multiple output tubes.
  * **Target File(s):** `prototypes/entity.lua`, `scripts/ports/port-definitions.lua`, `scripts/networks/flow-cull.lua`, `scripts/networks/networks-flow.lua`

* **Specialized Transit Capsule Variants**
  * **Description:** Expand vessel capsule types with custom behavior profiles, slot mechanics, and lifecycle rules.
  * **Variants:**
    * **Biodegradable Capsules:** Low-cost early-game vessels that dissolve upon unpacking (eliminating capsule shell recycling), with a higher risk of structural failure/spilling mid-transit.
    * **Refrigerated Capsules:** Insulated containers that drastically reduce spoilable item degradation rates while in transit.
    * **Reinforced Capsules:** Heavy-duty, high-capacity vessels with expanded stack limits and high recipe cost.
    * **Player Transit Capsules:** Special single-occupant capsules allowing players to enter the pneumatic network and ride across tube topologies.
  * **Target File(s):** `scripts/capsules/capsule-definitions.lua`, `prototypes/item.lua`, `scripts/capsules/capsule-runner.lua`, `scripts/hubs/hub-packing.lua`

* **Specialized Logistics Entities**
  * **Description:** Introduce advanced structural components to solve complex factory layout challenges.
  * **Entities:**
    * **Underground Tubes:** Long-distance subterranean transport channels.
    * **Non-Interfering Crossflow Junctions:** Multi-layer tube crossovers allowing intersecting paths without merging network graph topologies.
    * **High-Pressure Compressors:** Advanced pressure generators requiring fluid lubrication and compressed gas inputs for maximum throughput.
  * **Target File(s):** `prototypes/entity.lua`, `prototypes/item.lua`, `prototypes/recipe.lua`, `scripts/ports/port-definitions.lua`

* **Custom Entity Artwork & Visual Assets**
  * **Description:** Replace placeholder prototype sprites with dedicated 3D-rendered graphics.
  * **Assets:** High-resolution sprites and animations for horizontal/vertical hubs, pumps, junctions, straight tubes, and compressors.
  * **Target Directory:** `graphics/entity/`

---

## Priority 4: Performance Optimizations & System Polish

* **Dominant Content Overlay Caching & Spoilable Polling**
  * **Description:** Optimize dominant item sprite overlay rendering by caching item selection during hub packing.
  * **Details:** Eliminates full inventory iteration on every tick for every active capsule. Re-evaluates item selection only upon packing, and polls at longer intermittent intervals (e.g., every 60 ticks) exclusively for capsules carrying spoilable items.
  * **Target File(s):** `scripts/capsules/capsule-runner.lua`, `scripts/hubs/hub-packing.lua`

* **Emptied Spill Container Auto-Cleanup**
  * **Description:** Automatically destroy temporary spilled capsule containers when their inventory is emptied manually or by automation.
  * **Details:** Hooks container inventory change events (e.g., inserter extraction, hand picking) to clean up empty spill chests without requiring manual player deconstruction orders.
  * **Target File(s):** `scripts/hubs/hub-spill.lua`

* **Capsule Motion Runner Concurrency Optimization**
  * **Description:** Refactor `capsule-runner.lua` execution for high capsule concurrency (>200 active capsules).
  * **Details:** Introduces spatial partitioning, batch rendering updates, cached node lookups, and interleaved updates for non-critical calculations to maintain 60 UPS at scale.
  * **Target File(s):** `scripts/capsules/capsule-runner.lua`, `scripts/capsules/capsule-queries.lua`

* **Network Topology Reflow & Recalculation Performance Optimization**
  * **Description:** Optimize graph rebuilds during pump state toggles or network polarity changes.
  * **Details:** Replaces full network flow map reconstruction with targeted incremental BFS updates and memoized pressure pathing when a pump changes power state or direction.
  * **Target File(s):** `scripts/networks/networks-flow.lua`, `scripts/networks/networks-pressure.lua`, `scripts/networks/pump-manager.lua`