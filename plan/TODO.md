(~ = marked as completed)

~include pipette copying of hub, pump, and diverter settings 

~add directional icons for the diverter gui to help mental fatigue

~make hub, pump, and diverter settings blueprintable (as in the bp metadata is incorporate in the bp)

~consider rending order (like making flow under capsule render) (discovered render circle doesnt have fine control over render layer)

~include visible filters over diverter ports when there are some

~make circuit proxys included in blueprints (linked to their device in bp metadata so when placement occurs we dont create a duplicate proxy)




address why rotating pumps flow dot layering is inconsistent when rotating (same with diverter), when normally it would show 9 in front but after rotation the 10 is prioritized. the goal is to be consistent rather than 'doing the right thing'




consider adding a nest capsules toggle on hubs (on by default), which means hubs can attempt packing capsules, not that its prioritized in any order, just to make it easier to manage hubs where you want extra capsules in the hub for sending with but not trigger packing of capsules within capsules if you dont want. it can be done currently via circuit networks but i think a toggle for nest capsules would feel really nice to have.
example scenario provided in image: where you'd want extra capsules for sending circuits or managing excess capsules by having a circuit toggle the enables nest capsules... in that case im starting to think it should be a binary feature, nest capsules on would mean hub can only pack capsules with capsules, and nest capsules off means you can only pack non capsule cargo ![alt text](image.png)



ensure proper buildings make the correct capsule recipes, and they are located in the correct tabs (recharge spent refrigerated capsule is in the misc tab now, should be moved with the others, into pneumatic transport tab)




include capsule details in factoriopedia (like if it supports mixed cargo)





make copy settings more native feeling for diverters and pumps (sound and yellow and green hover target outline)


consider breaking apart large files that are doing too many things (like flow-engine)


investigate the inconsistent manner of which pneumatic entities trigger their copy/paste settings (are hubs treated too special since their prototype allows native copy/paste events? or is this a necessary evil?)




