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
Purge lingering sticky dots and prevent recycled reticle trail circles (0.08r magenta) from cross-contaminating pressure corridor and wall flow overlays.

Investigate and fix two presentation regressions visible in the world overlay:
1. Trail Dot Cross-Contamination: Leased circle handles retain optical projector reticle properties (0.08 radius, holmium magenta tint) or erroneously fall back to reticle static rendering (`reticle_static`) on pressure corridor and wall segments instead of applying the pressure corridor specification (0.15 radius cyan/orange dots with Alt-Mode flow numbers).
2. Sticky Lingering Dots: Small static dots remain permanently visible on wall and tube flanges after corridor splitting, gate transitions, or corridor recession because render handles are orphaned in player visible sets or bypassed during leaf recycling.

Scope: Audit `render-pool.lua` property resetting on lease/recycle, ensure `viewport-bvh.lua` never falls back to optical projectile reticle routines for pneumatic corridors, enforce strict attribute sanitization in `capsule-renderer.lua`, and guarantee symmetric release/cleanup of all leased handles in `viewport_bvh.on_segment_removed` and `unseed_pressure_corridor`.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
render_pool.lease_circle, render_pool.recycle, render_pool.release_circle, render_pool.release_many
viewport_bvh.attach_static_render, viewport_bvh.attach_reticle_static_render, viewport_bvh.attach_pressure_static_render
viewport_bvh.on_segment_removed, viewport_bvh.on_leaf_static_changed, viewport_bvh.update_player, viewport_bvh.detach_static_render
motion_protocols.static_renders, motion_protocols.get_protocol, protocol.static_render == "pressure_static"
scripts/utils/render-pool.lua, scripts/utils/viewport-bvh.lua, scripts/capsules/capsule-renderer.lua, scripts/flow/flow-renderer.lua
leaf.render_objects, leaf.objects, leaf.has_trail, leaf.static_render_spec, player_visible_sets
purge_orphaned_renders, reticle_static fallback suppression, magenta dot pollution, 0.08r radius reset, sticky trail dot leak
flow_renderer.destroy_pos_renders, flow_engine.unseed_pressure_corridor, split_pressure_corridor teardown
[/CONTEXT_TOKENS]




![alt text](image.png)