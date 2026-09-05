### Revision: Alt-Mode Diverter Filter Overlay Inward Shift & Solid Black Shadow Rendering
**Date:** 2026-09-04 22:39 (EDT)
**Context:** Prevent Alt-Mode diverter port filter item icons from overlapping port flow indicator dots while enhancing icon contrast and readability against machine entity visuals.
**Key Changes:**
1. **Topological Inward Shift (`scripts/diverter-renderer.lua`):** Implemented a directional vector offset calculation (`PORT_INWARD_OFFSET = 0.55`) that shifts port filter overlay clusters inward toward the entity center `(0,0)`, eliminating visual collision with port flow dots.
2. **Pitch-Black Silhouette & Drop Shadow (`scripts/diverter-renderer.lua`):** Added a 1.3x scaled centered outline (`OUTLINE_SCALE_MULTIPLIER = 1.3`) and a 1.3x scaled down-right offset drop shadow (`SHADOW_SCALE_MULTIPLIER = 1.3`, offset `0.04`) rendered with full-opacity black tint (`BLACK_TINT = {r=0, g=0, b=0, a=1.0}`) to form a high-contrast backing frame.
3. **Render Layer Z-Ordering (`scripts/diverter-renderer.lua`):** Structured rendering passes across explicit layers by drawing black outline and shadow elements on `render_layer = "entity-info-icon"` while rendering full-color item icons directly on top via `render_layer = "entity-info-icon-above"`.


### Revision: Diverter Settings Orientation Sync, Directional Copy-Paste & Decoupled Scanner Observer
**Date:** 2026-09-05 09:34 (EDT)
**Context:** Automatically rotate and flip Pneumatic Diverter port settings in sync with physical entity orientation changes, align filter settings when copy-pasting between differently oriented diverters, and eliminate a circular script require loop between active device scanning and GUI controllers.
**Key Changes:**
1. **Modulo Port Rotation & Axis Flipping (`scripts/diverter-settings.lua`):** Implemented `rotate_ports`, `rotate_ports_by_steps`, and `flip_ports` using cardinal index mapping (`North = 1` through `West = 4`) and modulo arithmetic (`(p - 1 + steps) % 4 + 1`) to shift port filter configurations in lockstep with entity rotation (`R`, `Shift+R`) and flipping (`F`, `Shift+F`).
2. **Direction-Aware Copy-Paste Alignment (`scripts/diverter-settings.lua` & `scripts/device-settings-copier.lua`):** Enhanced `diverter_settings.copy` and `device-settings-copier` to track source and destination entity directions, applying relative step rotations when pasting or cloning settings between diverters facing different directions.
3. **Decoupled Scanner Observer & UI Refresh (`scripts/active-device-scanner.lua` & `scripts/diverter-gui.lua`):** Added `active_device_scanner.on_settings_changed` subscriber callback registration to invoke `diverter_gui.refresh_if_open`, breaking a top-level circular `require` dependency loop while guaranteeing live UI frame re-renders when open diverter entities are rotated or modified.


### Revision: Diverter Alt-Mode Filter Overlay Quality Badges, Comparators & Text Alignment Fix
**Date:** 2026-09-05 09:58 (EDT)
**Context:** Achieve visual parity between Diverter Alt-Mode filter overlays and native Factorio 2.0 inserter filter overlays by rendering bottom-left quality badges and non-equal comparator symbols while resolving a rendering API parameter crash.
**Key Changes:**
1. **Bottom-Left Overlay Alignment (`scripts/diverter-renderer.lua`):** Repositioned quality badges and comparator symbols to the bottom-left corner of item filter overlay icons (`cx - scale * 0.28, cy + scale * 0.28`), supporting side-by-side rendering when both a comparator and quality tier are present.
2. **Wildcard & Tier Quality Badge Integration (`scripts/diverter-renderer.lua`):** Integrated `gui_components.get_quality_sprite` to draw the registered wildcard `pneumatic_any_quality_badge` for "Any Quality" filters and native quality tier icons (`quality/uncommon`, `quality/rare`, `quality/epic`, `quality/legendary`) with black outline backings.
3. **Non-Equal Comparator Text Overlay (`scripts/diverter-renderer.lua`):** Added dual-pass high-contrast white text rendering with black drop shadows for non-equal quality comparators (`>`, `<`, `≥`, `≤`, `≠`), omitting the default `=` symbol.
4. **Vertical Text Alignment Crash Fix (`scripts/diverter-renderer.lua`):** Updated `vertical_alignment` parameters in `rendering.draw_text` from invalid `"center"` to `"middle"`, eliminating non-recoverable Factorio C++ engine runtime exceptions.


### Revision: Diverter Alt-Mode Blacklist Filter Overlay & Native Filter Parity
**Date:** 2026-09-05 10:44 (EDT)
**Context:** Resolve 101x101 filter-blacklist sprite cropping and align Alt-Mode diverter filter overlay indicators with native Factorio 2.0 inserter filter conventions.
**Key Changes:**
1. **Blacklist Sprite Prototype Registration (`data.lua`):** Registered `pneumatic_filter_blacklist` sprite prototype using the exact 101x101 frame dimensions (`width = 101`, `height = 101`) for `__core__/graphics/filter-blacklist.png`, eliminating sprite clipping and giant red arc distortion.
2. **Resolution-Aware Scale Adjustment (`scripts/diverter-renderer.lua`):** Added `get_blacklist_sprite` helper with fallback to `utility/filter_blacklist`, adjusting render scale (`0.33` standalone, `scale * 0.41` overlaid) to match 64x64 item icon tile proportions.
3. **Native Inserter Filter Parity (`scripts/diverter-renderer.lua`):** Aligned filter overlay behavior with Factorio 2.0 inserter rules: renders a standalone centered "no" symbol when `use_filters` is enabled on empty whitelist ports (`item_count == 0` - blocking all flow), overlays a single top-right "no" symbol over configured blacklist item clusters (`item_count > 0`), and suppresses overlays on empty blacklist ports.


### Revision: Native Inserter Parity for Diverter Filter Overlays & Standalone Quality Badges
**Date:** 2026-09-05 13:37 (EDT)
**Context:** Achieve 1:1 visual parity with Factorio 2.0 native inserter filter overlays for Diverter Alt-Mode rendering and UI slot buttons, supporting standalone quality filters, non-equal comparator target quality badges, and per-slot blacklist indicators.
**Key Changes:**
1. **Standalone Quality Filter Layout (`scripts/diverter-renderer.lua` & `scripts/utils/gui-components.lua`):** Supported filter slots configured with quality criteria but no specific item (`item == nil`), rendering quality tier sprites (`quality/rare`, `quality/legendary`, etc.) in horizontal side-by-side alignment with comparator symbols (`[ Comparator ] [ Quality Badge ]`).
2. **Target Quality Badge Preservation for Non-Equal Comparators (`scripts/diverter-renderer.lua` & `scripts/utils/gui-components.lua`):** Corrected overlay logic so non-equal comparators (`>`, `<`, `≥`, `≤`, `≠`) always render the target quality tier badge—including `quality/normal` (grey dot)—explicitly displaying the comparison target.
3. **Per-Slot Prominent Blacklist Symbol Overlay (`scripts/diverter-renderer.lua`):** Moved blacklist "no" symbol rendering inside the per-slot filter loop, scaling indicators to `bl_scale = scale * 0.88` centered over each individual filter icon (`cx + scale * 0.05, cy - scale * 0.05`) rather than drawing a single miniature port-wide symbol.


### Revision: Diverter Alt-Mode Overlay Alignment Fix & Consolidated Filter Display Specification
**Date:** 2026-09-05 14:31 (EDT)
**Context:** Unify filter display specification rules across GUI slot buttons and Alt-Mode world overlays while resolving comparator text collision over quality badge dots in world rendering.
**Key Changes:**
1. **Unified Filter Display Specification (`scripts/utils/gui-components.lua`):** Implemented `gui_components.get_filter_display_spec` and `gui_components.get_active_filters` to centralize native Factorio 2.0 filter display rules (item sprites, comparator visibility, target quality badges, and standalone quality filters) across both GUI slot buttons and world overlays.
2. **GUI Slot Button Simplification (`scripts/utils/gui-components.lua`):** Refactored `gui_components.update_overlay_slot_button` to consume `get_filter_display_spec`, ensuring 100% rule parity with Alt-Mode overlays while maintaining GUI widget styling and bottom-flow badge layouts.
3. **Alt-Mode Badge & Comparator Offset Alignment (`scripts/diverter-renderer.lua`):** Corrected Alt-Mode rendering offset coordinates and text alignment for multi-badge configurations (`badge_x = cx - scale * 0.18`, `comp_x = cx - scale * 0.38`, `alignment = "right"`), placing comparator symbols cleanly to the left of quality badge dots to achieve 1:1 visual parity with native Factorio 2.0 inserters.
4. **World Rendering Pass Consolidation (`scripts/diverter-renderer.lua`):** Added `draw_text_with_shadow` and `draw_sprite_with_outline_and_shadow` helpers to consolidate multi-pass rendering objects (black outlines, drop shadows, and main sprites) across item filters, standalone quality badges, and blacklist indicators.


### Revision: Revert Diverter GUI Default View to 'All' Mode
**Date:** 2026-09-05 15:09 (EDT)
**Context:** Default the Pneumatic Diverter configuration GUI to display all four directional port cards simultaneously ("All" mode) upon opening, rather than focusing single-port North view by default.
**Key Changes:**
1. **Default View State (`scripts/diverter-gui.lua`):** Updated `diverter_gui.open` and `diverter_gui.refresh_if_open` to default `current_view` to `"all"` instead of `1` (North port), rendering the full 4-port grid when opening the diverter interface without an explicit initial view parameter.


### Revision: Filter Slot Draft State, Quality Preservation & Draggable Modal GUI
**Date:** 2026-09-05 16:00 (EDT)
**Context:** Achieve native Factorio 2.0 filter configuration behavior by preserving existing quality/comparator rules on item swaps, isolating modal editing inside a draft working state, and making filter configuration pop-ups fully draggable.
**Key Changes:**
1. **Comparator & Quality Preservation (`scripts/utils/gui-components.lua`):** Refactored `gui_components.handle_filter_item_change` so selecting an item defaults to `=` and `normal` quality only if the slot is currently blank (`"Any Quality"`). Pre-configured comparators and quality tiers are preserved intact when changing item selections.
2. **Isolated Draft Filter State & Confirm Lifecycle (`scripts/diverter-gui.lua`):** Implemented a `draft_filters` working table in `diverter_gui.open_slot_config`. Interacting with items, quality radio buttons, or comparator dropdowns inside the modal updates only the draft without mutating persistent `diverter_settings` or leaking live updates to the machine. Drafts commit to the entity strictly upon clicking Confirm (✓) or pressing `E`/`Esc`, while clicking Cancel (X) discards unconfirmed changes.
3. **Window Focus & Draggable Header Integration (`scripts/diverter-gui.lua` & `scripts/utils/gui-components.lua`):** Removed `player.opened` re-assignment inside `open_slot_config` to prevent Factorio's engine from triggering `on_gui_closed` on the main frame and destroying the modal pop-up on spawn. Enhanced `gui_components.add_header` with `drag_target = parent_frame` across header title flows and drag spacers, making modal filter windows fully draggable across the viewport.


### Revision: Diverter GUI Per-Port Copy-Paste & Native Tool Buttons
**Date:** 2026-09-05 16:15 (EDT)
**Context:** Enable players to quickly duplicate filter rules, circuit conditions, and directional flow settings between individual diverter ports via native tool buttons and player-scoped clipboard storage.
**Key Changes:**
1. **Port Settings Copy-Paste API (`scripts/diverter-settings.lua`):** Added `diverter_settings.copy_port` and `diverter_settings.paste_port` to produce isolated deep-copies of port configurations and apply them to target ports while invalidating compiled filter caches (`_compiled = nil`).
2. **Native Tool Button Header Integration (`scripts/diverter-gui.lua`):** Added `port_copy_button` and `port_paste_button` using Factorio 2.0 `tool_button` sprite styles (`utility/copy` and `utility/paste`) to each port card header. Dynamically disabled paste buttons when `storage.port_clipboard[player_index]` is empty.
3. **Cursor Flying Text Feedback & Live Refresh (`scripts/diverter-gui.lua`):** Wired `on_gui_click` handlers to populate player clipboard storage, trigger `notify_change()` to update world overlays and active device scanners, refresh open GUIs, and display cursor floating text feedback (`create_at_cursor = true`).


### Revision: Blueprint Proxy Wire Tuple Fix & Instant Zero-State Reconstruction
**Date:** 2026-09-05 16:42 (EDT)
**Context:** Resolve a critical blueprint proxy wire corruption bug where stamped blueprint entities generated a web of erroneous circuit wire connections to the top-left entity (Entity #1) and leaked wire memory across unrelated blueprint placements.
**Key Changes:**
1. **Blueprint Wire Tuple Format Fix (`scripts/device-settings-copier.lua`):** Corrected `add_bp_wire` tuple array formatting to insert `proxy_bp_entity.entity_number` as the first element (`[entity_from, wire_type_from, entity_to, wire_type_to]`) instead of `src_conn_id`. Passing `1` (red wire connector ID) in position 1 previously caused Factorio's C++ blueprint parser to decode Entity #1 as the source for every wire in the blueprint, producing spiderweb cross-links to the top-left machine.
2. **Purged Persistent Pending Wire Queue (`scripts/device-settings-copier.lua`):** Removed `storage.bp_wire_cache` and `storage.pending_bp_wires` multi-tick storage buffers. Refactored `process_entity_built_wire_tags` to perform zero-state, instant spatial wire target resolution strictly on the build tick via `surface.find_entities_filtered` and relative distance matching (`is_valid_wire_target`), completely preventing cross-linking across separate blueprint stamps placed over time.
3. **Strict Target Entity Validity Guards (`scripts/device-settings-copier.lua`):** Added explicit `unit_number` and `.valid` checks across target entity lookups and table index accesses, preventing C++ `__newindex` metamethod runtime exceptions when destroyed ghost proxies are processed during blueprint placement events.


### Revision: Pneumatic Pump GUI Interaction Parity & Entity GUI Mode Fix
**Date:** 2026-09-05 17:08 (EDT)
**Context:** Resolve an issue where left-clicking physical `pneumatic-pump` entities failed to open the pump configuration GUI, requiring players to click its hidden circuit proxy.
**Key Changes:**
1. **Entity GUI Mode Activation (`prototypes/entity.lua`):** Added `gui_mode = "all"` to the `pneumatic-pump` `electric-energy-interface` prototype definition. This enables native entity interaction event dispatching (`on_gui_opened`) when left-clicked, allowing `proxy-manager.lua` to intercept interactions and launch `pump-gui` in 1:1 functional parity with `pneumatic-diverter`.


### Revision: Native Confirm GUI Event Linking & Esc Modal Cancellation
**Date:** 2026-09-05 17:32 (EDT)
**Context:** Differentiate between pressing `E` (Confirm) and `Esc` (Cancel) when leaving the Diverter filter slot configuration modal, achieving 1:1 parity with native Factorio 2.0 GUI draft lifecycle conventions.
**Key Changes:**
1. **Confirm GUI Custom Input Registration (`prototypes/custom-input.lua`):** Registered `pneumatic-confirm-gui` linked to Factorio's native `confirm-gui` control sequence (`linked_game_control = "confirm-gui"`) with `consuming = "none"`.
2. **Tick-Based Confirm Event Tracking (`scripts/diverter-gui.lua`):** Subscribed to the `pneumatic-confirm-gui` custom input event to record the exact execution tick (`confirm_ticks[player_index] = event.tick`) when a player triggers the GUI confirmation key.
3. **Confirm vs. Cancel Dismissal Logic (`scripts/diverter-gui.lua`):** Updated `on_gui_closed` to evaluate whether `confirm_ticks[event.player_index] == event.tick`. Pressing `E` (or clicking the checkmark) passes `should_apply = true` to commit draft filter settings, whereas pressing `Esc` (or closing without confirming) passes `should_apply = false` to discard draft changes without mutating entity settings.


### Revision: Diverter Filter Draft Quality Synchronization & Standalone Quality Preservation
**Date:** 2026-09-05 17:53 (EDT)
**Context:** Prevent diverter slot configuration modals from silently holding ghost quality settings when clearing item selections, while maintaining full GUI and draft parity for standalone quality filters.
**Key Changes:**
1. **Item Clear Quality Preservation (`scripts/utils/gui-components.lua`):** Refactored `gui_components.handle_filter_item_change` so clearing an item selection preserves configured comparator and quality settings (updating GUI quality bar controls accordingly), while resetting quality to `"normal"` only if the comparator is set to `"Any Quality"`.
2. **Draft & Modal Synchronization (`scripts/diverter-gui.lua`):** Updated `diverter_gui.open_slot_config` and `close_slot_config` to guarantee 1:1 synchronization between GUI widgets and draft state tables (`draft_filters`), ensuring submitted configurations strictly match the visual state of the modal window.
3. **Stored Setting Normalization (`scripts/diverter-settings.lua`):** Enhanced `diverter_settings.get` to sanitize stored filter settings on load, enforcing `quality = "normal"` and clearing `explicit_quality` whenever a slot uses `"Any Quality"` without an item.


### Revision: Refrigerated Capsule Recharge Recipe Subgroup & English Localization
**Date:** 2026-09-05 19:53 (EDT)
**Context:** Organize the `recharge-refrigerated-capsule` recipe into the dedicated Pneumatic Transport crafting tab and provide localized recipe name display in the English locale configuration.
**Key Changes:**
1. **Recipe Subgroup & Tab Order (`prototypes/recipe.lua`):** Configured `subgroup = "pneumatic-capsules"` and `order = "c[refrigerated]-b[recharge]"` on `recharge-refrigerated-capsule`, moving the recipe out of the fallback "other/misc" subgroup and positioning it directly adjacent to the main refrigerated capsule recipe in the Pneumatic Transport crafting tab.
2. **English Recipe Localization (`config.cfg`):** Added `recharge-refrigerated-capsule=Recharge Refrigerated Capsule` under `[recipe-name]` in the English locale file.