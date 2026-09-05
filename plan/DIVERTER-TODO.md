Here is your todo list ordered from **easiest to hardest** to implement:

---

### 1. Revert GUI Default View to 'All' Mode *(Easiest)*
* **Difficulty:** 🟢 **Very Low** (1-line change)
* **Why:** In `diverter-gui.lua`, you just change `local current_view = initial_view or 1` to `local current_view = initial_view or "all"`.

---

### 2. Preserve Comparator & Quality on Item Selection *(Easy)*
* **Difficulty:** 🟢 **Low** (~5–10 lines)
* **Why:** In `gui_components.handle_filter_item_change`, you update the condition so it only sets defaults (`=` and `normal`) if the slot is currently blank (`"Any Quality"`). If a comparator/quality is already configured, selecting an item leaves them untouched.

---

### 3. Add Copy/Paste Port Settings Buttons *(Moderate)*
* **Difficulty:** 🟡 **Medium** (~30–50 lines)
* **Why:** Involves UI layout and event wiring:
  1. Add a small "Copy" / "Paste" button pair to each port header card in `diverter-gui.lua`.
  2. Store a player-scoped clipboard in `storage.port_clipboard[player_index]`.
  3. Handle click events to deep-copy a port's filter/mode settings and paste them onto a target port, calling `notify_change()`.

---

### 4. Fix Blueprint Wire Cross-Linking Bug *(Hardest)*
* **Difficulty:** 🔴 **High** (Investigation & Scoping)
* **Why:** Requires debugging deferred wire reconstruction in `device-settings-copier.lua` (`bp_wire_cache` / `pending_bp_wires`). You have to trace why wire target lookups during blueprint stamping are matching nearby entities outside the current blueprint stamp, then add spatial or blueprint-instance guards.