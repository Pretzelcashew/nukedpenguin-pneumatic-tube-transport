# HELPERS.md - Developer Cheat Sheet & Sandbox Toolkit
**Mod:** `nukedpenguin-pneumatic-tube-transport`  
**Purpose:** Quick-reference collection of runtime console commands, test item spawners, regex utilities, and recurring AI prompts.

---

## 🎮 1. In-Game Testing Commands

### Hot-Reload Runtime Lua
Reloads `control.lua` and all active scripts without restarting Factorio or reloading the save.
```lua
/c game.reload_script()
```

### Respawn / Attach Character Body
Recreates and binds a physical character entity to the player (useful when stuck in god mode or after sandbox wipes).
```lua
/c local p = game.player; p.set_controller{type=defines.controllers.character, character=p.surface.create_entity{name='character', force=p.force, position=p.position}}
```

---

## 🧪 2. Cargo & Metadata Test Spawners

### Mass Spoilage Injection (500 Eggs @ 95% Spoil)
Fills inventory with 500 near-spoil biter eggs to test Wide Liminal Surface allocations, spoilage ticks, and bio-capsule decay.
```lua
/c local player = game.player for i=1, 500 do player.insert{name="biter-egg", count=1, spoil_percent=0.95} end
```

```lua
/c local player = game.player for i=1, 20 do player.insert{name="pentapod-egg", count=1, quality="legendary", spoil_percent=0.95} end
```

### Full-Spectrum Metadata Test Chest
Spawns an iron chest at your feet filled with every category of item metadata to verify that packing, unpacking, spills, and capsule transit preserve 100% of item state:
```lua
/c local p=game.player; local surf=p.surface; local pos=p.position; local chest=surf.create_entity{name="iron-chest", position=pos, force=p.force}; if chest then local inv=chest.get_inventory(defines.inventory.chest); local function g(n) return inv.find_item_stack(n) end; if inv.insert{name="repair-pack"}>0 then g"repair-pack".durability=0.5 end; if inv.insert{name="firearm-magazine"}>0 then g"firearm-magazine".ammo=5 end; if prototypes.item["jellynut"] and inv.insert{name="jellynut"}>0 then g"jellynut".spoil_tick=game.tick+prototypes.item["jellynut"].spoil_ticks/2 end; if inv.insert{name="stone-wall"}>0 then g"stone-wall".health=0.3 end; if inv.insert{name="selection-tool"}>0 then g"selection-tool".custom_description="test-id-123" end; if inv.insert{name="power-armor-mk2"}>0 then local s=g"power-armor-mk2"; if s.grid then s.grid.put{name="personal-laser-defense-equipment"} end end; p.print("Test chest created successfully!") end
```

---

## ✂️ 3. Text & Regex Utilities

### Strip Bracketed Citations from Text
Removes `[cite]` or web citation tags from AI responses in VS Code or text editors (Find & Replace with Regex enabled):
```regex
\s*\[cite[^\]]*\]
```

---

## 🤖 4. Quick AI Prompts

### Sanity & Performance Review
Paste this after a patch to verify efficiency and edge cases:
```text
What changed? In what situations will it help? Is my logic and performance preserved?
```

### Git Commit & Revision Log (Combined)
One-click prompt to generate both your commit message and your holding pen revision log:
```text
Now generate both my Git commit message and my Revision Log block based on the changes we just made.
Include today's date YYYY-MM-DD HH:MM (EDT/EST). Do NOT use cite blocks.

Output in TWO separate fenced code blocks so I can copy them individually:

Block 1 (text): Git commit title and message to paste directly into VS Code Git commit box.
Block 2 (markdown): Full revision block formatted for FRESH-CHANGES.md:

### Revision: <Title>
**Date:** YYYY-MM-DD HH:MM (EDT)
**Context:** <1-2 sentences on the problem and solution>
**Key Changes:**
1. **<Component> (`<file_path>`):** <Detail>
2. **<Component> (`<file_path>`):** <Detail>
```

### Architecture Sync Request
Triage prompt to initiate document maintenance:
```text
Please sync our documentation with the latest changes:
1. Update Architecture: Modify the relevant ARCH-*.md to fully reflect all changes, incorporating the final net results and updated system architecture state.
2. Output Format: Provide the full, updated contents of the file in a single 4-backtick code block ready to copy and paste.
```

### Refactor Request
Prompt for requesting a refactor of large files
```text
Target: Identify refactor candidates (large files with SoC violations, duplicated code which could be merged into commons).
```