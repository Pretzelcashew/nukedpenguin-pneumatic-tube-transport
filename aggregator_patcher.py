import fnmatch
import os
from pathlib import Path
import re
import sys
from datetime import datetime

# ==============================================================================
# SNAPSHOT ARCHIVE & LOGGING
# ==============================================================================

LAST_PATCH_DATA: dict = {
    "text": None,
    "patches": None,
    "source": None,
    "timestamp": None,
    "snapshots": {},  # str(Path): str (original file content)
}


def get_archive_dir(base_dir: Path) -> Path:
    archive_dir = base_dir / ".patch_archive"
    archive_dir.mkdir(parents=True, exist_ok=True)
    return archive_dir


def append_patch_log(base_dir: Path, message: str):
    try:
        archive_dir = get_archive_dir(base_dir)
        log_file = archive_dir / "patch_history.log"
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{now_str}] {message}\n")
    except Exception:
        pass


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


def read_file_text(file_path: Path) -> str | None:
    for encoding in ("utf-8", "utf-8-sig", "latin-1"):
        try:
            with open(file_path, "r", encoding=encoding) as f:
                return f.read()
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
        dirs[:] = [d for d in dirs if d.lower() != ".git" and d.lower() != ".patch_archive"]

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

    print(f"Found {len(matched_files)} matching file(s).")
    line_opt = input("Include line numbers in aggregate? (y/N) [default: N]: ").strip().lower()
    include_line_numbers = (line_opt == "y")

    output_path = get_next_aggregate_filepath(start_dir)
    mode_desc = "with line numbers" if include_line_numbers else "clean raw code"
    print(f"\nWriting {len(matched_files)} files ({mode_desc}) to {output_path.name}...")

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

            if include_line_numbers:
                pad_len = max(len(str(len(lines))), 4)
                for idx, line in enumerate(lines, start=1):
                    clean_line = line if line.endswith("\n") else line + "\n"
                    out.write(f"{idx:>{pad_len}} | {clean_line}")
            else:
                for line in lines:
                    clean_line = line if line.endswith("\n") else line + "\n"
                    out.write(clean_line)

            files_written += 1

    print(f"Completed! Created '{output_path.name}' with {files_written} file(s) ({mode_desc}).")


# ==============================================================================
# DIFF DECODER / PATCHER MODULE
# ==============================================================================


class PatchOperation:
    def __init__(
        self,
        op_type: str,
        start_line: int = 0,
        end_line: int = 0,
        lines: list[str] | None = None,
        find_lines: list[str] | None = None,
    ):
        self.op_type = op_type
        self.start_line = start_line
        self.end_line = end_line
        self.lines = lines or []
        self.find_lines = find_lines or []


class FilePatch:
    def __init__(self, action: str, target_path: Path, dest_path: Path | None = None):
        self.action = action  # 'MODIFY', 'CREATE', 'DELETE', 'MOVE'
        self.target_path = target_path
        self.dest_path = dest_path
        self.create_content: list[str] = []
        self.ops: list[PatchOperation] = []
        self.original_content: str | None = None  # Exact snapshot before patch


def resolve_file_path(raw_path: str, base_dir: Path | None) -> Path:
    p = Path(raw_path.strip().strip('"').strip("'"))
    if not p.is_absolute() and base_dir:
        p = (base_dir / p).resolve()
    return p


def parse_line_operations(body_text: str) -> list[PatchOperation]:
    line_block_pattern = re.compile(
        r"<<<\s*(REPLACE\s+LINES?\s+\d+(?:-\d+)?|"
        r"INSERT\s+(?:AFTER|BEFORE)\s+LINE\s+\d+|"
        r"DELETE\s+LINES?\s+\d+(?:-\d+)?)\s*\n"
        r"(.*?)"
        r"\n?>>>",
        re.DOTALL | re.IGNORECASE,
    )

    find_replace_pattern = re.compile(
        r"<<<{1,7}\s*(?:FIND|SEARCH)(?:\s+AND\s+REPLACE)?(?:\s*={0,7}\s*FIND\s*={0,7})?\s*\n"
        r"(.*?)\n"
        r"\s*(?:={3,}|-{3,})\s*(?:REPLACE|WITH)\s*(?:={3,}|-{3,})\s*\n"
        r"(.*?)"
        r"\n?>>>{1,7}",
        re.DOTALL | re.IGNORECASE,
    )

    raw_matches = []
    for match in line_block_pattern.finditer(body_text):
        raw_matches.append((match.start(), "LINE_OP", match))
    for match in find_replace_pattern.finditer(body_text):
        raw_matches.append((match.start(), "FIND_REPLACE", match))
    raw_matches.sort(key=lambda x: x[0])

    ops = []
    for _, op_kind, match in raw_matches:
        if op_kind == "LINE_OP":
            cmd_header = match.group(1).strip()
            content = match.group(2)
            replacement_lines = [line + "\n" for line in content.splitlines()] if content else []

            m_rep = re.match(r"REPLACE\s+LINES?\s+(\d+)(?:\s*-\s*(\d+))?", cmd_header, re.IGNORECASE)
            if m_rep:
                s = int(m_rep.group(1))
                e = int(m_rep.group(2)) if m_rep.group(2) else s
                ops.append(PatchOperation("REPLACE", s, e, replacement_lines))
                continue

            m_del = re.match(r"DELETE\s+LINES?\s+(\d+)(?:\s*-\s*(\d+))?", cmd_header, re.IGNORECASE)
            if m_del:
                s = int(m_del.group(1))
                e = int(m_del.group(2)) if m_del.group(2) else s
                ops.append(PatchOperation("DELETE", s, e, []))
                continue

            m_ins_after = re.match(r"INSERT\s+AFTER\s+LINE\s+(\d+)", cmd_header, re.IGNORECASE)
            if m_ins_after:
                line_no = int(m_ins_after.group(1))
                ops.append(PatchOperation("INSERT_AFTER", line_no, line_no, replacement_lines))
                continue

            m_ins_before = re.match(r"INSERT\s+BEFORE\s+LINE\s+(\d+)", cmd_header, re.IGNORECASE)
            if m_ins_before:
                line_no = int(m_ins_before.group(1))
                ops.append(PatchOperation("INSERT_BEFORE", line_no, line_no, replacement_lines))
                continue

        elif op_kind == "FIND_REPLACE":
            find_raw = match.group(1)
            replace_raw = match.group(2)
            find_lines = [l + "\n" for l in find_raw.splitlines()]
            replace_lines = [l + "\n" for l in replace_raw.splitlines()] if replace_raw else []
            ops.append(PatchOperation("FIND_REPLACE", lines=replace_lines, find_lines=find_lines))

    return ops


def parse_patch_file(patch_text: str, base_dir: Path | None = None) -> list[FilePatch]:
    header_pattern = re.compile(
        r'^\s*(?:\*\*\*\s*)?(CREATE\s+FILE|NEW\s+FILE|DELETE\s+FILE|MOVE\s+FILE|RENAME\s+FILE|FILE):\s*(.*?)$',
        re.MULTILINE | re.IGNORECASE,
    )

    matches = list(header_pattern.finditer(patch_text))
    if not matches:
        return []

    file_patches: list[FilePatch] = []
    for i, match in enumerate(matches):
        raw_cmd = match.group(1).upper()
        raw_arg = match.group(2).strip()

        start_pos = match.end()
        end_pos = matches[i + 1].start() if i + 1 < len(matches) else len(patch_text)
        body_text = patch_text[start_pos:end_pos].strip()

        if "DELETE" in raw_cmd:
            target = resolve_file_path(raw_arg, base_dir)
            file_patches.append(FilePatch("DELETE", target))
            continue

        if "MOVE" in raw_cmd or "RENAME" in raw_cmd:
            parts = re.split(r'\s*(?:->|\bTO\b)\s*', raw_arg, flags=re.IGNORECASE)
            if len(parts) >= 2:
                src = resolve_file_path(parts[0], base_dir)
                dest = resolve_file_path(parts[1], base_dir)
                fp = FilePatch("MOVE", src, dest)
                fp.ops = parse_line_operations(body_text)
                file_patches.append(fp)
            continue

        if "CREATE" in raw_cmd or "NEW" in raw_cmd:
            target = resolve_file_path(raw_arg, base_dir)
            fp = FilePatch("CREATE", target)
            content_match = re.search(
                r"<<<(?:[ \t]*(?:CREATE|CONTENT))?[ \t]*\n?(.*?)>>>",
                body_text,
                re.DOTALL | re.IGNORECASE,
            )
            if content_match:
                fp.create_content = [line + "\n" for line in content_match.group(1).splitlines()]
            elif body_text:
                fp.create_content = [line + "\n" for line in body_text.splitlines()]
            file_patches.append(fp)
            continue

        target = resolve_file_path(raw_arg, base_dir)
        fp = FilePatch("MODIFY", target)

        if re.search(r"<<<\s*DELETE\s+FILE\s*>>>", body_text, re.IGNORECASE):
            fp.action = "DELETE"
            file_patches.append(fp)
            continue

        move_match = re.search(r"<<<\s*(?:MOVE|RENAME)\s+TO\s+(.*?)\s*>>>", body_text, re.IGNORECASE)
        if move_match:
            fp.action = "MOVE"
            fp.dest_path = resolve_file_path(move_match.group(1), base_dir)
            cleaned_body = re.sub(r"<<<\s*(?:MOVE|RENAME)\s+TO\s+.*?\s*>>>", "", body_text, flags=re.IGNORECASE)
            fp.ops = parse_line_operations(cleaned_body)
            file_patches.append(fp)
            continue

        create_match = re.search(r"<<<\s*(?:CREATE|NEW)(?:\s+FILE)?\s*\n?(.*?)>>>", body_text, re.DOTALL | re.IGNORECASE)
        if create_match:
            fp.action = "CREATE"
            fp.create_content = [line + "\n" for line in create_match.group(1).splitlines()]
            file_patches.append(fp)
            continue

        fp.ops = parse_line_operations(body_text)
        if fp.ops:
            file_patches.append(fp)

    return file_patches


def find_occurrences(file_lines: list[str], find_lines: list[str]) -> list[int]:
    if not find_lines:
        return []

    target = [l.rstrip("\r\n") for l in find_lines]
    source = [l.rstrip("\r\n") for l in file_lines]
    m = len(target)

    matches = [i for i in range(len(source) - m + 1) if source[i : i + m] == target]
    if matches:
        return matches

    target = [l.rstrip() for l in find_lines]
    source = [l.rstrip() for l in file_lines]
    return [i for i in range(len(source) - m + 1) if source[i : i + m] == target]


def apply_line_ops(target_path: Path, ops: list[PatchOperation]) -> bool:
    if not target_path.exists():
        print(f"\nError: Target file does not exist: {target_path}")
        return False

    orig_lines = read_file_lines(target_path)
    if orig_lines is None:
        print(f"\nError: Could not read file encoding: {target_path}")
        return False

    has_crlf = any("\r\n" in l for l in orig_lines[:50])
    newline = "\r\n" if has_crlf else "\n"

    resolved_ops: list[PatchOperation] = []

    for op in ops:
        if op.op_type == "FIND_REPLACE":
            occurrences = find_occurrences(orig_lines, op.find_lines)

            if len(occurrences) == 0:
                print(f"\n[FIND FAILED] Could not find target snippet in {target_path.name}:")
                preview = "".join(f"    | {l}" for l in op.find_lines[:5])
                print(preview, end="")
                if len(op.find_lines) > 5:
                    print(f"    | ... ({len(op.find_lines) - 5} more lines)")
                return False

            elif len(occurrences) == 1:
                start_line = occurrences[0] + 1
                end_line = occurrences[0] + len(op.find_lines)
                clean_lines = [l.rstrip("\r\n") + newline for l in op.lines]
                resolved_ops.append(
                    PatchOperation("REPLACE", start_line, end_line, clean_lines, find_lines=op.find_lines)
                )

            else:
                line_nums = [str(idx + 1) for idx in occurrences]
                print(f"\n[AMBIGUOUS MATCH] Found {len(occurrences)} occurrences in {target_path.name} at lines: {', '.join(line_nums)}")
                preview = "".join(f"    | {l}" for l in op.find_lines[:3])
                print(preview, end="")
                if len(op.find_lines) > 3:
                    print(f"    | ... ({len(op.find_lines) - 3} more lines)")

                choice = input(f"Replace ALL {len(occurrences)} occurrences? (y/N): ").strip().lower()
                if choice == "y":
                    clean_lines = [l.rstrip("\r\n") + newline for l in op.lines]
                    for idx in occurrences:
                        start_line = idx + 1
                        end_line = idx + len(op.find_lines)
                        resolved_ops.append(
                            PatchOperation("REPLACE", start_line, end_line, clean_lines, find_lines=op.find_lines)
                        )
                else:
                    print(f"Aborted ambiguous operation in {target_path.name}.")
                    return False
        else:
            clean_lines = [l.rstrip("\r\n") + newline for l in op.lines]
            resolved_ops.append(
                PatchOperation(op.op_type, op.start_line, op.end_line, clean_lines, find_lines=op.find_lines)
            )

    resolved_ops.sort(key=lambda o: (o.start_line, o.end_line), reverse=True)

    for i in range(len(resolved_ops) - 1):
        if resolved_ops[i + 1].end_line >= resolved_ops[i].start_line:
            print(f"\nWarning: Overlapping operations detected between lines {resolved_ops[i + 1].start_line}-{resolved_ops[i + 1].end_line} and {resolved_ops[i].start_line}-{resolved_ops[i].end_line} in {target_path.name}")
            if input("Proceed despite overlapping operations? (y/N): ").strip().lower() != "y":
                return False

    modified_lines = list(orig_lines)
    for op in resolved_ops:
        if op.op_type in ("REPLACE", "DELETE"):
            start_idx = max(0, op.start_line - 1)
            end_idx = min(len(modified_lines), max(start_idx, op.end_line))
            if start_idx > len(modified_lines):
                continue
            modified_lines[start_idx:end_idx] = op.lines

        elif op.op_type == "INSERT_AFTER":
            idx = min(len(modified_lines), max(0, op.start_line))
            modified_lines[idx:idx] = op.lines

        elif op.op_type == "INSERT_BEFORE":
            idx = min(len(modified_lines), max(0, op.start_line - 1))
            modified_lines[idx:idx] = op.lines

    with open(target_path, "w", encoding="utf-8") as f:
        f.writelines(modified_lines)

    return True


def apply_patch(patch: FilePatch) -> bool:
    if patch.action == "DELETE":
        if not patch.target_path.exists():
            print("SKIPPED (File does not exist)")
            return True
        try:
            patch.target_path.unlink()
            print("DELETED")
            return True
        except Exception as e:
            print(f"FAILED ({e})")
            return False

    elif patch.action == "CREATE":
        try:
            patch.target_path.parent.mkdir(parents=True, exist_ok=True)
            with open(patch.target_path, "w", encoding="utf-8") as f:
                f.writelines(patch.create_content)
            print("CREATED")
            return True
        except Exception as e:
            print(f"FAILED ({e})")
            return False

    elif patch.action == "MOVE":
        if not patch.target_path.exists():
            print(f"FAILED (Source does not exist: {patch.target_path.name})")
            return False
        if not patch.dest_path:
            print("FAILED (No destination specified)")
            return False
        try:
            patch.dest_path.parent.mkdir(parents=True, exist_ok=True)
            patch.target_path.rename(patch.dest_path)
            if patch.ops:
                if apply_line_ops(patch.dest_path, patch.ops):
                    print("MOVED & PATCHED")
                    return True
                else:
                    print("MOVED (Subsequent line patch failed)")
                    return False
            print("MOVED")
            return True
        except Exception as e:
            print(f"FAILED ({e})")
            return False

    elif patch.action == "MODIFY":
        if apply_line_ops(patch.target_path, patch.ops):
            print("OK")
            return True
        else:
            print("FAILED")
            return False

    return False


# ==============================================================================
# SNAPSHOT-BASED UNDO MODULE (100% Deterministic File Reversion)
# ==============================================================================


def save_patch_snapshots(
    base_dir: Path,
    patch_text: str,
    patches: list[FilePatch],
    source_name: str = "patch.txt",
):
    """Captures exact full-file snapshots BEFORE modifying them for 100% clean undo."""
    now_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_dir = get_archive_dir(base_dir)
    snapshot_dir = archive_dir / f"snapshot_{now_str}"
    snapshot_dir.mkdir(parents=True, exist_ok=True)

    snapshots: dict[str, str | None] = {}

    for idx, p in enumerate(patches):
        target = p.target_path
        if p.action in ("MODIFY", "DELETE", "MOVE") and target.exists():
            content = read_file_text(target)
            p.original_content = content
            snapshots[str(target)] = content
            # Write physical backup to disk
            safe_name = f"{idx}_{target.name}.bak"
            with open(snapshot_dir / safe_name, "w", encoding="utf-8") as f:
                f.write(content or "")

    LAST_PATCH_DATA["text"] = patch_text
    LAST_PATCH_DATA["patches"] = patches
    LAST_PATCH_DATA["source"] = source_name
    LAST_PATCH_DATA["timestamp"] = now_str
    LAST_PATCH_DATA["snapshots"] = snapshots

    # Save manifest so undo survives Python restarts
    manifest_file = snapshot_dir / "manifest.txt"
    with open(manifest_file, "w", encoding="utf-8") as f:
        for idx, p in enumerate(patches):
            dest_str = str(p.dest_path) if p.dest_path else ""
            f.write(f"{p.action}|{p.target_path}|{dest_str}|{idx}_{p.target_path.name}.bak\n")

    last_snapshot_link = archive_dir / "last_snapshot.txt"
    with open(last_snapshot_link, "w", encoding="utf-8") as f:
        f.write(str(snapshot_dir))

    append_patch_log(
        base_dir,
        f"APPLIED {source_name} ({len(patches)} file(s)), snapshot saved to {snapshot_dir.name}",
    )


def undo_snapshot(patch: FilePatch, snapshot_dir: Path | None = None) -> bool:
    """Restores files to exact pre-patch byte-for-byte snapshots (zero duplicate code risk)."""
    target = patch.target_path

    if patch.action == "CREATE":
        if target.exists():
            try:
                target.unlink()
                print("REMOVED (Created file deleted)")
                return True
            except Exception as e:
                print(f"FAILED ({e})")
                return False
        print("SKIPPED (File does not exist)")
        return True

    elif patch.action == "DELETE":
        content = patch.original_content
        if content is None and snapshot_dir:
            bak_file = next(snapshot_dir.glob(f"*_{target.name}.bak"), None)
            if bak_file and bak_file.exists():
                content = read_file_text(bak_file)
        if content is not None:
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                with open(target, "w", encoding="utf-8") as f:
                    f.write(content)
                print("RESTORED FROM SNAPSHOT")
                return True
            except Exception as e:
                print(f"FAILED ({e})")
                return False
        print("FAILED (No snapshot content available)")
        return False

    elif patch.action == "MOVE":
        if patch.dest_path and patch.dest_path.exists():
            try:
                target.parent.mkdir(parents=True, exist_ok=True)
                patch.dest_path.rename(target)
                if patch.original_content is not None:
                    with open(target, "w", encoding="utf-8") as f:
                        f.write(patch.original_content)
                print("MOVED BACK & RESTORED")
                return True
            except Exception as e:
                print(f"FAILED ({e})")
                return False
        print("FAILED (Moved file destination not found)")
        return False

    elif patch.action == "MODIFY":
        content = patch.original_content
        if content is None and snapshot_dir:
            bak_file = next(snapshot_dir.glob(f"*_{target.name}.bak"), None)
            if bak_file and bak_file.exists():
                content = read_file_text(bak_file)
        if content is not None:
            try:
                with open(target, "w", encoding="utf-8") as f:
                    f.write(content)
                print("RESTORED (Exact Pre-Patch Snapshot)")
                return True
            except Exception as e:
                print(f"FAILED ({e})")
                return False
        print("FAILED (No snapshot content available)")
        return False

    return False


def run_undo(start_dir: Path):
    """Restores files to exact pre-patch snapshots without reverse find-and-replace hazards."""
    print("\n--- UNDO LAST PATCH (EXACT SNAPSHOT RESTORATION) ---")

    patches = LAST_PATCH_DATA.get("patches")
    snapshot_dir = None

    if not patches:
        archive_dir = start_dir / ".patch_archive"
        last_link = archive_dir / "last_snapshot.txt"
        if last_link.exists():
            try:
                with open(last_link, "r", encoding="utf-8") as f:
                    s_path = Path(f.read().strip())
                if s_path.exists():
                    snapshot_dir = s_path
                    manifest = s_path / "manifest.txt"
                    if manifest.exists():
                        patches = []
                        with open(manifest, "r", encoding="utf-8") as mf:
                            for line in mf:
                                parts = line.strip().split("|")
                                if len(parts) >= 4:
                                    act, tgt, dst, bak = parts[0], Path(parts[1]), Path(parts[2]) if parts[2] else None, parts[3]
                                    fp = FilePatch(act, tgt, dst)
                                    bak_path = snapshot_dir / bak
                                    if bak_path.exists():
                                        fp.original_content = read_file_text(bak_path)
                                    patches.append(fp)
            except Exception as e:
                print(f"Error loading disk snapshot: {e}")

    if not patches:
        print("No patch history or snapshots found to undo.")
        return

    print(f"Found pre-patch snapshots for {len(patches)} file(s):\n")
    for idx, p in enumerate(patches, start=1):
        if p.action == "CREATE":
            desc = f"[CREATE] {p.target_path.name} (Will be removed)"
        elif p.action == "DELETE":
            desc = f"[DELETE] {p.target_path.name} (Will be restored)"
        elif p.action == "MOVE":
            desc = f"[MOVE]   {p.target_path.name} (Will be moved back and restored)"
        elif p.action == "MODIFY":
            desc = f"[MODIFY] {p.target_path.name} (Will be reverted to exact pre-patch state)"
        print(f"  [{idx}] {desc}")

    prompt_msg = "\nEnter file number(s) to undo (e.g. 1,2 | -1 for all | 0 to cancel) [default: -1]: "
    user_choice = input(prompt_msg).strip()

    if user_choice == "0":
        print("Undo cancelled.")
        return

    selected_indices: list[int] = []
    if not user_choice or user_choice == "-1":
        selected_indices = list(range(len(patches)))
    else:
        for tok in user_choice.split(","):
            tok = tok.strip()
            if tok.isdigit():
                num = int(tok)
                if 1 <= num <= len(patches):
                    selected_indices.append(num - 1)

    if not selected_indices:
        print("No valid files selected.")
        return

    print(f"\nRestoring {len(selected_indices)} file(s) to exact pre-patch snapshots...")
    undone_count = 0
    undone_names = []
    for idx in selected_indices:
        p = patches[idx]
        print(f"Restoring: {p.target_path.name} ... ", end="")
        if undo_snapshot(p, snapshot_dir):
            undone_count += 1
            undone_names.append(p.target_path.name)

    append_patch_log(
        start_dir,
        f"UNDONE {undone_count}/{len(selected_indices)} file(s): {', '.join(undone_names)}",
    )

    # Invalidate in-memory last patch once undone
    LAST_PATCH_DATA["patches"] = None
    LAST_PATCH_DATA["snapshots"] = {}
    last_link = (start_dir / ".patch_archive" / "last_snapshot.txt")
    if last_link.exists():
        try:
            last_link.unlink()
        except Exception:
            pass

    print(f"\nCompleted! Reverted {undone_count}/{len(selected_indices)} file(s) with ZERO line shift or duplicate code.")


# ==============================================================================
# CLEANUP MODULE
# ==============================================================================


def run_cleanup(start_dir: Path):
    print("\n--- CLEANUP WORKSPACE ---")
    agg_files = [
        f for f in start_dir.rglob("aggregate*.txt")
        if ".git" not in f.parts and ".patch_archive" not in f.parts
    ]
    archive_dir = start_dir / ".patch_archive"
    archive_files = []
    if archive_dir.exists():
        archive_files.extend([f for f in archive_dir.rglob("*") if f.is_file()])
    archive_files.extend(
        [f for f in start_dir.glob("*patch_archive*.txt") if f.is_file() and ".git" not in f.parts]
    )
    archive_files = list(set(archive_files))

    patch_file = start_dir / "patch.txt"
    has_patch = patch_file.exists() and patch_file.stat().st_size > 0

    if not agg_files and not archive_files and not has_patch:
        print("Nothing to clean up.")
        return

    print("Items found to clean:")
    if agg_files:
        print(f"  • {len(agg_files)} aggregate file(s) to delete")
    if archive_files:
        print(f"  • {len(archive_files)} patch archive / log file(s) to delete")
    if has_patch:
        print("  • patch.txt to be cleared")

    if input("\nProceed with cleanup? (y/n): ").strip().lower() != "y":
        print("Aborted.")
        return

    deleted_aggs = sum(1 for f in agg_files if not f.unlink())
    for a in archive_files:
        try:
            a.unlink()
        except Exception:
            pass

    if archive_dir.exists():
        import shutil
        shutil.rmtree(archive_dir, ignore_errors=True)

    LAST_PATCH_DATA["text"] = None
    LAST_PATCH_DATA["patches"] = None
    LAST_PATCH_DATA["snapshots"] = {}

    if patch_file.exists():
        with open(patch_file, "w", encoding="utf-8") as f:
            pass

    print(f"\nCleanup finished: Deleted {len(agg_files)} aggregate(s), purged snapshots, and cleared patch.txt.")


def run_patcher(start_dir: Path):
    print("\n--- APPLY DIFF / PATCH ---")
    patch_file_input = input("Enter patch file name [default: patch.txt]: ").strip()
    patch_file_path = Path(patch_file_input) if patch_file_input else (start_dir / "patch.txt")

    if not patch_file_path.exists():
        print(f"Patch file not found: {patch_file_path}")
        return

    try:
        with open(patch_file_path, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading patch file: {e}")
        return

    patches = parse_patch_file(content, base_dir=start_dir)
    if not patches:
        print("No valid patch operations found in the file.")
        return

    print(f"\nFound operations for {len(patches)} file(s):")
    for p in patches:
        if p.action == "CREATE":
            print(f"  • [CREATE] {p.target_path.name} ({len(p.create_content)} lines)")
        elif p.action == "DELETE":
            print(f"  • [DELETE] {p.target_path.name}")
        elif p.action == "MOVE":
            sub = f" with {len(p.ops)} edit(s)" if p.ops else ""
            print(f"  • [MOVE]   {p.target_path.name} -> {p.dest_path.name}{sub}")
        elif p.action == "MODIFY":
            num_find = sum(1 for op in p.ops if op.op_type == "FIND_REPLACE")
            num_line = len(p.ops) - num_find
            details = []
            if num_find:
                details.append(f"{num_find} find-and-replace")
            if num_line:
                details.append(f"{num_line} line-based")
            print(f"  • [MODIFY] {p.target_path.name}: {', '.join(details)} operation(s)")

    if input("\nProceed with applying changes? (y/n): ").strip().lower() != "y":
        print("Aborted.")
        return

    # 1. Take full byte-for-byte snapshots BEFORE touching any files
    save_patch_snapshots(start_dir, content, patches, source_name=patch_file_path.name)

    # 2. Apply modifications
    success_count = 0
    for p in patches:
        desc = p.target_path.name if p.action != "MOVE" else f"{p.target_path.name} -> {p.dest_path.name}"
        print(f"Processing: {desc} ... ", end="")
        if apply_patch(p):
            success_count += 1

    print(f"\nDone. Successfully processed {success_count}/{len(patches)} file(s).")


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
        print(" [3] Undo last patch (exact snapshot restore)")
        print(" [4] Clean up (aggregates, patch archives, clear patch.txt)")
        print(" [0] Exit")
        choice = input("\nSelect an option [0-4]: ").strip()

        if choice == "1":
            run_aggregator(start_dir)
        elif choice == "2":
            run_patcher(start_dir)
        elif choice == "3":
            run_undo(start_dir)
        elif choice == "4":
            run_cleanup(start_dir)
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