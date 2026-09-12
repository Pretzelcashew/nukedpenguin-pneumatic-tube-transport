local counter_settings = require("scripts.counters.counter-settings")
local counter_range = require("scripts.counters.counter-range")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")

local counter_logic = {}

--- Updates circuit proxy signals for a pneumatic capsule counter based on owned segment range and settings
--- @param counter_entity LuaEntity
function counter_logic.update_signals(counter_entity)
    if not (counter_entity and counter_entity.valid) then return end

    local main_proxy, red_proxy, green_proxy = counter_settings.get_channel_proxies(counter_entity)

    local function apply_filters_to_proxy(proxy_ent, filters)
        if proxy_ent and proxy_ent.valid then
            local cb = proxy_ent.get_control_behavior()
            if cb then
                local section = cb.get_section(1) or cb.add_section()
                if section then
                    section.filters = filters
                end
            end
        end
    end

    if counter_entity.energy == 0 then
        apply_filters_to_proxy(main_proxy, {})
        apply_filters_to_proxy(red_proxy, {})
        apply_filters_to_proxy(green_proxy, {})
        return
    end

    local unit_number = counter_entity.unit_number
    if not unit_number then return end

    local settings = counter_settings.get(unit_number)
    local vessels_target = settings and settings.vessels_target or "green"
    local cargo_target = settings and settings.cargo_target or "red"
    local total_target = settings and settings.total_target or "green"
    local total_signal = settings and settings.total_signal

    if vessels_target == "off" and cargo_target == "off" and total_target == "off" then
        apply_filters_to_proxy(main_proxy, {})
        apply_filters_to_proxy(red_proxy, {})
        apply_filters_to_proxy(green_proxy, {})
        return
    end

    local owned_nodes = counter_range.get_owned_nodes(unit_number)
    if not owned_nodes or next(owned_nodes) == nil then
        apply_filters_to_proxy(main_proxy, {})
        apply_filters_to_proxy(red_proxy, {})
        apply_filters_to_proxy(green_proxy, {})
        return
    end

    local stable_summary = counter_range.get_stable_summary(unit_number)
    local dynamic_capsules = counter_range.get_dynamic_capsules(unit_number)
    local has_stable = stable_summary and (stable_summary.capsule_count or 0) > 0
    local has_dynamic = dynamic_capsules and next(dynamic_capsules) ~= nil

    if not has_stable and not has_dynamic then
        apply_filters_to_proxy(main_proxy, {})
        apply_filters_to_proxy(red_proxy, {})
        apply_filters_to_proxy(green_proxy, {})
        return
    end

    local total_capsules_count = stable_summary and stable_summary.capsule_count or 0
    local red_signal_totals = {}
    local green_signal_totals = {}

    local function add_channel_signal(totals_map, sig_type, sig_name, sig_quality, amount)
        if not (sig_name and amount and amount > 0) then return end
        sig_type = sig_type or "item"
        sig_quality = sig_quality or "normal"
        local k = sig_type .. ":" .. sig_name .. ":" .. sig_quality
        local entry = totals_map[k]
        if not entry then
            entry = {
                type = sig_type,
                name = sig_name,
                quality = sig_quality,
                count = 0
            }
            totals_map[k] = entry
        end
        entry.count = entry.count + amount
    end

    if has_stable then
        if vessels_target ~= "off" and stable_summary.vessels then
            for _, v in pairs(stable_summary.vessels) do
                if vessels_target == "red" or vessels_target == "both" then
                    add_channel_signal(red_signal_totals, "item", v.name, v.quality, v.count)
                end
                if vessels_target == "green" or vessels_target == "both" then
                    add_channel_signal(green_signal_totals, "item", v.name, v.quality, v.count)
                end
            end
        end

        if cargo_target ~= "off" and stable_summary.cargo then
            for _, c in pairs(stable_summary.cargo) do
                if cargo_target == "red" or cargo_target == "both" then
                    add_channel_signal(red_signal_totals, "item", c.name, c.quality, c.count)
                end
                if cargo_target == "green" or cargo_target == "both" then
                    add_channel_signal(green_signal_totals, "item", c.name, c.quality, c.count)
                end
            end
        end
    end

    if has_dynamic then
        for cap_id in pairs(dynamic_capsules) do
        local cap = storage.capsules and storage.capsules[cap_id]
        if cap then
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
                        if vessels_target == "red" or vessels_target == "both" then
                            add_channel_signal(red_signal_totals, "item", v_name, v_qual, 1)
                        end
                        if vessels_target == "green" or vessels_target == "both" then
                            add_channel_signal(green_signal_totals, "item", v_name, v_qual, 1)
                        end
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
                                        if cargo_target == "red" or cargo_target == "both" then
                                            add_channel_signal(red_signal_totals, "item", stack.name, item_qual, stack.count)
                                        end
                                        if cargo_target == "green" or cargo_target == "both" then
                                            add_channel_signal(green_signal_totals, "item", stack.name, item_qual, stack.count)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            else
                dynamic_capsules[cap_id] = nil
            end
        end
    end

    if total_target ~= "off" and total_capsules_count > 0 and total_signal then
        local stype, sname, squal
        if type(total_signal) == "string" then
            stype = "virtual"
            sname = total_signal
            squal = "normal"
        elseif type(total_signal) == "table" and total_signal.name then
            stype = total_signal.type or "virtual"
            sname = total_signal.name
            squal = total_signal.quality or "normal"
        end

        if sname then
            if total_target == "red" or total_target == "both" then
                add_channel_signal(red_signal_totals, stype, sname, squal, total_capsules_count)
            end
            if total_target == "green" or total_target == "both" then
                add_channel_signal(green_signal_totals, stype, sname, squal, total_capsules_count)
            end
        end
    end

    local function build_filters(totals_map)
        local filters = {}
        for _, entry in pairs(totals_map) do
            table.insert(filters, {
                value = {
                    type = entry.type,
                    name = entry.name,
                    quality = entry.quality
                },
                min = entry.count
            })
        end
        return filters
    end

    -- Main terminal proxy output filters are kept empty (acts purely as wire terminal)
    apply_filters_to_proxy(main_proxy, {})

    -- Red and Green channel proxies output their channel-isolated signal filters
    apply_filters_to_proxy(red_proxy, build_filters(red_signal_totals))
    apply_filters_to_proxy(green_proxy, build_filters(green_signal_totals))
end

return counter_logic