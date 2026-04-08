"""
Batch File Renamer
==================

Features:
  - Preview mode   : compute_renames() returns (old, new) pairs without touching disk
  - Apply mode     : apply_renames() performs the renames, raising ConflictError first
  - Conflict detect: detect_conflicts() finds name collisions before renaming
  - Undo script    : generate_undo_script() returns a shell script that reverses renames

Design decisions:
  - compute_renames is pure (no I/O side effects) — safe to call for preview
  - detect_conflicts is called automatically inside apply_renames (fail-safe)
  - RenameResult is a dataclass so tests can inspect fields directly
  - Conflict is a dataclass carrying a human-readable message
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List


# ---------------------------------------------------------------------------
# Public data structures
# ---------------------------------------------------------------------------

@dataclass
class RenameResult:
    """A planned rename: the original path and the proposed new path."""
    old_path: Path
    new_path: Path


@dataclass
class Conflict:
    """Describes a naming conflict that would result from applying a rename set."""
    target_name: str  # the duplicated target filename
    sources: List[Path]  # source paths that all map to target_name
    message: str = field(init=False)

    def __post_init__(self) -> None:
        source_names = ", ".join(p.name for p in self.sources)
        self.message = (
            f"Conflict: '{self.target_name}' would be produced by: {source_names}"
        )


class ConflictError(Exception):
    """Raised by apply_renames when conflicts would corrupt the rename operation."""

    def __init__(self, conflicts: List[Conflict]) -> None:
        self.conflicts = conflicts
        lines = "\n".join(c.message for c in conflicts)
        super().__init__(f"Rename aborted due to {len(conflicts)} conflict(s):\n{lines}")


# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

def compute_renames(
    directory: Path,
    pattern: str,
    replacement: str,
) -> List[RenameResult]:
    """
    Scan *directory* (non-recursively) for files whose names match *pattern*
    and compute the renamed path using *replacement* (regex substitution).

    This is a pure preview — the filesystem is NOT modified.

    Parameters
    ----------
    directory   : directory to scan (Path or str)
    pattern     : regex pattern applied to the filename (not the full path)
    replacement : replacement string (supports back-references like \\1)

    Returns
    -------
    List of RenameResult with (old_path, new_path). Files that don't match
    the pattern are omitted. Files where the name doesn't change are also
    omitted (no-op renames are useless).
    """
    directory = Path(directory)
    compiled = re.compile(pattern)
    results: List[RenameResult] = []

    for entry in sorted(directory.iterdir()):
        if not entry.is_file():
            continue  # skip subdirectories

        new_name = compiled.sub(replacement, entry.name)

        # Only include if the pattern actually matched (name changed)
        if new_name == entry.name:
            continue
        # Skip if the regex didn't match at all (sub returns unchanged string)
        if not compiled.search(entry.name):
            continue

        results.append(
            RenameResult(
                old_path=entry.resolve(),
                new_path=(directory / new_name).resolve(),
            )
        )

    return results


def detect_conflicts(renames: List[RenameResult]) -> List[Conflict]:
    """
    Inspect a list of planned renames and return any conflicts.

    Two kinds of conflict are detected:
    1. Multiple sources map to the same target name.
    2. A target name collides with an existing file that is *not* being renamed.

    Parameters
    ----------
    renames : output of compute_renames()

    Returns
    -------
    List of Conflict objects (empty list means no conflicts).
    """
    conflicts: List[Conflict] = []

    # Build a map from target path → list of source paths
    target_to_sources: dict[Path, List[Path]] = {}
    for r in renames:
        target_to_sources.setdefault(r.new_path, []).append(r.old_path)

    # Set of paths being moved away (they'll vacate their current name)
    sources_being_moved = {r.old_path for r in renames}

    for target_path, sources in target_to_sources.items():
        # Conflict type 1: multiple sources map to the same target
        if len(sources) > 1:
            conflicts.append(Conflict(target_name=target_path.name, sources=sources))
            continue

        # Conflict type 2: target already exists AND is not itself being renamed
        if target_path.exists() and target_path not in sources_being_moved:
            conflicts.append(Conflict(target_name=target_path.name, sources=sources))

    return conflicts


def apply_renames(renames: List[RenameResult]) -> None:
    """
    Execute the planned renames on disk.

    Before renaming anything, conflicts are checked. If any are found,
    a ConflictError is raised and NO files are renamed (fail-safe).

    Parameters
    ----------
    renames : output of compute_renames()

    Raises
    ------
    ConflictError if conflicts are detected (no files will have been renamed).
    """
    if not renames:
        return

    conflicts = detect_conflicts(renames)
    if conflicts:
        raise ConflictError(conflicts)

    for r in renames:
        r.old_path.rename(r.new_path)


def generate_undo_script(renames: List[RenameResult]) -> str:
    """
    Generate a POSIX shell script that reverses the given renames.

    Each rename  old → new  becomes  mv "new" "old"  in the script.

    Parameters
    ----------
    renames : output of compute_renames() (applied or planned)

    Returns
    -------
    A string containing a complete, executable shell script.
    """
    lines = [
        "#!/usr/bin/env bash",
        "# Undo script — reverses the batch rename operation",
        "# Run with:  bash undo.sh",
        "set -euo pipefail",
        "",
    ]

    if not renames:
        lines.append("# No renames to undo.")
    else:
        lines.append("# Reversing renames (new → old):")
        for r in renames:
            # Quote paths to handle spaces and special characters
            new = str(r.new_path).replace("'", r"'\''")
            old = str(r.old_path).replace("'", r"'\''")
            lines.append(f"mv '{new}' '{old}'")

    lines.append("")  # trailing newline
    return "\n".join(lines)
