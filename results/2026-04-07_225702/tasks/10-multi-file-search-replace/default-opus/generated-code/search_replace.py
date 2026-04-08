"""
Multi-file search-and-replace tool.

Features:
  - Recursive glob-based file matching
  - Regex search with preview mode (no modifications)
  - Backup creation before modifying files
  - Summary report of all changes (file, line, old text, new text)
"""

import glob
import os
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class ChangeRecord:
    """One matched (or replaced) line in a file."""
    file: str           # absolute path to the file
    line_number: int    # 1-based line number
    old_text: str       # original line content (stripped of newline)
    new_text: Optional[str] = None  # replacement text, None for find-only


def _validate_root(root: Path) -> None:
    """Raise FileNotFoundError if root doesn't exist."""
    if not root.exists():
        raise FileNotFoundError(f"Root directory does not exist: {root}")


def _iter_matching_files(root: Path, pattern: str):
    """Yield sorted file paths under *root* matching *pattern*."""
    for filepath in sorted(root.rglob(pattern)):
        if filepath.is_file():
            yield filepath


def find_matches(
    root: str | Path,
    pattern: str,
    regex: str,
) -> list[ChangeRecord]:
    """Find all lines matching *regex* in files under *root* that match *pattern*.

    Returns ChangeRecord objects with new_text=None (find-only mode).
    """
    root = Path(root)
    _validate_root(root)
    compiled = re.compile(regex)
    records: list[ChangeRecord] = []

    for filepath in _iter_matching_files(root, pattern):
        try:
            lines = filepath.read_text().splitlines(keepends=True)
        except (OSError, UnicodeDecodeError):
            continue
        for idx, line in enumerate(lines, start=1):
            if compiled.search(line):
                records.append(ChangeRecord(
                    file=str(filepath),
                    line_number=idx,
                    old_text=line.rstrip("\n"),
                ))
    return records


def preview(
    root: str | Path,
    pattern: str,
    regex: str,
    replacement: str,
    context_lines: int = 1,
) -> str:
    """Return a human-readable preview of what *would* change, without modifying files.

    Shows each match with surrounding context, the original line, and what the
    replacement would look like.  Files are never modified.
    """
    root = Path(root)
    _validate_root(root)
    compiled = re.compile(regex)
    sections: list[str] = []

    for filepath in _iter_matching_files(root, pattern):
        try:
            lines = filepath.read_text().splitlines()
        except (OSError, UnicodeDecodeError):
            continue

        for idx, line in enumerate(lines):
            if not compiled.search(line):
                continue
            lineno = idx + 1  # 1-based
            new_line = compiled.sub(replacement, line)

            # Gather context window
            start = max(0, idx - context_lines)
            end = min(len(lines), idx + context_lines + 1)

            buf = [f"--- {filepath}:{lineno}: ---"]
            for ci in range(start, end):
                prefix = "  " if ci != idx else "- "
                buf.append(f"{prefix}{ci + 1}: {lines[ci]}")
                if ci == idx:
                    buf.append(f"+ {ci + 1}: {new_line}")
            sections.append("\n".join(buf))

    return "\n\n".join(sections)


def search_replace(
    root: str | Path,
    pattern: str,
    regex: str,
    replacement: str,
    *,
    backup: bool = True,
) -> list[ChangeRecord]:
    """Perform regex search-and-replace in files matching *pattern* under *root*.

    - If *backup* is True, creates a .bak copy of each modified file before writing.
    - Returns a list of ChangeRecord objects documenting every changed line.
    """
    root = Path(root)
    _validate_root(root)
    compiled = re.compile(regex)
    records: list[ChangeRecord] = []

    for filepath in _iter_matching_files(root, pattern):
        try:
            text = filepath.read_text()
        except (OSError, UnicodeDecodeError):
            continue

        lines = text.splitlines(keepends=True)
        changed = False
        new_lines: list[str] = []

        for idx, line in enumerate(lines, start=1):
            if compiled.search(line):
                new_line = compiled.sub(replacement, line)
                records.append(ChangeRecord(
                    file=str(filepath),
                    line_number=idx,
                    old_text=line.rstrip("\n"),
                    new_text=new_line.rstrip("\n"),
                ))
                new_lines.append(new_line)
                changed = True
            else:
                new_lines.append(line)

        if changed:
            if backup:
                shutil.copy2(str(filepath), str(filepath) + ".bak")
            filepath.write_text("".join(new_lines))

    return records


def summary_report(records: list[ChangeRecord]) -> str:
    """Format a human-readable summary table of all changes.

    Each entry shows the file, line number, old text, and new text.
    Returns "No changes made." when the list is empty.
    """
    if not records:
        return "No changes made."

    lines = ["Search-and-Replace Summary", "=" * 40]
    for rec in records:
        lines.append(f"File: {rec.file}")
        lines.append(f"  Line {rec.line_number}:")
        lines.append(f"    - {rec.old_text}")
        lines.append(f"    + {rec.new_text}")
        lines.append("")
    lines.append(f"Total changes: {len(records)}")
    return "\n".join(lines)
