"""
GitHub Actions Environment Matrix Generator
============================================
Generates a strategy.matrix JSON from a high-level configuration dict that
describes OS options, language versions, and feature flags.

Design:
  MatrixConfig  – thin dataclass that validates/parses the raw config dict
  MatrixGenerator – produces the final strategy fragment
  MatrixValidationError – raised when the matrix would exceed the size limit

TDD was followed: every public behaviour has a corresponding test that was
written *before* this code existed (see test_matrix_generator.py).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from itertools import product
from typing import Any


# ── Exceptions ───────────────────────────────────────────────────────────────

class MatrixValidationError(ValueError):
    """Raised when the generated matrix fails a validation rule."""


# ── Configuration dataclass ──────────────────────────────────────────────────

@dataclass
class MatrixConfig:
    """Parsed, validated representation of the user-supplied config dict."""

    os: list[str]
    language_versions: dict[str, list[str]]
    feature_flags: dict[str, list[Any]]
    include: list[dict[str, Any]] = field(default_factory=list)
    exclude: list[dict[str, Any]] = field(default_factory=list)
    max_parallel: int | None = None
    fail_fast: bool = True          # mirrors GitHub Actions default
    max_matrix_size: int = 256      # GitHub Actions hard limit is 256

    @classmethod
    def from_dict(cls, data: dict) -> "MatrixConfig":
        """Parse and validate a raw configuration dictionary."""
        if "os" not in data:
            raise ValueError("Configuration must include an 'os' key.")
        if not isinstance(data["os"], list) or len(data["os"]) == 0:
            raise ValueError("'os' must be a non-empty list.")

        return cls(
            os=data["os"],
            language_versions=data.get("language_versions", {}),
            feature_flags=data.get("feature_flags", {}),
            include=data.get("include", []),
            exclude=data.get("exclude", []),
            max_parallel=data.get("max_parallel"),  # None → omit from output
            fail_fast=data.get("fail_fast", True),
            max_matrix_size=data.get("max_matrix_size", 256),
        )


# ── Generator ────────────────────────────────────────────────────────────────

class MatrixGenerator:
    """Builds a GitHub Actions strategy fragment from a MatrixConfig."""

    def __init__(self, config: MatrixConfig) -> None:
        self.config = config
        # Populated by generate(); exposes the effective combination count.
        self.computed_size: int = 0

    # ── Step 1: collect all named axes ───────────────────────────────────────

    def build_axes(self) -> dict[str, list[Any]]:
        """
        Return all matrix axes as a plain dict: os, each language key,
        each feature-flag key.
        """
        axes: dict[str, list[Any]] = {}
        axes["os"] = self.config.os

        for lang, versions in self.config.language_versions.items():
            axes[lang] = versions

        for flag, values in self.config.feature_flags.items():
            axes[flag] = values

        return axes

    # ── Step 2: cartesian product of all axes ────────────────────────────────

    def compute_base_combinations(self) -> list[dict[str, Any]]:
        """
        Return every combination produced by the cartesian product of all
        axes.  If there are no secondary axes, just the OS list is returned.
        """
        axes = self.build_axes()
        keys = list(axes.keys())
        values = [axes[k] for k in keys]

        return [dict(zip(keys, combo)) for combo in product(*values)]

    # ── Step 3: apply exclude rules ──────────────────────────────────────────

    def apply_excludes(
        self, combinations: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """
        Remove any combination that is a superset of at least one exclude
        entry (i.e. every key/value in the exclude rule matches).
        """
        def is_excluded(combo: dict[str, Any]) -> bool:
            for rule in self.config.exclude:
                if all(combo.get(k) == v for k, v in rule.items()):
                    return True
            return False

        return [c for c in combinations if not is_excluded(c)]

    # ── Step 4: assemble and validate ────────────────────────────────────────

    def generate(self) -> dict[str, Any]:
        """
        Build the full GitHub Actions strategy fragment:

            {
              "fail-fast": <bool>,
              "max-parallel": <int>,   # omitted when None
              "matrix": {
                "os": [...],
                "<lang>": [...],
                "<flag>": [...],
                "include": [...],      # omitted when empty
                "exclude": [...],      # omitted when empty
              }
            }

        Raises MatrixValidationError if the effective combination count
        exceeds config.max_matrix_size.
        """
        axes = self.build_axes()
        effective_combinations = self.apply_excludes(
            self.compute_base_combinations()
        )
        self.computed_size = len(effective_combinations)

        if self.computed_size > self.config.max_matrix_size:
            raise MatrixValidationError(
                f"Matrix size {self.computed_size} exceeds maximum "
                f"allowed size of {self.config.max_matrix_size}. "
                "Reduce the number of OS options, language versions, "
                "feature flags, or lower the axes cardinality."
            )

        # Build the matrix sub-object; os and each axis go in directly.
        matrix: dict[str, Any] = {}
        for key, values in axes.items():
            matrix[key] = values

        if self.config.include:
            matrix["include"] = self.config.include

        if self.config.exclude:
            matrix["exclude"] = self.config.exclude

        # Assemble the top-level strategy fragment.
        strategy: dict[str, Any] = {
            "fail-fast": self.config.fail_fast,
            "matrix": matrix,
        }

        if self.config.max_parallel is not None:
            strategy["max-parallel"] = self.config.max_parallel

        return strategy

    def to_json(self, indent: int = 2) -> str:
        """Return the strategy fragment as a pretty-printed JSON string."""
        return json.dumps(self.generate(), indent=indent)


# ── CLI entry-point ──────────────────────────────────────────────────────────

def _main() -> None:
    """
    Read a JSON config from stdin (or a path given as argv[1]) and print
    the generated strategy fragment to stdout.

    Example:
        echo '{"os":["ubuntu-latest"],"language_versions":{"python":["3.12"]},
               "feature_flags":{}}' | python3 matrix_generator.py
    """
    import sys

    if len(sys.argv) > 1:
        with open(sys.argv[1]) as fh:
            raw = json.load(fh)
    else:
        raw = json.load(sys.stdin)

    try:
        cfg = MatrixConfig.from_dict(raw)
        gen = MatrixGenerator(cfg)
        print(gen.to_json())
        print(
            f"\n# Effective combinations: {gen.computed_size}",
            file=sys.stderr,
        )
    except (ValueError, MatrixValidationError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    _main()
