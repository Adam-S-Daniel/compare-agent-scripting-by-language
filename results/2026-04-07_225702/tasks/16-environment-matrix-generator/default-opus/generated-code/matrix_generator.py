"""
Environment matrix generator for GitHub Actions strategy.matrix.

Generates a build matrix (JSON) from a configuration of dimensions (OS options,
language versions, feature flags), with support for include/exclude rules,
max-parallel limits, fail-fast, and matrix size validation.
"""

from __future__ import annotations

import json
import sys
import itertools
from dataclasses import dataclass, field
from typing import Any


class MatrixError(Exception):
    """Raised when matrix configuration is invalid or exceeds constraints."""


@dataclass
class MatrixConfig:
    """Configuration for generating a GitHub Actions build matrix."""
    dimensions: dict[str, list[Any]] = field(default_factory=dict)
    include: list[dict[str, Any]] = field(default_factory=list)
    exclude: list[dict[str, Any]] = field(default_factory=list)
    fail_fast: bool | None = None
    max_parallel: int | None = None
    max_combinations: int = 256  # GitHub Actions default limit


def _count_cartesian_size(dimensions: dict[str, list[Any]]) -> int:
    """Count the total cartesian product size from dimensions."""
    if not dimensions:
        return 0
    size = 1
    for values in dimensions.values():
        size *= len(values)
    return size


def _count_excluded(dimensions: dict[str, list[Any]], excludes: list[dict[str, Any]]) -> int:
    """Count how many combos from the cartesian product each exclude rule removes.

    An exclude rule matches all combos where the specified keys have the specified
    values. For keys not mentioned in the exclude, all values match.
    """
    if not dimensions or not excludes:
        return 0

    dim_keys = list(dimensions.keys())
    total_excluded = 0

    for exc in excludes:
        # For each exclude rule, figure out how many combos it removes.
        # For each dimension key: if the key is in the exclude, it matches 1 value;
        # otherwise it matches all values in that dimension.
        matched = 1
        for key in dim_keys:
            if key in exc:
                # Only removes combos where this key equals the excluded value
                if exc[key] in dimensions[key]:
                    matched *= 1
                else:
                    # The excluded value isn't even in the dimension, so 0 matches
                    matched = 0
                    break
            else:
                matched *= len(dimensions[key])
        total_excluded += matched

    return total_excluded


def _validate_config(config: MatrixConfig) -> None:
    """Run all validations on the config before generating the matrix."""
    if not config.dimensions and not config.include:
        raise MatrixError("At least one dimension or include entry is required")

    for dim_name, dim_values in config.dimensions.items():
        if not dim_values:
            raise MatrixError(f"Dimension '{dim_name}' must have at least one value")
        if len(dim_values) != len(set(str(v) for v in dim_values)):
            raise MatrixError(f"Dimension '{dim_name}' has duplicate values")

    if config.max_parallel is not None and config.max_parallel < 1:
        raise MatrixError("max_parallel must be a positive integer")


def _validate_matrix_size(config: MatrixConfig) -> None:
    """Validate the effective matrix size doesn't exceed the maximum."""
    base_size = _count_cartesian_size(config.dimensions)
    excluded = _count_excluded(config.dimensions, config.exclude)
    # Include entries that introduce entirely new combos (not augmenting existing)
    extra_includes = len(config.include)
    effective = base_size - excluded + extra_includes

    if effective > config.max_combinations:
        raise MatrixError(
            f"Matrix has {effective} combinations exceeds maximum of "
            f"{config.max_combinations}"
        )


def generate_matrix(config: MatrixConfig) -> dict[str, Any]:
    """Generate a GitHub Actions strategy.matrix object from config."""
    _validate_config(config)

    # Build the matrix section
    matrix: dict[str, Any] = {}
    for dim_name, dim_values in config.dimensions.items():
        matrix[dim_name] = dim_values

    # Add include entries — these add extra combos or augment existing ones
    if config.include:
        matrix["include"] = config.include

    # Add exclude entries — these remove matching combos from the product
    if config.exclude:
        matrix["exclude"] = config.exclude

    # Validate matrix size doesn't exceed the limit
    _validate_matrix_size(config)

    result: dict[str, Any] = {"matrix": matrix}

    # Strategy-level options (siblings of matrix, not inside it)
    if config.fail_fast is not None:
        result["fail-fast"] = config.fail_fast
    if config.max_parallel is not None:
        result["max-parallel"] = config.max_parallel

    return result


def matrix_to_json(config: MatrixConfig, indent: int = 2) -> str:
    """Generate matrix and return as formatted JSON string."""
    return json.dumps(generate_matrix(config), indent=indent)


def load_config_from_dict(data: dict[str, Any]) -> MatrixConfig:
    """Create a MatrixConfig from a plain dictionary (e.g. parsed from JSON/YAML)."""
    return MatrixConfig(
        dimensions=data.get("dimensions", {}),
        include=data.get("include", []),
        exclude=data.get("exclude", []),
        fail_fast=data.get("fail_fast"),
        max_parallel=data.get("max_parallel"),
        max_combinations=data.get("max_combinations", 256),
    )


def _matches_exclude(combo: dict[str, Any], exclude: dict[str, Any]) -> bool:
    """Check if a combination matches an exclude rule (all specified keys must match)."""
    return all(combo.get(k) == v for k, v in exclude.items())


def expand_combinations(config: MatrixConfig) -> list[dict[str, Any]]:
    """Enumerate all concrete job combinations after applying include/exclude rules.

    This is useful for debugging or inspecting what the matrix will actually run.
    """
    combos: list[dict[str, Any]] = []

    # Generate cartesian product of all dimensions
    if config.dimensions:
        keys = list(config.dimensions.keys())
        for values in itertools.product(*config.dimensions.values()):
            combos.append(dict(zip(keys, values)))

    # Remove excluded combinations
    if config.exclude:
        combos = [
            c for c in combos
            if not any(_matches_exclude(c, exc) for exc in config.exclude)
        ]

    # Add include entries as extra combinations
    combos.extend(config.include)

    return combos


def main() -> None:
    """CLI entry point: reads a JSON config from stdin or a file argument,
    generates the matrix, and prints the complete JSON to stdout."""
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
        try:
            with open(filepath) as f:
                raw = json.load(f)
        except FileNotFoundError:
            print(f"Error: file not found: {filepath}", file=sys.stderr)
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: invalid JSON in {filepath}: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        try:
            raw = json.load(sys.stdin)
        except json.JSONDecodeError as e:
            print(f"Error: invalid JSON from stdin: {e}", file=sys.stderr)
            sys.exit(1)

    try:
        config = load_config_from_dict(raw)
        print(matrix_to_json(config))
    except MatrixError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
