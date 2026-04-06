"""
PR Label Assigner

Assigns labels to a PR based on configurable path-to-label mapping rules.
Supports glob patterns, multiple labels per file, and priority ordering.

Design:
  - LabelRule: a single pattern -> label mapping with a priority
  - LabelConfig: a collection of rules with an optional exclusive mode
  - assign_labels(): core function that takes file paths + config and returns labels
"""

import fnmatch
import re
from dataclasses import dataclass, field
from typing import List


def _validate_glob_pattern(pattern: str) -> None:
    """
    Validate that a glob pattern is syntactically usable.
    Raises ValueError for patterns with unclosed character classes or bad regex.

    Note: fnmatch.translate() silently escapes unclosed '[' rather than raising,
    so we must detect unclosed brackets explicitly before delegating to regex.
    """
    # Detect unclosed character classes (e.g. '[invalid')
    i = 0
    while i < len(pattern):
        if pattern[i] == "[":
            j = i + 1
            if j < len(pattern) and pattern[j] == "!":
                j += 1
            if j < len(pattern) and pattern[j] == "]":
                j += 1
            while j < len(pattern) and pattern[j] != "]":
                j += 1
            if j >= len(pattern):
                raise ValueError(
                    f"Invalid glob pattern '{pattern}': unclosed character class '['"
                )
        i += 1
    # Also try to compile the translated regex in case of other bad constructs
    try:
        re.compile(fnmatch.translate(pattern))
    except re.error as exc:
        raise ValueError(f"Invalid glob pattern '{pattern}': {exc}") from exc


@dataclass
class LabelRule:
    """
    A single rule mapping a glob pattern to a label.

    Attributes:
        pattern:  Glob pattern (e.g. 'docs/**', '**/*.test.*')
        label:    The label to apply when the pattern matches
        priority: Higher numbers = higher priority (default 0)
    """

    pattern: str
    label: str
    priority: int = 0

    def __post_init__(self) -> None:
        # Validate inputs eagerly so callers get clear errors immediately
        if not self.pattern:
            raise ValueError("Pattern cannot be empty")
        if not self.label:
            raise ValueError("Label cannot be empty")
        _validate_glob_pattern(self.pattern)

    def matches(self, file_path: str) -> bool:
        """
        Return True if *file_path* matches this rule's glob pattern.

        fnmatch.fnmatch is used for single-component wildcards (*).
        The '**' wildcard is expanded to match any number of path segments
        by treating the pattern as a series of path parts joined with fnmatch.
        """
        return _glob_match(self.pattern, file_path)


@dataclass
class LabelConfig:
    """
    Configuration holding a list of LabelRules.

    Attributes:
        rules:     Ordered list of LabelRule objects
        exclusive: When True, only the highest-priority matching rule(s)
                   per file contribute labels (conflict resolution mode).
                   When False (default), all matching rules apply.
    """

    rules: List[LabelRule] = field(default_factory=list)
    exclusive: bool = False


# ---------------------------------------------------------------------------
# Core glob matching
# ---------------------------------------------------------------------------

def _glob_match(pattern: str, path: str) -> bool:
    """
    Match *path* against *pattern* supporting ** for multi-segment wildcards.

    Strategy:
      1. If pattern contains '**', convert to a regex that allows '**' to
         span zero or more path segments (including '/').
      2. Otherwise fall back to fnmatch which handles '*' and '?' within
         a single path segment.
    """
    if "**" in pattern:
        regex = _glob_to_regex(pattern)
        return bool(re.fullmatch(regex, path))
    # For plain patterns (no **), fnmatch handles * within the filename
    return fnmatch.fnmatch(path, pattern)


def _glob_to_regex(pattern: str) -> str:
    """
    Convert a glob pattern (including **) to a regex string.

    Rules:
      - **  matches zero or more characters including '/'
      - *   matches zero or more characters except '/'
      - ?   matches exactly one character except '/'
      - .   is escaped (treated literally)
    """
    # We build the regex piece by piece
    parts = re.split(r"(\*\*|\*|\?|\.)", pattern)
    regex_parts = []
    for part in parts:
        if part == "**":
            regex_parts.append(".*")          # any chars including /
        elif part == "*":
            regex_parts.append("[^/]*")       # any chars except /
        elif part == "?":
            regex_parts.append("[^/]")        # single char except /
        elif part == ".":
            regex_parts.append(r"\.")         # literal dot
        else:
            regex_parts.append(re.escape(part))
    return "".join(regex_parts)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def assign_labels(file_paths: List[str], config: LabelConfig) -> List[str]:
    """
    Determine which labels apply to a PR described by *file_paths*.

    Algorithm:
      For each file, collect all rules that match it.
      If config.exclusive is True, keep only rules with the maximum priority
      among those that matched (per file).
      Accumulate all resulting labels, deduplicate, and sort by descending
      priority so the most important labels appear first.

    Args:
        file_paths: List of changed file paths in the PR.
        config:     Label configuration with rules.

    Returns:
        Deduplicated list of label strings ordered by descending priority.
    """
    if not file_paths or not config.rules:
        return []

    # label -> highest priority at which it was awarded
    label_priority: dict[str, int] = {}

    for file_path in file_paths:
        matching_rules = [r for r in config.rules if r.matches(file_path)]

        if not matching_rules:
            continue

        if config.exclusive:
            # Only rules with the maximum priority for this file contribute
            max_priority = max(r.priority for r in matching_rules)
            matching_rules = [r for r in matching_rules if r.priority == max_priority]

        for rule in matching_rules:
            # Track the highest priority for each label (for final ordering)
            if rule.label not in label_priority or rule.priority > label_priority[rule.label]:
                label_priority[rule.label] = rule.priority

    # Return labels sorted by descending priority (highest first)
    return sorted(label_priority.keys(), key=lambda lbl: label_priority[lbl], reverse=True)
