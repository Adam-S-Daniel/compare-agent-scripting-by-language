"""
TDD tests for GitHub Actions build matrix generator.

Red/Green TDD approach:
1. Write a failing test
2. Write minimum code to pass
3. Refactor
4. Repeat
"""
import pytest
import json
from matrix_generator import (
    generate_matrix,
    validate_matrix_size,
    MatrixTooLargeError,
    InvalidConfigError,
)


# --- Fixtures ---

BASIC_CONFIG = {
    "os": ["ubuntu-latest", "windows-latest"],
    "python-version": ["3.10", "3.11"],
    "feature-flags": ["flag-a", "flag-b"],
}

CONFIG_WITH_INCLUDE = {
    "os": ["ubuntu-latest", "macos-latest"],
    "python-version": ["3.10", "3.11"],
    "include": [
        {"os": "windows-latest", "python-version": "3.12", "feature-flags": "flag-c"}
    ],
}

CONFIG_WITH_EXCLUDE = {
    "os": ["ubuntu-latest", "windows-latest"],
    "python-version": ["3.10", "3.11"],
    "exclude": [
        {"os": "windows-latest", "python-version": "3.10"}
    ],
}

CONFIG_WITH_LIMITS = {
    "os": ["ubuntu-latest"],
    "python-version": ["3.10", "3.11"],
    "max-parallel": 2,
    "fail-fast": False,
}


# --- Test: basic matrix generation ---

class TestBasicMatrixGeneration:
    def test_generates_cross_product_of_axes(self):
        """Matrix should contain all combinations of provided axes."""
        config = {"os": ["ubuntu-latest", "windows-latest"], "python-version": ["3.10", "3.11"]}
        result = generate_matrix(config)
        combinations = result["matrix"]
        assert len(combinations) == 4
        assert {"os": "ubuntu-latest", "python-version": "3.10"} in combinations
        assert {"os": "ubuntu-latest", "python-version": "3.11"} in combinations
        assert {"os": "windows-latest", "python-version": "3.10"} in combinations
        assert {"os": "windows-latest", "python-version": "3.11"} in combinations

    def test_generates_cross_product_three_axes(self):
        """Three-axis config expands to full cross product."""
        result = generate_matrix(BASIC_CONFIG)
        combinations = result["matrix"]
        assert len(combinations) == 8  # 2 * 2 * 2

    def test_single_axis(self):
        """Single axis produces one combination per value."""
        config = {"os": ["ubuntu-latest", "windows-latest", "macos-latest"]}
        result = generate_matrix(config)
        assert len(result["matrix"]) == 3

    def test_output_contains_matrix_key(self):
        """Result dict must have a 'matrix' key."""
        result = generate_matrix({"os": ["ubuntu-latest"]})
        assert "matrix" in result


# --- Test: include rules ---

class TestIncludeRules:
    def test_include_adds_extra_combinations(self):
        """Include entries are appended to the matrix."""
        result = generate_matrix(CONFIG_WITH_INCLUDE)
        combos = result["matrix"]
        # 2 os * 2 python + 1 include = 5
        assert len(combos) == 5

    def test_include_entry_appears_in_matrix(self):
        """The exact include entry is present in the output."""
        result = generate_matrix(CONFIG_WITH_INCLUDE)
        assert {
            "os": "windows-latest",
            "python-version": "3.12",
            "feature-flags": "flag-c",
        } in result["matrix"]

    def test_include_can_extend_existing_combination(self):
        """Include entry that matches an existing combo adds extra keys to it."""
        config = {
            "os": ["ubuntu-latest"],
            "python-version": ["3.10"],
            "include": [{"os": "ubuntu-latest", "python-version": "3.10", "extra": "value"}],
        }
        result = generate_matrix(config)
        # Should merge rather than add a duplicate
        assert len(result["matrix"]) == 1
        assert result["matrix"][0]["extra"] == "value"


# --- Test: exclude rules ---

class TestExcludeRules:
    def test_exclude_removes_matching_combinations(self):
        """Exclude entries are removed from the generated matrix."""
        result = generate_matrix(CONFIG_WITH_EXCLUDE)
        combos = result["matrix"]
        # 2*2=4 minus 1 excluded = 3
        assert len(combos) == 3
        assert {"os": "windows-latest", "python-version": "3.10"} not in combos

    def test_exclude_with_partial_match(self):
        """Exclude entry with fewer keys removes all combos matching those keys."""
        config = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python-version": ["3.10", "3.11"],
            "exclude": [{"os": "windows-latest"}],
        }
        result = generate_matrix(config)
        assert len(result["matrix"]) == 2
        for combo in result["matrix"]:
            assert combo["os"] != "windows-latest"


# --- Test: max-parallel and fail-fast ---

class TestMatrixOptions:
    def test_max_parallel_included_in_output(self):
        """max-parallel appears at the top level of the output."""
        result = generate_matrix(CONFIG_WITH_LIMITS)
        assert result["max-parallel"] == 2

    def test_fail_fast_included_in_output(self):
        """fail-fast appears at the top level of the output."""
        result = generate_matrix(CONFIG_WITH_LIMITS)
        assert result["fail-fast"] is False

    def test_defaults_when_omitted(self):
        """When max-parallel and fail-fast are omitted, they are not in the output."""
        config = {"os": ["ubuntu-latest"]}
        result = generate_matrix(config)
        assert "max-parallel" not in result
        assert "fail-fast" not in result


# --- Test: matrix size validation ---

class TestMatrixSizeValidation:
    def test_validate_accepts_matrix_within_limit(self):
        """No error when matrix size is within limit."""
        matrix = [{"os": str(i)} for i in range(10)]
        validate_matrix_size(matrix, max_size=256)  # should not raise

    def test_validate_raises_when_exceeding_limit(self):
        """MatrixTooLargeError raised when matrix exceeds max size."""
        matrix = [{"os": str(i)} for i in range(300)]
        with pytest.raises(MatrixTooLargeError) as exc_info:
            validate_matrix_size(matrix, max_size=256)
        assert "300" in str(exc_info.value)
        assert "256" in str(exc_info.value)

    def test_generate_matrix_enforces_default_max_size(self):
        """generate_matrix raises when matrix exceeds default limit of 256."""
        # 6^4 = 1296 combinations
        config = {
            "os": [str(i) for i in range(6)],
            "a": [str(i) for i in range(6)],
            "b": [str(i) for i in range(6)],
            "c": [str(i) for i in range(6)],
        }
        with pytest.raises(MatrixTooLargeError):
            generate_matrix(config)

    def test_generate_matrix_respects_custom_max_size(self):
        """generate_matrix accepts a custom max_size parameter."""
        config = {"os": [str(i) for i in range(5)]}
        result = generate_matrix(config, max_size=10)
        assert len(result["matrix"]) == 5

    def test_generate_matrix_raises_with_custom_max_size(self):
        """generate_matrix raises MatrixTooLargeError when exceeding custom max_size."""
        config = {"os": [str(i) for i in range(5)]}
        with pytest.raises(MatrixTooLargeError):
            generate_matrix(config, max_size=3)


# --- Test: error handling ---

class TestErrorHandling:
    def test_empty_config_raises(self):
        """Empty config (no axes) raises InvalidConfigError."""
        with pytest.raises(InvalidConfigError):
            generate_matrix({})

    def test_config_with_only_reserved_keys_raises(self):
        """Config with only reserved keys (include/exclude/max-parallel/fail-fast) raises."""
        with pytest.raises(InvalidConfigError):
            generate_matrix({"include": [], "max-parallel": 2})

    def test_axis_with_empty_list_raises(self):
        """An axis with an empty list raises InvalidConfigError."""
        with pytest.raises(InvalidConfigError):
            generate_matrix({"os": []})

    def test_error_message_names_empty_axis(self):
        """Error message includes the name of the empty axis."""
        with pytest.raises(InvalidConfigError) as exc_info:
            generate_matrix({"os": [], "python-version": ["3.10"]})
        assert "os" in str(exc_info.value)


# --- Test: JSON output ---

class TestJsonOutput:
    def test_output_is_json_serializable(self):
        """The result of generate_matrix must be JSON-serializable."""
        result = generate_matrix(BASIC_CONFIG)
        dumped = json.dumps(result)
        loaded = json.loads(dumped)
        assert loaded == result

    def test_github_actions_strategy_shape(self):
        """Output matches the shape expected by GitHub Actions strategy.matrix."""
        config = {
            "os": ["ubuntu-latest"],
            "python-version": ["3.10"],
            "max-parallel": 1,
            "fail-fast": True,
        }
        result = generate_matrix(config)
        # GitHub Actions strategy block keys
        assert "matrix" in result
        assert isinstance(result["matrix"], list)
        assert result["max-parallel"] == 1
        assert result["fail-fast"] is True
