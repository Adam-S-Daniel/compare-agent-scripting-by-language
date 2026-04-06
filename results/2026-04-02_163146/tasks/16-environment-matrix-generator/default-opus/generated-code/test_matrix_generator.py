"""
Tests for the GitHub Actions environment matrix generator.

TDD approach: each test was written BEFORE the corresponding implementation code.
We build up functionality incrementally:
  1. Basic cartesian product of matrix dimensions
  2. Include rules (add extra combinations)
  3. Exclude rules (remove specific combinations)
  4. Max-parallel and fail-fast configuration
  5. Matrix size validation
  6. Input validation and error handling
  7. Complete JSON output
"""

import json
import unittest
from matrix_generator import generate_matrix, MatrixConfig, MatrixError


# ---------------------------------------------------------------------------
# TDD Cycle 1: Basic cartesian-product matrix generation
# ---------------------------------------------------------------------------
class TestBasicMatrixGeneration(unittest.TestCase):
    """Generate a cartesian product from dimension lists."""

    def test_single_dimension(self):
        """One dimension produces one entry per value."""
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest", "windows-latest"]})
        result = generate_matrix(config)
        self.assertEqual(
            result["matrix"],
            [{"os": "ubuntu-latest"}, {"os": "windows-latest"}],
        )

    def test_two_dimensions(self):
        """Two dimensions produce a full cartesian product."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"], "node": ["18", "20"]},
        )
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 2)
        self.assertIn({"os": "ubuntu-latest", "node": "18"}, result["matrix"])
        self.assertIn({"os": "ubuntu-latest", "node": "20"}, result["matrix"])

    def test_three_dimensions(self):
        """Three dimensions: 2 x 2 x 2 = 8 combinations."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest"],
                "python": ["3.10", "3.12"],
                "debug": [True, False],
            },
        )
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 8)
        self.assertIn(
            {"os": "ubuntu-latest", "python": "3.10", "debug": True},
            result["matrix"],
        )

    def test_empty_dimension_values(self):
        """A dimension with an empty list produces zero combinations."""
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"], "node": []})
        result = generate_matrix(config)
        self.assertEqual(result["matrix"], [])


# ---------------------------------------------------------------------------
# TDD Cycle 2: Include rules — add extra combinations to the matrix
# ---------------------------------------------------------------------------
class TestIncludeRules(unittest.TestCase):
    """Include rules add specific combinations that might not appear in the
    cartesian product, or add extra keys to matching rows."""

    def test_include_adds_extra_combination(self):
        """An include entry with values outside the normal product is appended."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"], "node": ["18"]},
            include=[{"os": "macos-latest", "node": "20"}],
        )
        result = generate_matrix(config)
        self.assertIn({"os": "macos-latest", "node": "20"}, result["matrix"])

    def test_include_adds_extra_key_to_matching_rows(self):
        """An include that partially matches existing rows extends them with
        the extra key (GitHub Actions 'include' behavior)."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"]},
            include=[{"os": "ubuntu-latest", "experimental": True}],
        )
        result = generate_matrix(config)
        # The ubuntu row should have the extra key
        ubuntu_rows = [r for r in result["matrix"] if r.get("os") == "ubuntu-latest"]
        self.assertTrue(all(r.get("experimental") is True for r in ubuntu_rows))
        # The windows row should NOT have the extra key
        win_rows = [r for r in result["matrix"] if r.get("os") == "windows-latest"]
        self.assertTrue(all("experimental" not in r for r in win_rows))

    def test_multiple_includes(self):
        """Multiple include rules are all applied."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            include=[
                {"os": "macos-latest"},
                {"os": "windows-latest"},
            ],
        )
        result = generate_matrix(config)
        os_values = [r["os"] for r in result["matrix"]]
        self.assertIn("macos-latest", os_values)
        self.assertIn("windows-latest", os_values)
        self.assertIn("ubuntu-latest", os_values)


# ---------------------------------------------------------------------------
# TDD Cycle 3: Exclude rules — remove specific combinations
# ---------------------------------------------------------------------------
class TestExcludeRules(unittest.TestCase):
    """Exclude rules remove combinations that match ALL specified keys."""

    def test_exclude_removes_matching_combination(self):
        """A fully-matching exclude entry is removed."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"]},
            exclude=[{"os": "windows-latest", "node": "18"}],
        )
        result = generate_matrix(config)
        self.assertNotIn(
            {"os": "windows-latest", "node": "18"}, result["matrix"]
        )
        # Other combos survive
        self.assertEqual(len(result["matrix"]), 3)

    def test_exclude_partial_match_removes_all_matching(self):
        """An exclude with fewer keys than the matrix removes every row where
        ALL specified keys match."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"]},
            exclude=[{"os": "windows-latest"}],
        )
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 2)
        self.assertTrue(
            all(r["os"] != "windows-latest" for r in result["matrix"])
        )

    def test_exclude_no_match_is_noop(self):
        """Excluding a non-existent combination doesn't change the matrix."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"], "node": ["18"]},
            exclude=[{"os": "macos-latest", "node": "20"}],
        )
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 1)

    def test_exclude_applied_after_include(self):
        """Excludes run after includes, so an included row can be excluded."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]},
            include=[{"os": "macos-latest"}],
            exclude=[{"os": "macos-latest"}],
        )
        result = generate_matrix(config)
        os_values = [r["os"] for r in result["matrix"]]
        self.assertNotIn("macos-latest", os_values)


# ---------------------------------------------------------------------------
# TDD Cycle 4: Strategy-level options (max-parallel, fail-fast)
# ---------------------------------------------------------------------------
class TestStrategyOptions(unittest.TestCase):
    """max-parallel and fail-fast are top-level strategy keys."""

    def test_default_fail_fast_is_true(self):
        """By default, fail-fast should be True (GitHub Actions default)."""
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"]})
        result = generate_matrix(config)
        self.assertTrue(result["fail-fast"])

    def test_fail_fast_false(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]}, fail_fast=False
        )
        result = generate_matrix(config)
        self.assertFalse(result["fail-fast"])

    def test_max_parallel_included_when_set(self):
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"]}, max_parallel=2
        )
        result = generate_matrix(config)
        self.assertEqual(result["max-parallel"], 2)

    def test_max_parallel_absent_when_none(self):
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"]})
        result = generate_matrix(config)
        self.assertNotIn("max-parallel", result)

    def test_max_parallel_must_be_positive(self):
        with self.assertRaises(MatrixError) as ctx:
            config = MatrixConfig(
                dimensions={"os": ["ubuntu-latest"]}, max_parallel=0
            )
            generate_matrix(config)
        self.assertIn("positive", str(ctx.exception).lower())


# ---------------------------------------------------------------------------
# TDD Cycle 5: Matrix size validation
# ---------------------------------------------------------------------------
class TestMatrixSizeValidation(unittest.TestCase):
    """GitHub Actions caps the matrix at 256 combinations. We must validate."""

    def test_matrix_within_limit_passes(self):
        """A matrix with <= max_size combinations is accepted."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"]},
            max_size=256,
        )
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 2)

    def test_matrix_exceeding_limit_raises(self):
        """A matrix exceeding max_size raises a clear error."""
        config = MatrixConfig(
            dimensions={
                "a": list(range(10)),
                "b": list(range(10)),
                "c": list(range(10)),
            },
            max_size=256,
        )
        # 10 * 10 * 10 = 1000, exceeds 256
        with self.assertRaises(MatrixError) as ctx:
            generate_matrix(config)
        self.assertIn("1000", str(ctx.exception))
        self.assertIn("256", str(ctx.exception))

    def test_custom_max_size(self):
        """max_size can be configured lower than the default."""
        config = MatrixConfig(
            dimensions={"os": ["a", "b", "c"]},
            max_size=2,
        )
        with self.assertRaises(MatrixError):
            generate_matrix(config)

    def test_default_max_size_is_256(self):
        """Default max_size should be 256 (GitHub Actions limit)."""
        config = MatrixConfig(dimensions={"os": ["ubuntu-latest"]})
        self.assertEqual(config.max_size, 256)

    def test_excludes_reduce_size_below_limit(self):
        """Excludes that bring the matrix below the limit should pass."""
        # 3 x 3 = 9, exclude 5 -> 4, limit 5 -> should pass
        config = MatrixConfig(
            dimensions={"a": [1, 2, 3], "b": [1, 2, 3]},
            exclude=[
                {"a": 1, "b": 1},
                {"a": 1, "b": 2},
                {"a": 2, "b": 1},
                {"a": 2, "b": 2},
                {"a": 3, "b": 3},
            ],
            max_size=5,
        )
        result = generate_matrix(config)
        self.assertLessEqual(len(result["matrix"]), 5)


# ---------------------------------------------------------------------------
# TDD Cycle 6: Input validation and error handling
# ---------------------------------------------------------------------------
class TestInputValidation(unittest.TestCase):
    """Graceful errors on bad input."""

    def test_empty_dimensions_error(self):
        """At least one dimension is required."""
        with self.assertRaises(MatrixError) as ctx:
            config = MatrixConfig(dimensions={})
            generate_matrix(config)
        self.assertIn("dimension", str(ctx.exception).lower())

    def test_dimension_values_must_be_lists(self):
        """Each dimension value must be a list."""
        with self.assertRaises(MatrixError):
            config = MatrixConfig(dimensions={"os": "ubuntu-latest"})
            generate_matrix(config)

    def test_include_must_be_list_of_dicts(self):
        """Include must be a list of dicts."""
        with self.assertRaises(MatrixError):
            config = MatrixConfig(
                dimensions={"os": ["ubuntu-latest"]},
                include="bad",
            )
            generate_matrix(config)

    def test_exclude_must_be_list_of_dicts(self):
        """Exclude must be a list of dicts."""
        with self.assertRaises(MatrixError):
            config = MatrixConfig(
                dimensions={"os": ["ubuntu-latest"]},
                exclude="bad",
            )
            generate_matrix(config)


# ---------------------------------------------------------------------------
# TDD Cycle 7: Complete JSON output
# ---------------------------------------------------------------------------
class TestJsonOutput(unittest.TestCase):
    """The output should be valid JSON suitable for strategy.matrix."""

    def test_output_is_json_serializable(self):
        """The result can be serialized to JSON."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"]},
            fail_fast=False,
            max_parallel=2,
        )
        result = generate_matrix(config)
        json_str = json.dumps(result, indent=2)
        parsed = json.loads(json_str)
        self.assertIn("matrix", parsed)
        self.assertIn("fail-fast", parsed)
        self.assertIn("max-parallel", parsed)

    def test_output_structure_matches_github_actions(self):
        """Output has the structure GitHub Actions expects under strategy."""
        config = MatrixConfig(
            dimensions={"os": ["ubuntu-latest"], "node": ["18"]},
            include=[{"os": "macos-latest", "node": "20"}],
            exclude=[],
            fail_fast=True,
            max_parallel=4,
        )
        result = generate_matrix(config)
        # Top-level keys
        self.assertIn("matrix", result)
        self.assertIn("fail-fast", result)
        self.assertIn("max-parallel", result)
        # matrix is a list of dicts
        self.assertIsInstance(result["matrix"], list)
        for entry in result["matrix"]:
            self.assertIsInstance(entry, dict)

    def test_mixed_value_types_in_matrix(self):
        """Matrix values can be strings, numbers, and booleans."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest"],
                "version": [14, 16, 18],
                "experimental": [True, False],
            },
        )
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 6)
        json_str = json.dumps(result)
        parsed = json.loads(json_str)
        self.assertEqual(len(parsed["matrix"]), 6)


# ---------------------------------------------------------------------------
# TDD Cycle 8: End-to-end / integration
# ---------------------------------------------------------------------------
class TestEndToEnd(unittest.TestCase):
    """Full realistic scenarios."""

    def test_realistic_ci_matrix(self):
        """A realistic multi-OS, multi-version matrix with includes/excludes."""
        config = MatrixConfig(
            dimensions={
                "os": ["ubuntu-latest", "windows-latest", "macos-latest"],
                "python": ["3.10", "3.11", "3.12"],
            },
            include=[
                # Add an experimental Python 3.13 only on Ubuntu
                {"os": "ubuntu-latest", "python": "3.13", "experimental": True},
            ],
            exclude=[
                # Don't test 3.10 on macos (e.g., incompatible)
                {"os": "macos-latest", "python": "3.10"},
            ],
            fail_fast=False,
            max_parallel=4,
        )
        result = generate_matrix(config)

        # 3*3 = 9 - 1 exclude + 1 include = 9
        self.assertEqual(len(result["matrix"]), 9)
        self.assertFalse(result["fail-fast"])
        self.assertEqual(result["max-parallel"], 4)

        # The included experimental row should exist
        exp_rows = [r for r in result["matrix"] if r.get("experimental") is True]
        self.assertEqual(len(exp_rows), 1)
        self.assertEqual(exp_rows[0]["python"], "3.13")

        # The excluded row should not exist
        self.assertNotIn(
            {"os": "macos-latest", "python": "3.10"},
            result["matrix"],
        )

    def test_from_json_config_string(self):
        """Build a MatrixConfig from a JSON string (config file scenario)."""
        json_input = json.dumps({
            "dimensions": {
                "os": ["ubuntu-latest"],
                "node": ["18", "20"],
            },
            "include": [{"os": "ubuntu-latest", "node": "22", "experimental": True}],
            "exclude": [],
            "fail_fast": False,
            "max_parallel": 2,
            "max_size": 256,
        })
        config = MatrixConfig.from_json(json_input)
        result = generate_matrix(config)
        self.assertEqual(len(result["matrix"]), 3)
        self.assertFalse(result["fail-fast"])
        self.assertEqual(result["max-parallel"], 2)


if __name__ == "__main__":
    unittest.main()
