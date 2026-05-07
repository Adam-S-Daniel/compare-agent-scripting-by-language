"""PR label assigner.

Given a list of changed file paths and a config of glob-pattern -> label
rules, emit the deduplicated set of labels that should be applied to the
PR.

Concepts
--------
* Each rule has a ``pattern`` (glob), a ``label`` (string), and optionally
  a ``group`` plus ``priority``. Rules in the same ``group`` conflict:
  for any given file, only the highest-priority rule in that group
  contributes its label. Rules without a group are independent and always
  contribute when matched.
* Glob semantics follow common path-matching conventions:
    ``**``      any number of path segments (including zero)
    ``*``       any characters in a single segment (no ``/``)
    ``?``       a single non-``/`` character
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence


class LabelAssignerError(Exception):
    """Raised on configuration or input errors."""


@dataclass(frozen=True)
class LabelRule:
    pattern: str
    label: str
    group: str | None = None
    priority: int = 0


# --- glob -> regex ------------------------------------------------------
def _glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Translate a glob pattern to an anchored regex.

    Supports ``**`` (any path segments), ``*`` (any chars in one segment),
    and ``?`` (one non-``/`` char). Simpler and more predictable than
    ``fnmatch`` for the patterns this tool actually has to handle.
    """
    out: list[str] = []
    i = 0
    n = len(pattern)
    while i < n:
        c = pattern[i]
        if c == "*":
            if i + 1 < n and pattern[i + 1] == "*":
                # `**/` consumes zero or more leading path segments;
                # bare `**` (e.g. at end) matches anything.
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
        elif c in r".\+()^$|{}[]":
            out.append("\\" + c)
            i += 1
        else:
            out.append(c)
            i += 1
    return re.compile("^" + "".join(out) + "$")


def _matches(pattern: str, path: str) -> bool:
    return _glob_to_regex(pattern).match(path) is not None


# --- core ---------------------------------------------------------------
def assign_labels(rules: Sequence[LabelRule], files: Iterable[str]) -> list[str]:
    """Return the sorted, deduplicated list of labels for ``files``.

    For each file:
      * collect every rule whose pattern matches
      * within each conflict ``group``, keep only the highest-priority rule
      * ungrouped rules always contribute when matched
    """
    labels: set[str] = set()
    for f in files:
        if not f:
            continue
        matched = [r for r in rules if _matches(r.pattern, f)]
        winners_per_group: dict[str, LabelRule] = {}
        for r in matched:
            if r.group is None:
                labels.add(r.label)
            else:
                cur = winners_per_group.get(r.group)
                if cur is None or r.priority > cur.priority:
                    winners_per_group[r.group] = r
        for r in winners_per_group.values():
            labels.add(r.label)
    return sorted(labels)


# --- config loading -----------------------------------------------------
def _coerce_rules(raw: object, source: str) -> list[LabelRule]:
    if not isinstance(raw, dict) or "rules" not in raw:
        raise LabelAssignerError(
            f"{source}: top-level must be a mapping with a 'rules' key"
        )
    items = raw["rules"]
    if not isinstance(items, list):
        raise LabelAssignerError(f"{source}: 'rules' must be a list")
    out: list[LabelRule] = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            raise LabelAssignerError(
                f"{source}: rule #{idx} must be a mapping"
            )
        if "pattern" not in item:
            raise LabelAssignerError(
                f"{source}: rule #{idx} missing required field 'pattern'"
            )
        if "label" not in item:
            raise LabelAssignerError(
                f"{source}: rule #{idx} missing required field 'label'"
            )
        out.append(LabelRule(
            pattern=str(item["pattern"]),
            label=str(item["label"]),
            group=(str(item["group"]) if item.get("group") is not None else None),
            priority=int(item.get("priority", 0)),
        ))
    return out


def load_rules(path: str) -> list[LabelRule]:
    p = Path(path)
    if not p.exists():
        raise LabelAssignerError(f"rules config not found: {path}")
    suffix = p.suffix.lower()
    text = p.read_text(encoding="utf-8")
    try:
        if suffix == ".json":
            data = json.loads(text)
        elif suffix in (".yaml", ".yml"):
            import yaml  # local import; YAML is optional
            data = yaml.safe_load(text)
        else:
            raise LabelAssignerError(
                f"unsupported rules-file extension: {suffix or '(none)'}"
            )
    except json.JSONDecodeError as exc:
        raise LabelAssignerError(f"invalid JSON in {path}: {exc}") from exc
    return _coerce_rules(data, source=path)


# --- CLI ----------------------------------------------------------------
def _read_files_list(path: str) -> list[str]:
    p = Path(path)
    if not p.exists():
        raise LabelAssignerError(f"changed-files list not found: {path}")
    out: list[str] = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            out.append(line)
    return out


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Assign labels to a PR based on its changed files."
    )
    parser.add_argument("--rules", required=True, help="path to rules config (JSON or YAML)")
    parser.add_argument("--files", required=True, help="path to a newline-separated list of changed files")
    args = parser.parse_args(argv)

    try:
        rules = load_rules(args.rules)
        files = _read_files_list(args.files)
    except LabelAssignerError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    labels = assign_labels(rules, files)
    for lbl in labels:
        print(lbl)
    # Machine-readable summary the workflow / harness can grep for.
    print(f"LABELS_JSON={json.dumps(labels)}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
