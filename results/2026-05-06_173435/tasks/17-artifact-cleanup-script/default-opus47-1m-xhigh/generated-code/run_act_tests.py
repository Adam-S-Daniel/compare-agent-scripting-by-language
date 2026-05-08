"""End-to-end test harness: run the GitHub Actions workflow under `act` for
each fixture case, parse the output, and assert exact expected values.

Per the task spec:
  * Each test case sets up a fresh temp git repo with the project tree plus
    the case's fixture data placed at fixtures/active/.
  * `act push --rm` is invoked once per case; output is captured, appended
    to act-result.txt with clear delimiters.
  * Assertions:
      - act exited 0
      - every job emitted "Job succeeded"
      - every CLEANUP::KEY=VALUE assertion line exactly matches
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent
ACT_RESULT = PROJECT / "act-result.txt"

# Files/dirs that must travel into every per-case temp repo.
PROJECT_ENTRIES = [
    ".github",
    "tests",
    "fixtures",
    "cleanup.py",
    "conftest.py",
    ".actrc",
]


# Each entry: case directory under fixtures/, the exact CLEANUP::* assertion
# lines that must appear in the act log.
#
# Values were computed by running cleanup.py against each fixture locally;
# they are the contract: if the engine ever produces something different,
# either the engine or the expectations are wrong.
CASES = {
    "case_max_age": {
        "summary": {
            "DELETED_COUNT": "2",
            "RETAINED_COUNT": "1",
            "SPACE_RECLAIMED": "1500",
            "SPACE_RETAINED": "200",
            "TOTAL": "3",
            "DRY_RUN": "False",
        },
        "deletions": {
            "a1:max_age_days",
            "a2:max_age_days",
        },
    },
    "case_keep_latest": {
        "summary": {
            "DELETED_COUNT": "4",
            "RETAINED_COUNT": "4",
            "SPACE_RECLAIMED": "350",
            "SPACE_RETAINED": "300",
            "TOTAL": "8",
            "DRY_RUN": "False",
        },
        "deletions": {
            "k1:keep_latest_n_per_workflow",
            "k2:keep_latest_n_per_workflow",
            "k3:keep_latest_n_per_workflow",
            "t1:keep_latest_n_per_workflow",
        },
    },
    "case_combined_dryrun": {
        "summary": {
            "DELETED_COUNT": "4",
            "RETAINED_COUNT": "1",
            "SPACE_RECLAIMED": "2200",
            "SPACE_RETAINED": "200",
            "TOTAL": "5",
            "DRY_RUN": "True",
        },
        "deletions": {
            "c1:max_age_days",
            "c2:max_age_days",
            "c3:keep_latest_n_per_workflow",
            "c4:max_total_size_bytes",
        },
    },
}

# Number of jobs in the workflow. Each job emits "Job succeeded" on success.
EXPECTED_JOB_COUNT = 2


def _setup_temp_repo(case_name: str, tmp: Path) -> None:
    """Lay out a clean copy of the project files in tmp, with the named
    fixture promoted into fixtures/active/, then init a git repo so act has
    something to find."""
    for entry in PROJECT_ENTRIES:
        src = PROJECT / entry
        if not src.exists():
            continue
        dst = tmp / entry
        if src.is_dir():
            shutil.copytree(src, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dst)

    active = tmp / "fixtures" / "active"
    if active.exists():
        shutil.rmtree(active)
    shutil.copytree(PROJECT / "fixtures" / case_name, active)

    # Minimal git repo so `act push` has a HEAD to read.
    env = {"GIT_TERMINAL_PROMPT": "0"}
    subprocess.run(["git", "init", "-q", "-b", "master"], cwd=tmp, check=True, env={**env})
    subprocess.run(["git", "config", "user.email", "act@test.local"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.name", "act-test"], cwd=tmp, check=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp, check=True)
    subprocess.run(["git", "commit", "-q", "-m", f"fixture {case_name}"], cwd=tmp, check=True)


def _run_act(tmp: Path) -> tuple[int, str]:
    """Run `act push --rm` in tmp; return (exit_code, combined_output)."""
    # --pull=false: the act-ubuntu-pwsh image is built locally (see the
    # repo's Dockerfile.act); without this, act always tries to pull from a
    # registry first and fails on a local-only image.
    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp,
        capture_output=True,
        text=True,
    )
    combined = proc.stdout + ("\n--- stderr ---\n" + proc.stderr if proc.stderr else "")
    return proc.returncode, combined


def _check_case(case_name: str, expected: dict, output: str) -> list[str]:
    """Return a list of failure messages (empty list = pass)."""
    fails: list[str] = []

    for key, val in expected["summary"].items():
        line = f"CLEANUP::{key}={val}"
        if line not in output:
            fails.append(f"missing line: {line!r}")

    for d in expected["deletions"]:
        line = f"CLEANUP::DELETION={d}"
        if line not in output:
            fails.append(f"missing deletion line: {line!r}")

    succeed_count = output.count("Job succeeded")
    if succeed_count < EXPECTED_JOB_COUNT:
        fails.append(
            f"only {succeed_count} 'Job succeeded' messages, expected "
            f"{EXPECTED_JOB_COUNT}"
        )

    return fails


def main() -> int:
    # Truncate the result file at the start so an old run doesn't bleed in.
    ACT_RESULT.write_text("")
    overall_failures: list[str] = []

    for case_name, expected in CASES.items():
        print(f"\n>>> {case_name}: setting up temp repo...", flush=True)
        with tempfile.TemporaryDirectory(prefix=f"act-{case_name}-") as tmp_str:
            tmp = Path(tmp_str)
            try:
                _setup_temp_repo(case_name, tmp)
            except subprocess.CalledProcessError as exc:
                overall_failures.append(f"{case_name}: setup failed: {exc}")
                continue

            print(f">>> {case_name}: running act push...", flush=True)
            exit_code, output = _run_act(tmp)

            with ACT_RESULT.open("a") as f:
                f.write("\n" + "=" * 72 + "\n")
                f.write(f"=== CASE: {case_name}\n")
                f.write("=" * 72 + "\n")
                f.write(output)
                f.write(f"\n[act exit code: {exit_code}]\n")

            if exit_code != 0:
                overall_failures.append(
                    f"{case_name}: act exited {exit_code}; see act-result.txt"
                )
                continue

            fails = _check_case(case_name, expected, output)
            if fails:
                for f in fails:
                    overall_failures.append(f"{case_name}: {f}")
            else:
                print(f">>> {case_name}: PASS")

    print("\n" + "=" * 72)
    if overall_failures:
        print("ACT TEST HARNESS: FAILURES")
        for f in overall_failures:
            print(f"  - {f}")
        return 1
    print(f"ACT TEST HARNESS: ALL {len(CASES)} CASES PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
