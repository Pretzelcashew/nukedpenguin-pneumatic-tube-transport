Here is the feature plan outline for the Vacuum Capsule, written strictly focusing on **what** needs to be built and how it behaves in-game:

---

### Feature Specification: Vacuum Capsule & Recharging Lifecycle

#### 1. Core Overview & Target Role
* Introduce the **Vacuum Capsule** as a late-game space technology unlock (`space-science-pack`).
* Fills the niche of **inserter-free, ultra-compact hub loading**, allowing pneumatic hubs to siphon items directly off adjacent transport belts and underground belt hoods.
* Balanced via a **rechargeable charge lifecycle** (converting into a `spent-vacuum-capsule` upon charge depletion) to ensure Standard Capsules remain the maintenance-free default for standard hubs.

---

#### 2. Item, Recipe & Technology Registration ("The What")
* **Vacuum Capsule Item & Recipe:**
  * Subgroup: `pneumatic-capsules`.
  * Unlocked via Space Science Technology (`space-science-pack`).
* **Spent Vacuum Capsule Item:**
  * Depleted shell item resulting from exhausted vacuum charges.
  * Stack size 1, non-operable shell.
* **Recharge Vacuum Capsule Recipe:**
  * Unlocked alongside the capsule.
  * Executed in Assembling Machines to restore `spent-vacuum-capsule` back into a functional `vacuum-capsule`.

---

#### 3. Baseline Capsule Schema & Capacity Rules
* **Cargo Capacity:** 1 base net cargo stack (+1 per Quality tier).
* **Stack Enforcement:** Requires full item stacks (`full_stacks = true`).
* **Quality Rules:** Mixed cargo allowed; cargo quality clamped to the capsule's quality tier (`quality_filter = "ceil"`).
* **Container Lifecycle:** Reusable (converts to spent shell upon charge exhaustion, does not dissolve).

---

#### 4. Functional Capabilities & Behavior
* **Belt Siphon / Vacuum Extraction:**
  * When packing cargo at a Hub, the capsule automatically siphons items directly off any touching belt segment or underground belt hood connected to the hub's ports.
  * Operates on all belt types and belt qualities without requiring inserters or loaders.
* **Charge Consumption:**
  * Performing belt vacuum extractions consumes capsule charges.
  * Once all charges are expended, the capsule transitions into a `spent-vacuum-capsule`.
* **Standard Loading Compatibility:**
  * If no touching belts are present, it can still be loaded via standard inserters into the hub chest.

---

#### 5. User Interface & Visual Polish
* **English Locale Definitions:**
  * Localized names and tooltips for `vacuum-capsule`, `spent-vacuum-capsule`, recharge recipe, and technology node.
  * Tooltip clearly detailing the belt vacuum ability, stack capacity, and recharging requirement.
* **Alt-Mode / Debug Visual Overlay:**
  * Distinct RGBA color code for Alt-Mode debug overlay rings and status icons.