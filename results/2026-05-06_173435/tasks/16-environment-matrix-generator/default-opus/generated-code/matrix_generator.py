#!/usr/bin/env python3
"""Environment Matrix Generator for GitHub Actions.

Generates a build matrix JSON suitable for GitHub Actions strategy.matrix.
Supports include/exclude rules, max-parallel limits, fail-fast, and
validates that the matrix doesn't exceed a configurable maximum size.
"""

import json
import sys
import itertools

DEFAULT_MAX_COMBINATIONS = 256
DEFAULT_FAIL_FAST = False


def validate_config(config: dict) -> None:
    """Validate the matrix configuration structure."""
    if not isinstance(config, dict):
        raise ValueError("Configuration must be a JSON object")

    if "matrix" not in config:
        raise ValueError("Configuration must contain a 'matrix' key with dimension definitions")

    matrix = config["matrix"]
    if not isinstance(matrix, dict):
        raise ValueError("'matrix' must be a JSON object mapping dimension names to value arrays")

    if not matrix:
        raise ValueError("'matrix' must contain at least one dimension")

    for key, values in matrix.items():
        if not isinstance(values, list):
            raise ValueError(f"Dimension '{key}' must be an array of values, got {type(values).__name__}")
        if not values:
            raise ValueError(f"Dimension '{key}' must have at least one value")

    for rule_key in ("include", "exclude"):
        if rule_key in config:
            rules = config[rule_key]
            if not isinstance(rules, list):
                raise ValueError(f"'{rule_key}' must be an array of objects")
            for i, rule in enumerate(rules):
                if not isinstance(rule, dict):
                    raise ValueError(f"'{rule_key}[{i}]' must be a JSON object")

    if "max-parallel" in config:
        mp = config["max-parallel"]
        if not isinstance(mp, int) or mp < 1:
            raise ValueError("'max-parallel' must be a positive integer")

    if "max-combinations" in config:
        mc = config["max-combinations"]
        if not isinstance(mc, int) or mc < 1:
            raise ValueError("'max-combinations' must be a positive integer")


def compute_cross_product(matrix: dict) -> list[dict]:
    """Compute the Cartesian product of all matrix dimensions."""
    keys = sorted(matrix.keys())
    values = [matrix[k] for k in keys]
    return [dict(zip(keys, combo)) for combo in itertools.product(*values)]


def matches_rule(combination: dict, rule: dict) -> bool:
    """Check if a combination matches all key-value pairs in a rule."""
    return all(combination.get(k) == v for k, v in rule.items())


def apply_excludes(combinations: list[dict], excludes: list[dict]) -> list[dict]:
    """Remove combinations matching any exclude rule."""
    return [c for c in combinations
            if not any(matches_rule(c, rule) for rule in excludes)]


def apply_includes(combinations: list[dict], includes: list[dict], matrix_keys: set) -> list[dict]:
    """Apply include rules following GitHub Actions semantics.

    If an include specifies only existing matrix keys, it adds a new combination
    (if not already present). If it specifies new keys, those are merged into
    matching existing combinations; if nothing matches, a new combination is added.
    """
    result = [dict(c) for c in combinations]

    for include in includes:
        existing_keys = {k: v for k, v in include.items() if k in matrix_keys}
        extra_keys = {k: v for k, v in include.items() if k not in matrix_keys}

        if extra_keys:
            matched = False
            for combo in result:
                if matches_rule(combo, existing_keys):
                    combo.update(extra_keys)
                    matched = True
            if not matched:
                result.append(dict(include))
        else:
            already_exists = any(
                all(combo.get(k) == v for k, v in include.items())
                for combo in result
            )
            if not already_exists:
                result.append(dict(include))

    return result


def count_effective_combinations(config: dict) -> int:
    """Count effective combinations after applying include/exclude rules."""
    matrix = config["matrix"]
    combinations = compute_cross_product(matrix)

    excludes = config.get("exclude", [])
    if excludes:
        combinations = apply_excludes(combinations, excludes)

    includes = config.get("include", [])
    if includes:
        combinations = apply_includes(combinations, includes, set(matrix.keys()))

    return len(combinations)


def generate_matrix(config: dict) -> dict:
    """Generate the complete strategy configuration for GitHub Actions.

    Returns a dict with matrix, fail-fast, max-parallel, and total_combinations.
    Raises ValueError if the matrix exceeds max-combinations.
    """
    validate_config(config)

    max_combinations = config.get("max-combinations", DEFAULT_MAX_COMBINATIONS)
    total = count_effective_combinations(config)

    if total > max_combinations:
        raise ValueError(
            f"Matrix produces {total} combinations, exceeding the maximum of "
            f"{max_combinations}. Add exclude rules or reduce dimension values."
        )

    output_matrix = {}
    for key, values in sorted(config["matrix"].items()):
        output_matrix[key] = list(values)

    if config.get("include"):
        output_matrix["include"] = config["include"]

    if config.get("exclude"):
        output_matrix["exclude"] = config["exclude"]

    strategy = {
        "matrix": output_matrix,
        "fail-fast": config.get("fail-fast", DEFAULT_FAIL_FAST),
        "total_combinations": total,
    }

    if "max-parallel" in config:
        strategy["max-parallel"] = config["max-parallel"]

    return strategy


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 matrix_generator.py <config.json>", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]

    try:
        with open(config_path) as f:
            config = json.load(f)
        result = generate_matrix(config)
        print(json.dumps(result, indent=2, sort_keys=True))
    except FileNotFoundError:
        print(f"Error: Config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
