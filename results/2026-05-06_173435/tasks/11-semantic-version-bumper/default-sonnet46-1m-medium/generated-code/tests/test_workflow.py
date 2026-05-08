"""
Workflow structure tests.
Verify the GitHub Actions workflow YAML has the expected shape,
references existing script files, and passes actionlint.
"""
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

WORKSPACE = Path(__file__).parent.parent
WORKFLOW_PATH = WORKSPACE / ".github" / "workflows" / "semantic-version-bumper.yml"


@pytest.fixture(scope="module")
def workflow() -> dict:
    with WORKFLOW_PATH.open() as f:
        return yaml.safe_load(f)


def _triggers(workflow: dict) -> dict:
    # PyYAML 5.x parses bare 'on' as boolean True; handle both cases.
    return workflow.get("on") or workflow.get(True) or {}


def test_workflow_file_exists():
    assert WORKFLOW_PATH.exists(), "workflow YAML not found"


def test_workflow_has_push_trigger(workflow):
    assert "push" in _triggers(workflow), "missing push trigger"


def test_workflow_has_pull_request_trigger(workflow):
    assert "pull_request" in _triggers(workflow), "missing pull_request trigger"


def test_workflow_has_workflow_dispatch_trigger(workflow):
    assert "workflow_dispatch" in _triggers(workflow), "missing workflow_dispatch trigger"


def test_workflow_has_permissions(workflow):
    assert "permissions" in workflow, "missing permissions block"


def test_workflow_has_jobs(workflow):
    assert "jobs" in workflow and workflow["jobs"], "no jobs defined"


def test_workflow_job_runs_on_ubuntu(workflow):
    jobs = workflow["jobs"]
    for job in jobs.values():
        assert "ubuntu" in job.get("runs-on", ""), "job should run on ubuntu-latest"


def test_workflow_has_checkout_step(workflow):
    all_steps = [s for job in workflow["jobs"].values() for s in job.get("steps", [])]
    uses_vals = [s.get("uses", "") for s in all_steps]
    assert any("actions/checkout" in u for u in uses_vals), "missing checkout step"


def test_workflow_has_setup_python_step(workflow):
    all_steps = [s for job in workflow["jobs"].values() for s in job.get("steps", [])]
    uses_vals = [s.get("uses", "") for s in all_steps]
    assert any("setup-python" in u for u in uses_vals), "missing setup-python step"


def test_workflow_runs_pytest(workflow):
    all_steps = [s for job in workflow["jobs"].values() for s in job.get("steps", [])]
    run_cmds = " ".join(s.get("run", "") for s in all_steps)
    assert "pytest" in run_cmds, "workflow must run pytest"


def test_workflow_runs_bump_version_script(workflow):
    all_steps = [s for job in workflow["jobs"].values() for s in job.get("steps", [])]
    run_cmds = " ".join(s.get("run", "") for s in all_steps)
    assert "bump_version.py" in run_cmds, "workflow must invoke bump_version.py"


def test_script_file_exists():
    assert (WORKSPACE / "bump_version.py").exists(), "bump_version.py not found"


def test_tests_directory_exists():
    assert (WORKSPACE / "tests").is_dir(), "tests/ directory not found"


def test_fixtures_directory_exists():
    assert (WORKSPACE / "fixtures").is_dir(), "fixtures/ directory not found"


def test_fixture_commits_patch_exists():
    assert (WORKSPACE / "fixtures" / "commits_patch.txt").exists()


def test_fixture_commits_minor_exists():
    assert (WORKSPACE / "fixtures" / "commits_minor.txt").exists()


def test_fixture_commits_major_exists():
    assert (WORKSPACE / "fixtures" / "commits_major.txt").exists()


@pytest.mark.skipif(
    shutil.which("actionlint") is None,
    reason="actionlint not installed in this environment",
)
def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )
