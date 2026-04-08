"""
Batch File Renamer - TDD test suite.

Red/Green TDD approach:
1. Write a failing test
2. Write minimum code to make it pass
3. Refactor
4. Repeat

Tests cover: preview mode, undo script generation, conflict detection.
"""

import os
import stat
import tempfile
import pytest
from pathlib import Path

# Import the module we're about to build - will fail until renamer.py exists
from renamer import (
    compute_renames,
    apply_renames,
    detect_conflicts,
    generate_undo_script,
)


# ---------------------------------------------------------------------------
# Fixtures: mock file system helpers
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_dir(tmp_path):
    """Provide a temporary directory for each test."""
    return tmp_path


def make_files(directory: Path, names: list[str]) -> list[Path]:
    """Create empty files in directory and return their Paths."""
    paths = []
    for name in names:
        p = directory / name
        p.touch()
        paths.append(p)
    return paths


# ---------------------------------------------------------------------------
# TEST 1: compute_renames returns correct (old, new) pairs in preview mode
# ---------------------------------------------------------------------------

class TestComputeRenames:
    def test_basic_regex_substitution(self, tmp_dir):
        """Preview mode should return (old_path, new_path) pairs without touching disk."""
        make_files(tmp_dir, ["report_2024.txt", "report_2025.txt", "notes.md"])

        # Replace underscores with hyphens in .txt files only
        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^(report)_(\d{4})\.txt$",
            replacement=r"\1-\2.txt",
        )

        # Should only match the two .txt files
        assert len(results) == 2

        old_names = {r.old_path.name for r in results}
        new_names = {r.new_path.name for r in results}
        assert old_names == {"report_2024.txt", "report_2025.txt"}
        assert new_names == {"report-2024.txt", "report-2025.txt"}

    def test_no_matches_returns_empty(self, tmp_dir):
        """When no files match the pattern, result should be empty."""
        make_files(tmp_dir, ["readme.md", "setup.py"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"\.txt$",
            replacement=r"_renamed.txt",
        )

        assert results == []

    def test_partial_match_skipped(self, tmp_dir):
        """Files that don't match the pattern are not included in results."""
        make_files(tmp_dir, ["img_001.jpg", "img_002.jpg", "document.pdf"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^img_(\d+)\.jpg$",
            replacement=r"photo_\1.jpg",
        )

        assert len(results) == 2
        new_names = {r.new_path.name for r in results}
        assert new_names == {"photo_001.jpg", "photo_002.jpg"}

    def test_preview_does_not_modify_filesystem(self, tmp_dir):
        """compute_renames must NOT rename files — it's purely a preview."""
        make_files(tmp_dir, ["old_name.txt"])

        compute_renames(
            directory=tmp_dir,
            pattern=r"old_name",
            replacement=r"new_name",
        )

        # Original file still exists, new file does not
        assert (tmp_dir / "old_name.txt").exists()
        assert not (tmp_dir / "new_name.txt").exists()

    def test_rename_result_paths_are_absolute(self, tmp_dir):
        """RenameResult paths should be absolute Paths."""
        make_files(tmp_dir, ["foo.log"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"\.log$",
            replacement=r".txt",
        )

        assert len(results) == 1
        assert results[0].old_path.is_absolute()
        assert results[0].new_path.is_absolute()


# ---------------------------------------------------------------------------
# TEST 2: conflict detection
# ---------------------------------------------------------------------------

class TestDetectConflicts:
    def test_two_files_map_to_same_name(self, tmp_dir):
        """Conflict when two source files would both rename to identical target."""
        # Both "photo_1.jpg" and "photo_01.jpg" → "photo_1.jpg" after stripping leading zeros
        make_files(tmp_dir, ["photo_1.jpg", "photo_01.jpg"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^photo_0*(\d+)\.jpg$",
            replacement=r"photo_\1.jpg",
        )

        conflicts = detect_conflicts(results)

        # "photo_1.jpg" is both unchanged AND a target for "photo_01.jpg"
        assert len(conflicts) > 0

    def test_no_conflicts_when_all_unique(self, tmp_dir):
        """No conflicts when all targets are distinct."""
        make_files(tmp_dir, ["report_2023.txt", "report_2024.txt"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^(report)_(\d{4})\.txt$",
            replacement=r"\1-\2.txt",
        )

        conflicts = detect_conflicts(results)
        assert conflicts == []

    def test_conflict_with_existing_file_not_being_renamed(self, tmp_dir):
        """Conflict when a target name matches an existing file that is NOT being renamed."""
        # "old.txt" will be renamed to "existing.txt", but "existing.txt" already exists
        make_files(tmp_dir, ["old.txt", "existing.txt"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^old\.txt$",
            replacement=r"existing.txt",
        )

        conflicts = detect_conflicts(results)
        assert len(conflicts) == 1
        assert "existing.txt" in conflicts[0].target_name

    def test_conflict_description_is_informative(self, tmp_dir):
        """Conflict objects carry a human-readable message."""
        make_files(tmp_dir, ["a.txt", "b.txt"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^[ab]\.txt$",
            replacement=r"c.txt",
        )

        conflicts = detect_conflicts(results)
        assert len(conflicts) == 1
        assert conflicts[0].message  # non-empty string


# ---------------------------------------------------------------------------
# TEST 3: apply_renames actually renames files on disk
# ---------------------------------------------------------------------------

class TestApplyRenames:
    def test_files_are_renamed(self, tmp_dir):
        """apply_renames should rename files on disk."""
        make_files(tmp_dir, ["foo_2024.log", "bar_2024.log"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^(\w+)_2024\.log$",
            replacement=r"\1_current.log",
        )
        apply_renames(results)

        assert (tmp_dir / "foo_current.log").exists()
        assert (tmp_dir / "bar_current.log").exists()
        assert not (tmp_dir / "foo_2024.log").exists()
        assert not (tmp_dir / "bar_2024.log").exists()

    def test_apply_empty_list_does_nothing(self, tmp_dir):
        """Applying an empty rename list should not raise or change anything."""
        make_files(tmp_dir, ["untouched.txt"])
        apply_renames([])
        assert (tmp_dir / "untouched.txt").exists()

    def test_apply_raises_on_conflict(self, tmp_dir):
        """apply_renames should raise ConflictError when conflicts are present."""
        from renamer import ConflictError

        make_files(tmp_dir, ["a.txt", "b.txt"])
        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^[ab]\.txt$",
            replacement=r"c.txt",
        )

        with pytest.raises(ConflictError):
            apply_renames(results)

    def test_apply_does_not_rename_on_conflict(self, tmp_dir):
        """When conflicts exist, no files should be renamed (atomic-like behaviour)."""
        from renamer import ConflictError

        make_files(tmp_dir, ["a.txt", "b.txt"])
        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^[ab]\.txt$",
            replacement=r"c.txt",
        )

        try:
            apply_renames(results)
        except Exception:
            pass

        # Both originals must still exist
        assert (tmp_dir / "a.txt").exists()
        assert (tmp_dir / "b.txt").exists()


# ---------------------------------------------------------------------------
# TEST 4: undo script generation
# ---------------------------------------------------------------------------

class TestGenerateUndoScript:
    def test_undo_script_contains_reverse_renames(self, tmp_dir):
        """The undo script should reverse each rename (new → old)."""
        make_files(tmp_dir, ["report_2024.txt", "report_2025.txt"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^(report)_(\d{4})\.txt$",
            replacement=r"\1-\2.txt",
        )
        script = generate_undo_script(results)

        # The script must mention the reversed paths
        assert "report-2024.txt" in script
        assert "report_2024.txt" in script
        assert "report-2025.txt" in script
        assert "report_2025.txt" in script

    def test_undo_script_is_executable_shell(self, tmp_dir):
        """The generated undo script should be valid sh/bash (starts with shebang)."""
        make_files(tmp_dir, ["img001.jpg"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^img(\d+)\.jpg$",
            replacement=r"image_\1.jpg",
        )
        script = generate_undo_script(results)

        assert script.strip().startswith("#!/")

    def test_undo_script_empty_for_no_renames(self):
        """Generating an undo script for an empty list should still return a valid script."""
        script = generate_undo_script([])
        assert isinstance(script, str)
        assert script.strip().startswith("#!/")

    def test_undo_script_can_be_saved_and_run(self, tmp_dir):
        """Write the undo script to disk, apply renames, then run script to reverse."""
        make_files(tmp_dir, ["hello_world.txt"])

        results = compute_renames(
            directory=tmp_dir,
            pattern=r"^hello_world\.txt$",
            replacement=r"goodbye_world.txt",
        )
        script_content = generate_undo_script(results)

        # Save undo script
        undo_path = tmp_dir / "undo.sh"
        undo_path.write_text(script_content)
        undo_path.chmod(undo_path.stat().st_mode | stat.S_IEXEC)

        # Apply renames
        apply_renames(results)
        assert (tmp_dir / "goodbye_world.txt").exists()
        assert not (tmp_dir / "hello_world.txt").exists()

        # Run undo script
        import subprocess
        subprocess.run(["bash", str(undo_path)], check=True)

        assert (tmp_dir / "hello_world.txt").exists()
        assert not (tmp_dir / "goodbye_world.txt").exists()
