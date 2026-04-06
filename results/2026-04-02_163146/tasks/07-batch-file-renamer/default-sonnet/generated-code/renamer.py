"""
Batch File Renamer
==================
Rename files in a directory using regex-based patterns.

Features:
  - Preview mode  : show what would change without doing it (dry_run=True)
  - Undo script   : generate a shell script that reverses the renames
  - Conflict detection : flag when two files would get the same name, or
                        when the target already exists

TDD approach (red → green → refactor):
  Each function was driven by a failing test in test_renamer.py.
"""

import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# Data model
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class RenameOperation:
    """Represents a single planned rename: old_path → new_path."""
    old_name: str
    new_name: str
    old_path: Path
    new_path: Path


# ─────────────────────────────────────────────────────────────────────────────
# Core functions
# ─────────────────────────────────────────────────────────────────────────────

def compute_renames(
    directory: Path,
    pattern: str,
    replacement: str,
    *,
    ignore_case: bool = False,
) -> list[RenameOperation]:
    """
    Scan *directory* and compute which files match *pattern*.

    Returns a list of RenameOperation objects for every file whose name
    matches the regex.  Files that don't match are silently ignored.

    Args:
        directory:   Directory to scan (must exist).
        pattern:     Python regex pattern applied to the *filename* (not path).
        replacement: Replacement string (supports back-references like \\1).
        ignore_case: If True, the regex is compiled with re.IGNORECASE.

    Raises:
        FileNotFoundError: If *directory* does not exist.
    """
    directory = Path(directory)
    if not directory.exists():
        raise FileNotFoundError(f"Directory not found: {directory}")

    flags = re.IGNORECASE if ignore_case else 0
    compiled = re.compile(pattern, flags)

    ops: list[RenameOperation] = []
    for entry in sorted(directory.iterdir()):
        # Only rename files, not subdirectories
        if not entry.is_file():
            continue

        new_name = compiled.sub(replacement, entry.name)

        # Only include files whose name actually changed
        if new_name != entry.name:
            ops.append(
                RenameOperation(
                    old_name=entry.name,
                    new_name=new_name,
                    old_path=entry,
                    new_path=directory / new_name,
                )
            )

    return ops


def detect_conflicts(
    ops: list[RenameOperation],
    directory: Optional[Path] = None,
) -> list[dict]:
    """
    Detect naming conflicts among the planned renames.

    Two kinds of conflict are detected:
      1. Two ops produce the same new_name (intra-op collision).
      2. The new_name already exists in *directory* and that file is NOT
         itself being renamed away (clash with an existing file).

    Args:
        ops:       List of RenameOperation objects from compute_renames().
        directory: Optional; needed only for conflict type 2 (existing files).

    Returns:
        A list of conflict dicts, each with keys:
          "new_name"  – the conflicting target name
          "sources"   – list of old_name strings that collide on that target
    """
    conflicts: list[dict] = []

    # --- Conflict type 1: two ops map to the same new name ---
    by_new: dict[str, list[str]] = defaultdict(list)
    for op in ops:
        by_new[op.new_name].append(op.old_name)

    for new_name, sources in by_new.items():
        if len(sources) > 1:
            conflicts.append({"new_name": new_name, "sources": sources})

    # --- Conflict type 2: new name already exists (and isn't moving away) ---
    if directory is not None:
        directory = Path(directory)
        # Names that are being moved *away* (they will be vacated by the rename)
        old_names_being_renamed = {op.old_name for op in ops}

        for op in ops:
            target = directory / op.new_name
            if (
                target.exists()
                and op.new_name not in old_names_being_renamed  # the source isn't vacated
                and op.new_name not in {c["new_name"] for c in conflicts}  # not already flagged
            ):
                conflicts.append({"new_name": op.new_name, "sources": [op.old_name]})

    return conflicts


def generate_undo_script(ops: list[RenameOperation]) -> str:
    """
    Generate a POSIX shell script that reverses all renames in *ops*.

    The undo script renames each *new_name* back to *old_name* using `mv`.
    The script is safe to inspect before running.

    Args:
        ops: The same list of RenameOperation objects that were (or will be)
             passed to apply_renames().

    Returns:
        A string containing a complete shell script.
    """
    lines = [
        "#!/usr/bin/env bash",
        "# Auto-generated undo script for batch-file-renamer",
        "# Run this script to reverse the renames.",
        "set -euo pipefail",
        "",
    ]

    for op in ops:
        # Quote paths to handle spaces and special characters
        old = _shell_quote(str(op.old_path))
        new = _shell_quote(str(op.new_path))
        lines.append(f"mv {new} {old}")

    lines.append("")  # trailing newline
    return "\n".join(lines)


def apply_renames(
    ops: list[RenameOperation],
    *,
    dry_run: bool = False,
) -> list[RenameOperation]:
    """
    Execute the rename operations.

    In dry-run mode the filesystem is not touched; the list is returned as-is
    so callers can display a preview.

    Args:
        ops:     List of RenameOperation objects from compute_renames().
        dry_run: If True, no files are moved on disk.

    Returns:
        The list of operations that were (or, in dry-run, would be) performed.

    Raises:
        ValueError: If any conflicts are detected (regardless of dry_run).
    """
    # Always check for conflicts – even previews should warn the user.
    # Determine the directory from the first op (all ops share a directory).
    directory = ops[0].old_path.parent if ops else None
    conflicts = detect_conflicts(ops, directory=directory)
    if conflicts:
        descriptions = "; ".join(
            f"'{c['new_name']}' ← {c['sources']}" for c in conflicts
        )
        raise ValueError(f"Rename conflict detected: {descriptions}")

    if dry_run:
        return list(ops)

    completed: list[RenameOperation] = []
    for op in ops:
        op.old_path.rename(op.new_path)
        completed.append(op)

    return completed


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _shell_quote(s: str) -> str:
    """Minimally quote a path for POSIX shell (single-quote with escaping)."""
    return "'" + s.replace("'", "'\\''") + "'"
