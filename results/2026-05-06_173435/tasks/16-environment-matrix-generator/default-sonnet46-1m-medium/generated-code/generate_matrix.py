#!/usr/bin/env python3
"""
Generate a GitHub Actions strategy.matrix JSON from a configuration file.

Config format:
  {
    "<var>": ["val1", "val2", ...],   # matrix axis (e.g. "os", "python-version")
    "include": [...],                 # extra combinations to add
    "exclude": [...],                 # combinations to remove
    "max-parallel": <int>,            # optional: GitHub Actions max-parallel
    "fail-fast": <bool>,              # optional: default true
    "max-size": <int>                 # validation limit, default 256
  }

Output: GitHub Actions strategy object printed as JSON.
"""

import itertools
import json
import sys
from typing import Any


# Keys that are not matrix variable axes
_SPECIAL_KEYS = {"include", "exclude", "max-parallel", "fail-fast", "max-size"}


def generate_matrix(config: dict[str, Any]) -> dict[str, Any]:
    """
    Build a GitHub Actions strategy object from the config dict.

    Returns a dict with keys: matrix, fail-fast, optionally max-parallel,
    and _total_combinations (a convenience count for test assertions).

    Raises ValueError if the matrix exceeds max-size.
    """
    matrix_vars: dict[str, list] = {
        k: v for k, v in config.items() if k not in _SPECIAL_KEYS
    }
    includes: list[dict] = config.get("include", [])
    excludes: list[dict] = config.get("exclude", [])
    max_parallel: int | None = config.get("max-parallel")
    fail_fast: bool = config.get("fail-fast", True)
    max_size: int = config.get("max-size", 256)

    # Generate cartesian product of all axis values
    if matrix_vars:
        keys = list(matrix_vars.keys())
        value_lists = [matrix_vars[k] for k in keys]
        combinations = [dict(zip(keys, combo)) for combo in itertools.product(*value_lists)]
    else:
        combinations = [{}]

    # Apply exclude rules: drop any combination that matches all fields of an exclude entry
    def _matches_exclude(combo: dict, exclude: dict) -> bool:
        return all(combo.get(k) == v for k, v in exclude.items())

    combinations = [
        c for c in combinations
        if not any(_matches_exclude(c, exc) for exc in excludes)
    ]

    total = len(combinations) + len(includes)
    if total > max_size:
        raise ValueError(
            f"Matrix size {total} exceeds maximum of {max_size}. "
            f"Reduce the number of axes, values, or raise max-size."
        )

    # Build the matrix object (axes + optional include/exclude)
    matrix: dict[str, Any] = dict(matrix_vars)
    if excludes:
        matrix["exclude"] = excludes
    if includes:
        matrix["include"] = includes

    # Build the strategy object
    result: dict[str, Any] = {
        "matrix": matrix,
        "fail-fast": fail_fast,
    }
    if max_parallel is not None:
        result["max-parallel"] = max_parallel

    # Convenience field for test assertions (not consumed by GitHub Actions)
    result["_total_combinations"] = total

    return result


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: generate_matrix.py <config-file>", file=sys.stderr)
        sys.exit(1)

    config_file = sys.argv[1]

    try:
        with open(config_file) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Error: Config file '{config_file}' not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        result = generate_matrix(config)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print("MATRIX_JSON:")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
