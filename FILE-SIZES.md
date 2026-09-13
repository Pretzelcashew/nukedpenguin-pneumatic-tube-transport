# FILE-SIZES.md - Workspace Size & Metric Audit
**Project:** `nukedpenguin-pneumatic-tube-transport`  
**Last Generated:** 2026-09-12 22:48:37  
**Total Scope:** 22 directories, 98 files  
**Total Workspace Size:** 1.61 MB | **Total Text Lines:** 27,336  

---

## 1. Refactor Watchlist (Largest Files by Line Count)
Files flagged with 🔴 should be considered for modularization before major refactors to prevent AI patch failures.

| Relative File Path | Lines | Size | Patch Risk / Refactor Status |
| :--- | :---: | :---: | :--- |
| `plan/core/CHANGELOG.md` | 2,225 | 357.5 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/flow/flow-engine.lua` | 1,079 | 46.4 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/capsules/capsule-runner.lua` | 1,045 | 40.2 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/capsules/capsule-lifecycle.lua` | 971 | 42.4 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `plan/archive/ARCHITECTURE.md` | 830 | 120.9 KB | 🔴 **High Risk** (Split candidate, > 800 lines) |
| `scripts/debug-manager.lua` | 771 | 31.3 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `aggregator_patcher.py` | 756 | 26.9 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/diverters/diverter-gui.lua` | 746 | 29.2 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/proxy-manager.lua` | 660 | 22.8 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/gui-components.lua` | 627 | 23.7 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/flow/flow-renderer.lua` | 621 | 23.8 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/blueprint-sync.lua` | 614 | 26.3 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/utils/binary-heap.lua` | 552 | 17.6 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/active-device-scanner.lua` | 545 | 24.2 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/capsules/capsule-ballistics.lua` | 534 | 21.9 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/capsules/capsule-queries.lua` | 518 | 19.4 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/flow/flow-gate-interop.lua` | 517 | 22.9 KB | 🟡 **Moderate** (Approaching patch threshold, 500–800) |
| `scripts/capsules/capsule-renderer.lua` | 470 | 17.2 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/hubs/packing/belt-siphon.lua` | 464 | 19.0 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/flow/flow-kinetic.lua` | 457 | 19.2 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/counters/counter-range.lua` | 425 | 16.1 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/hubs/hub-packing.lua` | 415 | 16.7 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/capsules/capsule-definitions.lua` | 393 | 16.3 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/utils/profiler.lua` | 387 | 10.9 KB | 🟢 **Manageable** (< 500 lines) |
| `scripts/capsules/capsule-manager.lua` | 353 | 14.7 KB | 🟢 **Manageable** (< 500 lines) |

---

## 2. Full Workspace Metric Tree

```text
nukedpenguin-pneumatic-tube-transport/
├── docs/
│   ├── arch/
│   │   ├── ARCH-CAPSULES-MOTION.md             [144 lines | 20.7 KB]
│   │   ├── ARCH-DEVICES-CIRCUITS.md            [220 lines | 32.3 KB]
│   │   ├── ARCH-FLOW-KINETICS.md               [150 lines | 21.0 KB]
│   │   ├── ARCH-HUBS-LOGISTICS.md              [94 lines | 16.3 KB]
│   │   └── ARCH-PROTOTYPES.md                  [57 lines | 11.8 KB]
│   └── guides/
│       └── capsule-definitions-guide.md        [214 lines | 8.5 KB]
├── locale/
│   └── en/
│       └── config.cfg                          [169 lines | 11.8 KB]
├── plan/
│   ├── archive/
│   │   ├── ARCHITECTURE.md                     [830 lines | 120.9 KB]
│   │   ├── CHANGES_0.3.23.md                   [28 lines | 3.9 KB]
│   │   └── SCRATCH.md                          [26 lines | 2.5 KB]
│   └── core/
│       ├── CHANGELOG.md                        [2,225 lines | 357.5 KB]
│       ├── EXPORT.md                           [43 lines | 1.5 KB]
│       ├── FRESH-CHANGES.md                    [185 lines | 30.4 KB]
│       ├── HELPERS.md                          [92 lines | 4.3 KB]
│       ├── MANIFEST.md                         [101 lines | 15.9 KB]
│       ├── MOD-DESCRIPTION.md                  [9 lines | 345 B]
│       ├── package.py                          [225 lines | 7.8 KB]
│       ├── PROMPT-AG-DIFF.md                   [128 lines | 8.9 KB]
│       ├── PROMPT-DOC-SYNC.md                  [55 lines | 4.5 KB]
│       ├── PROMPT-REVISION-LOG.md              [28 lines | 1.3 KB]
│       ├── SPLASH-PAGE.md                      [59 lines | 4.3 KB]
│       ├── TODO.md                             [105 lines | 8.4 KB]
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
│   │   ├── capsule-ballistics.lua              [534 lines | 21.9 KB]
│   │   ├── capsule-definitions.lua             [393 lines | 16.3 KB]
│   │   ├── capsule-inputs.lua                  [9 lines | 324 B]
│   │   ├── capsule-lifecycle.lua               [971 lines | 42.4 KB]
│   │   ├── capsule-manager.lua                 [353 lines | 14.7 KB]
│   │   ├── capsule-queries.lua                 [518 lines | 19.4 KB]
│   │   ├── capsule-renderer.lua                [470 lines | 17.2 KB]
│   │   ├── capsule-runner.lua                  [1,045 lines | 40.2 KB]
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
│   │   ├── flow-common.lua                     [150 lines | 5.8 KB]
│   │   ├── flow-engine.lua                     [1,079 lines | 46.4 KB]
│   │   ├── flow-gate-interop.lua               [517 lines | 22.9 KB]
│   │   ├── flow-kinetic.lua                    [457 lines | 19.2 KB]
│   │   ├── flow-renderer.lua                   [621 lines | 23.8 KB]
│   │   └── port-defs.lua                       [302 lines | 33.3 KB]
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
│   │   ├── hub-spill.lua                       [281 lines | 12.7 KB]
│   │   └── hub-unpacking.lua                   [282 lines | 11.4 KB]
│   ├── projectors/
│   │   ├── projector-manager.lua               [117 lines | 5.1 KB]
│   │   └── projector-settings.lua              [281 lines | 10.7 KB]
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
│   │   ├── binary-heap.lua                     [552 lines | 17.6 KB]
│   │   ├── blueprint-sync.lua                  [614 lines | 26.3 KB]
│   │   ├── gui-components.lua                  [627 lines | 23.7 KB]
│   │   ├── item-transfer-handler.lua           [208 lines | 7.8 KB]
│   │   └── profiler.lua                        [387 lines | 10.9 KB]
│   ├── active-device-scanner.lua           [545 lines | 24.2 KB]
│   ├── debug-manager.lua                   [771 lines | 31.3 KB]
│   ├── device-settings-copier.lua          [239 lines | 10.9 KB]
│   ├── event-logger.lua                    [35 lines | 899 B]
│   ├── events.lua                          [38 lines | 1.2 KB]
│   └── proxy-manager.lua                   [660 lines | 22.8 KB]
├── .gitignore                          [13 lines | 204 B]
├── aggregator_patcher.py               [756 lines | 26.9 KB]
├── changelog.txt                       [178 lines | 19.3 KB]
├── control.lua                         [127 lines | 5.3 KB]
├── data.lua                            [30 lines | 868 B]
├── info.json                           [13 lines | 426 B]
├── LICENSE                             [21 lines | 1.1 KB]
├── patch.txt                           [0 lines | 0 B]
├── settings.lua                        [1 lines | 30 B]
└── thumbnail.png                       [64.7 KB]
```
