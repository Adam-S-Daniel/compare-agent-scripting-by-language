"""
Tests for semantic version bumper using red/green TDD methodology.

Test order reflects the TDD cycle:
1. Write failing test
2. Write minimum code to pass
3. Refactor
4. Repeat

Run with: pytest test_version_bumper.py -v
"""

import json
import os
import tempfile
import pytest

# Import the module under test (will fail until we create it)
from version_bumper import (
    parse_version,
    parse_commit_type,
    bump_version,
    generate_changelog,
    update_version_file,
    process_commits,
)


# ---------------------------------------------------------------------------
# Test fixtures: mock commit logs
# ---------------------------------------------------------------------------

FIXTURE_COMMITS_PATCH = [
    "fix: correct null pointer in login handler",
    "fix: handle empty string in email validator",
    "chore: update dependencies",
]

FIXTURE_COMMITS_MINOR = [
    "feat: add user profile endpoint",
    "fix: typo in README",
    "docs: update API docs",
]

FIXTURE_COMMITS_MAJOR = [
    "feat!: rewrite authentication system",
    "fix: minor styling issue",
]

FIXTURE_COMMITS_MAJOR_FOOTER = [
    "feat: new payment processor\n\nBREAKING CHANGE: old payment API removed",
    "fix: correct rounding error",
]

FIXTURE_COMMITS_NO_BUMP = [
    "chore: clean up temp files",
    "docs: improve README",
    "style: format code",
]

FIXTURE_COMMITS_MIXED = [
    "feat: add dark mode",
    "fix: button alignment",
    "feat: export to CSV",
    "chore: update linter config",
]


# ---------------------------------------------------------------------------
# Phase 1: Parse version from package.json
# ---------------------------------------------------------------------------

class TestParseVersion:
    """TDD Phase 1 — parse version string from package.json."""

    def test_parse_version_from_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "1.2.3"}))
        assert parse_version(str(pkg)) == "1.2.3"

    def test_parse_version_initial_zero(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "0.0.0"}))
        assert parse_version(str(pkg)) == "0.0.0"

    def test_parse_version_missing_key_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "no-version"}))
        with pytest.raises(KeyError, match="version"):
            parse_version(str(pkg))

    def test_parse_version_file_not_found_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            parse_version(str(tmp_path / "nonexistent.json"))

    def test_parse_version_plain_text_file(self, tmp_path):
        """Also support a plain VERSION file containing just the version string."""
        ver_file = tmp_path / "VERSION"
        ver_file.write_text("2.5.1\n")
        assert parse_version(str(ver_file)) == "2.5.1"


# ---------------------------------------------------------------------------
# Phase 2: Parse conventional commit type
# ---------------------------------------------------------------------------

class TestParseCommitType:
    """TDD Phase 2 — classify a commit message as patch/minor/major/none."""

    def test_fix_is_patch(self):
        assert parse_commit_type("fix: correct null pointer") == "patch"

    def test_feat_is_minor(self):
        assert parse_commit_type("feat: add new endpoint") == "minor"

    def test_breaking_exclamation_is_major(self):
        assert parse_commit_type("feat!: rewrite auth") == "major"

    def test_fix_breaking_exclamation_is_major(self):
        assert parse_commit_type("fix!: remove deprecated param") == "major"

    def test_breaking_change_footer_is_major(self):
        msg = "feat: new API\n\nBREAKING CHANGE: old API removed"
        assert parse_commit_type(msg) == "major"

    def test_chore_is_none(self):
        assert parse_commit_type("chore: update deps") is None

    def test_docs_is_none(self):
        assert parse_commit_type("docs: update readme") is None

    def test_style_is_none(self):
        assert parse_commit_type("style: reformat") is None

    def test_refactor_is_none(self):
        assert parse_commit_type("refactor: extract helper") is None

    def test_non_conventional_is_none(self):
        assert parse_commit_type("random commit message") is None

    def test_scope_in_feat(self):
        assert parse_commit_type("feat(api): add rate limiting") == "minor"

    def test_scope_in_fix(self):
        assert parse_commit_type("fix(auth): handle token expiry") == "patch"

    def test_scope_breaking(self):
        assert parse_commit_type("feat(core)!: redesign config") == "major"


# ---------------------------------------------------------------------------
# Phase 3: Bump version
# ---------------------------------------------------------------------------

class TestBumpVersion:
    """TDD Phase 3 — compute the next version."""

    def test_bump_patch(self):
        assert bump_version("1.2.3", "patch") == "1.2.4"

    def test_bump_minor(self):
        assert bump_version("1.2.3", "minor") == "1.3.0"

    def test_bump_major(self):
        assert bump_version("1.2.3", "major") == "2.0.0"

    def test_bump_patch_from_zero(self):
        assert bump_version("0.0.0", "patch") == "0.0.1"

    def test_bump_minor_resets_patch(self):
        assert bump_version("1.5.9", "minor") == "1.6.0"

    def test_bump_major_resets_minor_and_patch(self):
        assert bump_version("3.7.2", "major") == "4.0.0"

    def test_bump_none_returns_same(self):
        assert bump_version("1.2.3", None) == "1.2.3"

    def test_invalid_version_raises(self):
        with pytest.raises(ValueError, match="Invalid version"):
            bump_version("not-a-version", "patch")


# ---------------------------------------------------------------------------
# Phase 4: Determine bump level from a list of commits
# ---------------------------------------------------------------------------

class TestProcessCommits:
    """TDD Phase 4 — determine the highest bump level from commit list."""

    def test_all_fixes_gives_patch(self):
        assert process_commits(FIXTURE_COMMITS_PATCH) == "patch"

    def test_feat_in_list_gives_minor(self):
        assert process_commits(FIXTURE_COMMITS_MINOR) == "minor"

    def test_breaking_in_list_gives_major(self):
        assert process_commits(FIXTURE_COMMITS_MAJOR) == "major"

    def test_breaking_footer_gives_major(self):
        assert process_commits(FIXTURE_COMMITS_MAJOR_FOOTER) == "major"

    def test_no_relevant_commits_gives_none(self):
        assert process_commits(FIXTURE_COMMITS_NO_BUMP) is None

    def test_feat_and_fix_gives_minor(self):
        assert process_commits(FIXTURE_COMMITS_MIXED) == "minor"

    def test_empty_list_gives_none(self):
        assert process_commits([]) is None


# ---------------------------------------------------------------------------
# Phase 5: Generate changelog entry
# ---------------------------------------------------------------------------

class TestGenerateChangelog:
    """TDD Phase 5 — format a changelog entry from commits."""

    def test_changelog_includes_new_version(self):
        entry = generate_changelog("1.3.0", FIXTURE_COMMITS_MINOR)
        assert "1.3.0" in entry

    def test_changelog_lists_features(self):
        entry = generate_changelog("1.3.0", FIXTURE_COMMITS_MINOR)
        assert "add user profile endpoint" in entry

    def test_changelog_lists_fixes(self):
        entry = generate_changelog("1.2.4", FIXTURE_COMMITS_PATCH)
        assert "correct null pointer" in entry or "null pointer" in entry

    def test_changelog_has_sections(self):
        commits = [
            "feat: add search",
            "fix: correct crash on empty input",
        ]
        entry = generate_changelog("2.0.0", commits)
        # Should have separate sections for features and fixes
        assert "feat" in entry.lower() or "feature" in entry.lower()
        assert "fix" in entry.lower()

    def test_changelog_skips_chore(self):
        commits = ["feat: new thing", "chore: update deps"]
        entry = generate_changelog("1.1.0", commits)
        assert "update deps" not in entry

    def test_changelog_no_commits_returns_minimal(self):
        entry = generate_changelog("1.0.0", [])
        assert "1.0.0" in entry

    def test_changelog_includes_date(self):
        from datetime import date
        entry = generate_changelog("1.0.0", FIXTURE_COMMITS_PATCH)
        today = date.today().isoformat()
        assert today in entry


# ---------------------------------------------------------------------------
# Phase 6: Update version file
# ---------------------------------------------------------------------------

class TestUpdateVersionFile:
    """TDD Phase 6 — write new version back to the file."""

    def test_update_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "1.0.0"}, indent=2))
        update_version_file(str(pkg), "1.1.0")
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.1.0"

    def test_update_preserves_other_fields(self, tmp_path):
        pkg = tmp_path / "package.json"
        original = {"name": "app", "version": "1.0.0", "description": "test"}
        pkg.write_text(json.dumps(original, indent=2))
        update_version_file(str(pkg), "2.0.0")
        data = json.loads(pkg.read_text())
        assert data["name"] == "app"
        assert data["description"] == "test"

    def test_update_plain_version_file(self, tmp_path):
        ver_file = tmp_path / "VERSION"
        ver_file.write_text("1.0.0\n")
        update_version_file(str(ver_file), "1.1.0")
        assert ver_file.read_text().strip() == "1.1.0"

    def test_update_file_not_found_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            update_version_file(str(tmp_path / "missing.json"), "1.0.0")
