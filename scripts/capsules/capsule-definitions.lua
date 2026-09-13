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
--- Evaluates whether a capsule type or definition is an electromagnetic capsule
--- @param def_or_name string|table|nil
--- @return boolean
function capsule_definitions.is_electromagnetic(def_or_name)
    if not def_or_name then return false end
    if type(def_or_name) == "table" then
        return def_or_name.is_electromagnetic == true or def_or_name.name == "electromagnetic-capsule"
    elseif type(def_or_name) == "string" then
        local def = capsule_definitions.types[def_or_name]
        return (def and def.is_electromagnetic == true) or def_or_name == "electromagnetic-capsule"
    end
    return false
end

--- Helper to safely test if an item stack or prototype is spoilable without triggering Factorio 2.0 errors
--- @param stack LuaItemStack|nil
--- @return boolean
function capsule_definitions.is_stack_spoilable(stack)
    if not (stack and stack.valid_for_read) then return false end
    local proto = stack.prototype
    if proto and proto.get_spoil_ticks then
        local ticks = proto.get_spoil_ticks()
        if ticks and ticks > 0 then
            return true
        end
    end
    if stack.spoil_tick and stack.spoil_tick > 0 then
        return true
    end
    if stack.spoil_percent and stack.spoil_percent > 0 then
        return true
    end
    return false
end

--- Evaluates if an item stack is spoilable into physical units (biters, pentapods, etc.)
--- Uses strict C++ prototype property inspection and exact matrix lookups.
--- @param stack LuaItemStack|nil
--- @return boolean
function capsule_definitions.is_unit_spoilable(stack)
    if not (stack and stack.valid_for_read) then return false end
    if not capsule_definitions.is_stack_spoilable(stack) then return false end

    local proto = stack.prototype
    if proto and proto.spoil_to_trigger_result then
        return true
    end

    local name = stack.name
    if name == "biter-egg" or name == "pentapod-egg" or name == "captive-biter-spawner" then
        return true
    end

    return false
end

--- Evaluates whether a capsule definition represents a dynamic capsule shell whose state can change in transit
--- @param def_or_name string|table|nil
--- @param has_spoilable_items boolean|nil
--- @return boolean
function capsule_definitions.is_dynamic_capsule(def_or_name, has_spoilable_items)
    if not def_or_name then return false end
    local def = type(def_or_name) == "table" and def_or_name or capsule_definitions.types[def_or_name]
    if not def then return false end
    if def.is_player_transit then
        return true
    end
    return has_spoilable_items == true
end

--- Reusable upper classifier for evaluating whether a capsule is fully stable
--- A stable capsule is guaranteed to never change its primary shell identity or cargo contents during transit.
--- @param def_or_name string|table|nil Capsule type name or definition table
--- @param has_spoilable_items boolean|nil Whether any item in cargo can spoil
--- @param passenger LuaPlayer|nil Whether a passenger is riding in the capsule
--- @return boolean
function capsule_definitions.is_stable_capsule(def_or_name, has_spoilable_items, passenger)
    if passenger ~= nil then return false end
    if has_spoilable_items == true then return false end
    local def = type(def_or_name) == "table" and def_or_name or capsule_definitions.types[def_or_name]
    if def and def.is_player_transit then return false end
    return true
end

capsule_definitions.types = {
    ["item-capsule"] = {
        name = "item-capsule",
        type = "capsule",
        debug_color = { r = 1.0, g = 0.84, b = 0.0, a = 0.9 }, -- Metallic Gold
        cargo_capacity = 1,                 -- Exactly 1 net cargo slot
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        mixed_cargo = true,                 -- Mix any item types across cargo slots
        mixed_quantity = false,
        mixed_quality = "any",              -- Mix qualities up to capsule quality
        quality_filter = "ceil",            -- Cargo quality clamped to capsule's quality tier
        minimum_cargo = 2,                  -- Requires at least 1 full cargo stack + vessel slot
        full_stacks = true,                 -- Full stacks required
        consolidate_stacks = true,          -- Consolidate partial stacks into full stacks
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
        name = "biodegradable-capsule",
        type = "capsule",
        debug_color = { r = 0.2, g = 0.9, b = 0.2, a = 0.9 }, -- Emerald Green
        cargo_capacity = 1,                 -- Exactly 1 net cargo slot (2 bio items or 1 inorganic)
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        mixed_cargo = false,
        mixed_quantity = false,
        mixed_quality = "strict",
        quality_filter = "any",
        minimum_cargo = 2,
        full_stacks = false,
        consolidate_stacks = true,
        include_self = true,
        destroy_self = true,
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
        name = "refrigerated-capsule",
        type = "capsule",
        debug_color = { r = 0.2, g = 0.85, b = 1.0, a = 0.9 }, -- Frost Cyan
        cargo_capacity = 1,                 -- Exactly 1 net cargo slot
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        durability = 600,                   -- Base cooling charges (600s / 10 minutes of active refrigeration)
        bio_only = true,                    -- Biological items only
        mixed_cargo = true,
        mixed_quantity = false,
        mixed_quality = "any",
        quality_filter = "ceil",            -- Cargo quality clamped to capsule's quality tier
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
        name = "spent-refrigerated-capsule",
        type = "capsule",
        debug_color = { r = 0.6, g = 0.65, b = 0.7, a = 0.9 }, -- Slate Grey
        cargo_capacity = 1,                 -- Exactly 1 net cargo slot
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        bio_only = true,                    -- Biological items only
        mixed_cargo = true,
        mixed_quantity = false,
        mixed_quality = "any",
        quality_filter = "ceil",            -- Cargo quality clamped to capsule's quality tier
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
        name = "reinforced-capsule",
        type = "capsule",
        debug_color = { r = 0.8, g = 0.3, b = 1.0, a = 0.9 }, -- Violet Purple
        cargo_capacity = 2,                 -- Exactly 2 net cargo slots
        quality_affected_capacity = 2,      -- +2 cargo slots per quality tier
        mixed_cargo = false,                -- Strictly single item type
        mixed_quantity = false,
        mixed_quality = "strict",           -- Uniform quality tier across all cargo
        quality_filter = "any",
        minimum_cargo = "ceil",             -- Must fill ALL cargo slots completely to pack
        full_stacks = true,                 -- Full stacks required
        consolidate_stacks = true,          -- Consolidate partial stacks into full stacks
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
    ["electromagnetic-capsule"] = {
        name = "electromagnetic-capsule",
        type = "capsule",
        is_electromagnetic = true,
        debug_color = { r = 0.85, g = 0.35, b = 0.95, a = 0.9 }, -- Holmium Pink-Magenta
        cargo_capacity = 1,                 -- Exactly 1 base net cargo slot
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        mixed_cargo = true,                 -- Mix any item types
        mixed_quantity = true,              -- Fractional capacity scaled by item stack size
        mixed_quality = "any",              -- Mix any qualities
        quality_filter = "any",
        minimum_cargo = 1,                  -- Pack at least 1 item or partial stack
        full_stacks = false,                -- Partial stacks allowed
        consolidate_stacks = false,         -- No full stack restriction
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
    ["vacuum-capsule"] = {
        name = "vacuum-capsule",
        type = "capsule",
        debug_color = { r = 0.3, g = 0.5, b = 0.95, a = 0.9 }, -- Deep Vacuum Blue
        cargo_capacity = 1,                 -- Exactly 1 net cargo slot
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        siphon_belts = true,                -- Vacuum siphon belt extraction capability
        durability = 500,                   -- Base vacuum charges (500 items siphoned or deposited)
        mixed_cargo = true,
        mixed_quantity = false,
        mixed_quality = "any",
        quality_filter = "ceil",            -- Cargo quality clamped to capsule's quality tier
        minimum_cargo = 2,                  -- Requires at least 1 full cargo stack + vessel slot
        full_stacks = true,                 -- Full stacks required
        consolidate_stacks = true,          -- Consolidate partial stacks into full stacks
        include_self = true,
        destroy_self = false,
        spent_capsule_item = "spent-vacuum-capsule",
        destroy_holder_if_empty = true,
        holder_type = "invisible-capsule-holder",
        spill_contents = {
            units = true,
            mode = "container",
            container = "visible-capsule-holder",
            mark_for_deconstruction = true
        }
    },
    ["spent-vacuum-capsule"] = {
        name = "spent-vacuum-capsule",
        type = "capsule",
        debug_color = { r = 0.4, g = 0.45, b = 0.6, a = 0.9 }, -- Dim Vacuum Slate
        cargo_capacity = 1,                 -- Exactly 1 net cargo slot
        quality_affected_capacity = 1,      -- +1 cargo slot per quality tier
        mixed_cargo = true,
        mixed_quantity = false,
        mixed_quality = "any",
        quality_filter = "ceil",            -- Cargo quality clamped to capsule's quality tier
        minimum_cargo = 2,                  -- Requires at least 1 full cargo stack + vessel slot
        full_stacks = true,                 -- Full stacks required
        consolidate_stacks = true,          -- Consolidate partial stacks into full stacks
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
        name = "player-transit-capsule",
        type = "capsule",
        is_player_transit = true,
        debug_color = { r = 1.0, g = 0.4, b = 0.1, a = 0.9 }, -- Crimson Orange
        cargo_capacity = 0,                 -- Exactly 0 cargo slots
        quality_affected_capacity = 0,
        mixed_cargo = false,
        mixed_quantity = false,
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

local DEFAULT_DEBUG_COLOR = { r = 1.0, g = 0.84, b = 0.0, a = 0.9 }

--- Evaluates and returns the debug overlay color for a capsule type or definition
--- @param def_or_name string|table|nil
--- @return table color RGBA color table
function capsule_definitions.get_debug_color(def_or_name)
    if not def_or_name then return DEFAULT_DEBUG_COLOR end
    local def = type(def_or_name) == "table" and def_or_name or capsule_definitions.types[def_or_name]
    if def and def.debug_color then
        return def.debug_color
    end
    return DEFAULT_DEBUG_COLOR
end

--- Calculates quality-scaled maximum charges (durability) for a capsule
--- Uses standard Factorio quality scaling formula: base * (1 + 0.3 * quality_level)
--- @param def_or_name string|table|nil
--- @param quality_arg string|table|LuaQualityPrototype|nil
--- @return number max_charges
function capsule_definitions.get_max_charges(def_or_name, quality_arg)
    if not def_or_name then return 600 end
    local def = type(def_or_name) == "table" and def_or_name or capsule_definitions.types[def_or_name]
    if not def then return 600 end

    local base_durability = def.durability or 600

    local level = 0
    if quality_arg then
        if type(quality_arg) == "table" or type(quality_arg) == "userdata" then
            level = quality_arg.level or 0
        elseif type(quality_arg) == "string" then
            local q_proto = prototypes.quality[quality_arg]
            if q_proto then
                level = q_proto.level or 0
            end
        end
    end

    return math.floor(base_durability * (1 + 0.3 * level) + 0.5)
end

return capsule_definitions