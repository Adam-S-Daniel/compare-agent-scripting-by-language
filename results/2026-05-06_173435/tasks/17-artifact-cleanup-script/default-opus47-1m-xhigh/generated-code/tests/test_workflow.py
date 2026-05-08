"""Static structural tests for the GitHub Actions workflow file.

These tests don't run act; they verify shape and references so that bugs in
the YAML are caught instantly without paying the 30-90s act cost.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

WORKFLOW_PATH = Path(__file__).resolve().parent.parent / ".github" / "workflows" / "artifact-cleanup-script.yml"
PROJECT_ROOT = Path(__file__).resolve().parent.parent


def _load_yaml() -> dict:
    # PyYAML is the standard but might not be installed; fall back to ruamel
    # or fail with a useful message. For this codebase pyyaml is fine.
    try:
        import yaml  # type: ignore[import-not-found]
    except ImportError:  # pragma: no cover - environmental
        pytest.skip("PyYAML not installed; install pyyaml to run workflow tests")
    return yaml.safe_load(WORKFLOW_PATH.read_text())


def test_workflow_file_exists():
    assert WORKFLOW_PATH.is_file(), f"workflow not found at {WORKFLOW_PATH}"


def test_workflow_has_expected_triggers():
    wf = _load_yaml()
    # PyYAML parses `on:` as the boolean True if unquoted in some versions —
    # tolerate both keys.
    on = wf.get("on") or wf.get(True)
    assert on is not None, "workflow has no 'on' trigger block"
    assert "push" in on
    assert "pull_request" in on
    assert "workflow_dispatch" in on
    assert "schedule" in on


def test_workflow_has_required_jobs():
    wf = _load_yaml()
    jobs = wf["jobs"]
    assert "unit-tests" in jobs
    assert "cleanup-plan" in jobs
    # Cleanup job must depend on unit tests so a failing test blocks the plan.
    assert jobs["cleanup-plan"].get("needs") == "unit-tests"


def test_workflow_uses_checkout():
    """Every job must check out the repository so it can see cleanup.py and
    the fixtures. We rely on the runner image's pre-installed Python rather
    than actions/setup-python, since act's custom image already provides it."""
    wf = _load_yaml()
    for name, job in wf["jobs"].items():
        used = [s.get("uses", "").split("@")[0] for s in job["steps"]]
        assert "actions/checkout" in used, f"job {name} missing checkout"


def test_workflow_references_existing_script():
    """The workflow runs `python3 cleanup.py ...`; cleanup.py must exist."""
    assert (PROJECT_ROOT / "cleanup.py").is_file()
    assert (PROJECT_ROOT / "tests").is_dir()
    # The workflow reads from fixtures/active/ — at least the placeholder
    # directory should exist so the path is meaningful.
    assert (PROJECT_ROOT / "fixtures").is_dir()


def test_workflow_has_minimal_permissions():
    wf = _load_yaml()
    perms = wf.get("permissions")
    assert perms is not None, "workflow should declare top-level permissions"
    assert perms.get("contents") == "read"


def test_actionlint_passes():
    """actionlint should accept the workflow without errors."""
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    proc = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, (
        f"actionlint failed (exit {proc.returncode}):\n"
        f"stdout: {proc.stdout}\n"
        f"stderr: {proc.stderr}"
    )
