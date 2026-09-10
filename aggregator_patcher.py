import fnmatch
import os
from pathlib import Path
import re
import sys

# ==============================================================================
# AGGREGATOR MODULE
# ==============================================================================


def parse_search_query(query: str) -> list[str]:
    matches = re.findall(r'filename:\s*(?:"([^"]+)"|(\S+))', query, re.IGNORECASE)
    patterns = [m[0] if m[0] else m[1] for m in matches if (m[0] or m[1])]

    if not patterns:
        tokens = re.split(r"\s+OR\s+|\s*,\s*", query, flags=re.IGNORECASE)
        patterns = [t.strip(' "') for t in tokens if t.strip(' "')]

    return patterns


def get_next_aggregate_filepath(base_dir: Path) -> Path:
    candidate = base_dir / "aggregate.txt"
    if not candidate.exists():
        return candidate

    counter = 1
    while True:
        candidate = base_dir / f"aggregate_{counter}.txt"
        if not candidate.exists():
            return candidate
        counter += 1


def is_binary_file(file_path: Path) -> bool:
    try:
        with open(file_path, "rb") as f:
            return b"\0" in f.read(1024)
    except Exception:
        return True


def read_file_lines(file_path: Path) -> list[str] | None:
    for encoding in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            with open(file_path, "r", encoding=encoding) as f:
                return f.readlines()
        except (UnicodeDecodeError, PermissionError):
            continue
    return None


def run_aggregator(start_dir: Path):
    script_path = Path(__file__).resolve()
    print("\n--- AGGREGATE FILES ---")
    print('Syntax example: filename: "some-file.md" OR filename: "*.lua"')
    query = input("Enter search query: ").strip()

    if not query:
        print("No search query entered.")
        return

    patterns = parse_search_query(query)
    if not patterns:
        print("Could not parse query.")
        return

    matched_files: list[Path] = []
    seen_paths = set()

    for root, dirs, files in os.walk(start_dir):
        # Ignore .git directory
        dirs[:] = [d for d in dirs if d.lower() != ".git"]

        for file_name in files:
            for pat in patterns:
                if fnmatch.fnmatch(file_name.lower(), pat.lower()):
                    full_path = (Path(root) / file_name).resolve()
                    if (
                        full_path == script_path
                        or full_path.name.startswith("aggregate")
                    ):
                        continue
                    if full_path not in seen_paths:
                        seen_paths.add(full_path)
                        matched_files.append(full_path)
                    break

    if not matched_files:
        print("No matching files found.")
        return

    output_path = get_next_aggregate_filepath(start_dir)
    print(f"\nWriting {len(matched_files)} files to {output_path.name}...")

    files_written = 0
    with open(output_path, "w", encoding="utf-8") as out:
        for file_path in matched_files:
            if is_binary_file(file_path):
                continue
            lines = read_file_lines(file_path)
            if lines is None:
                continue

            out.write("\n\n")
            out.write("=" * 80 + "\n")
            out.write(f"FILE: {file_path}\n")
            out.write("=" * 80 + "\n")

            pad_len = max(len(str(len(lines))), 4)
            for idx, line in enumerate(lines, start=1):
                clean_line = line if line.endswith("\n") else line + "\n"
                out.write(f"{idx:>{pad_len}} | {clean_line}")

            files_written += 1

    print(
        f"Completed! Created '{output_path.name}' with {files_written} file(s)."
    )


# ==============================================================================
# DIFF DECODER / PATCHER MODULE
# ==============================================================================


class PatchOperation:

    def __init__(self, op_type: str, start_line: int, end_line: int, lines: list[str]):
        self.op_type = op_type  # 'REPLACE', 'INSERT', 'DELETE'
        self.start_line = start_line
        self.end_line = end_line
        self.lines = lines

    def sort_key(self):
        # Sort bottom-to-top so modifications at the bottom do not change line
        # indices of earlier modifications.
        return self.start_line


def parse_patch_file(patch_text: str) -> dict[Path, list[PatchOperation]]:
    """Parses diff commands grouped by file path."""
    file_patches: dict[Path, list[PatchOperation]] = {}

    # Split into sections by file header
    file_sections = re.split(r"(?:\*\*\*\s*FILE:\s*|FILE:\s*)", patch_text)

    for section in file_sections:
        if not section.strip():
            continue

        lines = section.splitlines()
        raw_path = lines[0].strip().strip('"').strip("'")
        target_path = Path(raw_path)

        # Regex for <<< COMMAND ... >>> blocks
        block_pattern = re.compile(
            r"<<<\s*(REPLACE\s+LINES?\s+\d+(?:-\d+)?|"
            r"INSERT\s+(?:AFTER|BEFORE)\s+LINE\s+\d+|"
            r"DELETE\s+LINES?\s+\d+(?:-\d+)?)\s*\n"
            r"(.*?)"
            r"\n?>>>",
            re.DOTALL | re.IGNORECASE,
        )

        ops = []
        body_text = "\n".join(lines[1:])

        for match in block_pattern.finditer(body_text):
            cmd_header = match.group(1).strip()
            content = match.group(2)

            replacement_lines = (
                [line + "\n" for line in content.splitlines()]
                if content
                else []
            )

            # 1. REPLACE LINES X-Y or REPLACE LINE X
            m_rep = re.match(
                r"REPLACE\s+LINES?\s+(\d+)(?:\s*-\s*(\d+))?",
                cmd_header,
                re.IGNORECASE,
            )
            if m_rep:
                s = int(m_rep.group(1))
                e = int(m_rep.group(2)) if m_rep.group(2) else s
                ops.append(PatchOperation("REPLACE", s, e, replacement_lines))
                continue

            # 2. DELETE LINES X-Y or DELETE LINE X
            m_del = re.match(
                r"DELETE\s+LINES?\s+(\d+)(?:\s*-\s*(\d+))?",
                cmd_header,
                re.IGNORECASE,
            )
            if m_del:
                s = int(m_del.group(1))
                e = int(m_del.group(2)) if m_del.group(2) else s
                ops.append(PatchOperation("DELETE", s, e, []))
                continue

            # 3. INSERT AFTER LINE X
            m_ins_after = re.match(
                r"INSERT\s+AFTER\s+LINE\s+(\d+)", cmd_header, re.IGNORECASE
            )
            if m_ins_after:
                line_no = int(m_ins_after.group(1))
                ops.append(
                    PatchOperation(
                        "INSERT_AFTER", line_no, line_no, replacement_lines
                    )
                )
                continue

            # 4. INSERT BEFORE LINE X
            m_ins_before = re.match(
                r"INSERT\s+BEFORE\s+LINE\s+(\d+)", cmd_header, re.IGNORECASE
            )
            if m_ins_before:
                line_no = int(m_ins_before.group(1))
                ops.append(
                    PatchOperation(
                        "INSERT_BEFORE", line_no, line_no, replacement_lines
                    )
                )
                continue

        if ops:
            file_patches[target_path] = ops

    return file_patches


def apply_patch(target_path: Path, ops: list[PatchOperation]) -> bool:
    """Applies a list of patch operations to a file."""
    if not target_path.exists():
        print(f"Error: Target file does not exist: {target_path}")
        return False

    orig_lines = read_file_lines(target_path)
    if orig_lines is None:
        print(f"Error: Could not read file encoding: {target_path}")
        return False

    # Sort descending by target line so bottom edits don't shift top line numbers
    ops.sort(key=lambda o: o.sort_key(), reverse=True)

    modified_lines = list(orig_lines)

    for op in ops:
        if op.op_type in ("REPLACE", "DELETE"):
            start_idx = op.start_line - 1
            end_idx = op.end_line
            if start_idx < 0 or start_idx > len(modified_lines):
                print(
                    f"Warning: Line {op.start_line} is out of range for {target_path.name}"
                )
                continue
            modified_lines[start_idx:end_idx] = op.lines

        elif op.op_type == "INSERT_AFTER":
            # After line X is at index X
            idx = op.start_line
            modified_lines[idx:idx] = op.lines

        elif op.op_type == "INSERT_BEFORE":
            # Before line X is at index X - 1
            idx = max(0, op.start_line - 1)
            modified_lines[idx:idx] = op.lines

    with open(target_path, "w", encoding="utf-8") as f:
        f.writelines(modified_lines)

    return True


def run_patcher(start_dir: Path):
    print("\n--- APPLY DIFF / PATCH ---")
    patch_file_input = input(
        "Enter patch file name [default: patch.txt]: "
    ).strip()
    patch_file_path = (
        Path(patch_file_input)
        if patch_file_input
        else (start_dir / "patch.txt")
    )

    if not patch_file_path.exists():
        print(f"Patch file not found: {patch_file_path}")
        return

    try:
        with open(patch_file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading patch file: {e}")
        return

    patches = parse_patch_file(content)
    if not patches:
        print(
            "No valid patch operations found in the file. Check formatting syntax."
        )
        return

    print(f"\nFound operations for {len(patches)} file(s):")
    for file_path, ops in patches.items():
        print(f"  • {file_path.name}: {len(ops)} operation(s)")

    confirm = input("\nProceed with applying changes? (y/n): ").strip().lower()
    if confirm != "y":
        print("Aborted.")
        return

    success_count = 0
    for file_path, ops in patches.items():
        print(f"Patching: {file_path} ... ", end="")
        if apply_patch(file_path, ops):
            print("OK")
            success_count += 1
        else:
            print("FAILED")

    print(
        f"\nDone. Successfully modified {success_count}/{len(patches)} file(s)."
    )


# ==============================================================================
# MAIN ENTRY
# ==============================================================================


def main():
    start_dir = Path(__file__).resolve().parent

    while True:
        print("\n" + "=" * 60)
        print(" Code Aggregator & Diff Patcher")
        print("=" * 60)
        print(" [1] Aggregate files into aggregate_N.txt")
        print(" [2] Apply AI patch/diffs (from patch.txt)")
        print(" [0] Exit")
        choice = input("\nSelect an option [0-2]: ").strip()

        if choice == "1":
            run_aggregator(start_dir)
        elif choice == "2":
            run_patcher(start_dir)
        elif choice == "0":
            break
        else:
            print("Invalid selection.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\nAn error occurred: {e}")
    finally:
        input("\nPress Enter to close...")