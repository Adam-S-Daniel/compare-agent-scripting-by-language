#!/usr/bin/env python3
"""PR label assigner.

Given a list of changed file paths and a set of pattern->label rules, decide
which labels apply to the PR. Supports gitignore-style globs (* / ** / ?),
multiple labels per file, and group-scoped priority for conflict resolution.

Approach
--------
- Each rule has a `pattern`, a `label`, an optional `priority` (int, default 0),
  and an optional `group` (string).
- For every file we evaluate every rule. A rule with no `/` in its pattern is
  treated as a basename-anywhere match (we prepend `**/`); otherwise the
  pattern must match the full path.
- All matching rules contribute their (label, priority) pairs.
- Conflict resolution: within a single `group`, only the highest-priority
  matching label survives. Ungrouped rules never conflict with each other.
- Output is sorted by priority descending, then alphabetically — deterministic
  so test assertions can compare exact strings.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


class LabelAssignerError(Exception):
    """Raised for any user-facing config or input error."""


@dataclass(frozen=True)
class _CompiledRule:
    pattern: str
    label: str
    priority: int
    group: str | None
    regex: re.Pattern[str]


def _glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Convert a glob pattern to an anchored regex.

    Semantics:
    - `**` matches any sequence of characters including `/`.
    - `**/` matches zero or more directory components.
    - `*` matches anything but `/`.
    - `?` matches a single non-`/` character.
    - All other regex metacharacters are escaped literally.
    - A pattern with no slash is treated as `**/<pattern>` (basename-anywhere).
    """
    if "/" not in pattern:
        pattern = "**/" + pattern

    out: list[str] = []
    i = 0
    n = len(pattern)
    while i < n:
        c = pattern[i]
        if c == "*":
            if i + 1 < n and pattern[i + 1] == "*":
                # `**` — handle the common `**/` form specially so it matches
                # zero directories (e.g. `**/x.py` should match `x.py`).
                if i + 2 < n and pattern[i + 2] == "/":
                    out.append("(?:.*/)?")
                    i += 3
                else:
                    out.append(".*")
                    i += 2
            else:
                out.append("[^/]*")
                i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        elif c in r".+()|^$\{}[]":
            out.append("\\" + c)
            i += 1
        else:
            out.append(c)
            i += 1

    return re.compile("^" + "".join(out) + "$")


class LabelAssigner:
    """Apply a set of pattern->label rules to a list of changed files."""

    def __init__(self, rules: list[dict]) -> None:
        self._rules: list[_CompiledRule] = []
        for idx, raw in enumerate(rules):
            if "pattern" not in raw:
                raise LabelAssignerError(f"rule {idx}: missing required field 'pattern'")
            if "label" not in raw:
                raise LabelAssignerError(f"rule {idx}: missing required field 'label'")
            try:
                regex = _glob_to_regex(raw["pattern"])
            except re.error as e:
                raise LabelAssignerError(
                    f"rule {idx}: invalid pattern {raw['pattern']!r}: {e}"
                ) from e
            self._rules.append(
                _CompiledRule(
                    pattern=raw["pattern"],
                    label=raw["label"],
                    priority=int(raw.get("priority", 0)),
                    group=raw.get("group"),
                    regex=regex,
                )
            )

    def assign_labels(self, files: list[str]) -> list[str]:
        """Return the deterministic, deduplicated list of labels for these files."""
        # Collect every (label, priority, group) match across all (file, rule) pairs.
        matches: list[tuple[str, int, str | None]] = []
        for path in files:
            for rule in self._rules:
                if rule.regex.match(path):
                    matches.append((rule.label, rule.priority, rule.group))

        # Group conflict resolution: within a group, keep only the label whose
        # rule had the highest priority. Ties broken alphabetically by label
        # so output stays deterministic.
        best_per_group: dict[str, tuple[int, str]] = {}
        ungrouped: dict[str, int] = {}
        for label, priority, group in matches:
            if group is None:
                # Ungrouped: keep the best priority observed for the same label.
                if label not in ungrouped or priority > ungrouped[label]:
                    ungrouped[label] = priority
            else:
                cur = best_per_group.get(group)
                if cur is None or priority > cur[0] or (priority == cur[0] and label < cur[1]):
                    best_per_group[group] = (priority, label)

        final: dict[str, int] = dict(ungrouped)
        for priority, label in best_per_group.values():
            # If the same label arrives via both grouped and ungrouped rules,
            # keep the higher priority.
            if label not in final or priority > final[label]:
                final[label] = priority

        # Sort: priority desc, then label asc.
        return [lbl for lbl, _ in sorted(final.items(), key=lambda kv: (-kv[1], kv[0]))]


def load_rules(path: Path | str) -> list[dict]:
    """Load and validate rules from a JSON config file.

    Expected shape: ``{"rules": [{"pattern": ..., "label": ..., ...}, ...]}``.
    """
    p = Path(path)
    if not p.exists():
        raise LabelAssignerError(f"rules file not found: {p}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise LabelAssignerError(f"invalid JSON in {p}: {e}") from e

    if not isinstance(data, dict) or "rules" not in data:
        raise LabelAssignerError(
            f"{p}: top-level object must contain a 'rules' array"
        )
    rules = data["rules"]
    if not isinstance(rules, list):
        raise LabelAssignerError(f"{p}: 'rules' must be an array")

    for idx, r in enumerate(rules):
        if not isinstance(r, dict):
            raise LabelAssignerError(f"{p}: rule {idx} must be an object")
        if "pattern" not in r:
            raise LabelAssignerError(f"{p}: rule {idx} missing 'pattern'")
        if "label" not in r:
            raise LabelAssignerError(f"{p}: rule {idx} missing 'label'")
    return rules


def load_files(path: Path | str) -> list[str]:
    """Load a list of changed file paths from JSON.

    Accepts either ``{"files": [...]}`` or a bare JSON array.
    """
    p = Path(path)
    if not p.exists():
        raise LabelAssignerError(f"files file not found: {p}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise LabelAssignerError(f"invalid JSON in {p}: {e}") from e
    if isinstance(data, dict) and "files" in data:
        files = data["files"]
    elif isinstance(data, list):
        files = data
    else:
        raise LabelAssignerError(
            f"{p}: expected either an array or an object with a 'files' array"
        )
    if not all(isinstance(f, str) for f in files):
        raise LabelAssignerError(f"{p}: every entry in 'files' must be a string")
    return files


def main(argv: list[str] | None = None) -> int:
    """CLI entry point. Returns process exit code."""
    parser = argparse.ArgumentParser(
        description="Assign PR labels based on changed file paths.",
    )
    parser.add_argument(
        "--rules", required=True,
        help="Path to a JSON file with the rule set.",
    )
    parser.add_argument(
        "--files", required=True,
        help="Path to a JSON file listing the PR's changed files.",
    )
    parser.add_argument(
        "--format", choices=("lines", "json"), default="lines",
        help="Output format: 'lines' (one label per line) or 'json'.",
    )
    args = parser.parse_args(argv)

    try:
        rules = load_rules(args.rules)
        files = load_files(args.files)
        labels = LabelAssigner(rules).assign_labels(files)
    except LabelAssignerError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    if args.format == "json":
        print(json.dumps({"labels": labels}))
    else:
        for lbl in labels:
            print(lbl)
    return 0


if __name__ == "__main__":
    sys.exit(main())
