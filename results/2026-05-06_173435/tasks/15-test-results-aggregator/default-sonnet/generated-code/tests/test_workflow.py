"""
Workflow structure tests — verify the GitHub Actions YAML has the expected shape,
references real files, and passes actionlint.

Written in TDD red/green style: these are written before the workflow exists so they
fail first, then the workflow is created to make them pass.
"""
import subprocess
import sys
from pathlib import Path

import shutil

import pytest
import yaml

REPO_ROOT = Path(__file__).parent.parent
WORKFLOW_PATH = REPO_ROOT / ".github" / "workflows" / "test-results-aggregator.yml"


class TestWorkflowExists:
    def test_workflow_file_exists(self):
        assert WORKFLOW_PATH.exists(), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_is_valid_yaml(self):
        content = WORKFLOW_PATH.read_text(encoding="utf-8")
        doc = yaml.safe_load(content)
        assert isinstance(doc, dict), "Workflow YAML root must be a dict"


class TestWorkflowTriggers:
    def setup_method(self):
        self.doc = yaml.safe_load(WORKFLOW_PATH.read_text(encoding="utf-8"))
        self.on = self.doc.get("on", self.doc.get(True))  # YAML parses 'on' as True

    def test_has_push_trigger(self):
        assert "push" in self.on, "Workflow must trigger on push"

    def test_has_workflow_dispatch_trigger(self):
        assert "workflow_dispatch" in self.on, "Workflow must have workflow_dispatch trigger"


class TestWorkflowJobs:
    def setup_method(self):
        self.doc = yaml.safe_load(WORKFLOW_PATH.read_text(encoding="utf-8"))
        self.jobs = self.doc.get("jobs", {})

    def test_has_at_least_one_job(self):
        assert len(self.jobs) >= 1, "Workflow must define at least one job"

    def test_job_runs_on_ubuntu(self):
        for job in self.jobs.values():
            assert "ubuntu" in job.get("runs-on", ""), \
                f"Job must use ubuntu runner, got: {job.get('runs-on')}"

    def test_job_has_steps(self):
        for job_name, job in self.jobs.items():
            steps = job.get("steps", [])
            assert len(steps) >= 1, f"Job '{job_name}' must have steps"


class TestWorkflowSteps:
    def setup_method(self):
        self.doc = yaml.safe_load(WORKFLOW_PATH.read_text(encoding="utf-8"))
        # Collect all steps across all jobs.
        self.all_steps = []
        for job in self.doc.get("jobs", {}).values():
            self.all_steps.extend(job.get("steps", []))

    def _uses(self, prefix: str) -> bool:
        return any(str(s.get("uses", "")).startswith(prefix) for s in self.all_steps)

    def test_has_checkout_step(self):
        assert self._uses("actions/checkout"), "Workflow must use actions/checkout"

    def test_has_pytest_step(self):
        run_cmds = " ".join(str(s.get("run", "")) for s in self.all_steps)
        assert "pytest" in run_cmds, "Workflow must run pytest"

    def test_has_aggregator_step(self):
        run_cmds = " ".join(str(s.get("run", "")) for s in self.all_steps)
        assert "aggregator.py" in run_cmds, "Workflow must run aggregator.py"


class TestWorkflowReferencesExistingFiles:
    def setup_method(self):
        self.doc = yaml.safe_load(WORKFLOW_PATH.read_text(encoding="utf-8"))

    def test_aggregator_script_exists(self):
        assert (REPO_ROOT / "aggregator.py").exists(), \
            "aggregator.py referenced by workflow does not exist"

    def test_fixtures_directory_exists(self):
        assert (REPO_ROOT / "fixtures").is_dir(), \
            "fixtures/ directory referenced by workflow does not exist"

    def test_fixture_files_exist(self):
        fixtures = list((REPO_ROOT / "fixtures").glob("*.xml")) + \
                   list((REPO_ROOT / "fixtures").glob("*.json"))
        assert len(fixtures) >= 3, \
            f"Expected at least 3 fixture files, found {len(fixtures)}"


class TestActionlint:
    @pytest.mark.skipif(
        shutil.which("actionlint") is None,
        reason="actionlint not installed in this environment",
    )
    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", str(WORKFLOW_PATH)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, \
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
