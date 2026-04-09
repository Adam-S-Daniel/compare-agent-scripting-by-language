#!/usr/bin/env python3
"""
Act Test Harness for Secret Rotation Validator
===============================================

Runs the GitHub Actions workflow via `act` for each test case and asserts on:
  1. act exit code == 0  (all jobs succeeded)
  2. Exact expected strings appear in the act output
  3. "Job succeeded" appears in the output

Also runs workflow-structure checks without invoking act:
  - YAML parses correctly and has required triggers / jobs / steps
  - Referenced script / fixture files exist on disk
  - actionlint exits with code 0

All act output is appended to act-result.txt in the current working directory.

Usage:
    python3 run_act_tests.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths and configuration
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).parent.resolve()
RESULT_FILE = PROJECT_ROOT / "act-result.txt"
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "secret-rotation-validator.yml"

# Platform image — already pulled, so act won't need to download it
ACT_PLATFORM = "ubuntu-latest=catthehacker/ubuntu:act-22.04"

# Files that must be present in every temp repo
PROJECT_FILES = [
    "secret_rotation_validator.py",
    "conftest.py",
    "requirements.txt",
    "tests/__init__.py",
    "tests/test_validator.py",
    ".github/workflows/secret-rotation-validator.yml",
]

# ---------------------------------------------------------------------------
# Fixture data (reference date = 2024-01-15 for all cases)
# ---------------------------------------------------------------------------

FIXTURE_ALL_OK = [
    # 1 day since rotation,  89 days until expiry  →  ok
    {"name": "fresh-key",   "last_rotated": "2024-01-14", "rotation_days": 90, "required_by": ["service-a"]},
    # 5 days since rotation, 85 days until expiry  →  ok
    {"name": "fresh-token", "last_rotated": "2024-01-10", "rotation_days": 90, "required_by": ["service-b"]},
]

FIXTURE_EXPIRED = [
    # 136 days since rotation, -46 days until expiry  →  expired
    {"name": "old-db-password", "last_rotated": "2023-09-01", "rotation_days": 90, "required_by": ["backend-api"]},
]

FIXTURE_WARNING = [
    # 26 days since rotation, 4 days until expiry  →  warning
    {"name": "expiring-api-key", "last_rotated": "2023-12-20", "rotation_days": 30, "required_by": ["frontend"]},
]

FIXTURE_MIXED = [
    {"name": "db-password",  "last_rotated": "2023-09-01", "rotation_days": 90, "required_by": ["backend-api", "worker"]},
    {"name": "api-key",      "last_rotated": "2023-12-20", "rotation_days": 30, "required_by": ["frontend"]},
    {"name": "jwt-secret",   "last_rotated": "2024-01-01", "rotation_days": 90, "required_by": ["auth-service"]},
]

# ---------------------------------------------------------------------------
# Test cases — each specifies fixture data and exact strings to assert
# ---------------------------------------------------------------------------

TEST_CASES = [
    {
        "name": "test_all_ok_markdown",
        "description": "All secrets are fresh — no expired or warnings",
        "fixture": FIXTURE_ALL_OK,
        "expected_strings": [
            "**Expired:** 0",
            "**Warning:** 0",
            "**OK:** 2",
            "fresh-key",
            "fresh-token",
        ],
    },
    {
        "name": "test_expired_markdown",
        "description": "One expired secret appears in the EXPIRED section",
        "fixture": FIXTURE_EXPIRED,
        "expected_strings": [
            "**Expired:** 1",
            "**Warning:** 0",
            "**OK:** 0",
            "old-db-password",
            "## EXPIRED (1)",
            "OVERDUE",
        ],
    },
    {
        "name": "test_warning_markdown",
        "description": "One near-expiry secret appears in the WARNING section",
        "fixture": FIXTURE_WARNING,
        "expected_strings": [
            "**Expired:** 0",
            "**Warning:** 1",
            "**OK:** 0",
            "expiring-api-key",
            "## WARNING (1)",
        ],
    },
    {
        "name": "test_mixed_json",
        "description": "Mixed secrets with JSON output — verify exact counts",
        "fixture": FIXTURE_MIXED,
        "expected_strings": [
            '"total": 3',
            '"expired": 1',
            '"warning": 1',
            '"ok": 1',
            "db-password",
            "api-key",
            "jwt-secret",
        ],
    },
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def strip_ansi(text: str) -> str:
    """Remove ANSI escape codes so string searches work reliably."""
    return re.sub(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])", "", text)


def write_result(text: str) -> None:
    """Append text to act-result.txt."""
    with open(RESULT_FILE, "a") as fh:
        fh.write(text)


def setup_temp_repo(fixture_data: list) -> Path:
    """
    Create a temporary git repository populated with all project files and
    the given fixture written to fixtures/secrets_config.json.
    """
    tmpdir = Path(tempfile.mkdtemp(prefix="act-test-"))

    # Copy project files into the temp repo
    for rel_path in PROJECT_FILES:
        src = PROJECT_ROOT / rel_path
        dst = tmpdir / rel_path
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Write test fixture as the default secrets file for the workflow
    fixtures_dir = tmpdir / "fixtures"
    fixtures_dir.mkdir(exist_ok=True)
    (fixtures_dir / "secrets_config.json").write_text(
        json.dumps(fixture_data, indent=2)
    )

    # Initialise git repo (act requires a git repo to simulate push events)
    def git(*args):
        subprocess.run(["git", *args], cwd=tmpdir, check=True, capture_output=True)

    git("init")
    git("symbolic-ref", "HEAD", "refs/heads/main")   # default branch = main
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test Runner")
    git("add", "-A")
    git("commit", "-m", "Initial commit")

    return tmpdir


def run_act(tmpdir: Path) -> tuple[int, str]:
    """Run `act push --rm` in tmpdir and return (exit_code, combined_output)."""
    cmd = [
        "act", "push",
        "--rm",
        "-P", ACT_PLATFORM,
        "--pull=false",    # image is already cached locally
    ]
    result = subprocess.run(
        cmd,
        cwd=tmpdir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=600,
    )
    return result.returncode, strip_ansi(result.stdout)


# ---------------------------------------------------------------------------
# Workflow structure tests (no act required)
# ---------------------------------------------------------------------------

def test_workflow_structure() -> list[str]:
    """
    Parse the workflow YAML and verify required triggers, jobs, and steps.
    Returns a list of failure messages (empty = all checks passed).
    """
    failures = []

    try:
        import yaml  # PyYAML
    except ImportError:
        # Fall back to a regex-based check if PyYAML is not installed
        text = WORKFLOW_PATH.read_text()
        checks = [
            ("push trigger",             "push:" in text or "push:\n" in text),
            ("pull_request trigger",     "pull_request" in text),
            ("schedule trigger",         "schedule:" in text),
            ("workflow_dispatch trigger","workflow_dispatch" in text),
            ("test job",                 "test:" in text),
            ("validate-markdown job",    "validate-markdown:" in text),
            ("validate-json job",        "validate-json:" in text),
            ("actions/checkout@v4",      "actions/checkout@v4" in text),
            ("actions/setup-python",     "actions/setup-python" in text),
            ("script reference",         "secret_rotation_validator.py" in text),
            ("fixture reference",        "fixtures/secrets_config.json" in text),
        ]
        for name, ok in checks:
            if not ok:
                failures.append(f"Workflow missing: {name}")
        return failures

    wf = yaml.safe_load(WORKFLOW_PATH.read_text())

    # PyYAML parses the bare YAML key `on` as boolean True — handle both forms
    triggers = wf.get("on", wf.get(True, {}))
    for trig in ("push", "pull_request", "schedule", "workflow_dispatch"):
        if trig not in triggers:
            failures.append(f"Missing trigger: {trig}")

    # Jobs
    jobs = wf.get("jobs", {})
    for job in ("test", "validate-markdown", "validate-json"):
        if job not in jobs:
            failures.append(f"Missing job: {job}")

    # validate-* jobs depend on test
    for job in ("validate-markdown", "validate-json"):
        needs = jobs.get(job, {}).get("needs", [])
        if isinstance(needs, str):
            needs = [needs]
        if "test" not in needs:
            failures.append(f"Job '{job}' should depend on 'test'")

    # Script file referenced in workflow steps exists on disk
    for job_def in jobs.values():
        for step in job_def.get("steps", []):
            run_script = step.get("run", "")
            if "secret_rotation_validator.py" in run_script:
                if not (PROJECT_ROOT / "secret_rotation_validator.py").exists():
                    failures.append("secret_rotation_validator.py not found on disk")
                break

    return failures


def test_referenced_files_exist() -> list[str]:
    """Verify all files the workflow references actually exist."""
    failures = []
    required = [
        PROJECT_ROOT / "secret_rotation_validator.py",
        PROJECT_ROOT / "fixtures" / "secrets_config.json",
        PROJECT_ROOT / "requirements.txt",
        PROJECT_ROOT / "tests" / "test_validator.py",
    ]
    for path in required:
        if not path.exists():
            failures.append(f"Required file missing: {path.relative_to(PROJECT_ROOT)}")
    return failures


def test_actionlint() -> tuple[int, str]:
    """Run actionlint on the workflow file and return (exit_code, output)."""
    result = subprocess.run(
        ["actionlint", str(WORKFLOW_PATH)],
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout + result.stderr


# ---------------------------------------------------------------------------
# Main test runner
# ---------------------------------------------------------------------------

def main() -> int:
    # Start fresh
    RESULT_FILE.unlink(missing_ok=True)

    total_failures = 0

    # -----------------------------------------------------------------------
    # Section A: Workflow structure tests
    # -----------------------------------------------------------------------
    write_result("=" * 70 + "\n")
    write_result("SECTION A: Workflow Structure Tests\n")
    write_result("=" * 70 + "\n\n")

    print("=== Section A: Workflow Structure Tests ===")

    # A1: structure check
    struct_failures = test_workflow_structure()
    if struct_failures:
        for f in struct_failures:
            msg = f"  FAIL: {f}\n"
            print(msg, end="")
            write_result(msg)
        total_failures += len(struct_failures)
    else:
        msg = "  PASS: workflow structure (triggers, jobs, dependencies)\n"
        print(msg, end="")
        write_result(msg)

    # A2: referenced files exist
    file_failures = test_referenced_files_exist()
    if file_failures:
        for f in file_failures:
            msg = f"  FAIL: {f}\n"
            print(msg, end="")
            write_result(msg)
        total_failures += len(file_failures)
    else:
        msg = "  PASS: all referenced files exist on disk\n"
        print(msg, end="")
        write_result(msg)

    # A3: actionlint
    lint_code, lint_output = test_actionlint()
    write_result(f"\n--- actionlint output ---\n{lint_output or '(no output)'}\n")
    if lint_code != 0:
        msg = f"  FAIL: actionlint exited {lint_code}\n"
        print(msg, end="")
        write_result(msg)
        total_failures += 1
    else:
        msg = "  PASS: actionlint (exit code 0)\n"
        print(msg, end="")
        write_result(msg)

    write_result("\n")

    # -----------------------------------------------------------------------
    # Section B: Act execution tests
    # -----------------------------------------------------------------------
    write_result("=" * 70 + "\n")
    write_result("SECTION B: Act Execution Tests\n")
    write_result("=" * 70 + "\n\n")

    print("\n=== Section B: Act Execution Tests ===")

    for tc in TEST_CASES:
        name = tc["name"]
        print(f"\n--- {name}: {tc['description']} ---")
        write_result(f"{'=' * 70}\n")
        write_result(f"TEST CASE: {name}\n")
        write_result(f"Description: {tc['description']}\n")
        write_result(f"Fixture: {json.dumps(tc['fixture'], indent=2)}\n\n")

        # Set up isolated temp repo
        tmpdir = setup_temp_repo(tc["fixture"])
        case_failures = 0

        try:
            print(f"  Running act push --rm in {tmpdir} ...")
            exit_code, output = run_act(tmpdir)

            write_result(f"--- act output ---\n{output}\n\n")

            # Assertion 1: exit code must be 0
            if exit_code == 0:
                write_result("ASSERT exit_code == 0: PASS\n")
                print("  PASS: act exited with code 0")
            else:
                write_result(f"ASSERT exit_code == 0: FAIL (got {exit_code})\n")
                print(f"  FAIL: act exited with code {exit_code}")
                case_failures += 1

            # Assertion 2: "Job succeeded" appears for each job
            job_succeeded_count = output.lower().count("job succeeded")
            if job_succeeded_count >= 3:
                write_result(f"ASSERT 'Job succeeded' x3: PASS ({job_succeeded_count} occurrences)\n")
                print(f"  PASS: found 'Job succeeded' {job_succeeded_count} times")
            else:
                write_result(f"ASSERT 'Job succeeded' x3: FAIL (found {job_succeeded_count})\n")
                print(f"  FAIL: expected 3 'Job succeeded', got {job_succeeded_count}")
                case_failures += 1

            # Assertion 3: exact expected strings
            for expected in tc["expected_strings"]:
                if expected in output:
                    write_result(f"ASSERT '{expected}': PASS\n")
                    print(f"  PASS: found expected string: {expected!r}")
                else:
                    write_result(f"ASSERT '{expected}': FAIL (not found in output)\n")
                    print(f"  FAIL: expected string not found: {expected!r}")
                    case_failures += 1

        except subprocess.TimeoutExpired:
            write_result("ERROR: act timed out after 600s\n")
            print("  ERROR: act timed out")
            case_failures += 1
        except Exception as exc:
            write_result(f"ERROR: {exc}\n")
            print(f"  ERROR: {exc}")
            case_failures += 1
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)

        if case_failures == 0:
            write_result(f"\nRESULT: PASS (all assertions passed)\n\n")
            print(f"  RESULT: PASS")
        else:
            write_result(f"\nRESULT: FAIL ({case_failures} assertion(s) failed)\n\n")
            print(f"  RESULT: FAIL ({case_failures} failures)")
            total_failures += case_failures

    # -----------------------------------------------------------------------
    # Final summary
    # -----------------------------------------------------------------------
    summary = (
        f"\n{'=' * 70}\n"
        f"FINAL RESULT: {'PASS' if total_failures == 0 else 'FAIL'} "
        f"({total_failures} total failure(s))\n"
        f"{'=' * 70}\n"
    )
    write_result(summary)
    print(summary)

    return 0 if total_failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
