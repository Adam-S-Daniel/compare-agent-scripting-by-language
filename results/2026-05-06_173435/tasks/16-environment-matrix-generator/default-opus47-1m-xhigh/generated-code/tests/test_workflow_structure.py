"""Workflow-structure tests.

These verify the YAML file under .github/workflows/ has the expected
triggers, jobs, steps, and that script paths it references actually
exist on disk. They run as part of the unit-tests job inside `act`,
so the workflow self-validates every CI run.
"""
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = REPO_ROOT / ".github" / "workflows" / "environment-matrix-generator.yml"


@pytest.fixture(scope="module")
def workflow():
    return yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))


def _triggers(wf):
    # PyYAML 1.1 quirk: bare ``on`` is parsed as the boolean True. Accept either.
    return wf.get("on") if "on" in wf else wf.get(True)


def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"workflow file not found at {WORKFLOW}"


def test_workflow_has_expected_triggers(workflow):
    triggers = _triggers(workflow)
    assert triggers is not None
    keys = set(triggers.keys() if isinstance(triggers, dict) else triggers)
    for must_have in ("push", "pull_request", "workflow_dispatch"):
        assert must_have in keys, f"missing trigger: {must_have}"


def test_workflow_declares_minimal_permissions(workflow):
    perms = workflow.get("permissions")
    assert perms == {"contents": "read"}, (
        f"expected read-only contents permission, got {perms}"
    )


def test_workflow_has_two_jobs(workflow):
    jobs = workflow.get("jobs", {})
    assert set(jobs.keys()) == {"unit-tests", "generate-matrix"}


def test_generate_job_depends_on_unit_tests(workflow):
    needs = workflow["jobs"]["generate-matrix"].get("needs")
    # `needs` may be a string or a list — accept both.
    if isinstance(needs, str):
        assert needs == "unit-tests"
    else:
        assert "unit-tests" in needs


def test_every_job_uses_checkout_v4(workflow):
    for name, job in workflow["jobs"].items():
        uses = [s.get("uses") for s in job.get("steps", []) if s.get("uses")]
        assert any(u and "actions/checkout@v4" in u for u in uses), (
            f"job {name!r} missing actions/checkout@v4"
        )


def test_unit_tests_job_runs_pytest(workflow):
    runs = " ".join(
        s.get("run", "") for s in workflow["jobs"]["unit-tests"]["steps"]
    )
    assert "pytest" in runs


def test_generate_job_invokes_matrix_generator(workflow):
    runs = " ".join(
        s.get("run", "") for s in workflow["jobs"]["generate-matrix"]["steps"]
    )
    assert "matrix_generator.py" in runs
    assert "config.json" in runs


def test_referenced_script_exists():
    assert (REPO_ROOT / "matrix_generator.py").exists()


def test_referenced_tests_dir_exists():
    assert (REPO_ROOT / "tests").is_dir()


def test_actionlint_passes():
    """actionlint isn't shipped in the act container, so skip there;
    on the developer host it's enforced before the harness runs `act`
    anyway, so this is belt-and-suspenders coverage."""
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not on PATH in this environment")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)], capture_output=True, text=True
    )
    assert result.returncode == 0, result.stdout + result.stderr
