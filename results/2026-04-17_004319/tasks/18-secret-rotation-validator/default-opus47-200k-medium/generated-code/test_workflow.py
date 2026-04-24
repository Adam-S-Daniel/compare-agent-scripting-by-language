"""Test harness that runs the entire GitHub Actions workflow through `act`.

For each test case we:
  1. Stage the project files + the case's fixture into a fresh temp git repo.
  2. Invoke `act push --rm --var TODAY=<pinned-date>` in that repo.
  3. Capture act's stdout/stderr, append to act-result.txt (required artifact).
  4. Assert exit code 0, every job shows "Job succeeded", and exact expected
     values appear in the rendered report output (not just "some output").

We also validate the workflow's static structure and run actionlint.

Cost control: `act` is expensive (~30-90s/run). Three test cases == three
`act` invocations, which is the hard cap stated in the task instructions.
"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml


HERE = Path(__file__).resolve().parent
ACT_RESULT = HERE / "act-result.txt"
WORKFLOW = HERE / ".github" / "workflows" / "secret-rotation-validator.yml"

# Files (other than the fixture) that must be present in each temp repo.
PROJECT_FILES = [
    "secret_rotation.py",
    "test_secret_rotation.py",
    ".actrc",
]


# ---------- Static workflow structure tests -------------------------------

@pytest.fixture(scope="module")
def workflow_yaml():
    with open(WORKFLOW, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def test_workflow_has_expected_triggers(workflow_yaml):
    # PyYAML parses the YAML key `on:` as the Python boolean True.
    triggers = workflow_yaml.get("on") or workflow_yaml.get(True)
    assert triggers is not None
    for key in ("push", "pull_request", "workflow_dispatch", "schedule"):
        assert key in triggers, f"missing trigger: {key}"


def test_workflow_has_expected_jobs(workflow_yaml):
    jobs = workflow_yaml["jobs"]
    assert "unit-tests" in jobs
    assert "rotation-report" in jobs
    assert jobs["rotation-report"]["needs"] == "unit-tests"


def test_workflow_references_existing_script(workflow_yaml):
    jobs_text = yaml.safe_dump(workflow_yaml)
    assert "secret_rotation.py" in jobs_text
    assert (HERE / "secret_rotation.py").exists()
    assert "test_secret_rotation.py" in jobs_text
    assert (HERE / "test_secret_rotation.py").exists()


def test_actionlint_passes():
    result = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"actionlint failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
    )


# ---------- act-driven test cases -----------------------------------------

# Each case: name, fixture to drop in as fixtures/secrets.json,
# TODAY (pinned), warning_days, and expected substrings in the act output.
ACT_CASES = [
    {
        "name": "mixed_urgencies",
        "fixture_src": "fixtures/secrets.json",  # already correct default
        "today": "2026-04-20",
        "warning_days": "7",
        # Expected values: db-password is 120d old vs 90d policy = 30d overdue.
        # stripe-key is 25d old vs 30d policy = due in 5 days (within 7d warning).
        # aws-access-key is 10d old vs 180d policy = 170 days remaining.
        "expect_contains": [
            "## Expired (1)",
            "## Warning (1)",
            "## OK (1)",
            "db-password",
            "30 days overdue",
            "stripe-key",
            "due in 5 days",
            "aws-access-key",
            # JSON summary printed by workflow's Summarize step:
            "{'expired': 1, 'warning': 1, 'ok': 1}",
        ],
        "expect_not_contains": [],
    },
    {
        "name": "all_expired",
        "fixture_src": "fixtures/all_expired.json",
        "today": "2026-04-20",
        "warning_days": "7",
        "expect_contains": [
            "## Expired (2)",
            "## Warning (0)",
            "## OK (0)",
            "legacy-db",
            "old-api-key",
            "_None_",  # empty Warning/OK tables
        ],
        "expect_not_contains": [],
    },
    {
        "name": "all_ok_tight_window",
        "fixture_src": "fixtures/all_ok.json",
        "today": "2026-04-20",
        "warning_days": "1",
        "expect_contains": [
            "## Expired (0)",
            "## Warning (0)",
            "## OK (2)",
            "fresh-key-1",
            "fresh-key-2",
        ],
        "expect_not_contains": ["## Expired (1)", "## Warning (1)"],
    },
]


@pytest.fixture(scope="module", autouse=True)
def _reset_act_result_file():
    # Start each test session with a clean artifact file.
    if ACT_RESULT.exists():
        ACT_RESULT.unlink()
    ACT_RESULT.touch()
    yield


def _prepare_repo(workdir: Path, fixture_src: Path) -> None:
    """Stage project files into a fresh git repo under `workdir`."""
    for relpath in PROJECT_FILES:
        src = HERE / relpath
        dst = workdir / relpath
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Workflow
    wf_dst = workdir / ".github" / "workflows" / "secret-rotation-validator.yml"
    wf_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(WORKFLOW, wf_dst)

    # Pinned fixture -> fixtures/secrets.json
    fx_dst = workdir / "fixtures" / "secrets.json"
    fx_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(fixture_src, fx_dst)

    # git init & commit so `act push` has a commit to run against.
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "add", "."], cwd=workdir, check=True, env=env)
    subprocess.run(
        ["git", "commit", "-q", "-m", "init"],
        cwd=workdir, check=True, env=env,
    )


def _append_result(case_name: str, result: subprocess.CompletedProcess) -> None:
    with open(ACT_RESULT, "a", encoding="utf-8") as f:
        f.write(f"\n{'=' * 72}\n")
        f.write(f"CASE: {case_name}\n")
        f.write(f"EXIT CODE: {result.returncode}\n")
        f.write(f"{'=' * 72}\n")
        f.write("--- STDOUT ---\n")
        f.write(result.stdout or "")
        f.write("\n--- STDERR ---\n")
        f.write(result.stderr or "")
        f.write("\n")


@pytest.mark.parametrize("case", ACT_CASES, ids=[c["name"] for c in ACT_CASES])
def test_act_case(case, tmp_path_factory):
    workdir = tmp_path_factory.mktemp(f"act_{case['name']}")
    _prepare_repo(workdir, HERE / case["fixture_src"])

    cmd = [
        "act", "push",
        "--rm",
        "--pull=false",  # use the local act-ubuntu-pwsh image (see .actrc)
        "--var", f"TODAY={case['today']}",
        "--env", f"WARNING_DAYS={case['warning_days']}",
    ]
    result = subprocess.run(
        cmd,
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=600,
    )
    _append_result(case["name"], result)

    combined = (result.stdout or "") + "\n" + (result.stderr or "")

    assert result.returncode == 0, (
        f"act exited {result.returncode} for case {case['name']!r}; "
        f"see act-result.txt"
    )

    # Every job should report success. Act prints "Job succeeded" per job.
    # Our workflow has two jobs -> expect at least 2 occurrences.
    assert combined.count("Job succeeded") >= 2, (
        f"case {case['name']!r}: expected >=2 'Job succeeded' lines, "
        f"got {combined.count('Job succeeded')}"
    )

    for needle in case["expect_contains"]:
        assert needle in combined, (
            f"case {case['name']!r}: expected substring {needle!r} "
            f"not found in act output"
        )
    for needle in case["expect_not_contains"]:
        assert needle not in combined, (
            f"case {case['name']!r}: unexpected substring {needle!r} found"
        )


def test_act_result_file_exists_and_is_nonempty():
    assert ACT_RESULT.exists(), "act-result.txt must exist after the run"
    assert ACT_RESULT.stat().st_size > 0, "act-result.txt must not be empty"
