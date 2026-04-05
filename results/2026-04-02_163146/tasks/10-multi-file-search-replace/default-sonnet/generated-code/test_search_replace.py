"""
TDD tests for multi-file search-and-replace tool.
Red/green methodology: each test was written before the implementation.
"""

import os
import re
import shutil
import tempfile
import pytest
from pathlib import Path

# Import the module under test (will fail until we create it)
from search_replace import (
    find_files,
    find_matches,
    preview_matches,
    create_backup,
    perform_replace,
    generate_report,
    run_search_replace,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_dir():
    """Create a temporary directory tree with mock files for testing."""
    d = tempfile.mkdtemp()
    # src/
    src = os.path.join(d, "src")
    os.makedirs(src)
    Path(os.path.join(src, "main.py")).write_text(
        "# main module\nfoo = 'hello'\nbar = foo\n"
    )
    Path(os.path.join(src, "utils.py")).write_text(
        "def foo():\n    return 'world'\n\nfoo_value = foo()\n"
    )
    # src/sub/
    sub = os.path.join(src, "sub")
    os.makedirs(sub)
    Path(os.path.join(sub, "helper.py")).write_text(
        "# helper\nimport foo\nfoo.run()\n"
    )
    # docs/
    docs = os.path.join(d, "docs")
    os.makedirs(docs)
    Path(os.path.join(docs, "readme.md")).write_text(
        "# Project\nUse foo for everything.\n"
    )
    Path(os.path.join(docs, "notes.txt")).write_text(
        "foo bar baz\n"
    )
    yield d
    shutil.rmtree(d)


# ---------------------------------------------------------------------------
# 1. find_files — glob pattern matching
# ---------------------------------------------------------------------------

class TestFindFiles:
    def test_finds_py_files_recursively(self, tmp_dir):
        files = find_files(tmp_dir, "**/*.py")
        names = {os.path.basename(f) for f in files}
        assert names == {"main.py", "utils.py", "helper.py"}

    def test_finds_md_files(self, tmp_dir):
        files = find_files(tmp_dir, "**/*.md")
        names = {os.path.basename(f) for f in files}
        assert names == {"readme.md"}

    def test_finds_all_files_with_star(self, tmp_dir):
        files = find_files(tmp_dir, "**/*.*")
        assert len(files) == 5

    def test_empty_result_for_nonmatching_pattern(self, tmp_dir):
        files = find_files(tmp_dir, "**/*.rs")
        assert files == []

    def test_returns_absolute_paths(self, tmp_dir):
        files = find_files(tmp_dir, "**/*.py")
        for f in files:
            assert os.path.isabs(f)


# ---------------------------------------------------------------------------
# 2. find_matches — regex search within a file
# ---------------------------------------------------------------------------

class TestFindMatches:
    def test_finds_simple_pattern(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        matches = find_matches(path, r"foo")
        # "foo" appears on lines 2, 3 (1-indexed)
        line_nums = [m["line"] for m in matches]
        assert 2 in line_nums
        assert 3 in line_nums

    def test_match_includes_line_content(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        matches = find_matches(path, r"foo")
        for m in matches:
            assert "foo" in m["content"]

    def test_match_includes_span(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        matches = find_matches(path, r"foo")
        for m in matches:
            assert "start" in m and "end" in m

    def test_no_matches_returns_empty(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        matches = find_matches(path, r"zzznomatch")
        assert matches == []

    def test_regex_pattern(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "utils.py")
        # Match "foo" only at word boundary
        matches = find_matches(path, r"\bfoo\b")
        assert len(matches) >= 1


# ---------------------------------------------------------------------------
# 3. preview_matches — show matches with context (no file modification)
# ---------------------------------------------------------------------------

class TestPreviewMatches:
    def test_preview_does_not_modify_file(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        original = Path(path).read_text()
        preview_matches(path, r"foo", "bar")
        assert Path(path).read_text() == original

    def test_preview_returns_preview_entries(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        entries = preview_matches(path, r"foo", "bar")
        assert len(entries) > 0

    def test_preview_entry_has_required_fields(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        entries = preview_matches(path, r"foo", "bar")
        for e in entries:
            assert "file" in e
            assert "line" in e
            assert "old_text" in e
            assert "new_text" in e
            assert "context" in e

    def test_preview_shows_replacement(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        entries = preview_matches(path, r"foo", "BAR")
        for e in entries:
            assert e["new_text"] != e["old_text"] or "BAR" in e["new_text"]


# ---------------------------------------------------------------------------
# 4. create_backup — copy originals before modifying
# ---------------------------------------------------------------------------

class TestCreateBackup:
    def test_backup_file_exists(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        backup = create_backup(path)
        assert os.path.exists(backup)

    def test_backup_has_expected_extension(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        backup = create_backup(path)
        assert backup.endswith(".bak")

    def test_backup_content_matches_original(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        original_content = Path(path).read_text()
        backup = create_backup(path)
        assert Path(backup).read_text() == original_content

    def test_backup_does_not_modify_original(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        original_content = Path(path).read_text()
        create_backup(path)
        assert Path(path).read_text() == original_content

    def test_backup_in_same_directory(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        backup = create_backup(path)
        assert os.path.dirname(backup) == os.path.dirname(path)


# ---------------------------------------------------------------------------
# 5. perform_replace — actually modify the file
# ---------------------------------------------------------------------------

class TestPerformReplace:
    def test_replaces_pattern_in_file(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        perform_replace(path, r"foo", "bar")
        content = Path(path).read_text()
        assert "bar" in content

    def test_original_pattern_removed(self, tmp_dir):
        path = os.path.join(tmp_dir, "docs", "notes.txt")
        perform_replace(path, r"foo", "qux")
        content = Path(path).read_text()
        # "foo" should no longer appear
        assert "foo" not in content

    def test_returns_change_records(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        changes = perform_replace(path, r"foo", "bar")
        assert isinstance(changes, list)
        assert len(changes) > 0

    def test_change_record_fields(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        changes = perform_replace(path, r"foo", "bar")
        for c in changes:
            assert "file" in c
            assert "line" in c
            assert "old_text" in c
            assert "new_text" in c

    def test_no_change_for_no_match(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "main.py")
        original = Path(path).read_text()
        changes = perform_replace(path, r"zzznomatch", "bar")
        assert changes == []
        assert Path(path).read_text() == original

    def test_regex_group_references_work(self, tmp_dir):
        path = os.path.join(tmp_dir, "src", "utils.py")
        # Wrap "foo" in brackets using back-reference
        changes = perform_replace(path, r"\b(foo)\b", r"[\1]")
        content = Path(path).read_text()
        assert "[foo]" in content


# ---------------------------------------------------------------------------
# 6. generate_report — summary of all changes
# ---------------------------------------------------------------------------

class TestGenerateReport:
    def _make_changes(self):
        return [
            {"file": "/a/b.py", "line": 3, "old_text": "foo = 1", "new_text": "bar = 1"},
            {"file": "/a/c.py", "line": 7, "old_text": "import foo", "new_text": "import bar"},
            {"file": "/a/b.py", "line": 9, "old_text": "x = foo()", "new_text": "x = bar()"},
        ]

    def test_report_is_string(self):
        report = generate_report(self._make_changes())
        assert isinstance(report, str)

    def test_report_contains_file_names(self):
        report = generate_report(self._make_changes())
        assert "/a/b.py" in report
        assert "/a/c.py" in report

    def test_report_contains_line_numbers(self):
        report = generate_report(self._make_changes())
        assert "3" in report
        assert "7" in report

    def test_report_contains_old_and_new_text(self):
        report = generate_report(self._make_changes())
        assert "foo = 1" in report
        assert "bar = 1" in report

    def test_report_shows_total_count(self):
        report = generate_report(self._make_changes())
        assert "3" in report  # total 3 changes

    def test_empty_changes_report(self):
        report = generate_report([])
        assert "0" in report or "no changes" in report.lower()


# ---------------------------------------------------------------------------
# 7. run_search_replace — integration: ties everything together
# ---------------------------------------------------------------------------

class TestRunSearchReplace:
    def test_dry_run_does_not_modify_files(self, tmp_dir):
        originals = {}
        for f in Path(tmp_dir).rglob("*.py"):
            originals[str(f)] = f.read_text()
        run_search_replace(tmp_dir, "**/*.py", r"foo", "bar", dry_run=True)
        for path, content in originals.items():
            assert Path(path).read_text() == content

    def test_dry_run_returns_preview(self, tmp_dir):
        result = run_search_replace(tmp_dir, "**/*.py", r"foo", "bar", dry_run=True)
        assert "preview" in result
        assert len(result["preview"]) > 0

    def test_live_run_modifies_files(self, tmp_dir):
        run_search_replace(tmp_dir, "**/*.py", r"foo", "bar", dry_run=False)
        contents = [Path(f).read_text() for f in Path(tmp_dir).rglob("*.py")]
        assert any("bar" in c for c in contents)

    def test_live_run_creates_backups(self, tmp_dir):
        run_search_replace(tmp_dir, "**/*.py", r"foo", "bar", dry_run=False)
        bak_files = list(Path(tmp_dir).rglob("*.bak"))
        assert len(bak_files) > 0

    def test_live_run_returns_report(self, tmp_dir):
        result = run_search_replace(tmp_dir, "**/*.py", r"foo", "bar", dry_run=False)
        assert "report" in result
        assert isinstance(result["report"], str)

    def test_live_run_returns_changes(self, tmp_dir):
        result = run_search_replace(tmp_dir, "**/*.py", r"foo", "bar", dry_run=False)
        assert "changes" in result
        assert len(result["changes"]) > 0

    def test_no_matching_files_graceful(self, tmp_dir):
        result = run_search_replace(tmp_dir, "**/*.rs", r"foo", "bar", dry_run=False)
        assert result["changes"] == []

    def test_no_matching_pattern_graceful(self, tmp_dir):
        result = run_search_replace(tmp_dir, "**/*.py", r"zzznomatch", "bar", dry_run=False)
        assert result["changes"] == []
