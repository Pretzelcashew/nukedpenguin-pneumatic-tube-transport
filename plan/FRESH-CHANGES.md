### Revision: Unpowered Pump Flow Culling & Vector Gating
**Context:** Prevent unpowered pumps from acting as passive flow sinks that trap moving capsules on dead-end inlet paths or adjacent multi-port entity branches when pump power is disconnected.
**Key Changes:**
1. **Power State Evaluation (`scripts/networks/networks-flow.lua`):** Implemented an `is_pump_powered()` validation helper to check `storage.pump_power_states` for `pneumatic-pump` entities prior to hop construction.
2. **Internal Transfer Gating (`scripts/networks/networks-flow.lua`):** Restricted internal machine transfer hop generation across pump ports so unpowered pumps suppress internal transfers between inlet and outlet ports.
3. **External Vector Flow Gating (`scripts/networks/networks-flow.lua`):** Enforced power state validation on both source and destination entities during outbound hop calculation, preventing pressure-gradient vector creation into unpowered pump inlets.
4. **Dead-End Pruning Integration (`scripts/networks/networks-flow.lua`):** Suppressing unpowered pump hops allows `flow-cull.lua` to naturally identify and prune dead-end internal junction paths leading toward unpowered inlets.