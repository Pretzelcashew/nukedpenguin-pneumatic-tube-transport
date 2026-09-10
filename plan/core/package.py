import sys
import os
import re
import json
import shutil
import subprocess
import shlex
import traceback

def parse_config(filepath):
    config = {}
    if not filepath or not os.path.isfile(filepath):
        return config
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                key, val = line.split(":", 1)
                key = key.strip().lower().replace("_", " ")
                val = val.strip().strip('"').strip("'")
                config[key] = val
    return config

def resolve_exclusions(items_str, base_dir):
    """Turns relative paths into absolute paths for Robocopy, while leaving bare filenames as-is."""
    if not items_str:
        return ""
    try:
        items = shlex.split(items_str)
    except Exception:
        items = items_str.split()
    
    resolved = []
    for item in items:
        if "/" in item or "\\" in item:
            full_path = os.path.normpath(os.path.join(base_dir, item))
            resolved.append(f'"{full_path}"')
        else:
            resolved.append(f'"{item}"' if " " in item else item)
    return " ".join(resolved)

def main():
    print("=" * 70)
    print("FACTORIO MOD PACKAGER")
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

    # 3. Look for EXPORT.md
    config_path = ""
    if os.path.isfile(os.path.join(source, "EXPORT.md")):
        config_path = os.path.join(source, "EXPORT.md")
    elif os.path.isfile(os.path.join(destination, "EXPORT.md")):
        config_path = os.path.join(destination, "EXPORT.md")

    cfg = parse_config(config_path)
    config_filename = os.path.basename(config_path) if config_path else "EXPORT.md"

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
    
    # Bulletproof version extraction (safely handles missing or non-string version fields)
    raw_version = cfg.get("version") or info_data.get("version") or ""
    version = str(raw_version).lstrip("_v").strip()

    if not version:
        print("\nError: Could not determine version from info.json or EXPORT.md!")
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

    # 6. Exclusions
    user_folders = cfg.get("exclude folders", ".git plan")
    user_files = cfg.get("exclude files", "")
    all_files = f"package.py {config_filename} {user_files}".strip()

    xd_resolved = resolve_exclusions(user_folders, source)
    xf_resolved = resolve_exclusions(all_files, source)

    xd_flag = f"/XD {xd_resolved}" if xd_resolved else ""
    xf_flag = f"/XF {xf_resolved}" if xf_resolved else ""

    # 7. Staging on HDD (D:)
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
    print(f"TEMP STAGE:  {temp_staging} (HDD)")
    print(f"TO ZIP:      {dest_zip} (HDD)")
    print("=" * 70)
    print("\nRunning build...\n")

    # 8. Execute via PowerShell
    proc = subprocess.run(["powershell", "-NoProfile", "-Command", cmd])

    if proc.returncode in [0, 1, 2, 3]:
        print("\n" + "=" * 70)
        print("SUCCESS! Ready to upload:")
        print(f"--> {dest_zip}")
        print("=" * 70)
    else:
        print(f"\nFinished with code: {proc.returncode}")

    input("\nPress Enter to close this window...")

# CRASH GUARD: Locks window open if ANY error occurs
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