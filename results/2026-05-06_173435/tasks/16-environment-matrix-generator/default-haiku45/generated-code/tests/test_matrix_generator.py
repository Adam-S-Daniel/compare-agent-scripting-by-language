"""Test matrix generator with TDD approach."""
import json
import pytest
from matrix_generator import (
    MatrixGenerator,
    MatrixConfig,
    MatrixValidationError,
)


class TestMatrixGeneratorBasic:
    """First test: generate a simple matrix from basic config."""

    def test_simple_matrix_generation(self):
        """FAILING TEST: Generate matrix from simple OS + version config."""
        config = MatrixConfig(
            os=["ubuntu-latest", "windows-latest"],
            python_version=["3.10", "3.11"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Should create a matrix with 4 combinations (2 OS x 2 versions)
        assert len(matrix["include"]) == 4

        # Each entry should have os and python_version
        for entry in matrix["include"]:
            assert "os" in entry
            assert "python_version" in entry
            assert entry["os"] in ["ubuntu-latest", "windows-latest"]
            assert entry["python_version"] in ["3.10", "3.11"]


class TestMatrixGeneratorMaxParallel:
    """Test max-parallel limit enforcement."""

    def test_max_parallel_limit(self):
        """Limit parallel jobs to 2 when matrix is larger."""
        config = MatrixConfig(
            os=["ubuntu-latest", "windows-latest"],
            python_version=["3.10", "3.11", "3.12"],
            max_parallel=2,
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert "max-parallel" in matrix
        assert matrix["max-parallel"] == 2


class TestMatrixGeneratorIncludeExclude:
    """Test include/exclude rules."""

    def test_include_rule(self):
        """Add specific matrix combinations with include."""
        config = MatrixConfig(
            os=["ubuntu-latest"],
            python_version=["3.10"],
            include=[
                {"os": "macos-latest", "python_version": "3.11", "extra_flag": "test"}
            ],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 2
        assert any(
            e["os"] == "macos-latest" and e.get("extra_flag") == "test"
            for e in matrix["include"]
        )

    def test_exclude_rule(self):
        """Remove specific combinations with exclude."""
        config = MatrixConfig(
            os=["ubuntu-latest", "windows-latest"],
            python_version=["3.10", "3.11"],
            exclude=[{"os": "windows-latest", "python_version": "3.10"}],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 3
        assert not any(
            e["os"] == "windows-latest" and e["python_version"] == "3.10"
            for e in matrix["include"]
        )


class TestMatrixGeneratorFailFast:
    """Test fail-fast configuration."""

    def test_fail_fast_setting(self):
        """Set fail-fast: false to continue on failure."""
        config = MatrixConfig(
            os=["ubuntu-latest"],
            python_version=["3.10"],
            fail_fast=False,
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert matrix.get("fail-fast") is False

    def test_fail_fast_default_true(self):
        """Default fail-fast should be True."""
        config = MatrixConfig(
            os=["ubuntu-latest"],
            python_version=["3.10"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Should not include fail-fast key if True (GitHub Actions default)
        # or it can be explicitly True
        assert matrix.get("fail-fast", True) is True


class TestMatrixGeneratorMaxSize:
    """Test maximum matrix size validation."""

    def test_matrix_exceeds_max_size(self):
        """Raise error when matrix exceeds max size limit."""
        config = MatrixConfig(
            os=["ubuntu", "windows", "macos"],
            python_version=["3.8", "3.9", "3.10", "3.11"],
            node_version=["16", "18", "20"],
            max_size=20,  # Only allow 20 combinations
        )
        generator = MatrixGenerator(config)

        # 3 * 4 * 3 = 36 combinations > 20
        with pytest.raises(MatrixValidationError) as exc:
            generator.generate()
        assert "exceeds maximum" in str(exc.value)

    def test_matrix_within_max_size(self):
        """Allow matrix when it's within size limit."""
        config = MatrixConfig(
            os=["ubuntu-latest"],
            python_version=["3.10", "3.11"],
            max_size=10,
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        assert len(matrix["include"]) == 2


class TestMatrixGeneratorOutput:
    """Test JSON output format."""

    def test_output_is_valid_json(self):
        """Generated matrix should be serializable to JSON."""
        config = MatrixConfig(
            os=["ubuntu-latest"],
            python_version=["3.10"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Should not raise
        json_str = json.dumps(matrix)
        assert json_str  # Non-empty JSON

    def test_output_matches_github_actions_schema(self):
        """Output should match GitHub Actions matrix.strategy schema."""
        config = MatrixConfig(
            os=["ubuntu-latest", "windows-latest"],
            python_version=["3.10"],
        )
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # GitHub Actions expects 'include' and optionally 'exclude'
        assert isinstance(matrix, dict)
        assert "include" in matrix
        assert isinstance(matrix["include"], list)
