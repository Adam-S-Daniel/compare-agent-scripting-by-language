#!/usr/bin/env python3
"""
PR Label Assigner
-----------------
Given a list of changed file paths (simulating a PR's changed files), assigns
labels based on configurable path-to-label mapping rules.

Supports:
  - Glob patterns: *, ?, [], ** (recursive directory wildcard)
  - Multiple labels per file (all matching rules are applied)
  - Priority ordering: rules with lower 'priority' number appear first in output
  - Patterns without '/' match against the file's basename anywhere in the tree

Config format (JSON):
  {
    "rules": [
      {"pattern": "docs/**",   "label": "documentation", "priority": 1},
      {"pattern": "src/api/**","label": "api",            "priority": 2},
      {"pattern": "*.test.*",  "label": "tests",          "priority": 3}
    ]
  }

Priority note: when multiple rules match the same file (a "conflict"), ALL
matching labels are applied.  Priority only determines OUTPUT ORDER — lower
number means the label appears earlier in the final label list.
"""

import argparse
import fnmatch
import json
import os
import sys


# ---------------------------------------------------------------------------
# Core: glob pattern matching
# ---------------------------------------------------------------------------

def _match_parts(path_parts: list[str], pattern_parts: list[str]) -> bool:
    """
    Recursive helper: match a split file path against a split glob pattern.

    Handles:
      *   — any characters within a single path component (no /)
      ?   — any single character within a component
      **  — zero or more path components (recursive wildcard)
    """
    # Both exhausted: full match
    if not pattern_parts and not path_parts:
        return True

    # Pattern exhausted but path still has components: no match
    if not pattern_parts:
        return False

    # Path exhausted: match only if remaining pattern is all **
    if not path_parts:
        return all(p == "**" for p in pattern_parts)

    p = pattern_parts[0]

    if p == "**":
        # ** can consume ZERO path components (skip the ** and continue)
        if _match_parts(path_parts, pattern_parts[1:]):
            return True
        # ** can consume ONE path component (advance path, keep the **)
        return _match_parts(path_parts[1:], pattern_parts)

    # Normal component: must match the current path component with fnmatch
    if fnmatch.fnmatch(path_parts[0], p):
        return _match_parts(path_parts[1:], pattern_parts[1:])

    return False


def match_pattern(file_path: str, pattern: str) -> bool:
    """
    Return True if file_path matches the given glob pattern.

    Rules:
      - Patterns that contain '/' are matched against the full path from root.
      - Patterns WITHOUT '/' (e.g. "*.test.*") match against the basename of
        any file — so "*.test.*" catches test files in any subdirectory.
      - "**" in a pattern matches zero or more directory levels.
    """
    file_path = file_path.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    # Pattern without a path separator: match against basename only
    if "/" not in pattern and "**" not in pattern:
        return fnmatch.fnmatch(os.path.basename(file_path), pattern)

    # Split and recursively match
    return _match_parts(file_path.split("/"), pattern.split("/"))


# ---------------------------------------------------------------------------
# Core: label assignment
# ---------------------------------------------------------------------------

def assign_labels(changed_files: list[str], rules: list[dict]) -> list[str]:
    """
    Apply label-assignment rules to a list of changed file paths.

    Returns a deduplicated list of labels, ordered by each rule's 'priority'
    value (ascending — lower number = higher priority = earlier in the list).
    Rules without a 'priority' key default to priority 999 (lowest).

    All matching rules are applied; priority is only about output ordering.
    """
    if not changed_files or not rules:
        return []

    # Sort rules by priority so we visit them in output order
    sorted_rules = sorted(rules, key=lambda r: r.get("priority", 999))

    seen: set[str] = set()
    labels: list[str] = []

    for rule in sorted_rules:
        pattern = rule["pattern"]
        label = rule["label"]

        if label in seen:
            continue  # Already emitted this label

        # Check whether ANY changed file matches this rule's pattern
        for file_path in changed_files:
            if match_pattern(file_path, pattern):
                seen.add(label)
                labels.append(label)
                break  # One match is enough to emit this label

    return labels


# ---------------------------------------------------------------------------
# I/O helpers
# ---------------------------------------------------------------------------

def load_config(config_path: str) -> dict:
    """
    Load and validate a label-assigner config from a JSON file.
    Exits with code 1 and a message on error.
    """
    try:
        with open(config_path) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in config file {config_path}: {exc}", file=sys.stderr)
        sys.exit(1)

    if "rules" not in config:
        print(
            f"Error: config file {config_path} is missing the required 'rules' key.",
            file=sys.stderr,
        )
        sys.exit(1)

    return config


def load_files(files_path: str) -> list[str]:
    """
    Load a list of changed file paths from a plain-text file (one path per line).
    Blank lines are ignored.  Exits with code 1 on error.
    """
    try:
        with open(files_path) as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"Error: files list not found: {files_path}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Assign PR labels based on changed file paths."
    )
    parser.add_argument("--config", required=True, help="Path to the JSON config file")
    parser.add_argument(
        "--files", required=True, help="Path to a text file listing changed file paths"
    )
    parser.add_argument(
        "--output",
        choices=["text", "json", "csv"],
        default="text",
        help="Output format (default: text)",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    changed_files = load_files(args.files)
    labels = assign_labels(changed_files, config["rules"])

    if args.output == "json":
        print(json.dumps({"labels": labels}))
    elif args.output == "csv":
        # Print comma-separated labels (empty string if none)
        print(",".join(labels))
    else:
        # Human-readable text
        if labels:
            print("Labels: " + ", ".join(labels))
        else:
            print("Labels: (none)")


if __name__ == "__main__":
    main()
