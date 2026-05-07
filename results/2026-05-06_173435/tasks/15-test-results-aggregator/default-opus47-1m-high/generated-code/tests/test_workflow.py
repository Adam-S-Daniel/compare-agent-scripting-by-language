"""End-to-end tests that drive the script through GitHub Actions via `act`.

The harness, for each test case:

  1. Creates a temp git repo containing the project files plus that case's
     fixture data (different test cases supply different fixture sets so we
     can assert on different aggregator results).
  2. Runs `act push --rm`, capturing combined stdout+stderr.
  3. Appends the captured output to `act-result.txt` in the project dir,
     delimited by clear case headers.
  4. Asserts act exit code 0, "Job succeeded" appears for every job, and
     the aggregator's output matches the exact expected status line for
     that case's input.

We also run a structural sanity test on the workflow YAML and an
actionlint pass — both are instant, while each `act push` takes ~30-90s.
The total number of `act push` runs is capped at 3.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Iterable

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "test-results-aggregator.yml"
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"

# Files copied into every test repo (everything the workflow + script needs).
PROJECT_FILES = [
    "aggregator.py",
    "conftest.py",
    "pytest.ini",
    "tests/__init__.py",
    "tests/test_aggregator.py",
    ".actrc",
]


# ---------------------------------------------------------------------------
# Workflow structure tests (instant)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def workflow_yaml() -> dict:
    return yaml.safe_load(WORKFLOW_PATH.read_text())


def test_workflow_file_exists() -> None:
    assert WORKFLOW_PATH.exists(), f"workflow file missing: {WORKFLOW_PATH}"


def test_workflow_has_expected_triggers(workflow_yaml: dict) -> None:
    # PyYAML parses the `on:` key as bool True (because "on" is a YAML 1.1
    # boolean). Accept either form.
    triggers = workflow_yaml.get("on") or workflow_yaml.get(True)
    assert triggers is not None, "workflow has no triggers"
    assert "push" in triggers
    assert "pull_request" in triggers
    assert "workflow_dispatch" in triggers
    assert "schedule" in triggers


def test_workflow_has_required_jobs(workflow_yaml: dict) -> None:
    jobs = workflow_yaml["jobs"]
    assert "unit-tests" in jobs
    assert "aggregate" in jobs
    # aggregate depends on unit-tests passing first.
    assert jobs["aggregate"].get("needs") == "unit-tests"


def test_workflow_references_existing_files(workflow_yaml: dict) -> None:
    """The workflow's `run:` lines must point at files that actually exist."""
    referenced = ["aggregator.py", "tests/"]
    for rel in referenced:
        assert (PROJECT_ROOT / rel).exists(), f"missing referenced path: {rel}"


def test_workflow_uses_pinned_actions(workflow_yaml: dict) -> None:
    """All `uses:` references should specify a version (no floating @main)."""
    for job in workflow_yaml["jobs"].values():
        for step in job["steps"]:
            uses = step.get("uses")
            if uses:
                assert "@" in uses, f"unpinned action: {uses}"


def test_actionlint_passes() -> None:
    """actionlint must accept the workflow with no errors (instant check)."""
    if shutil.which("actionlint") is None:
        pytest.skip("actionlint not installed")
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    )


# ---------------------------------------------------------------------------
# Act-driven end-to-end tests
# ---------------------------------------------------------------------------

def _have_act_and_docker() -> bool:
    if shutil.which("act") is None or shutil.which("docker") is None:
        return False
    # Confirm dockerd is reachable; act will hang otherwise.
    info = subprocess.run(["docker", "info"], capture_output=True)
    return info.returncode == 0


requires_act = pytest.mark.skipif(
    not _have_act_and_docker(),
    reason="requires act + a running docker daemon",
)


def _materialize_repo(target: Path, fixtures: dict[str, str]) -> None:
    """Build a fresh git repo at `target` with our project files + fixtures.

    `fixtures` maps relative path under `fixtures/` to file *contents*.
    """
    target.mkdir(parents=True, exist_ok=True)

    # Copy project files (preserving relative paths).
    for rel in PROJECT_FILES:
        src = PROJECT_ROOT / rel
        dst = target / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Copy the workflow file.
    wf_dst = target / ".github" / "workflows" / "test-results-aggregator.yml"
    wf_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(WORKFLOW_PATH, wf_dst)

    # Write fixtures.
    fixture_dir = target / "fixtures"
    fixture_dir.mkdir(exist_ok=True)
    for rel, content in fixtures.items():
        (fixture_dir / rel).write_text(content)

    # Initialize a git repo (act needs one to compute event metadata).
    env = {**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "t@t"}
    for cmd in (
        ["git", "init", "-q", "-b", "main"],
        ["git", "add", "-A"],
        ["git", "commit", "-q", "-m", "fixture commit"],
    ):
        subprocess.run(cmd, cwd=target, check=True, env=env,
                       capture_output=True)


def _run_act(repo: Path) -> subprocess.CompletedProcess:
    """Run `act push --rm` in `repo` and return the completed process."""
    return subprocess.run(
        ["act", "push", "--rm"],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=600,
    )


def _append_act_log(case_name: str, proc: subprocess.CompletedProcess) -> None:
    """Append the act run's output to act-result.txt with a clear delimiter."""
    delim = "=" * 78
    block = (
        f"\n{delim}\nCASE: {case_name}\n"
        f"exit_code: {proc.returncode}\n"
        f"{delim}\n"
        f"--- STDOUT ---\n{proc.stdout}\n"
        f"--- STDERR ---\n{proc.stderr}\n"
    )
    with ACT_RESULT_FILE.open("a") as fh:
        fh.write(block)


def _assert_jobs_succeeded(stdout: str, jobs: Iterable[str]) -> None:
    """act prints e.g. `[Test Results Aggregator/Unit tests] 🏁  Job succeeded`."""
    for job in jobs:
        prefix = f"[Test Results Aggregator/{job}]"
        # Look for any line that has both the job's bracket prefix and
        # "Job succeeded". (act puts an emoji + spaces between them.)
        success = any(
            prefix in line and "Job succeeded" in line
            for line in stdout.splitlines()
        )
        assert success, (
            f"expected job '{job}' to report success.\n"
            f"Looking for line containing both {prefix!r} and 'Job succeeded'."
        )
        # And there must be NO failure marker for this job.
        for line in stdout.splitlines():
            if prefix in line and "Job failed" in line:
                raise AssertionError(f"job '{job}' reported failure: {line}")


# Fixture sets for our 3 act-driven cases.

_CLEAN_JSON = textwrap.dedent("""\
    {
      "tests": [
        {"classname": "s", "name": "t1", "status": "passed", "duration": 0.1},
        {"classname": "s", "name": "t2", "status": "passed", "duration": 0.2},
        {"classname": "s", "name": "t3", "status": "passed", "duration": 0.3}
      ]
    }
""")

_LINUX_XML = (PROJECT_ROOT / "fixtures" / "run-linux.xml").read_text()
_MACOS_XML = (PROJECT_ROOT / "fixtures" / "run-macos.xml").read_text()
_WINDOWS_JSON = (PROJECT_ROOT / "fixtures" / "run-windows.json").read_text()

_INVALID_XML = "<this is not> valid xml"


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result_file() -> None:
    # Truncate before the test session so we only capture this run's output.
    ACT_RESULT_FILE.write_text("")


@requires_act
def test_act_case_all_pass(tmp_path: Path) -> None:
    """Single JSON file, all 3 tests pass — workflow exits 0, no flaky."""
    repo = tmp_path / "all-pass"
    _materialize_repo(repo, {"clean.json": _CLEAN_JSON})
    proc = _run_act(repo)
    _append_act_log("all-pass", proc)

    assert proc.returncode == 0, "act should exit 0"
    _assert_jobs_succeeded(proc.stdout, ["Unit tests", "Aggregate test results"])

    # Exact aggregator status line for this input.
    expected = "AGGREGATOR_STATUS total=3 passed=3 failed=0 skipped=0 flaky=0"
    assert expected in proc.stdout, (
        f"expected aggregator status line not found.\n"
        f"expected: {expected}\nstdout tail: {proc.stdout[-2000:]}"
    )
    # The aggregator returned 0 (all green).
    assert "AGGREGATOR_EXIT=0" in proc.stdout
    # Markdown summary mentions PASSED.
    assert "PASSED" in proc.stdout


@requires_act
def test_act_case_mixed_with_flaky(tmp_path: Path) -> None:
    """Three matrix runs (Linux XML, macOS XML, Windows JSON)."""
    repo = tmp_path / "mixed-flaky"
    _materialize_repo(repo, {
        "run-linux.xml": _LINUX_XML,
        "run-macos.xml": _MACOS_XML,
        "run-windows.json": _WINDOWS_JSON,
    })
    proc = _run_act(repo)
    _append_act_log("mixed-with-flaky", proc)

    assert proc.returncode == 0, "act should exit 0 even when fixtures fail"
    _assert_jobs_succeeded(proc.stdout, ["Unit tests", "Aggregate test results"])

    # Computed totals across the 3 fixtures (8 cases each = 24 total):
    #   linux:  passed=6 failed=1 skipped=1
    #   macos:  passed=6 failed=2 skipped=0
    #   win:    passed=7 failed=1 skipped=0
    #   ----------------------------------
    #   sum:    passed=19 failed=4 skipped=1   total=24
    # Flaky: test_admin_promote (failed on macOS, passed on Windows;
    #        skipped on Linux — skipped runs don't count toward flakiness).
    expected = "AGGREGATOR_STATUS total=24 passed=19 failed=4 skipped=1 flaky=1"
    assert expected in proc.stdout, (
        f"expected aggregator status line not found.\n"
        f"expected: {expected}\nstdout tail: {proc.stdout[-3000:]}"
    )
    # Aggregator returns 1 because there are failures, but workflow still 0.
    assert "AGGREGATOR_EXIT=1" in proc.stdout
    assert "FAILED" in proc.stdout


@requires_act
def test_act_case_invalid_input_handled_gracefully(tmp_path: Path) -> None:
    """Malformed XML — script exits 2, but workflow still succeeds."""
    repo = tmp_path / "invalid"
    _materialize_repo(repo, {"broken.xml": _INVALID_XML})
    proc = _run_act(repo)
    _append_act_log("invalid-input", proc)

    assert proc.returncode == 0, "workflow should still succeed (continue-on-error)"
    _assert_jobs_succeeded(proc.stdout, ["Unit tests", "Aggregate test results"])

    # Aggregator should have reported a parse error and exited 2.
    assert "AGGREGATOR_EXIT=2" in proc.stdout
    assert "Failed to parse JUnit XML" in proc.stdout


if __name__ == "__main__":  # pragma: no cover
    sys.exit(pytest.main([__file__, "-v"]))
