#!/usr/bin/env python3
"""
file_grouper.py
Ultra-compact drag-and-drop file staging queue and Windows search query generator.
Pins new groups directly to Line 3 with zero fluff: just the group title and the copy box.
"""

import sys
import os
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
QUEUE_FILE = SCRIPT_DIR / ".file_group_queue.json"
OUTPUT_MD = SCRIPT_DIR / "FILE-GROUPS.md"

TITLE_LINE = "# FILE-GROUPS.md\n\n"


def load_queue() -> list:
    if QUEUE_FILE.exists():
        try:
            with open(QUEUE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
        except Exception:
            pass
    return []


def save_queue(queue: list):
    try:
        with open(QUEUE_FILE, "w", encoding="utf-8") as f:
            json.dump(queue, f, indent=2)
    except Exception as e:
        print(f"[!] Warning: Could not save queue file: {e}")


def clean_path(raw_path: str) -> str:
    p = Path(raw_path).resolve()
    try:
        rel = p.relative_to(SCRIPT_DIR)
        return str(rel).replace("\\", "/")
    except ValueError:
        return str(p).replace("\\", "/")


def generate_search_query(files: list) -> str:
    parts = []
    seen = set()
    for f in files:
        basename = Path(f).name
        if basename not in seen:
            seen.add(basename)
            parts.append(f'filename: "{basename}"')
    return " OR ".join(parts)


def insert_group_at_top(group_name: str, files: list):
    query = generate_search_query(files)

    # Ultra-compact: Title + 1-Click Box + Divider line
    new_entry = (
        f"### {group_name} ({len(files)} files)\n"
        f"```text\n{query}\n```\n\n"
        "---\n\n"
    )

    if not OUTPUT_MD.exists():
        full_content = TITLE_LINE + new_entry
    else:
        with open(OUTPUT_MD, "r", encoding="utf-8") as f:
            existing = f.read()

        if existing.startswith("# FILE-GROUPS.md"):
            lines = existing.splitlines(keepends=True)
            idx = 1
            while idx < len(lines):
                line_str = lines[idx].strip()
                if line_str.startswith("### "):
                    break
                idx += 1
            rest = "".join(lines[idx:]).lstrip("\n")
            full_content = TITLE_LINE + new_entry + rest
        else:
            full_content = TITLE_LINE + new_entry + existing.lstrip("\n")

    with open(OUTPUT_MD, "w", encoding="utf-8") as f:
        f.write(full_content)


def print_queue(queue: list):
    print("\n" + "=" * 65)
    print(f"  CURRENT QUEUE ({len(queue)} files)")
    print("=" * 65)
    if not queue:
        print("  (Queue is currently empty)")
    else:
        for idx, f in enumerate(queue, 1):
            print(f"  {idx:2d}. {f}")

    if queue:
        print("\n  Preview Search String:")
        print(f"  {generate_search_query(queue)}")
    print("=" * 65 + "\n")


def main():
    queue = load_queue()

    # Process files dropped directly onto the .py file in Windows Explorer
    incoming = sys.argv[1:]
    added_count = 0
    if incoming:
        for arg in incoming:
            target = Path(arg)
            if target.is_dir():
                for sub in target.rglob("*"):
                    if sub.is_file():
                        cp = clean_path(str(sub))
                        if cp not in queue:
                            queue.append(cp)
                            added_count += 1
            elif target.is_file():
                cp = clean_path(str(target))
                if cp not in queue:
                    queue.append(cp)
                    added_count += 1

        if added_count > 0:
            save_queue(queue)
            print(f"[+] Added {added_count} file(s) to the queue from drag-and-drop.")

    while True:
        print_queue(queue)

        print("Actions:")
        print("  • Type a GROUP NAME to save to TOP of FILE-GROUPS.md")
        print("  • Drag & drop another file into this window (then press Enter)")
        print("  • Type 'd <number>' to remove a file from queue")
        print("  • Type 'c' to clear queue")
        print("  • Press [ENTER] without typing anything to keep queue and exit")

        choice = input("\n> ").strip()

        if not choice:
            print("[✓] Queue preserved. Exiting.")
            break

        cmd_lower = choice.lower()
        if cmd_lower == 'q':
            break
        elif cmd_lower == 'c':
            queue.clear()
            save_queue(queue)
            print("[✓] Queue cleared.")
        elif cmd_lower.startswith("d ") and cmd_lower[2:].isdigit():
            idx = int(cmd_lower[2:]) - 1
            if 0 <= idx < len(queue):
                removed = queue.pop(idx)
                save_queue(queue)
                print(f"[✓] Removed '{removed}' from queue.")
            else:
                print("[!] Invalid item number.")
        else:
            test_path = Path(choice.strip('"\''))
            if test_path.exists() and test_path.is_file():
                cp = clean_path(str(test_path))
                if cp not in queue:
                    queue.append(cp)
                    save_queue(queue)
                    print(f"[✓] Added '{cp}' to queue.")
                else:
                    print(f"[i] '{cp}' is already in the queue.")
                continue

            if not queue:
                print("[!] Queue is empty. Add at least one file before naming a group.")
                continue

            group_name = choice
            insert_group_at_top(group_name, queue)
            print(f"\n[✓] Successfully pinned '{group_name}' to TOP of FILE-GROUPS.md!")
            queue.clear()
            save_queue(queue)

            input("\nPress Enter to finish...")
            break


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nExiting.")
        sys.exit(0)