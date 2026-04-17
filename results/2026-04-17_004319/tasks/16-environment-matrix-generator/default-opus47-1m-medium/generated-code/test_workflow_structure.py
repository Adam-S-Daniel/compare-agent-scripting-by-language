"""Workflow structure tests: YAML shape, referenced files exist, actionlint clean."""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent
WORKFLOW = ROOT / ".github/workflows/environment-matrix-generator.yml"


def _load():
    try:
        import yaml
    except ImportError:
        pytest.skip("PyYAML not installed")
    with WORKFLOW.open() as f:
        return yaml.safe_load(f)


def test_workflow_file_exists():
    assert WORKFLOW.is_file()


def test_has_expected_triggers():
    wf = _load()
    # PyYAML parses bare `on` as boolean True in YAML 1.1 mode; accept either.
    triggers = wf.get("on") if "on" in wf else wf.get(True)
    assert triggers is not None, "workflow has no triggers"
    assert set(triggers.keys()) >= {"push", "pull_request", "workflow_dispatch", "schedule"}


def test_has_expected_jobs():
    wf = _load()
    assert set(wf["jobs"].keys()) == {"unit-tests", "generate-matrix"}


def test_generate_depends_on_unit_tests():
    wf = _load()
    needs = wf["jobs"]["generate-matrix"].get("needs")
    assert needs == "unit-tests" or needs == ["unit-tests"]


def test_workflow_references_existing_files():
    # The workflow runs matrix_generator.py and test_matrix_generator.py.
    assert (ROOT / "matrix_generator.py").is_file()
    assert (ROOT / "test_matrix_generator.py").is_file()
    # And reads fixtures/<file>.
    assert (ROOT / "fixtures").is_dir()
    assert (ROOT / "fixtures" / "basic.json").is_file()


def test_actionlint_passes():
    actionlint = shutil.which("actionlint")
    if actionlint is None:
        pytest.skip("actionlint not on PATH")
    proc = subprocess.run(
        [actionlint, str(WORKFLOW)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
