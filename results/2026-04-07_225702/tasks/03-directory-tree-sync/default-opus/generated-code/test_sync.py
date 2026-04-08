"""Tests for directory tree sync tool — written test-first (red/green TDD)."""

import os
import tempfile
import pytest
from sync import (
    file_hash, scan_tree, compare_trees, ActionKind, SyncAction,
    dry_run_report, execute_sync,
)


# --- Cycle 1: SHA-256 hashing ---

class TestFileHash:
    def test_hash_known_content(self, tmp_path):
        """SHA-256 of a file with known content should match the expected digest."""
        f = tmp_path / "hello.txt"
        f.write_text("hello\n")
        # pre-computed: echo -n 'hello\n' | sha256sum
        expected = "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
        assert file_hash(f) == expected

    def test_hash_empty_file(self, tmp_path):
        f = tmp_path / "empty"
        f.write_bytes(b"")
        expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        assert file_hash(f) == expected

    def test_hash_nonexistent_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            file_hash(tmp_path / "nope")


# --- Cycle 2: Scan a directory tree ---

class TestScanTree:
    def test_scan_flat(self, tmp_path):
        """Scanning a flat directory returns relative paths mapped to hashes."""
        (tmp_path / "a.txt").write_text("aaa")
        (tmp_path / "b.txt").write_text("bbb")
        result = scan_tree(tmp_path)
        assert set(result.keys()) == {"a.txt", "b.txt"}
        assert result["a.txt"] == file_hash(tmp_path / "a.txt")

    def test_scan_nested(self, tmp_path):
        """Nested directories use forward-slash relative paths."""
        sub = tmp_path / "d1" / "d2"
        sub.mkdir(parents=True)
        (sub / "deep.txt").write_text("deep")
        result = scan_tree(tmp_path)
        assert "d1/d2/deep.txt" in result

    def test_scan_empty_dir(self, tmp_path):
        result = scan_tree(tmp_path)
        assert result == {}

    def test_scan_nonexistent_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            scan_tree(tmp_path / "nope")


# --- Cycle 3: Compare two trees ---

def _make_pair(tmp_path):
    """Helper: build source and destination directories for comparison tests."""
    src = tmp_path / "src"
    dst = tmp_path / "dst"
    src.mkdir()
    dst.mkdir()
    return src, dst


class TestCompareTrees:
    def test_identical_trees(self, tmp_path):
        """Identical trees produce no actions."""
        src, dst = _make_pair(tmp_path)
        (src / "f.txt").write_text("same")
        (dst / "f.txt").write_text("same")
        actions = compare_trees(src, dst)
        assert actions == []

    def test_file_only_in_source(self, tmp_path):
        """A file present only in source should be marked COPY."""
        src, dst = _make_pair(tmp_path)
        (src / "new.txt").write_text("new")
        actions = compare_trees(src, dst)
        assert len(actions) == 1
        assert actions[0].kind == ActionKind.COPY
        assert actions[0].rel_path == "new.txt"

    def test_file_only_in_dest(self, tmp_path):
        """A file present only in dest should be marked REMOVE."""
        src, dst = _make_pair(tmp_path)
        (dst / "old.txt").write_text("old")
        actions = compare_trees(src, dst)
        assert len(actions) == 1
        assert actions[0].kind == ActionKind.REMOVE
        assert actions[0].rel_path == "old.txt"

    def test_modified_file(self, tmp_path):
        """Different content (different hash) should be marked UPDATE."""
        src, dst = _make_pair(tmp_path)
        (src / "f.txt").write_text("version2")
        (dst / "f.txt").write_text("version1")
        actions = compare_trees(src, dst)
        assert len(actions) == 1
        assert actions[0].kind == ActionKind.UPDATE
        assert actions[0].rel_path == "f.txt"

    def test_mixed_changes(self, tmp_path):
        """Multiple kinds of changes in one comparison."""
        src, dst = _make_pair(tmp_path)
        # same
        (src / "keep.txt").write_text("keep")
        (dst / "keep.txt").write_text("keep")
        # modified
        (src / "mod.txt").write_text("new content")
        (dst / "mod.txt").write_text("old content")
        # only in source
        (src / "added.txt").write_text("added")
        # only in dest
        (dst / "removed.txt").write_text("removed")

        actions = compare_trees(src, dst)
        kinds = {a.rel_path: a.kind for a in actions}
        assert kinds == {
            "mod.txt": ActionKind.UPDATE,
            "added.txt": ActionKind.COPY,
            "removed.txt": ActionKind.REMOVE,
        }


# --- Cycle 4: Dry-run report ---

class TestDryRun:
    def test_report_no_actions(self):
        """Empty action list produces an 'in sync' message."""
        report = dry_run_report([])
        assert "in sync" in report.lower()

    def test_report_contains_all_actions(self):
        """Report includes a line for each action."""
        actions = [
            SyncAction(ActionKind.COPY, "new.txt"),
            SyncAction(ActionKind.REMOVE, "old.txt"),
            SyncAction(ActionKind.UPDATE, "changed.txt"),
        ]
        report = dry_run_report(actions)
        assert "COPY" in report
        assert "new.txt" in report
        assert "REMOVE" in report
        assert "old.txt" in report
        assert "UPDATE" in report
        assert "changed.txt" in report

    def test_report_summary_counts(self):
        """Report ends with a summary line showing counts."""
        actions = [
            SyncAction(ActionKind.COPY, "a"),
            SyncAction(ActionKind.COPY, "b"),
            SyncAction(ActionKind.REMOVE, "c"),
        ]
        report = dry_run_report(actions)
        # should mention totals
        assert "2" in report  # 2 copies
        assert "1" in report  # 1 remove


# --- Cycle 5: Execute sync ---

class TestExecuteSync:
    def test_copy_new_file(self, tmp_path):
        """COPY action creates the file in dest."""
        src, dst = _make_pair(tmp_path)
        (src / "new.txt").write_text("hello")
        actions = compare_trees(src, dst)
        execute_sync(actions, src, dst)
        assert (dst / "new.txt").read_text() == "hello"

    def test_remove_file(self, tmp_path):
        """REMOVE action deletes the file from dest."""
        src, dst = _make_pair(tmp_path)
        (dst / "old.txt").write_text("gone")
        actions = compare_trees(src, dst)
        execute_sync(actions, src, dst)
        assert not (dst / "old.txt").exists()

    def test_update_file(self, tmp_path):
        """UPDATE action overwrites dest file with source content."""
        src, dst = _make_pair(tmp_path)
        (src / "f.txt").write_text("v2")
        (dst / "f.txt").write_text("v1")
        actions = compare_trees(src, dst)
        execute_sync(actions, src, dst)
        assert (dst / "f.txt").read_text() == "v2"

    def test_copy_creates_subdirs(self, tmp_path):
        """COPY into a nested path creates intermediate directories."""
        src, dst = _make_pair(tmp_path)
        sub = src / "a" / "b"
        sub.mkdir(parents=True)
        (sub / "deep.txt").write_text("deep")
        actions = compare_trees(src, dst)
        execute_sync(actions, src, dst)
        assert (dst / "a" / "b" / "deep.txt").read_text() == "deep"

    def test_full_sync_makes_trees_identical(self, tmp_path):
        """After execute, dest should be a mirror of source."""
        src, dst = _make_pair(tmp_path)
        # Build a complex source tree
        (src / "keep.txt").write_text("keep")
        (dst / "keep.txt").write_text("keep")
        (src / "mod.txt").write_text("new")
        (dst / "mod.txt").write_text("old")
        (src / "added.txt").write_text("added")
        (dst / "removed.txt").write_text("removed")
        sub = src / "sub"
        sub.mkdir()
        (sub / "nested.txt").write_text("nested")

        actions = compare_trees(src, dst)
        execute_sync(actions, src, dst)

        # Trees should now be identical
        assert compare_trees(src, dst) == []

    def test_execute_empty_actions(self, tmp_path):
        """Executing an empty action list is a no-op."""
        src, dst = _make_pair(tmp_path)
        (dst / "f.txt").write_text("keep")
        execute_sync([], src, dst)
        assert (dst / "f.txt").read_text() == "keep"

    def test_execute_returns_log(self, tmp_path):
        """execute_sync returns a log of what was done."""
        src, dst = _make_pair(tmp_path)
        (src / "new.txt").write_text("hello")
        actions = compare_trees(src, dst)
        log = execute_sync(actions, src, dst)
        assert len(log) == 1
        assert "Copied" in log[0]


# --- Cycle 6: CLI entry point ---

import subprocess
import sys

class TestCLI:
    """Test the CLI via subprocess to verify argument parsing and modes."""

    def _run(self, *args):
        """Run sync.py as a subprocess and return (returncode, stdout, stderr)."""
        result = subprocess.run(
            [sys.executable, "sync.py", *args],
            capture_output=True, text=True,
        )
        return result.returncode, result.stdout, result.stderr

    def test_dry_run_mode(self, tmp_path):
        src, dst = _make_pair(tmp_path)
        (src / "new.txt").write_text("data")
        rc, out, err = self._run("--dry-run", str(src), str(dst))
        assert rc == 0
        assert "COPY" in out
        assert "new.txt" in out
        # File should NOT have been created (dry run)
        assert not (dst / "new.txt").exists()

    def test_execute_mode(self, tmp_path):
        src, dst = _make_pair(tmp_path)
        (src / "new.txt").write_text("data")
        rc, out, err = self._run("--execute", str(src), str(dst))
        assert rc == 0
        assert "Copied" in out
        assert (dst / "new.txt").exists()

    def test_missing_args(self):
        rc, out, err = self._run()
        assert rc != 0

    def test_nonexistent_source(self, tmp_path):
        rc, out, err = self._run("--dry-run", str(tmp_path / "nope"), str(tmp_path))
        assert rc != 0
        assert "error" in err.lower() or "error" in out.lower()

    def test_default_is_dry_run(self, tmp_path):
        """Without --execute, the tool defaults to dry-run (no changes)."""
        src, dst = _make_pair(tmp_path)
        (src / "x.txt").write_text("x")
        rc, out, err = self._run(str(src), str(dst))
        assert rc == 0
        assert "COPY" in out
        assert not (dst / "x.txt").exists()
