#!/usr/bin/env python3
"""
Act test harness for artifact-cleanup-script.

For each test case:
  1. Copy project files into a fresh temp git repo
  2. Run `act push --rm`
  3. Append full output to act-result.txt (clearly delimited)
  4. Assert exit code 0 and "Job succeeded"
  5. Parse output and assert exact expected values

Limit: at most 3 `act push` runs total (per benchmark guidance).
"""
import os
import shutil
import subprocess
import sys
import tempfile

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULT_FILE = os.path.join(PROJECT_DIR, "act-result.txt")

# Files/dirs to copy from the project into every temp repo
COPY_FILES = [
    "artifact_cleanup.py",
    "test_artifact_cleanup.py",
    "fixtures.json",
    ".github",
    ".actrc",
]


def setup_temp_repo(extra_files: dict[str, str] | None = None) -> str:
    """
    Create a temp directory, copy project files into it, initialise a git
    repo, and commit everything.  Returns the temp directory path.

    extra_files: {src_abs_path: dest_relative_path} for per-test overrides.
    """
    tmpdir = tempfile.mkdtemp(prefix="act-test-")

    for name in COPY_FILES:
        src = os.path.join(PROJECT_DIR, name)
        dst = os.path.join(tmpdir, name)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        elif os.path.isfile(src):
            shutil.copy2(src, dst)

    if extra_files:
        for src, rel_dst in extra_files.items():
            dst = os.path.join(tmpdir, rel_dst)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    # Initialise git repo
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "test@test.com"],
        ["git", "config", "user.name", "Test"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test"],
    ]:
        subprocess.run(cmd, cwd=tmpdir, check=True, capture_output=True)

    return tmpdir


def run_act(tmpdir: str) -> tuple[int, str]:
    """Run `act push --rm` in tmpdir; return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmpdir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return result.returncode, result.stdout + result.stderr


def append_result(test_name: str, exit_code: int, output: str) -> None:
    """Append act output to act-result.txt."""
    sep = "=" * 70
    with open(RESULT_FILE, "a") as f:
        f.write(f"\n{sep}\n")
        f.write(f"TEST CASE: {test_name}\n")
        f.write(f"{sep}\n")
        f.write(output)
        f.write(f"\nEXIT CODE: {exit_code}\n")


def assert_all(test_name: str, exit_code: int, output: str, checks: dict) -> None:
    """Assert all expected values are present; fail loudly if any are missing."""
    failures = []

    if exit_code != 0:
        failures.append(f"  act exited with code {exit_code} (expected 0)")

    for description, expected in checks.items():
        if expected not in output:
            failures.append(f"  Expected {description!r} → {expected!r} not found in output")

    if failures:
        print(f"\n[FAIL] {test_name}")
        for msg in failures:
            print(msg)
        # Print last 3000 chars of output for debugging
        print("\n--- output tail ---")
        print(output[-3000:])
        sys.exit(1)

    print(f"[PASS] {test_name}")


def main() -> None:
    # Clear/create the result file
    with open(RESULT_FILE, "w") as f:
        f.write("act-result.txt — artifact cleanup workflow test results\n")

    # ── Test case 1: max-age policy on known fixture data ─────────────────
    # Fixture: 5 artifacts; max-age=30 days; reference=2026-04-19
    # Expected deletions: build-1 (108d), build-2 (49d), test-1 (139d) → 3
    # Expected retentions: build-3 (9d), test-2 (14d) → 2
    # Space reclaimed: 100MB + 200MB + 10MB = 310MB
    test_name = "max-age-dry-run"
    print(f"\nRunning act: {test_name}")

    tmpdir = setup_temp_repo()
    try:
        exit_code, output = run_act(tmpdir)
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    append_result(test_name, exit_code, output)

    assert_all(
        test_name,
        exit_code,
        output,
        {
            "job succeeded":    "Job succeeded",
            "pytest passed":    "passed",
            "deleted count":    "Deleted: 3",
            "retained count":   "Retained: 2",
            "space reclaimed":  "Space reclaimed: 310.0 MB",
            "dry run mode":     "DRY RUN",
        },
    )

    print(f"\nAll act tests passed. Results written to {RESULT_FILE}")


if __name__ == "__main__":
    main()
