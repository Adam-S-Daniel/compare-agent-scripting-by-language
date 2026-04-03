#!/usr/bin/env python3
"""Tests for directory tree sync tool — built with red/green TDD.

Each test class represents one TDD cycle. Tests were written first (RED),
then the minimum code to pass was implemented (GREEN), then refactored.

Run with: python3 test_dirsync.py -v
"""

import os
import shutil
import tempfile
import unittest

# ---------------------------------------------------------------------------
# Helpers: create mock directory structures for testing
# ---------------------------------------------------------------------------

def make_tree(base, spec):
    """Build a directory tree from a dict spec.

    Keys ending with '/' create sub-directories; other keys create files
    with the value as content.  Nested dicts recurse into sub-dirs.

    Example:
        make_tree("/tmp/x", {
            "a.txt": "hello",
            "sub/": {"b.txt": "world"},
        })
    Creates /tmp/x/a.txt and /tmp/x/sub/b.txt.
    """
    os.makedirs(base, exist_ok=True)
    for name, content in spec.items():
        path = os.path.join(base, name.rstrip("/"))
        if isinstance(content, dict):
            make_tree(path, content)
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(content)


# ===========================================================================
# TDD Cycle 1 — SHA-256 file hashing
# ===========================================================================

class TestHashFile(unittest.TestCase):
    """Verify that hash_file returns correct SHA-256 hex digests."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_hash_known_content(self):
        """A file with known content should produce the expected SHA-256."""
        from dirsync import hash_file
        path = os.path.join(self.tmp, "hello.txt")
        with open(path, "w") as f:
            f.write("hello\n")
        expected = "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
        self.assertEqual(hash_file(path), expected)

    def test_different_content_different_hash(self):
        from dirsync import hash_file
        p1 = os.path.join(self.tmp, "a.txt")
        p2 = os.path.join(self.tmp, "b.txt")
        with open(p1, "w") as f:
            f.write("alpha")
        with open(p2, "w") as f:
            f.write("beta")
        self.assertNotEqual(hash_file(p1), hash_file(p2))

    def test_same_content_same_hash(self):
        from dirsync import hash_file
        p1 = os.path.join(self.tmp, "a.txt")
        p2 = os.path.join(self.tmp, "b.txt")
        for p in (p1, p2):
            with open(p, "w") as f:
                f.write("same content")
        self.assertEqual(hash_file(p1), hash_file(p2))

    def test_hash_nonexistent_file_raises(self):
        """Hashing a missing file should raise FileNotFoundError."""
        from dirsync import hash_file
        with self.assertRaises(FileNotFoundError):
            hash_file(os.path.join(self.tmp, "nope.txt"))


# ===========================================================================
# TDD Cycle 2 — Scanning a directory tree
# ===========================================================================

class TestScanTree(unittest.TestCase):
    """scan_tree should return {relative_path: sha256_hash} for every file."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_flat_directory(self):
        """Scanning a flat directory returns all files with correct rel paths."""
        from dirsync import scan_tree
        make_tree(self.tmp, {"a.txt": "aaa", "b.txt": "bbb"})
        result = scan_tree(self.tmp)
        self.assertEqual(set(result.keys()), {"a.txt", "b.txt"})
        # Values should be hex strings of length 64 (SHA-256)
        for v in result.values():
            self.assertEqual(len(v), 64)

    def test_nested_directory(self):
        """Scanning nested dirs uses forward-slash relative paths."""
        from dirsync import scan_tree
        make_tree(self.tmp, {
            "top.txt": "top",
            "sub/": {"deep.txt": "deep"},
        })
        result = scan_tree(self.tmp)
        self.assertIn("top.txt", result)
        # Relative path uses os.sep (forward slash on Linux)
        self.assertIn(os.path.join("sub", "deep.txt"), result)

    def test_empty_directory(self):
        """Scanning an empty directory returns an empty dict."""
        from dirsync import scan_tree
        empty = os.path.join(self.tmp, "empty")
        os.makedirs(empty)
        self.assertEqual(scan_tree(empty), {})

    def test_nonexistent_directory_raises(self):
        """Scanning a path that doesn't exist should raise a clear error."""
        from dirsync import scan_tree
        with self.assertRaises(FileNotFoundError):
            scan_tree(os.path.join(self.tmp, "nope"))


# ===========================================================================
# TDD Cycle 3 — Comparing two directory trees
# ===========================================================================

class TestCompare(unittest.TestCase):
    """compare_trees should classify files into categories."""

    def setUp(self):
        self.src = tempfile.mkdtemp()
        self.dst = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.dst)

    def test_identical_trees(self):
        """Identical trees → no differences."""
        from dirsync import compare_trees
        spec = {"a.txt": "hello", "b.txt": "world"}
        make_tree(self.src, spec)
        make_tree(self.dst, spec)
        diff = compare_trees(self.src, self.dst)
        self.assertEqual(diff.only_in_source, [])
        self.assertEqual(diff.only_in_dest, [])
        self.assertEqual(diff.content_differs, [])

    def test_file_only_in_source(self):
        """A file in source but not dest is reported as only_in_source."""
        from dirsync import compare_trees
        make_tree(self.src, {"a.txt": "aaa", "extra.txt": "extra"})
        make_tree(self.dst, {"a.txt": "aaa"})
        diff = compare_trees(self.src, self.dst)
        self.assertEqual(sorted(diff.only_in_source), ["extra.txt"])
        self.assertEqual(diff.only_in_dest, [])
        self.assertEqual(diff.content_differs, [])

    def test_file_only_in_dest(self):
        """A file in dest but not source is reported as only_in_dest."""
        from dirsync import compare_trees
        make_tree(self.src, {"a.txt": "aaa"})
        make_tree(self.dst, {"a.txt": "aaa", "orphan.txt": "orphan"})
        diff = compare_trees(self.src, self.dst)
        self.assertEqual(diff.only_in_source, [])
        self.assertEqual(sorted(diff.only_in_dest), ["orphan.txt"])

    def test_content_differs(self):
        """Same filename, different content → content_differs."""
        from dirsync import compare_trees
        make_tree(self.src, {"f.txt": "version-1"})
        make_tree(self.dst, {"f.txt": "version-2"})
        diff = compare_trees(self.src, self.dst)
        self.assertEqual(diff.content_differs, ["f.txt"])

    def test_mixed_differences(self):
        """A realistic scenario with all three kinds of difference."""
        from dirsync import compare_trees
        make_tree(self.src, {
            "same.txt": "ok",
            "changed.txt": "src-v",
            "src_only.txt": "s",
            "sub/": {"nested.txt": "n-src"},
        })
        make_tree(self.dst, {
            "same.txt": "ok",
            "changed.txt": "dst-v",
            "dst_only.txt": "d",
            "sub/": {"nested.txt": "n-dst"},
        })
        diff = compare_trees(self.src, self.dst)
        self.assertEqual(sorted(diff.only_in_source), ["src_only.txt"])
        self.assertEqual(sorted(diff.only_in_dest), ["dst_only.txt"])
        self.assertEqual(sorted(diff.content_differs),
                         ["changed.txt", os.path.join("sub", "nested.txt")])


# ===========================================================================
# TDD Cycle 4 — Sync plan generation (dry-run mode)
# ===========================================================================

class TestSyncPlan(unittest.TestCase):
    """generate_sync_plan should produce a list of planned operations."""

    def setUp(self):
        self.src = tempfile.mkdtemp()
        self.dst = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.dst)

    def test_plan_copy_new_files(self):
        """Files only in source should produce COPY actions."""
        from dirsync import generate_sync_plan
        make_tree(self.src, {"new.txt": "data"})
        make_tree(self.dst, {})
        plan = generate_sync_plan(self.src, self.dst)
        copy_actions = [a for a in plan if a["action"] == "COPY"]
        self.assertEqual(len(copy_actions), 1)
        self.assertEqual(copy_actions[0]["path"], "new.txt")

    def test_plan_update_changed_files(self):
        """Files with different content should produce UPDATE actions."""
        from dirsync import generate_sync_plan
        make_tree(self.src, {"f.txt": "new"})
        make_tree(self.dst, {"f.txt": "old"})
        plan = generate_sync_plan(self.src, self.dst)
        update_actions = [a for a in plan if a["action"] == "UPDATE"]
        self.assertEqual(len(update_actions), 1)
        self.assertEqual(update_actions[0]["path"], "f.txt")

    def test_plan_delete_orphan_files(self):
        """Files only in dest should produce DELETE actions."""
        from dirsync import generate_sync_plan
        make_tree(self.src, {})
        make_tree(self.dst, {"orphan.txt": "bye"})
        plan = generate_sync_plan(self.src, self.dst)
        del_actions = [a for a in plan if a["action"] == "DELETE"]
        self.assertEqual(len(del_actions), 1)
        self.assertEqual(del_actions[0]["path"], "orphan.txt")

    def test_plan_no_action_for_identical(self):
        """Identical files should not generate any actions."""
        from dirsync import generate_sync_plan
        spec = {"same.txt": "identical"}
        make_tree(self.src, spec)
        make_tree(self.dst, spec)
        plan = generate_sync_plan(self.src, self.dst)
        self.assertEqual(plan, [])

    def test_dry_run_returns_report(self):
        """dry_run should return a human-readable report string."""
        from dirsync import dry_run
        make_tree(self.src, {"new.txt": "data", "changed.txt": "v2"})
        make_tree(self.dst, {"changed.txt": "v1", "orphan.txt": "x"})
        report = dry_run(self.src, self.dst)
        # Report should mention all three action types
        self.assertIn("COPY", report)
        self.assertIn("UPDATE", report)
        self.assertIn("DELETE", report)
        self.assertIn("new.txt", report)
        self.assertIn("changed.txt", report)
        self.assertIn("orphan.txt", report)


# ===========================================================================
# TDD Cycle 5 — Execute mode (actually perform the sync)
# ===========================================================================

class TestExecuteSync(unittest.TestCase):
    """execute_sync should apply all planned operations to the destination."""

    def setUp(self):
        self.src = tempfile.mkdtemp()
        self.dst = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.dst)

    def test_copies_new_files(self):
        """New files in source are copied to dest."""
        from dirsync import execute_sync
        make_tree(self.src, {"new.txt": "hello"})
        make_tree(self.dst, {})
        execute_sync(self.src, self.dst)
        dst_file = os.path.join(self.dst, "new.txt")
        self.assertTrue(os.path.exists(dst_file))
        with open(dst_file) as f:
            self.assertEqual(f.read(), "hello")

    def test_updates_changed_files(self):
        """Changed files are overwritten with source content."""
        from dirsync import execute_sync
        make_tree(self.src, {"f.txt": "new-content"})
        make_tree(self.dst, {"f.txt": "old-content"})
        execute_sync(self.src, self.dst)
        with open(os.path.join(self.dst, "f.txt")) as f:
            self.assertEqual(f.read(), "new-content")

    def test_deletes_orphan_files(self):
        """Files only in dest are removed."""
        from dirsync import execute_sync
        make_tree(self.src, {"keep.txt": "keep"})
        make_tree(self.dst, {"keep.txt": "keep", "orphan.txt": "bye"})
        execute_sync(self.src, self.dst)
        self.assertFalse(os.path.exists(os.path.join(self.dst, "orphan.txt")))
        self.assertTrue(os.path.exists(os.path.join(self.dst, "keep.txt")))

    def test_creates_subdirectories_on_copy(self):
        """Copying into a new subdirectory creates the directory."""
        from dirsync import execute_sync
        make_tree(self.src, {"sub/": {"deep.txt": "deep"}})
        make_tree(self.dst, {})
        execute_sync(self.src, self.dst)
        expected = os.path.join(self.dst, "sub", "deep.txt")
        self.assertTrue(os.path.exists(expected))
        with open(expected) as f:
            self.assertEqual(f.read(), "deep")

    def test_full_sync_makes_trees_identical(self):
        """After execute_sync, dest should match source exactly."""
        from dirsync import scan_tree, execute_sync
        make_tree(self.src, {
            "a.txt": "aaa",
            "b.txt": "bbb",
            "d/": {"e.txt": "eee"},
        })
        make_tree(self.dst, {
            "a.txt": "old-a",
            "c.txt": "orphan",
        })
        execute_sync(self.src, self.dst)
        src_scan = scan_tree(self.src)
        dst_scan = scan_tree(self.dst)
        self.assertEqual(src_scan, dst_scan)

    def test_execute_returns_summary(self):
        """execute_sync should return a summary of what was done."""
        from dirsync import execute_sync
        make_tree(self.src, {"new.txt": "n", "upd.txt": "v2"})
        make_tree(self.dst, {"upd.txt": "v1", "del.txt": "d"})
        summary = execute_sync(self.src, self.dst)
        self.assertIn("copied", summary.lower())
        self.assertIn("updated", summary.lower())
        self.assertIn("deleted", summary.lower())


# ===========================================================================
# TDD Cycle 6 — Error handling
# ===========================================================================

class TestErrorHandling(unittest.TestCase):
    """Graceful error handling with meaningful messages."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_source_does_not_exist(self):
        """Syncing from a nonexistent source should raise FileNotFoundError."""
        from dirsync import execute_sync
        with self.assertRaises(FileNotFoundError) as ctx:
            execute_sync("/nonexistent/path/abc123", self.tmp)
        self.assertIn("source", str(ctx.exception).lower())

    def test_dest_does_not_exist(self):
        """Syncing to a nonexistent dest should raise FileNotFoundError."""
        from dirsync import execute_sync
        make_tree(self.tmp, {"a.txt": "a"})
        with self.assertRaises(FileNotFoundError) as ctx:
            execute_sync(self.tmp, "/nonexistent/path/abc123")
        self.assertIn("dest", str(ctx.exception).lower())

    def test_source_is_file_not_dir(self):
        """Source must be a directory, not a file."""
        from dirsync import execute_sync
        fpath = os.path.join(self.tmp, "file.txt")
        with open(fpath, "w") as f:
            f.write("x")
        dst = os.path.join(self.tmp, "dst")
        os.makedirs(dst)
        with self.assertRaises(NotADirectoryError):
            execute_sync(fpath, dst)

    def test_dry_run_nonexistent_source(self):
        """dry_run with missing source raises FileNotFoundError."""
        from dirsync import dry_run
        with self.assertRaises(FileNotFoundError):
            dry_run("/nonexistent/path/abc123", self.tmp)


if __name__ == "__main__":
    unittest.main()
