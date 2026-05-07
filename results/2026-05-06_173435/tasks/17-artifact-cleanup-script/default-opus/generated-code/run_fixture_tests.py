#!/usr/bin/env python3
"""Test runner that processes all fixtures and validates results.

Runs inside the GitHub Actions workflow (act container). For each fixture:
1. Extracts the input data and passes it to artifact_cleanup.py
2. Compares actual output against expected values
3. Prints structured results for the host-side test harness to parse
"""

import json
import os
import subprocess
import sys
import tempfile


def run_fixture(fixture_path):
    """Run artifact_cleanup.py with a fixture's input and return results."""
    with open(fixture_path) as f:
        fixture = json.load(f)

    input_data = fixture["input"]
    expected = fixture["expected"]

    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as tmp:
        json.dump(input_data, tmp)
        tmp_path = tmp.name

    try:
        result = subprocess.run(
            ["python3", "artifact_cleanup.py", tmp_path],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return {
                "status": "ERROR",
                "error": result.stderr.strip(),
                "expected": expected,
            }

        actual = json.loads(result.stdout)
    finally:
        os.unlink(tmp_path)

    failures = []

    if actual["summary"]["artifacts_to_delete"] != expected["delete_count"]:
        failures.append(
            f"delete_count: got {actual['summary']['artifacts_to_delete']}, "
            f"expected {expected['delete_count']}"
        )

    if actual["summary"]["artifacts_to_retain"] != expected["retain_count"]:
        failures.append(
            f"retain_count: got {actual['summary']['artifacts_to_retain']}, "
            f"expected {expected['retain_count']}"
        )

    if actual["summary"]["space_reclaimed_bytes"] != expected["space_reclaimed"]:
        failures.append(
            f"space_reclaimed: got {actual['summary']['space_reclaimed_bytes']}, "
            f"expected {expected['space_reclaimed']}"
        )

    if actual["summary"]["space_retained_bytes"] != expected["space_retained"]:
        failures.append(
            f"space_retained: got {actual['summary']['space_retained_bytes']}, "
            f"expected {expected['space_retained']}"
        )

    actual_deleted_names = sorted([a["name"] for a in actual["to_delete"]])
    expected_deleted_names = sorted(expected["deleted_names"])
    if actual_deleted_names != expected_deleted_names:
        failures.append(
            f"deleted_names: got {actual_deleted_names}, "
            f"expected {expected_deleted_names}"
        )

    actual_retained_names = sorted([a["name"] for a in actual["to_retain"]])
    expected_retained_names = sorted(expected["retained_names"])
    if actual_retained_names != expected_retained_names:
        failures.append(
            f"retained_names: got {actual_retained_names}, "
            f"expected {expected_retained_names}"
        )

    if actual["dry_run"] != expected["dry_run"]:
        failures.append(
            f"dry_run: got {actual['dry_run']}, expected {expected['dry_run']}"
        )

    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "actual_summary": actual["summary"],
        "expected": expected,
        "actual_dry_run": actual["dry_run"],
    }


def main():
    fixtures_dir = "test_fixtures"
    if not os.path.isdir(fixtures_dir):
        print("Error: test_fixtures directory not found", file=sys.stderr)
        sys.exit(1)

    fixture_files = sorted(
        f for f in os.listdir(fixtures_dir) if f.endswith(".json")
    )

    if not fixture_files:
        print("Error: no fixture files found", file=sys.stderr)
        sys.exit(1)

    all_passed = True
    total = len(fixture_files)
    passed = 0

    for fixture_file in fixture_files:
        fixture_path = os.path.join(fixtures_dir, fixture_file)
        test_name = fixture_file.replace(".json", "")

        print(f"=== FIXTURE: {test_name} ===")
        print(f"INPUT_FILE: {fixture_path}")

        result = run_fixture(fixture_path)

        if result["status"] == "ERROR":
            print(f"ERROR: {result['error']}")
            print(f"STATUS: FAIL")
            all_passed = False
        elif result["status"] == "PASS":
            summary = result["actual_summary"]
            print(f"DELETE_COUNT: {summary['artifacts_to_delete']}")
            print(f"RETAIN_COUNT: {summary['artifacts_to_retain']}")
            print(f"SPACE_RECLAIMED: {summary['space_reclaimed_bytes']}")
            print(f"SPACE_RETAINED: {summary['space_retained_bytes']}")
            print(f"DRY_RUN: {result['actual_dry_run']}")
            print(f"STATUS: PASS")
            passed += 1
        else:
            summary = result["actual_summary"]
            print(f"DELETE_COUNT: {summary['artifacts_to_delete']}")
            print(f"RETAIN_COUNT: {summary['artifacts_to_retain']}")
            print(f"SPACE_RECLAIMED: {summary['space_reclaimed_bytes']}")
            print(f"SPACE_RETAINED: {summary['space_retained_bytes']}")
            print(f"DRY_RUN: {result['actual_dry_run']}")
            for failure in result["failures"]:
                print(f"FAILURE: {failure}")
            print(f"STATUS: FAIL")
            all_passed = False

        print(f"=== END FIXTURE: {test_name} ===")
        print()

    print(f"=== SUMMARY ===")
    print(f"TOTAL: {total}")
    print(f"PASSED: {passed}")
    print(f"FAILED: {total - passed}")
    print(f"OVERALL: {'PASS' if all_passed else 'FAIL'}")
    print(f"=== END SUMMARY ===")

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
