local capsule_queries = {}

--- Destroys the visual rendering object associated with a capsule
--- @param capsule table
function capsule_queries.clear_capsule_render(capsule)
    if capsule and capsule.render_id and capsule.render_id.valid then
        capsule.render_id.destroy()
    end
    if capsule then
        capsule.render_id = nil
    end
end

--- Removes a capsule from motion tracking and clears its visual debug render
--- @param id number
function capsule_queries.remove_capsule(id)
    if not storage.capsules then return end
    local capsule = storage.capsules[id]
    if capsule then
        capsule_queries.clear_capsule_render(capsule)
        storage.capsules[id] = nil
    end
end

--- Finds all active capsule runner IDs currently located at or heading to/from an entity
--- @param unit_number number
--- @return table<number>
function capsule_queries.find_capsules_at_entity(unit_number)
    if not storage.capsules then return {} end
    local prefix = tostring(unit_number) .. ":"
    local prefix_len = #prefix
    local matches = {}

    for id, cap in pairs(storage.capsules) do
        local at_from = cap.from_port_key and string.sub(cap.from_port_key, 1, prefix_len) == prefix
        local at_to = cap.to_port_key and string.sub(cap.to_port_key, 1, prefix_len) == prefix
        if at_from or at_to then
            table.insert(matches, id)
        end
    end

    return matches
end

--- Checks how many capsules are currently occupying the entity's ports
--- @param unit_number number
--- @return number
function capsule_queries.get_capsule_count_at_entity(unit_number)
    if not storage.capsules then return 0 end
    local count = 0
    local prefix = tostring(unit_number) .. ":"
    local prefix_len = #prefix

    for _, cap in pairs(storage.capsules) do
        if cap.from_port_key and string.sub(cap.from_port_key, 1, prefix_len) == prefix then
            count = count + 1
        end
    end
    return count
end

return capsule_queries