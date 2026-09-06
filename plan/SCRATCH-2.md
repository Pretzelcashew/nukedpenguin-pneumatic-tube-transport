Project: Factorio Mod Development
Your Role: Principal AI Developer (100% codebase author)
Context: Mature, iterated architecture. See attached `ARCHITECTURE.md`.

Target Task: we currently do have a custom copy/paste entity settings for our pneumatic entites. the diverter, pump, and hub are the ones with settings. however, its not being done in a native way, ours is storing the data at the moment of copying. in contrast with factorio's native pipette that keeps track of the source entity, and when you paste the settings to the target entity, its the settings of the source entity at that moment rather than at the initial pipette source selection. another thing the native engine does for pipette handling is make the green target selector around the source entity but only while holding shift + cursor hovering over target entity + source entity being alive (ghost counts as being alive). we need to make it like this without simply tweaking the entity.lua because i do not want to invoke the native pipette tool for my diverter or pump since they are compound entities. i made that last guardrail because the previous gemini kept trying to overule me on that.
lastly, since hubs are containers that i allow the native pipette to interact with, we dont need to give it green outline handling since the engine handles that natively for this entity, but we still need the custom pipette to work on it since it has non native settings.

this will be attempt #5 on this task, the other 2 gemini's botched it so their changes are discarded.
before we do the main part of this task we need to ensure we can detect when the player holds shift and isnt holding shift. i simply say shift, but i really mean whatever they are hotkeyed to the pipette tool. we can detect this. i want debug outputs with my debug_print() givng me messages of this firing. if we cant get past this part then the rest doesnt work. this means we MUST FIRST ONLY PROVE WE CAN LISTEN TO THE SHIFT AND UNSHIFT EVENT AND HAVE IT PRINT TO DEBUG_PRINT BEFORE MOVING ONTO ANY OF THE OTHER TASKS.

I CANNOT STRESS ENOUGH ABOUT VERIFYING WE CAN HEAR THE SHIFT AND UNSHIFT EVENT BEFORE DOING ANYTHING ESLE DONT EVEN TRY TO DO MULTIPLE THINGS MAKE A NEW FILE JUST FOR LISTENING END DEBUGGING SHIT

so say it all back to me, your interpretation of what should happen before i greenlight giving you the files you request

Ensure require statements only stay at the top level of a script.
Do not include file delineation markers inside generated code (e.g. === FILE ===).
Do not automatically make your own revision statement at the end, I will ask for it if needed.
Do not regenerate a new architecture.md based on changes.
After seeing files you ask for, you may request to see others if needed.

Review `ARCHITECTURE.md`, identify which specific source files you need to examine to complete this objective, generate a single-line Windows File Explorer search string (e.g., filename:"file1.lua" OR filename:"file2.lua") for those files, and request them before writing any code. (note that windows search strings have a character limit, so you may have to make these requests in multiple segments for me; the character limit is 259 precisely, so we need multiple queries if going beyond that or if a search would be cut-off)


Included revision notes which weren't yet incorporated into architecture.md: [`None OR attached FRESH-CHANGES.md`]