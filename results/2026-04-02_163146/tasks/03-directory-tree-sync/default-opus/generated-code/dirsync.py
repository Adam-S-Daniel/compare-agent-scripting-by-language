#!/usr/bin/env python3
"""Directory Tree Sync — compare two trees by SHA-256 and synchronize.

Supports dry-run (report only) and execute (perform sync) modes.
All file operations use standard library only, no external dependencies.

Usage as a CLI:
    python3 dirsync.py --dry-run  /path/to/source /path/to/dest
    python3 dirsync.py --execute  /path/to/source /path/to/dest
"""

import hashlib
import os
import shutil
import sys
from dataclasses import dataclass, field
from typing import Dict, List


# ---------------------------------------------------------------------------
# TDD Cycle 1 — SHA-256 file hashing
# ---------------------------------------------------------------------------

def hash_file(path: str, block_size: int = 65536) -> str:
    """Return the SHA-256 hex digest of a file's contents.

    Reads in chunks so arbitrarily large files can be hashed without
    loading the entire file into memory.

    Raises FileNotFoundError if the path does not exist.
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")

    sha = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(block_size)
            if not chunk:
                break
            sha.update(chunk)
    return sha.hexdigest()


# ---------------------------------------------------------------------------
# TDD Cycle 2 — Directory tree scanning
# ---------------------------------------------------------------------------

def scan_tree(root: str) -> Dict[str, str]:
    """Walk a directory tree and return {relative_path: sha256_hash}.

    Raises FileNotFoundError if root does not exist.
    """
    if not os.path.exists(root):
        raise FileNotFoundError(f"Directory not found: {root}")
    if not os.path.isdir(root):
        raise NotADirectoryError(f"Not a directory: {root}")

    result: Dict[str, str] = {}
    for dirpath, _dirnames, filenames in os.walk(root):
        for fname in filenames:
            abs_path = os.path.join(dirpath, fname)
            rel_path = os.path.relpath(abs_path, root)
            result[rel_path] = hash_file(abs_path)
    return result


# ---------------------------------------------------------------------------
# TDD Cycle 3 — Comparing two trees
# ---------------------------------------------------------------------------

@dataclass
class TreeDiff:
    """Result of comparing two directory trees."""
    only_in_source: List[str] = field(default_factory=list)
    only_in_dest: List[str] = field(default_factory=list)
    content_differs: List[str] = field(default_factory=list)
    identical: List[str] = field(default_factory=list)


def compare_trees(source: str, dest: str) -> TreeDiff:
    """Compare source and dest directory trees by content hash.

    Returns a TreeDiff with files classified into four categories:
    - only_in_source: files present in source but missing in dest
    - only_in_dest:   files present in dest but missing in source
    - content_differs: files present in both but with different SHA-256
    - identical:       files present in both with matching SHA-256
    """
    _validate_dirs(source, dest)

    src_map = scan_tree(source)
    dst_map = scan_tree(dest)

    src_keys = set(src_map.keys())
    dst_keys = set(dst_map.keys())

    diff = TreeDiff()
    diff.only_in_source = sorted(src_keys - dst_keys)
    diff.only_in_dest = sorted(dst_keys - src_keys)

    for path in sorted(src_keys & dst_keys):
        if src_map[path] == dst_map[path]:
            diff.identical.append(path)
        else:
            diff.content_differs.append(path)

    return diff


# ---------------------------------------------------------------------------
# TDD Cycle 4 — Sync plan generation / dry-run
# ---------------------------------------------------------------------------

def generate_sync_plan(source: str, dest: str) -> List[dict]:
    """Produce a list of actions needed to make dest match source.

    Each action is a dict with keys:
        action: "COPY" | "UPDATE" | "DELETE"
        path:   relative file path
    """
    diff = compare_trees(source, dest)
    plan: List[dict] = []

    for path in diff.only_in_source:
        plan.append({"action": "COPY", "path": path})
    for path in diff.content_differs:
        plan.append({"action": "UPDATE", "path": path})
    for path in diff.only_in_dest:
        plan.append({"action": "DELETE", "path": path})

    return plan


def dry_run(source: str, dest: str) -> str:
    """Return a human-readable report of what sync would do (no changes made).

    Raises FileNotFoundError if source or dest do not exist.
    """
    plan = generate_sync_plan(source, dest)

    if not plan:
        return "Trees are identical — nothing to do."

    lines = [f"Sync plan: {source} → {dest}", ""]
    for action in plan:
        lines.append(f"  {action['action']:8s} {action['path']}")
    lines.append("")
    lines.append(f"Total: {len(plan)} action(s)")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# TDD Cycle 5 — Execute mode
# ---------------------------------------------------------------------------

def execute_sync(source: str, dest: str) -> str:
    """Synchronize dest to match source, then return a summary string.

    Operations performed:
    - COPY:   new files from source are copied into dest
    - UPDATE: changed files are overwritten with source content
    - DELETE: files only in dest are removed

    Raises FileNotFoundError / NotADirectoryError on bad inputs.
    """
    _validate_dirs(source, dest)

    plan = generate_sync_plan(source, dest)
    counts = {"copied": 0, "updated": 0, "deleted": 0}

    for action in plan:
        rel = action["path"]
        src_abs = os.path.join(source, rel)
        dst_abs = os.path.join(dest, rel)

        if action["action"] == "COPY":
            # Ensure parent directories exist in dest
            os.makedirs(os.path.dirname(dst_abs), exist_ok=True)
            shutil.copy2(src_abs, dst_abs)
            counts["copied"] += 1

        elif action["action"] == "UPDATE":
            shutil.copy2(src_abs, dst_abs)
            counts["updated"] += 1

        elif action["action"] == "DELETE":
            os.remove(dst_abs)
            counts["deleted"] += 1

    return (
        f"Sync complete: "
        f"{counts['copied']} copied, "
        f"{counts['updated']} updated, "
        f"{counts['deleted']} deleted"
    )


# ---------------------------------------------------------------------------
# TDD Cycle 6 — Validation / error handling
# ---------------------------------------------------------------------------

def _validate_dirs(source: str, dest: str) -> None:
    """Check that source and dest are existing directories.

    Raises FileNotFoundError with a message naming which path is bad,
    or NotADirectoryError if the path exists but isn't a directory.
    """
    if not os.path.exists(source):
        raise FileNotFoundError(f"Source directory not found: {source}")
    if not os.path.isdir(source):
        raise NotADirectoryError(f"Source is not a directory: {source}")
    if not os.path.exists(dest):
        raise FileNotFoundError(f"Destination directory not found: {dest}")
    if not os.path.isdir(dest):
        raise NotADirectoryError(f"Destination is not a directory: {dest}")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Command-line interface for directory tree sync."""
    if len(sys.argv) < 4 or sys.argv[1] not in ("--dry-run", "--execute"):
        print("Usage: python3 dirsync.py [--dry-run | --execute] SOURCE DEST")
        sys.exit(1)

    mode = sys.argv[1]
    source = sys.argv[2]
    dest = sys.argv[3]

    try:
        if mode == "--dry-run":
            print(dry_run(source, dest))
        else:
            result = execute_sync(source, dest)
            print(result)
    except (FileNotFoundError, NotADirectoryError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
