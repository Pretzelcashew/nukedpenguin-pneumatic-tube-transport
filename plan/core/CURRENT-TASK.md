i have spent a couple weeks on the new capsule flight system, which is more efficient than the capsule hops. currently it only works with projectors because of reticles.

but i want to expand this to pressure, is going to be baby steps. i still need to support the hops system and interface the flight system with the hops system.

so basically, what we did with em projectors, who use a reticle to find a clear straight path to another projector, i would like to do something similar for pressure, but because flow nodes are more complex and can branch, we have to treat the pump's version of a reticle differently:

where its the same:
    straight line path with a max distance
    renders a dot trail
    allows timed arrival capsules to fly through
    can be obstructed
    uses a bvh leaf increment set (16 tile leafs)

where its different:
    requires properly aligned pneumatic entities
    obstructions are a lack of a valid pneumatic entity rather than a physical block in empty air
    capsules cant crash at the end of an open segment (or do damage)
    any branching pneumatic entity stops the contiguous flight corridor, transitioning to the classic hops system, with the remaining pressure
    the pressure flow across this type of corridor can be negative or positive (which impacts the direction of timed arrival)
    capsules can back up rather than stack up on the same tile at the end of this kind of flight corridor
    only needs to check if there is still room in the flight corridor to transmit into it (if not, sleeping will happen until a wake signal of vacated room)
    must be compatible with the capsule counter
    pressure can turn off mid flight, freezing in flight capsules (not instant, pressure emission based bvh wave fronts will have their own version of an anti reticle)



many pneumatic entities can transmit pressure, and some can emit pressure, both actions will be our event for starting a pressure corridor.

tubes are the perfect candidate for transmitting a pressure corridor because they dont have branching ports
but other entites also have multiple ports that dont have branching ports, such as the crossflow junction, so they are also a pressure corridor candiate on 2 axes.

our first step to making all of this happen, is identifying the event for when a pressure begins to emit, and when a pressure begins to transmit. we arent hijacking this, they will transmit normal flow engine dots until it comes across a situation where the pneumatic member at this port is not a branch, not a bend, but a straight line, which is why the pneumatic tubes are the first place we will see these pressure corridors begin to expand instead of a flow engine flow spread.






[CURRENT_TASK]
Fix improper render object leasing and releasing causing pressure corridors to leave behind rogue magenta trail dots from the recycled render pool.

Recycled circle primitives leased from `render-pool.lua` by pressure corridors sometimes retain optical projector/reticle state (holmium magenta tint, small radius) because properties are not sanitized upon leasing or releasing back into the pool. Furthermore, when pressure corridors recede or unseed spatial BVH segments, leased primitives must be cleanly released back into `render_pool` with fully reset visibility and baseline styling rather than being orphaned in the world. Ensure strict lease-release symmetry and complete property re-initialization across both projector reticle and pneumatic corridor lifecycles.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
render_pool.lease_circle, render_pool.release_circle, render_pool.release, render-pool.lua
viewport_bvh.on_segment_registered, viewport_bvh.on_segment_removed, viewport_bvh.update_player_views
motion_tree, trajectory_bvh, timed_motion.get_motion_tree, motion_protocols
capsule_renderer.dispatch_player_renders, capsule_renderer.render_governor, render_corridor_dots
storage.render_pool, storage.pressure_corridors, storage.pinned_corridors, storage.kinetic_renders
leaf.objects, leaf.trail_count, leaf.has_trail, seg_key, render pool hygiene, object lease-release symmetry
pooled primitive property sanitization, stale leased circle reset, zero-destroy render object recycling
[/CONTEXT_TOKENS]