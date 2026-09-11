# ==============================================================================
# ⚠️ CRITICAL BUILD CONFIGURATION & RELEASE PROTOCOL
# DO NOT MOVE, RENAME, OR ARCHIVE THIS FILE!
# Active rule manifest consumed directly by package.py during mod release builds.
# ==============================================================================
#
# 🚨 PACKAGING SCRIPT USAGE & SYNC WARNING:
# 1. DO NOT execute the local `plan/core/package.py` inside this repository!
#    - That file is strictly an in-repo code record / reference copy.
# 2. ALWAYS use the standalone master `package.py` located on your external drive
#    to build release zips (drag and drop this mod folder onto THAT external script).
# 3. KEEP IN SYNC: Whenever you modify `package.py` (either on your external drive
#    or in `plan/core/`), immediately update the other copy so both remain identical!
#
# ==============================================================================
# ==============================================================================
# Factorio Mod Export Exclusions (.gitignore syntax)
# ==============================================================================

# Directories to exclude
.git/
.vscode/
plan/
docs/

# Factorio Mod Portal Banned Executables & Scripts (Error 500 Guard)
*.py
*.exe
*.bat
*.ps1
*.sh

# Documentation & Tooling Notes (LICENSE is kept and shipped)
*.md
.gitignore

# Patcher & Build Scratchpads
patch.txt
aggregate*.txt
aggregate.txt

# Development Lua Scratchpads
event-logger.lua