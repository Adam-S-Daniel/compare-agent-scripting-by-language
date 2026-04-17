"""Workflow tests.

Two sets of tests:
  1. Static structure checks on the YAML file (fast, local).
  2. End-to-end tests that drive the workflow through `act` (requires Docker).

Per the task rules, each fixture case is exercised through `act push`, its
output is appended to `act-result.txt`, and we assert on EXACT expected values
parsed from the aggregator's machine-readable output line.

The act runs are conditional on `RUN_ACT=1` so unit tests remain fast by default,
but the harness script (`run_act_tests.sh`) sets that variable.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "test-results-aggregator.yml"
FIXTURES_ROOT = PROJECT_ROOT / "fixtures"
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"

# Expected values for each fixture case — must match the fixture content exactly.
# These are asserted against the AGGREGATOR_RESULT line printed by aggregator.py.
EXPECTED = {
    "all-green":     {"total": 4, "passed": 4, "failed": 0, "skipped": 0, "flaky": 0, "duration": 0.70},
    "has-failures":  {"total": 3, "passed": 1, "failed": 1, "skipped": 1, "flaky": 0, "duration": 0.12},
    "flaky-matrix":  {"total": 6, "passed": 3, "failed": 3, "skipped": 0, "flaky": 1, "duration": 0.94},
}


# ---------------------------------------------------------------------------
# Static structure tests
# ---------------------------------------------------------------------------
def test_workflow_file_exists():
    assert WORKFLOW_PATH.exists(), f"missing workflow: {WORKFLOW_PATH}"


def test_workflow_valid_yaml():
    # yaml.safe_load raises on malformed YAML.
    doc = yaml.safe_load(WORKFLOW_PATH.read_text())
    assert isinstance(doc, dict)


def test_workflow_has_expected_triggers():
    doc = yaml.safe_load(WORKFLOW_PATH.read_text())
    # `on:` is parsed as True (YAML bool) by PyYAML since it's a reserved word,
    # so check both keys.
    triggers = doc.get("on") or doc.get(True)
    assert triggers is not None
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers


def test_workflow_defines_required_jobs():
    doc = yaml.safe_load(WORKFLOW_PATH.read_text())
    jobs = doc["jobs"]
    assert "unit-tests" in jobs
    assert "aggregate" in jobs
    # aggregate should depend on unit-tests to enforce ordering.
    assert jobs["aggregate"].get("needs") == "unit-tests"


def test_workflow_checks_out_repo_and_runs_aggregator():
    doc = yaml.safe_load(WORKFLOW_PATH.read_text())
    steps = doc["jobs"]["aggregate"]["steps"]
    uses_values = [s.get("uses", "") for s in steps]
    assert any(u.startswith("actions/checkout@") for u in uses_values)
    run_bodies = " \n".join(s.get("run", "") for s in steps)
    assert "aggregator.py" in run_bodies


def test_workflow_references_existing_script():
    # The workflow invokes `aggregator.py` — that file must exist in the repo.
    assert (PROJECT_ROOT / "aggregator.py").exists()
    assert (PROJECT_ROOT / "tests").is_dir()


def test_actionlint_passes():
    exe = shutil.which("actionlint")
    if exe is None:
        pytest.skip("actionlint not installed")
    result = subprocess.run([exe, str(WORKFLOW_PATH)], capture_output=True, text=True)
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout={result.stdout}\nstderr={result.stderr}"
    )


# ---------------------------------------------------------------------------
# End-to-end tests via `act`
# ---------------------------------------------------------------------------
ACT_ENABLED = os.environ.get("RUN_ACT") == "1"


def _parse_aggregator_result(log: str) -> dict[str, float]:
    """Extract the AGGREGATOR_RESULT marker line and parse its key=value pairs."""
    match = re.search(r"AGGREGATOR_RESULT\s+(.+)", log)
    assert match, f"AGGREGATOR_RESULT marker not found in act output:\n{log[:2000]}"
    result = {}
    for kv in match.group(1).strip().split():
        key, value = kv.split("=", 1)
        result[key] = float(value) if "." in value else int(value)
    return result


def _run_act_for_fixture(tmpdir: Path, case: str) -> subprocess.CompletedProcess:
    """Copy the project into a temp git repo, drop the fixture into test-results/,
    then run `act push --rm`. Returns the completed process with captured output."""
    repo_dir = tmpdir / f"repo-{case}"
    repo_dir.mkdir(parents=True)

    # Copy project files into the throwaway repo. Only what we need for the
    # workflow, not the old .git dir or act-result.txt.
    for name in ("aggregator.py", ".github", ".actrc", "tests"):
        src = PROJECT_ROOT / name
        dst = repo_dir / name
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Place fixture files into the workflow-expected location.
    results_dir = repo_dir / "test-results"
    results_dir.mkdir()
    for src in (FIXTURES_ROOT / case).iterdir():
        shutil.copy2(src, results_dir / src.name)

    # Initialize a fresh git repo so `act push` has something to work with.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo_dir, check=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=repo_dir, check=True)
    subprocess.run(["git", "config", "user.name", "test"], cwd=repo_dir, check=True)
    subprocess.run(["git", "add", "-A"], cwd=repo_dir, check=True)
    subprocess.run(["git", "commit", "-q", "-m", f"setup {case}"], cwd=repo_dir, check=True)

    proc = subprocess.run(
        ["act", "push", "--rm"],
        cwd=repo_dir, capture_output=True, text=True, timeout=600,
    )
    return proc


@pytest.mark.skipif(not ACT_ENABLED, reason="Set RUN_ACT=1 to enable act-backed tests")
@pytest.mark.parametrize("case", sorted(EXPECTED.keys()))
def test_act_run_matches_expected(tmp_path: Path, case: str):
    """For each fixture case, run the workflow under `act` and assert on exact
    expected values from the AGGREGATOR_RESULT marker line."""
    proc = _run_act_for_fixture(tmp_path, case)

    combined = proc.stdout + "\n" + proc.stderr

    # Append to act-result.txt with a clear delimiter.
    with ACT_RESULT_FILE.open("a", encoding="utf-8") as fh:
        fh.write(f"\n\n===== CASE: {case} (exit={proc.returncode}) =====\n")
        fh.write(combined)
        fh.write(f"\n===== END CASE: {case} =====\n")

    assert proc.returncode == 0, (
        f"act exited {proc.returncode} for case {case}.\n"
        f"Last 2000 chars of output:\n{combined[-2000:]}"
    )

    # Both jobs must report success.
    # act marks a passing job with "Job succeeded".
    assert combined.count("Job succeeded") >= 2, (
        f"Expected both jobs to succeed in case {case}. "
        f"Output tail:\n{combined[-2000:]}"
    )

    parsed = _parse_aggregator_result(combined)
    expected = EXPECTED[case]
    for key in ("total", "passed", "failed", "skipped", "flaky"):
        assert parsed[key] == expected[key], (
            f"case={case} key={key} got={parsed[key]} expected={expected[key]}"
        )
    # Duration is a float; allow a small tolerance because float addition order
    # in the aggregator may nudge the last digit.
    assert abs(parsed["duration"] - expected["duration"]) < 0.01, (
        f"case={case} duration got={parsed['duration']} expected={expected['duration']}"
    )


@pytest.mark.skipif(not ACT_ENABLED, reason="Set RUN_ACT=1 to enable act-backed tests")
def test_act_result_file_produced():
    """After the act-backed tests run, the act-result.txt artifact must exist."""
    assert ACT_RESULT_FILE.exists()
    content = ACT_RESULT_FILE.read_text()
    for case in EXPECTED:
        assert f"CASE: {case}" in content


if __name__ == "__main__":
    # Convenience: `python3 tests/test_workflow.py` runs the act suite.
    os.environ["RUN_ACT"] = "1"
    sys.exit(pytest.main([__file__, "-v", "-s"]))
