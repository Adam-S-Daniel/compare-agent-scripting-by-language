"""PR Label Assigner — applies labels to PRs based on changed file paths.

Rules are evaluated using glob patterns. Each rule has:
  pattern  : glob pattern to match against file paths (e.g. "docs/**", "*.test.*")
  label    : label to apply when the pattern matches
  priority : integer; lower number = higher priority (used for sorted output)

All matching rules contribute their labels (no exclusive-match / conflict elimination
by default). `assign_labels_with_priority` returns labels ordered by priority.
"""

import json
import fnmatch
from pathlib import Path


def _matches(pattern: str, filepath: str) -> bool:
    """Return True if filepath matches the glob pattern.

    Uses fnmatch for simple wildcard matching. The special "**" token in a
    pattern is converted to a single-level wildcard so that 'docs/**' matches
    'docs/README.md' and 'docs/guide/intro.md'.
    """
    # Normalise to forward slashes
    filepath = filepath.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    # Direct fnmatch first (handles simple patterns like "*.test.*")
    if fnmatch.fnmatch(filepath, pattern):
        return True

    # Handle "**" as "match any path segment(s)"
    if "**" in pattern:
        # Replace "**/" with a recursive wildcard understood by pathlib
        # Strategy: try matching with Path.match which supports "**"
        try:
            return Path(filepath).match(pattern)
        except Exception:
            pass

    return False


def assign_labels(files: list[str], rules: list[dict]) -> set[str]:
    """Return the set of labels that apply to the given file list.

    Every rule whose pattern matches at least one file in *files* contributes
    its label to the result set.
    """
    labels: set[str] = set()
    for rule in rules:
        pattern = rule["pattern"]
        for filepath in files:
            if _matches(pattern, filepath):
                labels.add(rule["label"])
                break  # one match is enough to activate this rule's label
    return labels


def assign_labels_with_priority(files: list[str], rules: list[dict]) -> list[dict]:
    """Return matched labels as a list of dicts, sorted by priority ascending.

    Each entry: {"label": str, "priority": int, "matched_files": list[str]}
    Lower priority number = higher importance, appears first in the list.
    """
    results: list[dict] = []
    for rule in sorted(rules, key=lambda r: r["priority"]):
        matched = [f for f in files if _matches(rule["pattern"], f)]
        if matched:
            results.append({
                "label": rule["label"],
                "priority": rule["priority"],
                "matched_files": matched,
            })
    return results


def load_rules(config_path: str) -> list[dict]:
    """Load labeling rules from a JSON config file.

    Expected format:
      {
        "rules": [
          {"pattern": "docs/**", "label": "documentation", "priority": 1},
          ...
        ]
      }
    """
    path = Path(config_path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in config file {config_path}: {exc}") from exc

    if "rules" not in data:
        raise ValueError(f"Config file {config_path} must contain a 'rules' key")

    return data["rules"]


def main() -> None:
    """CLI entry point: read changed files from stdin (one per line), print labels."""
    import argparse

    parser = argparse.ArgumentParser(description="Assign labels to a PR based on changed files")
    parser.add_argument(
        "--config",
        default="config/labels.json",
        help="Path to JSON config file with labeling rules",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        help="Changed file paths (space-separated). Reads from stdin if omitted.",
    )
    parser.add_argument("--output", choices=["set", "json", "lines"], default="lines")
    args = parser.parse_args()

    if args.files:
        files = args.files
    else:
        import sys
        files = [line.strip() for line in sys.stdin if line.strip()]

    try:
        rules = load_rules(args.config)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}", file=__import__("sys").stderr)
        raise SystemExit(1)

    labels = assign_labels(files, rules)

    if args.output == "json":
        print(json.dumps(sorted(labels)))
    elif args.output == "set":
        print(labels)
    else:
        for label in sorted(labels):
            print(label)


if __name__ == "__main__":
    main()
