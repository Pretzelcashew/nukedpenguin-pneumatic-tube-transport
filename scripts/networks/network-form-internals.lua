-- scripts/networks/network-form-internals.lua
local port_defs = require("scripts.ports.port-definitions")
local networks = require("scripts.networks.networks")

local network_form_internals = {}

--- Provisions standalone internal networks for a newly placed or rotated entity
function network_form_internals.execute(entity)
    if not (entity and entity.valid) then return end

    -- Ensure storage state is primed
    networks.init()

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    local processed_groups = {}
    
    for p_idx, port in ipairs(ports) do
        local group_id = port.group
        
        -- Only process each group once per entity
        if group_id and not processed_groups[group_id] then
            processed_groups[group_id] = true
            
            local port_key = entity.unit_number .. ":" .. p_idx
            
            -- If this port isn't mapped, it means the group needs provisioning
            if not storage.networks.port_to_network[port_key] then
                local new_net_id = networks.create()
                networks.bind_group_to_network(entity, group_id, new_net_id)
                debug_print(string.format("[INIT] Unit %d provisioned Network #%d for Group %d", entity.unit_number, new_net_id, group_id))
            end
        end
    end
end

return network_form_internals