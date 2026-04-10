#!/usr/bin/env python3
"""
PR Label Assigner - assigns labels to PRs based on changed file paths.

Given a list of changed files and configurable path-to-label mapping rules
(using glob patterns), outputs the final set of labels to apply.

Features:
- Glob pattern matching (*, **, ?) via PurePosixPath.match()
- Multiple labels per file (union of all matching rules)
- Priority ordering (lowest number = highest priority)
- Exclusive rules that prevent lower-priority matches for a file
- Deduplication of labels in sorted output
"""

import json
import sys
import os
import fnmatch


def load_config(config_path):
    """Load and validate label configuration from a JSON file.

    Raises FileNotFoundError if file doesn't exist.
    Raises ValueError if JSON is invalid or missing required fields.
    """
    try:
        with open(config_path) as f:
            config = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"Config file not found: {config_path}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in config file: {e}")

    if "rules" not in config:
        raise ValueError("Config must contain a 'rules' key")

    for i, rule in enumerate(config["rules"]):
        if "pattern" not in rule:
            raise ValueError(f"Rule {i} missing required field 'pattern'")
        if "labels" not in rule:
            raise ValueError(f"Rule {i} missing required field 'labels'")
        if not isinstance(rule["labels"], list):
            raise ValueError(f"Rule {i}: 'labels' must be a list")

    return config


def match_file(filepath, pattern):
    """Check if a filepath matches a glob pattern.

    Supports *, **, and ? wildcards. Uses fnmatch for simple patterns
    and custom logic for ** (recursive) patterns, ensuring compatibility
    with Python < 3.12 where PurePosixPath.match() doesn't handle **.

    - Patterns with ** match zero or more directory levels.
    - Patterns without / match against the filename component only.
    - Patterns with / (but not **) match the full path.
    """
    if "**" in pattern:
        # Split on ** to get prefix and suffix
        parts = pattern.split("**", 1)
        prefix = parts[0].rstrip("/")
        suffix = parts[1].lstrip("/")

        if prefix:
            # e.g. "docs/**", "src/api/**", ".github/**"
            if not filepath.startswith(prefix + "/"):
                return False
            if not suffix:
                return True
            remaining = filepath[len(prefix) + 1:]
            return fnmatch.fnmatch(remaining, suffix)
        else:
            # e.g. "**/*.py" — match suffix against any path tail
            if not suffix:
                return True
            if fnmatch.fnmatch(filepath, suffix):
                return True
            return any(
                fnmatch.fnmatch(filepath[i + 1:], suffix)
                for i, c in enumerate(filepath) if c == "/"
            )

    # No **: patterns without / match filename only, with / match full path
    if "/" in pattern:
        return fnmatch.fnmatch(filepath, pattern)
    filename = filepath.rsplit("/", 1)[-1]
    return fnmatch.fnmatch(filename, pattern)


def assign_labels(changed_files, config):
    """Assign labels based on changed files and configuration rules.

    Rules are sorted by priority (lowest number = highest priority).
    All matching rules contribute their labels (union), unless a rule
    has 'exclusive: true' — then lower-priority rules are skipped
    for that particular file.

    Returns a sorted list of unique labels.
    """
    if not changed_files:
        return []

    # Sort rules by priority (lowest number = evaluated first)
    rules = sorted(config["rules"], key=lambda r: r.get("priority", 100))
    labels = set()

    for filepath in changed_files:
        file_exclusive_hit = False
        for rule in rules:
            if file_exclusive_hit:
                break
            if match_file(filepath, rule["pattern"]):
                labels.update(rule["labels"])
                if rule.get("exclusive", False):
                    file_exclusive_hit = True

    return sorted(labels)


def main():
    """CLI entry point: parse args, load config, assign labels, print results."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Assign PR labels based on changed file paths")
    parser.add_argument("--config", default="label_config.json",
                        help="Path to label config JSON file")
    parser.add_argument("--files", nargs="*",
                        help="Changed file paths")
    parser.add_argument("--files-from",
                        help="Read changed file paths from a file (one per line)")
    args = parser.parse_args()

    # Load configuration
    config = load_config(args.config)

    # Gather changed files from args or file
    changed_files = []
    if args.files:
        changed_files = args.files
    elif args.files_from:
        try:
            with open(args.files_from) as f:
                changed_files = [line.strip() for line in f if line.strip()]
        except FileNotFoundError:
            print(f"Error: File list not found: {args.files_from}", file=sys.stderr)
            sys.exit(1)

    if not changed_files:
        print("No changed files provided")
        print("LABELS: (none)")
        return

    # Assign and output labels
    labels = assign_labels(changed_files, config)
    print(f"Changed files: {', '.join(changed_files)}")
    if labels:
        print(f"LABELS: {', '.join(labels)}")
        for label in labels:
            print(f"  - {label}")
    else:
        print("LABELS: (none)")


if __name__ == "__main__":
    main()
