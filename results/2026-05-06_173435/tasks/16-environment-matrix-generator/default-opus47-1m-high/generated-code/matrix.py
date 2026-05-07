"""Generate a GitHub Actions strategy.matrix block from a config file.

Approach
--------
A GitHub Actions matrix is the cartesian product of its axis values, with
two modifiers: `exclude` drops combos whose listed keys all match, and
`include` either appends new combos or merges extra keys onto existing
combos when its keys form a subset of the axes. We replicate that here so
we can compute the expanded combination count and reject configs that
would exceed `max_size` *before* CI ever sees them.

Input config (JSON) shape:
    {
      "os":              ["ubuntu-latest", "windows-latest"],
      "language_version":["3.11", "3.12"],
      "feature_flags":   {"redis": [true, false]},   # optional, flattened to axes
      "include":         [...],                      # optional
      "exclude":         [...],                      # optional
      "max_parallel":    4,                          # optional, -> strategy.max-parallel
      "fail_fast":       false,                      # optional, -> strategy.fail-fast
      "max_size":        100                         # optional validation limit
    }

Output (JSON) is the strategy block GitHub Actions consumes, plus an
`expanded_size` field that downstream tooling can assert against.
"""

from __future__ import annotations

import json
import sys
from itertools import product
from pathlib import Path


class MatrixError(Exception):
    """Raised for any user-facing matrix configuration error.

    We use a single exception type so the CLI can render a clean,
    one-line error message without leaking tracebacks for input mistakes.
    """


# Required top-level axes. Every GH Actions matrix in this generator must
# at least pick an OS and a language runtime version.
REQUIRED_AXES = ("os", "language_version")


def load_config(path: str) -> dict:
    """Read a JSON config file from disk and return it as a dict.

    All file/parse errors are mapped to MatrixError with a useful message.
    """
    p = Path(path)
    if not p.is_file():
        raise MatrixError(f"Config file not found: {path}")
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise MatrixError(f"Invalid JSON in {path}: {e.msg} (line {e.lineno})") from e


def _combo_matches(combo: dict, rule: dict) -> bool:
    """True if every key in `rule` is present in `combo` with the same value.

    GH Actions semantics: an exclude entry doesn't have to mention every
    axis; missing keys act as wildcards.
    """
    return all(k in combo and combo[k] == v for k, v in rule.items())


def expand_combinations(
    axes: dict[str, list],
    includes: list[dict],
    excludes: list[dict],
) -> list[dict]:
    """Apply the GH Actions matrix expansion rules to `axes`.

    Steps mirror the documented GH Actions algorithm:
      1. Take the cartesian product of axes.
      2. Remove every combo that matches any exclude rule.
      3. For each include: if its axis-keys are a subset of `axes` AND
         it matches an existing combo, merge the extra keys. Otherwise
         it becomes a new standalone combo.
    """
    keys = list(axes.keys())
    combos: list[dict] = []
    if keys:
        for values in product(*(axes[k] for k in keys)):
            combos.append(dict(zip(keys, values)))

    if excludes:
        combos = [c for c in combos if not any(_combo_matches(c, r) for r in excludes)]

    axis_key_set = set(keys)
    for inc in includes or []:
        # Keys in this include that overlap with our axes (used for matching).
        overlap = {k: v for k, v in inc.items() if k in axis_key_set}
        extras = {k: v for k, v in inc.items() if k not in axis_key_set}

        merged_any = False
        if overlap and extras:
            # Try to merge extras onto every existing combo whose overlap matches.
            for combo in combos:
                if all(combo.get(k) == v for k, v in overlap.items()):
                    combo.update(extras)
                    merged_any = True
            if merged_any:
                continue

        # Otherwise treat as a new standalone combo.
        combos.append(dict(inc))

    return combos


def build_matrix(cfg: dict) -> dict:
    """Build the full GH Actions strategy block (with expanded_size) from cfg."""
    for required in REQUIRED_AXES:
        if required not in cfg:
            raise MatrixError(f"Config is missing required axis: {required!r}")
        if not isinstance(cfg[required], list):
            raise MatrixError(f"Axis {required!r} must be a list")
        if len(cfg[required]) == 0:
            raise MatrixError(f"Axis {required!r} is empty; matrix would have 0 jobs")

    # Build the axes dict: required axes plus flattened feature flags.
    # Feature flags become first-class matrix axes so jobs can switch on them.
    axes: dict[str, list] = {k: list(cfg[k]) for k in REQUIRED_AXES}
    for flag_name, flag_values in (cfg.get("feature_flags") or {}).items():
        if not isinstance(flag_values, list) or not flag_values:
            raise MatrixError(
                f"Feature flag {flag_name!r} must be a non-empty list of values"
            )
        if flag_name in axes:
            raise MatrixError(f"Feature flag {flag_name!r} collides with an axis name")
        axes[flag_name] = list(flag_values)

    includes = cfg.get("include") or []
    excludes = cfg.get("exclude") or []
    if not isinstance(includes, list) or not isinstance(excludes, list):
        raise MatrixError("`include` and `exclude` must be lists if provided")

    expanded = expand_combinations(axes, includes=includes, excludes=excludes)

    max_size = cfg.get("max_size")
    if max_size is not None:
        if not isinstance(max_size, int) or max_size < 1:
            raise MatrixError("`max_size` must be a positive integer")
        if len(expanded) > max_size:
            raise MatrixError(
                f"Matrix expansion produced {len(expanded)} jobs, "
                f"which exceeds max_size={max_size}"
            )

    matrix: dict = dict(axes)
    if includes:
        matrix["include"] = includes
    if excludes:
        matrix["exclude"] = excludes

    strategy: dict = {"matrix": matrix}
    if "max_parallel" in cfg:
        if not isinstance(cfg["max_parallel"], int) or cfg["max_parallel"] < 1:
            raise MatrixError("`max_parallel` must be a positive integer")
        strategy["max-parallel"] = cfg["max_parallel"]
    if "fail_fast" in cfg:
        if not isinstance(cfg["fail_fast"], bool):
            raise MatrixError("`fail_fast` must be a boolean")
        strategy["fail-fast"] = cfg["fail_fast"]

    return {"strategy": strategy, "expanded_size": len(expanded)}


def generate(path: str) -> str:
    """End-to-end: load config from `path`, return pretty-printed JSON."""
    cfg = load_config(path)
    return json.dumps(build_matrix(cfg), indent=2, sort_keys=True)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: matrix.py <config.json>", file=sys.stderr)
        return 2
    try:
        print(generate(argv[1]))
    except MatrixError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
