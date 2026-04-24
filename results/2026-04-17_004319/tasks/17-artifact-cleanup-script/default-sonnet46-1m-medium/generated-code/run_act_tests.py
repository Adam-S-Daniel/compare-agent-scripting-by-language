#!/usr/bin/env python3
"""
Act test harness.

For each test case the harness:
  1. Sets up a fresh temp git repo containing all project files.
  2. Runs `act push --rm` inside it.
  3. Appends the full output to act-result.txt (clearly delimited).
  4. Asserts exit code == 0.
  5. Asserts exact expected strings appear in the output.

All five fixture-driven test cases are batched into a single `act push` run
to stay well within the 3-run limit.

Workflow structure tests (YAML parse, path checks, actionlint) run locally
without act.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import yaml  # pyyaml

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(SCRIPT_DIR, "act-result.txt")

# Files / directories to copy into every temp repo.
COPY_ITEMS = [
    "artifact_cleanup.py",
    "test_artifact_cleanup.py",
    "fixtures",
    ".github",
    ".actrc",
]

# ---------------------------------------------------------------------------
# Exact strings that must appear in the combined act output.
# Grouped by test case so failures are easy to diagnose.
# ---------------------------------------------------------------------------
TC_ASSERTIONS = [
    {
        "name": "TC1: Age-based retention",
        "strings": [
            "Artifacts to delete: 2",
            "Artifacts to retain: 2",
            "Space reclaimed: 150.0 MB",
            "VALIDATION: ALL ASSERTIONS PASSED",
            "DRY RUN",
        ],
    },
    {
        "name": "TC2: Size-based retention",
        "strings": [
            "Artifacts to delete: 2",
            "Artifacts to retain: 1",
            "Space reclaimed: 140.0 MB",
            "VALIDATION: ALL ASSERTIONS PASSED",
        ],
    },
    {
        "name": "TC3: Keep-latest-N",
        "strings": [
            "Artifacts to delete: 1",
            "Artifacts to retain: 4",
            "Space reclaimed: 10.0 MB",
            "VALIDATION: ALL ASSERTIONS PASSED",
        ],
    },
    {
        "name": "TC4: Combined policies",
        "strings": [
            "Artifacts to delete: 4",
            "Artifacts to retain: 4",
            "Space reclaimed: 115.0 MB",
            "VALIDATION: ALL ASSERTIONS PASSED",
            "EXECUTING",
        ],
    },
    {
        "name": "TC5: Dry-run mode",
        "strings": [
            "Artifacts to delete: 1",
            "Artifacts to retain: 1",
            "Space reclaimed: 50.0 MB",
            "VALIDATION: ALL ASSERTIONS PASSED",
        ],
    },
]

# Strings that must appear in the pytest section of the output.
PYTEST_ASSERTIONS = [
    "26 passed",
    "Job succeeded",
]


# ---------------------------------------------------------------------------
# Workflow structure tests (no act required)
# ---------------------------------------------------------------------------

def test_workflow_structure() -> list[str]:
    """Parse the YAML and assert expected triggers, jobs, steps, and file refs."""
    failures = []
    wf_path = os.path.join(SCRIPT_DIR, ".github", "workflows", "artifact-cleanup-script.yml")

    if not os.path.exists(wf_path):
        return [f"Workflow file missing: {wf_path}"]

    with open(wf_path) as fh:
        wf = yaml.safe_load(fh)

    # In pyyaml, the bare key `on:` is parsed as boolean True, not the string "on".
    triggers = wf.get(True, wf.get("on", {})) or {}
    # Triggers
    for trigger in ("push", "pull_request", "workflow_dispatch", "schedule"):
        if trigger not in triggers:
            failures.append(f"Missing trigger: {trigger}")

    # Jobs
    jobs = wf.get("jobs", {})
    for job in ("unit-tests", "fixture-tests"):
        if job not in jobs:
            failures.append(f"Missing job: {job}")

    # fixture-tests depends on unit-tests
    ft_needs = jobs.get("fixture-tests", {}).get("needs", [])
    if "unit-tests" not in ([ft_needs] if isinstance(ft_needs, str) else ft_needs):
        failures.append("fixture-tests must declare 'needs: unit-tests'")

    # Referenced paths exist
    for path in ("artifact_cleanup.py", "fixtures/tc1_age_policy.json",
                 "fixtures/tc2_size_policy.json", "fixtures/tc3_keep_latest.json",
                 "fixtures/tc4_combined.json", "fixtures/tc5_dry_run.json"):
        full = os.path.join(SCRIPT_DIR, path)
        if not os.path.exists(full):
            failures.append(f"Referenced path missing: {path}")

    # actionlint
    result = subprocess.run(
        ["actionlint", wf_path],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        failures.append(f"actionlint failed:\n{result.stdout}{result.stderr}")

    return failures


# ---------------------------------------------------------------------------
# Act run helpers
# ---------------------------------------------------------------------------

def _copy_project_to(dest: str) -> None:
    """Copy all project files into dest directory."""
    for item in COPY_ITEMS:
        src = os.path.join(SCRIPT_DIR, item)
        dst = os.path.join(dest, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)


def _init_git(repo_dir: str) -> None:
    """Initialise a git repo with one commit so `act push` works."""
    for cmd in (
        ["git", "init"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "initial"],
    ):
        subprocess.run(cmd, cwd=repo_dir, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_act(repo_dir: str) -> tuple[int, str]:
    """Run `act push --rm` in repo_dir; return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=600,
    )
    return result.returncode, result.stdout + result.stderr


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    all_failures: list[str] = []

    # -----------------------------------------------------------------------
    # 1. Workflow structure tests (instant — no Docker required)
    # -----------------------------------------------------------------------
    print("=" * 60)
    print("WORKFLOW STRUCTURE TESTS")
    print("=" * 60)
    struct_failures = test_workflow_structure()
    if struct_failures:
        for f in struct_failures:
            print(f"  FAIL: {f}")
        all_failures.extend(struct_failures)
    else:
        print("  PASS: triggers, jobs, paths, actionlint all OK")

    # -----------------------------------------------------------------------
    # 2. Act run — all test cases in one push
    # -----------------------------------------------------------------------
    print()
    print("=" * 60)
    print("ACT RUN: all test cases via act push --rm")
    print("=" * 60)

    with tempfile.TemporaryDirectory(prefix="artifact-cleanup-act-") as tmp:
        _copy_project_to(tmp)
        _init_git(tmp)

        print(f"  Temp repo: {tmp}")
        print("  Running act push --rm (this may take 1-3 minutes)...")

        exit_code, output = run_act(tmp)

        delim = "\n" + "=" * 60 + "\n"
        section = (
            f"{delim}ACT RUN: all 5 test cases (exit code {exit_code}){delim}"
            + output
            + delim
        )

        # Append to act-result.txt
        with open(RESULT_FILE, "a") as fh:
            fh.write(section)

        print(f"  act exit code: {exit_code}")

        if exit_code != 0:
            all_failures.append(f"act push exited with code {exit_code}")
            print("  FAIL: non-zero exit code — see act-result.txt for details")
        else:
            print("  PASS: act exited 0")

        # Assert "Job succeeded" appears
        for phrase in PYTEST_ASSERTIONS:
            if phrase in output:
                print(f"  PASS: found '{phrase}'")
            else:
                msg = f"Expected to find '{phrase}' in act output"
                all_failures.append(msg)
                print(f"  FAIL: {msg}")

        # Per-test-case exact assertions
        print()
        print("  Per-test-case assertions:")
        for tc in TC_ASSERTIONS:
            tc_failures = []
            for s in tc["strings"]:
                if s not in output:
                    tc_failures.append(s)
            if tc_failures:
                for s in tc_failures:
                    msg = f"{tc['name']}: expected string not found: '{s}'"
                    all_failures.append(msg)
                    print(f"    FAIL: {msg}")
            else:
                print(f"    PASS: {tc['name']}")

    # -----------------------------------------------------------------------
    # Summary
    # -----------------------------------------------------------------------
    print()
    print("=" * 60)
    if all_failures:
        print(f"RESULT: {len(all_failures)} FAILURE(S)")
        for f in all_failures:
            print(f"  - {f}")
        print(f"\nFull act output saved to: {RESULT_FILE}")
        return 1
    else:
        print("RESULT: ALL TESTS PASSED")
        print(f"Full act output saved to: {RESULT_FILE}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
