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

local function on_created(event)
    local entity = event.entity or event.created_entity or event.destination
    if not (entity and entity.valid) then return end

    local spec = registered_mains[entity.name]
    if not spec then return end

    local pos = entity.position
    if spec.offset then
        pos = { x = pos.x + spec.offset.x, y = pos.y + spec.offset.y }
    end

    local existing = entity.surface.find_entities_filtered{
        name = spec.proxy_entity_name,
        position = pos
    }
    if #existing == 0 then
        local proxy = entity.surface.create_entity{
            name = spec.proxy_entity_name,
            position = pos,
            force = entity.force,
            direction = entity.direction
        }
        if proxy then
            proxy.destructible = false
            proxy.operable = false
        end
    end
end

local function on_removed(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local spec = registered_mains[entity.name]
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
            proxy.destroy()
        end
    end
end

local function on_rotated(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    local spec = registered_mains[entity.name]
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