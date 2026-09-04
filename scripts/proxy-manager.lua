local events = require("scripts.events")
local pump_gui = require("scripts.pump-gui")
local diverter_gui = require("scripts.diverter-gui")

local proxy_manager = {}

local registered_mains = {}
local registered_proxies = {}

function proxy_manager.register_pair(spec)
    if not (spec and spec.main_entity_name and spec.proxy_entity_name) then return end
    registered_mains[spec.main_entity_name] = spec
    registered_proxies[spec.proxy_entity_name] = spec
end

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}
if defines.events.on_space_platform_built_entity then
    table.insert(build_events, defines.events.on_space_platform_built_entity)
end
if defines.events.on_entity_cloned then
    table.insert(build_events, defines.events.on_entity_cloned)
end

local destroy_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
}
if defines.events.on_space_platform_mined_entity then
    table.insert(destroy_events, defines.events.on_space_platform_mined_entity)
end

local rotate_events = {}
if defines.events.on_player_rotated_entity then
    table.insert(rotate_events, defines.events.on_player_rotated_entity)
end
if defines.events.on_player_flipped_entity then
    table.insert(rotate_events, defines.events.on_player_flipped_entity)
end

local function transfer_wire_connections(src_entity, dest_entity)
    if not (src_entity and src_entity.valid and dest_entity and dest_entity.valid) then return end
    if src_entity == dest_entity then return end

    local src_connectors = src_entity.get_wire_connectors(false)
    if not src_connectors then return end

    for conn_id, src_conn in pairs(src_connectors) do
        if src_conn.connections then
            local dest_conn = dest_entity.get_wire_connector(conn_id, true)
            if dest_conn then
                for _, conn in ipairs(src_conn.connections) do
                    local target_conn = conn.target
                    if target_conn and target_conn.owner and target_conn.owner.valid then
                        dest_conn.connect_to(target_conn)
                    end
                end
            end
        end
    end
end

function proxy_manager.purge_orphans()
    local proxy_names = {}
    for proxy_name in pairs(registered_proxies) do
        table.insert(proxy_names, proxy_name)
    end
    if #proxy_names == 0 then return end

    for _, surface in pairs(game.surfaces) do
        local proxies = surface.find_entities_filtered{ name = proxy_names }
        for _, proxy in ipairs(proxies) do
            if proxy.valid then
                local spec = registered_proxies[proxy.name]
                if spec then
                    local main_pos = proxy.position
                    if spec.offset then
                        main_pos = { x = main_pos.x - spec.offset.x, y = main_pos.y - spec.offset.y }
                    end
                    local main = surface.find_entity(spec.main_entity_name, main_pos)
                    if not (main and main.valid) then
                        local ghost_mains = surface.find_entities_filtered{
                            ghost_name = spec.main_entity_name,
                            position = main_pos
                        }
                        if #ghost_mains == 0 then
                            proxy.destroy()
                        end
                    end
                end
            end
        end

        local ghost_proxies = surface.find_entities_filtered{ ghost_name = proxy_names }
        for _, g in ipairs(ghost_proxies) do
            if g.valid then
                local spec = registered_proxies[g.ghost_name]
                if spec then
                    local main_pos = g.position
                    if spec.offset then
                        main_pos = { x = main_pos.x - spec.offset.x, y = main_pos.y - spec.offset.y }
                    end
                    local main = surface.find_entity(spec.main_entity_name, main_pos)
                    if not (main and main.valid) then
                        local ghost_mains = surface.find_entities_filtered{
                            ghost_name = spec.main_entity_name,
                            position = main_pos
                        }
                        if #ghost_mains == 0 then
                            g.destroy()
                        end
                    end
                end
            end
        end
    end
end

local function on_created(event)
    local entity = event.entity or event.created_entity or event.destination
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local name = is_ghost and entity.ghost_name or entity.name

    local main_spec = registered_mains[name]
    local proxy_spec = registered_proxies[name]

    if not (main_spec or proxy_spec) then return end

    if main_spec then
        local pos = entity.position
        if main_spec.offset then
            pos = { x = pos.x + main_spec.offset.x, y = pos.y + main_spec.offset.y }
        end

        local ghost_proxies = entity.surface.find_entities_filtered{
            ghost_name = main_spec.proxy_entity_name,
            position = pos
        }

        local existing = entity.surface.find_entities_filtered{
            name = main_spec.proxy_entity_name,
            position = pos
        }

        local primary_proxy = existing[1]
        if not (primary_proxy and primary_proxy.valid) then
            primary_proxy = entity.surface.create_entity{
                name = main_spec.proxy_entity_name,
                position = pos,
                force = entity.force,
                direction = entity.direction
            }
            if primary_proxy then
                primary_proxy.destructible = false
            end
        else
            primary_proxy.direction = entity.direction
            primary_proxy.teleport(pos)
        end

        if primary_proxy and primary_proxy.valid then
            -- Merge wires from all ghost proxies onto primary_proxy before destroying ghosts
            for _, g in ipairs(ghost_proxies) do
                if g.valid then
                    transfer_wire_connections(g, primary_proxy)
                    g.destroy()
                end
            end

            -- Merge wires from any duplicate real proxies onto primary_proxy before destroying
            for i = 2, #existing do
                local dup = existing[i]
                if dup and dup.valid then
                    transfer_wire_connections(dup, primary_proxy)
                    dup.destroy()
                end
            end
        end

    elseif proxy_spec then
        local main_pos = entity.position
        if proxy_spec.offset then
            main_pos = { x = main_pos.x - proxy_spec.offset.x, y = main_pos.y - proxy_spec.offset.y }
        end

        local main = entity.surface.find_entity(proxy_spec.main_entity_name, main_pos)
        if not (main and main.valid) then
            local ghost_mains = entity.surface.find_entities_filtered{
                ghost_name = proxy_spec.main_entity_name,
                position = main_pos
            }
            if #ghost_mains > 0 then
                main = ghost_mains[1]
            end
        end

        if not (main and main.valid) then
            -- Orphan cleanup
            entity.destroy()
        else
            local existing = entity.surface.find_entities_filtered{
                name = proxy_spec.proxy_entity_name,
                position = entity.position
            }

            if is_ghost then
                local primary_proxy = existing[1]
                if not (primary_proxy and primary_proxy.valid) then
                    primary_proxy = entity.surface.create_entity{
                        name = proxy_spec.proxy_entity_name,
                        position = entity.position,
                        force = main.force,
                        direction = main.direction
                    }
                    if primary_proxy then
                        primary_proxy.destructible = false
                    end
                end

                if primary_proxy and primary_proxy.valid then
                    transfer_wire_connections(entity, primary_proxy)
                end
                entity.destroy()

                -- Deduplicate extra real proxies, merging wires
                for i = 2, #existing do
                    if existing[i].valid then
                        transfer_wire_connections(existing[i], primary_proxy)
                        existing[i].destroy()
                    end
                end
            else
                -- Real proxy created/revived: merge other existing real proxies into this one
                for _, p in ipairs(existing) do
                    if p.valid and p ~= entity then
                        transfer_wire_connections(p, entity)
                        p.destroy()
                    end
                end
                entity.direction = main.direction
                entity.teleport(entity.position)
            end
        end
    end
end

local function on_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local name = is_ghost and entity.ghost_name or entity.name

    local main_spec = registered_mains[name]
    local proxy_spec = registered_proxies[name]

    if main_spec then
        local pos = entity.position
        if main_spec.offset then
            pos = { x = pos.x + main_spec.offset.x, y = pos.y + main_spec.offset.y }
        end

        local proxies = entity.surface.find_entities_filtered{
            name = main_spec.proxy_entity_name,
            position = pos
        }
        for _, proxy in ipairs(proxies) do
            if proxy.valid then
                proxy.destroy()
            end
        end

        local ghost_proxies = entity.surface.find_entities_filtered{
            ghost_name = main_spec.proxy_entity_name,
            position = pos
        }
        for _, g in ipairs(ghost_proxies) do
            if g.valid then
                g.destroy()
            end
        end

    elseif proxy_spec then
        local main_pos = entity.position
        if proxy_spec.offset then
            main_pos = { x = main_pos.x - proxy_spec.offset.x, y = main_pos.y - proxy_spec.offset.y }
        end

        local main = entity.surface.find_entity(proxy_spec.main_entity_name, main_pos)
        if not (main and main.valid) then
            local ghost_mains = entity.surface.find_entities_filtered{
                ghost_name = proxy_spec.main_entity_name,
                position = main_pos
            }
            if #ghost_mains > 0 then main = ghost_mains[1] end
        end

        if not (main and main.valid) then
            local proxies = entity.surface.find_entities_filtered{
                name = proxy_spec.proxy_entity_name,
                position = entity.position
            }
            for _, p in ipairs(proxies) do
                if p.valid then p.destroy() end
            end
            local ghost_proxies = entity.surface.find_entities_filtered{
                ghost_name = proxy_spec.proxy_entity_name,
                position = entity.position
            }
            for _, g in ipairs(ghost_proxies) do
                if g.valid then g.destroy() end
            end
        end
    end
end

local function on_rotated(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local is_ghost = (entity.name == "entity-ghost")
    local name = is_ghost and entity.ghost_name or entity.name

    local spec = registered_mains[name]
    if not spec then return end

    local pos = entity.position
    if spec.offset then
        pos = { x = pos.x + spec.offset.x, y = pos.y + spec.offset.y }
    end

    local proxies = entity.surface.find_entities_filtered{
        name = spec.proxy_entity_name,
        position = pos
    }
    for _, proxy in ipairs(proxies) do
        if proxy.valid then
            proxy.direction = entity.direction
            proxy.teleport(pos)
        end
    end
end

local function on_gui_opened(event)
    if event.gui_type ~= defines.gui_type.entity then return end
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local host_entity = nil
    local spec = registered_mains[entity.name]

    if spec then
        host_entity = entity
    else
        spec = registered_proxies[entity.name]
        if spec then
            local pos = entity.position
            if spec.offset then
                pos = { x = pos.x - spec.offset.x, y = pos.y - spec.offset.y }
            end
            host_entity = entity.surface.find_entity(spec.main_entity_name, pos)
        end
    end

    if not (host_entity and host_entity.valid and spec and spec.on_open_gui) then return end

    local player = game.get_player(event.player_index)
    if player and player.valid then
        spec.on_open_gui(player, host_entity)
    end
end

function proxy_manager.register_events()
    for _, id in ipairs(build_events) do
        events.on_event(id, on_created)
    end

    for _, id in ipairs(destroy_events) do
        events.on_event(id, on_removed)
    end

    for _, id in ipairs(rotate_events) do
        events.on_event(id, on_rotated)
    end

    events.on_event(defines.events.on_gui_opened, on_gui_opened)
end

proxy_manager.register_pair({
    main_entity_name = "pneumatic-pump",
    proxy_entity_name = "pneumatic-pump-circuit-proxy",
    on_open_gui = pump_gui.open
})

proxy_manager.register_pair({
    main_entity_name = "pneumatic-diverter",
    proxy_entity_name = "pneumatic-diverter-circuit-proxy",
    on_open_gui = diverter_gui.open
})

return proxy_manager