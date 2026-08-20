-- scripts/ports/port-compatibility-definitions.lua
local compatibility_defs = {}

-- Allowed flow pairings (symmetric - order does not matter)
compatibility_defs.flows = {
    { "in",  "out" },
    { "in",  "any" },
    { "out", "any" },
    { "any", "any" }
}

-- Allowed connection combinations and their explicit outcome mapping
compatibility_defs.connections = {
    { pair = { "join", "join" },   outcome = "join" },
    { pair = { "join", "merge" },  outcome = "join" },
    { pair = { "merge", "merge" }, outcome = "merge" }
}

return compatibility_defs