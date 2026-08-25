-- scripts/ports/port-renderer.lua
local events = require("scripts.events")
local port_defs = require("scripts.ports.port-definitions")

local port_renderer = {}

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

function port_renderer.draw_ports_for_entity(entity)
    if not (entity and entity.valid) then return end

    local ports = port_defs.get_ports(entity)
    if not ports then return end

    storage.port_render_objects = storage.port_render_objects or {}

    for _, port in ipairs(ports) do
        local circle = rendering.draw_circle{
            color = {r = 0, g = 1, b = 0.2, a = 0.8},
            radius = 0.12,
            filled = true,
            target = { entity = entity, offset = port.offset },
            surface = entity.surface
        }
        table.insert(storage.port_render_objects, circle)
    end
end

function port_renderer.clear_all()
    for _, obj in ipairs(storage.port_render_objects or {}) do
        if obj and obj.valid then
            obj.destroy()
        end
    end
    storage.port_render_objects = {}
end

function port_renderer.draw_all()
    port_renderer.clear_all()
    local drawn_units = {}
    for _, net in pairs(storage.networks and storage.networks.list or {}) do
        for _, member in ipairs(net.members or {}) do
            if member.entity and member.entity.valid and not drawn_units[member.unit_number] then
                drawn_units[member.unit_number] = true
                port_renderer.draw_ports_for_entity(member.entity)
            end
        end
    end
end

local function handle_entity_created(event)
    if not is_debug_active("ports") then return end
    port_renderer.draw_ports_for_entity(event.entity)
end

for _, event_id in ipairs(build_events) do
    events.on_event(event_id, handle_entity_created)
end

return port_renderer