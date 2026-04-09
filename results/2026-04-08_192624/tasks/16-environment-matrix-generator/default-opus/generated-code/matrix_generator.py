#!/usr/bin/env python3
"""
Environment Matrix Generator for GitHub Actions.

Takes a JSON configuration describing OS options, language versions, feature flags,
include/exclude rules, max-parallel limits, and fail-fast settings, then produces
a complete strategy.matrix JSON suitable for GitHub Actions.

Usage:
    python3 matrix_generator.py <config.json>
    python3 matrix_generator.py --config-stdin  (reads JSON from stdin)
"""

import json
import sys
import itertools
from typing import Any


# GitHub Actions enforces a max matrix size of 256 combinations
DEFAULT_MAX_MATRIX_SIZE = 256


def load_config(path: str) -> dict:
    """Load and validate a matrix configuration file."""
    try:
        with open(path, "r") as f:
            config = json.load(f)
    except FileNotFoundError:
        raise SystemExit(f"Error: Config file not found: {path}")
    except json.JSONDecodeError as e:
        raise SystemExit(f"Error: Invalid JSON in config file: {e}")
    return config


def validate_config(config: dict) -> None:
    """Validate the structure of the matrix configuration."""
    if not isinstance(config, dict):
        raise ValueError("Config must be a JSON object")

    if "matrix" not in config:
        raise ValueError("Config must contain a 'matrix' key with dimension definitions")

    matrix = config["matrix"]
    if not isinstance(matrix, dict):
        raise ValueError("'matrix' must be a JSON object mapping dimension names to value arrays")

    # Each dimension value must be a list
    for key, values in matrix.items():
        if key in ("include", "exclude"):
            continue
        if not isinstance(values, list):
            raise ValueError(f"Matrix dimension '{key}' must be an array, got {type(values).__name__}")
        if len(values) == 0:
            raise ValueError(f"Matrix dimension '{key}' must have at least one value")

    # Validate include/exclude are lists of dicts
    for rule_key in ("include", "exclude"):
        if rule_key in matrix:
            rules = matrix[rule_key]
            if not isinstance(rules, list):
                raise ValueError(f"'{rule_key}' must be an array of objects")
            for i, rule in enumerate(rules):
                if not isinstance(rule, dict):
                    raise ValueError(f"'{rule_key}[{i}]' must be a JSON object")

    # Validate max_parallel if present
    if "max_parallel" in config:
        mp = config["max_parallel"]
        if not isinstance(mp, int) or mp < 1:
            raise ValueError("'max_parallel' must be a positive integer")

    # Validate fail_fast if present
    if "fail_fast" in config:
        if not isinstance(config["fail_fast"], bool):
            raise ValueError("'fail_fast' must be a boolean")

    # Validate max_matrix_size if present
    if "max_matrix_size" in config:
        ms = config["max_matrix_size"]
        if not isinstance(ms, int) or ms < 1:
            raise ValueError("'max_matrix_size' must be a positive integer")


def generate_cartesian_product(dimensions: dict) -> list[dict]:
    """Generate the cartesian product of all matrix dimensions."""
    # Filter out include/exclude from dimensions
    dim_keys = [k for k in dimensions if k not in ("include", "exclude")]

    if not dim_keys:
        return []

    dim_values = [dimensions[k] for k in dim_keys]
    combinations = list(itertools.product(*dim_values))

    return [dict(zip(dim_keys, combo)) for combo in combinations]


def apply_excludes(combinations: list[dict], excludes: list[dict]) -> list[dict]:
    """Remove combinations that match any exclude rule.

    A combination matches an exclude rule if all key-value pairs in the
    exclude rule are present in the combination.
    """
    result = []
    for combo in combinations:
        excluded = False
        for rule in excludes:
            if all(combo.get(k) == v for k, v in rule.items()):
                excluded = True
                break
        if not excluded:
            result.append(combo)
    return result


def apply_includes(combinations: list[dict], includes: list[dict],
                   dim_keys: list[str]) -> list[dict]:
    """Apply include rules to the combination list.

    GitHub Actions include semantics:
    - If an include entry matches an existing combination on all shared
      dimension keys, extra properties are merged into that combination.
    - If an include entry does NOT match any existing combination, it is
      appended as a new entry.
    """
    result = [dict(c) for c in combinations]  # deep copy

    for inc in includes:
        # Find keys in the include that overlap with matrix dimensions
        shared_keys = [k for k in inc if k in dim_keys]
        extra_keys = [k for k in inc if k not in dim_keys]

        matched = False
        for combo in result:
            if all(combo.get(k) == inc[k] for k in shared_keys):
                # Merge extra keys into the matching combination
                for ek in extra_keys:
                    combo[ek] = inc[ek]
                matched = True

        if not matched:
            # Append as a new combination
            result.append(dict(inc))

    return result


def generate_matrix(config: dict) -> dict[str, Any]:
    """Generate the complete GitHub Actions strategy configuration.

    Returns a dict with 'matrix', and optionally 'max-parallel' and 'fail-fast'.
    """
    validate_config(config)

    matrix_def = config["matrix"]
    max_size = config.get("max_matrix_size", DEFAULT_MAX_MATRIX_SIZE)

    # Separate dimensions from include/exclude
    dim_keys = [k for k in matrix_def if k not in ("include", "exclude")]
    excludes = matrix_def.get("exclude", [])
    includes = matrix_def.get("include", [])

    # Step 1: Generate cartesian product
    combinations = generate_cartesian_product(matrix_def)

    # Step 2: Apply exclude rules
    if excludes:
        combinations = apply_excludes(combinations, excludes)

    # Step 3: Apply include rules
    if includes:
        combinations = apply_includes(combinations, includes, dim_keys)

    # Step 4: Validate size
    if len(combinations) > max_size:
        raise ValueError(
            f"Matrix size {len(combinations)} exceeds maximum allowed {max_size}. "
            f"Use exclude rules or reduce dimensions to stay within limits."
        )

    # Build the output strategy object
    # The matrix output mirrors GitHub Actions format: dimension arrays + include/exclude
    output_matrix = {}
    for k in dim_keys:
        output_matrix[k] = matrix_def[k]
    if excludes:
        output_matrix["exclude"] = excludes
    if includes:
        output_matrix["include"] = includes

    strategy: dict[str, Any] = {"matrix": output_matrix}

    if "fail_fast" in config:
        strategy["fail-fast"] = config["fail_fast"]
    if "max_parallel" in config:
        strategy["max-parallel"] = config["max_parallel"]

    # Also output the expanded combinations for visibility
    result = {
        "strategy": strategy,
        "expanded_combinations": combinations,
        "total_combinations": len(combinations),
    }

    return result


def main():
    """Entry point: read config, generate matrix, print JSON."""
    if len(sys.argv) < 2:
        print("Usage: python3 matrix_generator.py <config.json>", file=sys.stderr)
        print("       python3 matrix_generator.py --config-stdin", file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == "--config-stdin":
        try:
            config = json.load(sys.stdin)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON from stdin: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        config = load_config(sys.argv[1])

    try:
        result = generate_matrix(config)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print(json.dumps(result, indent=2, sort_keys=False))


if __name__ == "__main__":
    main()
