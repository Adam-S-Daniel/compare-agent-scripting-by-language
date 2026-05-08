"""Test config file loading."""
import json
import tempfile
from pathlib import Path

import pytest

from matrix_generator import MatrixConfig, MatrixGenerator


class TestConfigFileLoading:
    """Test loading config from JSON files."""

    def test_load_config_from_json_file(self):
        """Load config from a JSON file."""
        config_data = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python_version": ["3.10", "3.11"],
            "max_parallel": 2,
        }

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(config_data, f)
            config_file = f.name

        try:
            with open(config_file) as f:
                loaded_data = json.load(f)
            config = MatrixConfig(**loaded_data)
            generator = MatrixGenerator(config)
            matrix = generator.generate()

            assert len(matrix["include"]) == 4
            assert matrix["max-parallel"] == 2
        finally:
            Path(config_file).unlink()

    def test_load_config_with_include_exclude(self):
        """Load config with include and exclude rules from file."""
        config_data = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python_version": ["3.10", "3.11"],
            "exclude": [{"os": "windows-latest", "python_version": "3.10"}],
            "include": [{"os": "macos-latest", "python_version": "3.12"}],
        }

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(config_data, f)
            config_file = f.name

        try:
            with open(config_file) as f:
                loaded_data = json.load(f)
            config = MatrixConfig(**loaded_data)
            generator = MatrixGenerator(config)
            matrix = generator.generate()

            # 2*2=4, -1 exclude, +1 include = 4
            assert len(matrix["include"]) == 4
        finally:
            Path(config_file).unlink()

    def test_empty_config(self):
        """Handle empty configuration gracefully."""
        config = MatrixConfig()
        generator = MatrixGenerator(config)
        matrix = generator.generate()

        # Should produce empty matrix with only base structure
        assert matrix["include"] == []

    def test_config_with_all_dimensions(self):
        """Config with all optional dimensions."""
        config_data = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python_version": ["3.10"],
            "node_version": ["16", "18"],
            "max_parallel": 4,
            "fail_fast": False,
            "max_size": 100,
        }

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(config_data, f)
            config_file = f.name

        try:
            with open(config_file) as f:
                loaded_data = json.load(f)
            config = MatrixConfig(**loaded_data)
            generator = MatrixGenerator(config)
            matrix = generator.generate()

            # 2*1*2 = 4 combinations
            assert len(matrix["include"]) == 4
            assert matrix["max-parallel"] == 4
            assert matrix["fail-fast"] is False
        finally:
            Path(config_file).unlink()
