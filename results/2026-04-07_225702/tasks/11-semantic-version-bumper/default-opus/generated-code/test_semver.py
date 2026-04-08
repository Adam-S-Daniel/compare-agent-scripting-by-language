# TDD Cycle 1: Parse a semantic version string
# RED: Write failing tests for version parsing

import pytest
import json
import os
import subprocess
from pathlib import Path
from semver import (
    parse_version, SemVer, parse_commit, Commit, BumpType, bump_version,
    read_version_file, write_version_file, generate_changelog,
    load_commits,
)

FIXTURES = Path(__file__).parent / "fixtures"


class TestParseVersion:
    def test_parse_basic_version(self):
        v = parse_version("1.2.3")
        assert v == SemVer(1, 2, 3)

    def test_parse_zero_version(self):
        v = parse_version("0.0.0")
        assert v == SemVer(0, 0, 0)

    def test_parse_large_numbers(self):
        v = parse_version("10.200.3000")
        assert v == SemVer(10, 200, 3000)

    def test_parse_with_v_prefix(self):
        v = parse_version("v1.2.3")
        assert v == SemVer(1, 2, 3)

    def test_parse_invalid_version_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("not-a-version")

    def test_parse_incomplete_version_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("1.2")

    def test_semver_to_string(self):
        assert str(SemVer(1, 2, 3)) == "1.2.3"


# TDD Cycle 2: Parse conventional commit messages
# RED: Write failing tests for commit parsing

class TestParseCommit:
    def test_feat_commit(self):
        c = parse_commit("feat: add user login")
        assert c == Commit(BumpType.MINOR, "feat", "add user login", None)

    def test_fix_commit(self):
        c = parse_commit("fix: handle null pointer")
        assert c == Commit(BumpType.PATCH, "fix", "handle null pointer", None)

    def test_feat_with_scope(self):
        c = parse_commit("feat(auth): add OAuth support")
        assert c == Commit(BumpType.MINOR, "feat", "add OAuth support", "auth")

    def test_fix_with_scope(self):
        c = parse_commit("fix(db): close idle connections")
        assert c == Commit(BumpType.PATCH, "fix", "close idle connections", "db")

    def test_breaking_change_with_bang(self):
        c = parse_commit("feat!: remove deprecated API")
        assert c.bump_type == BumpType.MAJOR

    def test_breaking_change_with_scope_and_bang(self):
        c = parse_commit("refactor(core)!: rewrite engine")
        assert c.bump_type == BumpType.MAJOR

    def test_chore_commit(self):
        c = parse_commit("chore: update deps")
        assert c == Commit(BumpType.PATCH, "chore", "update deps", None)

    def test_docs_commit(self):
        c = parse_commit("docs: update readme")
        assert c == Commit(BumpType.PATCH, "docs", "update readme", None)

    def test_non_conventional_commit_returns_patch(self):
        c = parse_commit("just a regular commit message")
        assert c == Commit(BumpType.PATCH, None, "just a regular commit message", None)

    def test_breaking_change_in_footer(self):
        c = parse_commit("feat: big change\n\nBREAKING CHANGE: removed old API")
        assert c.bump_type == BumpType.MAJOR


# TDD Cycle 3: Bump version based on a list of commits
# RED: Write failing tests for version bumping

class TestBumpVersion:
    def test_patch_bump(self):
        commits = ["fix: typo", "chore: update deps"]
        assert bump_version(SemVer(1, 0, 0), commits) == SemVer(1, 0, 1)

    def test_minor_bump_resets_patch(self):
        commits = ["fix: typo", "feat: add login"]
        assert bump_version(SemVer(1, 0, 5), commits) == SemVer(1, 1, 0)

    def test_major_bump_resets_minor_and_patch(self):
        commits = ["feat: add login", "feat!: remove old API"]
        assert bump_version(SemVer(1, 2, 3), commits) == SemVer(2, 0, 0)

    def test_no_commits_raises(self):
        with pytest.raises(ValueError, match="No commits"):
            bump_version(SemVer(1, 0, 0), [])

    def test_single_feat_from_zero(self):
        commits = ["feat: initial feature"]
        assert bump_version(SemVer(0, 0, 0), commits) == SemVer(0, 1, 0)


# TDD Cycle 4: Read and write version files
# RED: Write failing tests for file I/O

class TestVersionFile:
    def test_read_plain_version_file(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("2.1.0\n")
        assert read_version_file(str(vf)) == SemVer(2, 1, 0)

    def test_read_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "3.4.5"}))
        assert read_version_file(str(pkg)) == SemVer(3, 4, 5)

    def test_read_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            read_version_file(str(tmp_path / "nope"))

    def test_read_package_json_missing_version_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp"}))
        with pytest.raises(ValueError, match="No 'version' field"):
            read_version_file(str(pkg))

    def test_write_plain_version_file(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("1.0.0\n")
        write_version_file(str(vf), SemVer(1, 1, 0))
        assert vf.read_text().strip() == "1.1.0"

    def test_write_package_json_preserves_other_fields(self, tmp_path):
        pkg = tmp_path / "package.json"
        original = {"name": "myapp", "version": "1.0.0", "description": "test"}
        pkg.write_text(json.dumps(original, indent=2))
        write_version_file(str(pkg), SemVer(2, 0, 0))
        data = json.loads(pkg.read_text())
        assert data["version"] == "2.0.0"
        assert data["name"] == "myapp"
        assert data["description"] == "test"


# TDD Cycle 5: Generate changelog entry from commits
# RED: Write failing tests for changelog generation

class TestGenerateChangelog:
    def test_changelog_has_version_header(self):
        commits = ["feat: add login"]
        log = generate_changelog(SemVer(1, 1, 0), commits)
        assert "## 1.1.0" in log

    def test_changelog_groups_by_type(self):
        commits = [
            "feat: add login",
            "feat(api): add endpoints",
            "fix: null check",
            "chore: cleanup",
        ]
        log = generate_changelog(SemVer(2, 0, 0), commits)
        assert "### Features" in log
        assert "### Bug Fixes" in log
        assert "### Other" in log

    def test_changelog_includes_descriptions(self):
        commits = ["feat: add login", "fix: null check"]
        log = generate_changelog(SemVer(1, 1, 0), commits)
        assert "add login" in log
        assert "null check" in log

    def test_changelog_includes_scope(self):
        commits = ["feat(auth): add OAuth"]
        log = generate_changelog(SemVer(1, 1, 0), commits)
        assert "**auth**" in log

    def test_changelog_highlights_breaking(self):
        commits = ["feat!: remove old API"]
        log = generate_changelog(SemVer(2, 0, 0), commits)
        assert "BREAKING" in log

    def test_changelog_empty_commits_raises(self):
        with pytest.raises(ValueError, match="No commits"):
            generate_changelog(SemVer(1, 0, 0), [])


# TDD Cycle 6: Load commits from fixture files and end-to-end integration
# RED: Write failing tests for commit loading and full workflow

class TestLoadCommits:
    def test_load_from_fixture_file(self):
        commits = load_commits(str(FIXTURES / "commits_patch.txt"))
        assert len(commits) == 3
        assert "fix: correct off-by-one error in pagination" in commits

    def test_load_skips_blank_lines(self):
        commits = load_commits(str(FIXTURES / "commits_major.txt"))
        # The blank line and BREAKING CHANGE footer line should not appear as separate commits
        assert all(c.strip() for c in commits)

    def test_load_missing_file_raises(self):
        with pytest.raises(FileNotFoundError):
            load_commits("/nonexistent/commits.txt")


class TestEndToEnd:
    """Integration tests: version file + commit fixtures -> bumped version + changelog."""

    def test_patch_bump_e2e(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("1.0.0\n")
        commits = load_commits(str(FIXTURES / "commits_patch.txt"))

        old = read_version_file(str(vf))
        new = bump_version(old, commits)
        write_version_file(str(vf), new)
        changelog = generate_changelog(new, commits)

        assert new == SemVer(1, 0, 1)
        assert vf.read_text().strip() == "1.0.1"
        assert "## 1.0.1" in changelog
        assert "### Bug Fixes" in changelog

    def test_minor_bump_e2e(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": "2.3.1"}))
        commits = load_commits(str(FIXTURES / "commits_minor.txt"))

        old = read_version_file(str(pkg))
        new = bump_version(old, commits)
        write_version_file(str(pkg), new)
        changelog = generate_changelog(new, commits)

        assert new == SemVer(2, 4, 0)
        data = json.loads(pkg.read_text())
        assert data["version"] == "2.4.0"
        assert "### Features" in changelog

    def test_major_bump_e2e(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("3.2.1\n")
        commits = load_commits(str(FIXTURES / "commits_major.txt"))

        old = read_version_file(str(vf))
        new = bump_version(old, commits)
        write_version_file(str(vf), new)

        assert new == SemVer(4, 0, 0)
        assert vf.read_text().strip() == "4.0.0"

    def test_mixed_commits_e2e(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("0.9.3\n")
        commits = load_commits(str(FIXTURES / "commits_mixed.txt"))

        old = read_version_file(str(vf))
        new = bump_version(old, commits)

        # feat is highest, so minor bump
        assert new == SemVer(0, 10, 0)


class TestCLI:
    """Test the CLI entry point."""

    def test_cli_with_version_file(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("1.0.0\n")
        commits_file = str(FIXTURES / "commits_minor.txt")

        result = subprocess.run(
            ["python3", "semver.py", str(vf), commits_file],
            capture_output=True, text=True,
        )
        assert result.returncode == 0
        assert "1.1.0" in result.stdout
        # Version file should be updated
        assert vf.read_text().strip() == "1.1.0"

    def test_cli_missing_args(self):
        result = subprocess.run(
            ["python3", "semver.py"],
            capture_output=True, text=True,
        )
        assert result.returncode != 0

    def test_cli_bad_version_file(self, tmp_path):
        vf = tmp_path / "VERSION"
        vf.write_text("not-a-version\n")
        commits_file = str(FIXTURES / "commits_patch.txt")

        result = subprocess.run(
            ["python3", "semver.py", str(vf), commits_file],
            capture_output=True, text=True,
        )
        assert result.returncode != 0
        assert "Error" in result.stderr
