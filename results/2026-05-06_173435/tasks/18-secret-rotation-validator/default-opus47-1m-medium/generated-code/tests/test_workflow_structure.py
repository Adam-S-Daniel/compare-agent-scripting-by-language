"""Workflow structure tests.

These verify the workflow YAML before we ever invoke `act`:
  - YAML parses
  - expected triggers, jobs, steps are present
  - file references on disk actually exist
  - `actionlint` passes (exit code 0)
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

# PyYAML may not be on PATH in every environment; skip yaml-parse tests if absent.
yaml = pytest.importorskip("yaml")

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github/workflows/secret-rotation-validator.yml"


@pytest.fixture(scope="module")
def parsed_workflow():
    with WORKFLOW.open() as fh:
        return yaml.safe_load(fh)


def test_workflow_file_exists():
    assert WORKFLOW.is_file()


def test_workflow_has_expected_triggers(parsed_workflow):
    # PyYAML parses bare `on:` as the boolean True due to YAML 1.1 quirk.
    on = parsed_workflow.get("on") or parsed_workflow.get(True)
    assert on is not None
    assert "push" in on
    assert "pull_request" in on
    assert "schedule" in on
    assert "workflow_dispatch" in on


def test_workflow_has_unit_test_and_validate_jobs(parsed_workflow):
    jobs = parsed_workflow["jobs"]
    assert "unit-tests" in jobs
    assert "validate-secrets" in jobs
    # validate-secrets depends on unit-tests
    assert jobs["validate-secrets"]["needs"] == "unit-tests"


def test_workflow_runs_pytest(parsed_workflow):
    steps = parsed_workflow["jobs"]["unit-tests"]["steps"]
    runs = " ".join(s.get("run", "") for s in steps)
    assert "pytest" in runs


def test_workflow_invokes_validator_script(parsed_workflow):
    steps = parsed_workflow["jobs"]["validate-secrets"]["steps"]
    runs = " ".join(s.get("run", "") for s in steps)
    assert "validator.py" in runs
    assert "--format markdown" in runs
    assert "--format json" in runs


def test_referenced_files_exist_on_disk():
    assert (ROOT / "validator.py").is_file()
    assert (ROOT / "fixtures" / "mixed.json").is_file()
    assert (ROOT / "fixtures" / "all-ok.json").is_file()


def test_actionlint_passes():
    if not shutil.which("actionlint"):
        pytest.skip("actionlint not installed")
    proc = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert proc.returncode == 0, f"actionlint failed:\n{proc.stdout}\n{proc.stderr}"
