"""
Tests for the environment matrix generator.
Uses red/green TDD: each test was written BEFORE the corresponding implementation.
"""
import json
import subprocess
import sys
import pytest
from pathlib import Path

# Add parent dir to path so we can import the module
sys.path.insert(0, str(Path(__file__).parent.parent))


# --- Test 1: Basic matrix generation from simple config ---
# Written FIRST (red phase) - no implementation yet
def test_basic_matrix_generation():
    """Generate a matrix from OS + language versions, no rules."""
    from matrix_generator import generate_matrix

    config = {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
    }
    result = generate_matrix(config)

    assert "matrix" in result
    combos = result["matrix"]["include"]
    assert len(combos) == 4
    assert {"os": "ubuntu-latest", "python-version": "3.10"} in combos
    assert {"os": "ubuntu-latest", "python-version": "3.11"} in combos
    assert {"os": "windows-latest", "python-version": "3.10"} in combos
    assert {"os": "windows-latest", "python-version": "3.11"} in combos


# --- Test 2: Feature flags included in matrix ---
def test_matrix_with_feature_flags():
    """Feature flags create additional matrix dimensions."""
    from matrix_generator import generate_matrix

    config = {
        "os": ["ubuntu-latest"],
        "python-version": ["3.11"],
        "experimental": [True, False],
    }
    result = generate_matrix(config)
    combos = result["matrix"]["include"]
    assert len(combos) == 2
    assert {"os": "ubuntu-latest", "python-version": "3.11", "experimental": True} in combos
    assert {"os": "ubuntu-latest", "python-version": "3.11", "experimental": False} in combos


# --- Test 3: Exclude rules ---
def test_exclude_rules():
    """Exclude rules remove matching combinations from the matrix."""
    from matrix_generator import generate_matrix

    config = {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "exclude": [
            {"os": "windows-latest", "python-version": "3.10"}
        ],
    }
    result = generate_matrix(config)
    combos = result["matrix"]["include"]
    assert len(combos) == 3
    assert {"os": "windows-latest", "python-version": "3.10"} not in combos


# --- Test 4: Include rules (extra combos) ---
def test_include_rules():
    """Include rules add extra combinations beyond the Cartesian product."""
    from matrix_generator import generate_matrix

    config = {
        "os": ["ubuntu-latest"],
        "python-version": ["3.11"],
        "include": [
            {"os": "macos-latest", "python-version": "3.12", "extra": True}
        ],
    }
    result = generate_matrix(config)
    combos = result["matrix"]["include"]
    assert len(combos) == 2
    assert {"os": "ubuntu-latest", "python-version": "3.11"} in combos
    assert {"os": "macos-latest", "python-version": "3.12", "extra": True} in combos


# --- Test 5: Max-parallel and fail-fast config ---
def test_strategy_options():
    """max-parallel and fail-fast appear in the output."""
    from matrix_generator import generate_matrix

    config = {
        "os": ["ubuntu-latest"],
        "python-version": ["3.11"],
        "max-parallel": 3,
        "fail-fast": False,
    }
    result = generate_matrix(config)
    assert result["max-parallel"] == 3
    assert result["fail-fast"] is False


# --- Test 6: Max size validation ---
def test_max_size_exceeded_raises():
    """Raise an error when the matrix exceeds max_size."""
    from matrix_generator import generate_matrix, MatrixSizeError

    config = {
        "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
        "python-version": ["3.8", "3.9", "3.10", "3.11"],
        "node-version": ["16", "18", "20"],
    }
    # 3 * 4 * 3 = 36 combos; limit to 10
    with pytest.raises(MatrixSizeError, match="36"):
        generate_matrix(config, max_size=10)


def test_max_size_default_256():
    """Default max_size is 256 (GitHub Actions limit)."""
    from matrix_generator import generate_matrix, MatrixSizeError

    # 3 * 3 * 3 * 3 * 3 = 243 — should be fine
    config = {
        "a": ["1", "2", "3"],
        "b": ["1", "2", "3"],
        "c": ["1", "2", "3"],
        "d": ["1", "2", "3"],
        "e": ["1", "2", "3"],
    }
    result = generate_matrix(config)
    assert len(result["matrix"]["include"]) == 243


def test_max_size_257_raises():
    """257 combos exceeds default 256 limit."""
    from matrix_generator import generate_matrix, MatrixSizeError

    # Need >256: 3^5 = 243, not enough. Use 4^4 = 256, then add one more value.
    config = {
        "a": ["1", "2", "3", "4"],
        "b": ["1", "2", "3", "4"],
        "c": ["1", "2", "3", "4"],
        "d": ["1", "2", "3", "4", "5"],  # 4*4*4*5 = 320
    }
    with pytest.raises(MatrixSizeError):
        generate_matrix(config)


# --- Test 7: JSON output ---
def test_json_output_format():
    """generate_matrix_json returns valid JSON string."""
    from matrix_generator import generate_matrix_json

    config = {
        "os": ["ubuntu-latest"],
        "python-version": ["3.11"],
        "fail-fast": True,
        "max-parallel": 2,
    }
    json_str = generate_matrix_json(config)
    parsed = json.loads(json_str)
    assert "matrix" in parsed
    assert parsed["fail-fast"] is True
    assert parsed["max-parallel"] == 2


# --- Test 8: CLI usage ---
def test_cli_with_json_input(tmp_path):
    """CLI reads a JSON config file and writes JSON to stdout."""
    config = {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.11"],
    }
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config))

    result = subprocess.run(
        [sys.executable, "matrix_generator.py", str(config_file)],
        cwd=Path(__file__).parent.parent,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    parsed = json.loads(result.stdout)
    assert len(parsed["matrix"]["include"]) == 2


def test_cli_exceeds_max_size_exits_nonzero(tmp_path):
    """CLI exits with non-zero code when matrix is too large."""
    config = {
        "a": ["1", "2", "3", "4"],
        "b": ["1", "2", "3", "4"],
        "c": ["1", "2", "3", "4"],
        "d": ["1", "2", "3", "4", "5"],
    }
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config))

    result = subprocess.run(
        [sys.executable, "matrix_generator.py", str(config_file)],
        cwd=Path(__file__).parent.parent,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "320" in result.stderr or "exceeds" in result.stderr.lower()


# --- Test 9: Partial exclude (matching subset of keys) ---
def test_exclude_partial_match():
    """An exclude entry with a subset of keys excludes all combos that match those keys."""
    from matrix_generator import generate_matrix

    config = {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"],
        "experimental": [True, False],
        # Exclude everything on windows with experimental=True
        "exclude": [{"os": "windows-latest", "experimental": True}],
    }
    result = generate_matrix(config)
    combos = result["matrix"]["include"]
    # All 8 combos minus 2 (windows + 3.10 + True, windows + 3.11 + True) = 6
    assert len(combos) == 6
    for combo in combos:
        assert not (combo["os"] == "windows-latest" and combo["experimental"] is True)


# --- Test 10: Empty config dimensions ---
def test_single_dimension():
    """A single-dimension config yields one entry per value."""
    from matrix_generator import generate_matrix

    config = {"os": ["ubuntu-latest", "windows-latest", "macos-latest"]}
    result = generate_matrix(config)
    assert len(result["matrix"]["include"]) == 3


# --- Test 11: Defaults when no strategy keys present ---
def test_defaults_when_no_strategy_keys():
    """When fail-fast and max-parallel are absent, they don't appear in output."""
    from matrix_generator import generate_matrix

    config = {"os": ["ubuntu-latest"]}
    result = generate_matrix(config)
    assert "fail-fast" not in result
    assert "max-parallel" not in result
