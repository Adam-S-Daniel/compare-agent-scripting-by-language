"""
TDD test suite for semantic version bumper.

Red/Green/Refactor cycle documented in comments for each group of tests.
"""
import pytest
import sys
import os
import subprocess
import tempfile
import shutil
from pathlib import Path

# Add parent dir to path so we can import version_bumper
sys.path.insert(0, str(Path(__file__).parent.parent))

WORKSPACE_DIR = Path(__file__).parent.parent
WORKFLOW_FILE = WORKSPACE_DIR / ".github" / "workflows" / "semantic-version-bumper.yml"


# ============================================================
# TDD CYCLE 1: Parse version string
# RED: These tests fail because version_bumper.py doesn't exist.
# GREEN: Implement parse_version() to make them pass.
# ============================================================

import version_bumper


class TestParseVersion:
    def test_parse_simple_version(self):
        assert version_bumper.parse_version("1.2.3") == (1, 2, 3)

    def test_parse_version_with_newline(self):
        # VERSION files often have trailing newlines
        assert version_bumper.parse_version("1.2.3\n") == (1, 2, 3)

    def test_parse_version_zeros(self):
        assert version_bumper.parse_version("0.0.0") == (0, 0, 0)

    def test_parse_major_only_incremented(self):
        assert version_bumper.parse_version("10.0.0") == (10, 0, 0)

    def test_parse_version_invalid_raises(self):
        with pytest.raises(ValueError, match="Invalid version"):
            version_bumper.parse_version("not-a-version")


# ============================================================
# TDD CYCLE 2: Classify individual commit messages
# RED: Tests fail because classify_commit() doesn't exist.
# GREEN: Implement classify_commit() with conventional commit parsing.
# ============================================================

class TestClassifyCommit:
    def test_fix_commit_is_patch(self):
        assert version_bumper.classify_commit("fix: resolve null pointer") == "patch"

    def test_feat_commit_is_minor(self):
        assert version_bumper.classify_commit("feat: add user profile upload") == "minor"

    def test_breaking_exclamation_is_major(self):
        # feat! convention for breaking changes
        assert version_bumper.classify_commit("feat!: remove deprecated API") == "major"

    def test_fix_breaking_is_major(self):
        assert version_bumper.classify_commit("fix!: change error format") == "major"

    def test_breaking_change_keyword_is_major(self):
        assert version_bumper.classify_commit("BREAKING CHANGE: old auth removed") == "major"

    def test_chore_is_none(self):
        assert version_bumper.classify_commit("chore: update dependencies") == "none"

    def test_docs_is_none(self):
        assert version_bumper.classify_commit("docs: update README") == "none"

    def test_fix_with_scope_is_patch(self):
        assert version_bumper.classify_commit("fix(auth): correct token expiry") == "patch"

    def test_feat_with_scope_is_minor(self):
        assert version_bumper.classify_commit("feat(ui): add dark mode toggle") == "minor"

    def test_refactor_is_none(self):
        assert version_bumper.classify_commit("refactor: extract auth helper") == "none"

    def test_empty_line_is_none(self):
        assert version_bumper.classify_commit("") == "none"


# ============================================================
# TDD CYCLE 3: Parse a block of commit messages
# RED: Tests fail because parse_commits() doesn't exist.
# GREEN: Implement parse_commits() to split and classify each line.
# ============================================================

class TestParseCommits:
    def test_parse_single_fix(self):
        commits = version_bumper.parse_commits("fix: resolve bug\n")
        assert len(commits) == 1
        assert commits[0]["type"] == "patch"
        assert "fix: resolve bug" in commits[0]["message"]

    def test_parse_multiple_commits(self):
        text = "feat: new feature\nfix: bug fix\nchore: update deps\n"
        commits = version_bumper.parse_commits(text)
        assert len(commits) == 3

    def test_skip_blank_lines(self):
        text = "fix: bug\n\nfeat: feature\n\n"
        commits = version_bumper.parse_commits(text)
        assert len(commits) == 2

    def test_parse_preserves_message(self):
        commits = version_bumper.parse_commits("feat: add dashboard widget\n")
        assert commits[0]["message"] == "feat: add dashboard widget"


# ============================================================
# TDD CYCLE 4: Determine version bump type from commits
# RED: Tests fail because determine_bump() doesn't exist.
# GREEN: Implement determine_bump() with priority: major > minor > patch.
# ============================================================

class TestDetermineBump:
    def test_only_patch_commits_gives_patch(self):
        commits = [{"type": "patch"}, {"type": "patch"}]
        assert version_bumper.determine_bump(commits) == "patch"

    def test_only_minor_commits_gives_minor(self):
        commits = [{"type": "minor"}, {"type": "none"}]
        assert version_bumper.determine_bump(commits) == "minor"

    def test_major_overrides_minor_and_patch(self):
        commits = [{"type": "patch"}, {"type": "minor"}, {"type": "major"}]
        assert version_bumper.determine_bump(commits) == "major"

    def test_minor_overrides_patch(self):
        commits = [{"type": "patch"}, {"type": "minor"}]
        assert version_bumper.determine_bump(commits) == "minor"

    def test_only_none_commits_gives_none(self):
        commits = [{"type": "none"}, {"type": "none"}]
        assert version_bumper.determine_bump(commits) == "none"

    def test_empty_commits_gives_none(self):
        assert version_bumper.determine_bump([]) == "none"


# ============================================================
# TDD CYCLE 5: Calculate new version from bump type
# RED: Tests fail because bump_version() doesn't exist.
# GREEN: Implement bump_version() for patch/minor/major/none.
# ============================================================

class TestBumpVersion:
    def test_patch_bump(self):
        assert version_bumper.bump_version((1, 2, 3), "patch") == "1.2.4"

    def test_minor_bump_resets_patch(self):
        assert version_bumper.bump_version((1, 2, 3), "minor") == "1.3.0"

    def test_major_bump_resets_minor_and_patch(self):
        assert version_bumper.bump_version((1, 2, 3), "major") == "2.0.0"

    def test_no_bump(self):
        assert version_bumper.bump_version((1, 5, 2), "none") == "1.5.2"

    def test_patch_from_zero(self):
        assert version_bumper.bump_version((0, 0, 0), "patch") == "0.0.1"

    def test_major_from_zero(self):
        assert version_bumper.bump_version((0, 0, 0), "major") == "1.0.0"

    def test_non_trivial_version_minor(self):
        assert version_bumper.bump_version((2, 3, 4), "minor") == "2.4.0"


# ============================================================
# TDD CYCLE 6: Generate changelog entry
# RED: Tests fail because generate_changelog() doesn't exist.
# GREEN: Implement generate_changelog() to produce structured markdown.
# ============================================================

class TestGenerateChangelog:
    def setup_method(self):
        self.commits = [
            {"message": "feat: add dashboard", "type": "minor"},
            {"message": "fix: correct validation", "type": "patch"},
            {"message": "chore: update deps", "type": "none"},
        ]

    def test_changelog_contains_new_version(self):
        entry = version_bumper.generate_changelog(self.commits, "1.0.0", "1.1.0")
        assert "1.1.0" in entry

    def test_changelog_has_features_section(self):
        entry = version_bumper.generate_changelog(self.commits, "1.0.0", "1.1.0")
        assert "Features" in entry
        assert "feat: add dashboard" in entry

    def test_changelog_has_bugfixes_section(self):
        entry = version_bumper.generate_changelog(self.commits, "1.0.0", "1.1.0")
        assert "Bug Fix" in entry
        assert "fix: correct validation" in entry

    def test_changelog_has_date(self):
        entry = version_bumper.generate_changelog(self.commits, "1.0.0", "1.1.0")
        # Date in YYYY-MM-DD format
        import re
        assert re.search(r"\d{4}-\d{2}-\d{2}", entry)

    def test_changelog_breaking_change_section(self):
        commits = [{"message": "feat!: remove old API", "type": "major"}]
        entry = version_bumper.generate_changelog(commits, "1.0.0", "2.0.0")
        assert "Breaking" in entry


# ============================================================
# TDD CYCLE 7: Read version from VERSION file
# RED: Tests fail because read_version() doesn't exist.
# GREEN: Implement read_version() to support VERSION file and package.json.
# ============================================================

class TestReadVersion:
    def test_read_from_version_file(self, tmp_path):
        (tmp_path / "VERSION").write_text("1.2.3\n")
        assert version_bumper.read_version(
            version_file=str(tmp_path / "VERSION"),
            package_json=str(tmp_path / "package.json")
        ) == "1.2.3"

    def test_read_from_package_json(self, tmp_path):
        import json
        pkg = {"name": "myapp", "version": "3.4.5"}
        (tmp_path / "package.json").write_text(json.dumps(pkg))
        assert version_bumper.read_version(
            version_file=str(tmp_path / "VERSION"),
            package_json=str(tmp_path / "package.json")
        ) == "3.4.5"

    def test_version_file_takes_priority(self, tmp_path):
        import json
        (tmp_path / "VERSION").write_text("1.0.0\n")
        pkg = {"name": "myapp", "version": "9.9.9"}
        (tmp_path / "package.json").write_text(json.dumps(pkg))
        assert version_bumper.read_version(
            version_file=str(tmp_path / "VERSION"),
            package_json=str(tmp_path / "package.json")
        ) == "1.0.0"

    def test_missing_files_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            version_bumper.read_version(
                version_file=str(tmp_path / "VERSION"),
                package_json=str(tmp_path / "package.json")
            )


# ============================================================
# WORKFLOW STRUCTURE TESTS
# These verify the GitHub Actions workflow file is correct.
# ============================================================

class TestWorkflowStructure:
    """Tests that parse the workflow YAML and verify its structure."""

    def _load_workflow(self):
        try:
            import yaml
        except ImportError:
            pytest.skip("pyyaml not installed")
        with open(WORKFLOW_FILE) as f:
            wf = yaml.safe_load(f)
        # pyyaml parses 'on' as boolean True — normalize it
        if True in wf and "on" not in wf:
            wf["on"] = wf.pop(True)
        return wf

    def test_workflow_file_exists(self):
        assert WORKFLOW_FILE.exists(), f"Workflow file not found: {WORKFLOW_FILE}"

    def test_workflow_has_push_trigger(self):
        wf = self._load_workflow()
        assert "push" in wf.get("on", {}), "Workflow must have push trigger"

    def test_workflow_has_workflow_dispatch_trigger(self):
        wf = self._load_workflow()
        assert "workflow_dispatch" in wf.get("on", {}), "Workflow must have workflow_dispatch trigger"

    def test_workflow_has_jobs(self):
        wf = self._load_workflow()
        assert wf.get("jobs"), "Workflow must have at least one job"

    def test_workflow_job_has_steps(self):
        wf = self._load_workflow()
        jobs = wf.get("jobs", {})
        for job_name, job in jobs.items():
            assert job.get("steps"), f"Job '{job_name}' must have steps"

    def test_workflow_references_version_bumper_script(self):
        content = WORKFLOW_FILE.read_text()
        assert "version_bumper.py" in content, "Workflow must reference version_bumper.py"

    def test_version_bumper_script_exists(self):
        script = WORKSPACE_DIR / "version_bumper.py"
        assert script.exists(), "version_bumper.py must exist"

    def test_workflow_has_checkout_step(self):
        wf = self._load_workflow()
        jobs = wf.get("jobs", {})
        found_checkout = False
        for job in jobs.values():
            for step in job.get("steps", []):
                if "actions/checkout" in str(step.get("uses", "")):
                    found_checkout = True
        assert found_checkout, "Workflow must include actions/checkout step"

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_FILE)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
        )
