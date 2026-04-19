"""Test suite for environment matrix generator using red/green TDD."""
import json
import pytest
from matrix_generator import (
    MatrixGenerator,
    MatrixConfig,
    MatrixValidationError,
)


class TestBasicMatrixGeneration:
    """Test basic matrix generation from configuration."""

    def test_single_os_single_version(self):
        """Test matrix with single OS and language version."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 1
        assert matrix["include"][0]["os"] == "ubuntu-latest"
        assert matrix["include"][0]["language_version"] == "3.9"

    def test_multiple_os_versions(self):
        """Test matrix with multiple OS versions."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest", "windows-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 3
        os_values = [item["os"] for item in matrix["include"]]
        assert os_values == ["ubuntu-latest", "macos-latest", "windows-latest"]

    def test_multiple_language_versions(self):
        """Test matrix with multiple language versions."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9", "3.10", "3.11"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 3
        lang_values = [item["language_version"] for item in matrix["include"]]
        assert lang_values == ["3.9", "3.10", "3.11"]

    def test_cartesian_product(self):
        """Test matrix generates cartesian product of OS and language versions."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9", "3.10"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 4
        combinations = [
            (item["os"], item["language_version"])
            for item in matrix["include"]
        ]
        expected = [
            ("ubuntu-latest", "3.9"),
            ("ubuntu-latest", "3.10"),
            ("macos-latest", "3.9"),
            ("macos-latest", "3.10"),
        ]
        assert combinations == expected


class TestFeatureFlags:
    """Test matrix generation with feature flags."""

    def test_single_feature_flag(self):
        """Test matrix with single feature flag."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
            feature_flags=["debug"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 1
        assert matrix["include"][0]["feature_flag"] == "debug"

    def test_multiple_feature_flags(self):
        """Test matrix with multiple feature flags."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
            feature_flags=["debug", "verbose"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 2
        flags = [item.get("feature_flag") for item in matrix["include"]]
        assert set(flags) == {"debug", "verbose"}

    def test_feature_flags_with_multiple_os_language(self):
        """Test feature flags multiply with OS and language versions."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9"],
            feature_flags=["debug", "verbose"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Should be 2 OS * 1 language * 2 flags = 4 combinations
        assert len(matrix["include"]) == 4


class TestIncludeExcludeRules:
    """Test include and exclude rules."""

    def test_include_specific_combinations(self):
        """Test including only specific combinations."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9", "3.10"],
            include=[
                {"os": "ubuntu-latest", "language_version": "3.9"},
            ],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 1
        assert matrix["include"][0]["os"] == "ubuntu-latest"
        assert matrix["include"][0]["language_version"] == "3.9"

    def test_exclude_specific_combinations(self):
        """Test excluding specific combinations."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9", "3.10"],
            exclude=[
                {"os": "macos-latest", "language_version": "3.9"},
            ],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 3
        # The excluded combination should not be present
        combinations = [
            (item["os"], item["language_version"])
            for item in matrix["include"]
        ]
        assert ("macos-latest", "3.9") not in combinations

    def test_exclude_list_in_output(self):
        """Test that exclude list appears in output when specified."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9"],
            exclude=[
                {"os": "macos-latest"},
            ],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert "exclude" in matrix
        assert matrix["exclude"] == [{"os": "macos-latest"}]


class TestMatrixConfiguration:
    """Test matrix configuration options."""

    def test_max_parallel_configuration(self):
        """Test max-parallel configuration."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
            max_parallel=4,
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert matrix["max-parallel"] == 4

    def test_fail_fast_configuration(self):
        """Test fail-fast configuration."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
            fail_fast=False,
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert matrix["fail-fast"] is False

    def test_fail_fast_default_true(self):
        """Test fail-fast defaults to true."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert matrix["fail-fast"] is True


class TestMatrixValidation:
    """Test matrix validation."""

    def test_max_size_validation(self):
        """Test that matrix size is validated."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"] * 100,
            language_versions=["3.9"],
            max_size=50,
        )
        generator = MatrixGenerator(config)

        with pytest.raises(MatrixValidationError) as exc_info:
            generator.generate()

        assert "exceeds maximum size" in str(exc_info.value)

    def test_valid_matrix_size(self):
        """Test that valid matrix size passes."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9", "3.10"],
            max_size=10,
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) <= 10

    def test_default_max_size(self):
        """Test default max size is 256."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        # Should not raise with reasonable size
        matrix = generator.generate()
        assert matrix is not None


class TestJSONOutput:
    """Test JSON output format."""

    def test_matrix_is_json_serializable(self):
        """Test that matrix output is JSON serializable."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Should not raise
        json_str = json.dumps(matrix)
        assert json_str

    def test_matrix_structure_valid(self):
        """Test that matrix has required GitHub Actions structure."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "macos-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert "include" in matrix
        assert isinstance(matrix["include"], list)
        assert len(matrix["include"]) > 0
        assert "fail-fast" in matrix

    def test_matrix_to_json_string(self):
        """Test converting matrix to JSON string."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        json_output = generator.to_json()

        # Parse it back to verify it's valid JSON
        parsed = json.loads(json_output)
        assert "include" in parsed


class TestEdgeCases:
    """Test edge cases and error handling."""

    def test_empty_os_versions(self):
        """Test handling of empty OS versions."""
        config = MatrixConfig(
            os_versions=[],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)

        with pytest.raises(MatrixValidationError):
            generator.generate()

    def test_empty_language_versions(self):
        """Test handling of empty language versions."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=[],
        )
        generator = MatrixGenerator(config)

        with pytest.raises(MatrixValidationError):
            generator.generate()

    def test_duplicate_os_versions_removed(self):
        """Test that duplicate OS versions are deduplicated."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest", "ubuntu-latest"],
            language_versions=["3.9"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 1

    def test_feature_flag_addition_to_existing_combination(self):
        """Test that feature flags are added to existing combinations."""
        config = MatrixConfig(
            os_versions=["ubuntu-latest"],
            language_versions=["3.9"],
            feature_flags=["debug"],
            include=[
                {"os": "ubuntu-latest", "language_version": "3.9", "extra": "value"}
            ],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) >= 1
        # First item should have the extra field if include was used
        assert matrix["include"][0].get("extra") == "value"
