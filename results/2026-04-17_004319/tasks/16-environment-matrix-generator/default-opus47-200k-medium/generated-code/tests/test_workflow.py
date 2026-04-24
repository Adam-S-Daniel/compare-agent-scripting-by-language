"""Integration tests that run everything through GitHub Actions via `act`.

Each test case:
  1. Sets FIXTURE env var to pick a fixture file already in the repo.
  2. Runs `act push --rm` in the project directory with that env.
  3. Appends stdout+stderr to act-result.txt with a clear delimiter.
  4. Asserts exit code 0, "Job succeeded" for every job, and checks the
     exact expected matrix values in the captured output.

Budget: at most 3 `act push` runs across the whole module.
"""
from __future__ import annotations

import os
import subprocess
import sys
import yaml
from pathlib import Path

import pytest

PROJECT = Path(__file__).resolve().parent.parent
ACT_RESULT = PROJECT / "act-result.txt"
WORKFLOW = PROJECT / ".github" / "workflows" / "environment-matrix-generator.yml"


# ---------------- structural tests (fast, no act) ----------------

def test_workflow_yaml_parses_and_has_expected_structure():
    data = yaml.safe_load(WORKFLOW.read_text())
    # PyYAML parses bare `on:` as True (Python bool key) — handle both.
    triggers = data.get("on", data.get(True))
    assert triggers is not None, "workflow missing triggers"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers
    jobs = data["jobs"]
    assert "unit-tests" in jobs
    assert "generate" in jobs
    # job dependency wired up
    assert jobs["generate"]["needs"] == "unit-tests"
    # permissions present
    assert data["permissions"] == {"contents": "read"}


def test_workflow_references_existing_files():
    # matrix_generator.py referenced by workflow must exist.
    assert (PROJECT / "matrix_generator.py").is_file()
    assert (PROJECT / "tests" / "test_matrix_generator.py").is_file()
    for fx in ("basic", "with_include_exclude", "features"):
        assert (PROJECT / "fixtures" / f"{fx}.json").is_file()


def test_actionlint_passes():
    r = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True, cwd=PROJECT,
    )
    assert r.returncode == 0, f"actionlint failed: {r.stdout}\n{r.stderr}"


# ---------------- act integration tests ----------------

def _run_act(fixture: str) -> subprocess.CompletedProcess:
    """Run `act push --rm` with a specific fixture env var."""
    env = os.environ.copy()
    # Feed fixture via GitHub event-style env — the workflow reads $FIXTURE.
    env["FIXTURE"] = fixture
    # Create an event file so `act push` emits the desired ref; not strictly
    # required, but keeps behavior stable inside isolated runs.
    cmd = [
        "act", "push", "--rm",
        "--env", f"FIXTURE={fixture}",
    ]
    return subprocess.run(cmd, cwd=PROJECT, capture_output=True, text=True, env=env, timeout=600)


def _append_result(fixture: str, result: subprocess.CompletedProcess) -> None:
    with ACT_RESULT.open("a") as f:
        f.write(f"\n========== act run: fixture={fixture} ==========\n")
        f.write(f"exit code: {result.returncode}\n")
        f.write("----- stdout -----\n")
        f.write(result.stdout)
        f.write("\n----- stderr -----\n")
        f.write(result.stderr)
        f.write("\n========== end fixture={} ==========\n".format(fixture))


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    # Fresh file at the start of the integration run.
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.touch()
    yield


# Use parametrize but keep to <= 3 runs (per instructions).
@pytest.mark.parametrize("fixture,expected_size,must_contain", [
    ("basic", 4, ['"os"', '"ubuntu-latest"', '"macos-latest"', '"python"']),
    ("with_include_exclude", 4, ['"include"', '"exclude"', '"max-parallel": 3', '"fail-fast": false']),
    ("features", 2, ['"use_cache"', "true", "false"]),
])
def test_act_run_for_fixture(fixture, expected_size, must_contain):
    r = _run_act(fixture)
    _append_result(fixture, r)

    # Assertions
    assert r.returncode == 0, f"act exited with {r.returncode} for fixture {fixture}"
    combined = r.stdout + r.stderr
    # Every job must succeed
    assert "Job succeeded" in combined, "no 'Job succeeded' marker found"
    # Make sure both jobs ran (unit-tests and generate)
    assert combined.count("Job succeeded") >= 2, (
        f"expected >= 2 'Job succeeded' entries, got {combined.count('Job succeeded')}"
    )
    # Exact expected size
    assert f'"size": {expected_size}' in combined, (
        f"expected size={expected_size} in output for fixture {fixture}"
    )
    for token in must_contain:
        assert token in combined, f"missing token {token!r} in output for fixture {fixture}"
