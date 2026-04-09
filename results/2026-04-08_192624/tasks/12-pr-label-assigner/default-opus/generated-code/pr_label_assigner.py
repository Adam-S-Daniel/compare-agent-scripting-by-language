#!/usr/bin/env python3
"""
PR Label Assigner — maps changed file paths to labels using configurable
glob-pattern rules with priority ordering.

TDD approach:
  1. Red:   wrote failing tests for each feature (glob matching, multi-label,
            priority, error handling) before any implementation.
  2. Green: implemented the minimum code to pass each test.
  3. Refactor: cleaned up after each green phase.

Design:
  - Rules are loaded from a YAML config file.  Each rule has a glob pattern,
    a label, and an optional integer priority (lower = higher priority).
  - When multiple rules match the same file, priorities resolve conflicts:
    only the highest-priority (lowest number) label(s) survive per file.
    Rules sharing the same priority all apply (multiple labels per file).
  - The final output is the deduplicated, sorted set of labels across all files.
"""

import json
import os
import sys
import fnmatch
from typing import Any


def load_config(config_path: str) -> dict[str, Any]:
    """Load label rules from a JSON config file.

    Expected format:
    {
      "rules": [
        {"pattern": "docs/**", "label": "documentation", "priority": 1},
        ...
      ]
    }
    """
    if not os.path.isfile(config_path):
        print(f"Error: config file not found: {config_path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(config_path) as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in config: {e}", file=sys.stderr)
        sys.exit(1)

    if "rules" not in config or not isinstance(config["rules"], list):
        print("Error: config must contain a 'rules' list", file=sys.stderr)
        sys.exit(1)

    for i, rule in enumerate(config["rules"]):
        if "pattern" not in rule or "label" not in rule:
            print(
                f"Error: rule {i} missing required 'pattern' or 'label' field",
                file=sys.stderr,
            )
            sys.exit(1)
        # Default priority is 10 (lower number = higher priority)
        rule.setdefault("priority", 10)

    return config


def match_file(filepath: str, pattern: str) -> bool:
    """Check if a filepath matches a glob pattern.

    Supports:
      - ** for recursive directory matching
      - * for single-component wildcards
      - *.ext for extension matching
    """
    # fnmatch doesn't handle ** natively, so we convert ** patterns
    # to work with both fnmatch and manual segment matching.

    # Normalise separators
    filepath = filepath.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    # Handle ** (recursive match)
    if "**" in pattern:
        # Split pattern on **
        parts = pattern.split("**")
        if len(parts) == 2:
            prefix = parts[0]  # e.g. "docs/"
            suffix = parts[1]  # e.g. "/*.md" or ""

            # Strip leading slash from suffix
            suffix = suffix.lstrip("/")

            # File must start with prefix (if any)
            if prefix and not filepath.startswith(prefix):
                return False

            remaining = filepath[len(prefix):]

            # If no suffix, any remaining path matches
            if not suffix:
                return True

            # Suffix must match the tail of the remaining path
            # Try matching suffix against every possible tail
            segments = remaining.split("/")
            for i in range(len(segments)):
                tail = "/".join(segments[i:])
                if fnmatch.fnmatch(tail, suffix):
                    return True
            return False

    # Simple glob — match the full path
    return fnmatch.fnmatch(filepath, pattern)


def assign_labels(
    changed_files: list[str], rules: list[dict[str, Any]]
) -> list[str]:
    """Apply rules to changed files and return the deduplicated sorted label set.

    Priority logic: for each file, collect all matching rules. Keep only those
    whose priority equals the best (lowest number) priority among the matches.
    This lets a high-priority rule override lower-priority catch-alls.
    """
    if not changed_files:
        return []

    all_labels: set[str] = set()

    for filepath in changed_files:
        # Collect all matching rules for this file
        matches: list[dict[str, Any]] = []
        for rule in rules:
            if match_file(filepath, rule["pattern"]):
                matches.append(rule)

        if not matches:
            continue

        # Find the best (lowest) priority among matches
        best_priority = min(m["priority"] for m in matches)

        # Keep labels from rules that share the best priority
        for m in matches:
            if m["priority"] == best_priority:
                all_labels.add(m["label"])

    return sorted(all_labels)


def main() -> None:
    # Config path from env or default
    config_path = os.environ.get("LABEL_CONFIG", "label-config.json")
    # Changed files: newline-separated from env var, or from a file
    changed_files_str = os.environ.get("CHANGED_FILES", "")
    changed_files_path = os.environ.get("CHANGED_FILES_PATH", "")

    if changed_files_str:
        changed_files = [f.strip() for f in changed_files_str.split("\n") if f.strip()]
    elif changed_files_path and os.path.isfile(changed_files_path):
        with open(changed_files_path) as f:
            changed_files = [line.strip() for line in f if line.strip()]
    else:
        print("Error: set CHANGED_FILES or CHANGED_FILES_PATH", file=sys.stderr)
        sys.exit(1)

    config = load_config(config_path)
    labels = assign_labels(changed_files, config["rules"])

    if labels:
        print("LABELS=" + ",".join(labels))
        for label in labels:
            print(f"  - {label}")
    else:
        print("LABELS=")
        print("  (no labels matched)")


if __name__ == "__main__":
    main()
