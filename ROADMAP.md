# ROADMAP.md - Project Development & Feature Hierarchy
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1  
**Author / Maintainer:** Collaborator / Nukedpenguin  
**Description:** Feature roadmap and priority queue outlining planned engineering milestones, mechanics expansion, and visual polish.

---

## Priority 1: Core Systems & Usability Enhancements

* **Entity Destruction & Disconnect Capsule Spill Safety**
  * **Description:** Trigger payload spilling when any network component (tubes, junctions, pumps) hosting an active in-transit capsule is mined or destroyed.
  * **Details:** Expands `hub-spill.lua` beyond hub entities so that destroying an active pipe or junction ejects the capsule's payload (cargo + capsule vessel item) onto the ground or into surrounding inventories, preventing liminal holder entity leaks or orphaned state tables.
  * **Target File(s):** `scripts/networks/network-disconnect.lua`, `scripts/hubs/hub-spill.lua`, `scripts/capsules/capsule-runner.lua`

* **Network Capsule Capacity Limits**
  * **Description:** Enforce maximum simultaneous in-flight capsule capacity per individual network ID (`net_id`).
  * **Details:** Entities hosting multiple distinct internal networks track and enforce capsule limits independently per network instance.
  * **Target File(s):** `scripts/networks/networks-store.lua`, `scripts/capsules/capsule-runner.lua`

* **Pneumatic Pump Power Consumption**
  * **Description:** Integrate electric power requirements into pneumatic pump entity prototypes.
  * **Details:** Unpowered pumps (`entity.energy == 0`) halt pressure generation, disrupting BFS pressure propagation along connected tube graphs.
  * **Target File(s):** `prototypes/entity.lua`, `scripts/networks/networks-pressure.lua`

* **Hub Operational Mode Toggles (`can_send` / `can_receive`)**
  * **Description:** Add configurable transfer permission toggles to Hub GUIs.
  * **Details:** Allows players to restrict hub behavior to send-only (dispatch), receive-only (arrival), or bidirectional operation without altering physical pressure or flow vectors.
  * **Target File(s):** `scripts/hubs/hub-packing.lua`, `scripts/hubs/hub-unpacking.lua``

* **Dominant Capsule Content Visual Indicators**
  * **Description:** Dynamic rendering overlay reflecting the primary payload inside transit capsules.
  * **Details:** Inspects cargo payload to display the icon or color signature of the dominant item stack on active in-flight capsule render objects.
  * **Target File(s):** `scripts/capsules/capsule-runner.lua`

---

## Priority 2: Advanced Dynamic Mechanics & Automation

* **Pressure-Gradient Variable Capsule Velocity**
  * **Description:** Dynamically calculate capsule motion speed based on pressure differentials.
  * **Details:** Replaces static velocity ($30 \text{ tiles/sec}$) with dynamic scaling tied to local edge pressure drops ($\Delta P = P_{\text{from}} - P_{\text{to}}$).
  * **Target File(s):** `scripts/capsules/capsule-runner.lua`

* **Circuit Network Automation Integration**
  * **Description:** Expose hubs and pumps to Factorio's red/green circuit network signal controls.
  * **Details:** Enables dynamic pump enabling/disabling, target pressure manipulation, hub container inventory signal output, and automated `can_send`/`can_receive` toggles.
  * **Target File(s):** `prototypes/entity.lua`, `scripts/hubs/hub-manager.lua`, `scripts/networks/networks-pressure.lua`

---

## Priority 3: Logistics Suite Expansion & Visual Polish

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