-- scripts/ports/port-evaluator.lua
local port_defs = require("scripts.ports.port-definitions")
local compat_defs = require("scripts.ports.port-compatibility-definitions")

local port_evaluator = {}

local function is_valid_pair(allowed_list, value_a, value_b)
    for _, pair in ipairs(allowed_list) do
        if (pair[1] == value_a and pair[2] == value_b) or 
           (pair[1] == value_b and pair[2] == value_a) then
            return true
        end
    end
    return false
end

--- Evaluates compatibility between two entity ports by index
-- @param entity_a LuaEntity
-- @param port_a_index number
-- @param entity_b LuaEntity
-- @param port_b_index number
-- @return boolean
function port_evaluator.are_compatible(entity_a, port_a_index, entity_b, port_b_index)
    local ports_a = port_defs.get_ports(entity_a)
    local ports_b = port_defs.get_ports(entity_b)

    if not (ports_a and ports_b) then return false end

    local port_a = ports_a[port_a_index]
    local port_b = ports_b[port_b_index]

    if not (port_a and port_b) then return false end

    -- Group check
    if port_a.group ~= port_b.group then
        return false
    end

    -- Flow check
    if not is_valid_pair(compat_defs.flows, port_a.flow, port_b.flow) then
        return false
    end

    -- Connection type check
    if not is_valid_pair(compat_defs.connections, port_a.connection, port_b.connection) then
        return false
    end

    return true
end

return port_evaluator