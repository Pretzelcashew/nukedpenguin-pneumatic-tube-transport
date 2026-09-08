

---

### Task Breakdown for Sequential Execution

#### **Task 1: Prototypes, Technology Tree & Capsule Schema Declarations**
* **Focus:** Register all item, tool, recipe, technology, locale, and capsule definition schemas.
* **Deliverables:**
  * Register `vacuum-capsule` (tool with durability/charges) and `spent-vacuum-capsule` items in `prototypes/item.lua`.
  * Register crafting and `recharge-vacuum-capsule` recipes in `prototypes/recipe.lua`.
  * Add the `vacuum-capsule` technology node (prerequisites: `space-science-pack`, `pneumatic-transport`) in `prototypes/technology.lua`.
  * Add localized English names, tooltips, and descriptions in `locale/en/config.cfg`.
  * Register `vacuum-capsule` and `spent-vacuum-capsule` schemas, rules, and distinct RGBA debug overlay colors in `scripts/capsules/capsule-definitions.lua`.

---

#### **Task 2: Transport Belt Adjacency & Vacuum Siphon Extraction Engine**
* **Focus:** Detect touching belt entities at Hub ports and extract items directly from transport lines during cargo packing.
* **Deliverables:**
  * Create a belt-siphoning helper module (`scripts/hubs/packing/belt-siphon.lua`) to inspect adjacent transport belts, underground belt hoods, splitters, and linked belts connected to active Hub ports.
  * Query transport lines using `LuaEntity.get_transport_line()` and scan line contents.
  * Integrate belt extraction into `scripts/hubs/hub-packing.lua` and `cargo-planner.lua` to pull cargo directly off belts when packing a `vacuum-capsule`.

---

#### **Task 3: Charge Consumption, Tool Durability Lifecycle & Assembly Recharging**
* **Focus:** Durability drain, charge exhaustion, spent capsule conversion, and assembly machine recharging integration.
* **Deliverables:**
  * Apply charge/durability drain on `vacuum-capsule` tool items upon successful belt siphon packing operations in `hub-packing.lua`.
  * Trigger conversion to `spent-vacuum-capsule` upon charge exhaustion (`spent_capsule_item`).
  * Verify full lifecycle compatibility with assembling machine recharging (`recharge-vacuum-capsule`), hub unpacking, and spill handlers.

---
