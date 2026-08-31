local networks = require("scripts.networks.networks")
local port_defs = require("scripts.ports.port-definitions")
local networks_flow = require("scripts.networks.networks-flow")
local networks_pressure = require("scripts.networks.networks-pressure")
local capsule_queries = require("scripts.capsules.capsule-queries")
local events = require("scripts.events")

local network_rebuild_engine = {}

local DEFAULT_NODE_BUDGET = 350

--- Initializes storage structures for the time-sliced rebuild engine
function network_rebuild_engine.init()
    storage.network_rebuild_queue = storage.network_rebuild_queue or {
        pending_splits = {},
        dirty_networks = {},
        active_job = nil
    }
end

--- Enqueues a split check job following a severed edge
--- @param severed_port_key string Port key of the removed entity (e.g. "101:1")
--- @param neighbor_key string Port key of the surviving neighbor (e.g. "102:2")
--- @param old_net_id uint Network ID prior to edge severing
function network_rebuild_engine.queue_split(severed_port_key, neighbor_key, old_net_id)
    network_rebuild_engine.init()
    if not (severed_port_key and neighbor_key and old_net_id) then return end

    table.insert(storage.network_rebuild_queue.pending_splits, {
        severed_port_key = severed_port_key,
        neighbor_key = neighbor_key,
        old_net_id = old_net_id
    })
end

--- Marks a network ID as requiring flow and pressure recalculation
--- @param net_id uint
function network_rebuild_engine.mark_dirty(net_id)
    network_rebuild_engine.init()
    if net_id then
        storage.network_rebuild_queue.dirty_networks[net_id] = true
    end
end

--- Internal helper to initialize a new split walk job
local function start_next_split_job()
    local queue_data = storage.network_rebuild_queue
    if #queue_data.pending_splits == 0 then return nil end

    local job_spec = table.remove(queue_data.pending_splits, 1)
    local old_net = storage.networks.list and storage.networks.list[job_spec.old_net_id]

    if not (old_net and old_net.members) then
        return nil
    end

    local u_severed = job_spec.severed_port_key:match("^(%d+):")
    if not u_severed then return nil end

    local expected_count = 0
    for _, m in ipairs(old_net.members) do
        if tostring(m.unit_number) ~= u_severed then
            expected_count = expected_count + 1
        end
    end

    return {
        severed_port_key = job_spec.severed_port_key,
        neighbor_key = job_spec.neighbor_key,
        old_net_id = job_spec.old_net_id,
        u_severed = u_severed,
        expected_count = expected_count,
        visited = { [job_spec.neighbor_key] = true },
        bfs_queue = { job_spec.neighbor_key },
        head = 1
    }
end

--- Finalizes a completed split walk job
local function complete_split_job(job)
    local old_net = storage.networks.list and storage.networks.list[job.old_net_id]
    if not old_net then return end

    local visited_count = 0
    for _ in pairs(job.visited) do
        visited_count = visited_count + 1
    end

    if visited_count >= job.expected_count then
        -- NO SPLIT: Clean up dead entity members and preserve network ID
        local remaining_members = {}
        for _, m in ipairs(old_net.members) do
            if tostring(m.unit_number) ~= job.u_severed then
                table.insert(remaining_members, m)
            end
        end
        old_net.members = remaining_members

        if #old_net.members == 0 then
            networks.delete(job.old_net_id)
            debug_print(string.format("[REBUILD ENGINE] Network #%d emptied and recycled.", job.old_net_id))
        else
            network_rebuild_engine.mark_dirty(job.old_net_id)
            debug_print(string.format("[REBUILD ENGINE] Network #%d intact (%d members remain).", job.old_net_id, #remaining_members))
        end
    else
        -- SPLIT DETECTED: Provision new network ID for visited subgraph
        local new_net_id = networks.create()
        local new_net = storage.networks.list[new_net_id]

        local remaining_old_members = {}

        for _, m in ipairs(old_net.members) do
            local m_key = m.unit_number .. ":" .. m.port_index
            if job.visited[m_key] then
                table.insert(new_net.members, m)
                storage.networks.port_to_network[m_key] = new_net_id
            elseif tostring(m.unit_number) ~= job.u_severed then
                table.insert(remaining_old_members, m)
            end
        end

        old_net.members = remaining_old_members

        network_rebuild_engine.mark_dirty(new_net_id)

        if #old_net.members == 0 then
            networks.delete(job.old_net_id)
            debug_print(string.format("[REBUILD ENGINE SPLIT] Subgraph broke off into Network #%d (%d members). Old network #%d recycled.",
                new_net_id, #new_net.members, job.old_net_id))
        else
            network_rebuild_engine.mark_dirty(job.old_net_id)
            debug_print(string.format("[REBUILD ENGINE SPLIT] Subgraph broke off into Network #%d (%d members). Network #%d retains %d members.",
                new_net_id, #new_net.members, job.old_net_id, #old_net.members))
        end
    end
end

--- Executes a time-sliced processing step across queued splits and dirty networks
--- @param node_budget? uint Maximum graph nodes to walk in this tick (default 350)
function network_rebuild_engine.step(node_budget)
    network_rebuild_engine.init()
    local queue_data = storage.network_rebuild_queue
    local budget = node_budget or DEFAULT_NODE_BUDGET
    local nodes_walked = 0

    while nodes_walked < budget do
        if not queue_data.active_job then
            queue_data.active_job = start_next_split_job()
            if not queue_data.active_job then
                break
            end
        end

        local job = queue_data.active_job

        while job.head <= #job.bfs_queue and nodes_walked < budget do
            local current_key = job.bfs_queue[job.head]
            job.head = job.head + 1
            nodes_walked = nodes_walked + 1

            local neighbors = storage.port_connections and storage.port_connections[current_key]
            if neighbors then
                for neighbor_key, conn_type in pairs(neighbors) do
                    if conn_type == "merge" and not job.visited[neighbor_key] then
                        job.visited[neighbor_key] = true
                        table.insert(job.bfs_queue, neighbor_key)
                    end
                end
            end
        end

        if job.head > #job.bfs_queue then
            complete_split_job(job)
            queue_data.active_job = nil
        end
    end

    -- If split traversals are idle, flush flow & pressure rebuilds for dirty networks in a single batch
    if not queue_data.active_job and #queue_data.pending_splits == 0 and next(queue_data.dirty_networks) ~= nil then
        local dirty_copy = queue_data.dirty_networks
        queue_data.dirty_networks = {}
        networks_flow.build_batch(dirty_copy)
    end
end

--- Synchronously flushes all queued rebuilds (used before game save or explicit sync)
function network_rebuild_engine.flush()
    network_rebuild_engine.init()
    local queue_data = storage.network_rebuild_queue
    while queue_data.active_job or #queue_data.pending_splits > 0 or next(queue_data.dirty_networks) ~= nil do
        network_rebuild_engine.step(math.huge)
    end
end

events.on_event(defines.events.on_tick, function()
    network_rebuild_engine.step()
end)

return network_rebuild_engine