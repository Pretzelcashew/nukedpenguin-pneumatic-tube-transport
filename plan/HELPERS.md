Regex cite brackets remover

\s*\[cite[^\]]*\]





Now make me a revision code block based on the changes we just made. 
The output must be in a code block I can press copy on here.

I have provided a sample of previous revisions to give you an idea of the format:

### Revision: Electric Energy Interface Fix & Instant Power-State Sensitivity `[INCORPORATED IN TABLE]`
**Context:** Resolve 0 W power consumption display and false unpowered network recalculations caused by energy buffer depletion mid-frame during entity destruction events.
**Key Changes:**
1. **Energy Source Buffer Tuning (`prototypes/entity.lua`):** Configured `buffer_capacity` to `3kJ` and `input_flow_limit` to `60kW` on the `pneumatic-pump` prototype. This provides necessary headroom so `entity.energy` remains above zero during mid-frame event checks while maintaining sub-0.1s network shutdown response times upon true grid disconnection.
2. **Sprite Table Correction (`prototypes/entity.lua`):** Updated `pneumatic-pump` prototype definition to use the plural `pictures` table required by `electric-energy-interface` entities.
3. **Power-State Polling & Invalidation (`scripts/networks/pump-manager.lua`):** Implemented a periodic `on_tick` scanner (15-tick interval) tracking `active_pumps` and `pump_power_states`. Power toggles automatically trigger `networks_flow.build(net_id)` to re-evaluate pressure and flow vectors across connected subgraphs.

### Revision: Specialized Transit Capsule Prototypes & Tech Tree Integration
**Date:** 2026-08-26 21:25 (EDT)
**Context:** Register item prototypes, crafting recipes, and technology research nodes for specialized transit capsule variants (biodegradable, refrigerated, reinforced, and player transit) ahead of runtime mechanics integration.
**Key Changes:**
1. **Capsule Variant Items (`prototypes/item.lua`):** Registered item prototypes for `biodegradable-capsule`, `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule` with stack size 1 and distinct order sub-keys (`a[capsule]-b[...]` through `e[...]`) under the `intermediate-product` subgroup.
2. **Variant Crafting Recipes (`prototypes/recipe.lua`):** Added recipe definitions for all four new capsule variants with `enabled = false` for tech unlock gating, establishing crafting times (1.0s to 5.0s) and ingredients matching tier progression.
3. **Technology Unlocks & Tree Expansion (`prototypes/technology.lua`):** Added `biodegradable-capsule` unlock directly to the baseline `pneumatic-transport` technology. Created the `specialized-pneumatic-capsules` technology node (prerequisite: `pneumatic-transport`, 250 cycles @ 30s) to unlock `refrigerated-capsule`, `reinforced-capsule`, and `player-transit-capsule`.




Now make a commit title for git in vs code

Avoid using [cite] blocks

Include today's date YYYY-MM-DD HH:MM (EDT/EST)






Please sync our documentation with the latest changelog updates by following these steps:

1. **Update Architecture:** Modify `architecture.md` to fully reflect all unapplied changes listed in `changelog.md` (specifically, any items not yet marked as incorporated in the changelog table).
2. **Mark as Applied:** Update `changelog.md` to clearly mark all of those newly processed items as applied/incorporated.
3. **Output Format:** Provide the full, updated contents of both `architecture.md` and `changelog.md` in full, ready for me to copy and paste.





/c local p = game.player p.set_controller{type=defines.controllers.character, character=p.surface.create_entity{name='character', force=p.force, position=p.position}}


/c local player = game.player for i=1, 500 do player.insert{name="biter-egg", count=1, spoil_percent=0.95} end



/c local p=game.player; local surf=p.surface; local pos=p.position; local chest=surf.create_entity{name="iron-chest", position=pos, force=p.force}; if chest then local inv=chest.get_inventory(defines.inventory.chest); local function g(n) return inv.find_item_stack(n) end; if inv.insert{name="repair-pack"}>0 then g"repair-pack".durability=0.5 end; if inv.insert{name="firearm-magazine"}>0 then g"firearm-magazine".ammo=5 end; if prototypes.item["jellynut"] and inv.insert{name="jellynut"}>0 then g"jellynut".spoil_tick=game.tick+prototypes.item["jellynut"].spoil_ticks/2 end; if inv.insert{name="stone-wall"}>0 then g"stone-wall".health=0.3 end; if inv.insert{name="selection-tool"}>0 then g"selection-tool".custom_description="test-id-123" end; if inv.insert{name="power-armor-mk2"}>0 then local s=g"power-armor-mk2"; if s.grid then s.grid.put{name="personal-laser-defense-equipment"} end end; p.print("Test chest created successfully!") end




what changed, and in what situations will it help?



