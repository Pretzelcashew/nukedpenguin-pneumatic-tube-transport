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


### Revision: Spatial Junction Flow Overlay Consolidation & Z-Ordering Fix
**Date:** 2026-09-05 20:01 (EDT)
**Context:** Resolve duplicate overlapping overlay circles, garbled text z-index fighting, and placement-order visual inconsistencies at connected flow junctions.
**Key Changes:**
1. **Spatial Position-Based Rendering (`scripts/flow/flow-engine.lua`):** Refactored Alt-Mode flow level visual overlays from individual port tracking (`pkey`) to unified spatial junction tracking (`pos_key`). `update_pos_render` guarantees exactly one circle and text object is rendered per physical tile coordinate, eliminating duplicate circle stacking and placement-order sensitivity.
2. **Dominant Flow Level Selection (`scripts/flow/flow-engine.lua`):** Implemented `get_dominant_port_at_pos` to evaluate all overlapping ports at a tile location and display the dominant magnitude flow level (`math.abs(level)`), resolving ties in favor of positive pressure and active machine emitters.
3. **Zero-Length Vector Suppression (`scripts/flow/flow-engine.lua`):** Updated `update_edge_render` to automatically discard zero-length vector line renders between co-located ports sharing the same `pos_key`.


### Revision: Concise Capsule Item & Factoriopedia Descriptions & Maintenance Correction
**Date:** 2026-09-05 20:27 (EDT)
**Context:** Provide concise Factoriopedia and tooltip descriptions for all pneumatic transport capsule items, detailing capacity scaling, quality rules, spoilage mechanics, and correct maintenance crafting facilities.
**Key Changes:**
1. **Concise Capsule Locale Descriptions (`config.cfg`):** Updated `[item-description]` entries for all six capsule variants (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `spent-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`) with punchy multiline specs covering slot capacity scaling, quality rules, organic slot cost discounts, 90% cryo spoilage reduction, dissolution/rupture risks, and emergency player ejection controls (`__CONTROL__capsule-emergency-exit__`).
2. **Assembling Machine Recharge Correction (`config.cfg`):** Corrected `refrigerated-capsule` and `spent-refrigerated-capsule` maintenance documentation to specify that coolant recharging with cold fluoroketone occurs at assembling machines.
3. **Prototype Description Cleanup (`prototypes/item.lua`):** Removed unused `factoriopedia_description` properties from `ItemPrototype` and `ToolPrototype` definitions, ensuring Factoriopedia and item tooltips cleanly render the localized multiline descriptions directly from `[item-description]`.


### Revision: Pneumatic Hub Binary Nest Capsules Configuration Toggle
**Date:** 2026-09-05 20:43 (EDT)
**Context:** Enable players to configure Pneumatic Hubs to either exclusively nest capsule vessel items inside outgoing capsules or restrict packing strictly to non-capsule cargo items.
**Key Changes:**
1. **Hub Settings State & Blueprint Sync (`scripts/hubs/hub-settings.lua`):** Added `nest_capsules = true` default setting to `hub_settings.get()`, ensuring property preservation across entity copy-paste (`hub_settings.copy`) and blueprint tag deserialization (`hub_settings.apply_blueprint_settings`).
2. **Operational Mode GUI Checkbox (`scripts/hubs/hub-gui.lua`):** Added a "Nest capsules" checkbox to the Hub relative settings window, wiring `on_gui_checked_state_changed` to update `settings.nest_capsules` and invoke `hub_manager.notify_settings_changed()` to wake active scanners.
3. **Inventory Packing Filter Pipeline (`scripts/hubs/hub-packing.lua`):** Updated `evaluate_inventory()` to filter candidate cargo stacks based on `nest_capsules`: restricting cargo choices strictly to registered capsule variants (`capsule_defs.types`) when enabled, or excluding capsule items when disabled.


### Revision: Native-Style Live Source Entity Copy-Paste & Ghost Settings Parity
**Date:** 2026-09-06 10:02 (EDT)
**Context:** Align entity settings copy-paste mechanisms with Factorio 2.0 native behavior by tracking live source entities instead of static snapshots, requiring live source existence, and bringing 1:1 settings copy, rotate, and revival parity to ghost entities.
**Key Changes:**
1. **Live Entity Source Tracking (`scripts/device-settings-copier.lua`):** Updated `on_copy_settings` to store live `LuaEntity` references in `storage.player_copy_buffer`, evaluating live settings and relative entity directions dynamically at the tick of paste execution (`apply_live_settings_copy`).
2. **Source Validity Guard (`scripts/device-settings-copier.lua`):** Added strict `source and source.valid` checks across custom hotkey and native `on_entity_settings_pasted` events, preventing paste operations if the source machine or ghost was destroyed or mined.
3. **Ghost Proxy Target Resolution (`scripts/device-settings-copier.lua`):** Enhanced `resolve_target_entity` to inspect `ghost_name` when targeting ghost entities or clicking proxy circuit terminals overlaying unbuilt ghost structures.
4. **Ghost Entity Settings Lifecycle (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Refactored build, destroy, and rotate event listeners to resolve ghost entity names (`is_ghost and entity.ghost_name or entity.name`), enabling blueprint tag deserialization, orientation rotation, revival transfer (`event.source`), and storage cleanup for ghost pumps, diverters, and hubs.


### Revision: Pneumatic Ghost Entity GUI Evoking, Live Settings & Copy-Paste Parity
**Date:** 2026-09-06 10:34 (EDT)
**Context:** Achieve 1:1 parity with native Factorio 2.0 ghost interactions by enabling configuration GUI opening, live setting updates, rotation sync, and copy-paste handling across ghost pumps, diverters, and hubs.
**Key Changes:**
1. **Ghost Entity Search & Proxy Resolution (`scripts/proxy-manager.lua` & `scripts/hubs/hub-gui.lua`):** Updated `on_gui_opened` to resolve `entity.ghost_name` and locate ghost main entities when clicking circuit proxies, allowing players to open configuration windows on unbuilt ghost entities.
2. **O(1) Ghost Entity Tracking (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Added `storage.ghost_devices` and `storage.ghost_hubs` tables to record active ghost entities by `unit_number`, enabling instant entity resolution during GUI change events.
3. **Ghost Live GUI Updates & Observer Sync (`scripts/pump-gui.lua`, `scripts/diverter-gui.lua`, `scripts/hubs/hub-gui.lua`):** Refactored `notify_change` to resolve ghost entities, triggering scanner notifications and live UI frame re-renders (`refresh_if_open`) whenever ghost settings are modified.
4. **Ghost Rotation & Copy-Paste Parity (`scripts/active-device-scanner.lua` & `scripts/device-settings-copier.lua`):** Triggered setting updates on ghost rotation/flip events and un-guarded `apply_live_settings_copy` to notify observers and refresh open GUIs when pasting settings to ghost destinations.


### Revision: Ghost Entity Configuration Parity, Alt-Mode Overlays & Build Settings Adoption
**Date:** 2026-09-06 18:56 (EDT)
**Context:** Achieve 1:1 functional parity for ghost Diverters, Pumps, and Cargo Hubs by supporting full GUI interaction, world Alt-Mode filter overlay rendering, and automatic settings inheritance when building physical entities over ghosts.
**Key Changes:**
1. **Spatial Ghost Location Registry (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Implemented `storage.ghost_by_pos` mapping tile coordinates (`surface@x,y`) to ghost unit numbers. When a physical entity replaces a ghost (via inventory build, robot construction, or revive script), the newly created entity retrieves the ghost unit number and copies settings (`pump_settings.copy`, `diverter_settings.copy`, `hub_settings.copy`) even after the ghost object is consumed by the engine.
2. **Ghost GUI Registration & Live Observer Sync (`scripts/diverter-gui.lua`, `scripts/pump-gui.lua`, `scripts/hubs/hub-gui.lua`):** Registered open ghost entities directly into `storage.ghost_devices` and `storage.ghost_hubs`. Allows `notify_change()` to resolve ghost entity handles, triggering live scanner updates, world Alt-Mode overlay renders, and instant GUI frame re-renders when checkboxes, switches, or circuit conditions are modified.
3. **Decoupled Ghost Port Resolution & Circuit Isolation (`scripts/flow/port-defs.lua`, `scripts/pump-settings.lua`, `scripts/diverter-settings.lua`, `scripts/hubs/hub-settings.lua`):** Updated `port_defs.get_ports()` to resolve `ghost_name` transparently for world overlays while bypassing active circuit signal reads (`get_signal`) and proxy queries on ghost entities, isolating ghost settings storage from runtime simulation loops.
4. **Proxy Lifecycle Replacement Guard (`scripts/proxy-manager.lua`):** Updated `on_removed` to inspect tile coordinates for remaining main or ghost entities before destroying circuit proxies, preventing proxy wire disruption when physical entities replace ghosts.


### Revision: Ghost Entity Configuration Parity, Circuit Proxy Isolation & GUI Tag Resolution
**Date:** 2026-09-06 20:10 (EDT)
**Context:** Resolve ghost diverter GUI checkbox reset instability, prevent circuit proxy lifecycle events from wiping ghost settings storage, and ensure physical entities inherit and correctly rotate ghost configurations upon build/revive.
**Key Changes:**
1. **Ghost Device Position-Based Identity Resolution (`scripts/diverter-settings.lua`, `scripts/pump-settings.lua`, `scripts/hubs/hub-settings.lua`):** Implemented `get_device_id()` to produce stable spatial position keys (`ghost@name@surface@x,y`) for hand-placed and blueprint ghost entities that do not possess native `unit_number` properties in Factorio 2.0.
2. **Circuit Proxy Blacklist & Spatial Key Namespacing (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Blacklisted circuit proxy entities from build/destroy/rotate handlers and namespaced spatial position keys (`real_name@surface@x,y`), preventing circuit proxy spawns from falsely matching and erasing ghost device settings in `storage`.
3. **Recursive Parent GUI Tag Resolution (`scripts/diverter-gui.lua`):** Implemented `get_element_tags()` to traverse up the widget hierarchy (`element.parent`), enabling nested checkboxes, switches, and dropdowns to reliably retrieve device IDs attached to parent card frames.
4. **Suppressed Local GUI Re-Entrant Destructions (`scripts/diverter-gui.lua`):** Added a local GUI edit flag guarding `refresh_if_open`, preventing local user checkbox toggles from clearing `inner_frame` mid-click while preserving live UI re-renders for external rotation and copy-paste events.
5. **Ghost Settings Migration & Rotation Inheritance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Recorded `storage.ghost_directions` on placement/rotation and updated build event handlers (`on_built_entity`, `script_raised_revive`, etc.) to copy settings from ghost sources (`event.consumed_ghost`, `event.source`, or spatial lookup) and apply relative direction rotations.


### Revision: Ghost Spatial Identity, Directional Indexing & Rotation/Flip Build Inheritance
**Date:** 2026-09-06 20:46 (EDT)
**Context:** Ensure ghost pumps, diverters, and cargo hubs maintain and adapt configured settings across rotation, flipping, ghost-on-ghost replacement, and physical placement over ghosts regardless of orientation changes.
**Key Changes:**
1. **Spatial Device Identity Export (`scripts/pump-settings.lua` & `scripts/hubs/hub-settings.lua`):** Exported `get_device_id` across `pump_settings` and `hub_settings` matching `diverter_settings`, establishing a unified spatial identity schema (`ghost@name@surface@x,y` or `unit_number`) across all device storage layers.
2. **Cardinal Direction Enum Normalization (`scripts/diverter-settings.lua`):** Implemented `get_cardinal_index` to map Factorio 2.0 16-way, 8-way, and 4-way direction enum values (`0`, `4`, `8`, `12`) cleanly to cardinal indices (North=1 through West=4), ensuring relative step rotations are accurately calculated during settings copying.
3. **Pre-Registration Ghost Proximity Search (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Added `find_ghost_id_at_pos` spatial search (1.2 tile radius) to resolve preceding ghost settings prior to updating `storage.ghost_by_pos`, preventing newly placed entities from overwriting spatial lookup keys before reading settings.
4. **Ghost-on-Ghost & Flip Settings Inheritance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Removed `not is_ghost` guards from build event copy logic, allowing replacement ghosts spawned when flipping (`F`) or rotating (`R`) existing ghosts to inherit and adapt settings from preceding ghosts at the same tile coordinate.
5. **Deferred Ghost Settings Purge (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Deferred ghost settings deletion during ghost destruction events, preserving configuration tables in `storage` across engine entity replacement ticks.


### Revision: Object Destruction Tracking & Circuit Proxy Cleanup for Super Force Building
**Date:** 2026-09-06 20:56 (EDT)
**Context:** Resolve lingering orphan circuit proxy entities left behind when built or ghost diverters and pumps are mined, destroyed, or super force built over.
**Key Changes:**
1. **Self-Exclusion Removal Guard (`scripts/proxy-manager.lua`):** Updated `on_removed` to filter out `m ~= entity` and `g ~= entity` when evaluating remaining main or ghost entities at machine tile coordinates, preventing active destruction targets from falsely suppressing proxy removal.
2. **Object Destruction Registration (`scripts/proxy-manager.lua`):** Registered main built and ghost entities with `script.register_on_object_destroyed` inside `on_created`, tracking registration IDs in `storage.proxy_destruction_map` alongside surface, spatial position, and proxy specification metadata.
3. **Engine-Level Object Destroyed Callback (`scripts/proxy-manager.lua`):** Subscribed to `defines.events.on_object_destroyed` to catch C++ engine-level entity removals (such as super force building, fast replacement, and ghost cancellation). The callback evaluates remaining spatial main entities post-destruction and purges orphaned real and ghost circuit proxies when no host machine remains.


### Revision: Complete English Locale Recipe Description Coverage
**Date:** 2026-09-06 22:05 (EDT)
**Context:** Achieve 100% English locale coverage for all pneumatic transport crafting recipes, ensuring detailed localized descriptions render cleanly in Factoriopedia and crafting menu tooltips.
**Key Changes:**
1. **Localized Recipe Description Section (`config.cfg`):** Added a dedicated `[recipe-description]` section to the English locale configuration file.
2. **Comprehensive Recipe Description Entries (`config.cfg`):** Populated concise localized description strings for all 13 mod recipes (`item-capsule`, `biodegradable-capsule`, `refrigerated-capsule`, `recharge-refrigerated-capsule`, `reinforced-capsule`, `player-transit-capsule`, `capsule-hub-horizontal`, `capsule-hub-vertical`, `pneumatic-tube`, `pneumatic-pump`, `junction`, `crossflow-junction`, and `pneumatic-diverter`), detailing operational roles, capsule behaviors, and thermal byproduct discharges.


### Revision: Strict Ghost Settings Adoption, Spatial Bounding Box & Orientation Overlap
**Date:** 2026-09-06 23:01 (EDT)
**Context:** Prevent improper settings inheritance when placing physical entities or ghosts over ghosts with different bounding box shapes, orientation axes, or spatial offsets.
**Key Changes:**
1. **Strict Spatial Position Tolerance (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Tightened ghost spatial lookup distance matching from 1.2 tiles down to `< 0.1` tiles (`dx < 0.1, dy < 0.1`), preventing entities placed offset or 1 tile away from falsely adopting adjacent ghost configurations.
2. **Orientation Axis Alignment Guard (`scripts/active-device-scanner.lua` & `scripts/diverter-settings.lua`):** Exported `diverter_settings.get_cardinal_index` to enforce orientation axis checks (`(g_idx % 2) == (e_idx % 2)`), ensuring 1x2 and 2x1 pumps only inherit settings when placed along matching orientation axes (blocking adoption when placing horizontal pumps over vertical ghost pumps).
3. **Prototype Real-Name Compatibility (`scripts/active-device-scanner.lua` & `scripts/hubs/hub-manager.lua`):** Enforced exact prototype real-name equality (`g_real_name == real_name`) across ghost entity handles (`event.consumed_ghost`, `event.source`, or spatial lookup) prior to copying settings, preventing cross-prototype adoption between locked orientation hub variants (`capsule-hub-horizontal` vs `capsule-hub-vertical`).