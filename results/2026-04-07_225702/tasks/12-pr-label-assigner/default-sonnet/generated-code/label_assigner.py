# PR Label Assigner
# Assigns labels to pull requests based on configurable path-to-label mapping rules.
# Supports glob patterns, multiple labels per file, and priority-based conflict resolution.

from __future__ import annotations

import fnmatch
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class LabelRule:
    """A single mapping rule: if a changed file matches `pattern`, assign `label`.

    Attributes:
        pattern: Glob pattern to match against file paths (e.g., "docs/**", "*.test.*").
        label: The label to assign when the pattern matches.
        priority: Lower numbers = higher priority. Used for ordering and exclusive conflict
                  resolution. Must be a positive integer.
        exclusive_group: Optional group name. When set, only the highest-priority rule
                         in this group that matches will contribute its label; lower-priority
                         rules in the same group are suppressed.
    """

    pattern: str
    label: str
    priority: int
    exclusive_group: Optional[str] = field(default=None)

    def __post_init__(self) -> None:
        # Validate all fields eagerly so callers get clear errors at construction time.
        if not self.pattern:
            raise ValueError("pattern cannot be empty")
        if not self.label:
            raise ValueError("label cannot be empty")
        if not isinstance(self.priority, int) or self.priority < 1:
            raise ValueError("priority must be a positive integer")


def _matches(pattern: str, path: str) -> bool:
    """Return True if `path` matches `pattern` using glob semantics.

    Handles:
    - Standard fnmatch wildcards (*, ?)
    - Double-star (**) for matching across path separators at any depth.

    Strategy: translate `**` into a form that fnmatch can handle by normalising
    the double-star glob into multiple candidate patterns.
    """
    # Normalise path separators to forward slashes for consistent matching.
    path = path.replace("\\", "/")
    pattern = pattern.replace("\\", "/")

    # Fast path: no glob metacharacters — exact match only.
    if "*" not in pattern and "?" not in pattern and "[" not in pattern:
        return path == pattern

    # If the pattern contains `**`, expand it:
    #   `**` should match zero or more path components.
    #   We do this by building two derived patterns:
    #   1. The pattern as-is with `**` replaced by `*` (matches within one directory level).
    #   2. A recursive variant where `**/foo` is tried as `foo` (matches at root).
    # For robustness we use a small recursive expansion approach.
    return _glob_match(pattern, path)


def _glob_match(pattern: str, path: str) -> bool:
    """Match `path` against `pattern` supporting ** glob semantics."""
    # Split both into components for component-level matching.
    pattern_parts = pattern.split("/")
    path_parts = path.split("/")
    return _match_parts(pattern_parts, path_parts)


def _match_parts(pattern_parts: list[str], path_parts: list[str]) -> bool:
    """Recursively match path_parts against pattern_parts.

    The `**` wildcard in a pattern component matches zero or more path components.
    """
    if not pattern_parts and not path_parts:
        return True
    if not pattern_parts:
        return False

    head = pattern_parts[0]
    rest_pattern = pattern_parts[1:]

    if head == "**":
        # `**` can consume zero path components (skip it and try the rest of the pattern)
        if _match_parts(rest_pattern, path_parts):
            return True
        # or consume one path component and keep `**` in play
        if path_parts:
            return _match_parts(pattern_parts, path_parts[1:])
        return False

    if not path_parts:
        return False

    # Match the current component using fnmatch (handles *, ?, [...])
    if fnmatch.fnmatch(path_parts[0], head):
        return _match_parts(rest_pattern, path_parts[1:])

    return False


class LabelAssigner:
    """Assigns labels to a PR based on its changed file paths.

    Rules are evaluated for every file. Labels accumulate across all files.
    Exclusive-group rules within the same group compete: only the highest-priority
    (lowest priority number) matching rule per group contributes its label.
    """

    def __init__(self, rules: list[LabelRule]) -> None:
        # Sort rules by priority ascending (lower number = higher priority first).
        self._rules = sorted(rules, key=lambda r: r.priority)

    def assign(self, file_paths: list[str]) -> set[str]:
        """Return the set of labels that apply to the given list of changed file paths.

        Args:
            file_paths: List of relative file paths changed in the PR.

        Returns:
            Set of label strings.

        Raises:
            TypeError: If file_paths is not a list.
        """
        if not isinstance(file_paths, list):
            raise TypeError("file_paths must be a list of strings")

        labels: set[str] = set()

        # Track the best (highest-priority) rule already matched per exclusive group.
        # Key: group name → best priority seen so far (lower = better).
        best_exclusive: dict[str, int] = {}

        for path in file_paths:
            for rule in self._rules:
                if not _matches(rule.pattern, path):
                    continue

                if rule.exclusive_group:
                    current_best = best_exclusive.get(rule.exclusive_group)
                    if current_best is None or rule.priority < current_best:
                        # This rule wins the group for now — update the best and add its label.
                        # First remove any label added by a previously winning rule in this group.
                        if current_best is not None:
                            # Remove the label added by the previous winner (if still present).
                            # We need to find and remove it.
                            for old_rule in self._rules:
                                if (
                                    old_rule.exclusive_group == rule.exclusive_group
                                    and old_rule.priority == current_best
                                ):
                                    labels.discard(old_rule.label)
                        best_exclusive[rule.exclusive_group] = rule.priority
                        labels.add(rule.label)
                    # else: a higher-priority rule already claimed this group — skip
                else:
                    labels.add(rule.label)

        return labels

    def assign_with_priority(self, file_paths: list[str]) -> list[str]:
        """Like assign(), but returns labels ordered by the priority of their winning rule.

        Labels matched by a lower priority-number rule appear earlier in the list.
        If two labels share the same best priority, they are sorted alphabetically
        for deterministic output.

        Args:
            file_paths: List of relative file paths changed in the PR.

        Returns:
            Ordered list of label strings (highest-priority first).
        """
        if not isinstance(file_paths, list):
            raise TypeError("file_paths must be a list of strings")

        # Map each label to its best (lowest) priority number seen across all files.
        label_priority: dict[str, int] = {}

        for path in file_paths:
            for rule in self._rules:
                if _matches(rule.pattern, path):
                    current = label_priority.get(rule.label)
                    if current is None or rule.priority < current:
                        label_priority[rule.label] = rule.priority

        # Sort by priority ascending, then alphabetically for ties.
        return sorted(label_priority.keys(), key=lambda lbl: (label_priority[lbl], lbl))
