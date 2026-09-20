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
Fix pressure corridor severing when a pneumatic member is removed immediately adjacent to a pressure source (like a pump).

Currently, deconstructing a tube in the middle of a line properly splits the corridor: upstream truncates at the break face, and downstream detaches into an autonomous receding wake. However, if the player removes the very first tube touching the pump, the line does not sever—the entire corridor collapses into a monolithic decay.

Make near-source removal consistent with mid-segment removal: the cut point should detach cleanly, terminating the near-source interface while detaching all surviving downstream members into an autonomous receding wake equalizing to zero.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
storage.pressure_corridors, storage.corridor_tip_flows, storage.flow_connections, storage.flow_nodes, storage.flow_unit_ports
flow_engine.disconnect_entity, flow_engine.split_pressure_corridor, flow_engine.unseed_pressure_corridor, flow_engine.step_pressure_corridors
touches_source, touches_entity, to_recede, to_split, corr.source_unit, corr.unit_number, corr.in_pkey, corr.out_pkey, corr.corridor_entities
near-source deconstruction, first tube removal next to pump, downstream autonomous wake detachment, exact_up_dist boundary handling
down_cid severed corridor generation, down_flow_mag, down_last_out, corridor_tip_flows preservation, anti-pressure decay
motion_tree:insert_segment, motion_tree:remove_segment, viewport_bvh.on_segment_registered, viewport_bvh.on_segment_removed
[/CONTEXT_TOKENS]