#!/usr/bin/env python3
"""PR label assigner.

Given:
  * a JSON rules file mapping path globs -> label lists
  * a list of changed file paths (one per line; `-` reads stdin)

produce a deduplicated, priority-ordered list of labels as JSON on stdout.

Rule schema:
    {
      "rules": [
        {"pattern": "docs/**",    "labels": ["documentation"], "priority": 1},
        {"pattern": "src/api/**", "labels": ["api"],           "priority": 10},
        {"pattern": "src/**",     "labels": ["source"], "group": "area", "priority": 1}
      ]
    }

Semantics:
  * Glob `**` crosses directory boundaries; `*` is single-segment; `?` is
    single character.
  * A file can match multiple rules; all of their labels are collected.
  * `priority` orders the output (highest first). Default: 0. Ties keep config
    order (stable).
  * `group` triggers conflict resolution: when two rules share a group and both
    match the same file, only the higher-priority rule's labels apply for that
    file.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


# --- Glob matching ---------------------------------------------------------
#
# Python's `fnmatch` doesn't handle `**` the way git/GitHub labelers do, so we
# translate the glob to a regex ourselves. Rules:
#   `**`  -> match anything, including slashes (zero or more chars)
#   `*`   -> match any chars *except* `/` (single path segment)
#   `?`   -> match exactly one non-`/` character
#   other chars -> regex-escaped literal
#
# A small nuance: a leading `**/` should also match the root (i.e. `**/a.js`
# matches `a.js`). We handle that explicitly.

def _glob_to_regex(pattern: str) -> str:
    """Translate a glob pattern to an anchored regex pattern."""
    # Allow a leading `**/` to match zero or more leading directories.
    if pattern.startswith("**/"):
        prefix = "(?:.*/)?"
        pattern = pattern[3:]
    else:
        prefix = ""

    out = []
    i = 0
    n = len(pattern)
    while i < n:
        c = pattern[i]
        if c == "*":
            # Look ahead for a second `*`.
            if i + 1 < n and pattern[i + 1] == "*":
                out.append(".*")
                i += 2
                # Consume a trailing slash so `docs/**/x` matches `docs/x`.
                if i < n and pattern[i] == "/":
                    i += 1
            else:
                out.append("[^/]*")
                i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(c))
            i += 1
    return f"^{prefix}{''.join(out)}$"


def match_pattern(path: str, pattern: str) -> bool:
    """Return True if `path` matches the glob `pattern`."""
    return re.match(_glob_to_regex(pattern), path) is not None


# --- Rules loading ---------------------------------------------------------

def load_rules(config_path: str | Path) -> list[dict]:
    """Load and validate rules from a JSON config file.

    Raises FileNotFoundError with the path if the file is missing, and
    ValueError (with the filename) for any structural problems.
    """
    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(f"Rules file not found: {config_path}")
    try:
        data = json.loads(config_path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {config_path}: {e}") from e
    if "rules" not in data:
        raise ValueError(
            f"Config {config_path} is missing required top-level 'rules' key"
        )
    rules = data["rules"]
    if not isinstance(rules, list):
        raise ValueError(f"'rules' in {config_path} must be a list")
    for i, rule in enumerate(rules):
        if "pattern" not in rule or "labels" not in rule:
            raise ValueError(
                f"Rule #{i} in {config_path} needs 'pattern' and 'labels'"
            )
    return rules


# --- Label assignment ------------------------------------------------------

def assign_labels(files: list[str], rules: list[dict]) -> list[str]:
    """Return the deduplicated, priority-ordered label list for `files`.

    Algorithm:
      1. For each file, find the matching rules.
      2. Within a `group`, only the highest-priority matching rule survives
         (conflict resolution).
      3. Collect (priority, config_order, label) tuples across all files.
      4. Sort by (-priority, config_order, first_seen_order) and dedupe.
    """
    # Track each label's best priority and the earliest-seen order so we can
    # produce stable output.
    best_priority: dict[str, int] = {}
    first_seen: dict[str, int] = {}
    order = 0

    for fpath in files:
        # Find rules this file matches, annotated with their index.
        matches = [
            (idx, rule) for idx, rule in enumerate(rules)
            if match_pattern(fpath, rule["pattern"])
        ]
        if not matches:
            continue

        # Conflict resolution within groups: keep only the highest-priority
        # match for each group; rules without a group pass through untouched.
        groups: dict[str, tuple[int, dict]] = {}
        kept: list[tuple[int, dict]] = []
        for idx, rule in matches:
            grp = rule.get("group")
            if grp is None:
                kept.append((idx, rule))
                continue
            existing = groups.get(grp)
            if existing is None or rule.get("priority", 0) > existing[1].get("priority", 0):
                groups[grp] = (idx, rule)
        kept.extend(groups.values())

        for _idx, rule in kept:
            priority = rule.get("priority", 0)
            for label in rule["labels"]:
                # Keep the maximum priority we've ever seen for this label...
                if label not in best_priority or priority > best_priority[label]:
                    best_priority[label] = priority
                # ...but remember the first time we saw it, so ties are stable.
                if label not in first_seen:
                    first_seen[label] = order
                    order += 1

    # Sort: descending priority, then by first-seen order (stable).
    return sorted(
        best_priority.keys(),
        key=lambda lab: (-best_priority[lab], first_seen[lab]),
    )


# --- CLI -------------------------------------------------------------------

def _read_file_list(source: str) -> list[str]:
    """Read a newline-delimited list of paths. `-` means stdin."""
    if source == "-":
        text = sys.stdin.read()
    else:
        text = Path(source).read_text()
    return [line.strip() for line in text.splitlines() if line.strip()]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Assign labels to a PR based on changed file paths.",
    )
    parser.add_argument("--rules", required=True,
                        help="Path to JSON rules config")
    parser.add_argument("--files", required=True,
                        help="Path to newline-delimited file list; `-` for stdin")
    args = parser.parse_args(argv)

    try:
        rules = load_rules(args.rules)
        files = _read_file_list(args.files)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    labels = assign_labels(files, rules)
    print(json.dumps(labels))
    return 0


if __name__ == "__main__":
    sys.exit(main())
