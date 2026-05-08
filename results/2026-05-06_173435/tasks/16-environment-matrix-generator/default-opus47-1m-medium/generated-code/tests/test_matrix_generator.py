"""Tests for environment matrix generator.

TDD approach: each test was written first, then the minimum implementation
to make it pass was added to matrix_generator.py.
"""
import json
import os
import subprocess
import sys
import tempfile

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from matrix_generator import (
    MatrixError,
    MatrixSizeError,
    generate_matrix,
    load_config,
    main,
)


# --- 1. Cartesian product of axes -------------------------------------------

def test_cartesian_product_of_two_axes():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.10", "3.11"],
        }
    }
    result = generate_matrix(config)
    assert "include" in result or "os" in result
    # There should be 4 combinations
    combos = result["include"]
    assert len(combos) == 4
    assert {"os": "ubuntu-latest", "python": "3.10"} in combos


def test_single_axis():
    config = {"axes": {"os": ["ubuntu-latest"]}}
    result = generate_matrix(config)
    assert result["include"] == [{"os": "ubuntu-latest"}]


def test_three_axes_with_features():
    config = {
        "axes": {
            "os": ["ubuntu-latest"],
            "python": ["3.11", "3.12"],
            "feature": ["fast", "safe"],
        }
    }
    result = generate_matrix(config)
    assert len(result["include"]) == 4


# --- 2. Exclude rules --------------------------------------------------------

def test_exclude_removes_combination():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.10", "3.11"],
        },
        "exclude": [{"os": "windows-latest", "python": "3.10"}],
    }
    result = generate_matrix(config)
    combos = result["include"]
    assert len(combos) == 3
    assert {"os": "windows-latest", "python": "3.10"} not in combos


def test_exclude_partial_match_removes_all_matching():
    # exclude rule matches on subset of keys -> all combos with those values dropped
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.10", "3.11"],
        },
        "exclude": [{"os": "windows-latest"}],
    }
    result = generate_matrix(config)
    combos = result["include"]
    assert len(combos) == 2
    assert all(c["os"] == "ubuntu-latest" for c in combos)


# --- 3. Include rules (extra entries) ----------------------------------------

def test_include_adds_extra_combination():
    config = {
        "axes": {
            "os": ["ubuntu-latest"],
            "python": ["3.11"],
        },
        "include": [{"os": "macos-latest", "python": "3.12", "experimental": True}],
    }
    result = generate_matrix(config)
    combos = result["include"]
    assert len(combos) == 2
    assert {"os": "macos-latest", "python": "3.12", "experimental": True} in combos


# --- 4. max-parallel and fail-fast ------------------------------------------

def test_max_parallel_and_fail_fast_passthrough():
    config = {
        "axes": {"os": ["ubuntu-latest"]},
        "max_parallel": 4,
        "fail_fast": False,
    }
    result = generate_matrix(config)
    assert result["max-parallel"] == 4
    assert result["fail-fast"] is False


def test_default_fail_fast_is_true():
    config = {"axes": {"os": ["ubuntu-latest"]}}
    result = generate_matrix(config)
    # GitHub Actions default fail-fast is true; we mirror that.
    assert result.get("fail-fast", True) is True


# --- 5. Maximum size validation ---------------------------------------------

def test_matrix_size_limit_exceeded_raises():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
            "python": ["3.9", "3.10", "3.11", "3.12"],
        },
        "max_size": 5,
    }
    with pytest.raises(MatrixSizeError) as exc_info:
        generate_matrix(config)
    assert "exceeds" in str(exc_info.value).lower() or "max" in str(exc_info.value).lower()


def test_matrix_size_default_256_enforced():
    # GitHub Actions hard limit is 256 jobs per matrix.
    axes = {f"axis{i}": ["a", "b"] for i in range(9)}  # 2^9 = 512
    config = {"axes": axes}
    with pytest.raises(MatrixSizeError):
        generate_matrix(config)


def test_matrix_size_at_limit_passes():
    config = {
        "axes": {"os": ["a", "b", "c"]},
        "max_size": 3,
    }
    # Should not raise
    result = generate_matrix(config)
    assert len(result["include"]) == 3


# --- 6. Validation errors ----------------------------------------------------

def test_missing_axes_raises():
    with pytest.raises(MatrixError):
        generate_matrix({})


def test_empty_axis_values_raises():
    with pytest.raises(MatrixError):
        generate_matrix({"axes": {"os": []}})


def test_non_dict_config_raises():
    with pytest.raises(MatrixError):
        generate_matrix("not a dict")


# --- 7. Config loading -------------------------------------------------------

def test_load_config_from_json_file():
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False
    ) as f:
        json.dump({"axes": {"os": ["ubuntu-latest"]}}, f)
        path = f.name
    try:
        cfg = load_config(path)
        assert cfg["axes"]["os"] == ["ubuntu-latest"]
    finally:
        os.unlink(path)


def test_load_config_missing_file():
    with pytest.raises(MatrixError):
        load_config("/nonexistent/path/config.json")


# --- 8. CLI / main() output --------------------------------------------------

def test_main_prints_matrix_json(tmp_path, capsys):
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({"axes": {"os": ["ubuntu-latest"]}}))
    rc = main([str(cfg)])
    assert rc == 0
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert parsed["include"] == [{"os": "ubuntu-latest"}]


def test_main_returns_nonzero_on_size_violation(tmp_path, capsys):
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({"axes": {"a": [1, 2, 3]}, "max_size": 1}))
    rc = main([str(cfg)])
    assert rc != 0


def test_main_returns_nonzero_on_missing_file(capsys):
    rc = main(["/nope/missing.json"])
    assert rc != 0


# --- 9. Combined include/exclude/feature flags ------------------------------

def test_full_featured_matrix():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest"],
            "node": ["18", "20"],
            "feature": ["minimal", "full"],
        },
        "exclude": [
            {"os": "windows-latest", "feature": "minimal"},
        ],
        "include": [
            {"os": "macos-latest", "node": "20", "feature": "full"},
        ],
        "max_parallel": 6,
        "fail_fast": False,
        "max_size": 10,
    }
    result = generate_matrix(config)
    # 2*2*2 = 8 - 2 excluded (windows+minimal x 2 node versions) + 1 include = 7
    assert len(result["include"]) == 7
    assert result["max-parallel"] == 6
    assert result["fail-fast"] is False
