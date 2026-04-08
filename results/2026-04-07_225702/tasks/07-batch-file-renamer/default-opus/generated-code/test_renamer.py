"""Tests for the batch file renamer, written test-first using red/green TDD."""

import os
import re
import tempfile
import shutil
import stat
import unittest

from renamer import (
    compute_renames,
    detect_conflicts,
    preview_renames,
    generate_undo_script,
    execute_renames,
)


class TestComputeRenames(unittest.TestCase):
    """Test the core rename-computation logic."""

    def test_simple_regex_rename(self):
        """A basic regex substitution renames matching files."""
        files = ["photo_001.jpg", "photo_002.jpg", "notes.txt"]
        result = compute_renames(files, r"photo_(\d+)", r"img_\1")
        self.assertEqual(result, {
            "photo_001.jpg": "img_001.jpg",
            "photo_002.jpg": "img_002.jpg",
        })

    def test_no_matches(self):
        """Files that don't match the pattern are left untouched."""
        files = ["readme.md", "notes.txt"]
        result = compute_renames(files, r"photo_(\d+)", r"img_\1")
        self.assertEqual(result, {})

    def test_full_name_replacement(self):
        """Pattern can match and replace the entire filename."""
        files = ["report-2024.pdf"]
        result = compute_renames(files, r"report-(\d+)\.pdf", r"annual_\1.pdf")
        self.assertEqual(result, {"report-2024.pdf": "annual_2024.pdf"})


class TestDetectConflicts(unittest.TestCase):
    """RED: detect_conflicts doesn't exist yet."""

    def test_no_conflicts(self):
        """Distinct target names produce no conflicts."""
        renames = {"a.txt": "b.txt", "c.txt": "d.txt"}
        conflicts = detect_conflicts(renames)
        self.assertEqual(conflicts, {})

    def test_two_files_same_target(self):
        """Two source files mapping to the same target is a conflict."""
        renames = {"file1.txt": "output.txt", "file2.txt": "output.txt"}
        conflicts = detect_conflicts(renames)
        self.assertEqual(conflicts, {"output.txt": ["file1.txt", "file2.txt"]})

    def test_conflict_with_existing_file(self):
        """Renaming to a name that already exists (and isn't being renamed) is a conflict."""
        renames = {"old.txt": "existing.txt"}
        existing_files = ["existing.txt", "old.txt"]
        conflicts = detect_conflicts(renames, existing_files)
        self.assertEqual(conflicts, {"existing.txt": ["old.txt", "(already exists)"]})

    def test_no_conflict_when_existing_is_also_renamed(self):
        """If the 'existing' file is itself being renamed away, no conflict."""
        renames = {"a.txt": "b.txt", "b.txt": "c.txt"}
        existing_files = ["a.txt", "b.txt"]
        conflicts = detect_conflicts(renames, existing_files)
        self.assertEqual(conflicts, {})


class TestPreviewRenames(unittest.TestCase):
    """RED: preview_renames doesn't exist yet."""

    def test_preview_returns_formatted_lines(self):
        """Preview mode returns human-readable lines showing old -> new."""
        renames = {"photo_001.jpg": "img_001.jpg", "photo_002.jpg": "img_002.jpg"}
        lines = preview_renames(renames)
        self.assertIn("photo_001.jpg -> img_001.jpg", lines)
        self.assertIn("photo_002.jpg -> img_002.jpg", lines)

    def test_preview_empty(self):
        """Preview of no renames gives an informative message."""
        lines = preview_renames({})
        self.assertEqual(lines, "No files match the pattern.")


class TestGenerateUndoScript(unittest.TestCase):
    """RED: generate_undo_script doesn't exist yet."""

    def test_undo_script_content(self):
        """Undo script contains reverse mv commands."""
        renames = {"a.txt": "b.txt", "c.txt": "d.txt"}
        script = generate_undo_script(renames)
        # The undo should reverse each rename
        self.assertIn("mv", script)
        self.assertIn("b.txt", script)
        self.assertIn("a.txt", script)
        self.assertIn("d.txt", script)
        self.assertIn("c.txt", script)

    def test_undo_script_is_executable_bash(self):
        """Undo script starts with a shebang line."""
        renames = {"x.txt": "y.txt"}
        script = generate_undo_script(renames)
        self.assertTrue(script.startswith("#!/bin/bash"))


class TestExecuteRenames(unittest.TestCase):
    """RED: execute_renames doesn't exist yet. Uses real temp dirs."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def _touch(self, name):
        path = os.path.join(self.tmpdir, name)
        open(path, "w").close()
        return path

    def test_execute_renames_files(self):
        """execute_renames actually moves files on disk."""
        self._touch("old.txt")
        renames = {"old.txt": "new.txt"}
        execute_renames(self.tmpdir, renames)
        self.assertFalse(os.path.exists(os.path.join(self.tmpdir, "old.txt")))
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "new.txt")))

    def test_execute_refuses_on_conflict(self):
        """execute_renames raises on conflict instead of clobbering files."""
        self._touch("a.txt")
        self._touch("b.txt")
        # Both map to same target
        renames = {"a.txt": "target.txt", "b.txt": "target.txt"}
        with self.assertRaises(ValueError) as ctx:
            execute_renames(self.tmpdir, renames)
        self.assertIn("conflict", str(ctx.exception).lower())

    def test_execute_writes_undo_script(self):
        """execute_renames writes an undo script next to the renamed files."""
        self._touch("old.txt")
        renames = {"old.txt": "new.txt"}
        execute_renames(self.tmpdir, renames)
        undo_path = os.path.join(self.tmpdir, "undo_renames.sh")
        self.assertTrue(os.path.exists(undo_path))
        # Undo script should be executable
        self.assertTrue(os.stat(undo_path).st_mode & stat.S_IXUSR)

    def test_execute_source_missing(self):
        """execute_renames gives a clear error when a source file is missing."""
        renames = {"nonexistent.txt": "new.txt"}
        with self.assertRaises(FileNotFoundError) as ctx:
            execute_renames(self.tmpdir, renames)
        self.assertIn("nonexistent.txt", str(ctx.exception))


class TestUndoEndToEnd(unittest.TestCase):
    """End-to-end: rename files, then run the undo script to reverse them."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def _touch(self, name):
        path = os.path.join(self.tmpdir, name)
        open(path, "w").close()

    def test_undo_reverses_renames(self):
        """Running the generated undo script restores original filenames."""
        self._touch("photo_001.jpg")
        self._touch("photo_002.jpg")
        self._touch("notes.txt")

        renames = compute_renames(
            ["photo_001.jpg", "photo_002.jpg", "notes.txt"],
            r"photo_(\d+)", r"img_\1",
        )
        execute_renames(self.tmpdir, renames)

        # Verify renamed state
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "img_001.jpg")))
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "img_002.jpg")))
        self.assertFalse(os.path.exists(os.path.join(self.tmpdir, "photo_001.jpg")))

        # Run the undo script
        import subprocess
        undo_path = os.path.join(self.tmpdir, "undo_renames.sh")
        result = subprocess.run(
            ["bash", undo_path], cwd=self.tmpdir,
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, f"Undo script failed: {result.stderr}")

        # Verify originals are restored
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "photo_001.jpg")))
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "photo_002.jpg")))
        self.assertFalse(os.path.exists(os.path.join(self.tmpdir, "img_001.jpg")))


class TestInvalidRegex(unittest.TestCase):
    """Error handling for bad regex patterns."""

    def test_invalid_pattern_raises(self):
        """An invalid regex raises a clear error."""
        with self.assertRaises(re.error):
            compute_renames(["file.txt"], r"[invalid", "replacement")


class TestCLIIntegration(unittest.TestCase):
    """Test the CLI entry point end-to-end."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def _touch(self, name):
        path = os.path.join(self.tmpdir, name)
        open(path, "w").close()

    def test_cli_preview_mode(self):
        """--preview shows what would change without modifying files."""
        import subprocess
        self._touch("doc_v1.txt")
        self._touch("doc_v2.txt")
        result = subprocess.run(
            ["python3", "renamer.py", self.tmpdir, r"doc_v(\d+)", r"document_v\1", "--preview"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("doc_v1.txt -> document_v1.txt", result.stdout)
        # Files should NOT have been renamed
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "doc_v1.txt")))

    def test_cli_execute_mode(self):
        """Without --preview, files are actually renamed."""
        import subprocess
        self._touch("old_a.txt")
        result = subprocess.run(
            ["python3", "renamer.py", self.tmpdir, r"old_(\w+)", r"new_\1"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, f"CLI failed: {result.stderr}")
        self.assertFalse(os.path.exists(os.path.join(self.tmpdir, "old_a.txt")))
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "new_a.txt")))

    def test_cli_conflict_exits_nonzero(self):
        """CLI exits with error code when conflicts are detected."""
        import subprocess
        self._touch("a1.txt")
        self._touch("a2.txt")
        # Both files will rename to the same target (strips digits)
        result = subprocess.run(
            ["python3", "renamer.py", self.tmpdir, r"a\d+", "same"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflict", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
