#!/usr/bin/env python3
"""
Tests for matrix_generator.py — written BEFORE the implementation (TDD red phase).

TDD cycle order:
  Round 1: Basic matrix generation (os list -> matrix.os)
  Round 2: Language version dimensions (python -> python-version)
  Round 3: Feature flag dimensions
  Round 4: Include / exclude rules
  Round 5: max-parallel and fail-fast strategy settings
  Round 6: Matrix size validation and error handling

Run: pytest test_matrix_generator.py -v
At the time of writing, ALL tests below FAIL because matrix_generator.py does not exist yet.
"""

import json
import pytest

# This import will fail until matrix_generator.py is created — that is intentional.
from matrix_generator import (
    generate_matrix,
    calculate_matrix_size,
    MatrixTooLargeError,
    load_config,
)


# ---------------------------------------------------------------------------
# Round 1 — calculate_matrix_size helper
# ---------------------------------------------------------------------------

class TestCalculateMatrixSize:
    """Unit tests for the Cartesian-product size helper."""

    def test_empty_dimensions_returns_zero(self):
        assert calculate_matrix_size({}) == 0

    def test_single_dimension(self):
        assert calculate_matrix_size({"os": ["ubuntu", "windows"]}) == 2

    def test_two_dimensions_multiplied(self):
        assert calculate_matrix_size({
            "os": ["ubuntu", "windows"],
            "python-version": ["3.9", "3.10", "3.11"],
        }) == 6

    def test_three_dimensions_multiplied(self):
        assert calculate_matrix_size({
            "os": ["ubuntu", "windows", "macos"],
            "python-version": ["3.10", "3.11"],
            "experimental": [True, False],
        }) == 12


# ---------------------------------------------------------------------------
# Round 2 — Basic OS matrix generation
# ---------------------------------------------------------------------------

class TestBasicMatrixGeneration:
    """generate_matrix returns a well-formed strategy structure."""

    def test_result_has_strategy_key(self):
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert "strategy" in result

    def test_result_has_matrix_key_inside_strategy(self):
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert "matrix" in result["strategy"]

    def test_os_list_preserved_in_matrix(self):
        config = {"os": ["ubuntu-latest", "windows-latest"]}
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["os"] == ["ubuntu-latest", "windows-latest"]

    def test_empty_os_list_omitted_from_matrix(self):
        result = generate_matrix({"os": []})
        assert "os" not in result["strategy"]["matrix"]

    def test_missing_os_key_omitted(self):
        result = generate_matrix({})
        assert "os" not in result["strategy"]["matrix"]


# ---------------------------------------------------------------------------
# Round 3 — Language version dimensions
# ---------------------------------------------------------------------------

class TestLanguageVersionDimensions:
    """Language version lists become <lang>-version matrix dimensions."""

    def test_python_becomes_python_version(self):
        config = {"language_versions": {"python": ["3.9", "3.10", "3.11"]}}
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["python-version"] == ["3.9", "3.10", "3.11"]

    def test_node_becomes_node_version(self):
        config = {"language_versions": {"node": ["16", "18", "20"]}}
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["node-version"] == ["16", "18", "20"]

    def test_multiple_languages_create_separate_dimensions(self):
        config = {
            "language_versions": {
                "python": ["3.9", "3.10"],
                "node": ["16", "18"],
            }
        }
        matrix = generate_matrix(config)["strategy"]["matrix"]
        assert "python-version" in matrix
        assert "node-version" in matrix

    def test_empty_version_list_omitted(self):
        config = {"language_versions": {"python": []}}
        result = generate_matrix(config)
        assert "python-version" not in result["strategy"]["matrix"]


# ---------------------------------------------------------------------------
# Round 4 — Feature flag dimensions
# ---------------------------------------------------------------------------

class TestFeatureFlagDimensions:
    """Feature flags become plain dimensions in the matrix."""

    def test_boolean_flag_in_matrix(self):
        config = {"feature_flags": {"experimental": [True, False]}}
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["experimental"] == [True, False]

    def test_string_flag_in_matrix(self):
        config = {"feature_flags": {"build_mode": ["release", "debug"]}}
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["build_mode"] == ["release", "debug"]

    def test_multiple_feature_flags(self):
        config = {
            "feature_flags": {
                "experimental": [True, False],
                "debug": [True, False],
            }
        }
        matrix = generate_matrix(config)["strategy"]["matrix"]
        assert "experimental" in matrix
        assert "debug" in matrix

    def test_empty_flag_list_omitted(self):
        config = {"feature_flags": {"experimental": []}}
        result = generate_matrix(config)
        assert "experimental" not in result["strategy"]["matrix"]


# ---------------------------------------------------------------------------
# Round 5 — Include / exclude rules
# ---------------------------------------------------------------------------

class TestIncludeExcludeRules:
    """Include and exclude rules are forwarded verbatim into the matrix."""

    def test_include_rules_forwarded(self):
        rule = {"os": "windows-latest", "python-version": "3.12"}
        config = {"os": ["ubuntu-latest"], "include": [rule]}
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["include"] == [rule]

    def test_exclude_rules_forwarded(self):
        rule = {"os": "windows-latest", "python-version": "3.9"}
        config = {
            "os": ["ubuntu-latest", "windows-latest"],
            "language_versions": {"python": ["3.9", "3.10"]},
            "exclude": [rule],
        }
        result = generate_matrix(config)
        assert result["strategy"]["matrix"]["exclude"] == [rule]

    def test_empty_include_list_omitted(self):
        result = generate_matrix({"os": ["ubuntu-latest"], "include": []})
        assert "include" not in result["strategy"]["matrix"]

    def test_missing_exclude_key_omitted(self):
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert "exclude" not in result["strategy"]["matrix"]

    def test_multiple_include_rules(self):
        rules = [
            {"os": "ubuntu-latest", "python-version": "3.12", "nightly": True},
            {"os": "macos-latest", "python-version": "3.12"},
        ]
        result = generate_matrix({"os": ["ubuntu-latest"], "include": rules})
        assert result["strategy"]["matrix"]["include"] == rules


# ---------------------------------------------------------------------------
# Round 6 — Strategy: max-parallel and fail-fast
# ---------------------------------------------------------------------------

class TestStrategySettings:
    """max-parallel and fail-fast map onto the strategy object."""

    def test_max_parallel_appears_in_strategy(self):
        result = generate_matrix({"os": ["ubuntu-latest"], "max_parallel": 4})
        assert result["strategy"]["max-parallel"] == 4

    def test_max_parallel_absent_when_not_provided(self):
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert "max-parallel" not in result["strategy"]

    def test_fail_fast_defaults_to_true(self):
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert result["strategy"]["fail-fast"] is True

    def test_fail_fast_can_be_set_to_false(self):
        result = generate_matrix({"os": ["ubuntu-latest"], "fail_fast": False})
        assert result["strategy"]["fail-fast"] is False

    def test_fail_fast_explicit_true(self):
        result = generate_matrix({"os": ["ubuntu-latest"], "fail_fast": True})
        assert result["strategy"]["fail-fast"] is True


# ---------------------------------------------------------------------------
# Round 7 — Matrix size validation
# ---------------------------------------------------------------------------

class TestMatrixSizeValidation:
    """Matrices that exceed max_size must raise MatrixTooLargeError."""

    def test_matrix_within_default_limit_succeeds(self):
        # 4 * 4 * 4 = 64, well under 256
        result = generate_matrix({
            "os": ["u", "w", "m", "u20"],
            "language_versions": {"python": ["3.9", "3.10", "3.11", "3.12"]},
            "feature_flags": {"exp": [True, False, "maybe", "soon"]},
        })
        assert result is not None

    def test_matrix_exactly_at_limit_succeeds(self):
        config = {
            "os": ["ubuntu-latest", "windows-latest"],
            "language_versions": {"python": ["3.9", "3.10"]},
            "max_size": 4,  # exactly 2 * 2 = 4
        }
        result = generate_matrix(config)
        assert result is not None

    def test_matrix_one_over_limit_raises(self):
        config = {
            "os": ["ubuntu-latest", "windows-latest"],
            "language_versions": {"python": ["3.9", "3.10"]},
            "max_size": 3,  # 4 > 3
        }
        with pytest.raises(MatrixTooLargeError):
            generate_matrix(config)

    def test_error_message_contains_actual_and_max_size(self):
        config = {
            "os": ["ubuntu-latest", "windows-latest", "macos-latest"],  # 3
            "language_versions": {"python": ["3.9", "3.10", "3.11"]},   # 3
            "max_size": 5,  # 9 > 5
        }
        with pytest.raises(MatrixTooLargeError) as exc_info:
            generate_matrix(config)
        msg = str(exc_info.value)
        assert "9" in msg   # actual size
        assert "5" in msg   # max size

    def test_default_max_size_is_256(self):
        # 256 exactly — should pass without specifying max_size
        config = {
            "os": ["u"] * 4,
            "language_versions": {"python": ["v"] * 4},
            "feature_flags": {"f": ["x"] * 16},
        }
        # 4 * 4 * 16 = 256  should succeed
        result = generate_matrix(config)
        assert result is not None

    def test_one_over_default_max_size_raises(self):
        config = {
            "os": ["u"] * 4,
            "language_versions": {"python": ["v"] * 4},
            "feature_flags": {"f": ["x"] * 17},
        }
        # 4 * 4 * 17 = 272 > 256
        with pytest.raises(MatrixTooLargeError):
            generate_matrix(config)


# ---------------------------------------------------------------------------
# Round 8 — load_config (CLI helper)
# ---------------------------------------------------------------------------

class TestLoadConfig:
    """load_config reads and parses JSON configuration files."""

    def test_load_valid_json(self, tmp_path):
        cfg = {"os": ["ubuntu-latest"], "fail_fast": False}
        p = tmp_path / "config.json"
        p.write_text(json.dumps(cfg))
        assert load_config(str(p)) == cfg

    def test_missing_file_raises_file_not_found(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            load_config(str(tmp_path / "does_not_exist.json"))

    def test_invalid_json_raises_value_error(self, tmp_path):
        p = tmp_path / "bad.json"
        p.write_text("{not valid json}")
        with pytest.raises(ValueError):
            load_config(str(p))


# ---------------------------------------------------------------------------
# Round 9 — Full integration / complex configuration
# ---------------------------------------------------------------------------

class TestComplexConfiguration:
    """Integration test: all features combined."""

    def test_full_config_generates_complete_strategy(self):
        config = {
            "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
            "language_versions": {"python": ["3.10", "3.11", "3.12"]},
            "feature_flags": {"experimental": [True, False]},
            "include": [
                {"os": "ubuntu-latest", "python-version": "3.12", "nightly": True}
            ],
            "exclude": [
                {"os": "windows-latest", "python-version": "3.10"}
            ],
            "max_parallel": 6,
            "fail_fast": False,
            "max_size": 256,
        }
        result = generate_matrix(config)
        strategy = result["strategy"]
        matrix = strategy["matrix"]

        assert matrix["os"] == ["ubuntu-latest", "windows-latest", "macos-latest"]
        assert matrix["python-version"] == ["3.10", "3.11", "3.12"]
        assert matrix["experimental"] == [True, False]
        assert len(matrix["include"]) == 1
        assert matrix["include"][0]["nightly"] is True
        assert len(matrix["exclude"]) == 1
        assert matrix["exclude"][0]["os"] == "windows-latest"
        assert strategy["max-parallel"] == 6
        assert strategy["fail-fast"] is False

    def test_os_only_config(self):
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert result["strategy"]["matrix"] == {"os": ["ubuntu-latest"]}
        assert result["strategy"]["fail-fast"] is True
