# Pneumatic Diverter Manual GUI - Implementation Specification

## 1. Key Architecture & Design Decisions
* UI Standard: Screen frame (defines.gui_type.screen) centered on screen.
* Layout Structure: 2x2 grid representing the 4 physical directional ports (Port 1: North, Port 2: East, Port 3: South, Port 4: West) derived from port-definitions.lua.
* Pressure Display (Option B): Omitted from the UI header; network pressure calculations run strictly in the background simulation layer (networks-pressure.lua).
* Proxy Linkage Integration: pneumatic-diverter-proxy-linkage.lua intercepts on_gui_opened for pneumatic-diverter and launches this screen GUI, binding player.opened = screen_frame.

---

## 2. Full Non-Truncated Visual Wireframe

======================================================================================================================
[Icon] Pneumatic Diverter Configuration                                                                           [X]
======================================================================================================================
+----------------------------------------------------------+  +----------------------------------------------------------+
| [✓] Port 1: North                                        |  | [✓] Port 2: East                                         |
| Direction:   [ Input (Pull)  |  Output (Push) ]          |  | Direction:   [ Input (Pull)  |  Output (Push) ]          |
| -------------------------------------------------------- |  | -------------------------------------------------------- |
| [✓] Use Filters               Mode: [ Whitelist | Black ]|  | [ ] Use Filters               Mode: [ Whitelist | Black ]|
| Filter Slots & Quality Comparators:                      |  | Filter Slots & Quality Comparators:                      |
|  [Slot 1][=▼]  [Slot 2][=▼]  [Slot 3][=▼]               |  |  [Slot 1][=▼]  [Slot 2][=▼]  [Slot 3][=▼]               |
|  [Slot 4][=▼]  [Slot 5][=▼]                              |  |  [Slot 4][=▼]  [Slot 5][=▼]                              |
+----------------------------------------------------------+  +----------------------------------------------------------+
+----------------------------------------------------------+  +----------------------------------------------------------+
| [✓] Port 3: South                                        |  | [✓] Port 4: West                                         |
| Direction:   [ Input (Pull)  |  Output (Push) ]          |  | Direction:   [ Input (Pull)  |  Output (Push) ]          |
| -------------------------------------------------------- |  | -------------------------------------------------------- |
| [✓] Use Filters               Mode: [ Whitelist | Black ]|  | [ ] Use Filters               Mode: [ Whitelist | Black ]|
| Filter Slots & Quality Comparators:                      |  | Filter Slots & Quality Comparators:                      |
|  [Slot 1][=▼]  [Slot 2][=▼]  [Slot 3][=▼]               |  |  [Slot 1][=▼]  [Slot 2][=▼]  [Slot 3][=▼]               |
|  [Slot 4][=▼]  [Slot 5][=▼]                              |  |  [Slot 4][=▼]  [Slot 5][=▼]                              |
+----------------------------------------------------------+  +----------------------------------------------------------+
======================================================================================================================

---

## 3. Persistent Storage Schema (storage.diverter_settings)

Create scripts/diverter-settings.lua to initialize and manage storage state per entity unit_number:

storage.diverter_settings = storage.diverter_settings or {}

function diverter_settings.get(unit_number)
  if not storage.diverter_settings[unit_number] then
    storage.diverter_settings[unit_number] = {
      ports = {
        [1] = { -- Port 1: North
          enabled = true,
          mode = "input", -- "input" (pull) | "output" (push)
          use_filters = false,
          filter_mode = "whitelist", -- "whitelist" | "blacklist"
          filters = {
            [1] = { name = nil, quality = "any", comparator = "=" },
            [2] = { name = nil, quality = "any", comparator = "=" },
            [3] = { name = nil, quality = "any", comparator = "=" },
            [4] = { name = nil, quality = "any", comparator = "=" },
            [5] = { name = nil, quality = "any", comparator = "=" }
          }
        },
        [2] = { -- Port 2: East
          enabled = true, mode = "input", use_filters = false, filter_mode = "whitelist",
          filters = {
            [1] = { name = nil, quality = "any", comparator = "=" },
            [2] = { name = nil, quality = "any", comparator = "=" },
            [3] = { name = nil, quality = "any", comparator = "=" },
            [4] = { name = nil, quality = "any", comparator = "=" },
            [5] = { name = nil, quality = "any", comparator = "=" }
          }
        },
        [3] = { -- Port 3: South
          enabled = true, mode = "input", use_filters = false, filter_mode = "whitelist",
          filters = {
            [1] = { name = nil, quality = "any", comparator = "=" },
            [2] = { name = nil, quality = "any", comparator = "=" },
            [3] = { name = nil, quality = "any", comparator = "=" },
            [4] = { name = nil, quality = "any", comparator = "=" },
            [5] = { name = nil, quality = "any", comparator = "=" }
          }
        },
        [4] = { -- Port 4: West
          enabled = true, mode = "input", use_filters = false, filter_mode = "whitelist",
          filters = {
            [1] = { name = nil, quality = "any", comparator = "=" },
            [2] = { name = nil, quality = "any", comparator = "=" },
            [3] = { name = nil, quality = "any", comparator = "=" },
            [4] = { name = nil, quality = "any", comparator = "=" },
            [5] = { name = nil, quality = "any", comparator = "=" }
          }
        }
      }
    }
  end
  return storage.diverter_settings[unit_number]
end

---

## 4. Widget Hierarchy & Property Specification

Implement in scripts/diverter-gui.lua:

* Main Frame: type = "frame", direction = "vertical", name = "diverter_configuration_frame", added to player.gui.screen.
  * Titlebar Flow (direction = "horizontal"):
    * Title Label: type = "label", style = "frame_title", caption = "Pneumatic Diverter Configuration".
    * Draggable Spacer: type = "empty-widget", style = "draggable_space".
    * Close Button: type = "sprite-button", name = "diverter_close_button", style = "frame_action_button", sprite = "utility/close".
  * Inner Frame: type = "frame", style = "inside_shallow_frame_with_padding".
    * Port Grid Table: type = "table", column_count = 2, horizontal_spacing = 12, vertical_spacing = 12.
      * Port Card Frame (4 instances, port_index = 1..4): type = "frame", direction = "vertical", style = "bordered_frame".
        * Header Row Flow (direction = "horizontal"):
          * Port Checkbox: type = "checkbox", name = "port_enable", caption = "Port " .. i .. ": " .. dir_name, state = port_data.enabled.
        * Direction Control Flow (direction = "horizontal"):
          * Label: type = "label", caption = "Direction:".
          * Switch: type = "switch", name = "port_direction_switch", allow_none = false, left_caption = "Input (Pull)", right_caption = "Output (Push)", switch_state = (port_data.mode == "input" and "left" or "right").
        * Divider: type = "line", direction = "horizontal".
        * Filter Settings Flow (direction = "horizontal"):
          * Checkbox: type = "checkbox", name = "port_use_filters", caption = "Use Filters", state = port_data.use_filters.
          * Spacer: type = "empty-widget", horizontally_stretchable = true.
          * Mode Switch: type = "switch", name = "port_filter_mode_switch", allow_none = false, left_caption = "Whitelist", right_caption = "Blacklist", switch_state = (port_data.filter_mode == "whitelist" and "left" or "right").
        * Filter Slot Container Table: type = "table", column_count = 3, vertical_spacing = 4.
          * Slot Pair Flow (5 instances, slot_index = 1..5): type = "flow", direction = "horizontal".
            * Item Button: type = "choose-elem-button", name = "filter_slot_button", elem_type = "signal", signal = filter_data.name.
            * Quality Dropdown: type = "drop-down", name = "filter_quality_dropdown", items = {"any", "=", "≥", "≤", ">", "<", "≠"}, selected_index = comparator_index.

---

## 5. Event Handling & State Mapping

Assign element tags { unit_number = entity.unit_number, port_index = i, slot_index = j } to every interactive element during construction.

| Event ID | Target Widget | State Logic Handled |
| :--- | :--- | :--- |
| on_gui_opened | Physical Machine / Proxy | Destroys previous frame, constructs screen GUI, attaches tags, sets player.opened = frame. |
| on_gui_checked_state_changed | port_enable, port_use_filters | Updates enabled or use_filters booleans in storage.diverter_settings. |
| on_gui_switch_state_changed | port_direction_switch, port_filter_mode_switch | Updates mode ("input"/"output") or filter_mode ("whitelist"/"blacklist") strings. |
| on_gui_elem_changed | filter_slot_button | Writes signal selection to filters[slot_index].name. |
| on_gui_selection_state_changed | filter_quality_dropdown | Writes operator choice to filters[slot_index].comparator. |
| on_gui_closed / Click Close | Titlebar button or Escape | Destroys screen GUI frame and clears player.opened. |

---

## 6. Mandatory Developer Rules
1. Top-Level require Statements Only: Ensure all imports remain strictly at the very top of scripts/diverter-gui.lua and scripts/diverter-settings.lua.
2. Proxy Intercept Update: Modify pneumatic-diverter-proxy-linkage.lua so on_gui_opened triggers diverter_gui.open(player, entity) instead of setting player.opened = nil.
3. No Dynamic Pressure GUI Code: Omit all pressure label widgets from the GUI. Pressure simulation remains in networks-pressure.lua.