local capsule_definitions = {}

--- Exact lookup dictionary for biological items in Factorio 2.0 & Space Age
capsule_definitions.bio_items = {
    ["yumako"] = true,
    ["yumako-seed"] = true,
    ["yumako-mash"] = true,
    ["jellynut"] = true,
    ["jellynut-seed"] = true,
    ["jellynut-slump"] = true,
    ["bioflux"] = true,
    ["jelly"] = true,
    ["spoilage"] = true,
    ["nutrients"] = true,
    ["agricultural-science-pack"] = true,
    ["tree-seed"] = true,
    ["wood"] = true,
    ["raw-fish"] = true,
    ["fish"] = true,
    ["biter-egg"] = true,
    ["pentapod-egg"] = true,
    ["copper-bacteria"] = true,
    ["iron-bacteria"] = true,
    ["captive-biter-spawner"] = true,
    ["biodegradable-capsule"] = true
}

--- Evaluates whether an item is considered a biological item for slot cost calculations
--- @param item_name string
--- @return boolean
function capsule_definitions.is_bio_item(item_name)
    if not item_name then return false end
    return capsule_definitions.bio_items[item_name] == true
end

capsule_definitions.types = {
    ["item-capsule"] = {
        type = "capsule",
        base_capacity = 2,
        quality_affected_capacity = 1,
        mixed_cargo = false,
        mixed_quality = "strict",
        quality_filter = "any",            
        minimum_cargo = "ceil",
        full_stacks = true,
        consolidate_stacks = true,
        include_self = true,
        destroy_self = false,
        destroy_holder_if_empty = true,
        destroy_holder_if_primary_expires = true,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = true,
            mode = "container",
            container = "visible-capsule-holder",
            mark_for_deconstruction = true
        }
    },
    ["biodegradable-capsule"] = {
        type = "capsule",
        base_capacity = 2,
        quality_affected_capacity = 1,
        mixed_cargo = false,
        mixed_quality = "strict",
        quality_filter = "any",
        minimum_cargo = 2,
        full_stacks = false,
        consolidate_stacks = true,
        include_self = true,
        destroy_self = true,
        spill_risk = 0.0008,
        slot_costs = {
            bio_item = 0.5,
            inorganic = 1.0
        },
        destroy_holder_if_empty = true,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = true,
            mode = "ground",
            mark_for_deconstruction = true
        }
    },
    ["refrigerated-capsule"] = {
        type = "capsule",
        base_capacity = 3,
        quality_affected_capacity = 1,
        mixed_cargo = true,
        mixed_quality = "any",
        quality_filter = "any",
        minimum_cargo = 2,
        full_stacks = true,
        consolidate_stacks = true,
        include_self = true,
        destroy_self = false,
        spoilage_modifier = 0.10,
        spent_capsule_item = "spent-refrigerated-capsule",
        destroy_holder_if_empty = true,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = true,
            mode = "container",
            container = "visible-capsule-holder",
            mark_for_deconstruction = true
        }
    },
    ["spent-refrigerated-capsule"] = {
        type = "capsule",
        base_capacity = 3,
        quality_affected_capacity = 1,
        mixed_cargo = true,
        mixed_quality = "any",
        quality_filter = "any",
        minimum_cargo = 2,
        full_stacks = true,
        consolidate_stacks = true,
        include_self = true,
        destroy_self = false,
        spoilage_modifier = 1.0,
        destroy_holder_if_empty = true,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = true,
            mode = "container",
            container = "visible-capsule-holder",
            mark_for_deconstruction = true
        }
    },
    ["reinforced-capsule"] = {
        type = "capsule",
        base_capacity = 6,
        quality_affected_capacity = 2,
        mixed_cargo = true,
        mixed_quality = "any",
        quality_filter = "any",
        minimum_cargo = 2,
        full_stacks = true,
        consolidate_stacks = true,
        include_self = true,
        destroy_self = false,
        destroy_holder_if_empty = true,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = true,
            mode = "container",
            container = "visible-capsule-holder",
            mark_for_deconstruction = true
        }
    },
    ["player-transit-capsule"] = {
        type = "capsule",
        is_player_transit = true,
        base_capacity = 0,
        quality_affected_capacity = 0,
        mixed_cargo = false,
        mixed_quality = "any",
        quality_filter = "any",
        minimum_cargo = 0,
        full_stacks = false,
        consolidate_stacks = false,
        include_self = true,
        destroy_self = false,
        destroy_holder_if_empty = false,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = false,
            mode = "ground",
            mark_for_deconstruction = false
        }
    }
}

return capsule_definitions