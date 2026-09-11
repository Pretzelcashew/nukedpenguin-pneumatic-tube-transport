#### 0.3.23

### Revision: Prototype Subfolder Modularization and Workspace Hygiene
**Date:** 2026-09-11 18:22 EDT
**Context:** Consolidated machine and proxy prototype definitions out of the root prototype folder into a dedicated entities subfolder to decouple general data specifications from device implementations. Relocated loose documentation out of the runtime script directory and archived obsolete staging files to maintain clean repository hygiene.
**Key Changes:**
1. **Prototype Stage Loader (`data.lua`):** Updated prototype `require` paths to load `pneumatic-diverter`, `pneumatic-pump-proxy`, `pneumatic-capsule-counter`, and `pneumatic-projector` from `prototypes/entities/`.
2. **Device Prototypes (`prototypes/entities/`):** Moved physical machine and proxy prototype definitions (`pneumatic-diverter.lua`, `pneumatic-pump-proxy.lua`, `pneumatic-capsule-counter.lua`, `pneumatic-projector.lua`, and proxy linkage files) from `prototypes/` into `prototypes/entities/`.
3. **Documentation Hygiene (`docs/guides/capsule-definitions-guide.md`):** Moved `scripts_capsules_capsule-definitions-guide.md` out of the runtime script directory `scripts/capsules/` into `docs/guides/`.
4. **Staging Archive (`plan/archive/`):** Relocated historical changelog notes, scratchpad files, and export dumps (`CHANGES_0.3.23.md`, `SCRATCH.md`, and `EXPORT.md`) into `plan/archive/`.