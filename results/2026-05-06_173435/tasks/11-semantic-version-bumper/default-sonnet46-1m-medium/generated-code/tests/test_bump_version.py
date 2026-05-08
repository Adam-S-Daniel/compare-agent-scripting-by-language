"""
TDD tests for semantic version bumper.
Red/green cycle: these tests were written before the implementation.
"""
import pytest
import sys
import json
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from bump_version import (
    parse_version,
    determine_bump_type,
    bump_version,
    format_version,
    generate_changelog_entry,
    read_version,
    write_version,
    read_commits,
)


# --- parse_version ---

def test_parse_version_standard():
    assert parse_version("1.2.3") == (1, 2, 3)

def test_parse_version_zeros():
    assert parse_version("0.0.0") == (0, 0, 0)

def test_parse_version_with_trailing_newline():
    assert parse_version("1.0.0\n") == (1, 0, 0)

def test_parse_version_invalid_raises():
    with pytest.raises(ValueError, match="Invalid version"):
        parse_version("not-a-version")

def test_parse_version_missing_patch_raises():
    with pytest.raises(ValueError):
        parse_version("1.2")


# --- determine_bump_type ---

def test_bump_type_patch_for_fix_commits():
    commits = ["fix: correct typo", "fix(auth): fix login bug"]
    assert determine_bump_type(commits) == "patch"

def test_bump_type_patch_for_no_commits():
    assert determine_bump_type([]) == "patch"

def test_bump_type_minor_for_feat_commit():
    commits = ["feat: add new API endpoint"]
    assert determine_bump_type(commits) == "minor"

def test_bump_type_minor_beats_patch():
    commits = ["fix: small fix", "feat: cool feature", "fix: another fix"]
    assert determine_bump_type(commits) == "minor"

def test_bump_type_major_for_breaking_exclamation():
    commits = ["feat!: redesign public API"]
    assert determine_bump_type(commits) == "major"

def test_bump_type_major_for_fix_exclamation():
    commits = ["fix!: remove deprecated endpoint"]
    assert determine_bump_type(commits) == "major"

def test_bump_type_major_for_breaking_change_keyword():
    commits = ["feat: new feature", "BREAKING CHANGE: old API removed"]
    assert determine_bump_type(commits) == "major"

def test_bump_type_major_beats_minor():
    commits = ["feat: add feature", "feat!: breaking redesign"]
    assert determine_bump_type(commits) == "major"

def test_bump_type_scoped_feat():
    commits = ["feat(api): add new endpoint"]
    assert determine_bump_type(commits) == "minor"

def test_bump_type_scoped_breaking():
    commits = ["feat(api)!: breaking API change"]
    assert determine_bump_type(commits) == "major"


# --- bump_version ---

def test_bump_patch_increments_patch():
    assert bump_version((1, 0, 0), "patch") == (1, 0, 1)

def test_bump_patch_large_patch():
    assert bump_version((1, 2, 9), "patch") == (1, 2, 10)

def test_bump_minor_increments_minor_resets_patch():
    assert bump_version((1, 2, 3), "minor") == (1, 3, 0)

def test_bump_minor_from_zero():
    assert bump_version((0, 0, 0), "minor") == (0, 1, 0)

def test_bump_major_increments_major_resets_minor_patch():
    assert bump_version((1, 5, 3), "major") == (2, 0, 0)

def test_bump_major_from_zero():
    assert bump_version((0, 0, 0), "major") == (1, 0, 0)


# --- format_version ---

def test_format_version_basic():
    assert format_version((1, 2, 3)) == "1.2.3"

def test_format_version_zeros():
    assert format_version((0, 0, 0)) == "0.0.0"

def test_format_version_double_digits():
    assert format_version((10, 20, 30)) == "10.20.30"


# --- generate_changelog_entry ---

def test_changelog_includes_version_header():
    entry = generate_changelog_entry("1.2.0", ["feat: new feature"])
    assert "## 1.2.0" in entry

def test_changelog_categorizes_features():
    entry = generate_changelog_entry("1.2.0", ["feat: cool feature"])
    assert "Features" in entry
    assert "cool feature" in entry

def test_changelog_categorizes_fixes():
    entry = generate_changelog_entry("1.0.1", ["fix: nasty bug"])
    assert "Bug Fixes" in entry
    assert "nasty bug" in entry

def test_changelog_categorizes_breaking():
    entry = generate_changelog_entry("2.0.0", ["feat!: new API"])
    assert "Breaking" in entry

def test_changelog_multiple_categories():
    commits = ["feat: feature", "fix: bugfix", "feat!: breaking"]
    entry = generate_changelog_entry("2.0.0", commits)
    assert "Features" in entry
    assert "Bug Fixes" in entry
    assert "Breaking" in entry

def test_changelog_empty_commits():
    entry = generate_changelog_entry("1.0.1", [])
    assert "## 1.0.1" in entry


# --- read_version / write_version ---

def test_read_version_from_file():
    with tempfile.TemporaryDirectory() as d:
        v = Path(d) / "VERSION"
        v.write_text("1.0.0\n")
        assert read_version(str(v)) == "1.0.0"

def test_write_version_to_file():
    with tempfile.TemporaryDirectory() as d:
        v = Path(d) / "VERSION"
        v.write_text("1.0.0\n")
        write_version("1.1.0", str(v))
        assert v.read_text().strip() == "1.1.0"

def test_read_write_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        v = Path(d) / "VERSION"
        v.write_text("2.3.4\n")
        write_version("3.0.0", str(v))
        assert read_version(str(v)) == "3.0.0"

def test_read_version_from_package_json():
    with tempfile.TemporaryDirectory() as d:
        pkg = Path(d) / "package.json"
        pkg.write_text(json.dumps({"name": "test", "version": "2.0.0"}))
        assert read_version(str(pkg)) == "2.0.0"

def test_write_version_to_package_json():
    with tempfile.TemporaryDirectory() as d:
        pkg = Path(d) / "package.json"
        pkg.write_text(json.dumps({"name": "test", "version": "2.0.0"}))
        write_version("2.1.0", str(pkg))
        data = json.loads(pkg.read_text())
        assert data["version"] == "2.1.0"

def test_write_package_json_preserves_other_fields():
    with tempfile.TemporaryDirectory() as d:
        pkg = Path(d) / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "1.0.0", "license": "MIT"}))
        write_version("1.1.0", str(pkg))
        data = json.loads(pkg.read_text())
        assert data["name"] == "myapp"
        assert data["license"] == "MIT"

def test_read_version_missing_file_raises():
    with pytest.raises((FileNotFoundError, OSError)):
        read_version("/nonexistent/VERSION")


# --- read_commits ---

def test_read_commits_returns_list():
    with tempfile.TemporaryDirectory() as d:
        c = Path(d) / "commits.txt"
        c.write_text("feat: new feature\nfix: bug fix\n")
        commits = read_commits(str(c))
        assert len(commits) == 2

def test_read_commits_strips_blank_lines():
    with tempfile.TemporaryDirectory() as d:
        c = Path(d) / "commits.txt"
        c.write_text("feat: new feature\n\nfix: bug fix\n\n")
        commits = read_commits(str(c))
        assert len(commits) == 2

def test_read_commits_missing_file_returns_empty():
    commits = read_commits("/nonexistent/commits.txt")
    assert commits == []

def test_read_commits_content():
    with tempfile.TemporaryDirectory() as d:
        c = Path(d) / "commits.txt"
        c.write_text("feat: add login\nfix: typo\n")
        commits = read_commits(str(c))
        assert "feat: add login" in commits
        assert "fix: typo" in commits
