(~ = marked as completed)

~make bio capsules minimum cargo increase by 1 to prevent instant packing when there is no cargo

~make the liminal item holder's cargohold larger or dynamic to account for larger capsule capacities

~make the spilled capsule container able to hold variable sized contents, and not be an exploit of free insertable cargo space after spill. (can take out but not put things in)

~make the spilled capsule container go away when empty (like player bodies after looting, or crashed cargo capsules in space age do)

~prime the liminal holder entity spawning to be spaced out on a grid. storing spaces free for reuse later. (this is to account for when units spawn from spoiling items, we can know what liminal holder by proximity, so there needs to be decent spacing between liminal holder cells)

~make liminal item holder selectable for debugging since players wont be on the surface to see them anyway.

~make units spawned from spoilables while on the liminal surface of the liminal item holder, make those units spill out like spilled cargo items would (this doesnt mean crash the capsule, just spawn/move the units to where the capsule is in the real world like we do when it triggers spill)

investigate why stalled capsules impact fps so greatly even in low quantities (a stalled capsule is one that isnt moving through the network, just parked, waiting for a spot)

~add capsule peeking feature /capsule-peek lets you hover your mouse over a pneumatic entity and it will render capsules in any internal networks of this entity that are occupying this entity (so if its a merged network, you only see capsules on the tube you're hovering over) toggles off the capsule-debug for that player as they are mutually exclusive but can also be both off at the same time. (both only render during alt mode)

fix deleting pumps with the decon tool in sandbox would leave behind the circuit proxy (check if this is the same case for diverters)

mark capsules that dont have spoilage to not be re-poll candidates for dominant item rechecks

fix flow rendering flag from not updating properly (seems tied to reflow)

clean up command naming, explore adding in some toggles in the hotbar toggles section (vertical elipsis button)

improve deconstruction/removal of pnuematic networks (particularly regarding merge type networks). consider a staged, progressive over time rebuild of networks rather than that instant.

fix small flow update bug in light of the recent stage 4 fix of the performance plan involving short circuiting checks


