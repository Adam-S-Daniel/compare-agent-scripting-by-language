"""
GitHub Actions build matrix generator.

Converts a configuration dict describing OS options, language versions,
and feature flags into a GitHub Actions strategy.matrix-compatible JSON
structure.

Supports:
  - Full cross-product expansion of matrix axes
  - include rules (append extra combinations or extend existing ones)
  - exclude rules (remove matching combinations)
  - max-parallel and fail-fast top-level options
  - Validation that the final matrix doesn't exceed a maximum size (default 256)

Design follows Red/Green TDD: tests in test_matrix_generator.py were written
first; this file contains the minimum implementation required to make them pass.
"""

import itertools
from typing import Any, Dict, List

# Keys that are not matrix axes but carry matrix-level options
_RESERVED_KEYS = {"include", "exclude", "max-parallel", "fail-fast"}


class MatrixTooLargeError(Exception):
    """Raised when the generated matrix exceeds the allowed maximum size."""


class InvalidConfigError(Exception):
    """Raised when the configuration is structurally invalid."""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def generate_matrix(config: Dict[str, Any], max_size: int = 256) -> Dict[str, Any]:
    """Generate a GitHub Actions strategy.matrix dict from *config*.

    Parameters
    ----------
    config:
        A dict whose keys are either matrix axes (lists of values) or the
        reserved keys ``include``, ``exclude``, ``max-parallel``, and
        ``fail-fast``.
    max_size:
        Maximum number of combinations allowed.  Defaults to 256, which is
        GitHub Actions' documented upper limit.

    Returns
    -------
    dict
        A dict suitable for use as the ``strategy`` block in a GitHub Actions
        workflow.  Always contains a ``matrix`` key (list of combination dicts).
        Optionally contains ``max-parallel`` and ``fail-fast`` if specified in
        *config*.

    Raises
    ------
    InvalidConfigError
        When no matrix axes are found or an axis has an empty value list.
    MatrixTooLargeError
        When the resulting matrix exceeds *max_size*.
    """
    _validate_config(config)

    axes = _extract_axes(config)
    include_rules = config.get("include", [])
    exclude_rules = config.get("exclude", [])

    # Step 1: compute base cross-product
    combinations = _cross_product(axes)

    # Step 2: apply exclude rules
    combinations = _apply_excludes(combinations, exclude_rules)

    # Step 3: apply include rules (extend existing combos or add new ones)
    combinations = _apply_includes(combinations, include_rules)

    # Step 4: enforce size limit
    validate_matrix_size(combinations, max_size=max_size)

    # Step 5: assemble result
    result: Dict[str, Any] = {"matrix": combinations}
    if "max-parallel" in config:
        result["max-parallel"] = config["max-parallel"]
    if "fail-fast" in config:
        result["fail-fast"] = config["fail-fast"]

    return result


def validate_matrix_size(matrix: List[Dict], max_size: int = 256) -> None:
    """Raise :class:`MatrixTooLargeError` if *matrix* has more than *max_size* entries.

    Parameters
    ----------
    matrix:
        List of combination dicts to check.
    max_size:
        Upper bound (inclusive).

    Raises
    ------
    MatrixTooLargeError
        When ``len(matrix) > max_size``.
    """
    if len(matrix) > max_size:
        raise MatrixTooLargeError(
            f"Matrix has {len(matrix)} combinations, which exceeds the maximum of {max_size}. "
            "Reduce the number of axes or values, or add exclude rules."
        )


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _validate_config(config: Dict[str, Any]) -> None:
    """Check structural validity of the config, raising InvalidConfigError if bad."""
    if not config:
        raise InvalidConfigError(
            "Configuration is empty.  Provide at least one matrix axis."
        )

    axes = _extract_axes(config)
    if not axes:
        raise InvalidConfigError(
            "No matrix axes found.  All top-level keys are reserved "
            f"({', '.join(sorted(_RESERVED_KEYS))}).  "
            "Add at least one axis such as 'os' or 'python-version'."
        )

    for axis_name, values in axes.items():
        if not values:
            raise InvalidConfigError(
                f"Axis '{axis_name}' has an empty value list.  "
                "Provide at least one value per axis."
            )


def _extract_axes(config: Dict[str, Any]) -> Dict[str, list]:
    """Return only the non-reserved keys from *config* as axis->values pairs."""
    return {k: v for k, v in config.items() if k not in _RESERVED_KEYS}


def _cross_product(axes: Dict[str, list]) -> List[Dict]:
    """Return the full Cartesian product of all axis values.

    Each combination is a dict mapping axis name -> selected value.
    The order mirrors the dict insertion order of *axes*.
    """
    if not axes:
        return []
    keys = list(axes.keys())
    value_lists = [axes[k] for k in keys]
    return [dict(zip(keys, combo)) for combo in itertools.product(*value_lists)]


def _matches(combination: Dict, rule: Dict) -> bool:
    """Return True if *combination* contains every key/value pair in *rule*."""
    return all(combination.get(k) == v for k, v in rule.items())


def _apply_excludes(combinations: List[Dict], exclude_rules: List[Dict]) -> List[Dict]:
    """Remove combinations that match any exclude rule."""
    if not exclude_rules:
        return combinations

    def _should_keep(combo: dict) -> bool:
        return not any(_matches(combo, rule) for rule in exclude_rules)

    return [c for c in combinations if _should_keep(c)]


def _apply_includes(combinations: List[Dict], include_rules: List[Dict]) -> List[Dict]:
    """Apply include rules according to GitHub Actions semantics:

    - If an include entry matches an existing combination (all include keys
      are present with the same values), the extra keys from the include are
      *merged* into that combination (in-place extension).
    - If the include entry doesn't match any existing combination, it is
      *appended* as a brand-new combination.

    When an include matches multiple existing combinations, the extra keys
    are merged into each of them.
    """
    if not include_rules:
        return combinations

    result = [dict(c) for c in combinations]  # shallow copies

    for rule in include_rules:
        # Separate the "match" keys (those already present as axes) from the
        # "extra" keys that should be injected.
        # We identify axis keys by checking which keys already appear in
        # existing combinations.
        existing_keys = {k for combo in result for k in combo}
        match_part = {k: v for k, v in rule.items() if k in existing_keys}
        extra_part = {k: v for k, v in rule.items() if k not in existing_keys}

        if match_part:
            # Try to find matching combinations
            matched = [c for c in result if _matches(c, match_part)]
            if matched:
                # Extend each matching combination with the extra keys
                for combo in matched:
                    combo.update(rule)  # merge all rule keys into the match
                continue  # do not append a new entry

        # No match found (or no match keys) — append as a new combination
        result.append(dict(rule))

    return result
