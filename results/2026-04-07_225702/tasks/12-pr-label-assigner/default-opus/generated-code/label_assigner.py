"""
PR Label Assigner — assigns labels to a PR based on changed file paths.

Uses configurable path-to-label mapping with glob patterns, multiple labels
per file, and priority-based conflict resolution.

Priority logic: when multiple rules match the SAME file, only labels from
the highest-priority (lowest number) matching rules are kept for that file.
Rules at the same priority level all apply. Labels are accumulated across
all files to produce the final set.
"""

from __future__ import annotations

import fnmatch
from dataclasses import dataclass


@dataclass(frozen=True)
class LabelRule:
    """A mapping from a glob pattern to a label, with an optional priority.

    Lower priority numbers win when rules conflict on the same file.
    Default priority is 5.
    """
    pattern: str
    label: str
    priority: int = 5

    def __post_init__(self):
        if not self.pattern:
            raise ValueError(f"Invalid pattern: pattern must be non-empty")
        if not self.label:
            raise ValueError(f"Invalid label: label must be non-empty")
        if self.priority < 0:
            raise ValueError(f"Priority must be a positive integer, got {self.priority}")

    def matches(self, path: str) -> bool:
        """Check if a file path matches this rule's glob pattern.

        Supports ** for recursive directory matching and * for single-segment wildcards.
        For basename-only patterns (no /), matches against just the filename.
        """
        # For patterns without a directory separator, match against both
        # the full path and just the basename (last component)
        if "/" not in self.pattern:
            # e.g. "*.test.*" should match "src/deep/foo.test.js"
            basename = path.rsplit("/", 1)[-1] if "/" in path else path
            return fnmatch.fnmatch(basename, self.pattern)

        # For directory patterns, use fnmatch with the full path
        # fnmatch doesn't natively handle ** so we translate it
        return fnmatch.fnmatch(path, self.pattern)


def assign_labels(files: list[str], rules: list[LabelRule]) -> set[str]:
    """Assign labels to a set of changed files based on the given rules.

    For each file, finds all matching rules, then keeps only those at the
    highest priority (lowest number). The final label set is the union of
    labels chosen across all files.

    Args:
        files: list of changed file paths (relative to repo root)
        rules: list of LabelRule instances

    Returns:
        set of label strings to apply to the PR
    """
    if not files or not rules:
        return set()

    all_labels: set[str] = set()

    for path in files:
        # Collect all matching rules for this file
        matches = [r for r in rules if r.matches(path)]
        if not matches:
            continue

        # Find the best (lowest) priority among matches
        best_priority = min(r.priority for r in matches)

        # Keep only labels from rules at the best priority level
        for r in matches:
            if r.priority == best_priority:
                all_labels.add(r.label)

    return all_labels


def load_rules(config: dict) -> list[LabelRule]:
    """Load label rules from a configuration dictionary.

    Expected format:
        {"rules": [{"pattern": "docs/**", "label": "documentation", "priority": 5}, ...]}

    Args:
        config: dict with a "rules" key containing a list of rule dicts

    Returns:
        list of LabelRule instances

    Raises:
        ValueError: if config is missing required keys or has invalid entries
    """
    if "rules" not in config:
        raise ValueError("Configuration must contain a 'rules' key")

    rules = []
    for i, entry in enumerate(config["rules"]):
        if "pattern" not in entry or "label" not in entry:
            raise ValueError(
                f"Rule at index {i} must have 'pattern' and 'label' keys"
            )
        rules.append(LabelRule(
            pattern=entry["pattern"],
            label=entry["label"],
            priority=entry.get("priority", 5),
        ))

    return rules


# --- CLI entry point for quick demo ---

if __name__ == "__main__":
    # Example configuration
    config = {
        "rules": [
            {"pattern": "docs/**", "label": "documentation", "priority": 5},
            {"pattern": "src/api/**", "label": "api", "priority": 1},
            {"pattern": "src/**", "label": "source", "priority": 10},
            {"pattern": "*.test.*", "label": "tests", "priority": 3},
            {"pattern": "*.md", "label": "markdown", "priority": 8},
            {"pattern": ".github/**", "label": "ci", "priority": 2},
        ]
    }

    # Mock PR changed files
    mock_files = [
        "docs/getting-started.md",
        "src/api/users.py",
        "src/api/users.test.py",
        "src/utils/helpers.py",
        ".github/workflows/ci.yml",
        "README.md",
    ]

    rules = load_rules(config)
    labels = assign_labels(mock_files, rules)

    print("Changed files:")
    for f in mock_files:
        file_matches = [r for r in rules if r.matches(f)]
        best = min(r.priority for r in file_matches) if file_matches else None
        chosen = [r.label for r in file_matches if r.priority == best]
        print(f"  {f} -> {', '.join(chosen) if chosen else '(no match)'}")

    print(f"\nFinal label set: {sorted(labels)}")
