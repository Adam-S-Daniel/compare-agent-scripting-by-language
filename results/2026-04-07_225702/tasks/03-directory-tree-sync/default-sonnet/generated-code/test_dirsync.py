"""
Directory Tree Sync - TDD Test Suite

Red/Green TDD approach:
1. Write a failing test
2. Write minimum code to pass
3. Refactor
Repeat for each feature.
"""

import hashlib
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# Import the module we're building (will fail until we create it)
from dirsync import (
    FileSystem,
    RealFileSystem,
    MockFileSystem,
    hash_file,
    scan_tree,
    compare_trees,
    generate_sync_plan,
    execute_sync,
    SyncAction,
    SyncPlan,
)


class TestHashFile(unittest.TestCase):
    """Tests for SHA-256 hashing of file contents."""

    def test_hash_returns_sha256_hex_string(self):
        """hash_file returns a 64-char hex string (SHA-256)."""
        fs = MockFileSystem({"file.txt": b"hello world"})
        result = hash_file(fs, "file.txt")
        expected = hashlib.sha256(b"hello world").hexdigest()
        self.assertEqual(result, expected)
        self.assertEqual(len(result), 64)

    def test_hash_differs_for_different_content(self):
        """Different content produces different hashes."""
        fs = MockFileSystem({
            "a.txt": b"content A",
            "b.txt": b"content B",
        })
        self.assertNotEqual(hash_file(fs, "a.txt"), hash_file(fs, "b.txt"))

    def test_hash_same_for_identical_content(self):
        """Same content in different files produces the same hash."""
        fs = MockFileSystem({
            "a.txt": b"same content",
            "b.txt": b"same content",
        })
        self.assertEqual(hash_file(fs, "a.txt"), hash_file(fs, "b.txt"))

    def test_hash_missing_file_raises(self):
        """Hashing a non-existent file raises FileNotFoundError."""
        fs = MockFileSystem({})
        with self.assertRaises(FileNotFoundError):
            hash_file(fs, "missing.txt")


class TestScanTree(unittest.TestCase):
    """Tests for scanning a directory tree into a flat path->hash map."""

    def test_scan_empty_directory(self):
        """Scanning an empty directory returns an empty dict."""
        # Explicitly register the root so MockFileSystem knows it exists.
        fs = MockFileSystem({}, dirs={"/root"})
        result = scan_tree(fs, "/root")
        self.assertEqual(result, {})

    def test_scan_flat_directory(self):
        """Scanning a flat directory returns relative paths and hashes."""
        fs = MockFileSystem({
            "/root/a.txt": b"aaa",
            "/root/b.txt": b"bbb",
        })
        result = scan_tree(fs, "/root")
        self.assertIn("a.txt", result)
        self.assertIn("b.txt", result)
        self.assertEqual(result["a.txt"], hashlib.sha256(b"aaa").hexdigest())
        self.assertEqual(result["b.txt"], hashlib.sha256(b"bbb").hexdigest())

    def test_scan_nested_directory(self):
        """Scanning a nested directory returns relative paths with subdirs."""
        fs = MockFileSystem({
            "/root/a.txt": b"aaa",
            "/root/sub/b.txt": b"bbb",
            "/root/sub/deep/c.txt": b"ccc",
        })
        result = scan_tree(fs, "/root")
        self.assertIn("a.txt", result)
        self.assertIn("sub/b.txt", result)
        self.assertIn("sub/deep/c.txt", result)

    def test_scan_nonexistent_root_raises(self):
        """Scanning a non-existent directory raises an error."""
        fs = MockFileSystem({})
        with self.assertRaises(FileNotFoundError):
            scan_tree(fs, "/nonexistent")


class TestCompareTrees(unittest.TestCase):
    """Tests for comparing two scanned trees."""

    def test_identical_trees_no_differences(self):
        """Two identical trees produce no differences."""
        tree = {"a.txt": "hash1", "b.txt": "hash2"}
        result = compare_trees(tree, tree)
        self.assertEqual(result["only_in_src"], [])
        self.assertEqual(result["only_in_dst"], [])
        self.assertEqual(result["modified"], [])
        self.assertEqual(result["identical"], ["a.txt", "b.txt"])

    def test_file_only_in_source(self):
        """File in source but not destination is flagged as only_in_src."""
        src = {"a.txt": "hash1", "new.txt": "hash3"}
        dst = {"a.txt": "hash1"}
        result = compare_trees(src, dst)
        self.assertIn("new.txt", result["only_in_src"])
        self.assertEqual(result["only_in_dst"], [])
        self.assertEqual(result["modified"], [])

    def test_file_only_in_destination(self):
        """File in destination but not source is flagged as only_in_dst."""
        src = {"a.txt": "hash1"}
        dst = {"a.txt": "hash1", "extra.txt": "hash4"}
        result = compare_trees(src, dst)
        self.assertIn("extra.txt", result["only_in_dst"])
        self.assertEqual(result["only_in_src"], [])
        self.assertEqual(result["modified"], [])

    def test_modified_file(self):
        """File with same path but different hash is flagged as modified."""
        src = {"a.txt": "hash_v1"}
        dst = {"a.txt": "hash_v2"}
        result = compare_trees(src, dst)
        self.assertIn("a.txt", result["modified"])
        self.assertEqual(result["only_in_src"], [])
        self.assertEqual(result["only_in_dst"], [])

    def test_mixed_differences(self):
        """Mixed scenario with all types of differences."""
        src = {"common.txt": "same", "modified.txt": "v1", "src_only.txt": "h1"}
        dst = {"common.txt": "same", "modified.txt": "v2", "dst_only.txt": "h2"}
        result = compare_trees(src, dst)
        self.assertEqual(result["identical"], ["common.txt"])
        self.assertEqual(result["modified"], ["modified.txt"])
        self.assertEqual(result["only_in_src"], ["src_only.txt"])
        self.assertEqual(result["only_in_dst"], ["dst_only.txt"])


class TestGenerateSyncPlan(unittest.TestCase):
    """Tests for generating a sync plan from comparison results."""

    def _make_diff(self, only_in_src=None, only_in_dst=None, modified=None, identical=None):
        return {
            "only_in_src": only_in_src or [],
            "only_in_dst": only_in_dst or [],
            "modified": modified or [],
            "identical": identical or [],
        }

    def test_copy_files_only_in_src(self):
        """Files only in source get a COPY action."""
        diff = self._make_diff(only_in_src=["new.txt"])
        plan = generate_sync_plan(diff)
        copy_actions = [a for a in plan.actions if a.action == "COPY"]
        self.assertEqual(len(copy_actions), 1)
        self.assertEqual(copy_actions[0].path, "new.txt")

    def test_delete_files_only_in_dst(self):
        """Files only in destination get a DELETE action."""
        diff = self._make_diff(only_in_dst=["old.txt"])
        plan = generate_sync_plan(diff)
        delete_actions = [a for a in plan.actions if a.action == "DELETE"]
        self.assertEqual(len(delete_actions), 1)
        self.assertEqual(delete_actions[0].path, "old.txt")

    def test_update_modified_files(self):
        """Modified files get an UPDATE action."""
        diff = self._make_diff(modified=["changed.txt"])
        plan = generate_sync_plan(diff)
        update_actions = [a for a in plan.actions if a.action == "UPDATE"]
        self.assertEqual(len(update_actions), 1)
        self.assertEqual(update_actions[0].path, "changed.txt")

    def test_identical_files_no_action(self):
        """Identical files produce no actions."""
        diff = self._make_diff(identical=["same.txt"])
        plan = generate_sync_plan(diff)
        self.assertEqual(len(plan.actions), 0)

    def test_plan_summary(self):
        """Plan summary accurately counts each action type."""
        diff = self._make_diff(
            only_in_src=["a.txt", "b.txt"],
            only_in_dst=["c.txt"],
            modified=["d.txt"],
        )
        plan = generate_sync_plan(diff)
        self.assertEqual(plan.summary["copies"], 2)
        self.assertEqual(plan.summary["deletes"], 1)
        self.assertEqual(plan.summary["updates"], 1)


class TestExecuteSync(unittest.TestCase):
    """Tests for executing a sync plan against a mock filesystem."""

    def _make_plan(self, actions):
        plan = SyncPlan(actions=actions, summary={})
        return plan

    def test_dry_run_does_not_modify_filesystem(self):
        """Dry-run mode reports actions but does not touch the filesystem."""
        fs = MockFileSystem({
            "/src/new.txt": b"hello",
        })
        actions = [SyncAction(action="COPY", path="new.txt")]
        plan = self._make_plan(actions)

        report = execute_sync(fs, plan, src_root="/src", dst_root="/dst", dry_run=True)

        # Destination should not have been created
        self.assertFalse(fs.exists("/dst/new.txt"))
        self.assertEqual(len(report), 1)
        self.assertEqual(report[0]["action"], "COPY")
        self.assertEqual(report[0]["status"], "dry-run")

    def test_execute_copy_creates_file_in_dst(self):
        """Execute mode copies a file from src to dst."""
        fs = MockFileSystem({
            "/src/new.txt": b"hello",
        })
        actions = [SyncAction(action="COPY", path="new.txt")]
        plan = self._make_plan(actions)

        execute_sync(fs, plan, src_root="/src", dst_root="/dst", dry_run=False)

        self.assertTrue(fs.exists("/dst/new.txt"))
        self.assertEqual(fs.read("/dst/new.txt"), b"hello")

    def test_execute_delete_removes_file_from_dst(self):
        """Execute mode deletes a file from dst."""
        fs = MockFileSystem({
            "/dst/old.txt": b"stale",
        })
        actions = [SyncAction(action="DELETE", path="old.txt")]
        plan = self._make_plan(actions)

        execute_sync(fs, plan, src_root="/src", dst_root="/dst", dry_run=False)

        self.assertFalse(fs.exists("/dst/old.txt"))

    def test_execute_update_overwrites_file_in_dst(self):
        """Execute mode updates (overwrites) a file in dst with src content."""
        fs = MockFileSystem({
            "/src/file.txt": b"new content",
            "/dst/file.txt": b"old content",
        })
        actions = [SyncAction(action="UPDATE", path="file.txt")]
        plan = self._make_plan(actions)

        execute_sync(fs, plan, src_root="/src", dst_root="/dst", dry_run=False)

        self.assertEqual(fs.read("/dst/file.txt"), b"new content")

    def test_execute_copy_creates_nested_directories(self):
        """Execute mode creates parent directories when copying nested files."""
        fs = MockFileSystem({
            "/src/sub/deep/file.txt": b"deep file",
        })
        actions = [SyncAction(action="COPY", path="sub/deep/file.txt")]
        plan = self._make_plan(actions)

        execute_sync(fs, plan, src_root="/src", dst_root="/dst", dry_run=False)

        self.assertTrue(fs.exists("/dst/sub/deep/file.txt"))
        self.assertEqual(fs.read("/dst/sub/deep/file.txt"), b"deep file")

    def test_execute_returns_report_with_done_status(self):
        """Execute mode returns a report with 'done' status for each action."""
        fs = MockFileSystem({
            "/src/a.txt": b"content",
        })
        actions = [SyncAction(action="COPY", path="a.txt")]
        plan = self._make_plan(actions)

        report = execute_sync(fs, plan, src_root="/src", dst_root="/dst", dry_run=False)

        self.assertEqual(report[0]["status"], "done")


class TestRealFileSystem(unittest.TestCase):
    """Integration tests using RealFileSystem with a temp directory."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.src = os.path.join(self.tmp, "src")
        self.dst = os.path.join(self.tmp, "dst")
        os.makedirs(self.src)
        os.makedirs(self.dst)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def _write(self, path, content):
        full = os.path.join(self.tmp, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        Path(full).write_bytes(content)

    def test_real_end_to_end_sync(self):
        """Full end-to-end test using real filesystem in temp dirs."""
        self._write("src/keep.txt", b"same")
        self._write("src/update.txt", b"new version")
        self._write("src/new_file.txt", b"brand new")
        self._write("dst/keep.txt", b"same")
        self._write("dst/update.txt", b"old version")
        self._write("dst/to_delete.txt", b"should be gone")

        fs = RealFileSystem()
        src_tree = scan_tree(fs, self.src)
        dst_tree = scan_tree(fs, self.dst)
        diff = compare_trees(src_tree, dst_tree)
        plan = generate_sync_plan(diff)
        execute_sync(fs, plan, src_root=self.src, dst_root=self.dst, dry_run=False)

        # new_file.txt copied
        self.assertTrue(os.path.exists(os.path.join(self.dst, "new_file.txt")))
        # update.txt updated
        self.assertEqual(Path(os.path.join(self.dst, "update.txt")).read_bytes(), b"new version")
        # to_delete.txt removed
        self.assertFalse(os.path.exists(os.path.join(self.dst, "to_delete.txt")))
        # keep.txt untouched
        self.assertEqual(Path(os.path.join(self.dst, "keep.txt")).read_bytes(), b"same")


if __name__ == "__main__":
    unittest.main(verbosity=2)
