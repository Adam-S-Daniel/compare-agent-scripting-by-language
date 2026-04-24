"""
TDD tests for semantic version bumper.
RED phase: All tests written before implementation.
"""
import json
import os
import sys
import pytest
import tempfile

# Add parent dir to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import version_bumper


# --- Test fixtures: conventional commit messages ---

FIXTURE_PATCH_COMMITS = [
    "fix: correct off-by-one error in pagination",
    "fix(auth): handle expired tokens properly",
    "docs: update README",
    "chore: update dependencies",
]

FIXTURE_MINOR_COMMITS = [
    "feat: add user profile endpoint",
    "fix: correct typo in error message",
    "chore: run formatter",
]

FIXTURE_MAJOR_COMMITS = [
    "feat!: remove deprecated v1 API",
    "fix: patch null pointer",
]

FIXTURE_MAJOR_COMMITS_FOOTER = [
    "feat: add new authentication system\n\nBREAKING CHANGE: old auth tokens no longer valid",
    "fix: patch cors issue",
]

FIXTURE_NO_BUMP_COMMITS = [
    "docs: update contributing guide",
    "chore: bump dev dependency",
    "style: fix linting warnings",
    "ci: update pipeline config",
]


# ============================================================
# 1. Version parsing tests
# ============================================================

class TestParseVersion:
    def test_parse_from_version_file(self, tmp_path):
        """Read semantic version from a plain VERSION file."""
        v_file = tmp_path / "VERSION"
        v_file.write_text("1.2.3\n")
        assert version_bumper.parse_version(str(v_file)) == (1, 2, 3)

    def test_parse_from_package_json(self, tmp_path):
        """Read semantic version from package.json."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "2.5.11"}))
        assert version_bumper.parse_version(str(pkg)) == (2, 5, 11)

    def test_parse_version_zero(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("0.0.0")
        assert version_bumper.parse_version(str(v_file)) == (0, 0, 0)

    def test_parse_missing_file_raises(self):
        with pytest.raises(FileNotFoundError):
            version_bumper.parse_version("/no/such/file.txt")

    def test_parse_invalid_version_raises(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("not-a-version")
        with pytest.raises(ValueError, match="Invalid semantic version"):
            version_bumper.parse_version(str(v_file))

    def test_parse_package_json_missing_version_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp"}))
        with pytest.raises(ValueError, match="No 'version' field"):
            version_bumper.parse_version(str(pkg))


# ============================================================
# 2. Commit classification tests
# ============================================================

class TestClassifyCommits:
    def test_patch_commits_yield_patch(self):
        assert version_bumper.determine_bump_type(FIXTURE_PATCH_COMMITS) == "patch"

    def test_feat_commit_yields_minor(self):
        assert version_bumper.determine_bump_type(FIXTURE_MINOR_COMMITS) == "minor"

    def test_breaking_bang_yields_major(self):
        assert version_bumper.determine_bump_type(FIXTURE_MAJOR_COMMITS) == "major"

    def test_breaking_footer_yields_major(self):
        assert version_bumper.determine_bump_type(FIXTURE_MAJOR_COMMITS_FOOTER) == "major"

    def test_no_releasable_commits_yields_none(self):
        assert version_bumper.determine_bump_type(FIXTURE_NO_BUMP_COMMITS) is None

    def test_empty_commit_list_yields_none(self):
        assert version_bumper.determine_bump_type([]) is None

    def test_major_beats_minor(self):
        mixed = FIXTURE_MINOR_COMMITS + FIXTURE_MAJOR_COMMITS
        assert version_bumper.determine_bump_type(mixed) == "major"

    def test_minor_beats_patch(self):
        mixed = FIXTURE_PATCH_COMMITS + FIXTURE_MINOR_COMMITS
        assert version_bumper.determine_bump_type(mixed) == "minor"


# ============================================================
# 3. Version calculation tests
# ============================================================

class TestCalculateNextVersion:
    def test_patch_bump(self):
        assert version_bumper.calculate_next_version((1, 2, 3), "patch") == (1, 2, 4)

    def test_minor_bump_resets_patch(self):
        assert version_bumper.calculate_next_version((1, 2, 3), "minor") == (1, 3, 0)

    def test_major_bump_resets_minor_and_patch(self):
        assert version_bumper.calculate_next_version((1, 2, 3), "major") == (2, 0, 0)

    def test_none_bump_returns_same(self):
        assert version_bumper.calculate_next_version((1, 2, 3), None) == (1, 2, 3)

    def test_patch_from_zero(self):
        assert version_bumper.calculate_next_version((0, 0, 0), "patch") == (0, 0, 1)

    def test_version_to_string(self):
        assert version_bumper.version_to_str((2, 5, 11)) == "2.5.11"


# ============================================================
# 4. Version file update tests
# ============================================================

class TestUpdateVersionFile:
    def test_update_version_file(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("1.0.0\n")
        version_bumper.update_version_file(str(v_file), (1, 1, 0))
        assert v_file.read_text().strip() == "1.1.0"

    def test_update_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        original = {"name": "myapp", "version": "1.0.0", "description": "test"}
        pkg.write_text(json.dumps(original, indent=2))
        version_bumper.update_version_file(str(pkg), (1, 1, 0))
        updated = json.loads(pkg.read_text())
        assert updated["version"] == "1.1.0"
        # Other fields must be preserved
        assert updated["name"] == "myapp"
        assert updated["description"] == "test"


# ============================================================
# 5. Changelog generation tests
# ============================================================

class TestGenerateChangelog:
    def test_changelog_contains_version(self):
        entry = version_bumper.generate_changelog("1.3.0", FIXTURE_MINOR_COMMITS, "2026-04-19")
        assert "1.3.0" in entry

    def test_changelog_contains_date(self):
        entry = version_bumper.generate_changelog("1.3.0", FIXTURE_MINOR_COMMITS, "2026-04-19")
        assert "2026-04-19" in entry

    def test_changelog_lists_feat_commits(self):
        entry = version_bumper.generate_changelog("1.3.0", FIXTURE_MINOR_COMMITS, "2026-04-19")
        assert "add user profile endpoint" in entry

    def test_changelog_lists_fix_commits(self):
        entry = version_bumper.generate_changelog("1.3.0", FIXTURE_PATCH_COMMITS, "2026-04-19")
        assert "correct off-by-one error" in entry

    def test_changelog_omits_chore_and_docs(self):
        entry = version_bumper.generate_changelog("1.3.0", FIXTURE_NO_BUMP_COMMITS, "2026-04-19")
        # Non-releasable commits should NOT appear as changelog items
        assert "update contributing guide" not in entry

    def test_changelog_prepends_to_existing(self, tmp_path):
        changelog = tmp_path / "CHANGELOG.md"
        changelog.write_text("# Changelog\n\n## [1.0.0] - 2026-01-01\n\n- Initial release\n")
        entry = version_bumper.generate_changelog("1.1.0", FIXTURE_MINOR_COMMITS, "2026-04-19")
        version_bumper.prepend_changelog(str(changelog), entry)
        content = changelog.read_text()
        assert content.index("1.1.0") < content.index("1.0.0")


# ============================================================
# 6. End-to-end / integration tests
# ============================================================

class TestEndToEnd:
    def test_full_pipeline_minor_bump(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("1.2.3\n")
        changelog = tmp_path / "CHANGELOG.md"
        changelog.write_text("")

        result = version_bumper.run(
            version_file=str(v_file),
            commits=FIXTURE_MINOR_COMMITS,
            changelog_file=str(changelog),
            today="2026-04-19",
        )

        assert result == "1.3.0"
        assert v_file.read_text().strip() == "1.3.0"
        assert "1.3.0" in changelog.read_text()

    def test_full_pipeline_patch_bump(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("1.2.3\n")
        changelog = tmp_path / "CHANGELOG.md"
        changelog.write_text("")

        result = version_bumper.run(
            version_file=str(v_file),
            commits=FIXTURE_PATCH_COMMITS,
            changelog_file=str(changelog),
            today="2026-04-19",
        )
        assert result == "1.2.4"

    def test_full_pipeline_major_bump(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("2.0.0\n")
        changelog = tmp_path / "CHANGELOG.md"
        changelog.write_text("")

        result = version_bumper.run(
            version_file=str(v_file),
            commits=FIXTURE_MAJOR_COMMITS,
            changelog_file=str(changelog),
            today="2026-04-19",
        )
        assert result == "3.0.0"

    def test_full_pipeline_no_bump(self, tmp_path):
        v_file = tmp_path / "VERSION"
        v_file.write_text("1.0.0\n")
        changelog = tmp_path / "CHANGELOG.md"
        changelog.write_text("")

        result = version_bumper.run(
            version_file=str(v_file),
            commits=FIXTURE_NO_BUMP_COMMITS,
            changelog_file=str(changelog),
            today="2026-04-19",
        )
        assert result == "1.0.0"

    def test_package_json_pipeline(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "0.9.0"}))
        changelog = tmp_path / "CHANGELOG.md"
        changelog.write_text("")

        result = version_bumper.run(
            version_file=str(pkg),
            commits=FIXTURE_MINOR_COMMITS,
            changelog_file=str(changelog),
            today="2026-04-19",
        )
        assert result == "0.10.0"
        assert json.loads(pkg.read_text())["version"] == "0.10.0"
