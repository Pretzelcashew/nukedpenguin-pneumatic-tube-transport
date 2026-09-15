import argparse
import asyncio
from datetime import datetime
import os
from pathlib import Path
import re
import sys
from typing import Any

# ==============================================================================
# FACTORIO BUILT-IN LIBRARIES & STAGES
# ==============================================================================

FACTORIO_BUILTIN_LUALIBS = {
    "util",
    "mod-gui",
    "noise",
    "collision-mask-util",
    "circuit-connector-sprites",
    "factorio-color",
    "story",
    "canvas",
}

FACTORIO_STAGES = {
    "settings": [
        "settings.lua",
        "settings-updates.lua",
        "settings-final-fixes.lua",
    ],
    "data": [
        "data.lua",
        "data-updates.lua",
        "data-final-fixes.lua",
    ],
    "control": [
        "control.lua",
    ],
}

EXCLUDED_DIR_NAMES = {
    ".git",
    ".github",
    ".gitlab",
    ".patch_archive",
    ".vscode",
    ".idea",
    "__pycache__",
    "node_modules",
    "doc",
    "docs",
    "documentation",
    "wiki",
    "guides",
    "manual",
    "build",
    "dist",
    "releases",
    "archive",
    "backup",
    "backups",
    "temp",
    "tmp",
}

LUA_MULTI_COMMENT_PATTERN = re.compile(r"--\[(=*)\[.*?\]\1\]", re.DOTALL)
LUA_SINGLE_COMMENT_PATTERN = re.compile(r"--[^\r\n]*")
REQUIRE_PATTERN = re.compile(
    r'\brequire\s*(?:\(\s*["\']([^"\']+)["\']\s*\)|["\']([^"\']+)["\'])'
)


# ==============================================================================
# METADATA & PARSING HELPERS
# ==============================================================================


def read_info_json(mod_root: Path) -> dict[str, Any]:
    info_path = mod_root / "info.json"
    if not info_path.exists():
        return {
            "name": mod_root.name,
            "version": "Unknown",
            "title": mod_root.name,
            "author": "Unknown",
            "factorio_version": "Unknown",
        }

    import json
    for enc in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            with open(info_path, "r", encoding=enc) as f:
                return json.load(f)
        except Exception:
            continue

    return {
        "name": mod_root.name,
        "version": "Unknown",
        "title": mod_root.name,
        "author": "Unknown",
        "factorio_version": "Unknown",
    }


def strip_lua_comments(code: str) -> str:
    cleaned = LUA_MULTI_COMMENT_PATTERN.sub("", code)
    return LUA_SINGLE_COMMENT_PATTERN.sub("", cleaned)


def parse_requires_from_code(code: str) -> list[str]:
    cleaned = strip_lua_comments(code)
    matches = REQUIRE_PATTERN.findall(cleaned)
    results: list[str] = []
    for m in matches:
        req = m[0] if m[0] else m[1]
        req = req.strip()
        if req and req not in results:
            results.append(req)
    return results


# ==============================================================================
# RESOLVER
# ==============================================================================


class RequireResolver:
    def __init__(self, mod_root: Path, mod_name: str):
        self.mod_root = mod_root.resolve()
        self.mod_name = mod_name
        self.lua_files: dict[Path, list[str]] = {}
        self.all_relative_lua_files: set[str] = set()

    def resolve_require(
        self, req_str: str, current_file: Path
    ) -> tuple[str, Path | str | None]:
        clean_req = req_str.strip()
        if clean_req.endswith(".lua"):
            clean_req = clean_req[:-4]

        if clean_req.lower() in FACTORIO_BUILTIN_LUALIBS:
            return "BUILTIN", clean_req

        mod_match = re.match(r"^__([a-zA-Z0-9_\-]+)__[./\\]?(.*)$", clean_req)
        if mod_match:
            target_mod = mod_match.group(1)
            inner_path = mod_match.group(2)

            if target_mod != self.mod_name:
                return f"EXTERNAL:{target_mod}", clean_req
            else:
                clean_req = inner_path

        path_variants = [
            clean_req.replace(".", "/"),
            clean_req,
        ]

        current_dir = current_file.parent

        for p_var in path_variants:
            candidates = [
                current_dir / f"{p_var}.lua",
                current_dir / p_var / "init.lua",
                self.mod_root / f"{p_var}.lua",
                self.mod_root / p_var / "init.lua",
            ]
            for candidate in candidates:
                if candidate.is_file() and candidate.suffix.lower() == ".lua":
                    return "INTERNAL", candidate.resolve()

        return "UNRESOLVED", clean_req


async def scan_single_file(file_path: Path) -> tuple[Path, list[str]]:
    def _read():
        for enc in ("utf-8", "utf-8-sig", "latin-1"):
            try:
                with open(file_path, "r", encoding=enc) as f:
                    return parse_requires_from_code(f.read())
            except Exception:
                continue
        return []

    reqs = await asyncio.to_thread(_read)
    return file_path.resolve(), reqs


async def scan_codebase_async(
    mod_root: Path, mod_name: str, status_dict: dict
) -> RequireResolver:
    resolver = RequireResolver(mod_root, mod_name)
    lua_paths: list[Path] = []

    status_dict["msg"] = "Scanning active .lua files..."
    for root, dirs, files in os.walk(mod_root):
        dirs[:] = [
            d
            for d in dirs
            if not d.startswith(".")
            and d.lower() not in EXCLUDED_DIR_NAMES
            and not re.search(r"_\d+\.\d+\.\d+$", d)
        ]

        for f in files:
            p = Path(f)
            if p.suffix.lower() == ".lua" and not f.startswith("."):
                lua_paths.append((Path(root) / f).resolve())

    total_files = len(lua_paths)
    status_dict["msg"] = f"Found {total_files} .lua files. Analyzing graph..."

    chunk_size = 50
    for i in range(0, total_files, chunk_size):
        chunk = lua_paths[i : i + chunk_size]
        tasks = [scan_single_file(p) for p in chunk]
        results = await asyncio.gather(*tasks)

        for p, reqs in results:
            resolver.lua_files[p] = reqs
            try:
                rel = p.relative_to(resolver.mod_root).as_posix()
                resolver.all_relative_lua_files.add(rel)
            except ValueError:
                pass

    return resolver


# ==============================================================================
# COMPACT GRAPH & HAZARD GENERATOR
# ==============================================================================


def clean_rel(path_str: str) -> str:
    """Strips redundant .lua extensions for token efficiency."""
    return path_str[:-4] if path_str.endswith(".lua") else path_str


def detect_cycles(adj_list: dict[str, list[str]]) -> list[list[str]]:
    cycles: list[list[str]] = []
    visited: set[str] = set()
    rec_stack: list[str] = []

    def dfs(node: str):
        visited.add(node)
        rec_stack.append(node)

        for neighbor in adj_list.get(node, []):
            if neighbor not in visited:
                dfs(neighbor)
            elif neighbor in rec_stack:
                cycle_start_idx = rec_stack.index(neighbor)
                cycle = rec_stack[cycle_start_idx:] + [neighbor]
                sorted_cycle = tuple(sorted(cycle[:-1]))
                if not any(tuple(sorted(c[:-1])) == sorted_cycle for c in cycles):
                    cycles.append(cycle)

        rec_stack.pop()

    for n in list(adj_list.keys()):
        if n not in visited:
            dfs(n)

    return cycles


def generate_token_dense_markdown(
    mod_root: Path, resolver: RequireResolver, mod_info: dict[str, Any]
) -> tuple[str, dict[str, Any]]:
    forward_graph: dict[str, list[str]] = {}
    reverse_counts: dict[str, int] = {
        clean_rel(rel): 0 for rel in resolver.all_relative_lua_files
    }
    external_deps: set[str] = set()
    builtins_used: set[str] = set()
    unresolved: set[str] = set()

    for file_p, raw_reqs in resolver.lua_files.items():
        src = clean_rel(file_p.relative_to(mod_root).as_posix())
        forward_graph[src] = []

        for r in raw_reqs:
            cat, resolved = resolver.resolve_require(r, file_p)

            if cat == "INTERNAL" and isinstance(resolved, Path):
                dst = clean_rel(resolved.relative_to(mod_root).as_posix())
                if dst not in forward_graph[src]:
                    forward_graph[src].append(dst)
                if dst in reverse_counts:
                    reverse_counts[dst] += 1
            elif cat == "BUILTIN":
                builtins_used.add(str(resolved))
            elif cat.startswith("EXTERNAL"):
                external_deps.add(cat.split(":")[1])
            else:
                unresolved.add(str(resolved))

    cycles = detect_cycles(forward_graph)

    # Detect entry points
    entry_points = {}
    for stage, stage_files in FACTORIO_STAGES.items():
        present = [
            clean_rel(sf) for sf in stage_files if (mod_root / sf).is_file()
        ]
        if present:
            entry_points[stage] = present

    # High blast-radius modules (depended on by 3 or more files)
    top_dependents = sorted(
        [(f, count) for f, count in reverse_counts.items() if count >= 3],
        key=lambda x: x[1],
        reverse=True,
    )

    # Detect dead files / orphans
    all_top_levels = {
        clean_rel(sf) for files in FACTORIO_STAGES.values() for sf in files
    }
    orphans = sorted(
        [
            f
            for f, count in reverse_counts.items()
            if count == 0 and f not in all_top_levels
        ]
    )

    # Build token-dense Markdown
    lines: list[str] = []
    lines.append("# AI Architectural Manifest")
    lines.append(f"- **Mod**: {mod_info.get('name', mod_root.name)} (v{mod_info.get('version', 'Unknown')})")
    lines.append(f"- **Factorio Version**: {mod_info.get('factorio_version', 'Unknown')}")
    lines.append(f"- **Total Active Lua Files**: {len(resolver.lua_files)}")

    # Entry points
    lines.append("\n## Entry Points")
    for stage, files in entry_points.items():
        lines.append(f"- **{stage}**: {', '.join(files)}")

    # Hazards
    lines.append("\n## Hazards & Warnings")
    if cycles:
        lines.append("- **Circular Dependency Loops**:")
        for c in cycles:
            lines.append(f"  - `{' <-> '.join(c)}`")
    else:
        lines.append("- **Circular Dependency Loops**: None")

    orphan_str = ", ".join(orphans) if orphans else "None"
    lines.append(f"- **Orphaned / Dead Files**: {orphan_str}")

    if unresolved:
        lines.append(f"- **Unresolved Requires**: {', '.join(sorted(unresolved))}")
    if external_deps:
        lines.append(f"- **External Mods**: {', '.join(sorted(external_deps))}")
    if builtins_used:
        lines.append(f"- **Factorio Built-in Libraries**: {', '.join(sorted(builtins_used))}")

    # Blast-Radius index
    lines.append("\n## Blast Radius (Files with >= 3 Dependents)")
    for f, count in top_dependents:
        lines.append(f"- `{f}`: **{count}** dependents")

    # Compact Graph: File -> Dependencies
    lines.append("\n## Dependency Graph (`file`: [requires...])")
    for src in sorted(forward_graph.keys()):
        deps = forward_graph[src]
        if deps:
            lines.append(f"- `{src}`: [{', '.join(deps)}]")
        else:
            lines.append(f"- `{src}`: []")

    output_str = "\n".join(lines) + "\n"

    stats = {
        "mod_name": mod_info.get("name", mod_root.name),
        "version": mod_info.get("version", "Unknown"),
        "total_files": len(resolver.lua_files),
        "cycles": len(cycles),
        "orphans": len(orphans),
    }

    return output_str, stats


# ==============================================================================
# CLI
# ==============================================================================


async def spinner_animation(status: dict[str, Any]):
    symbols = ["|", "/", "-", "\\"]
    idx = 0
    while not status.get("done", False):
        msg = status.get("msg", "Processing...")
        sys.stdout.write(f"\r[{symbols[idx % len(symbols)]}] {msg}")
        sys.stdout.flush()
        idx += 1
        await asyncio.sleep(0.08)
    sys.stdout.write("\r" + " " * 80 + "\r")
    sys.stdout.flush()


async def async_main():
    parser = argparse.ArgumentParser(
        description="Token-Dense Markdown AI Require Graph Generator"
    )
    parser.add_argument(
        "dir",
        nargs="?",
        default=None,
        help="Path to the Factorio mod root directory",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="require_graph.md",
        help="Output filename (default: require_graph.md, also supports .txt)",
    )

    args = parser.parse_args()

    print("\n" + "=" * 65)
    print(" FACTORIO AI ARCHITECTURE SCANNER (.MD / .TXT READY)")
    print("=" * 65)

    if args.dir:
        mod_root = Path(args.dir).resolve()
    else:
        user_input = input(
            "Enter path to Factorio mod directory [default: current dir]: "
        ).strip()
        mod_root = Path(user_input).resolve() if user_input else Path.cwd().resolve()

    if not mod_root.exists() or not mod_root.is_dir():
        print(f"\nError: Directory does not exist: {mod_root}")
        return

    mod_info = read_info_json(mod_root)
    mod_name = mod_info.get("name", mod_root.name)
    mod_version = mod_info.get("version", "Unknown")

    print(f"\nTarget Mod: {mod_name} (v{mod_version})")
    print(f"Directory : {mod_root}")
    print(f"Output    : {args.output}\n")

    status = {"done": False, "msg": "Initializing..."}
    spinner = asyncio.create_task(spinner_animation(status))

    try:
        resolver = await scan_codebase_async(mod_root, mod_name, status)
        status["msg"] = "Generating drag-and-drop ready markdown..."
        await asyncio.sleep(0.05)

        md_text, stats = generate_token_dense_markdown(mod_root, resolver, mod_info)

        out_path = mod_root / args.output
        with open(out_path, "w", encoding="ascii") as out:
            out.write(md_text)

        out_size_kb = out_path.stat().st_size / 1024
        est_tokens = int(len(md_text) / 4)

    finally:
        status["done"] = True
        await spinner

    print("[OK] Manifest generated successfully!\n")
    print(f"  - Mod Name & Version : {mod_name} v{mod_version}")
    print(f"  - Active Lua Files   : {stats['total_files']}")
    print(f"  - Circular Loops     : {stats['cycles']}")
    print(f"  - Orphan Files       : {stats['orphans']}")
    print(f"  - Estimated Size     : {out_size_kb:.1f} KB (~{est_tokens} tokens)")
    print(f"\nSaved to: {out_path.name} (drag-and-drop ready)")


def main():
    try:
        asyncio.run(async_main())
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
    except Exception as e:
        print(f"\nAn error occurred: {e}")
    finally:
        input("\nPress Enter to close...")


if __name__ == "__main__":
    main()