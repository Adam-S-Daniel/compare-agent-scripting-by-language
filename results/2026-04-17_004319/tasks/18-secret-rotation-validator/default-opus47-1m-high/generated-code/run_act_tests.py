"""End-to-end test harness that runs every test case through `act`.

For each fixture in act-fixtures/, the harness:
  1. Builds an isolated git repo containing the project + the fixture as
     `secrets.json`.
  2. Invokes `act push --rm` against the workflow.
  3. Appends the captured output to act-result.txt with a clear delimiter.
  4. Asserts exit code 0 and that the output contains exact expected values
     for that fixture.
  5. Verifies workflow structure (YAML, actionlint, file references).

Run:  python3 run_act_tests.py
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

REPO = Path(__file__).parent.resolve()
FIXTURE_DIR = REPO / "act-fixtures"
RESULT_FILE = REPO / "act-result.txt"
WORKFLOW = REPO / ".github" / "workflows" / "secret-rotation-validator.yml"

# Each case lists assertions over the act stdout + stderr capture. The
# assertions check exact strings, not just "some output appeared", because
# the values are deterministic given the fixture's current_date / policy.
CASES = [
    {
        "name": "all_ok",
        "fixture": "all_ok.json",
        "must_contain": [
            "## EXPIRED (0)",
            "## WARNING (0)",
            "## OK (3)",
            "| stripe-api-key |",
            "| github-deploy-token |",
            "| postgres-root-password |",
            "rotation-exit-code=0",
        ],
        "must_not_contain": ["rotation-exit-code=1", "rotation-exit-code=2"],
    },
    {
        "name": "mixed",
        "fixture": "mixed.json",
        "must_contain": [
            "## EXPIRED (1)",
            "## WARNING (1)",
            "## OK (1)",
            # stripe-api-key: 2025-12-01 + 90 = 2026-03-01 -> -49 days
            "| stripe-api-key | 2025-12-01 | 90 | 2026-03-01 | -49 |",
            # github-deploy-token: 2026-01-25 + 90 = 2026-04-25 -> 6 days
            "| github-deploy-token | 2026-01-25 | 90 | 2026-04-25 | 6 |",
            # postgres-root-password: 2026-04-15 + 90 = 2026-07-14 -> 86 days
            "| postgres-root-password | 2026-04-15 | 90 | 2026-07-14 | 86 |",
            "rotation-exit-code=1",
        ],
        "must_not_contain": ["rotation-exit-code=0", "rotation-exit-code=2"],
    },
    {
        "name": "json_output",
        "fixture": "json_output.json",
        "must_contain": [
            '"summary"',
            '"expired": 1',
            '"warning": 1',
            '"ok": 0',
            '"name": "expired-key"',
            '"name": "warning-key"',
            '"days_until_expiry": -443',
            '"days_until_expiry": 3',
            "rotation-exit-code=1",
        ],
        "must_not_contain": ["rotation-exit-code=0", "rotation-exit-code=2"],
    },
]


def _stage_workspace(workdir: Path, fixture: Path) -> None:
    """Copy project files into *workdir* and overwrite secrets.json."""
    for entry in ("secret_rotation.py", "tests", ".github", ".actrc"):
        src = REPO / entry
        dst = workdir / entry
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy(src, dst)
    shutil.copy(fixture, workdir / "secrets.json")
    # Initialize a git repo so act can run against it.
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=workdir,
                   check=True, env=env)
    subprocess.run(["git", "add", "-A"], cwd=workdir, check=True, env=env)
    subprocess.run(["git", "commit", "-q", "-m", "init"], cwd=workdir,
                   check=True, env=env)


def _run_act(workdir: Path) -> tuple[int, str]:
    # --pull=false: the custom act image (act-ubuntu-pwsh) is built locally and
    # not on any registry, so disable act's default force-pull behavior.
    proc = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=workdir,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout + "\n--- STDERR ---\n" + proc.stderr


def _check_assertions(case: dict, output: str) -> list[str]:
    failures = []
    for needle in case["must_contain"]:
        if needle not in output:
            failures.append(f"missing expected substring: {needle!r}")
    for needle in case.get("must_not_contain", []):
        if needle in output:
            failures.append(f"unexpected substring present: {needle!r}")
    if "Job succeeded" not in output:
        failures.append("no 'Job succeeded' line in act output")
    return failures


def _verify_workflow_structure() -> list[str]:
    failures = []
    with WORKFLOW.open() as f:
        # PyYAML treats the literal `on` key as boolean True in YAML 1.1; we
        # accept either form.
        wf = yaml.safe_load(f)
    triggers = wf.get("on") or wf.get(True) or {}
    for required in ("push", "pull_request", "workflow_dispatch", "schedule"):
        if required not in triggers:
            failures.append(f"workflow missing trigger: {required}")
    jobs = wf.get("jobs", {})
    for job in ("unit-tests", "rotation-report"):
        if job not in jobs:
            failures.append(f"workflow missing job: {job}")
    if jobs.get("rotation-report", {}).get("needs") != "unit-tests":
        failures.append("rotation-report should depend on unit-tests")
    # Check the workflow references files that exist.
    serialized = WORKFLOW.read_text()
    for path in ("secret_rotation.py", "tests/", "secrets.json"):
        if path not in serialized:
            failures.append(f"workflow does not reference {path}")
        if not (REPO / path.rstrip("/")).exists():
            failures.append(f"referenced path missing on disk: {path}")
    if wf.get("permissions", {}).get("contents") != "read":
        failures.append("workflow should declare read-only contents permission")
    return failures


def _verify_actionlint() -> list[str]:
    proc = subprocess.run(
        ["actionlint", str(WORKFLOW)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return [f"actionlint failed (exit {proc.returncode}):\n{proc.stdout}{proc.stderr}"]
    return []


def main() -> int:
    if RESULT_FILE.exists():
        RESULT_FILE.unlink()
    RESULT_FILE.write_text(
        f"# act-result.txt — captured output from {len(CASES)} act runs\n\n"
    )

    overall_failures: list[str] = []

    print("== Workflow structure checks ==")
    structure_failures = _verify_workflow_structure() + _verify_actionlint()
    if structure_failures:
        for f in structure_failures:
            print(f"  FAIL: {f}")
        overall_failures.extend(structure_failures)
    else:
        print("  OK")

    for case in CASES:
        name = case["name"]
        fixture = FIXTURE_DIR / case["fixture"]
        print(f"\n== act case: {name} ==")
        with tempfile.TemporaryDirectory(prefix=f"act-{name}-") as tmp:
            workdir = Path(tmp)
            _stage_workspace(workdir, fixture)
            exit_code, output = _run_act(workdir)

        # Append to act-result.txt with a clear delimiter.
        with RESULT_FILE.open("a") as out:
            out.write(f"\n{'=' * 78}\n")
            out.write(f"CASE: {name}  (fixture={case['fixture']})\n")
            out.write(f"act exit code: {exit_code}\n")
            out.write(f"{'=' * 78}\n")
            out.write(output)

        case_failures: list[str] = []
        if exit_code != 0:
            case_failures.append(f"act exited {exit_code}, expected 0")
        case_failures.extend(_check_assertions(case, output))
        if case_failures:
            for f in case_failures:
                print(f"  FAIL: {f}")
            overall_failures.extend(f"[{name}] {f}" for f in case_failures)
        else:
            print("  OK")

    print("\n" + "=" * 60)
    if overall_failures:
        print(f"FAILED ({len(overall_failures)} issue(s)):")
        for f in overall_failures:
            print(f"  - {f}")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
