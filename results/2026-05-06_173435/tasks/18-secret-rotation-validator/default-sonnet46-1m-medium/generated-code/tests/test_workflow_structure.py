"""
Workflow structure tests.

Verify the GitHub Actions workflow YAML has the expected shape and that
actionlint passes. These tests run inside the act container via pytest.

TDD note: these tests were written after the core validator tests to
validate the CI/CD pipeline configuration itself.
"""

import os
import subprocess
import shutil

import pytest
import yaml

WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__), "..", ".github", "workflows", "secret-rotation-validator.yml"
)
WORKFLOW_PATH = os.path.normpath(WORKFLOW_PATH)

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "..", "secret_rotation_validator.py")
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "..", "fixtures")


@pytest.fixture(scope="module")
def workflow():
    """Load and return the parsed workflow YAML."""
    with open(WORKFLOW_PATH) as f:
        return yaml.safe_load(f)


def _triggers(workflow: dict) -> dict:
    # PyYAML 5.x parses the 'on:' key as boolean True (YAML 1.1 spec).
    # Try both spellings so tests work across PyYAML versions.
    return workflow.get("on") or workflow.get(True) or {}


# ── File existence ────────────────────────────────────────────────────────────

def test_workflow_file_exists():
    assert os.path.isfile(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"

def test_validator_script_exists():
    assert os.path.isfile(os.path.normpath(SCRIPT_PATH))

def test_fixtures_dir_exists():
    assert os.path.isdir(os.path.normpath(FIXTURES_DIR))

def test_fixture_secrets_mixed_exists():
    path = os.path.join(FIXTURES_DIR, "secrets_mixed.json")
    assert os.path.isfile(os.path.normpath(path))


# ── Trigger events ────────────────────────────────────────────────────────────

def test_workflow_has_push_trigger(workflow):
    assert "push" in _triggers(workflow)

def test_workflow_has_pull_request_trigger(workflow):
    assert "pull_request" in _triggers(workflow)

def test_workflow_has_schedule_trigger(workflow):
    assert "schedule" in _triggers(workflow)

def test_workflow_has_workflow_dispatch_trigger(workflow):
    assert "workflow_dispatch" in _triggers(workflow)


# ── Jobs ──────────────────────────────────────────────────────────────────────

def test_workflow_has_test_job(workflow):
    assert "test" in workflow["jobs"]

def test_workflow_has_report_job(workflow):
    assert "report" in workflow["jobs"]

def test_report_job_needs_test(workflow):
    needs = workflow["jobs"]["report"].get("needs", [])
    if isinstance(needs, str):
        needs = [needs]
    assert "test" in needs, "report job should depend on test job"


# ── Steps reference valid files ───────────────────────────────────────────────

def test_workflow_references_validator_script(workflow):
    """At least one step in the workflow should reference our script."""
    all_steps = []
    for job in workflow["jobs"].values():
        all_steps.extend(job.get("steps", []))

    run_commands = [s.get("run", "") for s in all_steps if "run" in s]
    combined = "\n".join(run_commands)
    assert "secret_rotation_validator.py" in combined

def test_workflow_references_fixtures(workflow):
    """The report job should reference the fixtures directory."""
    report_steps = workflow["jobs"]["report"].get("steps", [])
    run_commands = [s.get("run", "") for s in report_steps if "run" in s]
    combined = "\n".join(run_commands)
    assert "fixtures" in combined


# ── actionlint ────────────────────────────────────────────────────────────────

def test_actionlint_passes():
    """actionlint must exit 0 — validates the workflow has no syntax errors."""
    actionlint_bin = shutil.which("actionlint")
    if actionlint_bin is None:
        pytest.skip("actionlint not in PATH (install it to enable this check)")
    result = subprocess.run(
        [actionlint_bin, WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
