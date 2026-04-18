"""Unit tests for matrix_generator.

TDD approach: each test exercises one piece of behaviour in isolation.
The module is implemented to make these tests pass.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

# Make matrix_generator importable from the repo root regardless of how
# pytest is invoked.
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from matrix_generator import (  # noqa: E402
    MatrixError,
    build_matrix,
    cartesian_combinations,
    effective_combinations,
    load_config,
    matches_rule,
)


# --- pure helpers ----------------------------------------------------------


def test_cartesian_product_of_axes():
    # Smallest meaningful case: two axes, returns every combination.
    axes = {"os": ["ubuntu", "macos"], "py": ["3.10", "3.11"]}
    combos = cartesian_combinations(axes)
    assert len(combos) == 4
    assert {"os": "ubuntu", "py": "3.10"} in combos
    assert {"os": "macos", "py": "3.11"} in combos


def test_cartesian_product_single_axis():
    axes = {"os": ["ubuntu"]}
    combos = cartesian_combinations(axes)
    assert combos == [{"os": "ubuntu"}]


def test_cartesian_product_empty_axis_yields_nothing():
    axes = {"os": []}
    assert cartesian_combinations(axes) == []


def test_matches_rule_exact():
    combo = {"os": "ubuntu", "py": "3.10"}
    assert matches_rule(combo, {"os": "ubuntu"})
    assert matches_rule(combo, {"os": "ubuntu", "py": "3.10"})
    assert not matches_rule(combo, {"os": "macos"})
    # A rule referring to a key not on the combo cannot match.
    assert not matches_rule(combo, {"node": "20"})


# --- core matrix building --------------------------------------------------


def test_build_matrix_minimal():
    cfg = {"matrix": {"os": ["ubuntu-latest"], "python": ["3.12"]}}
    result = build_matrix(cfg)
    assert result["matrix"]["os"] == ["ubuntu-latest"]
    assert result["matrix"]["python"] == ["3.12"]
    assert result["total_combinations"] == 1
    # fail-fast / max-parallel omitted when not configured.
    assert "fail-fast" not in result
    assert "max-parallel" not in result


def test_build_matrix_cartesian_count():
    cfg = {
        "matrix": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.10", "3.11", "3.12"],
        }
    }
    result = build_matrix(cfg)
    # 2 * 3 = 6 combinations.
    assert result["total_combinations"] == 6


def test_build_matrix_with_excludes():
    cfg = {
        "matrix": {
            "os": ["ubuntu-latest", "windows-latest"],
            "python": ["3.10", "3.11"],
        },
        "exclude": [{"os": "windows-latest", "python": "3.10"}],
    }
    result = build_matrix(cfg)
    # 4 combos - 1 excluded = 3.
    assert result["total_combinations"] == 3
    # Exclude rule preserved in the matrix block.
    assert result["matrix"]["exclude"] == [
        {"os": "windows-latest", "python": "3.10"}
    ]


def test_build_matrix_with_includes_new_row():
    cfg = {
        "matrix": {
            "os": ["ubuntu-latest"],
            "python": ["3.12"],
        },
        "include": [{"os": "macos-latest", "python": "3.12", "extra": "coverage"}],
    }
    result = build_matrix(cfg)
    # 1 base + 1 fully new include = 2 combinations.
    assert result["total_combinations"] == 2
    assert result["matrix"]["include"] == [
        {"os": "macos-latest", "python": "3.12", "extra": "coverage"}
    ]


def test_build_matrix_include_extends_existing_row():
    # An include whose values match an existing combo adds keys but does not
    # create a new row (GitHub Actions semantics).
    cfg = {
        "matrix": {
            "os": ["ubuntu-latest"],
            "python": ["3.12"],
        },
        "include": [{"os": "ubuntu-latest", "python": "3.12", "coverage": True}],
    }
    result = build_matrix(cfg)
    assert result["total_combinations"] == 1


def test_build_matrix_fail_fast_and_max_parallel():
    cfg = {
        "matrix": {"os": ["ubuntu-latest"], "python": ["3.12"]},
        "fail_fast": False,
        "max_parallel": 4,
    }
    result = build_matrix(cfg)
    assert result["fail-fast"] is False
    assert result["max-parallel"] == 4


def test_build_matrix_feature_flags_axis():
    cfg = {
        "matrix": {
            "os": ["ubuntu-latest"],
            "python": ["3.12"],
            "features": ["minimal", "full"],
        }
    }
    result = build_matrix(cfg)
    assert result["total_combinations"] == 2
    assert set(result["matrix"]["features"]) == {"minimal", "full"}


# --- validation ------------------------------------------------------------


def test_max_size_exceeded_raises():
    cfg = {
        "matrix": {
            "os": ["a", "b", "c"],
            "py": ["1", "2", "3"],
        },
        "max_size": 5,
    }
    with pytest.raises(MatrixError) as exc:
        build_matrix(cfg)
    assert "exceeds maximum" in str(exc.value)
    assert "9" in str(exc.value)  # reports actual size.


def test_max_size_respected_exactly():
    cfg = {
        "matrix": {"os": ["a", "b"], "py": ["1", "2"]},
        "max_size": 4,
    }
    # Should not raise; boundary value accepted.
    result = build_matrix(cfg)
    assert result["total_combinations"] == 4


def test_empty_matrix_raises():
    with pytest.raises(MatrixError):
        build_matrix({"matrix": {}})


def test_missing_matrix_key_raises():
    with pytest.raises(MatrixError):
        build_matrix({})


def test_non_list_axis_value_raises():
    with pytest.raises(MatrixError):
        build_matrix({"matrix": {"os": "ubuntu-latest"}})


def test_invalid_max_parallel_raises():
    cfg = {"matrix": {"os": ["u"]}, "max_parallel": 0}
    with pytest.raises(MatrixError):
        build_matrix(cfg)


# --- effective_combinations (used by CLI for verification) -----------------


def test_effective_combinations_lists_rows():
    cfg = {
        "matrix": {"os": ["u", "w"], "py": ["3.12"]},
        "exclude": [{"os": "w"}],
        "include": [{"os": "m", "py": "3.12"}],
    }
    rows = effective_combinations(cfg)
    # u/3.12 kept, w/3.12 excluded, m/3.12 added.
    osses = sorted(r["os"] for r in rows)
    assert osses == ["m", "u"]


# --- CLI / end-to-end ------------------------------------------------------


def test_load_config_parses_json(tmp_path):
    cfg_path = tmp_path / "cfg.json"
    cfg_path.write_text(json.dumps({"matrix": {"os": ["u"]}}))
    cfg = load_config(str(cfg_path))
    assert cfg == {"matrix": {"os": ["u"]}}


def test_load_config_bad_json_raises(tmp_path):
    cfg_path = tmp_path / "bad.json"
    cfg_path.write_text("{not json")
    with pytest.raises(MatrixError):
        load_config(str(cfg_path))


def test_load_config_missing_file_raises(tmp_path):
    with pytest.raises(MatrixError):
        load_config(str(tmp_path / "nope.json"))


def test_cli_success(tmp_path):
    # End-to-end: write a config, invoke the CLI, parse its stdout.
    cfg_path = tmp_path / "cfg.json"
    cfg_path.write_text(
        json.dumps(
            {
                "matrix": {"os": ["ubuntu-latest"], "python": ["3.12"]},
                "fail_fast": True,
                "max_parallel": 2,
            }
        )
    )
    proc = subprocess.run(
        [sys.executable, str(ROOT / "matrix_generator.py"), "--config", str(cfg_path)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert data["fail-fast"] is True
    assert data["max-parallel"] == 2
    assert data["total_combinations"] == 1


def test_cli_exceeds_max_size_exits_nonzero(tmp_path):
    cfg_path = tmp_path / "cfg.json"
    cfg_path.write_text(
        json.dumps(
            {
                "matrix": {"os": ["a", "b", "c"], "py": ["1", "2", "3"]},
                "max_size": 5,
            }
        )
    )
    proc = subprocess.run(
        [sys.executable, str(ROOT / "matrix_generator.py"), "--config", str(cfg_path)],
        capture_output=True,
        text=True,
    )
    assert proc.returncode != 0
    assert "exceeds maximum" in proc.stderr
