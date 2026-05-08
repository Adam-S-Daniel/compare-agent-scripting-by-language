#!/usr/bin/env python3
"""Test harness: run the workflow under `act` for each fixture-set test case.

Every assertion exercises the aggregator *through the GitHub Actions workflow*
(per task requirements) — we never call aggregator.py directly here.

For each case, we:
  1. Build a temp git repo containing the project + only that case's fixture files
  2. Run `act push --rm` once (capped at 3 total runs to stay under the budget)
  3. Append all output to act-result.txt
  4. Assert act exited 0, every job says "Job succeeded", and the STATS line
     printed by aggregator.py contains the exact expected counts for this case.
"""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
ACT_RESULT = PROJECT / "act-result.txt"

PROJECT_FILES = [
    "aggregator.py",
    "test_aggregator.py",
    ".actrc",
    ".github/workflows/test-results-aggregator.yml",
]

# Each case: name -> {fixtures (list of source filenames), expected stats}.
# Expected values were hand-computed from the fixture contents — see fixtures/.
CASES = [
    {
        "name": "all_three_runs",
        "fixtures": ["run1.xml", "run2.json", "run3.xml"],
        # run1: 3p/1f/1s, run2: 4p/0f/1s, run3: 1p/1f/0s
        # token_refresh failed in run1, passed in run2 → flaky
        # charge_card failed only (consistently) → real failure
        "expected": {"passed": 8, "failed": 2, "skipped": 2, "flaky": 1,
                     "duration": 6.43},
        "expect_md": ["payments.ChargeTests.test_charge_card",
                      "auth.LoginTests.test_token_refresh"],
    },
    {
        "name": "json_only_clean",
        "fixtures": ["run2.json"],
        "expected": {"passed": 4, "failed": 0, "skipped": 1, "flaky": 0,
                     "duration": 2.83},
        "expect_md": ["All tests passed cleanly"],
    },
    {
        "name": "single_failing_xml",
        "fixtures": ["run3.xml"],
        "expected": {"passed": 1, "failed": 1, "skipped": 0, "flaky": 0,
                     "duration": 0.60},
        "expect_md": ["payments.ChargeTests.test_charge_card"],
    },
]


def stage_repo(case: dict) -> Path:
    """Create a temp git repo containing the project + only this case's fixtures."""
    workdir = Path(tempfile.mkdtemp(prefix=f"act-{case['name']}-"))
    for rel in PROJECT_FILES:
        src = PROJECT / rel
        dst = workdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
    fixtures_dir = workdir / "fixtures"
    fixtures_dir.mkdir()
    for f in case["fixtures"]:
        shutil.copy2(PROJECT / "fixtures" / f, fixtures_dir / f)
    # Initialize git so act has a sha to operate on.
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=workdir, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=workdir, check=True)
    subprocess.run(["git", "add", "."], cwd=workdir, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=workdir, check=True)
    return workdir


def run_act(workdir: Path) -> tuple[int, str]:
    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=workdir,
        capture_output=True,
        text=True,
        timeout=600,
    )
    return proc.returncode, proc.stdout + proc.stderr


def parse_stats(output: str) -> dict | None:
    """Find the `STATS passed=X failed=Y ...` line emitted by aggregator.py."""
    m = re.search(
        r"STATS passed=(\d+) failed=(\d+) skipped=(\d+) flaky=(\d+) duration=([\d.]+)",
        output,
    )
    if not m:
        return None
    return {
        "passed": int(m.group(1)),
        "failed": int(m.group(2)),
        "skipped": int(m.group(3)),
        "flaky": int(m.group(4)),
        "duration": float(m.group(5)),
    }


def main() -> int:
    ACT_RESULT.write_text("")  # truncate at start
    failures: list[str] = []

    for case in CASES:
        print(f"\n=== CASE: {case['name']} ===", flush=True)
        workdir = stage_repo(case)
        try:
            rc, output = run_act(workdir)
        finally:
            # Always preserve output even on exceptions
            with ACT_RESULT.open("a") as fh:
                fh.write(f"\n\n========== CASE: {case['name']} ==========\n")
                fh.write(f"workdir: {workdir}\n")
                fh.write(output if 'output' in locals() else "<no output>\n")
                fh.write(f"\n--- exit code: {rc if 'rc' in locals() else '?'} ---\n")

        # --- Assertions ---
        if rc != 0:
            failures.append(f"{case['name']}: act exit code {rc} (expected 0)")
            continue

        # Every job in act prints either "Job succeeded" or "Job failed". Require all succeeded.
        if "Job failed" in output:
            failures.append(f"{case['name']}: at least one job failed")
        if "Job succeeded" not in output:
            failures.append(f"{case['name']}: no 'Job succeeded' line found")

        stats = parse_stats(output)
        if stats is None:
            failures.append(f"{case['name']}: STATS line not found in output")
            continue

        exp = case["expected"]
        for key in ("passed", "failed", "skipped", "flaky"):
            if stats[key] != exp[key]:
                failures.append(
                    f"{case['name']}: {key} = {stats[key]}, expected {exp[key]}"
                )
        # Allow tiny float slop on duration
        if abs(stats["duration"] - exp["duration"]) > 0.01:
            failures.append(
                f"{case['name']}: duration = {stats['duration']}, "
                f"expected ≈ {exp['duration']}"
            )

        for needle in case["expect_md"]:
            if needle not in output:
                failures.append(
                    f"{case['name']}: expected substring not in output: {needle!r}"
                )

        # Tidy up the temp dir on success
        shutil.rmtree(workdir, ignore_errors=True)

    print("\n========== HARNESS RESULT ==========")
    if failures:
        for f in failures:
            print(f"FAIL: {f}")
        print(f"\n{len(failures)} assertion(s) failed.")
        return 1
    print(f"All {len(CASES)} cases passed.")
    print(f"Full act output captured in: {ACT_RESULT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
