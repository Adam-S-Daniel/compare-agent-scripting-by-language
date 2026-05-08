# Workflow-structure tests.
#
# These don't run `act` — they just parse the YAML and confirm the
# workflow names the script + fixture paths we expect, declares the
# right triggers, and passes actionlint cleanly. This catches drift
# without paying the act-startup cost.

import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "secret-rotation-validator.yml"


@pytest.fixture(scope="module")
def workflow():
    text = WORKFLOW_PATH.read_text()
    # PyYAML parses the bare word `on` as Python True (YAML 1.1 boolean
    # alias), so the triggers section ends up under the key `True`. We
    # accept either, since that quirk is unrelated to workflow correctness.
    return yaml.safe_load(text)


def _on_section(wf):
    return wf.get("on") if "on" in wf else wf.get(True)


def test_workflow_file_exists():
    assert WORKFLOW_PATH.exists(), f"missing workflow at {WORKFLOW_PATH}"


def test_workflow_has_expected_triggers(workflow):
    on = _on_section(workflow)
    assert on is not None, "workflow has no `on:` section"
    # Spec required at least two of these; we provide all four.
    for trigger in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert trigger in on, f"missing trigger: {trigger}"


def test_workflow_has_jobs(workflow):
    jobs = workflow["jobs"]
    assert "unit-tests" in jobs
    assert "rotation-audit" in jobs
    # rotation-audit depends on unit-tests
    assert jobs["rotation-audit"].get("needs") == "unit-tests"


def test_workflow_references_existing_files(workflow):
    text = WORKFLOW_PATH.read_text()
    # Every file path the workflow names must exist in the repo so the
    # audit step doesn't fail with "no such file" inside act.
    assert "rotation_validator.py" in text
    assert (PROJECT_ROOT / "rotation_validator.py").exists()
    assert "fixtures/secrets.json" in text
    assert (PROJECT_ROOT / "fixtures" / "secrets.json").exists()
    assert "tests/" in text
    assert (PROJECT_ROOT / "tests").is_dir()


def test_workflow_uses_pinned_checkout(workflow):
    # actions/checkout pinned to a major version — both jobs use it.
    text = WORKFLOW_PATH.read_text()
    assert "actions/checkout@v4" in text
    assert "actions/setup-python@v5" in text


def test_workflow_declares_least_privilege_permissions(workflow):
    assert workflow.get("permissions") == {"contents": "read"}


def test_actionlint_passes():
    actionlint = shutil.which("actionlint")
    if actionlint is None:
        pytest.skip("actionlint not installed in this environment")
    proc = subprocess.run(
        [actionlint, str(WORKFLOW_PATH)],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )
    assert proc.returncode == 0, (
        f"actionlint failed (exit {proc.returncode}):\n"
        f"STDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
    )
