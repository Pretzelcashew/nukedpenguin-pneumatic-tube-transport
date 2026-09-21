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
Refactor pressure corridor change detection from entity units to spatial coordinate indexing (pos_key), resolving unpredictable wakeups on dead-ends and gate transitions while strictly preserving gradual simulation pacing.

Architectural Invariants & Constraints:
- Gradual Simulation Pacing: Wavefront expansion must remain timed (2 ticks/tile); recession must remain gradual via monotonic equalization decay. Corridors must never spread, teleport, or purge instantly.
- Zero Recursive Graph Crawling: Corridors are strictly 1D axial vectors. Do not implement recursive flood-fills, BFS searches, or cascading corridor triggers across connected networks.
- Spatial Decoupling: Change detection must index universal surface coordinate keys (pos_key) instead of entity unit numbers, allowing non-unit segments, terrain tiles, and un-numbered entities to participate equally.

Deliverables:
1. Spatial Coordinate Indexing: Track corridor footprints and boundary interfaces by spatial position keys in storage. Remove unit-number-specific dependency mapping.
2. Event-Driven Spatial Triggers: Notify spatial watchers when gates open/close, entities are built/mined, or orientation changes, evaluating only the specific corridors registered at that coordinate.
3. State Transition Handling: When a path re-opens, resume gradual wavefront expansion via the tip waking routine. When interrupted, sever cleanly into a truncated upstream run and an autonomous decaying wake.
4. Dead-End & Boundary Fixes: Allow quiescent corridor transmission to reach open dead-end flanges without requiring external downstream connections. Ensure non-transmitting ports evaluate to zero flow so reopening cleanly triggers recalculation.
[/CURRENT_TASK]

[CONTEXT_TOKENS]
storage.corridor_pos_watchers, flow_common.make_pos_key, notify_pos_topology_changed
GRADUAL_WAVEFRONT_EXPANSION_TPT_2, GRADUAL_EQUALIZATION_RECESSION_DECAY
NO_INSTANT_TELEPORTATION, NO_RECURSIVE_GRAPH_WALK, STRICT_1D_VECTOR_RAYCAST
spatial_coordinate_watchers, non_unit_segments, dead_end_corridor_transmission
flow_engine.on_pressure_begin_transmit, flow_engine.wake_corridor_tip, flow_engine.split_pressure_corridor
flow_gate_interop.step_gates, compute_port_flow_level, scripts/flow/flow-engine.lua, scripts/flow/flow-gate-interop.lua
[/CONTEXT_TOKENS]




![alt text](image.png)