"""Environment matrix generator for GitHub Actions.

Reads a JSON config describing matrix axes, include/exclude rules, parallelism
controls, and a max-size safety cap, and emits an expanded matrix JSON object
suitable for consumption by a downstream job via
`strategy.matrix: ${{ fromJson(...) }}`.

Config shape (all keys lowercase, dashes in `fail-fast` / `max-parallel` /
`max-size` to mirror GitHub Actions' own YAML keys):

    {
      "matrix": { "os": [...], "python": [...], "flag": [...] },
      "include": [ { ...partial combo... }, ... ],
      "exclude": [ { ...partial combo... }, ... ],
      "fail-fast": true,
      "max-parallel": 4,
      "max-size": 256
    }

Output shape:

    {
      "include": [ { ...full combo... }, ... ],
      "fail-fast": true,
      "max-parallel": 4   # omitted if unset
    }

Using `include` as the top-level key means the result is directly usable as a
`strategy.matrix` value (GitHub Actions accepts `matrix: { include: [...] }` as
an explicit list of job configurations). Exit status is 1 on any MatrixError.
"""

from __future__ import annotations

import argparse
import itertools
import json
import sys
from pathlib import Path
from typing import Any


class MatrixError(Exception):
    """Raised for any user-facing configuration or validation error."""


# ---------------------------------------------------------------------------
# Core matrix expansion
# ---------------------------------------------------------------------------


def expand_matrix(axes: dict[str, list[Any]]) -> list[dict[str, Any]]:
    """Return the cartesian product of every axis as a list of dicts.

    With no axes, returns an empty list (not `[{}]`): "no matrix" means "no
    jobs", which is the only interpretation that avoids a silent single-job
    run on an empty config.
    """
    if not axes:
        return []
    keys = list(axes.keys())
    value_lists = [axes[k] for k in keys]
    return [dict(zip(keys, combo)) for combo in itertools.product(*value_lists)]


def _matches(combo: dict[str, Any], rule: dict[str, Any]) -> bool:
    """True iff every key in `rule` exists in `combo` with the same value."""
    return all(combo.get(k) == v for k, v in rule.items())


def _apply_excludes(
    combos: list[dict[str, Any]], excludes: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    return [c for c in combos if not any(_matches(c, rule) for rule in excludes)]


def _apply_includes(
    combos: list[dict[str, Any]], includes: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    """Merge include rules per GitHub Actions semantics.

    For each include entry: if any existing combo already matches the include's
    *original* axis keys, augment those combos with the include's extra keys.
    Otherwise, append the include as a new standalone combo.

    We approximate "original axis keys" as the keys shared with the first
    combo (if any). This mirrors how Actions decides whether an include
    "extends" an existing matrix cell vs. adds a new one.
    """
    if not combos:
        # With no base combos, every include is just a standalone job.
        return list(includes)

    axis_keys = set(combos[0].keys())
    result = [dict(c) for c in combos]

    for inc in includes:
        match_keys = {k: v for k, v in inc.items() if k in axis_keys}
        extra_keys = {k: v for k, v in inc.items() if k not in axis_keys}

        matched_any = False
        if match_keys:
            for combo in result:
                if _matches(combo, match_keys):
                    combo.update(extra_keys)
                    matched_any = True

        if not matched_any:
            result.append(dict(inc))

    return result


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


def _validate_axes(axes: Any) -> dict[str, list[Any]]:
    if not isinstance(axes, dict) or not axes:
        raise MatrixError("'matrix' must be a non-empty object of axis -> values")
    for name, values in axes.items():
        if not isinstance(values, list):
            raise MatrixError(f"axis '{name}' must be a list")
        if not values:
            raise MatrixError(f"axis '{name}' must not be empty")
    return axes


def _validate_rules(name: str, rules: Any) -> list[dict[str, Any]]:
    if rules is None:
        return []
    if not isinstance(rules, list):
        raise MatrixError(f"'{name}' must be a list of objects")
    for i, rule in enumerate(rules):
        if not isinstance(rule, dict):
            raise MatrixError(f"'{name}[{i}]' must be an object")
    return rules


def _validate_int(name: str, value: Any, minimum: int) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
        raise MatrixError(f"'{name}' must be an integer >= {minimum}")
    return value


# ---------------------------------------------------------------------------
# Top-level entry point
# ---------------------------------------------------------------------------


def generate(config: dict[str, Any]) -> dict[str, Any]:
    """Turn a config dict into an expanded matrix dict, validating as we go."""
    if not isinstance(config, dict):
        raise MatrixError("config must be a JSON object")
    if "matrix" not in config:
        raise MatrixError("config is missing 'matrix' key")

    axes = _validate_axes(config["matrix"])
    excludes = _validate_rules("exclude", config.get("exclude"))
    includes = _validate_rules("include", config.get("include"))

    fail_fast = config.get("fail-fast", True)
    if not isinstance(fail_fast, bool):
        raise MatrixError("'fail-fast' must be a boolean")

    combos = expand_matrix(axes)
    combos = _apply_excludes(combos, excludes)
    combos = _apply_includes(combos, includes)

    # Size validation runs AFTER excludes/includes so users can excludes their
    # way under a strict cap -- what matters is the job count we'll actually
    # hand to GitHub Actions.
    if "max-size" in config:
        max_size = _validate_int("max-size", config["max-size"], 1)
        if len(combos) > max_size:
            raise MatrixError(
                f"matrix has {len(combos)} combinations, exceeds max-size {max_size}"
            )

    out: dict[str, Any] = {"include": combos, "fail-fast": fail_fast}
    if "max-parallel" in config:
        out["max-parallel"] = _validate_int("max-parallel", config["max-parallel"], 1)

    return out


def load_config(path: Path) -> dict[str, Any]:
    """Read and parse the config file with friendly error wrapping."""
    if not path.exists():
        raise MatrixError(f"config file not found: {path}")
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise MatrixError(f"invalid JSON in {path}: {e}") from e


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate a GitHub Actions build matrix from a JSON config."
    )
    parser.add_argument("config", type=Path, help="path to JSON config file")
    parser.add_argument(
        "--pretty", action="store_true", help="pretty-print the output JSON"
    )
    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
        result = generate(config)
    except MatrixError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    kwargs = {"indent": 2} if args.pretty else {"separators": (",", ":")}
    print(json.dumps(result, **kwargs))
    return 0


if __name__ == "__main__":
    sys.exit(_main())
