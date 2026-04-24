"""PR label assigner.

Given a list of changed file paths and a set of glob-pattern rules,
emit the deduplicated list of labels that apply to the changeset,
ordered by rule priority (lowest priority value first).

Built TDD-style; see tests/test_label_assigner.py for the red/green
steps that drove each piece of functionality.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class LabelRule:
    pattern: str
    label: str
    # Lower number = higher priority (appears earlier in output).
    # Default 100 keeps unspecified rules behind any explicitly ordered ones.
    priority: int = 100


def _matches(path: str, pattern: str) -> bool:
    # fnmatch's `*` matches across `/`, so `**` and `*` behave equivalently
    # for our purposes — both work as recursive wildcards. This keeps the
    # pattern syntax familiar (docs/**, src/api/**, *.test.*) without
    # pulling in a heavier glob library.
    return fnmatch.fnmatch(path, pattern)


def assign_labels(files: Iterable[str], rules: list[LabelRule]) -> list[str]:
    """Return the ordered, deduplicated list of labels for the given files."""
    # Sort rules by priority so the output order reflects rule priority.
    ordered = sorted(rules, key=lambda r: r.priority)
    seen: set[str] = set()
    out: list[str] = []
    files = list(files)
    for rule in ordered:
        if any(_matches(f, rule.pattern) for f in files):
            if rule.label not in seen:
                seen.add(rule.label)
                out.append(rule.label)
    return out


def load_rules(path: str) -> list[LabelRule]:
    """Load rules from a JSON config file.

    Expected shape: {"rules": [{"pattern": "...", "label": "...", "priority": N}, ...]}
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Rules file not found: {path}")
    try:
        data = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in rules file {path}: {e}") from e

    raw_rules = data.get("rules", [])
    rules: list[LabelRule] = []
    for i, r in enumerate(raw_rules):
        if "pattern" not in r or "label" not in r:
            raise ValueError(
                f"Rule #{i} missing required field 'pattern' or 'label'"
            )
        rules.append(
            LabelRule(
                pattern=r["pattern"],
                label=r["label"],
                priority=int(r.get("priority", 100)),
            )
        )
    return rules


def _read_files_list(path: str) -> list[str]:
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Files list not found: {path}")
    return [line.strip() for line in p.read_text().splitlines() if line.strip()]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Assign PR labels by changed-file globs.")
    parser.add_argument("--rules", required=True, help="Path to JSON rules config.")
    parser.add_argument("--files", required=True,
                        help="Path to a newline-separated list of changed files.")
    args = parser.parse_args(argv)

    try:
        rules = load_rules(args.rules)
        files = _read_files_list(args.files)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    for label in assign_labels(files, rules):
        print(label)
    return 0


if __name__ == "__main__":
    sys.exit(main())
