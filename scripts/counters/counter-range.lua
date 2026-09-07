-- File: scripts/counters/counter-range.lua

local flow_engine = require("scripts.flow.flow-engine")

local counter_range = {}

function counter_range.init_storage()
    flow_engine.init_storage()
end

function counter_range.enqueue_port(pkey)
    flow_engine.enqueue_port(pkey)
end

function counter_range.enqueue_unit_ports(unit_number)
    flow_engine.enqueue_unit_ports(unit_number)
end

function counter_range.register_counter(entity)
    flow_engine.init_storage()
    if not (entity and entity.valid and entity.unit_number) then return end

    local unit_number = entity.unit_number
    if not storage.active_counters[unit_number] then
        storage.active_counters[unit_number] = entity
    end

    flow_engine.enqueue_unit_ports(unit_number)
end

function counter_range.unregister_counter(unit_number)
    flow_engine.init_storage()
    if not unit_number then return end
    flow_engine.handle_object_destroyed(unit_number)
end

function counter_range.get_owned_nodes(counter_unit)
    flow_engine.init_storage()
    if not counter_unit then return {} end
    return storage.counter_owned_nodes[counter_unit] or {}
end

function counter_range.clear_all_renders(player_index)
    flow_engine.clear_counter_renders(player_index)
end

function counter_range.draw_all(player_index)
    flow_engine.draw_all_counters(player_index)
end

function counter_range.register_events()
    commands.add_command("check-counters", "Display active pneumatic capsule counter status and range territory", function()
        flow_engine.init_storage()
        local count = 0
        for unit_number, entity in pairs(storage.active_counters) do
            if entity and entity.valid then
                count = count + 1
                local owned = storage.counter_owned_nodes[unit_number]
                local node_count = 0
                if owned then
                    for _ in pairs(owned) do node_count = node_count + 1 end
                end
                local power = (entity.energy > 0) and "POWERED" or "UNPOWERED"
                game.print(string.format("[Counter Status] Counter #%d (%s at x=%.1f, y=%.1f): owns %d tube node(s)", unit_number, power, entity.position.x, entity.position.y, node_count))
            end
        end
        if count == 0 then
            game.print("[Counter Status] No active capsule counters registered in storage!")
        end
    end)
end

return counter_range