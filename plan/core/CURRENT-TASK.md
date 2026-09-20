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
Fix pressure corridors to stably deliver persistent pressure to downstream pneumatic networks placed after corridor formation, and implement dynamic colinear corridor elongation when colinear-compatible entities with straight port pairs (tubes, inline unbranched junctions, defensive walls, inline counters) are connected to an existing corridor's terminal tip.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
storage.pressure_corridors, storage.corridor_tip_flows, storage.flow_connections, storage.flow_nodes, storage.flow_levels, storage.flow_grid, storage.flow_queue, storage.flow_unit_ports
connect_entity, disconnect_entity, step_pressure_corridors, compute_port_flow_level, flow_engine.step, on_pressure_begin_transmit, scan_pneumatic_colinear_reach, is_colinear_straight_internal
polymorphic colinear port evaluation, opposing port vectors & axial alignment, unbranched junction straight reduction, wall/gate interop straight colinearity
post-formation downstream attachment, downstream pressure starvation/decay, persistent tip emission substrate, corridor_tip_flows lifetime & refresh
terminal_branch_pkey binding, branch_enqueued synchronization, colinear extension detection, entity-agnostic corridor elongation, scan_pneumatic_colinear_reach re-scan
in_pkey, out_pkey, last_out_pkey, terminal_branch_pkey, corridor_entities, registered_segs, max_seg_idx, total_dist, terminal_pos
motion_tree:insert_segment, viewport_bvh.on_segment_registered, viewport_bvh.on_leaf_static_changed, trajectory_bvh.refresh_active_renders
flow_common.wake_port_parked, flow_engine.enqueue_port, update_pos_render, 0-tick idle sleep
[/CONTEXT_TOKENS]