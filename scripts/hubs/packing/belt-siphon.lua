local port_defs = require("scripts.flow.port-defs")
local capsule_defs = require("scripts.capsules.capsule-definitions")
local item_transfer_handler = require("scripts.utils.item-transfer-handler")

local belt_siphon = {}

local BELT_TYPES = {
    ["transport-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
    ["linked-belt"] = true
}

local BELT_SEARCH_TYPES = {
    "transport-belt",
    "underground-belt",
    "splitter",
    "linked-belt"
}

--- Helper print to output debug messages to console
local function log_debug(msg)
    if debug_print then
        debug_print(msg)
    else
        game.print(msg)
    end
end

--- Calculates the net pneumatic pressure across all ports on the Hub
--- @param hub_entity LuaEntity
--- @return number net_pressure Total sum of pressure levels (-10 to +10) across connected ports
local function get_hub_net_pressure(hub_entity)
    if not (hub_entity and hub_entity.valid and hub_entity.unit_number) then return 0 end
    local ports = storage.flow_unit_ports and storage.flow_unit_ports[hub_entity.unit_number]
    if not ports then return 0 end

    local net = 0
    for i = 1, #ports do
        local pkey = ports[i]
        local level = storage.flow_levels and storage.flow_levels[pkey] or 0
        net = net + level
    end
    return net
end

--- Checks if a belt entity is strictly orthogonally adjacent to the Hub's container walls
--- Eliminates diagonal corners and belts extending past the Hub's footprint (e.g. next to attached tubes).
--- @param hub_entity LuaEntity
--- @param belt LuaEntity
--- @return boolean
local function is_strictly_adjacent(hub_entity, belt)
    local hub_bb = hub_entity.bounding_box
    local belt_bb = belt.bounding_box

    -- Check West/East wall adjacency:
    -- Belt must touch the West or East edge in X, AND must project into the Hub's Y span
    local touches_west = (belt_bb.right_bottom.x >= hub_bb.left_top.x - 0.3) and (belt_bb.left_top.x < hub_bb.left_top.x)
    local touches_east = (belt_bb.left_top.x <= hub_bb.right_bottom.x + 0.3) and (belt_bb.right_bottom.x > hub_bb.right_bottom.x)
    local overlaps_y = (belt_bb.right_bottom.y > hub_bb.left_top.y + 0.1) and (belt_bb.left_top.y < hub_bb.right_bottom.y - 0.1)

    if (touches_west or touches_east) and overlaps_y then
        return true
    end

    -- Check North/South wall adjacency:
    -- Belt must touch the North or South edge in Y, AND must project into the Hub's X span
    local touches_north = (belt_bb.right_bottom.y >= hub_bb.left_top.y - 0.3) and (belt_bb.left_top.y < hub_bb.left_top.y)
    local touches_south = (belt_bb.left_top.y <= hub_bb.right_bottom.y + 0.3) and (belt_bb.right_bottom.y > hub_bb.right_bottom.y)
    local overlaps_x = (belt_bb.right_bottom.x > hub_bb.left_top.x + 0.1) and (belt_bb.left_top.x < hub_bb.right_bottom.x - 0.1)

    if (touches_north or touches_south) and overlaps_x then
        return true
    end

    return false
end

--- Finds deduplicated belt entities touching any side of the Hub's bounding box
--- @param hub_entity LuaEntity
--- @return table Array of valid LuaEntity belt structures
function belt_siphon.find_adjacent_belts(hub_entity)
    if not (hub_entity and hub_entity.valid) then return {} end

    local surface = hub_entity.surface
    local bb = hub_entity.bounding_box
    local search_area = {
        { bb.left_top.x - 0.6, bb.left_top.y - 0.6 },
        { bb.right_bottom.x + 0.6, bb.right_bottom.y + 0.6 }
    }

    local entities = surface.find_entities_filtered{
        area = search_area,
        type = BELT_SEARCH_TYPES
    }
    local found_belts = {}
    local seen_units = {}

    for _, entity in ipairs(entities) do
        if entity and entity.valid and BELT_TYPES[entity.type] and entity ~= hub_entity then
            if is_strictly_adjacent(hub_entity, entity) then
                local unit_num = entity.unit_number or (entity.position.x .. "," .. entity.position.y)
                if not seen_units[unit_num] then
                    seen_units[unit_num] = true
                    table.insert(found_belts, entity)
                end
            end
        end
    end

    return found_belts
end

--- Determines which transport line indices the Hub should deposit onto.
--- For parallel passing belts, only the near lane touching the hub wall is sideloaded.
--- For outbound belts pointing straight away, all lines are available.
--- @param hub_entity LuaEntity
--- @param belt LuaEntity
--- @return table line_indices Array of transport line numbers to deposit onto
local function get_deposit_line_indices(hub_entity, belt)
    local max_lines = belt.get_max_transport_line_index() or 0
    if max_lines <= 1 then
        return { 1 }
    end

    local bb = hub_entity.bounding_box
    local bx, by = belt.position.x, belt.position.y
    local bdir = belt.direction

    -- Belt is on the West of the hub (Hub is to its East)
    if bx < bb.left_top.x then
        if bdir == defines.direction.north then
            return { 2 } -- Right line is East (near lane)
        elseif bdir == defines.direction.south then
            return { 1 } -- Left line is East (near lane)
        end
    -- Belt is on the East of the hub (Hub is to its West)
    elseif bx > bb.right_bottom.x then
        if bdir == defines.direction.north then
            return { 1 } -- Left line is West (near lane)
        elseif bdir == defines.direction.south then
            return { 2 } -- Right line is West (near lane)
        end
    end

    -- Belt is on the North of the hub (Hub is to its South)
    if by < bb.left_top.y then
        if bdir == defines.direction.east then
            return { 2 } -- Right line is South (near lane)
        elseif bdir == defines.direction.west then
            return { 1 } -- Left line is South (near lane)
        end
    -- Belt is on the South of the hub (Hub is to its North)
    elseif by > bb.right_bottom.y then
        if bdir == defines.direction.east then
            return { 1 } -- Left line is North (near lane)
        elseif bdir == defines.direction.west then
            return { 2 } -- Right line is North (near lane)
        end
    end

    -- Outbound head-on or multi-line entities (e.g. splitters): use all lines
    local all_lines = {}
    for i = 1, max_lines do
        all_lines[i] = i
    end
    return all_lines
end

--- Converts a depleted capsule item in the chest into a spent capsule shell
--- @param chest_inv LuaInventory
--- @param capsule_slot number
--- @param capsule_stack LuaItemStack
--- @param capsule_def table
--- @param hub_entity LuaEntity
local function convert_to_spent(chest_inv, capsule_slot, capsule_stack, capsule_def, hub_entity)
    local spent_name = capsule_def.spent_capsule_item or "spent-vacuum-capsule"
    local q_obj = capsule_stack.quality
    local src_grid = capsule_stack.grid

    chest_inv[capsule_slot].set_stack({
        name = spent_name,
        count = 1,
        quality = q_obj
    })
    if src_grid and src_grid.valid and chest_inv[capsule_slot].valid_for_read then
        item_transfer_handler.copy_equipment_grid(src_grid, chest_inv[capsule_slot])
    end
end

--- Siphons available items directly off adjacent transport belts into the Hub chest inventory
--- Deducts 1 charge point per siphoned item via stack.health.
--- @param hub_entity LuaEntity
--- @param chest_inv LuaInventory
--- @param capsule_slot number
--- @param capsule_stack LuaItemStack
--- @param capsule_def table
--- @param cur_charges number
--- @param max_charges number
--- @param belts table
--- @return boolean items_siphoned
local function siphon_from_belts(hub_entity, chest_inv, capsule_slot, capsule_stack, capsule_def, cur_charges, max_charges, belts)
    local any_siphoned = false

    for _, belt in ipairs(belts) do
        if belt and belt.valid then
            local max_lines = belt.get_max_transport_line_index() or 0
            for line_idx = 1, max_lines do
                local line = belt.get_transport_line(line_idx)
                if line and line.valid and #line > 0 then
                    local contents = line.get_contents()
                    if contents and #contents > 0 then
                        for _, entry in ipairs(contents) do
                            local item_name = entry.name
                            local item_q_name = entry.quality or "normal"
                            local item_count = entry.count or 1

                            if item_name and item_count > 0 then
                                local proto = prototypes.item[item_name]
                                local stack_size = proto and proto.stack_size or 50
                                local max_take = math.min(item_count, stack_size, cur_charges)

                                if max_take > 0 then
                                    local stack_spec = {
                                        name = item_name,
                                        count = max_take,
                                        quality = item_q_name
                                    }

                                    if chest_inv.can_insert(stack_spec) then
                                        local removed = line.remove_item({
                                            name = item_name,
                                            count = max_take,
                                            quality = item_q_name
                                        })

                                        if removed and removed > 0 then
                                            chest_inv.insert({
                                                name = item_name,
                                                count = removed,
                                                quality = item_q_name
                                            })
                                            log_debug("[BeltSiphon] Siphoned " .. tostring(removed) .. " of " .. tostring(item_name) .. " off belt into Hub #" .. tostring(hub_entity.unit_number))
                                            any_siphoned = true

                                            local new_charges = cur_charges - removed
                                            if new_charges <= 0 then
                                                convert_to_spent(chest_inv, capsule_slot, capsule_stack, capsule_def, hub_entity)
                                                return any_siphoned
                                            else
                                                capsule_stack.health = math.max(0.01, new_charges / max_charges)
                                                cur_charges = new_charges
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return any_siphoned
end

--- Finds an eligible item slot in the chest to deposit onto belts
--- Prioritizes regular cargo and uncharged/spent vacuum capsules first (Tier 1).
--- Only selects secondary charged vacuum capsules if no Tier 1 items remain (Tier 2).
--- The active working capsule in active_slot can never push itself out.
--- @param chest_inv LuaInventory
--- @param active_slot number
--- @return number|nil candidate_slot
local function find_deposit_candidate_slot(chest_inv, active_slot)
    local tier2_slot = nil

    for i = 1, #chest_inv do
        if i ~= active_slot then
            local stack = chest_inv[i]
            if stack and stack.valid_for_read then
                local def = capsule_defs.types[stack.name]
                local is_charged_vacuum = def and def.siphon_belts and ((stack.health or 1.0) > 0.001)

                if not is_charged_vacuum then
                    return i -- Tier 1: regular cargo or spent/inert shell
                elseif not tier2_slot then
                    tier2_slot = i -- Tier 2: secondary charged capsule
                end
            end
        end
    end

    return tier2_slot
end

--- Deposits eligible cargo items from the Hub chest onto adjacent transport belts.
--- Respects sideloading: only inserts into the near lane on parallel passing belts.
--- Respects Gleba belt stacking research: creates stacks up to force.belt_stack_size_bonus + 1.
--- Deducts 1 charge point per item deposited via stack.health.
--- @param hub_entity LuaEntity
--- @param chest_inv LuaInventory
--- @param capsule_slot number
--- @param capsule_stack LuaItemStack
--- @param capsule_def table
--- @param cur_charges number
--- @param max_charges number
--- @param belts table
--- @return boolean items_deposited
local function deposit_to_belts(hub_entity, chest_inv, capsule_slot, capsule_stack, capsule_def, cur_charges, max_charges, belts)
    local any_deposited = false

    local force = hub_entity.force
    local stack_bonus = (force and force.belt_stack_size_bonus) or 0
    local max_belt_stack = 1 + stack_bonus

    for _, belt in ipairs(belts) do
        if belt and belt.valid then
            local target_lines = get_deposit_line_indices(hub_entity, belt)
            for _, line_idx in ipairs(target_lines) do
                local line = belt.get_transport_line(line_idx)
                while line and line.valid and line.can_insert_at_back() and cur_charges > 0 do
                    local cand_slot = find_deposit_candidate_slot(chest_inv, capsule_slot)
                    if not cand_slot then
                        return any_deposited
                    end

                    local cand_stack = chest_inv[cand_slot]
                    if not (cand_stack and cand_stack.valid_for_read) then
                        break
                    end

                    local item_name = cand_stack.name
                    local item_quality = cand_stack.quality
                    local item_spoil = cand_stack.spoil_percent

                    local proto = prototypes.item[item_name]
                    local item_can_stack = proto and (proto.stack_size > 1)
                    local allowed_stack = item_can_stack and max_belt_stack or 1

                    local drop_count = math.min(cand_stack.count, allowed_stack, cur_charges)
                    if drop_count <= 0 then break end

                    local spec = {
                        name = item_name,
                        count = drop_count,
                        quality = item_quality
                    }
                    if item_spoil then
                        spec.spoil_percent = item_spoil
                    end

                    local inserted = line.insert_at_back(spec, allowed_stack)
                    if inserted then
                        any_deposited = true
                        cand_stack.count = cand_stack.count - drop_count

                        cur_charges = cur_charges - drop_count
                        if cur_charges <= 0 then
                            convert_to_spent(chest_inv, capsule_slot, capsule_stack, capsule_def, hub_entity)
                            return any_deposited
                        else
                            capsule_stack.health = math.max(0.01, cur_charges / max_charges)
                        end
                    else
                        break
                    end
                end

                if cur_charges <= 0 then
                    return any_deposited
                end
            end
        end
    end

    return any_deposited
end

--- Primary hub belt processing entry point
--- Evaluates net tube pressure:
---   Net < 0 (Suction): Siphons items off belts into Hub chest.
---   Net > 0 (Blowing): Deposits items from Hub chest onto belts.
---   Net == 0 (Neutral / Disconnected): Inactive.
--- @param hub_entity LuaEntity
--- @return boolean activity_performed
function belt_siphon.process_belts(hub_entity)
    if not (hub_entity and hub_entity.valid) then return false end

    -- Early exit 1: Check net tube pressure. Neutral/zero pressure means idle.
    local net_pressure = get_hub_net_pressure(hub_entity)
    if net_pressure == 0 then
        return false
    end

    local chest_inv = hub_entity.get_inventory(defines.inventory.chest)
    if not (chest_inv and chest_inv.valid and not chest_inv.is_empty()) then return false end

    local capsule_slot = nil
    local capsule_stack = nil
    local capsule_def = nil

    -- Fast native lookup for vacuum capsule stack
    local fast_stack, fast_slot = chest_inv.find_item_stack("vacuum-capsule")
    if fast_stack and fast_stack.valid_for_read then
        local def = capsule_defs.types[fast_stack.name]
        if def and def.siphon_belts then
            capsule_slot = fast_slot
            capsule_stack = fast_stack
            capsule_def = def
        end
    end

    -- Fallback scan if not found via fast path (supports other siphon-capable capsules)
    if not capsule_slot then
        for i = 1, #chest_inv do
            local stack = chest_inv[i]
            if stack and stack.valid_for_read then
                local def = capsule_defs.types[stack.name]
                if def and def.siphon_belts then
                    capsule_slot = i
                    capsule_stack = stack
                    capsule_def = def
                    break
                end
            end
        end
    end

    if not (capsule_slot and capsule_stack and capsule_stack.valid_for_read) then return false end

    local cur_health = capsule_stack.health or 1.0
    if cur_health <= 0.001 then
        convert_to_spent(chest_inv, capsule_slot, capsule_stack, capsule_def, hub_entity)
        return false
    end

    local max_charges = capsule_defs.get_max_charges(capsule_def, capsule_stack.quality)
    local cur_charges = math.floor((cur_health * max_charges) + 0.5)
    if cur_charges <= 0 then
        convert_to_spent(chest_inv, capsule_slot, capsule_stack, capsule_def, hub_entity)
        return false
    end

    local belts = belt_siphon.find_adjacent_belts(hub_entity)
    if #belts == 0 then return false end

    if net_pressure < 0 then
        return siphon_from_belts(hub_entity, chest_inv, capsule_slot, capsule_stack, capsule_def, cur_charges, max_charges, belts)
    else
        return deposit_to_belts(hub_entity, chest_inv, capsule_slot, capsule_stack, capsule_def, cur_charges, max_charges, belts)
    end
end

-- Backward compatibility alias
belt_siphon.siphon_to_chest = belt_siphon.process_belts

return belt_siphon