"""
Tests for multi-file search-and-replace tool.

Organized by TDD cycles:
  Cycle 1 – find_files: glob-based recursive file discovery
  Cycle 2 – search_files: regex matching within discovered files
  Cycle 3 – preview: show proposed changes without modifying files
  Cycle 4 – create_backup: copy originals before modifying
  Cycle 5 – search_and_replace: full replacement with report
  Cycle 6 – error handling: bad regex, missing dirs, binary files
"""

import os
import re
import pytest
from pathlib import Path

from search_replace import (
    find_files,
    search_files,
    preview,
    create_backup,
    search_and_replace,
    Match,
    Change,
    Report,
)


# ── Shared fixtures ──


@pytest.fixture
def mock_tree(tmp_path):
    """Create a realistic mock directory tree for testing.

    Structure:
        readme.txt          "Hello World\nThis is a test.\n"
        data.csv            "a,b,c\n1,2,3\n"
        src/
          utils/
            helper.txt      "def hello():\n    return 'hello world'\n"
            config.txt      "host=localhost\nport=8080\n"
            image.png       (binary bytes)
          core/
            inner/
              deep.txt      "Hello from the deep\nAnother line\n"
    """
    (tmp_path / "readme.txt").write_text("Hello World\nThis is a test.\n")
    (tmp_path / "data.csv").write_text("a,b,c\n1,2,3\n")

    utils = tmp_path / "src" / "utils"
    utils.mkdir(parents=True)
    (utils / "helper.txt").write_text("def hello():\n    return 'hello world'\n")
    (utils / "config.txt").write_text("host=localhost\nport=8080\n")
    (utils / "image.png").write_bytes(b"\x89PNG\r\n\x1a\n" + bytes(range(256)))

    deep = tmp_path / "src" / "core" / "inner"
    deep.mkdir(parents=True)
    (deep / "deep.txt").write_text("Hello from the deep\nAnother line\n")

    return tmp_path


# ═══════════════════════════════════════════════════════════════════
# Cycle 1 – find_files
# ═══════════════════════════════════════════════════════════════════


class TestFindFiles:
    """RED: wrote these tests before find_files existed.
    GREEN: implemented find_files to make them pass."""

    def test_find_all_txt_files(self, mock_tree):
        """Should recursively find every .txt file."""
        result = find_files(mock_tree, "**/*.txt")
        names = sorted(p.name for p in result)
        assert names == ["config.txt", "deep.txt", "helper.txt", "readme.txt"]

    def test_find_no_matches(self, mock_tree):
        """Should return empty list when glob matches nothing."""
        result = find_files(mock_tree, "**/*.xyz")
        assert result == []

    def test_find_specific_subdir(self, mock_tree):
        """Should respect directory components in the glob."""
        result = find_files(mock_tree, "src/utils/*.txt")
        names = sorted(p.name for p in result)
        assert names == ["config.txt", "helper.txt"]

    def test_find_csv_files(self, mock_tree):
        """Should find non-txt file types too."""
        result = find_files(mock_tree, "**/*.csv")
        assert len(result) == 1
        assert result[0].name == "data.csv"

    def test_find_excludes_directories(self, mock_tree):
        """Should only return files, not directories."""
        result = find_files(mock_tree, "**/*")
        for p in result:
            assert p.is_file()

    def test_find_nonexistent_root_raises(self, tmp_path):
        """Should raise FileNotFoundError for bad root directory."""
        fake = tmp_path / "no_such_dir"
        with pytest.raises(FileNotFoundError):
            find_files(fake, "**/*.txt")


# ═══════════════════════════════════════════════════════════════════
# Cycle 2 – search_files
# ═══════════════════════════════════════════════════════════════════


class TestSearchFiles:
    """RED: wrote these tests before search_files existed.
    GREEN: implemented search_files with regex matching."""

    def test_simple_literal_search(self, mock_tree):
        """Should find literal string matches across files."""
        matches = search_files(mock_tree, "**/*.txt", r"hello")
        # "hello" appears in helper.txt lines 1 and 2, and nowhere else (case-sensitive)
        assert len(matches) == 2
        assert all(isinstance(m, Match) for m in matches)

    def test_case_insensitive_search(self, mock_tree):
        """Should support regex flags like (?i) for case-insensitive."""
        matches = search_files(mock_tree, "**/*.txt", r"(?i)hello")
        # "Hello" in readme.txt line 1, "hello" in helper.txt lines 1 & 2,
        # "Hello" in deep.txt line 1
        texts = [m.match_text for m in matches]
        assert "Hello" in texts
        assert "hello" in texts
        assert len(matches) == 4

    def test_regex_pattern(self, mock_tree):
        """Should support real regex patterns, not just literals."""
        matches = search_files(mock_tree, "**/*.txt", r"port=\d+")
        assert len(matches) == 1
        assert matches[0].match_text == "port=8080"
        assert matches[0].line_number == 2

    def test_no_matches(self, mock_tree):
        """Should return empty list when regex finds nothing."""
        matches = search_files(mock_tree, "**/*.txt", r"ZZZZZ_NOPE")
        assert matches == []

    def test_match_attributes(self, mock_tree):
        """Each Match should carry file path, line number, and matched text."""
        matches = search_files(mock_tree, "**/*.txt", r"port=\d+")
        m = matches[0]
        assert m.file.name == "config.txt"
        assert m.line_number == 2
        assert m.line_text == "port=8080"
        assert m.match_text == "port=8080"

    def test_skips_binary_files(self, mock_tree):
        """Should not crash or return results from binary files."""
        # image.png is under src/utils; search all files
        matches = search_files(mock_tree, "**/*", r"PNG")
        # Only text files may match, binary should be skipped
        for m in matches:
            assert m.file.suffix != ".png"

    def test_invalid_regex_raises(self, mock_tree):
        """Should raise re.error for an invalid regex pattern."""
        with pytest.raises(re.error):
            search_files(mock_tree, "**/*.txt", r"[invalid")


# ═══════════════════════════════════════════════════════════════════
# Cycle 3 – preview mode
# ═══════════════════════════════════════════════════════════════════


class TestPreview:
    """RED: wrote these tests before preview existed.
    GREEN: implemented preview to format match context."""

    def test_preview_shows_old_and_new(self, mock_tree):
        """Preview should show the original and proposed replacement."""
        output = preview(mock_tree, "**/*.txt", r"localhost", "127.0.0.1")
        assert "- host=localhost" in output
        assert "+ host=127.0.0.1" in output

    def test_preview_does_not_modify_files(self, mock_tree):
        """Preview must NOT change any file content."""
        config = mock_tree / "src" / "utils" / "config.txt"
        original = config.read_text()
        preview(mock_tree, "**/*.txt", r"localhost", "example.com")
        assert config.read_text() == original

    def test_preview_no_matches_message(self, mock_tree):
        """Preview should return a friendly message when nothing matches."""
        output = preview(mock_tree, "**/*.txt", r"NOPE_NOTHING", "x")
        assert output == "No matches found."

    def test_preview_includes_file_and_line(self, mock_tree):
        """Preview output should reference file path and line number."""
        output = preview(mock_tree, "**/*.txt", r"port=\d+", "port=9090")
        assert "config.txt:2" in output

    def test_preview_shows_context(self, mock_tree):
        """Preview with context_lines=1 should show surrounding lines."""
        output = preview(
            mock_tree, "**/*.txt", r"port=\d+", "port=9090", context_lines=1
        )
        # Context should include the line before port=8080
        assert "host=localhost" in output


# ═══════════════════════════════════════════════════════════════════
# Cycle 4 – backup creation
# ═══════════════════════════════════════════════════════════════════


class TestCreateBackup:
    """RED: wrote tests before create_backup existed.
    GREEN: implemented shutil-based backup."""

    def test_backup_creates_copy(self, tmp_path):
        """Should create a .bak copy of the original file."""
        original = tmp_path / "test.txt"
        original.write_text("original content")
        backup_path = create_backup(original)
        assert backup_path.exists()
        assert backup_path.read_text() == "original content"

    def test_backup_default_suffix(self, tmp_path):
        """Default backup suffix should be '.bak'."""
        original = tmp_path / "test.txt"
        original.write_text("data")
        backup_path = create_backup(original)
        assert backup_path.name == "test.txt.bak"

    def test_backup_custom_suffix(self, tmp_path):
        """Should support a custom backup suffix."""
        original = tmp_path / "test.txt"
        original.write_text("data")
        backup_path = create_backup(original, backup_suffix=".orig")
        assert backup_path.name == "test.txt.orig"

    def test_backup_preserves_original(self, tmp_path):
        """The original file should remain untouched after backup."""
        original = tmp_path / "test.txt"
        original.write_text("keep me")
        create_backup(original)
        assert original.read_text() == "keep me"

    def test_backup_nonexistent_raises(self, tmp_path):
        """Should raise FileNotFoundError for a non-existent file."""
        fake = tmp_path / "no_such.txt"
        with pytest.raises(FileNotFoundError):
            create_backup(fake)


# ═══════════════════════════════════════════════════════════════════
# Cycle 5 – search_and_replace (full operation + report)
# ═══════════════════════════════════════════════════════════════════


class TestSearchAndReplace:
    """RED: wrote these tests before search_and_replace existed.
    GREEN: implemented the full replace + report pipeline."""

    def test_replaces_in_files(self, mock_tree):
        """Should actually modify file contents."""
        search_and_replace(
            mock_tree, "**/*.txt", r"localhost", "127.0.0.1",
            create_backups=False,
        )
        config = mock_tree / "src" / "utils" / "config.txt"
        assert "127.0.0.1" in config.read_text()
        assert "localhost" not in config.read_text()

    def test_report_change_count(self, mock_tree):
        """Report should accurately count replacements."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"localhost", "127.0.0.1",
            create_backups=False,
        )
        assert report.total_replacements == 1
        assert report.files_modified == 1

    def test_report_change_details(self, mock_tree):
        """Each Change in the report should have correct old/new text."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"port=\d+", "port=9090",
            create_backups=False,
        )
        assert len(report.changes) == 1
        change = report.changes[0]
        assert change.old_text == "port=8080"
        assert change.new_text == "port=9090"
        assert change.line_number == 2

    def test_creates_backups_by_default(self, mock_tree):
        """Should create backup files when create_backups=True."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"localhost", "127.0.0.1",
            create_backups=True,
        )
        assert len(report.backups_created) == 1
        backup = report.backups_created[0]
        assert backup.exists()
        # Backup should contain the original content
        assert "localhost" in backup.read_text()

    def test_no_backups_when_disabled(self, mock_tree):
        """Should skip backup creation when create_backups=False."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"localhost", "127.0.0.1",
            create_backups=False,
        )
        assert report.backups_created == []

    def test_no_changes_returns_empty_report(self, mock_tree):
        """Report should be empty when pattern matches nothing."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"NOPE_NOTHING", "x",
            create_backups=False,
        )
        assert report.total_replacements == 0
        assert report.files_modified == 0
        assert report.changes == []

    def test_multiple_files_modified(self, mock_tree):
        """Should handle replacements across multiple files."""
        # "Hello" appears in readme.txt and deep.txt (case-sensitive)
        report = search_and_replace(
            mock_tree, "**/*.txt", r"Hello", "Hi",
            create_backups=False,
        )
        assert report.files_modified == 2
        assert report.total_replacements == 2
        # Verify actual content changed
        assert "Hi World" in (mock_tree / "readme.txt").read_text()
        deep = mock_tree / "src" / "core" / "inner" / "deep.txt"
        assert "Hi from the deep" in deep.read_text()

    def test_regex_replacement_with_groups(self, mock_tree):
        """Should support regex groups in the replacement string."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"port=(\d+)", r"port=\1_updated",
            create_backups=False,
        )
        config = mock_tree / "src" / "utils" / "config.txt"
        assert "port=8080_updated" in config.read_text()

    def test_report_summary_string(self, mock_tree):
        """The report summary() should produce readable output."""
        report = search_and_replace(
            mock_tree, "**/*.txt", r"localhost", "127.0.0.1",
            create_backups=False,
        )
        summary = report.summary()
        assert "Files modified: 1" in summary
        assert "Total replacements: 1" in summary
        assert "host=localhost" in summary
        assert "host=127.0.0.1" in summary


# ═══════════════════════════════════════════════════════════════════
# Cycle 6 – error handling & edge cases
# ═══════════════════════════════════════════════════════════════════


class TestErrorHandling:
    """RED: wrote edge-case tests.
    GREEN: ensured graceful handling throughout."""

    def test_invalid_regex_in_replace(self, mock_tree):
        """search_and_replace should raise re.error for bad regex."""
        with pytest.raises(re.error):
            search_and_replace(
                mock_tree, "**/*.txt", r"[bad", "x",
                create_backups=False,
            )

    def test_empty_directory(self, tmp_path):
        """Should handle an empty directory gracefully."""
        result = find_files(tmp_path, "**/*.txt")
        assert result == []

    def test_replace_skips_binary(self, mock_tree):
        """search_and_replace should not crash on binary files."""
        # Searching all files including binary .png
        report = search_and_replace(
            mock_tree, "**/*", r"hello", "goodbye",
            create_backups=False,
        )
        # Should only modify text files, not crash on binary
        for c in report.changes:
            assert c.file.suffix != ".png"

    def test_file_with_empty_content(self, tmp_path):
        """Should handle empty files without error."""
        (tmp_path / "empty.txt").write_text("")
        matches = search_files(tmp_path, "**/*.txt", r"anything")
        assert matches == []

    def test_multiple_matches_per_line(self, tmp_path):
        """Should find multiple regex matches on a single line."""
        (tmp_path / "multi.txt").write_text("aaa bbb aaa\n")
        matches = search_files(tmp_path, "**/*.txt", r"aaa")
        assert len(matches) == 2
        assert all(m.match_text == "aaa" for m in matches)
        assert all(m.line_number == 1 for m in matches)

    def test_replace_multiple_on_same_line(self, tmp_path):
        """Replace should handle multiple matches on a single line.
        Note: re.sub replaces all occurrences per line, counted as one Change."""
        (tmp_path / "multi.txt").write_text("aaa bbb aaa\n")
        report = search_and_replace(
            tmp_path, "**/*.txt", r"aaa", "zzz",
            create_backups=False,
        )
        content = (tmp_path / "multi.txt").read_text()
        assert content == "zzz bbb zzz\n"
        # One line changed = one Change entry
        assert report.total_replacements == 1
        assert report.changes[0].old_text == "aaa bbb aaa"
        assert report.changes[0].new_text == "zzz bbb zzz"
