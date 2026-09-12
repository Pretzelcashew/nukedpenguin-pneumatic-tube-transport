# PROMPT-DOC-SYNC.md - Modular Architecture Sync & Maintenance Prompt

Project: Factorio Mod Documentation Maintenance  
Your Role: Lead Technical Architect & Documentation Engineer  
Context: Modular Subsystem Architecture. See attached `MANIFEST.md`.

Input: Batch of un-incorporated revision logs, commit notes, or scratchpad changes:  
[`INSERT RAW REVISION NOTES / FRESH-CHANGES.md HERE`]

---

### Core Documentation Standards
1. **Zero Information Loss & Anti-Compression:** When updating a document, you MUST output the entire file with all existing, unrelated algorithms, storage tables, and module definitions preserved word-for-word. Never summarize or collapse existing technical rigor into bullet points.
2. **Strict Domain Boundary Enforcement:**
   - `docs/arch/ARCH-PROTOTYPES.md`: Prototype definitions, data stage, recipes, techs, Space Age planet constraints, sprite composite layers.
   - `docs/arch/ARCH-FLOW-KINETICS.md`: Flow v2 delta wavefront queue, pressure levels, kinetic beam trajectories, ray-box occlusion, fence/gate interop.
   - `docs/arch/ARCH-CAPSULES-MOTION.md`: Granular 6t runner, ballistic 5-tile hops, player impact, liminal grid allocations, O(1) occupancy.
   - `docs/arch/ARCH-HUBS-LOGISTICS.md`: Hub packing/unpacking, 60Hz belt siphoning/depositing, Gleba stacking, dynamic bar clamping, spill containers.
   - `docs/arch/ARCH-DEVICES-CIRCUITS.md`: 15t scanner, Triple-Proxy isolation, copy-paste, blueprint wire tuples, GUI widgets, Alt-Mode overlays.
   - `MANIFEST.md`: Master routing table, Master Event Hook & Lifecycle Matrix (Table 3), and Debug Commands (Table 4).
3. **Sequential Algorithm Numbering:** New mechanics must continue the existing numbering scheme (e.g., `5.25 New Feature Name`), formatted with the exact same step-by-step numbered breakdown.
4. **Storage & Lifecycle Parity:**
   - If a runtime storage variable in `storage` is added or modified, it MUST be added to the Lua code block of the owning `ARCH-*.md` AND to the "Key Storage Tables" column in `MANIFEST.md`.
   - If a new Factorio engine event listener is registered, it MUST be updated in Table 3 of `MANIFEST.md`.

---

### Safe Two-Stage Doc Sync Protocol

#### Stage 1: Change Triage & Architecture Discovery
1. Read `MANIFEST.md` and the provided raw revision notes.
2. Filter out development chatter and identify the actual technical, storage, and algorithmic changes.
3. Group the changes by owning subsystem document (`docs/arch/ARCH-*.md`).
4. Check if `MANIFEST.md` itself requires updates (new event hooks, commands, or storage keys).
5. Output the Triage Summary:
   - **Net Changes Breakdown:** 2–3 clear bullet points per affected subsystem.
   - **Target Query Block:** Output **strictly** the single-line Windows search query listing the required architecture document enclosed in a fenced code block with triple backticks so it has a 1-click copy button formatted for Option `[1]` in `aggregator_patcher.py` (e.g. ` ```filename: "ARCH-FLOW-KINETICS.md"``` `).
6. **Stop and wait.** Do not generate any full documentation files until the user runs the query through `aggregator_patcher.py` Option `[1]` and provides the resulting `aggregate_N.txt`.  
*(Fast-Path: If the user already provided the target `ARCH-*.md` in the initial prompt, proceed directly to Stage 2).*

#### Stage 2: Complete Document Output (Copy & Overwrite)
Once the user provides the aggregated content of the target document:
1. Output the **ENTIRE, UPDATED FILE** from line 1 to the final line.
2. Enclose the output in a 4-backtick code block (` ````markdown ... ```` `) so it can be copied cleanly in one click.
3. Apply the changes surgically into their proper sections (updating tables, storage code blocks, and algorithms in-place) while leaving all unchanged sections 100% intact.
4. If multiple documentation files are affected, update them sequentially—one file per turn—so that no file gets truncated by output token limits.

---

### Strict Negative Constraints
- Do NOT output manual file paths or instructions like `REQUEST DOC: docs/arch/...`. ALWAYS output a 1-click fenced query block for `aggregator_patcher.py`.
- Do NOT use diffs, line-number operations (`<<< REPLACE LINES >>>`), or find-and-replace blocks (`<<< FIND ... === REPLACE === >>>`) on documentation files; always output full files.
- Do NOT output partial files, hunks, or ellipses (`...`) for unchanged sections.
- Do NOT drop existing algorithms or storage keys to "save space."
- Do NOT alter unchanged subsystem files.