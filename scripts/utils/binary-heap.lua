--- Reusable Indexed Binary Heap (Priority Queue) with Sliding Allocation Buffer
-- Designed for high-frequency discrete event scheduling (spoil timers, arrival queues).
-- Features:
--   1. Sliding virtual boundary: Reuses allocated node slots without deallocating or resizing tables.
--   2. Paired Hash Map: O(1) index lookup mapping id -> heap position for O(log N) updates and removals.
--   3. Stable FIFO tie-breaking: Identical priorities preserve insertion sequence.
--   4. Dual API: Supports both functional calls and metatable method syntax.

local binary_heap = {}
local heap_mt = { __index = binary_heap }

--- Creates a new binary heap instance
--- @param is_max_heap boolean|nil If true, highest priority pops first; defaults to min-heap
--- @return table heap
function binary_heap.new(is_max_heap)
    local heap = {
        size = 0,
        next_seq = 1,
        nodes = {},
        indices = {},
        is_max_heap = is_max_heap == true,
    }
    return setmetatable(heap, heap_mt)
end

--- Re-attaches metatable to a deserialized heap table
--- @param heap table
--- @return table heap
function binary_heap.attach(heap)
    if heap and not getmetatable(heap) then
        setmetatable(heap, heap_mt)
    end
    return heap
end

--- Sifts an element up the tree to restore heap invariants
local function swim(heap, i)
    local nodes = heap.nodes
    local indices = heap.indices
    local is_max = heap.is_max_heap

    while i > 1 do
        local parent = math.floor(i / 2)
        local curr_node = nodes[i]
        local parent_node = nodes[parent]

        local higher = false
        if is_max then
            if curr_node.priority > parent_node.priority then
                higher = true
            elseif curr_node.priority == parent_node.priority then
                higher = curr_node.seq < parent_node.seq
            end
        else
            if curr_node.priority < parent_node.priority then
                higher = true
            elseif curr_node.priority == parent_node.priority then
                higher = curr_node.seq < parent_node.seq
            end
        end

        if higher then
            nodes[i] = parent_node
            nodes[parent] = curr_node
            indices[parent_node.id] = i
            indices[curr_node.id] = parent
            i = parent
        else
            break
        end
    end
    return i
end

--- Sifts an element down the tree to restore heap invariants
local function sink(heap, i)
    local size = heap.size
    local nodes = heap.nodes
    local indices = heap.indices
    local is_max = heap.is_max_heap

    while true do
        local left = 2 * i
        local right = left + 1
        local best = i

        if left <= size then
            local left_node = nodes[left]
            local best_node = nodes[best]
            local higher = false
            if is_max then
                if left_node.priority > best_node.priority then
                    higher = true
                elseif left_node.priority == best_node.priority then
                    higher = left_node.seq < best_node.seq
                end
            else
                if left_node.priority < best_node.priority then
                    higher = true
                elseif left_node.priority == best_node.priority then
                    higher = left_node.seq < best_node.seq
                end
            end
            if higher then
                best = left
            end
        end

        if right <= size then
            local right_node = nodes[right]
            local best_node = nodes[best]
            local higher = false
            if is_max then
                if right_node.priority > best_node.priority then
                    higher = true
                elseif right_node.priority == best_node.priority then
                    higher = right_node.seq < best_node.seq
                end
            else
                if right_node.priority < best_node.priority then
                    higher = true
                elseif right_node.priority == best_node.priority then
                    higher = right_node.seq < best_node.seq
                end
            end
            if higher then
                best = right
            end
        end

        if best ~= i then
            local curr_node = nodes[i]
            local best_node = nodes[best]
            nodes[i] = best_node
            nodes[best] = curr_node
            indices[best_node.id] = i
            indices[curr_node.id] = best
            i = best
        else
            break
        end
    end
    return i
end

--- Pushes an item into the heap or updates priority if id already exists
--- Reuses existing buffer slot tables without allocation when size <= capacity
--- @param heap table
--- @param id any Unique identifier
--- @param priority number Numeric sort key (e.g. game tick)
--- @param data any Optional user payload
--- @return any id
function binary_heap.push(heap, id, priority, data)
    id = id or ("__auto_" .. heap.next_seq)

    local existing_pos = heap.indices[id]
    if existing_pos then
        binary_heap.update(heap, id, priority, data)
        return id
    end

    local new_size = heap.size + 1
    heap.size = new_size

    local node = heap.nodes[new_size]
    if not node then
        node = {}
        heap.nodes[new_size] = node
    end

    node.id = id
    node.priority = priority
    node.data = data
    node.seq = heap.next_seq
    heap.next_seq = heap.next_seq + 1

    heap.indices[id] = new_size
    swim(heap, new_size)
    return id
end

--- Peeks at the root element without removing it
--- @param heap table
--- @return any id, number|nil priority, any data
function binary_heap.peek(heap)
    if heap.size == 0 then return nil, nil, nil end
    local top = heap.nodes[1]
    return top.id, top.priority, top.data
end

--- Peeks strictly at the root priority
--- @param heap table
--- @return number|nil priority
function binary_heap.peek_priority(heap)
    if heap.size == 0 then return nil end
    return heap.nodes[1].priority
end

--- Peeks strictly at the root id
--- @param heap table
--- @return any id
function binary_heap.peek_id(heap)
    if heap.size == 0 then return nil end
    return heap.nodes[1].id
end

--- Pops the highest-priority element, advancing the virtual boundary and preserving node tables
--- @param heap table
--- @return any id, number|nil priority, any data
function binary_heap.pop(heap)
    local size = heap.size
    if size == 0 then return nil, nil, nil end

    local top = heap.nodes[1]
    local out_id = top.id
    local out_priority = top.priority
    local out_data = top.data

    heap.indices[out_id] = nil

    if size == 1 then
        heap.size = 0
        top.data = nil
        return out_id, out_priority, out_data
    end

    local last_node = heap.nodes[size]
    heap.nodes[1] = last_node
    heap.nodes[size] = top
    top.data = nil

    heap.indices[last_node.id] = 1
    heap.size = size - 1

    sink(heap, 1)
    return out_id, out_priority, out_data
end

--- Removes an element from anywhere in the heap in O(log N) using the paired hash map
--- @param heap table
--- @param id any Unique identifier
--- @return boolean removed
function binary_heap.remove(heap, id)
    if id == nil then return false end
    local pos = heap.indices[id]
    if not pos then return false end

    heap.indices[id] = nil
    local target_node = heap.nodes[pos]
    target_node.data = nil

    local size = heap.size
    if pos == size then
        heap.size = size - 1
        return true
    end

    local last_node = heap.nodes[size]
    heap.nodes[pos] = last_node
    heap.nodes[size] = target_node

    heap.indices[last_node.id] = pos
    heap.size = size - 1

    local new_pos = swim(heap, pos)
    if new_pos == pos then
        sink(heap, pos)
    end
    return true
end

--- Updates the priority and/or payload of an existing element in O(log N)
--- @param heap table
--- @param id any Unique identifier
--- @param new_priority number New sort key
--- @param new_data any Optional updated payload
--- @return boolean updated
function binary_heap.update(heap, id, new_priority, new_data)
    if id == nil then return false end
    local pos = heap.indices[id]
    if not pos then return false end

    local node = heap.nodes[pos]
    local old_priority = node.priority
    node.priority = new_priority
    if new_data ~= nil then
        node.data = new_data
    end

    if new_priority ~= old_priority then
        local is_higher = false
        if heap.is_max_heap then
            is_higher = (new_priority > old_priority)
        else
            is_higher = (new_priority < old_priority)
        end

        if is_higher then
            swim(heap, pos)
        else
            sink(heap, pos)
        end
    end
    return true
end

--- Gets priority and payload of an item in O(1)
--- @param heap table
--- @param id any
--- @return number|nil priority, any data
function binary_heap.get(heap, id)
    if id == nil then return nil, nil end
    local pos = heap.indices[id]
    if not pos then return nil, nil end
    local node = heap.nodes[pos]
    return node.priority, node.data
end

--- Checks if an item exists in the heap in O(1)
--- @param heap table
--- @param id any
--- @return boolean
function binary_heap.contains(heap, id)
    return id ~= nil and heap.indices[id] ~= nil
end

--- Returns the active number of elements in the heap
--- @param heap table
--- @return number
function binary_heap.count(heap)
    return heap.size
end

--- Returns true if the heap has zero active elements
--- @param heap table
--- @return boolean
function binary_heap.is_empty(heap)
    return heap.size == 0
end

--- Returns total allocated node slots in the reusable buffer
--- @param heap table
--- @return number
function binary_heap.capacity(heap)
    return #heap.nodes
end

--- Resets active elements to zero while preserving the allocated buffer slots
--- @param heap table
function binary_heap.clear(heap)
    heap.size = 0
    heap.indices = {}
    for i = 1, #heap.nodes do
        heap.nodes[i].data = nil
    end
end

--- Runs an automated test suite verifying correctness, buffer sliding, and timer patterns
--- @param player LuaPlayer|nil
--- @return boolean success
function binary_heap.run_tests(player)
    local function log_line(msg)
        if player and player.valid then
            player.print(msg)
        else
            log(msg)
        end
    end

    log_line("[color=yellow][BinaryHeap Test][/color] Starting automated self-test suite...")

    -- Test 1: Min-Heap Push, Peek, Pop
    local h1 = binary_heap.new()
    h1:push("c", 30, "cargo_c")
    h1:push("a", 10, "cargo_a")
    h1:push("e", 50, "cargo_e")
    h1:push("b", 20, "cargo_b")
    h1:push("d", 40, "cargo_d")

    local top_id, top_prio = h1:peek()
    if top_id ~= "a" or top_prio ~= 10 then
        log_line("[color=red][BinaryHeap Test] Test 1 FAILED: Expected peek 'a' at 10, got " .. tostring(top_id) .. "[/color]")
        return false
    end

    local popped = {}
    while not h1:is_empty() do
        local id, prio = h1:pop()
        table.insert(popped, { id = id, prio = prio })
    end

    local expected = { { id = "a", prio = 10 }, { id = "b", prio = 20 }, { id = "c", prio = 30 }, { id = "d", prio = 40 }, { id = "e", prio = 50 } }
    for i = 1, #expected do
        if not popped[i] or popped[i].id ~= expected[i].id or popped[i].prio ~= expected[i].prio then
            log_line("[color=red][BinaryHeap Test] Test 1 FAILED: Pop order mismatch at step " .. i .. "[/color]")
            return false
        end
    end
    log_line("[color=green][BinaryHeap Test] Test 1: Basic Min-Heap Push, Peek, Pop -> PASSED[/color]")

    -- Test 2: Sliding Allocation Buffer Capacity Stability
    local h2 = binary_heap.new()
    for i = 1, 10 do
        h2:push("item_" .. i, 100 - i)
    end
    local cap_initial = h2:capacity()
    if cap_initial < 10 then
        log_line("[color=red][BinaryHeap Test] Test 2 FAILED: Expected capacity >= 10, got " .. cap_initial .. "[/color]")
        return false
    end

    for _ = 1, 6 do h2:pop() end
    if h2:count() ~= 4 or h2:capacity() ~= cap_initial then
        log_line("[color=red][BinaryHeap Test] Test 2 FAILED: Virtual line count should be 4 and capacity retained[/color]")
        return false
    end

    for i = 11, 16 do
        h2:push("item_" .. i, i * 10)
    end
    if h2:capacity() ~= cap_initial then
        log_line("[color=red][BinaryHeap Test] Test 2 FAILED: Capacity expanded unexpectedly instead of reusing buffer slots[/color]")
        return false
    end
    log_line("[color=green][BinaryHeap Test] Test 2: Sliding Buffer Reuse -> PASSED (Capacity maintained at " .. cap_initial .. ", 0 reallocations)[/color]")

    -- Test 3: Paired Hash Map In-Place Update
    local h3 = binary_heap.new()
    h3:push("x", 100)
    h3:push("y", 200)
    h3:push("z", 300)

    h3:update("z", 50) -- sift up to new root
    if h3:peek() ~= "z" then
        log_line("[color=red][BinaryHeap Test] Test 3 FAILED: 'z' should be root after priority decrease to 50[/color]")
        return false
    end

    h3:update("x", 500) -- sift down below 'y'
    local p1 = h3:pop()
    local p2 = h3:pop()
    local p3 = h3:pop()
    if p1 ~= "z" or p2 ~= "y" or p3 ~= "x" then
        log_line("[color=red][BinaryHeap Test] Test 3 FAILED: Order after updates expected z, y, x but got " .. tostring(p1) .. ", " .. tostring(p2) .. ", " .. tostring(p3) .. "[/color]")
        return false
    end
    log_line("[color=green][BinaryHeap Test] Test 3: Paired Hash Map In-Place Update -> PASSED[/color]")

    -- Test 4: O(log N) Arbitrary Deletion
    local h4 = binary_heap.new()
    h4:push("m1", 10)
    h4:push("m2", 20)
    h4:push("m3", 30)
    h4:push("m4", 40)
    h4:push("m5", 50)

    local removed = h4:remove("m3")
    if not removed or h4:contains("m3") or h4:count() ~= 4 then
        log_line("[color=red][BinaryHeap Test] Test 4 FAILED: Arbitrary removal of 'm3' failed[/color]")
        return false
    end

    local del_order = {}
    while not h4:is_empty() do
        local id = h4:pop()
        table.insert(del_order, id)
    end
    if del_order[1] ~= "m1" or del_order[2] ~= "m2" or del_order[3] ~= "m4" or del_order[4] ~= "m5" then
        log_line("[color=red][BinaryHeap Test] Test 4 FAILED: Order corrupted after arbitrary removal[/color]")
        return false
    end
    log_line("[color=green][BinaryHeap Test] Test 4: O(log N) Arbitrary Removal -> PASSED[/color]")

    -- Test 5: Stable FIFO Tie-Breaking
    local h5 = binary_heap.new()
    h5:push("tie_1", 100)
    h5:push("tie_2", 100)
    h5:push("tie_3", 100)

    local t1 = h5:pop()
    local t2 = h5:pop()
    local t3 = h5:pop()
    if t1 ~= "tie_1" or t2 ~= "tie_2" or t3 ~= "tie_3" then
        log_line("[color=red][BinaryHeap Test] Test 5 FAILED: FIFO tie-breaking sequence failed[/color]")
        return false
    end
    log_line("[color=green][BinaryHeap Test] Test 5: Stable FIFO Tie-Breaking -> PASSED[/color]")

    -- Test 6: Spoil Timer Simulation Pattern (Example 1)
    local timers = binary_heap.new()
    timers:push("cap_1", 120)
    timers:push("cap_2", 60)
    timers:push("cap_3", 90)
    timers:push("cap_4", 300)

    -- Tick 50: Earliest is cap_2 (tick 60) -> quick exit without popping
    local earliest_id, earliest_tick = timers:peek()
    if earliest_id ~= "cap_2" or earliest_tick ~= 60 or earliest_tick <= 50 then
        log_line("[color=red][BinaryHeap Test] Test 6 FAILED: Tick 50 quick exit evaluation mismatch[/color]")
        return false
    end

    -- Tick 60: cap_2 expires and pops
    local exp_id = timers:pop()
    if exp_id ~= "cap_2" then
        log_line("[color=red][BinaryHeap Test] Test 6 FAILED: Tick 60 expected cap_2 to pop[/color]")
        return false
    end

    -- Next peek is cap_3 at 90 -> quick exit
    if timers:peek_priority() ~= 90 then
        log_line("[color=red][BinaryHeap Test] Test 6 FAILED: Next timer should be 90[/color]")
        return false
    end

    -- cap_1 is delivered early at tick 70, unregister from timer
    timers:remove("cap_1")

    -- Tick 100: cap_3 expires and pops
    local exp_id2 = timers:pop()
    if exp_id2 ~= "cap_3" then
        log_line("[color=red][BinaryHeap Test] Test 6 FAILED: Tick 100 expected cap_3 to pop[/color]")
        return false
    end

    -- Remaining timer is cap_4 at tick 300
    if timers:peek_id() ~= "cap_4" or timers:peek_priority() ~= 300 then
        log_line("[color=red][BinaryHeap Test] Test 6 FAILED: Final remaining timer should be cap_4 at 300[/color]")
        return false
    end
    log_line("[color=green][BinaryHeap Test] Test 6: Spoil Timer Simulation Pattern -> PASSED[/color]")

    -- Test 7: Max-Heap Mode
    local max_h = binary_heap.new(true)
    max_h:push("low", 5)
    max_h:push("high", 25)
    max_h:push("mid", 15)

    local mx1 = max_h:pop()
    local mx2 = max_h:pop()
    local mx3 = max_h:pop()
    if mx1 ~= "high" or mx2 ~= "mid" or mx3 ~= "low" then
        log_line("[color=red][BinaryHeap Test] Test 7 FAILED: Max-heap order mismatch[/color]")
        return false
    end
    log_line("[color=green][BinaryHeap Test] Test 7: Max-Heap Mode -> PASSED[/color]")

    log_line("[color=green][font=default-bold][BinaryHeap Test] ALL 7 TESTS PASSED SUCCESSFULLY! Ready for virtual cargo spoil integration.[/font][/color]")
    return true
end

return binary_heap
