#!/usr/bin/env python3
"""Environment matrix generator for GitHub Actions.

Reads a configuration file describing OS options, language versions,
and feature flags, then emits a JSON matrix suitable for use as
``strategy.matrix`` in a GitHub Actions workflow.

Configuration shape (JSON)::

    {
        "axes": {                     # required: name -> list of values
            "os":      ["ubuntu-latest", "windows-latest"],
            "python":  ["3.11", "3.12"],
            "feature": ["fast", "safe"]
        },
        "exclude":      [ {"os": "windows-latest", "python": "3.11"} ],
        "include":      [ {"os": "macos-latest", "python": "3.12"} ],
        "max_parallel": 4,            # optional; passes through as max-parallel
        "fail_fast":    false,        # optional; passes through as fail-fast
        "max_size":     50            # optional; defaults to 256 (GHA hard limit)
    }

Output is a single JSON object with keys ``include``, ``fail-fast``, and
optionally ``max-parallel``. We always materialize combinations into the
``include`` list. This makes include/exclude semantics deterministic and
matches what GitHub Actions accepts as a fully-expanded matrix.
"""
from __future__ import annotations

import argparse
import itertools
import json
import sys
from typing import Any


GITHUB_ACTIONS_MAX_JOBS = 256


class MatrixError(ValueError):
    """Raised for any user-facing configuration error."""


class MatrixSizeError(MatrixError):
    """Raised when the generated matrix would exceed the configured max size."""


def _validate_config(config: Any) -> dict:
    if not isinstance(config, dict):
        raise MatrixError("config must be a JSON object / dict")
    if "axes" not in config:
        raise MatrixError("config is missing required 'axes' key")
    axes = config["axes"]
    if not isinstance(axes, dict) or not axes:
        raise MatrixError("'axes' must be a non-empty mapping of name -> list")
    for name, values in axes.items():
        if not isinstance(values, list) or len(values) == 0:
            raise MatrixError(
                f"axis '{name}' must be a non-empty list of values"
            )
    return config


def _matches(combo: dict, rule: dict) -> bool:
    """A rule matches when every key in the rule equals the value in combo."""
    return all(combo.get(k) == v for k, v in rule.items())


def _cartesian(axes: dict) -> list[dict]:
    """Build the Cartesian product of all axis values as a list of dicts."""
    names = list(axes.keys())
    value_lists = [axes[n] for n in names]
    return [dict(zip(names, combo)) for combo in itertools.product(*value_lists)]


def generate_matrix(config: Any) -> dict:
    """Generate a fully-expanded matrix from ``config``.

    Returns a dict containing ``include`` (the list of job parameter
    combinations) plus optional ``max-parallel`` and ``fail-fast`` keys
    whose names use GitHub's hyphenated convention.
    """
    config = _validate_config(config)
    axes: dict = config["axes"]
    excludes: list = config.get("exclude") or []
    extra_includes: list = config.get("include") or []
    max_size: int = int(config.get("max_size", GITHUB_ACTIONS_MAX_JOBS))
    fail_fast: bool = bool(config.get("fail_fast", True))

    combos = _cartesian(axes)
    # Apply excludes: drop any combo that matches any exclude rule.
    combos = [c for c in combos if not any(_matches(c, r) for r in excludes)]
    # Append extra includes verbatim (they may contain new keys).
    combos.extend(extra_includes)

    if len(combos) > max_size:
        raise MatrixSizeError(
            f"Generated matrix has {len(combos)} entries which exceeds the "
            f"configured maximum of {max_size}."
        )

    out: dict = {"include": combos, "fail-fast": fail_fast}
    if "max_parallel" in config:
        max_parallel = int(config["max_parallel"])
        if max_parallel < 1:
            raise MatrixError("max_parallel must be >= 1")
        out["max-parallel"] = max_parallel
    return out


def load_config(path: str) -> dict:
    """Load a config file. JSON only (keeps the dependency surface tiny)."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError as e:
        raise MatrixError(f"config file not found: {path}") from e
    except json.JSONDecodeError as e:
        raise MatrixError(f"config file is not valid JSON: {e}") from e
    return data


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate a GitHub Actions strategy.matrix JSON.",
    )
    parser.add_argument("config", help="Path to a JSON config file")
    parser.add_argument(
        "--pretty", action="store_true", help="Pretty-print the output JSON"
    )
    args = parser.parse_args(argv)

    try:
        cfg = load_config(args.config)
        matrix = generate_matrix(cfg)
    except MatrixError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    indent = 2 if args.pretty else None
    print(json.dumps(matrix, indent=indent, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
