"""Workflow structure + act integration tests.

These tests satisfy the benchmark's "all tests run through act" requirement:
- Validate YAML structure + script references.
- Run actionlint (must exit 0).
- For each test case, set up an isolated git repo with the project + that case's
  fixture data, run `act push --rm`, and assert on EXACT expected output values.
- Append every act run's output (clearly delimited) to ../act-result.txt.

The harness caps itself at 2 `act push` runs to respect the "at most 3" budget.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import textwrap
from pathlib import Path

import pytest
import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = PROJECT_ROOT / ".github" / "workflows" / "test-results-aggregator.yml"
ACT_RESULT = PROJECT_ROOT / "act-result.txt"

# Files to copy into the temp repo for every act run.
PROJECT_FILES = [
    "aggregator.py",
    ".actrc",
    ".github/workflows/test-results-aggregator.yml",
    "tests/test_aggregator.py",
    "tests/fixtures/run1.xml",
    "tests/fixtures/run2.json",
    "tests/fixtures/run3.xml",
]


# ---------- workflow structure tests ----------

def test_workflow_yaml_parses_and_has_expected_structure():
    data = yaml.safe_load(WORKFLOW.read_text())
    # yaml maps the bare `on:` key to True in some versions; handle both.
    triggers = data.get("on") or data.get(True)
    assert isinstance(triggers, dict)
    for trig in ("push", "pull_request", "workflow_dispatch"):
        assert trig in triggers, f"missing trigger: {trig}"

    assert "jobs" in data
    jobs = data["jobs"]
    assert "unit-tests" in jobs and "aggregate" in jobs
    # aggregate depends on unit-tests passing
    assert jobs["aggregate"].get("needs") == "unit-tests"


def test_workflow_references_real_script_paths():
    text = WORKFLOW.read_text()
    assert "aggregator.py" in text
    assert (PROJECT_ROOT / "aggregator.py").is_file()


def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
    )


# ---------- act integration ----------

def _check_docker_available() -> bool:
    try:
        r = subprocess.run(["docker", "info"], capture_output=True, timeout=5)
        return r.returncode == 0
    except Exception:
        return False


def _copy_project(dest: Path) -> None:
    for rel in PROJECT_FILES:
        src = PROJECT_ROOT / rel
        dst = dest / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def _write_fixtures(dest: Path, fixtures: dict[str, str]) -> None:
    """Write fixture-input files. `fixtures` maps filename -> content."""
    fdir = dest / "fixtures-input"
    fdir.mkdir(parents=True, exist_ok=True)
    for name, content in fixtures.items():
        (fdir / name).write_text(content)


def _init_git_repo(path: Path) -> None:
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "act", "GIT_AUTHOR_EMAIL": "act@example.com",
        "GIT_COMMITTER_NAME": "act", "GIT_COMMITTER_EMAIL": "act@example.com",
    }
    for cmd in (
        ["git", "init", "-q", "-b", "main"],
        ["git", "add", "-A"],
        ["git", "commit", "-q", "-m", "test case"],
    ):
        subprocess.run(cmd, cwd=path, check=True, env=env, capture_output=True)


def _run_act(cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["act", "push", "--rm"],
        cwd=cwd, capture_output=True, text=True, timeout=600,
    )


def _delimited_append(header: str, proc: subprocess.CompletedProcess) -> None:
    with ACT_RESULT.open("a") as f:
        f.write(f"\n\n========== {header} ==========\n")
        f.write(f"exit_code: {proc.returncode}\n")
        f.write("----- STDOUT -----\n")
        f.write(proc.stdout)
        f.write("\n----- STDERR -----\n")
        f.write(proc.stderr)
        f.write(f"\n========== END {header} ==========\n")


# Bundled fixtures produce this known-good aggregator summary line.
BUNDLED_EXPECTED = (
    "[aggregator] runs=3 total=12 passed=6 failed=4 skipped=2 "
    "flaky=1 duration=2.50s"
)

# Single clean fixture with 2 passes, no failures.
CLEAN_JSON = """{
  "tests": [
    {"name": "clean.one", "status": "passed", "duration": 0.10},
    {"name": "clean.two", "status": "passed", "duration": 0.20}
  ]
}
"""
CLEAN_EXPECTED = (
    "[aggregator] runs=1 total=2 passed=2 failed=0 skipped=0 "
    "flaky=0 duration=0.30s"
)


CASES = [
    {
        "name": "bundled-fixtures",
        # no extra fixtures-input dir — workflow falls back to tests/fixtures
        "fixtures": {},
        "expected_line": BUNDLED_EXPECTED,
        "must_contain": ["suite.flaky_test", "suite.always_fail"],
    },
    {
        "name": "clean-only-passes",
        "fixtures": {"run1.json": CLEAN_JSON},
        "expected_line": CLEAN_EXPECTED,
        "must_contain": ["No flaky tests detected", "No failures"],
    },
]


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result():
    # Start a fresh act-result.txt for each pytest run.
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.write_text("act run log\n")
    yield


@pytest.mark.skipif(not _check_docker_available(), reason="docker not available")
@pytest.mark.parametrize("case", CASES, ids=[c["name"] for c in CASES])
def test_workflow_runs_via_act(case, tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    _copy_project(repo)
    if case["fixtures"]:
        _write_fixtures(repo, case["fixtures"])
    _init_git_repo(repo)

    proc = _run_act(repo)
    _delimited_append(case["name"], proc)

    combined = proc.stdout + proc.stderr

    assert proc.returncode == 0, (
        f"act exited {proc.returncode}\nstdout:\n{proc.stdout[-4000:]}\n"
        f"stderr:\n{proc.stderr[-4000:]}"
    )
    # "Job succeeded" must appear for each job in the workflow.
    assert combined.count("Job succeeded") >= 2, (
        f"expected both jobs to succeed, got:\n{combined[-2000:]}"
    )
    # EXACT expected aggregator summary line.
    assert case["expected_line"] in combined, (
        f"expected line not found:\n  {case['expected_line']}\n"
        f"last output:\n{combined[-2000:]}"
    )
    for frag in case["must_contain"]:
        assert frag in combined, f"expected fragment {frag!r} missing"


def test_act_result_artifact_exists_and_nonempty():
    # Runs after the parametrised act tests — ACT_RESULT should be populated.
    assert ACT_RESULT.exists(), "act-result.txt must exist"
    assert ACT_RESULT.stat().st_size > 100, "act-result.txt looks empty"
