"""Tests for multi-file search-and-replace tool, written test-first (red/green TDD)."""

import os
import re
import shutil
import tempfile
import pytest

from search_replace import (
    find_matches, search_replace, preview, summary_report, ChangeRecord,
)


# ---------------------------------------------------------------------------
# Helpers: create a temporary directory tree for each test
# ---------------------------------------------------------------------------

@pytest.fixture
def workspace(tmp_path):
    """Build a small mock directory tree with several file types."""
    # src/app.py
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "app.py").write_text(
        "# application entry\n"
        "def hello_world():\n"
        '    print("Hello World")\n'
        "\n"
        "def goodbye_world():\n"
        '    print("Goodbye World")\n'
    )
    # src/utils.py
    (tmp_path / "src" / "utils.py").write_text(
        "# utilities\n"
        "def format_world(name):\n"
        '    return f"Hello {name}"\n'
    )
    # docs/readme.txt
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "readme.txt").write_text(
        "Welcome to the Hello World project.\n"
        "Hello World is a demo application.\n"
    )
    # nested/deep/file.py
    (tmp_path / "nested" / "deep").mkdir(parents=True)
    (tmp_path / "nested" / "deep" / "file.py").write_text(
        "# deep file\n"
        'msg = "Hello World"\n'
    )
    return tmp_path


# ===========================================================================
# RED PHASE 1: find_matches returns correct match records
# ===========================================================================

class TestFindMatches:
    def test_finds_matches_in_glob_pattern(self, workspace):
        """find_matches should return ChangeRecord objects for every regex hit."""
        results = find_matches(workspace, "**/*.py", r"Hello World")
        assert len(results) >= 2  # at least app.py and deep/file.py

    def test_change_record_has_required_fields(self, workspace):
        results = find_matches(workspace, "**/*.py", r"Hello World")
        rec = results[0]
        assert hasattr(rec, "file")
        assert hasattr(rec, "line_number")
        assert hasattr(rec, "old_text")
        # In find-only mode, new_text is None
        assert rec.new_text is None

    def test_respects_glob_filter(self, workspace):
        """Only .txt files should be searched when glob says *.txt."""
        results = find_matches(workspace, "**/*.txt", r"Hello World")
        for r in results:
            assert r.file.endswith(".txt")

    def test_no_matches_returns_empty(self, workspace):
        results = find_matches(workspace, "**/*.py", r"NONEXISTENT_PATTERN_XYZ")
        assert results == []

    def test_regex_support(self, workspace):
        """Should support real regex, not just literal strings."""
        results = find_matches(workspace, "**/*.py", r"Hello\s+World")
        assert len(results) >= 2

    def test_line_numbers_are_correct(self, workspace):
        results = find_matches(workspace, "**/*.py", r"Hello World")
        # src/app.py has "Hello World" on line 3
        app_results = [r for r in results if r.file.endswith("app.py")]
        assert any(r.line_number == 3 for r in app_results)


# ===========================================================================
# RED PHASE 2: preview mode — shows what would change, without modifying files
# ===========================================================================

class TestPreview:
    def test_preview_does_not_modify_files(self, workspace):
        original = (workspace / "src" / "app.py").read_text()
        preview(workspace, "**/*.py", r"Hello World", "Hi Earth")
        assert (workspace / "src" / "app.py").read_text() == original

    def test_preview_shows_old_and_new(self, workspace):
        output = preview(workspace, "**/*.py", r"Hello World", "Hi Earth")
        assert "Hello World" in output
        assert "Hi Earth" in output

    def test_preview_shows_file_paths(self, workspace):
        output = preview(workspace, "**/*.py", r"Hello World", "Hi Earth")
        assert "app.py" in output

    def test_preview_shows_line_numbers(self, workspace):
        output = preview(workspace, "**/*.py", r"Hello World", "Hi Earth")
        # Line 3 of app.py has "Hello World"
        assert ":3:" in output or "line 3" in output.lower()

    def test_preview_includes_context_lines(self, workspace):
        """With context_lines=1, the line before/after the match should appear."""
        output = preview(workspace, "**/*.py", r"Hello World", "Hi Earth", context_lines=1)
        # Line 2 is 'def hello_world():' — should appear as context for the line-3 match
        assert "hello_world" in output


# ===========================================================================
# RED PHASE 3: search_replace — modifies files, creates backups, returns report
# ===========================================================================

class TestSearchReplace:
    def test_replaces_text_in_files(self, workspace):
        search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth")
        content = (workspace / "src" / "app.py").read_text()
        assert "Hi Earth" in content
        assert "Hello World" not in content

    def test_returns_change_records_with_old_and_new(self, workspace):
        records = search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth")
        assert len(records) >= 2
        for rec in records:
            assert rec.old_text is not None
            assert rec.new_text is not None
            assert "Hello World" in rec.old_text
            assert "Hi Earth" in rec.new_text

    def test_change_records_have_line_numbers(self, workspace):
        records = search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth")
        app_recs = [r for r in records if r.file.endswith("app.py")]
        assert any(r.line_number == 3 for r in app_recs)

    def test_creates_backup_files(self, workspace):
        search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth", backup=True)
        backup_path = workspace / "src" / "app.py.bak"
        assert backup_path.exists()
        # Backup should contain the *original* text
        assert "Hello World" in backup_path.read_text()

    def test_backup_can_be_disabled(self, workspace):
        search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth", backup=False)
        backup_path = workspace / "src" / "app.py.bak"
        assert not backup_path.exists()

    def test_only_backs_up_files_that_have_matches(self, workspace):
        """utils.py has 'Hello' but not 'Hello World' — no backup needed."""
        search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth", backup=True)
        # utils.py should NOT get a backup (it has "Hello {name}" not "Hello World")
        assert not (workspace / "src" / "utils.py.bak").exists()

    def test_regex_groups_in_replacement(self, workspace):
        """Replacement should support regex back-references."""
        search_replace(workspace, "**/*.py", r"(Hello) (World)", r"\1 Beautiful \2")
        content = (workspace / "src" / "app.py").read_text()
        assert "Hello Beautiful World" in content

    def test_multiple_matches_same_line(self, workspace):
        """If a line has multiple non-overlapping matches, all should be replaced."""
        (workspace / "multi.py").write_text('x = "Hello World and Hello World"\n')
        records = search_replace(workspace, "*.py", r"Hello World", "Hi Earth")
        content = (workspace / "multi.py").read_text()
        assert content.count("Hi Earth") == 2
        assert "Hello World" not in content


# ===========================================================================
# RED PHASE 4: summary_report — formatted report of all changes
# ===========================================================================

class TestSummaryReport:
    def test_report_contains_file_line_old_new(self, workspace):
        records = search_replace(workspace, "**/*.py", r"Hello World", "Hi Earth")
        report = summary_report(records)
        assert "app.py" in report
        assert "Hello World" in report
        assert "Hi Earth" in report
        # Should mention line numbers
        assert "3" in report

    def test_report_for_empty_records(self):
        report = summary_report([])
        assert "no changes" in report.lower()


# ===========================================================================
# RED PHASE 5: error handling
# ===========================================================================

class TestErrorHandling:
    def test_invalid_regex_raises_readable_error(self, workspace):
        with pytest.raises(re.error):
            find_matches(workspace, "**/*.py", r"[invalid")

    def test_nonexistent_root_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            find_matches(tmp_path / "nonexistent", "**/*.py", r"hello")

    def test_binary_files_skipped(self, workspace):
        """Binary files should be silently skipped, not crash."""
        (workspace / "image.py").write_bytes(b"\x00\x01\x02\xff\xfe" * 100)
        # Should not raise
        results = find_matches(workspace, "**/*.py", r"Hello")
        # binary file should not appear in results
        assert all("image.py" not in r.file for r in results)
