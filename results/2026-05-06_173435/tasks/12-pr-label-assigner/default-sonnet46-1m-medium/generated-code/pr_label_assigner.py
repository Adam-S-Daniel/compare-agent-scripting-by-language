"""PR Label Assigner — assigns labels to a PR based on changed file paths.

Usage:
    python pr_label_assigner.py --files "docs/readme.md,src/api/v1.py"
    python pr_label_assigner.py --files "src/api/v1.py" --rules rules.json

The module exposes assign_labels() for programmatic use and a CLI for
use inside GitHub Actions workflows.
"""

import argparse
import fnmatch
import json
import sys
from pathlib import Path
from typing import Any


# Default rules applied when no custom rules file is provided.
# Each rule has: pattern (glob), label (string), priority (int, lower = higher priority).
DEFAULT_RULES: list[dict[str, Any]] = [
    {"pattern": "docs/**",        "label": "documentation", "priority": 1},
    {"pattern": "src/api/**",     "label": "api",           "priority": 1},
    {"pattern": "*.test.*",       "label": "tests",         "priority": 2},
    {"pattern": "**/*.test.*",    "label": "tests",         "priority": 2},
    {"pattern": "**/*.md",        "label": "documentation", "priority": 2},
    {"pattern": "*.md",           "label": "documentation", "priority": 2},
    {"pattern": "src/**",         "label": "source",        "priority": 3},
]


def match_glob(pattern: str, path: str) -> bool:
    """Return True if *path* matches the glob *pattern*.

    Supports:
    - Simple wildcards: *.md, *.test.*
    - Path prefix with **: docs/**, src/api/**
    - Deep wildcard: **/*.test.*
    """
    # Normalise to forward slashes
    path = path.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    if fnmatch.fnmatch(path, pattern):
        return True

    # For patterns ending with /**, also match the directory prefix itself
    # and any depth of nesting.  We translate ** -> * for fnmatch since
    # fnmatch's * does not cross path separators in the Python stdlib, but
    # by iterating over the possible prefix lengths we get the right answer.
    if "**" in pattern:
        # Split on ** to get prefix and suffix parts
        parts = pattern.split("**")
        prefix = parts[0].rstrip("/")   # e.g. "docs" from "docs/**"
        suffix = parts[-1].lstrip("/")  # e.g. "*.test.*" from "**/*.test.*"

        if prefix:
            # Pattern like "docs/**" or "src/api/**"
            if not path.startswith(prefix + "/"):
                return False
            remainder = path[len(prefix) + 1:]
            if suffix:
                return fnmatch.fnmatch(remainder, suffix) or fnmatch.fnmatch(
                    remainder.split("/")[-1], suffix
                )
            return True  # any file under prefix matches docs/**
        else:
            # Pattern like "**/*.test.*" — suffix must match the tail
            if suffix:
                return fnmatch.fnmatch(path, suffix) or fnmatch.fnmatch(
                    path.split("/")[-1], suffix
                )
    return False


def load_rules(path: str) -> list[dict[str, Any]]:
    """Load label rules from a JSON file.

    The file must contain a JSON array of rule objects:
        [{"pattern": "docs/**", "label": "documentation", "priority": 1}, ...]

    Raises:
        FileNotFoundError: if the file does not exist
        ValueError: if the file is not valid JSON or not a JSON array
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Rules file not found: {path}")

    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in rules file '{path}': {exc}") from exc

    if not isinstance(data, list):
        raise ValueError(f"Rules file must be a JSON array, got {type(data).__name__}: {path}")

    return data


def assign_labels(
    changed_files: list[str],
    rules: list[dict[str, Any]] | None = None,
) -> list[str]:
    """Return a sorted list of unique labels for a PR with *changed_files*.

    Args:
        changed_files: Paths of files changed in the PR.
        rules: Label rules.  Each rule must have 'pattern', 'label', and
               optionally 'priority' (default 999).  If None, DEFAULT_RULES
               are used.

    Returns:
        Alphabetically sorted list of unique label strings.

    Raises:
        ValueError: if *rules* is an empty list (distinct from None).
    """
    if rules is None:
        rules = DEFAULT_RULES

    if len(rules) == 0:
        raise ValueError("Rules list cannot be empty")

    # Evaluate higher-priority rules first so they win when multiple rules
    # produce the same label (deduplication is done by a set regardless).
    sorted_rules = sorted(rules, key=lambda r: r.get("priority", 999))

    labels: set[str] = set()
    for file_path in changed_files:
        for rule in sorted_rules:
            pattern = rule.get("pattern", "")
            label = rule.get("label", "")
            if not pattern or not label:
                continue
            if match_glob(pattern, file_path):
                labels.add(label)

    return sorted(labels)


def main(argv: list[str] | None = None) -> int:
    """CLI entry point.

    Prints the assigned labels, one per line, and also as a comma-joined
    summary line for easy parsing in CI.
    """
    parser = argparse.ArgumentParser(
        description="Assign PR labels based on changed file paths."
    )
    parser.add_argument(
        "--files",
        required=True,
        help="Comma-separated list of changed file paths",
    )
    parser.add_argument(
        "--rules",
        default=None,
        help="Path to a JSON rules file (optional; uses built-in rules if omitted)",
    )
    args = parser.parse_args(argv)

    changed_files = [f.strip() for f in args.files.split(",") if f.strip()]

    rules = None
    if args.rules:
        try:
            rules = load_rules(args.rules)
        except (FileNotFoundError, ValueError) as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1

    labels = assign_labels(changed_files, rules)

    if labels:
        for label in labels:
            print(label)
        print(f"LABELS: {','.join(labels)}")
    else:
        print("LABELS: (none)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
