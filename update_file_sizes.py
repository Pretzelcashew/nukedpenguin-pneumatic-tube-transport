#!/usr/bin/env python3
"""
update_file_sizes.py - Workspace File Size & Line Metrics Generator
Scans current working directory and generates FILE-SIZES.md with line counts,
byte sizes, and refactor threshold warnings.
Double-clickable on Windows.
"""

import os
import sys
from datetime import datetime

# Directory and file ignore rules (matches update_hierarchy.py)
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
    "FILE-SIZES.md",
    "update_hierarchy.py",
    "update_file_sizes.py",
    ".DS_Store",
    "thumbs.db",
}

BINARY_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".ico", ".zip", ".tar", ".gz", ".bin"
}

def is_ignored_file(filename: str) -> bool:
    if filename in IGNORED_FILES:
        return True
    if filename.startswith("aggregate_") and filename.endswith(".txt"):
        return True
    if filename.endswith(".zip") or filename.endswith(".tmp"):
        return True
    return False

def format_size(num_bytes: int) -> str:
    """Format bytes into human-readable B, KB, or MB."""
    if num_bytes < 1024:
        return f"{num_bytes} B"
    elif num_bytes < 1024 * 1024:
        return f"{num_bytes / 1024:.1f} KB"
    else:
        return f"{num_bytes / (1024 * 1024):.2f} MB"

def get_file_metrics(filepath: str) -> tuple[int, int | None]:
    """Return (byte_size, line_count). Line count is None for binary files."""
    try:
        size = os.path.getsize(filepath)
    except OSError:
        return 0, None

    ext = os.path.splitext(filepath)[1].lower()
    if ext in BINARY_EXTENSIONS:
        return size, None

    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            lines = sum(1 for _ in f)
        return size, lines
    except Exception:
        return size, None

def scan_tree(dir_path: str, root_dir: str, prefix: str = "") -> tuple[list[str], list[dict], int, int, int]:
    """
    Recursively scan tree.
    Returns: (tree_lines, all_file_records, total_dirs, total_files, total_bytes)
    """
    lines = []
    records = []
    dir_count = 0
    file_count = 0
    total_bytes = 0

    try:
        entries = sorted(
            os.listdir(dir_path),
            key=lambda s: (not os.path.isdir(os.path.join(dir_path, s)), s.lower())
        )
    except PermissionError:
        return lines, records, dir_count, file_count, total_bytes

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
            sub_lines, sub_records, sub_dirs, sub_files, sub_bytes = scan_tree(full_path, root_dir, next_prefix)
            lines.extend(sub_lines)
            records.extend(sub_records)
            dir_count += sub_dirs
            file_count += sub_files
            total_bytes += sub_bytes
        else:
            file_count += 1
            size, line_cnt = get_file_metrics(full_path)
            total_bytes += size
            
            rel_path = os.path.relpath(full_path, root_dir).replace("\\", "/")
            records.append({
                "rel_path": rel_path,
                "name": entry,
                "size": size,
                "lines": line_cnt
            })

            # Format tree label
            if line_cnt is not None:
                meta_label = f"[{line_cnt:,} lines | {format_size(size)}]"
            else:
                meta_label = f"[{format_size(size)}]"

            lines.append(f"{prefix}{connector}{entry:<35} {meta_label}")

    return lines, records, dir_count, file_count, total_bytes

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    project_name = os.path.basename(root_dir)

    print(f"[*] Scanning file sizes and line metrics for: {project_name}...")
    tree_lines, file_records, total_dirs, total_files, total_bytes = scan_tree(root_dir, root_dir)

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Filter text files with line counts for refactor ranking
    text_files = [r for r in file_records if r["lines"] is not None]
    text_files.sort(key=lambda r: r["lines"], reverse=True)

    total_lines = sum(r["lines"] for r in text_files)

    # Build Header & Summary
    output = [
        f"# FILE-SIZES.md - Workspace Size & Metric Audit",
        f"**Project:** `{project_name}`  ",
        f"**Last Generated:** {now_str}  ",
        f"**Total Scope:** {total_dirs} directories, {total_files} files  ",
        f"**Total Workspace Size:** {format_size(total_bytes)} | **Total Text Lines:** {total_lines:,}  ",
        "",
        "---",
        "",
        "## 1. Refactor Watchlist (Largest Files by Line Count)",
        "Files flagged with 🔴 should be considered for modularization before major refactors to prevent AI patch failures.",
        "",
        "| Relative File Path | Lines | Size | Patch Risk / Refactor Status |",
        "| :--- | :---: | :---: | :--- |",
    ]

    # Populate top largest files (top 20 or anything > 300 lines)
    watchlist = [r for r in text_files if r["lines"] >= 250][:25]
    if not watchlist:
        watchlist = text_files[:10]

    for item in watchlist:
        lines = item["lines"]
        if lines >= 800:
            status = "🔴 **High Risk** (Split candidate, > 800 lines)"
        elif lines >= 500:
            status = "🟡 **Moderate** (Approaching patch threshold, 500–800)"
        else:
            status = "🟢 **Manageable** (< 500 lines)"

        output.append(f"| `{item['rel_path']}` | {lines:,} | {format_size(item['size'])} | {status} |")

    # Add Full Workspace Tree
    output.extend([
        "",
        "---",
        "",
        "## 2. Full Workspace Metric Tree",
        "",
        "```text",
        f"{project_name}/",
    ])
    output.extend(tree_lines)
    output.extend([
        "```",
        "",
    ])

    output_content = "\n".join(output)
    output_path = os.path.join(root_dir, "FILE-SIZES.md")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(output_content)

    print(f"[SUCCESS] Scanned {total_dirs} directories, {total_files} files, {total_lines:,} lines.")
    print(f"[SUCCESS] Written cleanly to: {output_path}")

if __name__ == "__main__":
    main()
    # Keep console open on Windows double-click
    if sys.platform.startswith("win"):
        input("\nPress Enter to close...")