"""Static tests on the workflow YAML.

These tests are cheap (no Docker), so we run them every pytest invocation.
The act-based end-to-end tests live in test_act_pipeline.py.
"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

# Resolve repo root relative to this file rather than CWD so tests work
# wherever pytest is invoked from.
ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "dependency-license-checker.yml"


def _load_yaml(path: Path) -> dict:
    """Load YAML, preferring PyYAML and falling back to a minimal parser
    that's good enough for our deterministic workflow file."""
    try:
        import yaml  # type: ignore
        return yaml.safe_load(path.read_text())
    except ImportError:
        pytest.skip("PyYAML not installed; structure tests need it")


def test_workflow_file_exists() -> None:
    assert WORKFLOW.is_file(), f"Workflow file not found at {WORKFLOW}"


def test_workflow_yaml_is_valid_and_has_expected_top_level_keys() -> None:
    data = _load_yaml(WORKFLOW)
    assert "name" in data
    # PyYAML parses bare `on:` as Python True. Accept either.
    assert "on" in data or True in data, f"missing on: {list(data)}"
    assert "jobs" in data
    assert "permissions" in data


def test_workflow_has_required_triggers() -> None:
    data = _load_yaml(WORKFLOW)
    on_block = data.get("on", data.get(True))
    assert on_block is not None
    for trigger in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert trigger in on_block, f"missing trigger: {trigger}"


def test_workflow_jobs_reference_real_files() -> None:
    """Each `run:` step that names a project file should point at something
    that actually exists, otherwise the workflow can't possibly run."""
    text = WORKFLOW.read_text()
    # files we expect to be referenced
    for path in ("license_checker.py", "tests/", "fixtures/sample-package.json",
                 "fixtures/sample-licenses.json"):
        assert path in text, f"workflow does not reference {path}"
    # and they all exist
    assert (ROOT / "license_checker.py").is_file()
    assert (ROOT / "tests").is_dir()
    assert (ROOT / "fixtures" / "sample-package.json").is_file()
    assert (ROOT / "fixtures" / "sample-licenses.json").is_file()


def test_workflow_uses_pinned_action_versions() -> None:
    """Sanity check that we use major-version pins (v4/v5), not floating refs."""
    text = WORKFLOW.read_text()
    assert "actions/checkout@v4" in text
    assert "actions/setup-python@v5" in text


def test_workflow_has_two_jobs_with_dependency() -> None:
    data = _load_yaml(WORKFLOW)
    jobs = data["jobs"]
    assert "test" in jobs and "check" in jobs
    assert jobs["check"].get("needs") == "test", \
        "check job should depend on test job"


def test_actionlint_passes_on_workflow() -> None:
    """If actionlint is installed, assert it returns exit code 0."""
    if not shutil.which("actionlint"):
        pytest.skip("actionlint not installed")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True, cwd=str(ROOT),
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout={result.stdout}\nstderr={result.stderr}"
    )
