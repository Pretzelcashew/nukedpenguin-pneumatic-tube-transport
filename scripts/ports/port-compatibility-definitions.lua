local compatibility_defs = {}

compatibility_defs.flows = {
    { "in",  "out" },
    { "in",  "any" },
    { "out", "any" },
    { "any", "any" }
}

compatibility_defs.connections = {
    { pair = { "join", "join" },   outcome = "join",  unoutcome = "unjoin" },
    { pair = { "join", "merge" },  outcome = "join",  unoutcome = "unjoin" },
    { pair = { "merge", "merge" }, outcome = "merge", unoutcome = "unmerge" }
}

return compatibility_defs