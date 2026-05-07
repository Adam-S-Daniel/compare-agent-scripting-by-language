"""Test CLI interface."""
import json
import subprocess
import tempfile
from pathlib import Path

import pytest


class TestCLI:
    """Test generate_matrix.py CLI."""

    def test_cli_basic_matrix(self):
        """Run CLI to generate basic matrix."""
        config = {
            "os": ["ubuntu-latest"],
            "python_version": ["3.10"],
        }

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(config, f)
            config_file = f.name

        try:
            result = subprocess.run(
                ["python3", "generate_matrix.py", "--config", config_file],
                capture_output=True,
                text=True,
                cwd=Path(__file__).parent.parent,
            )

            assert result.returncode == 0, f"CLI failed: {result.stderr}"
            matrix = json.loads(result.stdout)
            assert "include" in matrix
            assert len(matrix["include"]) == 1
            assert matrix["include"][0]["os"] == "ubuntu-latest"
        finally:
            Path(config_file).unlink()

    def test_cli_output_to_file(self):
        """Write matrix output to file."""
        config = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python_version": ["3.10"],
        }

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(config, f)
            config_file = f.name

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            output_file = f.name

        try:
            result = subprocess.run(
                [
                    "python3",
                    "generate_matrix.py",
                    "--config",
                    config_file,
                    "--output",
                    output_file,
                ],
                capture_output=True,
                text=True,
                cwd=Path(__file__).parent.parent,
            )

            assert result.returncode == 0
            assert Path(output_file).exists()

            with open(output_file) as f:
                matrix = json.load(f)
            assert len(matrix["include"]) == 2
        finally:
            Path(config_file).unlink()
            Path(output_file).unlink()

    def test_cli_missing_config(self):
        """Handle missing config file gracefully."""
        result = subprocess.run(
            ["python3", "generate_matrix.py", "--config", "/nonexistent/config.json"],
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent,
        )

        assert result.returncode == 1
        assert "not found" in result.stderr

    def test_cli_invalid_json(self):
        """Handle invalid JSON in config file."""
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False
        ) as f:
            f.write("{invalid json")
            config_file = f.name

        try:
            result = subprocess.run(
                ["python3", "generate_matrix.py", "--config", config_file],
                capture_output=True,
                text=True,
                cwd=Path(__file__).parent.parent,
            )

            assert result.returncode == 1
            assert "Invalid JSON" in result.stderr
        finally:
            Path(config_file).unlink()

    def test_cli_with_rules(self):
        """CLI with include/exclude rules."""
        config = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python_version": ["3.10", "3.11"],
            "exclude": [{"os": "windows-latest", "python_version": "3.10"}],
            "include": [{"os": "macos-latest", "python_version": "3.12"}],
            "max_parallel": 3,
            "fail_fast": False,
        }

        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump(config, f)
            config_file = f.name

        try:
            result = subprocess.run(
                ["python3", "generate_matrix.py", "--config", config_file],
                capture_output=True,
                text=True,
                cwd=Path(__file__).parent.parent,
            )

            assert result.returncode == 0
            matrix = json.loads(result.stdout)
            assert len(matrix["include"]) == 4
            assert matrix["max-parallel"] == 3
            assert matrix["fail-fast"] is False
        finally:
            Path(config_file).unlink()
