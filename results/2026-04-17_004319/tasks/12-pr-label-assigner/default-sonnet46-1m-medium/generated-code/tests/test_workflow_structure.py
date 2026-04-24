# TDD: Workflow structure tests written BEFORE the workflow file exists (red phase).
# They fail until .github/workflows/pr-label-assigner.yml is created.

import os
import shutil
import subprocess
import pytest

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW_PATH = os.path.join(BASE_DIR, ".github", "workflows", "pr-label-assigner.yml")
SCRIPT_PATH = os.path.join(BASE_DIR, "label_assigner.py")
FIXTURE_PATH = os.path.join(BASE_DIR, "fixtures", "test_input.json")


def test_workflow_file_exists():
    assert os.path.exists(WORKFLOW_PATH), f"Workflow file missing: {WORKFLOW_PATH}"


def test_script_file_exists():
    assert os.path.exists(SCRIPT_PATH), f"Script missing: {SCRIPT_PATH}"


def test_fixture_file_exists():
    assert os.path.exists(FIXTURE_PATH), f"Fixture missing: {FIXTURE_PATH}"


@pytest.mark.skipif(not HAS_YAML, reason="pyyaml not installed")
def test_workflow_yaml_parses():
    with open(WORKFLOW_PATH) as fh:
        data = yaml.safe_load(fh)
    assert data is not None, "Workflow YAML parsed to None"


@pytest.mark.skipif(not HAS_YAML, reason="pyyaml not installed")
def test_workflow_has_push_trigger():
    with open(WORKFLOW_PATH) as fh:
        data = yaml.safe_load(fh)
    triggers = data.get("on", {})
    assert "push" in triggers, f"No 'push' trigger. Got: {list(triggers.keys())}"


@pytest.mark.skipif(not HAS_YAML, reason="pyyaml not installed")
def test_workflow_has_jobs():
    with open(WORKFLOW_PATH) as fh:
        data = yaml.safe_load(fh)
    jobs = data.get("jobs", {})
    assert len(jobs) > 0, "Workflow has no jobs"


@pytest.mark.skipif(not HAS_YAML, reason="pyyaml not installed")
def test_workflow_uses_checkout_action():
    with open(WORKFLOW_PATH) as fh:
        data = yaml.safe_load(fh)
    found = False
    for job in data.get("jobs", {}).values():
        for step in job.get("steps", []):
            if "uses" in step and "actions/checkout" in step["uses"]:
                found = True
    assert found, "No actions/checkout step found in workflow"


@pytest.mark.skipif(not HAS_YAML, reason="pyyaml not installed")
def test_workflow_references_label_assigner_script():
    with open(WORKFLOW_PATH) as fh:
        content = fh.read()
    assert "label_assigner.py" in content, "Workflow does not reference label_assigner.py"


def test_actionlint_passes():
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not in PATH")
    result = subprocess.run(
        ["actionlint", WORKFLOW_PATH],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
    )
