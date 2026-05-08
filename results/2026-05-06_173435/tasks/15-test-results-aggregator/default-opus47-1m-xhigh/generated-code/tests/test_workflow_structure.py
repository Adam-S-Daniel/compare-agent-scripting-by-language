# Workflow-structure tests: parse the YAML and assert the workflow is
# wired up correctly. These run BEFORE the act harness so we catch
# regressions in seconds rather than minutes.
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

WORKSPACE = Path(__file__).resolve().parent.parent
WORKFLOW = WORKSPACE / ".github" / "workflows" / "test-results-aggregator.yml"


@pytest.fixture(scope="module")
def workflow_doc():
    """Parsed YAML for the workflow file."""
    assert WORKFLOW.exists(), f"missing workflow file at {WORKFLOW}"
    return yaml.safe_load(WORKFLOW.read_text())


def test_workflow_yaml_is_valid(workflow_doc):
    assert isinstance(workflow_doc, dict)
    assert "jobs" in workflow_doc


def test_workflow_has_expected_triggers(workflow_doc):
    # PyYAML parses `on:` as the boolean True (the YAML 1.1 quirk),
    # so handle either key.
    triggers = workflow_doc.get("on", workflow_doc.get(True))
    assert triggers is not None, "workflow must declare an 'on:' trigger block"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers
    assert "schedule" in triggers


def test_workflow_has_explicit_permissions(workflow_doc):
    # Explicit permissions block guards against accidental token escalation.
    assert workflow_doc.get("permissions") == {"contents": "read"}


def test_workflow_job_runs_on_ubuntu_and_uses_python(workflow_doc):
    job = workflow_doc["jobs"]["aggregate"]
    assert job["runs-on"] == "ubuntu-latest"
    actions_used = [s.get("uses") for s in job["steps"] if s.get("uses")]
    assert "actions/checkout@v4" in actions_used
    assert any(u.startswith("actions/upload-artifact@") for u in actions_used)
    # We deliberately don't use setup-python — the runner image already
    # ships with python3 (3.10+) which is sufficient. Assert that the
    # workflow invokes python3 directly.
    run_steps = "\n".join(s.get("run", "") for s in job["steps"] if "run" in s)
    assert "python3" in run_steps


def test_workflow_runs_unit_tests_and_aggregator(workflow_doc):
    job = workflow_doc["jobs"]["aggregate"]
    run_steps = [s.get("run", "") for s in job["steps"] if "run" in s]
    joined = "\n".join(run_steps)
    assert "pytest tests/" in joined, "workflow must run the unit-test suite"
    assert "aggregator.py" in joined, "workflow must invoke the aggregator"
    assert "fixtures/" in joined, "workflow must reference fixture files"


def test_workflow_references_existing_files(workflow_doc):
    """All file paths referenced from `run:` steps must exist in the repo."""
    assert (WORKSPACE / "aggregator.py").exists()
    assert (WORKSPACE / "tests").is_dir()
    assert (WORKSPACE / "fixtures").is_dir()
    # All three scenario fixture pairs.
    for scenario in ("all-pass", "with-flake", "with-failures"):
        assert (WORKSPACE / "fixtures" / f"{scenario}-run1.xml").exists()
        assert (WORKSPACE / "fixtures" / f"{scenario}-run2.json").exists()


def test_actionlint_passes_cleanly():
    """actionlint must report zero issues against the workflow."""
    actionlint = shutil.which("actionlint")
    if not actionlint:
        pytest.skip("actionlint binary not on PATH")
    proc = subprocess.run(
        [actionlint, str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert proc.returncode == 0, (
        f"actionlint failed:\nstdout={proc.stdout}\nstderr={proc.stderr}"
    )
