### Revision: Refined Tech Tree Progression, Ingredient-Tech Prerequisite Mapping & Recipe Overhaul
**Date:** 2026-09-03 09:31 (EDT)
**Context:** Align item recipes and technology unlocks with refined progression specifications (`TECH-TREE-REFINED.md` and `RECIPES-REFINED.md`), enforce explicit technology prerequisites for all gated recipe ingredients, and update recipe syntax for Factorio 2.1 compatibility.
**Key Changes:**
1. **Recipe Cost Overhaul & Recharge Mechanics (`prototypes/recipe.lua`):**
   - Rebalanced crafting ingredient requirements across all infrastructure items, junctions, hubs, diverters, and capsule variants to match refined target recipes.
   - Added the `recharge-refrigerated-capsule` recipe allowing players to restore `spent-refrigerated-capsule` items using 125 units of cold fluoroketone while producing 100 units of hot fluoroketone as a byproduct.
   - Updated recipe definitions to Factorio 2.1 specifications by replacing deprecated single `category` string fields with `categories = { "category-name" }` array tables.
2. **Tiered Technology Progression Restructuring (`prototypes/technology.lua`):**
   - Distributed unlocks into distinct science and planet progression tiers: Red/Green science (`pneumatic-transport`), Blue science (`specialized-pneumatic-capsules`), Gleba (`biodegradable-capsule`), Vulcanus (`reinforced-capsule`), and Aquilo (`refrigerated-capsule`).
   - Re-linked `bio-capsule-integrity-1` through `4` upgrade research tiers to require the `biodegradable-capsule` technology node as their prerequisite root.
3. **Explicit Ingredient Technology Prerequisite Mapping (`prototypes/technology.lua`):**
   - Audited all 13 recipe ingredient chains and bound exact prerequisite technologies (`engine`, `advanced-circuit`, `low-density-structure`, `carbon-fiber`, `sulfur-processing`, `tungsten-carbide`, `cryogenic-plant`, `lithium-processing`, and `electromagnetic-plant`) into corresponding research nodes to ensure valid technology graph progression and prevent uncraftable recipe unlocks.