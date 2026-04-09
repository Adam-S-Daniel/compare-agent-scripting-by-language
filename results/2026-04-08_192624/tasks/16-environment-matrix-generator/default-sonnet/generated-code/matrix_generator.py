#!/usr/bin/env python3
"""
Generate GitHub Actions strategy.matrix configuration from a high-level config.

Usage:
    python matrix_generator.py <config.json>

The config JSON supports:
    os               – list of runner OS strings
    language_versions – dict: language name -> list of version strings
                        (each language becomes a "<lang>-version" matrix key)
    feature_flags    – dict: flag name -> list of values (any type)
    include          – list of extra matrix-entry dicts (forwarded verbatim)
    exclude          – list of exclusion-rule dicts (forwarded verbatim)
    max_parallel     – int: strategy.max-parallel
    fail_fast        – bool: strategy.fail-fast (default: true)
    max_size         – int: maximum allowed Cartesian-product size (default: 256)

Output (stdout):
    MATRIX_OUTPUT_BEGIN
    { ... JSON ... }
    MATRIX_OUTPUT_END
"""

import json
import sys
from typing import Any


class MatrixTooLargeError(ValueError):
    """Raised when the matrix Cartesian product exceeds the configured maximum."""
    pass


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def calculate_matrix_size(dimensions: dict[str, list]) -> int:
    """Return the total number of Cartesian-product combinations.

    Each key in *dimensions* is one axis; the size is the product of axis lengths.
    Returns 0 for an empty dict.
    """
    if not dimensions:
        return 0
    size = 1
    for values in dimensions.values():
        size *= len(values)
    return size


def generate_matrix(config: dict[str, Any]) -> dict[str, Any]:
    """Generate a GitHub Actions strategy block from *config*.

    Args:
        config: See module docstring for supported keys.

    Returns:
        Dict with a single ``strategy`` key containing ``matrix``,
        optionally ``max-parallel``, and always ``fail-fast``.

    Raises:
        MatrixTooLargeError: If the matrix exceeds *max_size*.
    """
    max_size: int = config.get("max_size", 256)

    # ---- Build matrix dimensions ----------------------------------------
    dimensions: dict[str, list] = {}

    # OS axis
    os_list = config.get("os") or []
    if os_list:
        dimensions["os"] = os_list

    # Language-version axes: "python" -> "python-version", etc.
    for lang, versions in config.get("language_versions", {}).items():
        if versions:
            dimensions[f"{lang}-version"] = versions

    # Feature-flag axes (key used verbatim)
    for flag, values in config.get("feature_flags", {}).items():
        if values:
            dimensions[flag] = values

    # ---- Validate size ---------------------------------------------------
    size = calculate_matrix_size(dimensions)
    if size > max_size:
        raise MatrixTooLargeError(
            f"Matrix size {size} exceeds maximum allowed size {max_size}. "
            f"Reduce the number of OS options, language versions, or feature flags."
        )

    # ---- Assemble matrix dict -------------------------------------------
    matrix: dict[str, Any] = dict(dimensions)

    include_rules: list = config.get("include") or []
    if include_rules:
        matrix["include"] = include_rules

    exclude_rules: list = config.get("exclude") or []
    if exclude_rules:
        matrix["exclude"] = exclude_rules

    # ---- Build strategy object ------------------------------------------
    strategy: dict[str, Any] = {"matrix": matrix}

    if "max_parallel" in config:
        strategy["max-parallel"] = config["max_parallel"]

    # GitHub Actions default for fail-fast is true; honour that default.
    strategy["fail-fast"] = config.get("fail_fast", True)

    return {"strategy": strategy}


# ---------------------------------------------------------------------------
# File I/O helper
# ---------------------------------------------------------------------------

def load_config(path: str) -> dict[str, Any]:
    """Load and parse a JSON configuration file.

    Raises:
        FileNotFoundError: If the file does not exist.
        ValueError: If the file contains invalid JSON.
    """
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        raise FileNotFoundError(f"Configuration file not found: {path}")
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in configuration file '{path}': {exc}")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python matrix_generator.py <config.json>", file=sys.stderr)
        print("", file=sys.stderr)
        print("  Generates a GitHub Actions strategy.matrix from a JSON config.", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    try:
        config = load_config(config_path)
        result = generate_matrix(config)
        # Emit delimited output so CI scripts can reliably extract the JSON.
        print("MATRIX_OUTPUT_BEGIN")
        print(json.dumps(result, indent=2))
        print("MATRIX_OUTPUT_END")
    except MatrixTooLargeError as exc:
        print(f"ERROR: Matrix too large - {exc}", file=sys.stderr)
        sys.exit(2)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
