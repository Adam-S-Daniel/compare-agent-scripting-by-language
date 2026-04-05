# Semantic Version Bumper - TDD Tests
# Approach: Red/Green TDD - each test is written first (failing), then the minimum
# implementation is added to make it pass, then refactored.
#
# Features under test:
# 1. Parse version from package.json / version file
# 2. Determine bump type from conventional commits
# 3. Calculate next semantic version
# 4. Update the version file
# 5. Generate changelog entry
# 6. Full integration: parse commits, bump, write changelog

import json
import pytest

from semver_bumper import (
    parse_version,
    determine_bump_type,
    bump_version,
    update_version_file,
    generate_changelog,
    run_version_bump,
)

# ---------------------------------------------------------------------------
# Test fixtures — mock commit logs
# ---------------------------------------------------------------------------

PATCH_COMMITS = [
    "fix: correct off-by-one error in pagination",
    "fix: handle null pointer in user lookup",
    "docs: update README with installation steps",
]

MINOR_COMMITS = [
    "feat: add dark mode support",
    "fix: resolve login redirect issue",
    "chore: upgrade dependencies",
]

MAJOR_COMMITS = [
    "feat!: redesign public API (breaking change)",
    "fix: patch XSS vulnerability",
]

MAJOR_COMMITS_FOOTER = [
    "feat: new authentication flow\n\nBREAKING CHANGE: removed legacy /auth endpoint",
    "fix: typo in error message",
]

NO_BUMP_COMMITS = [
    "docs: fix typo in contributing guide",
    "chore: update CI configuration",
    "style: reformat code with prettier",
]

# ---------------------------------------------------------------------------
# 1. Parse version from package.json
# ---------------------------------------------------------------------------

class TestParseVersion:
    def test_parse_version_from_package_json(self, tmp_path):
        """Parse semantic version string from a package.json file."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "1.2.3"}))
        assert parse_version(str(pkg)) == "1.2.3"

    def test_parse_version_from_version_txt(self, tmp_path):
        """Parse semantic version from a plain version.txt file."""
        vf = tmp_path / "version.txt"
        vf.write_text("2.0.1\n")
        assert parse_version(str(vf)) == "2.0.1"

    def test_parse_version_missing_file_raises(self, tmp_path):
        """Raise FileNotFoundError when the version file does not exist."""
        with pytest.raises(FileNotFoundError):
            parse_version(str(tmp_path / "nonexistent.json"))

    def test_parse_version_invalid_semver_raises(self, tmp_path):
        """Raise ValueError when the version string is not valid semver."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "not-a-version"}))
        with pytest.raises(ValueError):
            parse_version(str(pkg))

    def test_parse_version_missing_key_raises(self, tmp_path):
        """Raise ValueError when package.json has no 'version' key."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app"}))
        with pytest.raises(ValueError):
            parse_version(str(pkg))


# ---------------------------------------------------------------------------
# 2. Determine bump type from conventional commits
# ---------------------------------------------------------------------------

class TestDetermineBumpType:
    def test_fix_commits_produce_patch(self):
        """fix: commits should result in a patch bump."""
        assert determine_bump_type(PATCH_COMMITS) == "patch"

    def test_feat_commits_produce_minor(self):
        """feat: commits should result in a minor bump."""
        assert determine_bump_type(MINOR_COMMITS) == "minor"

    def test_breaking_exclamation_produces_major(self):
        """feat!: or fix!: commits should result in a major bump."""
        assert determine_bump_type(MAJOR_COMMITS) == "major"

    def test_breaking_footer_produces_major(self):
        """Commits with BREAKING CHANGE footer should result in a major bump."""
        assert determine_bump_type(MAJOR_COMMITS_FOOTER) == "major"

    def test_no_conventional_commits_returns_none(self):
        """Non-conventional commits (docs, chore, style) return None (no bump)."""
        assert determine_bump_type(NO_BUMP_COMMITS) is None

    def test_empty_commits_returns_none(self):
        """Empty commit list returns None."""
        assert determine_bump_type([]) is None

    def test_major_takes_precedence_over_minor(self):
        """major bump wins over minor when both are present."""
        mixed = ["feat: add feature", "feat!: breaking redesign"]
        assert determine_bump_type(mixed) == "major"

    def test_minor_takes_precedence_over_patch(self):
        """minor bump wins over patch when both are present."""
        mixed = ["fix: a small fix", "feat: a new feature"]
        assert determine_bump_type(mixed) == "minor"


# ---------------------------------------------------------------------------
# 3. Calculate next semantic version
# ---------------------------------------------------------------------------

class TestBumpVersion:
    def test_patch_bump(self):
        assert bump_version("1.2.3", "patch") == "1.2.4"

    def test_minor_bump_resets_patch(self):
        assert bump_version("1.2.3", "minor") == "1.3.0"

    def test_major_bump_resets_minor_and_patch(self):
        assert bump_version("1.2.3", "major") == "2.0.0"

    def test_patch_from_zero(self):
        assert bump_version("0.0.0", "patch") == "0.0.1"

    def test_minor_from_zero(self):
        assert bump_version("0.0.0", "minor") == "0.1.0"

    def test_major_from_zero(self):
        assert bump_version("0.0.0", "major") == "1.0.0"

    def test_invalid_bump_type_raises(self):
        with pytest.raises(ValueError):
            bump_version("1.0.0", "invalid")

    def test_invalid_version_raises(self):
        with pytest.raises(ValueError):
            bump_version("not-semver", "patch")


# ---------------------------------------------------------------------------
# 4. Update the version file
# ---------------------------------------------------------------------------

class TestUpdateVersionFile:
    def test_update_package_json(self, tmp_path):
        """Version field in package.json is updated in-place."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "1.0.0"}, indent=2))
        update_version_file(str(pkg), "1.1.0")
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.1.0"
        assert data["name"] == "my-app"  # other fields preserved

    def test_update_version_txt(self, tmp_path):
        """Plain version.txt is overwritten with the new version."""
        vf = tmp_path / "version.txt"
        vf.write_text("1.0.0\n")
        update_version_file(str(vf), "2.0.0")
        assert vf.read_text().strip() == "2.0.0"

    def test_update_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            update_version_file(str(tmp_path / "missing.json"), "1.0.0")


# ---------------------------------------------------------------------------
# 5. Generate changelog entry
# ---------------------------------------------------------------------------

class TestGenerateChangelog:
    def test_changelog_contains_new_version(self):
        entry = generate_changelog("1.3.0", MINOR_COMMITS)
        assert "1.3.0" in entry

    def test_changelog_groups_features(self):
        entry = generate_changelog("1.3.0", MINOR_COMMITS)
        assert "feat" in entry.lower() or "feature" in entry.lower()

    def test_changelog_groups_fixes(self):
        entry = generate_changelog("1.2.4", PATCH_COMMITS)
        assert "fix" in entry.lower()

    def test_changelog_includes_commit_messages(self):
        entry = generate_changelog("1.3.0", MINOR_COMMITS)
        assert "dark mode" in entry

    def test_changelog_excludes_non_release_commits(self):
        """docs/chore/style commits are excluded from the changelog body."""
        entry = generate_changelog("1.3.0", MINOR_COMMITS)
        # "upgrade dependencies" is a chore and should not appear
        assert "upgrade dependencies" not in entry

    def test_changelog_empty_commits_still_has_header(self):
        entry = generate_changelog("1.0.1", [])
        assert "1.0.1" in entry


# ---------------------------------------------------------------------------
# 6. Integration: run_version_bump end-to-end
# ---------------------------------------------------------------------------

class TestRunVersionBump:
    def test_full_minor_bump_on_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "1.2.3"}, indent=2))
        new_version = run_version_bump(str(pkg), MINOR_COMMITS)
        assert new_version == "1.3.0"
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.3.0"

    def test_full_patch_bump_on_version_txt(self, tmp_path):
        vf = tmp_path / "version.txt"
        vf.write_text("0.9.5\n")
        new_version = run_version_bump(str(vf), PATCH_COMMITS)
        assert new_version == "0.9.6"
        assert vf.read_text().strip() == "0.9.6"

    def test_full_major_bump(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "2.1.0"}, indent=2))
        new_version = run_version_bump(str(pkg), MAJOR_COMMITS)
        assert new_version == "3.0.0"

    def test_no_conventional_commits_no_bump(self, tmp_path):
        """When commits produce no bump type, version stays the same."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "1.0.0"}, indent=2))
        new_version = run_version_bump(str(pkg), NO_BUMP_COMMITS)
        assert new_version == "1.0.0"
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.0.0"

    def test_run_returns_changelog_as_well(self, tmp_path):
        """run_version_bump returns (new_version, changelog_entry) when asked."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "1.0.0"}, indent=2))
        result = run_version_bump(str(pkg), MINOR_COMMITS, return_changelog=True)
        assert isinstance(result, tuple)
        new_version, changelog = result
        assert new_version == "1.1.0"
        assert "1.1.0" in changelog
