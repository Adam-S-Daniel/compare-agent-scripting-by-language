# Tests for matrix_generator.py — written FIRST (TDD red phase).
# Each test describes a required behaviour; all will fail until the
# implementation is complete.

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from matrix_generator import (
    MatrixSizeError,
    compute_base_size,
    generate_matrix,
    validate_config,
)

# ---------------------------------------------------------------------------
# compute_base_size
# ---------------------------------------------------------------------------

def test_compute_base_size_single_dim():
    assert compute_base_size({"os": ["a", "b", "c"]}) == 3


def test_compute_base_size_two_dims():
    assert compute_base_size({"os": ["a", "b"], "python-version": ["3.9", "3.10", "3.11"]}) == 6


def test_compute_base_size_empty():
    assert compute_base_size({}) == 0


def test_compute_base_size_ignores_non_list():
    # include/exclude entries are dicts — they shouldn't be counted
    dims = {"os": ["a", "b"], "include": [{"os": "c"}]}
    assert compute_base_size(dims) == 2


# ---------------------------------------------------------------------------
# validate_config
# ---------------------------------------------------------------------------

def test_validate_config_missing_os():
    with pytest.raises(ValueError, match="os"):
        validate_config({})


def test_validate_config_os_not_list():
    with pytest.raises(ValueError, match="os"):
        validate_config({"os": "ubuntu-latest"})


def test_validate_config_os_empty():
    with pytest.raises(ValueError, match="os"):
        validate_config({"os": []})


def test_validate_config_max_parallel_non_positive():
    with pytest.raises(ValueError, match="max_parallel"):
        validate_config({"os": ["ubuntu-latest"], "max_parallel": 0})


def test_validate_config_max_size_non_positive():
    with pytest.raises(ValueError, match="max_size"):
        validate_config({"os": ["ubuntu-latest"], "max_size": 0})


def test_validate_config_valid_minimal():
    # should not raise
    validate_config({"os": ["ubuntu-latest"]})


def test_validate_config_valid_full():
    validate_config({
        "os": ["ubuntu-latest", "windows-latest"],
        "language_versions": {"python-version": ["3.9", "3.10"]},
        "feature_flags": {"experimental": [True, False]},
        "include": [{"os": "macos-latest"}],
        "exclude": [{"os": "windows-latest", "python-version": "3.9"}],
        "fail_fast": False,
        "max_parallel": 4,
        "max_size": 50,
    })


# ---------------------------------------------------------------------------
# generate_matrix — structure
# ---------------------------------------------------------------------------

MINIMAL_CONFIG = {
    "os": ["ubuntu-latest", "windows-latest"],
}

FULL_CONFIG = {
    "os": ["ubuntu-latest", "windows-latest"],
    "language_versions": {"python-version": ["3.9", "3.10", "3.11"]},
    "fail_fast": False,
    "max_parallel": 4,
    "max_size": 100,
}


def test_generate_matrix_returns_dict():
    result = generate_matrix(MINIMAL_CONFIG)
    assert isinstance(result, dict)


def test_generate_matrix_has_matrix_key():
    result = generate_matrix(MINIMAL_CONFIG)
    assert "matrix" in result


def test_generate_matrix_os_in_matrix():
    result = generate_matrix(MINIMAL_CONFIG)
    assert result["matrix"]["os"] == ["ubuntu-latest", "windows-latest"]


def test_generate_matrix_language_versions():
    result = generate_matrix(FULL_CONFIG)
    assert result["matrix"]["python-version"] == ["3.9", "3.10", "3.11"]


def test_generate_matrix_fail_fast_false():
    result = generate_matrix(FULL_CONFIG)
    assert result["fail-fast"] is False


def test_generate_matrix_fail_fast_default_true():
    result = generate_matrix(MINIMAL_CONFIG)
    assert result["fail-fast"] is True


def test_generate_matrix_max_parallel():
    result = generate_matrix(FULL_CONFIG)
    assert result["max-parallel"] == 4


def test_generate_matrix_no_max_parallel_when_absent():
    result = generate_matrix(MINIMAL_CONFIG)
    assert "max-parallel" not in result


def test_generate_matrix_feature_flags():
    cfg = {
        "os": ["ubuntu-latest"],
        "feature_flags": {"experimental": [True, False]},
        "max_size": 10,
    }
    result = generate_matrix(cfg)
    assert result["matrix"]["experimental"] == [True, False]


# ---------------------------------------------------------------------------
# generate_matrix — include / exclude
# ---------------------------------------------------------------------------

def test_generate_matrix_include():
    cfg = {
        "os": ["ubuntu-latest"],
        "language_versions": {"python-version": ["3.9"]},
        "include": [{"os": "macos-latest", "python-version": "3.11"}],
        "max_size": 10,
    }
    result = generate_matrix(cfg)
    assert result["matrix"]["include"] == [{"os": "macos-latest", "python-version": "3.11"}]


def test_generate_matrix_exclude():
    cfg = {
        "os": ["ubuntu-latest", "windows-latest"],
        "language_versions": {"python-version": ["3.9", "3.10"]},
        "exclude": [{"os": "windows-latest", "python-version": "3.9"}],
        "max_size": 10,
    }
    result = generate_matrix(cfg)
    assert result["matrix"]["exclude"] == [{"os": "windows-latest", "python-version": "3.9"}]


def test_generate_matrix_no_include_key_when_absent():
    result = generate_matrix(MINIMAL_CONFIG)
    assert "include" not in result["matrix"]


def test_generate_matrix_no_exclude_key_when_absent():
    result = generate_matrix(MINIMAL_CONFIG)
    assert "exclude" not in result["matrix"]


# ---------------------------------------------------------------------------
# generate_matrix — size validation
# ---------------------------------------------------------------------------

def test_generate_matrix_exceeds_max_size():
    cfg = {
        "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
        "language_versions": {"python-version": ["3.9", "3.10", "3.11"]},
        "max_size": 5,
    }
    with pytest.raises(MatrixSizeError, match="exceeds"):
        generate_matrix(cfg)


def test_generate_matrix_at_max_size_ok():
    cfg = {
        "os": ["ubuntu-latest", "windows-latest"],
        "language_versions": {"python-version": ["3.9", "3.10", "3.11"]},
        "max_size": 6,
    }
    result = generate_matrix(cfg)
    assert result["matrix"]["os"] == ["ubuntu-latest", "windows-latest"]


def test_generate_matrix_default_max_size_256():
    # 16x16 = 256 should be ok; 17x16 = 272 should fail with default max
    cfg_ok = {
        "os": [f"os-{i}" for i in range(16)],
        "language_versions": {"v": [str(i) for i in range(16)]},
    }
    result = generate_matrix(cfg_ok)
    assert "matrix" in result

    cfg_fail = {
        "os": [f"os-{i}" for i in range(17)],
        "language_versions": {"v": [str(i) for i in range(16)]},
    }
    with pytest.raises(MatrixSizeError):
        generate_matrix(cfg_fail)


# ---------------------------------------------------------------------------
# CLI (main) — round-trip via subprocess
# ---------------------------------------------------------------------------

SCRIPT = str(Path(__file__).parent.parent / "matrix_generator.py")


def _run_cli(config: dict) -> subprocess.CompletedProcess:
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(config, f)
        config_path = f.name
    return subprocess.run(
        [sys.executable, SCRIPT, config_path],
        capture_output=True,
        text=True,
    )


def test_cli_success_exit_zero():
    proc = _run_cli(FULL_CONFIG)
    assert proc.returncode == 0, proc.stderr


def test_cli_output_is_valid_json():
    proc = _run_cli(FULL_CONFIG)
    assert proc.returncode == 0
    data = json.loads(proc.stdout)
    assert "matrix" in data


def test_cli_error_exit_nonzero_on_exceeded_size():
    cfg = {
        "os": ["a", "b", "c"],
        "language_versions": {"v": ["1", "2"]},
        "max_size": 2,
    }
    proc = _run_cli(cfg)
    assert proc.returncode != 0


def test_cli_error_message_on_exceeded_size():
    cfg = {
        "os": ["a", "b", "c"],
        "language_versions": {"v": ["1", "2"]},
        "max_size": 2,
    }
    proc = _run_cli(cfg)
    assert "exceeds" in proc.stderr.lower() or "exceeds" in proc.stdout.lower()


def test_cli_missing_file():
    proc = subprocess.run(
        [sys.executable, SCRIPT, "/nonexistent/config.json"],
        capture_output=True,
        text=True,
    )
    assert proc.returncode != 0


def test_cli_invalid_json_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        f.write("not valid json {{{")
        bad_path = f.name
    proc = subprocess.run(
        [sys.executable, SCRIPT, bad_path],
        capture_output=True,
        text=True,
    )
    assert proc.returncode != 0
