* **Standard Capsule**
  * **Description:** Reusable baseline container for routine item transport across standard factory layouts.
  * **Details:** Holds standard item stacks with zero base spill risk. Requires dedicated return-line tube infrastructure or logistics handling to recycle empty capsules back to origin hubs.
  * **Target File(s):** `prototypes/capsules.lua`, `scripts/logistics/capsule-manager.lua`

* **Bio-Capsule**
  * **Description:** Single-use disposable capsule engineered specifically for Gleba's organic economy and zero-maintenance outposts.
  * **Details:** Crafted on Gleba (1 Carbon Fiber + 2 Jelly + 4 Sulfuric Acid -> 4 Capsules). Features dynamic capacity with higher stack limits for soft biological items (Yumako, Jellynuts, Bioflux) and reduced capacity for inorganic metals. Dissolves into zero items on arrival to eliminate return traffic, balanced by a baseline in-transit spill risk ($0.0008$).
  * **Target File(s):** `prototypes/capsules.lua`, `prototypes/recipes.lua`, `scripts/logistics/capsule-manager.lua`, `scripts/logistics/spill-handler.lua`

* **Bio-Capsule Integrity Upgrade Tech Tree**
  * **Description:** Dedicated Gleba/Agricultural science technology path to incrementally eliminate bio-capsule spill risks.
  * **Details:** Reduces base spill risk by 25% per tier against exponential science costs ($1\times, 4\times, 16\times, 64\times$). Level 0: $100\%$ risk ($0.0008$). Level 1: $75\%$ risk ($0.0006$). Level 2: $50\%$ risk ($0.0004$). Level 3: $25\%$ risk ($0.0002$). Level 4: $0\%$ risk (completely nullifies spills and construction bot decon cleanup strain).
  * **Target File(s):** `prototypes/technology.lua`, `scripts/logistics/spill-handler.lua`

* **Reinforced Capsule**
  * **Description:** Reusable heavy-duty container designed for mixed-cargo routing and multi-ingredient assembly lines.
  * **Details:** Supports mixed cargo stacks within a single capsule. Perfect for mini-bus pneumatic lines and feeding complex assembly setups without needing dedicated single-item tube runs.
  * **Target File(s):** `prototypes/capsules.lua`, `scripts/logistics/capsule-manager.lua`

* **Refrigerated Capsule**
  * **Description:** Specialized perishable goods container with active durability degradation over time.
  * **Details:** Holds a reduced stack size while drastically slowing item spoilage decay during high-speed transit. Degrades with use and eventually requires replacement or repair loops.
  * **Target File(s):** `prototypes/capsules.lua`, `scripts/logistics/capsule-manager.lua`, `scripts/logistics/spoilage-controller.lua`

* **Player Capsule**
  * **Description:** Personal rapid-transit vessel for high-speed player travel across pneumatic tube networks.
  * **Details:** Transports 1 player entity across network paths. Features a `Shift+E` emergency mid-flight bail mechanic (ejects player and destroys the capsule) alongside clean extraction at designated destination hubs.
  * **Target File(s):** `prototypes/capsules.lua`, `scripts/player/player-transit.lua`