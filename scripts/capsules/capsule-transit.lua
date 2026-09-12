local capsule_defs = require("scripts.capsules.capsule-definitions")
local capsule_manager = require("scripts.capsules.capsule-manager")

local capsule_transit = {}

--------------------------------------------------------------------------------
-- HARNESS & ELECTROMAGNETIC VALIDATION
--------------------------------------------------------------------------------
function capsule_transit.player_has_harness(player)
    if not (player and player.valid) then return false end
    local char = player.character
    if not (char and char.valid) then return false end
    local grid = char.grid
    if not (grid and grid.valid) then return false end

    local equipment = grid.equipment
    for i = 1, #equipment do
        local eq = equipment[i]
        if eq.name == "electromagnetic-harness" and eq.energy and eq.energy > 100000 then
            return true
        end
    end
    return false
end

function capsule_transit.is_electromagnetic_capsule(capsule_or_id)
    if not capsule_or_id then return false end
    if type(capsule_or_id) == "table" then
        if capsule_or_id.passenger and capsule_transit.player_has_harness(capsule_or_id.passenger) then
            return true
        end
        if capsule_or_id.capsule_type then
            return capsule_defs.is_electromagnetic(capsule_or_id.capsule_type)
        end
        local cid = capsule_or_id.capsule_id or capsule_or_id.id
        if cid then
            return capsule_transit.is_electromagnetic_capsule(cid)
        end
        return false
    elseif type(capsule_or_id) == "number" then
        local cap = storage.capsules and storage.capsules[capsule_or_id]
        if cap and cap.passenger and capsule_transit.player_has_harness(cap.passenger) then
            return true
        end
        if capsule_manager.is_electromagnetic(capsule_or_id) then
            return true
        end
        local cap = storage.capsules and storage.capsules[capsule_or_id]
        if cap and cap.capsule_type then
            return capsule_defs.is_electromagnetic(cap.capsule_type)
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- ZERO-ALLOCATION PLAYER TARGET SCRATCH & COLLISION
--------------------------------------------------------------------------------
local scratch_player_targets = {}
local scratch_player_target_count = 0

function capsule_transit.prepare_player_targets()
    scratch_player_target_count = 0
    local connected = game.connected_players
    if not connected or #connected == 0 then return end

    for i = 1, #connected do
        local player = connected[i]
        local char = player.character
        local veh = player.vehicle or player.physical_vehicle
        local target = (veh and veh.valid and veh) or (char and char.valid and char)

        if target and target.valid then
            local bb = target.bounding_box
            if bb then
                scratch_player_target_count = scratch_player_target_count + 1
                local entry = scratch_player_targets[scratch_player_target_count]
                if not entry then
                    entry = {}
                    scratch_player_targets[scratch_player_target_count] = entry
                end
                entry.target = target
                entry.player = player
                entry.surface = target.surface
                entry.min_x = bb.left_top.x - 0.45
                entry.max_x = bb.right_bottom.x + 0.45
                entry.min_y = bb.left_top.y - 0.45
                entry.max_y = bb.right_bottom.y + 0.45
            end
        end
    end
end

function capsule_transit.check_player_collision(surface, tx, ty, capsule)
    if scratch_player_target_count == 0 or not surface then return nil end

    local passenger = capsule and capsule.passenger
    local pass_index = passenger and passenger.valid and passenger.index
    local pass_char = passenger and passenger.valid and passenger.character

    for i = 1, scratch_player_target_count do
        local pdata = scratch_player_targets[i]
        if pdata and pdata.target and pdata.target.valid and pdata.surface == surface then
            local is_own_passenger = false
            if pass_index and pdata.player and pdata.player.valid and pdata.player.index == pass_index then
                is_own_passenger = true
            elseif pass_char and pdata.target == pass_char then
                is_own_passenger = true
            elseif pass_index and pdata.target.player and pdata.target.player.valid and pdata.target.player.index == pass_index then
                is_own_passenger = true
            end

            if not is_own_passenger then
                if tx >= pdata.min_x and tx <= pdata.max_x and ty >= pdata.min_y and ty <= pdata.max_y then
                    return pdata.target, pdata.player
                end
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- EMERGENCY EJECTION
--------------------------------------------------------------------------------
function capsule_transit.emergency_eject(player, runner)
    if not (storage.capsules and player and player.valid) then return end

    for id, capsule in pairs(storage.capsules) do
        if capsule.passenger == player then
            local pos, surface = runner.get_capsule_location(id)
            if not (pos and surface) then
                pos = player.position
                surface = player.surface
            end

            local safe_pos = surface.find_non_colliding_position("character", pos, 4, 0.5) or pos
            player.teleport(safe_pos, surface)

            surface.create_entity{
                name = "explosion",
                position = safe_pos
            }

            runner.remove_capsule(id)
            break
        end
    end
end

return capsule_transit
