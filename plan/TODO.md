(~ = marked as completed)

~restore power requirements on pumps and diverters with flow engine v2, must remain performant. must preserve v1 systems for legacy

~restore gui control of pumps and diverters under the flow engine v2, must remain performant. must preserve v1 systems for legacy
this means making sure enable/disable toggles are respected, pressure polarity of ports, dominant item filters, respect power requirement.

~make new flow engine pressure dots respect alt mode

~when v2 is select in settings, remove any strictly v1 related settings from the debug panel

~make the debug panel toggle for viewing the flow engine not use the word "new"

~make this toggle on by default

~in the game settings make v2 the default option

address capsule bouncing randomly between hubs that are full

address delete all entities on surface in sandbox repercussions with established v2 flow engine lingering (possible we are not linked into this kind of deletion event)

address why rotating pumps flow dot layering is inconsistent when rotating (same with diverter), when normally it would show 9 in front but after rotation the 10 is prioritized. the goal is to be consistent rather than 'doing the right thing'


consider adding a nest capsules toggle on hubs (on by default), which means hubs can attempt packing capsules, not that its prioritized in any order, just to make it easier to manage hubs where you want extra capsules in the hub for sending with but not trigger packing of capsules within capsules if you dont want. it can be done currently via circuit networks but i think a toggle for nest capsules would feel really nice to have.!
example scenario provided in image: where you'd want extra capsules for sending circuits or managing excess capsules by having a circuit toggle the enables nest capsules... in that case im starting to think it should be a binary feature, nest capsules on would mean hub can only pack capsules with capsules, and nest capsules off means you can only pack non capsule cargo ![alt text](image.png)



