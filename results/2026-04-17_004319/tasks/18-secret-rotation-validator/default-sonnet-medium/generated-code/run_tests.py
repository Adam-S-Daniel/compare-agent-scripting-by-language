#!/usr/bin/env python3
"""
Test harness: runs each test case through the GitHub Actions workflow via `act`.

For each test case we:
1. Set up a fresh temp git repo with all project files
2. Replace fixtures/default_config.json with the test case's fixture
3. Run: act push --rm  (uses .actrc from this dir for image config)
4. Append the full output to act-result.txt with clear delimiters
5. Assert exit code 0 and "Job succeeded"
6. Assert exact expected values in the output

Usage:
  python3 run_tests.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

WORKSPACE = Path(__file__).parent.resolve()
RESULT_FILE = WORKSPACE / "act-result.txt"

# Files to copy into each temp repo (relative to WORKSPACE)
FILES_TO_COPY = [
    "secret_rotation_validator.py",
    "test_secret_rotation_validator.py",
    ".actrc",
    ".github/workflows/secret-rotation-validator.yml",
    "fixtures/default_config.json",
    "fixtures/all_ok_config.json",
    "fixtures/all_expired_config.json",
]


def strip_ansi(text: str) -> str:
    """Remove ANSI escape codes from act output for clean string matching."""
    return re.sub(r"\x1b\[[0-9;]*[mKHF]", "", text)


def setup_temp_repo(fixture_override: str | None = None) -> Path:
    """Create a temp git repo with project files and an optional fixture swap.

    fixture_override: path (relative to WORKSPACE) to copy over
                      fixtures/default_config.json, or None to keep default.
    """
    tmpdir = Path(tempfile.mkdtemp(prefix="secret-rotation-test-"))

    # Copy all project files maintaining directory structure
    for rel in FILES_TO_COPY:
        src = WORKSPACE / rel
        dst = tmpdir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)

    # Optionally swap out the default config with a test-case fixture
    if fixture_override:
        shutil.copy2(
            WORKSPACE / fixture_override,
            tmpdir / "fixtures" / "default_config.json",
        )

    # Initialise a git repo so `act push` sees a real commit
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "ci@test.local"],
        ["git", "config", "user.name", "CI Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "ci: initial commit for act test"],
    ]:
        subprocess.run(cmd, cwd=tmpdir, check=True, capture_output=True)

    return tmpdir


def run_act(tmpdir: Path, test_name: str) -> tuple[int, str]:
    """Run `act push --rm` in tmpdir and return (exit_code, stripped_output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    output = strip_ansi(result.stdout + result.stderr)
    return result.returncode, output


def write_result(test_name: str, output: str, exit_code: int) -> None:
    """Append a test case's act output to act-result.txt."""
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{'='*70}\n")
        f.write(f"TEST CASE: {test_name}\n")
        f.write(f"EXIT CODE: {exit_code}\n")
        f.write(f"{'='*70}\n")
        f.write(output)
        f.write(f"\n{'='*70}\n")


def assert_job_succeeded(output: str, test_name: str) -> None:
    """Assert the workflow job shows success."""
    assert "Job succeeded" in output, (
        f"[{test_name}] Expected 'Job succeeded' in act output.\n"
        f"Last 50 lines:\n" + "\n".join(output.splitlines()[-50:])
    )


def run_test_case(
    test_name: str,
    fixture_override: str | None,
    assertions: list,
) -> None:
    """Run one act test case and apply assertions to its output."""
    print(f"\n--- Running: {test_name} ---")
    tmpdir = setup_temp_repo(fixture_override)
    try:
        exit_code, output = run_act(tmpdir, test_name)
        write_result(test_name, output, exit_code)
        assert exit_code == 0, (
            f"[{test_name}] act exited with code {exit_code}\n"
            f"Last 80 lines:\n" + "\n".join(output.splitlines()[-80:])
        )
        assert_job_succeeded(output, test_name)
        for label, check in assertions:
            assert check(output), (
                f"[{test_name}] Assertion failed: {label}\n"
                f"Last 80 lines:\n" + "\n".join(output.splitlines()[-80:])
            )
        print(f"    PASSED: {test_name}")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def main() -> int:
    # Clear previous results
    RESULT_FILE.write_text("")
    failures: list[str] = []

    test_cases = [
        # Test case 1: default fixture — mixed expired/warning/ok
        # Expected: DB_PASSWORD expired, API_KEY+OAUTH_SECRET warning, TLS_CERT ok
        (
            "test_case_1_mixed",
            None,  # use default_config.json
            [
                ("pytest passes", lambda o: "passed" in o and "failed" not in o.split("passed")[0].rsplit("\n", 1)[-1]),
                ("DB_PASSWORD in expired", lambda o: '"DB_PASSWORD"' in o or "DB_PASSWORD" in o),
                ("API_KEY present", lambda o: "API_KEY" in o),
                ("TLS_CERT present", lambda o: "TLS_CERT" in o),
                ("OAUTH_SECRET present", lambda o: "OAUTH_SECRET" in o),
                # Exact value: 10 days overdue for DB_PASSWORD
                ("DB_PASSWORD 10 days overdue", lambda o: '"days_overdue": 10' in o or "10 days overdue" in o),
                # Exact value: 7 days remaining for API_KEY
                ("API_KEY 7 days remaining", lambda o: '"days_remaining": 7' in o or "7 days remaining" in o),
                # Exact value: 355 days remaining for TLS_CERT
                ("TLS_CERT 355 days remaining", lambda o: '"days_remaining": 355' in o or "355 days remaining" in o),
            ],
        ),
        # Test case 2: all_ok fixture — no expired or warning secrets
        (
            "test_case_2_all_ok",
            "fixtures/all_ok_config.json",
            [
                ("DB_PASSWORD ok", lambda o: "DB_PASSWORD" in o),
                ("API_KEY ok", lambda o: "API_KEY" in o),
                # No expired entries: expired array should be empty
                ('"expired": []', lambda o: '"expired": []' in o),
                # No warning entries
                ('"warning": []', lambda o: '"warning": []' in o),
                # DB_PASSWORD has 72 days remaining
                ("DB_PASSWORD 72 days remaining", lambda o: '"days_remaining": 72' in o or "72 days remaining" in o),
            ],
        ),
        # Test case 3: all_expired fixture — both secrets overdue
        (
            "test_case_3_all_expired",
            "fixtures/all_expired_config.json",
            [
                ("LEGACY_TOKEN present", lambda o: "LEGACY_TOKEN" in o),
                ("OLD_API_KEY present", lambda o: "OLD_API_KEY" in o),
                # No ok entries
                ('"ok": []', lambda o: '"ok": []' in o),
                # No warning entries
                ('"warning": []', lambda o: '"warning": []' in o),
                # LEGACY_TOKEN 78 days overdue
                ("LEGACY_TOKEN 78 days overdue", lambda o: '"days_overdue": 78' in o or "78 days overdue" in o),
                # OLD_API_KEY 47 days overdue
                ("OLD_API_KEY 47 days overdue", lambda o: '"days_overdue": 47' in o or "47 days overdue" in o),
            ],
        ),
    ]

    for test_name, fixture_override, assertions in test_cases:
        try:
            run_test_case(test_name, fixture_override, assertions)
        except AssertionError as e:
            print(f"    FAILED: {test_name}\n    {e}")
            failures.append(test_name)

    print(f"\n{'='*50}")
    print(f"Results: {len(test_cases) - len(failures)}/{len(test_cases)} passed")
    if failures:
        print(f"Failed: {failures}")
        return 1
    print("All act test cases passed!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
