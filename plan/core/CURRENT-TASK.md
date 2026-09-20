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
Retroactively split or truncate active pressure corridors when a player connects a new branch to an intermediate junction during live gameplay.

Pre-built networks with existing branches already evaluate correctly at build time. The defect occurs strictly when an entity or tube is attached to the idle side port of an intermediate junction that is already actively conducting an established pressure corridor. In this live state-change scenario, `connect_entity` does not alert or sever the intersecting corridor, allowing it to remain intact across the newly branched junction instead of reacting to the loss of colinear straight status. 

Scope: Do not rewrite core static graph traversal or junction evaluation. Scope this change strictly to reactive event handling in `connect_entity` (and related topology wakeups), ensuring that when a newly linked edge breaks the straight-line status of an intermediate corridor member, the active corridor retroactively truncates or splits at the junction face and hands off tip pressure to the newly formed branch.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
flow_engine.connect_entity, flow_engine.split_pressure_corridor, flow_engine.unseed_pressure_corridor, flow_engine.wake_corridor_tip
flow_common.is_colinear_straight_internal, flow_common.link_ports, flow_common.enqueue_unit_ports, flow_common.enqueue_port
scan_pneumatic_colinear_reach, compute_port_flow_level, flow_engine.step, flow_engine.on_pressure_begin_transmit
storage.pressure_corridors, storage.corridor_tip_flows, storage.flow_connections, storage.flow_nodes, storage.flow_unit_ports
corr.corridor_entities, corr.terminal_branch_pkey, corr.last_out_pkey, corridor_entities[unit_number][group]
live edge insertion, retroactive corridor severing, dynamic junction branching, runtime colinear invalidation
preserve prebuilt topology, reactive connect_entity trigger, branched junction handoff, side-port link detection
upstream corridor truncation, downstream wake detachment, tip flow delivery at newly branched junction
[/CONTEXT_TOKENS]