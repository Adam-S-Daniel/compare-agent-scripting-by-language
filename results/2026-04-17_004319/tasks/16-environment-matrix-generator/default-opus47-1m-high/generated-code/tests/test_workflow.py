"""Workflow structure + act-based integration tests.

Every test case for the generator executes through the GitHub Actions workflow
via `act`. We do ONE full `act push` run (the workflow exercises all three
fixtures internally) and then parse act's captured stdout for the expected
markers. This stays within the 3-act-run budget.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None  # handled in test skip

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github" / "workflows" / "environment-matrix-generator.yml"
ACT_RESULT = ROOT / "act-result.txt"


# ----------------------------- Structure tests -------------------------------


def test_workflow_file_exists():
    assert WORKFLOW.exists(), f"workflow missing at {WORKFLOW}"


@pytest.mark.skipif(yaml is None, reason="PyYAML not installed")
def test_workflow_structure_is_valid():
    doc = yaml.safe_load(WORKFLOW.read_text())
    # PyYAML loads the YAML key `on:` as Python True because it's the unquoted
    # boolean 'on'. We accept either spelling to be robust.
    triggers = doc.get("on") or doc.get(True)
    assert triggers is not None, "workflow must declare triggers"
    for trig in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert trig in triggers, f"missing trigger: {trig}"

    jobs = doc["jobs"]
    assert "unit-tests" in jobs
    assert "generate-matrix" in jobs
    assert jobs["generate-matrix"]["needs"] == "unit-tests"

    # generate-matrix must reference each fixture file.
    gen_steps = jobs["generate-matrix"]["steps"]
    joined = "\n".join(step.get("run", "") for step in gen_steps)
    for fixture in ("fixtures/basic.json", "fixtures/with-excludes.json", "fixtures/oversized.json"):
        assert fixture in joined, f"workflow does not reference {fixture}"


def test_referenced_scripts_and_fixtures_exist():
    assert (ROOT / "matrix_gen.py").exists()
    for name in ("basic.json", "with-excludes.json", "oversized.json"):
        assert (ROOT / "fixtures" / name).exists(), f"missing fixture: {name}"


def test_actionlint_passes():
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, f"actionlint failed:\n{result.stdout}\n{result.stderr}"


# ----------------------------- Act integration -------------------------------


def _run_act_once() -> str:
    """Run `act push --rm` once; tee output to act-result.txt (append)."""
    if shutil.which("act") is None:
        pytest.skip("act not installed")
    if shutil.which("docker") is None:
        pytest.skip("docker not installed")

    # Fresh file for this session; append each test-case delimiter below.
    ACT_RESULT.write_text("")

    # --pull=false prevents act from trying to re-pull the local-only
    # act-ubuntu-pwsh image configured in .actrc.
    cmd = ["act", "push", "--rm", "--pull=false", "-W", str(WORKFLOW)]
    proc = subprocess.run(
        cmd,
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        check=False,
        timeout=900,
    )
    combined = (
        f"===== act push (workflow) =====\n"
        f"$ {' '.join(cmd)}\n"
        f"--- stdout ---\n{proc.stdout}\n"
        f"--- stderr ---\n{proc.stderr}\n"
        f"--- exit code: {proc.returncode} ---\n"
    )
    with ACT_RESULT.open("a") as f:
        f.write(combined)

    assert proc.returncode == 0, (
        f"act push failed with exit code {proc.returncode}.\n"
        f"See {ACT_RESULT} for full output."
    )
    return proc.stdout + "\n" + proc.stderr


@pytest.fixture(scope="module")
def act_output() -> str:
    # Opt-out to allow fast local iteration on structure tests only.
    if os.environ.get("SKIP_ACT") == "1":
        pytest.skip("SKIP_ACT=1")
    return _run_act_once()


def _split_case(full: str, marker: str, header: str) -> str:
    """Append a clearly-delimited slice of act output to act-result.txt."""
    block = f"\n===== CASE: {header} =====\n"
    # Include enough context to be useful when reviewing act-result.txt.
    lines = full.splitlines()
    idxs = [i for i, l in enumerate(lines) if marker in l]
    window = []
    for i in idxs:
        start = max(0, i - 2)
        end = min(len(lines), i + 15)
        window.extend(lines[start:end])
    block += "\n".join(window) + "\n"
    with ACT_RESULT.open("a") as f:
        f.write(block)
    return "\n".join(window)


# --- Per-fixture assertions (each is its own test case) ----------------------


def test_act_unit_tests_job_succeeded(act_output):
    # Every job must report success.
    assert "Job succeeded" in act_output
    # Specifically, the pytest job must have ran.
    assert "Unit tests (pytest)" in act_output or "unit-tests" in act_output


def test_act_basic_fixture_exact_output(act_output):
    _split_case(act_output, "MATRIX_BASIC=", "basic.json")
    # The matrix JSON is emitted with compact separators.
    expected = (
        '{"include":[{"os":"ubuntu-latest","python":"3.11"},'
        '{"os":"ubuntu-latest","python":"3.12"},'
        '{"os":"macos-latest","python":"3.11"},'
        '{"os":"macos-latest","python":"3.12"}],'
        '"fail-fast":true,"max-parallel":4}'
    )
    assert f"MATRIX_BASIC={expected}" in act_output
    assert "basic_count=4" in act_output


def test_act_with_excludes_fixture_exact_output(act_output):
    _split_case(act_output, "MATRIX_EXCLUDES=", "with-excludes.json")
    # 12 total combos - 4 excluded = 8. Include rule augments one combo.
    # Order follows itertools.product(os, python, flag).
    expected = (
        '{"include":['
        '{"os":"ubuntu-latest","python":"3.11","flag":"default"},'
        '{"os":"ubuntu-latest","python":"3.11","flag":"experimental"},'
        '{"os":"ubuntu-latest","python":"3.12","flag":"default","coverage":true},'
        '{"os":"ubuntu-latest","python":"3.12","flag":"experimental"},'
        '{"os":"macos-latest","python":"3.12","flag":"default"},'
        '{"os":"macos-latest","python":"3.12","flag":"experimental"},'
        '{"os":"windows-latest","python":"3.11","flag":"default"},'
        '{"os":"windows-latest","python":"3.12","flag":"default"}'
        '],"fail-fast":false,"max-parallel":3}'
    )
    assert f"MATRIX_EXCLUDES={expected}" in act_output
    assert "excl_count=8" in act_output


def test_act_oversized_fixture_fails_cleanly(act_output):
    _split_case(act_output, "OVERSIZED_", "oversized.json")
    # Script must exit non-zero and emit the specific max-size error.
    assert "OVERSIZED_RC=1" in act_output
    assert "exceeds max-size 10" in act_output
    assert "48 combinations" in act_output


def test_act_all_jobs_succeeded(act_output):
    # Two jobs: unit-tests and generate-matrix.
    assert act_output.count("Job succeeded") >= 2, (
        "Expected at least 2 'Job succeeded' markers, one per job"
    )


def test_act_result_artifact_exists():
    assert ACT_RESULT.exists()
    assert ACT_RESULT.stat().st_size > 0
