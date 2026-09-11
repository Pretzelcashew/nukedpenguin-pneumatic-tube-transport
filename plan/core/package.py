import sys
import os
import re
import json
import shutil
import subprocess
import shlex
import traceback

# Extensions strictly prohibited by the Factorio Mod Portal
PORTAL_FORBIDDEN_PATTERNS = ["*.py", "*.exe", "*.bat", "*.ps1", "*.sh"]

def parse_export_rules(filepath, base_dir):
    """
    Parses EXPORT.md using .gitignore-style syntax:
    - Lines ending with '/' or matching local directories -> /XD (Exclude Directory)
    - Other lines and wildcards (e.g. *.py, *.md) -> /XF (Exclude File)
    - Supports comments (#) and blank lines.
    - Retains backwards-compatibility with 'exclude folders:' / 'exclude files:'.
    """
    exclude_dirs = {".git", "plan"}
    exclude_files = set(PORTAL_FORBIDDEN_PATTERNS)
    exclude_files.update(["package.py", "EXPORT.md"])

    if not filepath or not os.path.isfile(filepath):
        return exclude_dirs, exclude_files

    with open(filepath, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            # Legacy support for 'exclude folders:' / 'exclude files:'
            if line.lower().startswith("exclude folders:"):
                parts = line.split(":", 1)[1].split()
                exclude_dirs.update(parts)
                continue
            if line.lower().startswith("exclude files:"):
                parts = line.split(":", 1)[1].split()
                exclude_files.update(parts)
                continue

            # .gitignore-style: trailing slash means folder
            if line.endswith("/") or line.endswith("\\"):
                folder_name = line.rstrip("/\\").strip()
                if folder_name:
                    exclude_dirs.add(folder_name)
            elif "/" in line or "\\" in line:
                # Path relative to base directory
                full_path = os.path.normpath(os.path.join(base_dir, line))
                if os.path.isdir(full_path):
                    exclude_dirs.add(full_path)
                else:
                    exclude_files.add(full_path)
            elif os.path.isdir(os.path.join(base_dir, line)):
                exclude_dirs.add(line)
            else:
                exclude_files.add(line)

    return exclude_dirs, exclude_files

def format_robocopy_flags(items):
    """Formats a set of exclusions into a space-separated string with quotes if needed."""
    resolved = []
    for item in sorted(items):
        if " " in item:
            resolved.append(f'"{item}"')
        else:
            resolved.append(item)
    return " ".join(resolved)

def main():
    print("=" * 70)
    print("FACTORIO MOD PACKAGER (.gitignore EXPORT Engine)")
    print("=" * 70)

    # 1. Destination is on your HDD (where package.py lives)
    destination = os.path.dirname(os.path.abspath(__file__))

    # 2. Source is the folder you dragged and dropped
    if len(sys.argv) > 1:
        source = sys.argv[1].strip().strip('"')
    else:
        source = input("Drag and drop your mod folder here and press Enter: ").strip().strip('"')

    if not os.path.isdir(source):
        print(f"\nError: Dropped item is not a valid folder:\n{source}")
        input("\nPress Enter to exit...")
        return

    # 3. Look for EXPORT.md in plan/core, source root, or destination
    config_path = ""
    checked_paths = [
        os.path.join(source, "plan", "core", "EXPORT.md"),
        os.path.join(source, "EXPORT.md"),
        os.path.join(destination, "EXPORT.md")
    ]

    for path in checked_paths:
        if os.path.isfile(path):
            config_path = path
            break

    # Stop and prompt if EXPORT.md could not be found anywhere
    if not config_path:
        print("\n" + "=" * 70)
        print("WARNING: EXPORT.md was NOT found!")
        print("Looked in:")
        for path in checked_paths:
            print(f"  - {path}")
        print("=" * 70)
        choice = input("Proceed packaging with default fallback exclusions? (y/N): ").strip().lower()
        if choice not in ["y", "yes"]:
            print("\nBuild cancelled. Please place EXPORT.md in plan/core/ or the mod root.")
            input("\nPress Enter to exit...")
            return

    exclude_dirs, exclude_files = parse_export_rules(config_path, source)

    # 4. Read info.json from the mod folder
    info_path = os.path.join(source, "info.json")
    info_data = {}
    if os.path.isfile(info_path):
        try:
            with open(info_path, "r", encoding="utf-8") as f:
                info_data = json.load(f)
        except Exception as e:
            print(f"Warning: Could not parse info.json: {e}")
    else:
        print(f"\nError: No info.json found inside:\n{source}")
        input("\nPress Enter to exit...")
        return

    mod_name = str(info_data.get("name") or os.path.basename(os.path.normpath(source))).strip()
    
    # Version extraction
    raw_version = info_data.get("version") or ""
    version = str(raw_version).lstrip("_v").strip()

    if not version:
        print("\nError: Could not determine version from info.json!")
        input("\nPress Enter to exit...")
        return

    package_name = f"{mod_name}_{version}"
    dest_zip = os.path.join(destination, f"{package_name}.zip")

    # 5. Overwrite Check
    if os.path.isfile(dest_zip):
        print("=" * 70)
        print(f"WARNING: Output file already exists in destination!")
        print(f"--> {dest_zip}")
        print("=" * 70)
        choice = input("Overwrite this file? Did you forget to bump info.json? (y/N): ").strip().lower()
        if choice not in ["y", "yes"]:
            print("\nBuild cancelled. No files were changed.")
            input("\nPress Enter to exit...")
            return
        try:
            os.remove(dest_zip)
        except Exception as e:
            print(f"Warning: Could not remove old file: {e}")

    # 6. Build Robocopy Flags
    xd_resolved = format_robocopy_flags(exclude_dirs)
    xf_resolved = format_robocopy_flags(exclude_files)

    xd_flag = f"/XD {xd_resolved}" if xd_resolved else ""
    xf_flag = f"/XF {xf_resolved}" if xf_resolved else ""

    # 7. Staging and Packaging
    temp_staging = os.path.join(destination, "_temp_staging")
    staging_target = os.path.join(temp_staging, package_name)

    if os.path.exists(temp_staging):
        try:
            shutil.rmtree(temp_staging, ignore_errors=True)
        except Exception:
            pass

    cmd = (
        f'robocopy "{source}" "{staging_target}" /E {xd_flag} {xf_flag}; '
        f'pushd "{temp_staging}"; '
        f'tar.exe -a -cf "{dest_zip}" "{package_name}"; '
        f'popd; '
        f'Remove-Item "{temp_staging}" -Recurse -Force'
    )
    cmd = re.sub(r'\s+', ' ', cmd)

    print(f"PACKAGING:   {package_name}")
    print(f"FROM SOURCE: {source} (SSD - Read Only)")
    if config_path:
        print(f"RULES FILE:  {config_path}")
    else:
        print("RULES FILE:  None found (User confirmed fallback mode)")
    print(f"EXCLUDING:   {len(exclude_dirs)} folder rule(s), {len(exclude_files)} file pattern(s)")
    print(f"TO ZIP:      {dest_zip}")
    print("=" * 70)
    print("\nRunning build...\n")

    # 8. Execute via PowerShell
    proc = subprocess.run(["powershell", "-NoProfile", "-Command", cmd])

    # Robocopy codes 0-3 are clean transfer codes
    if proc.returncode in [0, 1, 2, 3]:
        print("\n" + "=" * 70)
        print("SUCCESS! Release package built with zero forbidden files:")
        print(f"--> {dest_zip}")
        print("=" * 70)
    else:
        print(f"\nFinished with code: {proc.returncode}")

    input("\nPress Enter to close this window...")

if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("\n" + "!" * 70)
        print("AN UNHANDLED ERROR OCCURRED:")
        print("!" * 70)
        traceback.print_exc()
        print("!" * 70)
        input("\nPress Enter to close...")