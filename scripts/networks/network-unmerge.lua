-- FILE: scripts/networks/network-unmerge.lua

local networks = require("scripts.networks.networks")
local port_walk = require("scripts.ports.port-walk")
local network_unmerge = {}

function network_unmerge.execute(severed_port_key, neighbor_key)
    networks.init()

    local old_net_id = storage.networks.port_to_network[neighbor_key]
    
    -- 1. Sever the physical edge so the walk cannot cross back over it
    networks.remove_connection(severed_port_key, neighbor_key)

    if not old_net_id then return end
    local old_net = storage.networks.list[old_net_id]
    if not old_net then return end

    -- 2. Traverse from neighbor to see what is still connected to it
    local visited_subgraph = port_walk.traverse(neighbor_key, "merge")

    local visited_count = 0
    for _ in pairs(visited_subgraph) do
        visited_count = visited_count + 1
    end

    -- 3. Count how many valid members SHOULD remain (ignoring the entity being destroyed)
    local expected_count = 0
    local u_severed = severed_port_key:match("^(%d+):")
    
    for _, m in ipairs(old_net.members) do
        if tostring(m.unit_number) ~= u_severed then
            expected_count = expected_count + 1
        end
    end

    -- 4. Evaluate if the network actually split
    if visited_count >= expected_count then
        -- NO SPLIT (or it's the main chunk). Clean up the dead entity and KEEP the old ID.
        local new_members = {}
        for _, m in ipairs(old_net.members) do
            if tostring(m.unit_number) ~= u_severed then
                table.insert(new_members, m)
            end
        end
        old_net.members = new_members
        
        -- Safety catch: if no members remain, recycle the ID
        if #old_net.members == 0 then
            networks.delete(old_net_id)
            game.print(string.format("[UNMERGE] Network #%d emptied and recycled.", old_net_id))
        else
            game.print(string.format("[UNMERGE] Network #%d intact (%d members remain)", old_net_id, #new_members))
        end
    else
        -- SPLIT DETECTED!
        local new_net_id = networks.create()
        local new_net = storage.networks.list[new_net_id]
        
        local remaining_old_members = {}
        
        for _, m in ipairs(old_net.members) do
            local m_key = m.unit_number .. ":" .. m.port_index
            if visited_subgraph[m_key] then
                table.insert(new_net.members, m)
                storage.networks.port_to_network[m_key] = new_net_id
            elseif tostring(m.unit_number) ~= u_severed then
                table.insert(remaining_old_members, m)
            end
        end
        
        old_net.members = remaining_old_members
        
        -- Safety catch for the old network chunk
        if #old_net.members == 0 then
            networks.delete(old_net_id)
            game.print(string.format("[UNMERGE SPLIT] Subgraph broke off into Network #%d (%d members). Old network #%d was emptied and recycled.", 
                new_net_id, #new_net.members, old_net_id))
        else
            game.print(string.format("[UNMERGE SPLIT] Subgraph broke off into Network #%d (%d members). Network #%d retains %d members.", 
                new_net_id, #new_net.members, old_net_id, #old_net.members))
        end
    end
end -- <-- This was the missing 'end' for the function!

return network_unmerge