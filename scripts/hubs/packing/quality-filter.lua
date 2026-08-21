-- FILE: scripts/hubs/packing/quality-filter.lua
local quality_filter = {}

quality_filter.QUALITY_LEVELS = {
    ["normal"] = 0,
    ["uncommon"] = 1,
    ["rare"] = 2,
    ["epic"] = 3,
    ["legendary"] = 4
}

local function evaluate_single_rule(item_q_name, item_q_level, vessel_q_level, rule_str)
    rule_str = rule_str:lower():match("^%s*(.-)%s*$")
    if rule_str == "" or rule_str == "any" or rule_str == "*" then
        return true, false
    end

    if rule_str == "ceil" then
        return (item_q_level <= vessel_q_level), false
    end

    local op, target_str = rule_str:match("^(>=|<=|>|<|!=|=?%!?)(.+)$")
    if not op or not target_str then
        op = "="
        target_str = rule_str
    end

    target_str = target_str:match("^%s*(.-)%s*$")
    local target_level = quality_filter.QUALITY_LEVELS[target_str] or tonumber(target_str) or 0

    if op == ">=" then
        return (item_q_level >= target_level), false
    elseif op == "<=" then
        return (item_q_level <= target_level), false
    elseif op == ">" then
        return (item_q_level > target_level), false
    elseif op == "<" then
        return (item_q_level < target_level), false
    elseif op == "!=" or op == "!" then
        return (item_q_level == target_level or item_q_name == target_str), true
    elseif op == "=" or op == "" then
        return (item_q_level == target_level or item_q_name == target_str), false
    end

    return true, false
end

function quality_filter.is_quality_allowed(item_q_name, item_q_level, vessel_q_level, filter_config)
    if not filter_config then return true end

    if type(filter_config) == "string" then
        local pass, is_blacklist = evaluate_single_rule(item_q_name, item_q_level, vessel_q_level, filter_config)
        return is_blacklist and not pass or (not is_blacklist and pass)
    elseif type(filter_config) == "table" then
        local has_whitelist = false
        local whitelist_passed = false

        for _, rule in ipairs(filter_config) do
            local pass, is_blacklist = evaluate_single_rule(item_q_name, item_q_level, vessel_q_level, tostring(rule))
            if is_blacklist then
                if pass then return false end
            else
                has_whitelist = true
                if pass then whitelist_passed = true end
            end
        end

        if has_whitelist then
            return whitelist_passed
        end
        return true
    end

    return true
end

return quality_filter