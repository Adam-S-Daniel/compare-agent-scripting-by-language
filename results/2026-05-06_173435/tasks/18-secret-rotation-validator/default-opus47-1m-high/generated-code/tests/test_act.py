# Act-driven end-to-end test harness.
#
# This is the spec-mandated layer: every assertion about the validator's
# real behaviour goes through the GitHub Actions workflow executed by
# `act` in a Docker container. Each test case sets up an isolated temp
# git repo, swaps in case-specific fixture data, runs `act push --rm`,
# captures the output to act-result.txt (the required artifact), then
# asserts on exact known-good substrings + the "Job succeeded" markers
# for both jobs.
#
# We deliberately keep this to three test cases so the harness fits the
# benchmark's "at most 3 act push runs" budget. Each act run takes
# 30-90s, which is why structural correctness is covered separately by
# the cheap tests in test_workflow_structure.py and test_validator.py.

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ACT_RESULT_FILE = PROJECT_ROOT / "act-result.txt"

# Files that must accompany the workflow into each isolated temp repo.
# Listed explicitly (rather than copying * ) so we don't accidentally
# carry the harness's own pytest cache, the previous act-result.txt, or
# anything else that shouldn't influence the run.
PROJECT_FILES = [
    "rotation_validator.py",
    "conftest.py",
    "tests/test_validator.py",
    ".github/workflows/secret-rotation-validator.yml",
    ".actrc",
]


# --- expected outputs per test case ------------------------------------
#
# The audit step in the workflow always runs with --today=2026-05-07 and
# --warning-days=14 (pinned via env in the workflow), so the rendered
# values below are deterministic.

MIXED_FIXTURE = [
    {"name": "stripe-api-key", "last_rotated": "2026-05-01", "policy_days": 90, "services": ["billing", "web"]},
    {"name": "db-password", "last_rotated": "2026-04-15", "policy_days": 30, "services": ["api"]},
    {"name": "legacy-token", "last_rotated": "2025-01-01", "policy_days": 90, "services": ["batch"]},
    {"name": "oauth-client-secret", "last_rotated": "2026-03-01", "policy_days": 60, "services": ["auth", "web"]},
]

ALL_OK_FIXTURE = [
    {"name": "fresh-token", "last_rotated": "2026-05-01", "policy_days": 90, "services": ["web"]},
    {"name": "fresh-key", "last_rotated": "2026-04-30", "policy_days": 365, "services": ["api"]},
]

EMPTY_FIXTURE: list[dict] = []

TEST_CASES = [
    {
        "id": "mixed",
        "fixture": MIXED_FIXTURE,
        # Substrings that MUST appear in the act output. They include
        # exact rendered counts + at least one row from each bucket +
        # exact JSON values that depend on the date arithmetic.
        "expect_substrings": [
            # Markdown summary block (exact counts)
            "**Total:** 4",
            "**Expired:** 2",
            "**Warning:** 1",
            "**OK:** 1",
            # Section headers in urgency order
            "## Expired",
            "## Warning",
            "## OK",
            # One identifying row per bucket
            "| legacy-token |",
            "| oauth-client-secret |",
            "| db-password |",
            "| stripe-api-key |",
            # Exact "days overdue" / "until due" cells
            "401 overdue",   # legacy-token: due 2025-04-01, 2026-05-07 -> 401 overdue
            "7 overdue",     # oauth-client-secret: due 2026-04-30, 2026-05-07 -> 7 overdue
            "8 until due",   # db-password: due 2026-05-15 -> 8 days until
            # JSON output exact values
            '"generated_for": "2026-05-07"',
            '"warning_days": 14',
            '"days_until_due": -401',
            '"due_date": "2025-04-01"',
            "===MARKDOWN-REPORT-END===",
            "===JSON-REPORT-END===",
            "AUDIT-GATE: expired secrets detected",
        ],
        "must_not_contain": [
            "AUDIT-GATE: clean",
        ],
    },
    {
        "id": "all-ok",
        "fixture": ALL_OK_FIXTURE,
        "expect_substrings": [
            "**Total:** 2",
            "**Expired:** 0",
            "**Warning:** 0",
            "**OK:** 2",
            "| fresh-token |",
            "| fresh-key |",
            '"summary": {',
            '"expired": 0',
            '"warning": 0',
            '"ok": 2',
            "AUDIT-GATE: clean",
        ],
        "must_not_contain": [
            "AUDIT-GATE: expired secrets detected",
        ],
    },
    {
        "id": "empty",
        "fixture": EMPTY_FIXTURE,
        "expect_substrings": [
            "**Total:** 0",
            "**Expired:** 0",
            "**Warning:** 0",
            "**OK:** 0",
            "_None_",  # placeholder for empty buckets
            '"expired": []',
            '"warning": []',
            '"ok": []',
            "AUDIT-GATE: clean",
        ],
        "must_not_contain": [
            "AUDIT-GATE: expired secrets detected",
        ],
    },
]


# --- helpers ------------------------------------------------------------

def _materialize_repo(dst: Path, fixture: list[dict]) -> None:
    """Copy required project files into ``dst`` and write the fixture."""
    for rel in PROJECT_FILES:
        src = PROJECT_ROOT / rel
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if src.is_dir():
            shutil.copytree(src, target, dirs_exist_ok=True)
        else:
            shutil.copy2(src, target)

    # Workflow expects fixtures/secrets.json — write the case fixture there.
    fixtures_dir = dst / "fixtures"
    fixtures_dir.mkdir(parents=True, exist_ok=True)
    (fixtures_dir / "secrets.json").write_text(json.dumps(fixture, indent=2))


def _git_init(dst: Path) -> None:
    """`act` reads the workflow from a real git repo, so seed one."""
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "harness",
        "GIT_AUTHOR_EMAIL": "harness@example.com",
        "GIT_COMMITTER_NAME": "harness",
        "GIT_COMMITTER_EMAIL": "harness@example.com",
    }
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=dst, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=dst, check=True, env=env)
    subprocess.run(
        ["git", "commit", "-q", "-m", "initial"], cwd=dst, check=True, env=env
    )


def _run_act(dst: Path) -> tuple[int, str]:
    """Run `act push --rm` in ``dst`` and return (rc, combined_output)."""
    act = shutil.which("act")
    assert act, "act CLI is required for this test"
    proc = subprocess.run(
        [act, "push", "--rm"],
        cwd=dst,
        capture_output=True,
        text=True,
        timeout=600,
    )
    combined = proc.stdout + "\n--- stderr ---\n" + proc.stderr
    return proc.returncode, combined


def _append_to_result(case_id: str, rc: int, output: str) -> None:
    delim_top = f"\n{'=' * 80}\n=== TEST CASE: {case_id} (act rc={rc}) ===\n{'=' * 80}\n"
    delim_bot = f"\n{'=' * 80}\n=== END CASE: {case_id} ===\n{'=' * 80}\n\n"
    with ACT_RESULT_FILE.open("a") as f:
        f.write(delim_top)
        f.write(output)
        f.write(delim_bot)


# --- the harness --------------------------------------------------------

@pytest.fixture(scope="module")
def fresh_act_result_file():
    # Reset the artifact at the start of the module so each invocation
    # of pytest produces a clean, complete log.
    if ACT_RESULT_FILE.exists():
        ACT_RESULT_FILE.unlink()
    ACT_RESULT_FILE.touch()
    yield ACT_RESULT_FILE


@pytest.mark.parametrize("case", TEST_CASES, ids=[c["id"] for c in TEST_CASES])
def test_act_workflow(case, fresh_act_result_file, tmp_path_factory):
    if shutil.which("act") is None:
        pytest.skip("act not installed")
    if shutil.which("docker") is None:
        pytest.skip("docker not installed")

    repo = tmp_path_factory.mktemp(f"act-{case['id']}")
    _materialize_repo(repo, case["fixture"])
    _git_init(repo)

    rc, output = _run_act(repo)
    _append_to_result(case["id"], rc, output)

    # 1. act exited cleanly
    assert rc == 0, (
        f"act exited with rc={rc} for case {case['id']!r}.\n"
        f"Output (last 2000 chars):\n{output[-2000:]}"
    )

    # 2. Both jobs report success. act prints a "Job succeeded" line per job.
    job_succeeded_count = output.count("Job succeeded")
    assert job_succeeded_count >= 2, (
        f"expected >=2 'Job succeeded' lines (one per job), got "
        f"{job_succeeded_count}.\nOutput:\n{output[-2000:]}"
    )

    # 3. Every expected exact substring is present.
    for needle in case["expect_substrings"]:
        assert needle in output, (
            f"missing expected substring {needle!r} in act output for "
            f"case {case['id']!r}.\nOutput tail:\n{output[-2000:]}"
        )

    # 4. None of the forbidden substrings appear.
    for needle in case.get("must_not_contain", []):
        assert needle not in output, (
            f"unexpected substring {needle!r} appeared in act output "
            f"for case {case['id']!r}."
        )


def test_act_result_artifact_exists():
    # Sanity check that the artifact was produced. Runs after the
    # parametrized cases (alphabetical ordering puts this last because
    # of the leading `test_act_result_artifact` vs `test_act_workflow`,
    # so we guard with a simple existence check rather than rely on
    # ordering).
    if not ACT_RESULT_FILE.exists() or ACT_RESULT_FILE.stat().st_size == 0:
        pytest.skip(
            "act-result.txt not yet populated — this test only "
            "passes after test_act_workflow has run"
        )
    text = ACT_RESULT_FILE.read_text()
    for cid in (c["id"] for c in TEST_CASES):
        assert f"TEST CASE: {cid}" in text, (
            f"act-result.txt is missing the {cid!r} case delimiter"
        )
