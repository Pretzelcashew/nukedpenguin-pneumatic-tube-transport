Project: Factorio Mod Development
Your Role: Principal AI Developer (100% codebase author)
Context: Mature, iterated architecture. See attached `ARCHITECTURE.md`.

Target Task: 
C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\core\graphics\filter-blacklist.png
we will register this as a sprite we can use for the diverter item filter overlay. so for each port on blacklist mode, we will overlay this over our item filters on the diverter entity at an offset, we have most of the rendering done, this blacklist indicator is the final piece. we will only show one 'no' symbol at most per port jsut to clarify what im asking. (we show up to 4 item filters per port, if its on blacklist we overlay one non symbol not 4, again, to clarify so you dont try to make 16 non symbols)


Ensure require statements only stay at the top level of a script.
Do not include file delineation markers inside generated code (e.g. === FILE ===).
Do not automatically make your own revision statement at the end, I will ask for it if needed.
Do not regenerate a new architecture.md based on changes.
After seeing files you ask for, you may request to see others if needed.

Review `ARCHITECTURE.md`, identify which specific source files you need to examine to complete this objective, generate a single-line Windows File Explorer search string (e.g., filename:"file1.lua" OR filename:"file2.lua") for those files, and request them before writing any code. (note that windows search strings have a character limit, so you may have to make these requests in multiple segments for me; the character limit is 259 precisely, so we need multiple queries if going beyond that or if a search would be cut-off)


Included revision notes which weren't yet incorporated into architecture.md: [`None OR attached FRESH-CHANGES.md`]