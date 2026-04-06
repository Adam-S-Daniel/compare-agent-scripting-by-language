"""
Multi-file recursive search-and-replace tool.

Features:
  - Glob-pattern file discovery (recursive)
  - Regex search with match context
  - Preview mode (no modifications)
  - Backup creation before modifying files
  - Summary report of all changes (file, line, old text, new text)

TDD approach: tests in test_search_replace.py were written before this module.
Each function implements the minimum code needed to pass its corresponding tests.
"""

import os
import re
import shutil
from pathlib import Path
from typing import List, Dict, Any


# ---------------------------------------------------------------------------
# 1. find_files
# ---------------------------------------------------------------------------

def find_files(root: str, glob_pattern: str) -> List[str]:
    """
    Recursively find all files under *root* that match *glob_pattern*.

    Returns a sorted list of absolute paths so results are deterministic.
    Uses Path.glob() which handles '**' wildcard patterns natively.
    """
    root_path = Path(root).resolve()
    # Path.glob handles '**' recursion natively, e.g. '**/*.py'
    matches = [str(p.resolve()) for p in root_path.glob(glob_pattern) if p.is_file()]
    return sorted(matches)


# ---------------------------------------------------------------------------
# 2. find_matches
# ---------------------------------------------------------------------------

def find_matches(file_path: str, pattern: str) -> List[Dict[str, Any]]:
    """
    Search *file_path* for *pattern* (a regex string).

    Returns a list of match dicts, one per match occurrence:
      {
        "file":    absolute path,
        "line":    1-based line number,
        "content": full line text (stripped of newline),
        "start":   start column in the line,
        "end":     end column in the line,
      }

    Errors (missing file, bad regex) are raised so callers can handle them.
    """
    regex = re.compile(pattern)
    results: List[Dict[str, Any]] = []

    try:
        lines = Path(file_path).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        raise OSError(f"Cannot read '{file_path}': {exc}") from exc

    for lineno, line in enumerate(lines, start=1):
        for match in regex.finditer(line):
            results.append(
                {
                    "file": str(Path(file_path).resolve()),
                    "line": lineno,
                    "content": line,
                    "start": match.start(),
                    "end": match.end(),
                }
            )

    return results


# ---------------------------------------------------------------------------
# 3. preview_matches
# ---------------------------------------------------------------------------

def preview_matches(
    file_path: str,
    pattern: str,
    replacement: str,
    context_lines: int = 2,
) -> List[Dict[str, Any]]:
    """
    Return a preview of what would change in *file_path* if *pattern* were
    replaced by *replacement*.  The file is NOT modified.

    Each entry:
      {
        "file":     absolute path,
        "line":     1-based line number,
        "old_text": original line text,
        "new_text": line text after replacement,
        "context":  list of surrounding lines (±context_lines),
      }
    """
    regex = re.compile(pattern)
    entries: List[Dict[str, Any]] = []

    try:
        lines = Path(file_path).read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        raise OSError(f"Cannot read '{file_path}': {exc}") from exc

    abs_path = str(Path(file_path).resolve())

    for lineno, line in enumerate(lines, start=1):
        if regex.search(line):
            new_line = regex.sub(replacement, line)
            # Collect surrounding context
            ctx_start = max(0, lineno - 1 - context_lines)
            ctx_end = min(len(lines), lineno - 1 + context_lines + 1)
            context = [
                f"{i + 1}: {lines[i]}" for i in range(ctx_start, ctx_end)
            ]
            entries.append(
                {
                    "file": abs_path,
                    "line": lineno,
                    "old_text": line,
                    "new_text": new_line,
                    "context": context,
                }
            )

    return entries


# ---------------------------------------------------------------------------
# 4. create_backup
# ---------------------------------------------------------------------------

def create_backup(file_path: str) -> str:
    """
    Copy *file_path* to *file_path*.bak in the same directory.

    If a backup already exists it is overwritten (idempotent).
    Returns the absolute path of the backup file.
    """
    src = Path(file_path).resolve()
    backup = src.with_suffix(src.suffix + ".bak")
    shutil.copy2(str(src), str(backup))
    return str(backup)


# ---------------------------------------------------------------------------
# 5. perform_replace
# ---------------------------------------------------------------------------

def perform_replace(
    file_path: str,
    pattern: str,
    replacement: str,
) -> List[Dict[str, Any]]:
    """
    Apply regex search-and-replace on *file_path* in-place.

    Returns a list of change dicts for every line that was modified:
      {
        "file":     absolute path,
        "line":     1-based line number,
        "old_text": original line text,
        "new_text": line text after replacement,
      }

    If no matches are found the file is not written and an empty list is returned.
    """
    regex = re.compile(pattern)
    abs_path = str(Path(file_path).resolve())

    try:
        original_lines = Path(file_path).read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    except OSError as exc:
        raise OSError(f"Cannot read '{file_path}': {exc}") from exc

    changes: List[Dict[str, Any]] = []
    new_lines: List[str] = []

    for lineno, line in enumerate(original_lines, start=1):
        # Strip trailing newline for matching, restore it afterward
        stripped = line.rstrip("\n\r")
        if regex.search(stripped):
            new_stripped = regex.sub(replacement, stripped)
            # Reconstruct the line with its original line ending
            ending = line[len(stripped):]
            new_lines.append(new_stripped + ending)
            changes.append(
                {
                    "file": abs_path,
                    "line": lineno,
                    "old_text": stripped,
                    "new_text": new_stripped,
                }
            )
        else:
            new_lines.append(line)

    if changes:
        Path(file_path).write_text("".join(new_lines), encoding="utf-8")

    return changes


# ---------------------------------------------------------------------------
# 6. generate_report
# ---------------------------------------------------------------------------

def generate_report(changes: List[Dict[str, Any]]) -> str:
    """
    Build a human-readable summary report from a list of change dicts.

    The report groups changes by file and shows:
      - file path
      - line number
      - old text  →  new text

    A total change count is included at the end.
    """
    if not changes:
        return "No changes made (0 replacements)."

    # Group by file
    by_file: Dict[str, List[Dict[str, Any]]] = {}
    for c in changes:
        by_file.setdefault(c["file"], []).append(c)

    lines: List[str] = ["=" * 60, "Search-and-Replace Report", "=" * 60, ""]

    for file_path, file_changes in sorted(by_file.items()):
        lines.append(f"File: {file_path}  ({len(file_changes)} change(s))")
        lines.append("-" * 60)
        for c in file_changes:
            lines.append(f"  Line {c['line']}:")
            lines.append(f"    - {c['old_text']}")
            lines.append(f"    + {c['new_text']}")
        lines.append("")

    total = len(changes)
    lines += ["=" * 60, f"Total replacements: {total}", "=" * 60]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 7. run_search_replace  (integration entry point)
# ---------------------------------------------------------------------------

def run_search_replace(
    root: str,
    glob_pattern: str,
    pattern: str,
    replacement: str,
    dry_run: bool = True,
) -> Dict[str, Any]:
    """
    Orchestrate the full search-and-replace workflow.

    Args:
        root:         Base directory to search from.
        glob_pattern: Glob pattern for file selection (e.g. '**/*.py').
        pattern:      Regex pattern to search for.
        replacement:  Replacement string (may contain back-references like \\1).
        dry_run:      If True, show preview without modifying any file.

    Returns a dict:
      {
        "files_searched": int,
        "preview":  [preview entries] (always populated),
        "changes":  [change records]  (populated only on live run),
        "report":   str               (summary report),
      }
    """
    files = find_files(root, glob_pattern)

    all_previews: List[Dict[str, Any]] = []
    all_changes: List[Dict[str, Any]] = []

    for file_path in files:
        previews = preview_matches(file_path, pattern, replacement)
        all_previews.extend(previews)

        if not dry_run and previews:
            # Create backup before modifying
            try:
                create_backup(file_path)
            except OSError as exc:
                print(f"Warning: could not back up '{file_path}': {exc}")

            changes = perform_replace(file_path, pattern, replacement)
            all_changes.extend(changes)

    report = generate_report(all_changes if not dry_run else [])
    if dry_run and all_previews:
        # For dry-run, build a preview report instead
        report = _preview_report(all_previews)

    return {
        "files_searched": len(files),
        "preview": all_previews,
        "changes": all_changes,
        "report": report,
    }


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _preview_report(previews: List[Dict[str, Any]]) -> str:
    """Build a dry-run preview report (no changes applied)."""
    if not previews:
        return "No matches found (0 replacements would be made)."

    by_file: Dict[str, List[Dict[str, Any]]] = {}
    for p in previews:
        by_file.setdefault(p["file"], []).append(p)

    lines: List[str] = ["=" * 60, "Preview Report (DRY RUN — no files modified)", "=" * 60, ""]

    for file_path, file_previews in sorted(by_file.items()):
        lines.append(f"File: {file_path}  ({len(file_previews)} match(es))")
        lines.append("-" * 60)
        for pv in file_previews:
            lines.append(f"  Line {pv['line']}:")
            lines.append(f"    - {pv['old_text']}")
            lines.append(f"    + {pv['new_text']}")
        lines.append("")

    total = len(previews)
    lines += ["=" * 60, f"Would replace: {total} occurrence(s)", "=" * 60]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point (for manual use)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse
    import sys

    parser = argparse.ArgumentParser(
        description="Recursive multi-file regex search-and-replace."
    )
    parser.add_argument("root", help="Root directory to search")
    parser.add_argument("glob", help="Glob pattern (e.g. '**/*.py')")
    parser.add_argument("pattern", help="Regex pattern to search for")
    parser.add_argument("replacement", help="Replacement string")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually apply changes (default: dry-run preview only)",
    )
    args = parser.parse_args()

    result = run_search_replace(
        root=args.root,
        glob_pattern=args.glob,
        pattern=args.pattern,
        replacement=args.replacement,
        dry_run=not args.apply,
    )

    print(result["report"])
    if not args.apply:
        print(f"\n(Pass --apply to perform replacements in {result['files_searched']} file(s))")
    else:
        print(f"\n{len(result['changes'])} replacement(s) made across {result['files_searched']} file(s).")
    sys.exit(0)
