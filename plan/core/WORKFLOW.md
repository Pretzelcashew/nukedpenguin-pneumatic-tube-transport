# WORKFLOW.md - Developer Playbook & Routine Cheat Sheet
**Mod:** `nukedpenguin-pneumatic-tube-transport`  
**Purpose:** Quick-reference guide for prompts, tool usage, file updates, and release packaging.

---

## ⚡ Quick Prompt Selector

| What are you trying to do? | What to paste into the AI prompt |
| :--- | :--- |
| **Add a feature or fix a bug (Code)** | `plan/core/MANIFEST.md` + `plan/core/PROMPT-AG-DIFF.md` + Your Task |
| **Update prompts, guides, or docs (Markdown)** | Direct prompt asking for full file rewrite inside 4-backtick block (Routine 3 style) |
| **Create a Git commit & revision log** | `plan/core/PROMPT-REVISION-LOG.md` |
| **Update Architecture docs from notes** | `plan/core/PROMPT-DOC-SYNC.md` + `plan/core/MANIFEST.md` + `plan/core/FRESH-CHANGES.md` |
| **Update Mod Portal text / Splash** | Ask directly: *"Update short description / splash page in dry, non-flourishy Factorio style"* |

---

## 🛠️ Routine 1: Coding a Feature or Bugfix (The Loop)

Follow the muscle memory ritual:

1. **Start the Chat:**
   Paste `plan/core/MANIFEST.md` + `plan/core/PROMPT-AG-DIFF.md` + your task idea:
   ```text
   Target Task: [Describe the feature or fix in plain English]
   ```
   *Tip for large refactors (3+ files):* Append *"Break this into phases: patch 1 file at a time and wait for me to say 'next'."*
2. **First Search Query (Architecture):**
   * The AI outputs Query 1 (e.g., `filename: "ARCH-FLOW-KINETICS.md"`).
   * Copy that line.
   * Run Option `[1]` in `aggregator_patcher.py` and paste the query.
   * Paste the resulting `aggregate_1.txt` back to the AI.
3. **Second Search Query (Source Code):**
   * The AI reads the doc and outputs Query 2 (e.g., `filename: "flow-engine.lua"`).
   * Run Option `[1]` in `aggregator_patcher.py` and paste the query.
   * Paste the resulting `aggregate_2.txt` back to the AI.
4. **Apply the Patch:**
   * The AI generates a single ` ```text ` patch block using **Contextual Find & Replace** (`<<< FIND` / `=== REPLACE ===` / `>>>`) strictly anchored with 2–4 lines of context.
   * When refactoring or extracting functions, the AI uses 1-line facade delegations (`module.foo = new_module.foo`) to avoid large deletions.
   * Copy the code block.
   * Save it into `patch.txt` and run Option `[2]` in `aggregator_patcher.py`.
   * *If paced:* Test/verify, then reply `next` for the next file.
5. **Test in Factorio:**
   * If it works: Move to Routine 2.
   * If it crashes: Don't guess. Paste the exact Factorio crash log to the AI.

---

## 📝 Routine 2: Committing Code & Logging Changes

Keep coding momentum going without stopping to rewrite documentation:

1. **Ask for the Commit & Log:**
   Paste `plan/core/PROMPT-REVISION-LOG.md` into the same chat turn where you just finished the fix.
2. **Commit the Code:**
   * Copy **Block 1** (`text`) directly into the VS Code / Git commit message box.
3. **Save to Holding Pen:**
   * Copy **Block 2** (`markdown`) and append it to the bottom of `plan/core/FRESH-CHANGES.md`.
4. **Git Commit & Push.**
5. Move immediately to your next task!

---

## 📚 Routine 3: Syncing Architecture & Documentation (Full Overwrites)

Do this only after accumulating 5–10 revision entries in `FRESH-CHANGES.md`, at the end of a milestone, or when updating prompt/meta files.

1. **Open a Fresh Chat.**
2. **Send the Triage Prompt:**
   Paste `plan/core/PROMPT-DOC-SYNC.md` + `plan/core/MANIFEST.md` + the contents of `plan/core/FRESH-CHANGES.md`.
3. **AI Triages the Changes:**
   * The AI outputs a single 1-click Windows search query block for `aggregator_patcher.py` (e.g. ` ```filename: "ARCH-HUBS-LOGISTICS.md"``` `).
4. **Supply the File via Aggregator:**
   * Run Option `[1]` in `aggregator_patcher.py` with that query.
   * Paste the resulting `aggregate_1.txt` back into chat.
5. **Overwrite the File (Zero Silent Corruption):**
   * The AI outputs the **complete, updated file** inside a 4-backtick code block.
   * Click **Copy**.
   * Open the file in VS Code, press `Ctrl+A` -> `Ctrl+V` -> `Ctrl+S`.
6. **Clean the Holding Pen:**
   * Clear out the processed entries in `plan/core/FRESH-CHANGES.md` (or archive them into `CHANGELOG.md`).

---

## 📦 Routine 4: Releasing & Packaging the Mod

1. **Update Workspace Tree:**
   * Double-click `update_hierarchy.py` in the root directory.
   * Verifies `FOLDER-HIERARCHY.md` is updated.
2. **Bump Version:**
   * Update `"version"` in `info.json`.
   * Add the release notes header to `changelog.txt`.
3. **Build the Zip:**
   * **Drag and drop your mod folder directly onto `plan/core/package.py`.**
   * The script automatically reads `info.json` and creates a clean release zip:
     `nukedpenguin-pneumatic-tube-transport_<version>.zip`
4. **Upload to Mod Portal.**

---

## 🌐 Routine 5: Mod Portal Text & Descriptions

When updating mod portal presence, avoid AI marketing buzzwords ("blistering", "revolutionary", "high-impact").

* **Short Description (`info.json` & Search Card, < 255 chars):**
  > *"Fast, high-throughput item and player logistics via custom pressurized tube networks, specialized capsules, multi-port diverters, and electromagnetic launch projectors."*
* **Full Portal Page / Splash:**
  * Base text lives in `plan/core/SPLASH-PAGE.md`.
  * If updating, prompt the AI:
    > *"Update my mod splash text based on these new features. Keep the tone dry, direct, and technical like official Factorio patch notes. No marketing fluff."*