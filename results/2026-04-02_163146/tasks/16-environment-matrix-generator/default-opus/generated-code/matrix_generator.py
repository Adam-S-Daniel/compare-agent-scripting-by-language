"""
GitHub Actions Environment Matrix Generator

Generates a build matrix (JSON) suitable for GitHub Actions strategy.matrix.
Supports:
  - Cartesian product of arbitrary dimensions (OS, language versions, flags)
  - Include rules: add extra combinations or extend matching rows
  - Exclude rules: remove combinations matching all specified keys
  - max-parallel and fail-fast strategy configuration
  - Matrix size validation (default limit: 256, the GitHub Actions cap)

Usage:
  from matrix_generator import generate_matrix, MatrixConfig

  config = MatrixConfig(
      dimensions={"os": ["ubuntu-latest", "windows-latest"], "node": ["18", "20"]},
      include=[{"os": "ubuntu-latest", "node": "22", "experimental": True}],
      exclude=[{"os": "windows-latest", "node": "18"}],
      fail_fast=False,
      max_parallel=4,
  )
  result = generate_matrix(config)
  # result is a dict with "matrix", "fail-fast", and optionally "max-parallel"
"""

from __future__ import annotations

import json
import itertools
from dataclasses import dataclass, field
from typing import Any


class MatrixError(Exception):
    """Raised when matrix configuration is invalid or the matrix exceeds limits."""
    pass


@dataclass
class MatrixConfig:
    """Configuration for a GitHub Actions build matrix.

    Attributes:
        dimensions: Mapping of dimension name -> list of values.
                    The cartesian product of all dimensions forms the base matrix.
        include:    List of dicts to add or extend in the matrix.
        exclude:    List of dicts specifying combinations to remove.
        fail_fast:  Whether to cancel remaining jobs on first failure (default True).
        max_parallel: Maximum number of jobs to run in parallel (None = unlimited).
        max_size:   Maximum number of matrix combinations allowed (default 256).
    """
    dimensions: dict[str, list[Any]]
    include: list[dict[str, Any]] = field(default_factory=list)
    exclude: list[dict[str, Any]] = field(default_factory=list)
    fail_fast: bool = True
    max_parallel: int | None = None
    max_size: int = 256

    @classmethod
    def from_json(cls, json_str: str) -> MatrixConfig:
        """Create a MatrixConfig from a JSON string."""
        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            raise MatrixError(f"Invalid JSON configuration: {e}") from e

        if not isinstance(data, dict):
            raise MatrixError("Configuration must be a JSON object")

        return cls(
            dimensions=data.get("dimensions", {}),
            include=data.get("include", []),
            exclude=data.get("exclude", []),
            fail_fast=data.get("fail_fast", True),
            max_parallel=data.get("max_parallel"),
            max_size=data.get("max_size", 256),
        )


def _validate_config(config: MatrixConfig) -> None:
    """Validate the matrix configuration, raising MatrixError on problems."""

    # Dimensions must be a non-empty dict
    if not config.dimensions:
        raise MatrixError("At least one dimension is required")

    # Each dimension value must be a list
    for key, values in config.dimensions.items():
        if not isinstance(values, list):
            raise MatrixError(
                f"Dimension '{key}' values must be a list, got {type(values).__name__}"
            )

    # Include must be a list of dicts
    if not isinstance(config.include, list):
        raise MatrixError(
            f"'include' must be a list of dicts, got {type(config.include).__name__}"
        )
    for i, entry in enumerate(config.include):
        if not isinstance(entry, dict):
            raise MatrixError(f"'include[{i}]' must be a dict, got {type(entry).__name__}")

    # Exclude must be a list of dicts
    if not isinstance(config.exclude, list):
        raise MatrixError(
            f"'exclude' must be a list of dicts, got {type(config.exclude).__name__}"
        )
    for i, entry in enumerate(config.exclude):
        if not isinstance(entry, dict):
            raise MatrixError(f"'exclude[{i}]' must be a dict, got {type(entry).__name__}")

    # max_parallel must be positive if set
    if config.max_parallel is not None and config.max_parallel <= 0:
        raise MatrixError(
            f"max_parallel must be a positive integer, got {config.max_parallel}"
        )


def _build_cartesian_product(dimensions: dict[str, list[Any]]) -> list[dict[str, Any]]:
    """Build the cartesian product of all dimension values.

    Example: {"os": ["a", "b"], "node": ["18"]}
      -> [{"os": "a", "node": "18"}, {"os": "b", "node": "18"}]
    """
    if not dimensions:
        return []

    keys = list(dimensions.keys())
    value_lists = [dimensions[k] for k in keys]

    # If any dimension has zero values, the product is empty
    if any(len(v) == 0 for v in value_lists):
        return []

    return [dict(zip(keys, combo)) for combo in itertools.product(*value_lists)]


def _row_matches(row: dict[str, Any], pattern: dict[str, Any]) -> bool:
    """Check if a matrix row matches all keys in the pattern."""
    return all(key in row and row[key] == value for key, value in pattern.items())


def _apply_includes(
    matrix: list[dict[str, Any]], includes: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Apply include rules following GitHub Actions semantics:

    - If an include entry has keys that all match an existing row but also has
      extra keys, those extra keys are merged into the matching row(s).
    - If no existing row matches, the include entry is appended as a new row.
    """
    for inc in includes:
        # Separate keys that are dimension keys (present in existing rows)
        # from extra keys (new properties)
        matched = False

        if matrix:
            # Determine which keys in the include entry match existing dimension keys
            existing_keys = set()
            for row in matrix:
                existing_keys.update(row.keys())

            # Keys in include that are also existing matrix dimension keys
            matching_keys = {k: v for k, v in inc.items() if k in existing_keys}
            # Keys that are new (not in existing rows)
            extra_keys = {k: v for k, v in inc.items() if k not in existing_keys}

            if matching_keys and extra_keys:
                # Merge extra keys into matching rows
                for row in matrix:
                    if _row_matches(row, matching_keys):
                        row.update(extra_keys)
                        matched = True
            elif matching_keys and not extra_keys:
                # Check if any row already fully matches
                if any(_row_matches(row, matching_keys) for row in matrix):
                    matched = True

        if not matched:
            # No match found — append as a new combination
            matrix.append(dict(inc))

    return matrix


def _apply_excludes(
    matrix: list[dict[str, Any]], excludes: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Remove rows from the matrix that match ALL keys in any exclude pattern."""
    for exc in excludes:
        matrix = [row for row in matrix if not _row_matches(row, exc)]
    return matrix


def generate_matrix(config: MatrixConfig) -> dict[str, Any]:
    """Generate the complete strategy object for GitHub Actions.

    Returns a dict with:
      - "matrix": list of combination dicts
      - "fail-fast": boolean
      - "max-parallel": int (only if set)

    Raises MatrixError if the configuration is invalid or the resulting
    matrix exceeds max_size.
    """
    # Step 1: Validate input
    _validate_config(config)

    # Step 2: Build cartesian product from dimensions
    matrix = _build_cartesian_product(config.dimensions)

    # Step 3: Apply include rules (adds/extends rows)
    matrix = _apply_includes(matrix, config.include)

    # Step 4: Apply exclude rules (removes rows)
    matrix = _apply_excludes(matrix, config.exclude)

    # Step 5: Validate matrix size
    if len(matrix) > config.max_size:
        raise MatrixError(
            f"Matrix has {len(matrix)} combinations, which exceeds the "
            f"maximum allowed size of {config.max_size}. Reduce dimensions "
            f"or add exclude rules."
        )

    # Step 6: Build the output dict
    result: dict[str, Any] = {
        "matrix": matrix,
        "fail-fast": config.fail_fast,
    }

    if config.max_parallel is not None:
        result["max-parallel"] = config.max_parallel

    return result


# ---------------------------------------------------------------------------
# CLI entry point: read config from stdin or a file, output matrix JSON
# ---------------------------------------------------------------------------
def main() -> None:
    """CLI entry point: reads JSON config from stdin, outputs matrix JSON."""
    import sys

    if len(sys.argv) > 1:
        # Read from file
        try:
            with open(sys.argv[1], "r") as f:
                json_input = f.read()
        except FileNotFoundError:
            print(f"Error: File not found: {sys.argv[1]}", file=sys.stderr)
            sys.exit(1)
        except IOError as e:
            print(f"Error reading file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        # Read from stdin
        json_input = sys.stdin.read()

    try:
        config = MatrixConfig.from_json(json_input)
        result = generate_matrix(config)
        print(json.dumps(result, indent=2))
    except MatrixError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
