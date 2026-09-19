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
Implement smart mid-segment pressure corridor severing when intermediate pneumatic tubes are mined or destroyed, splitting the corridor into an upstream truncated corridor and a newly initialized downstream receding/orphaned corridor rather than collapsing the entire line.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
storage.pressure_corridors, storage.corridor_tip_flows, storage.flow_connections, storage.flow_nodes, storage.flow_grid, storage.flow_queue
disconnect_entity, unseed_pressure_corridor, on_pressure_begin_transmit, on_pressure_stop_transmit, scan_pneumatic_colinear_reach
corridor_entities, in_pkey, out_pkey, last_out_pkey, terminal_branch_pkey, source_unit, source_pkey, start_pos, dir, total_dist
midline tube removal, split_pressure_corridor, upstream truncation, downstream detached wake, break_dist = math.floor(|pos - start_pos|)
motion_tree, traj_tree, leaves, registered_segs, viewport_bvh.on_segment_removed, viewport_bvh.on_segment_registered
status = "receding", retreat_tick, end_decay_tick, tau, p_head_cont, p_tip_cont, cur_tip_mag, target_tip
flow_common.wake_port_parked, flow_engine.enqueue_port, update_pos_render, anti-reseed suppression, 0-tick idle sleep
[/CONTEXT_TOKENS]