"""
TDD test suite for directory tree sync tool.

Approach:
- Use unittest with mock filesystem (tmp_dir fixtures) for all file operations
- Tests are grouped by feature: hashing, tree comparison, sync plan, dry-run, execute
- Each test was written BEFORE its corresponding implementation (red/green TDD)
"""

import hashlib
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock, call

# Import the module under test
import dirsync
from dirsync import (
    compute_sha256,
    build_file_index,
    compare_trees,
    generate_sync_plan,
    execute_sync_plan,
    SyncAction,
    SyncPlan,
)


# ─────────────────────────────────────────────
# Fixtures / helpers
# ─────────────────────────────────────────────

def make_temp_tree(files: dict) -> Path:
    """
    Create a temporary directory tree from a dict mapping
    relative path -> file content (str or bytes).
    Returns the root Path.
    """
    root = Path(tempfile.mkdtemp())
    for rel_path, content in files.items():
        full = root / rel_path
        full.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, str):
            full.write_text(content, encoding="utf-8")
        else:
            full.write_bytes(content)
    return root


# ─────────────────────────────────────────────
# 1. SHA-256 hashing
# ─────────────────────────────────────────────

class TestComputeSha256(unittest.TestCase):
    """compute_sha256(path) returns the hex SHA-256 of a file's contents."""

    def test_known_content(self):
        """Hash of a file with known content must match manual calculation."""
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt") as f:
            f.write(b"hello world")
            tmp = f.name
        try:
            expected = hashlib.sha256(b"hello world").hexdigest()
            self.assertEqual(compute_sha256(Path(tmp)), expected)
        finally:
            os.unlink(tmp)

    def test_empty_file(self):
        """Empty file has a deterministic SHA-256."""
        with tempfile.NamedTemporaryFile(delete=False) as f:
            tmp = f.name
        try:
            expected = hashlib.sha256(b"").hexdigest()
            self.assertEqual(compute_sha256(Path(tmp)), expected)
        finally:
            os.unlink(tmp)

    def test_binary_content(self):
        """Binary data is hashed correctly."""
        data = bytes(range(256))
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(data)
            tmp = f.name
        try:
            expected = hashlib.sha256(data).hexdigest()
            self.assertEqual(compute_sha256(Path(tmp)), expected)
        finally:
            os.unlink(tmp)

    def test_missing_file_raises(self):
        """FileNotFoundError with a clear message for missing paths."""
        with self.assertRaises(FileNotFoundError) as ctx:
            compute_sha256(Path("/nonexistent/path/file.txt"))
        self.assertIn("/nonexistent/path/file.txt", str(ctx.exception))


# ─────────────────────────────────────────────
# 2. Building a file index
# ─────────────────────────────────────────────

class TestBuildFileIndex(unittest.TestCase):
    """build_file_index(root) returns {relative_path: sha256_hex} for every file."""

    def setUp(self):
        self.root = make_temp_tree({
            "a.txt": "alpha",
            "sub/b.txt": "beta",
            "sub/deep/c.txt": "gamma",
        })

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_returns_all_files(self):
        index = build_file_index(self.root)
        self.assertSetEqual(
            set(index.keys()),
            {"a.txt", "sub/b.txt", "sub/deep/c.txt"},
        )

    def test_hashes_are_correct(self):
        index = build_file_index(self.root)
        expected = hashlib.sha256(b"alpha").hexdigest()
        self.assertEqual(index["a.txt"], expected)

    def test_empty_directory(self):
        root = Path(tempfile.mkdtemp())
        try:
            self.assertEqual(build_file_index(root), {})
        finally:
            shutil.rmtree(root)

    def test_missing_root_raises(self):
        with self.assertRaises(FileNotFoundError):
            build_file_index(Path("/no/such/dir"))

    def test_paths_use_forward_slashes(self):
        """Relative paths must use '/' as separator regardless of OS."""
        index = build_file_index(self.root)
        for key in index:
            self.assertNotIn("\\", key)


# ─────────────────────────────────────────────
# 3. Comparing two trees
# ─────────────────────────────────────────────

class TestCompareTrees(unittest.TestCase):
    """compare_trees(src_root, dst_root) returns a dict with three categories."""

    def setUp(self):
        # source has: same.txt (identical), changed.txt (different), src_only.txt
        self.src = make_temp_tree({
            "same.txt": "identical content",
            "changed.txt": "source version",
            "src_only.txt": "only in source",
            "sub/nested.txt": "nested file",
        })
        # destination has: same.txt (identical), changed.txt (different), dst_only.txt
        self.dst = make_temp_tree({
            "same.txt": "identical content",
            "changed.txt": "destination version",
            "dst_only.txt": "only in destination",
            "sub/nested.txt": "nested file",
        })

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.dst)

    def test_identifies_identical_files(self):
        result = compare_trees(self.src, self.dst)
        self.assertIn("same.txt", result["identical"])
        self.assertIn("sub/nested.txt", result["identical"])

    def test_identifies_changed_files(self):
        result = compare_trees(self.src, self.dst)
        self.assertIn("changed.txt", result["changed"])

    def test_identifies_src_only_files(self):
        result = compare_trees(self.src, self.dst)
        self.assertIn("src_only.txt", result["src_only"])

    def test_identifies_dst_only_files(self):
        result = compare_trees(self.src, self.dst)
        self.assertIn("dst_only.txt", result["dst_only"])

    def test_no_false_positives_in_identical(self):
        result = compare_trees(self.src, self.dst)
        self.assertNotIn("changed.txt", result["identical"])
        self.assertNotIn("src_only.txt", result["identical"])

    def test_both_empty(self):
        empty_a = Path(tempfile.mkdtemp())
        empty_b = Path(tempfile.mkdtemp())
        try:
            result = compare_trees(empty_a, empty_b)
            self.assertEqual(result["identical"], [])
            self.assertEqual(result["changed"], [])
            self.assertEqual(result["src_only"], [])
            self.assertEqual(result["dst_only"], [])
        finally:
            shutil.rmtree(empty_a)
            shutil.rmtree(empty_b)


# ─────────────────────────────────────────────
# 4. Generating a sync plan
# ─────────────────────────────────────────────

class TestGenerateSyncPlan(unittest.TestCase):
    """generate_sync_plan(comparison) returns a SyncPlan (list of SyncAction)."""

    def setUp(self):
        self.comparison = {
            "identical": ["same.txt"],
            "changed": ["changed.txt"],
            "src_only": ["new_file.txt"],
            "dst_only": ["orphan.txt"],
        }

    def test_copy_for_src_only(self):
        """Files only in source should be COPY actions."""
        plan = generate_sync_plan(self.comparison)
        copy_actions = [a for a in plan if a.action == "COPY"]
        paths = [a.path for a in copy_actions]
        self.assertIn("new_file.txt", paths)

    def test_update_for_changed(self):
        """Files that differ should be UPDATE actions."""
        plan = generate_sync_plan(self.comparison)
        update_actions = [a for a in plan if a.action == "UPDATE"]
        paths = [a.path for a in update_actions]
        self.assertIn("changed.txt", paths)

    def test_delete_for_dst_only(self):
        """Files only in destination should be DELETE actions."""
        plan = generate_sync_plan(self.comparison)
        delete_actions = [a for a in plan if a.action == "DELETE"]
        paths = [a.path for a in delete_actions]
        self.assertIn("orphan.txt", paths)

    def test_no_action_for_identical(self):
        """Identical files must produce no sync action."""
        plan = generate_sync_plan(self.comparison)
        all_paths = [a.path for a in plan]
        self.assertNotIn("same.txt", all_paths)

    def test_empty_comparison(self):
        """An all-identical, all-empty comparison yields an empty plan."""
        plan = generate_sync_plan(
            {"identical": ["x.txt"], "changed": [], "src_only": [], "dst_only": []}
        )
        self.assertEqual(plan, [])

    def test_plan_is_list_of_sync_actions(self):
        plan = generate_sync_plan(self.comparison)
        for item in plan:
            self.assertIsInstance(item, SyncAction)


# ─────────────────────────────────────────────
# 5. SyncAction / SyncPlan data types
# ─────────────────────────────────────────────

class TestSyncActionDatatype(unittest.TestCase):
    def test_fields(self):
        a = SyncAction(action="COPY", path="foo/bar.txt")
        self.assertEqual(a.action, "COPY")
        self.assertEqual(a.path, "foo/bar.txt")

    def test_repr_contains_action_and_path(self):
        a = SyncAction(action="DELETE", path="baz.txt")
        r = repr(a)
        self.assertIn("DELETE", r)
        self.assertIn("baz.txt", r)


# ─────────────────────────────────────────────
# 6. Dry-run mode
# ─────────────────────────────────────────────

class TestDryRun(unittest.TestCase):
    """In dry-run mode, execute_sync_plan reports actions without touching files."""

    def setUp(self):
        self.src = make_temp_tree({
            "new.txt": "brand new",
            "changed.txt": "source version",
        })
        self.dst = make_temp_tree({
            "changed.txt": "old version",
            "orphan.txt": "to be deleted",
        })

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.dst)

    def test_no_files_modified_in_dry_run(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        execute_sync_plan(plan, self.src, self.dst, dry_run=True)

        # orphan.txt must still exist in dst
        self.assertTrue((self.dst / "orphan.txt").exists())
        # new.txt must NOT have been copied to dst
        self.assertFalse((self.dst / "new.txt").exists())
        # changed.txt in dst must still have original content
        self.assertEqual((self.dst / "changed.txt").read_text(), "old version")

    def test_dry_run_returns_report(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        report = execute_sync_plan(plan, self.src, self.dst, dry_run=True)
        # Report must mention all planned actions
        self.assertIn("new.txt", report)
        self.assertIn("changed.txt", report)
        self.assertIn("orphan.txt", report)


# ─────────────────────────────────────────────
# 7. Execute mode
# ─────────────────────────────────────────────

class TestExecuteMode(unittest.TestCase):
    """In execute mode, execute_sync_plan actually modifies the destination tree."""

    def setUp(self):
        self.src = make_temp_tree({
            "new.txt": "brand new",
            "sub/nested_new.txt": "nested brand new",
            "changed.txt": "source version",
        })
        self.dst = make_temp_tree({
            "changed.txt": "old version",
            "orphan.txt": "to be deleted",
        })

    def tearDown(self):
        shutil.rmtree(self.src)
        shutil.rmtree(self.dst)

    def test_copy_creates_file_in_dst(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        execute_sync_plan(plan, self.src, self.dst, dry_run=False)
        self.assertTrue((self.dst / "new.txt").exists())
        self.assertEqual((self.dst / "new.txt").read_text(), "brand new")

    def test_copy_creates_nested_dirs(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        execute_sync_plan(plan, self.src, self.dst, dry_run=False)
        self.assertTrue((self.dst / "sub" / "nested_new.txt").exists())

    def test_update_overwrites_file_in_dst(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        execute_sync_plan(plan, self.src, self.dst, dry_run=False)
        self.assertEqual((self.dst / "changed.txt").read_text(), "source version")

    def test_delete_removes_file_from_dst(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        execute_sync_plan(plan, self.src, self.dst, dry_run=False)
        self.assertFalse((self.dst / "orphan.txt").exists())

    def test_execute_returns_report(self):
        comparison = compare_trees(self.src, self.dst)
        plan = generate_sync_plan(comparison)
        report = execute_sync_plan(plan, self.src, self.dst, dry_run=False)
        self.assertIsInstance(report, str)
        self.assertGreater(len(report), 0)

    def test_identical_files_untouched(self):
        """Files not in the plan should not be touched."""
        src = make_temp_tree({"same.txt": "same content"})
        dst = make_temp_tree({"same.txt": "same content"})
        try:
            comparison = compare_trees(src, dst)
            plan = generate_sync_plan(comparison)
            self.assertEqual(plan, [])  # nothing to do
            execute_sync_plan(plan, src, dst, dry_run=False)
            self.assertEqual((dst / "same.txt").read_text(), "same content")
        finally:
            shutil.rmtree(src)
            shutil.rmtree(dst)


# ─────────────────────────────────────────────
# 8. Error handling
# ─────────────────────────────────────────────

class TestErrorHandling(unittest.TestCase):
    def test_compare_missing_src_raises(self):
        dst = Path(tempfile.mkdtemp())
        try:
            with self.assertRaises(FileNotFoundError) as ctx:
                compare_trees(Path("/no/src"), dst)
            self.assertIn("/no/src", str(ctx.exception))
        finally:
            shutil.rmtree(dst)

    def test_compare_missing_dst_raises(self):
        src = Path(tempfile.mkdtemp())
        try:
            with self.assertRaises(FileNotFoundError) as ctx:
                compare_trees(src, Path("/no/dst"))
            self.assertIn("/no/dst", str(ctx.exception))
        finally:
            shutil.rmtree(src)

    def test_execute_missing_src_raises(self):
        plan = [SyncAction(action="COPY", path="x.txt")]
        dst = Path(tempfile.mkdtemp())
        try:
            with self.assertRaises(FileNotFoundError):
                execute_sync_plan(plan, Path("/no/src"), dst, dry_run=False)
        finally:
            shutil.rmtree(dst)


if __name__ == "__main__":
    unittest.main(verbosity=2)
