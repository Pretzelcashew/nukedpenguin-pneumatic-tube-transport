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

local STAGGER_TICKS = 6
local MAX_NODE_HOPS_PER_STEP = 3
local PARKED_RETRY_INTERVAL = 10

local QUALITY_RANKS = {
    ["normal"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 3,
    ["epic"] = 4,
    ["legendary"] = 5
}

local capsule_runner = {}

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
    elseif target_port_key then
        local neighbors = storage.flow_connections and storage.flow_connections[target_port_key]
        if neighbors then
            for neighbor_key in pairs(neighbors) do
                add_port(neighbor_key)
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
-- PAYLOAD IDENTITY & STRICT PROJECTOR GATEKEEPING
--------------------------------------------------------------------------------
local function is_electromagnetic_capsule(capsule_id)
    if not capsule_id then return false end
    local cap_data = capsule_manager.get(capsule_id)
    if not cap_data then return false end

    if cap_data.capsule_type == "electromagnetic-capsule" or cap_data.item_name == "electromagnetic-capsule" then
        return true
    end

    if capsule_manager.get_primary_stack then
        local stack = capsule_manager.get_primary_stack(capsule_id)
        if stack and stack.valid_for_read and stack.name == "electromagnetic-capsule" then
            return true
        end
    end

    local holder = cap_data.holder
    if holder and holder.valid and cap_data.primary_slot then
        local inv = holder.get_inventory(defines.inventory.chest)
        if inv and inv.valid then
            local stack = inv[cap_data.primary_slot]
            if stack and stack.valid_for_read and stack.name == "electromagnetic-capsule" then
                return true
            end
        end
    end

    return false
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

    -- Core Invariant 1: Projector & Kinetic Beam strictly restrict access to electromagnetic capsules
    local target_is_projector = storage.active_projectors and storage.active_projectors[target_node.unit_number]
    local target_is_beam = target_node.is_beam_node or target_node.kinetic_transmit
    if target_is_projector or target_is_beam then
        if not is_electromagnetic_capsule(capsule_id) then
            return false
        end

        if target_is_projector then
            local proj_entity = storage.active_projectors[target_node.unit_number]
            if not (proj_entity and proj_entity.valid and projector_settings.is_projector_active(proj_entity)) then
                return false
            end
        end
    end

    if not capsule_runner.has_capacity(from_port_key, target_port_key) then
        return false
    end

    if not is_hop_allowed_by_diverter_filters(from_port_key, target_port_key, payload_item, payload_quality) then
        return false
    end

    if not (target_node.capsule_transmit or target_node.cross_transit or target_node.emitter or target_node.kinetic_transmit) then
        return false
    end

    if target_node.emitter and not target_node.kinetic_transmit then
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

    local unit_number = current_node.unit_number
    local cap_id = capsule.capsule_id or capsule.id

    -- Ballistic Kinetic Trajectory: strictly straight-line unidirectional forward propagation
    if current_node.is_beam_node then
        local beam = storage.projector_beams and storage.projector_beams[current_node.beam_owner]
        if not beam then
            return nil
        end

        if current_node.is_endpoint then
            return nil
        end

        local next_hop_idx = current_node.hop_index + 1
        if beam.hop_keys and next_hop_idx <= #beam.hop_keys then
            local next_key = beam.hop_keys[next_hop_idx]
            local next_node = storage.flow_nodes and storage.flow_nodes[next_key]
            if next_node then
                return next_key
            end
        end

        return nil
    end

    -- Projector Launch Muzzle Dispatch: transition from passive intake ports onto the active kinetic beam
    if storage.active_projectors and storage.active_projectors[unit_number] then
        if not is_electromagnetic_capsule(cap_id) then
            return nil
        end

        local proj_entity = storage.active_projectors[unit_number]
        if not (proj_entity and proj_entity.valid and projector_settings.is_projector_active(proj_entity)) then
            return nil
        end

        local beam = storage.projector_beams and storage.projector_beams[unit_number]
        if beam and beam.hop_keys and #beam.hop_keys > 0 then
            local first_hop_key = beam.hop_keys[1]
            if capsule_runner.has_capacity(from_port_key, first_hop_key) then
                return first_hop_key
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

                -- Suction into Projector Intake Ports
                if cand_node and storage.active_projectors and storage.active_projectors[cand_node.unit_number] then
                    if cand_node.emitter and cand_node.emitter < 0 then
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
        if r_node and not r_node.is_muzzle and not r_node.is_beam_node then
            local neighbors = storage.flow_connections and storage.flow_connections[r_pkey]
            if neighbors then
                for ext_key in pairs(neighbors) do
                    local ext_node = storage.flow_nodes and storage.flow_nodes[ext_key]
                    if ext_node and ext_node.unit_number ~= r_unit and ext_node.capsule_transmit then
                        if capsule_runner.has_capacity(r_pkey, ext_key) then
                            local ext_level = storage.flow_levels and storage.flow_levels[ext_key] or 0
                            local drop = -ext_level
                            if drop > best_drop then
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

        capsule_queries.update_capsule_occupancy(capsule)
        capsule_runner.wake_parked_capsules(prev_key)
        capsule_runner.wake_parked_capsules(best_ext_key)
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- HUB ARRIVAL & OUTBOUND PACKING
--------------------------------------------------------------------------------
function capsule_runner.handle_arrival(capsule, id)
    local from_key = capsule.from_port_key
    if not from_key then return false end

    local node = storage.flow_nodes and storage.flow_nodes[from_key]
    if not node then return false end

    -- Terminal Ballistic Endpoint Check
    if node.is_beam_node and node.is_endpoint then
        local hit_receiver_unit = node.hit_receiver
        local receiver_entity = hit_receiver_unit and storage.active_projectors and storage.active_projectors[hit_receiver_unit]
        local surface = game.surfaces[node.surface_name]
        local term_pos = node.pos

        if receiver_entity and receiver_entity.valid then
            if capsule_runner.catch_in_receiver(capsule, receiver_entity) then
                return true
            end
            -- Receiver connected lines are full; hold capsule safely at endpoint
            return false
        else
            -- Terminal crash landing: beam terminated in open air or receiver was destroyed
            if surface and surface.valid and term_pos then
                hub_spill.spill_capsule(id, surface, term_pos, nil, true)
            else
                capsule_runner.remove_capsule(id)
            end
            return true
        end
    end

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

    for id, capsule in pairs(storage.capsules) do
        local from_key = capsule.from_port_key
        local node = from_key and storage.flow_nodes and storage.flow_nodes[from_key]

        if not node then
            -- Severance or Node Removal Recovery: crash land safely at last known position
            mark_capsule_unparked(capsule)
            local pos = capsule.last_pos
            local surface = capsule.surface_name and game.surfaces[capsule.surface_name]
            if pos and surface and surface.valid then
                hub_spill.spill_capsule(id, surface, pos, nil, true)
            else
                capsule_runner.remove_capsule(id)
            end
        else
            capsule.last_pos = { x = node.pos.x, y = node.pos.y }
            capsule.surface_name = node.surface_name

            local is_beam = (node.is_beam_node == true)
            local is_woken = (capsule.next_retry_tick == nil)
            local is_stagger_tick = ((current_tick + id) % STAGGER_TICKS == 0)

            if is_beam or is_woken or is_stagger_tick then
                capsule.next_retry_tick = is_beam and (current_tick + 1) or (current_tick + STAGGER_TICKS)

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

                    mark_capsule_unparked(capsule)
                    local prev_key = capsule.from_port_key
                    capsule.last_port_key = prev_key
                    capsule.from_port_key = next_port_key
                    capsule.to_port_key = nil

                    capsule_queries.update_capsule_occupancy(capsule)
                    capsule_runner.wake_parked_capsules(prev_key)

                    hops_done = hops_done + 1

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