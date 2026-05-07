#!/usr/bin/env python3
"""Test harness: run the workflow through `act` for several fixtures.

For each test case we:
  1. Build a fresh temp git repo containing the project files + that case's
     fixture wired into the workflow's `CONFIG_PATH` env var.
  2. Run `act push --rm`, capture stdout+stderr.
  3. Append the captured output to ./act-result.txt with a clear delimiter.
  4. Assert: act exit code == 0, every job emitted "Job succeeded", and the
     workflow's printed report contains EXACT expected substrings for that case.

Limit: at most 3 act runs, per spec.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ACT_RESULT = HERE / "act-result.txt"

# Files the temp repo needs to run the workflow.
PROJECT_FILES = [
    "validator.py",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
]


# Each test case picks a fixture and supplies expected EXACT substrings to find
# in the act output. Strings come from the workflow's `cat report.md` /
# `cat report.json` steps.
TEST_CASES = [
    {
        "name": "all-ok",
        "config_path": "fixtures/all-ok.json",
        "warning_days": "7",
        "today": "2026-05-01",
        "expected_substrings": [
            "## Expired (0)",
            "## Warning (0)",
            "## OK (2)",
            "| internal-api-token |",
            "| monitoring-key |",
            '"expired": 0',
            '"ok": 2',
        ],
        # No expired -> validator exit 0 -> step succeeds normally.
        "expected_validator_exit": "0",
    },
    {
        "name": "mixed",
        "config_path": "fixtures/mixed.json",
        "warning_days": "7",
        "today": "2026-05-01",
        "expected_substrings": [
            "## Expired (1)",
            "## Warning (1)",
            "## OK (1)",
            "| db-password |",
            "| stripe-key |",
            "| internal-api-token |",
            '"expired": 1',
            '"warning": 1',
            '"ok": 1',
        ],
        # validator exits 2 when expired secrets present, but the step uses
        # `|| RC=$?` so the step still succeeds.
        "expected_validator_exit": "2",
    },
]


def build_temp_repo(tmp: Path) -> Path:
    """Copy project files into a fresh git repo (act expects a git repo)."""
    for entry in PROJECT_FILES:
        src = HERE / entry
        dst = tmp / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    # Initialize git so `act push` has something to chew on.
    env = {**os.environ, "GIT_AUTHOR_NAME": "test", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "test", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=tmp, check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "test"], cwd=tmp, check=True, env=env)
    return tmp


def run_one(case: dict) -> tuple[int, str]:
    """Run act for one test case in an isolated repo. Returns (rc, output)."""
    with tempfile.TemporaryDirectory() as tmpdir:
        repo = build_temp_repo(Path(tmpdir))

        # Override workflow env vars per-case via act's --env flag.
        cmd = [
            "act", "push", "--rm",
            # The pinned image is built locally; don't force-pull.
            "--pull=false",
            "--env", f"CONFIG_PATH={case['config_path']}",
            "--env", f"WARNING_DAYS={case['warning_days']}",
            "--env", f"TODAY={case['today']}",
        ]
        proc = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr


def assert_case(case: dict, rc: int, output: str) -> list[str]:
    """Return list of failure messages (empty == passed)."""
    failures: list[str] = []
    if rc != 0:
        failures.append(f"act exit code: expected 0, got {rc}")

    if "Job succeeded" not in output:
        failures.append("missing 'Job succeeded' in output")

    # Both jobs (unit-tests and validate-secrets) should succeed.
    succeeded_count = output.count("Job succeeded")
    if succeeded_count < 2:
        failures.append(
            f"expected at least 2 'Job succeeded' (one per job), got {succeeded_count}"
        )

    for needle in case["expected_substrings"]:
        if needle not in output:
            failures.append(f"missing expected substring: {needle!r}")

    expected_validator_marker = f"Validator exit code: {case['expected_validator_exit']}"
    if expected_validator_marker not in output:
        failures.append(f"missing exact line: {expected_validator_marker!r}")

    return failures


def main() -> int:
    # Wipe previous act-result.txt at the start of a run so it represents *this* run.
    ACT_RESULT.write_text("")

    overall_failures: list[str] = []
    for case in TEST_CASES:
        sys.stdout.write(f"\n=== running case: {case['name']} ===\n")
        sys.stdout.flush()
        rc, output = run_one(case)

        with ACT_RESULT.open("a") as fh:
            fh.write(f"\n{'=' * 70}\n")
            fh.write(f"=== TEST CASE: {case['name']} (act rc={rc}) ===\n")
            fh.write(f"{'=' * 70}\n")
            fh.write(output)
            fh.write("\n")

        failures = assert_case(case, rc, output)
        if failures:
            overall_failures.append(f"[{case['name']}] " + "; ".join(failures))
            sys.stdout.write(f"FAIL: {case['name']}\n")
            for f in failures:
                sys.stdout.write(f"  - {f}\n")
        else:
            sys.stdout.write(f"PASS: {case['name']}\n")

    if overall_failures:
        sys.stdout.write("\n=== HARNESS FAILED ===\n")
        for f in overall_failures:
            sys.stdout.write(f"  {f}\n")
        return 1
    sys.stdout.write("\n=== ALL ACT CASES PASSED ===\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
