"""TDD tests for the environment matrix generator."""
import json
import pytest
from matrix_generator import generate_matrix, MatrixError


# --- Test 1 (RED): basic Cartesian product from axes ---
def test_generates_cartesian_product():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11", "3.12"],
        }
    }
    result = generate_matrix(config)
    combos = result["matrix"]["include"] if "include" in result["matrix"] else None
    # The matrix should be emitted via axes directly (native GHA form).
    assert result["matrix"]["os"] == ["ubuntu-latest", "macos-latest"]
    assert result["matrix"]["python"] == ["3.11", "3.12"]
    assert result["size"] == 4


# --- Test 2: include adds extra combinations ---
def test_include_adds_combinations():
    config = {
        "axes": {"os": ["ubuntu-latest"], "node": ["18", "20"]},
        "include": [{"os": "windows-latest", "node": "20", "experimental": True}],
    }
    result = generate_matrix(config)
    assert {"os": "windows-latest", "node": "20", "experimental": True} in result["matrix"]["include"]
    # Base size = 2, include adds 1 new combo => 3
    assert result["size"] == 3


# --- Test 3: exclude removes combinations ---
def test_exclude_removes_combinations():
    config = {
        "axes": {"os": ["ubuntu-latest", "macos-latest"], "python": ["3.11", "3.12"]},
        "exclude": [{"os": "macos-latest", "python": "3.11"}],
    }
    result = generate_matrix(config)
    assert result["matrix"]["exclude"] == [{"os": "macos-latest", "python": "3.11"}]
    assert result["size"] == 3


# --- Test 4: max-parallel and fail-fast propagated ---
def test_strategy_options_propagated():
    config = {
        "axes": {"os": ["ubuntu-latest"]},
        "max-parallel": 4,
        "fail-fast": False,
    }
    result = generate_matrix(config)
    assert result["max-parallel"] == 4
    assert result["fail-fast"] is False


# --- Test 5: max-size validation raises error ---
def test_max_size_exceeded_raises():
    config = {
        "axes": {"a": [1, 2, 3], "b": [1, 2, 3], "c": [1, 2, 3]},  # 27
        "max-size": 10,
    }
    with pytest.raises(MatrixError) as exc:
        generate_matrix(config)
    assert "exceeds max-size" in str(exc.value)
    assert "27" in str(exc.value)


# --- Test 6: feature flags treated as axes ---
def test_feature_flags_as_axis():
    config = {
        "axes": {"os": ["ubuntu-latest"]},
        "features": {"use_cache": [True, False]},
    }
    result = generate_matrix(config)
    assert result["matrix"]["use_cache"] == [True, False]
    assert result["size"] == 2


# --- Test 7: invalid config (no axes) gives meaningful error ---
def test_empty_axes_raises():
    with pytest.raises(MatrixError) as exc:
        generate_matrix({})
    assert "axes" in str(exc.value).lower()


# --- Test 8: excludes that don't match anything still valid (warn not error) ---
def test_exclude_nonmatching_is_ok():
    config = {
        "axes": {"os": ["ubuntu-latest"]},
        "exclude": [{"os": "nonexistent"}],
    }
    result = generate_matrix(config)
    assert result["size"] == 1  # nothing actually excluded


# --- Test 9: default fail-fast is True; default max-parallel absent ---
def test_defaults():
    config = {"axes": {"os": ["ubuntu-latest"]}}
    result = generate_matrix(config)
    assert result["fail-fast"] is True
    assert "max-parallel" not in result or result["max-parallel"] is None


# --- Test 10: end-to-end JSON output serializable ---
def test_output_is_json_serializable():
    config = {
        "axes": {"os": ["ubuntu-latest", "macos-latest"], "python": ["3.11"]},
        "include": [{"os": "windows-latest", "python": "3.12"}],
        "exclude": [{"os": "macos-latest", "python": "3.11"}],
        "max-parallel": 2,
        "fail-fast": False,
        "max-size": 100,
    }
    result = generate_matrix(config)
    json_str = json.dumps(result)
    parsed = json.loads(json_str)
    assert parsed["size"] == 2  # 2 base - 1 exclude + 1 include
