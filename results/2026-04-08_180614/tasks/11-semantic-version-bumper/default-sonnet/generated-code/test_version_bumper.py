"""
Tests for semantic version bumper — written FIRST (TDD red/green methodology).

TDD Order (each block was written to fail before implementation existed):
  1. test_parse_version_* — parse_version() didn't exist yet
  2. test_determine_bump_* — determine_bump_type() didn't exist yet
  3. test_bump_version_*   — bump_version() didn't exist yet
  4. test_read_package_json / test_write_package_json — file I/O
  5. test_generate_changelog_* — generate_changelog() didn't exist yet
  6. test_parse_git_log_*  — parse_git_log() didn't exist yet
  7. test_workflow_structure_* — structural checks on the YAML file

Run:  pytest test_version_bumper.py -v
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

import version_bumper  # ← import fails until version_bumper.py exists


# ===========================================================================
# Test fixtures — mock commit log data
# These stand in for real git output; loaded from fixtures/ for readability.
# ===========================================================================

# Patch bump: only fix commits
FIXTURE_FIX_COMMITS = [
    {"hash": "aaa0001", "message": "fix: correct null pointer exception", "body": ""},
    {"hash": "aaa0002", "message": "fix(auth): handle expired tokens properly", "body": ""},
]

# Minor bump: at least one feat commit
FIXTURE_FEAT_COMMITS = [
    {"hash": "bbb0001", "message": "feat: add dark mode support", "body": ""},
    {"hash": "bbb0002", "message": "fix: typo in error message", "body": ""},
]

# Major bump: breaking change via exclamation syntax
FIXTURE_BREAKING_EXCL = [
    {"hash": "ccc0001", "message": "feat!: redesign authentication API", "body": ""},
    {"hash": "ccc0002", "message": "feat: add OAuth support", "body": ""},
]

# Major bump: BREAKING CHANGE in commit body
FIXTURE_BREAKING_BODY = [
    {
        "hash": "ddd0001",
        "message": "feat: overhaul config system",
        "body": "BREAKING CHANGE: config.yml format has changed; migrate with migrate-config.sh",
    }
]

# Patch bump: only chore/docs (non-semantic commits default to patch)
FIXTURE_CHORE_COMMITS = [
    {"hash": "eee0001", "message": "chore: update CI config", "body": ""},
    {"hash": "eee0002", "message": "docs: update README", "body": ""},
]

# Mixed: feat takes priority over fix → minor
FIXTURE_MIXED_COMMITS = [
    {"hash": "fff0001", "message": "fix: reduce memory usage", "body": ""},
    {"hash": "fff0002", "message": "feat: add caching layer", "body": ""},
    {"hash": "fff0003", "message": "chore: bump deps", "body": ""},
]


# ===========================================================================
# RED ①  parse_version — these fail until parse_version() is implemented
# ===========================================================================

class TestParseVersion:
    def test_parse_simple(self):
        assert version_bumper.parse_version("1.2.3") == (1, 2, 3)

    def test_parse_zeros(self):
        assert version_bumper.parse_version("0.0.0") == (0, 0, 0)

    def test_parse_large_numbers(self):
        assert version_bumper.parse_version("10.20.30") == (10, 20, 30)

    def test_parse_ignores_prerelease_suffix(self):
        # e.g. "1.2.3-alpha" — we only care about the numeric core
        assert version_bumper.parse_version("1.2.3-alpha") == (1, 2, 3)

    def test_parse_invalid_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            version_bumper.parse_version("not-a-version")

    def test_parse_empty_string_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            version_bumper.parse_version("")


# ===========================================================================
# RED ②  determine_bump_type — fails until determine_bump_type() is implemented
# ===========================================================================

class TestDetermineBumpType:
    def test_fix_commits_give_patch(self):
        assert version_bumper.determine_bump_type(FIXTURE_FIX_COMMITS) == "patch"

    def test_feat_commit_gives_minor(self):
        assert version_bumper.determine_bump_type(FIXTURE_FEAT_COMMITS) == "minor"

    def test_breaking_excl_gives_major(self):
        assert version_bumper.determine_bump_type(FIXTURE_BREAKING_EXCL) == "major"

    def test_breaking_body_gives_major(self):
        assert version_bumper.determine_bump_type(FIXTURE_BREAKING_BODY) == "major"

    def test_chore_commits_give_patch(self):
        # Non-semantic commits default to patch (conservative)
        assert version_bumper.determine_bump_type(FIXTURE_CHORE_COMMITS) == "patch"

    def test_mixed_commits_highest_wins(self):
        # feat + fix → minor (feat wins over fix)
        assert version_bumper.determine_bump_type(FIXTURE_MIXED_COMMITS) == "minor"

    def test_empty_commit_list_gives_patch(self):
        assert version_bumper.determine_bump_type([]) == "patch"

    def test_fix_with_scope(self):
        commits = [{"hash": "x", "message": "fix(api): handle 404 gracefully", "body": ""}]
        assert version_bumper.determine_bump_type(commits) == "patch"

    def test_feat_with_scope(self):
        commits = [{"hash": "x", "message": "feat(ui): add dark mode", "body": ""}]
        assert version_bumper.determine_bump_type(commits) == "minor"

    def test_breaking_change_fix_excl(self):
        commits = [{"hash": "x", "message": "fix!: remove deprecated endpoint", "body": ""}]
        assert version_bumper.determine_bump_type(commits) == "major"


# ===========================================================================
# RED ③  bump_version — fails until bump_version() is implemented
# ===========================================================================

class TestBumpVersion:
    def test_patch_bump(self):
        assert version_bumper.bump_version("1.2.3", "patch") == "1.2.4"

    def test_minor_bump_resets_patch(self):
        assert version_bumper.bump_version("1.2.3", "minor") == "1.3.0"

    def test_major_bump_resets_minor_and_patch(self):
        assert version_bumper.bump_version("1.2.3", "major") == "2.0.0"

    def test_patch_from_zero(self):
        assert version_bumper.bump_version("0.0.0", "patch") == "0.0.1"

    def test_minor_from_zero(self):
        assert version_bumper.bump_version("0.0.0", "minor") == "0.1.0"

    def test_major_from_zero(self):
        assert version_bumper.bump_version("0.0.0", "major") == "1.0.0"

    def test_invalid_bump_type_raises(self):
        with pytest.raises(ValueError, match="Invalid bump type"):
            version_bumper.bump_version("1.0.0", "super-major")

    def test_feat_commits_produce_minor_bump(self):
        """Integration: determine + bump together."""
        bump_type = version_bumper.determine_bump_type(FIXTURE_FEAT_COMMITS)
        result = version_bumper.bump_version("1.1.0", bump_type)
        assert result == "1.2.0"

    def test_fix_commits_produce_patch_bump(self):
        bump_type = version_bumper.determine_bump_type(FIXTURE_FIX_COMMITS)
        result = version_bumper.bump_version("1.1.0", bump_type)
        assert result == "1.1.1"

    def test_breaking_commits_produce_major_bump(self):
        bump_type = version_bumper.determine_bump_type(FIXTURE_BREAKING_EXCL)
        result = version_bumper.bump_version("1.1.0", bump_type)
        assert result == "2.0.0"


# ===========================================================================
# RED ④  package.json I/O — fails until read/write functions exist
# ===========================================================================

class TestPackageJsonIO:
    def test_read_version(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "2.3.4"}))
        assert version_bumper.read_version_from_package_json(str(pkg)) == "2.3.4"

    def test_read_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            version_bumper.read_version_from_package_json(str(tmp_path / "missing.json"))

    def test_read_no_version_field_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp"}))
        with pytest.raises(KeyError, match="version"):
            version_bumper.read_version_from_package_json(str(pkg))

    def test_write_version_updates_field(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "1.0.0"}))
        version_bumper.write_version_to_package_json("2.0.0", str(pkg))
        data = json.loads(pkg.read_text())
        assert data["version"] == "2.0.0"

    def test_write_version_preserves_other_fields(self, tmp_path):
        pkg = tmp_path / "package.json"
        original = {"name": "myapp", "version": "1.0.0", "description": "test"}
        pkg.write_text(json.dumps(original))
        version_bumper.write_version_to_package_json("1.0.1", str(pkg))
        data = json.loads(pkg.read_text())
        assert data["name"] == "myapp"
        assert data["description"] == "test"


# ===========================================================================
# RED ⑤  generate_changelog — fails until generate_changelog() is implemented
# ===========================================================================

class TestGenerateChangelog:
    def test_changelog_contains_version(self):
        entry = version_bumper.generate_changelog(FIXTURE_FEAT_COMMITS, "1.2.0")
        assert "1.2.0" in entry

    def test_changelog_has_features_section(self):
        entry = version_bumper.generate_changelog(FIXTURE_FEAT_COMMITS, "1.2.0")
        assert "Features" in entry
        assert "dark mode" in entry

    def test_changelog_has_fixes_section(self):
        entry = version_bumper.generate_changelog(FIXTURE_FIX_COMMITS, "1.0.1")
        assert "Bug Fixes" in entry
        assert "null pointer" in entry

    def test_changelog_has_breaking_section(self):
        entry = version_bumper.generate_changelog(FIXTURE_BREAKING_EXCL, "2.0.0")
        assert "Breaking" in entry

    def test_changelog_has_date(self):
        entry = version_bumper.generate_changelog(FIXTURE_FIX_COMMITS, "1.0.1")
        # Should contain a date in YYYY-MM-DD format
        import re
        assert re.search(r"\d{4}-\d{2}-\d{2}", entry)

    def test_changelog_no_empty_sections(self):
        # Only fix commits → no Features section
        entry = version_bumper.generate_changelog(FIXTURE_FIX_COMMITS, "1.0.1")
        assert "Features" not in entry


# ===========================================================================
# RED ⑥  parse_git_log — fails until parse_git_log() is implemented
# ===========================================================================

class TestParseGitLog:
    # Refactored in green→refactor step: format switched from |||  to NUL (%x00)
    # separators to handle empty commit bodies cleanly.

    def test_parse_single_commit(self):
        # NUL-separated triples: hash\x00subject\x00body\x00
        raw = "abc1234\x00feat: add login\x00\x00"
        commits = version_bumper.parse_git_log(raw)
        assert len(commits) == 1
        assert commits[0]["hash"] == "abc1234"
        assert commits[0]["message"] == "feat: add login"

    def test_parse_multiple_commits(self):
        raw = "abc1234\x00feat: add login\x00\x00def5678\x00fix: typo\x00\x00"
        commits = version_bumper.parse_git_log(raw)
        assert len(commits) == 2

    def test_parse_commit_with_body(self):
        raw = "abc1234\x00feat: redesign\x00BREAKING CHANGE: old API removed\x00"
        commits = version_bumper.parse_git_log(raw)
        assert commits[0]["body"] == "BREAKING CHANGE: old API removed"

    def test_parse_empty_log(self):
        assert version_bumper.parse_git_log("") == []


# ===========================================================================
# RED ⑦  workflow structure — structural checks (no act needed)
# ===========================================================================

class TestWorkflowStructure:
    WORKFLOW_PATH = Path(__file__).parent / ".github" / "workflows" / "semantic-version-bumper.yml"

    def test_workflow_file_exists(self):
        assert self.WORKFLOW_PATH.exists(), f"Workflow not found at {self.WORKFLOW_PATH}"

    def test_workflow_references_version_bumper_script(self):
        content = self.WORKFLOW_PATH.read_text()
        assert "version_bumper.py" in content

    def test_workflow_has_checkout_step(self):
        content = self.WORKFLOW_PATH.read_text()
        assert "actions/checkout" in content

    def test_workflow_has_python_setup(self):
        content = self.WORKFLOW_PATH.read_text()
        assert "setup-python" in content or "python" in content.lower()

    def test_workflow_has_push_trigger(self):
        import yaml  # stdlib pyyaml
        with open(self.WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        # PyYAML parses the bare `on:` key as boolean True — both are valid
        triggers = data.get("on") or data.get(True, {})
        assert "push" in triggers

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(self.WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )
