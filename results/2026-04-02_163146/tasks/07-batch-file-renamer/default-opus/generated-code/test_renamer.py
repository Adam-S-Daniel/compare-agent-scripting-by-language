"""
Batch File Renamer - Test Suite (TDD)

Tests are organized in the order they were developed using red/green TDD:
  1. Basic regex rename planning (compute what renames would happen)
  2. Preview mode (show changes without executing)
  3. Conflict detection (two files -> same target name)
  4. Undo script generation (reverse rename operations)
  5. Error handling (invalid regex, nonexistent directory, etc.)
  6. Actual file system renames with mock directories

Each section was written as a FAILING test first (RED), then the minimum
implementation was added to make it pass (GREEN), then refactored.
"""

import unittest
import os
import sys
import tempfile
import shutil
import stat

from renamer import BatchRenamer, RenameConflictError


# =============================================================================
# TDD CYCLE 1 — RED: Basic regex rename planning
# These tests verify that given a list of filenames and a regex pattern,
# we can compute the list of (old_name, new_name) rename operations.
# =============================================================================

class TestPlanRenames(unittest.TestCase):
    """Test the core rename planning logic (no filesystem interaction)."""

    def setUp(self):
        self.renamer = BatchRenamer()

    def test_simple_string_replacement(self):
        """Replace a literal substring in filenames."""
        files = ["report_2024.txt", "report_2025.txt", "readme.md"]
        result = self.renamer.plan_renames(files, r"report", "doc")
        self.assertEqual(result, [
            ("report_2024.txt", "doc_2024.txt"),
            ("report_2025.txt", "doc_2025.txt"),
        ])

    def test_regex_capture_group_replacement(self):
        """Support regex capture groups (\\1, \\2) in replacement string."""
        files = ["IMG_001.jpg", "IMG_002.jpg", "notes.txt"]
        result = self.renamer.plan_renames(files, r"IMG_(\d+)", r"photo_\1")
        self.assertEqual(result, [
            ("IMG_001.jpg", "photo_001.jpg"),
            ("IMG_002.jpg", "photo_002.jpg"),
        ])

    def test_no_matches_returns_empty_list(self):
        """When no files match the pattern, return an empty list."""
        files = ["hello.txt", "world.txt"]
        result = self.renamer.plan_renames(files, r"zzz", "aaa")
        self.assertEqual(result, [])

    def test_replaces_only_first_occurrence(self):
        """By default only the first regex match in a filename is replaced."""
        files = ["aa_bb_aa.txt"]
        result = self.renamer.plan_renames(files, r"aa", "xx")
        self.assertEqual(result, [("aa_bb_aa.txt", "xx_bb_aa.txt")])

    def test_extension_change(self):
        """Regex can target file extensions."""
        files = ["photo.jpeg", "image.jpeg", "doc.pdf"]
        result = self.renamer.plan_renames(files, r"\.jpeg$", ".jpg")
        self.assertEqual(result, [
            ("photo.jpeg", "photo.jpg"),
            ("image.jpeg", "image.jpg"),
        ])

    def test_complex_regex_with_multiple_groups(self):
        """Support complex regex patterns with multiple capture groups."""
        files = ["2024-01-15_report.txt", "2024-02-20_summary.txt"]
        # Swap date parts: YYYY-MM-DD -> DD.MM.YYYY
        result = self.renamer.plan_renames(
            files,
            r"(\d{4})-(\d{2})-(\d{2})_",
            r"\3.\2.\1_"
        )
        self.assertEqual(result, [
            ("2024-01-15_report.txt", "15.01.2024_report.txt"),
            ("2024-02-20_summary.txt", "20.02.2024_summary.txt"),
        ])

    def test_skips_files_where_result_is_unchanged(self):
        """If the regex matches but the replacement produces the same name, skip it."""
        files = ["abc.txt"]
        # Replace 'abc' with 'abc' — no actual change
        result = self.renamer.plan_renames(files, r"abc", "abc")
        self.assertEqual(result, [])


# =============================================================================
# TDD CYCLE 2 — RED: Preview mode
# Preview returns a human-readable summary of planned renames.
# =============================================================================

class TestPreviewMode(unittest.TestCase):
    """Test preview mode: show what would change without doing anything."""

    def setUp(self):
        self.renamer = BatchRenamer()

    def test_preview_returns_formatted_strings(self):
        """Preview should return a list of human-readable rename descriptions."""
        files = ["old_name.txt", "old_data.csv"]
        preview = self.renamer.preview(files, r"old", "new")
        self.assertEqual(preview, [
            "old_name.txt -> new_name.txt",
            "old_data.csv -> new_data.csv",
        ])

    def test_preview_with_no_matches(self):
        """Preview with no matches returns empty list."""
        files = ["hello.txt"]
        preview = self.renamer.preview(files, r"zzz", "aaa")
        self.assertEqual(preview, [])

    def test_preview_does_not_modify_input(self):
        """Preview must not mutate the input file list."""
        files = ["a.txt", "b.txt"]
        original = files.copy()
        self.renamer.preview(files, r"a", "x")
        self.assertEqual(files, original)


# =============================================================================
# TDD CYCLE 3 — RED: Conflict detection
# Detect when two source files would rename to the same target.
# =============================================================================

class TestConflictDetection(unittest.TestCase):
    """Test that conflicts (multiple files -> same target name) are detected."""

    def setUp(self):
        self.renamer = BatchRenamer()

    def test_detects_simple_conflict(self):
        """Two files that would get the same new name should raise an error."""
        # Both files become "file_x.txt" after removing the digit
        files = ["file_1.txt", "file_2.txt"]
        with self.assertRaises(RenameConflictError) as ctx:
            self.renamer.plan_renames(files, r"_\d", "_x")
        # The error should mention the conflicting target name
        self.assertIn("file_x.txt", str(ctx.exception))

    def test_no_conflict_when_targets_differ(self):
        """No error when all target names are unique."""
        files = ["a1.txt", "b2.txt"]
        # These produce different results
        result = self.renamer.plan_renames(files, r"(\w)(\d)", r"\1_\2")
        self.assertEqual(len(result), 2)

    def test_conflict_with_existing_unrenamed_file(self):
        """Conflict if a renamed file would clash with an existing file not being renamed."""
        # 'report.txt' doesn't match the pattern, but 'old_report.txt' -> 'report.txt'
        files = ["report.txt", "old_report.txt"]
        with self.assertRaises(RenameConflictError) as ctx:
            self.renamer.plan_renames(files, r"old_", "")
        self.assertIn("report.txt", str(ctx.exception))

    def test_conflict_message_lists_all_sources(self):
        """The conflict error should list which source files are involved."""
        files = ["cat_1.log", "cat_2.log"]
        with self.assertRaises(RenameConflictError) as ctx:
            self.renamer.plan_renames(files, r"_\d", "")
        error_msg = str(ctx.exception)
        self.assertIn("cat_1.log", error_msg)
        self.assertIn("cat_2.log", error_msg)


# =============================================================================
# TDD CYCLE 4 — RED: Undo script generation
# Generate a script/data structure that can reverse the renames.
# =============================================================================

class TestUndoGeneration(unittest.TestCase):
    """Test undo script/data generation to reverse renames."""

    def setUp(self):
        self.renamer = BatchRenamer()

    def test_generate_undo_plan(self):
        """Undo plan should be the reverse mapping of the rename plan."""
        files = ["a.txt", "b.txt"]
        plan = self.renamer.plan_renames(files, r"(a|b)", r"renamed_\1")
        undo = self.renamer.generate_undo(plan)
        self.assertEqual(undo, [
            ("renamed_a.txt", "a.txt"),
            ("renamed_b.txt", "b.txt"),
        ])

    def test_generate_undo_script_content(self):
        """Generate a shell script that undoes the renames."""
        files = ["old.txt"]
        plan = self.renamer.plan_renames(files, r"old", "new")
        script = self.renamer.generate_undo_script(plan)
        # The script should contain mv commands reversing each rename
        self.assertIn("mv", script)
        self.assertIn("new.txt", script)
        self.assertIn("old.txt", script)

    def test_undo_script_is_executable_shell(self):
        """The undo script should start with a shebang line."""
        plan = [("old.txt", "new.txt")]
        script = self.renamer.generate_undo_script(plan)
        self.assertTrue(script.startswith("#!/bin/bash"))

    def test_undo_script_has_safety_checks(self):
        """The undo script should use 'set -e' to stop on errors."""
        plan = [("old.txt", "new.txt")]
        script = self.renamer.generate_undo_script(plan)
        self.assertIn("set -e", script)

    def test_undo_empty_plan(self):
        """Undo of an empty plan is an empty list."""
        undo = self.renamer.generate_undo([])
        self.assertEqual(undo, [])


# =============================================================================
# TDD CYCLE 5 — RED: Error handling
# Invalid regex, empty file lists, etc.
# =============================================================================

class TestErrorHandling(unittest.TestCase):
    """Test graceful error handling with meaningful messages."""

    def setUp(self):
        self.renamer = BatchRenamer()

    def test_invalid_regex_raises_value_error(self):
        """An invalid regex pattern should raise ValueError with a helpful message."""
        files = ["test.txt"]
        with self.assertRaises(ValueError) as ctx:
            self.renamer.plan_renames(files, r"[invalid", "x")
        self.assertIn("Invalid regex pattern", str(ctx.exception))

    def test_empty_file_list(self):
        """Empty file list should return empty result, not error."""
        result = self.renamer.plan_renames([], r"a", "b")
        self.assertEqual(result, [])

    def test_scan_nonexistent_directory_raises_error(self):
        """Scanning a directory that doesn't exist should raise FileNotFoundError."""
        with self.assertRaises(FileNotFoundError) as ctx:
            self.renamer.scan_directory("/nonexistent/path/that/does/not/exist")
        self.assertIn("does not exist", str(ctx.exception))

    def test_empty_pattern_raises_value_error(self):
        """An empty regex pattern should raise ValueError."""
        files = ["test.txt"]
        with self.assertRaises(ValueError) as ctx:
            self.renamer.plan_renames(files, "", "replacement")
        self.assertIn("empty", str(ctx.exception).lower())


# =============================================================================
# TDD CYCLE 6 — RED: Actual filesystem renames with temp directories
# Use tempfile to create real directory structures for integration tests.
# =============================================================================

class TestFilesystemRenames(unittest.TestCase):
    """Integration tests: actually rename files on a temp filesystem."""

    def setUp(self):
        """Create a temporary directory with test files."""
        self.renamer = BatchRenamer()
        self.test_dir = tempfile.mkdtemp(prefix="renamer_test_")
        # Create test files
        for name in ["IMG_001.jpg", "IMG_002.jpg", "IMG_003.jpg", "readme.txt"]:
            open(os.path.join(self.test_dir, name), "w").close()

    def tearDown(self):
        """Remove the temporary directory."""
        shutil.rmtree(self.test_dir)

    def test_scan_directory_lists_files(self):
        """scan_directory should return sorted list of filenames in a directory."""
        files = self.renamer.scan_directory(self.test_dir)
        self.assertEqual(sorted(files), ["IMG_001.jpg", "IMG_002.jpg", "IMG_003.jpg", "readme.txt"])

    def test_scan_directory_excludes_subdirectories(self):
        """scan_directory should only list files, not subdirectories."""
        os.makedirs(os.path.join(self.test_dir, "subdir"))
        files = self.renamer.scan_directory(self.test_dir)
        self.assertNotIn("subdir", files)

    def test_execute_renames_files(self):
        """execute() should actually rename files on disk."""
        files = self.renamer.scan_directory(self.test_dir)
        plan = self.renamer.plan_renames(files, r"IMG_(\d+)", r"photo_\1")
        self.renamer.execute(self.test_dir, plan)

        after = sorted(os.listdir(self.test_dir))
        self.assertEqual(after, ["photo_001.jpg", "photo_002.jpg", "photo_003.jpg", "readme.txt"])

    def test_execute_returns_count_of_renames(self):
        """execute() should return the number of files renamed."""
        files = self.renamer.scan_directory(self.test_dir)
        plan = self.renamer.plan_renames(files, r"IMG_(\d+)", r"photo_\1")
        count = self.renamer.execute(self.test_dir, plan)
        self.assertEqual(count, 3)

    def test_execute_preserves_file_contents(self):
        """Renaming should preserve the content of files."""
        # Write content to a file
        filepath = os.path.join(self.test_dir, "IMG_001.jpg")
        with open(filepath, "w") as f:
            f.write("test content 123")

        files = self.renamer.scan_directory(self.test_dir)
        plan = self.renamer.plan_renames(files, r"IMG_(\d+)", r"photo_\1")
        self.renamer.execute(self.test_dir, plan)

        new_path = os.path.join(self.test_dir, "photo_001.jpg")
        with open(new_path) as f:
            self.assertEqual(f.read(), "test content 123")

    def test_execute_with_empty_plan(self):
        """execute() with empty plan should do nothing and return 0."""
        count = self.renamer.execute(self.test_dir, [])
        self.assertEqual(count, 0)
        # Files should be unchanged
        after = sorted(os.listdir(self.test_dir))
        self.assertEqual(after, ["IMG_001.jpg", "IMG_002.jpg", "IMG_003.jpg", "readme.txt"])

    def test_full_workflow_scan_plan_execute_undo(self):
        """End-to-end: scan, plan, execute, then undo via generated plan."""
        # Step 1: Scan and plan
        files = self.renamer.scan_directory(self.test_dir)
        plan = self.renamer.plan_renames(files, r"IMG_(\d+)", r"photo_\1")

        # Step 2: Execute renames
        self.renamer.execute(self.test_dir, plan)
        after_rename = sorted(os.listdir(self.test_dir))
        self.assertEqual(after_rename, ["photo_001.jpg", "photo_002.jpg", "photo_003.jpg", "readme.txt"])

        # Step 3: Generate and execute undo
        undo_plan = self.renamer.generate_undo(plan)
        self.renamer.execute(self.test_dir, undo_plan)
        after_undo = sorted(os.listdir(self.test_dir))
        self.assertEqual(after_undo, ["IMG_001.jpg", "IMG_002.jpg", "IMG_003.jpg", "readme.txt"])

    def test_write_undo_script_to_file(self):
        """write_undo_script() should create a shell script file."""
        plan = [("old.txt", "new.txt")]
        script_path = os.path.join(self.test_dir, "undo.sh")
        self.renamer.write_undo_script(plan, script_path)

        self.assertTrue(os.path.exists(script_path))
        with open(script_path) as f:
            content = f.read()
        self.assertIn("#!/bin/bash", content)
        self.assertIn("mv", content)

        # Check the file is executable
        mode = os.stat(script_path).st_mode
        self.assertTrue(mode & stat.S_IXUSR)


if __name__ == "__main__":
    unittest.main()
