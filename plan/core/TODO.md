(~ = marked as completed)

~include pipette copying of hub, pump, and diverter settings 

~add directional icons for the diverter gui to help mental fatigue

~make hub, pump, and diverter settings blueprintable (as in the bp metadata is incorporate in the bp)

~consider rending order (like making flow under capsule render) (discovered render circle doesnt have fine control over render layer)

~include visible filters over diverter ports when there are some

~make circuit proxys included in blueprints (linked to their device in bp metadata so when placement occurs we dont create a duplicate proxy)

~fix the situation where you would set an item filter in diverter when you already had a comparator and quality set, would clear the comparator/quality

~fix the situaton where pasting a bp would sometimes link circuit wires between diverters or pumps you just pasted down with a blueprint nearby

~add a copy/paste port settings feature for the diverter (a little button pair somewhere on each diverter port gui module)

~consider reverting back to having the diverter's 'all' mode selected by default when opening the gui

~make it so pressing esc cancels the item with quality and comparator gui rather than submitting into the diverter slot


~fix when clicking pneumpatic pump it doesnt open its gui


~fix that setting a quality in the diverter's item with quality comparator gui, and an item, but then clearing the item, and pressing submit, would ghost keep the quality until changing the comparator or item or quality

~make sure to update en locale to include recharge refrigerated capsule

~address why rotating pumps flow dot layering is inconsistent when rotating (same with diverter), when normally it would show 9 in front but after rotation the 10 is prioritized. the goal is to be consistent rather than 'doing the right thing'

~consider adding a nest capsules toggle on hubs (on by default), which means hubs can attempt packing capsules, not that its prioritized in any order, just to make it easier to manage hubs where you want extra capsules in the hub for sending with but not trigger packing of capsules within capsules if you dont want. it can be done currently via circuit networks but i think a toggle for nest capsules would feel really nice to have.
example scenario provided in image: where you'd want extra capsules for sending circuits or managing excess capsules by having a circuit toggle the enables nest capsules... in that case im starting to think it should be a binary feature, nest capsules on would mean hub can only pack capsules with capsules, and nest capsules off means you can only pack non capsule cargo ![alt text](image.png)

~ensure proper buildings make the correct capsule recipes, and they are located in the correct tabs (recharge spent refrigerated capsule is in the misc tab now, should be moved with the others, into pneumatic transport tab)

~include capsule details in factoriopedia (like if it supports mixed cargo)

~make copy settings more native feeling for diverters and pumps (sound and yellow and green hover target outline); essentially copying/pasting settings relies on the source entity to remain alive

~~investigate the inconsistent manner of which pneumatic entities trigger their copy/paste settings (are hubs treated too special since their prototype allows native copy/paste events? or is this a necessary evil?)

~fix en locale for all recipes that do not have an entry

~consider removing pneumatic entity setting adoption of ghosts when placing over entity which would be a different bounding box shape or orientation. inother words, if the entity placed on the ghost isnt square on it dont adopt the settings from the ghost. (however, rotations and flips are fair game to adopt settings if they dont violate this principle)

~consider adding capsule counter entity (1x2, uses power, reads how many capsules are currently in a tube segment. it emits a signal, all the capsules' primary capsule type and quality, can select which wire color to output on, red or green), determine if we need a circuit proxy for this entity, and what kind it has to be.

~make nest capsules off by default

~ensure all technology has an en locale so 'unknown key' doesnt keep appearing

~remove any mention of the old v1 engine in the project

~make a capsule counter research that require the circuit network tech and the initial pneumatic tech, in order to be able to craft capsule counters

~add vacuum capsule unlocked with space tech, same stats as standard capsule, but with added vaccuum ability, which takes items off any belt segment that is touching a hub port (works on undergound belts and belts, any quality). this makes the hub fill up without needing inserters

~make reinforced capsule's role more distinct, enforce strict bulk transport, all same item type, same quality, must use all slots to pack (dont forget to update descs)

~add a new capsule type unlocked on fulgora, designed to be the true mixer, zero restrictions on packing, can be any items, any quantity, any quality, (so you could load 1 single copper cable and be packed, or 23 rare iron gears, plus 27 uncommon LDS, plus 100 normal stone bricks), begins with 2 base slot capacity.
crafted using 75 superconductor 2 LDS and 25 scrap. dont forget all tech and locale, item descs, balance. do not have overly wordy descs.

~~add ladder for going over pneumatic tubes with character~~

~do not turn of transmit sense at terminator gates when opening the gate

~add a pre-emptive soft registry of walls/gates that are built next to a pneumatic port with active flow, so that we can enqueue an efficient flow queue wake up when the interoperability tech finishes being researched

~add a pneumatic gate which lets capsules through when closed

~fix that in certain scenarios with deleting and rotating gates and placing them back and rotating would not wake up the flow properly

~fix that building over a pneumatic entity to upgrade quality, would not preserve the original settings when building out of inventory

~add player equipment: electromagnetic harness that lets you launch from EM projectors while in a player transit capsule

~fix pasted ghosts do not show the correct settings reflected in their gui when clicked. (though, it does once the real building is placed)

~fix diverter circuit proxy disappearing after placing a real one on a diverter ghost

~consider breaking apart large files that are doing too many things (like flow-engine)

~fix the recipe for the refrigerated capsule (so recharging coolant isnt lossy), and the crafting recipe shouldnt be outputting hot flouroketone, thats for the recharge

~improve capsule counter performance by smartly registering capsule entry an exits on the capsule territory rather than scanning all of the counter's sensor dots every scan tick

~further improve capsule counter scanning by letting the liminal holder checks to the updating for capsule counter for volatile/dynamic cargo

~improve liminal holder dynamic cargo handling to mark the next item to be spoiled, and only re-check the cargo or re update it at this time rather than every 1 second scans.

~improve refrigerated capsule handling liminal scanning to use the volatile cargo timed sort recheck to intercept them before they would spoil and apply the modified spoil times, and deduct from the refrigerated capsule.

~if the refrigerated capsule (as a primary capsule) doesnt have any spoiling cargo, it is considered a stable capsule in the eyes of the capsule counter.

~use the same latent volatile/dynamic cargo checker to monitor unit spawning type spoilables (biter egg/pentapod egg), or better, turn it into virtual cargo so we dont have to guess what capsule the units belong to, and thus removing the separate moat grid that was designed to deal with them. So in essence, we only virtualize cargo that is spoilable inside a refrigerated capsule, or when it is a spoilable producing units in any capsule. so potentially any capsule could just about be qualified for virtual cargo because of this, but doesnt have to virtualize all unnecessary cargo

~also verify that all spoilable cargo in liminal capsules now utilizes the latent timer checker rather than periodic rechecks, so we can change the state of the capsule, such as dominant cargo for re-renders, or notifying capsule counters. this is a goal to eliminate frequent rechecks of all dynamic cargo in liminal item holders

~introduce binary heap, and the heap itself has a sliding allocation so popping is a virtual line within it, (may need a paired hash map or be a hash map itself), this way it doesnt need to reallocate over and over as the items in it grow and shrink

    the purpose, a reusable fast heap sort, which can be made multiples of for different systems in my mod. 

    Example 1: my new virtual cargo spoil timer system could greatly benefit from this, we just keep track of the single most spoiled item in the game, and we only keep a timer going for that one, and heap insert new entries, and as the lowest spoil timer spoils we check the next one, quick exit if the next one still has time left.

    Example 2: i havent implemented it yet, but the binary heap i described will be critical, when i migrate my capsule travel to arrive on time rather than iterating every capsule periodically. we just arrive them as needed with the binary heap sort. (but will implement a viewport culled capsule interpolation rendering to hide that they are teleporting, also critical for example 2 to work, but first we just need to prove the heap works for example 1 first)

    let's make the heap i described, and have some automated printouts in the game console to test that it works when we're done before we use it for my virtual cargo spoil system

--------------------------------------------

my plan is to add an arrival time for capsules, this means that they will essentially teleport to their target endpoint or junction (whenever there is a branching path), after a time that they wouldve reached it with my current motion script (though, it could be actually distance based arrival time rather than hop based that is currently variable). 

    i know its a big refactor, but i want to do it in small pieces, and i will start with the low hanging fruit, which is capsules on kinetic flows, which already feature a known endpoint. so we will only implement it for this part initially, and i want an easy bool in the top of the script for it to switch back to the normal kinetic motion if i dont like it. you'll see why im saying that in a sec.

    the success of this timed arrival is dependent on if i can also implement a reliable viewport based renderer to interpolate motion for only capsules that would be viewed by a player at that moment, to hide the fact that it is really being efficiently teleported behind the scenes.

    and the timed arrival will use the binary heap i just created too so its starting off with a leg up