data:extend({
  {
    type = "shortcut",
    name = "pt-toggle-flow",
    order = "a[pneumatic]-a[flow]",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/display-panel.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/display-panel.png",
    small_icon_size = 64,
    localized_name = {"shortcut-name.pt-toggle-flow"}
  },
  {
    type = "shortcut",
    name = "pt-toggle-capsules",
    order = "a[pneumatic]-b[capsules]",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/programmable-speaker.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/programmable-speaker.png",
    small_icon_size = 64,
    localized_name = {"shortcut-name.pt-toggle-capsules"}
  },
  {
    type = "shortcut",
    name = "pt-toggle-capsule-peek",
    order = "a[pneumatic]-c[peek]",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/selector-combinator.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/selector-combinator.png",
    small_icon_size = 64,
    localized_name = {"shortcut-name.pt-toggle-capsule-peek"}
  },
  {
    type = "shortcut",
    name = "pt-toggle-ports",
    order = "a[pneumatic]-d[ports]",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/arithmetic-combinator.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/arithmetic-combinator.png",
    small_icon_size = 64,
    localized_name = {"shortcut-name.pt-toggle-ports"}
  },
  {
    type = "shortcut",
    name = "pt-toggle-debug",
    order = "a[pneumatic]-e[debug]",
    action = "lua",
    toggleable = true,
    icon = "__base__/graphics/icons/constant-combinator.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/constant-combinator.png",
    small_icon_size = 64,
    localized_name = {"shortcut-name.pt-toggle-debug"}
  }
})