#!/usr/bin/env python3
"""
Test harness: runs all project tests through GitHub Actions via act.

Strategy:
  1. Copy project files to a temp directory and initialise a git repo there.
  2. Run `act push --rm` once — this executes the full workflow in Docker.
  3. Save all act output to act-result.txt in the project root.
  4. Assert on exact expected values present in the output:
       - Exit code 0
       - "Job succeeded" for every job
       - Specific markdown table cells produced by aggregator.py
       - Flaky test names

Expected aggregated totals from fixtures/:
  junit_run1.xml : 3 tests, 2 pass, 1 fail, 0.60s
  junit_run2.xml : 3 tests, 2 pass, 1 fail, 0.60s
  json_run1.json : 2 tests, 1 pass, 0 fail, 1 skip, 0.50s
  TOTAL          : 8 tests, 5 passed, 2 failed, 1 skipped, 1.70s
  FLAKY          : TestClass.test_b, TestClass.test_c
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.resolve()
ACT_RESULT_FILE = PROJECT_DIR / "act-result.txt"

# Exact markdown table cells that aggregator.py must emit.
EXPECTED_STRINGS = [
    "| Total Tests | 8 |",
    "| Passed | 5 |",
    "| Failed | 2 |",
    "| Skipped | 1 |",
    "1.70s",
    "TestClass.test_b",
    "TestClass.test_c",
    "Job succeeded",
]

# Files/dirs to skip when copying to the temp repo.
SKIP_PATTERNS = {
    "act-result.txt",
    "__pycache__",
    ".pytest_cache",
    "*.pyc",
}


def _should_skip(path: Path) -> bool:
    return path.name in SKIP_PATTERNS or path.suffix == ".pyc"


def setup_temp_repo(tmp_dir: Path) -> None:
    """Copy project into tmp_dir and initialise a git repo."""
    for item in PROJECT_DIR.iterdir():
        if _should_skip(item):
            continue
        dest = tmp_dir / item.name
        if item.is_dir():
            shutil.copytree(item, dest, ignore=shutil.ignore_patterns(*SKIP_PATTERNS))
        else:
            shutil.copy2(item, dest)

    subprocess.run(["git", "init"], cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "ci@test.local"],
                   cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "CI"],
                   cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=tmp_dir, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "ci: test fixture commit"],
                   cwd=tmp_dir, check=True, capture_output=True)


def run_act(tmp_dir: Path) -> tuple[int, str]:
    """Run `act push --rm` in tmp_dir and return (exit_code, combined_output)."""
    result = subprocess.run(
        ["act", "push", "--rm", "--pull=false"],
        cwd=tmp_dir,
        capture_output=True,
        text=True,
        timeout=300,
    )
    return result.returncode, result.stdout + result.stderr


def assert_output(output: str, case_name: str) -> list[str]:
    """Check all expected strings are present. Returns list of failure messages."""
    failures = []
    for expected in EXPECTED_STRINGS:
        if expected not in output:
            failures.append(f"  MISSING in '{case_name}': {expected!r}")
    return failures


def main() -> int:
    all_output_parts: list[str] = []
    all_failures: list[str] = []

    print("=" * 60)
    print("Test harness: running workflow via act")
    print("=" * 60)

    with tempfile.TemporaryDirectory(prefix="aggregator_test_") as tmp:
        tmp_dir = Path(tmp)
        print(f"Setting up temp git repo in {tmp_dir} ...")
        setup_temp_repo(tmp_dir)

        print("Running: act push --rm  (this may take 30-90 seconds) ...")
        exit_code, output = run_act(tmp_dir)

        header = "=== ACT RUN: full test suite ==="
        footer = f"=== EXIT CODE: {exit_code} ==="
        all_output_parts.extend([header, output, footer, ""])

        print(output[-3000:] if len(output) > 3000 else output)
        print(footer)

        if exit_code != 0:
            all_failures.append(
                f"  FAIL: act exited with code {exit_code} (expected 0)"
            )

        failures = assert_output(output, "full test suite")
        all_failures.extend(failures)

    # Write act-result.txt
    ACT_RESULT_FILE.write_text("\n".join(all_output_parts), encoding="utf-8")
    print(f"\nAct output saved to: {ACT_RESULT_FILE}")

    if all_failures:
        print("\n=== FAILURES ===")
        for f in all_failures:
            print(f)
        print(f"\n{len(all_failures)} assertion(s) failed.")
        return 1

    print("\nAll assertions passed!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
