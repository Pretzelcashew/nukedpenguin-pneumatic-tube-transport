local diverter_settings = {}

function diverter_settings.get(unit_number)
    storage.diverter_settings = storage.diverter_settings or {}
    if not storage.diverter_settings[unit_number] then
        storage.diverter_settings[unit_number] = {
            ports = {
                [1] = { -- Port 1: North
                    enabled = true,
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                },
                [2] = { -- Port 2: East
                    enabled = true,
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                },
                [3] = { -- Port 3: South
                    enabled = true,
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                },
                [4] = { -- Port 4: West
                    enabled = true,
                    mode = "input",
                    use_filters = false,
                    filter_mode = "whitelist",
                    filters = {
                        [1] = { comparator = "=", item = nil },
                        [2] = { comparator = "=", item = nil },
                        [3] = { comparator = "=", item = nil },
                        [4] = { comparator = "=", item = nil },
                        [5] = { comparator = "=", item = nil }
                    }
                }
            }
        }
    end
    return storage.diverter_settings[unit_number]
end

return diverter_settings