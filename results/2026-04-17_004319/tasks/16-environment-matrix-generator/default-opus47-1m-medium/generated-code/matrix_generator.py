"""Generate a GitHub Actions strategy.matrix payload from a concise config.

Input (JSON on stdin):
    {
      "axes": { "os": [...], "python": [...], ... },
      "include": [ {...extra combos...} ],
      "exclude": [ {...combos to drop...} ],
      "max-parallel": 4,         # optional
      "fail-fast": false,        # optional, default true
      "max-size": 100            # optional soft cap (on top of GH's 256 limit)
    }

Output (JSON on stdout): a strategy block suitable for inlining into a
workflow. We emit the "full axes" shape (each axis as a list, with optional
include/exclude arrays) because that is what GitHub Actions natively consumes.

Validation:
  * At least one axis is required.
  * GitHub Actions caps the matrix at 256 jobs -- we enforce that unconditionally.
  * The user may provide a stricter ``max-size`` cap on top of that.
  * Exclude entries shrink the combination count; includes add to it.

Errors are raised as ``MatrixError`` and, from the CLI, printed to stderr with
a non-zero exit code.
"""
from __future__ import annotations

import json
import sys
from itertools import product
from typing import Any

GITHUB_ACTIONS_MAX_JOBS = 256


class MatrixError(ValueError):
    """Raised for any configuration or validation error."""


def _cartesian(axes: dict[str, list[Any]]) -> list[dict[str, Any]]:
    keys = list(axes.keys())
    combos: list[dict[str, Any]] = []
    for values in product(*[axes[k] for k in keys]):
        combos.append(dict(zip(keys, values)))
    return combos


def _combo_matches(combo: dict[str, Any], rule: dict[str, Any]) -> bool:
    """True if every key/value in ``rule`` is present and equal in ``combo``."""
    return all(combo.get(k) == v for k, v in rule.items())


def generate_matrix(config: dict[str, Any]) -> dict[str, Any]:
    """Return a strategy dict ready to serialize to JSON.

    The returned shape:
        {
          "fail-fast": bool,
          "max-parallel": int | absent,
          "matrix": {
              "<axis>": [...],     # one per axis key
              "include": [...],    # if provided
              "exclude": [...]     # if provided
          }
        }
    """
    axes = config.get("axes") or {}
    if not isinstance(axes, dict) or not axes:
        raise MatrixError("Config must define at least one axis under 'axes'.")

    for name, values in axes.items():
        if not isinstance(values, list) or not values:
            raise MatrixError(f"Axis '{name}' must be a non-empty list.")

    includes = config.get("include", []) or []
    excludes = config.get("exclude", []) or []
    if not isinstance(includes, list) or not isinstance(excludes, list):
        raise MatrixError("'include' and 'exclude' must be arrays if provided.")

    # Compute combo count for validation.
    base = _cartesian(axes)
    kept = [c for c in base if not any(_combo_matches(c, e) for e in excludes)]
    total = len(kept) + len(includes)

    max_size = config.get("max-size")
    if max_size is not None:
        if not isinstance(max_size, int) or max_size < 1:
            raise MatrixError("'max-size' must be a positive integer.")
        if total > max_size:
            raise MatrixError(
                f"Matrix has {total} jobs, which exceeds maximum size {max_size}."
            )

    if total > GITHUB_ACTIONS_MAX_JOBS:
        raise MatrixError(
            f"Matrix has {total} jobs, which exceeds GitHub Actions limit of "
            f"{GITHUB_ACTIONS_MAX_JOBS}."
        )

    matrix: dict[str, Any] = dict(axes)
    if includes:
        matrix["include"] = includes
    if excludes:
        matrix["exclude"] = excludes

    strategy: dict[str, Any] = {
        "fail-fast": bool(config.get("fail-fast", True)),
        "matrix": matrix,
    }

    if "max-parallel" in config:
        mp = config["max-parallel"]
        if not isinstance(mp, int) or mp < 1:
            raise MatrixError("'max-parallel' must be a positive integer.")
        strategy["max-parallel"] = mp

    return strategy


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    # Optional --input=<file> argument; otherwise read stdin.
    source = sys.stdin
    if argv and argv[0].startswith("--input="):
        path = argv[0].split("=", 1)[1]
        try:
            source = open(path, "r")
        except OSError as e:
            print(f"Error: cannot open input file: {e}", file=sys.stderr)
            return 2

    raw = source.read()
    try:
        config = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        return 2

    try:
        strategy = generate_matrix(config)
    except MatrixError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    print(json.dumps(strategy, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
