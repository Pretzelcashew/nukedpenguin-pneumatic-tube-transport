You are acting as the Principal AI Developer for a mature Factorio 2.0 mod (`nukedpenguin-pneumatic-tube-transport`).

### Objective: Complete Ghost Entity Parity across Diverters, Pumps, and Cargo Hubs
We need to resolve three critical issues regarding ALL ghost device variants (Pneumatic Diverters, Pneumatic Pumps, and Cargo Hubs) across the codebase:

1. **Ghost Settings Binding & GUI Persistence:** Modifying settings (filters, whitelist/blacklist, circuit conditions, port modes) in the GUI for ANY ghost entity must bind cleanly to `storage` by `ghost.unit_number`. Ghosts do NOT participate in active circuit network signal reading (`get_signal`) or flow simulation—they simply store configuration data.
2. **Ghost Alt-Mode Filter Overlays:** Alt-Mode filter overlays must render over ghost diverters in the world whenever filter rules are configured. (and use filter is toggled on)
3. **Ghost Settings Migration on Build/Revive:** When a construction robot or player builds a physical entity over a ghost (or revives a ghost), the newly created physical entity must inherit the ghost's configured settings from `storage` instead of resetting to default. This applies equally to Diverters, Pumps, and Cargo Hubs.

---

### Strict Architectural Philosophy: Clean Ghost Parity
Ghosts are static configuration projections. The settings layer must treat ghosts with clean separation:

1. **Transparent Identity Resolution:** In `port-defs.lua`, state queries, and GUI controllers, always resolve `local real_name = (entity.name == "entity-ghost") and entity.ghost_name or entity.name`. A ghost device *is* that device for configuration queries.
2. **Decoupled Configuration & Simulation:** Ghost entities store settings in `storage` (`storage.diverter_settings`, `storage.pump_settings`, `storage.hub_settings`) by `unit_number`. GUI edits update `storage` directly and trigger UI refreshes without running simulation power state or circuit signal checks on `entity-ghost`.
3. **Unconditional Alt-Mode Overlays:** Remove all `if not is_ghost` or `if entity.name ~= "entity-ghost"` guards wrapping `diverter_renderer.update_render(entity)` and device overlays. Overlay rendering must run for both real and ghost entities whenever filter rules are configured.
4. **Universal Ghost Settings Migration on Build:** In `active-device-scanner.lua` (Pumps & Diverters) and `hub-manager.lua` (Cargo Hubs) build events (`on_built_entity`, `on_robot_built_entity`, `script_raised_revive`, etc.):
   * Standard items placed from inventory do not carry blueprint tags (`event.tags` is `nil`).
   * When a real entity replaces a ghost, resolve `ghost_source` via `event.consumed_ghost`, `event.source`, or spatial lookup (`surface.find_entities_filtered` for matching `ghost_name` at `position`).
   * Copy settings from `ghost_source.unit_number` to `real_entity.unit_number` (via `diverter_settings.copy`, `pump_settings.copy`, or `hub_settings.copy`).

---

### Primary Files to Inspect
- `scripts/flow/port-defs.lua`
- `scripts/diverter-renderer.lua`
- `scripts/active-device-scanner.lua`
- `scripts/hubs/hub-manager.lua`
- `scripts/proxy-manager.lua`
- `scripts/diverter-settings.lua`
- `scripts/pump-settings.lua`
- `scripts/hubs/hub-settings.lua`

---

### Strict Operating Guidelines for Code Generation
1. **Require Statements:** `require` statements MUST stay strictly at the top level of every file.
2. **No File Delineation Markers:** Do NOT include markers like `=== FILE ===` inside code blocks.
3. **No Unsolicited Revision Statements:** Do NOT generate revision statements or changelogs at the end of responses unless explicitly requested.
4. **No Regenerating Architecture Documents:** Do NOT regenerate `ARCHITECTURE.md`.
5. **Initial File Request Rule:** Before writing any code, identify the necessary files, generate a single-line Windows File Explorer search string (e.g., `filename:"file1.lua" OR filename:"file2.lua"`, <= 259 characters limit per query), and request to see the contents first.

Begin by requesting the files you need to examine using the single-line search string format.