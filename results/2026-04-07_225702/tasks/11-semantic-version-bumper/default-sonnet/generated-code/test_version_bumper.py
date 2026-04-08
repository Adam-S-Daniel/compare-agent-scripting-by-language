"""
TDD tests for semantic version bumper.
Red/Green cycle: write failing test first, then implement minimum code to pass.
"""
import json
import os
import tempfile
import pytest
from pathlib import Path


# ── Cycle 1: Parse version from package.json ──────────────────────────────────

class TestParseVersion:
    def test_parse_version_from_package_json(self, tmp_path):
        """RED: parse semantic version string from package.json"""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "1.2.3"}))

        from version_bumper import parse_version
        assert parse_version(str(pkg)) == "1.2.3"

    def test_parse_version_from_version_file(self, tmp_path):
        """RED: parse semantic version from a plain VERSION file"""
        ver_file = tmp_path / "VERSION"
        ver_file.write_text("2.5.0\n")

        from version_bumper import parse_version
        assert parse_version(str(ver_file)) == "2.5.0"

    def test_parse_version_missing_file_raises(self, tmp_path):
        """RED: missing file should raise FileNotFoundError"""
        from version_bumper import parse_version
        with pytest.raises(FileNotFoundError, match="Version file not found"):
            parse_version(str(tmp_path / "nonexistent.json"))


# ── Cycle 2: Classify commits ─────────────────────────────────────────────────

class TestClassifyCommits:
    def test_fix_commit_is_patch(self):
        """RED: 'fix: ...' → patch bump"""
        from version_bumper import classify_commits
        assert classify_commits(["fix: correct null pointer"]) == "patch"

    def test_feat_commit_is_minor(self):
        """RED: 'feat: ...' → minor bump"""
        from version_bumper import classify_commits
        assert classify_commits(["feat: add dark mode"]) == "minor"

    def test_breaking_change_footer_is_major(self):
        """RED: commit with BREAKING CHANGE footer → major bump"""
        from version_bumper import classify_commits
        commits = ["feat!: redesign API\n\nBREAKING CHANGE: removed /v1 endpoints"]
        assert classify_commits(commits) == "major"

    def test_breaking_bang_is_major(self):
        """RED: 'feat!' or 'fix!' shorthand → major bump"""
        from version_bumper import classify_commits
        assert classify_commits(["fix!: drop Python 2 support"]) == "major"

    def test_mixed_commits_highest_wins(self):
        """RED: multiple commits → highest bump level wins"""
        from version_bumper import classify_commits
        commits = ["fix: typo", "feat: new widget"]
        assert classify_commits(commits) == "minor"

    def test_no_conventional_commits_returns_none(self):
        """RED: no recognisable commit type → None"""
        from version_bumper import classify_commits
        assert classify_commits(["chore: update deps", "docs: readme"]) is None

    def test_empty_commits_returns_none(self):
        """RED: empty list → None"""
        from version_bumper import classify_commits
        assert classify_commits([]) is None


# ── Cycle 3: Bump version ─────────────────────────────────────────────────────

class TestBumpVersion:
    def test_bump_patch(self):
        from version_bumper import bump_version
        assert bump_version("1.2.3", "patch") == "1.2.4"

    def test_bump_minor_resets_patch(self):
        from version_bumper import bump_version
        assert bump_version("1.2.3", "minor") == "1.3.0"

    def test_bump_major_resets_minor_and_patch(self):
        from version_bumper import bump_version
        assert bump_version("1.2.3", "major") == "2.0.0"

    def test_invalid_bump_type_raises(self):
        from version_bumper import bump_version
        with pytest.raises(ValueError, match="Unknown bump type"):
            bump_version("1.0.0", "mega")

    def test_invalid_version_format_raises(self):
        from version_bumper import bump_version
        with pytest.raises(ValueError, match="Invalid semantic version"):
            bump_version("not-a-version", "patch")


# ── Cycle 4: Write updated version back to file ───────────────────────────────

class TestWriteVersion:
    def test_write_version_to_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "1.0.0"}, indent=2))

        from version_bumper import write_version
        write_version(str(pkg), "1.1.0")

        data = json.loads(pkg.read_text())
        assert data["version"] == "1.1.0"

    def test_write_version_to_version_file(self, tmp_path):
        ver_file = tmp_path / "VERSION"
        ver_file.write_text("1.0.0\n")

        from version_bumper import write_version
        write_version(str(ver_file), "2.0.0")

        assert ver_file.read_text().strip() == "2.0.0"

    def test_write_version_missing_file_raises(self, tmp_path):
        from version_bumper import write_version
        with pytest.raises(FileNotFoundError, match="Version file not found"):
            write_version(str(tmp_path / "nope.json"), "1.0.0")


# ── Cycle 5: Generate changelog entry ────────────────────────────────────────

class TestGenerateChangelog:
    def test_changelog_contains_new_version(self):
        from version_bumper import generate_changelog
        entry = generate_changelog("1.3.0", ["feat: add search"])
        assert "1.3.0" in entry

    def test_changelog_groups_by_type(self):
        from version_bumper import generate_changelog
        commits = ["feat: add search", "fix: broken login", "feat: dark mode"]
        entry = generate_changelog("1.3.0", commits)
        assert "Features" in entry
        assert "Bug Fixes" in entry

    def test_changelog_lists_commit_messages(self):
        from version_bumper import generate_changelog
        commits = ["fix: correct null pointer"]
        entry = generate_changelog("1.2.4", commits)
        assert "correct null pointer" in entry

    def test_changelog_includes_date(self):
        from version_bumper import generate_changelog
        entry = generate_changelog("1.0.0", ["fix: something"])
        import re
        assert re.search(r"\d{4}-\d{2}-\d{2}", entry), "Expected ISO date in changelog"


# ── Cycle 6: End-to-end ───────────────────────────────────────────────────────

class TestEndToEnd:
    def test_full_pipeline_feat(self, tmp_path):
        """feat commit bumps minor, writes file, returns new version string"""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "1.2.3"}))

        from version_bumper import run
        commits = ["feat: brand new feature"]
        new_version, changelog = run(str(pkg), commits)

        assert new_version == "1.3.0"
        assert json.loads(pkg.read_text())["version"] == "1.3.0"
        assert "1.3.0" in changelog

    def test_full_pipeline_fix(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "0.9.1"}))

        from version_bumper import run
        new_version, _ = run(str(pkg), ["fix: edge case crash"])
        assert new_version == "0.9.2"

    def test_full_pipeline_no_bump(self, tmp_path):
        """No conventional commits → version unchanged, changelog empty string"""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "3.0.0"}))

        from version_bumper import run
        new_version, changelog = run(str(pkg), ["chore: lint"])
        assert new_version == "3.0.0"
        assert changelog == ""


# ── Cycle 7: Fixture-driven tests ────────────────────────────────────────────

class TestFixtures:
    """Validates classify_commits against every mock commit fixture."""

    def setup_method(self):
        # Import lazily so the rest of the test file doesn't break on import errors
        import sys, os
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "fixtures"))
        import mock_commits as mc
        self.mc = mc

    def test_patch_fixture_yields_patch(self):
        from version_bumper import classify_commits
        assert classify_commits(self.mc.COMMITS_PATCH) == "patch"

    def test_minor_fixture_yields_minor(self):
        from version_bumper import classify_commits
        assert classify_commits(self.mc.COMMITS_MINOR) == "minor"

    def test_major_bang_fixture_yields_major(self):
        from version_bumper import classify_commits
        assert classify_commits(self.mc.COMMITS_MAJOR_BANG) == "major"

    def test_major_footer_fixture_yields_major(self):
        from version_bumper import classify_commits
        assert classify_commits(self.mc.COMMITS_MAJOR_FOOTER) == "major"

    def test_no_bump_fixture_yields_none(self):
        from version_bumper import classify_commits
        assert classify_commits(self.mc.COMMITS_NO_BUMP) is None

    def test_mixed_fixture_yields_patch(self):
        """COMMITS_MIXED has one fix and one perf; highest conventional = patch"""
        from version_bumper import classify_commits
        assert classify_commits(self.mc.COMMITS_MIXED) == "patch"
