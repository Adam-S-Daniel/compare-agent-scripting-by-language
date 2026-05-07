"""Pipeline-level tests: run the GitHub Actions workflow under `act`.

This is the *required* test harness — every case runs end-to-end through
the workflow rather than calling the script directly. Each case spins up
a temp directory, copies project files in, initializes git, and invokes
`act push --rm`, then asserts on exit code, "Job succeeded" markers, and
expected exact values parsed from the captured output.

Output is appended to ./act-result.txt (relative to project root).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml


PROJECT = Path(__file__).parent.resolve()
RESULT_FILE = PROJECT / "act-result.txt"

# Files needed inside the per-case temp git repo.
PROJECT_FILES = [
    "cleanup.py",
    "test_cleanup.py",
    ".github",
    "fixtures",
    ".actrc",
]


# ---------- Workflow structure tests ------------------------------------

WORKFLOW_PATH = PROJECT / ".github" / "workflows" / "artifact-cleanup-script.yml"


def test_workflow_file_exists():
    assert WORKFLOW_PATH.exists(), f"Missing {WORKFLOW_PATH}"


def test_workflow_passes_actionlint():
    rc = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True, text=True,
    )
    assert rc.returncode == 0, f"actionlint failed:\n{rc.stdout}\n{rc.stderr}"


def test_workflow_yaml_structure():
    data = yaml.safe_load(WORKFLOW_PATH.read_text())
    # `on` becomes True under YAML 1.1 boolean coercion, so check both.
    triggers = data.get("on") or data.get(True)
    assert triggers is not None
    for t in ("push", "pull_request", "schedule", "workflow_dispatch"):
        assert t in triggers, f"missing trigger: {t}"

    jobs = data["jobs"]
    assert "unit-tests" in jobs and "cleanup-plan" in jobs
    assert jobs["cleanup-plan"]["needs"] == "unit-tests"

    # Verify the cleanup-plan job actually invokes our script.
    steps = jobs["cleanup-plan"]["steps"]
    runs = " ".join(s.get("run", "") for s in steps)
    assert "cleanup.py" in runs

    # Referenced script files must exist on disk.
    assert (PROJECT / "cleanup.py").exists()
    assert (PROJECT / "fixtures" / "artifacts.json").exists()


# ---------- act-driven test cases ---------------------------------------

# Each case: (id, --var overrides, list of expected exact substrings).
# Computed expectations:
#
# default-fixture (5 artifacts, max-age 30, keep-latest 2, now=2026-05-07T12:00:00Z):
#   age cutoff 2026-04-07 -> deletes build-old, build-mid, ancient-debug.
#   keep-latest=2 in run-1 (build-new, build-mid, build-old) only adds
#   build-old which is already deleted. Total reclaimed:
#   1048576 + 2097152 + 131072 = 3276800. Retained: 2.
#
# only-recent (2 artifacts, max-age 10000): nothing to delete.
#
# size-budget (2 x 500 bytes, max-total 600): delete oldest (big-old).
ACT_CASES = [
    (
        "default-fixture",
        {
            "ARTIFACT_FIXTURE": "fixtures/artifacts.json",
            "MAX_AGE_DAYS": "30",
            "KEEP_LATEST": "2",
            "MAX_TOTAL_BYTES": "1000000000",
            "NOW_OVERRIDE": "2026-05-07T12:00:00Z",
        },
        [
            "Deleted: 3",
            "Retained: 2",
            "Reclaimed: 3276800 bytes",
            "build-old",
            "ancient-debug",
        ],
    ),
    (
        "only-recent",
        {
            "ARTIFACT_FIXTURE": "fixtures/only-recent.json",
            "MAX_AGE_DAYS": "10000",
            "KEEP_LATEST": "10",
            "MAX_TOTAL_BYTES": "999999999",
            "NOW_OVERRIDE": "2026-05-07T12:00:00Z",
        },
        [
            "Deleted: 0",
            "Retained: 2",
            "Reclaimed: 0 bytes",
        ],
    ),
    (
        "size-budget",
        {
            "ARTIFACT_FIXTURE": "fixtures/size-budget.json",
            "MAX_AGE_DAYS": "10000",
            "KEEP_LATEST": "10",
            "MAX_TOTAL_BYTES": "600",
            "NOW_OVERRIDE": "2026-05-07T12:00:00Z",
        },
        [
            "Deleted: 1",
            "Retained: 1",
            "Reclaimed: 500 bytes",
            "big-old",
        ],
    ),
]


def _setup_temp_repo(tmp_path: Path) -> Path:
    """Create a fresh git repo in tmp_path containing the project files."""
    for entry in PROJECT_FILES:
        src = PROJECT / entry
        dst = tmp_path / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    subprocess.run(
        ["git", "init", "-q", "-b", "main"], cwd=tmp_path, check=True
    )
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t",
         "add", "-A"], cwd=tmp_path, check=True
    )
    subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t",
         "commit", "-q", "-m", "init"], cwd=tmp_path, check=True
    )
    return tmp_path


def _run_act(repo: Path, vars_: dict[str, str]) -> subprocess.CompletedProcess:
    cmd = ["act", "push", "--rm", "--pull=false"]
    for k, v in vars_.items():
        cmd += ["--var", f"{k}={v}"]
    return subprocess.run(cmd, cwd=repo, capture_output=True, text=True)


# Truncate result file once per test session.
@pytest.fixture(scope="session", autouse=True)
def _reset_result_file():
    if RESULT_FILE.exists():
        RESULT_FILE.unlink()
    yield


@pytest.mark.parametrize("case_id,vars_,expected", ACT_CASES,
                         ids=[c[0] for c in ACT_CASES])
def test_act_case(tmp_path, case_id, vars_, expected):
    if shutil.which("act") is None or shutil.which("docker") is None:
        pytest.skip("act/docker not available")

    repo = _setup_temp_repo(tmp_path)
    proc = _run_act(repo, vars_)

    delim = f"\n\n========== CASE: {case_id} (rc={proc.returncode}) ==========\n"
    with RESULT_FILE.open("a") as f:
        f.write(delim)
        f.write("VARS: " + repr(vars_) + "\n")
        f.write("--- STDOUT ---\n")
        f.write(proc.stdout)
        f.write("\n--- STDERR ---\n")
        f.write(proc.stderr)

    combined = proc.stdout + proc.stderr
    assert proc.returncode == 0, f"[{case_id}] act exited {proc.returncode}"
    # "Job succeeded" should appear for both jobs.
    assert combined.count("Job succeeded") >= 2, \
        f"[{case_id}] expected >=2 'Job succeeded' lines"
    for needle in expected:
        assert needle in combined, f"[{case_id}] missing expected: {needle!r}"
