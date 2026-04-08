"""Tests for environment matrix generator — TDD red/green/refactor."""

import json
import pytest
from matrix_generator import (
    generate_matrix, MatrixConfig, MatrixError, matrix_to_json,
    load_config_from_dict, expand_combinations,
)


# ── RED: Test 1 — basic cartesian product ──

class TestBasicMatrix:
    def test_single_dimension(self):
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest", "windows-latest"]})
        result = generate_matrix(config)
        assert result["matrix"] == {
            "os": ["ubuntu-latest", "windows-latest"]
        }

    def test_multiple_dimensions_produce_cartesian_product(self):
        config = MatrixConfig(dimensions={
            "os": ["ubuntu-latest", "macos-latest"],
            "python-version": ["3.10", "3.11"],
        })
        result = generate_matrix(config)
        assert result["matrix"]["os"] == ["ubuntu-latest", "macos-latest"]
        assert result["matrix"]["python-version"] == ["3.10", "3.11"]

    def test_three_dimensions(self):
        config = MatrixConfig(dimensions={
            "os": ["ubuntu-latest"],
            "node": ["18", "20"],
            "experimental": [True, False],
        })
        result = generate_matrix(config)
        assert result["matrix"]["os"] == ["ubuntu-latest"]
        assert result["matrix"]["node"] == ["18", "20"]
        assert result["matrix"]["experimental"] == [True, False]


# ── RED: Test 2 — include rules ──

class TestIncludeRules:
    def test_include_adds_extra_combinations(self):
        """Include entries add specific combos beyond the cartesian product."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"], "node": ["18"]},
            include=[{"os": "windows-latest", "node": "20", "experimental": True}],
        )
        result = generate_matrix(config)
        assert result["matrix"]["include"] == [
            {"os": "windows-latest", "node": "20", "experimental": True}
        ]

    def test_include_only_no_dimensions(self):
        """A matrix can be built entirely from include entries."""
        config = MatrixConfig(
            dimensions={},
            include=[
                {"os": "ubuntu-latest", "python": "3.11"},
                {"os": "macos-latest", "python": "3.12"},
            ],
        )
        result = generate_matrix(config)
        assert "include" in result["matrix"]
        assert len(result["matrix"]["include"]) == 2

    def test_include_with_extra_fields(self):
        """Include entries can introduce new keys not in dimensions."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            include=[{"os": "ubuntu-latest", "coverage": True}],
        )
        result = generate_matrix(config)
        assert result["matrix"]["include"] == [{"os": "ubuntu-latest", "coverage": True}]


# ── RED: Test 3 — exclude rules ──

class TestExcludeRules:
    def test_exclude_removes_combinations(self):
        """Exclude entries filter out specific combos from the product."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest"],
                "node": ["18", "20"],
            },
            exclude=[{"os": "windows-latest", "node": "18"}],
        )
        result = generate_matrix(config)
        assert result["matrix"]["exclude"] == [
            {"os": "windows-latest", "node": "18"}
        ]

    def test_exclude_partial_match(self):
        """Exclude with a subset of keys removes all matching combos."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest"],
                "node": ["16", "18", "20"],
            },
            exclude=[{"os": "windows-latest"}],
        )
        result = generate_matrix(config)
        assert result["matrix"]["exclude"] == [{"os": "windows-latest"}]


# ── RED: Test 4 — fail-fast and max-parallel ──

class TestStrategyOptions:
    def test_fail_fast_true(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            fail_fast=True,
        )
        result = generate_matrix(config)
        assert result["fail-fast"] is True

    def test_fail_fast_false(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            fail_fast=False,
        )
        result = generate_matrix(config)
        assert result["fail-fast"] is False

    def test_fail_fast_omitted_when_none(self):
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"]})
        result = generate_matrix(config)
        assert "fail-fast" not in result

    def test_max_parallel(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            max_parallel=4,
        )
        result = generate_matrix(config)
        assert result["max-parallel"] == 4

    def test_max_parallel_omitted_when_none(self):
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"]})
        result = generate_matrix(config)
        assert "max-parallel" not in result

    def test_all_strategy_options(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "macos-latest"]},
            fail_fast=False,
            max_parallel=2,
        )
        result = generate_matrix(config)
        assert result["fail-fast"] is False
        assert result["max-parallel"] == 2
        assert "os" in result["matrix"]


# ── RED: Test 5 — matrix size validation ──

class TestMatrixSizeValidation:
    def test_matrix_within_limit(self):
        """Matrix with fewer combos than max should succeed."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"]},
            max_combinations=10,
        )
        # Should not raise
        generate_matrix(config)

    def test_matrix_exceeds_limit(self):
        """Matrix exceeding max_combinations raises MatrixError."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
                "python": ["3.9", "3.10", "3.11", "3.12"],
                "arch": ["x64", "arm64"],
            },
            max_combinations=5,  # 3*4*2 = 24 > 5
        )
        with pytest.raises(MatrixError, match="24 combinations exceeds maximum of 5"):
            generate_matrix(config)

    def test_default_limit_is_256(self):
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"]})
        assert config.max_combinations == 256

    def test_exact_limit_is_allowed(self):
        """Matrix with exactly max_combinations combos is fine."""
        config = MatrixConfig(
            dimensions={"a": ["1", "2"], "b": ["x", "y"]},
            max_combinations=4,  # 2*2 = 4, exactly at limit
        )
        generate_matrix(config)  # Should not raise

    def test_include_counted_in_size(self):
        """Include entries add to the effective matrix size."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"]},  # 2 combos
            include=[{"os": "macos-latest", "special": True}],       # +1 = 3
            max_combinations=2,
        )
        with pytest.raises(MatrixError, match="3 combinations exceeds maximum of 2"):
            generate_matrix(config)

    def test_exclude_reduces_size(self):
        """Exclude entries reduce the effective matrix size."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest"],
                "node": ["18", "20"],
            },  # 4 combos
            exclude=[{"os": "windows-latest", "node": "18"}],  # -1 = 3
            max_combinations=3,
        )
        generate_matrix(config)  # Should not raise


# ── RED: Test 6 — error handling ──

class TestErrorHandling:
    def test_empty_config_raises(self):
        """No dimensions and no includes is an error."""
        config = MatrixConfig()
        with pytest.raises(MatrixError, match="(?i)at least one dimension"):
            generate_matrix(config)

    def test_empty_dimension_values_raises(self):
        """A dimension with an empty list is an error."""
        config = MatrixConfig(dimensions={"os": []})
        with pytest.raises(MatrixError, match="Dimension 'os' must have at least one value"):
            generate_matrix(config)

    def test_negative_max_parallel_raises(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            max_parallel=-1,
        )
        with pytest.raises(MatrixError, match="max_parallel must be a positive integer"):
            generate_matrix(config)

    def test_zero_max_parallel_raises(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            max_parallel=0,
        )
        with pytest.raises(MatrixError, match="max_parallel must be a positive integer"):
            generate_matrix(config)

    def test_duplicate_dimension_values_raises(self):
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest", "ubuntu-latest"]})
        with pytest.raises(MatrixError, match="Dimension 'os' has duplicate values"):
            generate_matrix(config)


# ── RED: Test 7 — JSON output ──

class TestJsonOutput:
    def test_matrix_to_json_returns_valid_json(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"], "node": ["18"]},
            fail_fast=True,
            max_parallel=2,
        )
        output = matrix_to_json(config)
        parsed = json.loads(output)
        assert parsed["matrix"]["os"] == ["ubuntu-latest"]
        assert parsed["fail-fast"] is True
        assert parsed["max-parallel"] == 2

    def test_json_output_includes_all_sections(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            include=[{"os": "macos-latest"}],
            exclude=[{"os": "ubuntu-latest"}],
            fail_fast=False,
        )
        output = matrix_to_json(config)
        parsed = json.loads(output)
        assert "include" in parsed["matrix"]
        assert "exclude" in parsed["matrix"]
        assert parsed["fail-fast"] is False


# ── RED: Test 8 — load_config_from_dict ──

class TestLoadConfig:
    def test_load_from_simple_dict(self):
        raw = {
            "dimensions": {"os": ["ubuntu-latest"], "python": ["3.11", "3.12"]},
            "fail_fast": False,
            "max_parallel": 3,
        }
        config = load_config_from_dict(raw)
        assert config.dimensions == {"os": ["ubuntu-latest"], "python": ["3.11", "3.12"]}
        assert config.fail_fast is False
        assert config.max_parallel == 3

    def test_load_with_include_exclude(self):
        raw = {
            "dimensions": {"os": ["ubuntu-latest"]},
            "include": [{"os": "windows-latest", "experimental": True}],
            "exclude": [{"os": "ubuntu-latest"}],
        }
        config = load_config_from_dict(raw)
        assert len(config.include) == 1
        assert len(config.exclude) == 1

    def test_load_with_custom_max_combinations(self):
        raw = {
            "dimensions": {"os": ["ubuntu-latest"]},
            "max_combinations": 100,
        }
        config = load_config_from_dict(raw)
        assert config.max_combinations == 100

    def test_load_minimal(self):
        raw = {"dimensions": {"os": ["ubuntu-latest"]}}
        config = load_config_from_dict(raw)
        assert config.fail_fast is None
        assert config.max_parallel is None
        assert config.include == []
        assert config.exclude == []


# ── RED: Test 9 — expand_combinations to enumerate all jobs ──

class TestExpandCombinations:
    def test_expand_simple(self):
        """Expand should enumerate all concrete job entries."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"]},
        )
        combos = expand_combinations(config)
        assert len(combos) == 4
        assert {"os": "ubuntu-latest", "node": "18"} in combos
        assert {"os": "windows-latest", "node": "20"} in combos

    def test_expand_with_include(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            include=[{"os": "macos-latest", "experimental": True}],
        )
        combos = expand_combinations(config)
        assert len(combos) == 2
        assert {"os": "macos-latest", "experimental": True} in combos

    def test_expand_with_exclude(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"]},
            exclude=[{"os": "windows-latest", "node": "18"}],
        )
        combos = expand_combinations(config)
        assert len(combos) == 3
        assert {"os": "windows-latest", "node": "18"} not in combos

    def test_expand_include_only(self):
        config = MatrixConfig(
            dimensions={},
            include=[
                {"os": "ubuntu-latest", "special": True},
                {"os": "macos-latest", "special": False},
            ],
        )
        combos = expand_combinations(config)
        assert len(combos) == 2


# ── RED: Test 10 — end-to-end integration with JSON file ──

class TestEndToEnd:
    def test_full_workflow_from_json_file(self, tmp_path):
        """Load config from JSON file, generate matrix, verify output."""
        config_data = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
                "python-version": ["3.10", "3.11", "3.12"],
                "include-coverage": [True, False],
            },
            "include": [
                {"os": "ubuntu-latest", "python-version": "3.13", "include-coverage": True, "experimental": True}
            ],
            "exclude": [
                {"os": "macos-latest", "include-coverage": False}
            ],
            "fail_fast": False,
            "max_parallel": 6,
            "max_combinations": 50,
        }
        config_file = tmp_path / "matrix-config.json"
        config_file.write_text(json.dumps(config_data))

        # Load and generate
        loaded = json.loads(config_file.read_text())
        config = load_config_from_dict(loaded)
        result = generate_matrix(config)
        output_json = json.dumps(result, indent=2)

        # Verify structure
        parsed = json.loads(output_json)
        assert parsed["fail-fast"] is False
        assert parsed["max-parallel"] == 6
        assert len(parsed["matrix"]["os"]) == 3
        assert len(parsed["matrix"]["python-version"]) == 3
        assert len(parsed["matrix"]["include"]) == 1
        assert len(parsed["matrix"]["exclude"]) == 1

        # Verify expanded combinations:
        # 3 os * 3 python * 2 coverage = 18
        # minus 3 excluded (macos * 3 python * False coverage = 3)
        # plus 1 include = 16
        combos = expand_combinations(config)
        assert len(combos) == 16

    def test_realistic_node_matrix(self):
        """Realistic Node.js CI matrix with cross-platform testing."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
                "node": ["18", "20", "22"],
            },
            include=[
                {"os": "ubuntu-latest", "node": "23", "experimental": True},
            ],
            exclude=[
                {"os": "macos-latest", "node": "18"},  # Drop old node on macOS
            ],
            fail_fast=True,
            max_parallel=4,
        )
        result = generate_matrix(config)
        combos = expand_combinations(config)

        # 3*3=9 - 1 excluded + 1 include = 9
        assert len(combos) == 9
        assert result["fail-fast"] is True
        assert result["max-parallel"] == 4

        # Verify the excluded combo is truly gone
        assert {"os": "macos-latest", "node": "18"} not in combos
        # Verify the experimental include is present
        assert {"os": "ubuntu-latest", "node": "23", "experimental": True} in combos
