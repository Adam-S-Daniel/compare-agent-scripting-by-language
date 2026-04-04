"""
dirsync.py — Directory Tree Sync Tool
======================================
Compare two directory trees by SHA-256 content hash, generate a sync plan,
and optionally execute it. Supports dry-run (report only) and execute modes.

Design:
  1. compute_sha256   — hash a single file
  2. build_file_index — walk a tree, build {relative_path: sha256} map
  3. compare_trees    — diff two indexes into identical/changed/src_only/dst_only
  4. generate_sync_plan — turn a comparison into a list of SyncActions
  5. execute_sync_plan  — apply (or just report) the plan

All file operations flow through Path objects so the logic is easy to unit-test
with real temporary directories created by the test suite's fixtures.
"""

import hashlib
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List


# ─────────────────────────────────────────────
# Data types
# ─────────────────────────────────────────────

@dataclass
class SyncAction:
    """A single planned operation: COPY, UPDATE, or DELETE."""
    action: str   # "COPY" | "UPDATE" | "DELETE"
    path: str     # relative path (forward-slash separated)

    def __repr__(self) -> str:
        return f"SyncAction(action={self.action!r}, path={self.path!r})"


# SyncPlan is just a typed alias for readability
SyncPlan = List[SyncAction]


# ─────────────────────────────────────────────
# 1. SHA-256 hashing
# ─────────────────────────────────────────────

def compute_sha256(path: Path) -> str:
    """
    Return the hex-encoded SHA-256 digest of the file at *path*.

    Reads in 64 KiB chunks so large files don't exhaust memory.
    Raises FileNotFoundError with the path in the message if the file
    does not exist.
    """
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


# ─────────────────────────────────────────────
# 2. Building a file index
# ─────────────────────────────────────────────

def build_file_index(root: Path) -> Dict[str, str]:
    """
    Walk *root* recursively and return a dict mapping every file's relative
    path (forward-slash separated) to its SHA-256 hex digest.

    Raises FileNotFoundError if *root* does not exist.
    """
    if not root.exists():
        raise FileNotFoundError(f"Directory not found: {root}")

    index: Dict[str, str] = {}
    for file_path in sorted(root.rglob("*")):
        if file_path.is_file():
            # Convert to relative path and normalise to forward slashes
            rel = file_path.relative_to(root)
            key = rel.as_posix()  # always uses '/' regardless of OS
            index[key] = compute_sha256(file_path)
    return index


# ─────────────────────────────────────────────
# 3. Comparing two trees
# ─────────────────────────────────────────────

def compare_trees(src_root: Path, dst_root: Path) -> dict:
    """
    Compare two directory trees by content hash.

    Returns a dict with four lists of relative paths:
      - identical : present in both, same content
      - changed   : present in both, different content
      - src_only  : present only in source
      - dst_only  : present only in destination

    Raises FileNotFoundError for either missing root.
    """
    if not src_root.exists():
        raise FileNotFoundError(f"Source directory not found: {src_root}")
    if not dst_root.exists():
        raise FileNotFoundError(f"Destination directory not found: {dst_root}")

    src_index = build_file_index(src_root)
    dst_index = build_file_index(dst_root)

    src_keys = set(src_index.keys())
    dst_keys = set(dst_index.keys())
    common = src_keys & dst_keys

    identical = sorted(p for p in common if src_index[p] == dst_index[p])
    changed   = sorted(p for p in common if src_index[p] != dst_index[p])
    src_only  = sorted(src_keys - dst_keys)
    dst_only  = sorted(dst_keys - src_keys)

    return {
        "identical": identical,
        "changed":   changed,
        "src_only":  src_only,
        "dst_only":  dst_only,
    }


# ─────────────────────────────────────────────
# 4. Generating a sync plan
# ─────────────────────────────────────────────

def generate_sync_plan(comparison: dict) -> SyncPlan:
    """
    Convert a comparison result into a list of SyncActions.

    Rules:
      src_only  → COPY   (file needs to be copied to destination)
      changed   → UPDATE (destination file needs to be overwritten)
      dst_only  → DELETE (file in destination has no source counterpart)
      identical → (no action)
    """
    plan: SyncPlan = []

    for path in comparison.get("src_only", []):
        plan.append(SyncAction(action="COPY", path=path))

    for path in comparison.get("changed", []):
        plan.append(SyncAction(action="UPDATE", path=path))

    for path in comparison.get("dst_only", []):
        plan.append(SyncAction(action="DELETE", path=path))

    return plan


# ─────────────────────────────────────────────
# 5. Executing (or dry-running) a sync plan
# ─────────────────────────────────────────────

def execute_sync_plan(
    plan: SyncPlan,
    src_root: Path,
    dst_root: Path,
    dry_run: bool = True,
) -> str:
    """
    Apply *plan* to synchronise *dst_root* from *src_root*.

    dry_run=True  → report what would happen; do NOT touch the filesystem.
    dry_run=False → perform the operations and report what was done.

    Returns a human-readable report string.

    Raises FileNotFoundError if src_root is missing when execute mode needs
    to copy/update files.
    """
    if not dry_run and not src_root.exists():
        raise FileNotFoundError(f"Source directory not found: {src_root}")

    mode_label = "DRY-RUN" if dry_run else "EXECUTE"
    lines: List[str] = [f"=== Sync Plan ({mode_label}) ===", ""]

    if not plan:
        lines.append("Nothing to do — trees are already in sync.")
        return "\n".join(lines)

    for action in plan:
        src_file = src_root / action.path
        dst_file = dst_root / action.path

        if action.action in ("COPY", "UPDATE"):
            lines.append(f"  {action.action:<6}  {action.path}")
            if not dry_run:
                # Ensure parent directories exist before copying
                dst_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_file, dst_file)

        elif action.action == "DELETE":
            lines.append(f"  DELETE  {action.path}")
            if not dry_run:
                dst_file.unlink(missing_ok=True)

    lines.append("")
    lines.append(f"Total actions: {len(plan)}")
    return "\n".join(lines)


# ─────────────────────────────────────────────
# CLI entry point
# ─────────────────────────────────────────────

def _main() -> None:
    """
    Simple CLI: dirsync.py <src> <dst> [--execute]

    Default is dry-run. Pass --execute to actually sync.
    """
    import sys

    args = sys.argv[1:]
    execute = "--execute" in args
    paths = [a for a in args if not a.startswith("--")]

    if len(paths) != 2:
        print("Usage: python dirsync.py <src_dir> <dst_dir> [--execute]")
        sys.exit(1)

    src = Path(paths[0])
    dst = Path(paths[1])

    try:
        comparison = compare_trees(src, dst)
        plan = generate_sync_plan(comparison)

        # Always print the comparison summary first
        print(f"Identical : {len(comparison['identical'])} file(s)")
        print(f"Changed   : {len(comparison['changed'])} file(s)")
        print(f"Src only  : {len(comparison['src_only'])} file(s)")
        print(f"Dst only  : {len(comparison['dst_only'])} file(s)")
        print()

        report = execute_sync_plan(plan, src, dst, dry_run=not execute)
        print(report)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    _main()
