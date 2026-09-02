local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local flow_engine = require("scripts.flow.flow-engine")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local debug_manager = require("scripts.debug-manager")

local FLOW_VERSION = settings.startup["pneumatic-flow-version"] and settings.startup["pneumatic-flow-version"].value or "v1"

local capsule_runner_v2 = {}

function capsule_runner_v2.get_capsule_count_at_entity(unit_number)
    return capsule_queries.get_capsule_count_at_entity(unit_number)
end

function capsule_runner_v2.wake_parked_capsules(target)
    if not storage.capsules then return end

    for _, capsule in pairs(storage.capsules) do
        if not capsule.to_port_key then
            capsule.next_retry_tick = nil
            capsule.last_failed_hub = nil
        end
    end
end

--- Evaluates ports of a hub entity on the v2 flow engine.
--- Defaults fallback to port 1 of the hub entity so capsules pack onto the hub's internal node even when disconnected.
--- @param hub_entity LuaEntity
--- @param capsule_id number|nil
--- @return string|nil best_port_key
--- @return string fallback_port_key
--- @return number best_flow_level
function capsule_runner_v2.find_best_hub_outbound_port(hub_entity, capsule_id)
    if not (hub_entity and hub_entity.valid) then return nil, nil, 0 end

    local ports = port_defs.get_ports(hub_entity)
    if not ports then return nil, nil, 0 end

    local unit_number = hub_entity.unit_number
    local fallback_port_key = unit_number .. ":1"
    local best_port_key = nil
    local max_flow_mag = -1
    local best_flow_level = 0

    for port_index = 1, #ports do
        local pkey = unit_number .. ":" .. port_index
        local neighbors = storage.flow_connections and storage.flow_connections[pkey]

        if neighbors and next(neighbors) ~= nil then
            for n_key, _ in pairs(neighbors) do
                local level = storage.flow_levels and storage.flow_levels[n_key] or 0
                local mag = math.abs(level)
                if mag > max_flow_mag then
                    max_flow_mag = mag
                    best_port_key = pkey
                    best_flow_level = level
                end
            end
        end
    end

    return best_port_key, fallback_port_key, best_flow_level
end

--- Injects a packed capsule onto the v2 flow engine.
--- @param capsule_id number
--- @param entity LuaEntity
--- @param passenger LuaPlayer|nil
--- @return boolean success
function capsule_runner_v2.inject_from_hub(capsule_id, entity, passenger)
    if FLOW_VERSION ~= "v2" then return false end
    if not (entity and entity.valid) then return false end

    local best_port_key, fallback_port_key, flow_level = capsule_runner_v2.find_best_hub_outbound_port(entity, capsule_id)
    local target_port_key = best_port_key or fallback_port_key

    local cap_data = capsule_manager.get(capsule_id)
    local dominant_item = (cap_data and cap_data.dominant_item) or capsule_renderer.get_dominant_item(capsule_id)

    local new_capsule = {
        id = capsule_id,
        capsule_id = capsule_id,
        dominant_item = dominant_item,
        from_port_key = target_port_key,
        to_port_key = nil,
        last_port_key = nil,
        progress = 0.0,
        render_id = nil,
        render_cache = nil,
        source_hub = entity.unit_number,
        passenger = passenger
    }

    storage.capsules = storage.capsules or {}
    storage.capsules[capsule_id] = new_capsule

    capsule_queries.update_capsule_occupancy(new_capsule)
    capsule_runner_v2.wake_parked_capsules(target_port_key)

    if best_port_key then
        debug_print("[v2 Flow] Successfully packed capsule #" .. tostring(capsule_id) .. " (" .. tostring(dominant_item) .. ") onto v2 flow engine at hub " .. tostring(entity.unit_number) .. " port " .. tostring(target_port_key) .. " (flow level: " .. tostring(flow_level) .. ")")
    else
        debug_print("[v2 Flow] Successfully packed capsule #" .. tostring(capsule_id) .. " (" .. tostring(dominant_item) .. ") onto v2 flow engine at hub " .. tostring(entity.unit_number) .. " (parked at hub port " .. tostring(target_port_key) .. ")")
    end

    return true
end

--- v2 tick update handler: updates occupancy and renders active capsules on their v2 port positions
--- @param current_tick number
function capsule_runner_v2.update_capsules(current_tick)
    if FLOW_VERSION ~= "v2" then return end
    if not storage.capsules then return end

    capsule_renderer.prepare_frame()

    for id, capsule in pairs(storage.capsules) do
        local from_key = capsule.from_port_key
        local node = from_key and storage.flow_nodes and storage.flow_nodes[from_key]

        if node then
            local surface = game.surfaces[node.surface_name]
            if surface and surface.valid then
                capsule_renderer.render(capsule, id, node.pos, surface)
            end
        end
    end
end

function capsule_runner_v2.register_events()
    if FLOW_VERSION ~= "v2" then return end

    events.on_event(defines.events.on_tick, function(event)
        capsule_runner_v2.update_capsules(event.tick)
    end)
end

return capsule_runner_v2