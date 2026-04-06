"""
Batch File Renamer - TDD Test Suite

Red/Green TDD approach:
1. Write failing test
2. Write minimum code to pass
3. Refactor
4. Repeat
"""
import os
import pytest
import tempfile
import stat
from pathlib import Path

# Import the module we'll build - this will fail until we create it
from renamer import (
    compute_renames,
    detect_conflicts,
    generate_undo_script,
    apply_renames,
    RenameOperation,
)


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures
# ─────────────────────────────────────────────────────────────────────────────

@pytest.fixture
def tmp_dir(tmp_path):
    """Create a temporary directory with mock files for testing."""
    files = [
        "report_2024_01.txt",
        "report_2024_02.txt",
        "report_2024_03.txt",
        "notes.md",
        "image_001.jpg",
        "image_002.jpg",
        "image_003.jpg",
        "unrelated.py",
    ]
    for name in files:
        (tmp_path / name).touch()
    return tmp_path


# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: compute_renames - basic regex substitution
# RED: This test will fail because renamer.py doesn't exist yet.
# ─────────────────────────────────────────────────────────────────────────────

class TestComputeRenames:
    def test_basic_regex_substitution(self, tmp_dir):
        """Files matching the pattern should get renamed; non-matching files ignored."""
        ops = compute_renames(
            directory=tmp_dir,
            pattern=r"report_(\d{4})_(\d{2})\.txt",
            replacement=r"report-\1-\2.txt",
        )
        # Should match exactly 3 report files
        assert len(ops) == 3
        names = {op.new_name for op in ops}
        assert "report-2024-01.txt" in names
        assert "report-2024-02.txt" in names
        assert "report-2024-03.txt" in names

    def test_non_matching_files_are_excluded(self, tmp_dir):
        """Files that don't match the pattern should not appear in the result."""
        ops = compute_renames(
            directory=tmp_dir,
            pattern=r"report_(\d{4})_(\d{2})\.txt",
            replacement=r"report-\1-\2.txt",
        )
        old_names = {op.old_name for op in ops}
        assert "notes.md" not in old_names
        assert "unrelated.py" not in old_names

    def test_empty_directory_returns_empty_list(self, tmp_path):
        """Empty directory should produce no operations."""
        ops = compute_renames(tmp_path, r".*\.txt", r"new_\g<0>")
        assert ops == []

    def test_rename_operation_has_correct_fields(self, tmp_dir):
        """Each RenameOperation should carry old_name, new_name, old_path, new_path."""
        ops = compute_renames(
            directory=tmp_dir,
            pattern=r"image_(\d+)\.jpg",
            replacement=r"photo_\1.jpg",
        )
        assert len(ops) == 3
        op = ops[0]
        assert hasattr(op, "old_name")
        assert hasattr(op, "new_name")
        assert hasattr(op, "old_path")
        assert hasattr(op, "new_path")
        assert op.old_path.parent == tmp_dir
        assert op.new_path.parent == tmp_dir

    def test_case_insensitive_flag(self, tmp_path):
        """Pattern matching should respect the ignore_case flag."""
        (tmp_path / "Report_2024_01.TXT").touch()
        (tmp_path / "REPORT_2024_02.TXT").touch()

        # Without ignore_case - lowercase pattern won't match uppercase files
        ops_sensitive = compute_renames(
            tmp_path, r"report_(\d{4})_(\d{2})\.txt", r"new-\1-\2.txt"
        )
        assert len(ops_sensitive) == 0

        # With ignore_case - should match
        ops_insensitive = compute_renames(
            tmp_path,
            r"report_(\d{4})_(\d{2})\.txt",
            r"new-\1-\2.txt",
            ignore_case=True,
        )
        assert len(ops_insensitive) == 2

    def test_nonexistent_directory_raises(self):
        """Non-existent directory should raise FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            compute_renames(Path("/nonexistent/path"), r".*", r"new")


# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: detect_conflicts
# RED: detect_conflicts doesn't exist yet.
# ─────────────────────────────────────────────────────────────────────────────

class TestDetectConflicts:
    def test_no_conflicts_when_all_names_unique(self, tmp_dir):
        """Should return empty list when no two ops produce the same new name."""
        ops = compute_renames(
            tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg"
        )
        conflicts = detect_conflicts(ops)
        assert conflicts == []

    def test_detects_collision_between_two_ops(self, tmp_path):
        """Two files mapped to the same name should be flagged."""
        (tmp_path / "foo_1.txt").touch()
        (tmp_path / "foo_2.txt").touch()

        # Both "foo_1.txt" and "foo_2.txt" → "result.txt"
        ops = compute_renames(tmp_path, r"foo_\d+\.txt", r"result.txt")
        conflicts = detect_conflicts(ops)

        # Should have exactly one conflict group (both files clash on "result.txt")
        assert len(conflicts) == 1
        assert conflicts[0]["new_name"] == "result.txt"
        assert len(conflicts[0]["sources"]) == 2

    def test_detects_collision_with_existing_file(self, tmp_path):
        """If the new name already exists in the directory (and isn't being renamed), flag it."""
        (tmp_path / "alpha.txt").touch()
        (tmp_path / "beta.txt").touch()  # will become "alpha.txt" - collision!

        ops = compute_renames(tmp_path, r"beta\.txt", r"alpha.txt")
        conflicts = detect_conflicts(ops, directory=tmp_path)

        assert len(conflicts) == 1
        assert conflicts[0]["new_name"] == "alpha.txt"

    def test_no_false_positive_when_source_is_renamed_away(self, tmp_path):
        """If a file with the target name is itself being renamed, no conflict."""
        (tmp_path / "a.txt").touch()
        (tmp_path / "b.txt").touch()

        # a.txt -> b.txt and b.txt -> c.txt: a.txt wants b.txt, but b.txt is moving away
        ops = compute_renames(tmp_path, r"(a)\.txt", r"b.txt")
        ops2 = compute_renames(tmp_path, r"(b)\.txt", r"c.txt")
        all_ops = ops + ops2

        conflicts = detect_conflicts(all_ops, directory=tmp_path)
        assert conflicts == []


# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: generate_undo_script
# RED: generate_undo_script doesn't exist yet.
# ─────────────────────────────────────────────────────────────────────────────

class TestGenerateUndoScript:
    def test_undo_script_is_string(self, tmp_dir):
        """generate_undo_script should return a non-empty string."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        script = generate_undo_script(ops)
        assert isinstance(script, str)
        assert len(script) > 0

    def test_undo_script_reverses_renames(self, tmp_dir):
        """The undo script must map new_name → old_name for each operation."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        script = generate_undo_script(ops)

        # Each original file should appear as the target in the undo script
        for op in ops:
            assert op.old_name in script
            assert op.new_name in script

    def test_undo_script_is_executable_shell(self, tmp_dir):
        """Undo script should be valid shell (starts with shebang or mv commands)."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        script = generate_undo_script(ops)
        # Should contain mv commands to reverse the rename
        assert "mv" in script

    def test_empty_ops_returns_empty_script(self, tmp_path):
        """No operations → no-op undo script."""
        ops = []
        script = generate_undo_script(ops)
        assert isinstance(script, str)
        # Should still be valid (just a header/shebang with no mv commands)
        assert "mv" not in script


# ─────────────────────────────────────────────────────────────────────────────
# TEST 4: apply_renames (actual filesystem mutation)
# RED: apply_renames doesn't exist yet.
# ─────────────────────────────────────────────────────────────────────────────

class TestApplyRenames:
    def test_files_are_renamed_on_disk(self, tmp_dir):
        """After apply_renames, new files should exist and old ones should not."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        apply_renames(ops)

        for op in ops:
            assert not op.old_path.exists(), f"{op.old_path} should no longer exist"
            assert op.new_path.exists(), f"{op.new_path} should now exist"

    def test_non_matching_files_untouched(self, tmp_dir):
        """Files that were not matched should remain unchanged."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        apply_renames(ops)

        # notes.md and unrelated.py should still be there
        assert (tmp_dir / "notes.md").exists()
        assert (tmp_dir / "unrelated.py").exists()

    def test_apply_renames_raises_on_conflict(self, tmp_path):
        """apply_renames should refuse to proceed if conflicts exist."""
        (tmp_path / "foo_1.txt").touch()
        (tmp_path / "foo_2.txt").touch()
        ops = compute_renames(tmp_path, r"foo_\d+\.txt", r"result.txt")

        with pytest.raises(ValueError, match="conflict"):
            apply_renames(ops)

    def test_apply_renames_dry_run_does_nothing(self, tmp_dir):
        """With dry_run=True, no filesystem changes should occur."""
        before = set(tmp_dir.iterdir())
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        apply_renames(ops, dry_run=True)
        after = set(tmp_dir.iterdir())
        assert before == after

    def test_apply_returns_list_of_completed_ops(self, tmp_dir):
        """apply_renames should return the list of operations that were performed."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        completed = apply_renames(ops)
        assert len(completed) == len(ops)

    def test_apply_dry_run_returns_preview(self, tmp_dir):
        """Dry-run mode should return ops that *would* be performed, for preview."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        preview = apply_renames(ops, dry_run=True)
        assert len(preview) == len(ops)


# ─────────────────────────────────────────────────────────────────────────────
# Integration: full workflow
# ─────────────────────────────────────────────────────────────────────────────

class TestIntegration:
    def test_full_workflow_preview_then_apply(self, tmp_dir):
        """Preview mode should not mutate; subsequent apply should rename files."""
        ops = compute_renames(tmp_dir, r"report_(\d{4})_(\d{2})\.txt", r"report-\1-\2.txt")

        # Preview (dry-run) - files unchanged
        preview = apply_renames(ops, dry_run=True)
        assert len(preview) == 3
        assert (tmp_dir / "report_2024_01.txt").exists()

        # Apply - files renamed
        apply_renames(ops)
        assert not (tmp_dir / "report_2024_01.txt").exists()
        assert (tmp_dir / "report-2024-01.txt").exists()

    def test_undo_script_can_be_executed(self, tmp_dir):
        """Run the undo script and verify files are back to original names."""
        ops = compute_renames(tmp_dir, r"image_(\d+)\.jpg", r"photo_\1.jpg")
        script = generate_undo_script(ops)
        apply_renames(ops)

        # Write and execute the undo script
        undo_file = tmp_dir / "undo_rename.sh"
        undo_file.write_text(script)
        undo_file.chmod(undo_file.stat().st_mode | stat.S_IEXEC)

        ret = os.system(f"bash {undo_file}")
        assert ret == 0

        # After undo, originals should be back
        for op in ops:
            assert op.old_path.exists(), f"{op.old_name} should be restored"
            assert not op.new_path.exists(), f"{op.new_name} should be gone"
