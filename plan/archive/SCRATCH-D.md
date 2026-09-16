You are 100% right to catch that. If a prompt is *completely* generic, an LLM might latch onto the legacy 1-tile/tick kinetic graph wavefront simulation (`flow_grid`, `flow_nodes`, etc.) that is being phased out, instead of the new Projector Reticle Corridor engine.

The solution is to specify the **architectural domain and negative constraints** (which system to target, and which to explicitly ignore) without leaking brittle variable names or pseudocode.

Here is the balanced version that pins the AI to the exact modern system and warns it away from the deprecated wavefront code:

***

### 🎯 Target Task: Projector Reticle Corridor Slicing & Wake Reeling (Task 2 & 3 Bugfixes)

**Architectural Context:**
* **Target System:** The new Projector Scope & Reticle Corridor engine (defined in `PROJECTOR-REFACTOR.md`, Tasks 2 & 3), residing in `scripts/flow/flow-kinetic.lua` and `scripts/capsules/capsule-ballistics.lua`.
* **Explicit Deprecation Guard:** Do **NOT** touch or reference the legacy 1-tile/tick kinetic flow grid simulation (`ENABLE_KINETIC_FLOW_PROPAGATION = false`). We are working purely on the reticle corridor ballistics and anti-reticle wake reeling engine.

---

**Behavioral Requirements & Rules:**

1. **Corridors Must Never Forget Invariant Reach:**
   * Every reticle corridor has an invariant full reach determined by the firing projector's quality tier.
   * Obstructing, cutting, or pushing back a reticle must never cause the corridor (or any severed child slice) to permanently overwrite or forget this full reach.
   * If an obstruction is cleared, or if a severed slice is traveling, it must know its full original reach rather than treating an intermediate collision coordinate as its maximum reach.

2. **Mid-Corridor Cuts: Severed Pulses Must Keep Progressing:**
   * When an obstacle cuts across an active corridor, it splits into an upstream corridor (clamped to the obstacle face) and a downstream corridor (detached in mid-air).
   * If the severed downstream slice still had reach remaining before reaching the corridor's full potential distance, its front head must **continue traveling forward across the map at normal speed** toward that destination. It must not instantly freeze in mid-air as a stopped beam.
   * Only severed pieces that have zero distance remaining (e.g. were already fully extended to maximum reach or resting against an obstacle) should have their front stay stationary.

3. **Wake Reeling & Tandem Catchment:**
   * Slicing an active corridor must launch a trailing anti-reticle wake flight starting at the obstacle's exit boundary to reel away the tail dots toward the front.
   * If the front is actively traveling forward, the tail reels behind it in tandem.
   * The severed corridor must **never be prematurely deleted or wiped in a sudden bulk pop** while the front head is still traveling. The corridor must only clean up when the retreating tail actually catches up to where the front head stopped.

4. **Uniform Slicing for All Corridors (Recursive Wake Slicing):**
   * Cutting must operate purely on corridor geometry and work identically whether a beam is powered by a live machine, already an orphaned beam (from machine rotation/power loss), or an already-reeling wake.
   * Do not early-return or treat decaying wakes as garbage. If an obstacle drops across an already-reeling wake, split it recursively: the upstream half clamps to the obstacle, and the downstream half detaches as a new wake that continues reeling to the end without becoming headless or wiping instantly.

***

This gives the new Gemini instance crisp architectural boundaries, prevents it from touching the legacy kinetic wavefront code, and specifies the required behavior without polluting its context with hallucination-prone variable names.