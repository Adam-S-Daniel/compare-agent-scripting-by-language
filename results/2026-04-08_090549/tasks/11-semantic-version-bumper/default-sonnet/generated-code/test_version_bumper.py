"""
TDD test suite for semantic_version_bumper.py

RED → GREEN → REFACTOR cycle:
  1. Each test was written BEFORE the corresponding implementation.
  2. The test was run, confirmed to fail (ImportError / AssertionError).
  3. The minimum production code was added to make it green.
  4. Repeated for the next test.

Test order mirrors the implementation order so you can read them top-to-bottom
as a specification.
"""

import json
import shutil
import tempfile
from pathlib import Path

import pytest

# ── RED phase: this import will fail until version_bumper.py exists ──────────
from version_bumper import (
    parse_version,
    format_version,
    determine_bump_type,
    bump_version,
    read_version_from_package_json,
    write_version_to_package_json,
    generate_changelog_entry,
    run,
)

FIXTURES = Path(__file__).parent / "fixtures"


# ─────────────────────────────────────────────────────────────────────────────
# 1. parse_version  — RED: NameError; GREEN: implement parse_version
# ─────────────────────────────────────────────────────────────────────────────

class TestParseVersion:
    def test_standard_version(self):
        assert parse_version("1.2.3") == (1, 2, 3)

    def test_v_prefix(self):
        # Many version files prefix with "v"
        assert parse_version("v2.0.0") == (2, 0, 0)

    def test_zeroes(self):
        assert parse_version("0.0.1") == (0, 0, 1)

    def test_large_numbers(self):
        assert parse_version("100.200.300") == (100, 200, 300)

    def test_invalid_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("not-a-version")

    def test_missing_patch_raises(self):
        with pytest.raises(ValueError):
            parse_version("1.2")


# ─────────────────────────────────────────────────────────────────────────────
# 2. format_version  — GREEN together with parse_version
# ─────────────────────────────────────────────────────────────────────────────

class TestFormatVersion:
    def test_basic(self):
        assert format_version(1, 2, 3) == "1.2.3"

    def test_zeroes(self):
        assert format_version(0, 0, 0) == "0.0.0"

    def test_round_trips_with_parse(self):
        original = "3.14.159"
        assert format_version(*parse_version(original)) == original


# ─────────────────────────────────────────────────────────────────────────────
# 3. determine_bump_type  — RED: NameError; GREEN: implement function
# ─────────────────────────────────────────────────────────────────────────────

class TestDetermineBumpType:
    """Conventional Commits: feat→minor, fix→patch, !or BREAKING CHANGE→major."""

    def test_fix_gives_patch(self):
        assert determine_bump_type(["fix: resolve NPE in parser"]) == "patch"

    def test_feat_gives_minor(self):
        assert determine_bump_type(["feat: add dark mode"]) == "minor"

    def test_breaking_bang_gives_major(self):
        assert determine_bump_type(["feat!: drop Python 2 support"]) == "major"

    def test_fix_bang_also_gives_major(self):
        assert determine_bump_type(["fix!: rename config key"]) == "major"

    def test_breaking_change_footer_gives_major(self):
        commits = [
            "feat(auth): overhaul token storage\n\nBREAKING CHANGE: cookies only now"
        ]
        assert determine_bump_type(commits) == "major"

    def test_mixed_feat_and_fix_gives_minor(self):
        # feat beats fix — minor trumps patch
        commits = ["fix: typo", "feat: new endpoint"]
        assert determine_bump_type(commits) == "minor"

    def test_mixed_breaking_and_feat_gives_major(self):
        # major beats everything
        commits = ["feat: nice feature", "fix!: breaking correction"]
        assert determine_bump_type(commits) == "major"

    def test_no_conventional_commits_gives_none(self):
        commits = ["chore: update lockfile", "docs: fix typo", "ci: env var"]
        assert determine_bump_type(commits) == "none"

    def test_empty_list_gives_none(self):
        assert determine_bump_type([]) == "none"

    def test_scoped_feat(self):
        # feat(scope): ... should still trigger minor
        assert determine_bump_type(["feat(ui): new button"]) == "minor"

    def test_scoped_fix(self):
        assert determine_bump_type(["fix(parser): off-by-one"]) == "patch"

    def test_fixture_file_patch(self):
        commits = (FIXTURES / "commits_patch.txt").read_text().splitlines()
        assert determine_bump_type(commits) == "patch"

    def test_fixture_file_minor(self):
        commits = (FIXTURES / "commits_minor.txt").read_text().splitlines()
        assert determine_bump_type(commits) == "minor"

    def test_fixture_file_major_bang(self):
        commits = (FIXTURES / "commits_major_bang.txt").read_text().splitlines()
        assert determine_bump_type(commits) == "major"

    def test_fixture_file_major_breaking(self):
        # Multi-line commit with BREAKING CHANGE in body
        commits = (FIXTURES / "commits_major_breaking.txt").read_text().splitlines()
        assert determine_bump_type(commits) == "major"

    def test_fixture_file_none(self):
        commits = (FIXTURES / "commits_none.txt").read_text().splitlines()
        assert determine_bump_type(commits) == "none"


# ─────────────────────────────────────────────────────────────────────────────
# 4. bump_version  — RED: NameError; GREEN: implement function
# ─────────────────────────────────────────────────────────────────────────────

class TestBumpVersion:
    def test_patch_bump(self):
        assert bump_version("1.2.3", "patch") == "1.2.4"

    def test_minor_bump_resets_patch(self):
        assert bump_version("1.2.3", "minor") == "1.3.0"

    def test_major_bump_resets_minor_and_patch(self):
        assert bump_version("1.2.3", "major") == "2.0.0"

    def test_none_bump_leaves_unchanged(self):
        assert bump_version("1.2.3", "none") == "1.2.3"

    def test_bump_from_zero(self):
        assert bump_version("0.0.0", "patch") == "0.0.1"
        assert bump_version("0.0.0", "minor") == "0.1.0"
        assert bump_version("0.0.0", "major") == "1.0.0"

    def test_invalid_version_propagates_error(self):
        with pytest.raises(ValueError):
            bump_version("bad", "patch")


# ─────────────────────────────────────────────────────────────────────────────
# 5. I/O helpers  — RED: NameError; GREEN: implement read/write helpers
# ─────────────────────────────────────────────────────────────────────────────

class TestPackageJsonIO:
    """Use tmp files so tests never touch the real fixture."""

    def _make_pkg(self, tmp_path: Path, version: str) -> Path:
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "test", "version": version}, indent=2))
        return pkg

    def test_read_version(self, tmp_path):
        pkg = self._make_pkg(tmp_path, "3.1.4")
        assert read_version_from_package_json(pkg) == "3.1.4"

    def test_read_missing_version_key_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "no-version"}))
        with pytest.raises(KeyError):
            read_version_from_package_json(pkg)

    def test_read_nonexistent_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            read_version_from_package_json(tmp_path / "missing.json")

    def test_write_version_updates_field(self, tmp_path):
        pkg = self._make_pkg(tmp_path, "1.0.0")
        write_version_to_package_json(pkg, "2.0.0")
        data = json.loads(pkg.read_text())
        assert data["version"] == "2.0.0"

    def test_write_preserves_other_fields(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-pkg", "version": "1.0.0", "author": "Alice"}, indent=2))
        write_version_to_package_json(pkg, "1.0.1")
        data = json.loads(pkg.read_text())
        assert data["name"] == "my-pkg"
        assert data["author"] == "Alice"

    def test_read_fixture_package_json(self):
        version = read_version_from_package_json(FIXTURES / "package.json")
        assert version == "1.2.3"


# ─────────────────────────────────────────────────────────────────────────────
# 6. generate_changelog_entry  — RED: NameError; GREEN: implement function
# ─────────────────────────────────────────────────────────────────────────────

class TestGenerateChangelog:
    def test_contains_new_version(self):
        entry = generate_changelog_entry(["feat: something"], "1.3.0")
        assert "1.3.0" in entry

    def test_contains_today_date(self):
        from datetime import date
        entry = generate_changelog_entry(["fix: bug"], "1.2.4")
        assert date.today().isoformat() in entry

    def test_features_section_present(self):
        entry = generate_changelog_entry(["feat: add login"], "2.0.0")
        assert "### Features" in entry
        assert "feat: add login" in entry

    def test_fixes_section_present(self):
        entry = generate_changelog_entry(["fix: null check"], "1.2.4")
        assert "### Bug Fixes" in entry
        assert "fix: null check" in entry

    def test_breaking_section_present(self):
        entry = generate_changelog_entry(["feat!: new API"], "3.0.0")
        assert "### Breaking Changes" in entry

    def test_other_section_for_chore(self):
        entry = generate_changelog_entry(["chore: update deps"], "1.2.3")
        assert "### Other Changes" in entry

    def test_empty_commits_produces_header_only(self):
        entry = generate_changelog_entry([], "1.2.3")
        assert "## [1.2.3]" in entry

    def test_mixed_commits_all_sections(self):
        commits = [
            "feat!: redesign API",
            "feat: add webhooks",
            "fix: parse error",
            "chore: bump deps",
        ]
        entry = generate_changelog_entry(commits, "2.0.0")
        assert "### Breaking Changes" in entry
        assert "### Features" in entry
        assert "### Bug Fixes" in entry
        assert "### Other Changes" in entry


# ─────────────────────────────────────────────────────────────────────────────
# 7. run() integration  — RED: NameError; GREEN: wire everything together
# ─────────────────────────────────────────────────────────────────────────────

class TestRunIntegration:
    """End-to-end: reads package.json, bumps, writes, returns new version + changelog."""

    def _setup(self, tmp_path: Path, version: str, commits_text: str):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "app", "version": version}, indent=2))
        commits_file = tmp_path / "commits.txt"
        commits_file.write_text(commits_text)
        return pkg, commits_file

    def test_patch_bump_end_to_end(self, tmp_path):
        pkg, commits = self._setup(tmp_path, "1.2.3", "fix: correct edge case\n")
        new_ver, changelog = run(pkg, commits)
        assert new_ver == "1.2.4"
        assert json.loads(pkg.read_text())["version"] == "1.2.4"
        assert "1.2.4" in changelog

    def test_minor_bump_end_to_end(self, tmp_path):
        pkg, commits = self._setup(tmp_path, "1.2.3", "feat: add search\n")
        new_ver, changelog = run(pkg, commits)
        assert new_ver == "1.3.0"

    def test_major_bump_end_to_end(self, tmp_path):
        pkg, commits = self._setup(tmp_path, "1.2.3", "feat!: drop legacy endpoints\n")
        new_ver, changelog = run(pkg, commits)
        assert new_ver == "2.0.0"

    def test_no_bump_end_to_end(self, tmp_path):
        pkg, commits = self._setup(tmp_path, "1.2.3", "chore: deps update\n")
        new_ver, changelog = run(pkg, commits)
        assert new_ver == "1.2.3"

    def test_missing_package_json_raises(self, tmp_path):
        commits = tmp_path / "c.txt"
        commits.write_text("fix: something\n")
        with pytest.raises(FileNotFoundError):
            run(tmp_path / "nonexistent.json", commits)

    def test_missing_commits_file_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "x", "version": "1.0.0"}))
        with pytest.raises(FileNotFoundError):
            run(pkg, tmp_path / "nonexistent.txt")

    def test_real_fixture_minor(self, tmp_path):
        # Copy fixture package.json to tmp so we don't modify the real one
        pkg = shutil.copy(FIXTURES / "package.json", tmp_path / "package.json")
        commits_file = FIXTURES / "commits_minor.txt"
        new_ver, changelog = run(Path(pkg), commits_file)
        assert new_ver == "1.3.0"  # fixture starts at 1.2.3
