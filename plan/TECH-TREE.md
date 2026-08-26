# TECH-TREE.md - Technology & Recipe Progression
**Mod Name:** `nukedpenguin-pneumatic-tube-transport`  
**Factorio Target Version:** 2.1 / Space Age  
**Author / Maintainer:** Collaborator / Nukedpenguin  
---
## 1. Mid-Game Core Progression (Nauvis)
### Technology: Pneumatic Transport
* **Tier:** Chemical (Blue) Science
* **Cost:** 350 × Automation Pack (Red) + Logistics Pack (Green) + Chemical Pack (Blue) @ 45s per cycle
* **Prerequisites:** Advanced Circuit, Fluid Handling, Logistics 2
* **Unlocks:**
  * **Pneumatic Hub:** Primary dispatch & arrival terminal for item capsules.
  * **Pneumatic Tube:** Transport piping for pressurized flow lines.
  * **Pneumatic Pump:** Electric pressure generator establishing flow vectors across networks.
  * **Pneumatic Junction:** Passive multi-directional intersection point for tube lines.
  * **Standard Vessel Capsule:** Basic reusable transit container (1 item slot capacity).
### Technology: Advanced Pneumatic Logistics
* **Tier:** Utility (Yellow) Science
* **Cost:** 500 × Red + Green + Blue + Utility Pack (Yellow) @ 60s per cycle
* **Prerequisites:** Pneumatic Transport, Utility Science Pack
* **Unlocks:**
  * **Pneumatic Diverter:** Actuated tube splitter with dynamic line balancing and direction controls.
---
## 2. Space Age Planetary Expansion
### Technology: Organic Pneumatic Containers
* **Location:** Gleba
* **Science Pack:** Agricultural Science Pack
* **Prerequisites:** Agricultural Science Pack, Pneumatic Transport
* **Unlocks:**
  * **Biodegradable Capsule:** Single-use organic capsule. Dissolves upon arrival/unpacking, eliminating return-shell logistics loops. Has a higher structural rupture risk during transit.
  * **Crafting Recipe:** 1 Carbon Fiber + 2 Jelly + 4 Sulfuric Acid → **4× Biodegradable Capsule** (1 Item Slot)
### Technology: Heavy Pneumatic Containment
* **Location:** Vulcanus
* **Science Pack:** Metallurgic Science Pack
* **Prerequisites:** Metallurgic Science Pack, Pneumatic Transport
* **Unlocks:**
  * **Reinforced Capsule:** Heavy-duty vessel with expanded payload volume for dense materials.
  * **Crafting Recipe:** 2 Low Density Structure + 8 Tungsten Carbide → **1× Reinforced Capsule** (2 Item Slots)
### Technology: Cryogenic Pneumatic Preservation
* **Location:** Aquilo
* **Science Pack:** Cryogenic Science Pack
* **Prerequisites:** Cryogenic Science Pack, Pneumatic Transport
* **Unlocks:**
  * **Refrigerated Capsule:** Super-insulated thermal container. Reduces transit spoilage rates by 50% ($0.5\times$ rot speed multiplier). Degrades into a **Spent Refrigerated Capsule** after 30 minutes of operational runtime.
  * **Crafting Recipe:** 2 Low Density Structure + 4 Lithium Plate + 100 Fluoroketones → **1× Refrigerated Capsule** (1 Item Slot)
  * **Replenish Recipe:** 1 Spent Refrigerated Capsule + 125 Fluoroketones → **1× Refrigerated Capsule**
### Technology: Pneumatic Passenger Transport
* **Location:** Fulgora
* **Science Pack:** Electromagnetic Science Pack
* **Prerequisites:** Electromagnetic Science Pack, Pneumatic Transport
* **Unlocks:**
  * **Player Transit Capsule:** High-capacity personal transport capsule allowing the player entity to enter and ride through the pneumatic tube network.
  * **Crafting Recipe:** 4 Low Density Structure + 200 Superconductor → **1× Player Transit Capsule** (1 Player Slot)
---
## 3. Technology & Recipe Summary

| Item / Entity | Science Tier / Location | Ingredients | Yield / Capacity | Key Attribute |
| :--- | :--- | :--- | :--- | :--- |
| **Standard Capsule** | Chemical (Blue) | Base Prototype | 1 Capsule (1 Slot) | Standard reusable container |
| **Pneumatic Diverter** | Utility (Yellow) | Base Prototype | 1 Entity | Line-balancing splitter |
| **Biodegradable Capsule** | Gleba (Agricultural) | 1 Carbon Fiber, 2 Jelly, 4 Sulfuric Acid | 4 Capsules (1 Slot) | Auto-dissolves on unpack |
| **Reinforced Capsule** | Vulcanus (Metallurgic) | 2 LDS, 8 Tungsten Carbide | 1 Capsule (2 Slots) | Expanded stack capacity |
| **Refrigerated Capsule** | Aquilo (Cryogenic) | 2 LDS, 4 Lithium Plates, 100 Fluoroketones | 1 Capsule (1 Slot) | 0.5x rot speed, 30m lifetime |
| **Refrigerated Refill** | Aquilo (Cryogenic) | 1 Spent Capsule, 125 Fluoroketones | 1 Replenished Capsule | Restores spent coolant |
| **Player Transit Capsule** | Fulgora (Electromagnetic) | 4 LDS, 200 Superconductors | 1 Capsule (1 Player) | Passenger pod transport |