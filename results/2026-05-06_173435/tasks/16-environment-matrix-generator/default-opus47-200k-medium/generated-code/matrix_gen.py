"""Generate a GitHub Actions strategy.matrix from a config file.

Config schema (JSON or YAML, JSON only here for zero deps):

    {
      "axes": {              # required: at least one axis with >=1 value
        "os": ["ubuntu-latest", "windows-latest"],
        "python": ["3.11", "3.12"]
      },
      "include": [ {axis: value, ...} ],   # optional extra combos
      "exclude": [ {axis: value, ...} ],   # optional removals
      "max_parallel": 4,                   # optional int
      "fail_fast": false,                  # optional bool
      "max_size": 50                       # optional safety cap
    }

Output shape mirrors what GitHub Actions accepts under `strategy:`, plus a
computed `size` field used for max_size validation:

    {
      "matrix":      {axes..., "include": [...], "exclude": [...]},
      "max-parallel": int,        # only if provided
      "fail-fast":   bool,        # only if provided
      "size":        int
    }
"""
from __future__ import annotations

import argparse
import itertools
import json
import sys
from typing import Any


class MatrixError(ValueError):
    """Raised when the input config is invalid or the matrix is too large."""


def _matches(combo: dict, rule: dict) -> bool:
    """A rule matches a base combo if every key in the rule (that is also an
    axis key in the combo) equals the combo's value. Extra rule keys are
    treated as additions and ignored for matching purposes."""
    for k, v in rule.items():
        if k in combo and combo[k] != v:
            return False
    return True


def generate_matrix(config: dict[str, Any]) -> dict[str, Any]:
    axes = config.get("axes") or {}
    if not axes:
        raise MatrixError("config.axes must define at least one axis with values")
    for name, values in axes.items():
        if not isinstance(values, list) or not values:
            raise MatrixError(f"axis '{name}' must be a non-empty list")

    includes = config.get("include", []) or []
    excludes = config.get("exclude", []) or []

    # Build the base cartesian product so we can compute the post-exclude size.
    keys = list(axes.keys())
    base_combos = [dict(zip(keys, vals)) for vals in itertools.product(*axes.values())]

    kept = [c for c in base_combos if not any(_matches(c, e) for e in excludes)]
    size = len(kept) + len(includes)

    max_size = config.get("max_size")
    if max_size is not None and size > max_size:
        raise MatrixError(
            f"matrix size {size} exceeds max_size {max_size} "
            f"(base={len(base_combos)}, kept={len(kept)}, include={len(includes)})"
        )

    matrix: dict[str, Any] = {k: list(v) for k, v in axes.items()}
    if includes:
        matrix["include"] = includes
    if excludes:
        matrix["exclude"] = excludes

    out: dict[str, Any] = {"matrix": matrix, "size": size}
    if "max_parallel" in config:
        mp = config["max_parallel"]
        if not isinstance(mp, int) or mp < 1:
            raise MatrixError("max_parallel must be a positive integer")
        out["max-parallel"] = mp
    if "fail_fast" in config:
        ff = config["fail_fast"]
        if not isinstance(ff, bool):
            raise MatrixError("fail_fast must be a boolean")
        out["fail-fast"] = ff
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate a GitHub Actions strategy.matrix JSON.")
    parser.add_argument("config", help="Path to config JSON file (or '-' for stdin).")
    parser.add_argument("-o", "--output", help="Write matrix JSON here (default stdout).")
    args = parser.parse_args(argv)

    try:
        if args.config == "-":
            raw = sys.stdin.read()
        else:
            with open(args.config) as f:
                raw = f.read()
        config = json.loads(raw)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: failed to read config: {e}", file=sys.stderr)
        return 2

    try:
        result = generate_matrix(config)
    except MatrixError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    payload = json.dumps(result, indent=2, sort_keys=True)
    if args.output:
        with open(args.output, "w") as f:
            f.write(payload + "\n")
    print(payload)
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
