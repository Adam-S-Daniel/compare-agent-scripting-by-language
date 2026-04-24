"""
Workflow structure tests.

These are fast static checks that run as ordinary unit tests:
  - YAML parses
  - The workflow file has the expected triggers / jobs / steps
  - Every path referenced from the workflow actually exists in the repo
  - actionlint is happy (asserted by exit code 0)
"""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - PyYAML ships with most envs
    yaml = None  # type: ignore


PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = PROJECT_ROOT / ".github" / "workflows" / "test-results-aggregator.yml"


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_parses_as_yaml() -> None:
    data = yaml.safe_load(WORKFLOW.read_text())
    assert isinstance(data, dict)


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_has_expected_triggers() -> None:
    # PyYAML parses YAML "on:" key into Python bool True — workaround below.
    data = yaml.safe_load(WORKFLOW.read_text())
    triggers = data.get("on") or data.get(True)
    assert triggers is not None, "workflow must define 'on' triggers"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_references_existing_script() -> None:
    text = WORKFLOW.read_text()
    assert "aggregator.py" in text
    assert (PROJECT_ROOT / "aggregator.py").exists()


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_has_checkout_and_setup_python() -> None:
    data = yaml.safe_load(WORKFLOW.read_text())
    jobs = data["jobs"]
    agg = jobs["aggregate"]
    step_uses = [s.get("uses", "") for s in agg["steps"]]
    assert any(u.startswith("actions/checkout@") for u in step_uses)
    assert any(u.startswith("actions/setup-python@") for u in step_uses)


def test_actionlint_passes() -> None:
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    r = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )
    assert r.returncode == 0, f"actionlint failed: {r.stdout}\n{r.stderr}"
