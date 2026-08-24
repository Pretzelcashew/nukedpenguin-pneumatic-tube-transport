-- scripts/capsules/capsule-runner.lua
local port_defs = require("scripts.ports.port-definitions")

local capsule_runner = {}

local function init_storage()
    storage.capsules = storage.capsules or {}
    storage.next_capsule_id = storage.next_capsule_id or 1
    if storage.show_capsules == nil then
        storage.show_capsules = true
    end
end

local function draw_capsule(capsule)
    if not storage.show_capsules then return end

    -- Clear existing drawing if present
    if capsule.render_id and capsule.render_id.valid then
        capsule.render_id.destroy()
    end

    local unit_num, p_idx = capsule.current_port_key:match("^(%d+):(%d+)$")
    unit_num = tonumber(unit_num)
    p_idx = tonumber(p_idx)

    local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[capsule.current_port_key]
    if not net_id then return end

    local net = storage.networks.list and storage.networks.list[net_id]
    if not (net and net.members) then return end

    -- Find matching member entity to anchor position offset
    for _, member in ipairs(net.members) do
        if member.unit_number == unit_num and member.port_index == p_idx then
            local entity = member.entity
            if entity and entity.valid then
                local ports = port_defs.get_ports(entity)
                local port = ports and ports[p_idx]
                local offset = port and port.offset or { x = 0, y = 0 }

                capsule.render_id = rendering.draw_circle{
                    color = { r = 1, g = 0.84, b = 0, a = 0.9 }, -- Bright Gold / Yellow
                    radius = 0.25,
                    filled = true,
                    target = { entity = entity, offset = offset },
                    surface = entity.surface
                }
                break
            end
        end
    end
end

local function clear_capsule_render(capsule)
    if capsule.render_id and capsule.render_id.valid then
        capsule.render_id.destroy()
    end
    capsule.render_id = nil
end

function capsule_runner.spawn(player, entity)
    init_storage()

    if not (entity and entity.valid) then
        if player then player.print("[Capsule] No valid entity selected/hovered.") end
        return
    end

    local ports = port_defs.get_ports(entity)
    if not ports then
        if player then player.print(string.format("[Capsule] %s does not have network ports.", entity.name)) end
        return
    end

    -- Locate first valid port on an active network
    local target_port_key = nil
    local target_net_id = nil

    for p_idx, _ in ipairs(ports) do
        local key = entity.unit_number .. ":" .. p_idx
        local net_id = storage.networks and storage.networks.port_to_network and storage.networks.port_to_network[key]
        if net_id then
            target_port_key = key
            target_net_id = net_id
            break
        end
    end

    if not target_port_key then
        if player then player.print("[Capsule] Hovered entity is not bound to an active flow network.") end
        return
    end

    -- Provision abstract capsule pointer
    local id = storage.next_capsule_id
    storage.next_capsule_id = id + 1

    local capsule = {
        id = id,
        current_port_key = target_port_key,
        net_id = target_net_id,
        render_id = nil
    }

    storage.capsules[id] = capsule
    draw_capsule(capsule)

    if player then
        player.print(string.format("[Capsule] Spawned Capsule #%d at Port %s (Network #%d)", id, target_port_key, target_net_id))
    end
end

function capsule_runner.clear_all(player)
    init_storage()
    local count = 0

    for _, capsule in pairs(storage.capsules) do
        clear_capsule_render(capsule)
        count = count + 1
    end

    storage.capsules = {}

    if player then
        player.print(string.format("[Capsule] Cleared %d capsule(s).", count))
    end
end

function capsule_runner.toggle_rendering(player)
    init_storage()
    storage.show_capsules = not storage.show_capsules

    if storage.show_capsules then
        for _, capsule in pairs(storage.capsules) do
            draw_capsule(capsule)
        end
        if player then player.print("[Capsule] Visualization: ENABLED") end
    else
        for _, capsule in pairs(storage.capsules) do
            clear_capsule_render(capsule)
        end
        if player then player.print("[Capsule] Visualization: DISABLED") end
    end
end

-- Command registrations
commands.add_command("spawn-capsule", "Spawn an abstract capsule at the hovered network entity", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    local selected = player and player.selected
    capsule_runner.spawn(player, selected)
end)

commands.add_command("clear-capsules", "Clear all active capsules from the map", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    capsule_runner.clear_all(player)
end)

commands.add_command("toggle-capsule", "Toggle capsule rendering overlay", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    capsule_runner.toggle_rendering(player)
end)

return capsule_runner