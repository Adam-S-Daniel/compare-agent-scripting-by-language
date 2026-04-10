#!/usr/bin/env python3
"""
Environment Matrix Generator for GitHub Actions.

Generates a build matrix JSON suitable for GitHub Actions strategy.matrix
from a configuration describing OS options, language versions, and feature flags.

Supports:
- Cartesian product of dimension values (os, language versions, feature flags)
- Exclude rules: remove specific combinations from the base matrix
- Include rules: add extra combinations (beyond the Cartesian product)
- max-parallel: limit concurrent jobs in the strategy
- fail-fast: stop all jobs when one fails (default: True)
- max-size: validate the matrix does not exceed a maximum number of jobs

Usage:
    python matrix_generator.py config.json
    python matrix_generator.py config.json --pretty
"""

import itertools
import json
import sys
from typing import Any


class MatrixTooLargeError(Exception):
    """Raised when the generated matrix exceeds the configured maximum size."""


def compute_base_combinations(dimensions: dict[str, list]) -> list[dict]:
    """
    Compute the Cartesian product of all dimension values.

    Args:
        dimensions: dict mapping dimension names to lists of values.
            e.g. {"os": ["ubuntu", "windows"], "python-version": ["3.11", "3.12"]}

    Returns:
        List of dicts, one per combination.
    """
    if not dimensions:
        return []

    keys = list(dimensions.keys())
    values = [dimensions[k] for k in keys]

    return [dict(zip(keys, combo)) for combo in itertools.product(*values)]


def matches_rule(combination: dict, rule: dict) -> bool:
    """
    Check whether a combination matches a rule.

    A match requires that every key in the rule exists in the combination
    with the same value. Extra keys in the combination are ignored.
    """
    return all(combination.get(k) == v for k, v in rule.items())


def apply_excludes(combinations: list[dict], excludes: list[dict]) -> list[dict]:
    """
    Remove combinations that match any exclude rule.

    Args:
        combinations: base list of job combinations.
        excludes: list of rule dicts; any matching combination is removed.

    Returns:
        Filtered list with excluded combinations removed.
    """
    if not excludes:
        return combinations

    return [
        combo for combo in combinations
        if not any(matches_rule(combo, exc) for exc in excludes)
    ]


def apply_includes(base: list[dict], includes: list[dict]) -> list[dict]:
    """
    Add include entries to the matrix.

    For simplicity and correctness with GitHub Actions semantics:
    each include entry is appended to the result as a new combination.
    (GitHub Actions may also use includes to extend existing combinations,
    but for size-counting purposes we treat all includes as additions.)

    Args:
        base: the matrix after excludes have been applied.
        includes: list of extra combination dicts to add.

    Returns:
        Extended list with include entries appended.
    """
    if not includes:
        return base

    return list(base) + list(includes)


def generate_matrix(config: dict[str, Any]) -> dict[str, Any]:
    """
    Generate a GitHub Actions build matrix from a configuration dict.

    Config schema:
        dimensions   (required): dict[str, list] — dimension name -> list of values
        include      (optional): list[dict] — extra combinations to add
        exclude      (optional): list[dict] — rules for combinations to remove
        max-parallel (optional): int — max concurrent jobs (omitted if not set)
        fail-fast    (optional): bool — stop on first failure (default True)
        max-size     (optional): int — raise MatrixTooLargeError if exceeded

    Returns:
        dict with keys:
            strategy: {fail-fast, max-parallel?, matrix: {dims..., include?, exclude?}}
            matrix-size: int  — effective number of jobs

    Raises:
        MatrixTooLargeError: if matrix-size > max-size.
        ValueError: if config is malformed.
    """
    dimensions: dict[str, list] = config.get("dimensions", {})
    includes: list[dict] = config.get("include", [])
    excludes: list[dict] = config.get("exclude", [])
    max_parallel: int | None = config.get("max-parallel")
    fail_fast: bool = config.get("fail-fast", True)
    max_size: int | None = config.get("max-size")

    # Compute effective size: base combinations - excludes + includes
    base = compute_base_combinations(dimensions)
    after_excludes = apply_excludes(base, excludes)
    final_combinations = apply_includes(after_excludes, includes)
    matrix_size = len(final_combinations)

    # Validate against max-size
    if max_size is not None and matrix_size > max_size:
        raise MatrixTooLargeError(
            f"Matrix size {matrix_size} exceeds maximum {max_size}. "
            f"Reduce dimensions or increase max-size."
        )

    # Build the matrix object (GitHub Actions format)
    matrix: dict[str, Any] = dict(dimensions)
    if includes:
        matrix["include"] = includes
    if excludes:
        matrix["exclude"] = excludes

    # Build the strategy object
    strategy: dict[str, Any] = {
        "fail-fast": fail_fast,
        "matrix": matrix,
    }
    if max_parallel is not None:
        strategy["max-parallel"] = max_parallel

    return {
        "strategy": strategy,
        "matrix-size": matrix_size,
    }


def main() -> int:
    """
    CLI entry point.

    Usage: matrix_generator.py <config.json> [--pretty]

    Reads a JSON config file, generates the matrix, and prints the result as JSON.
    On error (including matrix too large), prints to stderr and exits non-zero.
    """
    if len(sys.argv) < 2:
        print("Usage: matrix_generator.py <config.json> [--pretty]", file=sys.stderr)
        return 1

    config_path = sys.argv[1]
    pretty = "--pretty" in sys.argv

    try:
        with open(config_path) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in {config_path}: {e}", file=sys.stderr)
        return 1

    try:
        result = generate_matrix(config)
    except MatrixTooLargeError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    indent = 2 if pretty else None
    output = json.dumps(result, indent=indent)
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
