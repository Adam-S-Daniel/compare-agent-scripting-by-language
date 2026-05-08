"""GitHub Actions strategy.matrix generator.

Reads a config describing axes (OS, language versions, feature flags),
include/exclude rules, and strategy options (max-parallel, fail-fast,
max_size), and emits a matrix JSON ready to drop into a workflow's
``strategy:`` block.

The output uses GitHub's ``include`` form to materialize all
combinations explicitly, so callers don't depend on Actions' own
cartesian expansion.

Config schema (JSON):

    {
      "axes": {
        "os": ["ubuntu-latest", "macos-latest"],
        "python": ["3.11", "3.12"],
        "with_redis": [true, false]
      },
      "exclude": [{"os": "macos-latest", "python": "3.11"}],
      "include": [
        {"os": "ubuntu-latest", "python": "3.12", "experimental": true}
      ],
      "max_parallel": 4,
      "fail_fast": false,
      "max_size": 256
    }

Output (JSON):

    {
      "matrix": {"include": [ ... explicit combinations ... ]},
      "max-parallel": 4,
      "fail-fast": false
    }
"""
from __future__ import annotations

import argparse
import copy
import json
import sys
from itertools import product


# Default cap mirrors GitHub's own published limit of 256 jobs per
# matrix, so a passing local validation stays within the platform
# limit too.
DEFAULT_MAX_SIZE = 256


class MatrixError(Exception):
    """Raised for invalid configs or matrix-size violations."""


def _matches(combo, rule):
    """True if every key in `rule` is present in `combo` with the same value."""
    return all(combo.get(k) == v for k, v in rule.items())


def _apply_includes(combinations, includes):
    """Apply GitHub Actions include semantics.

    For each include entry:
      * Try to augment every existing combo whose values match the include
        on the keys it specifies (without overwriting existing values).
      * If no existing combo could absorb it, append it as a new combo.
    """
    for inc in includes:
        if not isinstance(inc, dict):
            raise MatrixError(f"each include entry must be an object, got {inc!r}")

        absorbed = False
        for combo in combinations:
            shared_keys = set(inc) & set(combo)
            extra_keys = set(inc) - set(combo)
            # The include matches this combo iff every shared key already
            # has the include's value. (If a shared key has a *different*
            # value, the include doesn't apply to that combo.)
            if shared_keys and all(combo[k] == inc[k] for k in shared_keys):
                for k in extra_keys:
                    combo[k] = inc[k]
                absorbed = True
        if not absorbed:
            combinations.append(copy.deepcopy(inc))
    return combinations


def generate_matrix(config):
    """Materialize a strategy block dict from a config dict.

    Raises MatrixError on any structural problem or size violation.
    """
    if not isinstance(config, dict):
        raise MatrixError("config must be an object/mapping")

    axes = config.get("axes", {})
    if not isinstance(axes, dict):
        raise MatrixError("'axes' must be an object/mapping")

    excludes = config.get("exclude", [])
    if not isinstance(excludes, list):
        raise MatrixError("'exclude' must be a list")
    for e in excludes:
        if not isinstance(e, dict):
            raise MatrixError(f"each exclude entry must be an object, got {e!r}")

    includes = config.get("include", [])
    if not isinstance(includes, list):
        raise MatrixError("'include' must be a list")

    max_size = config.get("max_size", DEFAULT_MAX_SIZE)
    if not isinstance(max_size, int) or max_size < 0:
        raise MatrixError("'max_size' must be a non-negative integer")

    # Cartesian product of the named axes. With no axes we start from an
    # empty list (not a single empty dict) so a pure-include config doesn't
    # leave a phantom empty combo for every include to glom onto.
    keys = list(axes.keys())
    if keys:
        values = [axes[k] for k in keys]
        combinations = [dict(zip(keys, combo)) for combo in product(*values)]
    else:
        combinations = []

    # Apply excludes (an exclude with a partial spec drops every combo
    # that contains all of its key/value pairs).
    combinations = [
        c for c in combinations
        if not any(_matches(c, rule) for rule in excludes)
    ]

    # Apply includes (augment-or-append).
    combinations = _apply_includes(combinations, includes)

    # Validate size at the very end so a config that excludes itself
    # back under the cap still passes.
    if len(combinations) > max_size:
        raise MatrixError(
            f"matrix size {len(combinations)} exceeds max_size {max_size}"
        )

    result = {"matrix": {"include": combinations}}

    # Strategy-level options pass through to GitHub's hyphenated keys.
    if "max_parallel" in config:
        mp = config["max_parallel"]
        if not isinstance(mp, int) or mp < 1:
            raise MatrixError("'max_parallel' must be a positive integer")
        result["max-parallel"] = mp

    if "fail_fast" in config:
        ff = config["fail_fast"]
        if not isinstance(ff, bool):
            raise MatrixError("'fail_fast' must be a boolean")
        result["fail-fast"] = ff

    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate GitHub Actions matrix JSON")
    parser.add_argument("config", help="Path to JSON config file")
    parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    args = parser.parse_args(argv)

    with open(args.config, encoding="utf-8") as fh:
        config = json.load(fh)

    matrix = generate_matrix(config)
    text = json.dumps(matrix, indent=2, sort_keys=True)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    print(text)


if __name__ == "__main__":
    try:
        main()
    except MatrixError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(2)
    except FileNotFoundError as exc:
        print(f"Error: config file not found: {exc.filename}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in config: {exc}", file=sys.stderr)
        sys.exit(2)
