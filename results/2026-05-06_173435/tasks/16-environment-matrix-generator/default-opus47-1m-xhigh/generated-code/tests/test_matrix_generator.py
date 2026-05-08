"""Unit tests for matrix_generator.

TDD: each test is added red-first; the matching production code in
matrix_generator.py is the minimum needed to make it green.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

from matrix_generator import generate_matrix, MatrixError


def test_basic_cartesian_product():
    """A config with two axes produces every combination (axes x axes)."""
    config = {
        "axes": {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11", "3.12"],
        }
    }
    result = generate_matrix(config)
    # GitHub Actions strategy block: matrix carries the include list of
    # explicit combinations so we don't depend on Action's own expansion.
    assert "matrix" in result
    assert "include" in result["matrix"]
    combos = result["matrix"]["include"]
    assert len(combos) == 4
    assert {"os": "ubuntu-latest", "python": "3.11"} in combos
    assert {"os": "ubuntu-latest", "python": "3.12"} in combos
    assert {"os": "macos-latest", "python": "3.11"} in combos
    assert {"os": "macos-latest", "python": "3.12"} in combos


def test_exclude_rule_drops_matching_combinations():
    """An exclude entry whose key/value pairs all match drops the combo."""
    config = {
        "axes": {
            "os": ["ubuntu-latest", "macos-latest", "windows-latest"],
            "python": ["3.11", "3.12"],
        },
        "exclude": [
            {"os": "windows-latest", "python": "3.11"},
            {"os": "macos-latest"},  # drops both macos rows
        ],
    }
    combos = generate_matrix(config)["matrix"]["include"]
    assert len(combos) == 3
    assert {"os": "windows-latest", "python": "3.11"} not in combos
    assert {"os": "macos-latest", "python": "3.11"} not in combos
    assert {"os": "macos-latest", "python": "3.12"} not in combos
    assert {"os": "ubuntu-latest", "python": "3.11"} in combos
    assert {"os": "ubuntu-latest", "python": "3.12"} in combos
    assert {"os": "windows-latest", "python": "3.12"} in combos


def test_include_adds_new_combination_when_no_match():
    """An include entry that doesn't match any existing combo is appended."""
    config = {
        "axes": {
            "os": ["ubuntu-latest"],
            "python": ["3.11"],
        },
        "include": [
            {"os": "windows-latest", "python": "3.12", "experimental": True},
        ],
    }
    combos = generate_matrix(config)["matrix"]["include"]
    assert len(combos) == 2
    assert {"os": "ubuntu-latest", "python": "3.11"} in combos
    assert {
        "os": "windows-latest",
        "python": "3.12",
        "experimental": True,
    } in combos


def test_include_augments_matching_combination():
    """An include entry that fully matches a combo on its existing keys
    augments that combo with its extra keys (GitHub Actions semantics)."""
    config = {
        "axes": {
            "os": ["ubuntu-latest", "macos-latest"],
            "python": ["3.11", "3.12"],
        },
        "include": [
            # matches the ubuntu+3.12 combo, adds experimental flag to it
            {"os": "ubuntu-latest", "python": "3.12", "experimental": True},
        ],
    }
    combos = generate_matrix(config)["matrix"]["include"]
    assert len(combos) == 4  # no new combo, augmentation only
    augmented = next(
        c for c in combos
        if c["os"] == "ubuntu-latest" and c["python"] == "3.12"
    )
    assert augmented.get("experimental") is True
    other = next(
        c for c in combos
        if c["os"] == "macos-latest" and c["python"] == "3.11"
    )
    assert "experimental" not in other


def test_max_parallel_passes_through():
    config = {"axes": {"os": ["ubuntu-latest"]}, "max_parallel": 4}
    result = generate_matrix(config)
    assert result["max-parallel"] == 4


def test_fail_fast_passes_through():
    config = {"axes": {"os": ["ubuntu-latest"]}, "fail_fast": False}
    result = generate_matrix(config)
    assert result["fail-fast"] is False


def test_strategy_options_omitted_when_unset():
    """Don't add optional strategy keys unless the user asked for them."""
    result = generate_matrix({"axes": {"os": ["ubuntu-latest"]}})
    assert "max-parallel" not in result
    assert "fail-fast" not in result


def test_max_size_violation_raises():
    """If the final matrix exceeds max_size, raise MatrixError."""
    config = {
        "axes": {
            "os": ["a", "b", "c"],
            "v": ["1", "2", "3"],  # 9 combos
        },
        "max_size": 5,
    }
    with pytest.raises(MatrixError) as exc:
        generate_matrix(config)
    assert "9" in str(exc.value)
    assert "5" in str(exc.value)


def test_max_size_default_is_256():
    """Default cap matches GitHub Actions' own 256-job-per-matrix limit."""
    # 17*16 = 272 combinations exceed 256 with no explicit max_size.
    config = {
        "axes": {
            "x": [str(i) for i in range(17)],
            "y": [str(i) for i in range(16)],
        },
    }
    with pytest.raises(MatrixError):
        generate_matrix(config)


def test_feature_flags_are_a_first_class_axis():
    """Boolean feature flags expand like any other axis."""
    config = {
        "axes": {
            "os": ["ubuntu-latest"],
            "python": ["3.12"],
            "with_redis": [True, False],
            "with_postgres": [True, False],
        },
    }
    combos = generate_matrix(config)["matrix"]["include"]
    assert len(combos) == 4
    flag_pairs = {(c["with_redis"], c["with_postgres"]) for c in combos}
    assert flag_pairs == {(True, True), (True, False),
                          (False, True), (False, False)}


def test_invalid_axes_type_raises():
    with pytest.raises(MatrixError):
        generate_matrix({"axes": "not-a-dict"})


def test_invalid_exclude_type_raises():
    with pytest.raises(MatrixError):
        generate_matrix({
            "axes": {"os": ["ubuntu-latest"]},
            "exclude": {"os": "ubuntu-latest"},  # should be a list
        })


def test_invalid_include_type_raises():
    with pytest.raises(MatrixError):
        generate_matrix({
            "axes": {"os": ["ubuntu-latest"]},
            "include": {"os": "ubuntu-latest"},  # should be a list
        })


def test_empty_axes_with_include_only():
    """A pure-include matrix (no axes) is valid and yields the includes."""
    config = {
        "include": [
            {"os": "ubuntu-latest", "python": "3.12"},
            {"os": "windows-latest", "python": "3.11", "experimental": True},
        ],
    }
    combos = generate_matrix(config)["matrix"]["include"]
    assert len(combos) == 2


# --- CLI behavior (still invokes the script in-process via subprocess
# only to validate the entrypoint shape; the *real* end-to-end is the
# act-driven harness in run_act_tests.py). ---

def test_cli_reads_json_and_writes_json(tmp_path):
    config = {
        "axes": {"os": ["ubuntu-latest"], "python": ["3.12"]},
        "max_parallel": 2,
        "fail_fast": True,
    }
    cfg_path = tmp_path / "cfg.json"
    cfg_path.write_text(json.dumps(config))
    script = Path(__file__).resolve().parents[1] / "matrix_generator.py"
    proc = subprocess.run(
        [sys.executable, str(script), str(cfg_path)],
        capture_output=True, text=True, check=False,
    )
    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert payload["matrix"]["include"] == [
        {"os": "ubuntu-latest", "python": "3.12"},
    ]
    assert payload["max-parallel"] == 2
    assert payload["fail-fast"] is True


def test_cli_returns_nonzero_and_message_on_max_size_violation(tmp_path):
    config = {"axes": {"x": ["a", "b", "c"]}, "max_size": 1}
    cfg_path = tmp_path / "cfg.json"
    cfg_path.write_text(json.dumps(config))
    script = Path(__file__).resolve().parents[1] / "matrix_generator.py"
    proc = subprocess.run(
        [sys.executable, str(script), str(cfg_path)],
        capture_output=True, text=True, check=False,
    )
    assert proc.returncode == 2
    assert "exceeds" in proc.stderr.lower() or "max_size" in proc.stderr
