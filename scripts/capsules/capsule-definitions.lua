-- FILE: scripts/capsules/capsule-definitions.lua
local capsule_definitions = {}

capsule_definitions.types = {
    ["item-capsule"] = {
        -- Core Capacity
        type = "capsule",
        base_capacity = 2,
        quality_affected_capacity = 1,
        mixed_cargo = false,
        
        mixed_quality = "strict",
        quality_filter = "any",            

        minimum_cargo = "ceil",
        full_stacks = true,
        consolidate_stacks = true,

        -- Lifecycle Flags
        include_self = true,
        destroy_self = false,
        destroy_holder_if_empty = true,
        destroy_holder_if_primary_expires = true,

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