"""Unit tests for matrix_gen.

These tests are NOT part of the act-driven integration suite; they exist to
drive the red/green/refactor TDD cycle. The required end-to-end testing
through `act` lives in tests/test_workflow.py.
"""
import json
import pytest
from matrix_gen import generate_matrix, MatrixError


def test_basic_cartesian_product():
    config = {
        "axes": {"os": ["ubuntu-latest"], "python": ["3.11", "3.12"]},
    }
    out = generate_matrix(config)
    assert out["matrix"]["os"] == ["ubuntu-latest"]
    assert out["matrix"]["python"] == ["3.11", "3.12"]
    assert out["size"] == 2


def test_include_adds_extra_combination():
    config = {
        "axes": {"os": ["ubuntu-latest"], "python": ["3.11"]},
        "include": [{"os": "macos-latest", "python": "3.12", "experimental": True}],
    }
    out = generate_matrix(config)
    assert {"os": "macos-latest", "python": "3.12", "experimental": True} in out["matrix"]["include"]
    # base size 1 + 1 include
    assert out["size"] == 2


def test_exclude_removes_combination():
    config = {
        "axes": {"os": ["ubuntu-latest", "windows-latest"], "python": ["3.11", "3.12"]},
        "exclude": [{"os": "windows-latest", "python": "3.11"}],
    }
    out = generate_matrix(config)
    assert {"os": "windows-latest", "python": "3.11"} in out["matrix"]["exclude"]
    # 4 base - 1 excluded = 3
    assert out["size"] == 3


def test_max_parallel_and_fail_fast_passthrough():
    config = {
        "axes": {"os": ["ubuntu-latest"]},
        "max_parallel": 4,
        "fail_fast": False,
    }
    out = generate_matrix(config)
    assert out["max-parallel"] == 4
    assert out["fail-fast"] is False


def test_max_size_validation_raises():
    config = {
        "axes": {"os": ["a", "b", "c"], "py": ["1", "2", "3"]},
        "max_size": 4,
    }
    with pytest.raises(MatrixError) as exc:
        generate_matrix(config)
    assert "exceeds" in str(exc.value).lower()


def test_empty_axes_is_error():
    with pytest.raises(MatrixError):
        generate_matrix({"axes": {}})


def test_feature_flags_axis():
    config = {
        "axes": {"os": ["ubuntu-latest"], "feature": ["fast", "slow"]},
    }
    out = generate_matrix(config)
    assert out["matrix"]["feature"] == ["fast", "slow"]
    assert out["size"] == 2


def test_output_is_json_serializable():
    config = {"axes": {"os": ["ubuntu-latest"]}, "fail_fast": True, "max_parallel": 2}
    out = generate_matrix(config)
    s = json.dumps(out)
    assert json.loads(s) == out
