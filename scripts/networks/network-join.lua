-- scripts/networks/network-join.lua
local networks = require("scripts.networks.networks")

local network_join = {}

-- Track which network ID each (unit_number..":"..port_index) belongs to
local port_to_network = {}

local function get_port_key(unit_number, port_index)
    return unit_number .. ":" .. port_index
end

--- Handles joining ports into networks without merging distinct network IDs
-- @param entity_a LuaEntity
-- @param port_a_index number
-- @param entity_b LuaEntity
-- @param port_b_index number
function network_join.execute(entity_a, port_a_index, entity_b, port_b_index)
    local unit_a = entity_a.unit_number
    local unit_b = entity_b.unit_number

    if not (unit_a and unit_b) then return end

    local key_a = get_port_key(unit_a, port_a_index)
    local key_b = get_port_key(unit_b, port_b_index)

    local net_a = port_to_network[key_a]
    local net_b = port_to_network[key_b]

    if not net_a and not net_b then
        -- Neither has a network: Create a new network and add both
        local new_net_id = networks.create()
        
        networks.add_member(new_net_id, unit_a, port_a_index)
        networks.add_member(new_net_id, unit_b, port_b_index)

        port_to_network[key_a] = new_net_id
        port_to_network[key_b] = new_net_id

        game.print(string.format("[NETWORK CREATED #%d] Joined Unit %d (Port %d) <-> Unit %d (Port %d)", 
            new_net_id, unit_a, port_a_index, unit_b, port_b_index))

    elseif net_a and not net_b then
        -- Add B to A's network
        networks.add_member(net_a, unit_b, port_b_index)
        port_to_network[key_b] = net_a

        game.print(string.format("[NETWORK ADD] Added Unit %d (Port %d) to Network #%d", 
            unit_b, port_b_index, net_a))

    elseif not net_a and net_b then
        -- Add A to B's network
        networks.add_member(net_b, unit_a, port_a_index)
        port_to_network[key_a] = net_b

        game.print(string.format("[NETWORK ADD] Added Unit %d (Port %d) to Network #%d", 
            unit_a, port_a_index, net_b))

    elseif net_a ~= net_b then
        -- Both belong to distinct networks: Keep network IDs separate
        game.print(string.format("[NETWORK JOINED] Connected Network #%d <-> Network #%d (Keeping networks separate)", 
            net_a, net_b))
    end
end

return network_join