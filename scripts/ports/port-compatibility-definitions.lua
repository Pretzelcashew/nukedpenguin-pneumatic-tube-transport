-- scripts/ports/port-compatibility-definitions.lua
local compatibility_defs = {}

-- Allowed flow pairings (symmetric - order does not matter)
compatibility_defs.flows = {
    { "in",  "out" },
    { "in",  "any" },
    { "out", "any" },
    { "any", "any" }
}

-- Allowed connection type pairings (symmetric - order does not matter)
compatibility_defs.connections = {
    { "join",  "join" },
    { "join",  "merge" },
    { "merge", "merge" }
}

return compatibility_defs