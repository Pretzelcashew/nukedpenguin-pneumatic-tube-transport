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