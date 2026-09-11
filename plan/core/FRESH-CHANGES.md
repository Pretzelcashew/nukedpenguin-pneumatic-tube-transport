#### 0.3.22

### Revision: Alt-Mode EM Projector Muzzle Socket Overlay Parity
**Date:** 2026-09-11 09:24 EDT
**Context:** Unpowered, disabled, or idle Electromagnetic Projectors previously lacked an Alt-Mode visual indicator on their launch muzzle, obscuring machine orientation whenever the kinetic beam was inactive. This change introduces an idle muzzle overlay dot with parity to passive intake ports and hooks state transitions into the flow engine to toggle between idle dots and active kinetic beams.
**Key Changes:**
1. **Muzzle Socket Visual Overlay (`scripts/flow/flow-engine.lua`):** Defined `PROJECTOR_MUZZLE_COLOR` (0.12 radius, magenta) and updated `update_pos_render` to display a socket indicator at the projector launch muzzle whenever gas pressure and kinetic beam levels are zero.
2. **Kinetic Wavefront Transition Synchronization (`scripts/flow/flow-engine.lua`):** Enqueued position render updates in `flow_engine.step` when muzzle kinetic levels activate or recede, seamlessly hiding the idle socket dot in favor of the active kinetic guide beam and restoring it when unpowered or disabled.