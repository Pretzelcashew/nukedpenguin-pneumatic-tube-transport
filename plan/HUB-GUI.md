Circuit connection
=================================================
Input                                [✓] R  [✓] G
-------------------------------------------------
[✓] Enable send         [✓] Use circuit network
    [ Signal ]  [ < ▼ ]  [ 0 ]
-------------------------------------------------
[✓] Enable receive      [✓] Use circuit network
    [ Signal ]  [ < ▼ ]  [ 0 ]
=================================================


* **Hub Circuit Network GUI Integration**
  * **Description:** Build a custom relative GUI panel docked to the hub container window, adding manual state toggles and optional circuit condition overrides for `can_send` and `can_receive`.
  * **Details:**
    * **GUI Layout:** Uses `defines.relative_gui_type.container_gui` to dock to the main chest interface. Standard `[✓] R` and `[✓] G` wire toggles in the header filter incoming circuit channels.
    * **Dual Control Logic:** Features manual `Enable send` / `Enable receive` toggles alongside individual `Use circuit network` checkboxes. When enabled, circuit conditions dynamically override the hub's operational state.
    * **Condition Selectors:** Employs standard `choose-elem-button` widgets (`elem_type = "signal"`), operator dropdowns, and numeric fields for condition evaluation.
    * **Vanilla Signal Output:** Relies on the hub's native container prototype for inventory signal reading; no custom GUI output handlers or script-driven wire signals are required.
  * **Target File(s):** `prototypes/entity.lua`[cite: 1], `scripts/hubs/hub-manager.lua`[cite: 1], `scripts/hubs/hub-gui.lua` *(new file)*