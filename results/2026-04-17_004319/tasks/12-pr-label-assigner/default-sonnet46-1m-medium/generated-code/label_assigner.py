"""
PR Label Assigner — assigns labels to a pull request based on which files changed.

Rules map glob patterns to labels with a priority number (lower = higher priority).
Multiple rules can match; all their labels are collected and deduplicated.
Output is ordered by the priority of the first rule that produced each label.
"""

import argparse
import fnmatch
import json
import sys


def match_file(file_path: str, pattern: str) -> bool:
    """Return True if file_path matches the glob pattern.

    Uses fnmatch which lets * match path separators, so docs/** correctly
    matches docs/sub/dir/file.md without needing pathlib.
    """
    return fnmatch.fnmatch(file_path, pattern)


def load_rules(rules_config: list[dict]) -> list[dict]:
    """Return rules sorted by priority ascending (1 = highest priority).

    Rules without an explicit priority field are placed last (fallback 999).
    The original list is not modified.
    """
    return sorted(rules_config, key=lambda r: r.get("priority", 999))


def assign_labels(files: list[str], rules: list[dict]) -> list[str]:
    """Assign labels to a PR given its changed files and a set of rules.

    Algorithm:
      1. Sort rules by priority (lowest number first).
      2. For each rule, check whether ANY file matches its pattern.
      3. If so, add the rule's label to the output (skip if already present).
      4. Return the deduplicated label list in priority order.
    """
    sorted_rules = load_rules(rules)
    seen: set[str] = set()
    labels: list[str] = []

    for rule in sorted_rules:
        pattern = rule["pattern"]
        label = rule["label"]
        for file_path in files:
            if match_file(file_path, pattern):
                if label not in seen:
                    seen.add(label)
                    labels.append(label)
                break  # one matching file is enough to activate this rule

    return labels


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Assign PR labels based on changed file paths."
    )
    parser.add_argument("input_file", help="JSON file with 'files' and 'rules' keys")
    parser.add_argument(
        "--format",
        choices=["list", "csv", "json"],
        default="list",
        help="Output format (default: list)",
    )
    args = parser.parse_args()

    try:
        with open(args.input_file) as fh:
            data = json.load(fh)
    except FileNotFoundError:
        print(f"Error: input file '{args.input_file}' not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON in '{args.input_file}': {exc}", file=sys.stderr)
        sys.exit(1)

    files = data.get("files", [])
    rules = data.get("rules", [])

    if not isinstance(files, list):
        print("Error: 'files' must be a JSON array", file=sys.stderr)
        sys.exit(1)
    if not isinstance(rules, list):
        print("Error: 'rules' must be a JSON array", file=sys.stderr)
        sys.exit(1)

    result = assign_labels(files, rules)

    if args.format == "csv":
        print(",".join(result))
    elif args.format == "json":
        print(json.dumps(result))
    else:
        for label in result:
            print(label)

    # Always emit a machine-parseable summary line for the act test harness
    print(f"ASSIGNED_LABELS: {','.join(result)}")


if __name__ == "__main__":
    main()
