"""Tests for the semantic version bumper — TDD approach."""

import json
import subprocess
import pytest
from pathlib import Path
from version_bumper import (
    parse_version, classify_commits, determine_bump,
    bump_version, read_version_file, write_version_file,
    generate_changelog, load_commits_from_file,
)

FIXTURES = Path(__file__).parent / "fixtures"


class TestParseVersion:
    """Red/green cycle 1: parse a semver string into (major, minor, patch)."""

    def test_parse_simple_version(self):
        assert parse_version("1.2.3") == (1, 2, 3)

    def test_parse_zero_version(self):
        assert parse_version("0.0.0") == (0, 0, 0)

    def test_parse_version_with_v_prefix(self):
        assert parse_version("v1.0.0") == (1, 0, 0)

    def test_parse_invalid_version_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("not-a-version")

    def test_parse_incomplete_version_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("1.2")


class TestClassifyCommits:
    """Red/green cycle 2: classify conventional commit messages."""

    def test_fix_is_patch(self):
        commits = classify_commits(["fix: correct typo"])
        assert commits == {"patch": ["fix: correct typo"]}

    def test_feat_is_minor(self):
        commits = classify_commits(["feat: add search"])
        assert commits == {"minor": ["feat: add search"]}

    def test_breaking_bang_is_major(self):
        commits = classify_commits(["feat!: new auth flow"])
        assert commits == {"major": ["feat!: new auth flow"]}

    def test_breaking_change_footer_is_major(self):
        # A commit with "BREAKING CHANGE:" in the body
        raw = "feat: streaming API\n\nBREAKING CHANGE: removed /v1/sync"
        commits = classify_commits([raw])
        assert commits == {"major": [raw]}

    def test_scoped_commit(self):
        commits = classify_commits(["fix(core): null check"])
        assert commits == {"patch": ["fix(core): null check"]}

    def test_non_bumping_types_excluded(self):
        commits = classify_commits(["docs: update readme", "chore: lint"])
        assert commits == {}

    def test_mixed_commits(self):
        lines = [
            "feat: add dark mode",
            "fix: memory leak",
            "chore: cleanup",
        ]
        result = classify_commits(lines)
        assert result == {
            "minor": ["feat: add dark mode"],
            "patch": ["fix: memory leak"],
        }


class TestDetermineBump:
    """Red/green cycle 2b: given classified commits, pick the right bump level."""

    def test_major_wins(self):
        classified = {"major": ["feat!: x"], "minor": ["feat: y"], "patch": ["fix: z"]}
        assert determine_bump(classified) == "major"

    def test_minor_wins_over_patch(self):
        classified = {"minor": ["feat: y"], "patch": ["fix: z"]}
        assert determine_bump(classified) == "minor"

    def test_patch_only(self):
        assert determine_bump({"patch": ["fix: z"]}) == "patch"

    def test_no_bump(self):
        assert determine_bump({}) is None


class TestBumpVersion:
    """Red/green cycle 3: apply bump to a version tuple."""

    def test_patch_bump(self):
        assert bump_version((1, 2, 3), "patch") == (1, 2, 4)

    def test_minor_bump_resets_patch(self):
        assert bump_version((1, 2, 3), "minor") == (1, 3, 0)

    def test_major_bump_resets_minor_and_patch(self):
        assert bump_version((1, 2, 3), "major") == (2, 0, 0)

    def test_none_bump_returns_same(self):
        assert bump_version((1, 2, 3), None) == (1, 2, 3)


class TestVersionFileIO:
    """Red/green cycle 4: read/write version from plain text and package.json."""

    def test_read_plain_version_file(self, tmp_path):
        vfile = tmp_path / "VERSION"
        vfile.write_text("2.1.0\n")
        assert read_version_file(vfile) == "2.1.0"

    def test_read_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "3.4.5"}))
        assert read_version_file(pkg) == "3.4.5"

    def test_write_plain_version_file(self, tmp_path):
        vfile = tmp_path / "VERSION"
        vfile.write_text("1.0.0\n")
        write_version_file(vfile, "1.1.0")
        assert vfile.read_text().strip() == "1.1.0"

    def test_write_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "1.0.0"}))
        write_version_file(pkg, "1.1.0")
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.1.0"

    def test_read_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            read_version_file(tmp_path / "NOPE")

    def test_read_package_json_missing_version_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app"}))
        with pytest.raises(ValueError, match="No 'version' field"):
            read_version_file(pkg)


class TestGenerateChangelog:
    """Red/green cycle 5: produce a markdown changelog entry from classified commits."""

    def test_changelog_contains_version_header(self):
        classified = {"minor": ["feat: add search"]}
        cl = generate_changelog("1.1.0", classified)
        assert "## 1.1.0" in cl

    def test_changelog_groups_by_category(self):
        classified = {
            "minor": ["feat: add search", "feat(ui): dark mode"],
            "patch": ["fix: typo"],
        }
        cl = generate_changelog("2.0.0", classified)
        assert "### Features" in cl
        assert "### Bug Fixes" in cl
        assert "- add search" in cl
        assert "- dark mode" in cl
        assert "- typo" in cl

    def test_changelog_breaking_section(self):
        classified = {"major": ["feat!: new auth"]}
        cl = generate_changelog("3.0.0", classified)
        assert "### BREAKING CHANGES" in cl


class TestLoadCommitsFromFile:
    """Red/green cycle 6: load commit fixture files."""

    def test_load_patch_fixture(self):
        commits = load_commits_from_file(FIXTURES / "commits_patch.txt")
        classified = classify_commits(commits)
        assert determine_bump(classified) == "patch"

    def test_load_minor_fixture(self):
        commits = load_commits_from_file(FIXTURES / "commits_minor.txt")
        classified = classify_commits(commits)
        assert determine_bump(classified) == "minor"

    def test_load_major_bang_fixture(self):
        commits = load_commits_from_file(FIXTURES / "commits_major_bang.txt")
        classified = classify_commits(commits)
        assert determine_bump(classified) == "major"

    def test_load_major_breaking_fixture(self):
        commits = load_commits_from_file(FIXTURES / "commits_major_breaking.txt")
        classified = classify_commits(commits)
        assert determine_bump(classified) == "major"

    def test_load_no_bump_fixture(self):
        commits = load_commits_from_file(FIXTURES / "commits_none.txt")
        classified = classify_commits(commits)
        assert determine_bump(classified) is None


class TestEndToEnd:
    """Red/green cycle 7: full pipeline via CLI subprocess."""

    def test_cli_minor_bump(self, tmp_path):
        """Run the script end-to-end: VERSION 1.0.0 + feat commit -> 1.1.0."""
        vfile = tmp_path / "VERSION"
        vfile.write_text("1.0.0\n")
        cfile = tmp_path / "commits.txt"
        cfile.write_text("feat: add dark mode\n---\nfix: typo\n")

        result = subprocess.run(
            ["python3", "version_bumper.py", str(vfile), str(cfile)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        # VERSION file should now be 1.1.0
        assert vfile.read_text().strip() == "1.1.0"
        # Output should mention the bump
        assert "1.1.0" in result.stdout

    def test_cli_no_bump(self, tmp_path):
        """Non-bumping commits leave the version unchanged."""
        vfile = tmp_path / "VERSION"
        vfile.write_text("2.0.0\n")
        cfile = tmp_path / "commits.txt"
        cfile.write_text("docs: update readme\n")

        result = subprocess.run(
            ["python3", "version_bumper.py", str(vfile), str(cfile)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        assert vfile.read_text().strip() == "2.0.0"
        assert "unchanged" in result.stdout.lower()

    def test_cli_package_json_bump(self, tmp_path):
        """Bump works with package.json too."""
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "0.9.1"}))
        cfile = tmp_path / "commits.txt"
        cfile.write_text("feat!: breaking redesign\n")

        result = subprocess.run(
            ["python3", "version_bumper.py", str(pkg), str(cfile)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        data = json.loads(pkg.read_text())
        assert data["version"] == "1.0.0"

    def test_cli_missing_args(self):
        """Missing arguments should exit with error."""
        result = subprocess.run(
            ["python3", "version_bumper.py"],
            capture_output=True, text=True,
        )
        assert result.returncode != 0
