"""
Tests for semantic version bumper.
TDD approach: each test was written before the corresponding implementation.
"""

import json
import os
import pytest
import tempfile

# The module under test (will fail to import until we create it)
from version_bumper import (
    parse_version,
    determine_bump_type,
    bump_version,
    update_version_file,
    generate_changelog_entry,
    parse_commits,
)


# ---------------------------------------------------------------------------
# Fixtures: mock commit logs that serve as test data
# ---------------------------------------------------------------------------

FIXTURE_ONLY_PATCH = """\
abc1234 fix: correct off-by-one error in parser
def5678 fix: handle null pointer in auth module
a1b2c3d chore: update dependencies
"""

FIXTURE_MINOR_AND_PATCH = """\
abc1234 feat: add dark mode toggle
def5678 fix: resolve login redirect loop
a1b2c3d docs: update README badges
"""

FIXTURE_BREAKING_CHANGE = """\
abc1234 feat!: redesign public API endpoints
def5678 fix: normalise response codes
a1b2c3d refactor: extract helper utilities
"""

FIXTURE_BREAKING_IN_FOOTER = """\
abc1234 feat: add multi-tenant support

BREAKING CHANGE: `tenantId` now required in every request
def5678 fix: typo in error message
"""

FIXTURE_NO_RELEASABLE = """\
abc1234 chore: tidy CI config
def5678 docs: add contributing guide
a1b2c3d style: run formatter
"""

FIXTURE_EMPTY = ""


# ---------------------------------------------------------------------------
# 1. parse_version — read version from various file formats
# ---------------------------------------------------------------------------

class TestParseVersion:
    def test_parse_from_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "1.2.3"}))
        assert parse_version(str(pkg)) == "1.2.3"

    def test_parse_from_plain_version_file(self, tmp_path):
        ver = tmp_path / "VERSION"
        ver.write_text("2.0.0\n")
        assert parse_version(str(ver)) == "2.0.0"

    def test_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            parse_version(str(tmp_path / "nonexistent.json"))

    def test_package_json_missing_version_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app"}))
        with pytest.raises(KeyError):
            parse_version(str(pkg))

    def test_version_file_whitespace_stripped(self, tmp_path):
        ver = tmp_path / "VERSION"
        ver.write_text("  3.1.4  \n")
        assert parse_version(str(ver)) == "3.1.4"


# ---------------------------------------------------------------------------
# 2. parse_commits — turn raw log text into structured list
# ---------------------------------------------------------------------------

class TestParseCommits:
    def test_returns_list_of_dicts(self):
        commits = parse_commits(FIXTURE_ONLY_PATCH)
        assert isinstance(commits, list)
        assert all(isinstance(c, dict) for c in commits)

    def test_correct_count(self):
        assert len(parse_commits(FIXTURE_ONLY_PATCH)) == 3

    def test_commit_has_hash_and_message(self):
        commits = parse_commits(FIXTURE_ONLY_PATCH)
        assert commits[0]["hash"] == "abc1234"
        assert commits[0]["message"] == "fix: correct off-by-one error in parser"

    def test_empty_log_returns_empty_list(self):
        assert parse_commits(FIXTURE_EMPTY) == []

    def test_multiline_commit_body(self):
        # Commits with a blank line + body/footer are collected as one entry
        commits = parse_commits(FIXTURE_BREAKING_IN_FOOTER)
        assert len(commits) == 2  # two hash-prefixed commits


# ---------------------------------------------------------------------------
# 3. determine_bump_type — inspect commits, return 'major'/'minor'/'patch'
# ---------------------------------------------------------------------------

class TestDetermineBumpType:
    def test_fix_commits_give_patch(self):
        commits = parse_commits(FIXTURE_ONLY_PATCH)
        assert determine_bump_type(commits) == "patch"

    def test_feat_commit_gives_minor(self):
        commits = parse_commits(FIXTURE_MINOR_AND_PATCH)
        assert determine_bump_type(commits) == "minor"

    def test_breaking_exclamation_gives_major(self):
        commits = parse_commits(FIXTURE_BREAKING_CHANGE)
        assert determine_bump_type(commits) == "major"

    def test_breaking_change_footer_gives_major(self):
        commits = parse_commits(FIXTURE_BREAKING_IN_FOOTER)
        assert determine_bump_type(commits) == "major"

    def test_no_releasable_commits_gives_patch(self):
        # chore/docs/style → default to patch bump
        commits = parse_commits(FIXTURE_NO_RELEASABLE)
        assert determine_bump_type(commits) == "patch"

    def test_empty_commits_gives_patch(self):
        assert determine_bump_type([]) == "patch"


# ---------------------------------------------------------------------------
# 4. bump_version — calculate the next semver string
# ---------------------------------------------------------------------------

class TestBumpVersion:
    def test_patch_bump(self):
        assert bump_version("1.2.3", "patch") == "1.2.4"

    def test_minor_bump_resets_patch(self):
        assert bump_version("1.2.3", "minor") == "1.3.0"

    def test_major_bump_resets_minor_and_patch(self):
        assert bump_version("1.2.3", "major") == "2.0.0"

    def test_zero_patch_bump(self):
        assert bump_version("0.0.0", "patch") == "0.0.1"

    def test_invalid_bump_type_raises(self):
        with pytest.raises(ValueError):
            bump_version("1.0.0", "banana")

    def test_invalid_version_string_raises(self):
        with pytest.raises(ValueError):
            bump_version("not-a-version", "patch")


# ---------------------------------------------------------------------------
# 5. update_version_file — write new version back to file
# ---------------------------------------------------------------------------

class TestUpdateVersionFile:
    def test_updates_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "1.0.0"}, indent=2))
        update_version_file(str(pkg), "1.1.0")
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.1.0"

    def test_package_json_preserves_other_fields(self, tmp_path):
        pkg = tmp_path / "package.json"
        original = {"name": "my-app", "version": "1.0.0", "description": "test"}
        pkg.write_text(json.dumps(original, indent=2))
        update_version_file(str(pkg), "2.0.0")
        data = json.loads(pkg.read_text())
        assert data["name"] == "my-app"
        assert data["description"] == "test"

    def test_updates_plain_version_file(self, tmp_path):
        ver = tmp_path / "VERSION"
        ver.write_text("1.0.0\n")
        update_version_file(str(ver), "1.0.1")
        assert ver.read_text().strip() == "1.0.1"

    def test_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            update_version_file(str(tmp_path / "ghost.json"), "1.0.0")


# ---------------------------------------------------------------------------
# 6. generate_changelog_entry — produce a human-readable entry
# ---------------------------------------------------------------------------

class TestGenerateChangelogEntry:
    def test_entry_contains_new_version(self):
        commits = parse_commits(FIXTURE_MINOR_AND_PATCH)
        entry = generate_changelog_entry("1.3.0", commits)
        assert "1.3.0" in entry

    def test_entry_contains_feat_section(self):
        commits = parse_commits(FIXTURE_MINOR_AND_PATCH)
        entry = generate_changelog_entry("1.3.0", commits)
        assert "feat" in entry.lower() or "feature" in entry.lower()

    def test_entry_contains_fix_section(self):
        commits = parse_commits(FIXTURE_MINOR_AND_PATCH)
        entry = generate_changelog_entry("1.3.0", commits)
        assert "fix" in entry.lower()

    def test_entry_lists_commit_messages(self):
        commits = parse_commits(FIXTURE_ONLY_PATCH)
        entry = generate_changelog_entry("0.1.1", commits)
        assert "correct off-by-one error in parser" in entry

    def test_empty_commits_still_produces_entry(self):
        entry = generate_changelog_entry("1.0.1", [])
        assert "1.0.1" in entry


# ---------------------------------------------------------------------------
# Integration test: full pipeline end-to-end
# ---------------------------------------------------------------------------

class TestEndToEnd:
    def test_full_pipeline_patch_bump(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "1.2.3"}, indent=2))

        old_version = parse_version(str(pkg))
        commits = parse_commits(FIXTURE_ONLY_PATCH)
        bump_type = determine_bump_type(commits)
        new_version = bump_version(old_version, bump_type)
        update_version_file(str(pkg), new_version)
        entry = generate_changelog_entry(new_version, commits)

        assert new_version == "1.2.4"
        assert json.loads(pkg.read_text())["version"] == "1.2.4"
        assert "1.2.4" in entry

    def test_full_pipeline_major_bump(self, tmp_path):
        ver = tmp_path / "VERSION"
        ver.write_text("3.5.2\n")

        old_version = parse_version(str(ver))
        commits = parse_commits(FIXTURE_BREAKING_CHANGE)
        bump_type = determine_bump_type(commits)
        new_version = bump_version(old_version, bump_type)
        update_version_file(str(ver), new_version)

        assert new_version == "4.0.0"
        assert ver.read_text().strip() == "4.0.0"
