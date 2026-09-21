# FILE-SIZES.md - Workspace Size & Metric Audit
**Project:** `nukedpenguin-pneumatic-tube-transport`  
**Last Generated:** 2026-09-21 09:25:22  
**Total Scope:** 22 directories, 119 files  
**Total Workspace Size:** 8.92 MB | **Total Text Lines:** 41,321  

---

## 1. Refactor Watchlist (Largest Files by Line Count)
Files flagged with 🔴 should be considered for modularization before major refactors to prevent AI patch failures.

| Relative File Path | Lines | Size | Patch Risk / Refactor Status |
| :--- | :---: | :---: | :--- |
| `scripts/flow/flow-kinetic.lua` | 3,192 | 142.5 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `plan/core/CHANGELOG.md` | 3,112 | 515.2 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/capsules/capsule-renderer.lua` | 2,012 | 76.8 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/capsules/capsule-ballistics.lua` | 1,662 | 74.2 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/flow/flow-engine.lua` | 1,181 | 51.5 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/debug-manager.lua` | 1,099 | 47.3 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/capsules/capsule-runner.lua` | 1,073 | 41.7 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/utils/trajectory-bvh.lua` | 1,003 | 36.7 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/utils/viewport-bvh.lua` | 980 | 39.3 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/capsules/capsule-lifecycle.lua` | 971 | 42.4 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `plan/archive/CHANGES_0.3.23.md` | 915 | 161.6 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `aggregator_patcher.py` | 906 | 33.7 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `plan/archive/ARCHITECTURE.md` | 830 | 120.9 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/diverters/diverter-gui.lua` | 746 | 29.2 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/profiler.lua` | 709 | 22.0 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/flow/flow-renderer.lua` | 706 | 27.0 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/proxy-manager.lua` | 660 | 22.8 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/binary-heap.lua` | 637 | 20.7 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/gui-components.lua` | 627 | 23.7 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/blueprint-sync.lua` | 614 | 26.3 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/motion-protocols.lua` | 576 | 26.6 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/active-device-scanner.lua` | 545 | 24.2 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/timed-motion.lua` | 535 | 23.0 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/capsules/capsule-queries.lua` | 518 | 19.4 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/flow/flow-gate-interop.lua` | 517 | 22.9 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |

---

## 2. Full Workspace Metric Tree

```text
nukedpenguin-pneumatic-tube-transport/
├── docs/
│   ├── arch/
│   │   ├── ARCH-CAPSULES-MOTION.md             [339 lines | 50.5 KB]
│   │   ├── ARCH-DEVICES-CIRCUITS.md            [287 lines | 45.2 KB]
│   │   ├── ARCH-FLOW-KINETICS.md               [300 lines | 43.8 KB]
│   │   ├── ARCH-HUBS-LOGISTICS.md              [109 lines | 20.9 KB]
│   │   └── ARCH-PROTOTYPES.md                  [68 lines | 14.9 KB]
│   └── guides/
│       └── capsule-definitions-guide.md        [214 lines | 8.5 KB]
├── locale/
│   └── en/
│       └── config.cfg                          [169 lines | 11.8 KB]
├── plan/
│   ├── archive/
│   │   ├── ARCHITECTURE.md                     [830 lines | 120.9 KB]
│   │   ├── CHANGES_0.3.23.md                   [915 lines | 161.6 KB]
│   │   ├── FLIGHT-OCCLUSION.md                 [44 lines | 3.8 KB]
│   │   ├── image-1.png                         [2.28 MB]
│   │   ├── image-2.png                         [2.23 MB]
│   │   ├── image.png                           [1.90 MB]
│   │   ├── MOTION-REFACTOR.md                  [147 lines | 13.3 KB]
│   │   ├── SCRATCH-B.md                        [31 lines | 2.8 KB]
│   │   ├── SCRATCH-C.md                        [12 lines | 238 B]
│   │   ├── SCRATCH-D.md                        [40 lines | 3.8 KB]
│   │   └── SCRATCH.md                          [26 lines | 2.5 KB]
│   └── core/
│       ├── ANTI-RETICLE.md                     [179 lines | 15.9 KB]
│       ├── CHANGELOG.md                        [3,112 lines | 515.2 KB]
│       ├── CURRENT-TASK.md                     [32 lines | 2.7 KB]
│       ├── EXPORT.md                           [43 lines | 1.5 KB]
│       ├── FRESH-CHANGES.md                    [10 lines | 1.8 KB]
│       ├── HELPERS.md                          [92 lines | 4.3 KB]
│       ├── MANIFEST.md                         [287 lines | 45.2 KB]
│       ├── MOD-DESCRIPTION.md                  [9 lines | 345 B]
│       ├── package.py                          [225 lines | 7.8 KB]
│       ├── PROJECTOR-REFACTOR.md               [75 lines | 8.0 KB]
│       ├── PROMPT-AG-DIFF.md                   [128 lines | 8.9 KB]
│       ├── PROMPT-DOC-SYNC.md                  [55 lines | 4.5 KB]
│       ├── PROMPT-REVISION-LOG.md              [28 lines | 1.3 KB]
│       ├── SPLASH-PAGE.md                      [59 lines | 4.3 KB]
│       ├── TASKS.md                            [80 lines | 7.5 KB]
│       ├── TODO.md                             [175 lines | 18.9 KB]
│       ├── UPDATE-MOD-PAGE.md                  [36 lines | 1.8 KB]
│       └── WORKFLOW.md                         [111 lines | 5.4 KB]
├── prototypes/
│   ├── entities/
│   │   ├── pneumatic-capsule-counter.lua       [167 lines | 5.2 KB]
│   │   ├── pneumatic-diverter.lua              [83 lines | 2.6 KB]
│   │   ├── pneumatic-projector.lua             [159 lines | 4.9 KB]
│   │   └── pneumatic-pump-proxy.lua            [44 lines | 1.1 KB]
│   ├── custom-input.lua                    [38 lines | 904 B]
│   ├── entity.lua                          [338 lines | 10.7 KB]
│   ├── item.lua                            [257 lines | 7.9 KB]
│   ├── recipe.lua                          [324 lines | 9.0 KB]
│   ├── shortcut.lua                        [14 lines | 393 B]
│   └── technology.lua                      [304 lines | 9.0 KB]
├── scripts/
│   ├── capsules/
│   │   ├── capsule-ballistics.lua              [1,662 lines | 74.2 KB]
│   │   ├── capsule-definitions.lua             [393 lines | 16.3 KB]
│   │   ├── capsule-inputs.lua                  [9 lines | 324 B]
│   │   ├── capsule-lifecycle.lua               [971 lines | 42.4 KB]
│   │   ├── capsule-manager.lua                 [353 lines | 14.7 KB]
│   │   ├── capsule-queries.lua                 [518 lines | 19.4 KB]
│   │   ├── capsule-renderer.lua                [2,012 lines | 76.8 KB]
│   │   ├── capsule-runner.lua                  [1,073 lines | 41.7 KB]
│   │   └── capsule-transit.lua                 [151 lines | 5.9 KB]
│   ├── counters/
│   │   ├── counter-gui.lua                     [334 lines | 11.1 KB]
│   │   ├── counter-logic.lua                   [212 lines | 9.1 KB]
│   │   ├── counter-manager.lua                 [76 lines | 2.5 KB]
│   │   ├── counter-range.lua                   [425 lines | 16.1 KB]
│   │   └── counter-settings.lua                [93 lines | 3.5 KB]
│   ├── diverters/
│   │   ├── diverter-gui.lua                    [746 lines | 29.2 KB]
│   │   ├── diverter-manager.lua                [108 lines | 4.0 KB]
│   │   ├── diverter-renderer.lua               [324 lines | 15.6 KB]
│   │   ├── diverter-settings.lua               [345 lines | 14.3 KB]
│   │   └── diverter-slot-modal.lua             [278 lines | 10.5 KB]
│   ├── flow/
│   │   ├── flow-common.lua                     [202 lines | 7.9 KB]
│   │   ├── flow-engine.lua                     [1,181 lines | 51.5 KB]
│   │   ├── flow-gate-interop.lua               [517 lines | 22.9 KB]
│   │   ├── flow-kinetic.lua                    [3,192 lines | 142.5 KB]
│   │   ├── flow-renderer.lua                   [706 lines | 27.0 KB]
│   │   └── port-defs.lua                       [370 lines | 35.6 KB]
│   ├── hubs/
│   │   ├── packing/
│   │   │   ├── belt-siphon.lua                     [464 lines | 19.0 KB]
│   │   │   ├── cargo-planner.lua                   [155 lines | 6.9 KB]
│   │   │   └── quality-filter.lua                  [77 lines | 2.5 KB]
│   │   ├── hub-definitions.lua                 [15 lines | 318 B]
│   │   ├── hub-gui.lua                         [284 lines | 10.4 KB]
│   │   ├── hub-manager.lua                     [298 lines | 11.7 KB]
│   │   ├── hub-packing.lua                     [415 lines | 16.7 KB]
│   │   ├── hub-settings.lua                    [162 lines | 6.0 KB]
│   │   ├── hub-spill.lua                       [283 lines | 12.9 KB]
│   │   └── hub-unpacking.lua                   [282 lines | 11.4 KB]
│   ├── projectors/
│   │   ├── projector-manager.lua               [130 lines | 5.8 KB]
│   │   └── projector-settings.lua              [282 lines | 10.8 KB]
│   ├── pumps/
│   │   ├── pump-gui.lua                        [265 lines | 11.3 KB]
│   │   ├── pump-manager.lua                    [75 lines | 2.7 KB]
│   │   └── pump-settings.lua                   [138 lines | 5.2 KB]
│   ├── surfaces/
│   │   └── liminal-surface.lua                 [187 lines | 6.6 KB]
│   ├── utils/
│   │   ├── gui/
│   │   │   ├── gui-filter-spec.lua                 [239 lines | 9.6 KB]
│   │   │   └── gui-quality-bar.lua                 [213 lines | 8.1 KB]
│   │   ├── binary-heap.lua                     [637 lines | 20.7 KB]
│   │   ├── blueprint-sync.lua                  [614 lines | 26.3 KB]
│   │   ├── gui-components.lua                  [627 lines | 23.7 KB]
│   │   ├── item-transfer-handler.lua           [208 lines | 7.8 KB]
│   │   ├── motion-protocols.lua                [576 lines | 26.6 KB]
│   │   ├── profiler.lua                        [709 lines | 22.0 KB]
│   │   ├── render-pool.lua                     [387 lines | 14.4 KB]
│   │   ├── timed-motion.lua                    [535 lines | 23.0 KB]
│   │   ├── trajectory-bvh.lua                  [1,003 lines | 36.7 KB]
│   │   └── viewport-bvh.lua                    [980 lines | 39.3 KB]
│   ├── active-device-scanner.lua           [545 lines | 24.2 KB]
│   ├── debug-manager.lua                   [1,099 lines | 47.3 KB]
│   ├── device-settings-copier.lua          [239 lines | 10.9 KB]
│   ├── event-logger.lua                    [35 lines | 899 B]
│   ├── events.lua                          [54 lines | 1.7 KB]
│   └── proxy-manager.lua                   [660 lines | 22.8 KB]
├── .gitignore                          [18 lines | 305 B]
├── aggregator_patcher.py               [906 lines | 33.7 KB]
├── changelog.txt                       [178 lines | 19.3 KB]
├── control.lua                         [207 lines | 8.3 KB]
├── data.lua                            [30 lines | 868 B]
├── FILE-GROUPS.md                      [9 lines | 292 B]
├── file_grouper.py                     [197 lines | 6.1 KB]
├── info.json                           [13 lines | 426 B]
├── LICENSE                             [21 lines | 1.1 KB]
├── patch.txt                           [0 lines | 0 B]
├── require_graph.md                    [132 lines | 12.8 KB]
├── require_hierarchy.py                [491 lines | 15.1 KB]
├── settings.lua                        [1 lines | 30 B]
└── thumbnail.png                       [64.7 KB]
```
