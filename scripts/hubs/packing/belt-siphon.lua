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

--- Helper print to output debug messages to console
local function log_debug(msg)
    if debug_print then
        debug_print(msg)
    else
        game.print(msg)
    end
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

    local entities = surface.find_entities_filtered{ area = search_area }
    local found_belts = {}
    local seen_units = {}

    for _, entity in ipairs(entities) do
        if entity and entity.valid and BELT_TYPES[entity.type] and entity ~= hub_entity then
            local unit_num = entity.unit_number or (entity.position.x .. "," .. entity.position.y)
            if not seen_units[unit_num] then
                seen_units[unit_num] = true
                table.insert(found_belts, entity)
            end
        end
    end

    return found_belts
end

--- Siphons available items directly off adjacent transport belts into the Hub chest inventory
--- Deducts exactly 1 durability point per individual item siphoned off belts.
--- @param hub_entity LuaEntity
--- @return boolean items_siphoned
function belt_siphon.siphon_to_chest(hub_entity)
    if not (hub_entity and hub_entity.valid) then return false end

    local chest_inv = hub_entity.get_inventory(defines.inventory.chest)
    if not (chest_inv and chest_inv.valid) then return false end

    -- Find a valid tool capsule with siphon_belts enabled in chest_inv
    local capsule_slot = nil
    local capsule_stack = nil
    local capsule_def = nil

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

    if not (capsule_slot and capsule_stack and capsule_stack.is_tool) then return false end

    local cur_dur = capsule_stack.durability or (capsule_stack.prototype and capsule_stack.prototype.durability) or 100
    if cur_dur <= 0 then return false end

    local belts = belt_siphon.find_adjacent_belts(hub_entity)
    if #belts == 0 then return false end

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

                                -- Limit extraction quantity by item availability, stack size, AND remaining tool durability
                                local max_take = math.min(item_count, stack_size, math.floor(cur_dur))

                                if max_take > 0 then
                                    local stack_spec = {
                                        name = item_name,
                                        count = max_take,
                                        quality = item_q_name
                                    }

                                    -- Native Factorio C++ engine evaluation handles slot filters, bar limits, and slot availability
                                    if chest_inv.can_insert(stack_spec) then
                                        local removed = line.remove_item({
                                            name = item_name,
                                            count = max_take,
                                            quality = item_q_name
                                        })

                                        if removed and removed > 0 then
                                            local inserted = chest_inv.insert({
                                                name = item_name,
                                                count = removed,
                                                quality = item_q_name
                                            })
                                            log_debug("[BeltSiphon] Siphoned " .. tostring(inserted) .. " of " .. tostring(item_name) .. " off belt into Hub #" .. tostring(hub_entity.unit_number) .. " chest")
                                            any_siphoned = true

                                            -- Deduct exactly 1 durability point per individual siphoned item
                                            local new_dur = cur_dur - removed

                                            if new_dur <= 0 then
                                                -- Charge exhausted: convert tool stack in chest directly to spent capsule item
                                                local spent_name = capsule_def.spent_capsule_item or "spent-vacuum-capsule"
                                                local q_obj = capsule_stack.quality
                                                local src_grid = capsule_stack.grid

                                                if capsule_stack.count > 1 then
                                                    capsule_stack.count = capsule_stack.count - 1
                                                    chest_inv.insert({
                                                        name = spent_name,
                                                        count = 1,
                                                        quality = q_obj
                                                    })
                                                else
                                                    chest_inv[capsule_slot].set_stack({
                                                        name = spent_name,
                                                        count = 1,
                                                        quality = q_obj
                                                    })
                                                    if src_grid and src_grid.valid and chest_inv[capsule_slot].valid_for_read then
                                                        item_transfer_handler.copy_equipment_grid(src_grid, chest_inv[capsule_slot])
                                                    end
                                                end
                                                return any_siphoned
                                            else
                                                capsule_stack.durability = new_dur
                                                cur_dur = new_dur
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

return belt_siphon