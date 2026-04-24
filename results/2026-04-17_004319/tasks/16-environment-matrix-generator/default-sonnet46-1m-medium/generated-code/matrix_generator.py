# matrix_generator.py — generates GitHub Actions strategy.matrix JSON from config
import json
import sys
from typing import Any

DEFAULT_MAX_SIZE = 256


class MatrixSizeError(Exception):
    """Raised when generated matrix exceeds the configured maximum size."""


def compute_base_size(matrix_dims: dict[str, list]) -> int:
    """Return the Cartesian product count of all list-valued dimensions."""
    result = 1
    found = False
    for v in matrix_dims.values():
        if isinstance(v, list):
            result *= len(v)
            found = True
    return result if found else 0


def validate_config(config: dict) -> None:
    """Raise ValueError with a meaningful message for invalid configs."""
    os_val = config.get("os")
    if os_val is None:
        raise ValueError("Config must include 'os' key")
    if not isinstance(os_val, list):
        raise ValueError("'os' must be a list of OS strings")
    if len(os_val) == 0:
        raise ValueError("'os' must not be empty")

    if "max_parallel" in config:
        mp = config["max_parallel"]
        if not isinstance(mp, int) or mp < 1:
            raise ValueError("'max_parallel' must be a positive integer")

    if "max_size" in config:
        ms = config["max_size"]
        if not isinstance(ms, int) or ms < 1:
            raise ValueError("'max_size' must be a positive integer")


def generate_matrix(config: dict) -> dict:
    """Generate GitHub Actions strategy object from a config dict.

    Config keys:
      os               — list of OS strings (required)
      language_versions— dict mapping dimension name -> list of version strings
      feature_flags    — dict mapping flag name -> list of values (optional)
      include          — list of extra combination dicts (optional)
      exclude          — list of combination dicts to remove (optional)
      fail_fast        — bool (default True)
      max_parallel     — int (optional)
      max_size         — int max Cartesian-product size (default 256)

    Returns the top-level strategy object (fail-fast, max-parallel, matrix).
    Raises MatrixSizeError if base Cartesian product exceeds max_size.
    """
    validate_config(config)

    max_size: int = config.get("max_size", DEFAULT_MAX_SIZE)

    # Build the matrix dimensions dict
    matrix: dict[str, Any] = {"os": config["os"]}

    for dim, versions in config.get("language_versions", {}).items():
        matrix[dim] = versions

    for flag, values in config.get("feature_flags", {}).items():
        matrix[flag] = values

    # Validate size before optional include/exclude which may not grow base
    base_size = compute_base_size(matrix)
    if base_size > max_size:
        total = base_size
        raise MatrixSizeError(
            f"Matrix size {total} exceeds maximum allowed size of {max_size}. "
            f"Reduce dimensions or increase max_size."
        )

    if "include" in config:
        matrix["include"] = config["include"]
    if "exclude" in config:
        matrix["exclude"] = config["exclude"]

    # Build top-level strategy object
    strategy: dict[str, Any] = {
        "fail-fast": config.get("fail_fast", True),
        "matrix": matrix,
    }

    if "max_parallel" in config:
        strategy["max-parallel"] = config["max_parallel"]

    return strategy


def main(argv: list[str] | None = None) -> int:
    """CLI entry point. Reads a JSON config file and prints the matrix JSON."""
    args = sys.argv[1:] if argv is None else argv

    if len(args) != 1:
        print(f"Usage: {sys.argv[0]} <config.json>", file=sys.stderr)
        return 1

    config_path = args[0]
    try:
        with open(config_path) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in config file: {exc}", file=sys.stderr)
        return 1

    try:
        strategy = generate_matrix(config)
    except (ValueError, MatrixSizeError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(strategy, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
