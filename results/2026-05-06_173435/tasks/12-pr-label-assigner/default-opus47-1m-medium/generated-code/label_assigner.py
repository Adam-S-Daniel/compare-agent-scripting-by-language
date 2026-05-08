#!/usr/bin/env python3
"""PR Label Assigner.

Given a list of changed file paths and a set of path-to-label rules
(JSON config), output the deduplicated label set that should be applied
to the PR.

Rule shape (each entry):
    {
        "pattern": "docs/**",      # glob pattern (fnmatch + ** support)
        "label":   "documentation",
        "priority": 0               # optional, higher = appears earlier
    }

Multiple labels per file are supported (a file matches every rule whose
pattern matches it). When the same label is produced by several rules,
it appears once. The final list is sorted by descending priority, then
alphabetically — so output is deterministic and conflict resolution is
explicit.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Iterable


class RuleError(ValueError):
    """Raised when a rules document is malformed or unreadable."""


def _glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Translate a shell-style glob (with ** support) to a compiled regex.

    `**` matches any number of path segments (including zero). `*` matches
    within a single path segment. `?` matches a single non-separator char.
    """
    i = 0
    out = ["^"]
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            if i + 1 < len(pattern) and pattern[i + 1] == "*":
                # `**/` or trailing `**`
                if i + 2 < len(pattern) and pattern[i + 2] == "/":
                    out.append("(?:.*/)?")
                    i += 3
                    continue
                out.append(".*")
                i += 2
                continue
            out.append("[^/]*")
        elif c == "?":
            out.append("[^/]")
        elif c in ".+(){}|^$\\":
            out.append("\\" + c)
        else:
            out.append(c)
        i += 1
    out.append("$")
    return re.compile("".join(out))


def _validate_rule(rule: dict) -> None:
    if not isinstance(rule, dict):
        raise RuleError(f"Rule must be an object, got: {rule!r}")
    if "pattern" not in rule:
        raise RuleError(f"Rule missing 'pattern': {rule!r}")
    if "label" not in rule:
        raise RuleError(f"Rule missing 'label': {rule!r}")


def assign_labels(files: Iterable[str], rules: list[dict]) -> list[str]:
    """Compute the label set for the given file list under the given rules.

    Returns labels ordered by descending priority then alphabetical, with
    duplicates removed.
    """
    # Validate up-front so callers get clear errors before any matching.
    for r in rules:
        _validate_rule(r)

    # Track best (max) priority observed per label so we can sort sensibly
    # when several rules contribute the same label.
    label_priority: dict[str, int] = {}
    for f in files:
        for rule in rules:
            regex = _glob_to_regex(rule["pattern"])
            if regex.match(f):
                label = rule["label"]
                pri = rule.get("priority", 0)
                if label not in label_priority or pri > label_priority[label]:
                    label_priority[label] = pri

    return sorted(label_priority, key=lambda lbl: (-label_priority[lbl], lbl))


def load_rules(path: str) -> list[dict]:
    p = Path(path)
    if not p.exists():
        raise RuleError(f"Rules file not found: {path}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise RuleError(f"Invalid JSON in {path}: {e}") from e
    if not isinstance(data, list):
        raise RuleError(f"Rules file must contain a JSON array, got {type(data).__name__}")
    return data


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Assign PR labels from changed file paths.")
    parser.add_argument("--rules", required=True, help="Path to JSON rules file")
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--files-json", help="JSON array of changed file paths")
    src.add_argument("--files-file", help="Path to file with one changed path per line")
    args = parser.parse_args(argv)

    try:
        rules = load_rules(args.rules)
        if args.files_json:
            files = json.loads(args.files_json)
            if not isinstance(files, list):
                raise RuleError("--files-json must be a JSON array")
        else:
            files = [ln.strip() for ln in Path(args.files_file).read_text().splitlines() if ln.strip()]

        labels = assign_labels(files, rules)
    except RuleError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON for --files-json: {e}", file=sys.stderr)
        return 2

    print(json.dumps(labels))
    return 0


if __name__ == "__main__":
    sys.exit(main())
