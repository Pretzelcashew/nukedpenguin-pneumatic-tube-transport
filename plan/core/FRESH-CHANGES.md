#### 0.3.23

### Revision: Prototype Subfolder Modularization and Workspace Hygiene
**Date:** 2026-09-11 18:22 EDT
**Context:** Consolidated machine and proxy prototype definitions out of the root prototype folder into a dedicated entities subfolder to decouple general data specifications from device implementations. Relocated loose documentation out of the runtime script directory and archived obsolete staging files to maintain clean repository hygiene.
**Key Changes:**
1. **Prototype Stage Loader (`data.lua`):** Updated prototype `require` paths to load `pneumatic-diverter`, `pneumatic-pump-proxy`, `pneumatic-capsule-counter`, and `pneumatic-projector` from `prototypes/entities/`.
2. **Device Prototypes (`prototypes/entities/`):** Moved physical machine and proxy prototype definitions (`pneumatic-diverter.lua`, `pneumatic-pump-proxy.lua`, `pneumatic-capsule-counter.lua`, `pneumatic-projector.lua`, and proxy linkage files) from `prototypes/` into `prototypes/entities/`.
3. **Documentation Hygiene (`docs/guides/capsule-definitions-guide.md`):** Moved `scripts_capsules_capsule-definitions-guide.md` out of the runtime script directory `scripts/capsules/` into `docs/guides/`.
4. **Staging Archive (`plan/archive/`):** Relocated historical changelog notes, scratchpad files, and export dumps (`CHANGES_0.3.23.md`, `SCRATCH.md`, and `EXPORT.md`) into `plan/archive/`.


### Revision: Device Scripts Subfolder Modularization and Consumer Import Synchronization
**Date:** 2026-09-11 18:39 EDT
**Context:** Grouped loose device logic, state definitions, renderers, and UI components into dedicated domain subdirectories (diverters, pumps, and projectors) to resolve top-level script directory asymmetry. Synchronized module import paths across the runtime loader, proxy manager, flow engine, and device background scanner to preserve clean dependency resolution.
**Key Changes:**
1. **Flow & Kinetic Simulation (`scripts/flow/flow-engine.lua`):** Updated module require statements for pump, diverter, and projector settings to import from `scripts/pumps/`, `scripts/diverters/`, and `scripts/projectors/`.
2. **Proxy Selection & UI Dispatch (`scripts/proxy-manager.lua`):** Realigned UI controller imports to target `scripts.pumps.pump-gui` and `scripts.diverters.diverter-gui` for proxy interaction handling.
3. **Runtime Entry Loader (`control.lua`):** Updated device module imports to load diverter, pump, and projector settings, GUIs, and world overlay renderers from their respective subfolders.
4. **Active Scanner & Settings Copier (`scripts/active-device-scanner.lua`, `scripts/device-settings-copier.lua`):** Updated all consumer imports for pump, diverter, and projector configuration handlers to reference the modular subdirectories.
5. **Capsule Motion & Projector Ballistics (`scripts/capsules/capsule-runner.lua`):** Updated diverter and projector settings dependencies to point to the new modular locations.
6. **Device Domain Modules (`scripts/diverters/`, `scripts/pumps/`):** Synchronized intra-module requires across `diverter-gui.lua`, `diverter-renderer.lua`, and `pump-gui.lua` to load sibling settings files cleanly.


### Revision: Purge Obsolete Pre-Unified Proxy Linkage Files
**Date:** 2026-09-11 19:03 EDT
**Context:** Purged legacy standalone proxy linkage scripts from prototypes/entities/ that were rendered obsolete by the centralized runtime proxy-manager.lua engine. Verified zero active references across prototype and runtime stages, removing dead code without impacting proxy behavior.
**Key Changes:**
1. **Diverter Proxy Linkage (`prototypes/entities/pneumatic-diverter-proxy-linkage.lua`):** Deleted unreferenced legacy linkage script superseded by unified proxy lifecycle handlers in `proxy-manager.lua`.
2. **Pump Proxy Linkage (`prototypes/entities/pneumatic-pump-proxy-linkage.lua`):** Deleted unreferenced legacy linkage script superseded by unified proxy lifecycle handlers in `proxy-manager.lua`.