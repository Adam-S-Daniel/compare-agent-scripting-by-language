"""PR label assigner.

Reads a list of changed file paths and a set of path-to-label rules, then
emits the deduplicated, priority-ordered set of labels that apply.

Rules are YAML (or JSON) entries of the form:
    - pattern: "docs/**"     # glob, matched against the full path
      label:   documentation
      priority: 10           # higher priority appears first in output

A single file may match multiple rules and therefore contribute multiple
labels. The final output deduplicates labels across all files and sorts by
the rule priority that introduced each label (highest first); ties break
alphabetically so the output is stable.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from pathlib import Path
from typing import Iterable, Sequence


def _glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Translate a glob with ** support into a regex.

    fnmatch's translate doesn't distinguish ** from *, so we roll a small
    translator that treats ** as "any path including separators" and * as
    "any segment characters except /".
    """
    i, n = 0, len(pattern)
    out = ["^"]
    while i < n:
        c = pattern[i]
        if c == "*" and i + 1 < n and pattern[i + 1] == "*":
            # ** — match anything including slashes. Consume an optional
            # trailing slash so "docs/**" matches "docs/a/b" cleanly.
            out.append(".*")
            i += 2
            if i < n and pattern[i] == "/":
                i += 1
        elif c == "*":
            out.append("[^/]*")
            i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(c))
            i += 1
    out.append("$")
    return re.compile("".join(out))


def _matches(path: str, pattern: str) -> bool:
    return _glob_to_regex(pattern).match(path) is not None


def assign_labels(files: Sequence[str], rules: Sequence[dict]) -> list[str]:
    """Return the deduplicated label list for the given files.

    Sorted by priority descending, then label name ascending for stability.
    """
    # Map label -> highest priority seen for it across matching rules.
    label_priority: dict[str, int] = {}
    for path in files:
        for rule in rules:
            if _matches(path, rule["pattern"]):
                pri = int(rule.get("priority", 0))
                if rule["label"] not in label_priority or pri > label_priority[rule["label"]]:
                    label_priority[rule["label"]] = pri
    return sorted(label_priority, key=lambda lbl: (-label_priority[lbl], lbl))


def load_rules(path: str) -> list[dict]:
    """Load and validate rules from a YAML or JSON file.

    Uses a tiny inline YAML reader (only the subset we need: a list of
    mappings of scalar key:value pairs) so the script has zero third-party
    dependencies and runs cleanly inside the act container.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"rules file not found: {path}")
    text = p.read_text()
    rules = _parse_rules_yaml(text) if not text.lstrip().startswith("[") else json.loads(text)

    for idx, rule in enumerate(rules):
        if "pattern" not in rule:
            raise ValueError(f"rule #{idx} missing 'pattern'")
        if "label" not in rule:
            raise ValueError(f"rule #{idx} missing 'label'")
        rule.setdefault("priority", 0)
    return rules


def _parse_rules_yaml(text: str) -> list[dict]:
    """Parse the limited YAML subset we use: a list of flat mappings."""
    rules: list[dict] = []
    current: dict | None = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if line.startswith("- "):
            if current is not None:
                rules.append(current)
            current = {}
            rest = line[2:].strip()
            if rest:
                _absorb_kv(current, rest)
        else:
            if current is None:
                raise ValueError("expected list item starting with '- '")
            _absorb_kv(current, line.strip())
    if current is not None:
        rules.append(current)
    return rules


def _absorb_kv(target: dict, segment: str) -> None:
    if ":" not in segment:
        raise ValueError(f"expected key:value, got {segment!r}")
    key, _, value = segment.partition(":")
    key = key.strip()
    value = value.strip()
    if value.startswith(("'", '"')) and value.endswith(value[0]) and len(value) >= 2:
        value = value[1:-1]
    elif value.lstrip("-").isdigit():
        value = int(value)
    target[key] = value


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Assign labels to a PR based on changed files.")
    parser.add_argument("--rules", required=True, help="Path to rules YAML/JSON file.")
    parser.add_argument("--files", required=True, help="Path to a newline-delimited list of changed files.")
    args = parser.parse_args(list(argv) if argv is not None else None)

    try:
        rules = load_rules(args.rules)
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"error: invalid rules: {exc}", file=sys.stderr)
        return 2

    files_path = Path(args.files)
    if not files_path.exists():
        print(f"error: files list not found: {args.files}", file=sys.stderr)
        return 2
    files = [line.strip() for line in files_path.read_text().splitlines() if line.strip()]

    labels = assign_labels(files, rules)
    json.dump({"labels": labels, "count": len(labels)}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
