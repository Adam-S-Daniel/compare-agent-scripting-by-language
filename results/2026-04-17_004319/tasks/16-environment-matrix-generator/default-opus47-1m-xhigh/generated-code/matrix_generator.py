#!/usr/bin/env python3
"""Build a GitHub Actions strategy.matrix JSON from a higher-level config.

The config describes dimension axes (OS, language versions, feature flags,
etc.), plus optional include/exclude rules, max-parallel, fail-fast, and a
max-size cap. The generator produces the exact JSON shape GitHub Actions
expects under a job's ``strategy`` key, plus a ``total_combinations`` field
that callers can assert on.

Design goals:
- Semantics match GitHub Actions: exclude removes matching rows from the
  cartesian product; include either extends a matching row or adds a new
  row if it does not match any existing row.
- Validation is explicit: any structural problem raises ``MatrixError``
  with a human-readable message instead of silently producing junk.

Run as a CLI to feed a workflow step::

    python3 matrix_generator.py --config config.json

Exits 0 on success, 2 on validation errors (distinguishable from
interpreter errors / crashes).
"""

from __future__ import annotations

import argparse
import itertools
import json
import sys
from pathlib import Path
from typing import Any


class MatrixError(Exception):
    """Raised for any user-facing configuration or validation problem."""


def load_config(path: str) -> dict[str, Any]:
    """Load and parse a JSON config file, re-raising errors as MatrixError."""
    p = Path(path)
    if not p.exists():
        raise MatrixError(f"config file not found: {path}")
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as exc:
        raise MatrixError(f"invalid JSON in {path}: {exc}") from exc


def cartesian_combinations(axes: dict[str, list[Any]]) -> list[dict[str, Any]]:
    """Return every combination of one value per axis.

    An empty axis collapses the whole product to nothing, matching what
    GitHub Actions would do (no rows to run).
    """
    if not axes:
        return []
    keys = list(axes.keys())
    value_lists = [axes[k] for k in keys]
    if any(len(v) == 0 for v in value_lists):
        return []
    return [dict(zip(keys, values)) for values in itertools.product(*value_lists)]


def matches_rule(combo: dict[str, Any], rule: dict[str, Any]) -> bool:
    """True when every key in ``rule`` appears in ``combo`` with the same value.

    Keys in ``rule`` that are absent from ``combo`` cause a no-match — this
    mirrors GitHub's behaviour where an exclude referring to an unknown
    axis never fires.
    """
    for k, v in rule.items():
        if k not in combo or combo[k] != v:
            return False
    return True


def _validate_config(cfg: dict[str, Any]) -> dict[str, Any]:
    """Structural validation. Returns the ``matrix`` sub-dict on success."""
    if "matrix" not in cfg:
        raise MatrixError("config is missing required 'matrix' key")
    matrix = cfg["matrix"]
    if not isinstance(matrix, dict) or not matrix:
        raise MatrixError("'matrix' must be a non-empty object of axes")
    for key, value in matrix.items():
        if not isinstance(value, list):
            raise MatrixError(
                f"matrix axis '{key}' must be a list, got {type(value).__name__}"
            )
    for rule_list_key in ("include", "exclude"):
        if rule_list_key in cfg and not isinstance(cfg[rule_list_key], list):
            raise MatrixError(f"'{rule_list_key}' must be a list of rule objects")
        for rule in cfg.get(rule_list_key, []):
            if not isinstance(rule, dict):
                raise MatrixError(
                    f"each '{rule_list_key}' rule must be an object, got {type(rule).__name__}"
                )
    if "max_parallel" in cfg:
        mp = cfg["max_parallel"]
        if not isinstance(mp, int) or isinstance(mp, bool) or mp < 1:
            raise MatrixError("'max_parallel' must be a positive integer")
    if "fail_fast" in cfg and not isinstance(cfg["fail_fast"], bool):
        raise MatrixError("'fail_fast' must be a boolean")
    if "max_size" in cfg:
        ms = cfg["max_size"]
        if not isinstance(ms, int) or isinstance(ms, bool) or ms < 1:
            raise MatrixError("'max_size' must be a positive integer")
    return matrix


def effective_combinations(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    """Return the final list of matrix rows after applying excludes/includes.

    This is what GitHub Actions would actually execute — useful for tests
    that want to count or inspect the concrete jobs.
    """
    matrix = _validate_config(cfg)
    combos = cartesian_combinations(matrix)

    excludes = cfg.get("exclude", [])
    if excludes:
        combos = [c for c in combos if not any(matches_rule(c, e) for e in excludes)]

    includes = cfg.get("include", [])
    for inc in includes:
        # If the include matches an existing row (on the axes it mentions),
        # extend that row rather than adding a new one. Otherwise append.
        extended = False
        for combo in combos:
            axis_overlap = {k: inc[k] for k in inc if k in matrix}
            if axis_overlap and matches_rule(combo, axis_overlap):
                combo.update(inc)
                extended = True
        if not extended:
            combos.append(dict(inc))

    return combos


def build_matrix(cfg: dict[str, Any]) -> dict[str, Any]:
    """Turn a config dict into a strategy-shaped dict ready to be JSON-dumped.

    The returned dict is safe to drop directly under a job's ``strategy``
    key in a workflow (minus the synthetic ``total_combinations`` field,
    which callers can strip if they want)."""
    matrix = _validate_config(cfg)

    # Compute effective size up front so we can fail early if it breaks
    # the cap. Using effective_combinations keeps the count consistent
    # with what would actually execute.
    rows = effective_combinations(cfg)
    total = len(rows)

    max_size = cfg.get("max_size")
    if max_size is not None and total > max_size:
        raise MatrixError(
            f"matrix has {total} combinations, which exceeds maximum of {max_size}"
        )

    # Preserve the user's axes in the output; includes/excludes are emitted
    # verbatim so GitHub Actions can apply them with identical semantics.
    out_matrix: dict[str, Any] = {k: list(v) for k, v in matrix.items()}
    if cfg.get("exclude"):
        out_matrix["exclude"] = [dict(r) for r in cfg["exclude"]]
    if cfg.get("include"):
        out_matrix["include"] = [dict(r) for r in cfg["include"]]

    result: dict[str, Any] = {"matrix": out_matrix, "total_combinations": total}
    if "fail_fast" in cfg:
        result["fail-fast"] = cfg["fail_fast"]
    if "max_parallel" in cfg:
        result["max-parallel"] = cfg["max_parallel"]
    return result


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a GitHub Actions strategy.matrix JSON from a config file."
    )
    parser.add_argument("--config", required=True, help="Path to JSON config.")
    parser.add_argument(
        "--pretty", action="store_true", help="Pretty-print the output JSON."
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    try:
        cfg = load_config(args.config)
        result = build_matrix(cfg)
    except MatrixError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    indent = 2 if args.pretty else None
    print(json.dumps(result, indent=indent, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
