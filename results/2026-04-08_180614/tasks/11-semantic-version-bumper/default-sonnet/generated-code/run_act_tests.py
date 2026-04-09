#!/usr/bin/env python3
"""
Act test harness for the semantic version bumper.

Runs each test case through the GitHub Actions workflow via `act`, captures the
output, and asserts on EXACT expected values.  All output is appended to
act-result.txt in the current working directory.

Usage:
    python run_act_tests.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import List

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).parent.resolve()
RESULT_FILE = SCRIPT_DIR / "act-result.txt"

# ---------------------------------------------------------------------------
# Test case definition
# ---------------------------------------------------------------------------

@dataclass
class ActTestCase:
    name: str
    initial_version: str          # version in package.json before the bump
    commits: List[str]            # conventional commit messages to add to the repo
    expected_version: str         # exact version string the workflow must output
    expected_bump: str            # 'patch', 'minor', or 'major'


# ---------------------------------------------------------------------------
# Test cases — one per fixture scenario
# ---------------------------------------------------------------------------

TEST_CASES: List[ActTestCase] = [
    ActTestCase(
        name="patch_bump_fix_only",
        initial_version="1.0.0",
        commits=[
            "fix: correct null pointer exception",
            "fix(auth): handle expired JWT tokens",
        ],
        expected_version="1.0.1",
        expected_bump="patch",
    ),
    ActTestCase(
        name="minor_bump_feat",
        initial_version="1.1.0",
        commits=[
            "feat: add dark mode support",
            "fix: typo in error message",
        ],
        expected_version="1.2.0",
        expected_bump="minor",
    ),
    ActTestCase(
        name="major_bump_breaking_excl",
        initial_version="1.1.0",
        commits=[
            "feat!: redesign authentication API",
            "feat: add OAuth support",
        ],
        expected_version="2.0.0",
        expected_bump="major",
    ),
    ActTestCase(
        name="major_bump_breaking_body",
        initial_version="2.0.0",
        commits=[
            "feat: overhaul config system\n\nBREAKING CHANGE: config.yml format changed",
        ],
        expected_version="3.0.0",
        expected_bump="major",
    ),
    ActTestCase(
        name="mixed_commits_minor_wins",
        initial_version="1.0.0",
        commits=[
            "fix: reduce memory usage",
            "feat: add caching layer",
            "chore: bump deps",
        ],
        expected_version="1.1.0",
        expected_bump="minor",
    ),
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(cmd: list, cwd=None, check=True, **kwargs):
    """Thin subprocess wrapper with sensible defaults."""
    return subprocess.run(
        cmd, cwd=cwd, check=check, capture_output=True, text=True, **kwargs
    )


def _git(args: list, cwd):
    return _run(["git"] + args, cwd=cwd)


def setup_repo(tc: ActTestCase, tmpdir: Path) -> None:
    """Create an isolated git repo containing all project files + fixture commits."""

    # Copy project files into the temp repo
    for src in [
        SCRIPT_DIR / "version_bumper.py",
        SCRIPT_DIR / "test_version_bumper.py",
    ]:
        shutil.copy(src, tmpdir / src.name)

    # Copy fixture directory
    shutil.copytree(SCRIPT_DIR / "fixtures", tmpdir / "fixtures")

    # Copy workflow file
    wf_dir = tmpdir / ".github" / "workflows"
    wf_dir.mkdir(parents=True)
    shutil.copy(
        SCRIPT_DIR / ".github" / "workflows" / "semantic-version-bumper.yml",
        wf_dir / "semantic-version-bumper.yml",
    )

    # Write package.json with the test case's initial version
    pkg = {"name": "test-pkg", "version": tc.initial_version}
    (tmpdir / "package.json").write_text(json.dumps(pkg, indent=2) + "\n")

    # Initialise git
    _git(["init", "--initial-branch=main"], cwd=tmpdir)
    _git(["config", "user.email", "test@ci.local"], cwd=tmpdir)
    _git(["config", "user.name", "CI Test"], cwd=tmpdir)

    # Initial commit (tagged as the "previous release" so that the bumper
    # only analyses the fixture commits that follow)
    _git(["add", "-A"], cwd=tmpdir)
    _git(["commit", "-m", "chore: initial project setup"], cwd=tmpdir)
    _git(["tag", f"v{tc.initial_version}"], cwd=tmpdir)

    # Add the fixture commits
    for i, msg in enumerate(tc.commits):
        marker = tmpdir / "changes.txt"
        marker.write_text(f"change {i}\n")
        _git(["add", "changes.txt"], cwd=tmpdir)
        _git(["commit", "-m", msg], cwd=tmpdir)


def run_act(tmpdir: Path) -> tuple[int, str]:
    """Run `act push --rm` in *tmpdir* and return (exit_code, combined_output)."""
    cmd = [
        "act", "push",
        "--rm",
        "--container-architecture", "linux/amd64",
        "-W", ".github/workflows/semantic-version-bumper.yml",
    ]
    result = subprocess.run(
        cmd,
        cwd=tmpdir,
        capture_output=True,
        text=True,
    )
    combined = result.stdout + result.stderr
    return result.returncode, combined


# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

def assert_exit_zero(exit_code: int, output: str, tc: ActTestCase) -> None:
    if exit_code != 0:
        raise AssertionError(
            f"[{tc.name}] act exited with code {exit_code}.\n"
            f"Output (last 40 lines):\n"
            + "\n".join(output.splitlines()[-40:])
        )


def assert_version_in_output(exit_code: int, output: str, tc: ActTestCase) -> None:
    needle = tc.expected_version
    if needle not in output:
        raise AssertionError(
            f"[{tc.name}] Expected version '{needle}' not found in act output.\n"
            f"Output (last 40 lines):\n"
            + "\n".join(output.splitlines()[-40:])
        )


def assert_job_succeeded(exit_code: int, output: str, tc: ActTestCase) -> None:
    if "Job succeeded" not in output:
        raise AssertionError(
            f"[{tc.name}] 'Job succeeded' not found in act output.\n"
            f"Output (last 40 lines):\n"
            + "\n".join(output.splitlines()[-40:])
        )


# ---------------------------------------------------------------------------
# Main test runner
# ---------------------------------------------------------------------------

def run_all_tests() -> None:
    # Truncate the result file at the start of each full run
    RESULT_FILE.write_text("")

    total = len(TEST_CASES)
    passed = 0
    failed = 0

    for tc in TEST_CASES:
        header = f"{'=' * 60}\nTEST CASE: {tc.name}\n{'=' * 60}"
        print(header)
        RESULT_FILE.open("a").write(header + "\n")

        with tempfile.TemporaryDirectory(prefix="semver-test-") as tmp:
            tmpdir = Path(tmp)

            # ---- Setup ----
            try:
                setup_repo(tc, tmpdir)
            except subprocess.CalledProcessError as exc:
                msg = f"SKIP: repo setup failed — {exc}\n{exc.stderr}"
                print(msg)
                RESULT_FILE.open("a").write(msg + "\n")
                failed += 1
                continue

            # ---- Run act ----
            exit_code, output = run_act(tmpdir)

            # Append full output to result file
            RESULT_FILE.open("a").write(f"--- act output ---\n{output}\n")

            # ---- Assertions ----
            errors = []
            for assertion in (assert_exit_zero, assert_version_in_output, assert_job_succeeded):
                try:
                    assertion(exit_code, output, tc)
                except AssertionError as exc:
                    errors.append(str(exc))

            if errors:
                result_line = "FAIL\n" + "\n".join(errors)
                failed += 1
            else:
                result_line = (
                    f"PASS\n"
                    f"  act exit code : 0\n"
                    f"  expected ver  : {tc.expected_version!r}  ← found in output\n"
                    f"  Job succeeded : yes"
                )
                passed += 1

            print(result_line)
            RESULT_FILE.open("a").write(result_line + "\n\n")

    # ---- Summary ----
    summary = (
        f"\n{'=' * 60}\n"
        f"RESULTS: {passed}/{total} passed, {failed}/{total} failed\n"
        f"{'=' * 60}\n"
    )
    print(summary)
    RESULT_FILE.open("a").write(summary)

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    run_all_tests()
