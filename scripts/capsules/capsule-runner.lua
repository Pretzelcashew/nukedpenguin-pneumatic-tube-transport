local events = require("scripts.events")
local port_defs = require("scripts.flow.port-defs")
local flow_engine = require("scripts.flow.flow-engine")
local hub_defs = require("scripts.hubs.hub-definitions")
local hub_unpacking = require("scripts.hubs.hub-unpacking")
local hub_spill = require("scripts.hubs.hub-spill")
local diverter_settings = require("scripts.diverter-settings")
local projector_settings = require("scripts.projector-settings")
local capsule_queries = require("scripts.capsules.capsule-queries")
local capsule_manager = require("scripts.capsules.capsule-manager")
local capsule_lifecycle = require("scripts.capsules.capsule-lifecycle")
local capsule_renderer = require("scripts.capsules.capsule-renderer")
local liminal_surface = require("scripts.surfaces.liminal-surface")
local debug_manager = require("scripts.debug-manager")
local capsule_defs = require("scripts.capsules.capsule-definitions")

local STAGGER_TICKS = 6
local MAX_NODE_HOPS_PER_STEP = 3
local PARKED_RETRY_INTERVAL = 10
local HOP_DISTANCE = 5

local MAX_BEAM_DISTANCE = 500
local QUALITY_RANKS = {
    ["normal"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 3,
    ["epic"] = 4,
    ["legendary"] = 5
}

local capsule_runner = {}

local function is_electromagnetic_capsule(capsule_or_id)
    if not capsule_or_id then return false end
    if type(capsule_or_id) == "table" then
        if capsule_or_id.capsule_type then
            return capsule_defs.is_electromagnetic(capsule_or_id.capsule_type)
        end
        local cid = capsule_or_id.capsule_id or capsule_or_id.id
        if cid then
            return is_electromagnetic_capsule(cid)
        end
        return false
    elseif type(capsule_or_id) == "number" then
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

capsule_runner.is_electromagnetic_capsule = is_electromagnetic_capsule
--------------------------------------------------------------------------------
-- MODULE-LEVEL SCRATCH BUFFERS (Zero-Allocation GC Optimization)
--------------------------------------------------------------------------------
local scratch_cand_keys = { {}, {}, {} }
local scratch_cand_vias = { {}, {}, {} }
local scratch_cand_is_ext = { {}, {}, {} }
local scratch_cand_counts = { 0, 0, 0 }

local scratch_best_keys = {}
local scratch_best_vias = {}
local scratch_best_is_ext = {}
local scratch_best_count = 0

local scratch_ports_to_wake = {}
local scratch_player_targets = {}
local scratch_player_target_count = 0

local function prepare_player_targets()
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

local function check_player_collision(surface, tx, ty, capsule)
    if scratch_player_target_count == 0 or not surface then return nil end

    for i = 1, scratch_player_target_count do
        local pdata = scratch_player_targets[i]
        if pdata and pdata.target and pdata.target.valid and pdata.surface == surface then
            if not (capsule and capsule.passenger == pdata.player) then
                if tx >= pdata.min_x and tx <= pdata.max_x and ty >= pdata.min_y and ty <= pdata.max_y then
                    return pdata.target, pdata.player
                end
            end
        end
    end
    return nil
end

local function make_beam_port_key(unit_number, dx, dy, dist)
    return string.format("kinetic:%d:%d,%d:%d", unit_number, math.floor(dx or 0), math.floor(dy or 0), dist)
end

local function get_beam_endpoint(unit_number, dx, dy)
    for dist = 1, MAX_BEAM_DISTANCE do
        local check_key = make_beam_port_key(unit_number, dx, dy, dist)
        local check_node = storage.flow_nodes and storage.flow_nodes[check_key]
        if not check_node then break end
        if check_node.is_endpoint then
            return check_key, check_node
        end
    end
    return nil, nil
end

local function count_endpoint_capsules(unit_number, endpoint_key, endpoint_node)
    local count = 0

    if storage.parked_by_port and storage.parked_by_port[endpoint_key] then
        for _ in pairs(storage.parked_by_port[endpoint_key]) do
            count = count + 1
        end
    end

    local hit_receiver_unit = endpoint_node and endpoint_node.hit_receiver
    if hit_receiver_unit and storage.flow_unit_ports and storage.flow_unit_ports[hit_receiver_unit] then
        local r_ports = storage.flow_unit_ports[hit_receiver_unit]
        for i = 1, #r_ports do
            local rpkey = r_ports[i]
            if storage.parked_by_port and storage.parked_by_port[rpkey] then
                for _ in pairs(storage.parked_by_port[rpkey]) do
                    count = count + 1
                end
            end
        end
    end

    if storage.capsules then
        for _, cap in pairs(storage.capsules) do
            if cap.beam_flight and cap.beam_flight.owner == unit_number then
                if cap.from_port_key ~= endpoint_key then
                    count = count + 1
                end
            end
        end
    end

    return count
end
--------------------------------------------------------------------------------
-- AUDIO & PARTICLE VISUAL EFFECTS
--------------------------------------------------------------------------------
local function play_dispatch_effects(surface, pos)
    if not (surface and surface.valid and pos) then return end
    pcall(function()
        surface.create_entity{
            name = "spark-explosion",
            position = pos
        }
    end)
    pcall(function()
        surface.play_sound{
            path = "utility/wire_connect",
            position = pos,
            volume_modifier = 1.0
        }
    end)
end

local function play_flight_effects(surface, pos)
    if not (surface and surface.valid and pos) then return end
    pcall(function()
        surface.create_entity{
            name = "spark-explosion",
            position = pos
        }
    end)
end

local function play_catchment_effects(surface, pos)
    if not (surface and surface.valid and pos) then return end
    pcall(function()
        surface.create_entity{
            name = "spark-explosion",
            position = pos
        }
    end)
    pcall(function()
        surface.play_sound{
            path = "utility/wire_connect",
            position = pos,
            volume_modifier = 0.9
        }
    end)
end

--------------------------------------------------------------------------------
-- BALLISTIC FLIGHT TRAJECTORY INITIALIZATION
--------------------------------------------------------------------------------
local function init_capsule_beam_flight(capsule, muzzle_node)
    if not (capsule and muzzle_node and muzzle_node.dir) then return end
    local beam_owner = muzzle_node.beam_owner or muzzle_node.unit_number
    local dx = muzzle_node.dir.x
    local dy = muzzle_node.dir.y
    local surface_name = muzzle_node.surface_name

    local hop_positions = {}
    local hop_count = 0
    local terminal_pos = nil
    local hit_receiver_unit = nil

    for dist = 1, MAX_BEAM_DISTANCE do
        local check_key = make_beam_port_key(beam_owner, dx, dy, dist)
        local check_node = storage.flow_nodes and storage.flow_nodes[check_key]
        if not check_node then break end

        if check_node.is_prominent_kinetic or check_node.is_endpoint then
            hop_count = hop_count + 1
            hop_positions[hop_count] = { x = check_node.pos.x, y = check_node.pos.y }
            if check_node.is_endpoint then
                terminal_pos = { x = check_node.pos.x, y = check_node.pos.y }
                hit_receiver_unit = check_node.hit_receiver
                break
            end
        end
    end

    if hop_count == 0 then
        hop_count = 1
        hop_positions[1] = {
            x = muzzle_node.pos.x + dx * HOP_DISTANCE,
            y = muzzle_node.pos.y + dy * HOP_DISTANCE
        }
    end

    if not terminal_pos then
        terminal_pos = hop_positions[hop_count]
    end

    capsule.beam_flight = {
        surface_name = surface_name or "nauvis",
        dx = dx,
        dy = dy,
        current_hop = 1,
        total_hops = hop_count,
        hop_positions = hop_positions,
        terminal_pos = terminal_pos,
        hit_receiver_unit = hit_receiver_unit,
        owner = beam_owner
    }
end

--------------------------------------------------------------------------------
-- SPATIAL PARKED INDEX MANAGEMENT
--------------------------------------------------------------------------------
local function mark_capsule_parked(capsule)
    if not capsule then return end
    local cap_id = capsule.capsule_id or capsule.id
    local port_key = capsule.from_port_key
    if not (cap_id and port_key) then return end

    storage.parked_by_port = storage.parked_by_port or {}

    if capsule.parked_at_port and capsule.parked_at_port ~= port_key then
        local old_bucket = storage.parked_by_port[capsule.parked_at_port]
        if old_bucket then
            old_bucket[cap_id] = nil
            if next(old_bucket) == nil then
                storage.parked_by_port[capsule.parked_at_port] = nil
            end
        end
    end

    storage.parked_by_port[port_key] = storage.parked_by_port[port_key] or {}
    storage.parked_by_port[port_key][cap_id] = true
    capsule.parked_at_port = port_key
end

local function mark_capsule_unparked(capsule)
    if not capsule then return end
    local cap_id = capsule.capsule_id or capsule.id
    if not cap_id then return end

    storage.parked_by_port = storage.parked_by_port or {}

    if capsule.parked_at_port then
        local bucket = storage.parked_by_port[capsule.parked_at_port]
        if bucket then
            bucket[cap_id] = nil
            if next(bucket) == nil then
                storage.parked_by_port[capsule.parked_at_port] = nil
            end
        end
        capsule.parked_at_port = nil
    end

    if capsule.from_port_key then
        local bucket = storage.parked_by_port[capsule.from_port_key]
        if bucket then
            bucket[cap_id] = nil
            if next(bucket) == nil then
                storage.parked_by_port[capsule.from_port_key] = nil
            end
        end
    end
end

function capsule_runner.get_capsule_count_at_entity(unit_number)
    return capsule_queries.get_capsule_count_at_entity(unit_number)
end

function capsule_runner.has_capacity(from_port_key, target_port_key)
    local target_node = storage.flow_nodes and storage.flow_nodes[target_port_key]
    if target_node and (target_node.is_beam_node or target_node.is_kinetic) then
        return true
    end

    local from_unit = capsule_queries.get_port_info(from_port_key)
    local target_unit = capsule_queries.get_port_info(target_port_key)

    if not target_unit then return false end
    if from_unit == target_unit then
        return true
    end

    local max_cap = 1
    if storage.diverter_settings and storage.diverter_settings[target_unit] then
        max_cap = diverter_settings.get_capacity(target_unit)
    end

    local count = capsule_queries.get_capsule_count_at_entity(target_unit)
    return count < max_cap
end

function capsule_runner.wake_parked_capsules(target)
    if not storage.parked_by_port then return end

    local function wake_bucket(port_key)
        local bucket = storage.parked_by_port and storage.parked_by_port[port_key]
        if not bucket then return end

        for cap_id in pairs(bucket) do
            local capsule = storage.capsules and storage.capsules[cap_id]
            if capsule and capsule.to_port_key == nil then
                capsule.next_retry_tick = nil
                capsule.last_failed_hub = nil
                capsule.last_port_key = nil
            end
        end
    end

    if not target then
        for pkey in pairs(storage.parked_by_port) do
            wake_bucket(pkey)
        end
        return
    end

    local target_unit = nil
    local target_port_key = nil

    if type(target) == "string" then
        target_port_key = target
        target_unit = capsule_queries.get_port_info(target)
    elseif type(target) == "number" then
        target_unit = target
    elseif type(target) == "table" then
        for k, v in pairs(target) do
            local key = (type(k) == "string" and k) or (type(v) == "string" and v)
            if key then
                capsule_runner.wake_parked_capsules(key)
            end
        end
        return
    end

    for k in pairs(scratch_ports_to_wake) do
        scratch_ports_to_wake[k] = nil
    end

    local function add_port(pkey)
        if pkey then
            scratch_ports_to_wake[pkey] = true
        end
    end

    if target_port_key then
        add_port(target_port_key)
        local neighbors = storage.flow_connections and storage.flow_connections[target_port_key]
        if neighbors then
            for neighbor_key in pairs(neighbors) do
                add_port(neighbor_key)
            end
        end
    end

    if target_unit then
        local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[target_unit]
        if unit_ports then
            for i = 1, #unit_ports do
                local pkey = unit_ports[i]
                add_port(pkey)
                local neighbors = storage.flow_connections and storage.flow_connections[pkey]
                if neighbors then
                    for neighbor_key in pairs(neighbors) do
                        add_port(neighbor_key)
                    end
                end
            end
        end

        for parked_pkey in pairs(storage.parked_by_port) do
            local p_node = storage.flow_nodes and storage.flow_nodes[parked_pkey]
            if p_node and (p_node.hit_receiver == target_unit or p_node.beam_owner == target_unit) then
                add_port(parked_pkey)
                if p_node.hit_receiver == target_unit and p_node.beam_owner then
                    local s_ports = storage.flow_unit_ports and storage.flow_unit_ports[p_node.beam_owner]
                    if s_ports then
                        for sp = 1, #s_ports do
                            add_port(s_ports[sp])
                        end
                    end
                end
            end
        end
    end

    for pkey in pairs(scratch_ports_to_wake) do
        wake_bucket(pkey)
    end
end

function capsule_runner.remove_capsule(capsule_id)
    local capsule = storage.capsules and storage.capsules[capsule_id]
    if capsule then
        mark_capsule_unparked(capsule)
    end
    local target_key = capsule and capsule.from_port_key
    capsule_queries.remove_capsule(capsule_id)
    capsule_runner.wake_parked_capsules(target_key)
end

function capsule_runner.get_capsule_location(capsule_id)
    if not storage.capsules then return nil, nil end
    local capsule = storage.capsules[capsule_id]
    if not capsule then return nil, nil end

    local pkey = capsule.from_port_key
    local node = pkey and storage.flow_nodes and storage.flow_nodes[pkey]
    if node then
        local surf = game.surfaces[node.surface_name]
        if surf and surf.valid then
            return { x = node.pos.x, y = node.pos.y }, surf
        end
    end

    if capsule.last_pos and capsule.surface_name then
        local surf = game.surfaces[capsule.surface_name]
        if surf and surf.valid then
            return capsule.last_pos, surf
        end
    end

    return nil, nil
end

--------------------------------------------------------------------------------
-- STRICT DIVERTER FILTER & HOP VALIDATION
--------------------------------------------------------------------------------
local function get_item_name_and_quality(item_spec)
    if not item_spec then return nil, "normal" end
    if type(item_spec) == "table" then
        return item_spec.name, item_spec.quality or "normal"
    elseif type(item_spec) == "string" then
        return item_spec, "normal"
    end
    return nil, "normal"
end

local function matches_filter_item(payload_item, payload_quality, slot_item, slot_comp, slot_quality)
    if slot_item and slot_item ~= "" then
        local payload_name, p_qual = get_item_name_and_quality(payload_item)
        local slot_name = (type(slot_item) == "table" and slot_item.name) or slot_item
        if payload_name ~= slot_name then
            return false
        end
    end

    local comp = slot_comp or "Any Quality"
    if comp == "Any Quality" then
        return true
    end

    local payload_name, p_qual = get_item_name_and_quality(payload_item)
    if payload_quality then p_qual = payload_quality end

    local p_rank = QUALITY_RANKS[p_qual or "normal"] or 1
    local s_rank = QUALITY_RANKS[slot_quality or "normal"] or 1

    if comp == "=" or comp == "==" then
        return p_rank == s_rank
    elseif comp == "≥" or comp == ">=" then
        return p_rank >= s_rank
    elseif comp == "≤" or comp == "<=" then
        return p_rank <= s_rank
    elseif comp == ">" then
        return p_rank > s_rank
    elseif comp == "<" then
        return p_rank < s_rank
    elseif comp == "≠" or comp == "!=" then
        return p_rank ~= s_rank
    end

    return p_rank == s_rank
end

local function get_compiled_filter(port_setting)
    local compiled = port_setting._compiled
    if compiled ~= nil then
        return compiled
    end

    if not port_setting.use_filters then
        compiled = false
        port_setting._compiled = compiled
        return compiled
    end

    local filter_mode = port_setting.filter_mode or "whitelist"
    local is_blacklist = (filter_mode == "blacklist")
    local filters = port_setting.filters

    local active_slots = {}
    if filters then
        for i = 1, 5 do
            local slot = filters[i]
            if slot then
                local item = slot.item or slot.signal
                local comp = slot.comparator or "Any Quality"
                local qual = slot.quality or "normal"
                if item ~= nil or comp ~= "Any Quality" then
                    table.insert(active_slots, { item = item, comp = comp, quality = qual })
                end
            end
        end
    end

    compiled = {
        is_blacklist = is_blacklist,
        active_slots = active_slots
    }
    port_setting._compiled = compiled
    return compiled
end

local function evaluates_port_filter(port_setting, payload_item, payload_quality)
    if not port_setting then return true end

    local compiled = get_compiled_filter(port_setting)
    if compiled == false then
        return true
    end

    if not payload_item and #compiled.active_slots == 0 then
        return true
    end

    local active_slots = compiled.active_slots
    local num_active = #active_slots

    if num_active == 0 then
        return compiled.is_blacklist
    end

    local any_slot_matched = false
    for i = 1, num_active do
        local slot = active_slots[i]
        local slot_matched = matches_filter_item(payload_item, payload_quality, slot.item, slot.comp, slot.quality)

        if slot_matched then
            any_slot_matched = true
            if not compiled.is_blacklist then
                return true
            end
        end
    end

    if compiled.is_blacklist then
        return not any_slot_matched
    else
        return any_slot_matched
    end
end

local function check_diverter_port_filter(port_key, payload_item, payload_quality)
    if not port_key then return true end
    local diverter_settings_store = storage.diverter_settings
    if not diverter_settings_store then return true end

    local unit_number, port_index = capsule_queries.get_port_info(port_key)
    if not unit_number then return true end

    local d_settings = diverter_settings_store[unit_number]
    if not d_settings then return true end

    local port_setting = d_settings.ports and d_settings.ports[port_index]
    if not port_setting then return true end

    return evaluates_port_filter(port_setting, payload_item, payload_quality)
end

local function is_hop_allowed_by_diverter_filters(from_port_key, hop_key, payload_item, payload_quality)
    if not check_diverter_port_filter(hop_key, payload_item, payload_quality) then
        return false
    end
    if not check_diverter_port_filter(from_port_key, payload_item, payload_quality) then
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- ZERO-ALLOCATION PATHFINDING & CANDIDATE RESOLUTION
--------------------------------------------------------------------------------
local function get_candidate_hops(from_port_key, tier)
    tier = tier or 1
    local keys = scratch_cand_keys[tier]
    local vias = scratch_cand_vias[tier]
    local is_exts = scratch_cand_is_ext[tier]
    local old_count = scratch_cand_counts[tier] or 0

    local count = 0
    local node = storage.flow_nodes and storage.flow_nodes[from_port_key]
    if node then
        local unit_number = node.unit_number

        if node.cross_transit then
            local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
            if unit_ports then
                for i = 1, #unit_ports do
                    local port_key = unit_ports[i]
                    local ext_neighbors = storage.flow_connections and storage.flow_connections[port_key]
                    if ext_neighbors then
                        for ext_key in pairs(ext_neighbors) do
                            local ext_node = storage.flow_nodes and storage.flow_nodes[ext_key]
                            if ext_node and ext_node.unit_number ~= unit_number then
                                count = count + 1
                                keys[count] = ext_key
                                vias[count] = port_key
                                is_exts[count] = true
                            end
                        end
                    end
                end
            end
        else
            if node.capsule_transmit and node.group ~= nil then
                local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
                if unit_ports then
                    for i = 1, #unit_ports do
                        local int_key = unit_ports[i]
                        if int_key ~= from_port_key then
                            local int_node = storage.flow_nodes and storage.flow_nodes[int_key]
                            if int_node and int_node.capsule_transmit and int_node.group == node.group then
                                count = count + 1
                                keys[count] = int_key
                                vias[count] = from_port_key
                                is_exts[count] = false
                            end
                        end
                    end
                end
            end

            local ext_neighbors = storage.flow_connections and storage.flow_connections[from_port_key]
            if ext_neighbors then
                for ext_key in pairs(ext_neighbors) do
                    local ext_node = storage.flow_nodes and storage.flow_nodes[ext_key]
                    if ext_node and ext_node.unit_number ~= unit_number then
                        count = count + 1
                        keys[count] = ext_key
                        vias[count] = from_port_key
                        is_exts[count] = true
                    end
                end
            end
        end
    end

    for i = count + 1, old_count do
        keys[i] = nil
        vias[i] = nil
        is_exts[i] = nil
    end

    scratch_cand_counts[tier] = count
    return count
end

local function is_hop_valid(from_port_key, target_port_key, payload_item, payload_quality, depth, capsule_id)
    depth = depth or 1
    if depth > 3 then return false end

    local from_node = storage.flow_nodes and storage.flow_nodes[from_port_key]
    local target_node = storage.flow_nodes and storage.flow_nodes[target_port_key]
    if not (from_node and target_node) then return false end

    if not capsule_runner.has_capacity(from_port_key, target_port_key) then
        return false
    end

    if not is_hop_allowed_by_diverter_filters(from_port_key, target_port_key, payload_item, payload_quality) then
        return false
    end
    local target_unit = tonumber(target_node.unit_number) or capsule_queries.get_port_info(target_port_key)
    local is_target_projector = (target_unit and storage.active_projectors and storage.active_projectors[target_unit] ~= nil)
        or (target_unit and storage.projector_settings and storage.projector_settings[target_unit] ~= nil)
        or target_node.is_kinetic
        or target_node.is_beam_node
        or target_node.is_muzzle
        or target_node.kinetic_transmit

    if is_target_projector and not is_electromagnetic_capsule(capsule_id) then
        return false
    end

    if not (target_node.capsule_transmit or target_node.cross_transit or target_node.emitter or target_node.kinetic_transmit) then
        return false
    end

    if target_node.emitter and target_node.emitter ~= 0 and not target_node.kinetic_transmit then
        local target_emitter_lvl = flow_engine.get_node_emitter_level(target_node)
        if target_emitter_lvl == 0 then
            return false
        end
    end

    local is_internal = (from_node.unit_number == target_node.unit_number)
    if is_internal then
        if from_node.emitter and target_node.emitter then
            local from_emitter_lvl = flow_engine.get_node_emitter_level(from_node)
            local target_emitter_lvl = flow_engine.get_node_emitter_level(target_node)
            if from_emitter_lvl > 0 and target_emitter_lvl < 0 then
                return false
            end
        end

        local exit_count = get_candidate_hops(target_port_key, 3)
        local has_valid_exit = false
        for i = 1, exit_count do
            local exit_key = scratch_cand_keys[3][i]
            local exit_node = storage.flow_nodes and storage.flow_nodes[exit_key]
            if exit_node and exit_node.unit_number ~= target_node.unit_number then
                if is_hop_valid(target_port_key, exit_key, payload_item, payload_quality, depth + 1, capsule_id) then
                    has_valid_exit = true
                    break
                end
            end
        end
        if not has_valid_exit then
            return false
        end
    end

    return true
end

function capsule_runner.select_next_target(capsule)
    local from_port_key = capsule.from_port_key
    local current_node = storage.flow_nodes and storage.flow_nodes[from_port_key]
    if not current_node then return nil end

    local unit_number = tonumber(current_node.unit_number) or capsule_queries.get_port_info(from_port_key)
    local cap_id = capsule.capsule_id or capsule.id

    -- 1. Ballistic Kinetic Trajectory: straight-line forward propagation across prominent hop nodes
    if current_node.is_kinetic and not current_node.is_muzzle then
        if current_node.is_endpoint then
            return nil
        end

        local beam_owner = current_node.beam_owner or unit_number
        local dir = current_node.dir
        if not dir then return nil end

        local cur_dist = current_node.dist or 0
        local surface = game.surfaces[current_node.surface_name]
        local owner_entity = storage.active_projectors and storage.active_projectors[beam_owner]

        local next_prominent_key = nil
        local obstacle_pos = nil
        local hit_player_entity = nil

        for d = cur_dist + 1, cur_dist + HOP_DISTANCE do
            local cand_key = make_beam_port_key(beam_owner, dir.x, dir.y, d)
            local cand_node = storage.flow_nodes and storage.flow_nodes[cand_key]
            local tx = current_node.pos.x + dir.x * (d - cur_dist)
            local ty = current_node.pos.y + dir.y * (d - cur_dist)

            if surface and surface.valid then
                local player_target = check_player_collision(surface, tx, ty, capsule)
                if player_target then
                    found_obstacle = player_target
                    obstacle_pos = { x = tx, y = ty }
                    hit_player_entity = player_target
                    break
                end

                local occ = flow_engine.check_tile_obstruction(surface, tx, ty, owner_entity)
                if occ.blocked and not occ.is_receiver then
                    found_obstacle = occ.obstacle or true
                    obstacle_pos = { x = tx, y = ty }
                    break
                end
            end

            local cand_level = storage.kinetic_levels and storage.kinetic_levels[cand_key] or 0
            if not cand_node or cand_level <= 0 then
                found_obstacle = true
                obstacle_pos = { x = tx, y = ty }
                break
            end

            if cand_node.is_prominent_kinetic or cand_node.is_endpoint then
                next_prominent_key = cand_key
                break
            end
        end

        if found_obstacle and obstacle_pos and surface and surface.valid then
            if hit_player_entity and hit_player_entity.valid then
                local q_lvl = (current_node and current_node.q_level) or 0
                local dmg = math.floor((projector_settings.PROJECTILE_DAMAGE or 250) * (1 + 0.3 * q_lvl))
                local p_force = (owner_entity and owner_entity.valid and owner_entity.force) or (hit_player_entity.force) or "neutral"
                hit_player_entity.damage(dmg, p_force, "impact")
            end
            mark_capsule_unparked(capsule)
            local crash_port_key = from_port_key
            hub_spill.spill_capsule(cap_id, surface, obstacle_pos, nil, true)
            capsule_runner.wake_parked_capsules(crash_port_key)
            return nil
        end

        if next_prominent_key then
            if capsule.beam_flight then
                capsule.beam_flight.current_hop = (capsule.beam_flight.current_hop or 1) + 1
            end
            return next_prominent_key
        end

        return nil
    end

    -- 2. Projector Launch Muzzle Dispatch: transition from passive intake ports onto the kinetic beam
    if storage.active_projectors and storage.active_projectors[unit_number] and is_electromagnetic_capsule(capsule) then
        local proj_entity = storage.active_projectors[unit_number]
        if not (proj_entity and proj_entity.valid and projector_settings.is_projector_active(proj_entity)) then
            return nil
        end
        if not projector_settings.can_fire(proj_entity) then
            return nil
        end

        local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]
        local muzzle_pkey = nil
        local muzzle_node = nil
        if unit_ports then
            for i = 1, #unit_ports do
                local pkey = unit_ports[i]
                local pnode = storage.flow_nodes and storage.flow_nodes[pkey]
                if pnode and (pnode.is_muzzle or pnode.kinetic_transmit) then
                    muzzle_pkey = pkey
                    muzzle_node = pnode
                    break
                end
            end
        end

        if muzzle_node and muzzle_node.dir then
            local muzzle_level = flow_engine.get_kinetic_level(muzzle_pkey)
            if muzzle_level > 0 then
                local dx = muzzle_node.dir.x
                local dy = muzzle_node.dir.y

                local endpoint_key, endpoint_node = get_beam_endpoint(unit_number, dx, dy)
                if not endpoint_node then
                    return nil
                end

                local max_cap = projector_settings.MAX_ENDPOINT_CAPSULES or 2
                local endpoint_count = count_endpoint_capsules(unit_number, endpoint_key, endpoint_node)
                if endpoint_count >= max_cap then
                    return nil
                end
                for d = 1, HOP_DISTANCE do
                    local cand_key = make_beam_port_key(unit_number, dx, dy, d)
                    local cand_node = storage.flow_nodes and storage.flow_nodes[cand_key]
                    local cand_level = storage.kinetic_levels and storage.kinetic_levels[cand_key] or 0
                    local tx = muzzle_node.pos.x + dx * d
                    local ty = muzzle_node.pos.y + dy * d
                    local surface = game.surfaces[muzzle_node.surface_name]

                    if surface and surface.valid then
                        local player_target = check_player_collision(surface, tx, ty, capsule)
                        if player_target then
                            local launch_cost = projector_settings.get_launch_energy(proj_entity)
                            proj_entity.energy = math.max(0, proj_entity.energy - launch_cost)
                            storage.projector_last_fired = storage.projector_last_fired or {}
                            storage.projector_last_fired[unit_number] = game.tick
                            if storage.projector_ready_states then
                                storage.projector_ready_states[unit_number] = false
                            end

                            local q_lvl = muzzle_node.q_level or 0
                            local dmg = math.floor((projector_settings.PROJECTILE_DAMAGE or 250) * (1 + 0.3 * q_lvl))
                            local p_force = (proj_entity and proj_entity.valid and proj_entity.force) or (player_target.force) or "neutral"
                            player_target.damage(dmg, p_force, "impact")
                            mark_capsule_unparked(capsule)
                            hub_spill.spill_capsule(cap_id, surface, { x = tx, y = ty }, nil, true)
                            capsule_runner.wake_parked_capsules(from_port_key)
                            return nil
                        end
                    end

                    if cand_node and cand_level > 0 then
                        if cand_node.is_prominent_kinetic or cand_node.is_endpoint then
                            if capsule_runner.has_capacity(from_port_key, cand_key) then
                                local launch_cost = projector_settings.get_launch_energy(proj_entity)
                                proj_entity.energy = math.max(0, proj_entity.energy - launch_cost)
                                storage.projector_last_fired = storage.projector_last_fired or {}
                                storage.projector_last_fired[unit_number] = game.tick
                                if storage.projector_ready_states then
                                    storage.projector_ready_states[unit_number] = false
                                end

                                init_capsule_beam_flight(capsule, muzzle_node)
                                return cand_key
                            end
                        end
                    end
                end
            end
        end

        return nil
    end
    local payload_item = capsule.dominant_item
    local payload_quality = capsule.dominant_quality or "normal"
    if not payload_item then
        local cap_data = cap_id and capsule_manager.get(cap_id)
        payload_item = cap_data and cap_data.dominant_item
        payload_quality = (cap_data and cap_data.dominant_quality) or "normal"
        if not payload_item and cap_id then
            payload_item = capsule_renderer.get_dominant_item(cap_id)
            if payload_item then
                capsule.dominant_item = payload_item
                capsule.dominant_quality = payload_quality
            end
        end
    end

    local cand_count = get_candidate_hops(from_port_key, 1)
    if cand_count == 0 then return nil end

    local max_drop = 0
    scratch_best_count = 0

    for c = 1, cand_count do
        local cand_key = scratch_cand_keys[1][c]
        local via_port = scratch_cand_vias[1][c]

        if cand_key ~= capsule.last_port_key then
            local valid_hop = false
            if current_node.cross_transit then
                valid_hop = is_hop_valid(via_port, cand_key, payload_item, payload_quality, 1, cap_id)
            else
                valid_hop = is_hop_valid(from_port_key, cand_key, payload_item, payload_quality, 1, cap_id)
            end

            if valid_hop then
                local cand_node = storage.flow_nodes and storage.flow_nodes[cand_key]
                local level_cand = storage.flow_levels and storage.flow_levels[cand_key] or 0

                local exit_port = (current_node.cross_transit and via_port) or from_port_key
                local level_exit = storage.flow_levels and storage.flow_levels[exit_port] or 0

                local drop = level_exit - level_cand

                if current_node.emitter and cand_node and cand_node.emitter then
                    local current_lvl = flow_engine.get_node_emitter_level(current_node)
                    local cand_lvl = flow_engine.get_node_emitter_level(cand_node)
                    if current_lvl < 0 and cand_lvl > 0 then
                        drop = math.huge
                    end
                end

                local is_internal = (cand_node and cand_node.unit_number == current_node.unit_number)
                if is_internal and cand_node then
                    local best_downstream = -math.huge
                    local exit_count = get_candidate_hops(cand_key, 2)
                    for e = 1, exit_count do
                        local exit_key = scratch_cand_keys[2][e]
                        local exit_node = storage.flow_nodes and storage.flow_nodes[exit_key]
                        if exit_node and exit_node.unit_number ~= current_node.unit_number then
                            if is_hop_valid(cand_key, exit_key, payload_item, payload_quality, 2, cap_id) then
                                local exit_level = storage.flow_levels and storage.flow_levels[exit_key] or 0

                                local cand_emitter_lvl = flow_engine.get_node_emitter_level(cand_node)
                                local effective_from = (cand_emitter_lvl > 0) and cand_emitter_lvl or level_exit
                                local d = effective_from - exit_level
                                if d > best_downstream then
                                    best_downstream = d
                                end
                            end
                        end
                    end
                    if best_downstream ~= -math.huge then
                        drop = best_downstream
                    end
                end

                if drop > max_drop then
                    max_drop = drop
                    scratch_best_keys[1] = cand_key
                    scratch_best_vias[1] = via_port
                    scratch_best_is_ext[1] = (not is_internal)
                    scratch_best_count = 1
                elseif drop == max_drop and drop > 0 then
                    local current_best_is_ext = scratch_best_is_ext[1]
                    local cand_is_ext = not is_internal
                    if cand_is_ext and not current_best_is_ext then
                        scratch_best_keys[1] = cand_key
                        scratch_best_vias[1] = via_port
                        scratch_best_is_ext[1] = true
                        scratch_best_count = 1
                    elseif not cand_is_ext and current_best_is_ext then
                        -- prefer external
                    else
                        scratch_best_count = scratch_best_count + 1
                        scratch_best_keys[scratch_best_count] = cand_key
                        scratch_best_vias[scratch_best_count] = via_port
                        scratch_best_is_ext[scratch_best_count] = cand_is_ext
                    end
                end
            end
        end
    end

    if scratch_best_count == 0 then
        return nil
    end

    local idx = (scratch_best_count == 1) and 1 or math.random(1, scratch_best_count)
    local chosen_key = scratch_best_keys[idx]
    local chosen_via = scratch_best_vias[idx]

    if current_node.cross_transit and chosen_via and chosen_via ~= capsule.from_port_key then
        capsule.from_port_key = chosen_via
        capsule_queries.update_capsule_occupancy(capsule)
    end

    return chosen_key
end

--------------------------------------------------------------------------------
-- RECEIVER CATCHMENT & INJECTION
--------------------------------------------------------------------------------
function capsule_runner.catch_in_receiver(capsule, receiver_entity)
    if not (capsule and receiver_entity and receiver_entity.valid) then return false end
    local r_unit = receiver_entity.unit_number
    local r_ports = storage.flow_unit_ports and storage.flow_unit_ports[r_unit]
    if not r_ports then return false end

    local best_ext_key = nil
    local best_r_pkey = nil
    local best_drop = -math.huge

    for _, r_pkey in ipairs(r_ports) do
        local r_node = storage.flow_nodes and storage.flow_nodes[r_pkey]
        if r_node and not (r_node.is_muzzle or r_node.kinetic_transmit) and not r_node.is_beam_node then
            local neighbors = storage.flow_connections and storage.flow_connections[r_pkey]
            if neighbors then
                for ext_key in pairs(neighbors) do
                    local ext_node = storage.flow_nodes and storage.flow_nodes[ext_key]
                    if ext_node and ext_node.unit_number ~= r_unit and ext_node.capsule_transmit then
                        if capsule_runner.has_capacity(r_pkey, ext_key) then
                            local ext_level = storage.flow_levels and storage.flow_levels[ext_key] or 0
                            local drop = -ext_level
                            if drop >= 0 and drop > best_drop then
                                best_drop = drop
                                best_ext_key = ext_key
                                best_r_pkey = r_pkey
                            end
                        end
                    end
                end
            end
        end
    end

    if best_ext_key and best_r_pkey then
        mark_capsule_unparked(capsule)
        local prev_key = capsule.from_port_key
        capsule.last_port_key = best_r_pkey
        capsule.from_port_key = best_ext_key
        capsule.to_port_key = nil
        capsule.beam_flight = nil

        local ext_node = storage.flow_nodes and storage.flow_nodes[best_ext_key]
        if ext_node and ext_node.pos then
            capsule.last_pos = { x = ext_node.pos.x, y = ext_node.pos.y }
            capsule.surface_name = ext_node.surface_name
        end

        capsule_queries.update_capsule_occupancy(capsule)
        capsule_runner.wake_parked_capsules(prev_key)
        capsule_runner.wake_parked_capsules(best_ext_key)
        capsule_runner.wake_parked_capsules(r_unit)

        local prev_node = storage.flow_nodes and storage.flow_nodes[prev_key]
        local sender_unit = prev_node and (prev_node.beam_owner or prev_node.unit_number)
        if sender_unit and sender_unit ~= r_unit then
            capsule_runner.wake_parked_capsules(sender_unit)
        end
        play_catchment_effects(receiver_entity.surface, receiver_entity.position)
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- HUB ARRIVAL & OUTBOUND PACKING
--------------------------------------------------------------------------------
function capsule_runner.handle_arrival(capsule, id)
    local from_key = capsule.from_port_key
    local node = from_key and storage.flow_nodes and storage.flow_nodes[from_key]
    local bf = capsule.beam_flight

    local is_beam_endpoint = false
    if node then
        if (node.is_beam_node or node.is_prominent_kinetic) and node.is_endpoint then
            is_beam_endpoint = true
        end
    elseif bf and bf.current_hop and bf.total_hops and bf.current_hop >= bf.total_hops then
        is_beam_endpoint = true
    end

    if is_beam_endpoint then
        local hit_receiver_unit = (node and node.hit_receiver) or (bf and bf.hit_receiver_unit)
        local receiver_entity = hit_receiver_unit and storage.active_projectors and storage.active_projectors[hit_receiver_unit]
        local surface = (node and game.surfaces[node.surface_name])
            or (bf and bf.surface_name and game.surfaces[bf.surface_name])
            or (capsule.surface_name and game.surfaces[capsule.surface_name])
        local term_pos = (node and node.pos) or (bf and bf.terminal_pos) or capsule.last_pos

        if receiver_entity and receiver_entity.valid then
            if capsule_runner.catch_in_receiver(capsule, receiver_entity) then
                capsule.beam_flight = nil
                return true
            end
            return false
        else
            capsule.beam_flight = nil
            if surface and surface.valid and term_pos then
                local player_target = check_player_collision(surface, term_pos.x, term_pos.y, capsule)
                if player_target and player_target.valid then
                    local dmg = projector_settings.PROJECTILE_DAMAGE or 250
                    local p_force = (player_target.force) or "neutral"
                    player_target.damage(dmg, p_force, "impact")
                end
                hub_spill.spill_capsule(id, surface, term_pos, nil, true)
            else
                capsule_runner.remove_capsule(id)
            end
            return true
        end
    end

    if not from_key then return false end
    if not node then return false end

    local unit_num = capsule_queries.get_port_info(from_key)
    if capsule.source_hub and unit_num ~= capsule.source_hub then
        capsule.source_hub = nil
    end

    local hub_entity = storage.active_hubs and storage.active_hubs[node.unit_number]
    if hub_entity and hub_entity.valid and capsule.source_hub ~= node.unit_number then
        local unpacked = hub_unpacking.capture(capsule, hub_entity)
        if unpacked then
            capsule_runner.remove_capsule(id)
            return true
        end
    end

    return false
end

function capsule_runner.find_best_hub_outbound_port(hub_entity, capsule_id)
    if not (hub_entity and hub_entity.valid) then return nil, nil, 0 end

    local unit_number = hub_entity.unit_number
    local unit_ports = storage.flow_unit_ports and storage.flow_unit_ports[unit_number]

    local ports = port_defs.get_ports(hub_entity)
    local num_ports = ports and #ports or (unit_ports and #unit_ports or 0)
    if num_ports == 0 then return nil, nil, 0 end

    local fallback_port_key = (unit_ports and unit_ports[1]) or (unit_number .. ":1")
    local best_port_key = nil
    local max_drop = 0
    local best_flow_level = 0

    for port_index = 1, num_ports do
        local pkey = (unit_ports and unit_ports[port_index]) or (unit_number .. ":" .. port_index)
        local touching_level = storage.flow_levels and storage.flow_levels[pkey] or 0
        local neighbors = storage.flow_connections and storage.flow_connections[pkey]

        if neighbors and next(neighbors) ~= nil then
            for n_key in pairs(neighbors) do
                local n_node = storage.flow_nodes and storage.flow_nodes[n_key]
                if n_node and (n_node.capsule_transmit or n_node.cross_transit or n_node.emitter) then
                    local target_level = storage.flow_levels and storage.flow_levels[n_key] or 0
                    local drop = touching_level - target_level
                    if drop > max_drop then
                        max_drop = drop
                        best_port_key = pkey
                        best_flow_level = target_level
                    end
                end
            end
        end
    end

    return best_port_key, fallback_port_key, best_flow_level
end

function capsule_runner.inject_from_hub(capsule_id, entity, passenger)
    if not (entity and entity.valid) then return false end

    local best_port_key, fallback_port_key, flow_level = capsule_runner.find_best_hub_outbound_port(entity, capsule_id)
    if not best_port_key then
        return false
    end
    local target_port_key = best_port_key

    local cap_data = capsule_manager.get(capsule_id)
    local dominant_item = (cap_data and cap_data.dominant_item) or capsule_renderer.get_dominant_item(capsule_id)
    local dominant_quality = (cap_data and cap_data.dominant_quality) or "normal"

    local new_capsule = {
        id = capsule_id,
        capsule_id = capsule_id,
        capsule_type = (cap_data and cap_data.capsule_type) or (cap_data and cap_data.definition and cap_data.definition.name),
        dominant_item = dominant_item,
        dominant_quality = dominant_quality,
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
    mark_capsule_parked(new_capsule)
    capsule_runner.wake_parked_capsules(target_port_key)

    debug_print("[v2 Flow] Successfully packed capsule #" .. tostring(capsule_id) .. " (" .. tostring(dominant_item) .. " - " .. tostring(dominant_quality) .. ") onto v2 flow engine at hub " .. tostring(entity.unit_number) .. " port " .. tostring(target_port_key) .. " (flow level: " .. tostring(flow_level) .. ")")

    return true
end

function capsule_runner.emergency_eject(player)
    if not (storage.capsules and player and player.valid) then return end

    for id, capsule in pairs(storage.capsules) do
        if capsule.passenger == player then
            local pos, surface = capsule_runner.get_capsule_location(id)
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

            capsule_runner.remove_capsule(id)
            break
        end
    end
end

--------------------------------------------------------------------------------
-- LIMINAL SPAWN & TICK EXECUTION ENGINE
--------------------------------------------------------------------------------
local function handle_liminal_entity_spawn(entity)
    if not (entity and entity.valid) then return end

    local surface = entity.surface
    if not (surface and surface.valid and surface.name == "liminal_surface") then return end

    if entity.name == "invisible-capsule-holder" or entity.name == "visible-capsule-holder" then
        return
    end

    local holder = liminal_surface.find_holder_near(entity.position, 3.5)
    if not (holder and holder.valid) then
        entity.destroy()
        return
    end

    local capsule_id = holder.unit_number
    local capsule_data = capsule_manager.get(capsule_id)
    if not capsule_data then
        entity.destroy()
        return
    end

    local def = capsule_data.definition
    local spill_contents = def and def.spill_contents
    local units_allowed = true
    if type(spill_contents) == "table" and spill_contents.units == false then
        units_allowed = false
    elseif spill_contents == false then
        units_allowed = false
    end

    if not units_allowed then
        entity.destroy()
        return
    end

    local target_pos, target_surface = capsule_runner.get_capsule_location(capsule_id)
    if target_pos and target_surface and target_surface.valid then
        local safe_pos = target_surface.find_non_colliding_position(entity.name, target_pos, 6, 0.5) or target_pos
        local params = {
            name = entity.name,
            position = safe_pos,
            force = entity.force
        }
        if entity.quality then params.quality = entity.quality end

        local created = target_surface.create_entity(params)
        if created and created.valid then
            if entity.health and created.health then
                created.health = entity.health
            end
        end

        entity.destroy()
    else
        entity.destroy()
    end
end

function capsule_runner.update_capsules(current_tick)
    if not storage.capsules then return end

    capsule_renderer.prepare_frame()
    prepare_player_targets()

    for id, capsule in pairs(storage.capsules) do
        local from_key = capsule.from_port_key
        local node = from_key and storage.flow_nodes and storage.flow_nodes[from_key]
        local bf = capsule.beam_flight

        local is_woken = (capsule.next_retry_tick == nil)
        local is_stagger_tick = ((current_tick + id) % STAGGER_TICKS == 0)

        if not node then
            if is_woken or is_stagger_tick then
                capsule.next_retry_tick = current_tick + STAGGER_TICKS
                if bf and bf.hop_positions and bf.current_hop then
                local surface = game.surfaces[bf.surface_name or capsule.surface_name or "nauvis"]

                if bf.current_hop >= bf.total_hops then
                    capsule_runner.handle_arrival(capsule, id)
                else
                    local next_pos = bf.hop_positions[bf.current_hop] or bf.terminal_pos

                    local obstructed = false
                    local obst_pos = nil
                    local hit_player_entity = nil
                    if surface and surface.valid and capsule.last_pos and next_pos then
                        local sx, sy = capsule.last_pos.x, capsule.last_pos.y
                        local dx = (next_pos.x > sx and 1) or (next_pos.x < sx and -1) or 0
                        local dy = (next_pos.y > sy and 1) or (next_pos.y < sy and -1) or 0
                        local steps = math.max(math.abs(next_pos.x - sx), math.abs(next_pos.y - sy))
                        for step = 1, math.floor(steps) do
                            local cx = sx + dx * step
                            local cy = sy + dy * step

                            local player_target = check_player_collision(surface, cx, cy, capsule)
                            if player_target then
                                obstructed = true
                                obst_pos = { x = cx, y = cy }
                                hit_player_entity = player_target
                                break
                            end

                            local occ = flow_engine.check_tile_obstruction(surface, cx, cy, nil)
                            if occ.blocked and not occ.is_receiver then
                                obstructed = true
                                obst_pos = { x = cx, y = cy }
                                break
                            end
                        end
                    end

                    if obstructed and obst_pos and surface and surface.valid then
                        if hit_player_entity and hit_player_entity.valid then
                            local dmg = projector_settings.PROJECTILE_DAMAGE or 250
                            local p_force = (hit_player_entity.force) or "neutral"
                            hit_player_entity.damage(dmg, p_force, "impact")
                        end
                        mark_capsule_unparked(capsule)
                        local dead_port_key = capsule.from_port_key
                        hub_spill.spill_capsule(id, surface, obst_pos, nil, true)
                        if dead_port_key then
                            capsule_runner.wake_parked_capsules(dead_port_key)
                        end
                    else
                        capsule.last_pos = next_pos
                        play_flight_effects(surface, next_pos)

                        if surface and surface.valid and next_pos then
                            capsule_renderer.render(capsule, id, next_pos, surface)
                        end
                        capsule.next_retry_tick = current_tick + STAGGER_TICKS
                    end
                end
            else
                mark_capsule_unparked(capsule)
                local pos = capsule.last_pos
                local surface = capsule.surface_name and game.surfaces[capsule.surface_name]
                local dead_port_key = capsule.from_port_key
                if pos and surface and surface.valid then
                    hub_spill.spill_capsule(id, surface, pos, nil, true)
                else
                    capsule_runner.remove_capsule(id)
                end
                if dead_port_key then
                    capsule_runner.wake_parked_capsules(dead_port_key)
                end
            end
            end
        else
            capsule.last_pos = { x = node.pos.x, y = node.pos.y }
            capsule.surface_name = node.surface_name

            if is_woken or is_stagger_tick then
                capsule.next_retry_tick = current_tick + STAGGER_TICKS

                local hops_done = 0
                while hops_done < MAX_NODE_HOPS_PER_STEP do
                    if capsule_runner.handle_arrival(capsule, id) then
                        break
                    end

                    local next_port_key = capsule_runner.select_next_target(capsule)
                    if not next_port_key then
                        capsule.next_retry_tick = current_tick + PARKED_RETRY_INTERVAL
                        capsule.last_port_key = nil
                        mark_capsule_parked(capsule)
                        break
                    end

                    local next_node = storage.flow_nodes and storage.flow_nodes[next_port_key]
                    if next_node and (next_node.is_beam_node or next_node.is_prominent_kinetic) then
                        local surface = game.surfaces[next_node.surface_name]
                        if not (node.is_beam_node or node.is_prominent_kinetic) then
                            play_dispatch_effects(surface, node.pos)
                        else
                            play_flight_effects(surface, next_node.pos)
                        end
                    end

                    mark_capsule_unparked(capsule)
                    local prev_key = capsule.from_port_key
                    capsule.last_port_key = prev_key
                    capsule.from_port_key = next_port_key
                    capsule.to_port_key = nil

                    capsule_queries.update_capsule_occupancy(capsule)
                    capsule_runner.wake_parked_capsules(prev_key)

                    hops_done = hops_done + 1
                    if (next_node and (next_node.is_beam_node or next_node.is_prominent_kinetic))
                       or (node and (node.is_beam_node or node.is_prominent_kinetic)) then
                        if capsule_runner.handle_arrival(capsule, id) then
                            break
                        end
                        break
                    end

                    local prev_unit = capsule_queries.get_port_info(prev_key)
                    local new_unit = capsule_queries.get_port_info(next_port_key)
                    if prev_unit ~= new_unit then
                        if capsule_runner.handle_arrival(capsule, id) then
                            break
                        end
                        break
                    end
                end
            end

            if storage.capsules[id] then
                local current_node = storage.flow_nodes[capsule.from_port_key]
                if current_node then
                    local surface = game.surfaces[current_node.surface_name]
                    local curr_pos = current_node.pos
                    if surface and surface.valid and curr_pos then
                        if capsule_lifecycle.update(capsule, id, curr_pos, surface) then
                            capsule_runner.wake_parked_capsules(capsule.from_port_key)
                        else
                            capsule_renderer.render(capsule, id, curr_pos, surface)
                        end
                    end
                end
            end
        end
    end
end

function capsule_runner.register_events()
    events.on_event(defines.events.on_trigger_created_entity, function(event)
        handle_liminal_entity_spawn(event.entity)
    end)

    events.on_event(defines.events.on_entity_spawned, function(event)
        handle_liminal_entity_spawn(event.entity)
    end)

    events.on_event(defines.events.script_raised_built, function(event)
        handle_liminal_entity_spawn(event.entity)
    end)

    events.on_event(defines.events.on_built_entity, function(event)
        handle_liminal_entity_spawn(event.entity)
    end)

    events.on_event(defines.events.on_tick, function(event)
        capsule_runner.update_capsules(event.tick)

        if event.tick % 60 == 0 then
            local liminal_surf = game.surfaces["liminal_surface"]
            if liminal_surf and liminal_surf.valid then
                local entities = liminal_surf.find_entities_filtered{
                    type = {"unit", "turret"}
                }
                for _, entity in ipairs(entities) do
                    handle_liminal_entity_spawn(entity)
                end
            end
        end
    end)
end

return capsule_runner