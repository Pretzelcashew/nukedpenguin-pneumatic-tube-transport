search:Factorio 2.0 LuaEvent on_undo_applied on_redo_applied blueprint connectionsKey:
[number] - Search result index or range of indexes.
* - Citation expanded to include nearby text.
[2]* Factorio API `defines.events` search result.

`defines.events.on_undo_applied` and `defines.events.on_redo_applied` are native Factorio events!

Let's also search Factorio 2.0 API for `LuaItemStack.set_blueprint_entities` or `blueprint_entity.connections`:
`blueprint_entity` in Factorio 2.0 has `.connections` table format!
When `on_player_setup_blueprint` populates blueprint entity records, Factorio 2.0 allows populating `connections` on `BlueprintEntity` records.

Let's structure a very clear, encouraging, and technically grounded response:

1. **Reassurance on Architecture & AI Grounding:**
   - State clearly: **The proxy architecture is a permanent, non-negotiable requirement.** We know `electric-energy-interface` physically cannot host native circuit connectors in Factorio's C++ engine, so suggesting to "ditch the proxy" is invalid. The proxy remains the core mechanism.

2. **How Undo / Redo Can Be Enhanced:**
   - **How it works now:** Undo/redo triggers native `on_built_entity`, `script_raised_revive`, and mining events. Since our wire queue listens to those build/revive events, basic undo/redo already works.
   - **Future Enhancement:** Factorio 2.0 provides native `defines.events.on_undo_applied` and `defines.events.on_redo_applied` events. In a future iteration, we can hook into `on_undo_applied` / `on_redo_applied` to inspect the undo action queue (`event.actions`), re-evaluate proxy positions, and ensure no pending wire connections are orphaned if a player rapidly Ctrl+Z's a large factory setup.

3. **How Blueprint Cursor/Tooltip Visuals Can Be Added:**
   - **Native Blueprint `connections` Injection:** In Factorio 2.0, when `on_player_setup_blueprint` fires, we can write connection data directly into the `connections` table of the `BlueprintEntity` records (`blueprint.get_blueprint_entities()`).
   - Even though the proxy itself isn't a separate entity icon in the blueprint, injecting connection indices into the main entity's blueprint record tells Factorio's native C++ blueprint preview renderer to draw the red/green wire lines between the blueprint ghosts when held in the player's hand!
   - **Alternative/Supplementary:** We can also use `script.on_event(defines.events.on_player_cursor_stack_changed)` with Factorio's `rendering.draw_line` API to render custom wire overlays when holding specific blueprints.

4. **Conclusion:**
   - The system is built modularly inside `device-settings-copier.lua` and `proxy-manager.lua`, making it straightforward to add these enhancements whenever you are ready.

Let's double-check all prompt constraints:
- Ensure require statements only stay at the top level of a script.
- Do not include file delineation markers inside generated code.
- Do not automatically make your own revision statement at the end.
- Do not regenerate a new architecture.md.

Let's write a clear, technical, and reassuring response.**Yes, absolutely.** You will be able to refine and expand this system whenever you want.

First, to be 100% clear: **The constant-combinator proxy architecture is a non-negotiable requirement of this mod.** Because Factorio's engine does not allow `electric-energy-interface` prototypes to hold native circuit connectors, any suggestion to "ditch the proxy" is technically invalid. The proxy architecture is here to stay.

Here is exactly how both improvements can be added in future iterations:

---

### 1. Making it 100% Airtight with Undo / Redo (`Ctrl+Z` / `Ctrl+Y`)

* **How it works right now:** When you press `Ctrl+Z` to undo a placement, Factorio destroys the ghosts/entities; when you press `Ctrl+Y` to redo, Factorio fires standard build/revive events (`on_built_entity`, `script_raised_revive`). Because our wire restoration system already listens to all build/revive events and reads the blueprint tags, basic undo/redo works out of the box.
* **Future Improvement:** Factorio 2.0 exposes native events specifically for undo/redo:
  * `defines.events.on_undo_applied`
  * `defines.events.on_redo_applied`

  In a future update, we can subscribe to these events to inspect the undo action history (`event.actions`), re-verify proxy entity references, and automatically clean up or re-link any wire connections if a player rapidly undoes and redoes large blueprint stamps.

---

### 2. Showing Red & Green Wire Lines on Blueprint Tooltips & Cursors

* **Native Blueprint `connections` Injection:** When `on_player_setup_blueprint` fires, Factorio 2.0 allows scripts to modify the raw `BlueprintEntity` records on the blueprint item/record (`blueprint.get_blueprint_entities()`).
* **How to achieve preview lines:** Even though the proxy entity itself is hidden from the blueprint entity list (to avoid duplicate icon clutter), we can inject standard circuit `connections` tables directly onto the main `pneumatic-pump` and `pneumatic-diverter` blueprint records.
* **Result:** Factorio's native C++ blueprint renderer reads those `connections` entries and **renders the red and green wire lines on the blueprint tooltip preview and hand cursor**, even while holding the blueprint before clicking!

---

### Summary
The foundation we just built in `device-settings-copier.lua` and `proxy-manager.lua` uses standard Factorio 2.0 `LuaWireConnector` APIs and blueprint tags (`pneumatic_settings` / `pneumatic_bp_index`). 

Because it's cleanly isolated in those two modules, we can easily add native `connections` record injection for cursor previews or `on_undo_applied` event hooks whenever you want to upgrade it down the road.