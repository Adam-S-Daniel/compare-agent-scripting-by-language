"""Workflow structure tests (TDD).

These verify the GitHub Actions workflow file without running act:
  - YAML is valid and has expected structure
  - All referenced script/fixture paths exist on disk
  - actionlint passes (subprocess, assert exit code 0)
"""

import os
import subprocess
import sys

import pytest
import yaml

WORKFLOW_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    ".github", "workflows", "test-results-aggregator.yml",
)
ROOT = os.path.dirname(os.path.dirname(__file__))


# ---------------------------------------------------------------------------
# Red: written before the workflow file exists — will fail until it's created
# ---------------------------------------------------------------------------

class TestWorkflowExists:
    def test_workflow_file_exists(self):
        assert os.path.isfile(WORKFLOW_PATH), (
            f"Workflow file not found: {WORKFLOW_PATH}"
        )


class TestWorkflowStructure:
    @pytest.fixture(autouse=True)
    def workflow(self):
        # BaseLoader treats all scalars as strings, preserving 'on' as a key
        # (safe_load converts 'on' to boolean True)
        with open(WORKFLOW_PATH) as f:
            self._wf = yaml.load(f, Loader=yaml.BaseLoader)

    def test_has_on_triggers(self):
        assert "on" in self._wf, "Workflow must have 'on' trigger block"

    def test_has_push_trigger(self):
        on = self._wf["on"]
        assert "push" in on, "Workflow must trigger on push"

    def test_has_workflow_dispatch(self):
        on = self._wf["on"]
        assert "workflow_dispatch" in on, "Workflow must support workflow_dispatch"

    def test_has_jobs(self):
        assert "jobs" in self._wf and self._wf["jobs"], "Workflow must have jobs"

    def test_aggregate_job_exists(self):
        assert "aggregate" in self._wf["jobs"], "Workflow must have an 'aggregate' job"

    def test_aggregate_uses_ubuntu(self):
        runs_on = self._wf["jobs"]["aggregate"]["runs-on"]
        assert "ubuntu" in runs_on, f"Expected ubuntu runner, got: {runs_on}"

    def test_has_checkout_step(self):
        steps = self._wf["jobs"]["aggregate"]["steps"]
        uses_values = [s.get("uses", "") for s in steps]
        assert any("actions/checkout" in u for u in uses_values), (
            "Workflow must use actions/checkout"
        )

    def test_has_python_setup_step(self):
        steps = self._wf["jobs"]["aggregate"]["steps"]
        uses_values = [s.get("uses", "") for s in steps]
        assert any("actions/setup-python" in u for u in uses_values), (
            "Workflow must use actions/setup-python"
        )

    def test_references_aggregator_script(self):
        # At least one step's run command should mention aggregator.py
        steps = self._wf["jobs"]["aggregate"]["steps"]
        run_cmds = " ".join(s.get("run", "") for s in steps)
        assert "aggregator.py" in run_cmds, (
            "Workflow must reference aggregator.py in a run step"
        )

    def test_references_fixture_files(self):
        steps = self._wf["jobs"]["aggregate"]["steps"]
        run_cmds = " ".join(s.get("run", "") for s in steps)
        assert "fixtures" in run_cmds, (
            "Workflow must pass fixture directories to the aggregator"
        )


class TestWorkflowReferencedFilesExist:
    """All files the workflow references must actually exist."""

    def test_aggregator_script_exists(self):
        assert os.path.isfile(os.path.join(ROOT, "aggregator.py")), (
            "aggregator.py must exist"
        )

    def test_fixture_run1_exists(self):
        assert os.path.isfile(os.path.join(ROOT, "fixtures", "run1", "junit.xml"))

    def test_fixture_run2_exists(self):
        assert os.path.isfile(os.path.join(ROOT, "fixtures", "run2", "json.json"))

    def test_fixture_run3_exists(self):
        assert os.path.isfile(os.path.join(ROOT, "fixtures", "run3", "junit.xml"))


class TestActionlint:
    """actionlint must pass with zero errors."""

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
        )
