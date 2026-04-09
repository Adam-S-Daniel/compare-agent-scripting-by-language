"""
TDD test suite for semantic version bumper.
RED PHASE: Tests are written BEFORE implementation.
Run: pytest test_bumper.py -v  (will fail until bumper.py is created)
"""

import pytest
import json
import os
from pathlib import Path

# These imports FAIL until bumper.py is created — that is the intended RED phase.
from bumper import (
    BumpType,
    bump_version,
    determine_bump_type,
    generate_changelog_entry,
    parse_version,
    read_version_from_file,
    update_version_file,
    write_version_to_file,
)


# ─── Mock commit log fixtures ─────────────────────────────────────────────────

FEAT_COMMITS = [
    "feat: add user authentication",
    "feat(api): implement rate limiting",
    "docs: update README",          # not a conventional bump
]

FIX_COMMITS = [
    "fix: resolve null pointer exception",
    "fix(ui): correct button alignment",
    "chore: update dependencies",   # not a conventional bump
]

BREAKING_EXCLAMATION_COMMITS = [
    "feat!: redesign API interface",
    "fix: minor correction",
]

BREAKING_KEYWORD_COMMITS = [
    "BREAKING CHANGE: remove legacy /v1 endpoints",
    "chore: clean up",
]

MIXED_COMMITS = [
    "feat: add dashboard",
    "fix: resolve login bug",
    "chore: clean up",
]

NO_CONVENTIONAL_COMMITS = [
    "update stuff",
    "wip: working on features",
    "merge branch main",
]


# ─── parse_version ─────────────────────────────────────────────────────────────

class TestParseVersion:
    def test_standard_version(self):
        assert parse_version("1.2.3") == (1, 2, 3)

    def test_version_with_v_prefix(self):
        assert parse_version("v1.2.3") == (1, 2, 3)

    def test_zero_version(self):
        assert parse_version("0.0.0") == (0, 0, 0)

    def test_large_numbers(self):
        assert parse_version("10.20.30") == (10, 20, 30)

    def test_invalid_version_raises_value_error(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("not-a-version")

    def test_incomplete_version_raises(self):
        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version("1.2")


# ─── determine_bump_type ──────────────────────────────────────────────────────

class TestDetermineBumpType:
    def test_feat_gives_minor(self):
        assert determine_bump_type(["feat: add new feature"]) == BumpType.MINOR

    def test_fix_gives_patch(self):
        assert determine_bump_type(["fix: fix a bug"]) == BumpType.PATCH

    def test_breaking_exclamation_gives_major(self):
        assert determine_bump_type(["feat!: breaking change"]) == BumpType.MAJOR

    def test_breaking_change_keyword_gives_major(self):
        assert determine_bump_type(["BREAKING CHANGE: remove endpoint"]) == BumpType.MAJOR

    def test_non_conventional_gives_none(self):
        assert determine_bump_type(NO_CONVENTIONAL_COMMITS) == BumpType.NONE

    def test_empty_gives_none(self):
        assert determine_bump_type([]) == BumpType.NONE

    def test_major_overrides_minor(self):
        assert determine_bump_type(BREAKING_EXCLAMATION_COMMITS) == BumpType.MAJOR

    def test_minor_overrides_patch(self):
        assert determine_bump_type(MIXED_COMMITS) == BumpType.MINOR

    def test_feat_with_scope(self):
        assert determine_bump_type(["feat(api): add endpoint"]) == BumpType.MINOR

    def test_fix_with_scope(self):
        assert determine_bump_type(["fix(ui): fix button"]) == BumpType.PATCH

    def test_feat_commits_fixture(self):
        assert determine_bump_type(FEAT_COMMITS) == BumpType.MINOR

    def test_fix_commits_fixture(self):
        assert determine_bump_type(FIX_COMMITS) == BumpType.PATCH

    def test_breaking_keyword_fixture(self):
        assert determine_bump_type(BREAKING_KEYWORD_COMMITS) == BumpType.MAJOR

    def test_fix_exclamation_gives_major(self):
        assert determine_bump_type(["fix!: critical breaking fix"]) == BumpType.MAJOR


# ─── bump_version ─────────────────────────────────────────────────────────────

class TestBumpVersion:
    def test_major_bump(self):
        assert bump_version("1.2.3", BumpType.MAJOR) == "2.0.0"

    def test_minor_bump(self):
        assert bump_version("1.2.3", BumpType.MINOR) == "1.3.0"

    def test_patch_bump(self):
        assert bump_version("1.2.3", BumpType.PATCH) == "1.2.4"

    def test_none_bump_unchanged(self):
        assert bump_version("1.2.3", BumpType.NONE) == "1.2.3"

    def test_major_resets_minor_and_patch(self):
        assert bump_version("3.5.9", BumpType.MAJOR) == "4.0.0"

    def test_minor_resets_patch(self):
        assert bump_version("1.5.9", BumpType.MINOR) == "1.6.0"

    def test_zero_version_patch(self):
        assert bump_version("0.1.0", BumpType.PATCH) == "0.1.1"

    def test_specific_case_feat_on_1_1_0(self):
        # Test case: version 1.1.0 + feat commits → 1.2.0
        assert bump_version("1.1.0", BumpType.MINOR) == "1.2.0"


# ─── read_version_from_file ───────────────────────────────────────────────────

class TestReadVersionFromFile:
    def test_reads_from_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "test", "version": "1.0.0"}))
        assert read_version_from_file(str(pkg)) == "1.0.0"

    def test_reads_from_version_txt(self, tmp_path):
        ver = tmp_path / "version.txt"
        ver.write_text("2.3.4\n")
        assert read_version_from_file(str(ver)) == "2.3.4"

    def test_missing_file_raises_file_not_found(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            read_version_from_file(str(tmp_path / "nope.json"))

    def test_package_json_missing_version_raises(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "test"}))
        with pytest.raises(KeyError):
            read_version_from_file(str(pkg))


# ─── write_version_to_file ────────────────────────────────────────────────────

class TestWriteVersionToFile:
    def test_updates_package_json(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "test", "version": "1.0.0"}))
        write_version_to_file(str(pkg), "2.0.0")
        assert json.loads(pkg.read_text())["version"] == "2.0.0"

    def test_preserves_other_package_json_fields(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "myapp", "version": "1.0.0", "author": "dev"}))
        write_version_to_file(str(pkg), "1.1.0")
        data = json.loads(pkg.read_text())
        assert data["name"] == "myapp"
        assert data["author"] == "dev"
        assert data["version"] == "1.1.0"

    def test_updates_version_txt(self, tmp_path):
        ver = tmp_path / "version.txt"
        ver.write_text("1.0.0\n")
        write_version_to_file(str(ver), "1.1.0")
        assert ver.read_text().strip() == "1.1.0"


# ─── generate_changelog_entry ─────────────────────────────────────────────────

class TestGenerateChangelogEntry:
    def test_version_header(self):
        entry = generate_changelog_entry("1.1.0", FEAT_COMMITS, release_date="2024-01-15")
        assert "## [1.1.0] - 2024-01-15" in entry

    def test_features_section(self):
        entry = generate_changelog_entry("1.1.0", FEAT_COMMITS, release_date="2024-01-15")
        assert "### Features" in entry
        assert "feat: add user authentication" in entry

    def test_bug_fixes_section(self):
        entry = generate_changelog_entry("1.0.1", FIX_COMMITS, release_date="2024-01-15")
        assert "### Bug Fixes" in entry
        assert "fix: resolve null pointer exception" in entry

    def test_breaking_changes_section(self):
        entry = generate_changelog_entry("2.0.0", BREAKING_EXCLAMATION_COMMITS, release_date="2024-01-15")
        assert "### Breaking Changes" in entry
        assert "feat!: redesign API interface" in entry

    def test_empty_commits(self):
        entry = generate_changelog_entry("1.0.0", [], release_date="2024-01-15")
        assert "## [1.0.0] - 2024-01-15" in entry

    def test_date_defaults_to_today(self):
        from datetime import date
        entry = generate_changelog_entry("1.0.0", [])
        assert date.today().isoformat() in entry


# ─── update_version_file (integration) ───────────────────────────────────────

class TestUpdateVersionFile:
    def test_minor_bump_updates_and_returns_versions(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "1.1.0"}))
        old, new = update_version_file(str(pkg), BumpType.MINOR)
        assert old == "1.1.0"
        assert new == "1.2.0"
        assert json.loads(pkg.read_text())["version"] == "1.2.0"

    def test_none_bump_leaves_file_unchanged(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "1.1.0"}))
        old, new = update_version_file(str(pkg), BumpType.NONE)
        assert old == new == "1.1.0"

    def test_major_bump(self, tmp_path):
        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"version": "1.0.0"}))
        old, new = update_version_file(str(pkg), BumpType.MAJOR)
        assert old == "1.0.0"
        assert new == "2.0.0"


# ─── Workflow structure tests ─────────────────────────────────────────────────

class TestWorkflowStructure:
    """Verify the workflow YAML is structurally correct before running act."""

    WORKFLOW_PATH = Path(__file__).parent / ".github" / "workflows" / "semantic-version-bumper.yml"

    def test_workflow_file_exists(self):
        assert self.WORKFLOW_PATH.exists(), f"Workflow not found: {self.WORKFLOW_PATH}"

    def test_workflow_is_valid_yaml(self):
        import yaml  # pyyaml
        with open(self.WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        assert data is not None

    def test_workflow_has_push_trigger(self):
        import yaml
        with open(self.WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        # pyyaml parses bare `on:` as Python True (YAML boolean alias)
        triggers = data.get("on", data.get(True, {})) or {}
        assert "push" in triggers, "Workflow must trigger on push"

    def test_workflow_has_workflow_dispatch(self):
        import yaml
        with open(self.WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        triggers = data.get("on", data.get(True, {})) or {}
        assert "workflow_dispatch" in triggers, "Workflow must support manual dispatch"

    def test_workflow_has_jobs(self):
        import yaml
        with open(self.WORKFLOW_PATH) as f:
            data = yaml.safe_load(f)
        assert "jobs" in data
        assert len(data["jobs"]) > 0

    def test_workflow_references_bumper_script(self):
        workflow_text = self.WORKFLOW_PATH.read_text()
        assert "bumper.py" in workflow_text, "Workflow must reference bumper.py"

    def test_bumper_script_exists(self):
        script = Path(__file__).parent / "bumper.py"
        assert script.exists(), "bumper.py must exist alongside workflow"

    def test_actionlint_passes(self):
        import subprocess
        result = subprocess.run(
            ["actionlint", str(self.WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
        )
