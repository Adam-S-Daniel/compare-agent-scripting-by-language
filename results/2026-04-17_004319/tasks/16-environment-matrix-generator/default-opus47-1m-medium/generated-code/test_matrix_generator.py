"""Tests for the GitHub Actions matrix generator.

Following red/green TDD: each test was added first, then the minimum code
written in matrix_generator.py to make it pass.
"""
import json
import subprocess
import sys
import pytest

from matrix_generator import (
    generate_matrix,
    MatrixError,
    main,
)


# --- 1. Basic cartesian product ---

def test_basic_cartesian_product():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.11", "3.12"],
        }
    }
    result = generate_matrix(config)
    combos = result["matrix"]["include"] if "include" in result["matrix"] else _expand(result["matrix"])
    # 2 * 2 = 4 combinations
    assert len(_all_combos(result)) == 4


def _all_combos(result):
    """Helper: expand the generated matrix into its full combination list."""
    m = result["matrix"]
    if set(m.keys()) == {"include"}:
        return m["include"]
    # Full axes form -- expand ourselves
    axes = {k: v for k, v in m.items() if k not in ("include", "exclude")}
    from itertools import product
    keys = list(axes.keys())
    combos = []
    for values in product(*[axes[k] for k in keys]):
        combo = dict(zip(keys, values))
        combos.append(combo)
    # Apply excludes
    for excl in m.get("exclude", []):
        combos = [c for c in combos if not all(c.get(k) == v for k, v in excl.items())]
    # Apply includes (append only; GH Actions include semantics are more complex
    # but for combo-count purposes, simple append suffices here)
    for inc in m.get("include", []):
        combos.append(inc)
    return combos


def _expand(matrix):
    from itertools import product
    keys = [k for k in matrix if k not in ("include", "exclude")]
    out = []
    for values in product(*[matrix[k] for k in keys]):
        out.append(dict(zip(keys, values)))
    return out


# --- 2. Exclude rules remove specific combinations ---

def test_exclude_removes_combination():
    config = {
        "axes": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.11", "3.12"],
        },
        "exclude": [
            {"os": "windows-latest", "python": "3.11"},
        ],
    }
    result = generate_matrix(config)
    combos = _all_combos(result)
    # 4 - 1 = 3
    assert len(combos) == 3
    assert not any(c == {"os": "windows-latest", "python": "3.11"} for c in combos)


# --- 3. Include rules add extra combinations ---

def test_include_adds_extra_combo():
    config = {
        "axes": {"os": ["ubuntu-latest"], "python": ["3.12"]},
        "include": [
            {"os": "macos-latest", "python": "3.13", "experimental": True},
        ],
    }
    result = generate_matrix(config)
    combos = _all_combos(result)
    assert len(combos) == 2
    assert any(c.get("experimental") is True for c in combos)


# --- 4. max-parallel and fail-fast are preserved in output ---

def test_strategy_fields_preserved():
    config = {
        "axes": {"os": ["ubuntu-latest"]},
        "max-parallel": 4,
        "fail-fast": False,
    }
    result = generate_matrix(config)
    assert result["max-parallel"] == 4
    assert result["fail-fast"] is False


# --- 5. Default fail-fast is True (GH Actions default) ---

def test_default_fail_fast_true():
    config = {"axes": {"os": ["ubuntu-latest"]}}
    result = generate_matrix(config)
    assert result["fail-fast"] is True


# --- 6. Max size validation ---

def test_max_size_exceeded_raises():
    config = {
        "axes": {
            "a": list(range(10)),
            "b": list(range(10)),
            "c": list(range(10)),
        },
        "max-size": 100,
    }
    with pytest.raises(MatrixError, match="exceeds maximum size"):
        generate_matrix(config)


def test_max_size_respected_after_exclude():
    # 2*2=4 minus 1 exclude = 3; max-size 3 should pass.
    config = {
        "axes": {"a": [1, 2], "b": [1, 2]},
        "exclude": [{"a": 1, "b": 1}],
        "max-size": 3,
    }
    result = generate_matrix(config)
    assert len(_all_combos(result)) == 3


# --- 7. GH Actions 256 hard limit enforced by default ---

def test_default_hard_limit_256():
    config = {"axes": {"a": list(range(300))}}
    with pytest.raises(MatrixError, match="256"):
        generate_matrix(config)


# --- 8. Empty axes is an error ---

def test_empty_config_raises():
    with pytest.raises(MatrixError, match="at least one axis"):
        generate_matrix({"axes": {}})


def test_missing_axes_raises():
    with pytest.raises(MatrixError, match="at least one axis"):
        generate_matrix({})


# --- 9. Feature flags act as an axis ---

def test_feature_flags_as_axis():
    config = {
        "axes": {
            "os": ["ubuntu-latest"],
            "features": ["minimal", "full"],
        }
    }
    result = generate_matrix(config)
    combos = _all_combos(result)
    assert {c["features"] for c in combos} == {"minimal", "full"}


# --- 10. CLI reads stdin and prints JSON to stdout ---

def test_cli_reads_stdin_writes_stdout():
    config = {"axes": {"os": ["ubuntu-latest"]}}
    proc = subprocess.run(
        [sys.executable, "matrix_generator.py"],
        input=json.dumps(config),
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["fail-fast"] is True
    assert "matrix" in payload


def test_cli_invalid_json_exits_nonzero():
    proc = subprocess.run(
        [sys.executable, "matrix_generator.py"],
        input="{not json",
        capture_output=True,
        text=True,
    )
    assert proc.returncode != 0
    assert "Invalid JSON" in proc.stderr


def test_cli_exceeds_max_size_exits_nonzero():
    config = {"axes": {"a": list(range(20)), "b": list(range(20))}, "max-size": 10}
    proc = subprocess.run(
        [sys.executable, "matrix_generator.py"],
        input=json.dumps(config),
        capture_output=True,
        text=True,
    )
    assert proc.returncode != 0
    assert "exceeds maximum size" in proc.stderr
