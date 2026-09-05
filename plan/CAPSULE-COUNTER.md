Here is the complete, updated **Pneumatic Capsule Counter** specification block, fully updated with all per-category wire routing and coalesced signal features, ready to paste into your planner:

---

# Feature Specification: Pneumatic Capsule Counter

## 1. Overview & Core Purpose
The **Pneumatic Capsule Counter** is a 1x2 powered circuit-sensing structure designed to read real-time capsule occupancy and cargo manifests inside connected tube segments.

* **Primary Purpose:** Enables deadlock-free "sushi loop" tube automation, cargo balancing, and main-bus capacity monitoring.
* **Problem Solved:** Open-loop "add on send / subtract on receive" circuit memory counters fail when biodegradable capsules dissolve mid-flight, refrigerated cargo spoils, or hubs delay disembarkation. The counter provides exact, live ground-truth data directly from the physical tube segment.

---

## 2. Physical & Circuit Architecture
* **Footprint & Power:** 1x2 structure (`electric-energy-interface`, drawing ~30 kW operational power, `selection_priority = 50`).
* **Circuit Terminal Proxy:** Uses a hidden `constant-combinator` circuit proxy (`selection_priority = 60`) registered via `proxy-manager.lua` for native Red/Green wire tool connections, blueprinting, wire serialization, and copy-paste support.
* **Segment Discovery & Querying:** 
  * Inspects the adjacent tube tile it points to and resolves the connected contiguous tube segment via $O(1)$ spatial topology (`storage.flow_nodes`).
  * Scans active capsules in the segment using $O(1)$ occupancy buckets (`storage.occupancy`).

---

## 3. Per-Category Wire Target Routing & GUI Layout
To eliminate signal collision (e.g., when shipping empty capsules as cargo inside other capsules), each signal category has an independent **Wire Target Selector** (`Off`, `Red Wire`, `Green Wire`, `Both`):

```text
+-------------------------------------------------------------+
|  Pneumatic Capsule Counter Configuration                 [X]|
+-------------------------------------------------------------+
|  Wire Target Routing:                                       |
|                                                             |
|  1. Capsule Vessels:    (o) Off  ( ) Red  (•) Green  ( ) Both|
|  2. Cargo Contents:     (o) Off  (•) Red  ( ) Green  ( ) Both|
|  3. Total Capsule 'C':  (•) Off  ( ) Red  ( ) Green  ( ) Both|
|                                                             |
|  Total Count Signal Choice: [ Signal C  v ]                 |
+-------------------------------------------------------------+
```

### **Signal Category Definitions:**
1. **Capsule Vessels Breakdown:**
   * Emits individual signals for capsule item types and quality tiers (e.g., `[Item Capsule, Rare] = 2`). Used for vessel tier tracking and physical line capacity checks.
2. **Cargo Contents Breakdown:**
   * Emits signals for all cargo items and quality tiers loaded inside capsules in the segment via Factorio 2.0 native `LuaInventory.get_contents()` (e.g., `[Iron Plate, Normal] = 400`, `[Copper Cable, Uncommon] = 50`). Used for in-transit inventory balancing on sushi loops.
3. **Coalesced Total Capsule Count (`Signal C`):**
   * Coalesces every physical vessel in the segment—regardless of variant or quality—into a single integer signal (e.g., `[Signal C] = 6`). Players can customize the virtual signal ID (e.g., `Signal C`, `Signal 0`, etc.).
   * **Why Coalesced:** Simplifies tube capacity conditions to a single check (`Signal C < 5`) without needing complex `Each` / `Anything` combinator math.

---

## 4. Example Application (Zero Signal Collision)

* **Red Wire Output (Connected to Assembly / Inserters):**
  * `[Iron Plate, Quality: Normal] = 400`
  * *Purpose:* Assemblers read the **Red Wire** to stop injecting iron plates when enough are already circling the loop in transit.
* **Green Wire Output (Connected to Tube Injector / Diverter):**
  * `[Item Capsule, Quality: Rare] = 2`
  * `[Signal C] = 2`
  * *Purpose:* Diverters and injectors read the **Green Wire** to check physical line density (`Signal C < 5`) and decide whether to release or reroute capsules.

---

## 5. Technical Performance & Runtime Lifecycle
* **Update Frequency:** Integrates into `active-device-scanner.lua` on a 15-tick background loop (with instant power state sensitivity).
* **Zero-Allocation Scans:** Uses persistent scratch arrays to update proxy signal control behaviors without generating Lua GC overhead.
* **Unpowered Behavior:** If electrical power is cut (`entity.energy == 0`), all signal outputs drop to 0 immediately.