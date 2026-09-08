local port_defs = require("scripts.flow.port-defs")

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

--- Checks if an item is allowed by the hub inventory's slot filters (if any are configured)
--- @param inventory LuaInventory
--- @param item_name string
--- @return boolean
local function passes_hub_filters(inventory, item_name)
    if not (inventory and inventory.valid and inventory.is_filtered and inventory.is_filtered()) then
        return true
    end
    for i = 1, #inventory do
        local filter = inventory.get_filter(i)
        if filter == item_name then
            return true
        end
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
--- @param hub_entity LuaEntity
--- @return boolean items_siphoned
function belt_siphon.siphon_to_chest(hub_entity)
    if not (hub_entity and hub_entity.valid) then return false end

    local chest_inv = hub_entity.get_inventory(defines.inventory.chest)
    if not (chest_inv and chest_inv.valid) then return false end

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

                            if item_name and item_count > 0 and passes_hub_filters(chest_inv, item_name) then
                                local stack_spec = {
                                    name = item_name,
                                    count = item_count,
                                    quality = item_q_name
                                }

                                if chest_inv.can_insert(stack_spec) then
                                    local proto = prototypes.item[item_name]
                                    local stack_size = proto and proto.stack_size or 50
                                    local take_amount = math.min(item_count, stack_size)

                                    local removed = line.remove_item({
                                        name = item_name,
                                        count = take_amount,
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