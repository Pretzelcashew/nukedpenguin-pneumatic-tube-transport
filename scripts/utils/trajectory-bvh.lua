--- Trajectory Segment Bounding Volume Hierarchy (BVH)
-- Designed for high-performance spatial indexing of kinetic trajectories and line paths.
-- Features:
--   1. Surface Isolation: Separate trees per surface index; zero cross-surface query overhead.
--   2. Adaptive Segmentation: Subdivides long or diagonal paths into tight 16-tile leaf AABBs.
--   3. Tight Diagonal Culling: Eliminates massive diagonal bounding box false positives.
--   4. Spatiotemporal Progress Windows: Maps [p_start, p_end] directly to capsule flight ticks.
--   5. Dynamic AABB Tree: Insertion and removal with surface area heuristic (SAH).

local profiler = require("scripts.utils.profiler")

local trajectory_bvh = {}
local bvh_mt = { __index = trajectory_bvh }

local MAX_LEAF_SEGMENT = 16 -- Maximum segment length in tiles before subdivision
local BOX_PADDING = 0.5     -- Padding margin to ensure sub-tile overlap coverage

--- Creates a new empty BVH instance for a surface
--- @param surface_index number|nil
--- @return table bvh
--- Procedural constructor: Creates a new pure data table BVH instance
--- @param surface_index number|nil
--- @return table tree Pure data table schema
function trajectory_bvh.new_tree(surface_index)
    local tree = {
        surface_index = surface_index or 1,
        root = nil,
        size = 0,
        free_nodes = {},
        free_count = 0,
        leaves_by_key = {},
        trajectories = {},
        next_node_id = 1,
        leaf_count = 0,
    }
    return setmetatable(tree, bvh_mt)
end

function trajectory_bvh.new(surface_index)
    return trajectory_bvh.new_tree(surface_index)
end

--- Re-attaches metatable to a deserialized BVH table
--- @param bvh table
--- @return table bvh
function trajectory_bvh.attach(bvh)
    if not bvh then return nil end
    if not getmetatable(bvh) then
        setmetatable(bvh, bvh_mt)
    end
    bvh.free_nodes = bvh.free_nodes or {}
    bvh.free_count = bvh.free_count or #bvh.free_nodes
    bvh.leaves_by_key = bvh.leaves_by_key or {}
    bvh.trajectories = bvh.trajectories or {}
    bvh.size = bvh.size or bvh.leaf_count or 0
    return bvh
end

--------------------------------------------------------------------------------
-- AABB GEOMETRIC HELPERS
--------------------------------------------------------------------------------
local function box_area(min_x, min_y, max_x, max_y)
    return (max_x - min_x) * (max_y - min_y)
end

local function combined_box(a_min_x, a_min_y, a_max_x, a_max_y, b_min_x, b_min_y, b_max_x, b_max_y)
    return math.min(a_min_x, b_min_x),
           math.min(a_min_y, b_min_y),
           math.max(a_max_x, b_max_x),
           math.max(a_max_y, b_max_y)
end

local function box_intersects(a_min_x, a_min_y, a_max_x, a_max_y, b_min_x, b_min_y, b_max_x, b_max_y)
    return not (a_max_x < b_min_x or a_min_x > b_max_x or a_max_y < b_min_y or a_min_y > b_max_y)
end

--------------------------------------------------------------------------------
-- TREE INSERTION & BALANCING
--------------------------------------------------------------------------------
local function lease_node(bvh)
    local fc = bvh.free_count or 0
    if fc > 0 then
        local node = bvh.free_nodes[fc]
        bvh.free_nodes[fc] = nil
        bvh.free_count = fc - 1
        node.parent = nil
        node.left = nil
        node.right = nil
        node.is_leaf = false
        node.min_x = 0
        node.min_y = 0
        node.max_x = 0
        node.max_y = 0
        return node
    end
    return {
        id = bvh.next_node_id,
        parent = nil,
        left = nil,
        right = nil,
        is_leaf = false,
        min_x = 0,
        min_y = 0,
        max_x = 0,
        max_y = 0
    }
end

local function recycle_node(bvh, node)
    if not (bvh and node) then return end
    node.parent = nil
    node.left = nil
    node.right = nil
    node.is_leaf = false
    node.data = nil
    node.key = nil
    node.owner_id = nil
    node.seg_key = nil
    node.pending_removal = nil
    node.removal_expiry_tick = nil

    local size = bvh.size or 0
    local max_free = math.max(64, size * 2)
    local fc = bvh.free_count or 0
    if fc >= max_free then
        return
    end

    bvh.free_nodes = bvh.free_nodes or {}
    fc = fc + 1
    bvh.free_count = fc
    bvh.free_nodes[fc] = node
end

local function update_node_aabb(node)
    local l = node.left
    local r = node.right
    if l and r then
        node.min_x = math.min(l.min_x, r.min_x)
        node.min_y = math.min(l.min_y, r.min_y)
        node.max_x = math.max(l.max_x, r.max_x)
        node.max_y = math.max(l.max_y, r.max_y)
    elseif l then
        node.min_x, node.min_y, node.max_x, node.max_y = l.min_x, l.min_y, l.max_x, l.max_y
    elseif r then
        node.min_x, node.min_y, node.max_x, node.max_y = r.min_x, r.min_y, r.max_x, r.max_y
    end
end

local function insert_leaf_node(bvh, leaf)
    if not bvh.root then
        bvh.root = leaf
        leaf.parent = nil
        return
    end

    -- Surface Area Heuristic (SAH) descent to find best sibling
    local curr = bvh.root
    while not curr.is_leaf do
        local l = curr.left
        local r = curr.right

        local area_curr = box_area(curr.min_x, curr.min_y, curr.max_x, curr.max_y)
        local c_min_x, c_min_y, c_max_x, c_max_y = combined_box(
            curr.min_x, curr.min_y, curr.max_x, curr.max_y,
            leaf.min_x, leaf.min_y, leaf.max_x, leaf.max_y
        )
        local cost_curr = 2.0 * box_area(c_min_x, c_min_y, c_max_x, c_max_y)
        local cost_inheritance = 2.0 * (box_area(c_min_x, c_min_y, c_max_x, c_max_y) - area_curr)

        -- Cost of descending left
        local cost_l
        local l_min_x, l_min_y, l_max_x, l_max_y = combined_box(
            l.min_x, l.min_y, l.max_x, l.max_y,
            leaf.min_x, leaf.min_y, leaf.max_x, leaf.max_y
        )
        if l.is_leaf then
            cost_l = box_area(l_min_x, l_min_y, l_max_x, l_max_y) + cost_inheritance
        else
            local old_area = box_area(l.min_x, l.min_y, l.max_x, l.max_y)
            cost_l = (box_area(l_min_x, l_min_y, l_max_x, l_max_y) - old_area) + cost_inheritance
        end

        -- Cost of descending right
        local cost_r
        local r_min_x, r_min_y, r_max_x, r_max_y = combined_box(
            r.min_x, r.min_y, r.max_x, r.max_y,
            leaf.min_x, leaf.min_y, leaf.max_x, leaf.max_y
        )
        if r.is_leaf then
            cost_r = box_area(r_min_x, r_min_y, r_max_x, r_max_y) + cost_inheritance
        else
            local old_area = box_area(r.min_x, r.min_y, r.max_x, r.max_y)
            cost_r = (box_area(r_min_x, r_min_y, r_max_x, r_max_y) - old_area) + cost_inheritance
        end

        if cost_curr < cost_l and cost_curr < cost_r then
            break
        end

        if cost_l < cost_r then
            curr = l
        else
            curr = r
        end
    end

    local sibling = curr
    local old_parent = sibling.parent

    local new_parent = lease_node(bvh)
    new_parent.id = bvh.next_node_id
    bvh.next_node_id = bvh.next_node_id + 1
    new_parent.parent = old_parent
    new_parent.left = sibling
    new_parent.right = leaf
    new_parent.is_leaf = false
    new_parent.min_x = 0
    new_parent.min_y = 0
    new_parent.max_x = 0
    new_parent.max_y = 0

    sibling.parent = new_parent
    leaf.parent = new_parent

    if old_parent then
        if old_parent.left == sibling then
            old_parent.left = new_parent
        else
            old_parent.right = new_parent
        end
    else
        bvh.root = new_parent
    end

    -- Refit ancestors upwards
    local walk = new_parent
    while walk do
        update_node_aabb(walk)
        walk = walk.parent
    end
end

local function remove_leaf_node(bvh, leaf)
    if not leaf then return end

    if leaf == bvh.root then
        bvh.root = nil
        leaf.parent = nil
        return
    end

    local parent = leaf.parent
    if not parent then
        leaf.parent = nil
        return
    end
    local grandparent = parent.parent
    local sibling = (parent.left == leaf) and parent.right or parent.left

    if grandparent then
        if grandparent.left == parent then
            grandparent.left = sibling
        else
            grandparent.right = sibling
        end
        sibling.parent = grandparent

        local walk = grandparent
        while walk do
            update_node_aabb(walk)
            walk = walk.parent
        end
    else
        bvh.root = sibling
        sibling.parent = nil
    end

    leaf.parent = nil
    recycle_node(bvh, parent)
end

--------------------------------------------------------------------------------
-- INCREMENTAL SEGMENT & TRAJECTORY REGISTRATION
--------------------------------------------------------------------------------
--- Inserts a single discrete segment into the BVH (Amortized Incremental Building)
--- @param bvh table
--- @param owner_id number Projector unit number
--- @param seg_key any Unique identifier for this segment
--- @param start_pos table {x, y}
--- @param end_pos table {x, y}
--- @param d_start number Distance along beam in tiles
--- @param d_end number Distance along beam in tiles
--- @param seg_idx number|nil Sequential index of this segment
function trajectory_bvh.insert_segment(bvh, owner_id, seg_key, start_pos, end_pos, d_start, d_end, seg_idx)
    if not (bvh and owner_id and seg_key and start_pos and end_pos) then return end

    bvh.trajectories[owner_id] = bvh.trajectories[owner_id] or { segments = {} }
    local owner_rec = bvh.trajectories[owner_id]
    owner_rec.segments = owner_rec.segments or {}

    if owner_rec.segments[seg_key] then
        trajectory_bvh.remove_segment(bvh, owner_id, seg_key)
    end

    local leaf = lease_node(bvh)
    leaf.id = bvh.next_node_id
    leaf.owner_id = owner_id
    leaf.seg_key = seg_key
    leaf.key = tostring(owner_id) .. ":" .. tostring(seg_key)
    leaf.is_leaf = true
    leaf.min_x = math.min(start_pos.x, end_pos.x) - BOX_PADDING
    leaf.min_y = math.min(start_pos.y, end_pos.y) - BOX_PADDING
    leaf.max_x = math.max(start_pos.x, end_pos.x) + BOX_PADDING
    leaf.max_y = math.max(start_pos.y, end_pos.y) + BOX_PADDING
    leaf.d_start = d_start or 0
    leaf.d_end = d_end or 16
    leaf.seg_idx = seg_idx or 1
    leaf.start_pos = leaf.start_pos or {}
    leaf.start_pos.x = start_pos.x
    leaf.start_pos.y = start_pos.y
    leaf.end_pos = leaf.end_pos or {}
    leaf.end_pos.x = end_pos.x
    leaf.end_pos.y = end_pos.y
    bvh.next_node_id = bvh.next_node_id + 1
    insert_leaf_node(bvh, leaf)

    owner_rec.segments[seg_key] = leaf
    bvh.leaves_by_key = bvh.leaves_by_key or {}
    bvh.leaves_by_key[leaf.key] = leaf
    bvh.size = (bvh.size or 0) + 1
    bvh.leaf_count = bvh.size
    return leaf
end

--- Removes a single segment from the BVH
--- @param bvh table
--- @param owner_id number
--- @param seg_key any
function trajectory_bvh.remove_segment(bvh, owner_id, seg_key)
    if not (bvh and owner_id and seg_key) then return end
    local owner_rec = bvh.trajectories[owner_id]
    if not (owner_rec and owner_rec.segments) then return end

    local leaf = owner_rec.segments[seg_key]
    if leaf then
        remove_leaf_node(bvh, leaf)
        owner_rec.segments[seg_key] = nil
        if leaf.key and bvh.leaves_by_key then
            bvh.leaves_by_key[leaf.key] = nil
        end
        bvh.size = math.max(0, (bvh.size or 1) - 1)
        bvh.leaf_count = bvh.size
        recycle_node(bvh, leaf)
    end
end

--- Inserts or updates an entire beam trajectory in one call (Batch Fallback)
--- @param bvh table
--- @param owner_id number
--- @param start_pos table {x, y}
--- @param end_pos table {x, y}
function trajectory_bvh.insert_trajectory(bvh, owner_id, start_pos, end_pos)
    if not (bvh and owner_id and start_pos and end_pos) then return end
    bvh:remove_trajectory(owner_id)

    local dx = end_pos.x - start_pos.x
    local dy = end_pos.y - start_pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.001 then dist = 1.0 end

    local num_segs = math.max(1, math.ceil(dist / MAX_LEAF_SEGMENT))
    local d_x = (dx > 0 and 1) or (dx < 0 and -1) or 0
    local d_y = (dy > 0 and 1) or (dy < 0 and -1) or 0
    for s = 1, num_segs do
        local d_start = (s - 1) * MAX_LEAF_SEGMENT
        local d_end = math.min(dist, s * MAX_LEAF_SEGMENT)
        local p_start = d_start / dist
        local p_end = d_end / dist

        local s_pos = { x = start_pos.x + dx * p_start, y = start_pos.y + dy * p_start }
        local e_pos = { x = start_pos.x + dx * p_end, y = start_pos.y + dy * p_end }
        local seg_key = string.format("%d,%d:%d", d_x, d_y, s)

        bvh:insert_segment(owner_id, seg_key, s_pos, e_pos, d_start, d_end, s)
    end
end

--- Removes all segments for an owner trajectory from the BVH
--- @param bvh table
--- @param owner_id number
function trajectory_bvh.remove_trajectory(bvh, owner_id)
    if not (bvh and owner_id) then return end
    local owner_rec = bvh.trajectories[owner_id]
    if not owner_rec then return end

    if owner_rec.segments then
        for _, leaf in pairs(owner_rec.segments) do
            remove_leaf_node(bvh, leaf)
            if leaf.key and bvh.leaves_by_key then
                bvh.leaves_by_key[leaf.key] = nil
            end
            bvh.size = math.max(0, (bvh.size or 1) - 1)
            bvh.leaf_count = bvh.size
            recycle_node(bvh, leaf)
        end
    end
    if owner_rec.leaves then
        for i = 1, #owner_rec.leaves do
            local leaf = owner_rec.leaves[i]
            remove_leaf_node(bvh, leaf)
            if leaf.key and bvh.leaves_by_key then
                bvh.leaves_by_key[leaf.key] = nil
            end
            bvh.size = math.max(0, (bvh.size or 1) - 1)
            bvh.leaf_count = bvh.size
            recycle_node(bvh, leaf)
        end
    end

    bvh.trajectories[owner_id] = nil
end

--------------------------------------------------------------------------------
-- GENERIC PROCEDURAL BVH API (PHASE 1)
--------------------------------------------------------------------------------
--- Inserts a generic leaf node into the BVH
--- @param tree table Pure data table or attached BVH instance
--- @param leaf table Node with min_x, min_y, max_x, max_y (or aabb fields)
--- @param key any Optional unique string/number key for O(1) tracking
--- @return table leaf
function trajectory_bvh.insert(tree, leaf, key)
    if not (tree and leaf) then return nil end
    local t = profiler.start_timer()

    if key then
        leaf.key = key
    end
    if leaf.key and tree.leaves_by_key then
        if tree.leaves_by_key[leaf.key] then
            trajectory_bvh.remove(tree, tree.leaves_by_key[leaf.key])
        end
        tree.leaves_by_key[leaf.key] = leaf
    end

    leaf.id = leaf.id or tree.next_node_id
    tree.next_node_id = (tree.next_node_id or 1) + 1
    leaf.is_leaf = true

    insert_leaf_node(tree, leaf)
    tree.size = (tree.size or 0) + 1
    tree.leaf_count = tree.size
    if t then profiler.record_bvh("Tree Mutate", t) end
    return leaf
end

--- Removes a generic leaf from the BVH by reference or key
--- @param tree table Pure data table or attached BVH instance
--- @param leaf_or_key table|any Leaf table reference or unique key
--- @return boolean removed
function trajectory_bvh.remove(tree, leaf_or_key)
    if not (tree and leaf_or_key) then return false end
    local t = profiler.start_timer()

    local leaf = nil
    if type(leaf_or_key) == "table" and leaf_or_key.is_leaf then
        leaf = leaf_or_key
    elseif tree.leaves_by_key then
        leaf = tree.leaves_by_key[leaf_or_key]
    end

    if not leaf then return false end

    remove_leaf_node(tree, leaf)

    if leaf.key and tree.leaves_by_key then
        tree.leaves_by_key[leaf.key] = nil
    end

    tree.size = math.max(0, (tree.size or 1) - 1)
    tree.leaf_count = tree.size

    recycle_node(tree, leaf)
    if t then profiler.record_bvh("Tree Mutate", t) end
    return true
end

--- Updates the spatial bounding box of an existing leaf in-place
--- @param tree table
--- @param leaf table
--- @param min_x number|table New min_x or AABB table
--- @param min_y number|nil
--- @param max_x number|nil
--- @param max_y number|nil
function trajectory_bvh.update(tree, leaf, min_x, min_y, max_x, max_y)
    if not (tree and leaf) then return end
    local t = profiler.start_timer()
    remove_leaf_node(tree, leaf)
    if min_x then
        if type(min_x) == "table" then
            local aabb = min_x
            leaf.min_x = aabb.min_x or aabb.left or (aabb.left_top and aabb.left_top.x) or leaf.min_x
            leaf.min_y = aabb.min_y or aabb.top or (aabb.left_top and aabb.left_top.y) or leaf.min_y
            leaf.max_x = aabb.max_x or aabb.right or (aabb.right_bottom and aabb.right_bottom.x) or leaf.max_x
            leaf.max_y = aabb.max_y or aabb.bottom or (aabb.right_bottom and aabb.right_bottom.y) or leaf.max_y
        else
            leaf.min_x = min_x
            leaf.min_y = min_y
            leaf.max_x = max_x
            leaf.max_y = max_y
        end
    end
    insert_leaf_node(tree, leaf)
    if t then profiler.record_bvh("Tree Mutate", t) end
end

--- Fetches a leaf by key in O(1)
--- @param tree table
--- @param key any
--- @return table|nil
function trajectory_bvh.get_leaf(tree, key)
    return tree and tree.leaves_by_key and tree.leaves_by_key[key]
end

--- Clears all nodes from the tree and recycles them into the free pool
--- @param tree table
function trajectory_bvh.clear(tree)
    if not tree then return end
    local function recycle_subtree(node)
        if not node then return end
        if not node.is_leaf then
            if node.left then recycle_subtree(node.left) end
            if node.right then recycle_subtree(node.right) end
        end
        recycle_node(tree, node)
    end

    if tree.root then
        recycle_subtree(tree.root)
        tree.root = nil
    end

    tree.size = 0
    tree.leaf_count = 0
    tree.leaves_by_key = {}
    tree.trajectories = {}
end

--- Returns the total capacity (active leaves + pooled free nodes)
--- @param tree table
--- @return number
function trajectory_bvh.capacity(tree)
    return (tree.size or 0) + (tree.free_count or 0)
end

--- Amortized trickle decay for free node recycling pool with dual-watermark hysteresis
--- @param tree table
--- @param max_evictions number|nil Max free nodes to evict per call (default 8)
--- @return number evicted_count
function trajectory_bvh.step_decay(tree, max_evictions)
    if not tree or not tree.free_nodes then return 0 end
    local size = tree.size or 0
    local fc = tree.free_count or 0
    local cap = size + fc
    local ceiling = math.max(128, size * 3 + 128)
    local floor_cap = math.max(64, math.floor(size * 1.5 + 64))
    local target_free = math.max(64, floor_cap - size)

    if cap > ceiling then
        tree.is_decaying = true
    elseif cap <= floor_cap or fc <= target_free then
        tree.is_decaying = false
    end

    if tree.is_decaying and fc > target_free then
        local max_batch = max_evictions or 8
        local evictions = math.min(max_batch, fc - target_free)
        for i = fc, fc - evictions + 1, -1 do
            tree.free_nodes[i] = nil
        end
        tree.free_count = fc - evictions
        return evictions
    end
    return 0
end

--- Immediately compacts the free node pool down to safety_margin
--- @param tree table
--- @param safety_margin number|nil Retained free nodes in pool (default 64)
--- @return number evicted_count
function trajectory_bvh.compact(tree, safety_margin)
    if not tree or not tree.free_nodes then return 0 end
    safety_margin = safety_margin or 64
    local target = math.max(0, safety_margin)
    local fc = tree.free_count or 0
    local evicted = 0
    if fc > target then
        for i = fc, target + 1, -1 do
            tree.free_nodes[i] = nil
            evicted = evicted + 1
        end
        tree.free_count = target
    end
    tree.is_decaying = false
    return evicted
end

--------------------------------------------------------------------------------
-- QUERY & SPATIOTEMPORAL HIT-TESTING
--------------------------------------------------------------------------------
--- Recursively queries the BVH for leaf segments overlapping an AABB box
--- @param bvh table
--- @param q_min_x number
--- @param q_min_y number
--- @param q_max_x number
--- @param q_max_y number
--- @param out_hits table Array to populate with matching leaf tables
--- @return table out_hits
function trajectory_bvh.query_box(bvh, q_min_x, q_min_y, q_max_x, q_max_y, out_hits)
    local t = profiler.start_timer()
    if type(q_min_x) == "table" then
        local aabb = q_min_x
        out_hits = q_min_y or {}
        q_min_x = aabb.min_x or aabb.left or (aabb.left_top and aabb.left_top.x) or 0
        q_min_y = aabb.min_y or aabb.top or (aabb.left_top and aabb.left_top.y) or 0
        q_max_x = aabb.max_x or aabb.right or (aabb.right_bottom and aabb.right_bottom.x) or 0
        q_max_y = aabb.max_y or aabb.bottom or (aabb.right_bottom and aabb.right_bottom.y) or 0
    else
        out_hits = out_hits or {}
    end
    local root = bvh.root
    if not root then return out_hits end

    local function search_node(node)
        if not box_intersects(node.min_x, node.min_y, node.max_x, node.max_y, q_min_x, q_min_y, q_max_x, q_max_y) then
            return
        end

        if node.is_leaf then
            out_hits[#out_hits + 1] = node
        else
            if node.left then search_node(node.left) end
            if node.right then search_node(node.right) end
        end
    end

    search_node(root)
    if t then profiler.record_bvh("Query Box", t) end
    return out_hits
end

--- Spatiotemporal Distance Window Query:
-- Queries the screen box, inspects active projector flights, and returns only the capsules
-- whose current tick matches the absolute distance interval [d_start, d_end] of the visible leaf.
-- Uses fixed kinetic velocity: 5 tiles every 6 ticks (1.2 ticks per tile).
--- @param bvh table
--- @param q_min_x number Screen left
--- @param q_min_y number Screen top
--- @param q_max_x number Screen right
--- @param q_max_y number Screen bottom
--- @param active_flights table Map of [projector_id] = { flight1, ... }
--- @param current_tick number
--- @param out_capsules table|nil Map of [capsule_id] = flight
--- @return table out_capsules
local TICKS_PER_TILE = 1.2

function trajectory_bvh.query_visible_flights(bvh, q_min_x, q_min_y, q_max_x, q_max_y, active_flights, current_tick, out_capsules)
    out_capsules = out_capsules or {}
    if not (bvh and active_flights) then return out_capsules end

    local hits = {}
    bvh:query_box(q_min_x, q_min_y, q_max_x, q_max_y, hits)
    if #hits == 0 then return out_capsules end

    for i = 1, #hits do
        local leaf = hits[i]
        local proj_flights = active_flights[leaf.owner_id]
        if proj_flights then
            local tpt = trajectory_bvh.TICKS_PER_TILE or TICKS_PER_TILE
            for f = 1, #proj_flights do
                local flight = proj_flights[f]
                local t_start = flight.start_tick or 0
                local t_entry = t_start + math.floor((leaf.d_start or 0) * tpt)
                local t_exit = t_start + math.ceil((leaf.d_end or 16) * tpt)

                if current_tick >= t_entry and current_tick <= t_exit then
                    out_capsules[flight.capsule_id] = flight
                end
            end
        end
    end

    return out_capsules
end

--- Checks if a BVH leaf currently has active flights traversing or approaching its time slice.
--- @param leaf table Leaf node in BVH
--- @param active_flights table Map of [owner_id] = { flight1, ... }
--- @param current_tick number
--- @return boolean has_active_flight, number max_exit_tick
function trajectory_bvh.has_flight_in_leaf(leaf, active_flights, current_tick)
    if not (leaf and active_flights) then return false, 0 end
    local proj_flights = active_flights[leaf.owner_id]
    if not (proj_flights and #proj_flights > 0) then return false, 0 end

    local max_exit = 0
    local found = false
    local tpt = trajectory_bvh.TICKS_PER_TILE or TICKS_PER_TILE
    for f = 1, #proj_flights do
        local flight = proj_flights[f]
        local t_start = flight.start_tick or 0
        local t_exit = t_start + math.ceil((leaf.d_end or 16) * tpt)
        if current_tick <= t_exit then
            found = true
            if t_exit > max_exit then
                max_exit = t_exit
            end
        end
    end
    return found, max_exit
end

--------------------------------------------------------------------------------
-- STORAGE REGISTRY HELPER
--------------------------------------------------------------------------------
--- Lazily fetches or initializes a surface's dedicated BVH from storage
--- @param store table Mod global storage table
--- @param surface_index number
--- @return table bvh
function trajectory_bvh.get_surface_tree(store, surface_index)
    if not store then return nil end
    store.surface_bvh = store.surface_bvh or {}

    local tree = store.surface_bvh[surface_index]
    if not tree then
        tree = trajectory_bvh.new_tree(surface_index)
        store.surface_bvh[surface_index] = tree
    else
        trajectory_bvh.attach(tree)
    end
    return tree
end

--------------------------------------------------------------------------------
-- AUTOMATED TEST SUITE
--------------------------------------------------------------------------------
function trajectory_bvh.run_tests(player)
    local function log_msg(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_msg("[color=yellow][TrajectoryBVH Test][/color] Starting spatial BVH test suite...")

    -- Test 1: Orthogonal trajectory segmentation (100 tiles -> ceil(100/16) = 7 segments)
    local bvh = trajectory_bvh.new(1)
    bvh:insert_trajectory(101, { x = 0, y = 0 }, { x = 100, y = 0 })

    if bvh.leaf_count ~= 7 then
        log_msg("[color=red][TrajectoryBVH Test] Test 1 FAILED: Expected 7 segments for 100-tile beam, got " .. tostring(bvh.leaf_count) .. "[/color]")
        return false
    end

    local hits_mid = {}
    bvh:query_box(40, -2, 60, 2, hits_mid)
    if #hits_mid == 0 then
        log_msg("[color=red][TrajectoryBVH Test] Test 1 FAILED: Middle segment hit test returned 0 hits[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 1: Orthogonal segmentation & middle hit test -> PASSED (" .. #hits_mid .. " leaves intersected)[/color]")

    -- Test 2: Diagonal/slanted trajectory tightness (elimination of false positives)
    local bvh_diag = trajectory_bvh.new(1)
    -- Slanted beam from (0,0) to (200, 200)
    bvh_diag:insert_trajectory(202, { x = 0, y = 0 }, { x = 200, y = 200 })

    -- Test point FAR OFF the diagonal at (20, 180). Monolithic AABB would falsely hit, BVH must prune it!
    local false_pos_hits = {}
    bvh_diag:query_box(10, 170, 30, 190, false_pos_hits)
    if #false_pos_hits > 0 then
        log_msg("[color=red][TrajectoryBVH Test] Test 2 FAILED: Diagonal false positive detected! (" .. #false_pos_hits .. " hits in empty space)[/color]")
        return false
    end

    -- Test point DIRECTLY ON the diagonal at (100, 100)
    local true_hits = {}
    bvh_diag:query_box(95, 95, 105, 105, true_hits)
    if #true_hits == 0 then
        log_msg("[color=red][TrajectoryBVH Test] Test 2 FAILED: True diagonal hit test returned 0 hits[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 2: Diagonal tightness & false-positive elimination -> PASSED (0 false hits, " .. #true_hits .. " true hits)[/color]")

    -- Test 3: Spatiotemporal distance window filtering
    -- Velocity: 5 tiles / 6 ticks = 1.2 ticks/tile.
    -- Middle segment spanning [48, 64] tiles is traversed between ticks:
    -- t_entry = 1000 + floor(48 * 1.2) = 1057
    -- t_exit = 1000 + ceil(64 * 1.2) = 1077
    local dummy_flights = {
        [101] = {
            { capsule_id = 999, start_tick = 1000, arrival_tick = 1120, duration = 120 }
        }
    }

    local tpt = trajectory_bvh.TICKS_PER_TILE or 1.2
    local t_entry = 1000 + math.floor(48 * tpt)
    local t_exit = 1000 + math.ceil(64 * tpt)
    local t_mid = math.floor((t_entry + t_exit) * 0.5)

    local active_early = {}
    bvh:query_visible_flights(50, -2, 60, 2, dummy_flights, t_entry - 5, active_early)
    if active_early[999] ~= nil then
        log_msg("[color=red][TrajectoryBVH Test] Test 3 FAILED: Capsule detected too early in segment[/color]")
        return false
    end

    local active_mid = {}
    bvh:query_visible_flights(50, -2, 60, 2, dummy_flights, t_mid, active_mid)
    if not active_mid[999] then
        log_msg("[color=red][TrajectoryBVH Test] Test 3 FAILED: Capsule NOT detected during valid window[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 3: Spatiotemporal distance window gate -> PASSED[/color]")

    -- Test 4: Trajectory removal & clean tree collapse
    bvh:remove_trajectory(101)
    if bvh.leaf_count ~= 0 or bvh.root ~= nil then
        log_msg("[color=red][TrajectoryBVH Test] Test 4 FAILED: Leaves or root remained after trajectory removal[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 4: Dynamic removal & root collapse -> PASSED[/color]")

    -- Test 5: Procedural Generic BVH without metatables (100% storage serialization safe)
    local p_tree = trajectory_bvh.new_tree(1)
    setmetatable(p_tree, nil) -- Strip metatable completely
    local l1 = { min_x = 10, min_y = 10, max_x = 20, max_y = 20, payload = "p1" }
    local l2 = { min_x = 50, min_y = 50, max_x = 60, max_y = 60, payload = "p2" }
    trajectory_bvh.insert(p_tree, l1, "key_1")
    trajectory_bvh.insert(p_tree, l2, "key_2")

    if p_tree.size ~= 2 or not trajectory_bvh.get_leaf(p_tree, "key_1") then
        log_msg("[color=red][TrajectoryBVH Test] Test 5 FAILED: Procedural insert or get_leaf failed[/color]")
        return false
    end

    local q_hits = {}
    trajectory_bvh.query_box(p_tree, { min_x = 5, min_y = 5, max_x = 25, max_y = 25 }, q_hits)
    if #q_hits ~= 1 or q_hits[1].payload ~= "p1" then
        log_msg("[color=red][TrajectoryBVH Test] Test 5 FAILED: Query box on pure table failed[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 5: Procedural BVH without metatables -> PASSED[/color]")

    -- Test 6: High-water recycling node pool reuse
    local pre_free = p_tree.free_count or 0
    trajectory_bvh.remove(p_tree, "key_1")
    if (p_tree.free_count or 0) <= pre_free or p_tree.size ~= 1 then
        log_msg("[color=red][TrajectoryBVH Test] Test 6 FAILED: Node not returned to free pool on remove[/color]")
        return false
    end

    local cap_before = trajectory_bvh.capacity(p_tree)
    local l3 = { min_x = 15, min_y = 15, max_x = 25, max_y = 25, payload = "p3" }
    trajectory_bvh.insert(p_tree, l3, "key_3")
    local cap_after = trajectory_bvh.capacity(p_tree)
    if cap_after ~= cap_before then
        log_msg("[color=red][TrajectoryBVH Test] Test 6 FAILED: Free node pool failed to reuse existing allocated node[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 6: High-water node recycling pool -> PASSED (0 garbage allocations)[/color]")

    -- Test 7: Working-set proportional gating, amortized decay & pool compaction
    local p_tree2 = trajectory_bvh.new_tree(1)
    for i = 1, 4 do
        trajectory_bvh.insert(p_tree2, { min_x = i * 10, min_y = 0, max_x = i * 10 + 5, max_y = 5 }, "test_" .. i)
    end
    p_tree2.free_nodes = {}
    for i = 1, 200 do
        p_tree2.free_nodes[i] = { id = 1000 + i }
    end
    p_tree2.free_count = 200

    local dummy = { id = 9999 }
    recycle_node(p_tree2, dummy)
    if p_tree2.free_count ~= 200 then
        log_msg("[color=red][TrajectoryBVH Test] Test 7 FAILED: Proportional gating failed to drop node at capacity[/color]")
        return false
    end

    local bvh_evicted = trajectory_bvh.step_decay(p_tree2, 8)
    if bvh_evicted ~= 8 or p_tree2.free_count ~= 192 then
        log_msg("[color=red][TrajectoryBVH Test] Test 7 FAILED: Expected 8 evictions from step_decay, got " .. tostring(bvh_evicted) .. "[/color]")
        return false
    end

    local bvh_comp = trajectory_bvh.compact(p_tree2, 32)
    if p_tree2.free_count ~= 32 or bvh_comp ~= (192 - 32) then
        log_msg("[color=red][TrajectoryBVH Test] Test 7 FAILED: Expected free_count 32 after compact(32), got " .. tostring(p_tree2.free_count) .. "[/color]")
        return false
    end
    log_msg("[color=green][TrajectoryBVH Test] Test 7: Proportional gating, step_decay & compaction -> PASSED[/color]")

    log_msg("[color=green][font=default-bold][TrajectoryBVH Test] ALL 7 TESTS PASSED! Instantiable procedural BVH ready.[/font][/color]")
    return true
end

--------------------------------------------------------------------------------
-- VISUAL DEBUG RENDERING (BOUNDING BOX OVERLAY)
--------------------------------------------------------------------------------
function trajectory_bvh.clear_renders(player_index)
    storage.bvh_renders = storage.bvh_renders or {}
    local player_renders = storage.bvh_renders[player_index]
    if player_renders then
        for i = 1, #player_renders do
            local r = player_renders[i]
            if r and r.valid then
                r.destroy()
            end
        end
        storage.bvh_renders[player_index] = nil
    end
end

function trajectory_bvh.draw_for_player(player_index)
    trajectory_bvh.clear_renders(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return end

    local surf = player.surface
    if not (surf and surf.valid) then return end
    local s_idx = surf.index

    storage.bvh_renders = storage.bvh_renders or {}
    local renders = {}
    storage.bvh_renders[player_index] = renders

    local motion_tree = storage.motion_bvh and storage.motion_bvh[s_idx]
    if motion_tree and motion_tree.root then
        trajectory_bvh.attach(motion_tree)
        local function draw_motion_node(node, depth)
            if not node then return end
            if node.is_leaf then
                local col = { r = 0.2, g = 0.85, b = 1.0, a = 0.8 }
                local tag = "Tube"
                if node.seg_key == "machine" or node.static_render_spec == "machine_static" then
                    col = { r = 1.0, g = 0.6, b = 0.1, a = 0.85 }
                    tag = "Machine"
                elseif node.static_render_spec == "reticle_static" or node.has_trail or (node.owner_id and storage.projector_reticles and storage.projector_reticles[node.owner_id]) then
                    col = { r = 0.2, g = 1.0, b = 0.4, a = 0.85 }
                    tag = "Beam"
                end

                local rect = rendering.draw_rectangle{
                    color = col,
                    width = 2,
                    filled = false,
                    left_top = { node.min_x, node.min_y },
                    right_bottom = { node.max_x, node.max_y },
                    surface = surf,
                    players = { player }
                }
                renders[#renders + 1] = rect

                local mid_x = (node.min_x + node.max_x) * 0.5
                local mid_y = (node.min_y + node.max_y) * 0.5
                local txt = rendering.draw_text{
                    text = string.format("[%s #%s:%s]", tag, tostring(node.owner_id or "?"), tostring(node.seg_key or "?")),
                    surface = surf,
                    target = { mid_x, mid_y },
                    color = col,
                    scale = 0.6,
                    alignment = "center",
                    players = { player }
                }
                renders[#renders + 1] = txt
            else
                local rect = rendering.draw_rectangle{
                    color = { r = 0.1, g = 0.4, b = 0.8, a = 0.2 },
                    width = 1,
                    filled = false,
                    left_top = { node.min_x, node.min_y },
                    right_bottom = { node.max_x, node.max_y },
                    surface = surf,
                    players = { player }
                }
                renders[#renders + 1] = rect
                if node.left then draw_motion_node(node.left, depth + 1) end
                if node.right then draw_motion_node(node.right, depth + 1) end
            end
        end
        draw_motion_node(motion_tree.root, 0)
    end

    local tree = storage.surface_bvh and storage.surface_bvh[s_idx]
    if not (tree and tree.root) then return end
    trajectory_bvh.attach(tree)

    storage.bvh_renders = storage.bvh_renders or {}
    local renders = {}
    storage.bvh_renders[player_index] = renders

    local function draw_node(node, depth)
        if not node then return end
        if node.is_leaf then
            -- Leaf node: Bright green box with segment index & progress percentage
            local rect = rendering.draw_rectangle{
                color = { r = 0.1, g = 0.9, b = 0.2, a = 0.75 },
                width = 2,
                filled = false,
                left_top = { node.min_x, node.min_y },
                right_bottom = { node.max_x, node.max_y },
                surface = surf,
                players = { player }
            }
            renders[#renders + 1] = rect

            local d1 = math.floor(node.d_start or 0)
            local d2 = math.floor(node.d_end or 0)
            local mid_x = (node.min_x + node.max_x) * 0.5
            local mid_y = (node.min_y + node.max_y) * 0.5

            local txt = rendering.draw_text{
                text = string.format("#%d [%d-%d]", node.seg_idx or 1, d1, d2),
                surface = surf,
                target = { mid_x, mid_y },
                color = { r = 0.8, g = 1.0, b = 0.8, a = 0.85 },
                scale = 0.65,
                alignment = "center",
                players = { player }
            }
            renders[#renders + 1] = txt
        else
            -- Internal tree node: Subtle cyan/blue box
            local rect = rendering.draw_rectangle{
                color = { r = 0.1, g = 0.5, b = 0.9, a = 0.25 },
                width = 1,
                filled = false,
                left_top = { node.min_x, node.min_y },
                right_bottom = { node.max_x, node.max_y },
                surface = surf,
                players = { player }
            }
            renders[#renders + 1] = rect

            if node.left then draw_node(node.left, depth + 1) end
            if node.right then draw_node(node.right, depth + 1) end
        end
    end

    draw_node(tree.root, 0)
end

function trajectory_bvh.refresh_active_renders()
    if not storage.debug then return end
    for p_idx, dbg in pairs(storage.debug) do
        if dbg and dbg.master and dbg.bvh then
            trajectory_bvh.draw_for_player(p_idx)
        end
    end
end

return trajectory_bvh
