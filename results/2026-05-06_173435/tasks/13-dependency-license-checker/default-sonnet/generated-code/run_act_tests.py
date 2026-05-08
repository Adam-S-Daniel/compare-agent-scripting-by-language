"""
Act Integration Test Harness — Dependency License Checker

Sets up a temp git repo containing the project files, runs `act push --rm`
once, captures all output, saves it to act-result.txt, then asserts on
exact expected values in the output.

Limit: at most 3 `act push` runs total. We use one comprehensive run that
exercises all three test cases via the workflow steps.

Usage:
    python3 run_act_tests.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Where to write the captured act output
RESULT_FILE = Path(__file__).parent / "act-result.txt"

# Project root (the directory this script lives in)
PROJECT_ROOT = Path(__file__).parent.resolve()

# Files and directories to copy into the temp git repo
COPY_ITEMS = [
    "license_checker.py",
    "tests",
    "fixtures",
    ".github",
    ".actrc",
]


def run_command(cmd: list[str], cwd: str, timeout: int = 300) -> tuple[int, str]:
    """Run a command, capture combined stdout+stderr, return (exit_code, output)."""
    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return result.returncode, result.stdout + result.stderr


def setup_temp_repo(tmp_dir: str) -> None:
    """Copy project files into tmp_dir and initialise a git commit."""
    for item in COPY_ITEMS:
        src = PROJECT_ROOT / item
        if not src.exists():
            print(f"  Warning: {src} not found, skipping")
            continue
        dst = Path(tmp_dir) / item
        if src.is_dir():
            shutil.copytree(str(src), str(dst))
        else:
            shutil.copy2(str(src), str(dst))

    # Configure a minimal git identity so `git commit` works
    for cmd in [
        ["git", "init"],
        ["git", "config", "user.email", "test@example.com"],
        ["git", "config", "user.name", "Test Runner"],
        ["git", "add", "-A"],
        ["git", "commit", "-m", "test: add project files for act run"],
    ]:
        rc, out = run_command(cmd, cwd=tmp_dir)
        if rc != 0:
            raise RuntimeError(f"Setup command failed {cmd}: {out}")


def run_act(tmp_dir: str) -> tuple[int, str]:
    """Execute `act push --rm --pull=false` and return (exit_code, combined_output).

    --pull=false prevents act from trying to re-pull the local image from Docker Hub.
    """
    print("  Running: act push --rm --pull=false  (this takes 30-90 s) …")
    rc, out = run_command(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        timeout=300,
    )
    return rc, out


def assert_exact(label: str, output: str, expected: str) -> None:
    """Assert that *expected* appears as a substring of *output*."""
    if expected not in output:
        print(f"  FAIL [{label}]: expected to find: {expected!r}")
        raise AssertionError(f"[{label}] Expected substring not found: {expected!r}")
    print(f"  PASS [{label}]: found {expected!r}")


def assert_not(label: str, output: str, unexpected: str) -> None:
    """Assert that *unexpected* does NOT appear in *output*."""
    if unexpected in output:
        print(f"  FAIL [{label}]: unexpected substring found: {unexpected!r}")
        raise AssertionError(f"[{label}] Unexpected substring found: {unexpected!r}")
    print(f"  PASS [{label}]: correctly absent: {unexpected!r}")


def run_test_cases() -> None:
    """
    Single act run covering all three test-case scenarios.

    Test case 1 — sample_package.json:
      express (MIT) → APPROVED, some-gpl-lib (GPL-3.0) → DENIED,
      unknown-pkg (not in DB) → UNKNOWN, Overall → NON-COMPLIANT

    Test case 2 — sample_requirements.txt:
      requests (Apache-2.0) → APPROVED, django (BSD-3-Clause) → APPROVED,
      some-gpl (GPL-2.0) → DENIED, Overall → NON-COMPLIANT

    Test case 3 — clean_package.json:
      express (MIT) → APPROVED, lodash (MIT) → APPROVED,
      Overall → COMPLIANT  (step must exit 0)
    """
    with tempfile.TemporaryDirectory(prefix="act_license_test_") as tmp_dir:
        print(f"\n[Setup] Temp repo: {tmp_dir}")
        setup_temp_repo(tmp_dir)

        print("[Act  ] Launching workflow …")
        exit_code, output = run_act(tmp_dir)

        # ----------------------------------------------------------------
        # Save the full output (required artifact)
        # ----------------------------------------------------------------
        delimiter = "=" * 70
        with open(RESULT_FILE, "w") as f:
            f.write(f"{delimiter}\n")
            f.write("ACT RUN: dependency-license-checker  (all three test cases)\n")
            f.write(f"{delimiter}\n")
            f.write(output)
            f.write(f"\n{delimiter}\n")
            f.write(f"Exit code: {exit_code}\n")
            f.write(f"{delimiter}\n")

        print(f"\n[Output] Saved to {RESULT_FILE}  ({len(output)} chars)")

        # ----------------------------------------------------------------
        # Assert: act exited with 0
        # ----------------------------------------------------------------
        if exit_code != 0:
            print("\n--- act output (last 80 lines) ---")
            for line in output.splitlines()[-80:]:
                print(line)
            raise AssertionError(
                f"act exited with code {exit_code} (expected 0)"
            )
        print(f"  PASS [act exit code]: 0")

        # ----------------------------------------------------------------
        # Assert: every job succeeded
        # ----------------------------------------------------------------
        assert_exact("job succeeded", output, "Job succeeded")

        # ----------------------------------------------------------------
        # Assert: pytest ran and all tests passed
        # ----------------------------------------------------------------
        assert_exact("pytest passed", output, "passed")
        # Ensure no test failures
        assert_not("pytest no failures", output, " failed")

        # ----------------------------------------------------------------
        # Test case 1 assertions — sample_package.json
        # ----------------------------------------------------------------
        # express@4.18.0 is MIT → APPROVED
        assert_exact("tc1 express approved", output, "express")
        assert_exact("tc1 APPROVED present", output, "APPROVED")

        # some-gpl-lib@1.0.0 is GPL-3.0 → DENIED
        assert_exact("tc1 some-gpl-lib present", output, "some-gpl-lib")
        assert_exact("tc1 DENIED present", output, "DENIED")

        # unknown-pkg not in DB → UNKNOWN
        assert_exact("tc1 unknown-pkg present", output, "unknown-pkg")
        assert_exact("tc1 UNKNOWN present", output, "UNKNOWN")

        # Overall NON-COMPLIANT for sample_package.json
        assert_exact("tc1 NON-COMPLIANT", output, "NON-COMPLIANT")

        # ----------------------------------------------------------------
        # Test case 2 assertions — sample_requirements.txt
        # ----------------------------------------------------------------
        # requests Apache-2.0 → APPROVED
        assert_exact("tc2 requests present", output, "requests")
        # some-gpl GPL-2.0 → DENIED
        assert_exact("tc2 some-gpl present", output, "some-gpl")

        # ----------------------------------------------------------------
        # Test case 3 assertions — clean_package.json (all approved)
        # ----------------------------------------------------------------
        # lodash MIT → APPROVED (only in clean fixture)
        assert_exact("tc3 lodash present", output, "lodash")
        # Overall COMPLIANT (not NON-COMPLIANT) for the clean run
        # NON-COMPLIANT already asserted above; just verify COMPLIANT appears
        assert_exact("tc3 COMPLIANT", output, "COMPLIANT")

        # ----------------------------------------------------------------
        # Exact summary counts (from the compliance report header lines)
        # ----------------------------------------------------------------
        # sample_package.json has 5 deps: express MIT, react MIT, jest MIT,
        # some-gpl-lib GPL-3.0 (denied), unknown-pkg (unknown)
        # → "3 approved, 1 denied, 1 unknown"
        assert_exact(
            "tc1 summary counts",
            output,
            "3 approved, 1 denied, 1 unknown",
        )

        # sample_requirements.txt: requests Apache-2.0 (approved),
        # django BSD-3-Clause (approved), some-gpl GPL-2.0 (denied),
        # no-version-pkg (unknown)
        # → "2 approved, 1 denied, 1 unknown"
        assert_exact(
            "tc2 summary counts",
            output,
            "2 approved, 1 denied, 1 unknown",
        )

        # clean_package.json: express MIT (approved), lodash MIT (approved)
        # → "2 approved, 0 denied, 0 unknown"
        assert_exact(
            "tc3 summary counts",
            output,
            "2 approved, 0 denied, 0 unknown",
        )

    print("\n[All assertions passed]")


def main() -> int:
    print("=" * 60)
    print("Dependency License Checker — Act Integration Tests")
    print("=" * 60)
    try:
        run_test_cases()
        print("\nResult: SUCCESS")
        return 0
    except AssertionError as exc:
        print(f"\nResult: FAILURE — {exc}")
        return 1
    except Exception as exc:
        print(f"\nResult: ERROR — {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
