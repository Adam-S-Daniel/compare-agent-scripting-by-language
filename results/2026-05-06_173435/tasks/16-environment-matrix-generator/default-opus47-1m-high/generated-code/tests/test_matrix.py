"""Tests for the GitHub Actions matrix generator (TDD red/green).

Each test corresponds to a step in the red/green cycle: write the failing
test, then implement the minimum code in matrix.py that makes it pass.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

# Make matrix.py importable when tests run from the repo root.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from matrix import (  # noqa: E402
    MatrixError,
    build_matrix,
    expand_combinations,
    generate,
    load_config,
)


# ---------------------------------------------------------------------------
# expand_combinations: cartesian product across axes, with include/exclude.
# ---------------------------------------------------------------------------

def test_expand_combinations_simple_cartesian_product():
    """Two axes of size 2 produce 4 combinations."""
    axes = {"os": ["ubuntu-latest", "windows-latest"], "py": ["3.10", "3.11"]}
    combos = expand_combinations(axes, includes=[], excludes=[])
    assert len(combos) == 4
    assert {"os": "ubuntu-latest", "py": "3.10"} in combos
    assert {"os": "windows-latest", "py": "3.11"} in combos


def test_expand_combinations_exclude_removes_matching():
    """Excludes drop any combo whose listed keys all match."""
    axes = {"os": ["ubuntu-latest", "windows-latest"], "py": ["3.10", "3.11"]}
    excludes = [{"os": "windows-latest", "py": "3.10"}]
    combos = expand_combinations(axes, includes=[], excludes=excludes)
    assert len(combos) == 3
    assert {"os": "windows-latest", "py": "3.10"} not in combos


def test_expand_combinations_include_adds_new_combo():
    """Include with all axis keys appends a new combo not in the product."""
    axes = {"os": ["ubuntu-latest"], "py": ["3.10"]}
    includes = [{"os": "macos-latest", "py": "3.12"}]
    combos = expand_combinations(axes, includes=includes, excludes=[])
    assert len(combos) == 2
    assert {"os": "macos-latest", "py": "3.12"} in combos


def test_expand_combinations_include_extends_existing_combo():
    """Include matching an existing combo (subset of axis keys) merges extra keys."""
    axes = {"os": ["ubuntu-latest"], "py": ["3.10", "3.11"]}
    # Adds an `experimental` key only to the (ubuntu, 3.11) combo.
    includes = [{"os": "ubuntu-latest", "py": "3.11", "experimental": True}]
    combos = expand_combinations(axes, includes=includes, excludes=[])
    assert len(combos) == 2
    matched = next(c for c in combos if c["py"] == "3.11")
    assert matched["experimental"] is True
    other = next(c for c in combos if c["py"] == "3.10")
    assert "experimental" not in other


# ---------------------------------------------------------------------------
# build_matrix: combines axes + feature flags + include/exclude into the
# GitHub Actions strategy.matrix shape.
# ---------------------------------------------------------------------------

def test_build_matrix_feature_flags_become_axes():
    """Feature flags are flattened into matrix axes."""
    cfg = {
        "os": ["ubuntu-latest"],
        "language_version": ["3.11"],
        "feature_flags": {"redis": [True, False]},
    }
    out = build_matrix(cfg)
    matrix = out["strategy"]["matrix"]
    assert matrix["redis"] == [True, False]
    assert matrix["os"] == ["ubuntu-latest"]
    assert matrix["language_version"] == ["3.11"]


def test_build_matrix_includes_max_parallel_and_fail_fast():
    """max_parallel and fail_fast pass through to the strategy block."""
    cfg = {
        "os": ["ubuntu-latest"],
        "language_version": ["3.11"],
        "max_parallel": 3,
        "fail_fast": False,
    }
    out = build_matrix(cfg)
    assert out["strategy"]["max-parallel"] == 3
    assert out["strategy"]["fail-fast"] is False


def test_build_matrix_omits_strategy_keys_when_unset():
    """If max_parallel/fail_fast are not provided, omit them rather than emit nulls."""
    cfg = {"os": ["ubuntu-latest"], "language_version": ["3.11"]}
    out = build_matrix(cfg)
    assert "max-parallel" not in out["strategy"]
    assert "fail-fast" not in out["strategy"]


def test_build_matrix_passes_through_include_exclude():
    cfg = {
        "os": ["ubuntu-latest", "windows-latest"],
        "language_version": ["3.11"],
        "include": [{"os": "macos-latest", "language_version": "3.12"}],
        "exclude": [{"os": "windows-latest", "language_version": "3.11"}],
    }
    out = build_matrix(cfg)
    matrix = out["strategy"]["matrix"]
    assert matrix["include"] == [{"os": "macos-latest", "language_version": "3.12"}]
    assert matrix["exclude"] == [{"os": "windows-latest", "language_version": "3.11"}]


# ---------------------------------------------------------------------------
# Validation: max_size and malformed input.
# ---------------------------------------------------------------------------

def test_build_matrix_raises_when_expansion_exceeds_max_size():
    cfg = {
        "os": ["a", "b", "c"],
        "language_version": ["1", "2", "3"],
        "max_size": 4,
    }
    with pytest.raises(MatrixError) as exc:
        build_matrix(cfg)
    assert "max_size" in str(exc.value)
    assert "9" in str(exc.value)  # actual count surfaces in the message


def test_build_matrix_within_max_size_succeeds():
    cfg = {
        "os": ["a", "b"],
        "language_version": ["1", "2"],
        "max_size": 4,
    }
    out = build_matrix(cfg)
    assert out["expanded_size"] == 4


def test_build_matrix_excludes_count_against_max_size():
    """Excluded combos shouldn't push us over max_size."""
    cfg = {
        "os": ["a", "b", "c"],
        "language_version": ["1", "2", "3"],
        "exclude": [
            {"os": "a", "language_version": "1"},
            {"os": "b", "language_version": "2"},
            {"os": "c", "language_version": "3"},
            {"os": "a", "language_version": "2"},
            {"os": "b", "language_version": "3"},
        ],
        "max_size": 4,
    }
    out = build_matrix(cfg)
    assert out["expanded_size"] == 4


def test_build_matrix_rejects_empty_axis():
    """An axis with no values would zero out the cartesian product."""
    cfg = {"os": [], "language_version": ["3.11"]}
    with pytest.raises(MatrixError) as exc:
        build_matrix(cfg)
    assert "empty" in str(exc.value).lower()


def test_build_matrix_requires_os_and_language_version():
    cfg = {"os": ["ubuntu-latest"]}
    with pytest.raises(MatrixError) as exc:
        build_matrix(cfg)
    assert "language_version" in str(exc.value)


# ---------------------------------------------------------------------------
# load_config: read JSON from a path.
# ---------------------------------------------------------------------------

def test_load_config_reads_json_file(tmp_path):
    path = tmp_path / "cfg.json"
    path.write_text(json.dumps({"os": ["ubuntu-latest"], "language_version": ["3.11"]}))
    cfg = load_config(str(path))
    assert cfg["os"] == ["ubuntu-latest"]


def test_load_config_missing_file_raises():
    with pytest.raises(MatrixError) as exc:
        load_config("/nonexistent/path/config.json")
    assert "not found" in str(exc.value).lower()


def test_load_config_invalid_json_raises(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text("{not valid json")
    with pytest.raises(MatrixError) as exc:
        load_config(str(path))
    assert "json" in str(exc.value).lower()


# ---------------------------------------------------------------------------
# generate: end-to-end (read config -> emit JSON string).
# ---------------------------------------------------------------------------

def test_generate_returns_json_string_with_strategy_block(tmp_path):
    cfg = {
        "os": ["ubuntu-latest"],
        "language_version": ["3.11"],
        "feature_flags": {"redis": [True]},
        "max_parallel": 2,
        "fail_fast": True,
    }
    path = tmp_path / "cfg.json"
    path.write_text(json.dumps(cfg))
    text = generate(str(path))
    parsed = json.loads(text)
    assert parsed["strategy"]["matrix"]["os"] == ["ubuntu-latest"]
    assert parsed["strategy"]["matrix"]["redis"] == [True]
    assert parsed["strategy"]["max-parallel"] == 2
    assert parsed["strategy"]["fail-fast"] is True


# ---------------------------------------------------------------------------
# CLI: matrix.py runs as a script and writes JSON to stdout.
# ---------------------------------------------------------------------------

def test_cli_emits_matrix_json_for_valid_config(tmp_path):
    cfg = {
        "os": ["ubuntu-latest", "windows-latest"],
        "language_version": ["3.11", "3.12"],
        "max_parallel": 4,
        "fail_fast": False,
    }
    path = tmp_path / "cfg.json"
    path.write_text(json.dumps(cfg))
    result = subprocess.run(
        [sys.executable, str(ROOT / "matrix.py"), str(path)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    parsed = json.loads(result.stdout)
    assert parsed["strategy"]["max-parallel"] == 4
    assert parsed["expanded_size"] == 4


def test_cli_exits_nonzero_on_error(tmp_path):
    cfg = {"os": ["a"], "language_version": ["1", "2", "3"], "max_size": 1}
    path = tmp_path / "cfg.json"
    path.write_text(json.dumps(cfg))
    result = subprocess.run(
        [sys.executable, str(ROOT / "matrix.py"), str(path)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode != 0
    assert "max_size" in result.stderr
