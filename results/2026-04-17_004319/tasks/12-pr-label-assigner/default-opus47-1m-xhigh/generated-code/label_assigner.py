"""PR label assigner.

Given a list of changed file paths and a JSON rules file, emits the set of
labels that should be applied to a pull request. Labels are ordered by rule
priority (descending), then alphabetically on ties.

The rules file is JSON so we avoid third-party deps. Patterns support:

  *         — matches any chars within a single path segment
  **        — matches any sequence of segments (including none)
  ?         — matches any single char within a segment
  [abc]     — character class
  plain text — literal match

Examples:
  docs/**          -> any file under docs/
  src/api/**       -> any file under src/api/
  **/*.test.*      -> any *.test.* at any depth
  *.md             -> any .md at the repo root only

Usage:
  python3 label_assigner.py --rules rules.json --files changed_files.txt
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


# A rule: one glob pattern and the labels to emit when it matches, plus an
# optional priority (higher = earlier in output, default 0).
@dataclass(frozen=True)
class Rule:
    pattern: str
    labels: list[str]
    priority: int = 0


def _compile_glob(pattern: str) -> re.Pattern[str]:
    # Build a regex from the pattern. We cannot use fnmatch directly for `**`
    # because fnmatch's `*` already matches path separators — we want `*` to
    # stop at `/` and `**` to cross them.
    #
    # Tokenize: we walk the pattern character by character, emitting regex
    # for each meta-token. This is small enough to stay readable.
    i = 0
    out: list[str] = ["^"]
    n = len(pattern)
    while i < n:
        c = pattern[i]
        if c == "*":
            if i + 1 < n and pattern[i + 1] == "*":
                # `**` — match any number of chars including `/`. We also
                # consume a trailing `/` so `docs/**` matches `docs/x` and
                # `docs/a/x` but also the bare directory case.
                if i + 2 < n and pattern[i + 2] == "/":
                    out.append("(?:.*/)?")
                    i += 3
                else:
                    out.append(".*")
                    i += 2
            else:
                # single `*` — match any chars except `/`
                out.append("[^/]*")
                i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        elif c == "[":
            # character class — find closing `]`
            end = pattern.find("]", i + 1)
            if end == -1:
                out.append(re.escape(c))
                i += 1
            else:
                out.append(pattern[i : end + 1])
                i = end + 1
        else:
            out.append(re.escape(c))
            i += 1
    out.append("$")
    return re.compile("".join(out))


def matches(path: str, pattern: str) -> bool:
    """Return True if ``path`` matches the glob ``pattern``.

    Rules for glob syntax are documented at the top of this module.
    """
    # Fast-path: no meta chars -> straight equality
    if not any(m in pattern for m in "*?["):
        return path == pattern
    return _compile_glob(pattern).match(path) is not None


def load_rules(path: Path) -> list[Rule]:
    """Load rules from a JSON file.

    Expected shape:
      {"rules": [{"pattern": "...", "labels": [...], "priority": N?}, ...]}

    Raises:
      FileNotFoundError if the file doesn't exist.
      ValueError on malformed JSON or missing required fields.
    """
    if not path.exists():
        raise FileNotFoundError(f"Rules file not found: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in {path}: {e}") from e

    if not isinstance(data, dict) or "rules" not in data:
        raise ValueError(f"{path} must be an object with a 'rules' array")

    rules: list[Rule] = []
    for i, r in enumerate(data["rules"]):
        if "pattern" not in r:
            raise ValueError(f"Rule {i} is missing 'pattern' field")
        if "labels" not in r:
            raise ValueError(f"Rule {i} is missing 'labels' field")
        if not isinstance(r["labels"], list) or not all(
            isinstance(l, str) for l in r["labels"]
        ):
            raise ValueError(f"Rule {i}: 'labels' must be a list of strings")
        rules.append(
            Rule(
                pattern=r["pattern"],
                labels=list(r["labels"]),
                priority=int(r.get("priority", 0)),
            )
        )
    return rules


def assign_labels(files: list[str], rules: list[Rule]) -> list[str]:
    """Compute the label set for a list of changed files.

    Algorithm:
      1. For each rule, find the files it matches.
      2. For each label it emits, remember the highest priority that emitted
         it. This resolves "rule conflict": if rules A (priority 50) and B
         (priority 1) both emit "python", the label is kept and its effective
         priority is 50 (so it sorts earlier).
      3. Output labels sorted by effective priority desc, then alphabetically.
    """
    # label -> effective priority (max over contributing rules)
    effective_priority: dict[str, int] = {}
    for rule in rules:
        # If no file matches this rule, skip it entirely.
        matched = any(matches(f, rule.pattern) for f in files)
        if not matched:
            continue
        for label in rule.labels:
            prev = effective_priority.get(label)
            if prev is None or rule.priority > prev:
                effective_priority[label] = rule.priority

    return sorted(
        effective_priority.keys(),
        key=lambda lbl: (-effective_priority[lbl], lbl),
    )


# --- CLI --------------------------------------------------------------------


def _read_files_list(path: Path) -> list[str]:
    if not path.exists():
        raise FileNotFoundError(f"Files list not found: {path}")
    lines = path.read_text().splitlines()
    # Ignore blank lines and comments. A PR's file list is typically small,
    # so this is plenty fast.
    return [l.strip() for l in lines if l.strip() and not l.startswith("#")]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Assign labels to a PR from changed files")
    parser.add_argument("--rules", required=True, type=Path, help="Path to rules JSON file")
    parser.add_argument(
        "--files",
        required=True,
        type=Path,
        help="Path to a text file listing changed file paths, one per line",
    )
    parser.add_argument(
        "--format",
        choices=["lines", "json"],
        default="lines",
        help="Output format: one label per line (default) or a JSON array",
    )
    args = parser.parse_args(argv)

    try:
        rules = load_rules(args.rules)
        files = _read_files_list(args.files)
    except (FileNotFoundError, ValueError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    labels = assign_labels(files, rules)

    if args.format == "json":
        print(json.dumps(labels))
    else:
        for label in labels:
            print(label)
    return 0


if __name__ == "__main__":
    sys.exit(main())
