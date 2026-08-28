local port_defs = require("scripts.ports.port-definitions")
local compat_defs = require("scripts.ports.port-compatibility-definitions")

local port_evaluator = {}

local function check_pair(allowed_list, value_a, value_b)
    for _, entry in ipairs(allowed_list) do
        local pair = entry.pair or entry
        if (pair[1] == value_a and pair[2] == value_b) or 
           (pair[1] == value_b and pair[2] == value_a) then
            return true, entry.outcome
        end
    end
    return false, nil
end

--- Evaluates compatibility between two entity ports by index
-- @param entity_a LuaEntity
-- @param port_a_index number
-- @param entity_b LuaEntity
-- @param port_b_index number
-- @return boolean, string|nil (is_compatible, resolved_outcome)
function port_evaluator.are_compatible(entity_a, port_a_index, entity_b, port_b_index)
    local ports_a = port_defs.get_ports(entity_a)
    local ports_b = port_defs.get_ports(entity_b)

    if not (ports_a and ports_b) then return false end

    local port_a = ports_a[port_a_index]
    local port_b = ports_b[port_b_index]

    if not (port_a and port_b) then return false end

    -- Active state check: closed/disabled ports reject connection
    if port_a.enabled == false or port_b.enabled == false then
        return false
    end

    -- Flow check
    local flow_valid = check_pair(compat_defs.flows, port_a.flow, port_b.flow)
    if not flow_valid then
        return false
    end

    -- Connection type check
    local connection_valid, outcome = check_pair(compat_defs.connections, port_a.connection, port_b.connection)
    if not connection_valid then
        return false
    end

    return true, outcome
end

return port_evaluator