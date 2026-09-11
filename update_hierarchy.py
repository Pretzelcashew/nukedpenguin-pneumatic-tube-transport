#!/usr/bin/env python3
"""
update_hierarchy.py - Live Workspace Tree Generator for Factorio Modding
Scans current working directory and updates FOLDER-HIERARCHY.md.
Double-clickable on Windows.
"""

import os
import sys
from datetime import datetime

# Directory and file ignore rules
IGNORED_DIRS = {
    ".git",
    ".vscode",
    ".idea",
    "__pycache__",
    "build",
    "dist",
    ".venv",
    "venv",
}

IGNORED_FILES = {
    "FOLDER-HIERARCHY.md",
    "update_hierarchy.py",
    ".DS_Store",
    "thumbs.db",
}

def is_ignored_file(filename: str) -> bool:
    if filename in IGNORED_FILES:
        return True
    # Ignore git internals, zip archives, and patcher aggregate dumps
    if filename.startswith("aggregate_") and filename.endswith(".txt"):
        return True
    if filename.endswith(".zip") or filename.endswith(".tmp"):
        return True
    return False

def build_tree(dir_path: str, prefix: str = "") -> tuple[list[str], int, int]:
    lines = []
    dir_count = 0
    file_count = 0

    try:
        entries = sorted(os.listdir(dir_path), key=lambda s: (not os.path.isdir(os.path.join(dir_path, s)), s.lower()))
    except PermissionError:
        return lines, dir_count, file_count

    # Filter entries
    filtered = []
    for entry in entries:
        full_path = os.path.join(dir_path, entry)
        if os.path.isdir(full_path):
            if entry not in IGNORED_DIRS:
                filtered.append(entry)
        else:
            if not is_ignored_file(entry):
                filtered.append(entry)

    total = len(filtered)
    for index, entry in enumerate(filtered):
        is_last = (index == total - 1)
        connector = "└── " if is_last else "├── "
        full_path = os.path.join(dir_path, entry)

        if os.path.isdir(full_path):
            dir_count += 1
            lines.append(f"{prefix}{connector}{entry}/")
            next_prefix = prefix + ("    " if is_last else "│   ")
            sub_lines, sub_dirs, sub_files = build_tree(full_path, next_prefix)
            lines.extend(sub_lines)
            dir_count += sub_dirs
            file_count += sub_files
        else:
            file_count += 1
            lines.append(f"{prefix}{connector}{entry}")

    return lines, dir_count, file_count

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    project_name = os.path.basename(root_dir)
    
    print(f"[*] Scanning workspace: {project_name}...")
    tree_lines, total_dirs, total_files = build_tree(root_dir)

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    header = [
        f"# FOLDER-HIERARCHY.md - Live Workspace Tree",
        f"**Project:** `{project_name}`  ",
        f"**Last Generated:** {now_str}  ",
        f"**Scope:** {total_dirs} directories, {total_files} files  ",
        "",
        "```text",
        f"{project_name}/",
    ]
    
    footer = [
        "```",
        "",
    ]
    
    full_content = "\n".join(header + tree_lines + footer)
    output_path = os.path.join(root_dir, "FOLDER-HIERARCHY.md")
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(full_content)
        
    print(f"[SUCCESS] Scanned {total_dirs} directories and {total_files} files.")
    print(f"[SUCCESS] Written cleanly to: {output_path}")

if __name__ == "__main__":
    main()
    # Keep console open on Windows double-click
    if sys.platform.startswith("win"):
        input("\nPress Enter to close...")