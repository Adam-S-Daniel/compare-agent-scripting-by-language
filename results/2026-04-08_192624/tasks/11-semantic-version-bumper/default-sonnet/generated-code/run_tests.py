#!/usr/bin/env python3
"""
Test harness for the semantic version bumper.

For each test case this script:
  1. Creates an isolated temp git repository.
  2. Copies project files (bumper.py, test_bumper.py, workflow) into it.
  3. Seeds a package.json with the case's initial version and a fixtures/commits.txt
     with mock commit messages.
  4. Runs `act push --rm` inside that repo and captures all output.
  5. Appends the output (clearly delimited) to act-result.txt in the original CWD.
  6. Asserts act exited with code 0 and the output contains the expected new version.
  7. Asserts every job shows "Job succeeded".

All failures are collected; the script exits non-zero if any case fails.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, NamedTuple, Optional

# ─── Project root (where this script lives) ───────────────────────────────────

PROJECT_DIR = Path(__file__).parent.resolve()

# Output file written to the original CWD
ACT_RESULT_FILE = PROJECT_DIR / "act-result.txt"


# ─── Test-case definitions ─────────────────────────────────────────────────────

class TestCase(NamedTuple):
    name: str
    description: str
    initial_version: str
    commits: List[str]          # one mock commit message per entry
    expected_version: str       # exact string that must appear in act output


TEST_CASES: List[TestCase] = [
    TestCase(
        name="patch-bump",
        description="fix commits only → patch bump",
        initial_version="1.0.0",
        commits=[
            "fix: resolve null pointer exception",
            "fix(ui): correct button alignment",
            "chore: update dependencies",
        ],
        expected_version="1.0.1",
    ),
    TestCase(
        name="minor-bump",
        description="feat commit → minor bump (overrides fix)",
        initial_version="1.0.0",
        commits=[
            "feat: add new dashboard",
            "fix: minor bug fix",
        ],
        expected_version="1.1.0",
    ),
    TestCase(
        name="major-bump",
        description="breaking-change commit → major bump",
        initial_version="1.0.0",
        commits=[
            "feat!: redesign API interface",
            "fix: minor correction",
        ],
        expected_version="2.0.0",
    ),
    TestCase(
        name="no-bump",
        description="non-conventional commits → version unchanged",
        initial_version="1.2.3",
        commits=[
            "chore: update dependencies",
            "docs: update readme",
            "ci: fix workflow",
        ],
        expected_version="1.2.3",
    ),
    TestCase(
        name="minor-overrides-patch",
        description="feat + fix together → minor wins",
        initial_version="1.1.0",
        commits=[
            "feat: add user profile page",
            "fix: fix login timeout",
        ],
        expected_version="1.2.0",
    ),
]


# ─── Helpers ──────────────────────────────────────────────────────────────────

def run(cmd: List[str], cwd: Optional[str] = None, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command, optionally raising on failure."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


def setup_temp_repo(case: TestCase) -> Path:
    """
    Create a temporary git repository pre-loaded with project files and
    fixture data for the given test case.

    Structure:
        <tmp>/
          bumper.py              ← copied from PROJECT_DIR
          test_bumper.py         ← copied from PROJECT_DIR
          package.json           ← seeds initial_version
          fixtures/
            commits.txt          ← mock commit messages (one per line)
          .github/workflows/
            semantic-version-bumper.yml  ← copied from PROJECT_DIR
    """
    tmp = Path(tempfile.mkdtemp(prefix=f"act-test-{case.name}-"))

    # ── git init ──────────────────────────────────────────────────────────────
    run(["git", "init", "-b", "main"], cwd=str(tmp))
    run(["git", "config", "user.email", "ci@test.local"], cwd=str(tmp))
    run(["git", "config", "user.name", "CI Test"], cwd=str(tmp))

    # ── Copy project files ────────────────────────────────────────────────────
    shutil.copy2(PROJECT_DIR / "bumper.py",      tmp / "bumper.py")
    shutil.copy2(PROJECT_DIR / "test_bumper.py", tmp / "test_bumper.py")

    workflow_src = PROJECT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml"
    workflow_dst = tmp / ".github" / "workflows"
    workflow_dst.mkdir(parents=True)
    shutil.copy2(workflow_src, workflow_dst / "semantic-version-bumper.yml")

    # ── Seed package.json ─────────────────────────────────────────────────────
    pkg = {"name": "test-project", "version": case.initial_version, "private": True}
    (tmp / "package.json").write_text(json.dumps(pkg, indent=2) + "\n")

    # ── Fixture: commits.txt (one commit message per line) ────────────────────
    fixtures_dir = tmp / "fixtures"
    fixtures_dir.mkdir()
    (fixtures_dir / "commits.txt").write_text("\n".join(case.commits) + "\n")

    # ── Initial commit so git is happy ────────────────────────────────────────
    run(["git", "add", "."], cwd=str(tmp))
    run(["git", "commit", "-m", "chore: initial project setup"], cwd=str(tmp))

    return tmp


def run_act(repo_dir: Path) -> subprocess.CompletedProcess:
    """
    Execute `act push --rm` inside repo_dir and return the completed process.
    stdout+stderr are captured but NOT checked here — caller decides pass/fail.
    """
    return subprocess.run(
        [
            "act", "push",
            "--rm",
            "--no-cache-server",
            # Use the pre-pulled image to avoid network fetches
            "-P", "ubuntu-latest=catthehacker/ubuntu:act-latest",
        ],
        cwd=str(repo_dir),
        capture_output=True,
        text=True,
        timeout=300,   # 5 min safety net
    )


def check_assertions(case: TestCase, result: subprocess.CompletedProcess) -> List[str]:
    """
    Return a list of failure messages.  Empty list means all assertions passed.
    """
    failures: List[str] = []
    combined = result.stdout + result.stderr

    # 1. Exit code 0
    if result.returncode != 0:
        failures.append(f"act exited with code {result.returncode} (expected 0)")

    # 2. Expected new version present in output
    expected_tag = f"NEW_VERSION={case.expected_version}"
    if expected_tag not in combined:
        failures.append(
            f"Expected '{expected_tag}' in output, not found.\n"
            f"  (searched stdout+stderr for exact match)"
        )

    # 3. "Job succeeded" present
    if "Job succeeded" not in combined:
        failures.append("Expected 'Job succeeded' in act output, not found")

    return failures


# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    print(f"Running {len(TEST_CASES)} test case(s) through act…\n")

    # Truncate the result file for this run
    ACT_RESULT_FILE.write_text(
        f"=== act-result.txt — Semantic Version Bumper Test Run ===\n\n"
    )

    all_passed = True

    for idx, case in enumerate(TEST_CASES, start=1):
        print(f"[{idx}/{len(TEST_CASES)}] {case.name}: {case.description}")

        repo_dir = setup_temp_repo(case)

        try:
            print(f"  → Running act in {repo_dir} …", flush=True)
            result = run_act(repo_dir)
        except subprocess.TimeoutExpired:
            result = subprocess.CompletedProcess(
                args=[], returncode=1,
                stdout="", stderr="act timed out after 300 s",
            )

        # ── Append to act-result.txt ──────────────────────────────────────────
        delimiter = "=" * 72
        with ACT_RESULT_FILE.open("a") as f:
            f.write(f"{delimiter}\n")
            f.write(f"TEST CASE {idx}: {case.name}\n")
            f.write(f"  description : {case.description}\n")
            f.write(f"  initial ver : {case.initial_version}\n")
            f.write(f"  expected ver: {case.expected_version}\n")
            f.write(f"  commits     : {case.commits}\n")
            f.write(f"{delimiter}\n")
            f.write("--- STDOUT ---\n")
            f.write(result.stdout or "(empty)\n")
            f.write("--- STDERR ---\n")
            f.write(result.stderr or "(empty)\n")
            f.write(f"--- EXIT CODE: {result.returncode} ---\n\n")

        # ── Assertions ────────────────────────────────────────────────────────
        failures = check_assertions(case, result)

        if failures:
            all_passed = False
            print(f"  ✗ FAILED:")
            for msg in failures:
                print(f"    • {msg}")
        else:
            print(f"  ✓ PASSED (NEW_VERSION={case.expected_version})")

        # ── Clean up temp repo ────────────────────────────────────────────────
        shutil.rmtree(repo_dir, ignore_errors=True)

        print()

    # ── Final summary ─────────────────────────────────────────────────────────
    with ACT_RESULT_FILE.open("a") as f:
        f.write("=" * 72 + "\n")
        status = "ALL PASSED" if all_passed else "SOME FAILED"
        f.write(f"OVERALL RESULT: {status}\n")
        f.write("=" * 72 + "\n")

    if all_passed:
        print("✓ All test cases passed.")
        print(f"Results written to: {ACT_RESULT_FILE}")
        return 0
    else:
        print("✗ One or more test cases FAILED.")
        print(f"Results written to: {ACT_RESULT_FILE}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
