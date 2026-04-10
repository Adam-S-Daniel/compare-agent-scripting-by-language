"""
Tests for the Environment Matrix Generator.

Uses red/green TDD methodology:
- Each test is written before the corresponding implementation.
- Tests are organized by feature (cycles 1-6), plus workflow structure tests.
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil
import pytest
import yaml  # noqa: F401 - verified in workflow structure test

# The module under test
import matrix_generator as mg


# ---------------------------------------------------------------------------
# Fixtures: shared test data designed up front to avoid rewriting mid-test
# ---------------------------------------------------------------------------

BASIC_CONFIG = {
    "dimensions": {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.11", "3.12"],
    },
    "max-parallel": 2,
    "fail-fast": False,
}

CONFIG_WITH_EXCLUDES = {
    "dimensions": {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.11", "3.12"],
    },
    "exclude": [
        {"os": "windows-latest", "python-version": "3.11"},
    ],
    "max-parallel": 2,
    "fail-fast": True,
}

CONFIG_WITH_INCLUDES = {
    "dimensions": {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.11", "3.12"],
    },
    "include": [
        {"os": "macos-latest", "python-version": "3.12", "experimental": True},
    ],
    "max-parallel": 4,
    "fail-fast": False,
}

CONFIG_WITH_FLAGS = {
    "dimensions": {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.11", "3.12"],
        "feature-flag": ["enabled", "disabled"],
    },
    "max-parallel": 4,
    "fail-fast": False,
}

CONFIG_TOO_LARGE = {
    "dimensions": {
        "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
        "python-version": ["3.10", "3.11", "3.12", "3.13"],
    },
    "max-size": 5,  # 3x4=12 > 5
    "max-parallel": 4,
    "fail-fast": False,
}

CONFIG_VALID_MAX_SIZE = {
    "dimensions": {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.11", "3.12"],
    },
    "max-size": 4,  # exactly 2x2=4, should pass
    "max-parallel": 2,
    "fail-fast": False,
}


# ---------------------------------------------------------------------------
# Cycle 1: Basic Cartesian product
# ---------------------------------------------------------------------------

class TestBasicCombinations:
    """RED: Test Cartesian product before implementation exists."""

    def test_compute_base_combinations_two_dims(self):
        """2 OS x 2 python-version = 4 combinations."""
        dims = {"os": ["ubuntu-latest", "windows-latest"], "python-version": ["3.11", "3.12"]}
        combos = mg.compute_base_combinations(dims)
        assert len(combos) == 4

    def test_compute_base_combinations_single_dim(self):
        """Single dimension produces one combo per value."""
        dims = {"os": ["ubuntu-latest", "windows-latest"]}
        combos = mg.compute_base_combinations(dims)
        assert len(combos) == 2

    def test_compute_base_combinations_three_dims(self):
        """2 x 2 x 2 = 8 combinations."""
        dims = {
            "os": ["ubuntu-latest", "windows-latest"],
            "python-version": ["3.11", "3.12"],
            "feature-flag": ["enabled", "disabled"],
        }
        combos = mg.compute_base_combinations(dims)
        assert len(combos) == 8

    def test_compute_base_combinations_empty(self):
        """Empty dimensions return empty list."""
        assert mg.compute_base_combinations({}) == []

    def test_combo_values_are_dicts(self):
        """Each combination is a dict with keys from dimensions."""
        dims = {"os": ["ubuntu-latest"], "python-version": ["3.11"]}
        combos = mg.compute_base_combinations(dims)
        assert combos == [{"os": "ubuntu-latest", "python-version": "3.11"}]


# ---------------------------------------------------------------------------
# Cycle 2: Exclude rules
# ---------------------------------------------------------------------------

class TestExcludeRules:
    """RED: Test exclude filtering before implementation exists."""

    def test_exclude_removes_matching_combo(self):
        """Exclude rule removes exactly the matching combinations."""
        combos = [
            {"os": "ubuntu-latest", "python-version": "3.11"},
            {"os": "ubuntu-latest", "python-version": "3.12"},
            {"os": "windows-latest", "python-version": "3.11"},
            {"os": "windows-latest", "python-version": "3.12"},
        ]
        excludes = [{"os": "windows-latest", "python-version": "3.11"}]
        result = mg.apply_excludes(combos, excludes)
        assert len(result) == 3
        assert {"os": "windows-latest", "python-version": "3.11"} not in result

    def test_exclude_partial_match_removes_all_matching(self):
        """Exclude on single key removes all combos where that key matches."""
        combos = [
            {"os": "ubuntu-latest", "python-version": "3.11"},
            {"os": "ubuntu-latest", "python-version": "3.12"},
            {"os": "windows-latest", "python-version": "3.11"},
        ]
        excludes = [{"os": "ubuntu-latest"}]
        result = mg.apply_excludes(combos, excludes)
        assert len(result) == 1
        assert result[0] == {"os": "windows-latest", "python-version": "3.11"}

    def test_exclude_no_match_returns_unchanged(self):
        """Exclude rule matching nothing leaves the list unchanged."""
        combos = [{"os": "ubuntu-latest", "python-version": "3.11"}]
        excludes = [{"os": "macos-latest"}]
        result = mg.apply_excludes(combos, excludes)
        assert result == combos

    def test_exclude_empty_rules(self):
        """Empty exclude list returns the original list."""
        combos = [{"os": "ubuntu-latest"}]
        assert mg.apply_excludes(combos, []) == combos

    def test_multiple_excludes(self):
        """Multiple exclude rules are all applied."""
        combos = [
            {"os": "ubuntu-latest", "python-version": "3.11"},
            {"os": "ubuntu-latest", "python-version": "3.12"},
            {"os": "windows-latest", "python-version": "3.11"},
            {"os": "windows-latest", "python-version": "3.12"},
        ]
        excludes = [
            {"os": "windows-latest", "python-version": "3.11"},
            {"os": "ubuntu-latest", "python-version": "3.12"},
        ]
        result = mg.apply_excludes(combos, excludes)
        assert len(result) == 2


# ---------------------------------------------------------------------------
# Cycle 3: Include rules
# ---------------------------------------------------------------------------

class TestIncludeRules:
    """RED: Test include addition before implementation exists."""

    def test_include_adds_new_combination(self):
        """Include entries not already in the base are added."""
        base = [
            {"os": "ubuntu-latest", "python-version": "3.11"},
            {"os": "ubuntu-latest", "python-version": "3.12"},
        ]
        includes = [{"os": "macos-latest", "python-version": "3.12", "experimental": True}]
        result = mg.apply_includes(base, includes)
        assert len(result) == 3
        assert {"os": "macos-latest", "python-version": "3.12", "experimental": True} in result

    def test_include_empty_adds_nothing(self):
        """Empty include list does not change the base."""
        base = [{"os": "ubuntu-latest"}]
        assert mg.apply_includes(base, []) == base

    def test_multiple_includes(self):
        """Multiple includes are all added."""
        base = [{"os": "ubuntu-latest", "python-version": "3.11"}]
        includes = [
            {"os": "macos-latest", "python-version": "3.11"},
            {"os": "macos-latest", "python-version": "3.12"},
        ]
        result = mg.apply_includes(base, includes)
        assert len(result) == 3


# ---------------------------------------------------------------------------
# Cycle 4: Max-parallel and fail-fast pass through to output
# ---------------------------------------------------------------------------

class TestStrategyConfig:
    """RED: Test that max-parallel and fail-fast appear in output."""

    def test_generate_matrix_contains_fail_fast(self):
        """Output strategy has fail-fast matching config."""
        result = mg.generate_matrix(BASIC_CONFIG)
        assert result["strategy"]["fail-fast"] is False

    def test_generate_matrix_contains_max_parallel(self):
        """Output strategy has max-parallel matching config."""
        result = mg.generate_matrix(BASIC_CONFIG)
        assert result["strategy"]["max-parallel"] == 2

    def test_generate_matrix_defaults(self):
        """Defaults: fail-fast=True, no max-parallel limit."""
        config = {"dimensions": {"os": ["ubuntu-latest"]}}
        result = mg.generate_matrix(config)
        assert result["strategy"]["fail-fast"] is True
        assert "max-parallel" not in result["strategy"]


# ---------------------------------------------------------------------------
# Cycle 5: Max-size validation
# ---------------------------------------------------------------------------

class TestMaxSizeValidation:
    """RED: Test matrix size validation before implementation exists."""

    def test_matrix_exceeding_max_size_raises_error(self):
        """Matrix with more entries than max-size raises MatrixTooLargeError."""
        with pytest.raises(mg.MatrixTooLargeError) as exc_info:
            mg.generate_matrix(CONFIG_TOO_LARGE)
        # Error message includes actual size and maximum
        assert "12" in str(exc_info.value)
        assert "5" in str(exc_info.value)

    def test_matrix_at_max_size_passes(self):
        """Matrix with exactly max-size entries passes validation."""
        result = mg.generate_matrix(CONFIG_VALID_MAX_SIZE)
        assert result["matrix-size"] == 4

    def test_no_max_size_no_validation(self):
        """When max-size is not set, no size validation is performed."""
        config = {
            "dimensions": {
                "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
                "python-version": ["3.10", "3.11", "3.12", "3.13"],
            },
        }
        # Should not raise even with 12 combinations
        result = mg.generate_matrix(config)
        assert result["matrix-size"] == 12

    def test_matrix_size_reported_in_output(self):
        """Output includes the computed matrix-size."""
        result = mg.generate_matrix(BASIC_CONFIG)
        assert result["matrix-size"] == 4

    def test_matrix_size_with_excludes(self):
        """Matrix size accounts for excluded combinations."""
        result = mg.generate_matrix(CONFIG_WITH_EXCLUDES)
        # 2x2=4 base, minus 1 excluded = 3
        assert result["matrix-size"] == 3

    def test_matrix_size_with_includes(self):
        """Matrix size accounts for added include entries."""
        result = mg.generate_matrix(CONFIG_WITH_INCLUDES)
        # 2x2=4 base + 1 include = 5
        assert result["matrix-size"] == 5


# ---------------------------------------------------------------------------
# Cycle 6: Full JSON output structure
# ---------------------------------------------------------------------------

class TestOutputStructure:
    """RED: Test the complete output JSON structure."""

    def test_output_has_strategy_key(self):
        """Top-level output has 'strategy' key."""
        result = mg.generate_matrix(BASIC_CONFIG)
        assert "strategy" in result

    def test_strategy_has_matrix_key(self):
        """strategy contains 'matrix' key with dimensions."""
        result = mg.generate_matrix(BASIC_CONFIG)
        assert "matrix" in result["strategy"]

    def test_matrix_contains_dimensions(self):
        """matrix contains all configured dimension names."""
        result = mg.generate_matrix(BASIC_CONFIG)
        matrix = result["strategy"]["matrix"]
        assert "os" in matrix
        assert "python-version" in matrix
        assert matrix["os"] == ["ubuntu-latest", "windows-latest"]
        assert matrix["python-version"] == ["3.11", "3.12"]

    def test_matrix_with_excludes_in_output(self):
        """Exclude rules appear in output matrix for GitHub Actions."""
        result = mg.generate_matrix(CONFIG_WITH_EXCLUDES)
        assert result["strategy"]["matrix"]["exclude"] == CONFIG_WITH_EXCLUDES["exclude"]

    def test_matrix_with_includes_in_output(self):
        """Include rules appear in output matrix for GitHub Actions."""
        result = mg.generate_matrix(CONFIG_WITH_INCLUDES)
        assert result["strategy"]["matrix"]["include"] == CONFIG_WITH_INCLUDES["include"]

    def test_output_is_json_serializable(self):
        """Output can be serialized to JSON without error."""
        result = mg.generate_matrix(BASIC_CONFIG)
        serialized = json.dumps(result)
        assert json.loads(serialized) == result

    def test_with_feature_flags(self):
        """Feature flags (extra dimensions) appear as dimension in matrix."""
        result = mg.generate_matrix(CONFIG_WITH_FLAGS)
        assert "feature-flag" in result["strategy"]["matrix"]
        assert result["matrix-size"] == 8  # 2x2x2


# ---------------------------------------------------------------------------
# Cycle 7: Workflow structure tests
# ---------------------------------------------------------------------------

WORKFLOW_PATH = os.path.join(
    os.path.dirname(__file__),
    ".github", "workflows", "environment-matrix-generator.yml"
)
SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "matrix_generator.py")


class TestWorkflowStructure:
    """Tests that verify the GitHub Actions workflow is correctly structured."""

    def test_workflow_file_exists(self):
        """Workflow YAML file must exist at the expected path."""
        assert os.path.exists(WORKFLOW_PATH), f"Workflow not found: {WORKFLOW_PATH}"

    def test_workflow_is_valid_yaml(self):
        """Workflow file must be parseable YAML."""
        with open(WORKFLOW_PATH) as f:
            content = yaml.safe_load(f)
        assert content is not None

    def test_workflow_has_push_trigger(self):
        """Workflow must have a push trigger.

        Note: PyYAML 1.1 parses the bare YAML key `on` as boolean True.
        GitHub Actions always uses `on:` (unquoted), so we handle both.
        """
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        # `on` may be parsed as True (PyYAML boolean) or as the string "on"
        triggers = wf.get("on", wf.get(True, {})) or {}
        assert "push" in triggers

    def test_workflow_has_jobs(self):
        """Workflow must define at least one job."""
        with open(WORKFLOW_PATH) as f:
            wf = yaml.safe_load(f)
        assert wf.get("jobs"), "Workflow must have jobs"

    def test_workflow_uses_checkout(self):
        """Workflow must use actions/checkout@v4."""
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        assert "actions/checkout@v4" in content

    def test_workflow_references_script(self):
        """Workflow must reference the matrix_generator.py script."""
        with open(WORKFLOW_PATH) as f:
            content = f.read()
        assert "matrix_generator.py" in content

    def test_script_file_exists(self):
        """The script referenced in the workflow must exist."""
        assert os.path.exists(SCRIPT_PATH), f"Script not found: {SCRIPT_PATH}"

    def test_actionlint_passes(self):
        """Workflow must pass actionlint validation."""
        result = subprocess.run(
            ["actionlint", WORKFLOW_PATH],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (
            f"actionlint failed:\n{result.stdout}\n{result.stderr}"
        )
