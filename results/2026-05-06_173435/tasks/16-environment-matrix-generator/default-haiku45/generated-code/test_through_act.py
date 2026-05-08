#!/usr/bin/env python3
"""Test harness to run all tests through GitHub Actions via act."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def run_act() -> tuple[int, str]:
    """Run workflow through act and capture output.

    Returns:
        Tuple of (exit_code, stdout_stderr).
    """
    result = subprocess.run(
        ["act", "push", "--rm", "-v"],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent,
    )
    return result.returncode, result.stdout + "\n" + result.stderr


def verify_act_output(output: str) -> bool:
    """Verify that act output contains success markers.

    Returns:
        True if all required success markers are present.
    """
    required_strings = [
        "Run unit tests",
        "passed",
        "✓ JSON schema validation passed",
        "✓ All workflow steps completed successfully",
    ]

    missing = [s for s in required_strings if s not in output]

    if missing:
        print("Missing success markers:")
        for s in missing:
            print(f"  - {s}")
        return False

    return True


def main() -> int:
    """Run act tests and save results."""
    act_result_file = Path("act-result.txt")

    print("Running environment matrix generator tests through act...")
    print("=" * 70)

    # Test case 1: Basic workflow run
    print("\n[Test 1/1] Running full workflow through act...")
    exit_code, output = run_act()

    print(f"Act exit code: {exit_code}")

    # Save full output
    with open(act_result_file, "a") as f:
        f.write("=" * 70 + "\n")
        f.write("TEST CASE 1: Full Workflow Execution via act\n")
        f.write("=" * 70 + "\n")
        f.write(f"Exit Code: {exit_code}\n")
        f.write("Output:\n")
        f.write(output)
        f.write("\n\n")

    # Verify output
    if exit_code != 0:
        print("ERROR: act exited with non-zero code")
        print("\nOutput excerpt:")
        print(output[-2000:] if len(output) > 2000 else output)
        return 1

    if not verify_act_output(output):
        print("ERROR: Missing required success markers in output")
        print("\nOutput excerpt:")
        print(output[-2000:] if len(output) > 2000 else output)
        return 1

    print("✓ Test passed: Job succeeded and all steps completed")

    # Append summary to result file
    with open(act_result_file, "a") as f:
        f.write("=" * 70 + "\n")
        f.write("SUMMARY\n")
        f.write("=" * 70 + "\n")
        f.write("Test cases run: 1\n")
        f.write("Test cases passed: 1\n")
        f.write("Test cases failed: 0\n")
        f.write("\n✓ All tests passed through act!\n")

    print("\n" + "=" * 70)
    print("✓ All act tests completed successfully!")
    print(f"Results saved to: {act_result_file}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
