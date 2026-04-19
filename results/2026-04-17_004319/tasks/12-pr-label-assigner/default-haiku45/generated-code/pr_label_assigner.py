"""
PR Label Assigner: Applies labels to changed files based on configurable rules.

Supports glob patterns, multiple labels per file, and priority ordering.
This module is designed to work with GitHub Actions for automated PR labeling.
"""

from fnmatch import fnmatch
from dataclasses import dataclass, field
from typing import List, Dict


@dataclass
class LabelRule:
    """A rule for assigning labels to files based on glob patterns.

    Attributes:
        pattern: Glob pattern to match file paths (e.g., "src/**/*.py", "docs/*")
        labels: List of labels to assign when pattern matches
        priority: Lower priority numbers execute first; float('inf') = lowest priority
    """

    pattern: str
    labels: List[str]
    priority: float = field(default=float("inf"))


class PRLabelAssigner:
    """Stateful assigner for applying labels to PR changed files."""

    def __init__(self, rules: List[LabelRule]):
        """Initialize assigner with rules.

        Args:
            rules: List of LabelRule objects
        """
        self.rules = rules

    def add_rule(self, rule: LabelRule) -> None:
        """Add a rule to the assigner.

        Args:
            rule: LabelRule to add
        """
        self.rules.append(rule)

    def assign(self, changed_files: List[str]) -> Dict[str, List[str]]:
        """Assign labels to changed files.

        Args:
            changed_files: List of file paths that changed in PR

        Returns:
            Dictionary mapping each file to its assigned labels (deduplicated)
        """
        return assign_labels(changed_files, self.rules)


def _match_pattern(file_path: str, pattern: str) -> bool:
    """Check if a file path matches a glob pattern.

    Handles fnmatch patterns and special case of ** for recursive matching.

    Args:
        file_path: Path to check (e.g., "src/api/handler.py")
        pattern: Glob pattern (e.g., "src/**/*.py")

    Returns:
        True if the file matches the pattern
    """
    # Handle ** as "match anything recursively"
    if "**" in pattern:
        # Convert ** to * for fnmatch (fnmatch treats * as any characters)
        # But we need to be smarter: a/** should match a/b, a/b/c, etc.
        parts = pattern.split("**")
        if len(parts) == 2:
            before, after = parts
            # Check if file starts with before part and matches after part
            if before and after:
                # Pattern like "src/**/*.py"
                if file_path.startswith(before):
                    remainder = file_path[len(before) :]
                    return fnmatch(remainder, "*" + after)
            elif before:
                # Pattern like "src/**"
                return file_path.startswith(before.rstrip("/"))
            elif after:
                # Pattern like "**/*.py"
                return fnmatch(file_path, "*" + after)
    return fnmatch(file_path, pattern)


def assign_labels(
    changed_files: List[str],
    rules: List[LabelRule],
    respect_priority: bool = False,
) -> Dict[str, List[str]]:
    """Assign labels to changed files based on rules.

    Args:
        changed_files: List of file paths that changed in PR
        rules: List of LabelRule objects defining label assignment
        respect_priority: If True, use priority ordering (lower = higher priority)

    Returns:
        Dictionary mapping each file to its list of assigned labels.
        Each file always appears in the result (even if no labels matched).
        Labels are deduplicated but order is preserved by rule order.
    """
    result = {}

    for file_path in changed_files:
        assigned_labels = []

        # Apply rules in order (or by priority if enabled)
        rules_to_apply = rules
        if respect_priority:
            rules_to_apply = sorted(rules, key=lambda r: r.priority)

        for rule in rules_to_apply:
            if _match_pattern(file_path, rule.pattern):
                # Add labels from this rule, avoiding duplicates
                for label in rule.labels:
                    if label not in assigned_labels:
                        assigned_labels.append(label)

        result[file_path] = assigned_labels

    return result


if __name__ == "__main__":
    # Example usage with mock data
    mock_rules = [
        LabelRule(pattern="docs/**", labels=["documentation"]),
        LabelRule(pattern="src/api/**", labels=["api", "backend"]),
        LabelRule(pattern="src/**", labels=["code"]),
        LabelRule(pattern="*.test.py", labels=["tests"]),
    ]

    mock_files = [
        "docs/README.md",
        "src/api/handler.py",
        "src/utils/helper.py",
        "test_main.py",
        "README.md",
    ]

    assigner = PRLabelAssigner(mock_rules)
    labels = assigner.assign(mock_files)

    print("PR Label Assignment Results:")
    print("-" * 50)
    for file, file_labels in labels.items():
        label_str = ", ".join(file_labels) if file_labels else "no labels"
        print(f"{file}: {label_str}")
