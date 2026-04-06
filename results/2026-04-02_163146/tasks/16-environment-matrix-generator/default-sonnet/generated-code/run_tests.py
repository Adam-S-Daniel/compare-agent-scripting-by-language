#!/usr/bin/env python3
"""
Standalone test runner for matrix_generator.
Runs all tests without requiring pytest, so it works in restricted environments.

Usage: python run_tests.py
"""
import sys
import json
import traceback

# ---- import the module under test ----
from matrix_generator import (
    generate_matrix,
    validate_matrix_size,
    MatrixTooLargeError,
    InvalidConfigError,
)

# ---- minimal test infrastructure ----

_passed = 0
_failed = 0
_errors = []


def ok(name: str) -> None:
    global _passed
    _passed += 1
    print(f"  PASS  {name}")


def fail(name: str, reason: str) -> None:
    global _failed
    _failed += 1
    msg = f"  FAIL  {name}: {reason}"
    print(msg)
    _errors.append(msg)


def run(name: str, fn):
    try:
        fn()
        ok(name)
    except AssertionError as exc:
        fail(name, str(exc) or "assertion failed")
    except Exception as exc:
        fail(name, f"{type(exc).__name__}: {exc}")


def assert_raises(exc_type, fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except exc_type as e:
        return e
    raise AssertionError(f"Expected {exc_type.__name__} but no exception was raised")


# ---- fixtures ----

BASIC_CONFIG = {
    "os": ["ubuntu-latest", "windows-latest"],
    "python-version": ["3.10", "3.11"],
    "feature-flags": ["flag-a", "flag-b"],
}

CONFIG_WITH_INCLUDE = {
    "os": ["ubuntu-latest", "macos-latest"],
    "python-version": ["3.10", "3.11"],
    "include": [
        {"os": "windows-latest", "python-version": "3.12", "feature-flags": "flag-c"}
    ],
}

CONFIG_WITH_EXCLUDE = {
    "os": ["ubuntu-latest", "windows-latest"],
    "python-version": ["3.10", "3.11"],
    "exclude": [
        {"os": "windows-latest", "python-version": "3.10"}
    ],
}

CONFIG_WITH_LIMITS = {
    "os": ["ubuntu-latest"],
    "python-version": ["3.10", "3.11"],
    "max-parallel": 2,
    "fail-fast": False,
}

# ---- test cases ----

print("\n=== Basic Matrix Generation ===")

def test_cross_product_two_axes():
    config = {"os": ["ubuntu-latest", "windows-latest"], "python-version": ["3.10", "3.11"]}
    result = generate_matrix(config)
    combos = result["matrix"]
    assert len(combos) == 4, f"expected 4 got {len(combos)}"
    assert {"os": "ubuntu-latest", "python-version": "3.10"} in combos
    assert {"os": "ubuntu-latest", "python-version": "3.11"} in combos
    assert {"os": "windows-latest", "python-version": "3.10"} in combos
    assert {"os": "windows-latest", "python-version": "3.11"} in combos

run("cross_product_two_axes", test_cross_product_two_axes)


def test_cross_product_three_axes():
    result = generate_matrix(BASIC_CONFIG)
    assert len(result["matrix"]) == 8, f"expected 8 got {len(result['matrix'])}"

run("cross_product_three_axes", test_cross_product_three_axes)


def test_single_axis():
    config = {"os": ["ubuntu-latest", "windows-latest", "macos-latest"]}
    result = generate_matrix(config)
    assert len(result["matrix"]) == 3

run("single_axis", test_single_axis)


def test_output_contains_matrix_key():
    result = generate_matrix({"os": ["ubuntu-latest"]})
    assert "matrix" in result

run("output_contains_matrix_key", test_output_contains_matrix_key)


print("\n=== Include Rules ===")

def test_include_adds_extra_combinations():
    result = generate_matrix(CONFIG_WITH_INCLUDE)
    # 2 os * 2 python + 1 include = 5
    assert len(result["matrix"]) == 5, f"expected 5, got {len(result['matrix'])}"

run("include_adds_extra_combinations", test_include_adds_extra_combinations)


def test_include_entry_appears_in_matrix():
    result = generate_matrix(CONFIG_WITH_INCLUDE)
    assert {
        "os": "windows-latest",
        "python-version": "3.12",
        "feature-flags": "flag-c",
    } in result["matrix"]

run("include_entry_appears_in_matrix", test_include_entry_appears_in_matrix)


def test_include_extends_existing_combination():
    config = {
        "os": ["ubuntu-latest"],
        "python-version": ["3.10"],
        "include": [{"os": "ubuntu-latest", "python-version": "3.10", "extra": "value"}],
    }
    result = generate_matrix(config)
    assert len(result["matrix"]) == 1, f"expected 1, got {len(result['matrix'])}"
    assert result["matrix"][0]["extra"] == "value"

run("include_extends_existing_combination", test_include_extends_existing_combination)


print("\n=== Exclude Rules ===")

def test_exclude_removes_matching_combinations():
    result = generate_matrix(CONFIG_WITH_EXCLUDE)
    combos = result["matrix"]
    assert len(combos) == 3, f"expected 3, got {len(combos)}"
    assert {"os": "windows-latest", "python-version": "3.10"} not in combos

run("exclude_removes_matching_combinations", test_exclude_removes_matching_combinations)


def test_exclude_partial_match():
    config = {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "exclude": [{"os": "windows-latest"}],
    }
    result = generate_matrix(config)
    assert len(result["matrix"]) == 2, f"expected 2, got {len(result['matrix'])}"
    for combo in result["matrix"]:
        assert combo["os"] != "windows-latest", f"windows-latest should have been excluded: {combo}"

run("exclude_partial_match", test_exclude_partial_match)


print("\n=== Matrix Options ===")

def test_max_parallel_in_output():
    result = generate_matrix(CONFIG_WITH_LIMITS)
    assert result["max-parallel"] == 2

run("max_parallel_in_output", test_max_parallel_in_output)


def test_fail_fast_in_output():
    result = generate_matrix(CONFIG_WITH_LIMITS)
    assert result["fail-fast"] is False

run("fail_fast_in_output", test_fail_fast_in_output)


def test_defaults_when_omitted():
    config = {"os": ["ubuntu-latest"]}
    result = generate_matrix(config)
    assert "max-parallel" not in result
    assert "fail-fast" not in result

run("defaults_when_omitted", test_defaults_when_omitted)


print("\n=== Matrix Size Validation ===")

def test_validate_accepts_within_limit():
    matrix = [{"os": str(i)} for i in range(10)]
    validate_matrix_size(matrix, max_size=256)  # should not raise

run("validate_accepts_within_limit", test_validate_accepts_within_limit)


def test_validate_raises_when_exceeding():
    matrix = [{"os": str(i)} for i in range(300)]
    exc = assert_raises(MatrixTooLargeError, validate_matrix_size, matrix, max_size=256)
    assert "300" in str(exc), f"error should mention 300: {exc}"
    assert "256" in str(exc), f"error should mention 256: {exc}"

run("validate_raises_when_exceeding", test_validate_raises_when_exceeding)


def test_generate_enforces_default_limit():
    config = {
        "os": [str(i) for i in range(6)],
        "a": [str(i) for i in range(6)],
        "b": [str(i) for i in range(6)],
        "c": [str(i) for i in range(6)],
    }
    assert_raises(MatrixTooLargeError, generate_matrix, config)

run("generate_enforces_default_limit", test_generate_enforces_default_limit)


def test_generate_respects_custom_max_size():
    config = {"os": [str(i) for i in range(5)]}
    result = generate_matrix(config, max_size=10)
    assert len(result["matrix"]) == 5

run("generate_respects_custom_max_size", test_generate_respects_custom_max_size)


def test_generate_raises_with_custom_max_size():
    config = {"os": [str(i) for i in range(5)]}
    assert_raises(MatrixTooLargeError, generate_matrix, config, max_size=3)

run("generate_raises_with_custom_max_size", test_generate_raises_with_custom_max_size)


print("\n=== Error Handling ===")

def test_empty_config_raises():
    assert_raises(InvalidConfigError, generate_matrix, {})

run("empty_config_raises", test_empty_config_raises)


def test_only_reserved_keys_raises():
    assert_raises(InvalidConfigError, generate_matrix, {"include": [], "max-parallel": 2})

run("only_reserved_keys_raises", test_only_reserved_keys_raises)


def test_empty_axis_raises():
    assert_raises(InvalidConfigError, generate_matrix, {"os": []})

run("empty_axis_raises", test_empty_axis_raises)


def test_error_names_empty_axis():
    exc = assert_raises(
        InvalidConfigError, generate_matrix, {"os": [], "python-version": ["3.10"]}
    )
    assert "os" in str(exc), f"error should name the empty axis: {exc}"

run("error_names_empty_axis", test_error_names_empty_axis)


print("\n=== JSON Output ===")

def test_output_is_json_serializable():
    result = generate_matrix(BASIC_CONFIG)
    dumped = json.dumps(result)
    loaded = json.loads(dumped)
    assert loaded == result

run("output_is_json_serializable", test_output_is_json_serializable)


def test_github_actions_strategy_shape():
    config = {
        "os": ["ubuntu-latest"],
        "python-version": ["3.10"],
        "max-parallel": 1,
        "fail-fast": True,
    }
    result = generate_matrix(config)
    assert "matrix" in result
    assert isinstance(result["matrix"], list)
    assert result["max-parallel"] == 1
    assert result["fail-fast"] is True

run("github_actions_strategy_shape", test_github_actions_strategy_shape)


# ---- summary ----

total = _passed + _failed
print(f"\n{'='*40}")
print(f"Results: {_passed}/{total} passed", end="")
if _failed:
    print(f", {_failed} FAILED")
    for e in _errors:
        print(f"  {e}")
    sys.exit(1)
else:
    print(" — all tests passed!")
    sys.exit(0)
