data:extend({
  {
    type = "custom-input",
    name = "on-player-rotate",
    key_sequence = "",
    linked_game_control = "rotate",
    action = "lua"
  },
  {
    type = "custom-input",
    name = "capsule-emergency-exit",
    key_sequence = "SHIFT + E",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "pneumatic-shift-key",
    key_sequence = "left-shift",
    alternative_key_sequence = "right-shift",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "pneumatic-copy-settings",
    key_sequence = "",
    linked_game_control = "copy-entity-settings",
    include_selected_prototype = true,
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "pneumatic-paste-settings",
    key_sequence = "",
    linked_game_control = "paste-entity-settings",
    include_selected_prototype = true,
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "pneumatic-confirm-gui",
    key_sequence = "",
    linked_game_control = "confirm-gui",
    consuming = "none"
  }
})