#!/usr/bin/env python3
"""Test runner that executes inside the GitHub Actions workflow.

Each test runs matrix_generator.py against a fixture and verifies exact output.
Output is structured so the external test harness can parse and validate results.
"""

import json
import subprocess
import sys


def run_generator(config_path: str) -> tuple[int, str, str]:
    result = subprocess.run(
        ["python3", "matrix_generator.py", config_path],
        capture_output=True, text=True
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def test_basic():
    print("=== TEST: test_basic ===")
    code, stdout, stderr = run_generator("fixtures/basic_config.json")
    assert code == 0, f"Exit code {code}: {stderr}"
    result = json.loads(stdout)
    print(f"OUTPUT: {json.dumps(result, sort_keys=True)}")
    assert result["total_combinations"] == 4, f"Expected 4, got {result['total_combinations']}"
    assert result["fail-fast"] is False
    assert "max-parallel" not in result
    assert result["matrix"]["os"] == ["ubuntu-latest", "windows-latest"]
    assert result["matrix"]["python-version"] == ["3.10", "3.11"]
    assert "include" not in result["matrix"]
    assert "exclude" not in result["matrix"]
    print("PASS: test_basic - total_combinations=4, fail-fast=false")
    print("=== END TEST: test_basic ===")


def test_include():
    print("=== TEST: test_include ===")
    code, stdout, stderr = run_generator("fixtures/include_config.json")
    assert code == 0, f"Exit code {code}: {stderr}"
    result = json.loads(stdout)
    print(f"OUTPUT: {json.dumps(result, sort_keys=True)}")
    assert result["total_combinations"] == 5, f"Expected 5, got {result['total_combinations']}"
    assert result["matrix"]["include"] == [{"os": "ubuntu-latest", "python-version": "3.12"}]
    print("PASS: test_include - total_combinations=5, include rule preserved")
    print("=== END TEST: test_include ===")


def test_exclude():
    print("=== TEST: test_exclude ===")
    code, stdout, stderr = run_generator("fixtures/exclude_config.json")
    assert code == 0, f"Exit code {code}: {stderr}"
    result = json.loads(stdout)
    print(f"OUTPUT: {json.dumps(result, sort_keys=True)}")
    assert result["total_combinations"] == 3, f"Expected 3, got {result['total_combinations']}"
    assert result["matrix"]["exclude"] == [{"os": "windows-latest", "python-version": "3.10"}]
    print("PASS: test_exclude - total_combinations=3, exclude rule preserved")
    print("=== END TEST: test_exclude ===")


def test_combined():
    print("=== TEST: test_combined ===")
    code, stdout, stderr = run_generator("fixtures/combined_config.json")
    assert code == 0, f"Exit code {code}: {stderr}"
    result = json.loads(stdout)
    print(f"OUTPUT: {json.dumps(result, sort_keys=True)}")
    assert result["total_combinations"] == 18, f"Expected 18, got {result['total_combinations']}"
    assert result["fail-fast"] is True
    assert result["max-parallel"] == 4
    assert len(result["matrix"]["include"]) == 1
    assert len(result["matrix"]["exclude"]) == 1
    print("PASS: test_combined - total_combinations=18, fail-fast=true, max-parallel=4")
    print("=== END TEST: test_combined ===")


def test_too_large():
    print("=== TEST: test_too_large ===")
    code, stdout, stderr = run_generator("fixtures/too_large_config.json")
    assert code == 1, f"Expected exit code 1, got {code}"
    assert "15" in stderr, f"Expected '15' in error: {stderr}"
    assert "5" in stderr, f"Expected '5' in error: {stderr}"
    print(f"STDERR: {stderr}")
    print("PASS: test_too_large - rejected 15 combinations exceeding max of 5")
    print("=== END TEST: test_too_large ===")


def test_feature_flags():
    print("=== TEST: test_feature_flags ===")
    code, stdout, stderr = run_generator("fixtures/feature_flags_config.json")
    assert code == 0, f"Exit code {code}: {stderr}"
    result = json.loads(stdout)
    print(f"OUTPUT: {json.dumps(result, sort_keys=True)}")
    assert result["total_combinations"] == 6, f"Expected 6, got {result['total_combinations']}"
    assert result["fail-fast"] is False
    assert result["matrix"]["experimental"] == [True, False]
    assert result["matrix"]["node-version"] == ["16", "18", "20"]
    print("PASS: test_feature_flags - total_combinations=6, boolean flags preserved")
    print("=== END TEST: test_feature_flags ===")


def test_invalid_config():
    print("=== TEST: test_invalid_config ===")
    code, stdout, stderr = run_generator("fixtures/invalid_config.json")
    assert code == 1, f"Expected exit code 1, got {code}"
    assert "matrix" in stderr.lower(), f"Expected 'matrix' in error: {stderr}"
    print(f"STDERR: {stderr}")
    print("PASS: test_invalid_config - rejected config missing 'matrix' key")
    print("=== END TEST: test_invalid_config ===")


def test_include_extra_keys():
    print("=== TEST: test_include_extra_keys ===")
    code, stdout, stderr = run_generator("fixtures/include_extra_config.json")
    assert code == 0, f"Exit code {code}: {stderr}"
    result = json.loads(stdout)
    print(f"OUTPUT: {json.dumps(result, sort_keys=True)}")
    assert result["total_combinations"] == 4, f"Expected 4, got {result['total_combinations']}"
    inc = result["matrix"]["include"]
    assert len(inc) == 1
    assert inc[0]["coverage"] is True
    print("PASS: test_include_extra_keys - total_combinations=4, extra key in include")
    print("=== END TEST: test_include_extra_keys ===")


def main():
    tests = [
        test_basic,
        test_include,
        test_exclude,
        test_combined,
        test_too_large,
        test_feature_flags,
        test_invalid_config,
        test_include_extra_keys,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
        except AssertionError as e:
            print(f"FAIL: {test.__name__} - {e}")
            failed += 1
        except Exception as e:
            print(f"FAIL: {test.__name__} - {type(e).__name__}: {e}")
            failed += 1

    print(f"\n=== SUMMARY ===")
    print(f"RESULTS: {passed} passed, {failed} failed, {passed + failed} total")

    if failed > 0:
        sys.exit(1)

    print("ALL TESTS PASSED")


if __name__ == "__main__":
    main()
