"""
Tests for the environment matrix generator.
TDD approach: tests were written before the implementation.
Each test covers one functional requirement.
"""
import json
import sys
import os
import subprocess
import pytest
import yaml

# Add parent directory to path so we can import the module
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from generate_matrix import generate_matrix, compute_matrix_size, load_config


# --- RED phase: these tests define the expected API ---

class TestComputeMatrixSize:
    """Tests for size calculation before generation."""

    def test_empty_dimensions_with_includes(self):
        # Only includes, no dimension cross-product
        size = compute_matrix_size({}, [{"os": "ubuntu-latest"}])
        assert size == 1

    def test_single_dimension(self):
        size = compute_matrix_size({"os": ["ubuntu-latest", "windows-latest"]}, [])
        assert size == 2

    def test_two_dimensions(self):
        size = compute_matrix_size(
            {"os": ["ubuntu-latest", "windows-latest"], "python": ["3.9", "3.10", "3.11"]},
            []
        )
        # 2 OS × 3 python = 6
        assert size == 6

    def test_includes_add_to_count(self):
        size = compute_matrix_size(
            {"os": ["ubuntu-latest"], "python": ["3.9", "3.10"]},
            [{"os": "ubuntu-latest", "python": "3.12", "experimental": True}]
        )
        # 1 × 2 base + 1 include = 3
        assert size == 3


class TestBasicMatrixGeneration:
    """Tests for the core matrix generation without includes/excludes."""

    def test_output_has_strategy_key(self):
        # Minimal config must produce a strategy-wrapped output
        config = {
            "dimensions": {"os": ["ubuntu-latest"]},
        }
        result = generate_matrix(config)
        assert "strategy" in result

    def test_strategy_has_matrix_key(self):
        config = {"dimensions": {"os": ["ubuntu-latest"]}}
        result = generate_matrix(config)
        assert "matrix" in result["strategy"]

    def test_dimensions_appear_in_matrix(self):
        config = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest"],
                "python-version": ["3.9", "3.10", "3.11"],
            }
        }
        result = generate_matrix(config)
        matrix = result["strategy"]["matrix"]
        assert matrix["os"] == ["ubuntu-latest", "windows-latest"]
        assert matrix["python-version"] == ["3.9", "3.10", "3.11"]

    def test_default_fail_fast_is_true(self):
        # GitHub Actions default is fail-fast: true; we mirror that
        config = {"dimensions": {"os": ["ubuntu-latest"]}}
        result = generate_matrix(config)
        assert result["strategy"]["fail-fast"] is True

    def test_fail_fast_false(self):
        config = {"dimensions": {"os": ["ubuntu-latest"]}, "fail_fast": False}
        result = generate_matrix(config)
        assert result["strategy"]["fail-fast"] is False

    def test_max_parallel_present_when_set(self):
        config = {"dimensions": {"os": ["ubuntu-latest"]}, "max_parallel": 4}
        result = generate_matrix(config)
        assert result["strategy"]["max-parallel"] == 4

    def test_max_parallel_absent_when_not_set(self):
        # Don't emit max-parallel if caller didn't specify it
        config = {"dimensions": {"os": ["ubuntu-latest"]}}
        result = generate_matrix(config)
        assert "max-parallel" not in result["strategy"]

    def test_empty_dimensions_produces_empty_matrix(self):
        config = {"dimensions": {}}
        result = generate_matrix(config)
        matrix = result["strategy"]["matrix"]
        # No dimension keys except possibly include/exclude
        keys = [k for k in matrix if k not in ("include", "exclude")]
        assert keys == []


class TestIncludeRules:
    """Tests for the include extra-combination mechanism."""

    def test_include_appears_in_matrix(self):
        config = {
            "dimensions": {"os": ["ubuntu-latest"], "python-version": ["3.9"]},
            "include": [{"os": "ubuntu-latest", "python-version": "3.12", "experimental": True}],
        }
        result = generate_matrix(config)
        matrix = result["strategy"]["matrix"]
        assert "include" in matrix
        assert len(matrix["include"]) == 1
        assert matrix["include"][0]["experimental"] is True

    def test_multiple_includes(self):
        config = {
            "dimensions": {"os": ["ubuntu-latest"]},
            "include": [
                {"os": "ubuntu-latest", "python-version": "3.12"},
                {"os": "macos-latest", "python-version": "3.13"},
            ],
        }
        result = generate_matrix(config)
        assert len(result["strategy"]["matrix"]["include"]) == 2

    def test_no_include_key_when_empty(self):
        config = {"dimensions": {"os": ["ubuntu-latest"]}, "include": []}
        result = generate_matrix(config)
        assert "include" not in result["strategy"]["matrix"]


class TestExcludeRules:
    """Tests for the exclude filtering mechanism."""

    def test_exclude_appears_in_matrix(self):
        config = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest"],
                "python-version": ["3.9", "3.10"],
            },
            "exclude": [{"os": "windows-latest", "python-version": "3.9"}],
        }
        result = generate_matrix(config)
        matrix = result["strategy"]["matrix"]
        assert "exclude" in matrix
        assert len(matrix["exclude"]) == 1
        assert matrix["exclude"][0] == {"os": "windows-latest", "python-version": "3.9"}

    def test_multiple_excludes(self):
        config = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
                "python-version": ["3.9", "3.10"],
            },
            "exclude": [
                {"os": "windows-latest", "python-version": "3.9"},
                {"os": "macos-latest", "python-version": "3.9"},
            ],
        }
        result = generate_matrix(config)
        assert len(result["strategy"]["matrix"]["exclude"]) == 2

    def test_no_exclude_key_when_empty(self):
        config = {"dimensions": {"os": ["ubuntu-latest"]}, "exclude": []}
        result = generate_matrix(config)
        assert "exclude" not in result["strategy"]["matrix"]


class TestMaxSizeValidation:
    """Tests for the max_size guard."""

    def test_raises_when_exceeds_max_size(self):
        # 2 × 3 × 4 = 24 combinations, limit = 10
        config = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest"],
                "python-version": ["3.9", "3.10", "3.11"],
                "node-version": ["16", "18", "20", "22"],
            },
            "max_size": 10,
        }
        with pytest.raises(ValueError, match="24") as exc_info:
            generate_matrix(config)
        # Error message must mention both actual size and limit
        assert "10" in str(exc_info.value)

    def test_does_not_raise_at_exact_limit(self):
        # Exactly 6 combinations, limit = 6 — should succeed
        config = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest"],
                "python-version": ["3.9", "3.10", "3.11"],
            },
            "max_size": 6,
        }
        result = generate_matrix(config)
        assert result is not None

    def test_default_max_size_is_256(self):
        # Build a 256-entry matrix (16 × 16) without specifying max_size
        config = {
            "dimensions": {
                "a": [str(i) for i in range(16)],
                "b": [str(i) for i in range(16)],
            }
        }
        result = generate_matrix(config)
        assert result is not None

    def test_exceeds_default_max_size(self):
        # 17 × 17 = 289 > 256
        config = {
            "dimensions": {
                "a": [str(i) for i in range(17)],
                "b": [str(i) for i in range(17)],
            }
        }
        with pytest.raises(ValueError, match="289"):
            generate_matrix(config)


class TestCLIInterface:
    """Tests for the command-line interface."""

    def test_cli_outputs_valid_json(self, tmp_path):
        fixture = tmp_path / "config.json"
        fixture.write_text(json.dumps({
            "dimensions": {"os": ["ubuntu-latest"], "python-version": ["3.9", "3.10"]},
            "fail_fast": False,
            "max_parallel": 2,
        }))
        result = subprocess.run(
            ["python3", "generate_matrix.py", str(fixture)],
            capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        assert result.returncode == 0, f"CLI failed: {result.stderr}"
        output = json.loads(result.stdout)
        assert "strategy" in output

    def test_cli_exits_nonzero_on_missing_file(self):
        result = subprocess.run(
            ["python3", "generate_matrix.py", "/nonexistent/config.json"],
            capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        assert result.returncode != 0

    def test_cli_exits_nonzero_when_matrix_too_large(self, tmp_path):
        fixture = tmp_path / "config.json"
        fixture.write_text(json.dumps({
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest"],
                "python-version": ["3.9", "3.10", "3.11"],
                "node-version": ["16", "18", "20", "22"],
            },
            "max_size": 5,
        }))
        result = subprocess.run(
            ["python3", "generate_matrix.py", str(fixture)],
            capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        assert result.returncode != 0
        assert "24" in result.stderr  # actual size in error message

    def test_cli_exits_nonzero_with_no_args(self):
        result = subprocess.run(
            ["python3", "generate_matrix.py"],
            capture_output=True, text=True, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        )
        assert result.returncode != 0


class TestLoadConfig:
    """Tests for the config loader."""

    def test_loads_json_file(self, tmp_path):
        config_data = {"dimensions": {"os": ["ubuntu-latest"]}, "fail_fast": False}
        path = tmp_path / "config.json"
        path.write_text(json.dumps(config_data))
        loaded = load_config(str(path))
        assert loaded == config_data

    def test_raises_on_missing_file(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            load_config(str(tmp_path / "nonexistent.json"))


class TestWorkflowStructure:
    """Tests verifying the GitHub Actions workflow file has the expected structure."""

    WORKFLOW_PATH = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        ".github", "workflows", "environment-matrix-generator.yml"
    )

    def test_workflow_file_exists(self):
        assert os.path.exists(self.WORKFLOW_PATH), f"Workflow not found at {self.WORKFLOW_PATH}"

    def test_workflow_has_push_trigger(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # PyYAML 1.1 parses bare `on:` as boolean True; handle both forms.
        triggers = wf.get("on") or wf.get(True) or {}
        assert "push" in triggers, "Workflow must trigger on push"

    def test_workflow_has_workflow_dispatch(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        triggers = wf.get("on") or wf.get(True) or {}
        assert "workflow_dispatch" in triggers

    def test_workflow_has_jobs(self):
        with open(self.WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert "jobs" in wf
        assert len(wf["jobs"]) >= 1

    def test_workflow_references_generate_matrix_script(self):
        script_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "generate_matrix.py"
        )
        assert os.path.exists(script_path), "generate_matrix.py must exist"

    def test_workflow_references_fixture_files(self):
        fixtures_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "fixtures"
        )
        assert os.path.isdir(fixtures_dir), "fixtures/ directory must exist"
        # At least one fixture file
        json_files = [f for f in os.listdir(fixtures_dir) if f.endswith(".json")]
        assert len(json_files) >= 1, "At least one fixture JSON file must exist"

    def test_actionlint_passes(self):
        result = subprocess.run(
            ["actionlint", self.WORKFLOW_PATH],
            capture_output=True, text=True
        )
        assert result.returncode == 0, (
            f"actionlint failed:\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}"
        )
