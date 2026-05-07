#!/usr/bin/env python3
"""PR Label Assigner - assigns labels based on changed file paths using glob pattern rules."""

import json
import sys
import fnmatch
from pathlib import Path


def load_rules(rules_path):
    """Load label rules from a JSON config file."""
    try:
        with open(rules_path) as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: Rules file not found: {rules_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in rules file: {e}", file=sys.stderr)
        sys.exit(1)

    rules = config.get("rules", [])
    for i, rule in enumerate(rules):
        if "pattern" not in rule:
            print(f"ERROR: Rule {i} missing 'pattern' field", file=sys.stderr)
            sys.exit(1)
        if "label" not in rule:
            print(f"ERROR: Rule {i} missing 'label' field", file=sys.stderr)
            sys.exit(1)
        if "priority" not in rule:
            rule["priority"] = 0

    return sorted(rules, key=lambda r: r["priority"], reverse=True)


def match_file(filepath, pattern):
    """Match a file path against a glob pattern supporting ** for directory recursion."""
    if "**" in pattern:
        parts = pattern.split("**")
        if len(parts) == 2:
            prefix = parts[0].rstrip("/")
            suffix = parts[1].lstrip("/")
            if prefix and not filepath.startswith(prefix + "/") and filepath != prefix:
                return False
            remainder = filepath[len(prefix):].lstrip("/") if prefix else filepath
            if suffix:
                return fnmatch.fnmatch(remainder, suffix) or fnmatch.fnmatch(
                    remainder.split("/")[-1], suffix
                )
            return True
    return fnmatch.fnmatch(filepath, pattern) or fnmatch.fnmatch(
        filepath.split("/")[-1], pattern
    )


def assign_labels(changed_files, rules):
    """Assign labels to a set of changed files based on rules with priority ordering.

    When multiple rules match the same file and have conflicting labels,
    higher-priority rules take precedence. All non-conflicting labels accumulate.
    """
    labels = set()
    file_assignments = {}

    for filepath in changed_files:
        file_labels = []
        for rule in rules:
            if match_file(filepath, rule["pattern"]):
                file_labels.append(rule["label"])
        file_assignments[filepath] = file_labels
        labels.update(file_labels)

    return sorted(labels), file_assignments


def load_changed_files(files_path):
    """Load changed files list from a text file (one path per line)."""
    try:
        with open(files_path) as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"ERROR: Changed files list not found: {files_path}", file=sys.stderr)
        sys.exit(1)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Assign PR labels based on changed files")
    parser.add_argument("--rules", default="label_rules.json", help="Path to rules config")
    parser.add_argument("--files", default="changed_files.txt", help="Path to changed files list")
    parser.add_argument("--output-format", choices=["text", "json"], default="text")
    args = parser.parse_args()

    rules = load_rules(args.rules)
    changed_files = load_changed_files(args.files)

    if not changed_files:
        print("No changed files provided.")
        return

    labels, file_assignments = assign_labels(changed_files, rules)

    if args.output_format == "json":
        result = {
            "labels": labels,
            "file_assignments": file_assignments,
        }
        print(json.dumps(result, indent=2))
    else:
        print("=== PR Label Assignment Results ===")
        print(f"LABELS: {', '.join(labels)}")
        print()
        print("File assignments:")
        for filepath, file_labels in sorted(file_assignments.items()):
            print(f"  {filepath} -> {', '.join(file_labels)}")


if __name__ == "__main__":
    main()
