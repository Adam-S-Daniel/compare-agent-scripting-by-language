"""
dirsync.py — Directory Tree Sync Tool

Architecture:
  - FileSystem abstraction (interface): all I/O goes through this
  - MockFileSystem: in-memory implementation for testing
  - RealFileSystem: wraps os/pathlib for production use
  - hash_file: SHA-256 hash of a file's bytes via the FileSystem
  - scan_tree: recursively scan a root, returning {relative_path: sha256}
  - compare_trees: diff two scanned trees into categorised sets
  - generate_sync_plan: turn a diff into a SyncPlan of SyncActions
  - execute_sync: apply (or dry-run) a SyncPlan

Red/Green TDD was used: each function was introduced to satisfy a failing test.
"""

import hashlib
import os
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any


# ---------------------------------------------------------------------------
# FileSystem abstraction
# ---------------------------------------------------------------------------

class FileSystem:
    """Abstract interface for all file-system operations.

    Using an abstraction lets tests inject a MockFileSystem without touching
    the real disk, while production code uses RealFileSystem unchanged.
    """

    def exists(self, path: str) -> bool:
        raise NotImplementedError

    def is_dir(self, path: str) -> bool:
        raise NotImplementedError

    def list_dir(self, path: str) -> list[str]:
        """Return names (not full paths) of entries directly inside *path*."""
        raise NotImplementedError

    def read(self, path: str) -> bytes:
        raise NotImplementedError

    def write(self, path: str, data: bytes) -> None:
        raise NotImplementedError

    def delete(self, path: str) -> None:
        raise NotImplementedError

    def makedirs(self, path: str) -> None:
        raise NotImplementedError


class MockFileSystem(FileSystem):
    """In-memory filesystem backed by a plain dict.

    Keys are normalised POSIX-style absolute paths ("/root/sub/file.txt").
    Directories are inferred from the paths present — you never store them
    explicitly; any path prefix counts as a directory.

    Pass a dict of {path: bytes} to the constructor to pre-populate.
    """

    def __init__(
        self,
        files: dict[str, bytes] | None = None,
        dirs: set[str] | None = None,
    ):
        # Normalise all paths using PurePosixPath to remove trailing slashes etc.
        self._files: dict[str, bytes] = {}
        for path, data in (files or {}).items():
            self._files[self._norm(path)] = data
        # Explicitly registered empty directories (needed when no files exist
        # under a directory but the directory itself must be visible).
        self._dirs: set[str] = {self._norm(d) for d in (dirs or set())}

    @staticmethod
    def _norm(path: str) -> str:
        return str(PurePosixPath(path))

    def exists(self, path: str) -> bool:
        norm = self._norm(path)
        # A path exists if it IS a file, an explicit directory, or a prefix of any file.
        return (
            norm in self._files
            or norm in self._dirs
            or any(k.startswith(norm + "/") for k in self._files)
        )

    def is_dir(self, path: str) -> bool:
        norm = self._norm(path)
        return norm in self._dirs or any(k.startswith(norm + "/") for k in self._files)

    def list_dir(self, path: str) -> list[str]:
        norm = self._norm(path)
        if not self.exists(norm):
            raise FileNotFoundError(f"Directory not found: {path}")
        names: set[str] = set()
        prefix = norm + "/"
        for k in self._files:
            if k.startswith(prefix):
                # Take only the next path component after the prefix.
                rest = k[len(prefix):]
                names.add(rest.split("/")[0])
        return sorted(names)

    def read(self, path: str) -> bytes:
        norm = self._norm(path)
        if norm not in self._files:
            raise FileNotFoundError(f"File not found: {path}")
        return self._files[norm]

    def write(self, path: str, data: bytes) -> None:
        self._files[self._norm(path)] = data

    def delete(self, path: str) -> None:
        norm = self._norm(path)
        if norm not in self._files:
            raise FileNotFoundError(f"File not found: {path}")
        del self._files[norm]

    def makedirs(self, path: str) -> None:
        # Directories are implicit in MockFileSystem; nothing to store.
        pass

    def join(self, *parts: str) -> str:
        """POSIX path join for mock paths."""
        return str(PurePosixPath(*parts))


class RealFileSystem(FileSystem):
    """Production filesystem using the real OS."""

    def exists(self, path: str) -> bool:
        return os.path.exists(path)

    def is_dir(self, path: str) -> bool:
        return os.path.isdir(path)

    def list_dir(self, path: str) -> list[str]:
        if not os.path.isdir(path):
            raise FileNotFoundError(f"Directory not found: {path}")
        return sorted(os.listdir(path))

    def read(self, path: str) -> bytes:
        try:
            return Path(path).read_bytes()
        except FileNotFoundError:
            raise FileNotFoundError(f"File not found: {path}")

    def write(self, path: str, data: bytes) -> None:
        Path(path).write_bytes(data)

    def delete(self, path: str) -> None:
        os.remove(path)

    def makedirs(self, path: str) -> None:
        os.makedirs(path, exist_ok=True)

    def join(self, *parts: str) -> str:
        return os.path.join(*parts)


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def hash_file(fs: FileSystem, path: str) -> str:
    """Return the SHA-256 hex digest of the file at *path* via *fs*.

    Raises FileNotFoundError if the file does not exist.
    """
    data = fs.read(path)  # propagates FileNotFoundError
    return hashlib.sha256(data).hexdigest()


def _join(fs: FileSystem, *parts: str) -> str:
    """Path-join using the filesystem's own join method if available."""
    if hasattr(fs, "join"):
        return fs.join(*parts)
    return os.path.join(*parts)


def scan_tree(fs: FileSystem, root: str) -> dict[str, str]:
    """Recursively scan *root* and return {relative_path: sha256}.

    Paths use forward slashes regardless of OS, so diffs are platform-neutral.
    Raises FileNotFoundError if *root* does not exist.
    """
    if not fs.exists(root):
        raise FileNotFoundError(f"Root directory not found: {root}")

    result: dict[str, str] = {}

    def _recurse(current: str, rel_prefix: str) -> None:
        for name in fs.list_dir(current):
            full = _join(fs, current, name)
            rel = f"{rel_prefix}{name}" if not rel_prefix else f"{rel_prefix}/{name}"
            # Trim the leading separator if rel_prefix was empty
            rel = rel.lstrip("/")
            if fs.is_dir(full):
                _recurse(full, rel)
            else:
                result[rel] = hash_file(fs, full)

    _recurse(root, "")
    return result


def compare_trees(
    src: dict[str, str], dst: dict[str, str]
) -> dict[str, list[str]]:
    """Diff two path->hash maps.

    Returns a dict with four keys:
      only_in_src  — files present in src but absent from dst
      only_in_dst  — files present in dst but absent from src
      modified     — files present in both but with different hashes
      identical    — files present in both with the same hash
    """
    src_keys = set(src)
    dst_keys = set(dst)

    only_in_src = sorted(src_keys - dst_keys)
    only_in_dst = sorted(dst_keys - src_keys)
    common = src_keys & dst_keys
    modified = sorted(p for p in common if src[p] != dst[p])
    identical = sorted(p for p in common if src[p] == dst[p])

    return {
        "only_in_src": only_in_src,
        "only_in_dst": only_in_dst,
        "modified": modified,
        "identical": identical,
    }


# ---------------------------------------------------------------------------
# Sync plan data structures
# ---------------------------------------------------------------------------

@dataclass
class SyncAction:
    """A single file operation in a sync plan.

    action: one of "COPY", "UPDATE", "DELETE"
    path:   relative path (used to locate the file under src_root / dst_root)
    """
    action: str   # "COPY" | "UPDATE" | "DELETE"
    path: str


@dataclass
class SyncPlan:
    """An ordered list of SyncActions plus a summary counter dict."""
    actions: list[SyncAction]
    summary: dict[str, int]


def generate_sync_plan(diff: dict[str, list[str]]) -> SyncPlan:
    """Build a SyncPlan from a compare_trees diff.

    Rules:
      only_in_src  → COPY   (bring new files into dst)
      only_in_dst  → DELETE (remove stale files from dst)
      modified     → UPDATE (overwrite changed files in dst)
      identical    → no action needed
    """
    actions: list[SyncAction] = []

    for path in diff.get("only_in_src", []):
        actions.append(SyncAction(action="COPY", path=path))

    for path in diff.get("modified", []):
        actions.append(SyncAction(action="UPDATE", path=path))

    for path in diff.get("only_in_dst", []):
        actions.append(SyncAction(action="DELETE", path=path))

    summary = {
        "copies": sum(1 for a in actions if a.action == "COPY"),
        "updates": sum(1 for a in actions if a.action == "UPDATE"),
        "deletes": sum(1 for a in actions if a.action == "DELETE"),
    }

    return SyncPlan(actions=actions, summary=summary)


# ---------------------------------------------------------------------------
# Execute / dry-run
# ---------------------------------------------------------------------------

def execute_sync(
    fs: FileSystem,
    plan: SyncPlan,
    src_root: str,
    dst_root: str,
    dry_run: bool = True,
) -> list[dict[str, Any]]:
    """Apply (or simulate) a SyncPlan.

    dry_run=True  — report what *would* happen, touch nothing.
    dry_run=False — perform the operations using *fs*.

    Returns a report list, one entry per action:
      {"action": "COPY", "path": "sub/file.txt", "status": "done"|"dry-run"}
    """
    report: list[dict[str, Any]] = []

    for action in plan.actions:
        src_path = _join(fs, src_root, action.path)
        dst_path = _join(fs, dst_root, action.path)

        if dry_run:
            report.append({
                "action": action.action,
                "path": action.path,
                "status": "dry-run",
            })
            continue

        if action.action in ("COPY", "UPDATE"):
            # Ensure parent directory exists in dst before writing.
            parent = str(PurePosixPath(dst_path).parent) if isinstance(fs, MockFileSystem) \
                     else os.path.dirname(dst_path)
            if parent and parent != dst_root:
                fs.makedirs(parent)
            data = fs.read(src_path)
            fs.write(dst_path, data)

        elif action.action == "DELETE":
            fs.delete(dst_path)

        else:
            raise ValueError(f"Unknown action: {action.action}")

        report.append({
            "action": action.action,
            "path": action.path,
            "status": "done",
        })

    return report


# ---------------------------------------------------------------------------
# CLI entry point (not tested via unit tests, but usable from the command line)
# ---------------------------------------------------------------------------

def _cli() -> None:
    import argparse
    import json

    parser = argparse.ArgumentParser(
        description="Compare two directory trees and optionally sync them."
    )
    parser.add_argument("src", help="Source directory")
    parser.add_argument("dst", help="Destination directory")
    parser.add_argument(
        "--execute",
        action="store_true",
        default=False,
        help="Actually perform the sync (default: dry-run only)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        default=False,
        help="Output the sync plan and report as JSON",
    )
    args = parser.parse_args()

    fs = RealFileSystem()

    print(f"Scanning source:      {args.src}")
    src_tree = scan_tree(fs, args.src)
    print(f"Scanning destination: {args.dst}")
    dst_tree = scan_tree(fs, args.dst)

    diff = compare_trees(src_tree, dst_tree)
    plan = generate_sync_plan(diff)

    mode = "EXECUTE" if args.execute else "DRY-RUN"
    print(f"\n=== Sync Plan ({mode}) ===")
    for a in plan.actions:
        print(f"  {a.action:8s}  {a.path}")

    summary = plan.summary
    print(f"\nSummary: {summary['copies']} copies, "
          f"{summary['updates']} updates, "
          f"{summary['deletes']} deletes.")

    report = execute_sync(fs, plan, src_root=args.src, dst_root=args.dst,
                          dry_run=not args.execute)

    if args.json:
        print(json.dumps({"plan": [vars(a) for a in plan.actions], "report": report},
                         indent=2))

    if args.execute:
        print("\nSync complete.")


if __name__ == "__main__":
    _cli()
