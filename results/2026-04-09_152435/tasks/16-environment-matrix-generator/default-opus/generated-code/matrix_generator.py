#!/usr/bin/env python3
"""
Environment Matrix Generator for GitHub Actions.

Reads a JSON configuration file and generates a build matrix (strategy object)
suitable for GitHub Actions strategy.matrix.

Supports:
- Cartesian product of OS options, language versions, and feature flags
- Include rules (add specific extra combinations)
- Exclude rules (remove specific combinations)
- max-parallel and fail-fast configuration
- Matrix size validation against a configurable maximum

Usage:
    python3 matrix_generator.py <config.json>

Config format:
    {
      "matrix": {
        "os": ["ubuntu-latest", "windows-latest"],
        "python-version": ["3.10", "3.11"]
      },
      "include": [{"os": "ubuntu-latest", "python-version": "3.12"}],
      "exclude": [{"os": "windows-latest", "python-version": "3.10"}],
      "fail-fast": true,
      "max-parallel": 4,
      "max-size": 256
    }
"""

import json
import sys
import itertools


def load_config(path):
    """Load and validate a matrix configuration file.

    Raises ValueError for missing/invalid 'matrix' key or empty dimensions.
    Raises FileNotFoundError / json.JSONDecodeError for file issues.
    """
    with open(path) as f:
        config = json.load(f)

    if "matrix" not in config:
        raise ValueError("Configuration must contain a 'matrix' key with dimension arrays")

    matrix = config["matrix"]
    if not isinstance(matrix, dict) or not matrix:
        raise ValueError("'matrix' must be a non-empty object with dimension arrays")

    # Validate each dimension is a non-empty list
    for key, values in matrix.items():
        if not isinstance(values, list) or not values:
            raise ValueError(f"Matrix dimension '{key}' must be a non-empty array")

    return config


def compute_cartesian_product(matrix):
    """Compute all combinations from matrix dimensions.

    Returns a list of dicts, one per combination, with keys sorted
    alphabetically for deterministic output.
    """
    keys = sorted(matrix.keys())
    values = [matrix[k] for k in keys]
    combinations = []
    for combo in itertools.product(*values):
        combinations.append(dict(zip(keys, combo)))
    return combinations


def apply_excludes(combinations, excludes):
    """Remove combinations that match any exclude rule.

    A combination matches an exclude rule if all key-value pairs in the
    rule are present in the combination.
    """
    if not excludes:
        return combinations

    result = []
    for combo in combinations:
        excluded = False
        for rule in excludes:
            # All keys in the rule must match the combination
            if all(combo.get(k) == v for k, v in rule.items()):
                excluded = True
                break
        if not excluded:
            result.append(combo)
    return result


def apply_includes(combinations, includes):
    """Add include combinations that aren't already present.

    An include is considered already present if an existing combination
    matches all of the include's key-value pairs.
    """
    if not includes:
        return combinations

    result = list(combinations)
    for inc in includes:
        already_exists = any(
            all(combo.get(k) == v for k, v in inc.items())
            for combo in result
        )
        if not already_exists:
            result.append(dict(inc))
    return result


def generate_matrix(config):
    """Generate the complete strategy object from a configuration dict.

    Returns a dict with:
    - strategy: the GitHub Actions strategy object (matrix, fail-fast, max-parallel)
    - computed_combinations: the expanded list of all matrix entries
    - total_combinations: count of entries
    """
    matrix = config["matrix"]
    includes = config.get("include", [])
    excludes = config.get("exclude", [])
    fail_fast = config.get("fail-fast", True)
    max_parallel = config.get("max-parallel", None)
    max_size = config.get("max-size", 256)

    # Step 1: cartesian product of all dimensions
    combinations = compute_cartesian_product(matrix)

    # Step 2: remove excluded combinations
    combinations = apply_excludes(combinations, excludes)

    # Step 3: add included combinations
    combinations = apply_includes(combinations, includes)

    # Step 4: validate size
    if len(combinations) > max_size:
        raise ValueError(
            f"Matrix size {len(combinations)} exceeds maximum allowed size of {max_size}"
        )

    # Build the strategy.matrix object (dimensions + include/exclude rules)
    strategy_matrix = dict(matrix)
    if includes:
        strategy_matrix["include"] = includes
    if excludes:
        strategy_matrix["exclude"] = excludes

    strategy = {
        "matrix": strategy_matrix,
        "fail-fast": fail_fast,
    }
    if max_parallel is not None:
        strategy["max-parallel"] = max_parallel

    return {
        "strategy": strategy,
        "computed_combinations": combinations,
        "total_combinations": len(combinations),
    }


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 matrix_generator.py <config.json>", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]

    try:
        config = load_config(config_path)
        result = generate_matrix(config)
        print(json.dumps(result, indent=2, sort_keys=True))
    except (ValueError, FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
