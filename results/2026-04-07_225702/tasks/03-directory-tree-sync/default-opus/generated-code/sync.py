"""
Directory Tree Sync Tool
=========================
Compares two directory trees by SHA-256 content hash, identifies differences,
and generates a sync plan.  Supports dry-run (report) and execute modes.

Built using red/green TDD — every public function was test-driven.
"""

from __future__ import annotations

import hashlib
import os
import shutil
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import List


# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------

def file_hash(path: Path | str, *, chunk_size: int = 8192) -> str:
    """Return the SHA-256 hex digest of *path*. Raises FileNotFoundError."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"No such file: {path}")
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(chunk_size):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Tree scanning
# ---------------------------------------------------------------------------

def scan_tree(root: Path | str) -> dict[str, str]:
    """Walk *root* and return {relative_posix_path: sha256_hex} for every file."""
    root = Path(root)
    if not root.is_dir():
        raise FileNotFoundError(f"Directory not found: {root}")
    result: dict[str, str] = {}
    for dirpath, _, filenames in os.walk(root):
        for name in sorted(filenames):
            full = Path(dirpath) / name
            rel = full.relative_to(root).as_posix()
            result[rel] = file_hash(full)
    return result


# ---------------------------------------------------------------------------
# Comparison model
# ---------------------------------------------------------------------------

class ActionKind(Enum):
    COPY = "copy"      # file exists only in source → copy to dest
    REMOVE = "remove"  # file exists only in dest → remove from dest
    UPDATE = "update"  # file differs between source and dest → overwrite in dest


@dataclass
class SyncAction:
    """One atomic operation in a sync plan."""
    kind: ActionKind
    rel_path: str      # forward-slash relative path within the trees


def compare_trees(
    source: Path | str,
    dest: Path | str,
) -> list[SyncAction]:
    """Compare *source* and *dest* trees and return the list of sync actions
    needed to make *dest* match *source*."""
    src_map = scan_tree(source)
    dst_map = scan_tree(dest)

    all_paths = sorted(set(src_map) | set(dst_map))
    actions: list[SyncAction] = []

    for rel in all_paths:
        in_src = rel in src_map
        in_dst = rel in dst_map
        if in_src and not in_dst:
            actions.append(SyncAction(ActionKind.COPY, rel))
        elif not in_src and in_dst:
            actions.append(SyncAction(ActionKind.REMOVE, rel))
        elif src_map[rel] != dst_map[rel]:
            actions.append(SyncAction(ActionKind.UPDATE, rel))
        # else: identical — nothing to do

    return actions


# ---------------------------------------------------------------------------
# Dry-run report
# ---------------------------------------------------------------------------

_KIND_LABELS = {
    ActionKind.COPY: "COPY  ",
    ActionKind.REMOVE: "REMOVE",
    ActionKind.UPDATE: "UPDATE",
}


def dry_run_report(actions: list[SyncAction]) -> str:
    """Return a human-readable report of planned sync actions."""
    if not actions:
        return "Trees are in sync — nothing to do."

    lines: list[str] = ["Sync plan (dry run):", ""]
    for a in actions:
        lines.append(f"  {_KIND_LABELS[a.kind]}  {a.rel_path}")

    # Summary counts
    counts = {k: 0 for k in ActionKind}
    for a in actions:
        counts[a.kind] += 1
    lines.append("")
    parts = []
    if counts[ActionKind.COPY]:
        parts.append(f"{counts[ActionKind.COPY]} to copy")
    if counts[ActionKind.UPDATE]:
        parts.append(f"{counts[ActionKind.UPDATE]} to update")
    if counts[ActionKind.REMOVE]:
        parts.append(f"{counts[ActionKind.REMOVE]} to remove")
    lines.append(f"Summary: {', '.join(parts)}.")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Execute sync
# ---------------------------------------------------------------------------

def execute_sync(
    actions: list[SyncAction],
    source: Path | str,
    dest: Path | str,
) -> list[str]:
    """Apply *actions* to make *dest* match *source*.

    Returns a list of human-readable log lines describing what was done.
    Raises OSError on any file-operation failure with a meaningful message.
    """
    source = Path(source)
    dest = Path(dest)
    log: list[str] = []

    for a in actions:
        src_file = source / a.rel_path
        dst_file = dest / a.rel_path

        if a.kind in (ActionKind.COPY, ActionKind.UPDATE):
            # Ensure parent directory exists in dest
            dst_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, dst_file)
            verb = "Copied" if a.kind == ActionKind.COPY else "Updated"
            log.append(f"{verb}: {a.rel_path}")

        elif a.kind == ActionKind.REMOVE:
            if dst_file.exists():
                dst_file.unlink()
                log.append(f"Removed: {a.rel_path}")
            else:
                log.append(f"Already absent: {a.rel_path}")

    return log


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    """Entry point.  Returns 0 on success, non-zero on error."""
    import argparse
    import sys

    parser = argparse.ArgumentParser(
        description="Compare two directory trees and sync destination to match source.",
    )
    parser.add_argument("source", help="Source directory (the 'truth')")
    parser.add_argument("dest", help="Destination directory to be synced")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run", action="store_true", default=True,
        help="Report planned actions without making changes (default)",
    )
    mode.add_argument(
        "--execute", action="store_true",
        help="Actually perform the sync",
    )
    args = parser.parse_args(argv)

    try:
        actions = compare_trees(args.source, args.dest)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    if args.execute:
        log = execute_sync(actions, args.source, args.dest)
        for line in log:
            print(line)
        if not log:
            print("Trees are already in sync — nothing to do.")
    else:
        print(dry_run_report(actions))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
