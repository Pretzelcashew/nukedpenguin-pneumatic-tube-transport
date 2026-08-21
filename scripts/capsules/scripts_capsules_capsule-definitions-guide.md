# Capsule Definitions Reference (`capsule-definitions.lua`)

This document provides a comprehensive specification of all configuration properties available in `capsule_definitions.types`. Each property controls how capsules interact with the hub packing pipeline (`hub-packing.lua`), quality scaling, stack validation, entity lifecycle, and spill management.

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
        minimum_cargo = "ceil",
        full_stacks = true,
        consolidate_stacks = true,

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

## Detailed Property Breakdown

### 1. `type`
* **Data Type:** `string`
* **Allowed Values:** Any organizational category string (e.g., `"capsule"`, `"cargo-pod"`, `"unit-capsule"`).
* **Description:** Categorizes the capsule definition type within Lua scripts. This separates high-level mod logic from underlying Factorio item/entity prototype names.

---

### 2. `base_capacity`
* **Data Type:** `number` (integer $\ge 0$)
* **Default / Fallback:** `1`
* **Description:** The baseline number of inventory slots available inside the capsule holder at normal quality before quality bonuses are applied.

---

### 3. `quality_affected_capacity`
* **Data Type:** `number` (integer $\ge 0$)
* **Default / Fallback:** `0`
* **Description:** Additional inventory slots granted per quality level.
* **Formula:** 
  $$	ext{Total Capacity} = 	ext{base\_capacity} + (	ext{quality\_level} 	imes 	ext{quality\_affected\_capacity})$$
* **Quality Levels:** Normal = 0, Uncommon = 1, Rare = 2, Epic = 3, Legendary = 4.

---

### 4. `mixed_cargo`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Description:** 
  * `true`: Allows cargo slots to contain multiple distinct item prototypes within a single capsule. Items are selected sequentially in inventory order.
  * `false`: Restricts the capsule to a single item prototype. The packer evaluates all item types present in the chest and selects the single item type group that yields the maximum valid cargo slots while satisfying `minimum_cargo`.

---

### 5. `minimum_cargo`
* **Data Type:** `number` | `string`
* **Allowed Values:** 
  * `number` (e.g., `0`, `1`, `5`): Minimum total slots (cargo slots + self cost if `include_self = true`) required to execute packing.
  * `"ceil"`: Dynamically sets required minimum total slots equal to `total_capacity`.
* **Description:** Defines the threshold of loaded slots required for the hub to successfully pack the capsule. If the chest contains fewer items than required, packing is aborted without modifying the hub chest.

---

### 6. `full_stacks`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Description:** 
  * `true`: Requires cargo items to form full stack quantities (`stack.count == stack.prototype.stack_size`) to be eligible for packing. Partial stacks are ignored unless `consolidate_stacks = true` is enabled.
  * `false`: Allows partial stacks to be packed into cargo slots as-is.

---

### 7. `consolidate_stacks`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Prerequisite:** `full_stacks = true`
* **Description:**
  * `true`: Enables virtual stack consolidation pre-checking. If multiple partial stacks of the same item exist in the hub chest, the packer calculates their total sum virtually. If the sum yields full stacks, the packer extracts the exact item quantities across slots and inserts consolidated full stacks into the holder. Leftover items remain untouched in the hub chest.
  * `false`: Strictly checks individual inventory slots for pre-existing full stacks.

---

### 8. `include_self`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Description:**
  * `true`: The primary capsule item occupies 1 slot inside the destination holder. Cargo slot limit becomes $	ext{total\_capacity} - 1$.
  * `false`: The primary capsule item does not occupy a slot inside the holder. Cargo slot limit equals $	ext{total\_capacity}$.

---

### 9. `destroy_self`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Description:**
  * `true`: The primary capsule item in the hub chest is consumed/destroyed during packing and is **not** placed into the destination holder (even if `include_self = true`).
  * `false`: The primary capsule item is preserved and inserted into the destination holder if `include_self = true`.

---

### 10. `destroy_holder_if_empty`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Description:**
  * `true`: If the holder inventory ends up completely empty after transfer and primary item processing, the holder entity is destroyed on the liminal surface and registration aborts.
  * `false`: Empty holders persist on the liminal surface (ideal for empty containers, probes, or signal transmitters).

---

### 11. `destroy_holder_if_primary_expires`
* **Data Type:** `boolean`
* **Allowed Values:** `true` | `false`
* **Description:**
  * `true`: Monitored by `capsule-manager.lua` on tick. If the primary capsule item inside the holder spoils, decays, or is removed, the liminal holder entity is destroyed.
  * `false`: The liminal holder entity and remaining cargo persist even if the primary capsule item expires or vanishes.

---

### 12. `holder_type`
* **Data Type:** `string`
* **Default / Fallback:** `"invisible-capsule-holder"`
* **Description:** Prototype name of the Factorio entity spawned on the liminal surface to act as the cargo container (e.g., `"invisible-capsule-holder"`, `"wooden-chest"`, `"rocket-silo-payload"`).

---

### 13. `spill_contents`
* **Data Type:** `boolean` | `string` | `table` (Polymorphic)
* **Allowed Configurations:**
  * **Option A (Boolean):**
    ```lua
    spill_contents = true -- Default ground spill
    ```
  * **Option B (String):**
    ```lua
    spill_contents = "ground"  -- Eject items onto terrain
    -- OR
    spill_contents = "capsule" -- Spill contents wrapped in capsule item
    ```
  * **Option C (Table):**
    ```lua
    spill_contents = {
        units = true,                  -- Spill/eject living units inside
        mode = "container",            -- "ground" or "container"
        container = "wooden-chest"     -- Target container prototype name if mode == "container"
    }
    ```
* **Description:** Defines cargo dispersion behavior when a capsule vessel or holder is destroyed or expired.

---

## Configuration Matrix Summary

| Property | Type | Default | Core Function |
| :--- | :--- | :--- | :--- |
| `type` | `string` | `"capsule"` | Definition schema classification |
| `base_capacity` | `number` | `1` | Base available inventory slots |
| `quality_affected_capacity` | `number` | `0` | Bonus slots added per quality level |
| `mixed_cargo` | `boolean` | `true` | Allow multi-item types vs single-item restriction |
| `minimum_cargo` | `number\|string` | `0` | Minimum loaded slots needed to pack (`"ceil"` supported) |
| `full_stacks` | `boolean` | `false` | Require cargo items to be full stacks |
| `consolidate_stacks` | `boolean` | `false` | Enable imaginary partial stack consolidation |
| `include_self` | `boolean` | `true` | Capsule item takes 1 slot in destination holder |
| `destroy_self` | `boolean` | `false` | Consume primary capsule without saving into holder |
| `destroy_holder_if_empty` | `boolean` | `false` | Clean up holder if 0 items packed |
| `destroy_holder_if_primary_expires` | `boolean` | `false` | Destroy holder when primary capsule spoils/vanishes |
| `holder_type` | `string` | `"invisible-capsule-holder"` | Liminal entity prototype created |
| `spill_contents` | `bool\|str\|table` | `true` | Cargo release behavior upon destruction |
