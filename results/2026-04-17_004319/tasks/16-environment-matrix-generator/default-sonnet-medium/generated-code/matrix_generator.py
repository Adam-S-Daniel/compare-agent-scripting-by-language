"""
Environment Matrix Generator for GitHub Actions strategy.matrix.

Generates a build matrix from a configuration describing OS options,
language versions, and feature flags. Supports include/exclude rules,
max-parallel limits, fail-fast configuration, and matrix size validation.
"""
import json
import sys
import itertools
from pathlib import Path
from typing import Any


# Reserved keys that control strategy behavior, not matrix dimensions
_STRATEGY_KEYS = {"max-parallel", "fail-fast", "include", "exclude"}


class MatrixSizeError(ValueError):
    """Raised when the generated matrix exceeds the allowed maximum size."""


def _cartesian_product(dimensions: dict[str, list]) -> list[dict]:
    """Compute Cartesian product of all dimension lists."""
    if not dimensions:
        return []
    keys = list(dimensions.keys())
    values = [dimensions[k] for k in keys]
    return [dict(zip(keys, combo)) for combo in itertools.product(*values)]


def _combo_matches_rule(combo: dict, rule: dict) -> bool:
    """Return True if combo matches ALL key-value pairs in rule (subset match)."""
    return all(combo.get(k) == v for k, v in rule.items())


def generate_matrix(config: dict[str, Any], max_size: int = 256) -> dict[str, Any]:
    """
    Generate a GitHub Actions build matrix from config.

    Args:
        config: Dict with dimension keys (lists of values), plus optional
                'include', 'exclude', 'max-parallel', 'fail-fast'.
        max_size: Maximum number of matrix entries (default 256, GitHub's limit).

    Returns:
        Dict suitable for use as a GitHub Actions strategy block:
        {
            "matrix": {"include": [...]},
            "max-parallel": N,   # only if specified
            "fail-fast": bool,   # only if specified
        }

    Raises:
        MatrixSizeError: If the generated matrix exceeds max_size.
    """
    # Separate dimension keys from strategy/rule keys
    dimensions = {k: v for k, v in config.items() if k not in _STRATEGY_KEYS}
    exclude_rules = config.get("exclude", [])
    extra_includes = config.get("include", [])

    # Generate base Cartesian product
    combos = _cartesian_product(dimensions)

    # Apply exclude rules (remove combos matching any exclude entry)
    if exclude_rules:
        combos = [
            c for c in combos
            if not any(_combo_matches_rule(c, rule) for rule in exclude_rules)
        ]

    # Append explicit include entries
    combos.extend(extra_includes)

    # Validate size
    if len(combos) > max_size:
        raise MatrixSizeError(
            f"Matrix size {len(combos)} exceeds maximum allowed size of {max_size}. "
            "Reduce dimensions, add exclude rules, or increase max_size."
        )

    result: dict[str, Any] = {"matrix": {"include": combos}}

    # Propagate strategy options only when explicitly set
    if "max-parallel" in config:
        result["max-parallel"] = config["max-parallel"]
    if "fail-fast" in config:
        result["fail-fast"] = config["fail-fast"]

    return result


def generate_matrix_json(config: dict[str, Any], max_size: int = 256, indent: int = 2) -> str:
    """Return generate_matrix result as a JSON string."""
    return json.dumps(generate_matrix(config, max_size=max_size), indent=indent)


def main():
    """CLI entry point: read config JSON from file, write matrix JSON to stdout."""
    if len(sys.argv) < 2:
        print("Usage: matrix_generator.py <config.json> [--max-size N]", file=sys.stderr)
        sys.exit(1)

    config_path = Path(sys.argv[1])
    if not config_path.exists():
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    # Parse optional --max-size flag
    max_size = 256
    args = sys.argv[2:]
    if "--max-size" in args:
        idx = args.index("--max-size")
        try:
            max_size = int(args[idx + 1])
        except (IndexError, ValueError):
            print("Error: --max-size requires an integer argument", file=sys.stderr)
            sys.exit(1)

    try:
        config = json.loads(config_path.read_text())
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in config file: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        print(generate_matrix_json(config, max_size=max_size))
    except MatrixSizeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
