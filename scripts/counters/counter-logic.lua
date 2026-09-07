local counter_settings = require("scripts.counters.counter-settings")
local counter_range = require("scripts.counters.counter-range")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")

local counter_logic = {}

--- Updates circuit proxy signals for a pneumatic capsule counter based on owned segment range and settings
--- @param counter_entity LuaEntity
function counter_logic.update_signals(counter_entity)
    if not (counter_entity and counter_entity.valid) then return end

    local proxy = counter_settings.get_proxy(counter_entity)
    if not (proxy and proxy.valid) then return end

    local cb = proxy.get_control_behavior()
    if not cb then return end

    local section = cb.get_section(1) or cb.add_section()
    if not section then return end

    if counter_entity.energy == 0 then
        section.filters = {}
        return
    end

    local unit_number = counter_entity.unit_number
    if not unit_number then return end

    local settings = counter_settings.get(unit_number)
    local vessels_target = settings and settings.vessels_target or "green"
    local cargo_target = settings and settings.cargo_target or "red"
    local total_target = settings and settings.total_target or "green"
    local total_signal = settings and settings.total_signal or { type = "virtual", name = "signal-C" }

    if vessels_target == "off" and cargo_target == "off" and total_target == "off" then
        section.filters = {}
        return
    end

    local owned_nodes = counter_range.get_owned_nodes(unit_number)
    if not owned_nodes or next(owned_nodes) == nil then
        section.filters = {}
        return
    end

    local owned_units = {}
    for key in pairs(owned_nodes) do
        local u_num = type(key) == "number" and key or capsule_queries.get_port_info(key)
        if u_num then
            owned_units[u_num] = true
        end
    end

    local scanned_capsules = {}
    local total_capsules_count = 0
    local signal_totals = {}

    local function add_signal(sig_type, sig_name, sig_quality, amount)
        if not (sig_name and amount and amount > 0) then return end
        sig_type = sig_type or "item"
        sig_quality = sig_quality or "normal"
        local k = sig_type .. ":" .. sig_name .. ":" .. sig_quality
        local entry = signal_totals[k]
        if not entry then
            entry = {
                type = sig_type,
                name = sig_name,
                quality = sig_quality,
                count = 0
            }
            signal_totals[k] = entry
        end
        entry.count = entry.count + amount
    end

    for tube_unit in pairs(owned_units) do
        local cap_ids = capsule_queries.find_capsules_at_entity(tube_unit)
        for _, cap_id in ipairs(cap_ids) do
            if not scanned_capsules[cap_id] then
                scanned_capsules[cap_id] = true
                local cap_data = capsule_manager.get(cap_id)
                if cap_data then
                    total_capsules_count = total_capsules_count + 1

                    if vessels_target ~= "off" then
                        local primary_stack, primary_slot = capsule_manager.get_primary_stack(cap_id)
                        local v_name, v_qual
                        if primary_stack and primary_stack.valid_for_read then
                            v_name = primary_stack.name
                            v_qual = primary_stack.quality and primary_stack.quality.name or "normal"
                        else
                            v_name = cap_data.definition and cap_data.definition.name or "item-capsule"
                            v_qual = cap_data.dominant_quality or "normal"
                        end
                        add_signal("item", v_name, v_qual, 1)
                    end

                    if cargo_target ~= "off" and cap_data.holder and cap_data.holder.valid then
                        local inv = cap_data.holder.get_inventory(defines.inventory.chest)
                        if inv and inv.valid and not inv.is_empty() then
                            local prim_slot = cap_data.primary_slot or 1
                            for slot_idx = 1, #inv do
                                if slot_idx ~= prim_slot then
                                    local stack = inv[slot_idx]
                                    if stack and stack.valid_for_read then
                                        local item_qual = stack.quality and stack.quality.name or "normal"
                                        add_signal("item", stack.name, item_qual, stack.count)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if total_target ~= "off" and total_capsules_count > 0 and total_signal and total_signal.name then
        add_signal(total_signal.type or "virtual", total_signal.name, "normal", total_capsules_count)
    end

    local filters = {}
    for _, entry in pairs(signal_totals) do
        table.insert(filters, {
            value = {
                type = entry.type,
                name = entry.name,
                quality = entry.quality
            },
            min = entry.count
        })
    end

    section.filters = filters
end

return counter_logic