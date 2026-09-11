#### 0.3.23


### Revision: Hardened Mod Packager and Release Export Manifest
**Date:** 2026-09-11 19:48 EDT
**Context:** Hardened the automated release packager against accidental configuration file omission and established explicit build-safety protocols for external drive packaging.
**Key Changes:**
1. **Mod Packaging Pipeline (`package.py`):** Extended `EXPORT.md` resolution to search `plan/core/` before root and destination fallbacks, added an interactive `(y/N)` execution gate when rules are absent, and documented multi-drive synchronization requirements.
2. **Release Export Manifest (`plan/core/EXPORT.md`):** Relocated active release exclusion rules out of archive staging into `plan/core/`, adding explicit anti-archival headers, script usage warnings, and cross-drive sync directives.