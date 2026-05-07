#!/usr/bin/env python3
"""
Environment Matrix Generator for GitHub Actions.

Generates a strategy.matrix JSON object suitable for GitHub Actions
from a configuration file that describes OS options, language versions,
and feature flags. Supports include/exclude rules, max-parallel limits,
fail-fast configuration, and validates that the matrix does not exceed
a configurable maximum size.

Usage:
    python3 generate_matrix.py <config.json>

Config schema (all fields optional except 'dimensions'):
{
    "dimensions":   { "<axis>": ["val1", "val2", ...], ... },
    "include":      [ { "<axis>": "<val>", ... }, ... ],
    "exclude":      [ { "<axis>": "<val>", ... }, ... ],
    "max_parallel": <int>,
    "fail_fast":    <bool>,   (default: true)
    "max_size":     <int>     (default: 256)
}
"""
import json
import sys
from typing import Any

DEFAULT_MAX_SIZE = 256


def load_config(path: str) -> dict:
    """Load and parse a JSON configuration file."""
    with open(path) as f:
        return json.load(f)


def compute_matrix_size(dimensions: dict[str, list], includes: list[dict]) -> int:
    """
    Return the total number of matrix entries.

    The base count is the Cartesian product of all dimension sizes.
    Each include entry is an additional row regardless of whether it
    overlaps with the base product — GitHub Actions counts them that way.
    """
    if not dimensions:
        return len(includes)
    base = 1
    for values in dimensions.values():
        base *= len(values)
    return base + len(includes)


def generate_matrix(config: dict) -> dict:
    """
    Generate a GitHub Actions strategy.matrix structure.

    Returns a dict with a top-level 'strategy' key whose value matches
    what belongs under `strategy:` in a GitHub Actions workflow YAML.

    Raises ValueError if the computed matrix size exceeds max_size.
    """
    dimensions: dict[str, list] = config.get("dimensions", {})
    includes: list[dict] = config.get("include", [])
    excludes: list[dict] = config.get("exclude", [])
    max_parallel: int | None = config.get("max_parallel", None)
    fail_fast: bool = config.get("fail_fast", True)
    max_size: int = config.get("max_size", DEFAULT_MAX_SIZE)

    # Validate that the matrix won't exceed the size guard.
    size = compute_matrix_size(dimensions, includes)
    if size > max_size:
        raise ValueError(
            f"Matrix size {size} exceeds maximum allowed size {max_size}. "
            "Reduce the number of dimensions/values or add exclude rules."
        )

    # Build the matrix object that maps directly to strategy.matrix in YAML.
    matrix: dict[str, Any] = {}

    for key, values in dimensions.items():
        matrix[key] = values

    # Only emit include/exclude keys when the lists are non-empty to avoid
    # writing null/empty arrays that would confuse GitHub Actions.
    if includes:
        matrix["include"] = includes
    if excludes:
        matrix["exclude"] = excludes

    strategy: dict[str, Any] = {"matrix": matrix}
    if max_parallel is not None:
        strategy["max-parallel"] = max_parallel
    strategy["fail-fast"] = fail_fast

    return {"strategy": strategy}


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: generate_matrix.py <config.json>", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    try:
        config = load_config(config_path)
    except FileNotFoundError:
        print(f"Error: Config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    try:
        result = generate_matrix(config)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
