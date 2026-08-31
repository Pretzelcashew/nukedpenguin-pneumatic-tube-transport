local events = require("scripts.events")
local diverter_gui = require("scripts.diverter-gui")

local diverter_linkage = {}

local DIVERTER_NAME = "pneumatic-diverter"
local PROXY_NAME = "pneumatic-diverter-circuit-proxy"

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}
if defines.events.on_space_platform_built_entity then
    table.insert(build_events, defines.events.on_space_platform_built_entity)
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

local rotate_events = {
    defines.events.on_player_rotated_entity,
    defines.events.on_player_flipped_entity
}

local function on_created(event)
    local entity = event.entity or event.created_entity or event.destination
    if not (entity and entity.valid) then return end
    if entity.name ~= DIVERTER_NAME then return end

    local existing = entity.surface.find_entities_filtered{
        name = PROXY_NAME,
        position = entity.position
    }
    if #existing == 0 then
        local proxy = entity.surface.create_entity{
            name = PROXY_NAME,
            position = entity.position,
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
    if entity.name ~= DIVERTER_NAME then return end

    local proxies = entity.surface.find_entities_filtered{
        name = PROXY_NAME,
        position = entity.position
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
    if entity.name ~= DIVERTER_NAME then return end

    local proxies = entity.surface.find_entities_filtered{
        name = PROXY_NAME,
        position = entity.position
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
    if entity.name ~= DIVERTER_NAME then return end

    local player = game.get_player(event.player_index)
    if player and player.valid then
        diverter_gui.open(player, entity)
    end
end

-- Hook build events
for _, id in ipairs(build_events) do
    events.on_event(id, on_created)
end

-- Hook destruction events
for _, id in ipairs(destroy_events) do
    events.on_event(id, on_removed)
end

-- Hook rotation events
for _, id in ipairs(rotate_events) do
    events.on_event(id, on_rotated)
end

-- Hook GUI opening
events.on_event(defines.events.on_gui_opened, on_gui_opened)

return diverter_linkage