"""Environment matrix generator for GitHub Actions strategy.matrix.

Approach:
- Accept a configuration with `axes` (os, language versions), optional `features`
  (merged into axes), `include`/`exclude` rules, `max-parallel`, `fail-fast`,
  and `max-size`.
- Compute the effective matrix size by expanding the Cartesian product of axes,
  subtracting excluded combinations that actually match, and adding includes
  that introduce new combinations (GitHub Actions include semantics).
- Validate against `max-size`; raise a `MatrixError` with a clear message.
- Emit a JSON-serializable dict shaped for direct use as `strategy.matrix`
  plus `max-parallel`, `fail-fast`, and a `size` field for diagnostics.
"""
from __future__ import annotations

import itertools
import json
import sys
from typing import Any


class MatrixError(ValueError):
    """Raised when the matrix config is invalid or violates constraints."""


def _cartesian(axes: dict[str, list[Any]]) -> list[dict[str, Any]]:
    keys = list(axes.keys())
    values = [axes[k] for k in keys]
    return [dict(zip(keys, combo)) for combo in itertools.product(*values)]


def _matches_exclude(combo: dict[str, Any], rule: dict[str, Any]) -> bool:
    # GHA semantics: an exclude rule matches if every key present in the rule
    # also matches the combination's value for that key.
    return all(k in combo and combo[k] == v for k, v in rule.items())


def generate_matrix(config: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(config, dict):
        raise MatrixError("config must be an object")

    axes = dict(config.get("axes") or {})
    features = config.get("features") or {}
    if not isinstance(features, dict):
        raise MatrixError("'features' must be an object mapping flag -> values")
    # Feature flags are just extra axes.
    for k, v in features.items():
        if k in axes:
            raise MatrixError(f"feature '{k}' collides with existing axis")
        axes[k] = v

    if not axes:
        raise MatrixError("config must define non-empty 'axes' (or 'features')")

    for k, v in axes.items():
        if not isinstance(v, list) or len(v) == 0:
            raise MatrixError(f"axis '{k}' must be a non-empty list")

    includes = config.get("include") or []
    excludes = config.get("exclude") or []
    if not isinstance(includes, list) or not isinstance(excludes, list):
        raise MatrixError("'include' and 'exclude' must be lists")

    # Compute effective size: cartesian - matching excludes + net new includes.
    combos = _cartesian(axes)
    kept = [c for c in combos if not any(_matches_exclude(c, e) for e in excludes)]

    # An include is "new" if it doesn't match any kept combination's axis values.
    # (GHA's real include logic is more nuanced, but for size accounting this
    #  is a reasonable approximation.)
    def is_new_include(inc: dict[str, Any]) -> bool:
        for c in kept:
            if all(c.get(k) == v for k, v in inc.items() if k in axes):
                return False
        return True

    new_includes = [i for i in includes if is_new_include(i)]
    size = len(kept) + len(new_includes)

    max_size = config.get("max-size")
    if max_size is not None and size > max_size:
        raise MatrixError(
            f"matrix size {size} exceeds max-size {max_size}; "
            f"reduce axes, add excludes, or raise max-size"
        )

    matrix: dict[str, Any] = {k: list(v) for k, v in axes.items()}
    if includes:
        matrix["include"] = list(includes)
    if excludes:
        matrix["exclude"] = list(excludes)

    result: dict[str, Any] = {
        "matrix": matrix,
        "fail-fast": bool(config.get("fail-fast", True)),
        "size": size,
    }
    mp = config.get("max-parallel")
    if mp is not None:
        if not isinstance(mp, int) or mp <= 0:
            raise MatrixError("'max-parallel' must be a positive integer")
        result["max-parallel"] = mp
    return result


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    if not argv:
        print("usage: matrix_generator.py <config.json>", file=sys.stderr)
        return 2
    path = argv[0]
    try:
        with open(path) as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: failed to load config: {e}", file=sys.stderr)
        return 2
    try:
        result = generate_matrix(config)
    except MatrixError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
