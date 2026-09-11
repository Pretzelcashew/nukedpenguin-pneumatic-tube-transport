# UPDATE-MOD-PAGE.md - Release Documentation Prompt Template

Use the prompt below whenever a new version revision or changes file is completed to generate clean, unhyped documentation.

---

## Copy & Paste Prompt for AI Assistant:

```text
I need to update `changelog.txt` and `SPLASH-PAGE.md` for my Factorio mod based on the latest changes notes provided below.

### Tone & Style Rules:
1. NO AI FLUFF OR MARKETING BUZZWORDS:
   - Do NOT use words like: "seamless", "cutting-edge", "game-changing", "powerhouse", "leverage", "meticulous", "state-of-the-art", "groundbreaking", "unrivaled", "delve", "robust architecture".
   - Do not hype simple mechanics. Describe what the player actually experiences in the game.
2. BREVITY & CLARITY:
   - Keep entries concise and written in plain layman English.
   - Focus on practical gameplay outcomes: what item was added, what changed, what recipe moved, what was fixed.
   - Avoid internal code abstractions or developer flexes (e.g. say "Fixed beams getting blocked by ore deposits" instead of "Replaced inline boolean check with O(1) ignorable set lookup in line-of-sight raycaster").
3. CHANGELOG REQUIREMENTS:
   - Follow strict Factorio changelog formatting:
     Version: X.Y.Z
     Date: YYYY-MM-DD
       Features:
       Balancing:
       Bugfixes:
       Optimizations: (only if there are genuine performance fixes)
   - Keep bullet points to 1-2 lines maximum.
4. SPLASH PAGE REQUIREMENTS:
   - Must start with a clear, 2-sentence summary of what the mod does.
   - Must include a `### What's New in X.Y.Z` section directly below the summary.
   - Break features into simple, scannable sections (How It Works, Capsules, Devices, Hotkeys).
   - Retain the brief developer note at the bottom.

### Inputs:
[PASTE CHANGES FILE / GIT DIFF HERE]