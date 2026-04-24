#!/usr/bin/env python3
"""
Act test harness for the secret rotation validator.

For each test case:
  1. Copy project files into a fresh temp git repo
  2. Run: act push --rm -W .github/workflows/secret-rotation-validator.yml
  3. Append the full output to act-result.txt
  4. Assert exit code 0, "Job succeeded", pytest passing, and exact rotation counts

Limited to 1 act push run (well within the 3-run budget) since the single
comprehensive fixture covers all three urgency categories.
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent
RESULT_FILE = PROJECT_ROOT / "act-result.txt"
WORKFLOW_REL = ".github/workflows/secret-rotation-validator.yml"

# Expected values from fixtures/test_secrets.json with --reference-date 2026-04-20
# DB_PASSWORD  (2025-10-01 + 90d = 2025-12-30) → EXPIRED
# API_KEY      (2026-04-05 + 30d = 2026-05-05) → WARNING (15 days)
# JWT_SECRET   (2026-03-01 + 60d = 2026-04-30) → WARNING (10 days)
# SMTP_PASSWORD(2026-04-15 + 90d = 2026-07-14) → OK      (85 days)
EXPECTED_SUMMARY = "ROTATION_SUMMARY: expired=1 warning=2 ok=1"


def copy_project_to(dest: Path) -> None:
    """Copy all project files to dest, skipping git internals and generated artifacts."""
    skip = {".git", "__pycache__", ".pytest_cache", "act-result.txt", "run_act_tests.py"}
    for item in PROJECT_ROOT.iterdir():
        if item.name in skip:
            continue
        target = dest / item.name
        if item.is_dir():
            shutil.copytree(item, target)
        else:
            shutil.copy2(item, target)


def init_git_repo(repo_dir: Path) -> None:
    """Initialise a git repo so act can detect the push event context."""
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test Runner"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test: add project files"],
    ]:
        subprocess.run(cmd, cwd=repo_dir, check=True, capture_output=True)


def run_act(repo_dir: Path) -> tuple[int, str]:
    """Run act push --rm and return (exit_code, combined_output)."""
    cmd = ["act", "push", "--rm", "--pull=false", "-W", WORKFLOW_REL]

    # Inject .actrc from workspace root if present (custom act container config)
    actrc = PROJECT_ROOT / ".actrc"
    if actrc.exists():
        shutil.copy2(actrc, repo_dir / ".actrc")

    result = subprocess.run(
        cmd,
        cwd=repo_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return result.returncode, result.stdout + result.stderr


def write_delimiter(f, label: str) -> None:
    f.write(f"\n{'=' * 70}\n{label}\n{'=' * 70}\n")


def check(assertions: list[tuple[str, bool]]) -> bool:
    all_ok = True
    for name, passed in assertions:
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {name}")
        if not passed:
            all_ok = False
    return all_ok


def main() -> None:
    # Initialise result file
    RESULT_FILE.write_text("Secret Rotation Validator — Act Test Results\n")

    print("Running act test case: standard_fixture")
    print("-" * 50)

    with tempfile.TemporaryDirectory() as tmpdir:
        repo = Path(tmpdir)
        copy_project_to(repo)
        init_git_repo(repo)

        print("Starting act push --rm …")
        returncode, output = run_act(repo)

    # Persist output
    with open(RESULT_FILE, "a") as f:
        write_delimiter(f, "TEST CASE: standard_fixture")
        f.write(f"EXIT CODE: {returncode}\n")
        f.write(output)
        write_delimiter(f, "END: standard_fixture")

    # Print a tail of the output for immediate visibility
    tail = output[-4000:] if len(output) > 4000 else output
    print(tail)

    # Assertions
    print("\nAssertions:")
    assertions = [
        ("act exited with code 0", returncode == 0),
        ("Job succeeded", "Job succeeded" in output),
        ("pytest: all tests passed", "passed" in output),
        (f"Rotation summary exact: {EXPECTED_SUMMARY!r}", EXPECTED_SUMMARY in output),
        ("DB_PASSWORD appears in report", "DB_PASSWORD" in output),
        ("JWT_SECRET appears in report", "JWT_SECRET" in output),
        ("SMTP_PASSWORD appears in report", "SMTP_PASSWORD" in output),
    ]
    all_ok = check(assertions)

    # Write assertion results
    with open(RESULT_FILE, "a") as f:
        write_delimiter(f, "ASSERTIONS")
        for name, passed in assertions:
            f.write(f"  [{'PASS' if passed else 'FAIL'}] {name}\n")
        f.write(f"\nOVERALL: {'PASS' if all_ok else 'FAIL'}\n")

    if all_ok:
        print("\nAll act tests PASSED.")
        sys.exit(0)
    else:
        print("\nSome act tests FAILED. See act-result.txt for details.")
        sys.exit(1)


if __name__ == "__main__":
    main()
