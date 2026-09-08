Project: Factorio Mod Development
Your Role: Principal AI Developer (100% codebase author)
Context: Mature, iterated architecture. See attached `ARCHITECTURE.md`.

Target Task: we are incrementally getting closer to how i see vacuum capsules. right now they agnostically vacuum off of any belt touching the hub's ports. i would like to consider my options here, before blindly resorting to turning this into another hub toggle right of the bat. i want to support vacuum capsules siphoning as well as depositing onto belts. we pretty much have several avenues we could take:

1.) dependent on belt directionality, whether its pointed into the hub directly or pointing away (muddies the waters with other directions, and underground belt covers, so this is a less likely option)

2.) dependent on a hub toggle, vacuum mode siphon/deposit

3.) dependent on pressure exerted on the hub (like if the net pressure of all of its ports is a positive pressure, vacuum capsules deposit onto belts, and if net negative pressure, siphon off belts. this is probably the most interesting option)

4.) some sort of vanilla feeling output arrows like some machines have, like mining drills, (and can be change to intake), this option is also interesting but feels a bit separated from the vibes of a pressure system, but you have more control of where you output/input via arrows.
---

### Core Engineering Standards
1. **Deterministic Data Design:** Use exact O(1) set lookups and native Factorio 2.0 API features (`element.tags`). Do not use string parsing or pattern matching (`string.find`, `gsub`) for entity or UI identification.
2. **Native API Parity & Decoupled State:** Maintain clean separation between configuration state (stored in `storage`) and physical runtime simulation. Respect native Factorio entity conventions and state inheritance without artificial restrictions or defensive hacks.
3. **Plain-English Plan & Escape Hatch:** Explain your plan in 3 simple, non-technical sentences before generating code. If a genuine Factorio API limitation requires breaking a standard, stop and ask permission in plain English first.

---

### Constraints & Workflow Protocol
- All `require` statements MUST remain strictly at the top level of the script.
- Do NOT include file delineation markers inside generated code (e.g., `=== FILE ===`).
- Do NOT automatically make revision statements at the end; the user will ask if needed.
- Do NOT regenerate `ARCHITECTURE.md`.
- Review `ARCHITECTURE.md`, identify which specific source files you need to examine to complete this objective, generate a single-line Windows File Explorer search string (e.g., `filename:"file1.lua" OR filename:"file2.lua"`, <= 259 characters limit per query), and request them before writing any code. (If needed, request files in multiple segments).

Included revision notes which weren't yet incorporated into architecture.md: [`None OR attached FRESH-CHANGES.md`]