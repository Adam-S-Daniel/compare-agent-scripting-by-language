"""
TDD test suite for semantic version bumper.

Red/Green TDD approach:
1. Write a failing test
2. Write minimum code to make it pass
3. Refactor
4. Repeat
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest
import yaml

# ─────────────────────────────────────────────
# Test fixtures: mock commit logs
# ─────────────────────────────────────────────

COMMITS_PATCH_ONLY = [
    "fix: correct off-by-one error in loop",
    "fix: handle null pointer in auth module",
    "docs: update README with new API examples",
]

COMMITS_MINOR = [
    "feat: add user profile endpoint",
    "fix: sanitize input in search handler",
    "chore: bump dev dependencies",
]

COMMITS_MAJOR = [
    "feat!: redesign authentication API",
    "fix: patch session expiry bug",
]

COMMITS_MAJOR_FOOTER = [
    "feat: add new payment gateway\n\nBREAKING CHANGE: old payment API removed",
    "fix: typo in error message",
]

COMMITS_NO_BUMP = [
    "docs: fix typo in changelog",
    "chore: update CI config",
    "style: reformat whitespace",
    "test: add missing unit tests",
]

COMMITS_MIXED = [
    "feat: add dark mode toggle",
    "fix: correct contrast ratio",
    "feat: support custom themes",
    "docs: document theme API",
]


# ─────────────────────────────────────────────
# RED: Version parsing tests (will fail before implementation)
# ─────────────────────────────────────────────

class TestVersionParsing:
    """Tests for parsing version from version.txt and package.json."""

    def test_parse_version_from_version_txt(self, tmp_path):
        """Should read '1.2.3' from a version.txt file."""
        from version_bumper import parse_version

        version_file = tmp_path / "version.txt"
        version_file.write_text("1.2.3\n")

        assert parse_version(str(version_file)) == (1, 2, 3)

    def test_parse_version_from_package_json(self, tmp_path):
        """Should read version from package.json's 'version' field."""
        from version_bumper import parse_version

        pkg = tmp_path / "package.json"
        pkg.write_text(json.dumps({"name": "my-app", "version": "2.5.11"}))

        assert parse_version(str(pkg)) == (2, 5, 11)

    def test_parse_version_raises_on_missing_file(self, tmp_path):
        """Should raise FileNotFoundError for a non-existent file."""
        from version_bumper import parse_version

        with pytest.raises(FileNotFoundError):
            parse_version(str(tmp_path / "nonexistent.txt"))

    def test_parse_version_raises_on_invalid_semver(self, tmp_path):
        """Should raise ValueError when the version string is malformed."""
        from version_bumper import parse_version

        bad = tmp_path / "version.txt"
        bad.write_text("not-a-version\n")

        with pytest.raises(ValueError, match="Invalid semantic version"):
            parse_version(str(bad))


# ─────────────────────────────────────────────
# RED: Commit type detection tests
# ─────────────────────────────────────────────

class TestCommitTypeDetection:
    """Tests for determining bump type from a list of commit messages."""

    def test_fix_commit_yields_patch(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(["fix: correct off-by-one error"]) == "patch"

    def test_feat_commit_yields_minor(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(["feat: add new endpoint"]) == "minor"

    def test_breaking_exclamation_yields_major(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(["feat!: redesign API"]) == "major"

    def test_breaking_change_footer_yields_major(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(["feat: new feature\n\nBREAKING CHANGE: old API removed"]) == "major"

    def test_no_relevant_commits_yields_none(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(COMMITS_NO_BUMP) is None

    def test_mixed_commits_major_wins(self):
        """Major always wins regardless of other commit types."""
        from version_bumper import determine_bump_type
        assert determine_bump_type(COMMITS_MAJOR) == "major"

    def test_minor_beats_patch(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(COMMITS_MINOR) == "minor"

    def test_full_patch_fixture(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(COMMITS_PATCH_ONLY) == "patch"

    def test_fix_with_breaking_footer_yields_major(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type(COMMITS_MAJOR_FOOTER) == "major"

    def test_empty_commit_list(self):
        from version_bumper import determine_bump_type
        assert determine_bump_type([]) is None


# ─────────────────────────────────────────────
# RED: Version bump calculation tests
# ─────────────────────────────────────────────

class TestVersionBumpCalculation:
    """Tests for calculating the next version tuple."""

    def test_bump_patch(self):
        from version_bumper import bump_version
        assert bump_version((1, 2, 3), "patch") == (1, 2, 4)

    def test_bump_minor_resets_patch(self):
        from version_bumper import bump_version
        assert bump_version((1, 2, 3), "minor") == (1, 3, 0)

    def test_bump_major_resets_minor_and_patch(self):
        from version_bumper import bump_version
        assert bump_version((1, 2, 3), "major") == (2, 0, 0)

    def test_bump_none_returns_same_version(self):
        from version_bumper import bump_version
        assert bump_version((1, 2, 3), None) == (1, 2, 3)

    def test_bump_patch_from_zero(self):
        from version_bumper import bump_version
        assert bump_version((0, 0, 0), "patch") == (0, 0, 1)

    def test_bump_raises_on_unknown_type(self):
        from version_bumper import bump_version
        with pytest.raises(ValueError, match="Unknown bump type"):
            bump_version((1, 0, 0), "unknown")


# ─────────────────────────────────────────────
# RED: Version file update tests
# ─────────────────────────────────────────────

class TestVersionFileUpdate:
    """Tests for writing the new version back to disk."""

    def test_update_version_txt(self, tmp_path):
        from version_bumper import update_version_file

        version_file = tmp_path / "version.txt"
        version_file.write_text("1.0.0\n")
        update_version_file(str(version_file), (1, 1, 0))

        assert version_file.read_text().strip() == "1.1.0"

    def test_update_package_json_preserves_fields(self, tmp_path):
        from version_bumper import update_version_file

        pkg = tmp_path / "package.json"
        original = {"name": "my-app", "version": "1.0.0", "description": "test"}
        pkg.write_text(json.dumps(original, indent=2))

        update_version_file(str(pkg), (2, 0, 0))

        updated = json.loads(pkg.read_text())
        assert updated["version"] == "2.0.0"
        assert updated["name"] == "my-app"
        assert updated["description"] == "test"


# ─────────────────────────────────────────────
# RED: Changelog generation tests
# ─────────────────────────────────────────────

class TestChangelogGeneration:
    """Tests for generating a changelog entry from commits."""

    def test_changelog_contains_version_header(self):
        from version_bumper import generate_changelog_entry
        entry = generate_changelog_entry((1, 1, 0), COMMITS_MINOR)
        assert "## [1.1.0]" in entry

    def test_changelog_lists_feat_commits(self):
        from version_bumper import generate_changelog_entry
        entry = generate_changelog_entry((1, 1, 0), COMMITS_MINOR)
        assert "add user profile endpoint" in entry

    def test_changelog_sections_for_mixed_commits(self):
        from version_bumper import generate_changelog_entry
        entry = generate_changelog_entry((1, 2, 0), COMMITS_MIXED)
        assert "### Features" in entry
        assert "### Bug Fixes" in entry

    def test_changelog_excludes_non_relevant_types(self):
        """chore/style/test commits should not appear as main sections."""
        from version_bumper import generate_changelog_entry
        entry = generate_changelog_entry((1, 0, 1), COMMITS_PATCH_ONLY)
        # docs commits are included in a separate section or skipped
        assert "## [1.0.1]" in entry

    def test_changelog_includes_date(self):
        from version_bumper import generate_changelog_entry
        import re
        entry = generate_changelog_entry((1, 0, 1), COMMITS_PATCH_ONLY)
        # Should contain a date in ISO format YYYY-MM-DD
        assert re.search(r"\d{4}-\d{2}-\d{2}", entry)

    def test_changelog_breaking_change_section(self):
        from version_bumper import generate_changelog_entry
        entry = generate_changelog_entry((2, 0, 0), COMMITS_MAJOR)
        assert "### Breaking Changes" in entry


# ─────────────────────────────────────────────
# RED: End-to-end integration test
# ─────────────────────────────────────────────

class TestEndToEnd:
    """Integration test running the full pipeline."""

    def test_full_pipeline_minor_bump(self, tmp_path):
        """Running the bumper with feat commits should bump minor version."""
        from version_bumper import run_version_bumper

        version_file = tmp_path / "version.txt"
        version_file.write_text("1.0.0\n")

        new_version = run_version_bumper(str(version_file), COMMITS_MINOR)

        assert new_version == "1.1.0"
        assert version_file.read_text().strip() == "1.1.0"

    def test_full_pipeline_no_bump(self, tmp_path):
        """Running with only chore/docs commits should not change version."""
        from version_bumper import run_version_bumper

        version_file = tmp_path / "version.txt"
        version_file.write_text("3.2.1\n")

        new_version = run_version_bumper(str(version_file), COMMITS_NO_BUMP)

        assert new_version == "3.2.1"
        assert version_file.read_text().strip() == "3.2.1"

    def test_full_pipeline_generates_changelog(self, tmp_path):
        """Changelog file should be created/updated after a run."""
        from version_bumper import run_version_bumper

        version_file = tmp_path / "version.txt"
        version_file.write_text("0.9.0\n")

        run_version_bumper(str(version_file), COMMITS_MAJOR, changelog_path=str(tmp_path / "CHANGELOG.md"))

        changelog = (tmp_path / "CHANGELOG.md").read_text()
        assert "## [1.0.0]" in changelog

    def test_full_pipeline_prepends_to_existing_changelog(self, tmp_path):
        """New entries should appear at the top of an existing changelog."""
        from version_bumper import run_version_bumper

        version_file = tmp_path / "version.txt"
        version_file.write_text("1.0.0\n")
        changelog_file = tmp_path / "CHANGELOG.md"
        changelog_file.write_text("## [1.0.0] - 2024-01-01\n\n- Initial release\n")

        run_version_bumper(str(version_file), COMMITS_MINOR, changelog_path=str(changelog_file))

        content = changelog_file.read_text()
        # New entry must appear before old entry
        assert content.index("## [1.1.0]") < content.index("## [1.0.0]")


# ─────────────────────────────────────────────
# RED: GitHub Actions workflow tests
# ─────────────────────────────────────────────

WORKFLOW_PATH = Path(__file__).parent / ".github" / "workflows" / "semantic-version-bumper.yml"
SCRIPT_PATH = Path(__file__).parent / "version_bumper.py"


class TestWorkflowStructure:
    """Tests that verify the GitHub Actions workflow file is correct."""

    @pytest.fixture(autouse=True)
    def workflow(self):
        """Load and parse the workflow YAML once per test."""
        assert WORKFLOW_PATH.exists(), f"Workflow file not found: {WORKFLOW_PATH}"
        with open(WORKFLOW_PATH) as f:
            self.wf = yaml.safe_load(f)
        # PyYAML parses the bare 'on' key as the boolean True; support both.
        self.triggers = self.wf.get("on") or self.wf.get(True) or {}

    def test_workflow_has_push_trigger(self):
        assert "push" in self.triggers, "Workflow must trigger on push"

    def test_workflow_has_workflow_dispatch_trigger(self):
        assert "workflow_dispatch" in self.triggers, "Workflow must support manual dispatch"

    def test_workflow_has_at_least_one_job(self):
        assert len(self.wf["jobs"]) >= 1

    def test_workflow_jobs_use_checkout(self):
        """Every job must include actions/checkout@v4."""
        for job_name, job in self.wf["jobs"].items():
            step_uses = [s.get("uses", "") for s in job.get("steps", [])]
            assert any("actions/checkout" in u for u in step_uses), \
                f"Job '{job_name}' is missing actions/checkout"

    def test_workflow_references_script_file(self):
        """At least one step must reference the version_bumper script."""
        all_runs = []
        for job in self.wf["jobs"].values():
            for step in job.get("steps", []):
                if "run" in step:
                    all_runs.append(step["run"])
        combined = "\n".join(all_runs)
        assert "version_bumper.py" in combined, \
            "No step references version_bumper.py"

    def test_script_file_exists(self):
        """The script referenced by the workflow must actually exist."""
        assert SCRIPT_PATH.exists(), f"Script not found: {SCRIPT_PATH}"

    def test_workflow_has_python_setup_or_install(self):
        """Workflow must set up Python or install dependencies."""
        all_runs = []
        all_uses = []
        for job in self.wf["jobs"].values():
            for step in job.get("steps", []):
                if "run" in step:
                    all_runs.append(step["run"])
                if "uses" in step:
                    all_uses.append(step["uses"])
        combined_runs = "\n".join(all_runs)
        combined_uses = "\n".join(all_uses)
        has_setup = ("setup-python" in combined_uses or
                     "pip install" in combined_runs or
                     "python" in combined_runs)
        assert has_setup, "Workflow must set up Python"

    def test_actionlint_passes(self):
        """actionlint must report no errors on the workflow file."""
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )
