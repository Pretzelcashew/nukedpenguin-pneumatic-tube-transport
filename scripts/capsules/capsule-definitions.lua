-- FILE: scripts/capsules/capsule-definitions.lua
local capsule_definitions = {}

capsule_definitions.types = {
    ["item-capsule"] = {
        -- Core Capacity
        type = "capsule",
        base_capacity = 2,
        quality_affected_capacity = 1,
        mixed_cargo = true,
        mixed_quality = false,
        minimum_cargo = "ceil",
        full_stacks = true,
        consolidate_stacks = true,
        quality_filter = "ceil",

        -- Lifecycle Flags
        include_self = true,
        destroy_self = false,
        destroy_holder_if_empty = false,
        destroy_holder_if_primary_expires = false,

        -- Entities
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