require("prototypes.item")
require("prototypes.recipe")
require("prototypes.entity")
require("prototypes.technology")
require("prototypes.custom-input")
require("prototypes.shortcut")

require("prototypes.pneumatic-diverter")
require("prototypes.pneumatic-pump-proxy")

data:extend({
    {
        type = "sprite",
        name = "pneumatic_any_quality_badge",
        filename = "__core__/graphics/icons/any-quality.png",
        width = 64,
        height = 64,
        flags = { "icon" }
    },
    {
        type = "sprite",
        name = "pneumatic_filter_blacklist",
        filename = "__core__/graphics/filter-blacklist.png",
        width = 101,
        height = 101,
        flags = { "icon" }
    }
})