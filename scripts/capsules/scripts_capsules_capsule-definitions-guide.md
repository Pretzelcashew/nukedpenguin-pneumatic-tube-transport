# Capsule Definitions Reference (`capsule-definitions.lua`)

This document provides a clear specification of all configuration properties available in `capsule_definitions.types`. Each property controls how capsules interact with the hub packing pipeline (`hub-packing.lua`), quality scaling, stack validation, entity lifecycle, and spill management.

---

## Example Definition

```lua
-- FILE: scripts/capsules/capsule-definitions.lua
local capsule_definitions = {}

capsule_definitions.types = {
    ["item-capsule"] = {
        -- Core Capacity & Cargo Rules
        type = "capsule",
        base_capacity = 2,
        quality_affected_capacity = 1,
        mixed_cargo = true,
        mixed_quality = false,
        minimum_cargo = "ceil",
        full_stacks = true,
        consolidate_stacks = true,
        quality_filter = "ceil",

        -- Lifecycle & Holder Flags
        include_self = true,
        destroy_self = false,
        destroy_holder_if_empty = false,
        destroy_holder_if_primary_expires = false,

        -- Liminal Entity
        holder_type = "invisible-capsule-holder",

        -- Spill Configuration
        spill_contents = {
            units = true,
            mode = "container",
            container = "wooden-chest"
        }
    }
}

return capsule_definitions
```

---

## Property Details

### 1. `type`
* **Data Type:** String
* **Allowed Values:** Any custom category label (e.g., `"capsule"`, `"cargo-pod"`, `"unit-capsule"`).
* **Description:** Internal organizational tag for your mod's script logic. It does not map to Factorio engine categories or item prototypes.

---

### 2. `base_capacity`
* **Data Type:** Whole number (0 or higher)
* **Default:** `1`
* **Description:** Baseline number of cargo slots in the holder at normal quality.

---

### 3. `quality_affected_capacity`
* **Data Type:** Whole number (0 or higher)
* **Default:** `0`
* **Description:** Extra cargo slots granted per quality level.
* **Calculation:** `base_capacity + (quality_level * quality_affected_capacity)`
* **Quality Levels:** Normal = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4.

---

### 4. `mixed_cargo`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `true`
* **Description:** 
  * `true`: Allows multiple different item prototypes in the same capsule.
  * `false`: Restricts the capsule to a single item prototype. The packer selects whichever item group yields the most filled slots.

---

### 5. `mixed_quality`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `false`
* **Description:**
  * `true`: Allows cargo stacks of different quality tiers to be packed into the same capsule.
  * `false`: Restricts cargo selection so that all packed stacks must share the exact same quality level.
  * **Note:** If `consolidate_stacks = true`, single-quality grouping is automatically enforced per stack regardless of this setting, as Factorio inventory slots cannot hold mixed-quality items.

---

### 6. `quality_filter`
* **Data Type:** String or Table
* **Allowed Values:**
  * `"ceil"`: Caps cargo item quality at or below the primary vessel capsule's quality level (`cargo_quality <= vessel_quality`).
  * `"any"` / `"*"` / `nil`: Accepts any item quality level.
  * Comparators: `">=rare"`, `">uncommon"`, `"<=epic"`, `"=normal"`, `"!legendary"`.
  * Array Table: Whitelist / Blacklist combination (e.g., `{"normal", "uncommon"}` or `{"!legendary", ">=uncommon"}`).
* **Description:** Filters cargo items by quality eligibility before stack consolidation and grouping take place.

---

### 7. `minimum_cargo`
* **Data Type:** Number or String
* **Allowed Values:** 
  * `number` (e.g., `0`, `1`, `5`): Minimum slots (cargo + self slot if enabled) required to pack.
  * `"ceil"`: Automatically sets the required minimum slots equal to maximum capacity.
* **Description:** Threshold required for the capsule to pack. If the chest doesn't have enough items, packing is aborted and items stay in the chest.

---

### 8. `full_stacks`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `false`
* **Description:** 
  * `true`: Only accepts stacks that are completely full. Partial stacks are ignored unless `consolidate_stacks` is enabled.
  * `false`: Accepts partial stacks as-is.

---

### 9. `consolidate_stacks`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `false`
* **Prerequisite:** `full_stacks = true`
* **Description:**
  * `true`: Virtually combines partial stacks of the same item/quality in the hub. If the total adds up to full stacks, it extracts those items and places clean full stacks into the holder. Leftovers remain in the hub untouched.
  * `false`: Strictly requires individual inventory slots to already be full stacks.

---

### 10. `include_self`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `true`
* **Description:**
  * `true`: The capsule item itself occupies 1 slot inside the destination holder (cargo limit becomes `total_capacity - 1`).
  * `false`: The capsule item does not take up a slot in the holder.

---

### 11. `destroy_self`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `false`
* **Description:**
  * `true`: Consumes/destroys the capsule item from the hub during packing without saving it to the holder.
  * `false`: Preserves the capsule item and puts it in the holder (if `include_self = true`).

---

### 12. `destroy_holder_if_empty`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `false`
* **Description:**
  * `true`: Destroys the holder entity if 0 items end up inside after packing.
  * `false`: Keeps empty holder entities alive on the liminal surface.

---

### 13. `destroy_holder_if_primary_expires`
* **Data Type:** Boolean (`true` or `false`)
* **Default:** `false`
* **Description:**
  * `true`: Destroys the liminal holder entity if the primary capsule item inside spoils, decays, or vanishes.
  * `false`: Keeps the holder and its contents intact even if the main capsule item expires.

---

### 14. `holder_type`
* **Data Type:** String
* **Default:** `"invisible-capsule-holder"`
* **Description:** Prototype name of the entity spawned on the liminal surface to store the cargo.

---

### 15. `spill_contents`
* **Data Type:** Boolean, String, or Table
* **Default:** `true`
* **Allowed Values:**
  * `true`: Spills contents onto the ground.
  * `"ground"` or `"capsule"`: Specific spill target mode.
  * Table configuration:
    ```lua
    spill_contents = {
        units = true,
        mode = "container",
        container = "wooden-chest"
    }
    ```
* **Description:** Defines what happens to the cargo when a capsule or holder is destroyed.

---

## Configuration Summary Table

| Property | Type | Default | What It Does |
| :--- | :--- | :--- | :--- |
| `type` | String | `"capsule"` | Custom organizational category label |
| `base_capacity` | Number | `1` | Base cargo slots |
| `quality_affected_capacity` | Number | `0` | Extra slots per quality level |
| `mixed_cargo` | Boolean | `true` | Allow different item types in one capsule |
| `mixed_quality` | Boolean | `false` | Allow different quality levels in one capsule |
| `quality_filter` | String/Table | `nil` | Filter eligible cargo quality (`"ceil"`, comparators, whitelists) |
| `minimum_cargo` | Number/String | `0` | Minimum slots required to trigger pack (`"ceil"` supported) |
| `full_stacks` | Boolean | `false` | Require cargo items to be full stacks |
| `consolidate_stacks` | Boolean | `false` | Combine partial stacks virtually into full stacks |
| `include_self` | Boolean | `true` | Primary capsule occupies 1 slot in holder |
| `destroy_self` | Boolean | `false` | Delete primary capsule instead of saving to holder |
| `destroy_holder_if_empty` | Boolean | `false` | Delete holder if no items were packed |
| `destroy_holder_if_primary_expires` | Boolean | `false` | Delete holder if main capsule spoils or vanishes |
| `holder_type` | String | `"invisible-capsule-holder"` | Prototype name of liminal entity |
| `spill_contents` | Bool/String/Table | `true` | Spill behavior on entity destruction |