#!/usr/bin/env python3
"""PR label assigner.

Reads a JSON rules file and a newline-delimited list of changed files, then
emits the deduplicated set of labels (one per line, stdout) that should apply
to the PR.

Rule format (JSON):
    {
      "rules": [
        {"pattern": "docs/**", "labels": ["documentation"], "priority": 10},
        {"pattern": "*.test.*", "labels": ["tests"], "priority": 5},
        {"pattern": "src/api/**", "labels": ["api", "backend"]}
      ]
    }

Priority (default 0) is used only to sort the output: higher priority first,
then alphabetic within the same priority. Every rule whose glob matches any
changed file contributes its labels to the final set (labels are deduped).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Translate a glob pattern into an anchored regex.

    Supports `**` (matches any path including slashes), `*` (matches within a
    single path segment), and `?` (matches a single non-slash char).
    """
    i = 0
    out = ["^"]
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            # `**/` -> any number of directories (including zero)
            if pattern[i : i + 3] == "**/":
                out.append("(?:.*/)?")
                i += 3
                continue
            # trailing or standalone `**` -> anything
            if pattern[i : i + 2] == "**":
                out.append(".*")
                i += 2
                continue
            # single `*` -> anything except slash
            out.append("[^/]*")
            i += 1
            continue
        if c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append("$")
    return re.compile("".join(out))


def rule_matches(pattern: str, files: list[str]) -> bool:
    """Return True if any changed file matches the rule's glob."""
    regex = glob_to_regex(pattern)
    return any(regex.match(f) for f in files)


def assign_labels(files: list[str], rules: list[dict]) -> list[str]:
    """Compute the sorted label list for the given files and rules."""
    # label -> highest priority seen for that label
    label_priority: dict[str, int] = {}
    for rule in rules:
        if "pattern" not in rule or "labels" not in rule:
            raise ValueError(
                f"rule missing required keys 'pattern' and 'labels': {rule!r}"
            )
        priority = int(rule.get("priority", 0))
        if rule_matches(rule["pattern"], files):
            for label in rule["labels"]:
                if label not in label_priority or label_priority[label] < priority:
                    label_priority[label] = priority
    return sorted(label_priority, key=lambda l: (-label_priority[l], l))


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(
            f"usage: {argv[0]} <rules.json> <files.txt>",
            file=sys.stderr,
        )
        return 2
    rules_path = Path(argv[1])
    files_path = Path(argv[2])
    try:
        rules_doc = json.loads(rules_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"error: rules file not found: {rules_path}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"error: invalid JSON in rules file: {e}", file=sys.stderr)
        return 1
    try:
        files_text = files_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        print(f"error: files list not found: {files_path}", file=sys.stderr)
        return 1

    rules = rules_doc.get("rules") if isinstance(rules_doc, dict) else None
    if not isinstance(rules, list):
        print("error: rules file must have top-level 'rules' list", file=sys.stderr)
        return 1
    files = [line.strip() for line in files_text.splitlines() if line.strip()]

    try:
        labels = assign_labels(files, rules)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    # Machine-parseable output: a BEGIN/END block so the CI harness can extract
    # exactly the labels regardless of other log chatter.
    print("LABELS_BEGIN")
    for label in labels:
        print(label)
    print("LABELS_END")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
